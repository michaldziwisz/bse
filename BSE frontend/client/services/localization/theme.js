import { createMuiTheme } from '@material-ui/core';
import {
  enUS,
  plPL,
} from '@material-ui/core/locale';
import themes from '../../themes';

export const locales = {
  en: enUS,
  'en-GB': enUS,
  'en-US': enUS,
  pl: plPL,
};

export function getLocale(lang) {
  const langShort = lang.substr(0, 2);
  const loadedLocale = locales[lang] || locales[langShort];

  if (!loadedLocale) {
    return Promise.reject(Error(`No such MUI locale: ${lang}`));
  }
  return Promise.resolve(loadedLocale);
}

export function getLocalizedTheme(locale, name = 'main') {
  if (!themes[name]) {
    throw Error(`No such theme: ${name}`);
  }
  return createMuiTheme(themes[name], locale);
}
