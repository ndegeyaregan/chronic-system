import React, { useMemo, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { format } from 'date-fns';
import { useAuth } from '../../context/AuthContext';
import toast from 'react-hot-toast';
import {
  UsersIcon, ClipboardDocumentCheckIcon, BeakerIcon, DocumentTextIcon,
  CalendarDaysIcon, HeartIcon, TableCellsIcon, ArrowDownTrayIcon,
  DocumentArrowDownIcon, ChartBarIcon, FunnelIcon,
  ChartPieIcon, ArrowTrendingUpIcon,
} from '@heroicons/react/24/outline';
import {
  getMembersReportData, getAuthorizationsReportData, getLabTestsReportData,
  getPrescriptionsReportData, getTreatmentPlansReportData, getAppointmentsReportData,
  getVitalsReportData, getConditionsEnrollmentData,
  downloadMembersCsv, downloadAuthorizationsCsv, downloadLabTestsCsv,
  downloadPrescriptionsCsv, downloadTreatmentPlansCsv, downloadAppointmentsCsv,
  downloadVitalsCsv, downloadConditionsCsv,
} from '../../api/reports';
import Button from '../../components/UI/Button';
import Spinner from '../../components/UI/Spinner';
import Table from '../../components/UI/Table';
import { downloadBlob, exportRowsToPdf, exportRowsToXlsx } from '../../utils/reportExports';
import axios from '../../api/axios';

/* ─────────────────── Report Catalog ─────────────────── */
const REPORTS = [
  {
    id: 'members',
    label: 'Members',
    description: 'All registered members — contact info, plan type, conditions, status',
    icon: UsersIcon,
    color: '#3b82f6',
    hasDateFilter: false,
    hasStatusFilter: false,
    queryFn: () => getMembersReportData(),
    csvFn: () => downloadMembersCsv(),
    filename: 'members_report',
    sheetName: 'Members',
    columns: [
      { key: 'member_number', label: 'Member #' },
      { key: 'first_name',    label: 'First Name' },
      { key: 'last_name',     label: 'Last Name' },
      { key: 'email',         label: 'Email' },
      { key: 'phone',         label: 'Phone' },
      { key: 'gender',        label: 'Gender' },
      { key: 'plan',          label: 'Plan' },
      { key: 'conditions',    label: 'Conditions' },
      { key: 'is_active',     label: 'Active', render: (v) => v ? 'Yes' : 'No' },
      { key: 'created_at',    label: 'Registered', render: (v) => v ? format(new Date(v), 'dd MMM yyyy') : '—' },
    ],
    previewColumns: (rows) => [
      { key: 'member_number', header: 'Member #' },
      { key: 'name', header: 'Name', render: (_, r) => `${r.first_name} ${r.last_name}` },
      { key: 'email', header: 'Email' },
      { key: 'plan', header: 'Plan' },
      { key: 'conditions', header: 'Conditions', render: (v) => Array.isArray(v) ? v.join(', ') || '—' : v || '—' },
      { key: 'is_active', header: 'Active', render: (v) => v ? '✓ Yes' : '✗ No' },
      { key: 'created_at', header: 'Registered', render: (v) => v ? format(new Date(v), 'dd MMM yyyy') : '—' },
    ],
  },
  {
    id: 'authorizations',
    label: 'Authorization History',
    description: 'All authorization requests — type, provider, status, reviewer, date range',
    icon: ClipboardDocumentCheckIcon,
    color: '#f59e0b',
    hasDateFilter: true,
    hasStatusFilter: true,
    statusOptions: ['pending','approved','rejected','cancelled'],
    queryFn: (p) => getAuthorizationsReportData(p),
    csvFn: (p) => downloadAuthorizationsCsv(p),
    filename: 'authorizations_report',
    sheetName: 'Authorizations',
    columns: [
      { key: 'member_number',    label: 'Member #' },
      { key: 'member_name',      label: 'Member' },
      { key: 'request_type',     label: 'Request Type', render: (v) => v?.replace(/_/g,' ') },
      { key: 'provider_name',    label: 'Provider' },
      { key: 'provider_type',    label: 'Provider Type' },
      { key: 'status',           label: 'Status' },
      { key: 'admin_comments',   label: 'Admin Comments' },
      { key: 'reviewed_by_name', label: 'Reviewed By' },
      { key: 'scheduled_date',   label: 'Scheduled', render: (v) => v ? format(new Date(v), 'dd MMM yyyy') : '—' },
      { key: 'created_at',       label: 'Created', render: (v) => v ? format(new Date(v), 'dd MMM yyyy') : '—' },
    ],
    previewColumns: () => [
      { key: 'member_number', header: 'Member #' },
      { key: 'member_name', header: 'Member' },
      { key: 'request_type', header: 'Type', render: (v) => v?.replace(/_/g,' ') },
      { key: 'provider_name', header: 'Provider' },
      { key: 'status', header: 'Status' },
      { key: 'reviewed_by_name', header: 'Reviewed By' },
      { key: 'created_at', header: 'Date', render: (v) => v ? format(new Date(v), 'dd MMM yyyy') : '—' },
    ],
  },
  {
    id: 'lab-tests',
    label: 'Lab Tests',
    description: 'All scheduled and completed lab tests — status, results, due dates',
    icon: BeakerIcon,
    color: '#10b981',
    hasDateFilter: true,
    hasStatusFilter: true,
    statusOptions: ['pending','completed','overdue'],
    queryFn: (p) => getLabTestsReportData(p),
    csvFn: (p) => downloadLabTestsCsv(p),
    filename: 'lab_tests_report',
    sheetName: 'Lab Tests',
    columns: [
      { key: 'member_number', label: 'Member #' },
      { key: 'member_name',   label: 'Member' },
      { key: 'test_type',     label: 'Test Type', render: (v) => v?.replace(/_/g,' ') },
      { key: 'due_date',      label: 'Due Date', render: (v) => v ? format(new Date(v), 'dd MMM yyyy') : '—' },
      { key: 'scheduled_date',label: 'Scheduled', render: (v) => v ? format(new Date(v), 'dd MMM yyyy') : '—' },
      { key: 'status',        label: 'Status' },
      { key: 'completed_at',  label: 'Completed', render: (v) => v ? format(new Date(v), 'dd MMM yyyy') : '—' },
      { key: 'result_notes',  label: 'Result Notes' },
    ],
    previewColumns: () => [
      { key: 'member_number', header: 'Member #' },
      { key: 'member_name', header: 'Member' },
      { key: 'test_type', header: 'Test Type', render: (v) => v?.replace(/_/g,' ') },
      { key: 'due_date', header: 'Due Date', render: (v) => v ? format(new Date(v), 'dd MMM yyyy') : '—' },
      { key: 'status', header: 'Status' },
      { key: 'completed_at', header: 'Completed', render: (v) => v ? format(new Date(v), 'dd MMM yyyy') : '—' },
      { key: 'result_notes', header: 'Result', render: (v) => v || '—' },
    ],
  },
  {
    id: 'prescriptions',
    label: 'Prescriptions',
    description: 'Member medication prescriptions — drug, dosage, refill schedule, active status',
    icon: DocumentTextIcon,
    color: '#0ea5e9',
    hasDateFilter: true,
    hasStatusFilter: false,
    queryFn: (p) => getPrescriptionsReportData(p),
    csvFn: (p) => downloadPrescriptionsCsv(p),
    filename: 'prescriptions_report',
    sheetName: 'Prescriptions',
    columns: [
      { key: 'member_number',   label: 'Member #' },
      { key: 'member_name',     label: 'Member' },
      { key: 'medication_name', label: 'Medication' },
      { key: 'generic_name',    label: 'Generic Name' },
      { key: 'dosage',          label: 'Dosage' },
      { key: 'frequency',       label: 'Frequency' },
      { key: 'start_date',      label: 'Start Date', render: (v) => v ? format(new Date(v), 'dd MMM yyyy') : '—' },
      { key: 'end_date',        label: 'End Date', render: (v) => v ? format(new Date(v), 'dd MMM yyyy') : '—' },
      { key: 'next_refill_date',label: 'Next Refill', render: (v) => v ? format(new Date(v), 'dd MMM yyyy') : '—' },
      { key: 'active_status',   label: 'Status' },
    ],
    previewColumns: () => [
      { key: 'member_number', header: 'Member #' },
      { key: 'member_name', header: 'Member' },
      { key: 'medication_name', header: 'Medication' },
      { key: 'dosage', header: 'Dosage' },
      { key: 'frequency', header: 'Frequency' },
      { key: 'next_refill_date', header: 'Next Refill', render: (v) => v ? format(new Date(v), 'dd MMM yyyy') : '—' },
      { key: 'active_status', header: 'Status' },
    ],
  },
  {
    id: 'treatment-plans',
    label: 'Treatment Plans',
    description: 'Member treatment plans — condition, provider, cost, status, dates',
    icon: ChartBarIcon,
    color: '#ec4899',
    hasDateFilter: true,
    hasStatusFilter: true,
    statusOptions: ['active','completed','cancelled'],
    queryFn: (p) => getTreatmentPlansReportData(p),
    csvFn: (p) => downloadTreatmentPlansCsv(p),
    filename: 'treatment_plans_report',
    sheetName: 'Treatment Plans',
    columns: [
      { key: 'member_number',   label: 'Member #' },
      { key: 'member_name',     label: 'Member' },
      { key: 'condition_name',  label: 'Condition' },
      { key: 'title',           label: 'Plan Title' },
      { key: 'status',          label: 'Status' },
      { key: 'provider_name',   label: 'Provider' },
      { key: 'plan_date',       label: 'Plan Date', render: (v) => v ? format(new Date(v), 'dd MMM yyyy') : '—' },
      { key: 'cost',            label: 'Cost' },
      { key: 'currency',        label: 'Currency' },
    ],
    previewColumns: () => [
      { key: 'member_number', header: 'Member #' },
      { key: 'member_name', header: 'Member' },
      { key: 'condition_name', header: 'Condition' },
      { key: 'title', header: 'Plan Title' },
      { key: 'status', header: 'Status' },
      { key: 'provider_name', header: 'Provider' },
      { key: 'plan_date', header: 'Date', render: (v) => v ? format(new Date(v), 'dd MMM yyyy') : '—' },
      { key: 'cost', header: 'Cost', render: (v, r) => v ? `${r.currency} ${v}` : '—' },
    ],
  },
  {
    id: 'appointments',
    label: 'Appointments',
    description: 'Appointment bookings — hospital, condition, date, time, status',
    icon: CalendarDaysIcon,
    color: '#0ea5e9',
    hasDateFilter: true,
    hasStatusFilter: true,
    statusOptions: ['pending','confirmed','completed','cancelled','missed'],
    queryFn: (p) => getAppointmentsReportData(p),
    csvFn: (p) => downloadAppointmentsCsv(p),
    filename: 'appointments_report',
    sheetName: 'Appointments',
    columns: [
      { key: 'member_number',    label: 'Member #' },
      { key: 'member_name',      label: 'Member' },
      { key: 'hospital_name',    label: 'Hospital' },
      { key: 'condition_name',   label: 'Condition' },
      { key: 'appointment_date', label: 'Date', render: (v) => v ? format(new Date(v), 'dd MMM yyyy') : '—' },
      { key: 'preferred_time',   label: 'Time' },
      { key: 'status',           label: 'Status' },
      { key: 'reason',           label: 'Reason' },
    ],
    previewColumns: () => [
      { key: 'member_number', header: 'Member #' },
      { key: 'member_name', header: 'Member' },
      { key: 'hospital_name', header: 'Hospital' },
      { key: 'condition_name', header: 'Condition' },
      { key: 'appointment_date', header: 'Date', render: (v) => v ? format(new Date(v), 'dd MMM yyyy') : '—' },
      { key: 'preferred_time', header: 'Time' },
      { key: 'status', header: 'Status' },
    ],
  },
  {
    id: 'vitals',
    label: 'Vitals',
    description: 'Member vitals readings — BP, blood sugar, heart rate, weight, mood',
    icon: HeartIcon,
    color: '#ef4444',
    hasDateFilter: true,
    hasStatusFilter: false,
    queryFn: (p) => getVitalsReportData(p),
    csvFn: (p) => downloadVitalsCsv(p),
    filename: 'vitals_report',
    sheetName: 'Vitals',
    columns: [
      { key: 'member_number',   label: 'Member #' },
      { key: 'member_name',     label: 'Member' },
      { key: 'recorded_at',     label: 'Recorded At', render: (v) => v ? format(new Date(v), 'dd MMM yyyy') : '—' },
      { key: 'blood_sugar_mmol',label: 'Blood Sugar (mmol)' },
      { key: 'systolic_bp',     label: 'Systolic BP' },
      { key: 'diastolic_bp',    label: 'Diastolic BP' },
      { key: 'heart_rate',      label: 'Heart Rate' },
      { key: 'weight_kg',       label: 'Weight (kg)' },
      { key: 'o2_saturation',   label: 'O2 Sat (%)' },
      { key: 'temperature_c',   label: 'Temp (°C)' },
      { key: 'mood',            label: 'Mood' },
    ],
    previewColumns: () => [
      { key: 'member_number', header: 'Member #' },
      { key: 'member_name', header: 'Member' },
      { key: 'recorded_at', header: 'Date', render: (v) => v ? format(new Date(v), 'dd MMM yyyy') : '—' },
      { key: 'blood_sugar_mmol', header: 'Blood Sugar' },
      { key: 'systolic_bp', header: 'Systolic' },
      { key: 'diastolic_bp', header: 'Diastolic' },
      { key: 'heart_rate', header: 'Heart Rate' },
      { key: 'weight_kg', header: 'Weight (kg)' },
      { key: 'mood', header: 'Mood' },
    ],
  },
  {
    id: 'conditions',
    label: 'Conditions Enrollment',
    description: 'Conditions with member enrollment counts — active vs total, diagnosis dates',
    icon: TableCellsIcon,
    color: '#64748b',
    hasDateFilter: false,
    hasStatusFilter: false,
    queryFn: () => getConditionsEnrollmentData(),
    csvFn: () => downloadConditionsCsv(),
    filename: 'conditions_enrollment_report',
    sheetName: 'Conditions',
    columns: [
      { key: 'condition_name',    label: 'Condition' },
      { key: 'description',       label: 'Description' },
      { key: 'total_enrolled',    label: 'Total Enrolled' },
      { key: 'active_members',    label: 'Active Members' },
      { key: 'earliest_diagnosis',label: 'First Diagnosis', render: (v) => v ? format(new Date(v), 'dd MMM yyyy') : '—' },
      { key: 'latest_diagnosis',  label: 'Latest Diagnosis', render: (v) => v ? format(new Date(v), 'dd MMM yyyy') : '—' },
    ],
    previewColumns: () => [
      { key: 'condition_name', header: 'Condition' },
      { key: 'description', header: 'Description' },
      { key: 'total_enrolled', header: 'Total Enrolled' },
      { key: 'active_members', header: 'Active Members' },
      { key: 'earliest_diagnosis', header: 'First Diagnosis', render: (v) => v ? format(new Date(v), 'dd MMM yyyy') : '—' },
      { key: 'latest_diagnosis', header: 'Latest Diagnosis', render: (v) => v ? format(new Date(v), 'dd MMM yyyy') : '—' },
    ],
  },
];

/* ─────────────────── Report Cards Components ─────────────────── */

function ContentAdminCard({ admin }) {
  return (
    <div style={{
      background: '#fff', border: '1px solid #e2e8f0', borderRadius: '8px',
      padding: '14px', display: 'flex', justifyContent: 'space-between', alignItems: 'center',
    }}>
      <div>
        <div style={{ fontWeight: '600', fontSize: '14px', color: '#1e293b' }}>{admin.name}</div>
        <div style={{ fontSize: '12px', color: '#64748b', marginTop: '2px' }}>{admin.email}</div>
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px', textAlign: 'right' }}>
        <div>
          <div style={{ fontSize: '18px', fontWeight: '700', color: '#3b82f6' }}>{admin.total_treatment_plans}</div>
          <div style={{ fontSize: '11px', color: '#64748b' }}>Treatment Plans</div>
        </div>
        <div>
          <div style={{ fontSize: '18px', fontWeight: '700', color: '#10b981' }}>{admin.members_managed}</div>
          <div style={{ fontSize: '11px', color: '#64748b' }}>Members</div>
        </div>
      </div>
    </div>
  );
}

function SchemeCard({ scheme }) {
  return (
    <div style={{
      background: '#fff', border: '1px solid #e2e8f0', borderRadius: '8px',
      padding: '14px', display: 'flex', justifyContent: 'space-between', alignItems: 'center',
    }}>
      <div>
        <div style={{ fontWeight: '600', fontSize: '14px', color: '#1e293b' }}>{scheme.name}</div>
        <div style={{ fontSize: '12px', color: '#64748b', marginTop: '2px' }}>Code: {scheme.code || '—'}</div>
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px', textAlign: 'right' }}>
        <div>
          <div style={{ fontSize: '18px', fontWeight: '700', color: '#8b5cf6' }}>{scheme.active_members}</div>
          <div style={{ fontSize: '11px', color: '#64748b' }}>Active Members</div>
        </div>
        <div>
          <div style={{ fontSize: '18px', fontWeight: '700', color: '#ec4899' }}>
            {scheme.total_treatment_plans}
          </div>
          <div style={{ fontSize: '11px', color: '#64748b' }}>Plans</div>
        </div>
      </div>
    </div>
  );
}

function ReportCardsSection() {
  // Create a custom axios instance for chronic care backend
  const chronicCareApi = axios.create?.({
    baseURL: import.meta.env.VITE_CHRONIC_CARE_API_URL || 'http://localhost:3001/api',
  }) || axios;

  const { data: contentAdmins, isLoading: loadingAdmins } = useQuery({
    queryKey: ['contentAdminPerformance'],
    queryFn: () => chronicCareApi.get('/admins/performance/content-admins').then(r => r.data),
    retry: false,
  });

  const { data: schemePerformance, isLoading: loadingSchemes } = useQuery({
    queryKey: ['schemePerformance'],
    queryFn: () => chronicCareApi.get('/schemes/performance/all').then(r => r.data),
    retry: false,
  });

  return (
    <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '24px' }}>
      {/* Content Admin Performance */}
      <div>
        <h3 style={{ margin: '0 0 12px', fontSize: '16px', fontWeight: '700', color: '#1e40af', display: 'flex', alignItems: 'center', gap: '8px' }}>
          <ChartBarIcon style={{ width: '20px', height: '20px' }} />
          Content Admin Performance
        </h3>
        <div style={{ border: '1px solid #e2e8f0', borderRadius: '8px', padding: '12px', background: 'linear-gradient(135deg, rgba(59, 130, 246, 0.05), rgba(99, 102, 241, 0.05))' }}>
          {loadingAdmins ? (
            <div style={{ display: 'flex', justifyContent: 'center', padding: '24px' }}><Spinner /></div>
          ) : contentAdmins?.length ? (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '10px', maxHeight: '400px', overflowY: 'auto' }}>
              {contentAdmins.map(admin => <ContentAdminCard key={admin.id} admin={admin} />)}
            </div>
          ) : (
            <div style={{ padding: '24px', textAlign: 'center', color: '#64748b', fontSize: '13px' }}>No content admins found</div>
          )}
        </div>
      </div>

      {/* Scheme Performance */}
      <div>
        <h3 style={{ margin: '0 0 12px', fontSize: '16px', fontWeight: '700', color: '#15803d', display: 'flex', alignItems: 'center', gap: '8px' }}>
          <ArrowTrendingUpIcon style={{ width: '20px', height: '20px' }} />
          Scheme Performance & Costs
        </h3>
        <div style={{ border: '1px solid #e2e8f0', borderRadius: '8px', padding: '12px', background: 'linear-gradient(135deg, rgba(34, 197, 94, 0.05), rgba(16, 185, 129, 0.05))' }}>
          {loadingSchemes ? (
            <div style={{ display: 'flex', justifyContent: 'center', padding: '24px' }}><Spinner /></div>
          ) : schemePerformance?.length ? (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '10px', maxHeight: '400px', overflowY: 'auto' }}>
              {schemePerformance.map(scheme => <SchemeCard key={scheme.id} scheme={scheme} />)}
            </div>
          ) : (
            <div style={{ padding: '24px', textAlign: 'center', color: '#64748b', fontSize: '13px' }}>No schemes found</div>
          )}
        </div>
      </div>
    </div>
  );
}

/* ─────────────────── Page ─────────────────── */

export default function ReportsPage() {
  const { user } = useAuth();
  const [selectedId, setSelectedId]   = useState('members');
  const [startDate,  setStartDate]    = useState('');
  const [endDate,    setEndDate]      = useState('');
  const [statusFilter, setStatusFilter] = useState('');

  const report = REPORTS.find((r) => r.id === selectedId);

  const queryParams = useMemo(() => ({
    start_date: startDate  || undefined,
    end_date:   endDate    || undefined,
    status:     statusFilter || undefined,
  }), [startDate, endDate, statusFilter]);

  const { data = [], isLoading } = useQuery({
    queryKey: ['report', selectedId, queryParams],
    queryFn: () => report.queryFn(queryParams),
    retry: false,
  });

  const rows = data || [];
  const previewRows = rows.slice(0, 30);

  const handleCsv = async () => {
    try {
      const res = await report.csvFn(queryParams);
      downloadBlob(res.data, `${report.filename}.csv`);
      toast.success('CSV downloaded');
    } catch { toast.error('CSV download failed'); }
  };

  const handlePdf = async () => {
    if (!rows.length) return toast.error('No data to export');
    try {
      await exportRowsToPdf({
        title: `${report.label} Report`,
        filename: `${report.filename}.pdf`,
        columns: report.columns,
        rows,
      });
      toast.success('PDF exported');
    } catch (e) { console.error(e); toast.error('PDF export failed'); }
  };

  const handleExcel = async () => {
    if (!rows.length) return toast.error('No data to export');
    try {
      const exportData = rows.map((row) => {
        const obj = {};
        report.columns.forEach((c) => {
          const v = row[c.key];
          obj[c.label] = c.render ? c.render(v, row) : (Array.isArray(v) ? v.join(', ') : (v ?? ''));
        });
        return obj;
      });
      await exportRowsToXlsx({
        sheetName: report.sheetName,
        filename: `${report.filename}.xlsx`,
        rows: exportData,
      });
      toast.success('Excel exported');
    } catch (e) { console.error(e); toast.error('Excel export failed'); }
  };

  const inputStyle = {
    padding: '8px 12px', borderRadius: '8px', border: '1px solid #e2e8f0',
    fontSize: '13px', background: '#fff', outline: 'none',
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
      <div>
        <h2 style={{ margin: 0, fontSize: '22px', fontWeight: 700, color: '#0f172a' }}>Reports</h2>
        <p style={{ margin: '4px 0 0', fontSize: '14px', color: '#64748b' }}>
          Generate and export reports for all areas of the chronic care programme
        </p>
      </div>

      {/* Role-based functional report cards */}
      {(user?.role === 'support_admin' || user?.role === 'super_admin') && (
        <ReportCardsSection />
      )}

      {/* Catalog */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(200px, 1fr))', gap: '12px' }}>
        {REPORTS.map((r) => {
          const Icon = r.icon;
          const active = selectedId === r.id;
          return (
            <button key={r.id} onClick={() => { setSelectedId(r.id); setStartDate(''); setEndDate(''); setStatusFilter(''); }}
              style={{
                background: active ? r.color : '#fff',
                border: active ? `2px solid ${r.color}` : '1px solid #e2e8f0',
                borderRadius: '12px', padding: '16px', textAlign: 'left', cursor: 'pointer',
                boxShadow: active ? `0 4px 14px ${r.color}30` : '0 1px 3px rgba(0,0,0,0.06)',
                transition: 'all 0.15s',
              }}>
              <div style={{ width: 36, height: 36, borderRadius: '8px',
                background: active ? 'rgba(255,255,255,0.25)' : r.color + '15',
                display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: '10px' }}>
                <Icon style={{ width: 18, height: 18, color: active ? '#fff' : r.color }} />
              </div>
              <div style={{ fontSize: '13px', fontWeight: 700, color: active ? '#fff' : '#0f172a', marginBottom: '4px' }}>{r.label}</div>
              <div style={{ fontSize: '11px', color: active ? 'rgba(255,255,255,0.8)' : '#94a3b8', lineHeight: 1.4 }}>{r.description}</div>
            </button>
          );
        })}
      </div>

      {/* Filters + Export */}
      <div style={{ background: '#fff', borderRadius: '12px', border: '1px solid #e2e8f0', padding: '16px 20px' }}>
        <div style={{ display: 'flex', gap: '12px', flexWrap: 'wrap', alignItems: 'center' }}>
          <FunnelIcon style={{ width: 16, height: 16, color: '#94a3b8', flexShrink: 0 }} />
          {report.hasDateFilter && (
            <>
              <input type="date" value={startDate} onChange={(e) => setStartDate(e.target.value)} style={inputStyle} />
              <span style={{ color: '#94a3b8', fontSize: '13px' }}>to</span>
              <input type="date" value={endDate} onChange={(e) => setEndDate(e.target.value)} style={inputStyle} />
            </>
          )}
          {report.hasStatusFilter && report.statusOptions && (
            <select value={statusFilter} onChange={(e) => setStatusFilter(e.target.value)} style={inputStyle}>
              <option value="">All statuses</option>
              {report.statusOptions.map((s) => (
                <option key={s} value={s}>{s.charAt(0).toUpperCase() + s.slice(1).replace(/_/g,' ')}</option>
              ))}
            </select>
          )}
          {!report.hasDateFilter && !report.hasStatusFilter && (
            <span style={{ fontSize: '13px', color: '#94a3b8' }}>No filters for this report</span>
          )}
          <span style={{ fontSize: '13px', color: '#64748b', marginLeft: 'auto' }}>
            <strong>{rows.length}</strong> record{rows.length !== 1 ? 's' : ''}
            {rows.length > 30 && <span style={{ color: '#94a3b8' }}> · showing first 30</span>}
          </span>
          <Button variant="secondary" onClick={handleCsv} style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
            <ArrowDownTrayIcon style={{ width: 15, height: 15 }} /> CSV
          </Button>
          <Button variant="secondary" onClick={handlePdf} disabled={!rows.length} style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
            <DocumentArrowDownIcon style={{ width: 15, height: 15 }} /> PDF
          </Button>
          <Button variant="primary" onClick={handleExcel} disabled={!rows.length} style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
            <TableCellsIcon style={{ width: 15, height: 15 }} /> Excel
          </Button>
        </div>
      </div>

      {/* Preview Table */}
      <div style={{ background: '#fff', borderRadius: '12px', boxShadow: '0 1px 4px rgba(0,0,0,0.07)', overflow: 'hidden' }}>
        <div style={{ padding: '14px 20px', borderBottom: '1px solid #f1f5f9', display: 'flex', alignItems: 'center', gap: '10px' }}>
          {(() => { const Icon = report.icon; return <Icon style={{ width: 16, height: 16, color: report.color }} />; })()}
          <span style={{ fontWeight: 600, fontSize: '14px', color: '#0f172a' }}>{report.label} Report — Preview</span>
          <span style={{ fontSize: '12px', color: '#94a3b8', marginLeft: 'auto' }}>
            Export to get all {rows.length} records
          </span>
        </div>
        {isLoading
          ? <div style={{ padding: '60px', display: 'flex', justifyContent: 'center' }}><Spinner /></div>
          : <Table columns={report.previewColumns(previewRows)} data={previewRows} emptyMessage="No data found for the selected filters." />
        }
      </div>
    </div>
  );
}
