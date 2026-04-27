import { useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useForm } from 'react-hook-form';
import { format } from 'date-fns';
import toast from 'react-hot-toast';
import { PencilSquareIcon, KeyIcon, UserPlusIcon } from '@heroicons/react/24/outline';
import {
  createAdmin,
  getAdmins,
  resetAdminPassword,
  toggleAdminStatus,
  updateAdmin,
} from '../../api/admins';
import Table from '../../components/UI/Table';
import Badge from '../../components/UI/Badge';
import Button from '../../components/UI/Button';
import Modal from '../../components/UI/Modal';
import Spinner from '../../components/UI/Spinner';
import Input from '../../components/UI/Input';
import Select from '../../components/UI/Select';

const roleOptions = [
  { value: 'super_admin', label: 'Super admin' },
  { value: 'support_admin', label: 'Support admin' },
  { value: 'content_admin', label: 'Content admin' },
];

export default function AdminUsersPage() {
  const qc = useQueryClient();
  const [editingAdmin, setEditingAdmin] = useState(null);
  const [resetTarget, setResetTarget] = useState(null);
  const {
    register,
    handleSubmit,
    reset,
    formState: { errors },
  } = useForm({
    defaultValues: {
      role: 'support_admin',
    },
  });
  const {
    register: registerReset,
    handleSubmit: handleResetSubmit,
    reset: resetResetForm,
    formState: { errors: resetErrors },
  } = useForm();

  const { data: admins = [], isLoading } = useQuery({
    queryKey: ['admins'],
    queryFn: getAdmins,
    retry: false,
  });

  const closeAdminModal = () => {
    setEditingAdmin(null);
    reset({ role: 'support_admin' });
  };

  const saveMutation = useMutation({
    mutationFn: (payload) => (
      editingAdmin?.id
        ? updateAdmin(editingAdmin.id, payload)
        : createAdmin(payload)
    ),
    onSuccess: () => {
      qc.invalidateQueries(['admins']);
      toast.success(editingAdmin ? 'Admin updated' : 'Admin created');
      closeAdminModal();
    },
    onError: (err) => toast.error(err.response?.data?.message || 'Failed to save admin'),
  });

  const toggleMutation = useMutation({
    mutationFn: toggleAdminStatus,
    onSuccess: (response) => {
      qc.invalidateQueries(['admins']);
      toast.success(response.message || 'Admin status updated');
    },
    onError: (err) => toast.error(err.response?.data?.message || 'Failed to update admin status'),
  });

  const resetPasswordMutation = useMutation({
    mutationFn: ({ id, payload }) => resetAdminPassword(id, payload),
    onSuccess: () => {
      qc.invalidateQueries(['admins']);
      toast.success('Password reset');
      setResetTarget(null);
      resetResetForm();
    },
    onError: (err) => toast.error(err.response?.data?.message || 'Failed to reset password'),
  });

  const columns = [
    {
      key: 'name',
      header: 'Admin',
      render: (_, row) => row.name || `${row.first_name || ''} ${row.last_name || ''}`.trim() || '—',
    },
    { key: 'email', header: 'Email' },
    {
      key: 'role',
      header: 'Role',
      render: (value) => value?.replace(/_/g, ' ') || '—',
    },
    {
      key: 'is_active',
      header: 'Status',
      render: (value) => <Badge status={value ? 'active' : 'inactive'} />,
    },
    {
      key: 'created_at',
      header: 'Created',
      render: (value) => value ? format(new Date(value), 'dd MMM yyyy') : '—',
    },
    {
      key: 'actions',
      header: 'Actions',
      render: (_, row) => (
        <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
          <Button
            variant="ghost"
            style={{ padding: '4px 8px', fontSize: '12px' }}
            onClick={() => {
              setEditingAdmin(row);
              reset({
                first_name: row.first_name || '',
                last_name: row.last_name || '',
                email: row.email || '',
                role: row.role || 'support_admin',
              });
            }}
          >
            <PencilSquareIcon style={{ width: 14, height: 14 }} /> Edit
          </Button>
          <Button
            variant={row.is_active ? 'secondary' : 'success'}
            style={{ padding: '4px 8px', fontSize: '12px' }}
            onClick={() => toggleMutation.mutate(row.id)}
          >
            {row.is_active ? 'Deactivate' : 'Activate'}
          </Button>
          <Button
            variant="secondary"
            style={{ padding: '4px 8px', fontSize: '12px' }}
            onClick={() => {
              setResetTarget(row);
              resetResetForm();
            }}
          >
            <KeyIcon style={{ width: 14, height: 14 }} /> Reset Password
          </Button>
        </div>
      ),
    },
  ];

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: '12px', flexWrap: 'wrap' }}>
        <div>
          <p style={{ margin: 0, fontSize: '13px', color: '#64748b' }}>Create new admins, update roles, and manage access.</p>
        </div>
        <Button
          variant="primary"
          onClick={() => {
            setEditingAdmin({});
            reset({ first_name: '', last_name: '', email: '', password: '', role: 'support_admin' });
          }}
        >
          <UserPlusIcon style={{ width: 16, height: 16 }} /> Add Admin
        </Button>
      </div>

      <div style={{ background: '#fff', borderRadius: '12px', boxShadow: '0 1px 4px rgba(0,0,0,0.07)', overflow: 'hidden' }}>
        {isLoading ? <Spinner /> : <Table columns={columns} data={admins} emptyMessage="No admin users found." />}
      </div>

      {editingAdmin && (
        <Modal title={editingAdmin.id ? 'Edit Admin' : 'Create Admin'} onClose={closeAdminModal}>
          <form
            onSubmit={handleSubmit((formData) => {
              const payload = editingAdmin.id
                ? {
                    first_name: formData.first_name,
                    last_name: formData.last_name,
                    role: formData.role,
                  }
                : formData;
              saveMutation.mutate(payload);
            })}
            style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}
          >
            <Input label="First Name" name="first_name" register={register} error={errors.first_name} />
            <Input label="Last Name" name="last_name" register={register} error={errors.last_name} />
            <Input
              label="Email"
              type="email"
              name="email"
              register={register}
              error={errors.email}
              disabled={!!editingAdmin.id}
            />
            {!editingAdmin.id && (
              <Input label="Temporary Password" type="password" name="password" register={register} error={errors.password} />
            )}
            <Select label="Role" name="role" register={register} options={roleOptions} error={errors.role} />

            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '8px' }}>
              <Button variant="secondary" onClick={closeAdminModal}>Cancel</Button>
              <Button type="submit" variant="primary" disabled={saveMutation.isPending}>
                {saveMutation.isPending ? 'Saving…' : editingAdmin.id ? 'Update Admin' : 'Create Admin'}
              </Button>
            </div>
          </form>
        </Modal>
      )}

      {resetTarget && (
        <Modal title={`Reset Password — ${resetTarget.name || resetTarget.email}`} onClose={() => setResetTarget(null)}>
          <form
            onSubmit={handleResetSubmit((formData) => resetPasswordMutation.mutate({
              id: resetTarget.id,
              payload: { new_password: formData.new_password },
            }))}
            style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}
          >
            <Input label="New Password" type="password" name="new_password" register={registerReset} error={resetErrors.new_password} />
            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '8px' }}>
              <Button variant="secondary" onClick={() => setResetTarget(null)}>Cancel</Button>
              <Button type="submit" variant="primary" disabled={resetPasswordMutation.isPending}>
                {resetPasswordMutation.isPending ? 'Updating…' : 'Reset Password'}
              </Button>
            </div>
          </form>
        </Modal>
      )}
    </div>
  );
}
