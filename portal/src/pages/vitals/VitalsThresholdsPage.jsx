import { useState, useMemo } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import toast from 'react-hot-toast';
import {
  PlusIcon,
  PencilSquareIcon,
  TrashIcon,
  ExclamationTriangleIcon,
  HeartIcon,
  BeakerIcon,
  InformationCircleIcon,
} from '@heroicons/react/24/outline';
import {
  getThresholds, createThreshold, updateThreshold, deleteThreshold,
} from '../../api/vitalsThresholds';
import { getConditions } from '../../api/conditions';
import Table from '../../components/UI/Table';
import Modal from '../../components/UI/Modal';
import Button from '../../components/UI/Button';
import Spinner from '../../components/UI/Spinner';
const METRICS = [
  { value: 'blood_sugar', label: 'Blood Sugar', unit: 'mmol/L' },
  { value: 'systolic_bp', label: 'Systolic BP', unit: 'mmHg' },
  { value: 'diastolic_bp', label: 'Diastolic BP', unit: 'mmHg' },
  { value: 'heart_rate', label: 'Heart Rate', unit: 'bpm' },
  { value: 'o2_saturation', label: 'O₂ Saturation', unit: '%' },
  { value: 'temperature_c', label: 'Temperature', unit: '°C' },
  { value: 'pain_level', label: 'Pain Level', unit: '0-10' },
];
const metricLabel = (key) => METRICS.find((m) => m.value === key)?.label || key;
const metricUnit = (key) => METRICS.find((m) => m.value === key)?.unit || '';
const inputStyle = {
  padding: '8px 12px', borderRadius: '6px', border: '1px solid #e2e8f0',
  fontSize: '14px', color: 'var(--text)', background: '#fff', outline: 'none',
  width: '100%', boxSizing: 'border-box',
};
export default function VitalsThresholdsPage() {
  const qc = useQueryClient();
  const [modalOpen, setModalOpen] = useState(false);
  const [editItem, setEditItem] = useState(null);
  const [deleteId, setDeleteId] = useState(null);
  const [form, setForm] = useState({ metric: '', condition_id: '', min_value: '', max_value: '' });
  const { data: thresholds, isLoading } = useQuery({
    queryKey: ['vitals-thresholds'],
    queryFn: getThresholds,
    placeholderData: [],
  });
  const { data: conditionsData } = useQuery({
    queryKey: ['conditions'],
    queryFn: getConditions,
  });
  const conditions = conditionsData?.data || conditionsData || [];
  const conditionName = (id) => {
    if (!id) return 'All (Global)';
    const c = (Array.isArray(conditions) ? conditions : []).find((c) => c.id === id);
    return c?.name || id;
  };
  const createMut = useMutation({
    mutationFn: (data) => createThreshold(data),
    onSuccess: () => { qc.invalidateQueries({ queryKey: ['vitals-thresholds'] }); toast.success('Threshold created'); closeModal(); },
    onError: () => toast.error('Failed to create threshold'),
  });
  const updateMut = useMutation({
    mutationFn: ({ id, data }) => updateThreshold(id, data),
    onSuccess: () => { qc.invalidateQueries({ queryKey: ['vitals-thresholds'] }); toast.success('Threshold updated'); closeModal(); },
    onError: () => toast.error('Failed to update threshold'),
  });
  const deleteMut = useMutation({
    mutationFn: (id) => deleteThreshold(id),
    onSuccess: () => { qc.invalidateQueries({ queryKey: ['vitals-thresholds'] }); toast.success('Threshold deleted'); setDeleteId(null); },
    onError: () => toast.error('Failed to delete threshold'),
  });
  const openCreate = () => {
    setEditItem(null);
    setForm({ metric: METRICS[0].value, condition_id: '', min_value: '', max_value: '' });
    setModalOpen(true);
  };
  const openEdit = (row) => {
    setEditItem(row);
    setForm({
      metric: row.metric || '',
      condition_id: row.condition_id || '',
      min_value: row.min_value ?? '',
      max_value: row.max_value ?? '',
    });
    setModalOpen(true);
  };
  const closeModal = () => { setModalOpen(false); setEditItem(null); };
  const handleSubmit = (e) => {
    e.preventDefault();
    const payload = {
      metric: form.metric,
      condition_id: form.condition_id || null,
      min_value: form.min_value !== '' ? Number(form.min_value) : null,
      max_value: form.max_value !== '' ? Number(form.max_value) : null,
    };
    if (editItem) {
      updateMut.mutate({ id: editItem.id, data: payload });
    } else {
      createMut.mutate(payload);
    }
  };
  const thresholdList = Array.isArray(thresholds) ? thresholds : [];
  const stats = useMemo(() => {
    const metricsSet = new Set(thresholdList.map((t) => t.metric));
    const conditionsSet = new Set(thresholdList.filter((t) => t.condition_id).map((t) => t.condition_id));
    return {
      total: thresholdList.length,
      conditions: conditionsSet.size,
      metrics: metricsSet.size,
    };
  }, [thresholdList]);
  const columns = [
    {
      key: 'metric',
      header: 'Metric',
      render: (val) => (
        <span style={{ fontWeight: 600 }}>{metricLabel(val)}</span>
      ),
    },
    {
      key: 'condition_id',
      header: 'Condition',
      render: (val) => (
        <span style={{
          background: val ? '#dbeafe' : '#f1f5f9',
          color: val ? '#1e40af' : '#64748b',
          padding: '2px 10px', borderRadius: '999px', fontSize: '12px', fontWeight: 600,
        }}>
          {conditionName(val)}
        </span>
      ),
    },
    {
      key: 'min_value',
      header: 'Min Value',
      render: (val, row) => (
        <span>{val != null ? `${val} ${metricUnit(row.metric)}` : '—'}</span>
      ),
    },
    {
      key: 'max_value',
      header: 'Max Value',
      render: (val, row) => (
        <span>{val != null ? `${val} ${metricUnit(row.metric)}` : '—'}</span>
      ),
    },
    {
      key: 'unit',
      header: 'Unit',
      render: (_, row) => <span style={{ color: '#64748b' }}>{metricUnit(row.metric)}</span>,
    },
    {
      key: 'actions',
      header: 'Actions',
      render: (_, row) => (
        <div style={{ display: 'flex', gap: '6px' }}>
          <Button variant="secondary" onClick={() => openEdit(row)}
            style={{ padding: '4px 8px', fontSize: '12px' }}>
            <PencilSquareIcon style={{ width: 14, height: 14 }} />
          </Button>
          <Button variant="danger" onClick={() => setDeleteId(row.id)}
            style={{ padding: '4px 8px', fontSize: '12px' }}>
            <TrashIcon style={{ width: 14, height: 14 }} />
          </Button>
        </div>
      ),
    },
  ];
  const isSaving = createMut.isPending || updateMut.isPending;
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
      {/* Header */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '10px' }}>
        <div>
          <h1 style={{ fontSize: '22px', fontWeight: 700, color: '#0f172a', margin: 0 }}>
            Vital Thresholds
          </h1>
          <p style={{ margin: '4px 0 0', fontSize: '14px', color: '#64748b' }}>
            Configure alert thresholds for patient vitals
          </p>
        </div>
        <Button onClick={openCreate}>
          <PlusIcon style={{ width: 16, height: 16 }} /> Add Threshold
        </Button>
      </div>
      {/* Info Panel */}
      <div style={{
        background: '#eff6ff', borderRadius: '12px', padding: '14px 20px',
        border: '1px solid #bfdbfe', display: 'flex', gap: '10px', alignItems: 'flex-start',
      }}>
        <InformationCircleIcon style={{ width: 20, height: 20,  flexShrink: 0, marginTop: 1 }} />
        <p style={{ margin: 0, fontSize: '13px', color: '#1e40af', lineHeight: 1.6 }}>
          When a member logs vitals outside these ranges, they automatically receive an alert.
          Thresholds can be set globally or per condition.
        </p>
      </div>
      {/* Stat Cards */}
      <div style={{ display: 'flex', gap: '14px', flexWrap: 'wrap' }}>
        {[
          { label: 'Total Rules', value: stats.total,  Icon: BeakerIcon },
          { label: 'Conditions Covered', value: stats.conditions,  Icon: HeartIcon },
          { label: 'Metrics Monitored', value: stats.metrics,  Icon: ExclamationTriangleIcon },
        ].map((s) => (
          <div key={s.label} style={{
            background: '#fff', borderRadius: '12px', border: '1px solid #e2e8f0',
            padding: '16px 20px', flex: 1, minWidth: 160,
          }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '6px' }}>
              <s.Icon style={{ width: 16, height: 16, color: '#64748b' }} />
              <span style={{ fontSize: '12px', color: '#94a3b8', fontWeight: 500 }}>{s.label}</span>
            </div>
            <div style={{ fontSize: '28px', fontWeight: 800, color: '#0f172a', lineHeight: 1 }}>
              {s.value ?? '—'}
            </div>
          </div>
        ))}
      </div>
      {/* Table */}
      <div style={{
        background: '#fff', borderRadius: '12px',
        boxShadow: '0 1px 4px rgba(0,0,0,0.07)', border: '1px solid #e2e8f0',
        overflow: 'hidden',
      }}>
        {isLoading ? <Spinner /> : (
          <Table columns={columns} data={thresholdList} emptyMessage="No thresholds configured yet." />
        )}
      </div>
      {/* Create / Edit Modal */}
      {modalOpen && (
        <Modal title={editItem ? 'Edit Threshold' : 'Add Threshold'} onClose={closeModal}>
          <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '4px' }}>
              <label style={{ fontSize: '13px', fontWeight: 500, color: '#475569' }}>Metric</label>
              <select value={form.metric} onChange={(e) => setForm({ ...form, metric: e.target.value })}
                style={{ ...inputStyle, cursor: 'pointer' }}>
                {METRICS.map((m) => <option key={m.value} value={m.value}>{m.label} ({m.unit})</option>)}
              </select>
            </div>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '4px' }}>
              <label style={{ fontSize: '13px', fontWeight: 500, color: '#475569' }}>Condition</label>
              <select value={form.condition_id}
                onChange={(e) => setForm({ ...form, condition_id: e.target.value })}
                style={{ ...inputStyle, cursor: 'pointer' }}>
                <option value="">All (Global)</option>
                {(Array.isArray(conditions) ? conditions : []).map((c) => (
                  <option key={c.id} value={c.id}>{c.name}</option>
                ))}
              </select>
            </div>
            <div style={{ display: 'flex', gap: '12px' }}>
              <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: '4px' }}>
                <label style={{ fontSize: '13px', fontWeight: 500, color: '#475569' }}>Min Value</label>
                <input type="number" step="any" value={form.min_value}
                  onChange={(e) => setForm({ ...form, min_value: e.target.value })}
                  placeholder="e.g. 4.0" style={inputStyle} />
              </div>
              <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: '4px' }}>
                <label style={{ fontSize: '13px', fontWeight: 500, color: '#475569' }}>Max Value</label>
                <input type="number" step="any" value={form.max_value}
                  onChange={(e) => setForm({ ...form, max_value: e.target.value })}
                  placeholder="e.g. 10.0" style={inputStyle} />
              </div>
            </div>
            <div style={{ display: 'flex', gap: '10px', justifyContent: 'flex-end', marginTop: '4px' }}>
              <Button variant="secondary" onClick={closeModal} disabled={isSaving}>Cancel</Button>
              <Button type="submit" disabled={isSaving}>
                {isSaving ? 'Saving…' : editItem ? 'Update' : 'Create'}
              </Button>
            </div>
          </form>
        </Modal>
      )}
      {/* Delete confirmation */}
      {deleteId && (
        <Modal title="Delete Threshold" onClose={() => setDeleteId(null)} width="420px">
          <p style={{ margin: '0 0 20px', fontSize: '14px', color: '#475569' }}>
            Are you sure you want to delete this threshold rule? This action cannot be undone.
          </p>
          <div style={{ display: 'flex', gap: '10px', justifyContent: 'flex-end' }}>
            <Button variant="secondary" onClick={() => setDeleteId(null)}
              disabled={deleteMut.isPending}>Cancel</Button>
            <Button variant="danger" onClick={() => deleteMut.mutate(deleteId)}
              disabled={deleteMut.isPending}>
              {deleteMut.isPending ? 'Deleting…' : 'Delete'}
            </Button>
          </div>
        </Modal>
      )}
    </div>
  );
}
