import api from './axios';

export const getMedicationOverview = () => api.get('/medications/admin/overview');
export const getMedicationCatalogue = (params) => api.get('/medications', { params });
export const createMedication = (data) => api.post('/medications', data);
export const updateMedication = (id, data) => api.put(`/medications/${id}`, data);
export const assignMedicationToMember = (data) => api.post('/medications/admin/assign', data, {
  headers: data instanceof FormData ? { 'Content-Type': 'multipart/form-data' } : undefined,
});
export const stopAssignment = (id, data) => api.put(`/medications/assignment/${id}/stop`, data);
export const updateAssignmentRefill = (id, data) => api.patch(`/medications/assignment/${id}/refill`, data);
export const getAssignmentDoseLogs = (id) => api.get(`/medications/admin/assignment/${id}/logs`);
export const adminUpdateAssignment = (id, data) => api.put(`/medications/assignment/${id}`, data);
