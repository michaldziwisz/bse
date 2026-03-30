import { enGB } from 'date-fns/locale';

export const locales = {
  en: enGB,
  'en-GB': enGB,
};
const loaders = {
  'en-US': () => import(/* webpackChunkName: "pickersEnUS" */ 'date-fns/locale/en-US'),
  pl: () => import(/* webpackChunkName: "pickersPl" */ 'date-fns/locale/pl'),
};

export function getLocale(lang) {
  const langShort = lang.substr(0, 2);
  const loadedLocale = locales[lang] || locales[langShort];
  let promise;

  if (!loadedLocale) {
    if (loaders[lang]) {
      promise = loaders[lang]();
    } else if (loaders[langShort]) {
      promise = loaders[langShort]();
    } else {
      return Promise.reject(Error(`No such picker locale: ${lang}`));
    }
    return promise.then((chunk) => {
      const locale = chunk.default;
      if (!locales[lang]) {
        locales[lang] = locale;
      }
      return locale;
    });
  }
  return Promise.resolve(loadedLocale);
}
