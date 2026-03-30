import axios from 'axios';
import getRequestInterceptors from './requestInterceptors';
import getResponseInterceptors from './responseInterceptors';

/*
 * INITIALIZE
 */

export default function createHTTPClient(axiosConfig) {
  const instance = axios.create();
  const requestInterceptors = getRequestInterceptors();
  const responseInterceptors = getResponseInterceptors();

  // Configure axios
  Object.entries(axiosConfig).forEach(([key, value]) => {
    instance.defaults[key] = value;
  });

  // Initialize interceptors
  if (requestInterceptors && requestInterceptors.length) {
    requestInterceptors.forEach(({ onFulfilled, onRejected }) => {
      instance.interceptors.request.use(onFulfilled, onRejected);
    });
  }

  if (responseInterceptors && responseInterceptors.length) {
    responseInterceptors.forEach(({ onFulfilled, onRejected }) => {
      instance.interceptors.response.use(onFulfilled, onRejected);
    });
  }

  return instance;
}
