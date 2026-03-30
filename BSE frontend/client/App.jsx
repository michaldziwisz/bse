import React, { Fragment } from 'react';
import { Helmet } from 'react-helmet-async';
import { Route, Switch } from 'react-router-dom';
import { makeStyles } from '@material-ui/core';
import { useLocalization } from './context/localization';
// import PrivateRoute from './components/PrivateRoute';
import ViewMain from './views/main';
import ViewSettings from './views/settings';
import ViewAdministration from './views/administration';
import ViewNotFound from './views/notFound';
import routes from './routes';
import {
  layoutFlexNoShrink,
  layoutVertical,
} from './mixins';
import favicon from './images/favicon.ico';


const useStyles = makeStyles(theme => ({
  root: {
    ...layoutVertical,
    position: 'relative',
    minHeight: '100vh',
    backgroundColor: theme.palette.background.default,
    fontFamily: theme.typography.fontFamily,
    fontSize: theme.typography.fontSize,
    '& a': {
      cursor: 'pointer',
    },
  },
  content: {
    ...layoutFlexNoShrink,
    ...layoutVertical,
    position: 'relative',
  },
}));

function App() {
  const { translate, locale } = useLocalization();
  const classes = useStyles();

  return (
    <Fragment>
      <Helmet>
        <html lang={locale} />
        <title>{translate('title')}</title>
        <link rel="icon" href={favicon} sizes="64x64" />
      </Helmet>
      <div className={classes.root}>
        <main className={classes.content}>
          <Switch>
            <Route path={routes.index} exact component={ViewMain} />
            <Route path={routes.settings} exact component={ViewSettings} />
            <Route path={routes.administration} exact component={ViewAdministration} />
            <Route component={ViewNotFound} />
          </Switch>
        </main>
      </div>
    </Fragment>
  );
}

export default App;
