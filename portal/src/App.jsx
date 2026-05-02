import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { Toaster } from 'react-hot-toast';
import { AuthProvider, useAuth } from './context/AuthContext';
import DashboardLayout from './components/Layout/DashboardLayout';
import LoginPage from './pages/auth/LoginPage';
import ForgotPasswordPage from './pages/auth/ForgotPasswordPage';
import Dashboard from './pages/Dashboard';
import MembersPage from './pages/members/MembersPage';
import MemberDetailPage from './pages/members/MemberDetailPage';
import HospitalsPage from './pages/hospitals/HospitalsPage';
import InstitutionsPage from './pages/hospitals/InstitutionsPage';
import PharmaciesPage from './pages/pharmacies/PharmaciesPage';
import AppointmentsPage from './pages/appointments/AppointmentsPage';
import MedicationsPage from './pages/MedicationsPage';
import LifestylePartnersPage from './pages/lifestyle/LifestylePartnersPage';
import CMSPage from './pages/cms/CMSPage';
import NotificationsPage from './pages/notifications/NotificationsPage';
import AnalyticsPage from './pages/analytics/AnalyticsPage';
import SettingsPage from './pages/settings/SettingsPage';
import ConditionsPage from './pages/conditions/ConditionsPage';
import AlertsPage from './pages/AlertsPage';
import AuthorizationsPage from './pages/admin/AuthorizationsPage';
import ChatPage from './pages/admin/ChatPage';
import LabTestsQueuePage from './pages/admin/LabTestsQueuePage';
import AdminUsersPage from './pages/admin/AdminUsersPage';
import ReportsPage from './pages/admin/ReportsPage';
import SchemesPage from './pages/schemes/SchemesPage';
import AuditLogsPage from './pages/admin/AuditLogsPage';
import VitalsThresholdsPage from './pages/vitals/VitalsThresholdsPage';
import TreatmentPlansPage from './pages/treatmentPlans/TreatmentPlansPage';
import CareBuddiesPage from './pages/careBuddies/CareBuddiesPage';
import DownloadPage from './pages/DownloadPage';

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 1000 * 60 * 2,
      refetchOnWindowFocus: false,
    },
  },
});

function ProtectedPage({ children }) {
  return <DashboardLayout>{children}</DashboardLayout>;
}

function SuperAdminPage({ children }) {
  const { user, isSuperAdmin } = useAuth();
  if (!isSuperAdmin) {
    return <Navigate to="/" replace />;
  }
  return <DashboardLayout>{children}</DashboardLayout>;
}

function NotForContentAdminPage({ children }) {
  const { user } = useAuth();
  if (user?.role === 'content_admin') {
    return <Navigate to="/" replace />;
  }
  return <DashboardLayout>{children}</DashboardLayout>;
}

export default function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <AuthProvider>
        <BrowserRouter>
          <Routes>
            <Route path="/login" element={<LoginPage />} />
            <Route path="/forgot-password" element={<ForgotPasswordPage />} />
            <Route path="/download" element={<DownloadPage />} />
            <Route path="/" element={<ProtectedPage><Dashboard /></ProtectedPage>} />
            <Route path="/members" element={<ProtectedPage><MembersPage /></ProtectedPage>} />
            <Route path="/members/:id" element={<ProtectedPage><MemberDetailPage /></ProtectedPage>} />
            <Route path="/hospitals" element={<ProtectedPage><InstitutionsPage /></ProtectedPage>} />
            <Route path="/pharmacies" element={<ProtectedPage><PharmaciesPage /></ProtectedPage>} />
            <Route path="/appointments" element={<ProtectedPage><AppointmentsPage /></ProtectedPage>} />
            <Route path="/medications" element={<ProtectedPage><MedicationsPage /></ProtectedPage>} />
            <Route path="/lifestyle-partners" element={<ProtectedPage><LifestylePartnersPage /></ProtectedPage>} />
            <Route path="/cms" element={<ProtectedPage><CMSPage /></ProtectedPage>} />
            <Route path="/conditions" element={<ProtectedPage><ConditionsPage /></ProtectedPage>} />
            <Route path="/notifications" element={<NotForContentAdminPage><NotificationsPage /></NotForContentAdminPage>} />
            <Route path="/authorizations" element={<ProtectedPage><AuthorizationsPage /></ProtectedPage>} />
            <Route path="/chat" element={<ProtectedPage><ChatPage /></ProtectedPage>} />
            <Route path="/lab-tests/queue" element={<ProtectedPage><LabTestsQueuePage /></ProtectedPage>} />
            <Route path="/admin-users" element={<SuperAdminPage><AdminUsersPage /></SuperAdminPage>} />
            <Route path="/reports" element={<ProtectedPage><ReportsPage /></ProtectedPage>} />
            <Route path="/schemes" element={<ProtectedPage><SchemesPage /></ProtectedPage>} />
            <Route path="/alerts" element={<ProtectedPage><AlertsPage /></ProtectedPage>} />
            <Route path="/vitals-thresholds" element={<ProtectedPage><VitalsThresholdsPage /></ProtectedPage>} />
            <Route path="/treatment-plans" element={<ProtectedPage><TreatmentPlansPage /></ProtectedPage>} />
            <Route path="/care-buddies" element={<ProtectedPage><CareBuddiesPage /></ProtectedPage>} />
            <Route path="/audit-logs" element={<SuperAdminPage><AuditLogsPage /></SuperAdminPage>} />
            <Route path="/analytics" element={<NotForContentAdminPage><AnalyticsPage /></NotForContentAdminPage>} />
            <Route path="/settings" element={<ProtectedPage><SettingsPage /></ProtectedPage>} />
            <Route path="*" element={<Navigate to="/" replace />} />
          </Routes>
        </BrowserRouter>
        <Toaster
          position="top-right"
          toastOptions={{
            style: { fontSize: '14px', borderRadius: '8px' },
            success: { iconTheme: { primary: '#7AB800', secondary: '#fff' } },
          }}
        />
      </AuthProvider>
    </QueryClientProvider>
  );
}
