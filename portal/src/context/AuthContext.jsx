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
    const res = await loginAdmin({ email, password });
    const { token, admin } = res.data;
    localStorage.setItem('sanlam_admin_token', token);
    localStorage.setItem('sanlam_admin_user', JSON.stringify(admin));
    setUser(admin);
    return admin;
  };

  const logout = () => {
    localStorage.removeItem('sanlam_admin_token');
    localStorage.removeItem('sanlam_admin_user');
    setUser(null);
    window.location.href = '/login';
  };

  return (
    <AuthContext.Provider value={{ user, login, logout, isAuthenticated: !!user, loading }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used within AuthProvider');
  return ctx;
}
