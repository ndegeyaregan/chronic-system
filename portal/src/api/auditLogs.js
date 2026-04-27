import api from './axios';

export const getAuditLogs = (params) => api.get('/audit-logs', { params }).then(r => r.data);
export const getMemberAuditLogs = (memberId) => api.get(`/audit-logs/member/${memberId}`).then(r => r.data);
