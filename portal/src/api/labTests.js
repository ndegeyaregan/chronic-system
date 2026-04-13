import api from './axios';

export const getLabTestsByMember = (memberId) =>
  api.get(`/lab-tests/admin/${memberId}`).then((r) => r.data);

export const getAdminLabTests = (params) =>
  api.get('/lab-tests/admin/all', { params }).then((r) => r.data);

export const getLabTestStats = () =>
  api.get('/lab-tests/admin/stats').then((r) => r.data);

export const scheduleLabTest = (data) =>
  api.post('/lab-tests', data).then((r) => r.data);

export const adminCompleteLabTest = (id, formData) =>
  api.patch(`/lab-tests/admin/${id}/complete`, formData, {
    headers: { 'Content-Type': 'multipart/form-data' },
  }).then((r) => r.data);
