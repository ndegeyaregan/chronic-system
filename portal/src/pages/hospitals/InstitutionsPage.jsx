import { useState, useMemo, useRef } from 'react';
import { useForm } from 'react-hook-form';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import toast from 'react-hot-toast';
import { PlusIcon, PencilIcon, TrashIcon, PaperClipIcon, XMarkIcon } from '@heroicons/react/24/outline';
import {
  getInstitutions,
  createInstitution,
  updateInstitution,
  suspendInstitution,
  unsuspendInstitution,
  deleteInstitution,
  getInstitutionCopays,
  syncInstitutionCopays,
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

const fmtDate = (v) => {
  if (!v) return '';
  try {
    return new Date(v).toLocaleString(undefined, {
      year: 'numeric', month: 'short', day: '2-digit',
      hour: '2-digit', minute: '2-digit',
    });
  } catch { return ''; }
};

const fmtMoney = (v) => {
  if (v == null) return null;
  return Number(v).toLocaleString('en-UG', { maximumFractionDigits: 0 });
};

const CopayBadge = ({ copay }) => {
  if (!copay) return <span style={{ color: '#94a3b8', fontSize: '12px' }}>—</span>;

  const parts = [];
  if (copay.out_patient_percent > 0) parts.push(`OP ${copay.out_patient_percent}%`);
  else if (copay.out_patient > 0) parts.push(`OP UGX ${fmtMoney(copay.out_patient)}`);
  if (copay.in_patient_percent > 0) parts.push(`IP ${copay.in_patient_percent}%`);
  else if (copay.in_patient > 0) parts.push(`IP UGX ${fmtMoney(copay.in_patient)}`);
  if (copay.dental_percent > 0) parts.push(`Dental ${copay.dental_percent}%`);
  if (copay.optical_percent > 0) parts.push(`Optical ${copay.optical_percent}%`);
  if (copay.pharma_percent > 0) parts.push(`Pharma ${copay.pharma_percent}%`);

  if (parts.length === 0) return <span style={{ color: '#94a3b8', fontSize: '12px' }}>—</span>;

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '2px' }}>
      {parts.map((p, i) => (
        <span key={i} style={{
          display: 'inline-block', fontSize: '11px', fontWeight: 600,
          background: '#fef3c7', color: '#92400e',
          borderRadius: '4px', padding: '1px 6px',
        }}>{p}</span>
      ))}
    </div>
  );
};

export default function InstitutionsPage() {
  const qc = useQueryClient();
  const [showModal, setShowModal] = useState(false);
  const [showSuspendModal, setShowSuspendModal] = useState(false);
  const [editingInstitution, setEditingInstitution] = useState(null); // null = add, obj = edit
  const [selectedInstitution, setSelectedInstitution] = useState(null);
  const [search, setSearch] = useState('');
  const [areaFilter, setAreaFilter] = useState('');
  const [category, setCategory] = useState('');
  const [showDeleted, setShowDeleted] = useState(false);
  const [showSuspended, setShowSuspended] = useState(false);
  const [docFiles, setDocFiles] = useState([]); // files for new institution
  const fileInputRef = useRef(null);

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

  const { data: copaysData } = useQuery({
    queryKey: ['institution-copays'],
    queryFn: () => getInstitutionCopays().then((r) => r.data),
    retry: false,
    placeholderData: [],
  });

  // Index copays by sanlam_id for O(1) lookup
  const copaysBySanlamId = useMemo(() => {
    const map = {};
    (copaysData || []).forEach((c) => { map[c.sanlam_id] = c; });
    return map;
  }, [copaysData]);

  const { register, handleSubmit, reset, formState: { errors } } = useForm();

  const createMutation = useMutation({
    mutationFn: (formData) => createInstitution(formData),
    onSuccess: () => {
      qc.invalidateQueries(['institutions']);
      toast.success('Institution added — IT team notified via email');
      setShowModal(false);
      setDocFiles([]);
      reset();
    },
    onError: (err) => toast.error(err.response?.data?.message || 'Failed to add institution'),
  });

  const updateMutation = useMutation({
    mutationFn: ({ id, data }) => updateInstitution(id, data),
    onSuccess: () => {
      qc.invalidateQueries(['institutions']);
      toast.success('Institution updated');
      setShowModal(false);
      setEditingInstitution(null);
      reset();
    },
    onError: (err) => toast.error(err.response?.data?.message || 'Failed to update institution'),
  });

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

  const unsuspendMutation = useMutation({
    mutationFn: (id) => unsuspendInstitution(id),
    onSuccess: () => {
      qc.invalidateQueries(['institutions']);
      toast.success('Institution reinstated');
      setSelectedInstitution(null);
    },
    onError: (err) => toast.error(err.response?.data?.message || 'Failed to reinstate'),
  });

  const deleteMutation = useMutation({
    mutationFn: deleteInstitution,
    onSuccess: () => {
      qc.invalidateQueries(['institutions']);
      toast.success('Institution removed');
      setSelectedInstitution(null);
    },
    onError: (err) => toast.error(err.response?.data?.message || 'Failed to delete'),
  });

  const syncCopaysMutation = useMutation({
    mutationFn: syncInstitutionCopays,
    onSuccess: (res) => {
      qc.invalidateQueries(['institution-copays']);
      toast.success(`Copays synced: ${res.data.upserted} institutions`);
    },
    onError: (err) => toast.error(err.response?.data?.message || 'Failed to sync copays'),
  });

  const openAdd = () => {
    setEditingInstitution(null);
    setDocFiles([]);
    reset();
    setShowModal(true);
  };

  const openEdit = (inst) => {
    setEditingInstitution(inst);
    setDocFiles([]);
    reset({
      name: inst.name,
      category: inst.category,
      phone: inst.phone || '',
      email: inst.email || '',
      address: inst.address || '',
      street: inst.street || '',
      area: inst.area || '',
      city: inst.city || '',
      province: inst.province || '',
      postal_code: inst.postal_code || '',
      contact_person: inst.contact_person || '',
      working_hours: inst.working_hours || '',
      latitude: inst.latitude || '',
      longitude: inst.longitude || '',
      first_name: inst.first_name || '',
      last_name: inst.last_name || '',
      title: inst.title || '',
    });
    setShowModal(true);
  };

  const onSubmit = (d) => {
    if (editingInstitution) {
      updateMutation.mutate({ id: editingInstitution.id, data: d });
    } else {
      // Build FormData so files are included
      const fd = new FormData();
      Object.entries(d).forEach(([k, v]) => {
        if (v !== undefined && v !== null && v !== '') fd.append(k, v);
      });
      docFiles.forEach((file) => fd.append('documents', file));
      createMutation.mutate(fd);
    }
  };

  const handleFileChange = (e) => {
    const picked = Array.from(e.target.files || []);
    setDocFiles((prev) => {
      const combined = [...prev, ...picked];
      return combined.slice(0, 5); // max 5
    });
    if (fileInputRef.current) fileInputRef.current.value = '';
  };

  const removeFile = (idx) => setDocFiles((prev) => prev.filter((_, i) => i !== idx));

  const institutions = data || [];

  // Build unique areas for dropdown filter
  const uniqueAreas = useMemo(() => {
    const areas = new Set(institutions.map((i) => i.area).filter(Boolean));
    return Array.from(areas).sort();
  }, [institutions]);

  const filteredInstitutions = useMemo(() => {
    let list = category ? institutions.filter((i) => i.category === category) : institutions;
    if (areaFilter) list = list.filter((i) => i.area === areaFilter);
    return list;
  }, [institutions, category, areaFilter]);

  const isSanlamManaged = (inst) => !inst?.is_user_added;

  const columns = [
    { key: 'name', header: 'Institution Name' },
    {
      key: 'category',
      header: 'Category',
      render: (v) => <span style={{ textTransform: 'capitalize' }}>{v}</span>,
    },
    { key: 'city', header: 'City' },
    {
      key: 'area',
      header: 'Area/Location',
      render: (v) => v
        ? <span style={{ fontSize: '13px', color: '#0f172a' }}>{v}</span>
        : <span style={{ fontSize: '12px', color: '#94a3b8' }}>—</span>,
    },
    {
      key: 'contact_person',
      header: 'Contact Person',
      render: (v, row) => {
        const contact = v || [row.first_name, row.last_name].filter(Boolean).join(' ') || null;
        return contact
          ? <span style={{ fontSize: '13px' }}>{contact}</span>
          : <span style={{ fontSize: '12px', color: '#94a3b8' }}>—</span>;
      },
    },
    {
      key: 'sanlam_id',
      header: 'Co-pay',
      render: (sanlamId) => <CopayBadge copay={sanlamId ? copaysBySanlamId[sanlamId] : null} />,
    },
    {
      key: 'added_by_name',
      header: 'Added By',
      render: (_, row) => {
        if (!row.is_user_added) {
          return <span style={{ fontSize: '12px', color: '#94a3b8' }}>Sanlam sync</span>;
        }
        return (
          <div style={{ fontSize: '12px', lineHeight: 1.35 }}>
            <div style={{ color: '#0f172a', fontWeight: 500 }}>{row.added_by_name || '—'}</div>
            {row.created_at && <div style={{ color: '#64748b' }}>{fmtDate(row.created_at)}</div>}
          </div>
        );
      },
    },
    {
      key: 'is_suspended',
      header: 'Status',
      render: (suspended, row) => (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '4px' }}>
          <div style={{ display: 'flex', gap: '6px', alignItems: 'center', flexWrap: 'wrap' }}>
            {suspended
              ? <Badge status="error" label="Suspended" />
              : <Badge status="success" label="Active" />}
            {row.is_user_added && <Badge status="info" label="User Added" />}
          </div>
          {suspended && (row.suspended_by_name || row.suspended_at) && (
            <div style={{ fontSize: '11px', color: '#64748b', lineHeight: 1.3 }}>
              by <strong style={{ color: '#475569' }}>{row.suspended_by_name || '—'}</strong>
              {row.suspended_at ? ` · ${fmtDate(row.suspended_at)}` : ''}
            </div>
          )}
          {!suspended && row.unsuspended_by_name && (
            <div style={{ fontSize: '11px', color: '#64748b', lineHeight: 1.3 }}>
              reinstated by <strong style={{ color: '#475569' }}>{row.unsuspended_by_name}</strong>
              {row.unsuspended_at ? ` · ${fmtDate(row.unsuspended_at)}` : ''}
            </div>
          )}
        </div>
      ),
    },
    {
      key: 'suspended_reason',
      header: 'Reason',
      render: (reason) => reason
        ? <span style={{ fontSize: '12px', color: '#666' }}>{reason}</span>
        : '—',
    },
    {
      key: 'actions',
      header: 'Actions',
      render: (_, row) => (
        <div style={{ display: 'flex', gap: '6px', flexWrap: 'wrap' }}>
          <Button
            variant="ghost"
            onClick={() => openEdit(row)}
            style={{ padding: '4px 8px', fontSize: '12px' }}
          >
            <PencilIcon style={{ width: 13, height: 13 }} /> Edit
          </Button>
          {!row.is_suspended ? (
            <Button
              variant="warning"
              onClick={() => { setSelectedInstitution(row); setShowSuspendModal(true); }}
              style={{ padding: '4px 8px', fontSize: '12px' }}
            >
              ⚠️ Suspend
            </Button>
          ) : (
            <Button
              variant="success"
              onClick={() => {
                if (window.confirm(`Reinstate "${row.name}"? It will become active again.`)) {
                  unsuspendMutation.mutate(row.id);
                }
              }}
              style={{ padding: '4px 8px', fontSize: '12px' }}
              disabled={unsuspendMutation.isPending}
            >
              ✅ Reinstate
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
      {/* Category filter tabs */}
      <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
        {[{ value: '', label: 'All' }, ...CATEGORIES].map((c) => {
          const active = category === c.value;
          const count = c.value
            ? institutions.filter((i) => i.category === c.value).length
            : institutions.length;
          return (
            <button
              key={c.value || 'all'}
              type="button"
              onClick={() => setCategory(c.value)}
              style={{
                padding: '8px 14px',
                borderRadius: '999px',
                border: active ? '1px solid #1d4ed8' : '1px solid #e2e8f0',
                background: active ? '#1d4ed8' : '#fff',
                color: active ? '#fff' : '#334155',
                fontSize: '13px',
                fontWeight: active ? 600 : 500,
                cursor: 'pointer',
                display: 'flex',
                alignItems: 'center',
                gap: '8px',
              }}
            >
              {c.label}
              <span style={{
                background: active ? 'rgba(255,255,255,0.25)' : '#f1f5f9',
                color: active ? '#fff' : '#475569',
                borderRadius: '999px',
                padding: '1px 8px',
                fontSize: '11px',
                fontWeight: 600,
              }}>
                {count}
              </span>
            </button>
          );
        })}
      </div>

      {/* Search, area filter, and action buttons */}
      <div style={{ display: 'flex', gap: '12px', alignItems: 'center', flexWrap: 'wrap' }}>
        <input
          placeholder="Search by name, city, area…"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          style={{
            flex: 1, minWidth: '200px',
            padding: '8px 12px', borderRadius: '6px',
            border: '1px solid #e2e8f0', fontSize: '14px',
          }}
        />

        {/* Area filter */}
        <select
          value={areaFilter}
          onChange={(e) => setAreaFilter(e.target.value)}
          style={{
            padding: '8px 12px', borderRadius: '6px',
            border: '1px solid #e2e8f0', fontSize: '14px',
            background: '#fff', cursor: 'pointer', minWidth: '160px',
          }}
        >
          <option value="">All areas</option>
          {uniqueAreas.map((a) => (
            <option key={a} value={a}>{a}</option>
          ))}
        </select>

        <label style={{ display: 'flex', gap: '6px', alignItems: 'center', fontSize: '14px', cursor: 'pointer' }}>
          <input type="checkbox" checked={showDeleted} onChange={(e) => setShowDeleted(e.target.checked)} style={{ cursor: 'pointer' }} />
          Show Deleted
        </label>

        <label style={{ display: 'flex', gap: '6px', alignItems: 'center', fontSize: '14px', cursor: 'pointer' }}>
          <input type="checkbox" checked={showSuspended} onChange={(e) => setShowSuspended(e.target.checked)} style={{ cursor: 'pointer' }} />
          Show Suspended
        </label>

        <Button
          variant="secondary"
          onClick={() => syncCopaysMutation.mutate()}
          disabled={syncCopaysMutation.isPending}
          style={{ whiteSpace: 'nowrap' }}
        >
          {syncCopaysMutation.isPending ? 'Syncing…' : '⟳ Sync Copays'}
        </Button>

        <Button variant="primary" onClick={openAdd}>
          <PlusIcon style={{ width: 15, height: 15 }} /> Add Institution
        </Button>
      </div>

      {/* Table */}
      <div style={{ background: '#fff', borderRadius: '12px', boxShadow: '0 1px 4px rgba(0,0,0,0.07)', overflow: 'hidden' }}>
        {isLoading ? <Spinner /> : (
          <Table columns={columns} data={filteredInstitutions} emptyMessage="No institutions found." />
        )}
      </div>

      {/* Add / Edit Institution Modal */}
      {showModal && (
        <Modal
          title={editingInstitution ? `Edit – ${editingInstitution.name}` : 'Add Institution'}
          onClose={() => { setShowModal(false); setEditingInstitution(null); reset(); }}
          width="720px"
        >
          {editingInstitution && isSanlamManaged(editingInstitution) && (
            <div style={{
              background: '#eff6ff', border: '1px solid #bfdbfe',
              borderRadius: '8px', padding: '10px 14px', marginBottom: '14px',
              fontSize: '13px', color: '#1e40af',
            }}>
              ℹ️ This institution is managed by Sanlam sync. Only <strong>Area/Location, Contact Person, Working Hours</strong> and <strong>Coordinates</strong> can be edited here.
            </div>
          )}
          <form
            onSubmit={handleSubmit(onSubmit)}
            style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '14px' }}
          >
            {/* Identity fields — only editable for user-added */}
            <div style={{ gridColumn: '1 / -1' }}>
              <Input
                label="Institution Name *"
                name="name"
                register={register}
                error={errors.name}
                placeholder="e.g. Nakasero Hospital"
                disabled={editingInstitution && isSanlamManaged(editingInstitution)}
              />
            </div>
            <Select
              label="Category *"
              name="category"
              register={register}
              options={CATEGORIES}
              error={errors.category}
              disabled={editingInstitution && isSanlamManaged(editingInstitution)}
            />
            <Input
              label="City"
              name="city"
              register={register}
              placeholder="e.g. Kampala"
              disabled={editingInstitution && isSanlamManaged(editingInstitution)}
            />
            <div style={{ gridColumn: '1 / -1' }}>
              <Input
                label="Address"
                name="address"
                register={register}
                placeholder="Street address"
                disabled={editingInstitution && isSanlamManaged(editingInstitution)}
              />
            </div>
            <Input
              label="Street"
              name="street"
              register={register}
              placeholder="Street name"
              disabled={editingInstitution && isSanlamManaged(editingInstitution)}
            />
            <Input
              label="Phone"
              name="phone"
              register={register}
              placeholder="+256701234567"
              disabled={editingInstitution && isSanlamManaged(editingInstitution)}
            />
            <Input
              label="Email"
              name="email"
              type="email"
              register={register}
              placeholder="info@hospital.ug"
              disabled={editingInstitution && isSanlamManaged(editingInstitution)}
            />

            {/* Separator */}
            <div style={{ gridColumn: '1 / -1', borderTop: '1px solid #f1f5f9', paddingTop: '4px' }}>
              <p style={{ margin: 0, fontSize: '12px', fontWeight: 600, color: '#64748b', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
                Admin-Managed Fields
              </p>
            </div>

            {/* Always editable */}
            <Input
              label="Area / Location"
              name="area"
              register={register}
              placeholder="e.g. Wandegeya, Nakasero, Kololo"
            />
            <Input
              label="Contact Person"
              name="contact_person"
              register={register}
              placeholder="Full name of contact"
            />
            <div style={{ gridColumn: '1 / -1' }}>
              <Input
                label="Working Hours"
                name="working_hours"
                register={register}
                placeholder="e.g. Mon–Fri 08:00–17:00"
              />
            </div>
            <Input
              label="Latitude"
              name="latitude"
              register={register}
              placeholder="e.g. 0.3476"
              type="number"
              step="any"
            />
            <Input
              label="Longitude"
              name="longitude"
              register={register}
              placeholder="e.g. 32.5825"
              type="number"
              step="any"
            />

            {/* Document upload — only when adding a new institution */}
            {!editingInstitution && (
              <div style={{ gridColumn: '1 / -1' }}>
                <div style={{ borderTop: '1px solid #f1f5f9', paddingTop: '4px', marginBottom: '10px' }}>
                  <p style={{ margin: 0, fontSize: '12px', fontWeight: 600, color: '#64748b', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
                    Supporting Documents <span style={{ fontWeight: 400, textTransform: 'none' }}>(optional, max 5 files · 10MB each)</span>
                  </p>
                  <p style={{ margin: '4px 0 0', fontSize: '12px', color: '#94a3b8' }}>
                    These will be emailed to the IT team with the provider addition request.
                  </p>
                </div>

                {/* File list */}
                {docFiles.length > 0 && (
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '6px', marginBottom: '10px' }}>
                    {docFiles.map((file, i) => (
                      <div key={i} style={{
                        display: 'flex', alignItems: 'center', gap: '8px',
                        background: '#f8fafc', border: '1px solid #e2e8f0',
                        borderRadius: '6px', padding: '6px 10px',
                      }}>
                        <PaperClipIcon style={{ width: 14, height: 14, color: '#64748b', flexShrink: 0 }} />
                        <span style={{ fontSize: '13px', flex: 1, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                          {file.name}
                        </span>
                        <span style={{ fontSize: '11px', color: '#94a3b8', flexShrink: 0 }}>
                          {(file.size / 1024).toFixed(0)} KB
                        </span>
                        <button type="button" onClick={() => removeFile(i)} style={{ background: 'none', border: 'none', cursor: 'pointer', padding: '2px', color: '#ef4444' }}>
                          <XMarkIcon style={{ width: 14, height: 14 }} />
                        </button>
                      </div>
                    ))}
                  </div>
                )}

                {docFiles.length < 5 && (
                  <label style={{
                    display: 'inline-flex', alignItems: 'center', gap: '6px',
                    padding: '8px 14px', borderRadius: '6px',
                    border: '1px dashed #94a3b8', background: '#f8fafc',
                    fontSize: '13px', color: '#64748b', cursor: 'pointer',
                  }}>
                    <PaperClipIcon style={{ width: 14, height: 14 }} />
                    Attach file
                    <input
                      ref={fileInputRef}
                      type="file"
                      multiple
                      accept=".pdf,.doc,.docx,.xls,.xlsx,.jpg,.jpeg,.png,.webp"
                      onChange={handleFileChange}
                      style={{ display: 'none' }}
                    />
                  </label>
                )}
              </div>
            )}

            <div style={{ gridColumn: '1 / -1', display: 'flex', gap: '8px', justifyContent: 'flex-end', marginTop: '4px' }}>
              <Button variant="secondary" type="button" onClick={() => { setShowModal(false); setEditingInstitution(null); setDocFiles([]); reset(); }}>
                Cancel
              </Button>
              <Button
                variant="primary"
                type="submit"
                disabled={createMutation.isPending || updateMutation.isPending}
              >
                {createMutation.isPending || updateMutation.isPending
                  ? 'Saving…'
                  : editingInstitution ? 'Save Changes' : 'Add Institution'}
              </Button>
            </div>
          </form>
        </Modal>
      )}

      {/* Suspend Modal */}
      {showSuspendModal && selectedInstitution && (
        <Modal
          title="Suspend Institution"
          onClose={() => { setShowSuspendModal(false); setSelectedInstitution(null); }}
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
              <Button variant="secondary" type="button" onClick={() => { setShowSuspendModal(false); setSelectedInstitution(null); }}>
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
