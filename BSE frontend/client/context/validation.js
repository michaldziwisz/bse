import React from 'react';
import { useLocalization } from './localization';
import { getValidationAgent, getBulkValidationAgent } from '../services/validation';

/** @module ContextValidation */

/**
 * Validation context hook
 * @returns {Object} Validation methods bag
 */
function useValidation() {
  const { intl } = useLocalization();
  const validateValue = React.useCallback(getValidationAgent(intl), [intl]);
  const validateValues = React.useCallback(getBulkValidationAgent(intl), [intl]);
  return { validateValues, validateValue };
}

// eslint-disable-next-line import/prefer-default-export
export { useValidation };
