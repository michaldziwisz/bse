import React from 'react';
import constate from 'constate';
/** @module ContextVoices */

/**
 * Text to speech available voices hook
 * @returns {Object} Available voices bag
 */
function useVoicesHook() {
  const [voices, setVoices] = React.useState(null);

  React.useEffect(() => {
    function getVoices() {
      const systemVoices = speechSynthesis.getVoices();
      const defaultVoice = systemVoices.find(v => v.default)?.voiceURI;
      const availableVoices = systemVoices.filter(v => v.localService).map(voice => ({
        name: voice.name,
        value: voice.voiceURI,
        instance: voice,
      }));
      setVoices({
        available: availableVoices,
        default: defaultVoice,
      });
    }
    if (!speechSynthesis.getVoices().length) {
      speechSynthesis.addEventListener('voiceschanged', getVoices);
    } else {
      getVoices();
    }
  }, []);

  return voices;
}

/**
 * Provider component for voices context
 * @method VoicesProvider
 * @param {Object} props
 * @param {*} props.children
 * @returns React component
 */
export const [VoicesProvider, useVoices] = constate(useVoicesHook);
