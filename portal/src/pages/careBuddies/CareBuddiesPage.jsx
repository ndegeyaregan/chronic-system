import { useState, useEffect, useRef } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import toast from 'react-hot-toast';
import {
  PlusIcon,
  PencilSquareIcon,
  TrashIcon,
  UserGroupIcon,
  MagnifyingGlassIcon,
  InformationCircleIcon,
  XMarkIcon,
} from '@heroicons/react/24/outline';
import { getBuddies, addBuddy, updateBuddy, deleteBuddy } from '../../api/careBuddies';
import { getMembers } from '../../api/members';
import Table from '../../components/UI/Table';
import Modal from '../../components/UI/Modal';
import Button from '../../components/UI/Button';
import Spinner from '../../components/UI/Spinner';

const RELATIONSHIPS = [
  { value: 'spouse', label: 'Spouse' },
  { value: 'parent', label: 'Parent' },
  { value: 'child', label: 'Child' },
  { value: 'sibling', label: 'Sibling' },
  { value: 'friend', label: 'Friend' },
  { value: 'caregiver', label: 'Caregiver' },
  { value: 'other', label: 'Other' },
];

const fmtDate = (d) =>
  d ? new Date(d).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' }) : '—';

const inputStyle = {
  padding: '8px 12px', borderRadius: '6px', border: '1px solid #e2e8f0',
  fontSize: '14px', color: 'var(--text)', background: '#fff', outline: 'none',
  width: '100%', boxSizing: 'border-box',
};

export default function CareBuddiesPage() {
  const qc = useQueryClient();

  // Member search
  const [memberSearch, setMemberSearch] = useState('');
  const [selectedMember, setSelectedMember] = useState(null);
  const [showDropdown, setShowDropdown] = useState(false);
  const searchTimeout = useRef(null);
  const dropdownRef = useRef(null);

  // Buddy modal
  const [modalOpen, setModalOpen] = useState(false);
  const [editBuddy, setEditBuddy] = useState(null);
  const [deleteId, setDeleteId] = useState(null);
  const [form, setForm] = useState({ name: '', phone: '', relationship: 'spouse' });

  // Debounced member search
  const [debouncedSearch, setDebouncedSearch] = useState('');
  useEffect(() => {
    clearTimeout(searchTimeout.current);
    if (memberSearch.length >= 2) {
      searchTimeout.current = setTimeout(() => setDebouncedSearch(memberSearch), 350);
    } else {
      setDebouncedSearch('');
    }
    return () => clearTimeout(searchTimeout.current);
  }, [memberSearch]);

  const { data: membersData, isFetching: membersLoading } = useQuery({
    queryKey: ['members-search', debouncedSearch],
    queryFn: () => getMembers({ search: debouncedSearch, limit: 10 }),
    enabled: debouncedSearch.length >= 2,
  });
  const memberResults = membersData?.data?.members || membersData?.data || [];

  // Close dropdown when clicking outside
  useEffect(() => {
    const handler = (e) => {
      if (dropdownRef.current && !dropdownRef.current.contains(e.target)) {
        setShowDropdown(false);
      }
    };
    document.addEventListener('mousedown', handler);
    return () => document.removeEventListener('mousedown', handler);
  }, []);

  // Buddies query (only when a member is selected)
  const { data: buddiesData, isLoading: buddiesLoading } = useQuery({
    queryKey: ['care-buddies', selectedMember?.id],
    queryFn: () => getBuddies(selectedMember.id),
    enabled: !!selectedMember?.id,
  });
  const buddies = buddiesData?.data?.buddies || buddiesData?.data || [];

  const addMut = useMutation({
    mutationFn: (data) => addBuddy(selectedMember.id, data),
    onSuccess: () => { qc.invalidateQueries({ queryKey: ['care-buddies', selectedMember.id] }); toast.success('Buddy added'); closeModal(); },
    onError: () => toast.error('Failed to add buddy'),
  });

  const updateMut = useMutation({
    mutationFn: ({ id, data }) => updateBuddy(id, data),
    onSuccess: () => { qc.invalidateQueries({ queryKey: ['care-buddies', selectedMember.id] }); toast.success('Buddy updated'); closeModal(); },
    onError: () => toast.error('Failed to update buddy'),
  });

  const deleteMut = useMutation({
    mutationFn: (id) => deleteBuddy(id),
    onSuccess: () => { qc.invalidateQueries({ queryKey: ['care-buddies', selectedMember.id] }); toast.success('Buddy removed'); setDeleteId(null); },
    onError: () => toast.error('Failed to delete buddy'),
  });

  const openCreate = () => {
    setEditBuddy(null);
    setForm({ name: '', phone: '', relationship: 'spouse' });
    setModalOpen(true);
  };

  const openEdit = (buddy) => {
    setEditBuddy(buddy);
    setForm({ name: buddy.name || '', phone: buddy.phone || '', relationship: buddy.relationship || 'other' });
    setModalOpen(true);
  };

  const closeModal = () => { setModalOpen(false); setEditBuddy(null); };

  const handleSubmit = (e) => {
    e.preventDefault();
    if (editBuddy) {
      updateMut.mutate({ id: editBuddy.id, data: form });
    } else {
      addMut.mutate(form);
    }
  };

  const selectMember = (m) => {
    setSelectedMember(m);
    setMemberSearch('');
    setShowDropdown(false);
  };

  const isSaving = addMut.isPending || updateMut.isPending;

  const columns = [
    { key: 'name', header: 'Name', render: (val) => <span style={{ fontWeight: 500 }}>{val || '—'}</span> },
    { key: 'phone', header: 'Phone', render: (val) => val || '—' },
    {
      key: 'relationship',
      header: 'Relationship',
      render: (val) => (
        <span style={{
          background: '#e0f2fe', color: '#0369a1',
          padding: '2px 10px', borderRadius: '999px',
          fontSize: '12px', fontWeight: 600, textTransform: 'capitalize',
        }}>
          {val || '—'}
        </span>
      ),
    },
    {
      key: 'created_at',
      header: 'Added Date',
      render: (val) => <span style={{ whiteSpace: 'nowrap', fontSize: '13px' }}>{fmtDate(val)}</span>,
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

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
      {/* Header */}
      <div>
        <h1 style={{ fontSize: '22px', fontWeight: 700, color: '#0f172a', margin: 0 }}>
          Care Buddies
        </h1>
        <p style={{ margin: '4px 0 0', fontSize: '14px', color: '#64748b' }}>
          Manage care buddy relationships for members
        </p>
      </div>

      {/* Info Panel */}
      <div style={{
        background: '#eff6ff', borderRadius: '12px', padding: '14px 20px',
        border: '1px solid #bfdbfe', display: 'flex', gap: '10px', alignItems: 'flex-start',
      }}>
        <InformationCircleIcon style={{ width: 20, height: 20, color: '#3b82f6', flexShrink: 0, marginTop: 1 }} />
        <p style={{ margin: 0, fontSize: '13px', color: '#1e40af', lineHeight: 1.6 }}>
          Care Buddies are trusted contacts who can receive health alerts and provide support to members.
          Search for a member below to view and manage their care buddies.
        </p>
      </div>

      {/* Member Search */}
      <div style={{
        background: '#fff', borderRadius: '12px', padding: '20px 24px',
        boxShadow: '0 1px 4px rgba(0,0,0,0.07)', border: '1px solid #e2e8f0',
      }}>
        <label style={{ fontSize: '13px', fontWeight: 500, color: '#475569', marginBottom: '8px', display: 'block' }}>
          Select Member
        </label>
        <div ref={dropdownRef} style={{ position: 'relative', maxWidth: '480px' }}>
          <div style={{ position: 'relative' }}>
            <MagnifyingGlassIcon style={{
              width: 16, height: 16, position: 'absolute', left: 12, top: '50%',
              transform: 'translateY(-50%)', color: '#94a3b8', pointerEvents: 'none',
            }} />
            <input
              type="text"
              placeholder="Search by member name or number…"
              value={memberSearch}
              onChange={(e) => { setMemberSearch(e.target.value); setShowDropdown(true); }}
              onFocus={() => { if (memberResults.length > 0) setShowDropdown(true); }}
              style={{ ...inputStyle, paddingLeft: '36px' }}
            />
          </div>

          {/* Dropdown */}
          {showDropdown && debouncedSearch.length >= 2 && (
            <div style={{
              position: 'absolute', top: '100%', left: 0, right: 0, zIndex: 50,
              background: '#fff', border: '1px solid #e2e8f0', borderRadius: '8px',
              boxShadow: '0 8px 24px rgba(0,0,0,0.12)', marginTop: '4px',
              maxHeight: '260px', overflowY: 'auto',
            }}>
              {membersLoading ? (
                <div style={{ padding: '16px', textAlign: 'center', color: '#94a3b8', fontSize: '13px' }}>
                  Searching…
                </div>
              ) : memberResults.length === 0 ? (
                <div style={{ padding: '16px', textAlign: 'center', color: '#94a3b8', fontSize: '13px' }}>
                  No members found
                </div>
              ) : (
                memberResults.map((m) => (
                  <button key={m.id} onClick={() => selectMember(m)}
                    style={{
                      width: '100%', textAlign: 'left', padding: '10px 14px',
                      background: 'none', border: 'none', borderBottom: '1px solid #f1f5f9',
                      cursor: 'pointer', fontSize: '14px', color: 'var(--text)',
                      display: 'flex', justifyContent: 'space-between', alignItems: 'center',
                    }}
                    onMouseEnter={(e) => (e.currentTarget.style.background = '#f8fafc')}
                    onMouseLeave={(e) => (e.currentTarget.style.background = 'transparent')}
                  >
                    <span style={{ fontWeight: 500 }}>{m.first_name} {m.last_name}</span>
                    <span style={{ fontSize: '12px', color: '#94a3b8' }}>{m.member_number}</span>
                  </button>
                ))
              )}
            </div>
          )}
        </div>
      </div>

      {/* Selected Member Card + Buddies */}
      {selectedMember && (
        <>
          {/* Member Info Card */}
          <div style={{
            background: '#fff', borderRadius: '12px', padding: '20px 24px',
            boxShadow: '0 1px 4px rgba(0,0,0,0.07)', border: '1px solid #e2e8f0',
            display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '12px',
          }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '14px' }}>
              <div style={{
                width: 44, height: 44, borderRadius: '50%', background: 'var(--primary)',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                color: '#fff', fontWeight: 700, fontSize: '16px',
              }}>
                {selectedMember.first_name?.[0]}{selectedMember.last_name?.[0]}
              </div>
              <div>
                <div style={{ fontWeight: 600, fontSize: '16px', color: '#0f172a' }}>
                  {selectedMember.first_name} {selectedMember.last_name}
                </div>
                <div style={{ fontSize: '13px', color: '#64748b' }}>
                  {selectedMember.member_number || '—'}
                  {selectedMember.conditions?.length > 0 && (
                    <span> · {selectedMember.conditions.map((c) => c.name || c).join(', ')}</span>
                  )}
                </div>
              </div>
            </div>
            <div style={{ display: 'flex', gap: '8px' }}>
              <Button onClick={openCreate}>
                <PlusIcon style={{ width: 16, height: 16 }} /> Add Buddy
              </Button>
              <Button variant="secondary" onClick={() => setSelectedMember(null)}>
                <XMarkIcon style={{ width: 16, height: 16 }} /> Clear
              </Button>
            </div>
          </div>

          {/* Buddies Table */}
          <div style={{
            background: '#fff', borderRadius: '12px',
            boxShadow: '0 1px 4px rgba(0,0,0,0.07)', border: '1px solid #e2e8f0',
            overflow: 'hidden',
          }}>
            <div style={{
              padding: '14px 20px', borderBottom: '1px solid #f1f5f9',
              display: 'flex', alignItems: 'center', gap: '8px',
            }}>
              <UserGroupIcon style={{ width: 18, height: 18, color: 'var(--primary)' }} />
              <span style={{ fontSize: '15px', fontWeight: 600, color: '#0f172a' }}>
                Care Buddies ({Array.isArray(buddies) ? buddies.length : 0})
              </span>
            </div>
            {buddiesLoading ? (
              <Spinner />
            ) : (
              <Table columns={columns} data={Array.isArray(buddies) ? buddies : []}
                emptyMessage="No care buddies added yet." />
            )}
          </div>
        </>
      )}

      {/* No member selected placeholder */}
      {!selectedMember && (
        <div style={{
          background: '#fff', borderRadius: '12px', padding: '60px 20px',
          boxShadow: '0 1px 4px rgba(0,0,0,0.07)', border: '1px solid #e2e8f0',
          textAlign: 'center',
        }}>
          <UserGroupIcon style={{ width: 48, height: 48, color: '#cbd5e1', margin: '0 auto 16px' }} />
          <p style={{ margin: 0, fontSize: '15px', color: '#64748b', fontWeight: 500 }}>
            Search for a member above to manage their care buddies
          </p>
        </div>
      )}

      {/* Add / Edit Modal */}
      {modalOpen && (
        <Modal title={editBuddy ? 'Edit Buddy' : 'Add Care Buddy'} onClose={closeModal}>
          <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '4px' }}>
              <label style={{ fontSize: '13px', fontWeight: 500, color: '#475569' }}>Name *</label>
              <input type="text" required value={form.name}
                onChange={(e) => setForm({ ...form, name: e.target.value })}
                placeholder="Full name" style={inputStyle} />
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '4px' }}>
              <label style={{ fontSize: '13px', fontWeight: 500, color: '#475569' }}>Phone *</label>
              <input type="tel" required value={form.phone}
                onChange={(e) => setForm({ ...form, phone: e.target.value })}
                placeholder="+254…" style={inputStyle} />
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '4px' }}>
              <label style={{ fontSize: '13px', fontWeight: 500, color: '#475569' }}>Relationship</label>
              <select value={form.relationship}
                onChange={(e) => setForm({ ...form, relationship: e.target.value })}
                style={{ ...inputStyle, cursor: 'pointer' }}>
                {RELATIONSHIPS.map((r) => <option key={r.value} value={r.value}>{r.label}</option>)}
              </select>
            </div>

            <div style={{ display: 'flex', gap: '10px', justifyContent: 'flex-end', marginTop: '4px' }}>
              <Button variant="secondary" onClick={closeModal} disabled={isSaving}>Cancel</Button>
              <Button type="submit" disabled={isSaving}>
                {isSaving ? 'Saving…' : editBuddy ? 'Update' : 'Add Buddy'}
              </Button>
            </div>
          </form>
        </Modal>
      )}

      {/* Delete confirmation */}
      {deleteId && (
        <Modal title="Remove Care Buddy" onClose={() => setDeleteId(null)} width="420px">
          <p style={{ margin: '0 0 20px', fontSize: '14px', color: '#475569' }}>
            Are you sure you want to remove this care buddy? They will no longer receive health alerts for this member.
          </p>
          <div style={{ display: 'flex', gap: '10px', justifyContent: 'flex-end' }}>
            <Button variant="secondary" onClick={() => setDeleteId(null)}
              disabled={deleteMut.isPending}>Cancel</Button>
            <Button variant="danger" onClick={() => deleteMut.mutate(deleteId)}
              disabled={deleteMut.isPending}>
              {deleteMut.isPending ? 'Removing…' : 'Remove'}
            </Button>
          </div>
        </Modal>
      )}
    </div>
  );
}
