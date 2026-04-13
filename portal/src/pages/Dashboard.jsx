import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { Link } from 'react-router-dom';
import {
  BarChart, Bar, PieChart, Pie, Cell,
  LineChart, Line, XAxis, YAxis, CartesianGrid,
  Tooltip, Legend, ResponsiveContainer, RadialBarChart, RadialBar,
} from 'recharts';
import {
  UsersIcon, CalendarDaysIcon, HeartIcon, UserPlusIcon,
  ShieldCheckIcon, BeakerIcon, BellAlertIcon, ClipboardDocumentListIcon,
  ArrowPathIcon, CheckBadgeIcon, ChatBubbleLeftRightIcon,
  ChartBarIcon, DocumentChartBarIcon, ClockIcon, ExclamationCircleIcon,
} from '@heroicons/react/24/outline';
import { format } from 'date-fns';
import StatCard from '../components/UI/StatCard';
import Badge from '../components/UI/Badge';
import Spinner from '../components/UI/Spinner';
import { useAuth } from '../context/AuthContext';
import api from '../api/axios';

/* ── colours (no purple) ───────────────────────────── */
const C = {
  blue:    '#003DA5',
  green:   '#7AB800',
  amber:   '#f59e0b',
  red:     '#ef4444',
  sky:     '#0ea5e9',
  teal:    '#14b8a6',
  orange:  '#f97316',
  slate:   '#64748b',
  border:  '#e2e8f0',
  bg:      '#f8fafc',
};
const PIE_COLORS = [C.blue, C.green, C.amber, C.red, C.sky, C.teal];
const SEVERITY_COLOR = { critical: C.red, high: C.orange, medium: C.amber, low: C.green };
const LAB_COLOR = { ordered: C.blue, pending: C.amber, processing: C.sky, completed: C.green, cancelled: C.slate };

/* ── api ────────────────────────────────────────────── */
const fetchSummary = () => api.get('/dashboard/summary').then(r => r.data);

/* ── small helpers ──────────────────────────────────── */
const panel = (extra = {}) => ({
  background: '#fff',
  borderRadius: '12px',
  padding: '20px',
  boxShadow: '0 1px 4px rgba(0,0,0,0.07)',
  border: `1px solid ${C.border}`,
  ...extra,
});

const greeting = () => {
  const h = new Date().getHours();
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
};

/* ── Quick Actions ──────────────────────────────────── */
const QUICK_ACTIONS = [
  { label: 'New Appointment',      icon: CalendarDaysIcon,        to: '/appointments',   color: C.blue   },
  { label: 'Authorizations',       icon: ShieldCheckIcon,         to: '/authorizations', color: C.green  },
  { label: 'Lab Queue',            icon: BeakerIcon,              to: '/lab-tests/queue',color: C.sky    },
  { label: 'View Reports',         icon: DocumentChartBarIcon,    to: '/reports',        color: C.amber  },
  { label: 'Alerts',               icon: BellAlertIcon,           to: '/alerts',         color: C.red    },
  { label: 'Chat',                 icon: ChatBubbleLeftRightIcon, to: '/chat',           color: C.teal   },
  { label: 'Analytics',            icon: ChartBarIcon,            to: '/analytics',      color: C.orange },
  { label: 'Members',              icon: UsersIcon,               to: '/members',        color: C.slate  },
];

/* ══════════════════════════════════════════════════════ */
export default function Dashboard() {
  const { user } = useAuth();
  const adminName = user?.first_name || user?.name || 'Admin';
  const [lastRefresh, setLastRefresh] = useState(new Date());

  const { data, isLoading, refetch, isFetching } = useQuery({
    queryKey: ['dashboard-summary'],
    queryFn: () => fetchSummary().then(d => { setLastRefresh(new Date()); return d; }),
    refetchInterval: 60_000,
    retry: false,
  });

  const conditionData    = data?.by_condition      || [];
  const growthData       = data?.member_growth      || [];
  const todayAppts       = data?.today_appointments || [];
  const recentAlerts     = data?.recent_alerts      || [];
  const adherenceTrend   = data?.adherence_trend    || [];
  const alertsBySeverity = data?.alerts_by_severity || [];
  const labByStatus      = data?.lab_by_status      || [];
  const recentMembers    = data?.recent_members     || [];
  const unreadChats      = data?.unread_chats       ?? 0;

  const pieData = [
    { name: 'Pending',   value: data?.pending_appts   || 0 },
    { name: 'Confirmed', value: data?.confirmed_appts || 0 },
    { name: 'Completed', value: data?.completed_appts || 0 },
  ].filter(d => d.value > 0);

  /* Action items that need attention */
  const actionItems = [
    data?.pending_auths > 0  && { label: `${data.pending_auths} pending authorizations`,      to: '/authorizations', color: C.red    },
    data?.open_alerts   > 0  && { label: `${data.open_alerts} unread alerts`,                 to: '/alerts',         color: C.red    },
    unreadChats         > 0  && { label: `${unreadChats} unread member messages`,              to: '/chat',           color: C.amber  },
    data?.pending_labs  > 0  && { label: `${data.pending_labs} lab tests pending`,            to: '/lab-tests/queue',color: C.blue   },
    data?.pending_appts > 0  && { label: `${data.pending_appts} appointments need confirmation`,to: '/appointments',  color: C.blue   },
  ].filter(Boolean);

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>

      {/* ── Welcome bar ── */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 12 }}>
        <div>
          <h2 style={{ margin: 0, fontSize: '20px', fontWeight: '700', color: 'var(--text)' }}>
            {greeting()}, {adminName} 👋
          </h2>
          <p style={{ margin: '4px 0 0', fontSize: '13px', color: C.slate }}>
            {format(new Date(), "EEEE, d MMMM yyyy")} — here's your overview
          </p>
        </div>
        <button
          onClick={() => refetch()}
          disabled={isFetching}
          style={{ display: 'flex', alignItems: 'center', gap: 6, padding: '7px 14px', border: `1px solid ${C.border}`, borderRadius: '8px', background: '#fff', fontSize: '12px', color: C.slate, cursor: 'pointer', fontWeight: '600' }}
        >
          <ArrowPathIcon style={{ width: 14, height: 14, animation: isFetching ? 'spin 1s linear infinite' : 'none' }} />
          Refresh · {format(lastRefresh, 'HH:mm:ss')}
        </button>
      </div>

      {/* ── Pending Action Items ── */}
      {!isLoading && actionItems.length > 0 && (
        <div style={{ ...panel(), background: '#fffbeb', borderColor: C.amber + '60', padding: '14px 20px' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 10 }}>
            <ExclamationCircleIcon style={{ width: 16, height: 16, color: C.amber }} />
            <span style={{ fontSize: '13px', fontWeight: '700', color: '#92400e' }}>Items Requiring Your Attention</span>
          </div>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
            {actionItems.map((item, i) => (
              <Link key={i} to={item.to} style={{
                fontSize: '12px', fontWeight: '600', padding: '5px 12px',
                borderRadius: '20px', textDecoration: 'none',
                background: item.color + '15', color: item.color,
                border: `1px solid ${item.color}40`,
              }}>
                {item.label} →
              </Link>
            ))}
          </div>
        </div>
      )}

      {/* ── Stat Cards Row 1 ── */}
      {isLoading ? <Spinner /> : (
        <>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '16px' }}>
            <StatCard title="Total Members"          value={data?.total_members   ?? 0} color={C.blue}  trendLabel="registered" />
            <StatCard title="Active Members"         value={data?.active_members  ?? 0} color={C.blue}  trendLabel="currently active" />
            <StatCard title="New Members This Month" value={data?.new_this_month  ?? 0} color={C.blue}  trendLabel="this month" />
            <StatCard title="Medication Adherence"   value={`${data?.adherence_rate ?? 0}%`} color={C.blue}  trendLabel="last 30 days" />
          </div>

          {/* ── Stat Cards Row 2 ── */}
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '16px' }}>
            <StatCard title="Pending Appointments"   value={data?.pending_appts      ?? 0} color={C.blue}  trendLabel="awaiting confirmation" />
            <StatCard title="Today's Appointments"   value={data?.today_appts_count  ?? 0} color={C.blue}  trendLabel="scheduled today" />
            <StatCard title="Pending Authorizations" value={data?.pending_auths       ?? 0} color={C.red}   trendLabel="need review" />
            <StatCard title="Unread Chat Messages"   value={unreadChats}                   color={C.blue}  trendLabel="from members" />
          </div>
        </>
      )}

      {/* ── Quick Actions ── */}
      <div style={panel()}>
        <h3 style={{ margin: '0 0 14px', fontSize: '14px', fontWeight: '700', color: 'var(--text)' }}>Quick Actions</h3>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(130px, 1fr))', gap: '10px' }}>
          {QUICK_ACTIONS.map(({ label, icon: Icon, to, color }) => (
            <Link
              key={to}
              to={to}
              style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 8, padding: '14px 10px', borderRadius: '10px', border: `1px solid ${C.border}`, textDecoration: 'none', background: C.bg }}
              onMouseEnter={e => e.currentTarget.style.background = '#fff'}
              onMouseLeave={e => e.currentTarget.style.background = C.bg}
            >
              <Icon style={{ width: 20, height: 20, color }} />
              <span style={{ fontSize: '12px', fontWeight: '600', color: 'var(--text)', textAlign: 'center', lineHeight: 1.3 }}>{label}</span>
            </Link>
          ))}
        </div>
      </div>

      {/* ── Charts Row 1: existing 3 charts ── */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: '20px' }}>
        {/* Members by Condition */}
        <div style={panel()}>
          <h3 style={{ margin: '0 0 14px', fontSize: '14px', fontWeight: '700', color: 'var(--text)' }}>Members by Condition</h3>
          {isLoading ? <Spinner /> : (
            <ResponsiveContainer width="100%" height={200}>
              <BarChart data={conditionData} margin={{ top: 0, right: 4, left: -20, bottom: 0 }}>
                <CartesianGrid strokeDasharray="3 3" stroke="#f1f5f9" />
                <XAxis dataKey="condition" tick={{ fontSize: 10, fill: C.slate }} />
                <YAxis tick={{ fontSize: 10, fill: C.slate }} />
                <Tooltip contentStyle={{ fontSize: 12 }} />
                <Bar dataKey="count" fill={C.blue} radius={[4, 4, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          )}
        </div>

        {/* Appointment Status */}
        <div style={panel()}>
          <h3 style={{ margin: '0 0 14px', fontSize: '14px', fontWeight: '700', color: 'var(--text)' }}>Appointment Status</h3>
          {isLoading ? <Spinner /> : pieData.length === 0 ? (
            <div style={{ height: 200, display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#94a3b8', fontSize: 13 }}>No data</div>
          ) : (
            <ResponsiveContainer width="100%" height={200}>
              <PieChart>
                <Pie data={pieData} cx="50%" cy="50%" innerRadius={50} outerRadius={80} paddingAngle={3} dataKey="value" label={({ name, percent }) => `${name} ${((percent||0)*100).toFixed(0)}%`} labelLine={false}>
                  {pieData.map((_, i) => <Cell key={i} fill={PIE_COLORS[i % PIE_COLORS.length]} />)}
                </Pie>
                <Tooltip />
                <Legend iconSize={10} wrapperStyle={{ fontSize: 11 }} />
              </PieChart>
            </ResponsiveContainer>
          )}
        </div>

        {/* Member Growth */}
        <div style={panel()}>
          <h3 style={{ margin: '0 0 14px', fontSize: '14px', fontWeight: '700', color: 'var(--text)' }}>Member Growth</h3>
          {isLoading ? <Spinner /> : growthData.length === 0 ? (
            <div style={{ height: 200, display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#94a3b8', fontSize: 13 }}>No data</div>
          ) : (
            <ResponsiveContainer width="100%" height={200}>
              <LineChart data={growthData} margin={{ top: 4, right: 4, left: -20, bottom: 0 }}>
                <CartesianGrid strokeDasharray="3 3" stroke="#f1f5f9" />
                <XAxis dataKey="month" tick={{ fontSize: 10, fill: C.slate }} />
                <YAxis tick={{ fontSize: 10, fill: C.slate }} />
                <Tooltip contentStyle={{ fontSize: 12 }} />
                <Line type="monotone" dataKey="count" stroke={C.blue} strokeWidth={2} dot={{ r: 4, fill: C.blue }} />
              </LineChart>
            </ResponsiveContainer>
          )}
        </div>
      </div>

      {/* ── Charts Row 2: Adherence Trend + Alerts by Severity + Lab Status ── */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: '20px' }}>

        {/* Medication Adherence Trend */}
        <div style={panel()}>
          <h3 style={{ margin: '0 0 14px', fontSize: '14px', fontWeight: '700', color: 'var(--text)' }}>Adherence Trend</h3>
          <p style={{ margin: '-10px 0 12px', fontSize: '11px', color: C.slate }}>Monthly medication adherence %</p>
          {isLoading ? <Spinner /> : adherenceTrend.length === 0 ? (
            <div style={{ height: 180, display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#94a3b8', fontSize: 13 }}>No data</div>
          ) : (
            <ResponsiveContainer width="100%" height={180}>
              <LineChart data={adherenceTrend} margin={{ top: 4, right: 4, left: -20, bottom: 0 }}>
                <CartesianGrid strokeDasharray="3 3" stroke="#f1f5f9" />
                <XAxis dataKey="month" tick={{ fontSize: 10, fill: C.slate }} />
                <YAxis domain={[0, 100]} tick={{ fontSize: 10, fill: C.slate }} unit="%" />
                <Tooltip contentStyle={{ fontSize: 12 }} formatter={v => [`${v}%`, 'Adherence']} />
                <Line type="monotone" dataKey="rate" stroke={C.green} strokeWidth={2} dot={{ r: 4, fill: C.green }} />
              </LineChart>
            </ResponsiveContainer>
          )}
        </div>

        {/* Alerts by Severity */}
        <div style={panel()}>
          <h3 style={{ margin: '0 0 14px', fontSize: '14px', fontWeight: '700', color: 'var(--text)' }}>Alerts by Severity</h3>
          <p style={{ margin: '-10px 0 12px', fontSize: '11px', color: C.slate }}>Unread alerts breakdown</p>
          {isLoading ? <Spinner /> : alertsBySeverity.length === 0 ? (
            <div style={{ height: 180, display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#94a3b8', fontSize: 13 }}>No unread alerts</div>
          ) : (
            <>
              <ResponsiveContainer width="100%" height={140}>
                <BarChart data={alertsBySeverity} layout="vertical" margin={{ top: 0, right: 10, left: 10, bottom: 0 }}>
                  <XAxis type="number" tick={{ fontSize: 10, fill: C.slate }} />
                  <YAxis dataKey="severity" type="category" tick={{ fontSize: 10, fill: C.slate }} width={55} />
                  <Tooltip contentStyle={{ fontSize: 12 }} />
                  <Bar dataKey="count" radius={[0, 4, 4, 0]}>
                    {alertsBySeverity.map((entry, i) => (
                      <Cell key={i} fill={SEVERITY_COLOR[entry.severity] || C.slate} />
                    ))}
                  </Bar>
                </BarChart>
              </ResponsiveContainer>
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, marginTop: 8 }}>
                {alertsBySeverity.map(s => (
                  <span key={s.severity} style={{ fontSize: '11px', fontWeight: '700', padding: '3px 8px', borderRadius: '12px', background: (SEVERITY_COLOR[s.severity] || C.slate) + '18', color: SEVERITY_COLOR[s.severity] || C.slate, textTransform: 'capitalize' }}>
                    {s.severity}: {s.count}
                  </span>
                ))}
              </div>
            </>
          )}
        </div>

        {/* Lab Tests by Status */}
        <div style={panel()}>
          <h3 style={{ margin: '0 0 14px', fontSize: '14px', fontWeight: '700', color: 'var(--text)' }}>Lab Tests Status</h3>
          <p style={{ margin: '-10px 0 12px', fontSize: '11px', color: C.slate }}>All lab tests breakdown</p>
          {isLoading ? <Spinner /> : labByStatus.length === 0 ? (
            <div style={{ height: 180, display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#94a3b8', fontSize: 13 }}>No data</div>
          ) : (
            <>
              <ResponsiveContainer width="100%" height={140}>
                <PieChart>
                  <Pie data={labByStatus} cx="50%" cy="50%" outerRadius={60} dataKey="count" nameKey="status" label={({ status, percent }) => `${status} ${((percent||0)*100).toFixed(0)}%`} labelLine={false}>
                    {labByStatus.map((entry, i) => (
                      <Cell key={i} fill={LAB_COLOR[entry.status] || PIE_COLORS[i % PIE_COLORS.length]} />
                    ))}
                  </Pie>
                  <Tooltip contentStyle={{ fontSize: 12 }} />
                </PieChart>
              </ResponsiveContainer>
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, marginTop: 4 }}>
                {labByStatus.map(s => (
                  <span key={s.status} style={{ fontSize: '11px', fontWeight: '700', padding: '3px 8px', borderRadius: '12px', background: (LAB_COLOR[s.status] || C.slate) + '18', color: LAB_COLOR[s.status] || C.slate, textTransform: 'capitalize' }}>
                    {s.status}: {s.count}
                  </span>
                ))}
              </div>
            </>
          )}
        </div>
      </div>

      {/* ── Today's Appointments + Recent Alerts ── */}
      <div style={{ display: 'grid', gridTemplateColumns: '2fr 1fr', gap: '20px' }}>

        {/* Today's Appointments */}
        <div style={panel()}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 14 }}>
            <h3 style={{ margin: 0, fontSize: '14px', fontWeight: '700', color: 'var(--text)' }}>
              Today's Appointments
              {data?.today_appts_count > 0 && (
                <span style={{ marginLeft: 8, background: C.orange + '20', color: C.orange, fontSize: '11px', fontWeight: '700', borderRadius: '8px', padding: '2px 8px' }}>
                  {data.today_appts_count}
                </span>
              )}
            </h3>
            <Link to="/appointments" style={{ fontSize: '12px', color: C.blue, fontWeight: '600', textDecoration: 'none' }}>View all →</Link>
          </div>
          {isLoading ? <Spinner /> : todayAppts.length === 0 ? (
            <div style={{ padding: '24px 0', textAlign: 'center', color: '#94a3b8', fontSize: 13 }}>
              No appointments scheduled for today.
            </div>
          ) : (
            <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '13px' }}>
              <thead>
                <tr style={{ borderBottom: `2px solid ${C.bg}` }}>
                  {['Member', 'Hospital', 'Time', 'Reason', 'Status'].map(h => (
                    <th key={h} style={{ padding: '6px 10px', textAlign: 'left', fontSize: '11px', color: C.slate, fontWeight: '700', textTransform: 'uppercase', letterSpacing: '0.04em' }}>{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {todayAppts.map(a => (
                  <tr key={a.id} style={{ borderBottom: `1px solid ${C.bg}` }}>
                    <td style={{ padding: '8px 10px' }}>
                      <div style={{ fontWeight: '600', color: 'var(--text)', fontSize: 13 }}>{a.member_name || '—'}</div>
                      <div style={{ fontSize: '11px', color: C.slate }}>{a.member_number}</div>
                    </td>
                    <td style={{ padding: '8px 10px', color: C.slate, fontSize: 12 }}>{a.hospital || '—'}</td>
                    <td style={{ padding: '8px 10px', color: C.slate, fontSize: 12, whiteSpace: 'nowrap' }}>{a.confirmed_time || a.preferred_time || '—'}</td>
                    <td style={{ padding: '8px 10px', color: C.slate, fontSize: 12, maxWidth: 160, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{a.reason || '—'}</td>
                    <td style={{ padding: '8px 10px' }}><Badge status={a.status} /></td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>

        {/* Recent Alerts */}
        <div style={panel()}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 14 }}>
            <h3 style={{ margin: 0, fontSize: '14px', fontWeight: '700', color: 'var(--text)' }}>
              Recent Alerts
              {data?.open_alerts > 0 && (
                <span style={{ marginLeft: 8, background: C.red + '20', color: C.red, fontSize: '11px', fontWeight: '700', borderRadius: '8px', padding: '2px 8px' }}>
                  {data.open_alerts} unread
                </span>
              )}
            </h3>
            <Link to="/alerts" style={{ fontSize: '12px', color: C.blue, fontWeight: '600', textDecoration: 'none' }}>View all →</Link>
          </div>
          {isLoading ? <Spinner /> : recentAlerts.length === 0 ? (
            <div style={{ padding: '24px 0', textAlign: 'center', color: '#94a3b8', fontSize: 13 }}>No recent alerts.</div>
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
              {recentAlerts.map(alert => (
                <div key={alert.id} style={{ padding: '10px 12px', borderRadius: '8px', background: C.bg, border: `1px solid ${C.border}` }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: 8 }}>
                    <span style={{ fontSize: '12px', fontWeight: '700', color: C.red, textTransform: 'capitalize' }}>
                      {alert.severity} · {alert.alert_type}
                    </span>
                    <span style={{ fontSize: '10px', color: '#94a3b8', whiteSpace: 'nowrap' }}>
                      {alert.created_at ? format(new Date(alert.created_at), 'dd MMM HH:mm') : ''}
                    </span>
                  </div>
                  <p style={{ margin: '4px 0 0', fontSize: '12px', color: C.slate, lineHeight: 1.4 }}>{alert.member_name}</p>
                  <p style={{ margin: '2px 0 0', fontSize: '11px', color: '#94a3b8', lineHeight: 1.3 }}>{(alert.notes || '').slice(0, 80)}</p>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>

      {/* ── Recent Members + Recent Appointments ── */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 2fr', gap: '20px' }}>

        {/* Recent Members */}
        <div style={panel()}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 14 }}>
            <h3 style={{ margin: 0, fontSize: '14px', fontWeight: '700', color: 'var(--text)' }}>Recent Enrollments</h3>
            <Link to="/members" style={{ fontSize: '12px', color: C.blue, fontWeight: '600', textDecoration: 'none' }}>View all →</Link>
          </div>
          {isLoading ? <Spinner /> : recentMembers.length === 0 ? (
            <div style={{ padding: '24px 0', textAlign: 'center', color: '#94a3b8', fontSize: 13 }}>No members yet.</div>
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
              {recentMembers.map(m => (
                <div key={m.id} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', padding: '10px 12px', borderRadius: '8px', background: C.bg, border: `1px solid ${C.border}` }}>
                  <div>
                    <div style={{ fontSize: '13px', fontWeight: '700', color: 'var(--text)' }}>{m.full_name}</div>
                    <div style={{ fontSize: '11px', color: C.slate, marginTop: 2 }}>{m.member_number} · {m.plan_type || 'Standard'}</div>
                    {m.conditions && (
                      <div style={{ fontSize: '11px', color: C.blue, marginTop: 3, fontWeight: '600' }}>{m.conditions}</div>
                    )}
                  </div>
                  <div style={{ fontSize: '10px', color: '#94a3b8', whiteSpace: 'nowrap', textAlign: 'right' }}>
                    {m.created_at ? format(new Date(m.created_at), 'dd MMM') : '—'}
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>

        {/* Recent Appointments */}
        <div style={panel()}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 14, flexWrap: 'wrap', gap: 10 }}>
            <div>
              <h3 style={{ margin: 0, fontSize: '14px', fontWeight: '700', color: 'var(--text)' }}>Recent Appointments</h3>
              <p style={{ margin: '2px 0 0', fontSize: '12px', color: C.slate }}>Latest activity across all members</p>
            </div>
            <div style={{ display: 'flex', gap: 8 }}>
              <span style={{ fontSize: '12px', background: '#eff6ff', color: '#1d4ed8', padding: '5px 10px', borderRadius: '999px', fontWeight: '600' }}>
                This month: {data?.appts_this_month ?? 0}
              </span>
              <span style={{ fontSize: '12px', background: '#ecfdf5', color: '#047857', padding: '5px 10px', borderRadius: '999px', fontWeight: '600' }}>
                Completed: {data?.completed_appts ?? 0}
              </span>
            </div>
          </div>
          {isLoading ? <Spinner /> : (
            <AllAppointmentsTable />
          )}
        </div>
      </div>

    </div>
  );
}

/* ── sub-component: loads its own appointments ── */
function AllAppointmentsTable() {
  const { data: apptData, isLoading } = useQuery({
    queryKey: ['apptStats'],
    queryFn: () => api.get('/analytics/appointments').then(r => r.data),
    retry: false,
  });
  const recent = apptData?.recent || [];
  if (isLoading) return <Spinner />;
  if (recent.length === 0) return (
    <div style={{ padding: '24px 0', color: '#94a3b8', fontSize: 13, textAlign: 'center' }}>No appointments found.</div>
  );
  return (
    <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '13px' }}>
      <thead>
        <tr style={{ borderBottom: '2px solid #f1f5f9' }}>
          {['Member', 'Hospital', 'Condition', 'Date', 'Time', 'Reason', 'Status'].map(h => (
            <th key={h} style={{ padding: '7px 10px', textAlign: 'left', fontSize: '11px', color: '#64748b', fontWeight: '700', textTransform: 'uppercase', letterSpacing: '0.04em' }}>{h}</th>
          ))}
        </tr>
      </thead>
      <tbody>
        {recent.map(a => (
          <tr key={a.id} style={{ borderBottom: '1px solid #f8fafc' }}>
            <td style={{ padding: '9px 10px' }}>
              <div style={{ fontWeight: '600', color: 'var(--text)' }}>{a.member_name || '—'}</div>
              <div style={{ fontSize: '11px', color: '#64748b' }}>{a.member_number || '—'}</div>
            </td>
            <td style={{ padding: '9px 10px', color: '#64748b' }}>{a.hospital || '—'}</td>
            <td style={{ padding: '9px 10px', color: '#64748b' }}>{a.condition || 'General'}</td>
            <td style={{ padding: '9px 10px', color: '#64748b', whiteSpace: 'nowrap' }}>{a.appointment_date ? format(new Date(a.appointment_date), 'dd MMM yyyy') : '—'}</td>
            <td style={{ padding: '9px 10px', color: '#64748b', whiteSpace: 'nowrap' }}>{a.confirmed_time || a.preferred_time || '—'}</td>
            <td style={{ padding: '9px 10px', color: '#64748b', maxWidth: 200, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{a.reason || '—'}</td>
            <td style={{ padding: '9px 10px' }}><Badge status={a.status} /></td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}

