import { createContext, useContext, useState, useEffect } from 'react';
import { loginAdmin } from '../api/auth';

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const token = localStorage.getItem('sanlam_admin_token');
    const stored = localStorage.getItem('sanlam_admin_user');
    if (token && stored) {
      try {
        setUser(JSON.parse(stored));
      } catch {
        localStorage.removeItem('sanlam_admin_user');
      }
    }
    setLoading(false);
  }, []);

  const login = async (email, password) => {
    try {
      const res = await loginAdmin({ email, password });
      const { token, admin } = res.data;
      localStorage.setItem('sanlam_admin_token', token);
      localStorage.setItem('sanlam_admin_refresh_token', res.data.refreshToken);
      localStorage.setItem('sanlam_admin_user', JSON.stringify(admin));
      setUser(admin);
      return admin;
    } catch (error) {
      // Extract backend error message or provide user-friendly default
      const message = error.response?.data?.message || 'Invalid email or password. Please try again.';
      const err = new Error(message);
      throw err;
    }
  };

  const logout = () => {
    localStorage.removeItem('sanlam_admin_token');
    localStorage.removeItem('sanlam_admin_refresh_token');
    localStorage.removeItem('sanlam_admin_user');
    setUser(null);
    window.location.href = '/login';
  };

  return (
    <AuthContext.Provider value={{ user, login, logout, isAuthenticated: !!user, loading, isSuperAdmin: user?.role === 'super_admin' }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used within AuthProvider');
  return ctx;
}
