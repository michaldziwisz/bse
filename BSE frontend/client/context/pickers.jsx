import React from 'react';
import PropTypes from 'prop-types';
import constate from 'constate';
import DateFnsUtils from '@date-io/date-fns';
import { MuiPickersUtilsProvider } from '@material-ui/pickers';
import {
  getLocale,
  locales,
} from '../services/localization/pickers';
import { useLocalization } from './localization';

/** @module ContextPickers */

/**
 * Pickers context hook
 * @returns {Object} Picker locales bag
 */
function usePickerUtilsHook() {
  const { locale: language } = useLocalization();
  const [locale, setLocaleContent] = React.useState(locales.en);
  const [error, setError] = React.useState(null);
  React.useEffect(() => {
    getLocale(language)
      .then(localeContent => setLocaleContent(localeContent))
      .catch(setError);
  }, [language]);
  return {
    locale,
    error,
  };
}

const [InternalProvider, usePickerLocalization] = constate(usePickerUtilsHook);

/**
 * Proxy component providing date utils and locale
 * @param {Object} props
 * @param {*} props.children
 * @returns React component
 */
function PickerUtilsProxy({ children }) {
  const { locale } = usePickerLocalization();
  return (
    <MuiPickersUtilsProvider utils={DateFnsUtils} locale={locale}>
      {children}
    </MuiPickersUtilsProvider>
  );
}
PickerUtilsProxy.propTypes = {
  children: PropTypes.oneOfType([
    PropTypes.arrayOf(PropTypes.node),
    PropTypes.node,
  ]).isRequired,
};

/**
 * Provider component for picker localization context
 * @param {Object} props
 * @param {*} props.children
 * @returns React component
 */
function PickerLocalizationProvider({ children }) {
  return (
    <InternalProvider>
      <PickerUtilsProxy>
        {children}
      </PickerUtilsProxy>
    </InternalProvider>
  );
}
PickerLocalizationProvider.propTypes = {
  children: PropTypes.oneOfType([
    PropTypes.arrayOf(PropTypes.node),
    PropTypes.node,
  ]).isRequired,
};

export { PickerLocalizationProvider, usePickerLocalization };
