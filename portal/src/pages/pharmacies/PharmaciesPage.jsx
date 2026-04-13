import { useState } from 'react';
import { useForm } from 'react-hook-form';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import toast from 'react-hot-toast';
import {
  BuildingStorefrontIcon,
  HeartIcon,
  ClipboardDocumentCheckIcon,
  ArrowPathIcon,
  PlusIcon,
  PencilIcon,
  TrashIcon,
} from '@heroicons/react/24/outline';
import {
  getPharmacyMetrics,
  createPharmacy,
  updatePharmacy,
  deletePharmacy,
} from '../../api/pharmacies';
import StatCard from '../../components/UI/StatCard';
import Table from '../../components/UI/Table';
import Button from '../../components/UI/Button';
import Modal from '../../components/UI/Modal';
import Spinner from '../../components/UI/Spinner';
import Input from '../../components/UI/Input';
import Badge from '../../components/UI/Badge';

const formatPercent = (value) => `${Number(value || 0).toFixed(1)}%`;
const formatDateTime = (value) => (
  value
    ? new Date(value).toLocaleString('en-UG', {
      day: '2-digit',
      month: 'short',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    })
    : '—'
);

export default function PharmaciesPage() {
  const qc = useQueryClient();
  const [search, setSearch] = useState('');
  const [showModal, setShowModal] = useState(false);
  const [editing, setEditing] = useState(null);

  const { register, handleSubmit, reset, formState: { errors } } = useForm();

  const { data, isLoading } = useQuery({
    queryKey: ['pharmacy-metrics', search],
    queryFn: () => getPharmacyMetrics({ search }).then((r) => r.data),
    retry: false,
    placeholderData: { summary: {}, pharmacies: [] },
  });

  const saveMutation = useMutation({
    mutationFn: (payload) => (editing ? updatePharmacy(editing.id, payload) : createPharmacy(payload)),
    onSuccess: () => {
      qc.invalidateQueries(['pharmacy-metrics']);
      toast.success(editing ? 'Pharmacy updated' : 'Pharmacy added');
      setShowModal(false);
      setEditing(null);
      reset();
    },
    onError: (error) => toast.error(error.response?.data?.message || 'Failed to save pharmacy'),
  });

  const deleteMutation = useMutation({
    mutationFn: deletePharmacy,
    onSuccess: () => {
      qc.invalidateQueries(['pharmacy-metrics']);
      toast.success('Pharmacy removed');
    },
    onError: () => toast.error('Failed to remove pharmacy'),
  });

  const openAdd = () => {
    setEditing(null);
    reset();
    setShowModal(true);
  };

  const openEdit = (pharmacy) => {
    setEditing(pharmacy);
    reset({
      name: pharmacy.name,
      city: pharmacy.city,
      address: pharmacy.address,
      phone: pharmacy.phone,
      email: pharmacy.email,
      contact_person: pharmacy.contact_person,
      working_hours: pharmacy.working_hours,
    });
    setShowModal(true);
  };

  const summary = data?.summary || {};
  const pharmacies = data?.pharmacies || [];

  const columns = [
    {
      key: 'name',
      header: 'Pharmacy',
      render: (_, row) => (
        <div>
          <div style={{ fontWeight: '600', color: 'var(--text)' }}>{row.name}</div>
          <div style={{ fontSize: '12px', color: '#64748b' }}>{row.city || '—'}</div>
        </div>
      ),
    },
    { key: 'members_served', header: 'Members' },
    { key: 'active_prescriptions', header: 'Active Scripts' },
    { key: 'refills_due_7d', header: 'Due in 7 Days' },
    {
      key: 'avg_adherence',
      header: 'Adherence',
      render: (value) => formatPercent(value),
    },
    {
      key: 'approval_rate',
      header: 'Approval Rate',
      render: (value) => formatPercent(value),
    },
    {
      key: 'pending_authorizations',
      header: 'Pending Auths',
      render: (value) => (
        <Badge
          status={Number(value) > 0 ? 'pending' : 'active'}
          label={value}
        />
      ),
    },
    {
      key: 'last_assignment_at',
      header: 'Last Linked',
      render: (value) => formatDateTime(value),
    },
    {
      key: 'actions',
      header: 'Actions',
      render: (_, row) => (
        <div style={{ display: 'flex', gap: '6px' }}>
          <Button variant="ghost" onClick={() => openEdit(row)} style={{ padding: '4px 8px', fontSize: '12px' }}>
            <PencilIcon style={{ width: 13, height: 13 }} /> Edit
          </Button>
          <Button
            variant="danger"
            onClick={() => {
              if (window.confirm(`Remove ${row.name}?`)) {
                deleteMutation.mutate(row.id);
              }
            }}
            style={{ padding: '4px 8px', fontSize: '12px' }}
          >
            <TrashIcon style={{ width: 13, height: 13 }} /> Delete
          </Button>
        </div>
      ),
    },
  ];

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(210px, 1fr))', gap: '16px' }}>
        <StatCard title="Total Pharmacies" value={summary.total_pharmacies ?? 0} icon={BuildingStorefrontIcon} color="var(--primary)" variant="label" />
        <StatCard title="Members Served" value={summary.members_served ?? 0} icon={HeartIcon} color="var(--accent)" variant="label" />
        <StatCard title="Pending Authorizations" value={summary.pending_authorizations ?? 0} icon={ClipboardDocumentCheckIcon} color="#f59e0b" variant="label" />
        <StatCard title="Refills Due in 7 Days" value={summary.refills_due_7d ?? 0} icon={ArrowPathIcon} color="#0ea5e9" variant="label" />
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(210px, 1fr))', gap: '16px' }}>
        <StatCard title="Average Adherence" value={formatPercent(summary.avg_adherence)} color="var(--primary)" variant="label" />
        <StatCard title="Approval Rate" value={formatPercent(summary.approval_rate)} color="var(--accent)" variant="label" />
        <StatCard title="Active Prescriptions" value={summary.active_prescriptions ?? 0} color="#f59e0b" variant="label" />
        <StatCard title="Engaged Pharmacies" value={summary.engaged_pharmacies ?? 0} color="#0f766e" variant="label" />
      </div>

      <div style={{ display: 'flex', gap: '12px', alignItems: 'center' }}>
        <input
          placeholder="Search pharmacies by name, city, or address…"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          style={{ flex: 1, padding: '8px 12px', borderRadius: '6px', border: '1px solid #e2e8f0', fontSize: '14px' }}
        />
        <Button variant="primary" onClick={openAdd}>
          <PlusIcon style={{ width: 15, height: 15 }} /> Add Pharmacy
        </Button>
      </div>

      <div style={{ background: '#fff', borderRadius: '12px', boxShadow: '0 1px 4px rgba(0,0,0,0.07)', overflow: 'hidden' }}>
        {isLoading ? <Spinner /> : <Table columns={columns} data={pharmacies} emptyMessage="No pharmacies found." />}
      </div>

      {showModal && (
        <Modal
          title={editing ? 'Edit Pharmacy' : 'Add Pharmacy'}
          onClose={() => {
            setShowModal(false);
            setEditing(null);
            reset();
          }}
          width="680px"
        >
          <form onSubmit={handleSubmit((payload) => saveMutation.mutate(payload))} style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '14px' }}>
            <div style={{ gridColumn: '1 / -1' }}>
              <Input label="Pharmacy Name *" name="name" register={register} error={errors.name} placeholder="e.g. CityCare Pharmacy" />
            </div>
            <Input label="City *" name="city" register={register} error={errors.city} placeholder="e.g. Kampala" />
            <Input label="Phone" name="phone" register={register} placeholder="0700 123456" />
            <Input label="Email" name="email" type="email" register={register} placeholder="info@pharmacy.ug" />
            <Input label="Contact Person" name="contact_person" register={register} placeholder="Pharmacist or manager" />
            <Input label="Working Hours" name="working_hours" register={register} placeholder="Mon-Sat 08:00-20:00" />
            <div style={{ gridColumn: '1 / -1' }}>
              <Input label="Address" name="address" register={register} placeholder="Street address" />
            </div>
            <div style={{ gridColumn: '1 / -1', display: 'flex', gap: '8px', justifyContent: 'flex-end' }}>
              <Button variant="secondary" type="button" onClick={() => { setShowModal(false); setEditing(null); reset(); }}>
                Cancel
              </Button>
              <Button variant="primary" type="submit" disabled={saveMutation.isPending}>
                {saveMutation.isPending ? 'Saving…' : editing ? 'Save Changes' : 'Add Pharmacy'}
              </Button>
            </div>
          </form>
        </Modal>
      )}
    </div>
  );
}
