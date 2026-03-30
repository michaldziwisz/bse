import React from 'react';
import PropTypes from 'prop-types';
import constate from 'constate';
import { createIntl, createIntlCache, RawIntlProvider } from 'react-intl';
import { locales, getLocale, getTranslationAgent } from '../services/localization';

/** @module ContextLocalization */

const cache = createIntlCache();
const defaultIntl = createIntl({ locale: 'en-GB', messages: locales.en }, cache);

/**
 * Get stored locale from local storage
 * @returns {string|null} Stored locale
 */
function getStoredLocale() {
  return window.localStorage
    ? localStorage.language || navigator.language || navigator.userLanguage
    : null;
}

/**
 * Write locale into loacal storage
 * @param {string} language
 */
function setStoredLocale(language) {
  if (window.localStorage) {
    localStorage.language = language;
  }
}

/**
 * Localization context hook
 * @returns {Object} Localization bag
 */
function useLocalizationHook() {
  const agent = React.useRef({});
  const [intl, setIntl] = React.useState(defaultIntl);
  const [error, setError] = React.useState(null);
  const [locale, setLocaleValue] = React.useState('en-GB');
  const storedLocale = getStoredLocale();

  const translate = React.useCallback(getTranslationAgent(intl), [intl]);
  const changeLocale = React.useCallback((language) => {
    setError(null);
    getLocale(language)
      .then(messages => setIntl(createIntl({ locale: language, messages }, cache)))
      .then(() => {
        setStoredLocale(language);
        setLocaleValue(language);
      })
      .catch(setError);
  }, []);

  React.useEffect(() => {
    if (storedLocale && locale !== storedLocale) {
      changeLocale(storedLocale);
    }
  }, [locale, storedLocale, changeLocale]);

  React.useEffect(() => {
    agent.current.intl = intl;
    agent.current.translate = translate;
  }, [agent, intl, translate]);

  return {
    agent: agent.current,
    intl,
    translate,
    error,
    locale,
    changeLocale,
  };
}
const [IntlProvider, useLocalization] = constate(useLocalizationHook);

/**
 * Proxy component providing intl instance
 * @param {Object} props
 * @param {*} props.children
 * @returns React component
 */
function IntlProxy({ children }) {
  const { intl } = useLocalization();
  return (
    <RawIntlProvider value={intl}>
      {children}
    </RawIntlProvider>
  );
}
IntlProxy.propTypes = {
  children: PropTypes.oneOfType([
    PropTypes.arrayOf(PropTypes.node),
    PropTypes.node,
  ]).isRequired,
};

/**
 * Provider component for intl localization context
 * @param {Object} props
 * @param {*} props.children
 * @returns React component
 */
function LocalizationProvider({ children }) {
  return (
    <IntlProvider>
      <IntlProxy>
        {children}
      </IntlProxy>
    </IntlProvider>
  );
}
LocalizationProvider.propTypes = {
  children: PropTypes.oneOfType([
    PropTypes.arrayOf(PropTypes.node),
    PropTypes.node,
  ]).isRequired,
};

export { LocalizationProvider, useLocalization };
