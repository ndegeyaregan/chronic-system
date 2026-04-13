export default function StatCard({
  title,
  value,
  trend,
  trendLabel,
  color = 'var(--primary)',
}) {
  return (
    <div style={{
      background: '#fff',
      borderRadius: '12px',
      padding: '20px 24px',
      boxShadow: '0 1px 4px rgba(0,0,0,0.07)',
      border: '1px solid #e2e8f0',
      display: 'flex',
      flexDirection: 'column',
      gap: '12px',
    }}>
      <div>
        <p style={{ margin: 0, fontSize: '13px', color: color, fontWeight: '700', letterSpacing: '0.01em' }}>{title}</p>
        <p style={{ margin: '4px 0 0', fontSize: '28px', fontWeight: '700', color: 'var(--text)' }}>
          {value ?? '—'}
        </p>
      </div>
      {(trend !== undefined || trendLabel) && (
        <p style={{ margin: 0, fontSize: '12px', color: '#64748b' }}>
          {trend !== undefined && (
            <span style={{ color: trend >= 0 ? '#16a34a' : '#dc2626', fontWeight: '600', marginRight: '4px' }}>
              {trend >= 0 ? '▲' : '▼'} {Math.abs(trend)}%
            </span>
          )}
          {trendLabel}
        </p>
      )}
    </div>
  );
}
