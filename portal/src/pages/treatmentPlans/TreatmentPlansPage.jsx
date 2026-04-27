import { useState, useRef } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import toast from 'react-hot-toast';
import {
  PlusIcon,
  PencilIcon,
  DocumentIcon,
  PhotoIcon,
  MusicalNoteIcon,
  VideoCameraIcon,
  ClipboardDocumentCheckIcon,
  CheckCircleIcon,
  XCircleIcon,
  ChevronLeftIcon,
  ChevronRightIcon,
} from '@heroicons/react/24/outline';
import { getAllTreatmentPlans, adminCreateTreatmentPlan, adminUpdateTreatmentPlan } from '../../api/treatmentPlans';
import { getConditions } from '../../api/conditions';
import Table from '../../components/UI/Table';
import Modal from '../../components/UI/Modal';
import Badge from '../../components/UI/Badge';
import Button from '../../components/UI/Button';
import Spinner from '../../components/UI/Spinner';

const PER_PAGE = 20;

const fmtDate = (d) =>
  d ? new Date(d).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' }) : '—';

const fmtCost = (amount, currency) => {
  if (amount == null) return '—';
  const c = currency || 'KES';
  return `${c} ${Number(amount).toLocaleString()}`;
};

export default function TreatmentPlansPage() {
  const qc = useQueryClient();
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('');
  const [conditionFilter, setConditionFilter] = useState('');
  const [modalOpen, setModalOpen] = useState(false);

  // Form state
  const [form, setForm] = useState({
    member_id: '', title: '', description: '', provider_name: '',
    plan_date: '', cost: '', currency: 'KES', condition_id: '',
  });
  const [editingPlan, setEditingPlan] = useState(null);
  const [editModalOpen, setEditModalOpen] = useState(false);
  const [editForm, setEditForm] = useState({
    title: '', description: '', provider_name: '',
    plan_date: '', cost: '', currency: 'KES', condition_id: '', status: '',
  });
  const docRef = useRef(null);
  const photoRef = useRef(null);
  const audioRef = useRef(null);
  const videoRef = useRef(null);
  const editDocRef = useRef(null);
  const editPhotoRef = useRef(null);
  const editAudioRef = useRef(null);
  const editVideoRef = useRef(null);

  const params = {
    page, limit: PER_PAGE,
    ...(search && { search }),
    ...(statusFilter && { status: statusFilter }),
    ...(conditionFilter && { condition_id: conditionFilter }),
  };

  const { data, isLoading } = useQuery({
    queryKey: ['treatment-plans', params],
    queryFn: () => getAllTreatmentPlans(params),
    placeholderData: (prev) => prev,
  });

  const { data: conditionsData } = useQuery({
    queryKey: ['conditions'],
    queryFn: getConditions,
  });
  const conditions = conditionsData?.data || conditionsData || [];

  const plans = Array.isArray(data) ? data : (data?.plans || data?.data || []);
  const totalPlans = data?.total || plans.length;
  const pages = data?.pages || Math.ceil(totalPlans / PER_PAGE) || 1;

  // Stats
  const activePlans = plans.filter((p) => p.status === 'active').length;
  const completedPlans = plans.filter((p) => p.status === 'completed').length;
  const cancelledPlans = plans.filter((p) => p.status === 'cancelled').length;

  const createMut = useMutation({
    mutationFn: (formData) => adminCreateTreatmentPlan(formData),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['treatment-plans'] });
      toast.success('Treatment plan created');
      closeModal();
    },
    onError: () => toast.error('Failed to create treatment plan'),
  });

  const editMut = useMutation({
    mutationFn: ({ id, formData }) => adminUpdateTreatmentPlan(id, formData),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['treatment-plans'] });
      toast.success('Treatment plan updated');
      closeEditModal();
    },
    onError: () => toast.error('Failed to update treatment plan'),
  });

  const closeModal = () => {
    setModalOpen(false);
    setForm({ member_id: '', title: '', description: '', provider_name: '', plan_date: '', cost: '', currency: 'KES', condition_id: '' });
  };

  const closeEditModal = () => {
    setEditModalOpen(false);
    setEditingPlan(null);
    setEditForm({ title: '', description: '', provider_name: '', plan_date: '', cost: '', currency: 'KES', condition_id: '', status: '' });
  };

  const openEditModal = (plan) => {
    setEditingPlan(plan);
    setEditForm({
      title: plan.title || '',
      description: plan.description || '',
      provider_name: plan.provider_name || '',
      plan_date: plan.plan_date ? new Date(plan.plan_date).toISOString().split('T')[0] : '',
      cost: plan.cost || '',
      currency: plan.currency || 'KES',
      condition_id: plan.condition_id || '',
      status: plan.status || 'active',
    });
    setEditModalOpen(true);
  };

  const handleCreate = (e) => {
    e.preventDefault();
    const fd = new FormData();
    fd.append('member_id', form.member_id);
    fd.append('title', form.title);
    if (form.description) fd.append('description', form.description);
    if (form.provider_name) fd.append('provider_name', form.provider_name);
    if (form.plan_date) fd.append('plan_date', form.plan_date);
    if (form.cost) fd.append('cost', form.cost);
    if (form.currency) fd.append('currency', form.currency);
    if (form.condition_id) fd.append('condition_id', form.condition_id);
    if (docRef.current?.files[0]) fd.append('document', docRef.current.files[0]);
    if (photoRef.current?.files[0]) fd.append('photo', photoRef.current.files[0]);
    if (audioRef.current?.files[0]) fd.append('audio', audioRef.current.files[0]);
    if (videoRef.current?.files[0]) fd.append('video', videoRef.current.files[0]);
    createMut.mutate(fd);
  };

  const handleEdit = (e) => {
    e.preventDefault();
    const fd = new FormData();
    fd.append('title', editForm.title);
    if (editForm.description) fd.append('description', editForm.description);
    if (editForm.provider_name) fd.append('provider_name', editForm.provider_name);
    if (editForm.plan_date) fd.append('plan_date', editForm.plan_date);
    if (editForm.cost) fd.append('cost', editForm.cost);
    if (editForm.currency) fd.append('currency', editForm.currency);
    if (editForm.condition_id) fd.append('condition_id', editForm.condition_id);
    if (editForm.status) fd.append('status', editForm.status);
    if (editDocRef.current?.files[0]) fd.append('document', editDocRef.current.files[0]);
    if (editPhotoRef.current?.files[0]) fd.append('photo', editPhotoRef.current.files[0]);
    if (editAudioRef.current?.files[0]) fd.append('audio', editAudioRef.current.files[0]);
    if (editVideoRef.current?.files[0]) fd.append('video', editVideoRef.current.files[0]);
    editMut.mutate({ id: editingPlan.id, formData: fd });
  };

  const inputStyle = {
    padding: '8px 12px', borderRadius: '6px', border: '1px solid #e2e8f0',
    fontSize: '14px', color: 'var(--text)', background: '#fff', outline: 'none',
    width: '100%', boxSizing: 'border-box',
  };

  const attachmentIcons = (row) => {
    const items = [
      { url: row.document_url, Icon: DocumentIcon, label: 'Doc' },
      { url: row.photo_url, Icon: PhotoIcon, label: 'Photo' },
      { url: row.audio_url, Icon: MusicalNoteIcon, label: 'Audio' },
      { url: row.video_url, Icon: VideoCameraIcon, label: 'Video' },
    ];
    const present = items.filter((i) => i.url);
    if (present.length === 0) return <span style={{ color: '#94a3b8' }}>—</span>;
    return (
      <div style={{ display: 'flex', gap: '6px' }}>
        {present.map((item) => (
          <a key={item.label} href={item.url} target="_blank" rel="noreferrer"
            title={item.label}
            style={{
              width: 26, height: 26, borderRadius: '6px', background: '#f1f5f9',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              color: '#3b82f6', textDecoration: 'none',
            }}>
            <item.Icon style={{ width: 14, height: 14 }} />
          </a>
        ))}
      </div>
    );
  };

  const columns = [
    {
      key: 'member',
      header: 'Member',
      render: (_, row) => (
        <div>
          <div style={{ fontWeight: 500 }}>{row.first_name} {row.last_name}</div>
          <div style={{ fontSize: '11px', color: '#94a3b8' }}>{row.member_number || '—'}</div>
        </div>
      ),
    },
    {
      key: 'condition_name',
      header: 'Condition',
      render: (val) => <span>{val || '—'}</span>,
    },
    { key: 'title', header: 'Title' },
    { key: 'provider_name', header: 'Provider', render: (val) => val || '—' },
    {
      key: 'plan_date',
      header: 'Plan Date',
      render: (val) => <span style={{ whiteSpace: 'nowrap' }}>{fmtDate(val)}</span>,
    },
    {
      key: 'cost',
      header: 'Cost',
      render: (val, row) => <span style={{ whiteSpace: 'nowrap' }}>{fmtCost(val, row.currency)}</span>,
    },
    {
      key: 'status',
      header: 'Status',
      render: (val) => <Badge status={val} />,
    },
    {
      key: 'attachments',
      header: 'Attachments',
      render: (_, row) => attachmentIcons(row),
    },
    {
      key: 'created_at',
      header: 'Created',
      render: (val) => <span style={{ whiteSpace: 'nowrap', fontSize: '13px' }}>{fmtDate(val)}</span>,
    },
    {
      key: 'actions',
      header: 'Actions',
      render: (_, row) => (
        <Button variant="ghost" onClick={() => openEditModal(row)} style={{ padding: '4px 8px', fontSize: '12px' }}>
          <PencilIcon style={{ width: 13, height: 13 }} /> Edit
        </Button>
      ),
    },
  ];

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
      {/* Header */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '10px' }}>
        <div>
          <h1 style={{ fontSize: '22px', fontWeight: 700, color: '#0f172a', margin: 0 }}>
            Treatment Plans
          </h1>
          <p style={{ margin: '4px 0 0', fontSize: '14px', color: '#64748b' }}>
            Manage treatment plans across all members
          </p>
        </div>
        <Button onClick={() => setModalOpen(true)}>
          <PlusIcon style={{ width: 16, height: 16 }} /> New Treatment Plan
        </Button>
      </div>

      {/* Stat Cards */}
      <div style={{ display: 'flex', gap: '14px', flexWrap: 'wrap' }}>
        {[
          { label: 'Total Plans', value: totalPlans, color: '#3b82f6', Icon: ClipboardDocumentCheckIcon },
          { label: 'Active Plans', value: activePlans, color: '#10b981', Icon: CheckCircleIcon },
          { label: 'Completed', value: completedPlans, color: '#0ea5e9', Icon: CheckCircleIcon },
          { label: 'Cancelled', value: cancelledPlans, color: '#ef4444', Icon: XCircleIcon },
        ].map((s) => (
          <div key={s.label} style={{
            background: '#fff', borderRadius: '12px', border: '1px solid #e2e8f0',
            padding: '16px 20px', flex: 1, minWidth: 140,
            borderTop: `3px solid ${s.color}`,
          }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '6px' }}>
              <s.Icon style={{ width: 16, height: 16, color: s.color }} />
              <span style={{ fontSize: '12px', color: '#94a3b8', fontWeight: 500 }}>{s.label}</span>
            </div>
            <div style={{ fontSize: '28px', fontWeight: 800, color: '#0f172a', lineHeight: 1 }}>
              {s.value ?? '—'}
            </div>
          </div>
        ))}
      </div>

      {/* Filter Bar */}
      <div style={{
        background: '#fff', borderRadius: '12px', padding: '16px 20px',
        boxShadow: '0 1px 4px rgba(0,0,0,0.07)', border: '1px solid #e2e8f0',
        display: 'flex', gap: '12px', flexWrap: 'wrap', alignItems: 'flex-end',
      }}>
        <div style={{ display: 'flex', flexDirection: 'column', gap: '4px', flex: '1 1 200px' }}>
          <label style={{ fontSize: '13px', fontWeight: 500, color: '#475569' }}>Search</label>
          <input type="text" placeholder="Member name or number…"
            value={search} onChange={(e) => { setSearch(e.target.value); setPage(1); }}
            style={inputStyle} />
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: '4px', flex: '1 1 150px' }}>
          <label style={{ fontSize: '13px', fontWeight: 500, color: '#475569' }}>Status</label>
          <select value={statusFilter}
            onChange={(e) => { setStatusFilter(e.target.value); setPage(1); }}
            style={{ ...inputStyle, cursor: 'pointer' }}>
            <option value="">All Statuses</option>
            <option value="active">Active</option>
            <option value="completed">Completed</option>
            <option value="cancelled">Cancelled</option>
          </select>
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: '4px', flex: '1 1 150px' }}>
          <label style={{ fontSize: '13px', fontWeight: 500, color: '#475569' }}>Condition</label>
          <select value={conditionFilter}
            onChange={(e) => { setConditionFilter(e.target.value); setPage(1); }}
            style={{ ...inputStyle, cursor: 'pointer' }}>
            <option value="">All Conditions</option>
            {(Array.isArray(conditions) ? conditions : []).map((c) => (
              <option key={c.id} value={c.id}>{c.name}</option>
            ))}
          </select>
        </div>
      </div>

      {/* Table */}
      <div style={{
        background: '#fff', borderRadius: '12px',
        boxShadow: '0 1px 4px rgba(0,0,0,0.07)', border: '1px solid #e2e8f0',
        overflow: 'hidden',
      }}>
        {isLoading ? (
          <Spinner />
        ) : (
          <>
            <Table columns={columns} data={plans} emptyMessage="No treatment plans found." />

            {pages > 1 && (
              <div style={{
                display: 'flex', alignItems: 'center', justifyContent: 'space-between',
                padding: '12px 20px', borderTop: '1px solid #f1f5f9',
              }}>
                <span style={{ fontSize: '13px', color: '#64748b' }}>
                  Page {page} of {pages} · {totalPlans} total
                </span>
                <div style={{ display: 'flex', gap: '6px' }}>
                  <Button variant="secondary" onClick={() => setPage((p) => Math.max(1, p - 1))}
                    disabled={page <= 1} style={{ padding: '6px 10px' }}>
                    <ChevronLeftIcon style={{ width: 16, height: 16 }} />
                  </Button>
                  <Button variant="secondary" onClick={() => setPage((p) => Math.min(pages, p + 1))}
                    disabled={page >= pages} style={{ padding: '6px 10px' }}>
                    <ChevronRightIcon style={{ width: 16, height: 16 }} />
                  </Button>
                </div>
              </div>
            )}
          </>
        )}
      </div>

      {/* Create Modal */}
      {modalOpen && (
        <Modal title="New Treatment Plan" onClose={closeModal} width="620px">
          <form onSubmit={handleCreate} style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '4px' }}>
              <label style={{ fontSize: '13px', fontWeight: 500, color: '#475569' }}>Member ID</label>
              <input type="text" placeholder="Member UUID" required
                value={form.member_id} onChange={(e) => setForm({ ...form, member_id: e.target.value })}
                style={inputStyle} />
              <span style={{ fontSize: '11px', color: '#94a3b8' }}>Enter the member&apos;s UUID</span>
            </div>

            <div style={{ display: 'flex', gap: '12px' }}>
              <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: '4px' }}>
                <label style={{ fontSize: '13px', fontWeight: 500, color: '#475569' }}>Title *</label>
                <input type="text" required value={form.title}
                  onChange={(e) => setForm({ ...form, title: e.target.value })}
                  style={inputStyle} />
              </div>
              <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: '4px' }}>
                <label style={{ fontSize: '13px', fontWeight: 500, color: '#475569' }}>Provider Name</label>
                <input type="text" value={form.provider_name}
                  onChange={(e) => setForm({ ...form, provider_name: e.target.value })}
                  style={inputStyle} />
              </div>
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '4px' }}>
              <label style={{ fontSize: '13px', fontWeight: 500, color: '#475569' }}>Description</label>
              <textarea value={form.description}
                onChange={(e) => setForm({ ...form, description: e.target.value })}
                rows={3}
                style={{ ...inputStyle, resize: 'vertical', fontFamily: 'inherit' }} />
            </div>

            <div style={{ display: 'flex', gap: '12px' }}>
              <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: '4px' }}>
                <label style={{ fontSize: '13px', fontWeight: 500, color: '#475569' }}>Plan Date</label>
                <input type="date" value={form.plan_date}
                  onChange={(e) => setForm({ ...form, plan_date: e.target.value })}
                  style={inputStyle} />
              </div>
              <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: '4px' }}>
                <label style={{ fontSize: '13px', fontWeight: 500, color: '#475569' }}>Condition</label>
                <select value={form.condition_id}
                  onChange={(e) => setForm({ ...form, condition_id: e.target.value })}
                  style={{ ...inputStyle, cursor: 'pointer' }}>
                  <option value="">— Select —</option>
                  {(Array.isArray(conditions) ? conditions : []).map((c) => (
                    <option key={c.id} value={c.id}>{c.name}</option>
                  ))}
                </select>
              </div>
            </div>

            <div style={{ display: 'flex', gap: '12px' }}>
              <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: '4px' }}>
                <label style={{ fontSize: '13px', fontWeight: 500, color: '#475569' }}>Cost</label>
                <input type="number" step="0.01" value={form.cost}
                  onChange={(e) => setForm({ ...form, cost: e.target.value })}
                  placeholder="0.00" style={inputStyle} />
              </div>
              <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: '4px' }}>
                <label style={{ fontSize: '13px', fontWeight: 500, color: '#475569' }}>Currency</label>
                <select value={form.currency}
                  onChange={(e) => setForm({ ...form, currency: e.target.value })}
                  style={{ ...inputStyle, cursor: 'pointer' }}>
                  <option value="KES">KES</option>
                  <option value="USD">USD</option>
                  <option value="EUR">EUR</option>
                  <option value="GBP">GBP</option>
                </select>
              </div>
            </div>

            {/* File uploads */}
            <div style={{ display: 'flex', gap: '12px', flexWrap: 'wrap' }}>
              {[
                { label: 'Document', ref: docRef, accept: '.pdf,.doc,.docx' },
                { label: 'Photo', ref: photoRef, accept: 'image/*' },
                { label: 'Audio', ref: audioRef, accept: 'audio/*' },
                { label: 'Video', ref: videoRef, accept: 'video/*' },
              ].map((f) => (
                <div key={f.label} style={{ flex: '1 1 120px', display: 'flex', flexDirection: 'column', gap: '4px' }}>
                  <label style={{ fontSize: '13px', fontWeight: 500, color: '#475569' }}>{f.label}</label>
                  <input type="file" ref={f.ref} accept={f.accept}
                    style={{ fontSize: '12px', color: '#64748b' }} />
                </div>
              ))}
            </div>

            <div style={{ display: 'flex', gap: '10px', justifyContent: 'flex-end', marginTop: '4px' }}>
              <Button variant="secondary" onClick={closeModal} disabled={createMut.isPending}>Cancel</Button>
              <Button type="submit" disabled={createMut.isPending}>
                {createMut.isPending ? 'Creating…' : 'Create Plan'}
              </Button>
            </div>
          </form>
        </Modal>
      )}
      {/* Edit Modal */}
      {editModalOpen && editingPlan && (
        <Modal title="Edit Treatment Plan" onClose={closeEditModal} width="620px">
          <form onSubmit={handleEdit} style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
            <div style={{ background: '#f8fafc', borderRadius: '8px', padding: '10px 14px', fontSize: '13px', color: '#475569' }}>
              <strong>Member:</strong> {editingPlan.first_name} {editingPlan.last_name} ({editingPlan.member_number || '—'})
            </div>

            <div style={{ display: 'flex', gap: '12px' }}>
              <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: '4px' }}>
                <label style={{ fontSize: '13px', fontWeight: 500, color: '#475569' }}>Title *</label>
                <input type="text" required value={editForm.title}
                  onChange={(e) => setEditForm({ ...editForm, title: e.target.value })}
                  style={inputStyle} />
              </div>
              <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: '4px' }}>
                <label style={{ fontSize: '13px', fontWeight: 500, color: '#475569' }}>Provider Name</label>
                <input type="text" value={editForm.provider_name}
                  onChange={(e) => setEditForm({ ...editForm, provider_name: e.target.value })}
                  style={inputStyle} />
              </div>
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '4px' }}>
              <label style={{ fontSize: '13px', fontWeight: 500, color: '#475569' }}>Description</label>
              <textarea value={editForm.description}
                onChange={(e) => setEditForm({ ...editForm, description: e.target.value })}
                rows={3}
                style={{ ...inputStyle, resize: 'vertical', fontFamily: 'inherit' }} />
            </div>

            <div style={{ display: 'flex', gap: '12px' }}>
              <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: '4px' }}>
                <label style={{ fontSize: '13px', fontWeight: 500, color: '#475569' }}>Plan Date</label>
                <input type="date" value={editForm.plan_date}
                  onChange={(e) => setEditForm({ ...editForm, plan_date: e.target.value })}
                  style={inputStyle} />
              </div>
              <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: '4px' }}>
                <label style={{ fontSize: '13px', fontWeight: 500, color: '#475569' }}>Status</label>
                <select value={editForm.status}
                  onChange={(e) => setEditForm({ ...editForm, status: e.target.value })}
                  style={{ ...inputStyle, cursor: 'pointer' }}>
                  <option value="active">Active</option>
                  <option value="completed">Completed</option>
                  <option value="cancelled">Cancelled</option>
                </select>
              </div>
            </div>

            <div style={{ display: 'flex', gap: '12px' }}>
              <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: '4px' }}>
                <label style={{ fontSize: '13px', fontWeight: 500, color: '#475569' }}>Condition</label>
                <select value={editForm.condition_id}
                  onChange={(e) => setEditForm({ ...editForm, condition_id: e.target.value })}
                  style={{ ...inputStyle, cursor: 'pointer' }}>
                  <option value="">— Select —</option>
                  {(Array.isArray(conditions) ? conditions : []).map((c) => (
                    <option key={c.id} value={c.id}>{c.name}</option>
                  ))}
                </select>
              </div>
              <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: '4px' }}>
                <label style={{ fontSize: '13px', fontWeight: 500, color: '#475569' }}>Currency</label>
                <select value={editForm.currency}
                  onChange={(e) => setEditForm({ ...editForm, currency: e.target.value })}
                  style={{ ...inputStyle, cursor: 'pointer' }}>
                  <option value="KES">KES</option>
                  <option value="USD">USD</option>
                  <option value="EUR">EUR</option>
                  <option value="GBP">GBP</option>
                </select>
              </div>
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '4px' }}>
              <label style={{ fontSize: '13px', fontWeight: 500, color: '#475569' }}>Cost</label>
              <input type="number" step="0.01" value={editForm.cost}
                onChange={(e) => setEditForm({ ...editForm, cost: e.target.value })}
                placeholder="0.00" style={inputStyle} />
            </div>

            {/* Replace file uploads */}
            <div style={{ display: 'flex', gap: '12px', flexWrap: 'wrap' }}>
              {[
                { label: 'Document', ref: editDocRef, accept: '.pdf,.doc,.docx' },
                { label: 'Photo', ref: editPhotoRef, accept: 'image/*' },
                { label: 'Audio', ref: editAudioRef, accept: 'audio/*' },
                { label: 'Video', ref: editVideoRef, accept: 'video/*' },
              ].map((f) => (
                <div key={f.label} style={{ flex: '1 1 120px', display: 'flex', flexDirection: 'column', gap: '4px' }}>
                  <label style={{ fontSize: '13px', fontWeight: 500, color: '#475569' }}>{f.label}</label>
                  <input type="file" ref={f.ref} accept={f.accept}
                    style={{ fontSize: '12px', color: '#64748b' }} />
                  <span style={{ fontSize: '11px', color: '#94a3b8' }}>Leave empty to keep current</span>
                </div>
              ))}
            </div>

            <div style={{ display: 'flex', gap: '10px', justifyContent: 'flex-end', marginTop: '4px' }}>
              <Button variant="secondary" onClick={closeEditModal} disabled={editMut.isPending}>Cancel</Button>
              <Button type="submit" disabled={editMut.isPending}>
                {editMut.isPending ? 'Saving…' : 'Save Changes'}
              </Button>
            </div>
          </form>
        </Modal>
      )}
    </div>
  );
}
