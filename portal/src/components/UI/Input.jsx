export default function Input({ label, name, register, error, type = 'text', placeholder, ...rest }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '4px' }}>
      {label && (
        <label style={{ fontSize: '13px', fontWeight: '500', color: '#475569' }}>
          {label}
        </label>
      )}
      <input
        type={type}
        placeholder={placeholder}
        {...(register ? register(name) : {})}
        {...rest}
        style={{
          padding: '8px 12px',
          borderRadius: '6px',
          border: error ? '1px solid #ef4444' : '1px solid #e2e8f0',
          fontSize: '14px',
          color: 'var(--text)',
          background: '#fff',
          outline: 'none',
          width: '100%',
          boxSizing: 'border-box',
        }}
      />
      {error && (
        <span style={{ fontSize: '12px', color: '#ef4444' }}>{error.message || error}</span>
      )}
    </div>
  );
}
