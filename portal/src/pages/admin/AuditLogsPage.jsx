import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import {
  DocumentMagnifyingGlassIcon,
  ClockIcon,
  UsersIcon,
  RectangleStackIcon,
  ChevronLeftIcon,
  ChevronRightIcon,
} from '@heroicons/react/24/outline';
import { getAuditLogs } from '../../api/auditLogs';
import Table from '../../components/UI/Table';
import Modal from '../../components/UI/Modal';
import Button from '../../components/UI/Button';
import Spinner from '../../components/UI/Spinner';

const ENTITY_OPTIONS = [
  { value: '', label: 'All Entities' },
  { value: 'member', label: 'Member' },
  { value: 'appointment', label: 'Appointment' },
  { value: 'medication', label: 'Medication' },
  { value: 'treatment_plan', label: 'Treatment Plan' },
  { value: 'authorization', label: 'Authorization' },
  { value: 'care_buddy', label: 'Care Buddy' },
  { value: 'admin', label: 'Admin' },
  { value: 'content', label: 'Content' },
  { value: 'lab_test', label: 'Lab Test' },
  { value: 'condition', label: 'Condition' },
  { value: 'hospital', label: 'Hospital' },
  { value: 'pharmacy', label: 'Pharmacy' },
  { value: 'scheme', label: 'Scheme' },
];

const ACTION_OPTIONS = [
  { value: '', label: 'All Actions' },
  { value: 'create', label: 'Create' },
  { value: 'update', label: 'Update' },
  { value: 'delete', label: 'Delete' },
  { value: 'login', label: 'Login' },
  { value: 'status_change', label: 'Status Change' },
  { value: 'approve', label: 'Approve' },
  { value: 'reject', label: 'Reject' },
  { value: 'export', label: 'Export' },
  { value: 'upload', label: 'Upload' },
];

const fmtTimestamp = (d) =>
  new Date(d).toLocaleString('en-GB', {
    day: '2-digit', month: 'short', year: 'numeric',
    hour: '2-digit', minute: '2-digit', second: '2-digit',
  });

const actionColor = (action) => {
  const map = {
    create: { background: '#d1fae5', color: '#065f46' },
    update: { background: '#dbeafe', color: '#1e40af' },
    delete: { background: '#fee2e2', color: '#991b1b' },
    login: { background: '#fef3c7', color: '#92400e' },
    status_change: { background: '#e0f2fe', color: '#0369a1' },
    approve: { background: '#d1fae5', color: '#065f46' },
    reject: { background: '#fee2e2', color: '#991b1b' },
  };
  return map[action?.toLowerCase()] || { background: '#f1f5f9', color: '#64748b' };
};

export default function AuditLogsPage() {
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState('');
  const [entityFilter, setEntityFilter] = useState('');
  const [actionFilter, setActionFilter] = useState('');
  const [dateFrom, setDateFrom] = useState('');
  const [dateTo, setDateTo] = useState('');
  const [detailsModal, setDetailsModal] = useState(null);

  const params = {
    page,
    limit: 25,
    ...(search && { actor_name: search }),
    ...(entityFilter && { entity: entityFilter }),
    ...(actionFilter && { action: actionFilter }),
    ...(dateFrom && { start_date: dateFrom }),
    ...(dateTo && { end_date: dateTo }),
  };

  const { data, isLoading } = useQuery({
    queryKey: ['audit-logs', params],
    queryFn: () => getAuditLogs(params),
    placeholderData: (prev) => prev,
  });

  const logs = data?.logs || [];
  const total = data?.total || 0;
  const pages = data?.pages || 1;

  // Derive stats from current data
  const todayStr = new Date().toISOString().split('T')[0];
  const todayCount = logs.filter((l) => l.created_at?.startsWith(todayStr)).length;
  const uniqueActors = new Set(logs.map((l) => l.actor_id)).size;
  const entityCounts = {};
  logs.forEach((l) => { entityCounts[l.entity] = (entityCounts[l.entity] || 0) + 1; });
  const topEntity = Object.entries(entityCounts).sort((a, b) => b[1] - a[1])[0];

  const inputStyle = {
    padding: '8px 12px', borderRadius: '6px', border: '1px solid #e2e8f0',
    fontSize: '14px', color: 'var(--text)', background: '#fff', outline: 'none',
    boxSizing: 'border-box',
  };

  const columns = [
    {
      key: 'created_at',
      header: 'Timestamp',
      render: (val) => (
        <span style={{ fontSize: '13px', whiteSpace: 'nowrap' }}>
          {val ? fmtTimestamp(val) : '—'}
        </span>
      ),
    },
    {
      key: 'actor_name',
      header: 'Actor',
      render: (val, row) => (
        <div>
          <div style={{ fontWeight: 500 }}>{val || '—'}</div>
          <div style={{ fontSize: '11px', color: '#94a3b8' }}>{row.actor_type}</div>
        </div>
      ),
    },
    {
      key: 'action',
      header: 'Action',
      render: (val) => {
        const style = actionColor(val);
        return (
          <span style={{
            ...style, padding: '2px 10px', borderRadius: '999px',
            fontSize: '12px', fontWeight: 600, display: 'inline-block',
            textTransform: 'capitalize', whiteSpace: 'nowrap',
          }}>
            {val || '—'}
          </span>
        );
      },
    },
    { key: 'entity', header: 'Entity', render: (val) => (
      <span style={{ textTransform: 'capitalize' }}>{val?.replace(/_/g, ' ') || '—'}</span>
    )},
    { key: 'entity_id', header: 'Entity ID', render: (val) => (
      <span style={{ fontSize: '12px', fontFamily: 'monospace', color: '#64748b' }}>
        {val ? val.substring(0, 8) + '…' : '—'}
      </span>
    )},
    { key: 'ip_address', header: 'IP Address', render: (val) => (
      <span style={{ fontSize: '13px', fontFamily: 'monospace' }}>{val || '—'}</span>
    )},
    {
      key: 'details',
      header: 'Details',
      render: (val, row) => (
        val ? (
          <Button variant="secondary" onClick={() => setDetailsModal(row)}
            style={{ fontSize: '12px', padding: '4px 10px' }}>
            View
          </Button>
        ) : <span style={{ color: '#94a3b8' }}>—</span>
      ),
    },
  ];

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
      {/* Header */}
      <div>
        <h1 style={{ fontSize: '22px', fontWeight: 700, color: '#0f172a', margin: 0 }}>
          Audit Logs
        </h1>
        <p style={{ margin: '4px 0 0', fontSize: '14px', color: '#64748b' }}>
          Track all admin actions across the system
        </p>
      </div>

      {/* Stat Cards */}
      <div style={{ display: 'flex', gap: '14px', flexWrap: 'wrap' }}>
        {[
          { label: 'Total Logs', value: total, color: '#3b82f6', Icon: DocumentMagnifyingGlassIcon },
          { label: 'Actions Today', value: todayCount, color: '#10b981', Icon: ClockIcon },
          { label: 'Unique Actors', value: uniqueActors, color: '#8b5cf6', Icon: UsersIcon },
          { label: 'Most Active Entity', value: topEntity ? topEntity[0]?.replace(/_/g, ' ') : '—', color: '#f97316', Icon: RectangleStackIcon },
        ].map((s) => (
          <div key={s.label} style={{
            background: '#fff', borderRadius: '12px', border: '1px solid #e2e8f0',
            padding: '16px 20px', flex: 1, minWidth: 160,
            borderTop: `3px solid ${s.color}`,
          }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '6px' }}>
              <s.Icon style={{ width: 16, height: 16, color: s.color }} />
              <span style={{ fontSize: '12px', color: '#94a3b8', fontWeight: 500 }}>{s.label}</span>
            </div>
            <div style={{ fontSize: '28px', fontWeight: 800, color: '#0f172a', lineHeight: 1, textTransform: 'capitalize' }}>
              {s.value ?? '—'}
            </div>
          </div>
        ))}
      </div>

      {/* Filter Bar */}
      <div style={{
        background: '#fff', borderRadius: '12px', padding: '16px 20px',
        boxShadow: '0 1px 4px rgba(0,0,0,0.07)', border: '1px solid #e2e8f0',
        display: 'flex', gap: '12px', flexWrap: 'wrap', alignItems: 'flex-end',
      }}>
        <div style={{ display: 'flex', flexDirection: 'column', gap: '4px', flex: '1 1 180px' }}>
          <label style={{ fontSize: '13px', fontWeight: 500, color: '#475569' }}>Search Actor</label>
          <input
            type="text"
            placeholder="Actor name…"
            value={search}
            onChange={(e) => { setSearch(e.target.value); setPage(1); }}
            style={inputStyle}
          />
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: '4px', flex: '1 1 160px' }}>
          <label style={{ fontSize: '13px', fontWeight: 500, color: '#475569' }}>Entity</label>
          <select
            value={entityFilter}
            onChange={(e) => { setEntityFilter(e.target.value); setPage(1); }}
            style={{ ...inputStyle, cursor: 'pointer' }}
          >
            {ENTITY_OPTIONS.map((o) => <option key={o.value} value={o.value}>{o.label}</option>)}
          </select>
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: '4px', flex: '1 1 140px' }}>
          <label style={{ fontSize: '13px', fontWeight: 500, color: '#475569' }}>Action</label>
          <select
            value={actionFilter}
            onChange={(e) => { setActionFilter(e.target.value); setPage(1); }}
            style={{ ...inputStyle, cursor: 'pointer' }}
          >
            {ACTION_OPTIONS.map((o) => <option key={o.value} value={o.value}>{o.label}</option>)}
          </select>
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: '4px' }}>
          <label style={{ fontSize: '13px', fontWeight: 500, color: '#475569' }}>From</label>
          <input type="date" value={dateFrom}
            onChange={(e) => { setDateFrom(e.target.value); setPage(1); }}
            style={inputStyle} />
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: '4px' }}>
          <label style={{ fontSize: '13px', fontWeight: 500, color: '#475569' }}>To</label>
          <input type="date" value={dateTo}
            onChange={(e) => { setDateTo(e.target.value); setPage(1); }}
            style={inputStyle} />
        </div>
      </div>

      {/* Table */}
      <div style={{
        background: '#fff', borderRadius: '12px',
        boxShadow: '0 1px 4px rgba(0,0,0,0.07)', border: '1px solid #e2e8f0',
        overflow: 'hidden',
      }}>
        {isLoading ? (
          <Spinner />
        ) : (
          <>
            <Table columns={columns} data={logs} emptyMessage="No audit logs found." />

            {/* Pagination */}
            {pages > 1 && (
              <div style={{
                display: 'flex', alignItems: 'center', justifyContent: 'space-between',
                padding: '12px 20px', borderTop: '1px solid #f1f5f9',
              }}>
                <span style={{ fontSize: '13px', color: '#64748b' }}>
                  Page {page} of {pages} · {total} total
                </span>
                <div style={{ display: 'flex', gap: '6px' }}>
                  <Button variant="secondary" onClick={() => setPage((p) => Math.max(1, p - 1))}
                    disabled={page <= 1} style={{ padding: '6px 10px' }}>
                    <ChevronLeftIcon style={{ width: 16, height: 16 }} />
                  </Button>
                  <Button variant="secondary" onClick={() => setPage((p) => Math.min(pages, p + 1))}
                    disabled={page >= pages} style={{ padding: '6px 10px' }}>
                    <ChevronRightIcon style={{ width: 16, height: 16 }} />
                  </Button>
                </div>
              </div>
            )}
          </>
        )}
      </div>

      {/* Details Modal */}
      {detailsModal && (
        <Modal title="Log Details" onClose={() => setDetailsModal(null)} width="640px">
          <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
            <div style={{
              background: '#f8fafc', borderRadius: '8px', padding: '12px 16px',
              fontSize: '13px', color: '#475569', lineHeight: 1.7,
            }}>
              <div><strong>Actor:</strong> {detailsModal.actor_name} ({detailsModal.actor_type})</div>
              <div><strong>Action:</strong> {detailsModal.action}</div>
              <div><strong>Entity:</strong> {detailsModal.entity} · {detailsModal.entity_id}</div>
              <div><strong>IP:</strong> {detailsModal.ip_address || '—'}</div>
              <div><strong>Time:</strong> {fmtTimestamp(detailsModal.created_at)}</div>
            </div>
            <div>
              <label style={{ fontSize: '13px', fontWeight: 500, color: '#475569', marginBottom: '6px', display: 'block' }}>
                Details (JSON)
              </label>
              <pre style={{
                background: '#0f172a', color: '#e2e8f0', borderRadius: '8px',
                padding: '16px', fontSize: '12px', overflow: 'auto',
                maxHeight: '320px', lineHeight: 1.6, margin: 0,
              }}>
                {JSON.stringify(detailsModal.details, null, 2)}
              </pre>
            </div>
          </div>
        </Modal>
      )}
    </div>
  );
}
