import { useState, useRef, useEffect } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import { BellIcon, UserCircleIcon, CalendarDaysIcon } from '@heroicons/react/24/outline';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { useAuth } from '../../context/AuthContext';
import { getAdminNotifications, markAdminNotificationRead } from '../../api/notifications';
import { format } from 'date-fns';

const TITLES = {
  '/': 'Dashboard',
  '/members': 'Members',
  '/hospitals': 'Hospitals',
  '/pharmacies': 'Pharmacies',
  '/appointments': 'Appointments',
  '/medications': 'Medications',
  '/lifestyle-partners': 'Lifestyle Partners',
  '/cms': 'Content Management',
  '/conditions': 'Conditions',
  '/notifications': 'Notifications',
  '/authorizations': 'Authorizations',
  '/chat': 'Admin Messaging',
  '/lab-tests/queue': 'Lab Tests Queue',
  '/admin-users': 'Admin Users',
  '/reports': 'Reports',
  '/alerts': 'Alerts',
  '/analytics': 'Analytics',
  '/settings': 'Settings',
};

export default function TopBar() {
  const { pathname } = useLocation();
  const navigate = useNavigate();
  const { user } = useAuth();
  const qc = useQueryClient();
  const [open, setOpen] = useState(false);
  const dropdownRef = useRef(null);

  const title = TITLES[pathname]
    || (pathname.startsWith('/members/') ? 'Member Detail' : 'Page');

  const { data: notifData } = useQuery({
    queryKey: ['adminNotifications'],
    queryFn: () => getAdminNotifications({ limit: 15 }).then((r) => r.data),
    refetchInterval: 30000, // refresh every 30s
    retry: false,
    placeholderData: { notifications: [], unread_count: 0 },
  });

  const readMutation = useMutation({
    mutationFn: markAdminNotificationRead,
    onSuccess: () => qc.invalidateQueries(['adminNotifications']),
  });

  const notifications = notifData?.notifications || [];
  const unreadCount = notifData?.unread_count || 0;

  useEffect(() => {
    const handler = (e) => {
      if (dropdownRef.current && !dropdownRef.current.contains(e.target)) {
        setOpen(false);
      }
    };
    document.addEventListener('mousedown', handler);
    return () => document.removeEventListener('mousedown', handler);
  }, []);

  return (
    <header style={{
      height: '60px',
      background: '#fff',
      borderBottom: '1px solid #e2e8f0',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'space-between',
      padding: '0 24px',
      boxShadow: '0 1px 3px rgba(0,0,0,0.05)',
      position: 'sticky',
      top: 0,
      zIndex: 50,
    }}>
      <h1 style={{ margin: 0, fontSize: '18px', fontWeight: '700', color: 'var(--text)' }}>
        {title}
      </h1>
      <div style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
        {/* Notification Bell */}
        <div ref={dropdownRef} style={{ position: 'relative' }}>
          <button
            onClick={() => setOpen((v) => !v)}
            style={{
              background: 'none', border: 'none', cursor: 'pointer',
              padding: '6px', borderRadius: '8px', position: 'relative',
              color: '#64748b',
            }}>
            <BellIcon style={{ width: 20, height: 20 }} />
            {unreadCount > 0 && (
              <span style={{
                position: 'absolute', top: 2, right: 2,
                minWidth: '16px', height: '16px',
                background: '#ef4444', borderRadius: '8px',
                border: '2px solid #fff',
                fontSize: '9px', fontWeight: '700', color: '#fff',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                padding: '0 2px',
              }}>
                {unreadCount > 9 ? '9+' : unreadCount}
              </span>
            )}
          </button>

          {open && (
            <div style={{
              position: 'absolute', top: '100%', right: 0, marginTop: '8px',
              width: '340px', background: '#fff', borderRadius: '12px',
              boxShadow: '0 8px 30px rgba(0,0,0,0.12)', border: '1px solid #e2e8f0',
              zIndex: 100, overflow: 'hidden',
            }}>
              <div style={{ padding: '12px 16px', borderBottom: '1px solid #f1f5f9', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <span style={{ fontWeight: '600', fontSize: '14px', color: 'var(--text)' }}>Notifications</span>
                {unreadCount > 0 && (
                  <span style={{ fontSize: '11px', color: 'var(--primary)', fontWeight: '500' }}>
                    {unreadCount} unread
                  </span>
                )}
              </div>
              <div style={{ maxHeight: '360px', overflowY: 'auto' }}>
                {notifications.length === 0 ? (
                  <div style={{ padding: '24px 16px', textAlign: 'center', color: '#94a3b8', fontSize: '13px' }}>
                    No notifications yet
                  </div>
                ) : notifications.map((n) => (
                  <div
                    key={n.id}
                    onClick={() => {
                      if (n.is_unread) readMutation.mutate(n.id);
                      if (n.reference_type === 'appointment') {
                        navigate('/appointments');
                        setOpen(false);
                      }
                    }}
                    style={{
                      padding: '12px 16px',
                      borderBottom: '1px solid #f8fafc',
                      cursor: 'pointer',
                      background: n.is_unread ? '#f0f7ff' : '#fff',
                      display: 'flex', gap: '10px', alignItems: 'flex-start',
                      transition: 'background 0.15s',
                    }}
                  >
                    <CalendarDaysIcon style={{ width: 18, height: 18, color: 'var(--primary)', flexShrink: 0, marginTop: 2 }} />
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <p style={{ margin: 0, fontSize: '13px', fontWeight: n.is_unread ? '600' : '400', color: 'var(--text)', lineHeight: 1.4 }}>
                        {n.title}
                      </p>
                      <p style={{ margin: '2px 0 0', fontSize: '12px', color: '#64748b', lineHeight: 1.4 }}>
                        {n.message}
                      </p>
                      <p style={{ margin: '4px 0 0', fontSize: '11px', color: '#94a3b8' }}>
                        {n.sent_at ? format(new Date(n.sent_at), 'dd MMM yyyy · HH:mm') : ''}
                      </p>
                    </div>
                    {n.is_unread && (
                      <span style={{ width: 8, height: 8, background: 'var(--primary)', borderRadius: '50%', flexShrink: 0, marginTop: 4 }} />
                    )}
                  </div>
                ))}
              </div>
              <div
                onClick={() => { navigate('/appointments'); setOpen(false); }}
                style={{ padding: '10px 16px', textAlign: 'center', fontSize: '12px', color: 'var(--primary)', fontWeight: '600', cursor: 'pointer', borderTop: '1px solid #f1f5f9' }}
              >
                View all appointments →
              </div>
            </div>
          )}
        </div>

        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
          <UserCircleIcon style={{ width: 32, height: 32, color: 'var(--primary)' }} />
          <div>
            <p style={{ margin: 0, fontSize: '13px', fontWeight: '600', color: 'var(--text)' }}>
              {user?.name || user?.email || 'Admin'}
            </p>
            <p style={{ margin: 0, fontSize: '11px', color: '#64748b', textTransform: 'capitalize' }}>
              {user?.role || 'Administrator'}
            </p>
          </div>
        </div>
      </div>
    </header>
  );
}
