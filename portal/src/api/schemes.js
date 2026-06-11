import api from './axios';

export const getSchemes = (params) => api.get('/schemes', { params });
export const createScheme = (data) => api.post('/schemes', data);
export const updateScheme = (id, data) => api.put(`/schemes/${id}`, data);
export const deleteScheme = (id) => api.delete(`/schemes/${id}`);
export const hardDeleteScheme = (id) => api.delete(`/schemes/${id}/hard`);
export const bulkImportSchemes = (schemes) => api.post('/schemes/bulk-import', { schemes });
