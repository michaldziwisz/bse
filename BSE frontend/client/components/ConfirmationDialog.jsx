import React from 'react';
import PropTypes from 'prop-types';
import {
  Button,
  Dialog,
  DialogActions,
  DialogContent,
  DialogContentText,
  DialogTitle,
} from '@material-ui/core';
import { useLocalization } from '../context/localization';

/**
 * Confirmation dialog component
 * @param {Object} props
 * @param {*} props.children - modal content
 * @param {bool} props.open - is modal opened
 * @param {function} props.onClose - modal close callback
 * @param {string} [props.title] - modal title
 * @param {string} [props.dismiss] - dismiss button label
 * @param {string} [props.confirm] - confirm button label
 * @returns React component
 */
function ConfirmationDialog({
  open,
  onClose,
  title,
  children,
  confirm,
  dismiss,
}) {
  const { translate } = useLocalization();
  const onOutsideClose = React.useCallback(e => onClose(e), [onClose]);
  const onDismiss = React.useCallback(e => onClose(e, false), [onClose]);
  const onConfirm = React.useCallback(e => onClose(e, true), [onClose]);
  return (
    <Dialog
      open={open}
      onClose={onOutsideClose}
      aria-labelledby={title && 'confirmation-dialog-title'}
      aria-describedby="confirmation-dialog-description"
    >
      {title && (
        <DialogTitle id="confirmation-dialog-title">{title}</DialogTitle>
      )}
      <DialogContent>
        <DialogContentText id="confirmation-dialog-description">{children}</DialogContentText>
      </DialogContent>
      <DialogActions>
        <Button onClick={onDismiss}>
          {dismiss || translate('common.cancel')}
        </Button>
        <Button onClick={onConfirm} color="primary" variant="contained">
          {confirm || translate('common.yes')}
        </Button>
      </DialogActions>
    </Dialog>
  );
}

ConfirmationDialog.propTypes = {
  children: PropTypes.node.isRequired,
  open: PropTypes.bool.isRequired,
  onClose: PropTypes.func.isRequired,
  title: PropTypes.string,
  dismiss: PropTypes.string,
  confirm: PropTypes.string,
};

ConfirmationDialog.defaultProps = {
  title: '',
  dismiss: '',
  confirm: '',
};

export default ConfirmationDialog;
