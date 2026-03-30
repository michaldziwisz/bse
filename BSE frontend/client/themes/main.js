import green from '@material-ui/core/colors/green';
import red from '@material-ui/core/colors/red';

export default {
  spacing: factor => (factor === 'auto' ? factor : `${0.5 * factor}em`),
  typography: {
    useNextVariants: true,
  },
  palette: {
    type: 'dark',
    secondary: { main: red[500] },
    success: { main: green[500] },
  },
};
