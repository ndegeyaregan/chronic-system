import { useEffect, useMemo, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import toast from 'react-hot-toast';
import {
  CheckCircleIcon, XCircleIcon, ClockIcon, ExclamationTriangleIcon,
  MagnifyingGlassIcon, FunnelIcon, BeakerIcon, ClipboardDocumentListIcon,
  EnvelopeIcon, PaperAirplaneIcon,
} from '@heroicons/react/24/outline';
import { getAdminAuthorizations, getAuthorizationStats, reviewAuthorization, getFacilityEmail, sendAuthorizationEmail } from '../../api/authorizations';
import { useAuth } from '../../context/AuthContext';
import Table from '../../components/UI/Table';
import Badge from '../../components/UI/Badge';
import Button from '../../components/UI/Button';
import Modal from '../../components/UI/Modal';
import Spinner from '../../components/UI/Spinner';

/* ── helpers ── */
const card = { background: '#fff', borderRadius: '12px', padding: '18px 20px', boxShadow: '0 1px 4px rgba(0,0,0,0.07)' };

function StatCard({ label, value, color = '#3b82f6', Icon, sub }) {
  return (
    <div style={{ ...card, display: 'flex', alignItems: 'center', gap: '16px', flex: 1, minWidth: 140 }}>
      <div style={{ width: 42, height: 42, borderRadius: '10px', background: color + '1a',
        display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
        {Icon && <Icon style={{ width: 20, height: 20, color }} />}
      </div>
      <div>
        <div style={{ fontSize: '24px', fontWeight: 700, color: '#0f172a', lineHeight: 1.1 }}>{value ?? 0}</div>
        <div style={{ fontSize: '13px', color: '#64748b', marginTop: '2px' }}>{label}</div>
        {sub && <div style={{ fontSize: '11px', color, marginTop: '2px' }}>{sub}</div>}
      </div>
    </div>
  );
}

function TypeBadge({ type }) {
  const map = {
    medication_refill: { label: 'Refill',     bg: '#eff6ff', color: '#3b82f6' },
    procedure:         { label: 'Procedure',  bg: '#f0fdf4', color: '#16a34a' },
    surgery:           { label: 'Surgery',    bg: '#fef2f2', color: '#dc2626' },
    follow_up:         { label: 'Follow-up',  bg: '#fff7ed', color: '#ea580c' },
  };
  const s = map[type] || { label: type, bg: '#f8fafc', color: '#64748b' };
  return (
    <span style={{ fontSize: '12px', fontWeight: 600, padding: '2px 8px',
      borderRadius: '20px', background: s.bg, color: s.color, whiteSpace: 'nowrap' }}>
      {s.label}
    </span>
  );
}

const STATUS_TABS = ['all', 'pending', 'approved', 'rejected', 'cancelled'];

/* ── Email template generator ── */
function buildEmailTemplate({ request, adminName, facilityContact }) {
  const typeLabels = {
    medication_refill: 'Medication Refill',
    procedure:         'Medical Procedure',
    surgery:           'Surgical Procedure',
    follow_up:         'Follow-up Consultation',
  };
  const refId = request.id?.split('-')[0]?.toUpperCase();
  const today = new Date().toLocaleDateString('en-GB', { day: 'numeric', month: 'long', year: 'numeric' });
  const contact = facilityContact || 'The Pharmacy / Hospital Manager';
  const lines = [
    `Dear ${contact},`,
    ``,
    `RE: AUTHORIZATION FOR ${typeLabels[request.request_type]?.toUpperCase() ?? request.request_type?.toUpperCase()}`,
    `Authorization Reference: ${refId}   |   Date: ${today}`,
    ``,
    `This letter serves as official authorization from Sanlam Chronic Care Programme for the following service:`,
    ``,
    `**Member Details**`,
    `Name:          ${request.first_name} ${request.last_name}`,
    `Member Number: ${request.member_number}`,
    ``,
    `**Service Details**`,
    `Request Type:  ${typeLabels[request.request_type] ?? request.request_type}`,
    ...(request.medication_name ? [
      `Medication:    ${request.medication_name}${request.dosage ? ' — ' + request.dosage : ''}${request.frequency ? ', ' + request.frequency : ''}`,
    ] : []),
    ...(request.treatment_plan_title ? [
      `Treatment Plan: ${request.treatment_plan_title}`,
    ] : []),
    ...(request.scheduled_date ? [
      `Scheduled Date: ${new Date(request.scheduled_date).toLocaleDateString('en-GB', { day: 'numeric', month: 'long', year: 'numeric' })}`,
    ] : []),
    ``,
    `Please proceed with providing the above service to the member as per their approved treatment plan.`,
    ``,
    `Should you require any further information or verification, please do not hesitate to contact us.`,
    ``,
    `Yours faithfully,`,
    ``,
    `${adminName}`,
    `Sanlam Chronic Care Programme`,
    `Email: systems@sanlamallianz4u.co.ug`,
  ];
  return lines.join('\n');
}

/* ── EmailStep (2nd step of approval modal) ── */
function EmailStep({ request, approvedId, adminUser, onClose }) {
  const [to,      setTo]      = useState('');
  const [cc,      setCc]      = useState('');
  const [subject, setSubject] = useState('');
  const [body,    setBody]    = useState('');
  const [loading, setLoading] = useState(true);

  const adminName = adminUser?.name || `${adminUser?.first_name ?? ''} ${adminUser?.last_name ?? ''}`.trim() || 'Admin';

  // Load facility email on mount
  useEffect(() => {
    getFacilityEmail(approvedId)
      .then((r) => {
        const fac = r.data;
        setTo(fac.email ?? '');
        const subj = `Authorization Letter – ${request.first_name} ${request.last_name} – Ref ${approvedId.split('-')[0].toUpperCase()}`;
        setSubject(subj);
        setBody(buildEmailTemplate({ request, adminName, facilityContact: fac.contact }));
      })
      .catch(() => {
        setSubject(`Authorization Letter – ${request.first_name} ${request.last_name}`);
        setBody(buildEmailTemplate({ request, adminName, facilityContact: '' }));
      })
      .finally(() => setLoading(false));
  }, []);

  const sendMutation = useMutation({
    mutationFn: () => sendAuthorizationEmail(approvedId, { to, cc: cc || undefined, subject, body }),
    onSuccess: () => { toast.success('Authorization email sent ✓'); onClose(); },
    onError: (err) => toast.error(err?.response?.data?.message || 'Failed to send email'),
  });

  const fieldStyle = {
    padding: '8px 12px', borderRadius: '6px', border: '1px solid #e2e8f0',
    fontSize: '13px', width: '100%', boxSizing: 'border-box', fontFamily: 'inherit',
  };

  if (loading) return <div style={{ padding: '40px', display: 'flex', justifyContent: 'center' }}><Spinner /></div>;

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
      {/* Info bar */}
      <div style={{ background: '#f0fdf4', border: '1px solid #bbf7d0', borderRadius: '8px',
        padding: '10px 14px', fontSize: '13px', color: '#166534', display: 'flex', alignItems: 'center', gap: '8px' }}>
        <CheckCircleIcon style={{ width: 16, height: 16, flexShrink: 0 }} />
        Authorization approved. Compose and send the letter to the provider below.
      </div>

      {/* From (read-only) */}
      <div>
        <label style={{ fontSize: '12px', fontWeight: 600, color: '#64748b', display: 'block', marginBottom: '4px' }}>FROM</label>
        <div style={{ ...fieldStyle, background: '#f8fafc', color: '#64748b' }}>
          {adminUser?.email ?? 'systems@sanlamallianz4u.co.ug'} (via Sanlam SMTP)
        </div>
      </div>

      {/* To */}
      <div>
        <label style={{ fontSize: '12px', fontWeight: 600, color: '#475569', display: 'block', marginBottom: '4px' }}>
          TO <span style={{ color: '#ef4444' }}>*</span>
          {!to && <span style={{ color: '#f59e0b', fontWeight: 400, marginLeft: '6px' }}>⚠ No email on file — please enter manually</span>}
        </label>
        <input value={to} onChange={(e) => setTo(e.target.value)}
          placeholder="provider@hospital.com" style={fieldStyle} />
      </div>

      {/* CC */}
      <div>
        <label style={{ fontSize: '12px', fontWeight: 600, color: '#94a3b8', display: 'block', marginBottom: '4px' }}>CC (optional)</label>
        <input value={cc} onChange={(e) => setCc(e.target.value)}
          placeholder="e.g. manager@sanlam.com" style={fieldStyle} />
      </div>

      {/* Subject */}
      <div>
        <label style={{ fontSize: '12px', fontWeight: 600, color: '#475569', display: 'block', marginBottom: '4px' }}>SUBJECT</label>
        <input value={subject} onChange={(e) => setSubject(e.target.value)} style={fieldStyle} />
      </div>

      {/* Body */}
      <div>
        <label style={{ fontSize: '12px', fontWeight: 600, color: '#475569', display: 'block', marginBottom: '4px' }}>
          BODY <span style={{ fontWeight: 400, color: '#94a3b8' }}>— edit as needed, **text** = bold</span>
        </label>
        <textarea value={body} onChange={(e) => setBody(e.target.value)} rows={14}
          style={{ ...fieldStyle, resize: 'vertical', lineHeight: 1.6 }} />
      </div>

      {/* Actions */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', paddingTop: '4px' }}>
        <button onClick={onClose}
          style={{ background: 'none', border: 'none', color: '#94a3b8', fontSize: '13px',
            cursor: 'pointer', textDecoration: 'underline' }}>
          Skip — don't send email
        </button>
        <div style={{ display: 'flex', gap: '8px' }}>
          <Button variant="secondary" onClick={onClose}>Cancel</Button>
          <Button variant="primary"
            disabled={!to || !subject || !body || sendMutation.isPending}
            onClick={() => sendMutation.mutate()}
            style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
            <PaperAirplaneIcon style={{ width: 14, height: 14 }} />
            {sendMutation.isPending ? 'Sending…' : 'Send Authorization Email'}
          </Button>
        </div>
      </div>
    </div>
  );
}

export default function AuthorizationsPage() {
  const { user: adminUser } = useAuth();
  const qc = useQueryClient();
  const [statusTab,   setStatusTab]   = useState('pending');
  const [search,      setSearch]      = useState('');
  const [page,        setPage]        = useState(1);
  const [activeReview, setActiveReview] = useState(null);
  const [reviewAction, setReviewAction] = useState('approved');
  const [reviewNote,   setReviewNote]   = useState('');
  const [emailStep,    setEmailStep]    = useState(null); // { id, request } after approval

  const invalidate = () => {
    qc.invalidateQueries({ queryKey: ['authorizations'] });
    qc.invalidateQueries({ queryKey: ['authStats'] });
  };

  /* ── Stats ── */
  const { data: stats } = useQuery({
    queryKey: ['authStats'],
    queryFn: () => getAuthorizationStats().then((r) => r.data),
    retry: false,
  });

  /* ── List ── */
  const statusParam = statusTab === 'all' ? undefined : statusTab;
  const { data, isLoading } = useQuery({
    queryKey: ['authorizations', { status: statusParam, page }],
    queryFn: () => getAdminAuthorizations({ status: statusParam, page, limit: 20 }).then((r) => r.data),
    retry: false,
    placeholderData: { requests: [], total: 0, pages: 1 },
  });

  /* ── Review mutation ── */
  const reviewMutation = useMutation({
    mutationFn: ({ id, payload }) => reviewAuthorization(id, payload),
    onSuccess: (_, vars) => {
      invalidate();
      if (reviewAction === 'approved') {
        // Transition to email step
        toast.success('Request approved ✓ — compose authorization email below');
        setEmailStep({ id: vars.id, request: activeReview });
      } else {
        toast.success('Request rejected');
      }
      setActiveReview(null);
      setReviewNote('');
    },
    onError: (err) => toast.error(err?.response?.data?.message || 'Failed to review request'),
  });

  /* ── Filtered rows (client-side search) ── */
  const requests = useMemo(() => data?.requests ?? [], [data]);
  const filtered = useMemo(() => {
    const q = search.toLowerCase();
    if (!q) return requests;
    return requests.filter((r) =>
      `${r.first_name} ${r.last_name}`.toLowerCase().includes(q) ||
      (r.member_number ?? '').toLowerCase().includes(q) ||
      (r.provider_name ?? '').toLowerCase().includes(q) ||
      (r.request_type ?? '').toLowerCase().includes(q)
    );
  }, [requests, search]);

  const totalPages = data?.pages ?? 1;

  const isOverdue = (row) =>
    row.status === 'pending' && row.scheduled_date && new Date(row.scheduled_date) < new Date();

  /* ── Table columns ── */
  const columns = [
    {
      key: 'member',
      header: 'Member',
      render: (_, row) => (
        <div>
          <div style={{ fontWeight: 600, fontSize: '14px', color: '#0f172a' }}>
            {row.first_name} {row.last_name}
          </div>
          <div style={{ fontSize: '12px', color: '#94a3b8' }}>#{row.member_number}</div>
        </div>
      ),
    },
    {
      key: 'request_type',
      header: 'Type',
      render: (v) => <TypeBadge type={v} />,
    },
    {
      key: 'linked',
      header: 'Linked To',
      render: (_, row) => (
        <div style={{ fontSize: '13px', color: '#475569' }}>
          {row.medication_name && (
            <div style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
              <BeakerIcon style={{ width: 12, height: 12, color: '#10b981', flexShrink: 0 }} />
              {row.medication_name}
              {row.dosage && <span style={{ color: '#94a3b8' }}> · {row.dosage}</span>}
            </div>
          )}
          {row.treatment_plan_title && (
            <div style={{ display: 'flex', alignItems: 'center', gap: '4px', marginTop: row.medication_name ? '2px' : 0 }}>
              <ClipboardDocumentListIcon style={{ width: 12, height: 12, color: '#f59e0b', flexShrink: 0 }} />
              {row.treatment_plan_title}
            </div>
          )}
          {!row.medication_name && !row.treatment_plan_title && (
            <span style={{ color: '#cbd5e1' }}>—</span>
          )}
        </div>
      ),
    },
    {
      key: 'provider_name',
      header: 'Provider',
      render: (v, row) => (
        <div style={{ fontSize: '13px' }}>
          <div style={{ color: '#334155' }}>{v || '—'}</div>
          {row.provider_type && (
            <div style={{ fontSize: '11px', color: '#94a3b8', textTransform: 'capitalize' }}>
              {row.provider_type}
            </div>
          )}
        </div>
      ),
    },
    {
      key: 'scheduled_date',
      header: 'Scheduled',
      render: (v, row) => v ? (
        <div>
          <div style={{ fontSize: '13px', color: isOverdue(row) ? '#ef4444' : '#334155', fontWeight: isOverdue(row) ? 600 : 400 }}>
            {new Date(v).toLocaleDateString()}
          </div>
          {isOverdue(row) && (
            <div style={{ fontSize: '11px', color: '#ef4444', display: 'flex', alignItems: 'center', gap: '3px' }}>
              <ExclamationTriangleIcon style={{ width: 11, height: 11 }} /> Overdue
            </div>
          )}
        </div>
      ) : <span style={{ color: '#cbd5e1', fontSize: '13px' }}>—</span>,
    },
    {
      key: 'status',
      header: 'Status',
      render: (v) => <Badge status={v} label={v?.charAt(0).toUpperCase() + v?.slice(1)} />,
    },
    {
      key: 'created_at',
      header: 'Submitted',
      render: (v) => v ? (
        <span style={{ fontSize: '12px', color: '#64748b' }}>
          {new Date(v).toLocaleDateString()}
        </span>
      ) : '—',
    },
    {
      key: 'reviewed_by_name',
      header: 'Reviewed By',
      render: (_, row) => row.reviewed_by_name ? (
        <div>
          <div style={{ fontSize: '13px', fontWeight: 600, color: '#334155' }}>
            {row.reviewed_by_name}
          </div>
          <div style={{ fontSize: '11px', color: '#94a3b8' }}>
            {new Date(row.reviewed_at).toLocaleDateString(undefined, { day: 'numeric', month: 'short', year: 'numeric' })}
          </div>
          {row.admin_comments && (
            <div style={{ fontSize: '11px', color: '#64748b', fontStyle: 'italic', marginTop: '2px', maxWidth: 180 }}
              title={row.admin_comments}>
              "{row.admin_comments.length > 50 ? row.admin_comments.slice(0, 50) + '…' : row.admin_comments}"
            </div>
          )}
        </div>
      ) : (
        <span style={{ fontSize: '12px', color: '#cbd5e1', fontStyle: 'italic' }}>Pending review</span>
      ),
    },
    {
      key: 'actions',
      header: '',
      render: (_, row) => {
        if (row.status === 'pending') {
          return (
            <div style={{ display: 'flex', gap: '6px' }}>
              <Button variant="success" style={{ padding: '4px 10px', fontSize: '12px', display: 'flex', alignItems: 'center', gap: '4px' }}
                onClick={() => { setReviewAction('approved'); setReviewNote(row.admin_comments || ''); setActiveReview(row); }}>
                <CheckCircleIcon style={{ width: 13, height: 13 }} /> Approve
              </Button>
              <Button variant="danger" style={{ padding: '4px 10px', fontSize: '12px', display: 'flex', alignItems: 'center', gap: '4px' }}
                onClick={() => { setReviewAction('rejected'); setReviewNote(row.admin_comments || ''); setActiveReview(row); }}>
                <XCircleIcon style={{ width: 13, height: 13 }} /> Reject
              </Button>
            </div>
          );
        }
        if (row.status === 'approved') {
          return (
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
              {/* Email sent indicator */}
              {row.auth_email_sent_at ? (
                <span title={`Email sent ${new Date(row.auth_email_sent_at).toLocaleString()}`}
                  style={{ display: 'flex', alignItems: 'center', gap: '4px', fontSize: '11px', color: '#16a34a' }}>
                  <EnvelopeIcon style={{ width: 13, height: 13 }} /> Sent
                </span>
              ) : (
                <span style={{ fontSize: '11px', color: '#94a3b8', display: 'flex', alignItems: 'center', gap: '3px' }}>
                  <EnvelopeIcon style={{ width: 13, height: 13 }} /> Not sent
                </span>
              )}
              <Button variant="secondary" style={{ padding: '3px 8px', fontSize: '12px', display: 'flex', alignItems: 'center', gap: '4px' }}
                onClick={() => setEmailStep({ id: row.id, request: row })}>
                <PaperAirplaneIcon style={{ width: 12, height: 12 }} />
                {row.auth_email_sent_at ? 'Resend' : 'Send Email'}
              </Button>
            </div>
          );
        }
        return (
          <span style={{ fontSize: '12px', color: '#94a3b8', fontStyle: 'italic' }}>—</span>
        );
      },
    },
  ];

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>

      {/* ── Header ── */}
      <div>
        <h2 style={{ margin: 0, fontSize: '22px', fontWeight: 700, color: '#0f172a' }}>Authorization Requests</h2>
        <p style={{ margin: '4px 0 0', fontSize: '14px', color: '#64748b' }}>
          Review and action member-submitted authorization requests
        </p>
      </div>

      {/* ── Stat cards ── */}
      <div style={{ display: 'flex', gap: '16px', flexWrap: 'wrap' }}>
        <StatCard label="Total Requests"  value={stats?.total}          color="#3b82f6" Icon={ClipboardDocumentListIcon} />
        <StatCard label="Pending"         value={stats?.pending}        color="#f59e0b" Icon={ClockIcon}
          sub={stats?.overdue ? `${stats.overdue} overdue` : undefined} />
        <StatCard label="Approved Today"  value={stats?.approved_today} color="#10b981" Icon={CheckCircleIcon} />
        <StatCard label="Total Approved"  value={stats?.approved}       color="#10b981" Icon={CheckCircleIcon} />
        <StatCard label="Rejected"        value={stats?.rejected}       color="#ef4444" Icon={XCircleIcon} />
      </div>

      {/* ── Filters ── */}
      <div style={{ ...card, padding: '12px 16px' }}>
        <div style={{ display: 'flex', gap: '10px', flexWrap: 'wrap', alignItems: 'center' }}>
          <FunnelIcon style={{ width: 16, height: 16, color: '#94a3b8', flexShrink: 0 }} />

          {/* Search */}
          <div style={{ position: 'relative', flex: 2, minWidth: 200 }}>
            <MagnifyingGlassIcon style={{ width: 14, height: 14, color: '#94a3b8',
              position: 'absolute', left: '10px', top: '50%', transform: 'translateY(-50%)' }} />
            <input
              placeholder="Search member name, number, provider…"
              value={search}
              onChange={(e) => { setSearch(e.target.value); setPage(1); }}
              style={{ width: '100%', padding: '7px 12px 7px 30px', borderRadius: '6px',
                border: '1px solid #e2e8f0', fontSize: '13px', boxSizing: 'border-box', outline: 'none' }}
            />
          </div>

          {/* Status tabs */}
          {STATUS_TABS.map((s) => (
            <button key={s} onClick={() => { setStatusTab(s); setPage(1); }}
              style={{ padding: '6px 14px', borderRadius: '6px', fontSize: '13px', cursor: 'pointer',
                border: statusTab === s ? '1.5px solid #3b82f6' : '1px solid #e2e8f0',
                background: statusTab === s ? '#eff6ff' : '#fff',
                color: statusTab === s ? '#3b82f6' : '#64748b',
                fontWeight: statusTab === s ? 600 : 400, textTransform: 'capitalize' }}>
              {s}{s === 'pending' && stats?.pending ? ` (${stats.pending})` : ''}
            </button>
          ))}

          <span style={{ marginLeft: 'auto', fontSize: '13px', color: '#94a3b8' }}>
            {filtered.length} shown
          </span>
        </div>
      </div>

      {/* ── Table ── */}
      <div style={{ background: '#fff', borderRadius: '12px', boxShadow: '0 1px 4px rgba(0,0,0,0.07)', overflow: 'hidden' }}>
        {isLoading
          ? <div style={{ padding: '60px', display: 'flex', justifyContent: 'center' }}><Spinner /></div>
          : <Table columns={columns} data={filtered} emptyMessage="No authorization requests found." />
        }
      </div>

      {/* ── Pagination ── */}
      {totalPages > 1 && (
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <span style={{ fontSize: '13px', color: '#64748b' }}>Page {page} of {totalPages}</span>
          <div style={{ display: 'flex', gap: '8px' }}>
            <Button variant="secondary" disabled={page <= 1} onClick={() => setPage((p) => Math.max(1, p - 1))}>‹ Prev</Button>
            <Button variant="secondary" disabled={page >= totalPages} onClick={() => setPage((p) => Math.min(totalPages, p + 1))}>Next ›</Button>
          </div>
        </div>
      )}

      {/* ── Review Modal ── */}
      {activeReview && (
        <Modal
          title={`${reviewAction === 'approved' ? '✓ Approve' : '✗ Reject'} Authorization`}
          onClose={() => { setActiveReview(null); setReviewNote(''); }}
          width="500px"
        >
          <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
            {/* Request summary */}
            <div style={{ background: '#f8fafc', borderRadius: '10px', padding: '14px 16px', display: 'grid', gap: '8px', fontSize: '14px' }}>
              <div><strong>Member:</strong> {activeReview.first_name} {activeReview.last_name}
                <span style={{ color: '#94a3b8' }}> · #{activeReview.member_number}</span>
              </div>
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                <strong>Type:</strong> <TypeBadge type={activeReview.request_type} />
              </div>
              <div><strong>Provider:</strong> {activeReview.provider_name || activeReview.provider_type || '—'}</div>
              {activeReview.medication_name && <div><strong>Medication:</strong> {activeReview.medication_name} {activeReview.dosage ? `· ${activeReview.dosage}` : ''}</div>}
              {activeReview.treatment_plan_title && <div><strong>Plan:</strong> {activeReview.treatment_plan_title}</div>}
              {activeReview.scheduled_date && <div><strong>Scheduled:</strong> {new Date(activeReview.scheduled_date).toLocaleDateString()}</div>}
              {activeReview.notes && <div><strong>Member note:</strong> {activeReview.notes}</div>}
            </div>

            {/* Admin review note */}
            <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
              <label style={{ fontSize: '13px', fontWeight: 600, color: '#475569' }}>
                Review note <span style={{ fontWeight: 400, color: '#94a3b8' }}>(sent to member)</span>
              </label>
              <textarea rows={3} value={reviewNote} onChange={(e) => setReviewNote(e.target.value)}
                placeholder={reviewAction === 'approved'
                  ? 'e.g. Approved — please proceed with the prescription.'
                  : 'e.g. Rejected — please contact your doctor for a new referral.'}
                style={{ padding: '10px 12px', borderRadius: '8px', border: '1px solid #e2e8f0',
                  fontSize: '14px', resize: 'vertical', fontFamily: 'inherit' }}
              />
            </div>

            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '8px' }}>
              <Button variant="secondary" onClick={() => { setActiveReview(null); setReviewNote(''); }}>Cancel</Button>
              <Button
                variant={reviewAction === 'approved' ? 'success' : 'danger'}
                disabled={reviewMutation.isPending}
                onClick={() => reviewMutation.mutate({ id: activeReview.id, payload: { action: reviewAction, review_note: reviewNote } })}
              >
                {reviewMutation.isPending ? 'Saving…' : reviewAction === 'approved' ? 'Approve & Notify' : 'Reject & Notify'}
              </Button>
            </div>
          </div>
        </Modal>
      )}

      {/* ── Email Authorization Step ── */}
      {emailStep && (
        <Modal
          title={<span style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
            <EnvelopeIcon style={{ width: 18, height: 18, color: '#3b82f6' }} />
            Send Authorization Letter
          </span>}
          onClose={() => setEmailStep(null)}
          width="620px"
        >
          <EmailStep
            request={emailStep.request}
            approvedId={emailStep.id}
            adminUser={adminUser}
            onClose={() => setEmailStep(null)}
          />
        </Modal>
      )}
    </div>
  );
}

