import { getMessageById } from '../localization';

const emailRE = /^[a-z0-9.!#$%&’*+/=?^_`{|}~-]+@[a-z0-9-]+(?:\.[a-z0-9-]+)*$/i;

function isEmpty(val) {
  const type = typeof (val);
  return type === 'undefined' || val === '' || (type === 'object' && !val);
}

function required(intl, val) {
  return isEmpty(val)
    ? intl.formatMessage(getMessageById('validation.required'))
    : undefined;
}

function string(intl, val) {
  return !isEmpty(val) && typeof (val) !== 'string'
    ? intl.formatMessage(getMessageById('validation.string'))
    : undefined;
}

function minLength(intl, val, { min }) {
  return !isEmpty(val)
    ? string(intl, val) || (val.length < min && intl.formatMessage(getMessageById('validation.minLength'), { min }))
    : undefined;
}

function maxLength(intl, val, { max }) {
  return !isEmpty(val)
    ? string(intl, val) || (val.length > max && intl.formatMessage(getMessageById('validation.maxLength'), { max }))
    : undefined;
}

function exactLength(intl, val, { length }) {
  return !isEmpty(val)
    ? string(intl, val) || (val.length !== length && intl.formatMessage(getMessageById('validation.length'), { length }))
    : undefined;
}

function email(intl, val) {
  return !isEmpty(val)
    ? string(intl, val) || (!emailRE.test(val) && intl.formatMessage(getMessageById('validation.email')))
    : undefined;
}

function isEnum(intl, val, { values }) {
  return !isEmpty(val)
    ? !values.includes(val) && intl.formatMessage(getMessageById('validation.enum'), { values })
    : undefined;
}

function number(intl, val) {
  const type = typeof (val);
  const numericVal = +val;
  // eslint-disable-next-line no-self-compare
  return !isEmpty(val) && type !== 'number' && (type !== 'string' || (numericVal !== numericVal)) // checking for NaN
    ? intl.formatMessage(getMessageById('validation.number'))
    : undefined;
}

function minValue(intl, val, { min }) {
  return !isEmpty(val)
    ? number(intl, val) || (val < min && intl.formatMessage(getMessageById('validation.min'), { min }))
    : undefined;
}

function maxValue(intl, val, { max }) {
  return !isEmpty(val)
    ? number(intl, val) || (val > max && intl.formatMessage(getMessageById('validation.max'), { max }))
    : undefined;
}

function bool(intl, val) {
  return !isEmpty(val)
    ? typeof val !== 'boolean' && intl.formatMessage(getMessageById('validation.boolean'))
    : undefined;
}

export const validators = {
  required,
  enum: isEnum,
  // string checks
  string,
  minLength,
  maxLength,
  length: exactLength,
  email,
  // numeric checks
  number,
  min: minValue,
  max: maxValue,
  // boolean
  boolean: bool,
};

export function validateValue(intl, val, options) {
  let validator;
  return options.reduce((err, validation) => {
    if (err) {
      return err;
    } if (typeof (validation) === 'string') {
      return validators[validation](intl, val);
    } if (typeof (validation) === 'object') {
      const { type, ...props } = validation;
      validator = validators[type];
      if (validator) {
        return validator(intl, val, props);
      }
      throw Error(`No such validation type: ${type}`);
    } else {
      throw Error(`No such validation type: ${validation}`);
    }
  }, undefined);
}

export function validateValues(intl, values, fieldsOptions) {
  const errors = {};
  Object.keys(fieldsOptions).forEach((key) => {
    const error = validateValue(intl, values[key], fieldsOptions[key]);
    if (error) {
      errors[key] = error;
    }
  });
  return errors;
}

export function getValidationAgent(intl) {
  return (val, options) => validateValue(intl, val, options);
}

export function getBulkValidationAgent(intl) {
  return (values, fieldsOptions) => validateValues(intl, values, fieldsOptions);
}
