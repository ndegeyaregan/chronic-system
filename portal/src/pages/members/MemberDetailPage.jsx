import { useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import toast from 'react-hot-toast';
import { ArrowLeftIcon, PlusIcon, DocumentArrowDownIcon, ClockIcon } from '@heroicons/react/24/outline';
import { getMemberById, toggleMemberStatus, updateMember } from '../../api/members';
import { resetMemberPassword } from '../../api/auth';
import { getTreatmentPlansByMember, adminCreateTreatmentPlan } from '../../api/treatmentPlans';
import { getLabTestsByMember, scheduleLabTest } from '../../api/labTests';
import { getMemberProvider } from '../../api/memberProvider';
import { createAppointmentForMember } from '../../api/appointments';
import { getSchemes } from '../../api/schemes';
import { getHospitals } from '../../api/hospitals';
import { getMemberAuditLogs } from '../../api/auditLogs';
import { assignMedicationToMember, getMedicationCatalogue } from '../../api/medications';
import { getBuddies, addBuddy, updateBuddy, deleteBuddy } from '../../api/careBuddies';
import Badge from '../../components/UI/Badge';
import Button from '../../components/UI/Button';
import Spinner from '../../components/UI/Spinner';
import Modal from '../../components/UI/Modal';

const TABS = ['Overview', 'Treatment Plans', 'Lab Results', 'Medications', 'Vitals', 'Appointments', 'Lifestyle', 'Activity Log', 'Care Buddies'];

const LAB_TEST_TYPES = ['Liver Function Test', 'Kidney Function Test'];
const API_BASE = (import.meta.env.VITE_API_URL || '/api').replace(/\/api$/, '');

const LAB_STATUS_BADGE = {
  pending: 'pending',
  overdue: 'cancelled',
  completed: 'completed',
};

function InfoRow({ label, value }) {
  return (
    <div style={{ display: 'flex', gap: '8px', padding: '10px 0', borderBottom: '1px solid #f1f5f9' }}>
      <span style={{ minWidth: '160px', fontSize: '13px', color: '#64748b', fontWeight: '500' }}>{label}</span>
      <span style={{ fontSize: '14px', color: 'var(--text)' }}>{value || '—'}</span>
    </div>
  );
}

function SummaryCard({ label, value, tone = 'default' }) {
  const tones = {
    default: { background: '#f8fafc', color: 'var(--text)' },
    success: { background: '#ecfdf5', color: '#047857' },
    warning: { background: '#fffbeb', color: '#b45309' },
    danger: { background: '#fef2f2', color: '#b91c1c' },
    info: { background: '#eff6ff', color: '#1d4ed8' },
  };
  const colors = tones[tone] || tones.default;

  return (
    <div style={{ ...colors, borderRadius: '12px', padding: '16px', border: '1px solid #e2e8f0' }}>
      <p style={{ margin: '0 0 6px', fontSize: '12px', fontWeight: '600', letterSpacing: '0.04em', textTransform: 'uppercase', opacity: 0.85 }}>
        {label}
      </p>
      <p style={{ margin: 0, fontSize: '24px', fontWeight: '700' }}>{value ?? '—'}</p>
    </div>
  );
}

const formatDate = (value) => (
  value
    ? new Date(value).toLocaleDateString('en-UG', { day: '2-digit', month: 'short', year: 'numeric' })
    : '—'
);

const getAssetUrl = (value) => {
  if (!value) return null;
  return value.startsWith('http') ? value : `${API_BASE}${value}`;
};

function AttachmentLinks({ documentUrl, photoUrl, audioUrl, videoUrl, prescriptionUrl }) {
  const links = [
    { label: 'View Document', url: getAssetUrl(documentUrl || prescriptionUrl) },
    { label: 'View Photo', url: getAssetUrl(photoUrl) },
  ].filter((item) => item.url);

  const resolvedAudioUrl = getAssetUrl(audioUrl);
  const resolvedVideoUrl = getAssetUrl(videoUrl);
  const resolvedPhotoUrl = getAssetUrl(photoUrl);

  if (!links.length && !resolvedAudioUrl && !resolvedVideoUrl && !resolvedPhotoUrl) {
    return null;
  }

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '12px', marginTop: '8px' }}>
      {links.length > 0 && (
        <div style={{ display: 'flex', gap: '10px', flexWrap: 'wrap' }}>
          {links.map((item) => (
            <a
              key={item.label}
              href={item.url}
              target="_blank"
              rel="noreferrer"
              style={{
                display: 'inline-flex',
                alignItems: 'center',
                gap: '6px',
                color: 'var(--primary)',
                fontSize: '13px',
                fontWeight: '500',
                textDecoration: 'none',
              }}
            >
              <DocumentArrowDownIcon style={{ width: 16, height: 16 }} />
              {item.label}
            </a>
          ))}
        </div>
      )}

      {resolvedPhotoUrl && (
        <div>
          <p style={{ margin: '0 0 6px', fontSize: '12px', color: '#64748b', fontWeight: '600', textTransform: 'uppercase', letterSpacing: '0.04em' }}>
            Attached photo
          </p>
          <a href={resolvedPhotoUrl} target="_blank" rel="noreferrer">
            <img
              src={resolvedPhotoUrl}
              alt="Attachment"
              style={{ width: '180px', maxWidth: '100%', borderRadius: '10px', border: '1px solid #e2e8f0', objectFit: 'cover' }}
            />
          </a>
        </div>
      )}

      {resolvedAudioUrl && (
        <div>
          <p style={{ margin: '0 0 6px', fontSize: '12px', color: '#64748b', fontWeight: '600', textTransform: 'uppercase', letterSpacing: '0.04em' }}>
            Attached audio
          </p>
          <audio controls preload="none" src={resolvedAudioUrl} style={{ width: '100%', maxWidth: '360px' }} />
        </div>
      )}

      {resolvedVideoUrl && (
        <div>
          <p style={{ margin: '0 0 6px', fontSize: '12px', color: '#64748b', fontWeight: '600', textTransform: 'uppercase', letterSpacing: '0.04em' }}>
            Attached video
          </p>
          <video controls preload="metadata" src={resolvedVideoUrl} style={{ width: '100%', maxWidth: '420px', borderRadius: '10px', border: '1px solid #e2e8f0', background: '#000' }} />
        </div>
      )}
    </div>
  );
}

function HospitalDropdown({ search, onSelect }) {
  const { data } = useQuery({
    queryKey: ['hospitals-search', search],
    queryFn: () => getHospitals({ search }).then(r => {
      const d = r.data;
      return Array.isArray(d) ? d : (d?.hospitals || d?.data || []);
    }),
    enabled: search.length > 0,
    staleTime: 10000,
  });
  const hospitals = data || [];
  if (hospitals.length === 0) return null;
  return (
    <div style={{
      position: 'absolute', top: '100%', left: 0, right: 0, zIndex: 50,
      background: '#fff', border: '1px solid #e2e8f0', borderRadius: '6px',
      boxShadow: '0 4px 12px rgba(0,0,0,0.1)', maxHeight: '180px', overflowY: 'auto',
    }}>
      {hospitals.slice(0, 10).map(h => (
        <div
          key={h.id}
          onClick={() => onSelect(h)}
          style={{ padding: '8px 12px', cursor: 'pointer', fontSize: '14px' }}
          onMouseEnter={(e) => e.currentTarget.style.background = '#f1f5f9'}
          onMouseLeave={(e) => e.currentTarget.style.background = 'transparent'}
        >
          {h.name}
        </div>
      ))}
    </div>
  );
}

export default function MemberDetailPage() {
  const { id } = useParams();
  const navigate = useNavigate();
  const qc = useQueryClient();
  const [activeTab, setActiveTab] = useState('Overview');
  const [showLabModal, setShowLabModal] = useState(false);
  const [labForm, setLabForm] = useState({ test_type: 'Liver Function Test', due_date: '' });
  const [showTpModal, setShowTpModal] = useState(false);
  const [tpForm, setTpForm] = useState({ title: '', description: '', provider_name: '', plan_date: '', cost: '', condition_id: '' });
  const [showApptModal, setShowApptModal] = useState(false);
  const [apptForm, setApptForm] = useState({ hospital_id: '', condition_id: '', appointment_date: '', preferred_time: '', reason: '' });
  const [hospitalSearch, setHospitalSearch] = useState('');
  const [showHospitalDropdown, setShowHospitalDropdown] = useState(false);
  const [showEditModal, setShowEditModal] = useState(false);
  const [editForm, setEditForm] = useState({});
  const [showMedModal, setShowMedModal] = useState(false);
  const [medForm, setMedForm] = useState({ name: '', dosage: '', frequency: '', start_date: '', end_date: '', notes: '' });
  const [medSearch, setMedSearch] = useState('');
  const [showBuddyModal, setShowBuddyModal] = useState(false);
  const [buddyForm, setBuddyForm] = useState({ name: '', phone: '', relationship: '' });
  const [editingBuddyId, setEditingBuddyId] = useState(null);

  const { data: member, isLoading } = useQuery({
    queryKey: ['member', id],
    queryFn: () => getMemberById(id).then((r) => r.data),
    retry: false,
  });

  const { data: providerData, isLoading: providerLoading } = useQuery({
    queryKey: ['member-provider', id],
    queryFn: () => getMemberProvider(id),
    enabled: activeTab === 'Overview',
    retry: false,
  });

  const { data: plansData, isLoading: plansLoading } = useQuery({
    queryKey: ['treatment-plans', id],
    queryFn: () => getTreatmentPlansByMember(id),
    enabled: activeTab === 'Treatment Plans',
    retry: false,
  });

  const { data: labTestsData, isLoading: labTestsLoading } = useQuery({
    queryKey: ['lab-tests', id],
    queryFn: () => getLabTestsByMember(id),
    enabled: activeTab === 'Lab Results',
    retry: false,
  });

  const { data: auditLogs = [], isLoading: auditLoading } = useQuery({
    queryKey: ['member-audit-logs', id],
    queryFn: () => getMemberAuditLogs(id),
    enabled: activeTab === 'Activity Log',
    retry: false,
  });

  const { data: schemesForEdit = [] } = useQuery({
    queryKey: ['schemes-list'],
    queryFn: () => getSchemes().then(r => { const d = r.data; return Array.isArray(d) ? d : (d?.schemes || []); }),
    enabled: showEditModal,
  });

  const { data: medCatalogue = [] } = useQuery({
    queryKey: ['med-catalogue', medSearch],
    queryFn: () => getMedicationCatalogue({ search: medSearch, limit: 10 }).then(r => {
      const d = r.data;
      return Array.isArray(d) ? d : (d?.medications || d?.data || []);
    }),
    enabled: medSearch.length > 1,
    staleTime: 10000,
  });

  const { data: buddies = [], isLoading: buddiesLoading } = useQuery({
    queryKey: ['care-buddies', id],
    queryFn: () => getBuddies(id).then(r => r.data),
    enabled: activeTab === 'Care Buddies',
    retry: false,
  });

  const toggleMutation = useMutation({
    mutationFn: () => toggleMemberStatus(id),
    onSuccess: () => { qc.invalidateQueries(['member', id]); toast.success('Status updated'); },
    onError: () => toast.error('Failed to update status'),
  });

  const resetMutation = useMutation({
    mutationFn: () => resetMemberPassword(id),
    onSuccess: () => toast.success('Password reset sent'),
    onError: () => toast.error('Failed to reset password'),
  });

  const scheduleLabMutation = useMutation({
    mutationFn: (data) => scheduleLabTest(data),
    onSuccess: () => {
      toast.success('Lab test scheduled');
      setShowLabModal(false);
      setLabForm({ test_type: 'Liver Function Test', due_date: '' });
      qc.invalidateQueries(['lab-tests', id]);
    },
    onError: (err) => toast.error(err.response?.data?.message || 'Failed to schedule lab test'),
  });

  const createTpMutation = useMutation({
    mutationFn: (data) => adminCreateTreatmentPlan(data),
    onSuccess: () => {
      toast.success('Treatment plan created');
      setShowTpModal(false);
      setTpForm({ title: '', description: '', provider_name: '', plan_date: '', cost: '', condition_id: '' });
      qc.invalidateQueries(['treatment-plans', id]);
      qc.invalidateQueries(['member-audit-logs', id]);
    },
    onError: (err) => toast.error(err.response?.data?.message || 'Failed to create treatment plan'),
  });

  const createApptMutation = useMutation({
    mutationFn: (data) => createAppointmentForMember(data),
    onSuccess: () => {
      toast.success('Appointment booked');
      setShowApptModal(false);
      setApptForm({ hospital_id: '', condition_id: '', appointment_date: '', preferred_time: '', reason: '' });
      setHospitalSearch('');
      qc.invalidateQueries(['member', id]);
      qc.invalidateQueries(['member-audit-logs', id]);
    },
    onError: (err) => toast.error(err.response?.data?.message || 'Failed to create appointment'),
  });

  const updateMemberMutation = useMutation({
    mutationFn: (data) => updateMember(id, data),
    onSuccess: () => {
      toast.success('Member updated');
      setShowEditModal(false);
      qc.invalidateQueries(['member', id]);
      qc.invalidateQueries(['member-audit-logs', id]);
    },
    onError: (err) => toast.error(err.response?.data?.message || 'Failed to update'),
  });

  const assignMedMutation = useMutation({
    mutationFn: (data) => assignMedicationToMember(data),
    onSuccess: () => {
      toast.success('Medication assigned');
      setShowMedModal(false);
      setMedForm({ name: '', dosage: '', frequency: '', start_date: '', end_date: '', notes: '' });
      setMedSearch('');
      qc.invalidateQueries(['member', id]);
      qc.invalidateQueries(['member-audit-logs', id]);
    },
    onError: (err) => toast.error(err.response?.data?.message || 'Failed to assign medication'),
  });

  const addBuddyMutation = useMutation({
    mutationFn: (data) => editingBuddyId ? updateBuddy(editingBuddyId, data) : addBuddy(id, data),
    onSuccess: () => {
      toast.success(editingBuddyId ? 'Buddy updated' : 'Buddy added');
      setShowBuddyModal(false);
      setBuddyForm({ name: '', phone: '', relationship: '' });
      setEditingBuddyId(null);
      qc.invalidateQueries(['care-buddies', id]);
      qc.invalidateQueries(['member-audit-logs', id]);
    },
    onError: (err) => toast.error(err.response?.data?.message || 'Failed to save buddy'),
  });

  const deleteBuddyMutation = useMutation({
    mutationFn: (buddyId) => deleteBuddy(buddyId),
    onSuccess: () => {
      toast.success('Buddy removed');
      qc.invalidateQueries(['care-buddies', id]);
      qc.invalidateQueries(['member-audit-logs', id]);
    },
    onError: () => toast.error('Failed to remove buddy'),
  });

  if (isLoading) return <Spinner size={48} />;

  const m = member || {
    member_number: 'SAN-DEMO-001',
    first_name: 'Thabo',
    last_name: 'Nkosi',
    email: 'thabo@example.com',
    phone: '0821234567',
    date_of_birth: '1982-05-15',
    plan: 'Gold',
    conditions: ['Diabetes', 'Hypertension'],
    is_active: true,
    address: '123 Main Street, Soweto, Gauteng',
    id_number: '820515XXXXX',
    joined_date: '2023-01-10',
  };

  const plans = Array.isArray(plansData)
    ? plansData
    : (plansData?.plans || plansData?.treatment_plans || []);
  const labTests = Array.isArray(labTestsData)
    ? labTestsData
    : (labTestsData?.tests || labTestsData?.lab_tests || []);
  const provider = providerData?.provider || (providerData && typeof providerData === 'object' && !providerData.message ? providerData : null);
  const conditionLabels = (Array.isArray(m.conditions) ? m.conditions : [m.conditions])
    .map((condition) => (typeof condition === 'string' ? condition : condition?.name))
    .filter(Boolean);
  const insights = m.insights || {};
  const insightMetrics = insights.metrics || {};
  const vitalsHistory = m.vitals_history || m.recent_vitals || [];
  const appointmentsHistory = m.appointments_history || m.recent_appointments || [];
  const medications = m.medications || [];
  const meals = m.meals || [];
  const fitnessLogs = m.fitness_logs || [];
  const psychosocial = m.psychosocial_checkins || [];
  const checkins = m.daily_checkins || [];
  const lifestyleSummary = m.lifestyle_summary || {};

  const handleScheduleLab = () => {
    if (!labForm.due_date) return toast.error('Please select a due date');
    scheduleLabMutation.mutate({ member_id: id, test_type: labForm.test_type, due_date: labForm.due_date });
  };

  const labColumns = [
    { key: 'test_type', header: 'Test Type' },
    {
      key: 'due_date', header: 'Due Date',
      render: (v) => v ? new Date(v).toLocaleDateString('en-UG', { day: '2-digit', month: 'short', year: 'numeric' }) : '—',
    },
    {
      key: 'status', header: 'Status',
      render: (v) => <Badge status={LAB_STATUS_BADGE[v?.toLowerCase()] || 'pending'} label={v} />,
    },
    {
      key: 'completed_date', header: 'Completed Date',
      render: (v) => v ? new Date(v).toLocaleDateString('en-UG', { day: '2-digit', month: 'short', year: 'numeric' }) : '—',
    },
    {
      key: 'result', header: 'Result',
      render: (v, row) => row.result_file_url ? (
        <a href={row.result_file_url} target="_blank" rel="noreferrer"
          style={{ color: 'var(--primary)', fontWeight: '500', fontSize: '13px', textDecoration: 'none' }}>
          View Result
        </a>
      ) : (v || '—'),
    },
  ];

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
      {/* Back button */}
      <button
        onClick={() => navigate('/members')}
        style={{ display: 'inline-flex', alignItems: 'center', gap: '6px', background: 'none', border: 'none', color: 'var(--primary)', cursor: 'pointer', fontWeight: '500', fontSize: '14px', padding: 0 }}
      >
        <ArrowLeftIcon style={{ width: 16, height: 16 }} /> Back to Members
      </button>

      {/* Profile Card */}
      <div style={{ background: '#fff', borderRadius: '12px', padding: '24px', boxShadow: '0 1px 4px rgba(0,0,0,0.07)' }}>
        <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', flexWrap: 'wrap', gap: '12px' }}>
          <div style={{ display: 'flex', gap: '16px', alignItems: 'center' }}>
            <div style={{
              width: 64, height: 64, borderRadius: '50%',
              background: 'var(--primary)',
              color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center',
              fontSize: '22px', fontWeight: '700', flexShrink: 0,
            }}>
              {m.first_name?.[0]}{m.last_name?.[0]}
            </div>
            <div>
              <h2 style={{ margin: '0 0 4px', fontSize: '20px', fontWeight: '700', color: 'var(--text)' }}>
                {m.first_name} {m.last_name}
              </h2>
              <p style={{ margin: '0 0 6px', color: '#64748b', fontSize: '14px' }}>{m.member_number}</p>
              <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
                <Badge status={m.is_active ? 'active' : 'inactive'} />
                <span style={{ background: '#dbeafe', color: '#1e40af', padding: '2px 8px', borderRadius: '999px', fontSize: '12px', fontWeight: '600' }}>
                  {m.scheme_name || m.plan || '—'}
                </span>
                {conditionLabels.map((conditionLabel) => (
                  <span key={conditionLabel} style={{ background: '#f0fdf4', color: '#15803d', padding: '2px 8px', borderRadius: '999px', fontSize: '12px', fontWeight: '500' }}>{conditionLabel}</span>
                ))}
              </div>
            </div>
          </div>
          <div style={{ display: 'flex', gap: '8px' }}>
            <Button variant={m.is_active ? 'secondary' : 'success'} onClick={() => toggleMutation.mutate()} disabled={toggleMutation.isPending}>
              {m.is_active ? 'Deactivate' : 'Activate'}
            </Button>
            <Button variant="ghost" onClick={() => resetMutation.mutate()} disabled={resetMutation.isPending}>
              Reset Password
            </Button>
          </div>
        </div>
      </div>

      {/* Tabs */}
      <div style={{ background: '#fff', borderRadius: '12px', boxShadow: '0 1px 4px rgba(0,0,0,0.07)', overflow: 'hidden' }}>
        <div style={{ display: 'flex', borderBottom: '2px solid #f1f5f9', overflowX: 'auto' }}>
          {TABS.map((tab) => (
            <button
              key={tab}
              onClick={() => setActiveTab(tab)}
              style={{
                padding: '12px 20px',
                background: 'none',
                border: 'none',
                borderBottom: activeTab === tab ? '2px solid var(--primary)' : '2px solid transparent',
                marginBottom: '-2px',
                cursor: 'pointer',
                fontSize: '14px',
                fontWeight: activeTab === tab ? '600' : '400',
                color: activeTab === tab ? 'var(--primary)' : '#64748b',
                whiteSpace: 'nowrap',
              }}
            >
              {tab}
            </button>
          ))}
        </div>

        <div style={{ padding: '20px' }}>
          {/* ── Overview ── */}
          {activeTab === 'Overview' && (
            <div>
              <div style={{ display: 'flex', justifyContent: 'flex-end', marginBottom: '12px' }}>
                <Button variant="secondary" onClick={() => {
                  setEditForm({
                    member_number: m.member_number || '',
                    first_name: m.first_name || '',
                    last_name: m.last_name || '',
                    email: m.email || '',
                    phone: m.phone || '',
                    date_of_birth: m.date_of_birth ? m.date_of_birth.slice(0, 10) : '',
                    id_number: m.id_number || '',
                    gender: m.gender || '',
                    scheme_id: m.scheme_id || '',
                  });
                  setShowEditModal(true);
                }}>
                  Edit Details
                </Button>
              </div>
              <InfoRow label="Full Name" value={`${m.first_name} ${m.last_name}`} />
              <InfoRow label="Email" value={m.email} />
              <InfoRow label="Phone" value={m.phone} />
              <InfoRow label="Date of Birth" value={m.date_of_birth} />
              <InfoRow label="ID Number" value={m.id_number} />
              <InfoRow label="Address" value={m.address} />
              <InfoRow label="Scheme" value={m.scheme_name || m.plan} />
              <InfoRow label="Conditions" value={conditionLabels.join(', ')} />
              <InfoRow label="Member Since" value={m.joined_date || formatDate(m.created_at)} />

              <div style={{ marginTop: '24px' }}>
                <h4 style={{ fontSize: '14px', fontWeight: '600', color: 'var(--text)', margin: '0 0 12px' }}>
                  Progress & Clinical Insight
                </h4>
                <div style={{
                  borderRadius: '12px',
                  padding: '16px',
                  border: '1px solid #e2e8f0',
                  background: insights.status === 'critical'
                    ? '#fef2f2'
                    : insights.status === 'needs_attention'
                      ? '#fffbeb'
                      : '#ecfdf5',
                }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', gap: '12px', flexWrap: 'wrap', alignItems: 'center' }}>
                    <div>
                      <p style={{ margin: '0 0 4px', fontSize: '12px', textTransform: 'uppercase', letterSpacing: '0.04em', color: '#64748b', fontWeight: '700' }}>
                        Member status
                      </p>
                      <h3 style={{ margin: 0, fontSize: '18px', color: 'var(--text)' }}>
                        {insights.status ? insights.status.replace(/_/g, ' ') : 'Awaiting enough data'}
                      </h3>
                    </div>
                    {insights.status && <Badge status={insights.status === 'on_track' ? 'active' : insights.status === 'needs_attention' ? 'pending' : 'cancelled'} label={insights.status.replace(/_/g, ' ')} />}
                  </div>
                  <p style={{ margin: '12px 0 0', fontSize: '14px', color: '#475569', lineHeight: 1.6 }}>
                    {insights.summary || 'As more patient-submitted data arrives, the platform will show a richer progress summary here.'}
                  </p>
                </div>
              </div>

              <div style={{ marginTop: '20px', display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '12px' }}>
                <SummaryCard label="Adherence" value={insightMetrics.medication_adherence_pct !== null && insightMetrics.medication_adherence_pct !== undefined ? `${insightMetrics.medication_adherence_pct}%` : '—'} tone="info" />
                <SummaryCard label="Upcoming Appointments" value={insightMetrics.upcoming_appointments ?? 0} tone="warning" />
                <SummaryCard label="Overdue Labs" value={insightMetrics.overdue_lab_tests ?? 0} tone={(insightMetrics.overdue_lab_tests || 0) > 0 ? 'danger' : 'success'} />
                <SummaryCard label="Active Medications" value={insightMetrics.active_medications ?? medications.length} tone="default" />
              </div>

              <div style={{ marginTop: '20px', display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
                <div style={{ background: '#fff', border: '1px solid #e2e8f0', borderRadius: '10px', padding: '16px' }}>
                  <h4 style={{ margin: '0 0 10px', fontSize: '14px', color: 'var(--text)' }}>Advice</h4>
                  {Array.isArray(insights.advice) && insights.advice.length > 0 ? (
                    <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                      {insights.advice.map((item) => (
                        <div key={item} style={{ fontSize: '13px', color: '#475569', lineHeight: 1.5 }}>• {item}</div>
                      ))}
                    </div>
                  ) : (
                    <p style={{ margin: 0, fontSize: '13px', color: '#94a3b8' }}>No risks detected from the latest data.</p>
                  )}
                </div>
                <div style={{ background: '#fff', border: '1px solid #e2e8f0', borderRadius: '10px', padding: '16px' }}>
                  <h4 style={{ margin: '0 0 10px', fontSize: '14px', color: 'var(--text)' }}>Suggested next steps</h4>
                  {Array.isArray(insights.suggestions) && insights.suggestions.length > 0 ? (
                    <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                      {insights.suggestions.map((item) => (
                        <div key={item} style={{ fontSize: '13px', color: '#475569', lineHeight: 1.5 }}>• {item}</div>
                      ))}
                    </div>
                  ) : (
                    <p style={{ margin: 0, fontSize: '13px', color: '#94a3b8' }}>The member is currently on track; no urgent interventions suggested.</p>
                  )}
                </div>
              </div>

              {Array.isArray(insights.strengths) && insights.strengths.length > 0 && (
                <div style={{ marginTop: '16px', background: '#f8fafc', border: '1px solid #e2e8f0', borderRadius: '10px', padding: '16px' }}>
                  <h4 style={{ margin: '0 0 10px', fontSize: '14px', color: 'var(--text)' }}>Positive signals</h4>
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                    {insights.strengths.map((item) => (
                      <div key={item} style={{ fontSize: '13px', color: '#475569', lineHeight: 1.5 }}>• {item}</div>
                    ))}
                  </div>
                </div>
              )}

              {/* Care Provider */}
              <div style={{ marginTop: '24px' }}>
                <h4 style={{ fontSize: '14px', fontWeight: '600', color: 'var(--text)', margin: '0 0 12px' }}>
                  Care Provider
                </h4>
                {providerLoading ? (
                  <Spinner size={24} />
                ) : provider ? (
                  <div style={{ background: '#f8fafc', border: '1px solid #e2e8f0', borderRadius: '8px', padding: '16px', display: 'flex', flexDirection: 'column', gap: '8px' }}>
                    {(provider.doctor_name || provider.name) && (
                      <div style={{ display: 'flex', gap: '8px' }}>
                        <span style={{ minWidth: '140px', fontSize: '13px', color: '#64748b', fontWeight: '500' }}>Doctor</span>
                        <span style={{ fontSize: '14px', color: 'var(--text)' }}>{provider.doctor_name || provider.name}</span>
                      </div>
                    )}
                    {provider.contact && (
                      <div style={{ display: 'flex', gap: '8px' }}>
                        <span style={{ minWidth: '140px', fontSize: '13px', color: '#64748b', fontWeight: '500' }}>Contact</span>
                        <a href={`tel:${provider.contact}`} style={{ fontSize: '14px', color: 'var(--primary)' }}>{provider.contact}</a>
                      </div>
                    )}
                    {(provider.hospital_name || provider.hospital) && (
                      <div style={{ display: 'flex', gap: '8px' }}>
                        <span style={{ minWidth: '140px', fontSize: '13px', color: '#64748b', fontWeight: '500' }}>Hospital</span>
                        <span style={{ fontSize: '14px', color: 'var(--text)' }}>{provider.hospital_name || provider.hospital}</span>
                      </div>
                    )}
                    {provider.address && (
                      <div style={{ display: 'flex', gap: '8px' }}>
                        <span style={{ minWidth: '140px', fontSize: '13px', color: '#64748b', fontWeight: '500' }}>Address</span>
                        <span style={{ fontSize: '14px', color: 'var(--text)' }}>{provider.address}</span>
                      </div>
                    )}
                  </div>
                ) : (
                  <p style={{ fontSize: '14px', color: '#94a3b8', fontStyle: 'italic', margin: 0 }}>
                    No care provider set by member.
                  </p>
                )}
              </div>
            </div>
          )}

          {/* ── Treatment Plans ── */}
          {activeTab === 'Treatment Plans' && (
            <div>
              <div style={{ display: 'flex', justifyContent: 'flex-end', marginBottom: '16px' }}>
                <Button variant="primary" onClick={() => setShowTpModal(true)}>
                  <PlusIcon style={{ width: 16, height: 16 }} />
                  Add Treatment Plan
                </Button>
              </div>
              {plansLoading ? (
                <Spinner />
              ) : plans.length === 0 ? (
                <div style={{ textAlign: 'center', padding: '48px 0', color: '#94a3b8', fontSize: '14px', fontStyle: 'italic' }}>
                  No treatment plans submitted yet.
                </div>
              ) : (
                <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
                  {plans.map((plan) => (
                    <div
                      key={plan.id}
                      style={{ border: '1px solid #e2e8f0', borderRadius: '10px', padding: '18px', background: '#fff', display: 'flex', flexDirection: 'column', gap: '10px' }}
                    >
                      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', flexWrap: 'wrap', gap: '8px' }}>
                        <h4 style={{ margin: 0, fontSize: '15px', fontWeight: '700', color: 'var(--text)' }}>{plan.title}</h4>
                        <Badge status={plan.status?.toLowerCase() || 'pending'} label={plan.status} />
                      </div>
                      {plan.description && (
                        <p style={{ margin: 0, fontSize: '13px', color: '#475569', lineHeight: '1.6' }}>{plan.description}</p>
                      )}
                      <div style={{ display: 'flex', gap: '24px', flexWrap: 'wrap', fontSize: '13px', color: '#64748b' }}>
                        {plan.provider_name && (
                          <span><strong style={{ color: '#475569' }}>Provider:</strong> {plan.provider_name}</span>
                        )}
                        {plan.plan_date && (
                          <span>
                            <strong style={{ color: '#475569' }}>Date:</strong>{' '}
                            {new Date(plan.plan_date).toLocaleDateString('en-UG', { day: '2-digit', month: 'short', year: 'numeric' })}
                          </span>
                        )}
                        {plan.cost !== undefined && plan.cost !== null && (
                          <span><strong style={{ color: '#475569' }}>Cost:</strong> UGX {Number(plan.cost).toLocaleString()}</span>
                        )}
                      </div>
                      <AttachmentLinks
                        documentUrl={plan.document_url}
                        photoUrl={plan.photo_url}
                        audioUrl={plan.audio_url}
                        videoUrl={plan.video_url}
                      />
                    </div>
                  ))}
                </div>
              )}
            </div>
          )}

          {/* ── Lab Results ── */}
          {activeTab === 'Lab Results' && (
            <div>
              <div style={{ display: 'flex', justifyContent: 'flex-end', marginBottom: '16px' }}>
                <Button variant="primary" onClick={() => setShowLabModal(true)}>
                  <PlusIcon style={{ width: 16, height: 16 }} />
                  Schedule Test
                </Button>
              </div>
              {labTestsLoading ? (
                <Spinner />
              ) : (
                <div style={{ overflowX: 'auto' }}>
                  <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '14px' }}>
                    <thead>
                      <tr style={{ borderBottom: '2px solid #e2e8f0', background: '#f8fafc' }}>
                        {labColumns.map((col) => (
                          <th
                            key={col.key}
                            style={{ padding: '10px 14px', textAlign: 'left', fontSize: '12px', fontWeight: '600', color: '#64748b', textTransform: 'uppercase', letterSpacing: '0.04em', whiteSpace: 'nowrap' }}
                          >
                            {col.header}
                          </th>
                        ))}
                      </tr>
                    </thead>
                    <tbody>
                      {labTests.length > 0 ? (
                        labTests.map((test, i) => (
                          <tr
                            key={test.id || i}
                            style={{ borderBottom: '1px solid #f1f5f9' }}
                            onMouseEnter={(e) => (e.currentTarget.style.background = '#f8fafc')}
                            onMouseLeave={(e) => (e.currentTarget.style.background = 'transparent')}
                          >
                            {labColumns.map((col) => (
                              <td key={col.key} style={{ padding: '11px 14px', color: 'var(--text)', verticalAlign: 'middle' }}>
                                {col.render ? col.render(test[col.key], test) : (test[col.key] ?? '—')}
                              </td>
                            ))}
                          </tr>
                        ))
                      ) : (
                        <tr>
                          <td colSpan={labColumns.length} style={{ padding: '32px', textAlign: 'center', color: '#94a3b8', fontStyle: 'italic' }}>
                            No lab tests found.
                          </td>
                        </tr>
                      )}
                    </tbody>
                  </table>
                </div>
              )}
            </div>
          )}

          {activeTab === 'Medications' && (
            <div>
              <div style={{ display: 'flex', justifyContent: 'flex-end', marginBottom: '16px' }}>
                <Button variant="primary" onClick={() => setShowMedModal(true)}>
                  <PlusIcon style={{ width: 16, height: 16 }} />
                  Add Medication
                </Button>
              </div>
            {medications.length === 0 ? (
              <div style={{ color: '#64748b', textAlign: 'center', padding: '32px 0', fontSize: '14px' }}>
                <p>No medication records submitted yet.</p>
              </div>
            ) : (
              <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
                {medications.map((medication) => (
                  <div key={medication.id} style={{ border: '1px solid #e2e8f0', borderRadius: '12px', padding: '18px', background: '#fff', display: 'flex', flexDirection: 'column', gap: '10px' }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', gap: '12px', flexWrap: 'wrap', alignItems: 'flex-start' }}>
                      <div>
                        <h4 style={{ margin: 0, fontSize: '15px', color: 'var(--text)' }}>{medication.medication_name || medication.name || 'Medication'}</h4>
                        <p style={{ margin: '4px 0 0', fontSize: '13px', color: '#64748b' }}>{medication.generic_name || medication.condition_name || '—'}</p>
                      </div>
                      <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
                        <Badge status={!medication.end_date || new Date(medication.end_date) >= new Date() ? 'active' : 'inactive'} label={!medication.end_date || new Date(medication.end_date) >= new Date() ? 'active' : 'ended'} />
                        <span style={{ background: '#eff6ff', color: '#1d4ed8', padding: '2px 8px', borderRadius: '999px', fontSize: '12px', fontWeight: '600' }}>
                          {medication.adherence_percent !== undefined ? `${Math.round(Number(medication.adherence_percent || 0))}% adherence` : 'No adherence yet'}
                        </span>
                      </div>
                    </div>
                    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '8px', fontSize: '13px', color: '#475569' }}>
                      <div><strong>Dosage:</strong> {medication.dosage || '—'}</div>
                      <div><strong>Frequency:</strong> {medication.frequency || '—'}</div>
                      <div><strong>Start date:</strong> {formatDate(medication.start_date)}</div>
                      <div><strong>End date:</strong> {formatDate(medication.end_date)}</div>
                      <div><strong>Condition:</strong> {medication.condition_name || '—'}</div>
                      <div><strong>Refill due:</strong> {formatDate(medication.next_refill_date)}</div>
                    </div>
                    {medication.medication_notes && (
                      <p style={{ margin: 0, fontSize: '13px', color: '#64748b', lineHeight: 1.5 }}>{medication.medication_notes}</p>
                    )}
                    <AttachmentLinks
                      prescriptionUrl={medication.prescription_file_url}
                      photoUrl={medication.photo_url}
                      audioUrl={medication.audio_url}
                      videoUrl={medication.video_url}
                    />
                  </div>
                ))}
              </div>
            )}
            </div>
          )}
          {activeTab === 'Vitals' && (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '12px' }}>
                <SummaryCard label="Avg Blood Sugar" value={insightMetrics.avg_blood_sugar !== null && insightMetrics.avg_blood_sugar !== undefined ? `${insightMetrics.avg_blood_sugar} mmol/L` : '—'} tone="info" />
                <SummaryCard label="Avg Blood Pressure" value={insightMetrics.avg_systolic_bp ? `${insightMetrics.avg_systolic_bp}/${insightMetrics.avg_diastolic_bp}` : '—'} tone="warning" />
                <SummaryCard label="Avg Pain" value={insightMetrics.avg_pain_level !== null && insightMetrics.avg_pain_level !== undefined ? `${insightMetrics.avg_pain_level}/10` : '—'} tone={(insightMetrics.avg_pain_level || 0) >= 7 ? 'danger' : 'default'} />
                <SummaryCard label="Latest Records" value={vitalsHistory.length} tone="default" />
              </div>
              {vitalsHistory.length === 0 ? (
                <div style={{ color: '#64748b', textAlign: 'center', padding: '32px 0', fontSize: '14px' }}>
                  <p>No vitals submitted yet.</p>
                </div>
              ) : (
                <div style={{ overflowX: 'auto' }}>
                  <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '14px' }}>
                    <thead>
                      <tr style={{ borderBottom: '2px solid #e2e8f0', background: '#f8fafc' }}>
                        {['Recorded', 'Blood Sugar', 'Blood Pressure', 'Heart Rate', 'Weight', 'Pain', 'Notes'].map((heading) => (
                          <th key={heading} style={{ padding: '10px 14px', textAlign: 'left', fontSize: '12px', fontWeight: '600', color: '#64748b', textTransform: 'uppercase', letterSpacing: '0.04em' }}>{heading}</th>
                        ))}
                      </tr>
                    </thead>
                    <tbody>
                      {vitalsHistory.map((entry) => (
                        <tr key={entry.id} style={{ borderBottom: '1px solid #f1f5f9' }}>
                          <td style={{ padding: '11px 14px' }}>{entry.recorded_at ? new Date(entry.recorded_at).toLocaleString('en-UG') : '—'}</td>
                          <td style={{ padding: '11px 14px' }}>{entry.blood_sugar_mmol ?? '—'}</td>
                          <td style={{ padding: '11px 14px' }}>{entry.systolic_bp && entry.diastolic_bp ? `${entry.systolic_bp}/${entry.diastolic_bp}` : '—'}</td>
                          <td style={{ padding: '11px 14px' }}>{entry.heart_rate ?? '—'}</td>
                          <td style={{ padding: '11px 14px' }}>{entry.weight_kg ? `${entry.weight_kg} kg` : '—'}</td>
                          <td style={{ padding: '11px 14px' }}>{entry.pain_level ?? '—'}</td>
                          <td style={{ padding: '11px 14px', color: '#64748b' }}>{entry.notes || '—'}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
            </div>
          )}
          {activeTab === 'Appointments' && (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '12px', flex: 1 }}>
                  <SummaryCard label="Upcoming" value={insightMetrics.upcoming_appointments ?? 0} tone="warning" />
                  <SummaryCard label="Missed" value={insightMetrics.missed_appointments ?? 0} tone={(insightMetrics.missed_appointments || 0) > 0 ? 'danger' : 'success'} />
                  <SummaryCard label="Lab Follow-up" value={insightMetrics.overdue_lab_tests ?? 0} tone={(insightMetrics.overdue_lab_tests || 0) > 0 ? 'danger' : 'default'} />
                </div>
                <Button variant="primary" onClick={() => setShowApptModal(true)} style={{ marginLeft: '12px', whiteSpace: 'nowrap' }}>
                  <PlusIcon style={{ width: 16, height: 16 }} />
                  Book Appointment
                </Button>
              </div>
              {appointmentsHistory.length === 0 ? (
                <div style={{ color: '#64748b', textAlign: 'center', padding: '32px 0', fontSize: '14px' }}>
                  <p>No appointment history for this member yet.</p>
                </div>
              ) : (
                <div style={{ overflowX: 'auto' }}>
                  <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '14px' }}>
                    <thead>
                      <tr style={{ borderBottom: '2px solid #e2e8f0', background: '#f8fafc' }}>
                        {['Date', 'Hospital', 'Condition', 'Preferred Time', 'Reason', 'Status'].map((heading) => (
                          <th key={heading} style={{ padding: '10px 14px', textAlign: 'left', fontSize: '12px', fontWeight: '600', color: '#64748b', textTransform: 'uppercase', letterSpacing: '0.04em' }}>{heading}</th>
                        ))}
                      </tr>
                    </thead>
                    <tbody>
                      {appointmentsHistory.map((entry) => (
                        <tr key={entry.id} style={{ borderBottom: '1px solid #f1f5f9' }}>
                          <td style={{ padding: '11px 14px' }}>{formatDate(entry.appointment_date)}</td>
                          <td style={{ padding: '11px 14px' }}>{entry.hospital_name || '—'}</td>
                          <td style={{ padding: '11px 14px' }}>{entry.condition_name || '—'}</td>
                          <td style={{ padding: '11px 14px' }}>{entry.confirmed_time || entry.preferred_time || '—'}</td>
                          <td style={{ padding: '11px 14px', color: '#64748b' }}>{entry.reason || '—'}</td>
                          <td style={{ padding: '11px 14px' }}><Badge status={entry.status} /></td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
            </div>
          )}
          {activeTab === 'Lifestyle' && (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '18px' }}>
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '12px' }}>
                <SummaryCard label="Meals Logged" value={lifestyleSummary.meals_logged_last_30_days ?? meals.length} tone="info" />
                <SummaryCard label="Workouts Logged" value={lifestyleSummary.workouts_last_30_days ?? fitnessLogs.length} tone="success" />
                <SummaryCard label="Check-ins" value={lifestyleSummary.checkins_last_30_days ?? checkins.length} tone="default" />
                <SummaryCard label="Avg Stress / Anxiety" value={(insightMetrics.avg_stress_level !== null && insightMetrics.avg_stress_level !== undefined) || (insightMetrics.avg_anxiety_level !== null && insightMetrics.avg_anxiety_level !== undefined) ? `${insightMetrics.avg_stress_level ?? '—'} / ${insightMetrics.avg_anxiety_level ?? '—'}` : '—'} tone="warning" />
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
                <div style={{ background: '#fff', border: '1px solid #e2e8f0', borderRadius: '10px', padding: '16px' }}>
                  <h4 style={{ margin: '0 0 10px', fontSize: '14px', color: 'var(--text)' }}>Daily check-ins</h4>
                  {checkins.length === 0 ? <p style={{ margin: 0, fontSize: '13px', color: '#94a3b8' }}>No check-ins submitted yet.</p> : (
                    <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
                      {checkins.slice(0, 5).map((entry) => (
                        <div key={entry.id} style={{ borderBottom: '1px solid #f1f5f9', paddingBottom: '10px' }}>
                          <div style={{ fontSize: '13px', fontWeight: '600', color: 'var(--text)' }}>{formatDate(entry.checkin_date)} • Mood: {entry.mood || '—'}</div>
                          <div style={{ fontSize: '12px', color: '#64748b' }}>Energy: {entry.energy_level ?? '—'} | Symptoms: {Array.isArray(entry.symptoms) && entry.symptoms.length ? entry.symptoms.join(', ') : '—'}</div>
                          {entry.notes && <div style={{ fontSize: '12px', color: '#64748b', marginTop: '4px' }}>{entry.notes}</div>}
                        </div>
                      ))}
                    </div>
                  )}
                </div>

                <div style={{ background: '#fff', border: '1px solid #e2e8f0', borderRadius: '10px', padding: '16px' }}>
                  <h4 style={{ margin: '0 0 10px', fontSize: '14px', color: 'var(--text)' }}>Psychosocial wellness</h4>
                  {psychosocial.length === 0 ? <p style={{ margin: 0, fontSize: '13px', color: '#94a3b8' }}>No psychosocial entries submitted yet.</p> : (
                    <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
                      {psychosocial.slice(0, 5).map((entry) => (
                        <div key={entry.id} style={{ borderBottom: '1px solid #f1f5f9', paddingBottom: '10px' }}>
                          <div style={{ fontSize: '13px', fontWeight: '600', color: 'var(--text)' }}>{formatDate(entry.checkin_date)} • Mood: {entry.mood || '—'}</div>
                          <div style={{ fontSize: '12px', color: '#64748b' }}>Stress: {entry.stress_level ?? '—'} | Anxiety: {entry.anxiety_level ?? '—'}</div>
                          {entry.notes && <div style={{ fontSize: '12px', color: '#64748b', marginTop: '4px' }}>{entry.notes}</div>}
                        </div>
                      ))}
                    </div>
                  )}
                </div>
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
                <div style={{ background: '#fff', border: '1px solid #e2e8f0', borderRadius: '10px', padding: '16px' }}>
                  <h4 style={{ margin: '0 0 10px', fontSize: '14px', color: 'var(--text)' }}>Meals & nutrition</h4>
                  {meals.length === 0 ? <p style={{ margin: 0, fontSize: '13px', color: '#94a3b8' }}>No meal logs yet.</p> : (
                    <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
                      {meals.slice(0, 5).map((entry) => (
                        <div key={entry.id} style={{ borderBottom: '1px solid #f1f5f9', paddingBottom: '10px' }}>
                          <div style={{ fontSize: '13px', fontWeight: '600', color: 'var(--text)' }}>{formatDate(entry.log_date)} • {entry.meal_type || 'Meal'}</div>
                          <div style={{ fontSize: '12px', color: '#64748b' }}>{entry.description || 'No description'}</div>
                          <div style={{ fontSize: '12px', color: '#64748b', marginTop: '4px' }}>Calories: {entry.calories ?? '—'} | Carbs: {entry.carbs_g ?? '—'}g | Protein: {entry.protein_g ?? '—'}g</div>
                        </div>
                      ))}
                    </div>
                  )}
                </div>

                <div style={{ background: '#fff', border: '1px solid #e2e8f0', borderRadius: '10px', padding: '16px' }}>
                  <h4 style={{ margin: '0 0 10px', fontSize: '14px', color: 'var(--text)' }}>Fitness activity</h4>
                  {fitnessLogs.length === 0 ? <p style={{ margin: 0, fontSize: '13px', color: '#94a3b8' }}>No fitness logs yet.</p> : (
                    <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
                      {fitnessLogs.slice(0, 5).map((entry) => (
                        <div key={entry.id} style={{ borderBottom: '1px solid #f1f5f9', paddingBottom: '10px' }}>
                          <div style={{ fontSize: '13px', fontWeight: '600', color: 'var(--text)' }}>{formatDate(entry.log_date)} • {entry.activity_type || 'Activity'}</div>
                          <div style={{ fontSize: '12px', color: '#64748b' }}>Duration: {entry.duration_minutes ?? '—'} min | Steps: {entry.steps ?? '—'} | Intensity: {entry.intensity || '—'}</div>
                          {entry.notes && <div style={{ fontSize: '12px', color: '#64748b', marginTop: '4px' }}>{entry.notes}</div>}
                        </div>
                      ))}
                    </div>
                  )}
                </div>
              </div>
            </div>
          )}

          {/* ── Activity Log ── */}
          {activeTab === 'Activity Log' && (
            <div>
              <h3 style={{ margin: '0 0 16px', fontSize: '16px', fontWeight: 600, color: 'var(--text)' }}>
                <ClockIcon style={{ width: 18, height: 18, display: 'inline', verticalAlign: 'text-bottom', marginRight: '6px' }} />
                Admin Activity Log
              </h3>
              {auditLoading ? (
                <Spinner />
              ) : auditLogs.length === 0 ? (
                <div style={{ textAlign: 'center', padding: '48px 0', color: '#94a3b8', fontSize: '14px', fontStyle: 'italic' }}>
                  No activity logged for this member yet.
                </div>
              ) : (
                <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                  {auditLogs.map((log) => {
                    const details = typeof log.details === 'string' ? JSON.parse(log.details) : (log.details || {});
                    return (
                      <div key={log.id} style={{ border: '1px solid #e2e8f0', borderRadius: '10px', padding: '14px 18px', background: '#fff' }}>
                        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: '12px' }}>
                          <div>
                            <span style={{ fontSize: '14px', fontWeight: 600, color: 'var(--text)', textTransform: 'capitalize' }}>
                              {log.action?.replace(/_/g, ' ')}
                            </span>
                            <span style={{ fontSize: '13px', color: '#64748b', marginLeft: '8px' }}>
                              on {log.entity?.replace(/_/g, ' ')}
                            </span>
                          </div>
                          <span style={{ fontSize: '12px', color: '#94a3b8', whiteSpace: 'nowrap' }}>
                            {new Date(log.created_at).toLocaleString('en-UG', { day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' })}
                          </span>
                        </div>
                        <div style={{ fontSize: '13px', color: '#475569', marginTop: '6px' }}>
                          <strong>By:</strong> {details.admin_name || log.actor_name || 'System'}
                          {details.member_number && <span style={{ marginLeft: '12px' }}><strong>Member:</strong> {details.member_number}</span>}
                          {details.title && <span style={{ marginLeft: '12px' }}><strong>Title:</strong> {details.title}</span>}
                          {details.hospital && <span style={{ marginLeft: '12px' }}><strong>Hospital:</strong> {details.hospital}</span>}
                        </div>
                      </div>
                    );
                  })}
                </div>
              )}
            </div>
          )}

          {/* ── Care Buddies ── */}
          {activeTab === 'Care Buddies' && (
            <div>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '16px' }}>
                <h3 style={{ margin: 0, fontSize: '16px', fontWeight: 600, color: 'var(--text)' }}>Care Buddies</h3>
                <Button variant="primary" onClick={() => { setBuddyForm({ name: '', phone: '', relationship: '' }); setEditingBuddyId(null); setShowBuddyModal(true); }}>
                  <PlusIcon style={{ width: 16, height: 16 }} />
                  Add Buddy
                </Button>
              </div>
              {buddiesLoading ? (
                <Spinner />
              ) : buddies.length === 0 ? (
                <div style={{ textAlign: 'center', padding: '48px 0', color: '#94a3b8', fontSize: '14px', fontStyle: 'italic' }}>
                  No care buddies added yet.
                </div>
              ) : (
                <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                  {buddies.map((buddy) => (
                    <div key={buddy.id} style={{ border: '1px solid #e2e8f0', borderRadius: '10px', padding: '16px', background: '#fff', display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: '12px', flexWrap: 'wrap' }}>
                      <div>
                        <h4 style={{ margin: '0 0 4px', fontSize: '15px', fontWeight: '600', color: 'var(--text)' }}>{buddy.name}</h4>
                        <p style={{ margin: '0 0 2px', fontSize: '13px', color: '#64748b' }}>Phone: {buddy.phone || '—'}</p>
                        <p style={{ margin: 0, fontSize: '13px', color: '#64748b' }}>Relationship: {buddy.relationship || '—'}</p>
                      </div>
                      <div style={{ display: 'flex', gap: '8px' }}>
                        <Button variant="secondary" onClick={() => { setBuddyForm({ name: buddy.name || '', phone: buddy.phone || '', relationship: buddy.relationship || '' }); setEditingBuddyId(buddy.id); setShowBuddyModal(true); }}>
                          Edit
                        </Button>
                        <Button variant="ghost" onClick={() => { if (window.confirm('Remove this care buddy?')) deleteBuddyMutation.mutate(buddy.id); }}>
                          Delete
                        </Button>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          )}
        </div>
      </div>

      {/* Schedule Lab Test Modal */}
      {showLabModal && (
        <Modal title="Schedule Lab Test" onClose={() => setShowLabModal(false)} width="480px">
          <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
              <label style={{ fontSize: '13px', fontWeight: '500', color: '#475569' }}>Test Type</label>
              <select
                value={labForm.test_type}
                onChange={(e) => setLabForm((f) => ({ ...f, test_type: e.target.value }))}
                style={{ padding: '8px 12px', borderRadius: '6px', border: '1px solid #e2e8f0', fontSize: '14px', color: 'var(--text)', background: '#fff' }}
              >
                {LAB_TEST_TYPES.map((t) => <option key={t} value={t}>{t}</option>)}
              </select>
            </div>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
              <label style={{ fontSize: '13px', fontWeight: '500', color: '#475569' }}>Due Date</label>
              <input
                type="date"
                value={labForm.due_date}
                min={new Date().toISOString().split('T')[0]}
                onChange={(e) => setLabForm((f) => ({ ...f, due_date: e.target.value }))}
                style={{ padding: '8px 12px', borderRadius: '6px', border: '1px solid #e2e8f0', fontSize: '14px', color: 'var(--text)' }}
              />
            </div>
            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '8px', marginTop: '4px' }}>
              <Button variant="secondary" onClick={() => setShowLabModal(false)}>Cancel</Button>
              <Button
                variant="primary"
                onClick={handleScheduleLab}
                disabled={scheduleLabMutation.isPending}
              >
                {scheduleLabMutation.isPending ? 'Scheduling…' : 'Schedule Test'}
              </Button>
            </div>
          </div>
        </Modal>
      )}

      {/* Add Treatment Plan Modal */}
      {showTpModal && (
        <Modal title="Add Treatment Plan" onClose={() => setShowTpModal(false)} width="560px">
          <div style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
              <label style={{ fontSize: '13px', fontWeight: '500', color: '#475569' }}>Title *</label>
              <input
                type="text"
                value={tpForm.title}
                onChange={(e) => setTpForm(f => ({ ...f, title: e.target.value }))}
                placeholder="e.g. Blood Pressure Management"
                style={{ padding: '8px 12px', borderRadius: '6px', border: '1px solid #e2e8f0', fontSize: '14px' }}
              />
            </div>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
              <label style={{ fontSize: '13px', fontWeight: '500', color: '#475569' }}>Description</label>
              <textarea
                value={tpForm.description}
                onChange={(e) => setTpForm(f => ({ ...f, description: e.target.value }))}
                placeholder="Treatment plan details…"
                rows={3}
                style={{ padding: '8px 12px', borderRadius: '6px', border: '1px solid #e2e8f0', fontSize: '14px', resize: 'vertical' }}
              />
            </div>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                <label style={{ fontSize: '13px', fontWeight: '500', color: '#475569' }}>Provider Name</label>
                <input
                  type="text"
                  value={tpForm.provider_name}
                  onChange={(e) => setTpForm(f => ({ ...f, provider_name: e.target.value }))}
                  placeholder="e.g. Uganda Heart Institute"
                  style={{ padding: '8px 12px', borderRadius: '6px', border: '1px solid #e2e8f0', fontSize: '14px' }}
                />
              </div>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                <label style={{ fontSize: '13px', fontWeight: '500', color: '#475569' }}>Plan Date</label>
                <input
                  type="date"
                  value={tpForm.plan_date}
                  onChange={(e) => setTpForm(f => ({ ...f, plan_date: e.target.value }))}
                  style={{ padding: '8px 12px', borderRadius: '6px', border: '1px solid #e2e8f0', fontSize: '14px' }}
                />
              </div>
            </div>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                <label style={{ fontSize: '13px', fontWeight: '500', color: '#475569' }}>Cost (UGX)</label>
                <input
                  type="number"
                  value={tpForm.cost}
                  onChange={(e) => setTpForm(f => ({ ...f, cost: e.target.value }))}
                  placeholder="0"
                  style={{ padding: '8px 12px', borderRadius: '6px', border: '1px solid #e2e8f0', fontSize: '14px' }}
                />
              </div>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                <label style={{ fontSize: '13px', fontWeight: '500', color: '#475569' }}>Condition</label>
                <select
                  value={tpForm.condition_id}
                  onChange={(e) => setTpForm(f => ({ ...f, condition_id: e.target.value }))}
                  style={{ padding: '8px 12px', borderRadius: '6px', border: '1px solid #e2e8f0', fontSize: '14px', background: '#fff' }}
                >
                  <option value="">Select condition</option>
                  {(Array.isArray(m.conditions) ? m.conditions : []).map(c => {
                    const condId = typeof c === 'string' ? '' : c?.id;
                    const condName = typeof c === 'string' ? c : c?.name;
                    return condId ? <option key={condId} value={condId}>{condName}</option> : null;
                  }).filter(Boolean)}
                </select>
              </div>
            </div>
            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '8px', marginTop: '4px' }}>
              <Button variant="secondary" onClick={() => setShowTpModal(false)}>Cancel</Button>
              <Button
                variant="primary"
                disabled={!tpForm.title || createTpMutation.isPending}
                onClick={() => {
                  const fd = new FormData();
                  fd.append('member_id', id);
                  fd.append('title', tpForm.title);
                  if (tpForm.description) fd.append('description', tpForm.description);
                  if (tpForm.provider_name) fd.append('provider_name', tpForm.provider_name);
                  if (tpForm.plan_date) fd.append('plan_date', tpForm.plan_date);
                  if (tpForm.cost) fd.append('cost', tpForm.cost);
                  if (tpForm.condition_id) fd.append('condition_id', tpForm.condition_id);
                  createTpMutation.mutate(fd);
                }}
              >
                {createTpMutation.isPending ? 'Creating…' : 'Create Treatment Plan'}
              </Button>
            </div>
          </div>
        </Modal>
      )}

      {/* Book Appointment Modal */}
      {showApptModal && (
        <Modal title="Book Appointment" onClose={() => { setShowApptModal(false); setHospitalSearch(''); }} width="520px">
          <div style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '6px', position: 'relative' }}>
              <label style={{ fontSize: '13px', fontWeight: '500', color: '#475569' }}>Hospital *</label>
              <input
                type="text"
                placeholder="Search hospital…"
                value={hospitalSearch}
                onChange={(e) => { setHospitalSearch(e.target.value); setShowHospitalDropdown(true); }}
                onFocus={() => setShowHospitalDropdown(true)}
                style={{ padding: '8px 12px', borderRadius: '6px', border: '1px solid #e2e8f0', fontSize: '14px' }}
              />
              {showHospitalDropdown && hospitalSearch.length > 0 && (
                <HospitalDropdown
                  search={hospitalSearch}
                  onSelect={(hospital) => {
                    setApptForm(f => ({ ...f, hospital_id: hospital.id }));
                    setHospitalSearch(hospital.name);
                    setShowHospitalDropdown(false);
                  }}
                />
              )}
            </div>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
              <label style={{ fontSize: '13px', fontWeight: '500', color: '#475569' }}>Condition</label>
              <select
                value={apptForm.condition_id}
                onChange={(e) => setApptForm(f => ({ ...f, condition_id: e.target.value }))}
                style={{ padding: '8px 12px', borderRadius: '6px', border: '1px solid #e2e8f0', fontSize: '14px', background: '#fff' }}
              >
                <option value="">Select condition</option>
                {(Array.isArray(m.conditions) ? m.conditions : []).map(c => {
                  const condId = typeof c === 'string' ? '' : c?.id;
                  const condName = typeof c === 'string' ? c : c?.name;
                  return condId ? <option key={condId} value={condId}>{condName}</option> : null;
                }).filter(Boolean)}
              </select>
            </div>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                <label style={{ fontSize: '13px', fontWeight: '500', color: '#475569' }}>Appointment Date *</label>
                <input
                  type="date"
                  value={apptForm.appointment_date}
                  min={new Date().toISOString().split('T')[0]}
                  onChange={(e) => setApptForm(f => ({ ...f, appointment_date: e.target.value }))}
                  style={{ padding: '8px 12px', borderRadius: '6px', border: '1px solid #e2e8f0', fontSize: '14px' }}
                />
              </div>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                <label style={{ fontSize: '13px', fontWeight: '500', color: '#475569' }}>Preferred Time</label>
                <select
                  value={apptForm.preferred_time}
                  onChange={(e) => setApptForm(f => ({ ...f, preferred_time: e.target.value }))}
                  style={{ padding: '8px 12px', borderRadius: '6px', border: '1px solid #e2e8f0', fontSize: '14px', background: '#fff' }}
                >
                  <option value="">Any time</option>
                  <option value="morning">Morning (8am–12pm)</option>
                  <option value="afternoon">Afternoon (12pm–5pm)</option>
                  <option value="evening">Evening (5pm–8pm)</option>
                </select>
              </div>
            </div>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
              <label style={{ fontSize: '13px', fontWeight: '500', color: '#475569' }}>Reason</label>
              <textarea
                value={apptForm.reason}
                onChange={(e) => setApptForm(f => ({ ...f, reason: e.target.value }))}
                placeholder="Reason for appointment…"
                rows={2}
                style={{ padding: '8px 12px', borderRadius: '6px', border: '1px solid #e2e8f0', fontSize: '14px', resize: 'vertical' }}
              />
            </div>
            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '8px', marginTop: '4px' }}>
              <Button variant="secondary" onClick={() => { setShowApptModal(false); setHospitalSearch(''); }}>Cancel</Button>
              <Button
                variant="primary"
                disabled={!apptForm.hospital_id || !apptForm.appointment_date || createApptMutation.isPending}
                onClick={() => createApptMutation.mutate({
                  member_id: id,
                  hospital_id: apptForm.hospital_id,
                  condition_id: apptForm.condition_id || undefined,
                  appointment_date: apptForm.appointment_date,
                  preferred_time: apptForm.preferred_time || undefined,
                  reason: apptForm.reason || undefined,
                })}
              >
                {createApptMutation.isPending ? 'Booking…' : 'Book Appointment'}
              </Button>
            </div>
          </div>
        </Modal>
      )}

      {/* Edit Member Modal */}
      {showEditModal && (
        <Modal title="Edit Member Details" onClose={() => setShowEditModal(false)} width="560px">
          <div style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
              <label style={{ fontSize: '13px', fontWeight: '500', color: '#475569' }}>Member Number</label>
              <input
                type="text"
                value={editForm.member_number || ''}
                onChange={(e) => setEditForm(f => ({ ...f, member_number: e.target.value }))}
                style={{ padding: '8px 12px', borderRadius: '6px', border: '1px solid #e2e8f0', fontSize: '14px' }}
              />
            </div>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                <label style={{ fontSize: '13px', fontWeight: '500', color: '#475569' }}>First Name</label>
                <input
                  type="text"
                  value={editForm.first_name || ''}
                  onChange={(e) => setEditForm(f => ({ ...f, first_name: e.target.value }))}
                  style={{ padding: '8px 12px', borderRadius: '6px', border: '1px solid #e2e8f0', fontSize: '14px' }}
                />
              </div>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                <label style={{ fontSize: '13px', fontWeight: '500', color: '#475569' }}>Last Name</label>
                <input
                  type="text"
                  value={editForm.last_name || ''}
                  onChange={(e) => setEditForm(f => ({ ...f, last_name: e.target.value }))}
                  style={{ padding: '8px 12px', borderRadius: '6px', border: '1px solid #e2e8f0', fontSize: '14px' }}
                />
              </div>
            </div>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                <label style={{ fontSize: '13px', fontWeight: '500', color: '#475569' }}>Email</label>
                <input
                  type="email"
                  value={editForm.email || ''}
                  onChange={(e) => setEditForm(f => ({ ...f, email: e.target.value }))}
                  style={{ padding: '8px 12px', borderRadius: '6px', border: '1px solid #e2e8f0', fontSize: '14px' }}
                />
              </div>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                <label style={{ fontSize: '13px', fontWeight: '500', color: '#475569' }}>Phone</label>
                <input
                  type="text"
                  value={editForm.phone || ''}
                  onChange={(e) => setEditForm(f => ({ ...f, phone: e.target.value }))}
                  style={{ padding: '8px 12px', borderRadius: '6px', border: '1px solid #e2e8f0', fontSize: '14px' }}
                />
              </div>
            </div>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                <label style={{ fontSize: '13px', fontWeight: '500', color: '#475569' }}>Date of Birth</label>
                <input
                  type="date"
                  value={editForm.date_of_birth || ''}
                  onChange={(e) => setEditForm(f => ({ ...f, date_of_birth: e.target.value }))}
                  style={{ padding: '8px 12px', borderRadius: '6px', border: '1px solid #e2e8f0', fontSize: '14px' }}
                />
              </div>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                <label style={{ fontSize: '13px', fontWeight: '500', color: '#475569' }}>ID Number</label>
                <input
                  type="text"
                  value={editForm.id_number || ''}
                  onChange={(e) => setEditForm(f => ({ ...f, id_number: e.target.value }))}
                  style={{ padding: '8px 12px', borderRadius: '6px', border: '1px solid #e2e8f0', fontSize: '14px' }}
                />
              </div>
            </div>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                <label style={{ fontSize: '13px', fontWeight: '500', color: '#475569' }}>Gender</label>
                <select
                  value={editForm.gender || ''}
                  onChange={(e) => setEditForm(f => ({ ...f, gender: e.target.value }))}
                  style={{ padding: '8px 12px', borderRadius: '6px', border: '1px solid #e2e8f0', fontSize: '14px', background: '#fff' }}
                >
                  <option value="">Select gender</option>
                  <option value="male">Male</option>
                  <option value="female">Female</option>
                  <option value="other">Other</option>
                </select>
              </div>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                <label style={{ fontSize: '13px', fontWeight: '500', color: '#475569' }}>Scheme</label>
                <select
                  value={editForm.scheme_id || ''}
                  onChange={(e) => setEditForm(f => ({ ...f, scheme_id: e.target.value }))}
                  style={{ padding: '8px 12px', borderRadius: '6px', border: '1px solid #e2e8f0', fontSize: '14px', background: '#fff' }}
                >
                  <option value="">Select scheme</option>
                  {schemesForEdit.map(s => (
                    <option key={s.id} value={s.id}>{s.name}</option>
                  ))}
                </select>
              </div>
            </div>
            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '8px', marginTop: '4px' }}>
              <Button variant="secondary" onClick={() => setShowEditModal(false)}>Cancel</Button>
              <Button
                variant="primary"
                disabled={updateMemberMutation.isPending}
                onClick={() => updateMemberMutation.mutate(editForm)}
              >
                {updateMemberMutation.isPending ? 'Saving…' : 'Save Changes'}
              </Button>
            </div>
          </div>
        </Modal>
      )}

      {/* Add Medication Modal */}
      {showMedModal && (
        <Modal title="Add Medication" onClose={() => { setShowMedModal(false); setMedSearch(''); }} width="560px">
          <div style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '6px', position: 'relative' }}>
              <label style={{ fontSize: '13px', fontWeight: '500', color: '#475569' }}>Medication Name *</label>
              <input
                type="text"
                placeholder="Search medication…"
                value={medSearch || medForm.name}
                onChange={(e) => { setMedSearch(e.target.value); setMedForm(f => ({ ...f, name: e.target.value, medication_id: '' })); }}
                style={{ padding: '8px 12px', borderRadius: '6px', border: '1px solid #e2e8f0', fontSize: '14px' }}
              />
              {medSearch.length > 1 && medCatalogue.length > 0 && (
                <div style={{
                  position: 'absolute', top: '100%', left: 0, right: 0, zIndex: 50,
                  background: '#fff', border: '1px solid #e2e8f0', borderRadius: '6px',
                  boxShadow: '0 4px 12px rgba(0,0,0,0.1)', maxHeight: '180px', overflowY: 'auto',
                }}>
                  {medCatalogue.slice(0, 10).map(med => (
                    <div
                      key={med.id}
                      onClick={() => { setMedForm(f => ({ ...f, name: med.name, medication_id: med.id })); setMedSearch(''); }}
                      style={{ padding: '8px 12px', cursor: 'pointer', fontSize: '14px' }}
                      onMouseEnter={(e) => e.currentTarget.style.background = '#f1f5f9'}
                      onMouseLeave={(e) => e.currentTarget.style.background = 'transparent'}
                    >
                      {med.name}{med.generic_name ? ` (${med.generic_name})` : ''}
                    </div>
                  ))}
                </div>
              )}
            </div>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                <label style={{ fontSize: '13px', fontWeight: '500', color: '#475569' }}>Dosage</label>
                <input
                  type="text"
                  placeholder="e.g. 500mg"
                  value={medForm.dosage}
                  onChange={(e) => setMedForm(f => ({ ...f, dosage: e.target.value }))}
                  style={{ padding: '8px 12px', borderRadius: '6px', border: '1px solid #e2e8f0', fontSize: '14px' }}
                />
              </div>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                <label style={{ fontSize: '13px', fontWeight: '500', color: '#475569' }}>Frequency</label>
                <select
                  value={medForm.frequency}
                  onChange={(e) => setMedForm(f => ({ ...f, frequency: e.target.value }))}
                  style={{ padding: '8px 12px', borderRadius: '6px', border: '1px solid #e2e8f0', fontSize: '14px', background: '#fff' }}
                >
                  <option value="">Select frequency</option>
                  {['Once daily', 'Twice daily', 'Three times daily', 'Four times daily', 'Every 8 hours', 'Every 12 hours', 'As needed'].map(f => (
                    <option key={f} value={f}>{f}</option>
                  ))}
                </select>
              </div>
            </div>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                <label style={{ fontSize: '13px', fontWeight: '500', color: '#475569' }}>Start Date</label>
                <input
                  type="date"
                  value={medForm.start_date}
                  onChange={(e) => setMedForm(f => ({ ...f, start_date: e.target.value }))}
                  style={{ padding: '8px 12px', borderRadius: '6px', border: '1px solid #e2e8f0', fontSize: '14px' }}
                />
              </div>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                <label style={{ fontSize: '13px', fontWeight: '500', color: '#475569' }}>End Date</label>
                <input
                  type="date"
                  value={medForm.end_date}
                  onChange={(e) => setMedForm(f => ({ ...f, end_date: e.target.value }))}
                  style={{ padding: '8px 12px', borderRadius: '6px', border: '1px solid #e2e8f0', fontSize: '14px' }}
                />
              </div>
            </div>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
              <label style={{ fontSize: '13px', fontWeight: '500', color: '#475569' }}>Notes</label>
              <textarea
                value={medForm.notes}
                onChange={(e) => setMedForm(f => ({ ...f, notes: e.target.value }))}
                placeholder="Additional notes…"
                rows={2}
                style={{ padding: '8px 12px', borderRadius: '6px', border: '1px solid #e2e8f0', fontSize: '14px', resize: 'vertical' }}
              />
            </div>
            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '8px', marginTop: '4px' }}>
              <Button variant="secondary" onClick={() => { setShowMedModal(false); setMedSearch(''); }}>Cancel</Button>
              <Button
                variant="primary"
                disabled={!medForm.name || assignMedMutation.isPending}
                onClick={() => {
                  const fd = new FormData();
                  fd.append('member_id', id);
                  fd.append('name', medForm.name);
                  if (medForm.medication_id) fd.append('medication_id', medForm.medication_id);
                  if (medForm.dosage) fd.append('dosage', medForm.dosage);
                  if (medForm.frequency) fd.append('frequency', medForm.frequency);
                  if (medForm.start_date) fd.append('start_date', medForm.start_date);
                  if (medForm.end_date) fd.append('end_date', medForm.end_date);
                  if (medForm.notes) fd.append('notes', medForm.notes);
                  assignMedMutation.mutate(fd);
                }}
              >
                {assignMedMutation.isPending ? 'Assigning…' : 'Assign Medication'}
              </Button>
            </div>
          </div>
        </Modal>
      )}

      {/* Care Buddy Modal */}
      {showBuddyModal && (
        <Modal title={editingBuddyId ? 'Edit Care Buddy' : 'Add Care Buddy'} onClose={() => { setShowBuddyModal(false); setEditingBuddyId(null); }} width="480px">
          <div style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
              <label style={{ fontSize: '13px', fontWeight: '500', color: '#475569' }}>Name *</label>
              <input
                type="text"
                value={buddyForm.name}
                onChange={(e) => setBuddyForm(f => ({ ...f, name: e.target.value }))}
                placeholder="Buddy's full name"
                style={{ padding: '8px 12px', borderRadius: '6px', border: '1px solid #e2e8f0', fontSize: '14px' }}
              />
            </div>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
              <label style={{ fontSize: '13px', fontWeight: '500', color: '#475569' }}>Phone</label>
              <input
                type="text"
                value={buddyForm.phone}
                onChange={(e) => setBuddyForm(f => ({ ...f, phone: e.target.value }))}
                placeholder="e.g. 0771234567"
                style={{ padding: '8px 12px', borderRadius: '6px', border: '1px solid #e2e8f0', fontSize: '14px' }}
              />
            </div>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
              <label style={{ fontSize: '13px', fontWeight: '500', color: '#475569' }}>Relationship</label>
              <input
                type="text"
                value={buddyForm.relationship}
                onChange={(e) => setBuddyForm(f => ({ ...f, relationship: e.target.value }))}
                placeholder="e.g. Spouse, Sibling, Friend"
                style={{ padding: '8px 12px', borderRadius: '6px', border: '1px solid #e2e8f0', fontSize: '14px' }}
              />
            </div>
            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '8px', marginTop: '4px' }}>
              <Button variant="secondary" onClick={() => { setShowBuddyModal(false); setEditingBuddyId(null); }}>Cancel</Button>
              <Button
                variant="primary"
                disabled={!buddyForm.name || addBuddyMutation.isPending}
                onClick={() => addBuddyMutation.mutate(buddyForm)}
              >
                {addBuddyMutation.isPending ? 'Saving…' : (editingBuddyId ? 'Update Buddy' : 'Add Buddy')}
              </Button>
            </div>
          </div>
        </Modal>
      )}
    </div>
  );
}
