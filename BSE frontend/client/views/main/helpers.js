const AudioContext = window.AudioContext || window.webkitAudioContext;
const audioCtx = new AudioContext();

/** @module ViewMain */

const FREQUENCY_MID = 440.00; // A4

/**
 * Wait for N ms
 * @async
 * @param {number} delay - delay in ms
 */
export function wait(delay) {
  return new Promise(resolve => setTimeout(resolve, delay));
}

/**
 * Play audio signal using audio context oscillator
 * @async
 * @param {number} [frequency] - signal frequency in Hz
 * @param {number} [duration=200] - signal duration in ms
 * @param {number} [volume=1] - signal volume in range <0,1>
 * @param {string} [type='triangle'] - signal wave type
 */
export function playSignal(frequency = FREQUENCY_MID, duration = 200, volume = 1, type = 'triangle') {
  return new Promise((resolve, reject) => {
    const gainNode = audioCtx.createGain();
    const oscillatorNode = audioCtx.createOscillator();
    oscillatorNode.connect(gainNode);
    oscillatorNode.frequency.value = frequency;
    oscillatorNode.type = type;
    gainNode.connect(audioCtx.destination);
    gainNode.gain.setValueCurveAtTime(
      [0, volume * 0.8, volume, volume * 0.8, 0],
      audioCtx.currentTime,
      duration ? duration / 1000 : 0,
    );
    oscillatorNode.addEventListener('ended', resolve);
    oscillatorNode.addEventListener('error', reject);
    oscillatorNode.start(audioCtx.currentTime);
    oscillatorNode.stop(audioCtx.currentTime + duration / 1000);
  });
}

/**
 * Read text using speech synthesis utterance
 * @async
 * @param {string} text - text to read
 * @param {Object} [readingVoice] - voice instance
 * @param {number} [readingRate=1] - rate of reading
 * @param {number} [readingVolume=1] - reading volume in range <0,1>
 */
export function readText(text, readingVoice, readingRate = 1, readingVolume = 1) {
  return new Promise(async (resolve, reject) => {
    const utterance = new SpeechSynthesisUtterance(text);
    utterance.rate = readingRate;
    utterance.volume = readingVolume;
    utterance.voice = readingVoice ?? utterance.voice;
    utterance.onend = resolve;
    utterance.onstop = resolve;
    utterance.onerror = reject;
    const now = Date.now();
    while (speechSynthesis.paused || speechSynthesis.speaking) {
      if (Date.now() - now > 1000) {
        // eslint-disable-next-line no-console
        console.warn('SpeechSynthesis timeout:', text);
        resolve();
        return;
      }
      // eslint-disable-next-line no-await-in-loop
      await wait(50);
    }
    speechSynthesis.speak(utterance);
  });
}

/**
 * Force speechSynthesis and audio context permissions by running
 * silent audio signal and text read
 * @async
 */
export async function ensureApisEnabled() {
  await Promise.all([
    readText(0, null, 1, 0),
    playSignal(440, 100, 0),
  ]);
}

/**
 * Get course relative to target course in range <-180,180>
 * @param {number} course - currrent course
 * @param {number} targetCourse - target course
 * @returns {number} relative course
 */
export function getRelativeCourse(course, targetCourse) {
  let delta = course - targetCourse;
  while (delta <= -180) {
    delta += 360;
  }
  while (delta > 180) {
    delta -= 360;
  }
  return delta;
}

/**
 * Describe status with text to speech based on readings and settings
 * @async
 * @param {Object} settings
 * @param {string} [settings.target='none'] - target reading to use in descripting status
 * @param {number} [settings.targetCourse] - target course
 * @param {number} [settings.targetWind] - target wind
 * @param {string} [settings.readingOutput='tts'] - reading output
 * @param {number} [settings.readingRate] - reading rate in percents
 * @param {number} [settings.readingVolume=100] - reading volume in range <0, 100>
 * @param {Object} readings
 * @param {number} readings.course - current course
 * @param {number} [readings.rudder] - current rudder angle
 * @param {number} [readings.wind] - current wind angle
 * @param {Object} deps
 * @param {Object} deps.voice - voice instance
 * @param {function} deps.translate - translator function
 * @param {function} deps.setAriaText - aria text setter function
 */
export async function describeStatus({
  target = 'none',
  targetCourse,
  targetWind,
  readingOutput = 'tts',
  readingRate,
  readingVolume = 100,
}, {
  course,
  rudder,
  wind,
}, {
  setAriaText,
  translate,
  voice,
}) {
  const toRead = [];
  const currentValue = {
    none: course,
    course,
    wind,
  }[target];
  const targetValue = {
    course: targetCourse,
    wind: targetWind,
  }[target];
  if (typeof currentValue !== 'undefined') {
    toRead.push(typeof targetValue !== 'undefined'
      ? Math.round(getRelativeCourse(currentValue, targetValue))
      : Math.round(currentValue));
  } else {
    toRead.push(translate(`helm.${target === 'none' ? 'course' : target}.unknown`));
  }
  if (typeof rudder !== 'undefined') {
    const rudderText = Math.abs(Math.round(rudder));
    toRead.push(`${translate(`helm.rudder.${rudder > 0 ? 'right' : 'left'}`)} ${rudderText}`);
  }
  if (readingOutput === 'tts') {
    await readText(toRead.join(', '), voice, readingRate / 100, readingVolume / 100);
  } else if (readingOutput === 'aria') {
    setAriaText(toRead.join(', '));
  }
}

/**
 * Signalize status with audio based on readings and settings
 * @async
 * @param {Object} settings
 * @param {string} [settings.target='none'] - target reading to use in descripting status
 * @param {number} [settings.targetCourse] - target course
 * @param {number} [settings.targetWind] - target wind
 * @param {bool} [settings.referenceTone=false] - play middle tone before error tone
 * @param {bool} [settings.toneBaseOffset=4] - tone base offset from reference tone
 * @param {bool} [settings.toneOnCourse=false] - play middle tone when on course
 * @param {string} [settings.toneType='triangle'] - tone generator type
 * @param {number} [settings.toneVolume=100] - tone volume in range <0, 100>
 * @param {bool} [settings.broadTonalSpread=false] - play error tones in broader tonal spread
 * @param {number} [settings.errorThreshold=2] - error threshold in degrees
 * @param {number} [settings.errorRange=30] - error range in degrees
 * @param {Object} readings
 * @param {number} readings.course - current course
 * @param {number} [readings.wind] - current wind
 * @param {Object} lastStatus
 */
export async function signalizeStatus({
  target = 'none',
  targetCourse,
  targetWind,
  referenceTone = false,
  toneBaseOffset = 5,
  toneOnCourse = false,
  toneType = 'triangle',
  toneVolume = 100,
  broadTonalSpread = false,
  errorThreshold = 2,
  errorRange = 30,
}, {
  course,
  wind,
}, lastStatus) {
  const currentValue = {
    none: course,
    course,
    wind,
  }[target];
  const targetValue = {
    course: targetCourse,
    wind: targetWind,
  }[target];
  const onTarget = targetValue || targetValue === 0;
  if (!onTarget && !lastStatus) {
    return;
  }
  const delta = onTarget
    ? getRelativeCourse(currentValue, targetValue)
    : getRelativeCourse(currentValue, lastStatus[target === 'none' ? 'course' : target]);
  const deltaAbs = Math.abs(delta);
  const errorExceeded = deltaAbs > errorThreshold;
  if (errorExceeded || toneOnCourse || !onTarget) {
    if (errorExceeded || (!onTarget && delta)) {
      const compensatedDelta = deltaAbs - (onTarget ? errorThreshold : 0);
      const severity = compensatedDelta > errorRange ? errorRange : compensatedDelta;
      const gain = delta > 0 ? 1 : -1;
      const multiplier = broadTonalSpread ? 2 : 1;
      if (referenceTone) {
        await playSignal(FREQUENCY_MID, 80, toneVolume / 100, toneType);
        await wait(20);
      }
      const baseOffset = toneBaseOffset / 12;
      await playSignal(
        FREQUENCY_MID * (2 ** (gain * (multiplier * severity / errorRange + baseOffset))),
        100,
        toneVolume / 100,
        toneType,
      );
    } else if (toneOnCourse || !onTarget) {
      await playSignal(FREQUENCY_MID, 100, toneVolume / 100, toneType);
    }
  }
}
