import { useEffect, useState } from 'react';
import sanlamLogo from '../assets/sanlam-logo.png';

const APK_URL = '/uploads/apk/SanCare%2B.apk';

export default function DownloadPage() {
  const [info, setInfo] = useState(null);

  useEffect(() => {
    fetch('/api/app/version')
      .then(r => r.ok ? r.json() : null)
      .then(setInfo)
      .catch(() => {});
  }, []);

  const sizeMb = info?.sizeBytes
    ? `${(info.sizeBytes / (1024 * 1024)).toFixed(1)} MB`
    : '~76 MB';
  const version = info?.latest;
  const notes = Array.isArray(info?.releaseNotes) ? info.releaseNotes : [];

  return (
    <div style={{
      minHeight: '100vh',
      background: 'linear-gradient(150deg, #003DA5 0%, #0055cc 55%, #003080 100%)',
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      justifyContent: 'center',
      fontFamily: "'Inter', 'Segoe UI', sans-serif",
      padding: '40px 20px',
    }}>
      {/* Decorative rings */}
      <div style={{ position: 'fixed', top: -80, right: -80, width: 320, height: 320, borderRadius: '50%', border: '60px solid rgba(255,255,255,0.04)' }} />
      <div style={{ position: 'fixed', bottom: -60, left: -60, width: 260, height: 260, borderRadius: '50%', border: '50px solid rgba(255,255,255,0.04)' }} />

      {/* Logo */}
      <img
        src={sanlamLogo}
        alt="Sanlam Allianz"
        style={{ width: '220px', marginBottom: '32px', filter: 'brightness(0) invert(1)', opacity: 0.92 }}
      />

      {/* Card */}
      <div style={{
        background: '#fff',
        borderRadius: '20px',
        padding: '48px 40px',
        maxWidth: '460px',
        width: '100%',
        boxShadow: '0 20px 60px rgba(0,0,0,0.25)',
        textAlign: 'center',
        position: 'relative',
        zIndex: 1,
      }}>
        {/* Phone icon */}
        <div style={{
          width: 72,
          height: 72,
          borderRadius: '18px',
          background: 'linear-gradient(135deg, #003DA5, #0055cc)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          margin: '0 auto 24px',
          boxShadow: '0 8px 24px rgba(0,61,165,0.3)',
        }}>
          <svg width="36" height="36" viewBox="0 0 24 24" fill="none" stroke="#fff" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
            <rect x="5" y="2" width="14" height="20" rx="2" ry="2" />
            <line x1="12" y1="18" x2="12" y2="18.01" strokeWidth="2.5" />
          </svg>
        </div>

        <h1 style={{ margin: '0 0 8px', fontSize: '24px', fontWeight: '800', color: '#0f172a', letterSpacing: '-0.5px' }}>
          Download Mobile App
        </h1>

        {version && (
          <div style={{
            display: 'inline-block',
            padding: '4px 12px',
            margin: '0 0 12px',
            background: '#003DA50f',
            border: '1px solid #003DA533',
            borderRadius: '999px',
            fontSize: '12px',
            fontWeight: 700,
            color: '#003DA5',
            letterSpacing: '0.3px',
          }}>
            Latest version: v{version}
          </div>
        )}

        <p style={{ margin: '0 0 24px', color: '#64748b', fontSize: '14px', lineHeight: 1.7 }}>
          Get the Sanlam Allianz Chronic Care app on your Android device to manage your health on the go.
        </p>

        {/* What's new (only when manifest provided notes) */}
        {notes.length > 0 && (
          <div style={{
            textAlign: 'left',
            marginBottom: '24px',
            padding: '14px 16px',
            background: '#f8fafc',
            borderRadius: '12px',
            border: '1px solid #e2e8f0',
          }}>
            <div style={{ fontSize: '12px', fontWeight: 700, color: '#0f172a', marginBottom: '8px', letterSpacing: '0.3px' }}>
              ✨ WHAT&apos;S NEW
            </div>
            <ul style={{ margin: 0, paddingLeft: '18px', color: '#334155', fontSize: '13px', lineHeight: 1.7 }}>
              {notes.map((n, i) => <li key={i}>{n}</li>)}
            </ul>
          </div>
        )}

        {/* Features */}
        <div style={{ textAlign: 'left', marginBottom: '32px' }}>
          {[
            { icon: '💊', text: 'Track medications & refill reminders' },
            { icon: '📅', text: 'Manage appointments' },
            { icon: '🏥', text: 'Find nearby hospitals & pharmacies' },
            { icon: '📊', text: 'View lab results & vitals' },
            { icon: '💬', text: 'Chat with your care team' },
          ].map(({ icon, text }) => (
            <div key={text} style={{
              display: 'flex',
              alignItems: 'center',
              gap: '12px',
              padding: '10px 0',
              borderBottom: '1px solid #f1f5f9',
            }}>
              <span style={{ fontSize: '20px' }}>{icon}</span>
              <span style={{ fontSize: '14px', color: '#334155' }}>{text}</span>
            </div>
          ))}
        </div>

        {/* Download button */}
        <a
          href={APK_URL}
          download="SanCare+.apk"
          style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            gap: '12px',
            width: '100%',
            padding: '14px 24px',
            background: 'linear-gradient(135deg, #003DA5, #0055cc)',
            color: '#fff',
            border: 'none',
            borderRadius: '12px',
            fontSize: '16px',
            fontWeight: '700',
            cursor: 'pointer',
            textDecoration: 'none',
            letterSpacing: '0.2px',
            transition: 'transform 0.15s, box-shadow 0.2s',
            boxShadow: '0 4px 16px rgba(0,61,165,0.35)',
            boxSizing: 'border-box',
          }}
          onMouseEnter={e => { e.currentTarget.style.transform = 'translateY(-1px)'; e.currentTarget.style.boxShadow = '0 6px 24px rgba(0,61,165,0.45)'; }}
          onMouseLeave={e => { e.currentTarget.style.transform = 'translateY(0)'; e.currentTarget.style.boxShadow = '0 4px 16px rgba(0,61,165,0.35)'; }}
        >
          <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
            <polyline points="7 10 12 15 17 10" />
            <line x1="12" y1="15" x2="12" y2="3" />
          </svg>
          {version ? `Download v${version} for Android` : 'Download for Android'}
        </a>

        <p style={{ margin: '20px 0 0', fontSize: '12px', color: '#94a3b8', lineHeight: 1.6 }}>
          Android 6.0+ required · {sizeMb}<br />
          You may need to enable &quot;Install from unknown sources&quot; in your device settings.
        </p>
      </div>

      {/* Back to login link */}
      <a
        href="/login"
        style={{
          marginTop: '24px',
          color: 'rgba(255,255,255,0.7)',
          fontSize: '13px',
          textDecoration: 'none',
          transition: 'color 0.2s',
        }}
        onMouseEnter={e => e.target.style.color = '#fff'}
        onMouseLeave={e => e.target.style.color = 'rgba(255,255,255,0.7)'}
      >
        ← Back to Login
      </a>

      <p style={{ marginTop: '32px', textAlign: 'center', fontSize: '12px', color: 'rgba(255,255,255,0.4)', lineHeight: 1.6 }}>
        © {new Date().getFullYear()} Sanlam Allianz · All rights reserved.
      </p>
    </div>
  );
}

