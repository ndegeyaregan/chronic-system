import React, { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import toast from 'react-hot-toast';
import sanlam_logo from '../../assets/sanlam-logo.png';

const ForgotPasswordPage = () => {
  const navigate = useNavigate();
  const [step, setStep] = useState(1);
  const [loading, setLoading] = useState(false);
  const [email, setEmail] = useState('');
  const [otp, setOtp] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [resetToken, setResetToken] = useState('');

  const handleRequestReset = async (e) => {
    e.preventDefault();
    if (!email.trim()) {
      toast.error('Please enter your email address');
      return;
    }

    setLoading(true);
    try {
      const response = await fetch('/api/auth/forgot-password', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email }),
      });

      const data = await response.json();
      if (response.ok) {
        toast.success('OTP sent to your email');
        setStep(2);
      } else {
        toast.error(data.message || 'Failed to send OTP');
      }
    } catch (error) {
      console.error('Error:', error);
      toast.error('An error occurred. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  const handleVerifyOtp = async (e) => {
    e.preventDefault();
    if (!otp.trim() || otp.length !== 6) {
      toast.error('Please enter a valid 6-digit OTP');
      return;
    }

    setLoading(true);
    try {
      const response = await fetch('/api/auth/verify-otp', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ otp, email }),
      });

      const data = await response.json();
      if (response.ok) {
        toast.success('OTP verified!');
        setResetToken(data.reset_token);
        setStep(3);
      } else {
        toast.error(data.message || 'Invalid or expired OTP');
      }
    } catch (error) {
      console.error('Error:', error);
      toast.error('An error occurred. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  const handleResetPassword = async (e) => {
    e.preventDefault();
    if (!newPassword || !confirmPassword) {
      toast.error('Please fill in all fields');
      return;
    }
    if (newPassword.length < 8) {
      toast.error('Password must be at least 8 characters');
      return;
    }
    if (newPassword !== confirmPassword) {
      toast.error('Passwords do not match');
      return;
    }

    setLoading(true);
    try {
      const response = await fetch('/api/auth/reset-password', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          reset_token: resetToken,
          new_password: newPassword,
          confirm_password: confirmPassword,
        }),
      });

      const data = await response.json();
      if (response.ok) {
        toast.success('Password reset successfully!');
        setTimeout(() => navigate('/login'), 1500);
      } else {
        toast.error(data.message || 'Failed to reset password');
      }
    } catch (error) {
      console.error('Error:', error);
      toast.error('An error occurred. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={{
      minHeight: '100vh',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      backgroundImage: 'url("https://images.unsplash.com/photo-1576091160550-2173dba999ef?w=1200&q=80")',
      backgroundSize: 'cover',
      backgroundPosition: 'center',
      backgroundAttachment: 'fixed'
    }}>
      <div style={{
        position: 'absolute',
        top: 0,
        left: 0,
        right: 0,
        bottom: 0,
        background: 'linear-gradient(135deg, rgba(0, 0, 0, 0.35) 0%, rgba(0, 0, 0, 0.25) 100%)',
        zIndex: 1
      }}></div>

      <style>{`
        @keyframes fadeInUp {
          from { opacity: 0; transform: translateY(30px); }
          to { opacity: 1; transform: translateY(0); }
        }
        @keyframes glowPulse {
          0%, 100% { box-shadow: 0 0 0 3px rgba(14, 165, 233, 0.15), inset 0 0 12px rgba(14, 165, 233, 0.08), 0 0 20px rgba(14, 165, 233, 0.3); }
          50% { box-shadow: 0 0 0 3px rgba(14, 165, 233, 0.25), inset 0 0 12px rgba(14, 165, 233, 0.12), 0 0 30px rgba(14, 165, 233, 0.5); }
        }
        .forgot-password-container {
          position: relative;
          z-index: 2;
          background: linear-gradient(135deg, rgba(30, 41, 59, 0.85) 0%, rgba(30, 41, 59, 0.8) 100%);
          backdrop-filter: blur(10px);
          border: 1px solid rgba(255, 255, 255, 0.1);
          border-radius: 20px;
          padding: 48px 40px;
          width: 100%;
          max-width: 420px;
          box-shadow: 0 8px 32px rgba(0, 0, 0, 0.3), 0 0 40px rgba(14, 165, 233, 0.15), inset 0 1px 1px rgba(255, 255, 255, 0.1);
          animation: fadeInUp 0.8s ease-out;
        }
        .form-header {
          display: flex;
          flex-direction: column;
          align-items: center;
          margin-bottom: 32px;
          animation: fadeInUp 0.8s ease-out 0.1s both;
        }
        .logo-img {
          width: 80px;
          height: auto;
          margin-bottom: 16px;
          filter: drop-shadow(0 4px 8px rgba(0, 0, 0, 0.2));
        }
        .form-title {
          font-size: 24px;
          font-weight: 700;
          color: rgba(255, 255, 255, 1);
          text-align: center;
          text-shadow: 0 2px 4px rgba(0, 0, 0, 0.2);
        }
        .form-subtitle {
          font-size: 13px;
          color: rgba(255, 255, 255, 0.7);
          text-align: center;
          margin-top: 8px;
        }
        .form-group {
          display: flex;
          flex-direction: column;
          gap: 6px;
          margin-bottom: 16px;
          animation: fadeInUp 0.8s ease-out 0.2s both;
        }
        .form-label {
          font-size: 12px;
          font-weight: 600;
          color: rgba(255, 255, 255, 0.7);
          text-transform: uppercase;
          letter-spacing: 0.5px;
        }
        .input {
          padding: 12px 14px;
          border: 2px solid rgba(255, 255, 255, 0.3);
          border-radius: 12px;
          font-size: 14px;
          background: rgba(255, 255, 255, 0.4);
          color: #0f172a;
          transition: all 0.3s ease;
          font-family: inherit;
          font-weight: 500;
          width: 100%;
        }
        .input::placeholder {
          color: rgba(15, 23, 42, 0.5);
        }
        .input:focus {
          outline: none;
          border-color: rgba(255, 255, 255, 0.6);
          background: rgba(255, 255, 255, 0.5);
          box-shadow: 0 0 0 3px rgba(14, 165, 233, 0.15), inset 0 0 12px rgba(14, 165, 233, 0.08), 0 0 20px rgba(14, 165, 233, 0.3);
          transform: scale(1.01);
        }
        .password-wrapper {
          position: relative;
          width: 100%;
        }
        .password-toggle {
          position: absolute;
          right: 14px;
          top: 50%;
          transform: translateY(-50%);
          background: none;
          border: none;
          cursor: pointer;
          font-size: 18px;
          color: rgba(15, 23, 42, 0.6);
          transition: color 0.2s;
          padding: 4px;
        }
        .password-toggle:hover {
          color: #0ea5e9;
        }
        .submit-btn {
          width: 100%;
          padding: 14px 24px;
          background: linear-gradient(135deg, rgba(14, 165, 233, 0.95) 0%, rgba(6, 182, 212, 0.95) 100%);
          color: white;
          border: 2px solid rgba(255, 255, 255, 0.2);
          border-radius: 12px;
          font-weight: 700;
          font-size: 14px;
          cursor: pointer;
          transition: all 0.3s ease;
          box-shadow: 0 8px 20px rgba(14, 165, 233, 0.3);
          margin-top: 24px;
          text-shadow: 0 1px 2px rgba(0, 0, 0, 0.15);
          text-transform: uppercase;
          letter-spacing: 0.5px;
          animation: fadeInUp 0.8s ease-out 0.3s both;
        }
        .submit-btn:hover:not(:disabled) {
          transform: translateY(-4px) scale(1.02);
          box-shadow: 0 14px 35px rgba(14, 165, 233, 0.45);
          background: linear-gradient(135deg, rgba(14, 165, 233, 1) 0%, rgba(6, 182, 212, 1) 100%);
        }
        .submit-btn:disabled {
          opacity: 0.6;
          cursor: not-allowed;
        }
        .back-link {
          text-align: center;
          margin-top: 20px;
        }
        .back-link a, .back-link button {
          font-size: 13px;
          color: rgba(255, 255, 255, 0.85);
          text-decoration: none;
          font-weight: 600;
          transition: all 0.2s;
          background: none;
          border: none;
          cursor: pointer;
          padding: 0;
        }
        .back-link a:hover, .back-link button:hover {
          color: rgba(255, 255, 255, 1);
          text-decoration: underline;
        }
        .step-indicator {
          display: flex;
          justify-content: center;
          gap: 8px;
          margin-bottom: 24px;
        }
        .step-dot {
          width: 10px;
          height: 10px;
          border-radius: 50%;
          background: rgba(255, 255, 255, 0.3);
        }
        .step-dot.active {
          background: rgba(14, 165, 233, 1);
          box-shadow: 0 0 12px rgba(14, 165, 233, 0.6);
        }
      `}</style>

      <div className="forgot-password-container">
        <div className="form-header">
          <img src={sanlam_logo} alt="Sanlam Logo" className="logo-img" />
          <h1 className="form-title">
            {step === 1 && 'Forgot Password'}
            {step === 2 && 'Verify OTP'}
            {step === 3 && 'Reset Password'}
          </h1>
          <p className="form-subtitle">
            {step === 1 && 'Enter your email to reset your password'}
            {step === 2 && 'Enter the 6-digit code sent to your email'}
            {step === 3 && 'Create your new password'}
          </p>
        </div>

        <div className="step-indicator">
          <div className={`step-dot ${step >= 1 ? 'active' : ''}`}></div>
          <div className={`step-dot ${step >= 2 ? 'active' : ''}`}></div>
          <div className={`step-dot ${step >= 3 ? 'active' : ''}`}></div>
        </div>

        {step === 1 && (
          <form onSubmit={handleRequestReset}>
            <div className="form-group">
              <label className="form-label">Email Address</label>
              <input type="email" className="input" placeholder="Enter your email address" value={email} onChange={(e) => setEmail(e.target.value)} disabled={loading} />
            </div>
            <button type="submit" className="submit-btn" disabled={loading}>{loading ? 'Sending...' : 'Send OTP'}</button>
          </form>
        )}

        {step === 2 && (
          <form onSubmit={handleVerifyOtp}>
            <div className="form-group">
              <label className="form-label">6-Digit OTP</label>
              <input type="text" className="input" placeholder="Enter 6-digit code" value={otp} onChange={(e) => setOtp(e.target.value.replace(/\D/g, '').slice(0, 6))} maxLength="6" disabled={loading} />
              <p className="form-subtitle">Check your email for the code</p>
            </div>
            <button type="submit" className="submit-btn" disabled={loading}>{loading ? 'Verifying...' : 'Verify OTP'}</button>
            <div className="back-link">
              <button type="button" onClick={() => setStep(1)} disabled={loading}>← Back to Email</button>
            </div>
          </form>
        )}

        {step === 3 && (
          <form onSubmit={handleResetPassword}>
            <div className="form-group">
              <label className="form-label">New Password</label>
              <div className="password-wrapper">
                <input type={showPassword ? 'text' : 'password'} className="input" placeholder="Enter new password (min 8 characters)" value={newPassword} onChange={(e) => setNewPassword(e.target.value)} disabled={loading} />
                <button type="button" className="password-toggle" onClick={() => setShowPassword(!showPassword)} disabled={loading}>{showPassword ? '👁️' : '👁️‍🗨️'}</button>
              </div>
            </div>

            <div className="form-group">
              <label className="form-label">Confirm Password</label>
              <div className="password-wrapper">
                <input type={showPassword ? 'text' : 'password'} className="input" placeholder="Confirm your password" value={confirmPassword} onChange={(e) => setConfirmPassword(e.target.value)} disabled={loading} />
                <button type="button" className="password-toggle" onClick={() => setShowPassword(!showPassword)} disabled={loading}>{showPassword ? '👁️' : '👁️‍🗨️'}</button>
              </div>
            </div>

            <button type="submit" className="submit-btn" disabled={loading}>{loading ? 'Resetting...' : 'Reset Password'}</button>
          </form>
        )}

        <div className="back-link">
          <Link to="/login">← Back to Login</Link>
        </div>
      </div>
    </div>
  );
};

export default ForgotPasswordPage;
