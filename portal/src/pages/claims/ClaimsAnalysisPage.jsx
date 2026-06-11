import { useEffect, useMemo, useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import toast from 'react-hot-toast';
import {
  ArrowUpTrayIcon,
  DocumentArrowDownIcon,
  TableCellsIcon,
  ChartBarIcon,
  TrashIcon,
  CheckCircleIcon,
  ExclamationTriangleIcon,
} from '@heroicons/react/24/outline';
import Button from '../../components/UI/Button';
import Spinner from '../../components/UI/Spinner';
import { useAuth } from '../../context/AuthContext';
import {
  uploadClaimsFile, listClaimsUploads, getClaimsUploadPreview, deleteClaimsUpload,
} from '../../api/claimsAnalysis';
import ClaimsAnalyticsDashboard from './ClaimsAnalyticsDashboard';

const card = {
  background: '#fff',
  borderRadius: '12px',
  padding: '18px 20px',
  boxShadow: '0 1px 4px rgba(0,0,0,0.07)',
};

const fmtNum = (v) => Number(v ?? 0).toLocaleString();
const fmtMB  = (b) => (Number(b ?? 0) / 1024 / 1024).toFixed(1) + ' MB';
const fmtMoney = (v) => Number(v ?? 0).toLocaleString('en-UG', { maximumFractionDigits: 0 });
const fmtDate = (v) => v ? new Date(v).toLocaleString('en-ZA', { day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' }) : '—';

const FIELD_LABEL = {
  claim_date:    'Claim date',
  provider:      'Provider / institution',
  provider_type: 'Provider type',
  scheme:        'Scheme (Corporate)',
  member_name:   'Member name',
  member_no:     'Member number',
  diagnosis:     'Diagnosis',
  amount:        'Amount (ProCharges)',
};

const STATUS_BADGE = {
  processing: { bg: '#fef3c7', color: '#92400e', label: 'Processing' },
  ready:      { bg: '#dcfce7', color: '#166534', label: 'Ready' },
  failed:     { bg: '#fee2e2', color: '#b91c1c', label: 'Failed' },
};

export default function ClaimsAnalysisPage() {
  const qc = useQueryClient();
  const { user, isSuperAdmin } = useAuth();
  const superAdmin = !!isSuperAdmin;
  const [selectedIds, setSelectedIds] = useState([]); // Array of IDs for multi-upload analysis
  const [progress, setProgress] = useState(0);

  // Ticks every 30s so the "5-minute" gate updates without a manual refresh
  const [, setNowTick] = useState(0);
  useEffect(() => {
    const id = setInterval(() => setNowTick((t) => t + 1), 30 * 1000);
    return () => clearInterval(id);
  }, []);

  /* ── Uploads list ── */
  const { data: uploads = [], isLoading: loadingUploads } = useQuery({
    queryKey: ['claims-uploads'],
    queryFn: () => listClaimsUploads().then((r) => (Array.isArray(r.data) ? r.data : [])),
    refetchInterval: (data) => (Array.isArray(data) && data.some((u) => u.status === 'processing')) ? 3000 : false,
  });

  // Auto-select all ready uploads for combined analysis
  // For regular users, this is automatic. For admins, they can override.
  useEffect(() => {
    const readyIds = uploads
      .filter((u) => u.status === 'ready')
      .map((u) => u.id);
    
    if (readyIds.length > 0 && selectedIds.length === 0) {
      setSelectedIds(readyIds);
    }
  }, [uploads, selectedIds.length]);

  const selected = useMemo(
    () => uploads.find((u) => u.id === selectedIds?.[0]) || null,
    [uploads, selectedIds]
  );

  /* ── Preview for the selected upload ── */
  const { data: preview = [] } = useQuery({
    queryKey: ['claims-upload-preview', selectedIds?.[0]],
    queryFn: () => getClaimsUploadPreview(selectedIds?.[0], 25).then((r) => (Array.isArray(r.data) ? r.data : [])),
    enabled: !!selectedIds?.[0] && selected?.status === 'ready',
  });

  /* ── Upload mutation ── */
  const uploadMutation = useMutation({
    mutationFn: (file) => uploadClaimsFile(file, setProgress),
    onSuccess: (res) => {
      setProgress(0);
      toast.success(`Parsed ${fmtNum(res.data.row_count)} rows`);
      qc.invalidateQueries({ queryKey: ['claims-uploads'] });
      // Don't manually change selection; auto-select will handle it
    },
    onError: (err) => {
      setProgress(0);
      toast.error(err?.response?.data?.message || err.message || 'Upload failed');
    },
  });

  const deleteMutation = useMutation({
    mutationFn: deleteClaimsUpload,
    onSuccess: () => {
      toast.success('Upload deleted');
      qc.invalidateQueries({ queryKey: ['claims-uploads'] });
      // selectedIds will auto-update as uploads list changes
    },
    onError: () => toast.error('Delete failed'),
  });

  const handleFile = (e) => {
    const file = e.target.files?.[0];
    if (!file) return;
    if (file.size > 250 * 1024 * 1024) {
      toast.error('File is larger than 250 MB');
      e.target.value = '';
      return;
    }
    uploadMutation.mutate(file);
    e.target.value = '';
  };

  const isUploading = uploadMutation.isPending;

  // Show the upload-inspection panels (detected columns, mapping, preview)
  // only for ~5 minutes after the upload was created. After that the page
  // shows just the analytics dashboard so the focus is on insights.
  const showUploadInspection = useMemo(() => {
    if (!selected?.created_at) return false;
    const ageMs = Date.now() - new Date(selected.created_at).getTime();
    return ageMs <= 5 * 60 * 1000;
  }, [selected]);

  /* ── Detected field mapping panel ── */
  const fieldMapping = useMemo(() => {
    if (!preview.length) return null;
    const sample = preview[0] || {};
    return Object.keys(FIELD_LABEL).map((k) => ({
      key: k,
      label: FIELD_LABEL[k],
      sample: sample[k] ?? null,
      filled: preview.filter((r) => r[k] !== null && r[k] !== undefined && r[k] !== '').length,
      total: preview.length,
    }));
  }, [preview]);

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
      {/* ── Header ── */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: '12px', flexWrap: 'wrap' }}>
        <div>
          <h2 style={{ margin: 0, fontSize: '22px', fontWeight: 700, color: '#0f172a' }}>Claims Analysis</h2>
          <p style={{ margin: '4px 0 0', fontSize: '14px', color: '#475569' }}>
            {superAdmin
              ? 'Upload a claims Excel and explore provider, scheme, diagnosis and visit-time analytics.'
              : 'Explore provider, scheme, diagnosis and visit-time analytics on uploaded claims data.'}
          </p>
        </div>
        {/* Dataset switcher (admin only, for manual override of auto-selection) */}
        {superAdmin && uploads.filter((u) => u.status === 'ready').length > 1 && (
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <label style={{ fontSize: 12, color: '#475569', fontWeight: 600 }}>Override dataset</label>
            <select
              value={selectedIds?.[0] || ''}
              onChange={(e) => setSelectedIds(e.target.value ? [e.target.value] : [])}
              style={{
                padding: '7px 12px', borderRadius: 8, border: '1px solid #cbd5e1',
                background: '#fff', color: '#0f172a', fontSize: 13, minWidth: 240,
              }}
            >
              <option value="">All ready uploads (default)</option>
              {uploads.filter((u) => u.status === 'ready').map((u) => (
                <option key={u.id} value={u.id}>
                  {u.filename} — {fmtNum(u.row_count)} rows
                </option>
              ))}
            </select>
          </div>
        )}
      </div>

      {/* ── Upload card (super admin only) ── */}
      {superAdmin && (
      <div style={{ ...card, display: 'flex', flexDirection: 'column', gap: '12px' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '12px', flexWrap: 'wrap' }}>
          <label style={{
            display: 'inline-flex', alignItems: 'center', gap: '8px',
            padding: '10px 16px', borderRadius: '8px',
            cursor: isUploading ? 'wait' : 'pointer',
            background: 'var(--primary, #0ea5e9)', color: '#fff', fontSize: '14px', fontWeight: 600,
            opacity: isUploading ? 0.7 : 1,
          }}>
            <ArrowUpTrayIcon style={{ width: 16, height: 16 }} />
            {isUploading
              ? (progress < 100 ? `Uploading ${progress}%…` : 'Parsing on server…')
              : 'Upload claims Excel (.xlsx / .xls / .csv, up to 250 MB)'}
            <input
              type="file"
              accept=".xlsx,.xls,.csv"
              onChange={handleFile}
              disabled={isUploading}
              style={{ display: 'none' }}
            />
          </label>
          {isUploading && progress < 100 && (
            <div style={{ flex: 1, minWidth: 200, height: 8, background: '#f1f5f9', borderRadius: 999, overflow: 'hidden' }}>
              <div style={{ width: `${progress}%`, height: '100%', background: 'var(--primary, #0ea5e9)', transition: 'width 0.2s' }} />
            </div>
          )}
        </div>
        <div style={{
          padding: '12px 14px', background: '#f0f9ff', borderRadius: '8px',
          fontSize: '12px', color: '#075985', lineHeight: 1.55,
        }}>
          <strong>Detected columns:</strong> the server maps <code>ProCharges</code> → amount and <code>Corporate</code> → scheme,
          plus typical names for date, provider, provider type, member and diagnosis. Anything else is preserved per-row for ad-hoc analysis.
        </div>
      </div>
      )}

      {/* ── Uploads list (super admin only) ── */}
      {superAdmin && (
      <div style={card}>
        <h3 style={{ margin: '0 0 12px', fontSize: '16px', fontWeight: 700, color: '#0f172a' }}>Uploaded files</h3>
        {loadingUploads ? (
          <div style={{ padding: '20px', display: 'flex', justifyContent: 'center' }}><Spinner /></div>
        ) : uploads.length === 0 ? (
          <div style={{ padding: '24px', textAlign: 'center', color: '#94a3b8', fontSize: '13px' }}>
            No uploads yet — upload your first claims Excel above.
          </div>
        ) : (
          <div style={{ overflowX: 'auto' }}>
            <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '13px' }}>
              <thead>
                <tr style={{ background: '#f8fafc', borderBottom: '2px solid #e2e8f0' }}>
                  {['', 'File', 'Size', 'Rows', 'Total amount', 'Status', 'Uploaded', ''].map((h, i) => (
                    <th key={i} style={{ padding: '8px 12px', textAlign: 'left',
                      fontSize: '11px', color: '#64748b', textTransform: 'uppercase', letterSpacing: '0.04em' }}>
                      {h}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {uploads.map((u) => {
                  const s = STATUS_BADGE[u.status] || STATUS_BADGE.processing;
                  const isSelected = selectedIds.includes(u.id);
                  return (
                    <tr key={u.id} style={{
                      borderBottom: '1px solid #f1f5f9',
                      background: isSelected ? '#eff6ff' : 'transparent',
                    }}>
                      <td style={{ padding: '8px 12px' }}>
                        <input type="radio" name="upload" checked={isSelected}
                          onChange={() => setSelectedIds([u.id])}
                          disabled={u.status !== 'ready'}
                          style={{ cursor: u.status === 'ready' ? 'pointer' : 'not-allowed' }} />
                      </td>
                      <td style={{ padding: '8px 12px', fontWeight: 600, color: '#0f172a',
                        maxWidth: 320, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}
                        title={u.filename}>
                        {u.filename}
                      </td>
                      <td style={{ padding: '8px 12px', color: '#475569' }}>{fmtMB(u.size_bytes)}</td>
                      <td style={{ padding: '8px 12px', color: '#475569' }}>{fmtNum(u.row_count)}</td>
                      <td style={{ padding: '8px 12px', color: '#475569' }}>UGX {fmtMoney(u.total_amount)}</td>
                      <td style={{ padding: '8px 12px' }}>
                        <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4,
                          padding: '2px 8px', borderRadius: '10px',
                          background: s.bg, color: s.color, fontSize: '11px', fontWeight: 600 }}>
                          {u.status === 'ready' && <CheckCircleIcon style={{ width: 11, height: 11 }} />}
                          {u.status === 'failed' && <ExclamationTriangleIcon style={{ width: 11, height: 11 }} />}
                          {s.label}
                        </span>
                        {u.status === 'failed' && u.error && (
                          <div style={{ fontSize: '11px', color: '#b91c1c', marginTop: 2, maxWidth: 280 }}
                            title={u.error}>
                            {u.error.length > 60 ? u.error.slice(0, 60) + '…' : u.error}
                          </div>
                        )}
                      </td>
                      <td style={{ padding: '8px 12px', color: '#64748b', fontSize: '12px' }}>{fmtDate(u.created_at)}</td>
                      <td style={{ padding: '8px 12px' }}>
                        <button
                          onClick={() => { if (window.confirm(`Delete "${u.filename}"?`)) deleteMutation.mutate(u.id); }}
                          style={{ background: 'none', border: 'none', color: '#ef4444', cursor: 'pointer', padding: 4 }}
                          title="Delete">
                          <TrashIcon style={{ width: 14, height: 14 }} />
                        </button>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>
      )}

      {/* ── Detected columns from selected upload (super admin, first 5 minutes only) ── */}
      {superAdmin && showUploadInspection &&
        selected?.status === 'ready' && Array.isArray(selected.columns) && selected.columns.length > 0 && (
        <div style={card}>
          <h3 style={{ margin: '0 0 12px', fontSize: '16px', fontWeight: 700, color: '#0f172a',
            display: 'flex', alignItems: 'center', gap: 8 }}>
            <TableCellsIcon style={{ width: 18, height: 18, color: 'var(--primary, #0ea5e9)' }} />
            Detected columns in <span style={{ color: '#475569', fontWeight: 500 }}>{selected.filename}</span>
            <span style={{ marginLeft: 'auto', fontSize: '12px', color: '#94a3b8', fontWeight: 400 }}>
              {selected.columns.length} columns · {fmtNum(selected.row_count)} rows
            </span>
          </h3>
          <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
            {selected.columns.map((c, i) => (
              <span key={i} style={{
                padding: '4px 10px', borderRadius: 999, background: '#f1f5f9',
                color: '#334155', fontSize: '12px', fontWeight: 500,
              }}>{c}</span>
            ))}
          </div>
        </div>
      )}

      {/* ── Field mapping panel (super admin, first 5 minutes only) ── */}
      {superAdmin && showUploadInspection && fieldMapping && (
        <div style={card}>
          <h3 style={{ margin: '0 0 12px', fontSize: '16px', fontWeight: 700, color: '#0f172a',
            display: 'flex', alignItems: 'center', gap: 8 }}>
            <ChartBarIcon style={{ width: 18, height: 18, color: 'var(--primary, #0ea5e9)' }} />
            Field mapping (server inferred)
          </h3>
          <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '13px' }}>
            <thead>
              <tr style={{ background: '#f8fafc', borderBottom: '2px solid #e2e8f0' }}>
                {['Logical field', 'Filled in preview', 'Sample value'].map((h) => (
                  <th key={h} style={{ padding: '8px 12px', textAlign: 'left',
                    fontSize: '11px', color: '#64748b', textTransform: 'uppercase', letterSpacing: '0.04em' }}>
                    {h}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {fieldMapping.map((f) => {
                const filledOk = f.filled > 0;
                return (
                  <tr key={f.key} style={{ borderBottom: '1px solid #f1f5f9' }}>
                    <td style={{ padding: '8px 12px', fontWeight: 600, color: '#0f172a' }}>{f.label}</td>
                    <td style={{ padding: '8px 12px', color: filledOk ? '#15803d' : '#b91c1c', fontWeight: 600 }}>
                      {f.filled}/{f.total}
                    </td>
                    <td style={{ padding: '8px 12px', color: '#475569',
                      maxWidth: 380, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}
                      title={String(f.sample ?? '')}>
                      {f.sample === null || f.sample === '' ? <em style={{ color: '#cbd5e1' }}>—</em> : String(f.sample)}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
          <p style={{ marginTop: 10, fontSize: '12px', color: '#64748b' }}>
            If any field shows <strong style={{ color: '#b91c1c' }}>0/{preview.length}</strong>, the column name in the Excel
            isn't in the server's recognised list yet — tell me the exact header and we'll add it.
          </p>
        </div>
      )}

      {/* ── Row preview (super admin, first 5 minutes only) ── */}
      {superAdmin && showUploadInspection && preview.length > 0 && (
        <div style={card}>
          <h3 style={{ margin: '0 0 12px', fontSize: '16px', fontWeight: 700, color: '#0f172a' }}>
            Preview · first {preview.length} rows
          </h3>
          <div style={{ overflowX: 'auto', border: '1px solid #e2e8f0', borderRadius: 8 }}>
            <table style={{ borderCollapse: 'collapse', fontSize: '12px', minWidth: '100%' }}>
              <thead>
                <tr style={{ background: '#f8fafc', borderBottom: '2px solid #e2e8f0' }}>
                  {Object.keys(FIELD_LABEL).map((k) => (
                    <th key={k} style={{ padding: '8px 12px', textAlign: 'left',
                      fontSize: '11px', color: '#64748b', textTransform: 'uppercase', letterSpacing: '0.04em',
                      whiteSpace: 'nowrap' }}>
                      {FIELD_LABEL[k]}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {preview.map((r, i) => (
                  <tr key={i} style={{ borderBottom: '1px solid #f1f5f9' }}>
                    {Object.keys(FIELD_LABEL).map((k) => {
                      const v = r[k];
                      const display = k === 'amount'
                        ? (v != null ? fmtMoney(v) : '')
                        : (v == null ? '' : String(v));
                      return (
                        <td key={k} style={{ padding: '6px 12px', color: '#334155',
                          whiteSpace: 'nowrap', maxWidth: 220, overflow: 'hidden', textOverflow: 'ellipsis',
                          textAlign: k === 'amount' ? 'right' : 'left' }}
                          title={display}>
                          {display || <span style={{ color: '#cbd5e1' }}>—</span>}
                        </td>
                      );
                    })}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <p style={{ marginTop: 10, fontSize: '12px', color: '#94a3b8' }}>
            Sample of the parsed rows. The analytics below run on the full {fmtNum(selected?.row_count || 0)} rows in this upload.
          </p>
        </div>
      )}

      {/* ── Analytics dashboard ── */}
      {selectedIds.length > 0 && uploads.filter((u) => selectedIds.includes(u.id)).some((u) => u.status === 'ready') && (
        <ClaimsAnalyticsDashboard uploadIds={selectedIds} uploads={uploads} />
      )}

      {/* ── Empty state for non-super-admins when no ready dataset exists ── */}
      {!superAdmin && !loadingUploads && !uploads.some((u) => u.status === 'ready') && (
        <div style={{
          ...card, padding: '40px 24px', textAlign: 'center',
          display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 10,
        }}>
          <ChartBarIcon style={{ width: 36, height: 36, color: '#0ea5e9' }} />
          <h3 style={{ margin: 0, color: '#0f172a', fontSize: 16 }}>No claims dataset available yet</h3>
          <p style={{ margin: 0, fontSize: 13, color: '#475569', maxWidth: 420 }}>
            A super admin needs to upload a claims Excel before the analytics can be shown.
          </p>
        </div>
      )}

      {/* Indicator that the upload was just processed and inspection panels were shown */}
      {superAdmin && selected?.status === 'ready' && !showUploadInspection && (
        <p style={{ margin: 0, fontSize: 11, color: '#94a3b8', textAlign: 'right' }}>
          Column-mapping & sample-row panels are hidden 5 minutes after upload to keep the page focused on analytics.
        </p>
      )}
    </div>
  );
}
