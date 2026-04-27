import React from 'react';

export default function Table({
  columns,
  data,
  emptyMessage = 'No records found.',
  selectable = false,
  selectedIds = [],
  onSelectionChange,
}) {
  const allSelected = data && data.length > 0 && data.every((r) => selectedIds.includes(r.id));
  const someSelected = data && data.some((r) => selectedIds.includes(r.id));

  const toggleAll = () => {
    if (!onSelectionChange) return;
    if (allSelected) {
      onSelectionChange([]);
    } else {
      onSelectionChange(data.map((r) => r.id));
    }
  };

  const toggleRow = (id) => {
    if (!onSelectionChange) return;
    if (selectedIds.includes(id)) {
      onSelectionChange(selectedIds.filter((x) => x !== id));
    } else {
      onSelectionChange([...selectedIds, id]);
    }
  };

  return (
    <div style={{ overflowX: 'auto', width: '100%' }}>
      <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '14px' }}>
        <thead>
          <tr style={{ borderBottom: '2px solid #e2e8f0', background: '#f8fafc' }}>
            {selectable && (
              <th style={{ padding: '10px 8px', width: '40px' }}>
                <input
                  type="checkbox"
                  checked={allSelected}
                  ref={(el) => { if (el) el.indeterminate = someSelected && !allSelected; }}
                  onChange={toggleAll}
                  style={{ cursor: 'pointer' }}
                />
              </th>
            )}
            {columns.map((col) => (
              <th
                key={col.key}
                style={{
                  padding: '10px 14px',
                  textAlign: 'left',
                  fontSize: '12px',
                  fontWeight: '600',
                  color: '#64748b',
                  textTransform: 'uppercase',
                  letterSpacing: '0.04em',
                  whiteSpace: 'nowrap',
                }}
              >
                {col.header}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {data && data.length > 0 ? (
            data.map((row, i) => {
              const isSelected = selectable && selectedIds.includes(row.id);
              return (
                <tr
                  key={row.id || i}
                  style={{
                    borderBottom: '1px solid #f1f5f9',
                    background: isSelected ? '#eff6ff' : 'transparent',
                    transition: 'background 0.1s',
                  }}
                  onMouseEnter={(e) => { if (!isSelected) e.currentTarget.style.background = '#f8fafc'; }}
                  onMouseLeave={(e) => { if (!isSelected) e.currentTarget.style.background = 'transparent'; else e.currentTarget.style.background = '#eff6ff'; }}
                >
                  {selectable && (
                    <td style={{ padding: '11px 8px', width: '40px' }}>
                      <input
                        type="checkbox"
                        checked={isSelected}
                        onChange={() => toggleRow(row.id)}
                        style={{ cursor: 'pointer' }}
                      />
                    </td>
                  )}
                  {columns.map((col) => (
                    <td key={col.key} style={{ padding: '11px 14px', color: 'var(--text)', verticalAlign: 'middle' }}>
                      {col.render ? col.render(row[col.key], row) : row[col.key] ?? '—'}
                    </td>
                  ))}
                </tr>
              );
            })
          ) : (
            <tr>
              <td
                colSpan={columns.length + (selectable ? 1 : 0)}
                style={{ padding: '32px', textAlign: 'center', color: '#94a3b8', fontStyle: 'italic' }}
              >
                {emptyMessage}
              </td>
            </tr>
          )}
        </tbody>
      </table>
    </div>
  );
}
