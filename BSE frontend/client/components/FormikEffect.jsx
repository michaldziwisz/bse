import React from 'react';
import PropTypes from 'prop-types';
import { useDebouncedEffect } from '../utils/useDebounced';

// Formik does not provide onChange event and does so on purpose
// because "some people will be using it wrong".
// Stick in your eye for this, Jared Palmer :/

/**
 * Component adding onChange event workaround to formik instances
 * @param {Object} props
 * @param {Object} props.values - formik values
 * @param {bool} props.isValid - formik isValid
 * @param {function} [props.onChange] - change callback
 * @param {function} [props.onValidChange] - valid change callback
 * @returns React component
 */
function FormikEffect({
  values,
  isValid,
  onChange,
  onValidChange,
}) {
  const [currentValues, setCurrentValues] = React.useState(null);

  // debounce is workaround of formik inconsistent state updates (isValid with invalid values)
  useDebouncedEffect(() => {
    if (currentValues && currentValues !== values) {
      if (onChange) {
        onChange(values);
      }
      if (isValid && onValidChange) {
        onValidChange(values);
      }
      setCurrentValues(values);
    } else if (!currentValues) {
      setCurrentValues(values);
    }
  }, [values, isValid, currentValues, onChange, onValidChange], 10);

  return null;
}

FormikEffect.propTypes = {
  values: PropTypes.shape({}).isRequired,
  isValid: PropTypes.bool.isRequired,
  onChange: PropTypes.func,
  onValidChange: PropTypes.func,
};

FormikEffect.defaultProps = {
  onChange: null,
  onValidChange: null,
};

export default FormikEffect;
