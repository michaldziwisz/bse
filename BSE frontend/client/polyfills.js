/* eslint-disable no-extend-native */

if (!String.prototype.startsWith) {
  Object.defineProperty(String.prototype, 'startsWith', {
    value(search, rawPos) {
      // eslint-disable-next-line no-bitwise
      const pos = rawPos > 0 ? rawPos | 0 : 0;
      return this.substring(pos, pos + search.length) === search;
    },
  });
}
