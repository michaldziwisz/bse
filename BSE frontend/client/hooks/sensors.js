/* eslint-disable import/prefer-default-export */
import httpClient from '../services/httpClient';

/** @module HooksSensors */

/**
 * Get helm readings from the device
 * @async
 * @param [settings]
 * @param [settings.courseSource]
 * @param [settings.averageWindow]
 * @returns {Object} Helm readings
 */
export async function getHelmReadings({ courseSource, averageWindow } = {}) {
  const { data } = await httpClient.get('/helm', {
    params: {
      time: Date.now(),
      source: courseSource,
      window: averageWindow
        ? averageWindow * 1000
        : undefined,
    },
  });
  return data;
}

/**
 * Get NMEA 2k readings from the device
 * @async
 * @returns {Object} NMEA 2k readings
 */
export async function getNmeaReadings() {
  const { data } = await httpClient.get('/nmea');
  return data;
}


/**
 * Get internal GPS readings from the device
 * @async
 * @returns {Object} GPS readings
 */
export async function getGpsReadings() {
  const { data } = await httpClient.get('/gps');
  return data;
}
