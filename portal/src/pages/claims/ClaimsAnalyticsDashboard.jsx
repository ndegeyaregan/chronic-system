import { useMemo, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import {
  ChartBarIcon, FunnelIcon, ArrowDownTrayIcon, XMarkIcon,
  BuildingOffice2Icon, ClipboardDocumentListIcon, RectangleStackIcon,
  UsersIcon, CalendarDaysIcon, ClockIcon, CheckCircleIcon,
} from '@heroicons/react/24/outline';
import Spinner from '../../components/UI/Spinner';
import Button from '../../components/UI/Button';
import { getClaimsAnalyticsOverview, getClaimsProviderDrilldown } from '../../api/claimsAnalysis';

/* ── shared helpers ── */
const fmtNum   = (v) => Number(v ?? 0).toLocaleString();
const fmtMoney = (v) => Number(v ?? 0).toLocaleString('en-UG', { maximumFractionDigits: 0 });
const card = {
  background: '#fff', borderRadius: '12px', padding: '18px 20px',
  boxShadow: '0 1px 4px rgba(0,0,0,0.07)',
};
const sectionTitle = {
  margin: 0, fontSize: '15px', fontWeight: 700, color: '#0f172a',
  display: 'flex', alignItems: 'center', gap: '8px',
};
const DOW_LABEL = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

const SORT_OPTIONS = [
  { value: 'total_amount', label: 'Total cost' },
  { value: 'claim_count',  label: 'Claim count' },
  { value: 'avg_amount',   label: 'Avg cost' },
  { value: 'unique_members', label: 'Unique members' },
];

/* ── MultiSelectChip filter ── */
function MultiSelect({ label, options = [], values = [], onChange, maxShown = 30 }) {
  const [open, setOpen] = useState(false);
  const [q, setQ] = useState('');
  const filtered = q
    ? options.filter((o) => o.value.toLowerCase().includes(q.toLowerCase()))
    : options;
  const shown = filtered.slice(0, maxShown);
  const has = (v) => values.includes(v);
  const toggle = (v) => onChange(has(v) ? values.filter((x) => x !== v) : [...values, v]);

  return (
    <div style={{ position: 'relative' }}>
      <button
        type="button"
        onClick={() => setOpen((o) => !o)}
        style={{
          padding: '7px 12px', borderRadius: '6px',
          border: '1px solid ' + (values.length ? 'var(--primary, #0ea5e9)' : '#e2e8f0'),
          background: values.length ? '#eff6ff' : '#fff',
          color: '#0f172a', fontSize: '13px', cursor: 'pointer',
          display: 'inline-flex', alignItems: 'center', gap: '6px',
        }}
      >
        <FunnelIcon style={{ width: 13, height: 13, color: '#64748b' }} />
        {label}
        {values.length > 0 && (
          <span style={{
            background: 'var(--primary, #0ea5e9)', color: '#fff',
            borderRadius: '10px', padding: '0 6px', fontSize: '11px', fontWeight: 700,
          }}>
            {values.length}
          </span>
        )}
      </button>
      {open && (
        <>
          <div onClick={() => setOpen(false)} style={{
            position: 'fixed', inset: 0, zIndex: 50,
          }} />
          <div style={{
            position: 'absolute', top: '100%', left: 0, marginTop: 4,
            background: '#fff', border: '1px solid #e2e8f0', borderRadius: '8px',
            boxShadow: '0 8px 24px rgba(0,0,0,0.12)',
            zIndex: 60, minWidth: 260, maxWidth: 360,
            padding: '8px', display: 'flex', flexDirection: 'column', gap: '6px',
          }}>
            <input
              autoFocus
              value={q}
              onChange={(e) => setQ(e.target.value)}
              placeholder={`Search ${label.toLowerCase()}…`}
              style={{
                padding: '6px 10px', border: '1px solid #e2e8f0', borderRadius: '6px',
                fontSize: '13px', outline: 'none',
              }}
            />
            <div style={{ maxHeight: '260px', overflowY: 'auto' }}>
              {shown.length === 0 && (
                <div style={{ padding: '10px', color: '#94a3b8', fontSize: '12px', textAlign: 'center' }}>
                  No matches
                </div>
              )}
              {shown.map((o) => (
                <label key={o.value} style={{
                  display: 'flex', alignItems: 'center', gap: '8px',
                  padding: '6px 8px', cursor: 'pointer', borderRadius: '4px',
                }}
                  onMouseEnter={(e) => e.currentTarget.style.background = '#f8fafc'}
                  onMouseLeave={(e) => e.currentTarget.style.background = 'transparent'}>
                  <input type="checkbox" checked={has(o.value)} onChange={() => toggle(o.value)}
                    style={{ cursor: 'pointer', accentColor: '#3b82f6' }} />
                  <span style={{ fontSize: '13px', flex: 1, color: '#334155' }}>{o.value}</span>
                  <span style={{ fontSize: '11px', color: '#94a3b8' }}>{fmtNum(o.count)}</span>
                </label>
              ))}
              {filtered.length > shown.length && (
                <div style={{ padding: '6px 10px', fontSize: '11px', color: '#94a3b8', textAlign: 'center' }}>
                  Showing first {shown.length} of {filtered.length} — refine search
                </div>
              )}
            </div>
            {values.length > 0 && (
              <button onClick={() => onChange([])} style={{
                padding: '6px', background: '#fee2e2', color: '#b91c1c',
                border: 'none', borderRadius: '6px', cursor: 'pointer',
                fontSize: '12px', fontWeight: 600,
              }}>
                Clear ({values.length})
              </button>
            )}
          </div>
        </>
      )}
    </div>
  );
}

/* ── Stat tile ── */
function Stat({ label, value, sub, color = '#3b82f6', Icon }) {
  return (
    <div style={{ ...card, flex: 1, minWidth: 160, display: 'flex', alignItems: 'center', gap: 14 }}>
      <div style={{
        width: 40, height: 40, borderRadius: '10px',
        background: color + '1a', display: 'flex', alignItems: 'center', justifyContent: 'center',
      }}>
        {Icon && <Icon style={{ width: 20, height: 20, color }} />}
      </div>
      <div>
        <div style={{ fontSize: '20px', fontWeight: 700, color: '#0f172a', lineHeight: 1.2 }}>{value}</div>
        <div style={{ fontSize: '12px', color: '#64748b' }}>{label}</div>
        {sub && <div style={{ fontSize: '11px', color, marginTop: 2 }}>{sub}</div>}
      </div>
    </div>
  );
}

/* ── Horizontal bar inside a table cell ── */
function MiniBar({ value, max, color = '#3b82f6' }) {
  const pct = max > 0 ? Math.max(2, Math.round((value / max) * 100)) : 0;
  return (
    <div style={{ width: 80, height: 6, background: '#f1f5f9', borderRadius: 999, overflow: 'hidden' }}>
      <div style={{ width: `${pct}%`, height: '100%', background: color }} />
    </div>
  );
}

/* ── Visit time aggregations (plain-English) ── */
const DAY_FULL = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
const PERIODS = [
  { id: 'early',     label: 'Early morning', sub: '12 AM – 6 AM',  range: [0, 6] },
  { id: 'morning',   label: 'Morning',       sub: '6 AM – 12 PM',  range: [6, 12] },
  { id: 'afternoon', label: 'Afternoon',     sub: '12 PM – 5 PM',  range: [12, 17] },
  { id: 'evening',   label: 'Evening',       sub: '5 PM – 9 PM',   range: [17, 21] },
  { id: 'night',     label: 'Night',         sub: '9 PM – 12 AM',  range: [21, 24] },
];

function hourLabel(h) {
  if (h === 0) return '12 AM';
  if (h === 12) return '12 PM';
  return h < 12 ? `${h} AM` : `${h - 12} PM`;
}

function summariseHeatmap(data) {
  const byDay  = Array(7).fill(0);
  const byHour = Array(24).fill(0);
  const byPeriod = Object.fromEntries(PERIODS.map((p) => [p.id, 0]));
  let total = 0;
  (data || []).forEach((d) => {
    const c = Number(d.claim_count || 0);
    if (d.dow >= 0 && d.dow < 7)  byDay[d.dow]  += c;
    if (d.hour >= 0 && d.hour < 24) {
      byHour[d.hour] += c;
      const p = PERIODS.find((pp) => d.hour >= pp.range[0] && d.hour < pp.range[1]);
      if (p) byPeriod[p.id] += c;
    }
    total += c;
  });
  let busiestDayIdx  = 0; byDay.forEach((v, i)  => { if (v > byDay[busiestDayIdx])   busiestDayIdx = i; });
  let busiestHourIdx = 0; byHour.forEach((v, i) => { if (v > byHour[busiestHourIdx]) busiestHourIdx = i; });
  let busiestPeriod  = PERIODS[0];
  PERIODS.forEach((p) => { if (byPeriod[p.id] > byPeriod[busiestPeriod.id]) busiestPeriod = p; });
  return { byDay, byHour, byPeriod, total, busiestDayIdx, busiestHourIdx, busiestPeriod };
}

function BarRow({ label, sub, value, max, color = '#0ea5e9', total, highlight }) {
  const pct = max > 0 ? Math.max(2, (value / max) * 100) : 0;
  const sharePct = total > 0 ? Math.round((value / total) * 100) : 0;
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '6px 0' }}>
      <div style={{ minWidth: 120 }}>
        <div style={{ fontSize: 13, fontWeight: highlight ? 700 : 500, color: '#0f172a' }}>{label}</div>
        {sub && <div style={{ fontSize: 11, color: '#94a3b8' }}>{sub}</div>}
      </div>
      <div style={{ flex: 1, height: 14, background: '#f1f5f9', borderRadius: 999, overflow: 'hidden', position: 'relative' }}>
        <div style={{ width: `${pct}%`, height: '100%', background: color, borderRadius: 999, transition: 'width 0.3s' }} />
      </div>
      <div style={{ minWidth: 110, textAlign: 'right', fontSize: 12 }}>
        <span style={{ color: '#0f172a', fontWeight: 600, fontVariantNumeric: 'tabular-nums' }}>{fmtNum(value)}</span>
        <span style={{ color: '#94a3b8', marginLeft: 6 }}>visits</span>
      </div>
      <div style={{ minWidth: 42, textAlign: 'right', fontSize: 12, color: '#475569', fontVariantNumeric: 'tabular-nums' }}>
        {sharePct}%
      </div>
    </div>
  );
}

/* ── Heatmap (DOW × HOUR) ── */
function Heatmap({ data }) {
  const grid = useMemo(() => {
    const g = Array.from({ length: 7 }, () => Array(24).fill(0));
    let max = 0;
    (data || []).forEach((d) => {
      if (d.dow >= 0 && d.dow < 7 && d.hour >= 0 && d.hour < 24) {
        g[d.dow][d.hour] = d.claim_count;
        if (d.claim_count > max) max = d.claim_count;
      }
    });
    return { g, max };
  }, [data]);
  const colour = (v) => {
    if (!v) return '#f8fafc';
    const t = v / grid.max;
    // light to deep blue
    const r = Math.round(239 - 200 * t);
    const g = Math.round(246 - 150 * t);
    const b = Math.round(255 - 50 * t);
    return `rgb(${r},${g},${b})`;
  };
  return (
    <div style={{ overflowX: 'auto' }}>
      <table style={{ borderCollapse: 'collapse', fontSize: '10px' }}>
        <thead>
          <tr>
            <th></th>
            {Array.from({ length: 24 }, (_, h) => (
              <th key={h} style={{ padding: '2px 3px', color: '#94a3b8', fontWeight: 500, fontSize: '10px' }}>
                {h}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {grid.g.map((row, dow) => (
            <tr key={dow}>
              <td style={{ padding: '2px 6px', fontSize: '11px', color: '#475569', fontWeight: 600 }}>
                {DOW_LABEL[dow]}
              </td>
              {row.map((v, h) => (
                <td key={h} title={`${DOW_LABEL[dow]} ${h}:00 — ${fmtNum(v)} claims`}
                  style={{
                    width: 22, height: 22, background: colour(v),
                    border: '1px solid #fff', textAlign: 'center',
                    fontSize: '9px', color: v > grid.max * 0.5 ? '#fff' : '#475569',
                  }}>
                  {v > 0 ? (v >= 1000 ? `${(v / 1000).toFixed(0)}k` : v) : ''}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

/* ── Monthly trend bar chart ── */
function MonthlyTrend({ data }) {
  const max = useMemo(() => Math.max(...(data || []).map((d) => Number(d.total_amount || 0)), 1), [data]);
  if (!data || !data.length) return <div style={{ padding: 20, textAlign: 'center', color: '#94a3b8', fontSize: 12 }}>No data</div>;
  return (
    <div style={{ display: 'flex', gap: 4, alignItems: 'flex-end', overflowX: 'auto', padding: '4px 0', height: 180 }}>
      {data.map((d) => {
        const h = Math.max(4, Math.round((Number(d.total_amount) / max) * 160));
        return (
          <div key={d.month} title={`${d.month}: ${fmtNum(d.claim_count)} claims, UGX ${fmtMoney(d.total_amount)}`}
            style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4, minWidth: 36 }}>
            <div style={{ width: 22, height: h, background: 'linear-gradient(to top, #0ea5e9, #38bdf8)',
              borderRadius: '4px 4px 0 0' }} />
            <div style={{ fontSize: '10px', color: '#64748b', writingMode: 'vertical-rl', transform: 'rotate(180deg)' }}>
              {d.month}
            </div>
          </div>
        );
      })}
    </div>
  );
}

/* ── Provider drill-down modal ── */
function ProviderDrilldown({ uploadIds, provider, filters, onClose }) {
  const { data, isLoading } = useQuery({
    queryKey: ['claims-provider', uploadIds, provider, filters],
    queryFn: () => getClaimsProviderDrilldown(uploadIds, provider, filters).then((r) => r.data),
    enabled: !!provider && uploadIds?.length > 0,
  });
  return (
    <div onClick={onClose} style={{
      position: 'fixed', inset: 0, background: 'rgba(15,23,42,0.5)',
      display: 'flex', alignItems: 'flex-start', justifyContent: 'center', zIndex: 200, padding: 30, overflowY: 'auto',
    }}>
      <div onClick={(e) => e.stopPropagation()} style={{
        background: '#fff', borderRadius: 12, padding: 24, maxWidth: 900, width: '100%',
        display: 'flex', flexDirection: 'column', gap: 16, boxShadow: '0 20px 50px rgba(0,0,0,0.2)',
      }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: 12 }}>
          <div>
            <h3 style={{ margin: 0, fontSize: 18, fontWeight: 700, color: '#0f172a' }}>{provider}</h3>
            <p style={{ margin: '2px 0 0', fontSize: 12, color: '#64748b' }}>Provider drill-down</p>
          </div>
          <button onClick={onClose} style={{
            background: 'none', border: 'none', cursor: 'pointer', color: '#94a3b8', padding: 4,
          }}>
            <XMarkIcon style={{ width: 22, height: 22 }} />
          </button>
        </div>
        {isLoading || !data ? (
          <div style={{ padding: 40, display: 'flex', justifyContent: 'center' }}><Spinner /></div>
        ) : (
          <>
            <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
              {data.summary.map((s, i) => (
                <span key={i} style={{
                  padding: '4px 10px', borderRadius: 999, background: '#eff6ff',
                  color: '#1d4ed8', fontSize: 12, fontWeight: 600,
                }}>
                  {s.provider_type || 'Unspecified'}: {fmtNum(s.claim_count)} claims · UGX {fmtMoney(s.total_amount)} · {fmtNum(s.unique_members)} members
                </span>
              ))}
            </div>

            <div>
              <h4 style={{ ...sectionTitle, fontSize: 14 }}>
                <ClipboardDocumentListIcon style={{ width: 15, height: 15, color: '#3b82f6' }} />
                Top 5 diagnoses at this facility
              </h4>
              <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 13, marginTop: 8 }}>
                <thead><tr style={{ background: '#f8fafc', borderBottom: '2px solid #e2e8f0' }}>
                  {['Diagnosis', 'Code', 'Claims', 'Members', 'Total cost'].map((h) => (
                    <th key={h} style={{ padding: '6px 10px', textAlign: 'left', fontSize: 11,
                      color: '#64748b', textTransform: 'uppercase', letterSpacing: '0.04em' }}>
                      {h}
                    </th>
                  ))}
                </tr></thead>
                <tbody>
                  {data.top_diagnoses.map((d, i) => (
                    <tr key={i} style={{ borderBottom: '1px solid #f1f5f9' }}>
                      <td style={{ padding: '6px 10px', color: '#0f172a' }}>{d.diagnosis}</td>
                      <td style={{ padding: '6px 10px', color: '#64748b', fontFamily: 'monospace', fontSize: 11 }}>{d.diagnosis_code || '—'}</td>
                      <td style={{ padding: '6px 10px', color: '#475569' }}>{fmtNum(d.claim_count)}</td>
                      <td style={{ padding: '6px 10px', color: '#475569' }}>{fmtNum(d.unique_members)}</td>
                      <td style={{ padding: '6px 10px', color: '#475569', textAlign: 'right' }}>UGX {fmtMoney(d.total_amount)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>

            <div>
              <h4 style={{ ...sectionTitle, fontSize: 14 }}>
                <RectangleStackIcon style={{ width: 15, height: 15, color: '#10b981' }} />
                Top schemes at this facility
              </h4>
              <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 13, marginTop: 8 }}>
                <thead><tr style={{ background: '#f8fafc', borderBottom: '2px solid #e2e8f0' }}>
                  {['Scheme', 'Claims', 'Members', 'Total cost'].map((h) => (
                    <th key={h} style={{ padding: '6px 10px', textAlign: 'left', fontSize: 11,
                      color: '#64748b', textTransform: 'uppercase', letterSpacing: '0.04em' }}>
                      {h}
                    </th>
                  ))}
                </tr></thead>
                <tbody>
                  {data.top_schemes.map((d, i) => (
                    <tr key={i} style={{ borderBottom: '1px solid #f1f5f9' }}>
                      <td style={{ padding: '6px 10px', color: '#0f172a', fontWeight: 500 }}>{d.scheme}</td>
                      <td style={{ padding: '6px 10px', color: '#475569' }}>{fmtNum(d.claim_count)}</td>
                      <td style={{ padding: '6px 10px', color: '#475569' }}>{fmtNum(d.unique_members)}</td>
                      <td style={{ padding: '6px 10px', color: '#475569', textAlign: 'right' }}>UGX {fmtMoney(d.total_amount)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>

            {/* Peak visit hours at this provider */}
            {data.heatmap && data.heatmap.length > 0 && (() => {
              const v = summariseHeatmap(data.heatmap);
              const maxHour = Math.max(...v.byHour, 1);
              const maxDay  = Math.max(...v.byDay, 1);
              return (
                <div>
                  <h4 style={{ ...sectionTitle, fontSize: 14 }}>
                    <ClockIcon style={{ width: 15, height: 15, color: '#dc2626' }} />
                    Peak visit hours at this facility
                  </h4>
                  <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: 8, marginTop: 8 }}>
                    <div style={{ padding: '10px 12px', background: '#eff6ff', borderRadius: 8 }}>
                      <div style={{ fontSize: 10, color: '#64748b', textTransform: 'uppercase', letterSpacing: '0.05em', fontWeight: 600 }}>Busiest day</div>
                      <div style={{ fontSize: 18, fontWeight: 700, color: '#0ea5e9', marginTop: 2 }}>{DAY_FULL[v.busiestDayIdx]}</div>
                      <div style={{ fontSize: 11, color: '#475569' }}>{fmtNum(v.byDay[v.busiestDayIdx])} visits</div>
                    </div>
                    <div style={{ padding: '10px 12px', background: '#f0fdf4', borderRadius: 8 }}>
                      <div style={{ fontSize: 10, color: '#64748b', textTransform: 'uppercase', letterSpacing: '0.05em', fontWeight: 600 }}>Busiest hour</div>
                      <div style={{ fontSize: 18, fontWeight: 700, color: '#16a34a', marginTop: 2 }}>{hourLabel(v.busiestHourIdx)}</div>
                      <div style={{ fontSize: 11, color: '#475569' }}>{fmtNum(v.byHour[v.busiestHourIdx])} visits</div>
                    </div>
                    <div style={{ padding: '10px 12px', background: '#fef2f2', borderRadius: 8 }}>
                      <div style={{ fontSize: 10, color: '#64748b', textTransform: 'uppercase', letterSpacing: '0.05em', fontWeight: 600 }}>Peak time of day</div>
                      <div style={{ fontSize: 18, fontWeight: 700, color: '#dc2626', marginTop: 2 }}>{v.busiestPeriod.label}</div>
                      <div style={{ fontSize: 11, color: '#475569' }}>{v.busiestPeriod.sub}</div>
                    </div>
                  </div>

                  <p style={{ margin: '14px 0 4px', fontSize: 12, color: '#64748b' }}>Hour of day</p>
                  <div style={{ display: 'flex', alignItems: 'flex-end', gap: 2, height: 110 }}>
                    {v.byHour.map((c, h) => {
                      const pct = (c / maxHour) * 100;
                      const peak = h === v.busiestHourIdx;
                      return (
                        <div key={h} title={`${hourLabel(h)} — ${fmtNum(c)} visits`}
                          style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 3, minWidth: 0 }}>
                          <div style={{ width: '100%', height: `${Math.max(2, pct)}%`,
                            background: peak ? '#dc2626' : '#fca5a5', borderRadius: '3px 3px 0 0' }} />
                          <div style={{ fontSize: 8, color: peak ? '#dc2626' : '#94a3b8',
                            fontWeight: peak ? 700 : 400, whiteSpace: 'nowrap' }}>
                            {h % 3 === 0 ? hourLabel(h).replace(' ', '') : ''}
                          </div>
                        </div>
                      );
                    })}
                  </div>

                  <p style={{ margin: '14px 0 4px', fontSize: 12, color: '#64748b' }}>Day of week</p>
                  <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
                    {[1,2,3,4,5,6,0].map((dow) => {
                      const c = v.byDay[dow];
                      const pct = (c / maxDay) * 100;
                      const peak = dow === v.busiestDayIdx;
                      return (
                        <div key={dow} style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 12 }}>
                          <span style={{ minWidth: 80, color: '#475569', fontWeight: peak ? 700 : 500 }}>{DAY_FULL[dow]}</span>
                          <div style={{ flex: 1, height: 10, background: '#f1f5f9', borderRadius: 999, overflow: 'hidden' }}>
                            <div style={{ width: `${Math.max(2, pct)}%`, height: '100%',
                              background: peak ? '#0ea5e9' : '#bae6fd' }} />
                          </div>
                          <span style={{ minWidth: 70, textAlign: 'right', color: '#0f172a', fontVariantNumeric: 'tabular-nums' }}>{fmtNum(c)}</span>
                        </div>
                      );
                    })}
                  </div>
                </div>
              );
            })()}

            <div>
              <h4 style={{ ...sectionTitle, fontSize: 14 }}>
                <UsersIcon style={{ width: 15, height: 15, color: '#16a34a' }} />
                Top frequent members at this facility
              </h4>
              <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 13, marginTop: 8 }}>
                <thead><tr style={{ background: '#f8fafc', borderBottom: '2px solid #e2e8f0' }}>
                  {['Member', 'No.', 'Scheme', 'Visits', 'Total cost', 'Last visit'].map((h) => (
                    <th key={h} style={{ padding: '6px 10px', textAlign: 'left', fontSize: 11,
                      color: '#64748b', textTransform: 'uppercase', letterSpacing: '0.04em' }}>
                      {h}
                    </th>
                  ))}
                </tr></thead>
                <tbody>
                  {data.top_members.map((d, i) => (
                    <tr key={i} style={{ borderBottom: '1px solid #f1f5f9' }}>
                      <td style={{ padding: '6px 10px', color: '#0f172a' }}>{d.member_name || '—'}</td>
                      <td style={{ padding: '6px 10px', color: '#64748b', fontFamily: 'monospace', fontSize: 11 }}>{d.member_no}</td>
                      <td style={{ padding: '6px 10px', color: '#475569' }}>{d.scheme || '—'}</td>
                      <td style={{ padding: '6px 10px', color: '#475569' }}>{fmtNum(d.visit_count)}</td>
                      <td style={{ padding: '6px 10px', color: '#475569', textAlign: 'right' }}>UGX {fmtMoney(d.total_amount)}</td>
                      <td style={{ padding: '6px 10px', color: '#64748b', fontSize: 12 }}>
                        {d.last_visit ? new Date(d.last_visit).toLocaleDateString('en-ZA') : '—'}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </>
        )}
      </div>
    </div>
  );
}

/* ══════════════════════════════════════════════════════════════════════ */
export default function ClaimsAnalyticsDashboard({ uploadIds, uploads = [] }) {
  const [from, setFrom]               = useState('');
  const [to, setTo]                   = useState('');
  const [claimTypes, setClaimTypes]   = useState([]);
  const [illnessTypes, setIllnessTypes] = useState([]);
  const [relations, setRelations]     = useState([]);
  const [schemes, setSchemes]         = useState([]);
  const [statuses, setStatuses]       = useState([]);
  const [sortBy, setSortBy]           = useState('total_amount');
  const [drilldownProvider, setDrilldownProvider] = useState(null);
  const [activeTab, setActiveTab] = useState('providers');

  const filters = useMemo(() => ({
    from: from || undefined,
    to:   to   || undefined,
    claim_type:   claimTypes,
    illness_type: illnessTypes,
    relation:     relations,
    scheme:       schemes,
    status:       statuses,
  }), [from, to, claimTypes, illnessTypes, relations, schemes, statuses]);

  // Get combined stats from all selected uploads
  const uploadsInfo = useMemo(() => {
    const selected = uploads.filter((u) => uploadIds.includes(u.id));
    const totalRows = selected.reduce((sum, u) => sum + (u.row_count || 0), 0);
    const filenames = selected.map((u) => u.filename).join(', ');
    return { totalRows, filenames, count: selected.length };
  }, [uploadIds, uploads]);

  const { data, isLoading, isFetching } = useQuery({
    queryKey: ['claims-overview', uploadIds, filters],
    queryFn: () => getClaimsAnalyticsOverview(uploadIds, filters).then((r) => r.data),
    enabled: uploadIds?.length > 0 && uploads.filter((u) => uploadIds.includes(u.id)).some((u) => u.status === 'ready'),
    keepPreviousData: true,
  });

  const clearFilters = () => {
    setFrom(''); setTo(''); setClaimTypes([]); setIllnessTypes([]);
    setRelations([]); setSchemes([]); setStatuses([]);
  };
  const hasFilters = from || to || claimTypes.length || illnessTypes.length ||
                     relations.length || schemes.length || statuses.length;

  const sortedProviders = useMemo(() => {
    if (!data?.top_providers) return [];
    const arr = [...data.top_providers];
    arr.sort((a, b) => Number(b[sortBy] || 0) - Number(a[sortBy] || 0));
    return arr;
  }, [data, sortBy]);

  const exportProvidersCSV = () => {
    const header = ['Rank', 'Provider', 'Type', 'Claims', 'Total Cost (UGX)', 'Avg Cost (UGX)', 'Members', 'Schemes'];
    const rows = sortedProviders.map((p, i) => [
      i + 1,
      `"${(p.provider || '').replace(/"/g, '""')}"`,
      p.provider_type || '',
      p.claim_count, p.total_amount, p.avg_amount,
      p.unique_members, p.unique_schemes,
    ]);
    const csv = [header, ...rows].map((r) => r.join(',')).join('\n');
    const a = document.createElement('a');
    a.href = URL.createObjectURL(new Blob([csv], { type: 'text/csv' }));
    a.download = `providers-ranking-${Date.now()}.csv`;
    a.click();
  };

  if (!uploadIds?.length || !uploads.filter((u) => uploadIds.includes(u.id)).some((u) => u.status === 'ready')) return null;
  if (isLoading || !data) {
    return (
      <div style={{ ...card, padding: 40, display: 'flex', justifyContent: 'center' }}><Spinner /></div>
    );
  }

  const s = data.summary;
  const maxProviderAmount = Math.max(...sortedProviders.map((p) => Number(p.total_amount || 0)), 1);
  const maxDiagnosisCount = Math.max(...data.top_diagnoses.map((d) => Number(d.claim_count || 0)), 1);
  const maxSchemeAmount   = Math.max(...data.top_schemes.map((d) => Number(d.total_amount || 0)), 1);

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 20 }}>
      {/* ── Filters ── */}
      <div style={{ ...card, padding: '14px 16px' }}>
        <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap', alignItems: 'center' }}>
          <span style={{ fontSize: 12, color: '#64748b', fontWeight: 700, textTransform: 'uppercase', letterSpacing: '0.04em' }}>
            Filters
          </span>
          <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
            <label style={{ fontSize: 12, color: '#475569' }}>From</label>
            <input type="date" value={from} onChange={(e) => setFrom(e.target.value)}
              style={{ padding: '6px 10px', borderRadius: 6, border: '1px solid #e2e8f0', fontSize: 13 }} />
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
            <label style={{ fontSize: 12, color: '#475569' }}>To</label>
            <input type="date" value={to} onChange={(e) => setTo(e.target.value)}
              style={{ padding: '6px 10px', borderRadius: 6, border: '1px solid #e2e8f0', fontSize: 13 }} />
          </div>
          <MultiSelect label="ClaimType"   options={data.filter_options.claim_types}   values={claimTypes}   onChange={setClaimTypes} />
          <MultiSelect label="IllnessType" options={data.filter_options.illness_types} values={illnessTypes} onChange={setIllnessTypes} />
          <MultiSelect label="Relation"    options={data.filter_options.relations}     values={relations}    onChange={setRelations} />
          <MultiSelect label="Scheme"      options={data.filter_options.schemes}       values={schemes}      onChange={setSchemes} />
          <MultiSelect label="Status"      options={data.filter_options.statuses}      values={statuses}     onChange={setStatuses} />
          {hasFilters && (
            <button onClick={clearFilters} style={{
              padding: '7px 10px', borderRadius: 6, border: '1px solid #fca5a5',
              background: '#fff', color: '#ef4444', fontSize: 13, cursor: 'pointer',
              display: 'inline-flex', alignItems: 'center', gap: 4,
            }}>
              <XMarkIcon style={{ width: 13, height: 13 }} /> Clear all
            </button>
          )}
          <span style={{ marginLeft: 'auto', fontSize: 12, color: '#94a3b8' }}>
            {isFetching ? 'Loading…' : `${fmtNum(s.total_claims)} matching claims`}
          </span>
        </div>
      </div>

      {/* ── Summary tiles ── */}
      <div style={{ display: 'flex', gap: 12, flexWrap: 'wrap' }}>
        <Stat label="Total claims"   value={fmtNum(s.total_claims)} color="#3b82f6" Icon={ClipboardDocumentListIcon}
          sub={s.first_date && s.last_date ? `${s.first_date.slice(0,10)} → ${s.last_date.slice(0,10)}` : ''} />
        <Stat label="Total cost"     value={`UGX ${fmtMoney(s.total_amount)}`} color="#dc2626" Icon={ChartBarIcon}
          sub={`Avg UGX ${fmtMoney(s.avg_amount)}`} />
        <Stat label="Total payable"  value={`UGX ${fmtMoney(s.total_payable)}`} color="#16a34a" Icon={CheckCircleIcon} />
        <Stat label="Providers"      value={fmtNum(s.unique_providers)} color="#0ea5e9" Icon={BuildingOffice2Icon} />
        <Stat label="Members"        value={fmtNum(s.unique_members)}   color="#16a34a" Icon={UsersIcon} />
        <Stat label="Schemes"        value={fmtNum(s.unique_schemes)}   color="#0ea5e9" Icon={RectangleStackIcon} />
      </div>

      {/* ── Tab navigation ── */}
      {(() => {
        const TABS = [
          { id: 'providers',  label: 'Provider ranking', Icon: BuildingOffice2Icon,
            sub: `${fmtNum(s.unique_providers)} institutions` },
          { id: 'diagnoses',  label: 'Top diagnoses',    Icon: ClipboardDocumentListIcon,
            sub: 'Top 10 overall' },
          { id: 'schemes',    label: 'Top schemes',      Icon: RectangleStackIcon,
            sub: `${fmtNum(s.unique_schemes)} schemes` },
          { id: 'times',      label: 'Visit times',      Icon: ClockIcon,
            sub: 'Busiest days & hours' },
          { id: 'monthly',    label: 'Monthly trend',    Icon: CalendarDaysIcon,
            sub: 'Cost over time' },
          { id: 'breakdowns', label: 'Breakdowns',       Icon: ChartBarIcon,
            sub: 'Status · illness · relation' },
        ];
        return (
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 10 }}>
            {TABS.map((t) => {
              const active = activeTab === t.id;
              return (
                <button
                  key={t.id}
                  type="button"
                  onClick={() => setActiveTab(t.id)}
                  style={{
                    display: 'flex', alignItems: 'center', gap: 12, padding: '12px 14px',
                    borderRadius: 10, cursor: 'pointer', textAlign: 'left',
                    background: active ? 'var(--primary, #0ea5e9)' : '#fff',
                    color: active ? '#fff' : '#0f172a',
                    border: '1px solid ' + (active ? 'var(--primary, #0ea5e9)' : '#e2e8f0'),
                    boxShadow: active ? '0 4px 12px rgba(14,165,233,0.25)' : '0 1px 2px rgba(0,0,0,0.04)',
                    transition: 'all 0.15s',
                  }}
                  onMouseEnter={(e) => { if (!active) e.currentTarget.style.borderColor = '#0ea5e9'; }}
                  onMouseLeave={(e) => { if (!active) e.currentTarget.style.borderColor = '#e2e8f0'; }}
                >
                  <div style={{
                    width: 36, height: 36, borderRadius: 8, flexShrink: 0,
                    background: active ? 'rgba(255,255,255,0.2)' : '#eff6ff',
                    display: 'flex', alignItems: 'center', justifyContent: 'center',
                  }}>
                    <t.Icon style={{ width: 18, height: 18, color: active ? '#fff' : '#0ea5e9' }} />
                  </div>
                  <div style={{ minWidth: 0 }}>
                    <div style={{ fontSize: 13, fontWeight: 700, lineHeight: 1.2 }}>{t.label}</div>
                    <div style={{ fontSize: 11, opacity: 0.8, marginTop: 2,
                      whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                      {t.sub}
                    </div>
                  </div>
                </button>
              );
            })}
          </div>
        );
      })()}

      {/* ── Provider ranking ── */}
      {activeTab === 'providers' && (
      <div style={card}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12, flexWrap: 'wrap', gap: 8 }}>
          <h3 style={sectionTitle}>
            <BuildingOffice2Icon style={{ width: 18, height: 18, color: '#0ea5e9' }} />
            Provider ranking ({fmtNum(sortedProviders.length)} of {fmtNum(s.unique_providers)})
          </h3>
          <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
            <label style={{ fontSize: 12, color: '#64748b' }}>Sort by</label>
            <select value={sortBy} onChange={(e) => setSortBy(e.target.value)}
              style={{ padding: '6px 10px', borderRadius: 6, border: '1px solid #e2e8f0', fontSize: 13 }}>
              {SORT_OPTIONS.map((o) => <option key={o.value} value={o.value}>{o.label}</option>)}
            </select>
            <Button variant="secondary" onClick={exportProvidersCSV}
              style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 12 }}>
              <ArrowDownTrayIcon style={{ width: 13, height: 13 }} /> Export CSV
            </Button>
          </div>
        </div>
        <div style={{ overflowX: 'auto', maxHeight: 540, overflowY: 'auto' }}>
          <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 13 }}>
            <thead style={{ position: 'sticky', top: 0, background: '#f8fafc', zIndex: 1 }}>
              <tr style={{ borderBottom: '2px solid #e2e8f0' }}>
                {['#', 'Provider', 'Type', 'Claims', 'Total cost', '', 'Avg cost', 'Members', 'Schemes'].map((h, i) => (
                  <th key={i} style={{ padding: '8px 10px', textAlign: i >= 3 && i !== 5 ? 'right' : 'left',
                    fontSize: 11, color: '#64748b', textTransform: 'uppercase', letterSpacing: '0.04em' }}>
                    {h}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {sortedProviders.map((p, i) => (
                <tr key={p.provider + i} style={{ borderBottom: '1px solid #f1f5f9', cursor: 'pointer' }}
                  onClick={() => setDrilldownProvider(p.provider)}
                  onMouseEnter={(e) => e.currentTarget.style.background = '#f8fafc'}
                  onMouseLeave={(e) => e.currentTarget.style.background = 'transparent'}>
                  <td style={{ padding: '7px 10px', color: '#94a3b8', fontVariantNumeric: 'tabular-nums' }}>{i + 1}</td>
                  <td style={{ padding: '7px 10px', fontWeight: 600, color: '#0f172a',
                    maxWidth: 320, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}
                    title={p.provider}>
                    {p.provider}
                  </td>
                  <td style={{ padding: '7px 10px' }}>
                    {p.provider_type && (
                      <span style={{
                        padding: '2px 8px', borderRadius: 10, background: '#eff6ff', color: '#1d4ed8',
                        fontSize: 11, fontWeight: 600,
                      }}>{p.provider_type}</span>
                    )}
                  </td>
                  <td style={{ padding: '7px 10px', textAlign: 'right', color: '#475569', fontVariantNumeric: 'tabular-nums' }}>{fmtNum(p.claim_count)}</td>
                  <td style={{ padding: '7px 10px', textAlign: 'right', color: '#0f172a', fontWeight: 600, fontVariantNumeric: 'tabular-nums' }}>UGX {fmtMoney(p.total_amount)}</td>
                  <td style={{ padding: '7px 10px' }}><MiniBar value={Number(p.total_amount)} max={maxProviderAmount} color="#0ea5e9" /></td>
                  <td style={{ padding: '7px 10px', textAlign: 'right', color: '#475569', fontVariantNumeric: 'tabular-nums' }}>UGX {fmtMoney(p.avg_amount)}</td>
                  <td style={{ padding: '7px 10px', textAlign: 'right', color: '#475569', fontVariantNumeric: 'tabular-nums' }}>{fmtNum(p.unique_members)}</td>
                  <td style={{ padding: '7px 10px', textAlign: 'right', color: '#475569', fontVariantNumeric: 'tabular-nums' }}>{fmtNum(p.unique_schemes)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <p style={{ marginTop: 8, fontSize: 11, color: '#94a3b8' }}>
          Click any row to drill into top diagnoses, schemes and frequent members at that facility.
        </p>
      </div>
      )}

      {/* ── Top diagnoses tab ── */}
      {activeTab === 'diagnoses' && (
        <div style={card}>
          <h3 style={{ ...sectionTitle, marginBottom: 10 }}>
            <ClipboardDocumentListIcon style={{ width: 18, height: 18, color: '#3b82f6' }} />
            Top 10 diagnoses overall
          </h3>
          <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 13 }}>
            <thead><tr style={{ background: '#f8fafc', borderBottom: '2px solid #e2e8f0' }}>
              {['Diagnosis', 'Claims', '', 'Members'].map((h, i) => (
                <th key={i} style={{ padding: '6px 10px', textAlign: i === 1 || i === 3 ? 'right' : 'left',
                  fontSize: 11, color: '#64748b', textTransform: 'uppercase', letterSpacing: '0.04em' }}>{h}</th>
              ))}
            </tr></thead>
            <tbody>
              {data.top_diagnoses.map((d, i) => (
                <tr key={i} style={{ borderBottom: '1px solid #f1f5f9' }}>
                  <td style={{ padding: '6px 10px', color: '#0f172a',
                    maxWidth: 260, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}
                    title={d.diagnosis}>
                    <div style={{ fontWeight: 500 }}>{d.diagnosis}</div>
                    {d.diagnosis_code && <div style={{ fontSize: 10, color: '#94a3b8', fontFamily: 'monospace' }}>{d.diagnosis_code}</div>}
                  </td>
                  <td style={{ padding: '6px 10px', textAlign: 'right', color: '#475569', fontWeight: 600, fontVariantNumeric: 'tabular-nums' }}>{fmtNum(d.claim_count)}</td>
                  <td style={{ padding: '6px 10px' }}><MiniBar value={d.claim_count} max={maxDiagnosisCount} color="#3b82f6" /></td>
                  <td style={{ padding: '6px 10px', textAlign: 'right', color: '#64748b', fontVariantNumeric: 'tabular-nums' }}>{fmtNum(d.unique_members)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {/* ── Top schemes tab ── */}
      {activeTab === 'schemes' && (
        <div style={card}>
          <h3 style={{ ...sectionTitle, marginBottom: 10 }}>
            <RectangleStackIcon style={{ width: 18, height: 18, color: '#10b981' }} />
            Top utilising schemes
          </h3>
          <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 13 }}>
            <thead><tr style={{ background: '#f8fafc', borderBottom: '2px solid #e2e8f0' }}>
              {['Scheme', 'Claims', 'Total cost', '', 'Members'].map((h, i) => (
                <th key={i} style={{ padding: '6px 10px', textAlign: i >= 1 && i !== 3 ? 'right' : 'left',
                  fontSize: 11, color: '#64748b', textTransform: 'uppercase', letterSpacing: '0.04em' }}>{h}</th>
              ))}
            </tr></thead>
            <tbody>
              {data.top_schemes.map((d, i) => (
                <tr key={i} style={{ borderBottom: '1px solid #f1f5f9' }}>
                  <td style={{ padding: '6px 10px', color: '#0f172a', fontWeight: 500,
                    maxWidth: 220, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}
                    title={d.scheme}>
                    {d.scheme}
                  </td>
                  <td style={{ padding: '6px 10px', textAlign: 'right', color: '#475569', fontVariantNumeric: 'tabular-nums' }}>{fmtNum(d.claim_count)}</td>
                  <td style={{ padding: '6px 10px', textAlign: 'right', color: '#0f172a', fontWeight: 600, fontVariantNumeric: 'tabular-nums' }}>UGX {fmtMoney(d.total_amount)}</td>
                  <td style={{ padding: '6px 10px' }}><MiniBar value={Number(d.total_amount)} max={maxSchemeAmount} color="#10b981" /></td>
                  <td style={{ padding: '6px 10px', textAlign: 'right', color: '#64748b', fontVariantNumeric: 'tabular-nums' }}>{fmtNum(d.unique_members)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {/* ── Visit times tab — plain-English breakdown ── */}
      {activeTab === 'times' && (() => {
        const v = summariseHeatmap(data.heatmap);
        const maxDay  = Math.max(...v.byDay, 1);
        const maxHour = Math.max(...v.byHour, 1);
        const maxPeriod = Math.max(...Object.values(v.byPeriod), 1);
        return (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
            {/* Headline insights */}
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: 12 }}>
              <div style={{ ...card, background: 'linear-gradient(135deg,#0ea5e9 0%,#0284c7 100%)', color: '#fff' }}>
                <div style={{ fontSize: 11, opacity: 0.85, textTransform: 'uppercase', letterSpacing: '0.05em', fontWeight: 600 }}>
                  Busiest day
                </div>
                <div style={{ fontSize: 24, fontWeight: 700, marginTop: 6 }}>{DAY_FULL[v.busiestDayIdx]}</div>
                <div style={{ fontSize: 13, marginTop: 4, opacity: 0.9 }}>
                  {fmtNum(v.byDay[v.busiestDayIdx])} visits ({Math.round((v.byDay[v.busiestDayIdx] / v.total) * 100)}% of all claims)
                </div>
              </div>
              <div style={{ ...card, background: 'linear-gradient(135deg,#16a34a 0%,#15803d 100%)', color: '#fff' }}>
                <div style={{ fontSize: 11, opacity: 0.85, textTransform: 'uppercase', letterSpacing: '0.05em', fontWeight: 600 }}>
                  Busiest hour
                </div>
                <div style={{ fontSize: 24, fontWeight: 700, marginTop: 6 }}>{hourLabel(v.busiestHourIdx)}</div>
                <div style={{ fontSize: 13, marginTop: 4, opacity: 0.9 }}>
                  {fmtNum(v.byHour[v.busiestHourIdx])} visits across the week
                </div>
              </div>
              <div style={{ ...card, background: 'linear-gradient(135deg,#dc2626 0%,#b91c1c 100%)', color: '#fff' }}>
                <div style={{ fontSize: 11, opacity: 0.85, textTransform: 'uppercase', letterSpacing: '0.05em', fontWeight: 600 }}>
                  Peak time of day
                </div>
                <div style={{ fontSize: 24, fontWeight: 700, marginTop: 6 }}>{v.busiestPeriod.label}</div>
                <div style={{ fontSize: 13, marginTop: 4, opacity: 0.9 }}>
                  {v.busiestPeriod.sub} · {fmtNum(v.byPeriod[v.busiestPeriod.id])} visits
                </div>
              </div>
            </div>

            {/* By time of day periods */}
            <div style={card}>
              <h3 style={{ ...sectionTitle, marginBottom: 4 }}>
                <ClockIcon style={{ width: 18, height: 18, color: '#0ea5e9' }} />
                When during the day do members visit?
              </h3>
              <p style={{ margin: '0 0 12px', fontSize: 12, color: '#64748b' }}>
                Visits grouped into easy-to-read parts of the day.
              </p>
              {PERIODS.map((p) => (
                <BarRow
                  key={p.id}
                  label={p.label}
                  sub={p.sub}
                  value={v.byPeriod[p.id]}
                  max={maxPeriod}
                  total={v.total}
                  color={p.id === v.busiestPeriod.id ? '#0ea5e9' : '#93c5fd'}
                  highlight={p.id === v.busiestPeriod.id}
                />
              ))}
            </div>

            {/* By day of week */}
            <div style={card}>
              <h3 style={{ ...sectionTitle, marginBottom: 4 }}>
                <CalendarDaysIcon style={{ width: 18, height: 18, color: '#16a34a' }} />
                Which days of the week are busiest?
              </h3>
              <p style={{ margin: '0 0 12px', fontSize: 12, color: '#64748b' }}>
                Total visits across the dataset, grouped by the day of the week.
              </p>
              {[1, 2, 3, 4, 5, 6, 0].map((dow) => (
                <BarRow
                  key={dow}
                  label={DAY_FULL[dow]}
                  value={v.byDay[dow]}
                  max={maxDay}
                  total={v.total}
                  color={dow === v.busiestDayIdx ? '#16a34a' : '#86efac'}
                  highlight={dow === v.busiestDayIdx}
                />
              ))}
            </div>

            {/* By hour of day */}
            <div style={card}>
              <h3 style={{ ...sectionTitle, marginBottom: 4 }}>
                <ClockIcon style={{ width: 18, height: 18, color: '#dc2626' }} />
                What hour of the day is busiest?
              </h3>
              <p style={{ margin: '0 0 12px', fontSize: 12, color: '#64748b' }}>
                Visits by clock hour — the tallest bars are the times members most often arrive at facilities.
              </p>
              <div style={{ display: 'flex', alignItems: 'flex-end', gap: 3, height: 180, paddingTop: 8 }}>
                {v.byHour.map((count, h) => {
                  const pct = (count / maxHour) * 100;
                  const isPeak = h === v.busiestHourIdx;
                  return (
                    <div key={h} title={`${hourLabel(h)} — ${fmtNum(count)} visits`}
                      style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4, minWidth: 0 }}>
                      <div style={{
                        width: '100%', height: `${Math.max(2, pct)}%`,
                        background: isPeak ? '#dc2626' : '#fca5a5',
                        borderRadius: '4px 4px 0 0',
                        transition: 'background 0.2s',
                      }} />
                      <div style={{ fontSize: 9, color: isPeak ? '#dc2626' : '#94a3b8',
                        fontWeight: isPeak ? 700 : 400, transform: 'rotate(-45deg)', transformOrigin: 'top right',
                        whiteSpace: 'nowrap', marginTop: 4 }}>
                        {h % 2 === 0 ? hourLabel(h) : ''}
                      </div>
                    </div>
                  );
                })}
              </div>
              <p style={{ marginTop: 18, fontSize: 12, color: '#475569' }}>
                Most members arrive at facilities around <strong style={{ color: '#dc2626' }}>{hourLabel(v.busiestHourIdx)}</strong>.
                Plan staffing and member-engagement campaigns around peak hours.
              </p>
            </div>

            {/* Optional full heatmap (collapsible — kept for advanced users) */}
            <details style={card}>
              <summary style={{ cursor: 'pointer', fontSize: 13, color: '#0f172a', fontWeight: 600 }}>
                Show full day × hour heatmap (advanced)
              </summary>
              <p style={{ margin: '8px 0 12px', fontSize: 12, color: '#64748b' }}>
                Each cell is one combination of day and hour. Deeper blue = more visits. Hover for exact counts.
              </p>
              <Heatmap data={data.heatmap} />
            </details>
          </div>
        );
      })()}

      {/* ── Monthly trend tab ── */}
      {activeTab === 'monthly' && (
        <div style={card}>
          <h3 style={{ ...sectionTitle, marginBottom: 10 }}>
            <CalendarDaysIcon style={{ width: 18, height: 18, color: '#0ea5e9' }} />
            Monthly trend (cost)
          </h3>
          <MonthlyTrend data={data.monthly} />
        </div>
      )}

      {/* ── Breakdown chips tab ── */}
      {activeTab === 'breakdowns' && (
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))', gap: 16 }}>
        {[
          { title: 'By claim status',  rows: data.by_status,   key: 'claim_status',  color: '#16a34a' },
          { title: 'By illness type',  rows: data.by_illness,  key: 'illness_type',  color: '#0ea5e9' },
          { title: 'By relation',      rows: data.by_relation, key: 'relation',      color: '#dc2626' },
        ].map((g) => {
          const max = Math.max(...g.rows.map((r) => r.claim_count), 1);
          return (
            <div key={g.title} style={card}>
              <h3 style={{ ...sectionTitle, marginBottom: 10, fontSize: 14 }}>{g.title}</h3>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
                {g.rows.map((r, i) => (
                  <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 10, fontSize: 13 }}>
                    <span style={{ minWidth: 110, color: '#0f172a', fontWeight: 500 }}>
                      {r[g.key] || <em style={{ color: '#cbd5e1' }}>Unspecified</em>}
                    </span>
                    <div style={{ flex: 1, height: 8, background: '#f1f5f9', borderRadius: 999, overflow: 'hidden' }}>
                      <div style={{ width: `${Math.max(2, (r.claim_count / max) * 100)}%`, height: '100%', background: g.color }} />
                    </div>
                    <span style={{ minWidth: 80, textAlign: 'right', color: '#475569', fontVariantNumeric: 'tabular-nums' }}>
                      {fmtNum(r.claim_count)}
                    </span>
                    <span style={{ minWidth: 110, textAlign: 'right', color: '#94a3b8', fontVariantNumeric: 'tabular-nums', fontSize: 12 }}>
                      UGX {fmtMoney(r.total_amount)}
                    </span>
                  </div>
                ))}
              </div>
            </div>
          );
        })}
      </div>
      )}

      {/* Drill-down modal */}
      {drilldownProvider && (
        <ProviderDrilldown
          uploadIds={uploadIds}
          provider={drilldownProvider}
          filters={filters}
          onClose={() => setDrilldownProvider(null)}
        />
      )}
    </div>
  );
}
