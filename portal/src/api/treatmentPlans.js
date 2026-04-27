import api from './axios';

export const getTreatmentPlansByMember = (memberId) =>
  api.get(`/treatment-plans/admin/${memberId}`).then(r => r.data);

export const getAllTreatmentPlans = (params) =>
  api.get('/treatment-plans/admin/all', { params }).then(r => r.data);

export const createTreatmentPlan = (data) =>
  api.post('/treatment-plans', data, {
    headers: { 'Content-Type': 'multipart/form-data' },
  }).then(r => r.data);

export const adminCreateTreatmentPlan = (data) =>
  api.post('/treatment-plans/admin', data, {
    headers: { 'Content-Type': 'multipart/form-data' },
  }).then(r => r.data);

export const updateTreatmentPlan = (id, data) =>
  api.put(`/treatment-plans/${id}`, data, {
    headers: { 'Content-Type': 'multipart/form-data' },
  }).then(r => r.data);

export const adminUpdateTreatmentPlan = (id, data) =>
  api.put(`/treatment-plans/admin/${id}`, data, {
    headers: { 'Content-Type': 'multipart/form-data' },
  }).then(r => r.data);
