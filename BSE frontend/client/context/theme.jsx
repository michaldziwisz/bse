import React from 'react';
import PropTypes from 'prop-types';
import constate from 'constate';
import { CssBaseline, ThemeProvider } from '@material-ui/core';
import {
  getLocalizedTheme,
  getLocale,
  locales,
} from '../services/localization/theme';
import { useLocalization } from './localization';

/** @module ContextTheme */

/**
 * Theme localization context hook
 * @returns {Object} Theme bag
 */
function useLocalizedThemeHook() {
  const { locale: language } = useLocalization();

  const [themeName, changeTheme] = React.useState('main');
  const [locale, setLocaleContent] = React.useState(locales.en);
  const [error, setError] = React.useState(null);

  const theme = React.useMemo(() => getLocalizedTheme(locale, themeName), [locale, themeName]);

  React.useEffect(() => {
    getLocale(language)
      .then(localeContent => setLocaleContent(localeContent))
      .catch(setError);
  }, [language]);

  return {
    theme,
    error,
    changeTheme,
  };
}

const [InternalProvider, useLocalizedTheme] = constate(useLocalizedThemeHook);

/**
 * Proxy component providing theme and css baseline
 * @param {Object} props
 * @param {*} props.children
 * @returns React component
 */
function LocalizedThemeProxy({ children }) {
  const { theme } = useLocalizedTheme();
  return (
    <ThemeProvider theme={theme}>
      <CssBaseline />
      {children}
    </ThemeProvider>
  );
}
LocalizedThemeProxy.propTypes = {
  children: PropTypes.oneOfType([
    PropTypes.arrayOf(PropTypes.node),
    PropTypes.node,
  ]).isRequired,
};

/**
 * Provider component for theme localization context
 * @param {Object} props
 * @param {*} props.children
 * @returns React component
 */
function LocalizedThemeProvider({ children }) {
  return (
    <InternalProvider>
      <LocalizedThemeProxy>
        {/* CssBaseline kickstart an elegant, consistent,
        and simple baseline to build upon. */}
        <CssBaseline />
        {children}
      </LocalizedThemeProxy>
    </InternalProvider>
  );
}
LocalizedThemeProvider.propTypes = {
  children: PropTypes.oneOfType([
    PropTypes.arrayOf(PropTypes.node),
    PropTypes.node,
  ]).isRequired,
};

export { LocalizedThemeProvider, useLocalizedTheme };
