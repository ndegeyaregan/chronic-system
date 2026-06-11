import api from './axios';

export const getServices = (params) => api.get('/service-prices/services', { params });
export const createService = (data) => api.post('/service-prices/services', data);

export const getServicePriceComparisons = (params) => api.get('/service-prices/compare', { params });
export const getInstitutionServicePrices = (params) => api.get('/service-prices', { params });
export const createInstitutionServicePrice = (data) => api.post('/service-prices', data);
export const updateInstitutionServicePrice = (id, data) => api.put(`/service-prices/${id}`, data);
