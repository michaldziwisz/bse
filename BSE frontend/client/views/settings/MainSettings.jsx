import React, { Fragment } from 'react';
import PropTypes from 'prop-types';
import clsx from 'clsx';
import { Typography, makeStyles } from '@material-ui/core';
import {
  Formik,
  Form,
  Field,
} from 'formik';
import { useLocalization } from '../../context/localization';
import { useValidation } from '../../context/validation';
import { useVoices } from '../../context/voices';
import {
  validationSchema,
  courseSources,
  readingOutputs,
  toneTypes,
  useSettings,
} from '../../context/settings';
import FormikEffect from '../../components/FormikEffect';
import Checkbox from '../../components/Checkbox';
import TextField from '../../components/TextField';
import Select from '../../components/Select';
import { layoutVertical } from '../../mixins';

/** @module ViewSettings */

const useStyles = makeStyles(theme => ({
  root: {
    ...layoutVertical,
    '& > *': {
      margin: theme.spacing(1, 0, 0.5, 0),
    },
  },
  header: {
    margin: theme.spacing(1, 0, 1, 0),
    textAlign: 'center',
  },
}));

/**
 * Main settings form component
 * @returns React component
 */
function MainSettings(props) {
  const { validateValues } = useValidation();
  const { translate } = useLocalization();
  const voices = useVoices();
  const classes = useStyles();

  const [settings, setSettings] = useSettings();
  const [initialValues] = React.useState(settings);

  const validate = React.useCallback(
    values => validateValues(values, validationSchema),
    [validateValues],
  );
  const updateSettings = React.useCallback(
    values => setSettings(values),
    [setSettings],
  );

  const sourceItems = React.useMemo(
    () => courseSources.map(t => ({ ...t, name: translate(t.translation) })),
    [translate],
  );
  const outputItems = React.useMemo(
    () => readingOutputs.map(t => ({ ...t, name: translate(t.translation) })),
    [translate],
  );
  const toneItems = React.useMemo(
    () => toneTypes.map(t => ({ ...t, name: translate(t.translation) })),
    [translate],
  );

  return (
    <Formik initialValues={initialValues} validate={validate}>
      {({ values, isValid }) => (
        <Form {...props} className={clsx(classes.root, props.className)}>
          <FormikEffect values={values} isValid={isValid} onValidChange={updateSettings} />
          <Typography component="h1" variant="h3" className={classes.header}>
            {translate('settings.title')}
          </Typography>
          <Typography component="h2" variant="h4" className={classes.header}>
            {translate('settings.reading')}
          </Typography>
          <Field
            name="readingOutput"
            label={translate('settings.readingOutput')}
            component={Select}
            items={outputItems}
          />
          {values.readingOutput === 'aria' && (
            <Field
              name="readingInterval"
              label={translate('settings.readingInterval')}
              component={TextField}
              InputProps={{
                type: 'number',
                inputProps: {
                  min: 1,
                  max: 45,
                },
              }}
            />
          )}
          {values.readingOutput !== 'aria' && (
            <Fragment>
              <Field
                name="readingVolume"
                label={translate('settings.readingVolume')}
                component={TextField}
                InputProps={{
                  type: 'number',
                  inputProps: {
                    step: 1,
                    min: 0,
                    max: 100,
                  },
                }}
              />
              <Field
                name="readingDelay"
                label={translate('settings.readingDelay')}
                component={TextField}
                InputProps={{
                  type: 'number',
                  inputProps: {
                    min: 0,
                    max: 30,
                  },
                }}
              />
            </Fragment>
          )}
          {values.readingOutput === 'tts' && (
            <Fragment>
              <Field
                name="readingRate"
                label={translate('settings.readingRate')}
                component={TextField}
                InputProps={{
                  type: 'number',
                  inputProps: {
                    step: 10,
                    min: 50,
                    max: 400,
                  },
                }}
              />
              {!!voices?.available?.length && (
                <Field
                  name="readingVoice"
                  label={translate('settings.readingVoice')}
                  component={Select}
                  items={voices?.available ?? []}
                  value={values.readingVoice ?? ''}
                />
              )}
            </Fragment>
          )}
          <Typography component="h2" variant="h4" className={classes.header}>
            {translate('settings.soundSignals')}
          </Typography>
          <Field
            name="soundSignalsEnabled"
            label={translate('settings.soundSignalsEnabled')}
            component={Checkbox}
            color="primary"
          />
          <Field
            name="toneVolume"
            label={translate('settings.toneVolume')}
            component={TextField}
            InputProps={{
              type: 'number',
              inputProps: {
                step: 1,
                min: 0,
                max: 100,
              },
            }}
          />
          <Field
            name="toneDelay"
            label={translate('settings.toneDelay')}
            component={TextField}
            InputProps={{
              type: 'number',
              inputProps: {
                step: 0.1,
                min: 0.5,
                max: 5,
              },
            }}
          />
          <Field
            name="toneType"
            label={translate('settings.toneType')}
            component={Select}
            items={toneItems}
          />
          <Typography component="h2" variant="h4" className={classes.header}>
            {translate('settings.auxilary')}
          </Typography>
          <Field
            name="invertRudderAngle"
            label={translate('settings.invertRudderAngle')}
            component={Checkbox}
            color="primary"
          />
          <Field
            name="rudderAngleCorrection"
            label={translate('settings.rudderAngleCorrection')}
            component={TextField}
            InputProps={{
              type: 'number',
              inputProps: {
                step: 0.1,
                min: -90,
                max: 90,
              },
            }}
          />
          <Typography component="h1" variant="h3" className={classes.header}>
            {translate('settings.advanced')}
          </Typography>
          <Typography component="h2" variant="h4" className={classes.header}>
            {translate('settings.course')}
          </Typography>
          <Field
            name="courseSource"
            label={translate('settings.courseSource')}
            component={Select}
            items={sourceItems}
          />
          <Field
            name="averageWindow"
            label={translate('settings.averageWindow')}
            component={TextField}
            InputProps={{
              type: 'number',
              inputProps: {
                step: 1,
                min: 1,
                max: 5,
              },
            }}
          />
          <Typography component="h2" variant="h4" className={classes.header}>
            {translate('settings.soundSignals')}
          </Typography>
          <Field
            name="errorThreshold"
            label={translate('settings.errorThreshold')}
            component={TextField}
            InputProps={{
              type: 'number',
              inputProps: {
                step: 0.1,
                min: 1,
                max: 15,
              },
            }}
          />
          <Field
            name="errorRange"
            label={translate('settings.errorRange')}
            component={TextField}
            InputProps={{
              type: 'number',
              inputProps: {
                min: 15,
                max: 60,
              },
            }}
          />
          {values.readingOutput !== 'aria' && (
            <Field
              name="avoidSignalsOverlap"
              label={translate('settings.avoidSignalsOverlap')}
              component={Checkbox}
              color="primary"
            />
          )}
          <Field
            name="referenceTone"
            label={translate('settings.referenceTone')}
            component={Checkbox}
            color="primary"
          />
          <Field
            name="toneOnCourse"
            label={translate('settings.toneOnCourse')}
            component={Checkbox}
            color="primary"
          />
          <Field
            name="broadTonalSpread"
            label={translate('settings.broadTonalSpread')}
            component={Checkbox}
            color="primary"
          />
          <Field
            name="toneBaseOffset"
            label={translate('settings.toneBaseOffset')}
            component={TextField}
            InputProps={{
              type: 'number',
              inputProps: {
                step: 1,
                min: 0,
                max: 6,
              },
            }}
          />
        </Form>
      )}
    </Formik>
  );
}

MainSettings.propTypes = {
  className: PropTypes.string,
};

MainSettings.defaultProps = {
  className: null,
};

export default MainSettings;
