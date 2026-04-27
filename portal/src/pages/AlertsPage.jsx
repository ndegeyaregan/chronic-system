import { useState, useEffect, useRef } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { useNavigate } from 'react-router-dom';
import toast from 'react-hot-toast';
import {
  CheckIcon, MapPinIcon, PhoneIcon, ArrowDownTrayIcon,
  ArrowPathIcon, BellAlertIcon, ExclamationTriangleIcon,
  ClipboardDocumentIcon,
} from '@heroicons/react/24/outline';
import {
  getAdminAlerts, getAlertStats,
  markAlertRead, markAllAlertsRead, exportAlertsCsv,
  getEmergencyRequests, updateEmergencyStatus,
} from '../api/alerts';
import { downloadBlob } from '../utils/reportExports';
import Button from '../components/UI/Button';
import Badge from '../components/UI/Badge';
import Spinner from '../components/UI/Spinner';

/* ── helpers ── */
const timeAgo = (dateStr) => {
  const diff = Date.now() - new Date(dateStr).getTime();
  const mins = Math.floor(diff / 60000);
  if (mins < 1) return 'Just now';
  if (mins < 60) return `${mins}m ago`;
  const hrs = Math.floor(mins / 60);
  if (hrs < 24) return `${hrs}h ago`;
  return `${Math.floor(hrs / 24)}d ago`;
};

const fmtDate = (d) => new Date(d).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' });

const SEV_BORDER = { low: '#22c55e', medium: '#f97316', high: '#ef4444', critical: '#dc2626' };
const SEV_BG     = { low: '#f0fdf4', medium: '#fff7ed', high: '#fef2f2', critical: '#fef2f2' };
const SEV_BADGE  = { low: '#22c55e', medium: '#f97316', high: '#ef4444', critical: '#dc2626' };
const TYPE_STYLE = {
  mood:         { background: '#e0f2fe', color: '#0369a1' },
  pain:         { background: '#fee2e2', color: '#991b1b' },
  psychosocial: { background: '#fef9c3', color: '#854d0e' },
};

const EMERGENCY_STATUS_OPTIONS = ['pending', 'dispatched', 'resolved'];
const TYPE_FILTERS = ['All', 'Mood', 'Pain', 'Psychosocial'];
const SEV_FILTERS  = ['All', 'Critical', 'High', 'Medium', 'Low'];

/* ── 7-day mini bar chart (pure SVG, no lib needed) ── */
function AlertsBarChart({ chartData }) {
  const days = [];
  for (let i = 6; i >= 0; i--) {
    const d = new Date();
    d.setDate(d.getDate() - i);
    const key = d.toISOString().split('T')[0];
    const found = chartData.find((r) => r.day?.split('T')[0] === key);
    days.push({ label: d.toLocaleDateString('en-GB', { weekday: 'short' }), count: found ? found.count : 0 });
  }
  const max = Math.max(...days.map((d) => d.count), 1);
  const W = 280, H = 60, BAR_W = 28, GAP = 12;

  return (
    <svg width={W} height={H + 16} style={{ display: 'block' }}>
      {days.map((d, i) => {
        const barH = Math.max(4, Math.round((d.count / max) * H));
        const x = i * (BAR_W + GAP);
        const y = H - barH;
        return (
          <g key={i}>
            <rect x={x} y={y} width={BAR_W} height={barH}
              fill={d.count > 0 ? '#ef4444' : '#e2e8f0'} rx={4} />
            {d.count > 0 && (
              <text x={x + BAR_W / 2} y={y - 3} textAnchor="middle"
                fontSize={9} fill="#64748b">{d.count}</text>
            )}
            <text x={x + BAR_W / 2} y={H + 14} textAnchor="middle"
              fontSize={9} fill="#94a3b8">{d.label}</text>
          </g>
        );
      })}
    </svg>
  );
}

/* ── Stats mini card ── */
function StatCard({ label, value, color, icon: Icon }) {
  return (
    <div style={{
      background: '#fff', borderRadius: '12px', border: '1px solid #e2e8f0',
      padding: '16px 20px', flex: 1, minWidth: 130,
      borderTop: `3px solid ${color}`,
    }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '6px' }}>
        <Icon style={{ width: 16, height: 16, color }} />
        <span style={{ fontSize: '12px', color: '#94a3b8', fontWeight: 500 }}>{label}</span>
      </div>
      <div style={{ fontSize: '28px', fontWeight: 800, color: '#0f172a', lineHeight: 1 }}>{value ?? '—'}</div>
    </div>
  );
}

/* ── Admin note modal ── */
function NoteModal({ alert, onClose, onSave, isSaving }) {
  const [note, setNote] = useState(alert.admin_note || '');
  return (
    <div style={{
      position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.45)',
      display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 9999,
    }}>
      <div style={{
        background: '#fff', borderRadius: '14px', padding: '28px', width: '100%', maxWidth: 460,
        boxShadow: '0 20px 60px rgba(0,0,0,0.2)',
      }}>
        <h3 style={{ margin: '0 0 6px', fontSize: '16px', fontWeight: 700, color: '#0f172a' }}>
          Mark Read + Add Note
        </h3>
        <p style={{ margin: '0 0 16px', fontSize: '13px', color: '#64748b' }}>
          Add an optional clinical/action note before marking this alert as read.
        </p>
        <div style={{
          background: '#f8fafc', borderRadius: '8px', padding: '10px 14px',
          fontSize: '13px', color: '#475569', marginBottom: '16px', lineHeight: 1.6,
        }}>
          <strong>{alert.first_name} {alert.last_name}</strong> · {alert.alert_type} ·{' '}
          <span style={{ color: SEV_BADGE[alert.severity] || '#94a3b8', fontWeight: 700, textTransform: 'uppercase' }}>
            {alert.severity}
          </span>
        </div>
        <textarea
          value={note}
          onChange={(e) => setNote(e.target.value)}
          placeholder="e.g. Called member, advised to visit clinic..."
          rows={4}
          style={{
            width: '100%', boxSizing: 'border-box', borderRadius: '8px',
            border: '1px solid #e2e8f0', padding: '10px 12px',
            fontSize: '13px', resize: 'vertical', outline: 'none',
            fontFamily: 'inherit',
          }}
        />
        <div style={{ display: 'flex', gap: '10px', marginTop: '16px', justifyContent: 'flex-end' }}>
          <Button variant="secondary" onClick={onClose} disabled={isSaving}>Cancel</Button>
          <Button variant="primary" onClick={() => onSave(note)} disabled={isSaving}>
            {isSaving ? 'Saving…' : 'Mark Read'}
          </Button>
        </div>
      </div>
    </div>
  );
}

/* ═══════════════════ Main Page ═══════════════════ */
export default function AlertsPage() {
  const navigate = useNavigate();
  const qc = useQueryClient();

  const [activeTab,    setActiveTab]    = useState('Health Alerts');
  const [typeFilter,   setTypeFilter]   = useState('All');
  const [sevFilter,    setSevFilter]    = useState('All');
  const [unreadOnly,   setUnreadOnly]   = useState(false);
  const [startDate,    setStartDate]    = useState('');
  const [endDate,      setEndDate]      = useState('');
  const [noteModal,    setNoteModal]    = useState(null); // alert object
  const [lastRefresh,  setLastRefresh]  = useState(new Date());
  const [refreshAgo,   setRefreshAgo]   = useState('Just now');
  const intervalRef = useRef(null);

  // Live "last refreshed" ticker
  useEffect(() => {
    intervalRef.current = setInterval(() => {
      const diff = Math.floor((Date.now() - lastRefresh.getTime()) / 1000);
      if (diff < 60) setRefreshAgo(`${diff}s ago`);
      else setRefreshAgo(`${Math.floor(diff / 60)}m ago`);
    }, 5000);
    return () => clearInterval(intervalRef.current);
  }, [lastRefresh]);

  const handleRefresh = () => {
    qc.invalidateQueries({ queryKey: ['admin-alerts'] });
    qc.invalidateQueries({ queryKey: ['alert-stats'] });
    setLastRefresh(new Date());
    setRefreshAgo('Just now');
  };

  /* ── queries ── */
  const { data: statsData } = useQuery({
    queryKey: ['alert-stats'],
    queryFn: getAlertStats,
    refetchInterval: 30000,
    retry: false,
    placeholderData: { unread: 0, critical: 0, high: 0, today: 0, pending_emergencies: 0, chart: [] },
    onSuccess: () => setLastRefresh(new Date()),
  });

  const { data: alertsData, isLoading: alertsLoading } = useQuery({
    queryKey: ['admin-alerts', { startDate, endDate }],
    queryFn: () => getAdminAlerts({
      start_date: startDate || undefined,
      end_date:   endDate   || undefined,
    }),
    refetchInterval: 30000,
    retry: false,
    placeholderData: { alerts: [], unread_count: 0 },
  });

  const { data: emergenciesData, isLoading: emergenciesLoading } = useQuery({
    queryKey: ['emergency-requests'],
    queryFn: () => getEmergencyRequests(),
    refetchInterval: 30000,
    retry: false,
    placeholderData: { requests: [] },
  });

  /* ── mutations ── */
  const markReadMutation = useMutation({
    mutationFn: ({ id, note }) => markAlertRead(id, note),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['admin-alerts'] });
      qc.invalidateQueries({ queryKey: ['alert-stats'] });
      toast.success('Alert marked as read');
      setNoteModal(null);
    },
    onError: () => toast.error('Failed to mark as read'),
  });

  const markAllReadMutation = useMutation({
    mutationFn: markAllAlertsRead,
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['admin-alerts'] });
      qc.invalidateQueries({ queryKey: ['alert-stats'] });
      toast.success('All alerts marked as read');
    },
    onError: () => toast.error('Failed to mark all as read'),
  });

  const updateStatusMutation = useMutation({
    mutationFn: ({ id, data }) => updateEmergencyStatus(id, data),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['emergency-requests'] });
      toast.success('Status updated');
    },
    onError: () => toast.error('Failed to update status'),
  });

  /* ── derived data ── */
  const alerts   = alertsData?.alerts   || [];
  const emergencies = emergenciesData?.requests || [];
  const pendingEmergencies = emergencies.filter((e) => e.status === 'pending').length;

  const filteredAlerts = alerts.filter((a) => {
    if (typeFilter !== 'All' && a.alert_type?.toLowerCase() !== typeFilter.toLowerCase()) return false;
    if (sevFilter  !== 'All' && a.severity?.toLowerCase()   !== sevFilter.toLowerCase())  return false;
    if (unreadOnly && a.is_read) return false;
    return true;
  });

  /* ── export ── */
  const handleExport = async () => {
    try {
      const res = await exportAlertsCsv({
        alert_type:  typeFilter !== 'All' ? typeFilter.toLowerCase() : undefined,
        severity:    sevFilter  !== 'All' ? sevFilter.toLowerCase()  : undefined,
        is_read:     unreadOnly ? false : undefined,
        start_date:  startDate  || undefined,
        end_date:    endDate    || undefined,
      });
      downloadBlob(res.data, 'alerts_export.csv');
      toast.success('CSV exported');
    } catch { toast.error('Export failed'); }
  };

  /* ── copy helper ── */
  const copyToClipboard = (text, label) => {
    navigator.clipboard.writeText(text).then(() => toast.success(`${label} copied`));
  };

  const inputStyle = {
    padding: '7px 11px', borderRadius: '8px', border: '1px solid #e2e8f0',
    fontSize: '13px', background: '#fff', outline: 'none',
  };

  const chip = (label, active, onClick) => (
    <button onClick={onClick} style={{
      padding: '5px 14px', borderRadius: '999px', border: '1px solid',
      borderColor: active ? 'var(--primary)' : '#e2e8f0',
      background: active ? 'var(--primary)' : '#fff',
      color: active ? '#fff' : '#64748b',
      fontSize: '12px', fontWeight: active ? 600 : 400,
      cursor: 'pointer', transition: 'all 0.15s',
    }}>{label}</button>
  );

  return (
    <>
      <style>{`
        @keyframes alertPulse {
          0%, 100% { box-shadow: 0 0 0 0 rgba(220,38,38,0.5); }
          50%       { box-shadow: 0 0 0 8px rgba(220,38,38,0); }
        }
        .critical-alert-card { animation: alertPulse 2s infinite; }
      `}</style>

      <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>

        {/* ── Header ── */}
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '10px' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
            <h1 style={{ fontSize: '22px', fontWeight: 700, color: '#0f172a', margin: 0 }}>Alerts</h1>
            {(statsData?.unread ?? 0) > 0 && (
              <span style={{
                background: '#ef4444', color: '#fff', fontSize: '12px', fontWeight: 700,
                padding: '2px 9px', borderRadius: '999px',
              }}>{statsData.unread}</span>
            )}
            <span style={{ fontSize: '12px', color: '#94a3b8', display: 'flex', alignItems: 'center', gap: '5px' }}>
              <ArrowPathIcon style={{ width: 13, height: 13 }} /> Refreshed {refreshAgo}
            </span>
          </div>
          <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
            <Button variant="secondary" onClick={handleRefresh} style={{ display: 'flex', alignItems: 'center', gap: '5px', fontSize: '13px' }}>
              <ArrowPathIcon style={{ width: 14, height: 14 }} /> Refresh
            </Button>
            <Button variant="secondary" onClick={handleExport} style={{ display: 'flex', alignItems: 'center', gap: '5px', fontSize: '13px' }}>
              <ArrowDownTrayIcon style={{ width: 14, height: 14 }} /> Export CSV
            </Button>
            <Button variant="secondary"
              onClick={() => markAllReadMutation.mutate()}
              disabled={markAllReadMutation.isPending || (statsData?.unread ?? 0) === 0}
              style={{ display: 'flex', alignItems: 'center', gap: '5px', fontSize: '13px' }}>
              <CheckIcon style={{ width: 14, height: 14 }} /> Mark All Read
            </Button>
          </div>
        </div>

        {/* ── Stats strip ── */}
        <div style={{ display: 'flex', gap: '14px', flexWrap: 'wrap' }}>
          <StatCard label="Unread Alerts"       value={statsData?.unread}              color="#3b82f6" icon={BellAlertIcon} />
          <StatCard label="Critical (unread)"   value={statsData?.critical}            color="#dc2626" icon={ExclamationTriangleIcon} />
          <StatCard label="High (unread)"        value={statsData?.high}                color="#f97316" icon={ExclamationTriangleIcon} />
          <StatCard label="Alerts Today"         value={statsData?.today}              color="#10b981" icon={BellAlertIcon} />
          <StatCard label="Pending Emergencies"  value={statsData?.pending_emergencies} color="#ef4444" icon={ExclamationTriangleIcon} />

          {/* 7-day chart card */}
          <div style={{
            background: '#fff', borderRadius: '12px', border: '1px solid #e2e8f0',
            padding: '16px 20px', flex: '1 1 300px',
          }}>
            <div style={{ fontSize: '12px', color: '#94a3b8', fontWeight: 500, marginBottom: '10px' }}>
              Alerts — Last 7 Days
            </div>
            <AlertsBarChart chartData={statsData?.chart || []} />
          </div>
        </div>

        {/* ── Tabs ── */}
        <div style={{ background: '#fff', borderRadius: '12px', boxShadow: '0 1px 4px rgba(0,0,0,0.07)', overflow: 'hidden' }}>
          <div style={{ display: 'flex', borderBottom: '2px solid #f1f5f9' }}>
            {['Health Alerts', 'Emergencies'].map((tab) => (
              <button key={tab} onClick={() => setActiveTab(tab)} style={{
                padding: '12px 20px', background: 'none', border: 'none',
                borderBottom: activeTab === tab ? '2px solid var(--primary)' : '2px solid transparent',
                marginBottom: '-2px', cursor: 'pointer', fontSize: '14px',
                fontWeight: activeTab === tab ? 600 : 400,
                color: activeTab === tab ? 'var(--primary)' : '#64748b',
                display: 'flex', alignItems: 'center', gap: '7px',
              }}>
                {tab}
                {tab === 'Emergencies' && pendingEmergencies > 0 && (
                  <span style={{ background: '#ef4444', color: '#fff', fontSize: '11px', fontWeight: 700, padding: '1px 6px', borderRadius: '999px' }}>
                    {pendingEmergencies}
                  </span>
                )}
              </button>
            ))}
          </div>

          <div style={{ padding: '20px' }}>

            {/* ════ HEALTH ALERTS TAB ════ */}
            {activeTab === 'Health Alerts' && (
              <div>
                {/* Filter bar */}
                <div style={{ display: 'flex', gap: '10px', flexWrap: 'wrap', marginBottom: '20px', alignItems: 'center' }}>
                  {/* Type chips */}
                  <div style={{ display: 'flex', gap: '6px', flexWrap: 'wrap' }}>
                    {TYPE_FILTERS.map((f) => chip(f, typeFilter === f, () => setTypeFilter(f)))}
                  </div>
                  <div style={{ width: 1, height: 24, background: '#e2e8f0', flexShrink: 0 }} />
                  {/* Severity chips */}
                  <div style={{ display: 'flex', gap: '6px', flexWrap: 'wrap' }}>
                    {SEV_FILTERS.map((f) => chip(f, sevFilter === f, () => setSevFilter(f)))}
                  </div>
                  <div style={{ width: 1, height: 24, background: '#e2e8f0', flexShrink: 0 }} />
                  {/* Unread toggle */}
                  <button onClick={() => setUnreadOnly((p) => !p)} style={{
                    padding: '5px 14px', borderRadius: '999px', border: '1px solid',
                    borderColor: unreadOnly ? '#f97316' : '#e2e8f0',
                    background: unreadOnly ? '#fff7ed' : '#fff',
                    color: unreadOnly ? '#c2410c' : '#64748b',
                    fontSize: '12px', fontWeight: unreadOnly ? 600 : 400, cursor: 'pointer',
                  }}>
                    {unreadOnly ? '● Unread only' : '○ Unread only'}
                  </button>
                  {/* Date range */}
                  <input type="date" value={startDate} onChange={(e) => setStartDate(e.target.value)} style={inputStyle} />
                  <span style={{ fontSize: '12px', color: '#94a3b8' }}>to</span>
                  <input type="date" value={endDate}   onChange={(e) => setEndDate(e.target.value)}   style={inputStyle} />
                  <span style={{ fontSize: '12px', color: '#94a3b8', marginLeft: 'auto' }}>
                    <strong>{filteredAlerts.length}</strong> result{filteredAlerts.length !== 1 ? 's' : ''}
                  </span>
                </div>

                {alertsLoading ? (
                  <Spinner />
                ) : filteredAlerts.length === 0 ? (
                  <div style={{ textAlign: 'center', padding: '48px 0', color: '#94a3b8', fontSize: '14px' }}>
                    No alerts match your filters.
                  </div>
                ) : (
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                    {filteredAlerts.map((alert) => {
                      const sev = alert.severity?.toLowerCase() || 'low';
                      const isCritical = sev === 'critical';
                      const typeKey = alert.alert_type?.toLowerCase();

                      return (
                        <div key={alert.id}
                          className={isCritical ? 'critical-alert-card' : undefined}
                          style={{
                            background: alert.is_read ? '#fff' : (SEV_BG[sev] || '#fff'),
                            border: '1px solid #e2e8f0',
                            borderLeft: `4px solid ${SEV_BORDER[sev] || '#94a3b8'}`,
                            borderRadius: '8px', padding: '16px',
                            display: 'flex', flexDirection: 'column', gap: '10px',
                            opacity: alert.is_read ? 0.75 : 1,
                          }}>

                          {/* Top row */}
                          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', flexWrap: 'wrap', gap: '8px' }}>
                            <div style={{ display: 'flex', alignItems: 'center', gap: '8px', flexWrap: 'wrap' }}>
                              <button onClick={() => navigate(`/members/${alert.member_id}`)}
                                style={{ background: 'none', border: 'none', cursor: 'pointer', fontSize: '15px',
                                  fontWeight: 700, color: 'var(--primary)', padding: 0, textDecoration: 'underline' }}>
                                {alert.first_name} {alert.last_name}
                              </button>
                              {alert.member_number && (
                                <span style={{ fontSize: '12px', color: '#94a3b8' }}>{alert.member_number}</span>
                              )}
                              {alert.alert_type && (
                                <span style={{
                                  ...(TYPE_STYLE[typeKey] || { background: '#f1f5f9', color: '#475569' }),
                                  padding: '2px 10px', borderRadius: '999px', fontSize: '11px', fontWeight: 700, textTransform: 'uppercase',
                                }}>{alert.alert_type}</span>
                              )}
                              <span style={{
                                background: SEV_BADGE[sev] || '#94a3b8', color: '#fff',
                                padding: '2px 10px', borderRadius: '999px', fontSize: '11px', fontWeight: 700, textTransform: 'uppercase',
                              }}>{alert.severity}</span>
                            </div>

                            <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                              <span style={{ fontSize: '12px', color: '#94a3b8' }}>
                                {alert.created_at ? timeAgo(alert.created_at) : ''}
                              </span>
                              {!alert.is_read && (
                                <button onClick={() => setNoteModal(alert)}
                                  style={{
                                    padding: '4px 14px', borderRadius: '6px', border: '1px solid var(--primary)',
                                    background: 'var(--primary)', color: '#fff', fontSize: '12px',
                                    fontWeight: 600, cursor: 'pointer',
                                  }}>
                                  Mark Read
                                </button>
                              )}
                              {alert.is_read && (
                                <span style={{ fontSize: '12px', color: '#22c55e', fontWeight: 600 }}>✓ Read</span>
                              )}
                            </div>
                          </div>

                          {/* Value */}
                          {(alert.value_reported !== null && alert.value_reported !== undefined) && (
                            <div style={{ fontSize: '13px', color: '#475569', fontWeight: 600 }}>
                              {typeKey === 'pain'         && `Pain Level: ${alert.value_reported}/10`}
                              {typeKey === 'mood'         && `Mood Score: ${alert.value_reported}`}
                              {typeKey === 'psychosocial' && `Score: ${alert.value_reported}`}
                              {!['pain','mood','psychosocial'].includes(typeKey) && `Value: ${alert.value_reported}`}
                            </div>
                          )}

                          {/* Notes */}
                          {alert.notes && (
                            <p style={{ margin: 0, fontSize: '13px', color: '#64748b', lineHeight: 1.6 }}>
                              {alert.notes}
                            </p>
                          )}

                          {/* Quick contact row */}
                          <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap', alignItems: 'center' }}>
                            {alert.phone && (
                              <a href={`tel:${alert.phone}`} style={{
                                display: 'inline-flex', alignItems: 'center', gap: '5px',
                                fontSize: '12px', color: '#0ea5e9', textDecoration: 'none', fontWeight: 500,
                              }}>
                                <PhoneIcon style={{ width: 13, height: 13 }} />{alert.phone}
                              </a>
                            )}
                            {alert.phone && (
                              <button onClick={() => copyToClipboard(alert.phone, 'Phone number')}
                                title="Copy phone"
                                style={{ background: 'none', border: '1px solid #e2e8f0', borderRadius: '6px',
                                  padding: '3px 8px', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '4px',
                                  fontSize: '11px', color: '#64748b' }}>
                                <ClipboardDocumentIcon style={{ width: 12, height: 12 }} /> Copy Phone
                              </button>
                            )}
                            {alert.email && (
                              <button onClick={() => copyToClipboard(alert.email, 'Email')}
                                title="Copy email"
                                style={{ background: 'none', border: '1px solid #e2e8f0', borderRadius: '6px',
                                  padding: '3px 8px', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '4px',
                                  fontSize: '11px', color: '#64748b' }}>
                                <ClipboardDocumentIcon style={{ width: 12, height: 12 }} /> Copy Email
                              </button>
                            )}
                          </div>

                          {/* Admin note (if already noted) */}
                          {alert.admin_note && (
                            <div style={{
                              background: '#f0fdf4', border: '1px solid #bbf7d0', borderRadius: '8px',
                              padding: '10px 14px', fontSize: '13px', color: '#166534',
                            }}>
                              <strong style={{ fontSize: '11px', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
                                Admin Note
                              </strong>
                              <p style={{ margin: '4px 0 0', lineHeight: 1.5 }}>{alert.admin_note}</p>
                              {alert.admin_note_at && (
                                <p style={{ margin: '4px 0 0', fontSize: '11px', color: '#4ade80' }}>
                                  {fmtDate(alert.admin_note_at)}
                                </p>
                              )}
                            </div>
                          )}
                        </div>
                      );
                    })}
                  </div>
                )}
              </div>
            )}

            {/* ════ EMERGENCIES TAB ════ */}
            {activeTab === 'Emergencies' && (
              <div>
                {emergenciesLoading ? (
                  <Spinner />
                ) : emergencies.length === 0 ? (
                  <div style={{ textAlign: 'center', padding: '48px 0', color: '#94a3b8', fontSize: '14px' }}>
                    No emergency requests found.
                  </div>
                ) : (
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
                    {emergencies.map((req) => (
                      <div key={req.id} style={{
                        border: '1px solid #fca5a5', borderRadius: '10px', overflow: 'hidden',
                        boxShadow: '0 2px 8px rgba(239,68,68,0.12)',
                      }}>
                        <div style={{
                          background: '#dc2626', color: '#fff', padding: '10px 16px',
                          display: 'flex', alignItems: 'center', gap: '8px',
                          fontWeight: 700, fontSize: '13px', letterSpacing: '0.06em',
                        }}>
                          🚨 AMBULANCE REQUEST
                          <span style={{ marginLeft: 'auto' }}>
                            <Badge
                              status={req.status === 'resolved' ? 'completed' : req.status === 'dispatched' ? 'confirmed' : 'pending'}
                              label={req.status?.toUpperCase()}
                            />
                          </span>
                        </div>

                        <div style={{ padding: '16px', background: '#fff', display: 'flex', flexDirection: 'column', gap: '12px' }}>
                          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', flexWrap: 'wrap', gap: '8px' }}>
                            <div>
                              <button onClick={() => navigate(`/members/${req.member_id}`)}
                                style={{ background: 'none', border: 'none', cursor: 'pointer', fontSize: '16px',
                                  fontWeight: 700, color: 'var(--primary)', padding: 0, textDecoration: 'underline',
                                  display: 'block', marginBottom: '6px' }}>
                                {req.member_name || (req.member ? `${req.member.first_name} ${req.member.last_name}` : 'Unknown')}
                              </button>
                              {req.phone && (
                                <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
                                  <a href={`tel:${req.phone}`} style={{
                                    display: 'inline-flex', alignItems: 'center', gap: '5px',
                                    fontSize: '14px', color: '#0ea5e9', textDecoration: 'none', fontWeight: 500,
                                  }}>
                                    <PhoneIcon style={{ width: 14, height: 14 }} />{req.phone}
                                  </a>
                                  <button onClick={() => copyToClipboard(req.phone, 'Phone number')}
                                    style={{ background: 'none', border: '1px solid #e2e8f0', borderRadius: '6px',
                                      padding: '2px 8px', cursor: 'pointer', fontSize: '11px', color: '#64748b' }}>
                                    Copy
                                  </button>
                                </div>
                              )}
                            </div>
                            <span style={{ fontSize: '12px', color: '#94a3b8', whiteSpace: 'nowrap' }}>
                              {req.created_at ? timeAgo(req.created_at) : ''}
                            </span>
                          </div>

                          {req.pain_level !== undefined && req.pain_level !== null && (
                            <div style={{
                              display: 'inline-flex', alignItems: 'center', gap: '8px',
                              background: '#fef2f2', border: '1px solid #fca5a5',
                              borderRadius: '8px', padding: '8px 16px', width: 'fit-content',
                            }}>
                              <span style={{ fontSize: '13px', color: '#64748b', fontWeight: 500 }}>Pain Level:</span>
                              <span style={{ fontSize: '26px', fontWeight: 800, color: '#dc2626', lineHeight: 1 }}>{req.pain_level}</span>
                              <span style={{ fontSize: '13px', color: '#94a3b8' }}>/ 10</span>
                            </div>
                          )}

                          {req.latitude && req.longitude ? (
                            <a href={`https://maps.google.com/?q=${req.latitude},${req.longitude}`}
                              target="_blank" rel="noreferrer"
                              style={{ display: 'inline-flex', alignItems: 'center', gap: '6px', fontSize: '13px', color: '#0ea5e9', textDecoration: 'none', fontWeight: 500 }}>
                              <MapPinIcon style={{ width: 16, height: 16 }} />
                              View on Google Maps ({Number(req.latitude).toFixed(4)}, {Number(req.longitude).toFixed(4)})
                            </a>
                          ) : req.address ? (
                            <div style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '13px', color: '#475569' }}>
                              <MapPinIcon style={{ width: 16, height: 16 }} />{req.address}
                            </div>
                          ) : null}

                          <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap', alignItems: 'center' }}>
                            {req.status === 'pending' && (
                              <Button variant="primary"
                                onClick={() => updateStatusMutation.mutate({ id: req.id, data: { status: 'dispatched' } })}
                                disabled={updateStatusMutation.isPending}>
                                🚑 Mark Dispatched
                              </Button>
                            )}
                            {req.status === 'dispatched' && (
                              <Button variant="success"
                                onClick={() => updateStatusMutation.mutate({ id: req.id, data: { status: 'resolved' } })}
                                disabled={updateStatusMutation.isPending}>
                                ✅ Mark Resolved
                              </Button>
                            )}
                            <select value={req.status}
                              onChange={(e) => updateStatusMutation.mutate({ id: req.id, data: { status: e.target.value } })}
                              style={{ padding: '7px 12px', borderRadius: '6px', border: '1px solid #e2e8f0', fontSize: '13px', background: '#fff', cursor: 'pointer' }}>
                              {EMERGENCY_STATUS_OPTIONS.map((s) => (
                                <option key={s} value={s}>{s.charAt(0).toUpperCase() + s.slice(1)}</option>
                              ))}
                            </select>
                          </div>
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            )}
          </div>
        </div>
      </div>

      {/* ── Admin Note Modal ── */}
      {noteModal && (
        <NoteModal
          alert={noteModal}
          onClose={() => setNoteModal(null)}
          onSave={(note) => markReadMutation.mutate({ id: noteModal.id, note })}
          isSaving={markReadMutation.isPending}
        />
      )}
    </>
  );
}
