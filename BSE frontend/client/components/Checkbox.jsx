import React from 'react';
import PropTypes from 'prop-types';
import FormControlLabel from '@material-ui/core/FormControlLabel';
import Checkbox from '@material-ui/core/Checkbox';

/**
 * Adapter between formik library and material-ui Checkbox
 * @param {Object} props
 * @param {Object} props.field - formik field object
 * @param {Object} props.form - formik form object
 * @param {bool} [props.disabled=false]
 * @param {string} [props.label]
 * @returns React component
 */
function CheckboxAdapter({
  disabled,
  field, field: { name, value },
  form: { setFieldValue },
  label,
  className,
  ...custom
}) {
  const onValueChange = React.useCallback(
    (e, v) => setFieldValue(name, v),
    [name, setFieldValue],
  );
  return (
    <FormControlLabel
      control={(
        <Checkbox
          disabled={disabled}
          checked={value || false}
          onChange={onValueChange}
          {...custom}
        />
      )}
      label={label}
      disabled={disabled}
      className={className}
    />
  );
}
CheckboxAdapter.propTypes = {
  disabled: PropTypes.bool,
  label: PropTypes.string,
  className: PropTypes.string,
  // passed from Field
  field: PropTypes.shape({
    name: PropTypes.string.isRequired,
    value: PropTypes.bool.isRequired,
  }).isRequired,
  form: PropTypes.shape({
    setFieldValue: PropTypes.func.isRequired,
  }).isRequired,
};
CheckboxAdapter.defaultProps = {
  disabled: false,
  label: null,
  className: null,
};

export default CheckboxAdapter;
