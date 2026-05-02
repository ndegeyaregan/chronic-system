import { useState } from 'react';
import { useForm } from 'react-hook-form';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import toast from 'react-hot-toast';
import { PlusIcon, PencilIcon, TrashIcon } from '@heroicons/react/24/outline';
import {
  getInstitutions,
  createInstitution,
  suspendInstitution,
  unsuspendInstitution,
  deleteInstitution,
} from '../../api/hospitals';
import Table from '../../components/UI/Table';
import Badge from '../../components/UI/Badge';
import Button from '../../components/UI/Button';
import Modal from '../../components/UI/Modal';
import Spinner from '../../components/UI/Spinner';
import Input from '../../components/UI/Input';
import Select from '../../components/UI/Select';

const CATEGORIES = [
  { value: 'outpatient', label: 'Outpatient' },
  { value: 'inpatient', label: 'Inpatient' },
  { value: 'pharmacy', label: 'Pharmacy' },
  { value: 'dental', label: 'Dental' },
  { value: 'optical', label: 'Optical' },
];

export default function InstitutionsPage() {
  const qc = useQueryClient();
  const [showModal, setShowModal] = useState(false);
  const [showSuspendModal, setShowSuspendModal] = useState(false);
  const [selectedInstitution, setSelectedInstitution] = useState(null);
  const [search, setSearch] = useState('');
  const [showDeleted, setShowDeleted] = useState(false);
  const [showSuspended, setShowSuspended] = useState(false);

  // Fetch institutions
  const { data, isLoading } = useQuery({
    queryKey: ['institutions', search, showDeleted, showSuspended],
    queryFn: () =>
      getInstitutions({
        search,
        includeDeleted: showDeleted ? 'true' : 'false',
        includeSuspended: showSuspended ? 'true' : 'false',
      }).then((r) => r.data),
    retry: false,
    placeholderData: [],
  });

  const { register, handleSubmit, reset, formState: { errors } } = useForm();

  // Create institution
  const createMutation = useMutation({
    mutationFn: (d) => createInstitution(d),
    onSuccess: () => {
      qc.invalidateQueries(['institutions']);
      toast.success('Institution added');
      setShowModal(false);
      reset();
    },
    onError: (err) => toast.error(err.response?.data?.message || 'Failed to add institution'),
  });

  // Suspend institution
  const suspendMutation = useMutation({
    mutationFn: ({ id, reason }) => suspendInstitution(id, reason),
    onSuccess: () => {
      qc.invalidateQueries(['institutions']);
      toast.success('Institution suspended');
      setShowSuspendModal(false);
      setSelectedInstitution(null);
    },
    onError: (err) => toast.error(err.response?.data?.message || 'Failed to suspend'),
  });

  // Unsuspend institution
  const unsuspendMutation = useMutation({
    mutationFn: (id) => unsuspendInstitution(id),
    onSuccess: () => {
      qc.invalidateQueries(['institutions']);
      toast.success('Institution unsuspended');
      setSelectedInstitution(null);
    },
    onError: (err) => toast.error(err.response?.data?.message || 'Failed to unsuspend'),
  });

  // Delete institution
  const deleteMutation = useMutation({
    mutationFn: deleteInstitution,
    onSuccess: () => {
      qc.invalidateQueries(['institutions']);
      toast.success('Institution removed');
      setSelectedInstitution(null);
    },
    onError: (err) => toast.error(err.response?.data?.message || 'Failed to delete'),
  });

  const institutions = data || [];

  const columns = [
    { key: 'name', header: 'Institution Name' },
    { key: 'category', header: 'Category', render: (v) => <span style={{ textTransform: 'capitalize' }}>{v}</span> },
    { key: 'city', header: 'City' },
    {
      key: 'is_suspended',
      header: 'Status',
      render: (suspended, row) => (
        <div style={{ display: 'flex', gap: '6px', alignItems: 'center' }}>
          {suspended ? (
            <Badge status="error" label="Suspended" />
          ) : (
            <Badge status="success" label="Active" />
          )}
          {row.is_user_added && (
            <Badge status="info" label="User Added" />
          )}
        </div>
      ),
    },
    {
      key: 'suspended_reason',
      header: 'Reason',
      render: (reason) => reason ? <span style={{ fontSize: '12px', color: '#666' }}>{reason}</span> : '—',
    },
    {
      key: 'actions',
      header: 'Actions',
      render: (_, row) => (
        <div style={{ display: 'flex', gap: '6px', flexWrap: 'wrap' }}>
          {!row.is_suspended ? (
            <Button
              variant="warning"
              onClick={() => {
                setSelectedInstitution(row);
                setShowSuspendModal(true);
              }}
              style={{ padding: '4px 8px', fontSize: '12px' }}
            >
              ⚠️ Suspend
            </Button>
          ) : (
            <Button
              variant="success"
              onClick={() => unsuspendMutation.mutate(row.id)}
              style={{ padding: '4px 8px', fontSize: '12px' }}
            >
              Unsuspend
            </Button>
          )}
          <Button
            variant="danger"
            onClick={() => {
              if (window.confirm('Remove this institution from the app?')) {
                deleteMutation.mutate(row.id);
              }
            }}
            style={{ padding: '4px 8px', fontSize: '12px' }}
          >
            <TrashIcon style={{ width: 13, height: 13 }} /> Remove
          </Button>
        </div>
      ),
    },
  ];

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
      {/* Search and filters */}
      <div style={{ display: 'flex', gap: '12px', alignItems: 'center', flexWrap: 'wrap' }}>
        <input
          placeholder="Search institutions…"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          style={{
            flex: 1,
            minWidth: '200px',
            padding: '8px 12px',
            borderRadius: '6px',
            border: '1px solid #e2e8f0',
            fontSize: '14px',
          }}
        />

        <label style={{ display: 'flex', gap: '6px', alignItems: 'center', fontSize: '14px', cursor: 'pointer' }}>
          <input
            type="checkbox"
            checked={showDeleted}
            onChange={(e) => setShowDeleted(e.target.checked)}
            style={{ cursor: 'pointer' }}
          />
          Show Deleted
        </label>

        <label style={{ display: 'flex', gap: '6px', alignItems: 'center', fontSize: '14px', cursor: 'pointer' }}>
          <input
            type="checkbox"
            checked={showSuspended}
            onChange={(e) => setShowSuspended(e.target.checked)}
            style={{ cursor: 'pointer' }}
          />
          Show Suspended
        </label>

        <Button variant="primary" onClick={() => { setShowModal(true); reset(); }}>
          <PlusIcon style={{ width: 15, height: 15 }} /> Add Institution
        </Button>
      </div>

      {/* Table */}
      <div
        style={{
          background: '#fff',
          borderRadius: '12px',
          boxShadow: '0 1px 4px rgba(0,0,0,0.07)',
          overflow: 'hidden',
        }}
      >
        {isLoading ? <Spinner /> : <Table columns={columns} data={institutions} emptyMessage="No institutions found." />}
      </div>

      {/* Add Institution Modal */}
      {showModal && (
        <Modal
          title="Add Institution"
          onClose={() => {
            setShowModal(false);
            reset();
          }}
          width="680px"
        >
          <form
            onSubmit={handleSubmit((d) => createMutation.mutate(d))}
            style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '14px' }}
          >
            <div style={{ gridColumn: '1 / -1' }}>
              <Input
                label="Institution Name *"
                name="name"
                register={register}
                error={errors.name}
                placeholder="e.g. Nakasero Hospital"
              />
            </div>
            <Select
              label="Category *"
              name="category"
              register={register}
              options={CATEGORIES}
              error={errors.category}
            />
            <Input label="City" name="city" register={register} placeholder="e.g. Kampala" />
            <div style={{ gridColumn: '1 / -1' }}>
              <Input label="Address" name="address" register={register} placeholder="Street address" />
            </div>
            <Input label="Phone" name="phone" register={register} placeholder="+256701234567" />
            <Input label="Email" name="email" type="email" register={register} placeholder="info@hospital.ug" />
            <div style={{ gridColumn: '1 / -1', display: 'flex', gap: '8px', justifyContent: 'flex-end', marginTop: '4px' }}>
              <Button
                variant="secondary"
                type="button"
                onClick={() => {
                  setShowModal(false);
                  reset();
                }}
              >
                Cancel
              </Button>
              <Button variant="primary" type="submit" disabled={createMutation.isPending}>
                {createMutation.isPending ? 'Adding…' : 'Add Institution'}
              </Button>
            </div>
          </form>
        </Modal>
      )}

      {/* Suspend Institution Modal */}
      {showSuspendModal && selectedInstitution && (
        <Modal
          title="Suspend Institution"
          onClose={() => {
            setShowSuspendModal(false);
            setSelectedInstitution(null);
          }}
          width="500px"
        >
          <form
            onSubmit={handleSubmit((d) =>
              suspendMutation.mutate({ id: selectedInstitution.id, reason: d.reason })
            )}
            style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}
          >
            <p style={{ margin: 0, color: '#666', fontSize: '14px' }}>
              Suspending <strong>{selectedInstitution.name}</strong>
            </p>
            <Input
              label="Reason (optional)"
              name="reason"
              register={register}
              placeholder="e.g. Under renovation, Quality issues, etc."
            />
            <div style={{ display: 'flex', gap: '8px', justifyContent: 'flex-end' }}>
              <Button
                variant="secondary"
                type="button"
                onClick={() => {
                  setShowSuspendModal(false);
                  setSelectedInstitution(null);
                }}
              >
                Cancel
              </Button>
              <Button variant="warning" type="submit" disabled={suspendMutation.isPending}>
                {suspendMutation.isPending ? 'Suspending…' : 'Suspend'}
              </Button>
            </div>
          </form>
        </Modal>
      )}
    </div>
  );
}
