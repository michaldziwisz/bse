import React from 'react';
import ReactDOM from 'react-dom';
import { BrowserRouter as Router } from 'react-router-dom';
import { HelmetProvider } from 'react-helmet-async';
import { ReactQueryCacheProvider, QueryCache } from 'react-query';
import { LocalizationProvider } from './context/localization';
import { PickerLocalizationProvider } from './context/pickers';
import { LocalizedThemeProvider } from './context/theme';
import { NotificationsProvider } from './context/notifications';
import { VoicesProvider } from './context/voices';
import { SettingsProvider } from './context/settings';
import App from './App';
import './polyfills';
import './index.css';

const queryCache = new QueryCache({
  defaultConfig: {
    queries: {
      refetchOnWindowFocus: false,
      retry: false,
    },
  },
});

// create store and render app
ReactDOM.render((
  <ReactQueryCacheProvider queryCache={queryCache}>
    <LocalizationProvider>
      <PickerLocalizationProvider>
        <LocalizedThemeProvider>
          <NotificationsProvider>
            <VoicesProvider>
              <SettingsProvider>
                <HelmetProvider>
                  <Router>
                    <App />
                  </Router>
                </HelmetProvider>
              </SettingsProvider>
            </VoicesProvider>
          </NotificationsProvider>
        </LocalizedThemeProvider>
      </PickerLocalizationProvider>
    </LocalizationProvider>
  </ReactQueryCacheProvider>
), document.querySelector('#app'));
