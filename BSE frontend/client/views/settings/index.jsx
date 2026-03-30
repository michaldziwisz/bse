/* eslint-disable no-shadow */

import React from 'react';
import { Link } from 'react-router-dom';
import {
  makeStyles,
  Button,
} from '@material-ui/core';
import { useLocalization } from '../../context/localization';
import {
  layoutCenter,
  layoutFlexNoShrink,
  layoutSelfStretch,
  layoutVertical,
} from '../../mixins';
import MainSettings from './MainSettings';
import routes from '../../routes';

/** @module ViewSettings */

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
  form: {
    marginBottom: theme.spacing(2),
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
 * View allowing settings change, device calibration and reboot
 * @returns React component
 */
function ViewSettings() {
  const { translate } = useLocalization();
  const classes = useStyles();

  return (
    <div className={classes.root}>
      <div className={classes.container}>
        <MainSettings className={classes.form} />
        <Link href={routes.index} to={routes.index} className={classes.link}>
          <Button
            variant="contained"
            className={classes.button}
          >
            {translate('settings.action.back')}
          </Button>
        </Link>
        <Link href={routes.administration} to={routes.administration} className={classes.link}>
          <Button
            variant="contained"
            className={classes.button}
          >
            {translate('administration.title')}
          </Button>
        </Link>
      </div>
    </div>
  );
}

export default ViewSettings;
