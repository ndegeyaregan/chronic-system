import { useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useForm } from 'react-hook-form';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import {
  BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, LineChart, Line, Legend,
} from 'recharts';
import toast from 'react-hot-toast';
import {
  HeartIcon,
  BellAlertIcon,
  ArrowPathIcon,
  BuildingStorefrontIcon,
  ClipboardDocumentCheckIcon,
  ExclamationTriangleIcon,
  UserPlusIcon,
  PlusIcon,
  PaperClipIcon,
  ArrowDownTrayIcon,
  PencilSquareIcon,
} from '@heroicons/react/24/outline';
import { getMedicationOverview, getMedicationCatalogue, createMedication, assignMedicationToMember, updateMedication, stopAssignment, updateAssignmentRefill, getAssignmentDoseLogs, adminUpdateAssignment } from '../api/medications';
import { getMembers } from '../api/members';
import { getPharmacies } from '../api/pharmacies';
import { getConditions } from '../api/conditions';

const API_BASE = (import.meta.env.VITE_API_URL || '/api').replace(/\/api$/, '');
import StatCard from '../components/UI/StatCard';
import Table from '../components/UI/Table';
import Button from '../components/UI/Button';
import Modal from '../components/UI/Modal';
import Spinner from '../components/UI/Spinner';
import Input from '../components/UI/Input';
import Select from '../components/UI/Select';
import Badge from '../components/UI/Badge';

const chartContainerStyle = {
  background: '#fff',
  borderRadius: '12px',
  padding: '20px',
  boxShadow: '0 1px 4px rgba(0,0,0,0.07)',
};

const insightStyle = {
  background: '#f8fafc',
  border: '1px solid #e2e8f0',
  borderRadius: '12px',
  padding: '14px 16px',
};

const formatPercent = (value) => `${Number(value || 0).toFixed(1)}%`;
const formatDate = (value) => (value ? new Date(value).toLocaleDateString('en-UG', { day: '2-digit', month: 'short', year: 'numeric' }) : '—');

const riskReasonLabel = {
  low_adherence: 'Low adherence',
  refill_due_soon: 'Refill due soon',
  refill_overdue: 'Refill overdue',
  no_pharmacy: 'No pharmacy linked',
};

export default function MedicationsPage() {
  const qc = useQueryClient();
  const navigate = useNavigate();
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [showAssignModal, setShowAssignModal] = useState(false);
  const [assignmentFilter, setAssignmentFilter] = useState('');
  const [memberSearch, setMemberSearch] = useState('');
  const [medicationSearch, setMedicationSearch] = useState('');
  const [selectedMember, setSelectedMember] = useState(null);
  const [selectedMedication, setSelectedMedication] = useState(null);

  const [catalogueSearch, setCatalogueSearch] = useState('');
  const [cataloguePage, setCataloguePage] = useState(1);
  const CATALOGUE_PAGE_SIZE = 8;

  const [showEditModal, setShowEditModal] = useState(false);
  const [editingMedication, setEditingMedication] = useState(null);
  const editForm = useForm();

  const [showMediaModal, setShowMediaModal] = useState(false);
  const [mediaAssignment, setMediaAssignment] = useState(null);

  const [showRefillModal, setShowRefillModal] = useState(false);
  const [refillAssignment, setRefillAssignment] = useState(null);
  const refillForm = useForm();

  const [showLogsModal, setShowLogsModal] = useState(false);
  const [logsAssignment, setLogsAssignment] = useState(null);

  const [showAssignEditModal, setShowAssignEditModal] = useState(false);
  const [editingAssignment, setEditingAssignment] = useState(null);
  const assignEditForm = useForm();

  const [catalogueConditionFilter, setCatalogueConditionFilter] = useState('');

  const medicationForm = useForm();
  const assignmentForm = useForm();

  const { data: overview, isLoading: overviewLoading } = useQuery({
    queryKey: ['medications-overview'],
    queryFn: () => getMedicationOverview().then((response) => response.data),
    retry: false,
    placeholderData: {
      summary: {},
      adherence_trend: [],
      top_medications: [],
      pharmacy_breakdown: [],
      risk_flags: [],
      assignments: [],
      suggestions: [],
    },
  });

  const { data: catalogueData } = useQuery({
    queryKey: ['medication-catalogue'],
    queryFn: () => getMedicationCatalogue({ limit: 100 }).then((response) => response.data),
    retry: false,
    placeholderData: [],
  });

  const { data: memberSearchData, isFetching: membersSearching } = useQuery({
    queryKey: ['members-selector', memberSearch],
    queryFn: () => getMembers({ search: memberSearch, limit: 10 }).then((response) => response.data),
    enabled: showAssignModal && memberSearch.trim().length >= 2,
    retry: false,
    placeholderData: { members: [] },
  });

  const { data: medicationSearchData, isFetching: medicationsSearching } = useQuery({
    queryKey: ['medication-search', medicationSearch],
    queryFn: () => getMedicationCatalogue({ search: medicationSearch, limit: 12 }).then((response) => response.data),
    enabled: showAssignModal && medicationSearch.trim().length >= 2,
    retry: false,
    placeholderData: [],
  });

  const { data: pharmaciesData } = useQuery({
    queryKey: ['pharmacies-selector'],
    queryFn: () => getPharmacies().then((response) => response.data),
    retry: false,
    placeholderData: [],
  });

  const { data: conditionsData } = useQuery({
    queryKey: ['conditions-selector'],
    queryFn: () => getConditions().then((response) => response.data),
    retry: false,
    placeholderData: [],
  });

  const { data: doseLogsData, isLoading: doseLogsLoading } = useQuery({
    queryKey: ['assignment-logs', logsAssignment?.id],
    queryFn: () => getAssignmentDoseLogs(logsAssignment.id).then((r) => r.data),
    enabled: showLogsModal && !!logsAssignment?.id,
    retry: false,
    placeholderData: [],
  });

  const createMutation = useMutation({
    mutationFn: (payload) => createMedication(payload),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['medication-catalogue'] });
      qc.invalidateQueries({ queryKey: ['medications-overview'] });
      toast.success('Medication added to catalogue');
      setShowCreateModal(false);
      medicationForm.reset();
    },
    onError: (error) => toast.error(error.response?.data?.message || 'Failed to add medication'),
  });

  const assignMutation = useMutation({
    mutationFn: (payload) => assignMedicationToMember(payload),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['medications-overview'] });
      toast.success('Medication assigned');
      setShowAssignModal(false);
      assignmentForm.reset();
    },
    onError: (error) => toast.error(error.response?.data?.message || 'Failed to assign medication'),
  });

  const stopAssignmentMutation = useMutation({
    mutationFn: ({ id, end_date }) => stopAssignment(id, { end_date }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['medications-overview'] });
      toast.success('Prescription stopped');
    },
    onError: (err) => toast.error(err.response?.data?.message || 'Failed to stop prescription'),
  });

  const updateRefillMutation = useMutation({
    mutationFn: ({ id, ...data }) => updateAssignmentRefill(id, data),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['medications-overview'] });
      toast.success('Refill date updated');
      setShowRefillModal(false);
      refillForm.reset();
    },
    onError: (err) => toast.error(err.response?.data?.message || 'Failed to update refill'),
  });

  const editMutation = useMutation({
    mutationFn: ({ id, ...data }) => updateMedication(id, data),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['medication-catalogue'] });
      qc.invalidateQueries({ queryKey: ['medications-overview'] });
      toast.success('Medication updated');
      setShowEditModal(false);
      editForm.reset();
      setEditingMedication(null);
    },
    onError: (err) => toast.error(err.response?.data?.message || 'Failed to update medication'),
  });

  const assignEditMutation = useMutation({
    mutationFn: ({ id, ...data }) => adminUpdateAssignment(id, data),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['medications-overview'] });
      toast.success('Assignment updated');
      setShowAssignEditModal(false);
      assignEditForm.reset();
      setEditingAssignment(null);
    },
    onError: (err) => toast.error(err.response?.data?.message || 'Failed to update assignment'),
  });

  const summary = overview?.summary || {};
  const assignments = overview?.assignments || [];
  const filteredAssignments = useMemo(() => {
    const query = assignmentFilter.trim().toLowerCase();
    if (!query) return assignments;
    return assignments.filter((item) => (
      item.member_name?.toLowerCase().includes(query)
      || item.member_number?.toLowerCase().includes(query)
      || item.medication_name?.toLowerCase().includes(query)
      || item.pharmacy_name?.toLowerCase().includes(query)
    ));
  }, [assignments, assignmentFilter]);

  const medications = Array.isArray(catalogueData) ? catalogueData : catalogueData?.data || [];
  const members = memberSearchData?.members || memberSearchData?.data || [];
  const medicationOptions = Array.isArray(medicationSearchData) ? medicationSearchData : medicationSearchData?.data || [];
  const pharmacies = Array.isArray(pharmaciesData) ? pharmaciesData : pharmaciesData?.pharmacies || [];
  const conditions = Array.isArray(conditionsData) ? conditionsData : conditionsData?.conditions || [];

  const filteredCatalogue = useMemo(() => {
    const q = catalogueSearch.trim().toLowerCase();
    return medications.filter((m) => {
      const matchesSearch = !q || m.name?.toLowerCase().includes(q) || m.generic_name?.toLowerCase().includes(q) || m.condition_name?.toLowerCase().includes(q);
      const matchesCondition = !catalogueConditionFilter || m.condition_id === catalogueConditionFilter;
      return matchesSearch && matchesCondition;
    });
  }, [medications, catalogueSearch, catalogueConditionFilter]);

  const catalogueTotalPages = Math.max(1, Math.ceil(filteredCatalogue.length / CATALOGUE_PAGE_SIZE));
  const cataloguePageItems = filteredCatalogue.slice(
    (cataloguePage - 1) * CATALOGUE_PAGE_SIZE,
    cataloguePage * CATALOGUE_PAGE_SIZE
  );

  const exportAssignmentsCSV = () => {
    const headers = ['Member', 'Member No.', 'Medication', 'Condition', 'Dosage', 'Frequency', 'Pharmacy', 'Adherence %', 'Next Refill', 'Reminders', 'Media'];
    const rows = filteredAssignments.map((a) => [
      a.member_name,
      a.member_number,
      a.medication_name,
      a.condition_name || '',
      a.dosage || '',
      a.frequency || '',
      a.pharmacy_name || '',
      a.adherence_percent,
      a.next_refill_date ? new Date(a.next_refill_date).toLocaleDateString() : '',
      a.reminder_enabled ? 'On' : 'Off',
      a.has_media ? 'Yes' : 'No',
    ]);
    const csv = [headers, ...rows].map((r) => r.map((v) => `"${String(v).replace(/"/g, '""')}"`).join(',')).join('\n');
    const blob = new Blob([csv], { type: 'text/csv' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `medication-assignments-${new Date().toISOString().split('T')[0]}.csv`;
    a.click();
    URL.revokeObjectURL(url);
  };

  const assignmentColumns = [
    {
      key: 'end_date',
      header: 'Status',
      render: (value) => (
        <Badge status={value ? 'inactive' : 'confirmed'} label={value ? 'Stopped' : 'Active'} />
      ),
    },
    {
      key: 'member_name',
      header: 'Member',
      render: (_, row) => (
        <div>
          <div style={{ fontWeight: '600' }}>{row.member_name}</div>
          <button
            type="button"
            onClick={() => navigate(`/members/${row.member_id}`)}
            style={{ background: 'none', border: 'none', color: 'var(--primary)', padding: 0, fontSize: '12px', cursor: 'pointer' }}
          >
            {row.member_number}
          </button>
        </div>
      ),
    },
    {
      key: 'medication_name',
      header: 'Medication',
      render: (_, row) => (
        <div>
          <div style={{ fontWeight: '600' }}>{row.medication_name}</div>
          <div style={{ fontSize: '12px', color: '#64748b' }}>{row.dosage || row.frequency || 'No dosing set'}</div>
        </div>
      ),
    },
    { key: 'condition_name', header: 'Condition' },
    { key: 'pharmacy_name', header: 'Pharmacy' },
    {
      key: 'start_date',
      header: 'Started',
      render: (value) => formatDate(value),
    },
    {
      key: 'adherence_percent',
      header: 'Adherence',
      render: (value) => <Badge status={Number(value) < 70 ? 'pending' : 'confirmed'} label={formatPercent(value)} />,
    },
    {
      key: 'next_refill_date',
      header: 'Next Refill',
      render: (value) => formatDate(value),
    },
    {
      key: 'reminder_enabled',
      header: 'Reminders',
      render: (value) => <Badge status={value ? 'active' : 'inactive'} label={value ? 'On' : 'Off'} />,
    },
    {
      key: 'edited_by_name',
      header: 'Edited By',
      render: (value, row) => value ? (
        <div>
          <div style={{ fontWeight: '600', fontSize: '12px', color: '#0f172a' }}>{value}</div>
          {row.edit_note && <div style={{ fontSize: '11px', color: '#64748b', marginTop: '2px' }}>{row.edit_note}</div>}
        </div>
      ) : <span style={{ color: '#cbd5e1', fontSize: '12px' }}>—</span>,
    },
    {
      key: 'has_media',
      header: 'Media',
      render: (value, row) => {
        if (!value) return <Badge status="inactive" label="None" />;
        return (
          <div style={{ display: 'flex', gap: '4px', flexWrap: 'wrap' }}>
            {row.prescription_file_url && (
              <a href={`${API_BASE}${row.prescription_file_url}`} target="_blank" rel="noreferrer" title="Prescription" style={{ background: '#f0fdf4', border: '1px solid #bbf7d0', borderRadius: '4px', padding: '2px 6px', fontSize: '11px', color: '#166534', textDecoration: 'none' }}>📎 Rx</a>
            )}
            {row.photo_url && (
              <a href={`${API_BASE}${row.photo_url}`} target="_blank" rel="noreferrer" title="Photo" style={{ background: '#fef3c7', border: '1px solid #fde68a', borderRadius: '4px', padding: '2px 6px', fontSize: '11px', color: '#92400e', textDecoration: 'none' }}>📷</a>
            )}
            {row.audio_url && (
              <a href={`${API_BASE}${row.audio_url}`} target="_blank" rel="noreferrer" title="Audio" style={{ background: '#ede9fe', border: '1px solid #c4b5fd', borderRadius: '4px', padding: '2px 6px', fontSize: '11px', color: '#5b21b6', textDecoration: 'none' }}>🎵</a>
            )}
            {row.video_url && (
              <a href={`${API_BASE}${row.video_url}`} target="_blank" rel="noreferrer" title="Video" style={{ background: '#eff6ff', border: '1px solid #bfdbfe', borderRadius: '4px', padding: '2px 6px', fontSize: '11px', color: '#1d4ed8', textDecoration: 'none' }}>🎬</a>
            )}
            <button
              type="button"
              onClick={() => { setMediaAssignment(row); setShowMediaModal(true); }}
              style={{ background: '#f1f5f9', border: '1px solid #e2e8f0', borderRadius: '4px', padding: '2px 6px', fontSize: '11px', color: '#475569', cursor: 'pointer' }}
            >View All</button>
          </div>
        );
      },
    },
    {
      key: 'id',
      header: 'Actions',
      render: (_, row) => (
        <div style={{ display: 'flex', gap: '6px', flexWrap: 'wrap' }}>
          <button
            type="button"
            title="Edit Assignment"
            onClick={() => {
              setEditingAssignment(row);
              assignEditForm.reset({
                dosage: row.dosage || '',
                frequency: row.frequency || '',
                notes: row.notes || '',
                reminder_enabled: row.reminder_enabled ?? true,
                next_refill_date: row.next_refill_date?.split('T')[0] || '',
                refill_interval_days: row.refill_interval_days || '',
                edit_note: '',
              });
              setShowAssignEditModal(true);
            }}
            style={{ background: '#eff6ff', border: '1px solid #bfdbfe', borderRadius: '6px', padding: '4px 8px', cursor: 'pointer', fontSize: '12px', color: '#1d4ed8', fontWeight: '600' }}
          >
            ✏️ Edit
          </button>
          <button
            type="button"
            title="View Dose Logs"
            onClick={() => { setLogsAssignment(row); setShowLogsModal(true); }}
            style={{ background: '#f8fafc', border: '1px solid #e2e8f0', borderRadius: '6px', padding: '4px 8px', cursor: 'pointer', fontSize: '12px', color: '#475569' }}
          >
            Logs
          </button>
          <button
            type="button"
            title="Update Refill Date"
            onClick={() => { setRefillAssignment(row); refillForm.setValue('next_refill_date', row.next_refill_date?.split('T')[0] || ''); refillForm.setValue('refill_interval_days', row.refill_interval_days || ''); setShowRefillModal(true); }}
            style={{ background: '#f0fdf4', border: '1px solid #bbf7d0', borderRadius: '6px', padding: '4px 8px', cursor: 'pointer', fontSize: '12px', color: '#166534' }}
          >
            Refill
          </button>
          {row.has_media && (
            <button
              type="button"
              title="View Media"
              onClick={() => { setMediaAssignment(row); setShowMediaModal(true); }}
              style={{ background: '#eff6ff', border: '1px solid #bfdbfe', borderRadius: '6px', padding: '4px 8px', cursor: 'pointer', fontSize: '12px', color: '#1d4ed8' }}
            >
              Media
            </button>
          )}
          {!row.end_date && (
            <button
              type="button"
              title="Stop Prescription"
              onClick={() => {
                if (window.confirm(`Stop ${row.medication_name} for ${row.member_name}?`)) {
                  stopAssignmentMutation.mutate({ id: row.id });
                }
              }}
              style={{ background: '#fff1f2', border: '1px solid #fecdd3', borderRadius: '6px', padding: '4px 8px', cursor: 'pointer', fontSize: '12px', color: '#be123c' }}
            >
              Stop
            </button>
          )}
        </div>
      ),
    },
  ];

  const riskColumns = [
    { key: 'member_name', header: 'Member' },
    { key: 'medication_name', header: 'Medication' },
    {
      key: 'reason_code',
      header: 'Risk',
      render: (value) => <Badge status={value === 'low_adherence' ? 'pending' : 'overdue'} label={riskReasonLabel[value] || value} />,
    },
    {
      key: 'adherence_percent',
      header: 'Adherence',
      render: (value) => formatPercent(value),
    },
    {
      key: 'next_refill_date',
      header: 'Refill Date',
      render: (value) => formatDate(value),
    },
    { key: 'pharmacy_name', header: 'Pharmacy' },
  ];

  const onCreateMedication = (formData) => {
    createMutation.mutate({
      name: formData.name,
      generic_name: formData.generic_name || undefined,
      condition_id: formData.condition_id || undefined,
      dosage_options: formData.dosage_options ? formData.dosage_options.split(',').map((item) => item.trim()).filter(Boolean) : [],
      frequency_options: formData.frequency_options ? formData.frequency_options.split(',').map((item) => item.trim()).filter(Boolean) : [],
      interactions: formData.interactions ? formData.interactions.split(',').map((item) => item.trim()).filter(Boolean) : [],
      notes: formData.notes || undefined,
    });
  };

  const onAssignMedication = (formData) => {
    if (!selectedMember?.id || !selectedMedication?.id) {
      toast.error('Select both a member and a medication first');
      return;
    }

    const payload = new FormData();
    payload.append('member_id', selectedMember.id);
    payload.append('medication_id', selectedMedication.id);
    if (formData.dosage) payload.append('dosage', formData.dosage);
    if (formData.frequency) payload.append('frequency', formData.frequency);
    if (formData.start_date) payload.append('start_date', formData.start_date);
    if (formData.end_date) payload.append('end_date', formData.end_date);
    if (formData.start_time) payload.append('start_time', formData.start_time);
    if (formData.pharmacy_id) payload.append('pharmacy_id', formData.pharmacy_id);
    if (formData.refill_interval_days) payload.append('refill_interval_days', `${Number(formData.refill_interval_days)}`);
    payload.append('reminder_enabled', formData.reminder_enabled ? 'true' : 'false');
    if (formData.prescription?.[0]) payload.append('prescription', formData.prescription[0]);
    if (formData.photo?.[0]) payload.append('photo', formData.photo[0]);
    if (formData.audio?.[0]) payload.append('audio', formData.audio[0]);
    if (formData.video?.[0]) payload.append('video', formData.video[0]);

    assignMutation.mutate(payload);
  };

  if (overviewLoading) {
    return <Spinner />;
  }

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: '12px', flexWrap: 'wrap' }}>
        <div>
          <h2 style={{ margin: 0, fontSize: '22px', fontWeight: '700', color: 'var(--text)' }}>Medication Operations</h2>
          <p style={{ margin: '4px 0 0', color: '#64748b', fontSize: '14px' }}>
            Track medication adherence, refill pressure, pharmacy linkage, and member-level risks.
          </p>
        </div>
        <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
          <Button variant="secondary" onClick={() => { medicationForm.reset(); setShowCreateModal(true); }}>
            <PlusIcon style={{ width: 15, height: 15 }} /> Add Catalogue Medication
          </Button>
          <Button variant="primary" onClick={() => {
            assignmentForm.reset();
            setSelectedMember(null);
            setSelectedMedication(null);
            setMemberSearch('');
            setMedicationSearch('');
            setShowAssignModal(true);
          }}>
            <UserPlusIcon style={{ width: 15, height: 15 }} /> Assign Medication
          </Button>
        </div>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '16px' }}>
        <StatCard title="Catalogue" value={summary.catalogue_total ?? 0} icon={ClipboardDocumentCheckIcon} color="var(--primary)" variant="label" />
        <StatCard title="Active Assignments" value={summary.active_assignments ?? 0} icon={HeartIcon} color="var(--accent)" variant="label" />
        <StatCard title="Members on Medication" value={summary.members_on_medication ?? 0} icon={UserPlusIcon} color="#6366f1" variant="label" />
        <StatCard title="Avg Adherence" value={formatPercent(summary.avg_adherence)} icon={BellAlertIcon} color="#0ea5e9" variant="label" />
        <StatCard title="Refills Due (7 Days)" value={summary.refills_due_7d ?? 0} icon={ArrowPathIcon} color="#f59e0b" variant="label" />
        <StatCard title="Refills Overdue" value={summary.refills_overdue ?? 0} icon={ExclamationTriangleIcon} color="#dc2626" variant="label" />
        <StatCard title="Low Adherence Cases" value={summary.low_adherence_count ?? 0} icon={ExclamationTriangleIcon} color="#ef4444" variant="label" />
        <StatCard title="Pharmacy Linked" value={(summary.active_assignments ?? 0) - (summary.unassigned_pharmacy_count ?? 0)} icon={BuildingStorefrontIcon} color="#0f766e" variant="label" />
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '1.1fr 0.9fr', gap: '20px' }}>
        <div style={chartContainerStyle}>
          <h3 style={{ margin: '0 0 16px', fontSize: '15px', fontWeight: '600' }}>Dose Trends: Taken vs Skipped</h3>
          <ResponsiveContainer width="100%" height={260}>
            <LineChart data={overview?.adherence_trend || []}>
              <CartesianGrid strokeDasharray="3 3" stroke="#f1f5f9" />
              <XAxis dataKey="day" tick={{ fontSize: 11, fill: '#64748b' }} />
              <YAxis tick={{ fontSize: 11, fill: '#64748b' }} />
              <Tooltip contentStyle={{ fontSize: 12 }} />
              <Legend />
              <Line type="monotone" dataKey="taken" stroke="var(--accent)" strokeWidth={2} name="Taken" />
              <Line type="monotone" dataKey="skipped" stroke="#ef4444" strokeWidth={2} name="Skipped" />
            </LineChart>
          </ResponsiveContainer>
        </div>

        <div style={chartContainerStyle}>
          <h3 style={{ margin: '0 0 16px', fontSize: '15px', fontWeight: '600' }}>Top Active Medications</h3>
          <ResponsiveContainer width="100%" height={260}>
            <BarChart data={overview?.top_medications || []}>
              <CartesianGrid strokeDasharray="3 3" stroke="#f1f5f9" />
              <XAxis dataKey="name" tick={{ fontSize: 10, fill: '#64748b' }} interval={0} angle={-20} textAnchor="end" height={70} />
              <YAxis tick={{ fontSize: 11, fill: '#64748b' }} />
              <Tooltip contentStyle={{ fontSize: 12 }} />
              <Bar dataKey="active_members" fill="var(--primary)" radius={[4, 4, 0, 0]} name="Active Members" />
            </BarChart>
          </ResponsiveContainer>
        </div>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '0.9fr 1.1fr', gap: '20px' }}>
        <div style={chartContainerStyle}>
          <h3 style={{ margin: '0 0 16px', fontSize: '15px', fontWeight: '600' }}>Pharmacy Adherence Breakdown</h3>
          <ResponsiveContainer width="100%" height={260}>
            <BarChart data={overview?.pharmacy_breakdown || []}>
              <CartesianGrid strokeDasharray="3 3" stroke="#f1f5f9" />
              <XAxis dataKey="pharmacy_name" tick={{ fontSize: 10, fill: '#64748b' }} interval={0} angle={-18} textAnchor="end" height={70} />
              <YAxis tick={{ fontSize: 11, fill: '#64748b' }} />
              <Tooltip contentStyle={{ fontSize: 12 }} />
              <Bar dataKey="avg_adherence" fill="#0f766e" radius={[4, 4, 0, 0]} name="Avg Adherence %" />
            </BarChart>
          </ResponsiveContainer>
        </div>

        <div style={chartContainerStyle}>
          <h3 style={{ margin: '0 0 16px', fontSize: '15px', fontWeight: '600' }}>Analysis & Suggestions</h3>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
            {(overview?.suggestions || []).length > 0 ? (
              overview.suggestions.map((suggestion, index) => (
                <div key={index} style={insightStyle}>
                  <p style={{ margin: 0, fontSize: '14px', color: 'var(--text)', lineHeight: 1.5 }}>{suggestion}</p>
                </div>
              ))
            ) : (
              <div style={insightStyle}>
                <p style={{ margin: 0, fontSize: '14px', color: '#64748b' }}>No medication risk suggestions right now.</p>
              </div>
            )}

            <div style={{ ...insightStyle, background: '#fff7ed', borderColor: '#fed7aa' }}>
              <p style={{ margin: 0, fontSize: '13px', color: '#9a3412', lineHeight: 1.5 }}>
                {summary.media_attachments ?? 0} active medication records include uploaded media. Review unclear scripts and member-submitted evidence from the member detail pages.
              </p>
            </div>
          </div>
        </div>
      </div>

      <div style={chartContainerStyle}>
        <h3 style={{ margin: '0 0 16px', fontSize: '15px', fontWeight: '600' }}>Adherence by Condition</h3>
        <ResponsiveContainer width="100%" height={260}>
          <BarChart data={overview?.adherence_by_condition || []}>
            <CartesianGrid strokeDasharray="3 3" stroke="#f1f5f9" />
            <XAxis dataKey="condition_name" tick={{ fontSize: 10, fill: '#64748b' }} interval={0} angle={-18} textAnchor="end" height={70} />
            <YAxis tick={{ fontSize: 11, fill: '#64748b' }} domain={[0, 100]} />
            <Tooltip contentStyle={{ fontSize: 12 }} formatter={(v) => [`${v}%`, 'Avg Adherence']} />
            <Bar dataKey="avg_adherence" fill="#6366f1" radius={[4, 4, 0, 0]} name="Avg Adherence %" />
          </BarChart>
        </ResponsiveContainer>
      </div>

      <div style={chartContainerStyle}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: '12px', flexWrap: 'wrap', marginBottom: '16px' }}>
          <div>
            <h3 style={{ margin: 0, fontSize: '15px', fontWeight: '600' }}>Upcoming Refills — Next 30 Days</h3>
            <p style={{ margin: '4px 0 0', fontSize: '13px', color: '#64748b' }}>Active prescriptions with a scheduled refill date in the next 30 days.</p>
          </div>
        </div>
        {(overview?.upcoming_refills || []).length === 0 ? (
          <p style={{ color: '#94a3b8', fontSize: '14px', margin: 0 }}>No refills scheduled in the next 30 days.</p>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
            {(() => {
              const grouped = (overview?.upcoming_refills || []).reduce((acc, r) => {
                const dateKey = new Date(r.next_refill_date).toLocaleDateString('en-UG', { weekday: 'short', day: '2-digit', month: 'short', year: 'numeric' });
                if (!acc[dateKey]) acc[dateKey] = [];
                acc[dateKey].push(r);
                return acc;
              }, {});
              return Object.entries(grouped).map(([date, items]) => (
                <div key={date} style={{ display: 'flex', gap: '12px', alignItems: 'flex-start' }}>
                  <div style={{ minWidth: '130px', fontSize: '12px', fontWeight: '600', color: '#475569', paddingTop: '8px', borderRight: '2px solid #e2e8f0', paddingRight: '12px' }}>{date}</div>
                  <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: '6px' }}>
                    {items.map((item) => (
                      <div key={item.assignment_id} style={{ background: '#f0fdf4', border: '1px solid #bbf7d0', borderRadius: '8px', padding: '8px 14px', display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '8px' }}>
                        <div>
                          <span style={{ fontWeight: '600', fontSize: '13px', color: 'var(--text)' }}>{item.member_name}</span>
                          <span style={{ fontSize: '12px', color: '#64748b' }}> · {item.medication_name}</span>
                        </div>
                        <span style={{ fontSize: '12px', color: '#64748b' }}>🏪 {item.pharmacy_name}</span>
                      </div>
                    ))}
                  </div>
                </div>
              ));
            })()}
          </div>
        )}
      </div>

      <div style={chartContainerStyle}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: '12px', flexWrap: 'wrap', marginBottom: '16px' }}>
          <div>
            <h3 style={{ margin: 0, fontSize: '15px', fontWeight: '600' }}>Members Needing Attention</h3>
            <p style={{ margin: '4px 0 0', fontSize: '13px', color: '#64748b' }}>Refill pressure, low adherence, and missing pharmacy linkage.</p>
          </div>
        </div>
        <Table columns={riskColumns} data={overview?.risk_flags || []} emptyMessage="No medication risks flagged." />
      </div>

      <div style={chartContainerStyle}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: '12px', flexWrap: 'wrap', marginBottom: '16px' }}>
          <div>
            <h3 style={{ margin: 0, fontSize: '15px', fontWeight: '600' }}>Active & Recent Medication Assignments</h3>
            <p style={{ margin: '4px 0 0', fontSize: '13px', color: '#64748b' }}>Recent prescriptions, refill tracking, reminder state, and media evidence.</p>
          </div>
          <div style={{ display: 'flex', gap: '8px', alignItems: 'center', flexWrap: 'wrap' }}>
            <input
              value={assignmentFilter}
              onChange={(event) => setAssignmentFilter(event.target.value)}
              placeholder="Filter assignments…"
              style={{ minWidth: '220px', padding: '8px 12px', borderRadius: '6px', border: '1px solid #e2e8f0', fontSize: '14px' }}
            />
            <Button variant="secondary" onClick={exportAssignmentsCSV}>
              <ArrowDownTrayIcon style={{ width: 15, height: 15 }} /> Export CSV
            </Button>
          </div>
        </div>
        <Table columns={assignmentColumns} data={filteredAssignments} emptyMessage="No medication assignments found." />
      </div>

      <div style={chartContainerStyle}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: '12px', flexWrap: 'wrap', marginBottom: '16px' }}>
          <h3 style={{ margin: 0, fontSize: '15px', fontWeight: '600' }}>Medication Catalogue</h3>
          <div style={{ display: 'flex', gap: '8px', alignItems: 'center', flexWrap: 'wrap' }}>
            <select
              value={catalogueConditionFilter}
              onChange={(e) => { setCatalogueConditionFilter(e.target.value); setCataloguePage(1); }}
              style={{ padding: '8px 12px', borderRadius: '6px', border: '1px solid #e2e8f0', fontSize: '14px', background: '#fff' }}
            >
              <option value="">All Conditions</option>
              {conditions.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
            </select>
            <input
              value={catalogueSearch}
              onChange={(e) => { setCatalogueSearch(e.target.value); setCataloguePage(1); }}
              placeholder="Search catalogue…"
              style={{ minWidth: '200px', padding: '8px 12px', borderRadius: '6px', border: '1px solid #e2e8f0', fontSize: '14px' }}
            />
          </div>
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(240px, 1fr))', gap: '12px' }}>
          {cataloguePageItems.map((med) => (
            <div key={med.id} style={{ border: '1px solid #e2e8f0', borderRadius: '12px', padding: '14px', background: '#f8fafc', display: 'flex', flexDirection: 'column', gap: '6px' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
                <p style={{ margin: 0, fontSize: '14px', fontWeight: '600', color: 'var(--text)' }}>{med.name}</p>
                <button
                  type="button"
                  onClick={() => {
                    setEditingMedication(med);
                    editForm.reset({
                      name: med.name,
                      generic_name: med.generic_name || '',
                      condition_id: med.condition_id || '',
                      dosage_options: Array.isArray(med.dosage_options) ? med.dosage_options.join(', ') : (med.dosage_options || ''),
                      frequency_options: Array.isArray(med.frequency_options) ? med.frequency_options.join(', ') : (med.frequency_options || ''),
                      interactions: Array.isArray(med.interactions) ? med.interactions.join(', ') : (med.interactions || ''),
                      notes: med.notes || '',
                    });
                    setShowEditModal(true);
                  }}
                  style={{ background: '#eff6ff', border: '1px solid #bfdbfe', borderRadius: '6px', cursor: 'pointer', color: '#1d4ed8', padding: '4px 10px', fontSize: '12px', fontWeight: '600', display: 'flex', alignItems: 'center', gap: '4px' }}
                  title="Edit medication"
                >
                  <PencilSquareIcon style={{ width: 13, height: 13 }} /> Edit
                </button>
              </div>
              <p style={{ margin: 0, fontSize: '12px', color: '#64748b' }}>{med.generic_name || '—'}</p>
              {med.condition_name && (
                <span style={{ display: 'inline-block', fontSize: '11px', background: '#eff6ff', color: '#1d4ed8', borderRadius: '6px', padding: '2px 8px', width: 'fit-content' }}>
                  {med.condition_name}
                </span>
              )}
              {(med.dosage_options?.length > 0) && (
                <p style={{ margin: 0, fontSize: '11px', color: '#94a3b8' }}>
                  Doses: {Array.isArray(med.dosage_options) ? med.dosage_options.join(', ') : med.dosage_options}
                </p>
              )}
              <p style={{ margin: 0, fontSize: '12px', color: med.active_members > 0 ? '#0f766e' : '#94a3b8', fontWeight: med.active_members > 0 ? '600' : '400' }}>
                {med.active_members ?? 0} active member{med.active_members !== 1 ? 's' : ''}
              </p>
            </div>
          ))}
          {cataloguePageItems.length === 0 && (
            <p style={{ color: '#94a3b8', fontSize: '14px', gridColumn: '1/-1' }}>No medications match your search.</p>
          )}
        </div>
        {catalogueTotalPages > 1 && (
          <div style={{ display: 'flex', justifyContent: 'center', gap: '8px', marginTop: '16px' }}>
            <button
              type="button"
              disabled={cataloguePage === 1}
              onClick={() => setCataloguePage((p) => p - 1)}
              style={{ padding: '6px 14px', borderRadius: '6px', border: '1px solid #e2e8f0', background: cataloguePage === 1 ? '#f8fafc' : '#fff', cursor: cataloguePage === 1 ? 'default' : 'pointer', fontSize: '13px' }}
            >
              ← Prev
            </button>
            <span style={{ padding: '6px 12px', fontSize: '13px', color: '#64748b' }}>
              Page {cataloguePage} of {catalogueTotalPages}
            </span>
            <button
              type="button"
              disabled={cataloguePage === catalogueTotalPages}
              onClick={() => setCataloguePage((p) => p + 1)}
              style={{ padding: '6px 14px', borderRadius: '6px', border: '1px solid #e2e8f0', background: cataloguePage === catalogueTotalPages ? '#f8fafc' : '#fff', cursor: cataloguePage === catalogueTotalPages ? 'default' : 'pointer', fontSize: '13px' }}
            >
              Next →
            </button>
          </div>
        )}
      </div>

      {showCreateModal && (
        <Modal title="Add Medication to Catalogue" onClose={() => setShowCreateModal(false)} width="720px">
          <form onSubmit={medicationForm.handleSubmit(onCreateMedication)} style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '14px' }}>
            <div style={{ gridColumn: '1 / -1' }}>
              <Input label="Medication Name *" name="name" register={medicationForm.register} error={medicationForm.formState.errors.name} placeholder="e.g. Metformin 500mg" />
            </div>
            <Input label="Generic Name" name="generic_name" register={medicationForm.register} placeholder="e.g. Metformin" />
            <Select
              label="Condition"
              name="condition_id"
              register={medicationForm.register}
              options={conditions.map((condition) => ({ value: condition.id, label: condition.name }))}
              placeholder="Select condition"
            />
            <Input label="Dosage Options" name="dosage_options" register={medicationForm.register} placeholder="250mg, 500mg, 1g" />
            <Input label="Frequency Options" name="frequency_options" register={medicationForm.register} placeholder="Once daily, Twice daily" />
            <div style={{ gridColumn: '1 / -1' }}>
              <Input label="Interactions" name="interactions" register={medicationForm.register} placeholder="Alcohol, NSAIDs, Insulin" />
            </div>
            <div style={{ gridColumn: '1 / -1' }}>
              <Input label="Notes" name="notes" register={medicationForm.register} placeholder="Clinical guidance or counselling notes" />
            </div>
            <div style={{ gridColumn: '1 / -1', display: 'flex', justifyContent: 'flex-end', gap: '8px' }}>
              <Button variant="secondary" type="button" onClick={() => setShowCreateModal(false)}>Cancel</Button>
              <Button variant="primary" type="submit" disabled={createMutation.isPending}>
                {createMutation.isPending ? 'Saving…' : 'Add Medication'}
              </Button>
            </div>
          </form>
        </Modal>
      )}

      {showAssignModal && (
        <Modal title="Assign Medication to Member" onClose={() => setShowAssignModal(false)} width="760px">
          <form onSubmit={assignmentForm.handleSubmit(onAssignMedication)} style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '14px' }}>
            <div style={{ gridColumn: '1 / -1', display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '14px' }}>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                <label style={{ fontSize: '13px', fontWeight: '500', color: '#475569' }}>Member *</label>
                <input
                  value={memberSearch}
                  onChange={(event) => setMemberSearch(event.target.value)}
                  placeholder="Search member by name or member number"
                  style={{ padding: '8px 12px', borderRadius: '6px', border: '1px solid #e2e8f0', fontSize: '14px' }}
                />
                {selectedMember && (
                  <div style={{ fontSize: '12px', color: 'var(--primary)', fontWeight: '600' }}>
                    Selected: {selectedMember.first_name} {selectedMember.last_name} ({selectedMember.member_number})
                  </div>
                )}
                <div style={{ maxHeight: '140px', overflowY: 'auto', border: memberSearch.trim().length >= 2 ? '1px solid #e2e8f0' : 'none', borderRadius: '8px' }}>
                  {membersSearching ? <Spinner size={20} /> : members.map((member) => (
                    <button
                      key={member.id}
                      type="button"
                      onClick={() => {
                        setSelectedMember(member);
                        setMemberSearch(`${member.first_name} ${member.last_name} (${member.member_number})`);
                      }}
                      style={{ width: '100%', textAlign: 'left', border: 'none', background: '#fff', padding: '10px 12px', cursor: 'pointer', borderBottom: '1px solid #f1f5f9' }}
                    >
                      <div style={{ fontWeight: '600', color: 'var(--text)' }}>{member.first_name} {member.last_name}</div>
                      <div style={{ fontSize: '12px', color: '#64748b' }}>{member.member_number}</div>
                    </button>
                  ))}
                </div>
              </div>

              <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                <label style={{ fontSize: '13px', fontWeight: '500', color: '#475569' }}>Medication *</label>
                <input
                  value={medicationSearch}
                  onChange={(event) => setMedicationSearch(event.target.value)}
                  placeholder="Search existing medications"
                  style={{ padding: '8px 12px', borderRadius: '6px', border: '1px solid #e2e8f0', fontSize: '14px' }}
                />
                {selectedMedication && (
                  <div style={{ fontSize: '12px', color: 'var(--primary)', fontWeight: '600' }}>
                    Selected: {selectedMedication.name}
                  </div>
                )}
                <div style={{ maxHeight: '140px', overflowY: 'auto', border: medicationSearch.trim().length >= 2 ? '1px solid #e2e8f0' : 'none', borderRadius: '8px' }}>
                  {medicationsSearching ? <Spinner size={20} /> : medicationOptions.map((medication) => (
                    <button
                      key={medication.id}
                      type="button"
                      onClick={() => {
                        setSelectedMedication(medication);
                        setMedicationSearch(medication.name);
                      }}
                      style={{ width: '100%', textAlign: 'left', border: 'none', background: '#fff', padding: '10px 12px', cursor: 'pointer', borderBottom: '1px solid #f1f5f9' }}
                    >
                      <div style={{ fontWeight: '600', color: 'var(--text)' }}>{medication.name}</div>
                      <div style={{ fontSize: '12px', color: '#64748b' }}>{medication.generic_name || medication.condition_name || 'Catalogue medication'}</div>
                    </button>
                  ))}
                </div>
              </div>
            </div>
            <Input label="Dosage" name="dosage" register={assignmentForm.register} placeholder="e.g. 500mg" />
            <Input label="Frequency" name="frequency" register={assignmentForm.register} placeholder="e.g. Twice daily" />
            <Input label="Start Date" name="start_date" type="date" register={assignmentForm.register} />
            <Input label="End Date" name="end_date" type="date" register={assignmentForm.register} />
            <Input label="Start Time" name="start_time" type="time" register={assignmentForm.register} />
            <Select
              label="Pharmacy"
              name="pharmacy_id"
              register={assignmentForm.register}
              options={pharmacies.map((pharmacy) => ({ value: pharmacy.id, label: pharmacy.name }))}
              placeholder="Optional pharmacy"
            />
            <Input label="Refill Interval (days)" name="refill_interval_days" type="number" register={assignmentForm.register} placeholder="30" />
            <div style={{ gridColumn: '1 / -1', border: '1px dashed #cbd5e1', borderRadius: '12px', padding: '14px', background: '#f8fafc' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '10px', color: '#475569', fontWeight: '600', fontSize: '14px' }}>
                <PaperClipIcon style={{ width: 16, height: 16 }} />
                Attach patient-facing instructions
              </div>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
                <Input label="Prescription / PDF" name="prescription" type="file" register={assignmentForm.register} />
                <Input label="Photo / Image" name="photo" type="file" register={assignmentForm.register} />
                <Input label="Audio Instructions" name="audio" type="file" register={assignmentForm.register} />
                <Input label="Video Instructions" name="video" type="file" register={assignmentForm.register} />
              </div>
            </div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginTop: '24px' }}>
              <input type="checkbox" id="medication-reminder-enabled" {...assignmentForm.register('reminder_enabled')} style={{ width: 16, height: 16 }} />
              <label htmlFor="medication-reminder-enabled" style={{ fontSize: '14px', color: 'var(--text)' }}>Enable reminders</label>
            </div>
            <div style={{ gridColumn: '1 / -1', display: 'flex', justifyContent: 'flex-end', gap: '8px' }}>
              <Button variant="secondary" type="button" onClick={() => setShowAssignModal(false)}>Cancel</Button>
              <Button variant="primary" type="submit" disabled={assignMutation.isPending}>
                {assignMutation.isPending ? 'Assigning…' : 'Assign Medication'}
              </Button>
            </div>
          </form>
        </Modal>
      )}

      {showEditModal && editingMedication && (
        <Modal title="Edit Medication" onClose={() => { setShowEditModal(false); setEditingMedication(null); }} width="720px">
          <form onSubmit={editForm.handleSubmit((data) => editMutation.mutate({ id: editingMedication.id, ...data, dosage_options: data.dosage_options ? data.dosage_options.split(',').map((s) => s.trim()).filter(Boolean) : [], frequency_options: data.frequency_options ? data.frequency_options.split(',').map((s) => s.trim()).filter(Boolean) : [], interactions: data.interactions ? data.interactions.split(',').map((s) => s.trim()).filter(Boolean) : [] }))} style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '14px' }}>
            <div style={{ gridColumn: '1 / -1' }}>
              <Input label="Medication Name *" name="name" register={editForm.register} error={editForm.formState.errors.name} />
            </div>
            <Input label="Generic Name" name="generic_name" register={editForm.register} />
            <Select
              label="Condition"
              name="condition_id"
              register={editForm.register}
              options={conditions.map((c) => ({ value: c.id, label: c.name }))}
              placeholder="Select condition"
            />
            <Input label="Dosage Options (comma-separated)" name="dosage_options" register={editForm.register} placeholder="250mg, 500mg" />
            <Input label="Frequency Options (comma-separated)" name="frequency_options" register={editForm.register} placeholder="Once daily, Twice daily" />
            <div style={{ gridColumn: '1 / -1' }}>
              <Input label="Interactions (comma-separated)" name="interactions" register={editForm.register} placeholder="Alcohol, NSAIDs" />
            </div>
            <div style={{ gridColumn: '1 / -1' }}>
              <Input label="Notes" name="notes" register={editForm.register} />
            </div>
            <div style={{ gridColumn: '1 / -1', display: 'flex', justifyContent: 'flex-end', gap: '8px' }}>
              <Button variant="secondary" type="button" onClick={() => { setShowEditModal(false); setEditingMedication(null); }}>Cancel</Button>
              <Button variant="primary" type="submit" disabled={editMutation.isPending}>
                {editMutation.isPending ? 'Saving…' : 'Save Changes'}
              </Button>
            </div>
          </form>
        </Modal>
      )}

      {showRefillModal && refillAssignment && (
        <Modal title="Update Refill Date" onClose={() => { setShowRefillModal(false); setRefillAssignment(null); }} width="480px">
          <form onSubmit={refillForm.handleSubmit((data) => updateRefillMutation.mutate({ id: refillAssignment.id, ...data }))} style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
            <p style={{ margin: 0, fontSize: '14px', color: '#64748b' }}>
              Updating refill for <strong>{refillAssignment.medication_name}</strong> — {refillAssignment.member_name}
            </p>
            <Input label="Next Refill Date *" name="next_refill_date" type="date" register={refillForm.register} />
            <Input label="Refill Interval (days)" name="refill_interval_days" type="number" register={refillForm.register} placeholder="30" />
            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '8px' }}>
              <Button variant="secondary" type="button" onClick={() => { setShowRefillModal(false); setRefillAssignment(null); }}>Cancel</Button>
              <Button variant="primary" type="submit" disabled={updateRefillMutation.isPending}>
                {updateRefillMutation.isPending ? 'Saving…' : 'Update Refill'}
              </Button>
            </div>
          </form>
        </Modal>
      )}

      {showLogsModal && logsAssignment && (
        <Modal title="Dose Log History" onClose={() => { setShowLogsModal(false); setLogsAssignment(null); }} width="640px">
          <p style={{ margin: '0 0 14px', fontSize: '14px', color: '#64748b' }}>
            Last 60 dose records for <strong>{logsAssignment.medication_name}</strong> — {logsAssignment.member_name}
          </p>
          {doseLogsLoading ? <Spinner /> : (doseLogsData || []).length === 0 ? (
            <p style={{ color: '#94a3b8', fontSize: '14px' }}>No dose logs recorded yet for this prescription.</p>
          ) : (
            <div style={{ maxHeight: '440px', overflowY: 'auto' }}>
              <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '13px' }}>
                <thead>
                  <tr style={{ background: '#f8fafc', borderBottom: '1px solid #e2e8f0' }}>
                    <th style={{ textAlign: 'left', padding: '10px 12px', color: '#475569', fontWeight: '600' }}>Scheduled</th>
                    <th style={{ textAlign: 'left', padding: '10px 12px', color: '#475569', fontWeight: '600' }}>Status</th>
                    <th style={{ textAlign: 'left', padding: '10px 12px', color: '#475569', fontWeight: '600' }}>Taken At</th>
                    <th style={{ textAlign: 'left', padding: '10px 12px', color: '#475569', fontWeight: '600' }}>Notes</th>
                  </tr>
                </thead>
                <tbody>
                  {(doseLogsData || []).map((log) => (
                    <tr key={log.id} style={{ borderBottom: '1px solid #f1f5f9' }}>
                      <td style={{ padding: '10px 12px', color: '#64748b' }}>{formatDate(log.scheduled_time)}</td>
                      <td style={{ padding: '10px 12px' }}>
                        <Badge
                          status={log.status === 'taken' ? 'confirmed' : 'pending'}
                          label={log.status === 'taken' ? 'Taken' : 'Skipped'}
                        />
                      </td>
                      <td style={{ padding: '10px 12px', color: '#64748b' }}>{log.taken_at ? formatDate(log.taken_at) : '—'}</td>
                      <td style={{ padding: '10px 12px', color: '#64748b' }}>{log.notes || '—'}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </Modal>
      )}

      {showMediaModal && mediaAssignment && (
        <Modal title="Attached Media" onClose={() => { setShowMediaModal(false); setMediaAssignment(null); }} width="600px">
          <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
            <p style={{ margin: 0, fontSize: '14px', color: '#64748b' }}>
              Media for <strong>{mediaAssignment.medication_name}</strong> — {mediaAssignment.member_name}
            </p>
            {mediaAssignment.prescription_file_url && (
              <div>
                <p style={{ margin: '0 0 6px', fontSize: '13px', fontWeight: '600', color: '#475569' }}>Prescription / PDF</p>
                <a href={`${API_BASE}${mediaAssignment.prescription_file_url}`} target="_blank" rel="noreferrer"
                  style={{ color: 'var(--primary)', fontSize: '14px' }}>
                  📄 View Prescription
                </a>
              </div>
            )}
            {mediaAssignment.photo_url && (
              <div>
                <p style={{ margin: '0 0 6px', fontSize: '13px', fontWeight: '600', color: '#475569' }}>Photo</p>
                <img src={`${API_BASE}${mediaAssignment.photo_url}`} alt="Medication" style={{ maxWidth: '100%', borderRadius: '8px', border: '1px solid #e2e8f0' }} />
              </div>
            )}
            {mediaAssignment.audio_url && (
              <div>
                <p style={{ margin: '0 0 6px', fontSize: '13px', fontWeight: '600', color: '#475569' }}>Audio Instructions</p>
                <audio controls src={`${API_BASE}${mediaAssignment.audio_url}`} style={{ width: '100%' }} />
              </div>
            )}
            {mediaAssignment.video_url && (
              <div>
                <p style={{ margin: '0 0 6px', fontSize: '13px', fontWeight: '600', color: '#475569' }}>Video Instructions</p>
                <video controls src={`${API_BASE}${mediaAssignment.video_url}`} style={{ maxWidth: '100%', borderRadius: '8px' }} />
              </div>
            )}
          </div>
        </Modal>
      )}

      {showAssignEditModal && editingAssignment && (
        <Modal title="Edit Medication Assignment" onClose={() => { setShowAssignEditModal(false); setEditingAssignment(null); }} width="600px">
          <div style={{ marginBottom: '16px', padding: '12px 16px', background: '#f8fafc', borderRadius: '10px', border: '1px solid #e2e8f0' }}>
            <p style={{ margin: 0, fontSize: '13px', color: '#475569' }}>
              <strong>Member:</strong> {editingAssignment.member_name} ({editingAssignment.member_number || '—'})
            </p>
            <p style={{ margin: '4px 0 0', fontSize: '13px', color: '#475569' }}>
              <strong>Medication:</strong> {editingAssignment.medication_name} {editingAssignment.generic_name ? `(${editingAssignment.generic_name})` : ''}
            </p>
            {editingAssignment.edited_by_name && (
              <p style={{ margin: '4px 0 0', fontSize: '12px', color: '#94a3b8' }}>
                Last edited by: <strong>{editingAssignment.edited_by_name}</strong>
                {editingAssignment.edit_note ? ` — ${editingAssignment.edit_note}` : ''}
              </p>
            )}
          </div>
          <form onSubmit={assignEditForm.handleSubmit((data) => assignEditMutation.mutate({ id: editingAssignment.id, ...data }))} style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '14px' }}>
            <Input label="Dosage" name="dosage" register={assignEditForm.register} placeholder="e.g. 500mg" />
            <Input label="Frequency" name="frequency" register={assignEditForm.register} placeholder="e.g. Twice daily" />
            <Input label="Next Refill Date" name="next_refill_date" type="date" register={assignEditForm.register} />
            <Input label="Refill Interval (days)" name="refill_interval_days" type="number" register={assignEditForm.register} />
            <div style={{ gridColumn: '1 / -1' }}>
              <label style={{ display: 'flex', alignItems: 'center', gap: '8px', fontSize: '13px', fontWeight: '600', color: '#374151', cursor: 'pointer' }}>
                <input type="checkbox" {...assignEditForm.register('reminder_enabled')} style={{ width: '16px', height: '16px' }} />
                Reminders Enabled
              </label>
            </div>
            <div style={{ gridColumn: '1 / -1' }}>
              <label style={{ display: 'block', fontSize: '13px', fontWeight: '600', color: '#374151', marginBottom: '6px' }}>Notes</label>
              <textarea {...assignEditForm.register('notes')} rows={3} style={{ width: '100%', boxSizing: 'border-box', padding: '10px 12px', border: '1.5px solid #e2e8f0', borderRadius: '8px', fontSize: '13px', resize: 'vertical' }} />
            </div>
            <div style={{ gridColumn: '1 / -1' }}>
              <label style={{ display: 'block', fontSize: '13px', fontWeight: '600', color: '#374151', marginBottom: '6px' }}>Edit Note (reason for change)</label>
              <input {...assignEditForm.register('edit_note')} placeholder="e.g. Adjusted dosage per doctor recommendation" style={{ width: '100%', boxSizing: 'border-box', padding: '10px 12px', border: '1.5px solid #e2e8f0', borderRadius: '8px', fontSize: '13px' }} />
            </div>
            <div style={{ gridColumn: '1 / -1', display: 'flex', justifyContent: 'flex-end', gap: '10px', marginTop: '8px' }}>
              <Button variant="secondary" type="button" onClick={() => { setShowAssignEditModal(false); setEditingAssignment(null); }}>Cancel</Button>
              <Button type="submit" loading={assignEditMutation.isPending}>Save Changes</Button>
            </div>
          </form>
        </Modal>
      )}
    </div>
  );
}
