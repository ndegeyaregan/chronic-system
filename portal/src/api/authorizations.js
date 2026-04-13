import api from './axios';

export const getAdminAuthorizations = (params) =>
  api.get('/authorizations/admin/all', { params });

export const getAuthorizationStats = () =>
  api.get('/authorizations/admin/stats');

export const reviewAuthorization = (id, data) =>
  api.patch(`/authorizations/admin/${id}/review`, data);

export const getFacilityEmail = (id) =>
  api.get(`/authorizations/admin/${id}/facility-email`);

export const sendAuthorizationEmail = (id, data) =>
  api.post(`/authorizations/admin/${id}/send-auth-email`, data);
