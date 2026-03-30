/* eslint-disable react-hooks/exhaustive-deps */
import {
  useCallback,
  useEffect,
  useRef,
} from 'react';

export function useDebouncedCallback(callback, dependencies, delay, disableDiscardOnUnload) {
  const timeout = useRef(null);
  const internalCallback = useRef(null);
  useEffect(() => (() => { // wrap on unmount
    if (timeout.current && !disableDiscardOnUnload) {
      clearTimeout(timeout.current);
    }
  }), [disableDiscardOnUnload, timeout]);
  const cb = useCallback((...args) => {
    if (timeout.current) {
      clearTimeout(timeout.current);
    }
    internalCallback.current = () => {
      timeout.current = null;
      callback(...args);
    };
    timeout.current = setTimeout(internalCallback.current, delay);
  }, dependencies);
  const flush = useCallback(() => {
    if (timeout.current) {
      clearTimeout(timeout.current);
      timeout.current = null;
      internalCallback.current();
    }
  }, [timeout]);
  const discard = useCallback(() => {
    if (timeout.current) {
      clearTimeout(timeout.current);
      timeout.current = null;
    }
  }, [timeout]);
  return [cb, discard, flush];
}

export function useDebouncedEffect(effect, dependencies, delay, disableDiscardOnUnmount) {
  const timeout = useRef(null);
  const callback = useRef(null);
  useEffect(() => (() => { // wrap on unmount
    if (timeout.current && !disableDiscardOnUnmount) {
      clearTimeout(timeout.current);
    }
  }), [disableDiscardOnUnmount, timeout]);
  useEffect((...args) => {
    if (timeout.current) {
      clearTimeout(timeout.current);
    }
    callback.current = () => {
      timeout.current = null;
      effect(...args);
    };
    timeout.current = setTimeout(callback.current, delay);
  }, dependencies);
  const flush = useCallback(() => {
    if (timeout.current) {
      clearTimeout(timeout.current);
      timeout.current = null;
      callback.current();
    }
  }, [timeout]);
  const discard = useCallback(() => {
    if (timeout.current) {
      clearTimeout(timeout.current);
      timeout.current = null;
    }
  }, [timeout]);
  return [discard, flush];
}
