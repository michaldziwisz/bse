import React from 'react';
import { makeStyles } from '@material-ui/core';
import { Link } from 'react-router-dom';
import { useLocalization } from '../../context/localization';
import { layoutCenterCenter, layoutFlexNoShrink, layoutVertical } from '../../mixins';
import routes from '../../routes';
import DeathStar from '../../icons/DeathStar';

/** @module ViewNotFound */

const useStyles = makeStyles(theme => ({
  root: {
    ...layoutFlexNoShrink,
    ...layoutVertical,
    ...layoutCenterCenter,
  },
  icon: {
    width: '4em',
    height: '4em',
  },
  text: {
    fontSize: '2em',
    marginTop: theme.spacing(1),
  },
  link: {
    color: 'inherit',
  },
}));

/**
 * View displaying not found status
 * @returns React component
 */
function ViewNotFound() {
  const { translate } = useLocalization();
  const classes = useStyles();

  return (
    <div className={classes.root}>
      <DeathStar className={classes.icon} />
      <div className={classes.text}>{translate('error.notFound')}</div>
      <Link to={routes.index} className={classes.link}>{translate('common.mainPage')}</Link>
    </div>
  );
}

export default ViewNotFound;
