import api from './axios';

export const getTreatmentPlansByMember = (memberId) =>
  api.get(`/treatment-plans/admin/${memberId}`).then(r => r.data);

export const getAllTreatmentPlans = (params) =>
  api.get('/treatment-plans/admin/all', { params }).then(r => r.data);
