import api from './axios';

export const listCardReprints = (params) =>
  api.get('/card-reprints', { params }).then((r) => r.data);

export const updateCardReprintStatus = (id, payload) =>
  api.patch(`/card-reprints/${id}/status`, payload).then((r) => r.data);
