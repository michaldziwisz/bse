import axiosRetry from 'axios-retry';
import createHTTPClient from './createHTTPClient';

const httpClient = createHTTPClient({
  baseURL: '/api',
});

axiosRetry(httpClient, {
  retries: 3,
  retryDelay: () => 0,
});

export default httpClient;
