import React from 'react';
import PropTypes from 'prop-types';
import clsx from 'clsx';
import FormControl from '@material-ui/core/FormControl';
import FormHelperText from '@material-ui/core/FormHelperText';
import InputLabel from '@material-ui/core/InputLabel';
import MenuItem from '@material-ui/core/MenuItem';
import Select from '@material-ui/core/Select';

/**
 * Adapter between formik library and material-ui Select.
 * Passes through all usual props of material-ui Select
 * @param {Object} props
 * @param {Object} props.field - formik field object
 * @param {Object} props.form - formik form object
 * @param {bool} [props.disabled=false]
 * @param {string} [props.label]
 * @param {string} [props.info] - helper text
 * @param {Object[]} props.items
 * @param {Component|function} [props.itemComponent] - component for item rendering
 * @returns React component
 */
function SelectAdapter({
  id,
  disabled,
  field, field: { name, value },
  form: { touched, errors },
  info, label,
  items, itemComponent,
  className, classes,
  variant,
  margin,
  size,
  ...custom
}) {
  const labelRef = React.useRef();
  const labelWidth = labelRef.current ? labelRef.current.clientWidth : 0;

  const dirty = touched[name];
  const error = dirty && errors[name];

  return (
    <FormControl
      className={clsx(className, classes && classes.root)}
      variant={variant}
      margin={margin}
      size={size}
      disabled={disabled}
    >
      <InputLabel
        className={clsx(classes && classes.label)}
        error={!!error}
        ref={labelRef}
        valriant={variant}
        shrink
      >
        {label}
      </InputLabel>
      <Select
        SelectDisplayProps={{
          'aria-label': label,
          'aria-describedby': `select-${name}-helper-text`,
        }}
        className={clsx(classes && classes.select)}
        labelWidth={labelWidth}
        value={value || ''}
        error={!!error}
        {...field}
        {...custom}
      >
        {items && items.map(itemComponent || (item => (
          <MenuItem
            key={item.value}
            className={clsx(classes && classes.item)}
            value={item.value}
          >
            {item.name ?? item.value}
          </MenuItem>
        )))}
      </Select>
      <FormHelperText
        id={`select-${name}-helper-text`}
        error={!!error}
        className={clsx(classes && classes.helper)}
      >
        {error || info}
      </FormHelperText>
    </FormControl>
  );
}
SelectAdapter.propTypes = {
  id: PropTypes.string,
  disabled: PropTypes.bool,
  label: PropTypes.string,
  info: PropTypes.string,
  items: PropTypes.arrayOf(PropTypes.shape({
    name: PropTypes.oneOfType([
      PropTypes.number,
      PropTypes.string,
    ]),
    value: PropTypes.oneOfType([
      PropTypes.number,
      PropTypes.string,
    ]).isRequired,
  })).isRequired,
  itemComponent: PropTypes.func,
  className: PropTypes.string,
  classes: PropTypes.shape({
    root: PropTypes.string,
    label: PropTypes.string,
    select: PropTypes.string,
    helper: PropTypes.string,
    item: PropTypes.string,
  }),
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
SelectAdapter.defaultProps = {
  id: null,
  disabled: false,
  label: null,
  info: null,
  className: null,
  classes: null,
  margin: 'none',
  variant: 'outlined',
  size: 'small',
  itemComponent: null,
};

export default SelectAdapter;
