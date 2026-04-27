import { useState } from 'react';
import { useForm } from 'react-hook-form';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import toast from 'react-hot-toast';
import { PlusIcon, PencilIcon, TrashIcon } from '@heroicons/react/24/outline';
import { getHospitals, createHospital, updateHospital, deleteHospital } from '../../api/hospitals';
import Table from '../../components/UI/Table';
import Badge from '../../components/UI/Badge';
import Button from '../../components/UI/Button';
import Modal from '../../components/UI/Modal';
import Spinner from '../../components/UI/Spinner';
import Input from '../../components/UI/Input';
import Select from '../../components/UI/Select';

const TYPES = [{ value: 'public', label: 'Public' }, { value: 'private', label: 'Private' }, { value: 'clinic', label: 'Clinic' }];

export default function HospitalsPage() {
  const qc = useQueryClient();
  const [showModal, setShowModal] = useState(false);
  const [editing, setEditing] = useState(null);
  const [search, setSearch] = useState('');

  const { data, isLoading } = useQuery({
    queryKey: ['hospitals', search],
    queryFn: () => getHospitals({ search }).then((r) => r.data),
    retry: false,
    placeholderData: { hospitals: [] },
  });

  const { register, handleSubmit, reset, watch, formState: { errors } } = useForm();
  const directBooking = watch('direct_booking_capable');

  const saveMutation = useMutation({
    mutationFn: (d) => editing ? updateHospital(editing.id, d) : createHospital(d),
    onSuccess: () => {
      qc.invalidateQueries(['hospitals']);
      toast.success(editing ? 'Hospital updated' : 'Hospital added');
      setShowModal(false); setEditing(null); reset();
    },
    onError: () => toast.error('Failed to save hospital'),
  });

  const deleteMutation = useMutation({
    mutationFn: deleteHospital,
    onSuccess: () => { qc.invalidateQueries(['hospitals']); toast.success('Hospital removed'); },
    onError: () => toast.error('Failed to delete'),
  });

  const openEdit = (h) => {
    setEditing(h);
    reset({
      name: h.name, type: h.type, address: h.address,
      city: h.city, phone: h.phone,
      email: h.email, contact_person: h.contact_person,
      working_hours: h.working_hours, direct_booking_capable: h.direct_booking_capable,
      booking_api_url: h.booking_api_url,
    });
    setShowModal(true);
  };

  const openAdd = () => { setEditing(null); reset(); setShowModal(true); };

  const hospitals = data?.hospitals || data || [];

  const columns = [
    { key: 'name', header: 'Hospital Name' },
    { key: 'city', header: 'City' },
    { key: 'type', header: 'Type', render: (v) => <span style={{ textTransform: 'capitalize' }}>{v}</span> },
    {
      key: 'direct_booking_capable', header: 'Direct Booking',
      render: (v) => <Badge status={v ? 'active' : 'inactive'} label={v ? 'Yes' : 'No'} />,
    },
    {
      key: 'is_active', header: 'Status',
      render: (v) => <Badge status={v !== false ? 'active' : 'inactive'} />,
    },
    {
      key: 'actions', header: 'Actions',
      render: (_, row) => (
        <div style={{ display: 'flex', gap: '6px' }}>
          <Button variant="ghost" onClick={() => openEdit(row)} style={{ padding: '4px 8px', fontSize: '12px' }}>
            <PencilIcon style={{ width: 13, height: 13 }} /> Edit
          </Button>
          <Button variant="danger" onClick={() => { if (window.confirm('Delete this hospital?')) deleteMutation.mutate(row.id); }} style={{ padding: '4px 8px', fontSize: '12px' }}>
            <TrashIcon style={{ width: 13, height: 13 }} /> Delete
          </Button>
        </div>
      ),
    },
  ];

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
      <div style={{ display: 'flex', gap: '12px', alignItems: 'center' }}>
        <input
          placeholder="Search hospitals…"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          style={{ flex: 1, padding: '8px 12px', borderRadius: '6px', border: '1px solid #e2e8f0', fontSize: '14px' }}
        />
        <Button variant="primary" onClick={openAdd}>
          <PlusIcon style={{ width: 15, height: 15 }} /> Add Hospital
        </Button>
      </div>

      <div style={{ background: '#fff', borderRadius: '12px', boxShadow: '0 1px 4px rgba(0,0,0,0.07)', overflow: 'hidden' }}>
        {isLoading ? <Spinner /> : <Table columns={columns} data={hospitals} emptyMessage="No hospitals found." />}
      </div>

      {showModal && (
        <Modal title={editing ? 'Edit Hospital' : 'Add Hospital'} onClose={() => { setShowModal(false); setEditing(null); reset(); }} width="680px">
          <form onSubmit={handleSubmit((d) => saveMutation.mutate(d))} style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '14px' }}>
            <div style={{ gridColumn: '1 / -1' }}>
              <Input label="Hospital Name *" name="name" register={register} error={errors.name} placeholder="e.g. Milpark Hospital" />
            </div>
            <Select label="Type *" name="type" register={register} options={TYPES} placeholder="Select type" error={errors.type} />
            <Input label="City *" name="city" register={register} error={errors.city} placeholder="e.g. Kampala" />
            <div style={{ gridColumn: '1 / -1' }}>
              <Input label="Address" name="address" register={register} placeholder="Street address" />
            </div>
            <Input label="Phone" name="phone" register={register} placeholder="011 123 4567" />
            <Input label="Email" name="email" type="email" register={register} placeholder="hospital@example.ug" />
            <Input label="Contact Person" name="contact_person" register={register} placeholder="Name and surname" />
            <Input label="Working Hours" name="working_hours" register={register} placeholder="Mon–Fri 08:00–17:00" />
            <div style={{ gridColumn: '1 / -1', display: 'flex', alignItems: 'center', gap: '10px' }}>
              <input type="checkbox" id="db" {...register('direct_booking_capable')} style={{ width: 16, height: 16, cursor: 'pointer' }} />
              <label htmlFor="db" style={{ fontSize: '14px', color: 'var(--text)', cursor: 'pointer' }}>Direct Booking Capable</label>
            </div>
            {directBooking && (
              <div style={{ gridColumn: '1 / -1' }}>
                <Input label="Booking API URL" name="booking_api_url" register={register} placeholder="https://api.hospital.co.za/book" />
              </div>
            )}
            <div style={{ gridColumn: '1 / -1', display: 'flex', gap: '8px', justifyContent: 'flex-end', marginTop: '4px' }}>
              <Button variant="secondary" type="button" onClick={() => { setShowModal(false); setEditing(null); reset(); }}>Cancel</Button>
              <Button variant="primary" type="submit" disabled={saveMutation.isPending}>
                {saveMutation.isPending ? 'Saving…' : editing ? 'Save Changes' : 'Add Hospital'}
              </Button>
            </div>
          </form>
        </Modal>
      )}
    </div>
  );
}
