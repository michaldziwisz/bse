import React from 'react';
import PropTypes from 'prop-types';
import TextField from '@material-ui/core/TextField';

/**
 * Adapter between formik library and material-ui TextField.
 * Passes through all usual props of material-ui TextField
 * @param {Object} props
 * @param {Object} props.field - formik field object
 * @param {Object} props.form - formik form object
 * @param {bool} [props.disabled=false]
 * @param {string} [props.label]
 * @param {string} [props.info] - helper text
 * @returns React component
 */
function TextFieldAdapter({
  field,
  field: { name, value },
  form: { touched, errors },
  id,
  className,
  info,
  margin,
  variant,
  size,
  ...custom
}) {
  const error = errors[name];
  const dirty = touched[name];
  return (
    <TextField
      {...field}
      id={id || `text-${name}`}
      value={value ?? ''}
      error={dirty && !!error}
      helperText={(dirty && error) || info}
      margin={margin || 'dense'}
      variant={variant || 'outlined'}
      size={size || 'small'}
      className={className}
      {...custom}
    />
  );
}
TextFieldAdapter.propTypes = {
  id: PropTypes.string,
  info: PropTypes.string,
  className: PropTypes.string,
  margin: PropTypes.string,
  variant: PropTypes.string,
  size: PropTypes.string,
  // passed from Field
  field: PropTypes.shape({
    name: PropTypes.string.isRequired,
    value: PropTypes.oneOfType([
      PropTypes.string,
      PropTypes.number,
    ]),
  }).isRequired,
  form: PropTypes.shape({
    touched: PropTypes.shape({}).isRequired,
    errors: PropTypes.shape({}).isRequired,
  }).isRequired,
};
TextFieldAdapter.defaultProps = {
  id: null,
  info: null,
  className: null,
  margin: 'none',
  variant: 'outlined',
  size: 'small',
};

export default TextFieldAdapter;
