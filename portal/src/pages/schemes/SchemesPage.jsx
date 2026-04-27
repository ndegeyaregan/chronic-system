import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { useForm } from 'react-hook-form';
import toast from 'react-hot-toast';
import {
  PlusIcon, PencilIcon, TrashIcon, CheckCircleIcon, XCircleIcon,
} from '@heroicons/react/24/outline';
import { getSchemes, createScheme, updateScheme, deleteScheme } from '../../api/schemes';
import Table from '../../components/UI/Table';
import Badge from '../../components/UI/Badge';
import Button from '../../components/UI/Button';
import Modal from '../../components/UI/Modal';
import Input from '../../components/UI/Input';
import Spinner from '../../components/UI/Spinner';

export default function SchemesPage() {
  const qc = useQueryClient();
  const [showForm, setShowForm] = useState(false);
  const [editing, setEditing] = useState(null);

  const { register, handleSubmit, reset, setValue, formState: { errors } } = useForm();

  const { data: schemes = [], isLoading } = useQuery({
    queryKey: ['schemes'],
    queryFn: () => getSchemes({ include_inactive: true }).then(r => r.data),
    retry: false,
  });

  const createMutation = useMutation({
    mutationFn: (data) => createScheme(data),
    onSuccess: () => {
      qc.invalidateQueries(['schemes']);
      toast.success('Scheme created');
      closeForm();
    },
    onError: (err) => toast.error(err.response?.data?.message || 'Failed to create scheme'),
  });

  const updateMutation = useMutation({
    mutationFn: ({ id, data }) => updateScheme(id, data),
    onSuccess: () => {
      qc.invalidateQueries(['schemes']);
      toast.success('Scheme updated');
      closeForm();
    },
    onError: (err) => toast.error(err.response?.data?.message || 'Failed to update scheme'),
  });

  const deleteMutation = useMutation({
    mutationFn: deleteScheme,
    onSuccess: () => {
      qc.invalidateQueries(['schemes']);
      toast.success('Scheme deactivated');
    },
    onError: () => toast.error('Failed to deactivate scheme'),
  });

  const toggleMutation = useMutation({
    mutationFn: ({ id, is_active }) => updateScheme(id, { is_active }),
    onSuccess: () => {
      qc.invalidateQueries(['schemes']);
      toast.success('Status updated');
    },
    onError: () => toast.error('Failed to update status'),
  });

  const closeForm = () => {
    setShowForm(false);
    setEditing(null);
    reset({ name: '', code: '' });
  };

  const openEdit = (scheme) => {
    setEditing(scheme);
    setValue('name', scheme.name);
    setValue('code', scheme.code || '');
    setShowForm(true);
  };

  const onSubmit = (formData) => {
    if (editing) {
      updateMutation.mutate({ id: editing.id, data: formData });
    } else {
      createMutation.mutate(formData);
    }
  };

  const columns = [
    { key: 'name', header: 'Scheme Name' },
    { key: 'code', header: 'Code', render: (v) => v || '—' },
    {
      key: 'is_active', header: 'Status',
      render: (v) => <Badge status={v ? 'active' : 'inactive'} />,
    },
    {
      key: 'actions', header: 'Actions',
      render: (_, row) => (
        <div style={{ display: 'flex', gap: '6px' }}>
          <Button variant="ghost" onClick={() => openEdit(row)} style={{ padding: '4px 8px', fontSize: '12px' }}>
            <PencilIcon style={{ width: 13, height: 13 }} /> Edit
          </Button>
          {row.is_active ? (
            <Button variant="secondary" onClick={() => toggleMutation.mutate({ id: row.id, is_active: false })} style={{ padding: '4px 8px', fontSize: '12px' }}>
              <XCircleIcon style={{ width: 13, height: 13 }} /> Deactivate
            </Button>
          ) : (
            <Button variant="success" onClick={() => toggleMutation.mutate({ id: row.id, is_active: true })} style={{ padding: '4px 8px', fontSize: '12px' }}>
              <CheckCircleIcon style={{ width: 13, height: 13 }} /> Activate
            </Button>
          )}
        </div>
      ),
    },
  ];

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div>
          <h2 style={{ margin: 0, fontSize: '20px', fontWeight: 700, color: 'var(--text)' }}>Schemes</h2>
          <p style={{ margin: '4px 0 0', fontSize: '13px', color: '#64748b' }}>
            Manage member schemes (e.g. corporate plans)
          </p>
        </div>
        <Button variant="primary" onClick={() => { reset({ name: '', code: '' }); setShowForm(true); }}>
          <PlusIcon style={{ width: 15, height: 15 }} /> Add Scheme
        </Button>
      </div>

      <div style={{ background: '#fff', borderRadius: '12px', boxShadow: '0 1px 4px rgba(0,0,0,0.07)', overflow: 'hidden' }}>
        {isLoading ? <Spinner /> : <Table columns={columns} data={schemes} emptyMessage="No schemes found." />}
      </div>

      {showForm && (
        <Modal title={editing ? 'Edit Scheme' : 'Add Scheme'} onClose={closeForm}>
          <form onSubmit={handleSubmit(onSubmit)} style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
            <Input label="Scheme Name" name="name" register={register} error={errors.name} placeholder="e.g. NEMA" required />
            <Input label="Code" name="code" register={register} error={errors.code} placeholder="e.g. NEMA" />
            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '8px' }}>
              <Button variant="secondary" onClick={closeForm}>Cancel</Button>
              <Button type="submit" variant="primary" disabled={createMutation.isPending || updateMutation.isPending}>
                {(createMutation.isPending || updateMutation.isPending) ? 'Saving…' : (editing ? 'Update' : 'Create')}
              </Button>
            </div>
          </form>
        </Modal>
      )}
    </div>
  );
}
