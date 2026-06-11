import api from './axios';

export const listReimbursements = (params) =>
  api.get('/reimbursements', { params }).then((r) => r.data);

export const updateReimbursementStatus = (id, payload) =>
  api.patch(`/reimbursements/${id}/status`, payload).then((r) => r.data);
