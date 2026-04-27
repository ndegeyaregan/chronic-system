import { useMemo, useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { useForm } from 'react-hook-form';
import { useNavigate } from 'react-router-dom';
import toast from 'react-hot-toast';
import {
  PlusIcon, ArrowPathIcon, CheckCircleIcon, XCircleIcon,
  PencilIcon, TrashIcon, UsersIcon, BeakerIcon,
  MagnifyingGlassIcon, FunnelIcon, EyeIcon, XMarkIcon,
  ClipboardDocumentListIcon, DocumentTextIcon,
} from '@heroicons/react/24/outline';
import { getConditions, getConditionDetail, syncConditions, createCondition, updateCondition, deleteCondition, toggleCondition } from '../../api/conditions';
import Table from '../../components/UI/Table';
import Badge from '../../components/UI/Badge';
import Button from '../../components/UI/Button';
import Modal from '../../components/UI/Modal';
import Spinner from '../../components/UI/Spinner';
import Input from '../../components/UI/Input';

/* ── helpers ── */
const card = {
  background: '#fff', borderRadius: '12px',
  padding: '18px 20px', boxShadow: '0 1px 4px rgba(0,0,0,0.07)',
};

function StatCard({ label, value, color = '#3b82f6', Icon, sub }) {
  return (
    <div style={{ ...card, display: 'flex', alignItems: 'center', gap: '16px', flex: 1, minWidth: 150 }}>
      <div style={{ width: 44, height: 44, borderRadius: '10px', background: color + '1a',
        display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
        {Icon && <Icon style={{ width: 22, height: 22, color }} />}
      </div>
      <div>
        <div style={{ fontSize: '24px', fontWeight: 700, color: '#0f172a', lineHeight: 1.1 }}>{value}</div>
        <div style={{ fontSize: '13px', color: '#64748b', marginTop: '2px' }}>{label}</div>
        {sub && <div style={{ fontSize: '11px', color, marginTop: '2px' }}>{sub}</div>}
      </div>
    </div>
  );
}

/* ── ConditionDrawer ── */
function ConditionDrawer({ conditionId, onClose, navigate }) {
  const [tab, setTab] = useState('overview'); // overview | medications | plans | members

  const { data, isLoading, isError } = useQuery({
    queryKey: ['conditionDetail', conditionId],
    queryFn: () => getConditionDetail(conditionId).then((r) => r.data),
    enabled: !!conditionId,
    retry: false,
  });

  const cond = data?.condition;
  const medications = data?.medications ?? [];
  const treatmentPlans = data?.treatment_plans ?? { by_status: [], recent: [] };
  const members = data?.members ?? [];

  const tabStyle = (t) => ({
    padding: '8px 16px', fontSize: '13px', fontWeight: tab === t ? 600 : 400,
    cursor: 'pointer', border: 'none', background: 'none',
    borderBottom: tab === t ? '2px solid #3b82f6' : '2px solid transparent',
    color: tab === t ? '#3b82f6' : '#64748b',
  });

  return (
    <>
      {/* Backdrop */}
      <div onClick={onClose} style={{
        position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.25)', zIndex: 200,
      }} />
      {/* Panel */}
      <div style={{
        position: 'fixed', top: 0, right: 0, bottom: 0, width: '520px', maxWidth: '95vw',
        background: '#fff', boxShadow: '-4px 0 24px rgba(0,0,0,0.12)', zIndex: 201,
        display: 'flex', flexDirection: 'column', overflowY: 'auto',
      }}>
        {/* Header */}
        <div style={{ padding: '20px 24px 0', borderBottom: '1px solid #f1f5f9' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
            <div style={{ flex: 1, paddingRight: '12px' }}>
              {isLoading ? (
                <div style={{ height: '24px', background: '#f1f5f9', borderRadius: '4px', width: '60%' }} />
              ) : (
                <>
                  <h3 style={{ margin: 0, fontSize: '18px', fontWeight: 700, color: '#0f172a' }}>
                    {cond?.name ?? '—'}
                  </h3>
                  <div style={{ display: 'flex', gap: '8px', alignItems: 'center', marginTop: '6px' }}>
                    <Badge status={cond?.is_active ? 'active' : 'inactive'}
                      label={cond?.is_active ? 'Active' : 'Inactive'} />
                    {cond?.description && cond.description.match(/^\[([A-Z]\d+)\]/) && (
                      <span style={{ fontSize: '12px', background: '#eff6ff', color: '#3b82f6',
                        borderRadius: '4px', padding: '2px 7px', fontWeight: 600 }}>
                        ICD: {cond.description.match(/^\[([A-Z]\d+)\]/)[1]}
                      </span>
                    )}
                  </div>
                </>
              )}
            </div>
            <button onClick={onClose} style={{ background: 'none', border: 'none', cursor: 'pointer',
              color: '#94a3b8', padding: '2px' }}>
              <XMarkIcon style={{ width: 20, height: 20 }} />
            </button>
          </div>

          {/* Tabs */}
          <div style={{ display: 'flex', marginTop: '16px', gap: '0' }}>
            {[
              { id: 'overview',    label: 'Overview' },
              { id: 'medications', label: `Medications${medications.length ? ` (${medications.length})` : ''}` },
              { id: 'plans',       label: `Treatment Plans${treatmentPlans.recent.length ? ` (${treatmentPlans.recent.length})` : ''}` },
              { id: 'members',     label: `Members${members.length ? ` (${members.length})` : ''}` },
            ].map((t) => (
              <button key={t.id} onClick={() => setTab(t.id)} style={tabStyle(t.id)}>
                {t.label}
              </button>
            ))}
          </div>
        </div>

        {/* Body */}
        <div style={{ padding: '20px 24px', flex: 1 }}>
          {isLoading && <div style={{ display: 'flex', justifyContent: 'center', padding: '40px' }}><Spinner /></div>}
          {isError && <p style={{ color: '#ef4444', textAlign: 'center' }}>Failed to load details</p>}

          {!isLoading && !isError && (
            <>
              {/* ── Overview ── */}
              {tab === 'overview' && (
                <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
                  {/* Mini stats */}
                  <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: '12px' }}>
                    {[
                      { label: 'Members',        value: cond?.member_count ?? 0,         color: '#0ea5e9', Icon: UsersIcon },
                      { label: 'Medications',     value: cond?.medication_count ?? 0,     color: '#10b981', Icon: BeakerIcon },
                      { label: 'Treatment Plans', value: cond?.treatment_plan_count ?? 0, color: '#f59e0b', Icon: ClipboardDocumentListIcon },
                    ].map((s) => (
                      <div key={s.label} style={{ background: '#f8fafc', borderRadius: '10px', padding: '14px',
                        display: 'flex', flexDirection: 'column', gap: '6px' }}>
                        <s.Icon style={{ width: 18, height: 18, color: s.color }} />
                        <div style={{ fontSize: '22px', fontWeight: 700, color: '#0f172a' }}>{s.value}</div>
                        <div style={{ fontSize: '12px', color: '#64748b' }}>{s.label}</div>
                      </div>
                    ))}
                  </div>
                  {/* Description */}
                  {cond?.description && (
                    <div>
                      <div style={{ fontSize: '12px', fontWeight: 600, color: '#94a3b8', textTransform: 'uppercase', letterSpacing: '0.5px', marginBottom: '6px' }}>
                        Description
                      </div>
                      <p style={{ margin: 0, fontSize: '14px', color: '#334155', lineHeight: 1.6,
                        background: '#f8fafc', borderRadius: '8px', padding: '12px' }}>
                        {cond.description.replace(/^\[[A-Z0-9]+\]\s*/, '')}
                      </p>
                    </div>
                  )}
                  {/* Treatment plan status breakdown */}
                  {treatmentPlans.by_status.length > 0 && (
                    <div>
                      <div style={{ fontSize: '12px', fontWeight: 600, color: '#94a3b8', textTransform: 'uppercase', letterSpacing: '0.5px', marginBottom: '8px' }}>
                        Treatment Plan Statuses
                      </div>
                      <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
                        {treatmentPlans.by_status.map((s) => (
                          <span key={s.status} style={{ fontSize: '13px', padding: '4px 12px', borderRadius: '20px',
                            background: s.status === 'active' ? '#dcfce7' : s.status === 'completed' ? '#dbeafe' : '#fef3c7',
                            color: s.status === 'active' ? '#166534' : s.status === 'completed' ? '#1e40af' : '#92400e',
                            fontWeight: 600 }}>
                            {s.status} · {s.count}
                          </span>
                        ))}
                      </div>
                    </div>
                  )}
                </div>
              )}

              {/* ── Medications ── */}
              {tab === 'medications' && (
                <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
                  {medications.length === 0 ? (
                    <div style={{ textAlign: 'center', padding: '40px', color: '#94a3b8' }}>
                      <BeakerIcon style={{ width: 36, height: 36, margin: '0 auto 8px', opacity: 0.4 }} />
                      <p style={{ margin: 0 }}>No medications linked to this condition</p>
                    </div>
                  ) : medications.map((med) => (
                    <div key={med.id} style={{ background: '#f8fafc', borderRadius: '10px', padding: '14px 16px',
                      border: '1px solid #e2e8f0' }}>
                      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
                        <div>
                          <div style={{ fontWeight: 700, fontSize: '14px', color: '#0f172a' }}>{med.name}</div>
                          {med.generic_name && (
                            <div style={{ fontSize: '12px', color: '#64748b', marginTop: '1px' }}>
                              Generic: {med.generic_name}
                            </div>
                          )}
                        </div>
                        <div style={{ display: 'flex', gap: '6px', alignItems: 'center' }}>
                          <span style={{ fontSize: '12px', background: '#eff6ff', color: '#3b82f6',
                            borderRadius: '20px', padding: '2px 8px', fontWeight: 600 }}>
                            {med.active_assignments} active Rx
                          </span>
                          <span style={{ fontSize: '11px', color: med.is_active ? '#10b981' : '#f59e0b', fontWeight: 600 }}>
                            {med.is_active ? '● Active' : '● Inactive'}
                          </span>
                        </div>
                      </div>
                      <div style={{ marginTop: '10px', display: 'flex', gap: '16px', flexWrap: 'wrap' }}>
                        {med.dosage_options?.length > 0 && (
                          <div>
                            <span style={{ fontSize: '11px', color: '#94a3b8', fontWeight: 600, display: 'block' }}>DOSAGES</span>
                            <span style={{ fontSize: '13px', color: '#475569' }}>{med.dosage_options.join(', ')}</span>
                          </div>
                        )}
                        {med.frequency_options?.length > 0 && (
                          <div>
                            <span style={{ fontSize: '11px', color: '#94a3b8', fontWeight: 600, display: 'block' }}>FREQUENCY</span>
                            <span style={{ fontSize: '13px', color: '#475569' }}>{med.frequency_options.join(', ')}</span>
                          </div>
                        )}
                      </div>
                      {med.notes && (
                        <div style={{ marginTop: '8px', fontSize: '12px', color: '#64748b', fontStyle: 'italic' }}>
                          {med.notes}
                        </div>
                      )}
                    </div>
                  ))}
                </div>
              )}

              {/* ── Treatment Plans ── */}
              {tab === 'plans' && (
                <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
                  {treatmentPlans.recent.length === 0 ? (
                    <div style={{ textAlign: 'center', padding: '40px', color: '#94a3b8' }}>
                      <ClipboardDocumentListIcon style={{ width: 36, height: 36, margin: '0 auto 8px', opacity: 0.4 }} />
                      <p style={{ margin: 0 }}>No treatment plans linked to this condition</p>
                    </div>
                  ) : (
                    <>
                      <p style={{ margin: '0 0 4px', fontSize: '13px', color: '#94a3b8' }}>
                        Showing most recent {treatmentPlans.recent.length} plans
                      </p>
                      {treatmentPlans.recent.map((tp) => (
                        <div key={tp.id} style={{ background: '#f8fafc', borderRadius: '10px', padding: '14px 16px',
                          border: '1px solid #e2e8f0' }}>
                          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
                            <div style={{ fontWeight: 700, fontSize: '14px', color: '#0f172a' }}>
                              {tp.title || 'Untitled Plan'}
                            </div>
                            <span style={{ fontSize: '12px', borderRadius: '20px', padding: '2px 8px', fontWeight: 600,
                              background: tp.status === 'active' ? '#dcfce7' : tp.status === 'completed' ? '#dbeafe' : '#fef3c7',
                              color: tp.status === 'active' ? '#166534' : tp.status === 'completed' ? '#1e40af' : '#92400e' }}>
                              {tp.status ?? 'unknown'}
                            </span>
                          </div>
                          <div style={{ marginTop: '8px', display: 'flex', gap: '16px', flexWrap: 'wrap', fontSize: '13px', color: '#64748b' }}>
                            <span>
                              <UsersIcon style={{ width: 13, height: 13, display: 'inline', marginRight: '4px', verticalAlign: 'middle' }} />
                              {tp.first_name} {tp.last_name}
                              {tp.member_number && <span style={{ color: '#94a3b8' }}> · #{tp.member_number}</span>}
                            </span>
                            {tp.provider_name && <span>Provider: {tp.provider_name}</span>}
                            {tp.plan_date && <span>Date: {new Date(tp.plan_date).toLocaleDateString()}</span>}
                            {tp.cost != null && (
                              <span style={{ fontWeight: 600, color: '#0f172a' }}>
                                {tp.currency ?? 'UGX'} {Number(tp.cost).toLocaleString()}
                              </span>
                            )}
                          </div>
                        </div>
                      ))}
                    </>
                  )}
                </div>
              )}

              {/* ── Members ── */}
              {tab === 'members' && (
                <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
                  {members.length === 0 ? (
                    <div style={{ textAlign: 'center', padding: '40px', color: '#94a3b8' }}>
                      <UsersIcon style={{ width: 36, height: 36, margin: '0 auto 8px', opacity: 0.4 }} />
                      <p style={{ margin: 0 }}>No members enrolled in this condition</p>
                    </div>
                  ) : (
                    <>
                      <p style={{ margin: '0 0 4px', fontSize: '13px', color: '#94a3b8' }}>
                        Showing {members.length} most recently diagnosed members
                      </p>
                      {members.map((mem) => (
                        <div key={mem.id} style={{ background: '#f8fafc', borderRadius: '10px', padding: '12px 16px',
                          border: '1px solid #e2e8f0', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                          <div>
                            <div style={{ fontWeight: 600, fontSize: '14px', color: '#0f172a' }}>
                              {mem.first_name} {mem.last_name}
                            </div>
                            <div style={{ fontSize: '12px', color: '#64748b', marginTop: '1px' }}>
                              #{mem.member_number}
                              {mem.gender && <> · {mem.gender}</>}
                              {mem.diagnosed_date && (
                                <> · Diagnosed: {new Date(mem.diagnosed_date).toLocaleDateString()}</>
                              )}
                            </div>
                            {mem.condition_notes && (
                              <div style={{ fontSize: '12px', color: '#94a3b8', marginTop: '3px', fontStyle: 'italic' }}>
                                {mem.condition_notes}
                              </div>
                            )}
                          </div>
                          <button
                            onClick={() => { onClose(); navigate(`/members/${mem.id}`); }}
                            style={{ fontSize: '12px', color: '#3b82f6', background: 'none', border: 'none',
                              cursor: 'pointer', fontWeight: 600, flexShrink: 0 }}>
                            View →
                          </button>
                        </div>
                      ))}
                    </>
                  )}
                </div>
              )}
            </>
          )}
        </div>
      </div>
    </>
  );
}

/* ── ConditionForm (reused for create + edit) ── */
function ConditionForm({ defaultValues, onSubmit, isPending, onCancel }) {
  const { register, handleSubmit, formState: { errors } } = useForm({ defaultValues });
  return (
    <form onSubmit={handleSubmit(onSubmit)} style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
      <Input label="Condition Name *" name="name" register={register}
        error={errors.name} placeholder="e.g. Type 2 Diabetes" />
      <Input label="ICD-10 Code" name="icd_code" register={register}
        placeholder="e.g. E11" />
      <div style={{ display: 'flex', flexDirection: 'column', gap: '4px' }}>
        <label style={{ fontSize: '13px', fontWeight: 600, color: '#475569' }}>Description</label>
        <textarea {...register('description')} rows={3}
          placeholder="Brief clinical description of the condition…"
          style={{ padding: '8px 12px', borderRadius: '6px', border: '1px solid #e2e8f0',
            fontSize: '14px', resize: 'vertical', fontFamily: 'inherit' }} />
      </div>
      <div style={{ display: 'flex', gap: '8px', justifyContent: 'flex-end', paddingTop: '4px' }}>
        <Button variant="secondary" type="button" onClick={onCancel}>Cancel</Button>
        <Button variant="primary" type="submit" disabled={isPending}>
          {isPending ? 'Saving…' : 'Save Condition'}
        </Button>
      </div>
    </form>
  );
}

/* ══════════════════════════════════════════════════════════════ */
export default function ConditionsPage() {
  const qc = useQueryClient();
  const navigate = useNavigate();

  const [showCreate, setShowCreate] = useState(false);
  const [editing,    setEditing]    = useState(null);
  const [drawer,     setDrawer]     = useState(null); // condition object
  const [search,     setSearch]     = useState('');
  const [filterStatus, setFilterStatus] = useState('all');// all | active | inactive

  /* ── Data ── */
  const { data: conditions = [], isLoading } = useQuery({
    queryKey: ['conditions'],
    queryFn: () => getConditions().then((r) => (Array.isArray(r.data) ? r.data : [])),
    retry: false,
  });

  /* ── Stats ── */
  const stats = useMemo(() => {
    const active   = conditions.filter((c) => c.is_active).length;
    const inactive = conditions.length - active;
    const totalMembers = conditions.reduce((s, c) => s + Number(c.member_count ?? 0), 0);
    const totalMeds    = conditions.reduce((s, c) => s + Number(c.medication_count ?? 0), 0);
    return { total: conditions.length, active, inactive, totalMembers, totalMeds };
  }, [conditions]);

  /* ── Filtered list ── */
  const filtered = useMemo(() => {
    const q = search.toLowerCase();
    return conditions.filter((c) => {
      if (filterStatus === 'active'   && !c.is_active) return false;
      if (filterStatus === 'inactive' &&  c.is_active) return false;
      if (q && !c.name?.toLowerCase().includes(q) && !(c.description || '').toLowerCase().includes(q)) return false;
      return true;
    });
  }, [conditions, search, filterStatus]);

  /* ── invalidate helper ── */
  const invalidate = () => qc.invalidateQueries({ queryKey: ['conditions'] });

  /* ── Mutations ── */
  const syncMutation = useMutation({
    mutationFn: syncConditions,
    onSuccess: (res) => { invalidate(); toast.success(res.data?.message || 'Conditions synced'); },
    onError: () => toast.error('Sync failed'),
  });

  const createMutation = useMutation({
    mutationFn: createCondition,
    onSuccess: () => { invalidate(); toast.success('Condition added'); setShowCreate(false); },
    onError: (err) => toast.error(err?.response?.data?.message || 'Failed to add condition'),
  });

  const updateMutation = useMutation({
    mutationFn: ({ id, data }) => updateCondition(id, data),
    onSuccess: () => { invalidate(); toast.success('Condition updated'); setEditing(null); },
    onError: (err) => toast.error(err?.response?.data?.message || 'Failed to update condition'),
  });

  const deleteMutation = useMutation({
    mutationFn: deleteCondition,
    onSuccess: () => { invalidate(); toast.success('Condition deleted'); },
    onError: (err) => toast.error(err?.response?.data?.message || 'Delete failed'),
  });

  const toggleMutation = useMutation({
    mutationFn: toggleCondition,
    onSuccess: () => { invalidate(); toast.success('Status updated'); },
    onError: () => toast.error('Update failed'),
  });

  /* ── Table columns ── */
  const columns = [
    {
      key: 'name', header: 'Condition Name',
      render: (v, row) => (
        <div>
          <div style={{ fontWeight: 700, fontSize: '14px', color: '#0f172a' }}>{v}</div>
          {row.description && (
            <div style={{ fontSize: '12px', color: '#94a3b8', marginTop: '2px',
              maxWidth: '340px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
              {row.description}
            </div>
          )}
        </div>
      ),
    },
    {
      key: 'member_count', header: 'Members',
      render: (v, row) => (
        <button
          onClick={() => navigate(`/members?condition=${row.id}`)}
          style={{ display: 'flex', alignItems: 'center', gap: '5px', background: 'none', border: 'none',
            cursor: v > 0 ? 'pointer' : 'default', color: v > 0 ? '#3b82f6' : '#94a3b8',
            fontSize: '14px', fontWeight: 600, padding: 0 }}
          title={v > 0 ? 'View members with this condition' : 'No members enrolled'}
        >
          <UsersIcon style={{ width: 14, height: 14 }} />
          {Number(v ?? 0).toLocaleString()}
        </button>
      ),
    },
    {
      key: 'medication_count', header: 'Medications',
      render: (v) => (
        <div style={{ display: 'flex', alignItems: 'center', gap: '5px',
          color: v > 0 ? '#10b981' : '#94a3b8', fontSize: '14px', fontWeight: 600 }}>
          <BeakerIcon style={{ width: 14, height: 14 }} />
          {Number(v ?? 0).toLocaleString()}
        </div>
      ),
    },
    {
      key: 'is_active', header: 'Status',
      render: (v) => <Badge status={v ? 'active' : 'inactive'} label={v ? 'Active' : 'Inactive'} />,
    },
    {
      key: 'actions', header: '',
      render: (_, row) => (
        <div style={{ display: 'flex', gap: '4px', flexWrap: 'wrap' }}>
          <Button variant="ghost" onClick={() => setDrawer(row)}
            style={{ padding: '4px 8px', fontSize: '12px', display: 'flex', alignItems: 'center', gap: '4px' }}>
            <EyeIcon style={{ width: 12, height: 12 }} /> View
          </Button>
          <Button variant="ghost" onClick={() => setEditing(row)}
            style={{ padding: '4px 8px', fontSize: '12px', display: 'flex', alignItems: 'center', gap: '4px' }}>
            <PencilIcon style={{ width: 12, height: 12 }} /> Edit
          </Button>
          <Button
            variant={row.is_active ? 'danger' : 'success'}
            onClick={() => toggleMutation.mutate(row.id)}
            style={{ padding: '4px 8px', fontSize: '12px', display: 'flex', alignItems: 'center', gap: '4px' }}>
            {row.is_active
              ? <><XCircleIcon style={{ width: 12, height: 12 }} /> Deactivate</>
              : <><CheckCircleIcon style={{ width: 12, height: 12 }} /> Activate</>
            }
          </Button>
          <Button variant="danger"
            onClick={() => {
              if (window.confirm(`Delete "${row.name}"? This cannot be undone.`)) {
                deleteMutation.mutate(row.id);
              }
            }}
            style={{ padding: '4px 8px', fontSize: '12px', display: 'flex', alignItems: 'center', gap: '4px' }}>
            <TrashIcon style={{ width: 12, height: 12 }} /> Delete
          </Button>
        </div>
      ),
    },
  ];

  /* ══ RENDER ══ */
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>

      {/* ── Header ── */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', flexWrap: 'wrap', gap: '12px' }}>
        <div>
          <h2 style={{ margin: 0, fontSize: '22px', fontWeight: 700, color: '#0f172a' }}>Chronic Conditions</h2>
          <p style={{ margin: '4px 0 0', fontSize: '14px', color: '#64748b' }}>
            Manage all chronic conditions covered by the programme
          </p>
        </div>
        <div style={{ display: 'flex', gap: '8px' }}>
          <Button variant="secondary" onClick={() => syncMutation.mutate()} disabled={syncMutation.isPending}
            style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
            <ArrowPathIcon style={{ width: 15, height: 15,
              animation: syncMutation.isPending ? 'spin 1s linear infinite' : 'none' }} />
            {syncMutation.isPending ? 'Syncing…' : 'Sync Standard List'}
          </Button>
          <Button variant="primary" onClick={() => setShowCreate(true)}
            style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
            <PlusIcon style={{ width: 15, height: 15 }} /> Add Condition
          </Button>
        </div>
      </div>

      {/* ── Stat cards ── */}
      <div style={{ display: 'flex', gap: '16px', flexWrap: 'wrap' }}>
        <StatCard label="Total Conditions" value={stats.total}        color="#3b82f6" Icon={BeakerIcon} />
        <StatCard label="Active"           value={stats.active}       color="#10b981" Icon={CheckCircleIcon}
          sub={stats.total ? `${Math.round((stats.active / stats.total) * 100)}% of total` : ''} />
        <StatCard label="Inactive"         value={stats.inactive}     color="#f59e0b" Icon={XCircleIcon} />
        <StatCard label="Members Enrolled" value={stats.totalMembers.toLocaleString()} color="#0ea5e9" Icon={UsersIcon} />
        <StatCard label="Linked Medications" value={stats.totalMeds.toLocaleString()} color="#06b6d4" Icon={BeakerIcon} />
      </div>

      {/* ── Filters ── */}
      <div style={{ ...card, padding: '12px 16px' }}>
        <div style={{ display: 'flex', gap: '10px', flexWrap: 'wrap', alignItems: 'center' }}>
          <FunnelIcon style={{ width: 16, height: 16, color: '#94a3b8', flexShrink: 0 }} />

          <div style={{ position: 'relative', flex: 2, minWidth: 200 }}>
            <MagnifyingGlassIcon style={{ width: 14, height: 14, color: '#94a3b8',
              position: 'absolute', left: '10px', top: '50%', transform: 'translateY(-50%)' }} />
            <input
              placeholder="Search by name or description…"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              style={{ width: '100%', padding: '7px 12px 7px 30px', borderRadius: '6px',
                border: '1px solid #e2e8f0', fontSize: '13px', boxSizing: 'border-box', outline: 'none' }}
            />
          </div>

          {['all', 'active', 'inactive'].map((s) => (
            <button key={s} onClick={() => setFilterStatus(s)}
              style={{ padding: '6px 14px', borderRadius: '6px', fontSize: '13px', cursor: 'pointer',
                border: filterStatus === s ? '1.5px solid #3b82f6' : '1px solid #e2e8f0',
                background: filterStatus === s ? '#eff6ff' : '#fff',
                color: filterStatus === s ? '#3b82f6' : '#64748b', fontWeight: filterStatus === s ? 600 : 400,
                textTransform: 'capitalize' }}>
              {s}
            </button>
          ))}

          <span style={{ marginLeft: 'auto', fontSize: '13px', color: '#94a3b8' }}>
            {filtered.length} of {conditions.length}
          </span>
        </div>
      </div>

      {/* ── Table ── */}
      <div style={{ background: '#fff', borderRadius: '12px', boxShadow: '0 1px 4px rgba(0,0,0,0.07)', overflow: 'hidden' }}>
        {isLoading
          ? <div style={{ padding: '60px', display: 'flex', justifyContent: 'center' }}><Spinner /></div>
          : <Table columns={columns} data={filtered}
              emptyMessage="No conditions found. Click 'Sync Standard List' to populate." />
        }
      </div>

      {/* ── Create Modal ── */}
      {showCreate && (
        <Modal title="Add Condition" onClose={() => setShowCreate(false)} width="500px">
          <ConditionForm
            defaultValues={{ name: '', icd_code: '', description: '' }}
            onSubmit={(d) => createMutation.mutate(d)}
            isPending={createMutation.isPending}
            onCancel={() => setShowCreate(false)}
          />
        </Modal>
      )}

      {/* ── Edit Modal ── */}
      {editing && (
        <Modal title={`Edit — ${editing.name}`} onClose={() => setEditing(null)} width="500px">
          <ConditionForm
            defaultValues={{
              name: editing.name,
              description: editing.description || '',
              icd_code: '',
            }}
            onSubmit={(d) => updateMutation.mutate({ id: editing.id, data: d })}
            isPending={updateMutation.isPending}
            onCancel={() => setEditing(null)}
          />
        </Modal>
      )}

      {/* ── Condition Drawer ── */}
      {drawer && (
        <ConditionDrawer
          conditionId={drawer.id}
          onClose={() => setDrawer(null)}
          navigate={navigate}
        />
      )}

      <style>{`
        @keyframes spin { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }
      `}</style>
    </div>
  );
}

