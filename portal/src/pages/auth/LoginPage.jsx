import React, { useState } from 'react';
import { useForm } from 'react-hook-form';
import { useNavigate, Link } from 'react-router-dom';
import { useAuth } from '../../context/AuthContext';
import toast from 'react-hot-toast';
import sanlam_logo from '../../assets/sanlam-logo.png';

const LoginPage = () => {
  const { login } = useAuth();
  const navigate = useNavigate();
  const { register, handleSubmit, formState: { errors, isSubmitting }, reset } = useForm();
  const [showPassword, setShowPassword] = useState(false);
  const [loginError, setLoginError] = useState('');

  const onSubmit = async (data) => {
    setLoginError('');
    try {
      await login(data.email, data.password);
      toast.success('Login successful!');
      reset();
      // Redirect to dashboard after successful login
      navigate('/', { replace: true });
    } catch (error) {
      const errorMessage = error.message || 'Login failed. Please check your credentials.';
      setLoginError(errorMessage);
      toast.error(errorMessage, {
        icon: '❌',
        duration: 4000
      });
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
      {/* Dark overlay for readability */}
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
        * {
          margin: 0;
          padding: 0;
          box-sizing: border-box;
        }

        body {
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Oxygen', 'Ubuntu', 'Cantarell', sans-serif;
        }

        @keyframes fadeInUp {
          from {
            opacity: 0;
            transform: translateY(20px);
          }
          to {
            opacity: 1;
            transform: translateY(0);
          }
        }

        @keyframes floatingCard {
          0%, 100% {
            transform: translateY(0px);
          }
          50% {
            transform: translateY(-8px);
          }
        }

        @keyframes glowPulse {
          0%, 100% {
            box-shadow: 0 0 0 0 rgba(14, 165, 233, 0.4);
          }
          50% {
            box-shadow: 0 0 0 8px rgba(14, 165, 233, 0.2);
          }
        }

        .form-section {
          width: 100%;
          max-width: 480px;
          display: flex;
          flex-direction: column;
          justify-content: center;
          padding: 60px 50px;
          background: rgba(255, 255, 255, 0.25);
          border-radius: 28px;
          box-shadow: 
            0 8px 32px rgba(0, 0, 0, 0.12),
            inset 0 1px 1px rgba(255, 255, 255, 0.3);
          backdrop-filter: blur(18px) saturate(130%);
          border: 1.5px solid rgba(255, 255, 255, 0.35);
          position: relative;
          z-index: 2;
          animation: fadeInUp 0.8s ease-out, floatingCard 4s ease-in-out infinite 0.5s;
        }

        .form-content {
          width: 100%;
        }

        .sanlam-logo {
          height: 50px;
          object-fit: contain;
          margin-bottom: 30px;
          filter: drop-shadow(0 2px 4px rgba(0, 0, 0, 0.15));
          animation: fadeInUp 0.8s ease-out;
        }

        .logo {
          font-size: 18px;
          font-weight: 800;
          color: #ffffff;
          margin-bottom: 8px;
          display: flex;
          align-items: center;
          gap: 10px;
          text-shadow: 0 2px 4px rgba(0, 0, 0, 0.2);
          animation: fadeInUp 0.8s ease-out 0.1s both;
        }

        .logo-icon {
          width: 40px;
          height: 40px;
          background: linear-gradient(135deg, rgba(255, 255, 255, 0.3), rgba(255, 255, 255, 0.15));
          border-radius: 12px;
          display: flex;
          align-items: center;
          justify-content: center;
          font-size: 20px;
          border: 1.5px solid rgba(255, 255, 255, 0.3);
        }

        .heading {
          font-size: 32px;
          font-weight: 800;
          color: #ffffff;
          margin-bottom: 6px;
          text-shadow: 0 2px 8px rgba(0, 0, 0, 0.15);
          letter-spacing: -0.5px;
          animation: fadeInUp 0.8s ease-out 0.2s both;
        }

        .subheading {
          font-size: 14px;
          color: rgba(255, 255, 255, 0.85);
          margin-bottom: 32px;
          line-height: 1.5;
          text-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
          animation: fadeInUp 0.8s ease-out 0.3s both;
        }

        .form-group {
          display: flex;
          flex-direction: column;
          margin-bottom: 16px;
          animation: fadeInUp 0.8s ease-out 0.4s both;
        }

        .label {
          font-size: 13px;
          font-weight: 600;
          color: rgba(255, 255, 255, 0.9);
          margin-bottom: 8px;
          text-transform: uppercase;
          letter-spacing: 0.5px;
          text-shadow: 0 1px 2px rgba(0, 0, 0, 0.1);
        }

        .input {
          padding: 14px 16px;
          border: 2px solid rgba(255, 255, 255, 0.3);
          border-radius: 12px;
          font-size: 14px;
          background: rgba(255, 255, 255, 0.4);
          color: #0f172a;
          transition: all 0.3s ease;
          font-family: inherit;
          font-weight: 500;
          width: 100%;
          box-sizing: border-box;
        }

        .input::placeholder {
          color: rgba(15, 23, 42, 0.5);
        }

        .input:focus {
          outline: none;
          border-color: rgba(255, 255, 255, 0.6);
          background: rgba(255, 255, 255, 0.5);
          box-shadow: 
            0 0 0 3px rgba(14, 165, 233, 0.15), 
            inset 0 0 12px rgba(14, 165, 233, 0.08),
            0 0 20px rgba(14, 165, 233, 0.3);
          transform: scale(1.01);
          animation: glowPulse 2s ease-in-out;
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

        .forgot-password {
          text-align: right;
          margin-bottom: 24px;
          margin-top: -8px;
          animation: fadeInUp 0.8s ease-out 0.45s both;
        }

        .forgot-password a {
          font-size: 13px;
          color: rgba(255, 255, 255, 0.85);
          text-decoration: none;
          font-weight: 600;
          transition: all 0.2s;
          text-shadow: 0 1px 2px rgba(0, 0, 0, 0.1);
          position: relative;
        }

        .forgot-password a:hover {
          color: rgba(255, 255, 255, 1);
          text-decoration: underline;
        }

        .error {
          color: #ff6b6b;
          font-size: 12px;
          margin-top: -12px;
          margin-bottom: 12px;
          font-weight: 500;
          text-shadow: 0 1px 2px rgba(0, 0, 0, 0.1);
          animation: fadeInUp 0.4s ease-out;
        }

        .login-btn {
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
          margin-bottom: 18px;
          text-shadow: 0 1px 2px rgba(0, 0, 0, 0.15);
          text-transform: uppercase;
          letter-spacing: 0.5px;
          animation: fadeInUp 0.8s ease-out 0.5s both;
        }

        .login-btn:hover {
          transform: translateY(-4px) scale(1.02);
          box-shadow: 0 14px 35px rgba(14, 165, 233, 0.45);
          background: linear-gradient(135deg, rgba(14, 165, 233, 1) 0%, rgba(6, 182, 212, 1) 100%);
        }

        .login-btn:active {
          transform: translateY(-2px) scale(1.01);
        }

        .login-btn:disabled {
          opacity: 0.6;
          cursor: not-allowed;
          transform: none;
        }

        .signup-link {
          text-align: center;
          font-size: 13px;
          color: rgba(255, 255, 255, 0.85);
          text-shadow: 0 1px 2px rgba(0, 0, 0, 0.1);
          animation: fadeInUp 0.8s ease-out 0.6s both;
        }

        .signup-link a {
          color: rgba(255, 255, 255, 1);
          text-decoration: none;
          font-weight: 700;
          transition: all 0.2s;
        }

        .signup-link a:hover {
          text-decoration: underline;
        }

        .download-link {
          text-align: center;
          font-size: 13px;
          color: rgba(255, 255, 255, 0.85);
          text-shadow: 0 1px 2px rgba(0, 0, 0, 0.1);
          animation: fadeInUp 0.8s ease-out 0.7s both;
          margin-top: 12px;
        }

        .download-link a {
          color: rgba(255, 255, 255, 1);
          text-decoration: none;
          font-weight: 700;
          transition: all 0.2s;
          display: inline-flex;
          align-items: center;
          gap: 6px;
          padding: 6px 12px;
          border-radius: 6px;
          background: rgba(255, 255, 255, 0.15);
          border: 1px solid rgba(255, 255, 255, 0.25);
        }

        .download-link a:hover {
          background: rgba(255, 255, 255, 0.25);
          border-color: rgba(255, 255, 255, 0.4);
          transform: translateY(-1px);
        }

        .login-error-banner {
          background: rgba(239, 68, 68, 0.2);
          border: 2px solid rgba(239, 68, 68, 0.6);
          border-radius: 12px;
          padding: 14px 16px;
          margin-bottom: 20px;
          color: #fca5a5;
          font-size: 13px;
          font-weight: 600;
          display: flex;
          align-items: center;
          gap: 10px;
          animation: fadeInUp 0.3s ease-out;
          box-shadow: 0 4px 12px rgba(239, 68, 68, 0.15);
        }

        .login-error-banner::before {
          content: '⚠️';
          font-size: 16px;
          flex-shrink: 0;
        }

        .image-section {
          display: none;
        }

        .logo-upload-section {
          margin-top: 30px;
          padding-top: 20px;
          border-top: 1px solid rgba(255, 255, 255, 0.2);
        }

        .upload-label {
          font-size: 12px;
          font-weight: 700;
          color: rgba(255, 255, 255, 0.9);
          text-transform: uppercase;
          letter-spacing: 0.5px;
          text-shadow: 0 1px 2px rgba(0, 0, 0, 0.1);
          display: block;
          margin-bottom: 12px;
        }

        .upload-area {
          position: relative;
          border: 2px dashed rgba(255, 255, 255, 0.4);
          border-radius: 12px;
          padding: 20px;
          text-align: center;
          cursor: pointer;
          transition: all 0.3s ease;
          background: rgba(255, 255, 255, 0.05);
        }

        .upload-area:hover {
          border-color: rgba(255, 255, 255, 0.6);
          background: rgba(255, 255, 255, 0.1);
        }

        .upload-area input[type='file'] {
          display: none;
        }

        .image-section {
          display: none;
        }

        @media (max-width: 1200px) {
          .form-section {
            width: 100%;
          }
        }

        @media (max-width: 768px) {
          .form-section {
            padding: 40px 20px;
          }

          .heading {
            font-size: 28px;
          }

          .logo {
            margin-bottom: 30px;
          }
        }
      `}</style>

      {/* Form Section */}
      <div className="form-section">
        <div className="form-content">
          <img 
            src={sanlam_logo} 
            alt="Sanlam Logo" 
            className="sanlam-logo"
          />

          <h1 className="heading">Welcome Back</h1>
          <p className="subheading">Monitor patient conditions, track medications, and manage chronic care securely</p>

          <form onSubmit={handleSubmit(onSubmit)}>
            {loginError && (
              <div className="login-error-banner">
                {loginError}
              </div>
            )}

            <div className="form-group">
              <label className="label">Email Address</label>
              <input
                type="email"
                className="input"
                placeholder="you@example.com"
                {...register('email', {
                  required: 'Email is required',
                  pattern: {
                    value: /^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$/i,
                    message: 'Invalid email address'
                  }
                })}
              />
              {errors.email && <span className="error">{errors.email.message}</span>}
            </div>

            <div className="form-group">
              <label className="label">Password</label>
              <div className="password-wrapper">
                <input
                  type={showPassword ? 'text' : 'password'}
                  className="input"
                  placeholder="Enter your password"
                  {...register('password', {
                    required: 'Password is required',
                    minLength: {
                      value: 6,
                      message: 'Password must be at least 6 characters'
                    }
                  })}
                />
                <button
                  type="button"
                  className="password-toggle"
                  onClick={() => setShowPassword(!showPassword)}
                >
                  {showPassword ? '👁️' : '👁️‍🗨️'}
                </button>
              </div>
              {errors.password && <span className="error">{errors.password.message}</span>}
            </div>

            <div className="forgot-password">
              <Link to="/forgot-password">Forgot your password?</Link>
            </div>

            <button
              type="submit"
              disabled={isSubmitting}
              className="login-btn"
            >
              {isSubmitting ? 'Signing In...' : 'Sign In'}
            </button>
          </form>

          <div className="signup-link">
            Don't have an account? <a href="/signup">Sign Up</a>
          </div>

          <div className="download-link">
            <a href="/download">📱 Download Mobile App</a>
          </div>
        </div>
      </div>
    </div>
  );
};

export default LoginPage;
