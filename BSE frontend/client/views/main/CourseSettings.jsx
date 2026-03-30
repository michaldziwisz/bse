import React, { Fragment } from 'react';
import PropTypes from 'prop-types';
import clsx from 'clsx';
import {
  Button,
  makeStyles,
} from '@material-ui/core';
import {
  Formik,
  Form,
  Field,
} from 'formik';
import { useLocalization } from '../../context/localization';
import { useValidation } from '../../context/validation';
import { validationSchema, availableTargets } from '../../context/settings';
import FormikEffect from '../../components/FormikEffect';
import TextField from '../../components/TextField';
import Select from '../../components/Select';
import { layoutVertical } from '../../mixins';

/** @module ViewMain */

const useStyles = makeStyles(theme => ({
  root: {
    ...layoutVertical,
    '& > *': {
      margin: theme.spacing(1, 0, 0.5, 0),
    },
  },
  button: {
    margin: theme.spacing(1, 0, 1, 0),
    width: '100%',
  },
}));

/**
 * Course settings form component
 * @param {Object} props
 * @param {Object} props.settings - current settings
 * @param {number} props.course - current course
 * @param {function} props.onSettingsChange - settings change callback
 * @returns React component
 */
function CourseSettings({
  settings,
  course = null,
  onSettingsChange,
  ...other
}) {
  const { validateValues } = useValidation();
  const { translate } = useLocalization();
  const classes = useStyles();

  const [initialValues] = React.useState(settings);

  const validate = React.useCallback(
    values => validateValues(values, validationSchema),
    [validateValues],
  );
  const updateSettings = React.useCallback(
    values => onSettingsChange(values),
    [onSettingsChange],
  );
  const holdCourse = React.useCallback(
    setFieldValue => setFieldValue('targetCourse', Math.round(course)),
    [course],
  );

  const targetItems = React.useMemo(
    () => availableTargets.map(t => ({ ...t, name: translate(t.translation) })),
    [translate],
  );

  return (
    <Formik initialValues={initialValues} validate={validate}>
      {({ values, isValid, setFieldValue }) => (
        <Form {...other} className={clsx(classes.root, other.className)}>
          <FormikEffect values={values} isValid={isValid} onValidChange={updateSettings} />
          {values.target === 'course' && (
            <Fragment>
              <Button
                variant="contained"
                onClick={() => holdCourse(setFieldValue)}
                disabled={course === null}
                className={classes.button}
              >
                {translate('settings.action.holdCourse', {
                  course: (course ? Math.round(course) : 0).toString().padStart(3, '0'),
                })}
              </Button>
              <Field
                name="targetCourse"
                label={translate('settings.target.course.label')}
                component={TextField}
                InputProps={{
                  type: 'number',
                  inputProps: {
                    min: 0,
                    max: 360,
                  },
                }}
              />
            </Fragment>
          )}
          <Field
            name="target"
            label={translate('settings.target')}
            component={Select}
            items={targetItems}
          />
        </Form>
      )}
    </Formik>
  );
}

CourseSettings.propTypes = {
  settings: PropTypes.shape({}).isRequired,
  course: PropTypes.number,
  onSettingsChange: PropTypes.func.isRequired,
};

CourseSettings.defaultProps = {
  course: null,
};

export default CourseSettings;
