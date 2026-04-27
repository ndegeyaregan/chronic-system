import { NavLink } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';
import {
  HomeIcon,
  UsersIcon,
  BuildingOffice2Icon,
  BuildingStorefrontIcon,
  CalendarDaysIcon,
  HeartIcon,
  SparklesIcon,
  DocumentTextIcon,
  BellIcon,
  BellAlertIcon,
  ChartBarIcon,
  Cog6ToothIcon,
  ArrowLeftOnRectangleIcon,
  ClipboardDocumentListIcon,
  ClipboardDocumentCheckIcon,
  ShieldCheckIcon,
  ChatBubbleLeftRightIcon,
  BeakerIcon,
  UserPlusIcon,
  UserGroupIcon,
  DocumentArrowDownIcon,
  DocumentMagnifyingGlassIcon,
  RectangleStackIcon,
} from '@heroicons/react/24/outline';
import { useAuth } from '../../context/AuthContext';
import { getAdminAlerts } from '../../api/alerts';
import sanlamLogo from '../../assets/sanlam-logo.png';

const NAV_ITEMS = [
  { to: '/', label: 'Dashboard', Icon: HomeIcon, end: true },
  { to: '/members', label: 'Members', Icon: UsersIcon },
  { to: '/schemes', label: 'Schemes', Icon: RectangleStackIcon },
  { to: '/hospitals', label: 'Hospitals', Icon: BuildingOffice2Icon },
  { to: '/pharmacies', label: 'Pharmacies', Icon: BuildingStorefrontIcon },
  { to: '/appointments', label: 'Appointments', Icon: CalendarDaysIcon },
  { to: '/medications', label: 'Medications', Icon: HeartIcon },
  { to: '/treatment-plans', label: 'Treatment Plans', Icon: ClipboardDocumentCheckIcon },
  { to: '/care-buddies', label: 'Care Buddies', Icon: UserGroupIcon },
  { to: '/lifestyle-partners', label: 'Lifestyle Partners', Icon: SparklesIcon },
  { to: '/cms', label: 'Content (CMS)', Icon: DocumentTextIcon },
  { to: '/conditions', label: 'Conditions', Icon: ClipboardDocumentListIcon },
  { to: '/vitals-thresholds', label: 'Vital Thresholds', Icon: BeakerIcon },
  { to: '/notifications', label: 'Notifications', Icon: BellIcon },
  { to: '/authorizations', label: 'Authorizations', Icon: ShieldCheckIcon },
  { to: '/chat', label: 'Messaging', Icon: ChatBubbleLeftRightIcon },
  { to: '/lab-tests/queue', label: 'Lab Tests Queue', Icon: BeakerIcon },
  { to: '/admin-users', label: 'Admin Users', Icon: UserPlusIcon },
  { to: '/reports', label: 'Reports', Icon: DocumentArrowDownIcon },
  { to: '/alerts', label: 'Alerts', Icon: BellAlertIcon, showBadge: true },
  { to: '/analytics', label: 'Analytics', Icon: ChartBarIcon },
  { to: '/audit-logs', label: 'Audit Logs', Icon: DocumentMagnifyingGlassIcon },
  { to: '/settings', label: 'Settings', Icon: Cog6ToothIcon },
];

export default function Sidebar() {
  const { user, logout, isSuperAdmin } = useAuth();

  const { data: alertsData } = useQuery({
    queryKey: ['admin-alerts-sidebar'],
    queryFn: () => getAdminAlerts({ is_read: false, limit: 100 }),
    refetchInterval: 30000,
    retry: false,
  });

  const unreadCount =
    alertsData?.unread_count ??
    (Array.isArray(alertsData?.alerts)
      ? alertsData.alerts.filter((a) => !a.is_read).length
      : 0);

  // Filter nav items by role
  const filteredNavItems = NAV_ITEMS.filter(item => {
    // Hide admin-users page from non-super admins
    if (item.to === '/admin-users' && !isSuperAdmin) {
      return false;
    }
    // Hide analytics from content_admin
    if (item.to === '/analytics' && user?.role === 'content_admin') {
      return false;
    }
    // Hide audit-logs from non-super admins
    if (item.to === '/audit-logs' && !isSuperAdmin) {
      return false;
    }
    // Hide notifications from content_admin
    if (item.to === '/notifications' && user?.role === 'content_admin') {
      return false;
    }
    return true;
  });

  return (
    <aside style={{
      width: '240px',
      minHeight: '100vh',
      background: 'var(--primary)',
      display: 'flex',
      flexDirection: 'column',
      flexShrink: 0,
      position: 'fixed',
      top: 0,
      left: 0,
      bottom: 0,
      zIndex: 100,
      boxShadow: '2px 0 8px rgba(0,0,0,0.15)',
    }}>
      {/* Logo */}
      <div style={{
        padding: '20px 20px 18px',
        borderBottom: '1px solid rgba(255,255,255,0.12)',
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
          <img
            src={sanlamLogo}
            alt="Sanlam Allianz"
            style={{ width: '140px', filter: 'brightness(0) invert(1)', opacity: 0.92 }}
          />
        </div>
        <p style={{ margin: '6px 0 0', color: 'rgba(255,255,255,0.55)', fontSize: '11px' }}>
          Chronic Care Admin
        </p>
      </div>

      {/* Navigation */}
      <nav style={{ flex: 1, overflowY: 'auto', padding: '12px 0' }}>
        {filteredNavItems.map((item) => {
          const NavIcon = item.Icon;
          return (
          <NavLink
            key={item.to}
            to={item.to}
            end={item.end}
            style={({ isActive }) => ({
              display: 'flex',
              alignItems: 'center',
              gap: '10px',
              padding: '10px 20px',
              color: isActive ? '#fff' : 'rgba(255,255,255,0.7)',
              textDecoration: 'none',
              fontSize: '14px',
              fontWeight: isActive ? '600' : '400',
              background: isActive ? 'rgba(255,255,255,0.15)' : 'transparent',
              borderLeft: isActive ? '3px solid var(--accent)' : '3px solid transparent',
              transition: 'all 0.15s',
              borderRadius: '0 6px 6px 0',
              marginRight: '8px',
            })}
          >
            <NavIcon style={{ width: 18, height: 18, flexShrink: 0 }} />
            {item.label}
            {item.showBadge && unreadCount > 0 && (
              <span style={{
                background: '#ef4444',
                color: '#fff',
                fontSize: '10px',
                fontWeight: '700',
                padding: '1px 6px',
                borderRadius: '999px',
                marginLeft: 'auto',
                minWidth: '18px',
                textAlign: 'center',
              }}>
                {unreadCount}
              </span>
            )}
          </NavLink>
          );
        })}
      </nav>

      {/* User section */}
      <div style={{
        borderTop: '1px solid rgba(255,255,255,0.12)',
        padding: '16px 20px',
      }}>
        {user && (
          <div style={{ marginBottom: '12px' }}>
            <p style={{ margin: 0, color: '#fff', fontSize: '13px', fontWeight: '600' }}>
              {user.name || user.email}
            </p>
            <p style={{ margin: '2px 0 0', color: 'rgba(255,255,255,0.55)', fontSize: '11px', textTransform: 'capitalize' }}>
              {user.role || 'Admin'}
            </p>
          </div>
        )}
        <div style={{ display: 'flex', gap: '8px', marginBottom: '12px' }}>
          <button
            onClick={() => window.location.href = '/settings'}
            style={{
              flex: 1,
              display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '6px',
              background: 'linear-gradient(135deg, rgba(59, 130, 246, 0.3), rgba(34, 197, 94, 0.3))',
              border: '1.5px solid rgba(59, 130, 246, 0.5)',
              color: '#fff', borderRadius: '8px',
              padding: '10px 12px', fontSize: '12px', fontWeight: '600',
              cursor: 'pointer',
              transition: 'all 0.2s',
            }}
            onMouseEnter={(e) => {
              e.currentTarget.style.background = 'linear-gradient(135deg, rgba(59, 130, 246, 0.4), rgba(34, 197, 94, 0.4))';
              e.currentTarget.style.boxShadow = '0 4px 12px rgba(59, 130, 246, 0.3)';
            }}
            onMouseLeave={(e) => {
              e.currentTarget.style.background = 'linear-gradient(135deg, rgba(59, 130, 246, 0.3), rgba(34, 197, 94, 0.3))';
              e.currentTarget.style.boxShadow = 'none';
            }}
            title="Update profile and credentials"
          >
            <Cog6ToothIcon style={{ width: 14, height: 14 }} />
            Settings
          </button>
          <button
            onClick={logout}
            style={{
              flex: 1,
              display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '6px',
              background: 'linear-gradient(135deg, rgba(239, 68, 68, 0.3), rgba(220, 38, 38, 0.3))',
              border: '1.5px solid rgba(239, 68, 68, 0.5)',
              color: '#fecaca', borderRadius: '8px',
              padding: '10px 12px', fontSize: '12px', fontWeight: '600',
              cursor: 'pointer',
              transition: 'all 0.2s',
            }}
            onMouseEnter={(e) => {
              e.currentTarget.style.background = 'linear-gradient(135deg, rgba(239, 68, 68, 0.4), rgba(220, 38, 38, 0.4))';
              e.currentTarget.style.boxShadow = '0 4px 12px rgba(239, 68, 68, 0.3)';
              e.currentTarget.style.color = '#fff';
            }}
            onMouseLeave={(e) => {
              e.currentTarget.style.background = 'linear-gradient(135deg, rgba(239, 68, 68, 0.3), rgba(220, 38, 38, 0.3))';
              e.currentTarget.style.boxShadow = 'none';
              e.currentTarget.style.color = '#fecaca';
            }}
            title="Logout and return to login"
          >
            <ArrowLeftOnRectangleIcon style={{ width: 14, height: 14 }} />
            Logout
          </button>
        </div>
      </div>
    </aside>
  );
}
