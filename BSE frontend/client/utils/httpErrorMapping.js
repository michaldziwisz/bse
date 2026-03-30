const httpErrorMapping = {
  400: 'error.validationError',
  401: 'error.unauthorized',
  403: 'error.notAllowed',
  404: 'error.notFound',
  500: 'error.internalServerError',
  502: 'error.serviceUnavailable',
  503: 'error.serviceUnavailable',
};

export function mapErrorToMessage(error) {
  const { response } = error;
  if (!response) {
    return httpErrorMapping[503];
  }
  const { status } = response;
  const { message, data } = response.data || {};
  return {
    id: message || httpErrorMapping[status] || 'error.unknownError',
    val: data || {},
  };
}

export default httpErrorMapping;
