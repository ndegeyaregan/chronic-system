import { useEffect, useMemo, useRef, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { format, isBefore, startOfDay } from 'date-fns';
import toast from 'react-hot-toast';
import {
  MagnifyingGlassIcon, CheckCircleIcon, ClockIcon, ExclamationTriangleIcon,
  BeakerIcon, DocumentArrowUpIcon, PaperClipIcon, CalendarIcon,
  BellIcon, EnvelopeIcon, DevicePhoneMobileIcon,
} from '@heroicons/react/24/outline';
import { getAdminLabTests, getLabTestStats, scheduleLabTest, adminCompleteLabTest } from '../../api/labTests';
import { getMembers } from '../../api/members';
import Table from '../../components/UI/Table';
import Badge from '../../components/UI/Badge';
import Button from '../../components/UI/Button';
import Modal from '../../components/UI/Modal';
import Spinner from '../../components/UI/Spinner';

/* ── helpers ── */
const card = { background: '#fff', borderRadius: '12px', padding: '18px 20px', boxShadow: '0 1px 4px rgba(0,0,0,0.07)' };

const TEST_TYPES = [
  { value: 'liver_function',   label: 'Liver Function Test (LFT)' },
  { value: 'kidney_function',  label: 'Kidney Function Test (KFT)' },
  { value: 'blood_glucose',    label: 'Blood Glucose' },
  { value: 'hba1c',            label: 'HbA1c' },
  { value: 'lipid_profile',    label: 'Lipid Profile' },
  { value: 'full_blood_count', label: 'Full Blood Count (FBC)' },
  { value: 'urine_analysis',   label: 'Urine Analysis' },
  { value: 'ecg',              label: 'ECG' },
  { value: 'other',            label: 'Other' },
];

const STATUS_TABS = [
  { value: '',          label: 'Active' },
  { value: 'pending',   label: 'Pending' },
  { value: 'overdue',   label: 'Overdue' },
  { value: 'completed', label: 'Completed' },
  { value: 'all',       label: 'All' },
];

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

/* ── Mark Complete Modal ── */
function CompleteModal({ test, onClose, onDone }) {
  const [notes, setNotes] = useState('');
  const [file,  setFile]  = useState(null);
  const fileRef = useRef();

  const mutation = useMutation({
    mutationFn: () => {
      const fd = new FormData();
      fd.append('result_notes', notes);
      if (file) fd.append('result', file);
      return adminCompleteLabTest(test.id, fd);
    },
    onSuccess: () => { toast.success('Lab test marked complete ✓'); onDone(); onClose(); },
    onError: (err) => toast.error(err?.response?.data?.message || 'Failed to complete test'),
  });

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
      <div style={{ background: '#f0fdf4', border: '1px solid #bbf7d0', borderRadius: '8px',
        padding: '10px 14px', fontSize: '13px', color: '#166534' }}>
        <strong>{test.first_name} {test.last_name}</strong> · {test.test_type?.replace(/_/g, ' ')} · Due {test.due_date ? format(new Date(test.due_date), 'dd MMM yyyy') : '—'}
      </div>

      <div>
        <label style={{ fontSize: '12px', fontWeight: 600, color: '#475569', display: 'block', marginBottom: '4px' }}>Result Notes</label>
        <textarea rows={4} value={notes} onChange={(e) => setNotes(e.target.value)}
          placeholder="e.g. All values within normal range. eGFR 85 mL/min/1.73m²"
          style={{ width: '100%', padding: '10px 12px', borderRadius: '8px', border: '1px solid #e2e8f0',
            fontSize: '14px', resize: 'vertical', fontFamily: 'inherit', boxSizing: 'border-box' }} />
      </div>

      <div>
        <label style={{ fontSize: '12px', fontWeight: 600, color: '#475569', display: 'block', marginBottom: '6px' }}>
          Upload Result File <span style={{ fontWeight: 400, color: '#94a3b8' }}>(PDF, JPG, PNG — optional)</span>
        </label>
        <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
          <button onClick={() => fileRef.current?.click()}
            style={{ display: 'flex', alignItems: 'center', gap: '6px', padding: '8px 14px', borderRadius: '8px',
              border: '1px dashed #94a3b8', background: '#f8fafc', fontSize: '13px', cursor: 'pointer', color: '#475569' }}>
            <DocumentArrowUpIcon style={{ width: 16, height: 16 }} />
            {file ? file.name : 'Choose file…'}
          </button>
          {file && <button onClick={() => setFile(null)}
            style={{ background: 'none', border: 'none', color: '#ef4444', fontSize: '12px', cursor: 'pointer' }}>✕ Remove</button>}
        </div>
        <input ref={fileRef} type="file" accept=".pdf,.jpg,.jpeg,.png" style={{ display: 'none' }}
          onChange={(e) => setFile(e.target.files[0] || null)} />
      </div>

      <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '8px', paddingTop: '4px' }}>
        <Button variant="secondary" onClick={onClose}>Cancel</Button>
        <Button variant="success" disabled={mutation.isPending} onClick={() => mutation.mutate()}>
          <CheckCircleIcon style={{ width: 14, height: 14, marginRight: 4 }} />
          {mutation.isPending ? 'Saving…' : 'Mark Complete'}
        </Button>
      </div>
    </div>
  );
}

/* ── Schedule New Test Modal ── */
function ScheduleModal({ onClose, onDone }) {
  const [memberSearch, setMemberSearch] = useState('');
  const [selectedMember, setSelectedMember] = useState(null);
  const [testType, setTestType] = useState('');
  const [dueDate, setDueDate] = useState('');
  const [scheduledDate, setScheduledDate] = useState('');

  const { data: membersData } = useQuery({
    queryKey: ['members-search', memberSearch],
    queryFn: () => getMembers({ search: memberSearch, limit: 8 }).then((r) => r.data?.members ?? r.data ?? []),
    enabled: memberSearch.length > 1,
    placeholderData: [],
  });

  const mutation = useMutation({
    mutationFn: () => scheduleLabTest({
      member_id: selectedMember.id,
      test_type: testType,
      due_date: dueDate,
      scheduled_date: scheduledDate || undefined,
    }),
    onSuccess: () => { toast.success('Lab test scheduled ✓'); onDone(); onClose(); },
    onError: (err) => toast.error(err?.response?.data?.message || 'Failed to schedule test'),
  });

  const fieldStyle = { padding: '8px 12px', borderRadius: '6px', border: '1px solid #e2e8f0',
    fontSize: '13px', width: '100%', boxSizing: 'border-box', fontFamily: 'inherit' };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
      {/* Member picker */}
      <div style={{ position: 'relative' }}>
        <label style={{ fontSize: '12px', fontWeight: 600, color: '#475569', display: 'block', marginBottom: '4px' }}>
          Member <span style={{ color: '#ef4444' }}>*</span>
        </label>
        {selectedMember ? (
          <div style={{ ...fieldStyle, background: '#f0fdf4', color: '#166534', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span>{selectedMember.first_name} {selectedMember.last_name} · #{selectedMember.member_number}</span>
            <button onClick={() => setSelectedMember(null)}
              style={{ background: 'none', border: 'none', color: '#ef4444', cursor: 'pointer', fontSize: '13px' }}>✕</button>
          </div>
        ) : (
          <>
            <input value={memberSearch} onChange={(e) => setMemberSearch(e.target.value)}
              placeholder="Type member name or number…" style={fieldStyle} />
            {membersData?.length > 0 && (
              <div style={{ position: 'absolute', zIndex: 50, top: '100%', left: 0, right: 0,
                background: '#fff', border: '1px solid #e2e8f0', borderRadius: '8px',
                boxShadow: '0 4px 12px rgba(0,0,0,0.1)', maxHeight: 200, overflowY: 'auto', marginTop: 2 }}>
                {membersData.map((m) => (
                  <div key={m.id} onClick={() => { setSelectedMember(m); setMemberSearch(''); }}
                    style={{ padding: '8px 14px', fontSize: '13px', cursor: 'pointer',
                      borderBottom: '1px solid #f1f5f9', color: '#334155' }}
                    onMouseEnter={(e) => e.currentTarget.style.background = '#f8fafc'}
                    onMouseLeave={(e) => e.currentTarget.style.background = 'transparent'}>
                    {m.first_name} {m.last_name} <span style={{ color: '#94a3b8' }}>· #{m.member_number}</span>
                  </div>
                ))}
              </div>
            )}
          </>
        )}
      </div>

      {/* Test type */}
      <div>
        <label style={{ fontSize: '12px', fontWeight: 600, color: '#475569', display: 'block', marginBottom: '4px' }}>
          Test Type <span style={{ color: '#ef4444' }}>*</span>
        </label>
        <select value={testType} onChange={(e) => setTestType(e.target.value)} style={fieldStyle}>
          <option value="">Select test type…</option>
          {TEST_TYPES.map((t) => <option key={t.value} value={t.value}>{t.label}</option>)}
        </select>
      </div>

      {/* Dates */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
        <div>
          <label style={{ fontSize: '12px', fontWeight: 600, color: '#475569', display: 'block', marginBottom: '4px' }}>
            Due Date <span style={{ color: '#ef4444' }}>*</span>
          </label>
          <input type="date" value={dueDate} onChange={(e) => setDueDate(e.target.value)} style={fieldStyle} />
        </div>
        <div>
          <label style={{ fontSize: '12px', fontWeight: 600, color: '#94a3b8', display: 'block', marginBottom: '4px' }}>Scheduled Date (optional)</label>
          <input type="date" value={scheduledDate} onChange={(e) => setScheduledDate(e.target.value)} style={fieldStyle} />
        </div>
      </div>

      <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '8px', paddingTop: '4px' }}>
        <Button variant="secondary" onClick={onClose}>Cancel</Button>
        <Button variant="primary"
          disabled={!selectedMember || !testType || !dueDate || mutation.isPending}
          onClick={() => mutation.mutate()}>
          <CalendarIcon style={{ width: 14, height: 14, marginRight: 4 }} />
          {mutation.isPending ? 'Scheduling…' : 'Schedule Test'}
        </Button>
      </div>
    </div>
  );
}

/* ── Main Page ── */
export default function LabTestsQueuePage() {
  const qc = useQueryClient();
  const [statusTab, setStatusTab] = useState('');
  const [search,    setSearch]    = useState('');
  const [page,      setPage]      = useState(1);
  const [completeTarget, setCompleteTarget] = useState(null);
  const [showSchedule,   setShowSchedule]   = useState(false);

  const statusParam = statusTab === 'all' ? undefined : statusTab || undefined;

  const { data: stats } = useQuery({
    queryKey: ['lab-stats'],
    queryFn: getLabTestStats,
    retry: false,
  });

  const { data, isLoading } = useQuery({
    queryKey: ['admin-lab-tests', { status: statusParam, page, search }],
    queryFn: () => getAdminLabTests({ status: statusParam, page, limit: 20, search: search || undefined }),
    retry: false,
    placeholderData: { tests: [], total: 0, pages: 1 },
  });

  const invalidate = () => {
    qc.invalidateQueries({ queryKey: ['admin-lab-tests'] });
    qc.invalidateQueries({ queryKey: ['lab-stats'] });
  };

  const tests = useMemo(() => data?.tests || [], [data]);
  const totalPages = data?.pages || 1;

  const isOverdue = (row) =>
    row.status !== 'completed' && row.due_date && isBefore(new Date(row.due_date), startOfDay(new Date()));

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
      key: 'test_type',
      header: 'Test Type',
      render: (v) => (
        <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
          <BeakerIcon style={{ width: 14, height: 14, color: '#10b981', flexShrink: 0 }} />
          <span style={{ fontSize: '13px', color: '#334155' }}>
            {TEST_TYPES.find((t) => t.value === v)?.label ?? v?.replace(/_/g, ' ') ?? '—'}
          </span>
        </div>
      ),
    },
    {
      key: 'due_date',
      header: 'Due Date',
      render: (v, row) => v ? (
        <div>
          <div style={{ fontSize: '13px', fontWeight: isOverdue(row) ? 600 : 400,
            color: isOverdue(row) ? '#ef4444' : '#334155' }}>
            {format(new Date(v), 'dd MMM yyyy')}
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
      key: 'scheduled_date',
      header: 'Scheduled',
      render: (v) => v
        ? <span style={{ fontSize: '13px', color: '#475569' }}>{format(new Date(v), 'dd MMM yyyy')}</span>
        : <span style={{ color: '#cbd5e1', fontSize: '13px' }}>—</span>,
    },
    {
      key: 'status',
      header: 'Status',
      render: (_, row) => {
        const eff = isOverdue(row) ? 'overdue' : row.status;
        return <Badge status={eff} label={eff?.charAt(0).toUpperCase() + eff?.slice(1)} />;
      },
    },
    {
      key: 'result',
      header: 'Result',
      render: (_, row) => {
        if (row.status !== 'completed') return <span style={{ color: '#cbd5e1', fontSize: '13px' }}>—</span>;
        return (
          <div style={{ maxWidth: 200 }}>
            {row.result_notes && (
              <div style={{ fontSize: '12px', color: '#475569', fontStyle: 'italic',
                overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}
                title={row.result_notes}>
                "{row.result_notes}"
              </div>
            )}
            {row.result_file_url && (
              <a href={`http://localhost:5000${row.result_file_url}`} target="_blank" rel="noreferrer"
                style={{ fontSize: '12px', color: '#3b82f6', display: 'flex', alignItems: 'center', gap: '4px', marginTop: '2px', textDecoration: 'none' }}>
                <PaperClipIcon style={{ width: 12, height: 12 }} /> View file
              </a>
            )}
            {!row.result_notes && !row.result_file_url && (
              <span style={{ fontSize: '12px', color: '#94a3b8', fontStyle: 'italic' }}>No result uploaded</span>
            )}
          </div>
        );
      },
    },
    {
      key: 'reminders',
      header: 'Reminders',
      render: (_, row) => (
        <div style={{ display: 'flex', gap: '6px', alignItems: 'center' }}>
          <span title={`Push: ${row.reminder_24h_sent ? 'sent' : 'not sent'}`}
            style={{ color: row.reminder_24h_sent ? '#10b981' : '#cbd5e1' }}>
            <BellIcon style={{ width: 14, height: 14 }} />
          </span>
          <span title={`Email: ${row.last_email_reminder_at ? `sent ${format(new Date(row.last_email_reminder_at), 'dd MMM')}` : 'not sent'}`}
            style={{ color: row.last_email_reminder_at ? '#3b82f6' : '#cbd5e1' }}>
            <EnvelopeIcon style={{ width: 14, height: 14 }} />
          </span>
          <span title={`SMS: ${row.last_sms_reminder_at ? `sent ${format(new Date(row.last_sms_reminder_at), 'dd MMM')}` : 'not sent'}`}
            style={{ color: row.last_sms_reminder_at ? '#f59e0b' : '#cbd5e1' }}>
            <DevicePhoneMobileIcon style={{ width: 14, height: 14 }} />
          </span>
        </div>
      ),
    },
    {
      key: 'actions',
      header: '',
      render: (_, row) => row.status !== 'completed' ? (
        <Button variant="success" style={{ padding: '4px 10px', fontSize: '12px', display: 'flex', alignItems: 'center', gap: '4px', whiteSpace: 'nowrap' }}
          onClick={() => setCompleteTarget(row)}>
          <CheckCircleIcon style={{ width: 13, height: 13 }} /> Mark Complete
        </Button>
      ) : (
        <span style={{ fontSize: '11px', color: '#10b981' }}>
          {row.completed_at ? format(new Date(row.completed_at), 'dd MMM yyyy') : '✓'}
        </span>
      ),
    },
  ];

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>

      {/* ── Header ── */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', flexWrap: 'wrap', gap: '12px' }}>
        <div>
          <h2 style={{ margin: 0, fontSize: '22px', fontWeight: 700, color: '#0f172a' }}>Lab Tests Queue</h2>
          <p style={{ margin: '4px 0 0', fontSize: '14px', color: '#64748b' }}>
            Track scheduled tests, upload results, and manage member lab work
          </p>
        </div>
        <Button variant="primary" style={{ display: 'flex', alignItems: 'center', gap: '6px' }}
          onClick={() => setShowSchedule(true)}>
          <CalendarIcon style={{ width: 15, height: 15 }} /> Schedule New Test
        </Button>
      </div>

      {/* ── Stat Cards ── */}
      <div style={{ display: 'flex', gap: '16px', flexWrap: 'wrap' }}>
        <StatCard label="Total Tests"  value={stats?.total}     color="#3b82f6" Icon={BeakerIcon} />
        <StatCard label="Pending"      value={stats?.pending}   color="#f59e0b" Icon={ClockIcon} />
        <StatCard label="Overdue"      value={stats?.overdue}   color="#ef4444" Icon={ExclamationTriangleIcon}
          sub={stats?.overdue > 0 ? 'Need immediate attention' : undefined} />
        <StatCard label="Completed"    value={stats?.completed} color="#10b981" Icon={CheckCircleIcon} />
      </div>

      {/* ── Filters ── */}
      <div style={{ ...card, padding: '12px 16px' }}>
        <div style={{ display: 'flex', gap: '10px', flexWrap: 'wrap', alignItems: 'center' }}>
          {/* Search */}
          <div style={{ position: 'relative', flex: 2, minWidth: 220 }}>
            <MagnifyingGlassIcon style={{ width: 14, height: 14, color: '#94a3b8',
              position: 'absolute', left: '10px', top: '50%', transform: 'translateY(-50%)' }} />
            <input placeholder="Search member name, number, test type…"
              value={search}
              onChange={(e) => { setSearch(e.target.value); setPage(1); }}
              style={{ width: '100%', padding: '7px 12px 7px 30px', borderRadius: '6px',
                border: '1px solid #e2e8f0', fontSize: '13px', boxSizing: 'border-box', outline: 'none' }} />
          </div>

          {/* Status tabs */}
          {STATUS_TABS.map((s) => (
            <button key={s.value} onClick={() => { setStatusTab(s.value); setPage(1); }}
              style={{ padding: '6px 14px', borderRadius: '6px', fontSize: '13px', cursor: 'pointer',
                border: statusTab === s.value ? '1.5px solid #3b82f6' : '1px solid #e2e8f0',
                background: statusTab === s.value ? '#eff6ff' : '#fff',
                color: statusTab === s.value ? '#3b82f6' : '#64748b',
                fontWeight: statusTab === s.value ? 600 : 400 }}>
              {s.label}
              {s.value === '' && stats?.pending ? ` (${stats.pending})` : ''}
              {s.value === 'overdue' && stats?.overdue ? ` (${stats.overdue})` : ''}
            </button>
          ))}

          <span style={{ marginLeft: 'auto', fontSize: '13px', color: '#94a3b8' }}>
            {data?.total ?? 0} shown
          </span>
        </div>
      </div>

      {/* ── Table ── */}
      <div style={{ background: '#fff', borderRadius: '12px', boxShadow: '0 1px 4px rgba(0,0,0,0.07)', overflow: 'hidden' }}>
        {isLoading
          ? <div style={{ padding: '60px', display: 'flex', justifyContent: 'center' }}><Spinner /></div>
          : <Table columns={columns} data={tests} emptyMessage="No lab tests found." />
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

      {/* ── Mark Complete Modal ── */}
      {completeTarget && (
        <Modal title="Mark Lab Test Complete" onClose={() => setCompleteTarget(null)} width="500px">
          <CompleteModal test={completeTarget} onClose={() => setCompleteTarget(null)} onDone={invalidate} />
        </Modal>
      )}

      {/* ── Schedule New Test Modal ── */}
      {showSchedule && (
        <Modal title="Schedule New Lab Test" onClose={() => setShowSchedule(false)} width="500px">
          <ScheduleModal onClose={() => setShowSchedule(false)} onDone={invalidate} />
        </Modal>
      )}
    </div>
  );
}
