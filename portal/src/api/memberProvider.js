import api from './axios';

export const getMemberProvider = (memberId) =>
  api.get(`/members/${memberId}/provider`).then(r => r.data);

export const updateMemberProvider = (memberId, data) =>
  api.put(`/members/${memberId}/provider`, data).then(r => r.data);

export const assignMemberProvider = (memberId, data) =>
  api.post(`/members/${memberId}/provider`, data).then(r => r.data);
