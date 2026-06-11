import api from './axios';

// Get all institutions (hospitals & pharmacies from Sanlam + user-added)
export const getInstitutions = (params) => api.get('/institutions', { params });
export const getInstitutionById = (id) => api.get(`/institutions/${id}`);
export const createInstitution = (data) => {
  // data may be a plain object or already a FormData (when files are included)
  if (data instanceof FormData) {
    return api.post('/institutions', data, { headers: { 'Content-Type': 'multipart/form-data' } });
  }
  return api.post('/institutions', data);
};
export const updateInstitution = (id, data) => api.put(`/institutions/${id}`, data);
export const suspendInstitution = (id, reason) => api.post(`/institutions/${id}/suspend`, { reason });
export const unsuspendInstitution = (id) => api.post(`/institutions/${id}/unsuspend`);
export const deleteInstitution = (id) => api.delete(`/institutions/${id}`);
export const getInstitutionPriceLists = (params) => api.get('/institutions/price-lists', { params });
export const getInstitutionCopays = () => api.get('/institutions/copays');
export const syncInstitutionCopays = () => api.post('/institutions/copays/sync');

export const createInstitutionPriceList = (data) => {
  const formData = new FormData();
  formData.append('institutionId', data.institutionId);
  if (data.notes) formData.append('notes', data.notes);
  formData.append('priceList', data.file);
  return api.post('/institutions/price-lists', formData, {
    headers: { 'Content-Type': 'multipart/form-data' },
  });
};

export const updateInstitutionPriceList = (id, data) => {
  const formData = new FormData();
  formData.append('institutionId', data.institutionId);
  if (data.notes !== undefined) formData.append('notes', data.notes);
  if (data.file) formData.append('priceList', data.file);
  return api.put(`/institutions/price-lists/${id}`, formData, {
    headers: { 'Content-Type': 'multipart/form-data' },
  });
};

// Legacy endpoints (kept for backward compatibility)
export const getHospitals = (params) => api.get('/hospitals', { params });
export const getHospitalById = (id) => api.get(`/hospitals/${id}`);
export const createHospital = (data) => api.post('/hospitals', data);
export const updateHospital = (id, data) => api.put(`/hospitals/${id}`, data);
export const deleteHospital = (id) => api.delete(`/hospitals/${id}`);
