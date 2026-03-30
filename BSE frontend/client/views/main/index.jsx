/* eslint-disable no-shadow */

import React from 'react';
import { Link } from 'react-router-dom';
import {
  makeStyles,
  Button,
  Typography,
} from '@material-ui/core';
import { getHelmReadings } from '../../hooks/sensors';
import { useLocalization } from '../../context/localization';
import { useNotifications } from '../../context/notifications';
import { useVoices } from '../../context/voices';
import CourseSettings from './CourseSettings';
import compass from '../../images/compass.svg';
import {
  layoutCenter,
  layoutCenterCenter,
  layoutFlexNoShrink,
  layoutVertical,
} from '../../mixins';
import {
  getRelativeCourse,
  ensureApisEnabled,
  describeStatus,
  signalizeStatus,
} from './helpers';
import { useSettings } from '../../context/settings';
import routes from '../../routes';

/** @module ViewMain */

const READING_ORCHESTRATION_INTERVAL = 10;
const STATUS_UPDATE_INTERVAL = 500;

const useStyles = makeStyles(theme => ({
  root: {
    ...layoutFlexNoShrink,
    ...layoutVertical,
    ...layoutCenter,
  },
  content: {
    maxWidth: 360,
    width: '100%',
  },
  statusContainer: {
    ...layoutVertical,
    ...layoutCenterCenter,
    background: '#fff',
    position: 'relative',
    overflow: 'hidden',
    height: 360,
    width: 360,
  },
  status: {
    ...layoutVertical,
    ...layoutCenterCenter,
    textAlign: 'center',
    background: `radial-gradient(circle, ${theme.palette.background.default} 0%, ${theme.palette.background.default} 40%, rgba(0, 0, 0, 0) 70%)`,
    height: '4em',
    width: '4em',
    zIndex: 1,
  },
  statusBackground: {
    position: 'absolute',
    width: '100%',
    height: '100%',
    top: 0,
    left: 0,
    zIndex: 0,
    backgroundImage: `url(${compass})`,
    backgroundPosition: 'center center',
    backgroundSize: 'cover',
  },
  readingToggle: {
    margin: theme.spacing(3, 0, 1),
    width: '100%',
  },
  link: {
    marginTop: theme.spacing(3),
    display: 'block',
    '& > *': {
      width: '100%',
    },
  },
  copyright: {
    marginTop: theme.spacing(2),
    marginBottom: theme.spacing(1),
    textAlign: 'center',
    fontStyle: 'italic',
  },
  ariaText: {
    maxWidth: 360,
    width: '100%',
    backgroundColor: '#fff',
    color: '#000',
    textAlign: 'center',
    textTransform: 'uppercase',
    fontSize: '2em',
  },
}));

/**
 * Main view
 * @returns React component
 */
function ViewMain() {
  const { translate } = useLocalization();
  const { showError } = useNotifications();
  const voices = useVoices();
  const classes = useStyles();

  const [settings, setSettings] = useSettings();
  const [initialized, setInitialized] = React.useState(false);
  const [status, setStatus] = React.useState(null);
  const [enabled, setEnabled] = React.useState(false);
  const [error, setError] = React.useState(null);
  const [voice, setVoice] = React.useState(null);
  const [ariaText, setAriaText] = React.useState('');
  const [screenLock, setScreenLock] = React.useState(null);
  const runnerRef = React.useRef(null);
  const runnerStateRef = React.useRef({
    lastUpdate: 0,
    lastRead: 0,
    lastSignal: 0,
    updating: false,
    reading: false,
    signalizing: false,
    status: {},
    lastSignallizedStatus: {},
    unmounted: false,
  });

  const toggleEnabled = React.useCallback(
    () => {
      if (!initialized) {
        ensureApisEnabled();
        setInitialized(true);
      }
      if (error) {
        setError(false);
        setEnabled(true);
      } else {
        setEnabled(!enabled);
      }
    },
    [enabled, error, initialized],
  );

  // eslint-disable-next-line prefer-arrow-callback
  const getStatus = React.useCallback(async function _getStatus(tries = 3) {
    try {
      const readings = await getHelmReadings(settings);
      const {
        wa: wind,
        rsa: rudder,
      } = readings;
      return {
        course: readings[settings.courseSource],
        rudder: typeof rudder === 'number'
          ? (rudder + (settings.rudderAngleCorrection || 0)) * (settings.invertRudderAngle ? -1 : 1)
          : undefined,
        wind,
      };
    } catch (err) {
      err.preventDefault();
      if (tries > 1) {
        return _getStatus(tries - 1);
      }
      setError(err);
      setEnabled(false);
      showError('reading.error.communication');
      throw err;
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [settings, translate, showError]);

  React.useEffect(() => { // lock screen when enabled
    async function lockScreen() {
      try {
        const lock = await navigator.wakeLock?.request('screen');
        setScreenLock(lock);
      } catch (error) {
        // eslint-disable-next-line no-console
        console.warn('Failed to lock screen', error);
      }
    }
    if (enabled && !screenLock) {
      lockScreen();
    } else if (screenLock && !enabled) {
      screenLock.release();
      setScreenLock(null);
    }
  }, [enabled, screenLock]);

  React.useEffect(() => { // set voice when available
    setVoice(voices?.available.find(v => v.value === settings.readingVoice)?.instance);
  }, [settings, voices, setVoice]);

  React.useEffect(() => { // orchestrate state updates and reading
    runnerRef.current = () => {
      const state = runnerStateRef.current;
      if (!state.updating && Date.now() - state.lastUpdate > STATUS_UPDATE_INTERVAL) {
        state.updating = true;
        getStatus()
          .then((currentStatus) => {
            state.lastUpdate = Date.now();
            state.status = currentStatus;
            setStatus(currentStatus);
          }, () => {
            state.status = {};
            setStatus(null);
          }).finally(() => {
            state.updating = false;
          });
      }
      const now = Date.now();
      if (enabled) {
        const delay = settings.readingOutput === 'aria'
          ? settings.readingInterval
          : settings.readingDelay;
        if (!state.reading && !(state.signalizing && settings.avoidSignalsOverlap)
          && now - state.lastRead > delay * 1000) {
          state.lastRead = now;
          state.reading = true;
          describeStatus(settings, state.status, {
            setAriaText,
            translate,
            voice,
          }).catch((error) => {
            showError('reading.error.speechSynthesis');
            // eslint-disable-next-line no-console
            console.error(error);
          }).finally(() => {
            state.reading = false;
          });
        }
        if (settings.soundSignalsEnabled && !state.signalizing
          && !(state.reading && settings.avoidSignalsOverlap)
          && now - state.lastSignal > settings.toneDelay * 1000) {
          state.lastSignal = now;
          state.signalizing = true;
          signalizeStatus(settings, state.status, state.lastSignallizedStatus || state.status)
            .finally(() => {
              state.signalizing = false;
            });
          state.lastSignallizedStatus = state.status;
        }
      }
      if (!error && !state.unmounted) {
        setTimeout(() => runnerRef.current(), READING_ORCHESTRATION_INTERVAL);
      }
    };
  }, [
    enabled,
    settings,
    error,
    getStatus,
    showError,
    translate,
    voice,
  ]);

  React.useEffect(() => {
    // initialize orchestration tick on mount/error ack and disable it on unmount
    if (!error) {
      setTimeout(() => runnerRef.current(), READING_ORCHESTRATION_INTERVAL);
    }
    const runnerState = runnerStateRef.current;
    return () => {
      runnerState.unmounted = true;
    };
  }, [runnerRef, runnerStateRef, error]);

  // TODO: add nmea data screen?

  const currentValue = status
    ? status[settings.target === 'none' ? 'course' : settings.target]
    : null;
  const targetValue = {
    course: settings.targetCourse,
  }[settings.target || 'none'];
  let displayedValue;
  if (currentValue === null || typeof currentValue === 'undefined') {
    displayedValue = '?';
  } else if (typeof targetValue === 'undefined') {
    displayedValue = Math.round(currentValue);
  } else {
    displayedValue = Math.round(getRelativeCourse(currentValue, targetValue));
  }

  return (
    <div className={classes.root}>
      <div className={classes.content}>
        {enabled && !error && settings.readingOutput === 'aria' && (
          <div
            id="aria-course"
            aria-live="assertive"
            aria-relevant="additions"
            className={classes.ariaText}
          >
            {ariaText}
          </div>
        )}
        <div aria-hidden className={classes.statusContainer}>
          <div className={classes.statusBackground} style={{ transform: `rotate(${-status?.course || 0}deg)` }} />
          <Typography variant="h3" className={classes.status}>
            {displayedValue}
            <br />
            {status?.rudder && Math.round(status.rudder)}
          </Typography>
        </div>
        <Button
          variant="contained"
          onClick={toggleEnabled}
          className={classes.readingToggle}
        >
          {translate(enabled && !error ? 'reading.stop' : 'reading.start')}
        </Button>
        <CourseSettings
          settings={settings}
          course={currentValue}
          onSettingsChange={setSettings}
        />
        <Link href={routes.settings} to={routes.settings} className={classes.link}>
          <Button
            variant="contained"
            className={classes.button}
          >
            {translate('settings.action.show')}
          </Button>
        </Link>
        <div className={classes.copyright}>
          Copyright © 2021-25 Błażej Wolańczyk
        </div>
      </div>
    </div>
  );
}

export default ViewMain;
