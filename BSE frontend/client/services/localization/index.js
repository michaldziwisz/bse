import en from '../../locales/en';

export const locales = {
  en,
  'en-GB': en,
};
const loaders = {
  'en-US': () => import(/* webpackChunkName: "localeEnUS" */ '../../locales/enUS'),
  pl: () => import(/* webpackChunkName: "localePl" */ '../../locales/pl'),
};

export function getLocale(lang) {
  const langShort = lang.substr(0, 2);
  const loadedMessages = locales[lang];
  let promise;

  if (!loadedMessages) {
    if (loaders[lang]) {
      promise = loaders[lang]();
    } else if (loaders[langShort]) {
      promise = loaders[langShort]();
    } else {
      return Promise.reject(Error(`No such language: ${lang}`));
    }
    return promise.then((locale) => {
      const messages = locale.default;
      if (!locales[lang]) {
        locales[lang] = messages;
      }
      return messages;
    });
  }
  return Promise.resolve(loadedMessages);
}

export function getMessageById(id) {
  return { id, defaultMessage: en[id] };
}

export function translate(intl, id, val, defaultMessage) {
  let values = val;
  let messageId = id;
  if (typeof id === 'object') {
    values = id.val;
    messageId = id.id;
  }
  return intl.formatMessage(
    defaultMessage
      ? { id, defaultMessage }
      : getMessageById(messageId),
    values,
  );
}

export function getTranslationAgent(intl) {
  return (id, val, defaultMessage) => translate(intl, id, val, defaultMessage);
}

export default locales;
