/* eslint-disable no-shadow */

import React from 'react';
import { Link } from 'react-router-dom';
import {
  makeStyles,
  Button,
  Typography,
} from '@material-ui/core';
import { runCalibration, runReboot } from '../../hooks/settings';
import { useLocalization } from '../../context/localization';
import { useNotifications } from '../../context/notifications';
import routes from '../../routes';

import {
  layoutCenter,
  layoutFlexNoShrink,
  layoutSelfStretch,
  layoutVertical,
} from '../../mixins';

/** @module ViewAdministration */

const useStyles = makeStyles(theme => ({
  root: {
    ...layoutFlexNoShrink,
    ...layoutVertical,
    ...layoutCenter,
  },
  container: {
    ...layoutVertical,
    maxWidth: 360,
    width: '100%',
    '& > *': {
      ...layoutSelfStretch,
      margin: theme.spacing(1, 0),
    },
  },
  header: {
    textAlign: 'center',
  },
  link: {
    margin: theme.spacing(1, 0),
    display: 'block',
    '& > *': {
      width: '100%',
    },
  },
}));

/**
 * View for device administartion
 * @returns React component
 */
function ViewAdministration() {
  const { translate } = useLocalization();
  const { showInfo, showError } = useNotifications();
  const classes = useStyles();

  const calibrate = React.useCallback(async () => {
    try {
      await runCalibration();
      showInfo('administration.action.calibrate.success');
    } catch (err) {
      err.preventDefault();
      showError('administration.action.calibrate.error');
    }
  }, [showInfo, showError]);
  const reboot = React.useCallback(async () => {
    try {
      await runReboot();
      showInfo('administration.action.reboot.success');
    } catch (err) {
      err.preventDefault();
      showError('administration.action.reboot.error');
    }
  }, [showInfo, showError]);

  return (
    <div className={classes.root}>
      <div className={classes.container}>
        <Typography component="h1" variant="h3" className={classes.header}>
          {translate('administration.title')}
        </Typography>
        <Button variant="contained" onClick={calibrate}>
          {translate('administration.action.calibrate')}
        </Button>
        <Button variant="contained" onClick={reboot}>
          {translate('administration.action.reboot')}
        </Button>
        <Link href={routes.settings} to={routes.settings} className={classes.link}>
          <Button
            variant="contained"
            className={classes.button}
          >
            {translate('settings.action.show')}
          </Button>
        </Link>
        <Link href={routes.index} to={routes.index} className={classes.link}>
          <Button
            variant="contained"
            className={classes.button}
          >
            {translate('settings.action.back')}
          </Button>
        </Link>
      </div>
    </div>
  );
}

export default ViewAdministration;
