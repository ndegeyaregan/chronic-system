import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useForm } from 'react-hook-form';
import toast from 'react-hot-toast';
import { useAuth } from '../../context/AuthContext';
import Input from '../../components/UI/Input';
import Button from '../../components/UI/Button';
import sanlamLogo from '../../assets/sanlam-logo.png';

/* ── Heartbeat animation ────────────────────────────── */
const heartbeatStyle = `
  @keyframes heartbeat-run {
    0%   { stroke-dashoffset: 600; opacity: 0.3; }
    30%  { opacity: 1; }
    100% { stroke-dashoffset: 0; opacity: 0.3; }
  }
  @keyframes pulse-glow {
    0%, 100% { filter: drop-shadow(0 0 0px rgba(255,255,255,0)); }
    50%       { filter: drop-shadow(0 0 6px rgba(255,255,255,0.7)); }
  }
  .lifeline {
    stroke-dasharray: 600;
    stroke-dashoffset: 600;
    animation: heartbeat-run 2.4s ease-in-out infinite, pulse-glow 2.4s ease-in-out infinite;
  }
`;


function ChronicIllustration() {
  return (
    <>
      <style>{heartbeatStyle}</style>
      <svg viewBox="0 0 420 340" fill="none" xmlns="http://www.w3.org/2000/svg" style={{ width: '100%', maxWidth: 380 }}>
      {/* Background blobs */}
      <ellipse cx="210" cy="180" rx="170" ry="140" fill="rgba(255,255,255,0.05)" />
      <ellipse cx="210" cy="180" rx="120" ry="100" fill="rgba(255,255,255,0.05)" />

      {/* Central medical cross */}
      <rect x="185" y="130" width="50" height="140" rx="12" fill="rgba(255,255,255,0.15)" />
      <rect x="135" y="180" width="150" height="50" rx="12" fill="rgba(255,255,255,0.15)" />
      <rect x="192" y="137" width="36" height="126" rx="8" fill="rgba(255,255,255,0.22)" />
      <rect x="142" y="187" width="136" height="36" rx="8" fill="rgba(255,255,255,0.22)" />

      {/* Heart rate line — animated */}
      <polyline
        className="lifeline"
        points="60,200 100,200 115,165 130,235 148,185 163,215 200,200 420,200"
        stroke="rgba(255,255,255,0.85)"
        strokeWidth="3"
        strokeLinecap="round"
        strokeLinejoin="round"
        fill="none"
      />

      {/* Pill shapes */}
      <rect x="50" y="110" width="52" height="24" rx="12" fill="rgba(255,255,255,0.18)" transform="rotate(-30 76 122)" />
      <rect x="330" y="130" width="52" height="24" rx="12" fill="rgba(255,255,255,0.18)" transform="rotate(20 356 142)" />

      {/* Dots / cells */}
      {[
        [80, 260], [340, 100], [360, 260], [70, 150], [350, 200],
      ].map(([cx, cy], i) => (
        <circle key={i} cx={cx} cy={cy} r="8" fill="rgba(255,255,255,0.12)" />
      ))}
      {[
        [100, 290], [310, 80], [380, 240],
      ].map(([cx, cy], i) => (
        <circle key={i} cx={cx} cy={cy} r="5" fill="rgba(255,255,255,0.08)" />
      ))}

      {/* Small heart */}
      <path
        d="M210 100 C210 100 195 88 195 78 C195 71 202 65 210 72 C218 65 225 71 225 78 C225 88 210 100 210 100Z"
        fill="rgba(255,255,255,0.35)"
      />
    </svg>
    </>
  );
}

export default function LoginPage() {
  const { login } = useAuth();
  const navigate = useNavigate();
  const [loading, setLoading] = useState(false);
  const [showPass, setShowPass] = useState(false);
  const { register, handleSubmit, formState: { errors } } = useForm();

  const onSubmit = async (data) => {
    setLoading(true);
    try {
      await login(data.email, data.password);
      toast.success('Welcome back!');
      navigate('/');
    } catch (err) {
      toast.error(err.response?.data?.message || 'Invalid credentials');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={{
      minHeight: '100vh',
      display: 'flex',
      fontFamily: "'Inter', 'Segoe UI', sans-serif",
    }}>
      {/* ── Left Panel ── */}
      <div style={{
        flex: '1 1 55%',
        background: 'linear-gradient(150deg, #003DA5 0%, #0055cc 55%, #003080 100%)',
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        padding: '48px 40px',
        position: 'relative',
        overflow: 'hidden',
      }}>
        {/* Decorative rings */}
        <div style={{ position: 'absolute', top: -80, right: -80, width: 320, height: 320, borderRadius: '50%', border: '60px solid rgba(255,255,255,0.04)' }} />
        <div style={{ position: 'absolute', bottom: -60, left: -60, width: 260, height: 260, borderRadius: '50%', border: '50px solid rgba(255,255,255,0.04)' }} />

        {/* Logo */}
        <img
          src={sanlamLogo}
          alt="Sanlam Allianz"
          style={{ width: '260px', marginBottom: '48px', filter: 'brightness(0) invert(1)', opacity: 0.92 }}
        />

        {/* Illustration */}
        <ChronicIllustration />

        {/* Text */}
        <div style={{ marginTop: '36px', textAlign: 'center', color: '#fff' }}>
          <h2 style={{ margin: '0 0 10px', fontSize: '22px', fontWeight: '700', letterSpacing: '-0.3px' }}>
            Chronic Care Management
          </h2>
          <p style={{ margin: 0, fontSize: '14px', color: 'rgba(255,255,255,0.65)', maxWidth: 340, lineHeight: 1.7 }}>
            Monitoring medication adherence, appointments, lab results and member wellness — all in one place.
          </p>
        </div>

        {/* Stats row */}
        <div style={{ display: 'flex', gap: 32, marginTop: 40 }}>
          {[
            { num: '360°', label: 'Member View' },
            { num: 'Real-time', label: 'Alerts' },
            { num: 'Secure', label: 'Access' },
          ].map(({ num, label }) => (
            <div key={label} style={{ textAlign: 'center' }}>
              <div style={{ fontSize: '16px', fontWeight: '800', color: '#fff' }}>{num}</div>
              <div style={{ fontSize: '11px', color: 'rgba(255,255,255,0.55)', marginTop: 2 }}>{label}</div>
            </div>
          ))}
        </div>
      </div>

      {/* ── Right Panel ── */}
      <div style={{
        flex: '1 1 45%',
        background: '#f8fafc',
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        padding: '48px 40px',
      }}>
        <div style={{ width: '100%', maxWidth: '380px' }}>

          {/* Mobile logo (hidden on wide screens via inline style trick) */}
          <div style={{ marginBottom: 36 }}>
            <h1 style={{ margin: '0 0 4px', fontSize: '26px', fontWeight: '800', color: '#0f172a', letterSpacing: '-0.5px' }}>
              Welcome back
            </h1>
            <p style={{ margin: 0, color: '#64748b', fontSize: '14px' }}>
              Sign in to your admin portal
            </p>
          </div>

          {/* Form card */}
          <div style={{
            background: '#fff',
            borderRadius: '16px',
            padding: '36px 32px',
            boxShadow: '0 4px 24px rgba(0,0,0,0.08)',
            border: '1px solid #e2e8f0',
          }}>
            <form onSubmit={handleSubmit(onSubmit)} style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>

              {/* Email */}
              <div>
                <label style={{ display: 'block', fontSize: '13px', fontWeight: '600', color: '#374151', marginBottom: 6 }}>
                  Email Address
                </label>
                <input
                  type="email"
                  placeholder="admin@sanlam.co.za"
                  {...register('email', { required: true })}
                  style={{
                    width: '100%', boxSizing: 'border-box',
                    padding: '11px 14px',
                    border: errors.email ? '1.5px solid #ef4444' : '1.5px solid #e2e8f0',
                    borderRadius: '10px',
                    fontSize: '14px', color: '#0f172a',
                    outline: 'none',
                    background: '#f8fafc',
                    transition: 'border-color 0.2s',
                  }}
                  onFocus={e => e.target.style.borderColor = '#003DA5'}
                  onBlur={e => e.target.style.borderColor = errors.email ? '#ef4444' : '#e2e8f0'}
                />
                {errors.email && <p style={{ margin: '4px 0 0', fontSize: '12px', color: '#ef4444' }}>Email is required</p>}
              </div>

              {/* Password */}
              <div>
                <label style={{ display: 'block', fontSize: '13px', fontWeight: '600', color: '#374151', marginBottom: 6 }}>
                  Password
                </label>
                <div style={{ position: 'relative' }}>
                  <input
                    type={showPass ? 'text' : 'password'}
                    placeholder="••••••••"
                    {...register('password', { required: true })}
                    style={{
                      width: '100%', boxSizing: 'border-box',
                      padding: '11px 42px 11px 14px',
                      border: errors.password ? '1.5px solid #ef4444' : '1.5px solid #e2e8f0',
                      borderRadius: '10px',
                      fontSize: '14px', color: '#0f172a',
                      outline: 'none',
                      background: '#f8fafc',
                      transition: 'border-color 0.2s',
                    }}
                    onFocus={e => e.target.style.borderColor = '#003DA5'}
                    onBlur={e => e.target.style.borderColor = errors.password ? '#ef4444' : '#e2e8f0'}
                  />
                  <button
                    type="button"
                    onClick={() => setShowPass(p => !p)}
                    style={{ position: 'absolute', right: 12, top: '50%', transform: 'translateY(-50%)', background: 'none', border: 'none', cursor: 'pointer', color: '#94a3b8', fontSize: 13 }}
                  >
                    {showPass ? 'Hide' : 'Show'}
                  </button>
                </div>
                {errors.password && <p style={{ margin: '4px 0 0', fontSize: '12px', color: '#ef4444' }}>Password is required</p>}
              </div>

              {/* Submit */}
              <button
                type="submit"
                disabled={loading}
                style={{
                  width: '100%',
                  padding: '12px',
                  background: loading ? '#93a4c9' : '#003DA5',
                  color: '#fff',
                  border: 'none',
                  borderRadius: '10px',
                  fontSize: '15px',
                  fontWeight: '700',
                  cursor: loading ? 'not-allowed' : 'pointer',
                  letterSpacing: '0.2px',
                  transition: 'background 0.2s, transform 0.1s',
                  marginTop: 4,
                }}
                onMouseEnter={e => { if (!loading) e.target.style.background = '#002d80'; }}
                onMouseLeave={e => { if (!loading) e.target.style.background = '#003DA5'; }}
              >
                {loading ? 'Signing in…' : 'Sign In →'}
              </button>
            </form>
          </div>

          <p style={{ marginTop: 28, textAlign: 'center', fontSize: '12px', color: '#94a3b8', lineHeight: 1.6 }}>
            Protected system. Authorised personnel only.<br />
            © {new Date().getFullYear()} Sanlam Allianz · All rights reserved.
          </p>
        </div>
      </div>
    </div>
  );
}
