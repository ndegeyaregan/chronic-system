import { useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import toast from 'react-hot-toast';
import { ArrowLeftIcon, PlusIcon, DocumentArrowDownIcon } from '@heroicons/react/24/outline';
import { getMemberById, toggleMemberStatus } from '../../api/members';
import { resetMemberPassword } from '../../api/auth';
import { getTreatmentPlansByMember } from '../../api/treatmentPlans';
import { getLabTestsByMember, scheduleLabTest } from '../../api/labTests';
import { getMemberProvider } from '../../api/memberProvider';
import Badge from '../../components/UI/Badge';
import Button from '../../components/UI/Button';
import Spinner from '../../components/UI/Spinner';
import Modal from '../../components/UI/Modal';

const TABS = ['Overview', 'Treatment Plans', 'Lab Results', 'Medications', 'Vitals', 'Appointments', 'Lifestyle'];

const LAB_TEST_TYPES = ['Liver Function Test', 'Kidney Function Test'];
const API_BASE = (import.meta.env.VITE_API_URL || 'http://localhost:5000/api').replace(/\/api$/, '');

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

export default function MemberDetailPage() {
  const { id } = useParams();
  const navigate = useNavigate();
  const qc = useQueryClient();
  const [activeTab, setActiveTab] = useState('Overview');
  const [showLabModal, setShowLabModal] = useState(false);
  const [labForm, setLabForm] = useState({ test_type: 'Liver Function Test', due_date: '' });

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
                  {m.plan} Plan
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
              <InfoRow label="Full Name" value={`${m.first_name} ${m.last_name}`} />
              <InfoRow label="Email" value={m.email} />
              <InfoRow label="Phone" value={m.phone} />
              <InfoRow label="Date of Birth" value={m.date_of_birth} />
              <InfoRow label="ID Number" value={m.id_number} />
              <InfoRow label="Address" value={m.address} />
              <InfoRow label="Plan" value={m.plan} />
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
                <Button variant="primary" onClick={() => setShowLabModal(true)}>
                  <PlusIcon style={{ width: 16, height: 16 }} />
                  Schedule Lab Test
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
            medications.length === 0 ? (
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
            )
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
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '12px' }}>
                <SummaryCard label="Upcoming" value={insightMetrics.upcoming_appointments ?? 0} tone="warning" />
                <SummaryCard label="Missed" value={insightMetrics.missed_appointments ?? 0} tone={(insightMetrics.missed_appointments || 0) > 0 ? 'danger' : 'success'} />
                <SummaryCard label="Lab Follow-up" value={insightMetrics.overdue_lab_tests ?? 0} tone={(insightMetrics.overdue_lab_tests || 0) > 0 ? 'danger' : 'default'} />
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
    </div>
  );
}
