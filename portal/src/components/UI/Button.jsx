export default function Button({ children, variant = 'primary', type = 'button', onClick, disabled, style = {} }) {
  const base = {
    display: 'inline-flex',
    alignItems: 'center',
    gap: '6px',
    padding: '8px 16px',
    borderRadius: '6px',
    fontSize: '14px',
    fontWeight: '500',
    cursor: disabled ? 'not-allowed' : 'pointer',
    border: 'none',
    transition: 'opacity 0.15s, background 0.15s',
    opacity: disabled ? 0.6 : 1,
  };

  const variants = {
    primary: { background: 'var(--primary)', color: '#fff' },
    secondary: { background: '#f1f5f9', color: 'var(--text)', border: '1px solid #e2e8f0' },
    danger: { background: '#ef4444', color: '#fff' },
    success: { background: 'var(--accent)', color: '#fff' },
    ghost: { background: 'transparent', color: 'var(--primary)', border: '1px solid var(--primary)' },
  };

  return (
    <button
      type={type}
      onClick={onClick}
      disabled={disabled}
      style={{ ...base, ...variants[variant], ...style }}
    >
      {children}
    </button>
  );
}
