import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { useForm } from 'react-hook-form';
import toast from 'react-hot-toast';
import { PlusIcon, PencilIcon, TrashIcon } from '@heroicons/react/24/outline';
import { getPartners, createPartner, updatePartner, deletePartner } from '../../api/lifestyle';
import Table from '../../components/UI/Table';
import Button from '../../components/UI/Button';
import Modal from '../../components/UI/Modal';
import Spinner from '../../components/UI/Spinner';
import Input from '../../components/UI/Input';
import Select from '../../components/UI/Select';

const TABS = ['Gyms', 'Nutritionists', 'Counsellors'];
const TAB_TYPES = { Gyms: 'gym', Nutritionists: 'nutritionist', Counsellors: 'counsellor' };
const PROVINCES = ['Gauteng', 'Western Cape', 'KwaZulu-Natal', 'Eastern Cape', 'Limpopo', 'Mpumalanga', 'North West', 'Free State', 'Northern Cape'];

export default function LifestylePartnersPage() {
  const qc = useQueryClient();
  const [activeTab, setActiveTab] = useState('Gyms');
  const [showModal, setShowModal] = useState(false);
  const [editing, setEditing] = useState(null);
  const type = TAB_TYPES[activeTab];

  const { data, isLoading } = useQuery({
    queryKey: ['lifestyle-partners', type],
    queryFn: () => getPartners({ type }).then((r) => r.data),
    retry: false,
    placeholderData: [],
  });

  const { register, handleSubmit, reset, formState: { errors } } = useForm();

  const saveMutation = useMutation({
    mutationFn: (d) => editing ? updatePartner(editing.id, d) : createPartner({ ...d, type }),
    onSuccess: () => {
      qc.invalidateQueries(['lifestyle-partners']);
      toast.success(editing ? 'Partner updated' : 'Partner added');
      setShowModal(false); setEditing(null); reset();
    },
    onError: () => toast.error('Failed to save partner'),
  });

  const deleteMutation = useMutation({
    mutationFn: deletePartner,
    onSuccess: () => { qc.invalidateQueries(['lifestyle-partners']); toast.success('Partner removed'); },
    onError: () => toast.error('Delete failed'),
  });

  const openEdit = (p) => {
    setEditing(p);
    reset({ name: p.name, city: p.city, province: p.province, phone: p.phone, email: p.email, address: p.address, website: p.website });
    setShowModal(true);
  };

  const partners = Array.isArray(data) ? data : data?.partners || [];

  const columns = [
    { key: 'name', header: 'Name' },
    { key: 'city', header: 'City' },
    { key: 'province', header: 'Province' },
    { key: 'phone', header: 'Phone' },
    { key: 'email', header: 'Email' },
    {
      key: 'actions', header: 'Actions',
      render: (_, row) => (
        <div style={{ display: 'flex', gap: '6px' }}>
          <Button variant="ghost" onClick={() => openEdit(row)} style={{ padding: '4px 8px', fontSize: '12px' }}>
            <PencilIcon style={{ width: 13, height: 13 }} /> Edit
          </Button>
          <Button variant="danger" onClick={() => { if (window.confirm('Remove this partner?')) deleteMutation.mutate(row.id); }} style={{ padding: '4px 8px', fontSize: '12px' }}>
            <TrashIcon style={{ width: 13, height: 13 }} /> Delete
          </Button>
        </div>
      ),
    },
  ];

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
      {/* Tabs */}
      <div style={{ background: '#fff', borderRadius: '12px', boxShadow: '0 1px 4px rgba(0,0,0,0.07)', overflow: 'hidden' }}>
        <div style={{ display: 'flex', borderBottom: '2px solid #f1f5f9', alignItems: 'center', justifyContent: 'space-between', paddingRight: '16px' }}>
          <div style={{ display: 'flex' }}>
            {TABS.map((tab) => (
              <button
                key={tab}
                onClick={() => setActiveTab(tab)}
                style={{
                  padding: '13px 20px', background: 'none', border: 'none',
                  borderBottom: activeTab === tab ? '2px solid var(--primary)' : '2px solid transparent',
                  marginBottom: '-2px', cursor: 'pointer',
                  fontSize: '14px', fontWeight: activeTab === tab ? '600' : '400',
                  color: activeTab === tab ? 'var(--primary)' : '#64748b',
                }}
              >
                {tab}
              </button>
            ))}
          </div>
          <Button variant="primary" onClick={() => { setEditing(null); reset(); setShowModal(true); }} style={{ padding: '6px 12px', fontSize: '13px' }}>
            <PlusIcon style={{ width: 14, height: 14 }} /> Add {activeTab.slice(0, -1)}
          </Button>
        </div>
        <div style={{ padding: '0' }}>
          {isLoading ? <Spinner /> : <Table columns={columns} data={partners} emptyMessage={`No ${activeTab.toLowerCase()} found.`} />}
        </div>
      </div>

      {showModal && (
        <Modal title={`${editing ? 'Edit' : 'Add'} ${activeTab.slice(0, -1)}`} onClose={() => { setShowModal(false); setEditing(null); reset(); }}>
          <form onSubmit={handleSubmit((d) => saveMutation.mutate(d))} style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '14px' }}>
            <div style={{ gridColumn: '1 / -1' }}>
              <Input label="Name *" name="name" register={register} error={errors.name} placeholder="Partner name" />
            </div>
            <Input label="City *" name="city" register={register} placeholder="e.g. Cape Town" />
            <Select label="Province" name="province" register={register} options={PROVINCES.map((p) => ({ value: p, label: p }))} placeholder="Select province" />
            <Input label="Phone" name="phone" register={register} placeholder="021 123 4567" />
            <Input label="Email" name="email" type="email" register={register} placeholder="info@partner.co.za" />
            <div style={{ gridColumn: '1 / -1' }}>
              <Input label="Address" name="address" register={register} placeholder="Street address" />
            </div>
            <div style={{ gridColumn: '1 / -1' }}>
              <Input label="Website" name="website" register={register} placeholder="https://partner.co.za" />
            </div>
            <div style={{ gridColumn: '1 / -1', display: 'flex', gap: '8px', justifyContent: 'flex-end' }}>
              <Button variant="secondary" type="button" onClick={() => { setShowModal(false); setEditing(null); reset(); }}>Cancel</Button>
              <Button variant="primary" type="submit" disabled={saveMutation.isPending}>
                {saveMutation.isPending ? 'Saving…' : editing ? 'Save Changes' : 'Add Partner'}
              </Button>
            </div>
          </form>
        </Modal>
      )}
    </div>
  );
}
