import api from './axios';

export const getMemberProvider = (memberId) =>
  api.get(`/members/${memberId}/provider`).then(r => r.data);
