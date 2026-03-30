import React from 'react';
import constate from 'constate';
/** @module ContextSettings */

export const defaultSettings = {
  averageWindow: 3,
  avoidSignalsOverlap: false,
  courseSource: 'cgfa',
  readingDelay: 3,
  readingInterval: 5,
  readingOutput: /iPad|iPhone|iPod/.test(navigator.userAgent) ? 'aria' : 'tts',
  readingRate: 150,
  readingVoice: null,
  readingVolume: 100,
  soundSignalsEnabled: true,
  toneDelay: 1,
  referenceTone: true,
  toneBaseOffset: 2,
  toneOnCourse: true,
  toneType: 'triangle',
  toneVolume: 25,
  broadTonalSpread: false,
  target: 'none',
  targetCourse: null,
  errorThreshold: 1,
  errorRange: 30,
  invertRudderAngle: false,
  rudderAngleCorrection: 0,
};

export const courseSources = ['cgfa', 'coga', 'hdga', 'cgf', 'cog', 'hdg'].map(value => ({
  value, translation: `settings.courseSource.${value}`,
}));
export const availableTargets = ['none', 'course'].map(value => ({
  value, translation: `settings.target.${value}`,
}));
export const toneTypes = ['sine', 'triangle', 'sawtooth', 'square'].map(value => ({
  value, translation: `settings.toneType.${value}`,
}));
export const readingOutputs = ['tts', 'aria'].map(value => ({
  value, translation: `settings.readingOutput.${value}`,
}));

export const validationSchema = {
  averageWindow: ['required', 'number', { type: 'min', min: 1 }, { type: 'max', max: 5 }],
  avoidSignalsOverlap: ['boolean'],
  courseSource: ['required', 'string', { type: 'enum', values: courseSources.map(v => v.value) }],
  soundSignalsEnabled: ['boolean'],
  referenceTone: ['boolean'],
  toneBaseOffset: ['required', 'number', { type: 'min', min: 0 }, { type: 'max', max: 6 }],
  toneOnCourse: ['boolean'],
  toneType: ['required', 'string', { type: 'enum', values: toneTypes.map(v => v.value) }],
  toneVolume: ['required', 'number', { type: 'min', min: 0 }, { type: 'max', max: 100 }],
  broadTonalSpread: ['boolean'],
  toneDelay: ['required', 'number', { type: 'min', min: 0.5 }, { type: 'max', max: 5 }],
  readingDelay: ['required', 'number', { type: 'min', min: 0 }, { type: 'max', max: 30 }],
  readingInterval: ['required', 'number', { type: 'min', min: 1 }, { type: 'max', max: 45 }],
  readingOutput: ['required', 'string', { type: 'enum', values: readingOutputs.map(v => v.value) }],
  readingRate: ['required', 'number', { type: 'min', min: 50 }, { type: 'max', max: 400 }],
  readingVoice: ['string'],
  readingVolume: ['required', 'number', { type: 'min', min: 0 }, { type: 'max', max: 100 }],
  target: ['required', 'string', { type: 'enum', values: availableTargets.map(v => v.value) }],
  targetCourse: ['number', { type: 'min', min: 0 }, { type: 'max', max: 360 }],
  errorThreshold: ['required', 'number', { type: 'min', min: 1 }, { type: 'max', max: 15 }],
  errorRange: ['required', 'number', { type: 'min', min: 15 }, { type: 'max', max: 60 }],
  invertRudderAngle: ['boolean'],
  rudderAngleCorrection: ['required', 'number', { type: 'min', min: -90 }, { type: 'max', max: 90 }]
};

let storedSettings;
try {
  storedSettings = localStorage.settings
    ? JSON.parse(localStorage.settings)
    : {};
} catch (err) {
  storedSettings = {};
}

/**
 * Stored settings hook
 * @returns {[Object, function]} Stored settings and setter
 */
function useSettingsHook() {
  const [settings, setSettings] = React.useState({
    ...defaultSettings,
    ...storedSettings,
  });

  const saveSettings = React.useCallback((newSettings) => {
    localStorage.settings = JSON.stringify(newSettings);
    setSettings(newSettings);
  }, []);

  return [settings, saveSettings];
}

/**
 * Provider component for settings context
 * @method SettingsProvider
 * @param {Object} props
 * @param {*} props.children
 * @returns React component
 */
export const [SettingsProvider, useSettings] = constate(useSettingsHook);
