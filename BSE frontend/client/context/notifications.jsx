import React from 'react';
import PropTypes from 'prop-types';
import constate from 'constate';
import { SnackbarProvider, useSnackbar } from 'notistack';
import httpClient from '../services/httpClient';
import { useLocalization } from './localization';
import { mapErrorToMessage } from '../utils/httpErrorMapping';

/** @module ContextNotifications */

/**
 * Notifications context hook
 * @returns {Object} Notification methods bag
 */
function useNotificationsHook() {
  const { enqueueSnackbar } = useSnackbar();
  const { agent } = useLocalization();

  const showNotification = React.useCallback(({ message, variant, options }) => {
    enqueueSnackbar(agent.translate(message), {
      preventDuplicate: true,
      variant,
      'data-test-id': 'Notification',
      'data-test-value': variant,
      ...options,
    });
  }, [agent, enqueueSnackbar]);

  const showSuccess = React.useCallback((message = '', options = {}) => {
    const variant = 'success';
    showNotification({ message, variant, options });
  }, [showNotification]);

  const showInfo = React.useCallback((message = '', options = {}) => {
    const variant = 'info';
    showNotification({ message, variant, options });
  }, [showNotification]);

  const showWarning = React.useCallback((message = '', options = {}) => {
    const variant = 'warning';
    showNotification({ message, variant, options });
  }, [showNotification]);

  const showError = React.useCallback((message = '', options = {}) => {
    const variant = 'error';
    showNotification({ message, variant, options });
  }, [showNotification]);

  const showApiError = React.useCallback(error => showError(mapErrorToMessage(error)), [showError]);

  React.useEffect(() => { // attach interceptor to show API errors as default preventable behavior
    httpClient.interceptors.response.use(null, (err) => {
      const timeout = setTimeout(() => showApiError(err), 1);
      // eslint-disable-next-line no-param-reassign
      err.defaultPrevented = false;
      // eslint-disable-next-line no-param-reassign
      err.preventDefault = () => {
        // eslint-disable-next-line no-param-reassign
        err.defaultPrevented = true;
        clearTimeout(timeout);
      };
      return Promise.reject(err);
    });
  }, [showApiError]);

  return {
    showSuccess,
    showInfo,
    showWarning,
    showError,
    showApiError,
    showNotification,
  };
}

const [InternalProvider, useNotifications] = constate(useNotificationsHook);

/**
 * Provider component for notifications context
 * @param {Object} props
 * @param {*} props.children
 * @returns React component
 */
function NotificationsProvider({ children }) {
  return (
    <SnackbarProvider>
      <InternalProvider>
        {children}
      </InternalProvider>
    </SnackbarProvider>
  );
}
NotificationsProvider.propTypes = {
  children: PropTypes.oneOfType([
    PropTypes.arrayOf(PropTypes.node),
    PropTypes.node,
  ]).isRequired,
};

export { NotificationsProvider, useNotifications };
