import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { useForm } from 'react-hook-form';
import toast from 'react-hot-toast';
import * as XLSX from 'xlsx';
import {
  PlusIcon, PencilIcon, TrashIcon, CheckCircleIcon, XCircleIcon, ArrowUpTrayIcon,
} from '@heroicons/react/24/outline';
import { getSchemes, createScheme, updateScheme, deleteScheme, bulkImportSchemes, hardDeleteScheme } from '../../api/schemes';
import { getInstitutionCopays } from '../../api/hospitals';
import { useAuth } from '../../context/AuthContext';
import Table from '../../components/UI/Table';
import Badge from '../../components/UI/Badge';
import Button from '../../components/UI/Button';
import Modal from '../../components/UI/Modal';
import Input from '../../components/UI/Input';
import Spinner from '../../components/UI/Spinner';

const fmtMoney = (v) => v == null ? null : Number(v).toLocaleString('en-UG', { maximumFractionDigits: 0 });

/** Returns a label string for a copay (e.g. "OP: 10% · IP: 25%") */
const describeCopay = (c) => {
  const parts = [];
  if (c.out_patient_percent > 0) parts.push(`OP: ${c.out_patient_percent}%`);
  else if (c.out_patient > 0) parts.push(`OP: UGX ${fmtMoney(c.out_patient)}`);
  if (c.in_patient_percent > 0) parts.push(`IP: ${c.in_patient_percent}%`);
  else if (c.in_patient > 0) parts.push(`IP: UGX ${fmtMoney(c.in_patient)}`);
  if (c.dental_percent > 0) parts.push(`Dental: ${c.dental_percent}%`);
  if (c.optical_percent > 0) parts.push(`Optical: ${c.optical_percent}%`);
  if (c.pharma_percent > 0) parts.push(`Pharma: ${c.pharma_percent}%`);
  return parts.join(' · ');
};

/** Returns true if a copay applies to the given scheme name/code */
const copayAppliesToScheme = (copay, schemeName, schemeCode) => {
  const coFor = (copay.copay_for || '').trim();
  if (!coFor) return true; // universal — applies to all
  const targets = coFor.split(/[|,;]/).map((s) => s.trim().toLowerCase()).filter(Boolean);
  const name = (schemeName || '').toLowerCase();
  const code = (schemeCode || '').toLowerCase();
  return targets.some((t) => name.includes(t) || t.includes(name) || (code && (code === t || t === code)));
};

function SchemeCopaysModal({ scheme, copays, onClose }) {
  const applicable = copays.filter((c) => copayAppliesToScheme(c, scheme.name, scheme.code));
  const universal = applicable.filter((c) => !(c.copay_for || '').trim());
  const specific  = applicable.filter((c) =>  (c.copay_for || '').trim());

  return (
    <Modal title={`Co-pays for ${scheme.name}`} onClose={onClose} width="680px">
      <p style={{ margin: '0 0 16px', fontSize: '13px', color: '#64748b' }}>
        Institutions that charge co-pays applicable to <strong>{scheme.name}</strong> members.
        {copays.length === 0 && ' Sync co-pays first using the button on the Hospitals page.'}
      </p>

      {specific.length > 0 && (
        <>
          <p style={{ margin: '0 0 8px', fontSize: '13px', fontWeight: 600, color: '#1e40af' }}>
            Scheme-specific co-pays
          </p>
          <table style={{ width: '100%', borderCollapse: 'collapse', marginBottom: '20px', fontSize: '13px' }}>
            <thead>
              <tr style={{ background: '#eff6ff' }}>
                <th style={{ padding: '8px 12px', textAlign: 'left', border: '1px solid #e5e7eb', color: '#374151' }}>Institution</th>
                <th style={{ padding: '8px 12px', textAlign: 'left', border: '1px solid #e5e7eb', color: '#374151' }}>Co-pay</th>
                <th style={{ padding: '8px 12px', textAlign: 'left', border: '1px solid #e5e7eb', color: '#374151' }}>Applies to</th>
              </tr>
            </thead>
            <tbody>
              {specific.map((c) => (
                <tr key={c.id}>
                  <td style={{ padding: '8px 12px', border: '1px solid #e5e7eb', fontWeight: 500 }}>
                    {c.matched_institution_name || c.institution_name || c.sanlam_id}
                  </td>
                  <td style={{ padding: '8px 12px', border: '1px solid #e5e7eb', color: '#92400e', fontWeight: 600 }}>
                    {describeCopay(c) || '—'}
                  </td>
                  <td style={{ padding: '8px 12px', border: '1px solid #e5e7eb', color: '#64748b', fontSize: '12px' }}>
                    {c.copay_for || 'All'}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </>
      )}

      {universal.length > 0 && (
        <>
          <p style={{ margin: '0 0 8px', fontSize: '13px', fontWeight: 600, color: '#374151' }}>
            Universal co-pays <span style={{ fontWeight: 400, color: '#64748b' }}>(apply to all members)</span>
          </p>
          <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '13px' }}>
            <thead>
              <tr style={{ background: '#f9fafb' }}>
                <th style={{ padding: '8px 12px', textAlign: 'left', border: '1px solid #e5e7eb', color: '#374151' }}>Institution</th>
                <th style={{ padding: '8px 12px', textAlign: 'left', border: '1px solid #e5e7eb', color: '#374151' }}>Co-pay</th>
              </tr>
            </thead>
            <tbody>
              {universal.map((c) => (
                <tr key={c.id}>
                  <td style={{ padding: '8px 12px', border: '1px solid #e5e7eb', fontWeight: 500 }}>
                    {c.matched_institution_name || c.institution_name || c.sanlam_id}
                  </td>
                  <td style={{ padding: '8px 12px', border: '1px solid #e5e7eb', color: '#92400e', fontWeight: 600 }}>
                    {describeCopay(c) || '—'}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </>
      )}

      {applicable.length === 0 && (
        <p style={{ color: '#94a3b8', fontSize: '13px', textAlign: 'center', padding: '24px 0' }}>
          No co-pay data for this scheme yet.
        </p>
      )}

      <div style={{ display: 'flex', justifyContent: 'flex-end', marginTop: '16px' }}>
        <Button variant="secondary" onClick={onClose}>Close</Button>
      </div>
    </Modal>
  );
}

export default function SchemesPage() {
  const qc = useQueryClient();
  const { isSuperAdmin } = useAuth();
  const [showForm, setShowForm] = useState(false);
  const [editing, setEditing] = useState(null);
  const [copayScheme, setCopayScheme] = useState(null); // scheme whose copays modal is open

  const { register, handleSubmit, reset, setValue, formState: { errors } } = useForm();

  const { data: schemes = [], isLoading } = useQuery({
    queryKey: ['schemes'],
    queryFn: () => getSchemes({ include_inactive: true }).then(r => r.data),
    retry: false,
  });

  const { data: copays = [] } = useQuery({
    queryKey: ['institution-copays'],
    queryFn: () => getInstitutionCopays().then(r => r.data),
    retry: false,
    staleTime: 5 * 60 * 1000,
  });

  // Count of applicable copays per scheme (for the column badge)
  const copayCountByScheme = {};
  schemes.forEach((s) => {
    copayCountByScheme[s.id] = copays.filter((c) => copayAppliesToScheme(c, s.name, s.code)).length;
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

  const hardDeleteMutation = useMutation({
    mutationFn: hardDeleteScheme,
    onSuccess: () => {
      qc.invalidateQueries(['schemes']);
      toast.success('Scheme deleted permanently');
    },
    onError: (err) => toast.error(err.response?.data?.message || 'Failed to delete scheme'),
  });

  const importMutation = useMutation({
    mutationFn: bulkImportSchemes,
    onSuccess: (res) => {
      qc.invalidateQueries(['schemes']);
      const { created, skipped, invalid } = res.data;
      toast.success(`Import done: ${created} added, ${skipped} already existed${invalid ? `, ${invalid} invalid` : ''}`);
    },
    onError: (err) => toast.error(err.response?.data?.message || 'Bulk import failed'),
  });

  const handleExcelUpload = async (e) => {
    const file = e.target.files?.[0];
    e.target.value = '';
    if (!file) return;
    try {
      const buf = await file.arrayBuffer();
      const wb = XLSX.read(buf, { type: 'array' });
      const sheet = wb.Sheets[wb.SheetNames[0]];
      const rows = XLSX.utils.sheet_to_json(sheet, { defval: '' });
      // Accept flexible column headers (case-insensitive)
      const norm = (r) => {
        const out = {};
        for (const k of Object.keys(r)) {
          out[k.toString().trim().toLowerCase()] = r[k];
        }
        return {
          name: (out.name || out['scheme name'] || out.scheme || out.corporate || out['corporate name'] || '').toString().trim(),
          code: (out.code || out['scheme code'] || '').toString().trim(),
          description: (out.description || out.notes || '').toString().trim(),
        };
      };
      const schemes = rows.map(norm).filter((s) => s.name);
      if (!schemes.length) {
        toast.error('No valid rows. Expected a "name" column (or "Scheme Name").');
        return;
      }
      importMutation.mutate(schemes);
    } catch (err) {
      console.error(err);
      toast.error('Could not parse Excel file');
    }
  };

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
      key: 'id',
      header: 'Provider Co-pays',
      render: (id, row) => {
        const count = copayCountByScheme[id] || 0;
        return (
          <button
            type="button"
            onClick={() => setCopayScheme(row)}
            style={{
              background: count > 0 ? '#fef3c7' : '#f1f5f9',
              color: count > 0 ? '#92400e' : '#64748b',
              border: 'none', borderRadius: '999px',
              padding: '3px 10px', fontSize: '12px', fontWeight: 600,
              cursor: 'pointer',
            }}
          >
            {count > 0 ? `${count} provider${count !== 1 ? 's' : ''}` : 'No data'}
          </button>
        );
      },
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
          {isSuperAdmin && (
            <Button
              variant="danger"
              onClick={() => {
                if (window.confirm(`Permanently delete "${row.name}"? This cannot be undone.`)) {
                  hardDeleteMutation.mutate(row.id);
                }
              }}
              style={{ padding: '4px 8px', fontSize: '12px' }}
              title="Permanently delete this scheme (super admin only)"
            >
              <TrashIcon style={{ width: 13, height: 13 }} /> Delete
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
        <div style={{ display: 'flex', gap: '8px' }}>
          <label style={{ display: 'inline-flex', alignItems: 'center', gap: '6px', padding: '8px 14px', background: '#fff', border: '1px solid #d1d5db', borderRadius: '8px', fontSize: '13px', fontWeight: 500, color: 'var(--text)', cursor: importMutation.isPending ? 'not-allowed' : 'pointer', opacity: importMutation.isPending ? 0.6 : 1 }}>
            <ArrowUpTrayIcon style={{ width: 15, height: 15 }} />
            {importMutation.isPending ? 'Importing…' : 'Import Excel'}
            <input
              type="file"
              accept=".xlsx,.xls,.csv"
              onChange={handleExcelUpload}
              disabled={importMutation.isPending}
              style={{ display: 'none' }}
            />
          </label>
          <Button variant="primary" onClick={() => { reset({ name: '', code: '' }); setShowForm(true); }}>
            <PlusIcon style={{ width: 15, height: 15 }} /> Add Scheme
          </Button>
        </div>
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

      {copayScheme && (
        <SchemeCopaysModal
          scheme={copayScheme}
          copays={copays}
          onClose={() => setCopayScheme(null)}
        />
      )}
    </div>
  );
}
