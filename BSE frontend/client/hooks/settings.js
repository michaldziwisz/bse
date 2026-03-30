/* eslint-disable import/prefer-default-export */
import httpClient from '../services/httpClient';

/** @module HooksSettings */

/**
 * Set device settings
 * @async
 * @param {Object} params
 * @param {number} params.beta - IMU filter beta
 * @returns Server response
 */
export async function setSettings(params) {
  const { data } = await httpClient.get('/set', { params });
  return data;
}

/**
 * Run IMU calibration on the device
 * @async
 * @returns Server response
 */
export async function runCalibration() {
  const { data } = await httpClient.get('/calibrate');
  return data;
}

/**
 * Force reboot of the device
 * @async
 * @returns Server response
 */
export async function runReboot() {
  const { data } = await httpClient.get('/reboot');
  return data;
}
