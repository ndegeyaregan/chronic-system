import api from './axios';

export const listMembershipAuthorizations = (params) =>
  api.get('/membership-authorizations', { params });

export const issueMembershipAuthorization = (formData) =>
  api.post('/membership-authorizations', formData, {
    headers: { 'Content-Type': 'multipart/form-data' },
  });

export const deleteMembershipAuthorization = (id) =>
  api.delete(`/membership-authorizations/${id}`);
