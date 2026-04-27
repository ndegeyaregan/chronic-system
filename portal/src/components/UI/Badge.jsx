import React from 'react';

const STATUS_STYLES = {
  pending: { background: '#fef3c7', color: '#92400e' },
  overdue: { background: '#fee2e2', color: '#991b1b' },
  confirmed: { background: '#d1fae5', color: '#065f46' },
  approved: { background: '#d1fae5', color: '#065f46' },
  rejected: { background: '#fee2e2', color: '#991b1b' },
  cancelled: { background: '#fee2e2', color: '#991b1b' },
  active: { background: '#d1fae5', color: '#065f46' },
  inactive: { background: '#f1f5f9', color: '#64748b' },
  published: { background: '#dbeafe', color: '#1e40af' },
  draft: { background: '#f1f5f9', color: '#64748b' },
  completed: { background: '#e0f2fe', color: '#0369a1' },
  scheduled: { background: '#fef3c7', color: '#92400e' },
};

export default function Badge({ status, label }) {
  const style = STATUS_STYLES[status?.toLowerCase()] || STATUS_STYLES.inactive;
  return (
    <span
      style={{
        ...style,
        padding: '2px 10px',
        borderRadius: '999px',
        fontSize: '12px',
        fontWeight: '600',
        display: 'inline-block',
        textTransform: 'capitalize',
        whiteSpace: 'nowrap',
      }}
    >
      {label || status}
    </span>
  );
}
