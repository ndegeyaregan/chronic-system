import { useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import toast from 'react-hot-toast';
import {
  ArrowUpTrayIcon,
  PencilSquareIcon,
  DocumentTextIcon,
  DocumentIcon,
  XMarkIcon,
  ArrowRightIcon,
} from '@heroicons/react/24/outline';
import Table from '../../components/UI/Table';
import Button from '../../components/UI/Button';
import Modal from '../../components/UI/Modal';
import Spinner from '../../components/UI/Spinner';
import {
  getInstitutions,
  getInstitutionPriceLists,
  createInstitutionPriceList,
  updateInstitutionPriceList,
} from '../../api/hospitals';

const ACCEPTED_FILE_TYPES = '.xlsx,.xls,.csv,.doc,.docx,.pdf';

const formatDateTime = (value) => {
  if (!value) return '—';
  try {
    return new Date(value).toLocaleString();
  } catch {
    return '—';
  }
};

const formatBytes = (bytes) => {
  if (!bytes && bytes !== 0) return '—';
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(2)} MB`;
};

const fileExtBadge = (name) => {
  if (!name) return '';
  const ext = String(name).split('.').pop().toLowerCase();
  return ext.length <= 5 ? ext.toUpperCase() : '';
};

const FilePreviewCard = ({ file, onClear, disabled }) => {
  if (!file) return null;
  const ext = fileExtBadge(file.name);
  const isSpreadsheet = ['XLSX', 'XLS', 'CSV'].includes(ext);
  return (
    <div style={{
      marginTop: 10, padding: 12, background: isSpreadsheet ? '#ecfdf5' : '#f8fafc',
      border: `1px solid ${isSpreadsheet ? '#86efac' : '#e2e8f0'}`,
      borderRadius: 8, display: 'flex', alignItems: 'center', gap: 12,
    }}>
      <div style={{
        width: 42, height: 42, borderRadius: 8,
        background: isSpreadsheet ? '#16a34a' : '#64748b',
        color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center',
        fontWeight: 700, fontSize: 12, flexShrink: 0,
      }}>
        {ext || <DocumentIcon style={{ width: 22, height: 22 }} />}
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontWeight: 600, color: '#0f172a', fontSize: 14, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
          {file.name}
        </div>
        <div style={{ fontSize: 12, color: '#64748b', marginTop: 2 }}>
          {formatBytes(file.size)} · {file.type || 'unknown type'}
          {isSpreadsheet && <span style={{ marginLeft: 8, color: '#15803d', fontWeight: 600 }}>✓ Service prices will be auto-extracted</span>}
        </div>
      </div>
      <button
        type="button" onClick={onClear} disabled={disabled}
        title="Remove selected file"
        style={{ background: 'transparent', border: 'none', cursor: disabled ? 'not-allowed' : 'pointer', padding: 6, color: '#64748b' }}
      >
        <XMarkIcon style={{ width: 18, height: 18 }} />
      </button>
    </div>
  );
};

export default function InstitutionPriceListPage() {
  const qc = useQueryClient();
  const [institutionId, setInstitutionId] = useState('');
  const [institutionInput, setInstitutionInput] = useState('');
  const [notes, setNotes] = useState('');
  const [file, setFile] = useState(null);
  const [editingRow, setEditingRow] = useState(null);
  const [editInstitutionId, setEditInstitutionId] = useState('');
  const [editInstitutionInput, setEditInstitutionInput] = useState('');
  const [editNotes, setEditNotes] = useState('');
  const [editFile, setEditFile] = useState(null);

  const RECENT_LIMIT = 5;

  const { data: institutionsData, isLoading: institutionsLoading } = useQuery({
    queryKey: ['institutions-for-price-lists'],
    queryFn: () => getInstitutions().then((r) => r.data || []),
    placeholderData: [],
    retry: false,
  });

  const institutions = institutionsData || [];
  const institutionOptions = useMemo(
    () =>
      institutions
        .map((i) => ({
          id: i.id,
          name: i.name || 'Unnamed Institution',
          category: i.category || 'unknown',
          display: `${i.name || 'Unnamed Institution'} (${i.category || 'unknown'})`,
        }))
        .sort((a, b) => a.name.localeCompare(b.name)),
    [institutions]
  );

  const resolveInstitutionId = (inputValue) => {
    const raw = String(inputValue || '').trim().toLowerCase();
    if (!raw) return '';
    const byDisplay = institutionOptions.find((i) => i.display.toLowerCase() === raw);
    if (byDisplay) return byDisplay.id;
    const byName = institutionOptions.find((i) => i.name.toLowerCase() === raw);
    if (byName) return byName.id;
    return '';
  };

  const { data: priceListsData, isLoading: listsLoading } = useQuery({
    queryKey: ['institution-price-lists'],
    queryFn: () => getInstitutionPriceLists().then((r) => r.data || []),
    placeholderData: [],
    retry: false,
  });

  const priceLists = priceListsData || [];
  const recentPriceLists = useMemo(() => priceLists.slice(0, RECENT_LIMIT), [priceLists]);

  const uploadMutation = useMutation({
    mutationFn: createInstitutionPriceList,
    onSuccess: (res) => {
      const summary = res?.data?.importSummary;
      if (summary && (summary.created || summary.updated)) {
        toast.success(`Uploaded. Extracted ${summary.created} new + ${summary.updated} updated service prices (${summary.skipped} skipped).`);
      } else if (summary && summary.total === 0) {
        toast.success('Price list uploaded (no service rows extracted — check Service / Price columns).');
      } else {
        toast.success('Price list uploaded successfully');
      }
      setNotes('');
      setInstitutionId('');
      setInstitutionInput('');
      setFile(null);
      qc.invalidateQueries(['institution-price-lists']);
    },
    onError: (err) => {
      toast.error(err.response?.data?.message || 'Failed to upload price list');
    },
  });

  const updateMutation = useMutation({
    mutationFn: ({ id, payload }) => updateInstitutionPriceList(id, payload),
    onSuccess: (res) => {
      const summary = res?.data?.importSummary;
      if (summary && (summary.created || summary.updated)) {
        toast.success(`Updated. Re-extracted ${summary.created} new + ${summary.updated} updated prices.`);
      } else {
        toast.success('Price list updated successfully');
      }
      setEditingRow(null);
      setEditInstitutionId('');
      setEditInstitutionInput('');
      setEditNotes('');
      setEditFile(null);
      qc.invalidateQueries(['institution-price-lists']);
    },
    onError: (err) => {
      toast.error(err.response?.data?.message || 'Failed to update price list');
    },
  });

  const onUpload = (e) => {
    e.preventDefault();
    const resolvedInstitutionId = institutionId || resolveInstitutionId(institutionInput);
    if (!resolvedInstitutionId) {
      toast.error('Please type and select a valid facility name');
      return;
    }
    if (!file) {
      toast.error('Please choose a price list file');
      return;
    }
    uploadMutation.mutate({
      institutionId: resolvedInstitutionId,
      notes,
      file,
    });
  };

  const openEditModal = (row) => {
    setEditingRow(row);
    setEditInstitutionId(row.institution_id || '');
    setEditInstitutionInput(
      `${row.institution_name || 'Unknown Institution'} (${row.institution_category || row.institution_type || 'unknown'})`
    );
    setEditNotes(row.notes || '');
    setEditFile(null);
  };

  const onEdit = (e) => {
    e.preventDefault();
    if (!editingRow?.id) return;
    const resolvedInstitutionId = editInstitutionId || resolveInstitutionId(editInstitutionInput);
    if (!resolvedInstitutionId) {
      toast.error('Please type and select a valid facility name');
      return;
    }
    updateMutation.mutate({
      id: editingRow.id,
      payload: {
        institutionId: resolvedInstitutionId,
        notes: editNotes,
        ...(editFile ? { file: editFile } : {}),
      },
    });
  };

  const columns = [
    {
      key: 'institution_name',
      header: 'Facility',
      render: (_, row) => (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
          <span style={{ fontWeight: 600, color: 'var(--text)' }}>{row.institution_name || '—'}</span>
          <span style={{ fontSize: 12, color: '#64748b', textTransform: 'capitalize' }}>
            {row.institution_category || row.institution_type || '—'}
          </span>
        </div>
      ),
    },
    {
      key: 'file_name',
      header: 'Price List File',
      render: (value, row) => (
        <a
          href={row.file_path}
          target="_blank"
          rel="noreferrer"
          style={{ color: 'var(--primary)', textDecoration: 'none', fontWeight: 500 }}
        >
          {value || 'Open file'}
        </a>
      ),
    },
    {
      key: 'file_size',
      header: 'Size',
      render: (value) => <span style={{ color: '#64748b' }}>{formatBytes(value)}</span>,
    },
    {
      key: 'uploaded_by_name',
      header: 'Uploaded By',
      render: (value) => <span style={{ color: 'var(--text)' }}>{value || '—'}</span>,
    },
    {
      key: 'created_at',
      header: 'Uploaded At',
      render: (value) => <span style={{ color: '#64748b' }}>{formatDateTime(value)}</span>,
    },
    {
      key: 'updated_at',
      header: 'Last Updated',
      render: (_, row) => (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
          <span style={{ color: '#64748b' }}>{formatDateTime(row.updated_at)}</span>
          <span style={{ fontSize: 11, color: '#94a3b8' }}>
            {row.updated_by_name ? `by ${row.updated_by_name}` : '—'}
          </span>
        </div>
      ),
    },
    {
      key: 'actions',
      header: 'Actions',
      render: (_, row) => (
        <Button
          variant="secondary"
          onClick={() => openEditModal(row)}
          style={{ padding: '4px 10px', fontSize: 12 }}
        >
          <PencilSquareIcon style={{ width: 14, height: 14 }} /> Edit
        </Button>
      ),
    },
  ];

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 18 }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
        <DocumentTextIcon style={{ width: 24, height: 24, color: 'var(--primary)' }} />
        <div>
          <h2 style={{ margin: 0, color: 'var(--text)' }}>Instution Price List</h2>
          <p style={{ margin: '4px 0 0', color: '#64748b', fontSize: 13 }}>
            Select a facility and upload its price list. Uploader name and upload date/time are logged automatically.
          </p>
        </div>
      </div>

      <form
        onSubmit={onUpload}
        style={{
          background: '#fff',
          border: '1px solid #e2e8f0',
          borderRadius: 12,
          padding: 16,
          display: 'grid',
          gridTemplateColumns: 'repeat(2, minmax(0, 1fr))',
          gap: 12,
        }}
      >
        <div>
          <label style={{ fontSize: 13, fontWeight: 600, color: '#475569', marginBottom: 6, display: 'block' }}>
            Facility *
          </label>
          <input
            list="institution-price-list-options"
            value={institutionInput}
            onChange={(e) => {
              const value = e.target.value;
              setInstitutionInput(value);
              setInstitutionId(resolveInstitutionId(value));
            }}
            placeholder="Type facility name and choose from suggestions"
            style={{ width: '100%', padding: '8px 10px', borderRadius: 6, border: '1px solid #e2e8f0' }}
            disabled={institutionsLoading || uploadMutation.isPending}
          />
          <datalist id="institution-price-list-options">
            {institutionOptions.map((i) => (
              <option key={i.id} value={i.display} />
            ))}
          </datalist>
        </div>

        <div>
          <label style={{ fontSize: 13, fontWeight: 600, color: '#475569', marginBottom: 6, display: 'block' }}>
            Price List File * (Excel/Word/PDF)
          </label>
          <input
            type="file"
            accept={ACCEPTED_FILE_TYPES}
            onChange={(e) => setFile(e.target.files?.[0] || null)}
            disabled={uploadMutation.isPending}
            style={{ width: '100%' }}
            key={file ? file.name + file.size : 'empty'}
          />
          <small style={{ color: '#64748b' }}>
            Supported: .xlsx, .xls, .csv, .doc, .docx, .pdf
          </small>
          <FilePreviewCard file={file} onClear={() => setFile(null)} disabled={uploadMutation.isPending} />
          <div style={{ marginTop: 8, padding: '8px 10px', background: '#f0f9ff', border: '1px solid #bae6fd', borderRadius: 6, fontSize: 12, color: '#075985' }}>
            <strong>Auto-extract tip:</strong> upload an Excel/CSV with columns <code>Service</code>, <code>Price</code> (optional <code>Category</code>, <code>Currency</code>) and prices will be auto-extracted into the comparison page.
            <div style={{ marginTop: 6 }}>
              Download template:{' '}
              <a href="/service-price-list-template.xlsx" download style={{ color: 'var(--primary)', fontWeight: 600, marginRight: 12 }}>Excel (.xlsx)</a>
              <a href="/service-price-list-template.csv" download style={{ color: 'var(--primary)', fontWeight: 600 }}>CSV</a>
            </div>
          </div>
        </div>

        <div style={{ gridColumn: '1 / -1' }}>
          <label style={{ fontSize: 13, fontWeight: 600, color: '#475569', marginBottom: 6, display: 'block' }}>
            Notes (optional)
          </label>
          <textarea
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
            rows={3}
            style={{
              width: '100%',
              borderRadius: 6,
              border: '1px solid #e2e8f0',
              padding: 10,
              fontFamily: 'inherit',
            }}
            placeholder="e.g. April 2026 approved rates"
            disabled={uploadMutation.isPending}
          />
        </div>

        <div style={{ gridColumn: '1 / -1', display: 'flex', justifyContent: 'flex-end' }}>
          <Button type="submit" variant="primary" disabled={uploadMutation.isPending || institutionsLoading}>
            <ArrowUpTrayIcon style={{ width: 15, height: 15 }} />
            {uploadMutation.isPending ? 'Uploading...' : 'Upload Price List'}
          </Button>
        </div>
      </form>

      <div
        style={{
          background: '#fff',
          border: '1px solid #e2e8f0',
          borderRadius: 12,
          padding: 14,
          display: 'flex',
          gap: 10,
          flexWrap: 'wrap',
          alignItems: 'center',
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <DocumentTextIcon style={{ width: 18, height: 18, color: '#0f172a' }} />
          <strong style={{ fontSize: 15, color: '#0f172a' }}>Recent uploads</strong>
          <span style={{ fontSize: 12, color: '#94a3b8' }}>(latest 5)</span>
        </div>
        <Link
          to="/institution-price-lists/all"
          style={{
            marginLeft: 'auto', display: 'inline-flex', alignItems: 'center', gap: 6,
            background: 'var(--primary)', color: '#fff', textDecoration: 'none',
            padding: '8px 14px', borderRadius: 6, fontSize: 13, fontWeight: 600,
          }}
        >
          View all price lists <ArrowRightIcon style={{ width: 14, height: 14 }} />
        </Link>
      </div>

      <div style={{ background: '#fff', borderRadius: 12, border: '1px solid #e2e8f0', overflow: 'hidden' }}>
        {listsLoading ? (
          <div style={{ padding: 30, display: 'flex', justifyContent: 'center' }}>
            <Spinner />
          </div>
        ) : (
          <Table columns={columns} data={recentPriceLists} emptyMessage="No price lists uploaded yet — upload your first one above." />
        )}
        {priceLists.length > RECENT_LIMIT && (
          <div style={{ padding: 12, textAlign: 'center', borderTop: '1px solid #e2e8f0', background: '#f8fafc', fontSize: 13, color: '#64748b' }}>
            Showing the {RECENT_LIMIT} most recent of {priceLists.length} total ·{' '}
            <Link to="/institution-price-lists/all" style={{ color: 'var(--primary)', fontWeight: 600 }}>Browse all →</Link>
          </div>
        )}
      </div>

      {editingRow && (
        <Modal title="Edit Price List" onClose={() => setEditingRow(null)} width="680px">
          <form onSubmit={onEdit} style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
            <div>
              <label style={{ fontSize: 13, fontWeight: 600, color: '#475569', marginBottom: 6, display: 'block' }}>
                Facility *
              </label>
              <input
                list="institution-price-list-options-edit"
                value={editInstitutionInput}
                onChange={(e) => {
                  const value = e.target.value;
                  setEditInstitutionInput(value);
                  setEditInstitutionId(resolveInstitutionId(value));
                }}
                placeholder="Type facility name and choose from suggestions"
                style={{ width: '100%', padding: '8px 10px', borderRadius: 6, border: '1px solid #e2e8f0' }}
                disabled={updateMutation.isPending}
              />
              <datalist id="institution-price-list-options-edit">
                {institutionOptions.map((i) => (
                  <option key={i.id} value={i.display} />
                ))}
              </datalist>
            </div>

            <div>
              <label style={{ fontSize: 13, fontWeight: 600, color: '#475569', marginBottom: 6, display: 'block' }}>
                Replace File (optional)
              </label>
              <input
                type="file"
                accept={ACCEPTED_FILE_TYPES}
                onChange={(e) => setEditFile(e.target.files?.[0] || null)}
                disabled={updateMutation.isPending}
                style={{ width: '100%' }}
                key={editFile ? editFile.name + editFile.size : 'empty-edit'}
              />
              <small style={{ color: '#64748b' }}>
                Current: {editingRow.file_name || '—'}
              </small>
              <FilePreviewCard file={editFile} onClear={() => setEditFile(null)} disabled={updateMutation.isPending} />
            </div>

            <div style={{ gridColumn: '1 / -1' }}>
              <label style={{ fontSize: 13, fontWeight: 600, color: '#475569', marginBottom: 6, display: 'block' }}>
                Notes
              </label>
              <textarea
                value={editNotes}
                onChange={(e) => setEditNotes(e.target.value)}
                rows={3}
                style={{
                  width: '100%',
                  borderRadius: 6,
                  border: '1px solid #e2e8f0',
                  padding: 10,
                  fontFamily: 'inherit',
                }}
                disabled={updateMutation.isPending}
              />
            </div>

            <div style={{ gridColumn: '1 / -1', display: 'flex', justifyContent: 'flex-end', gap: 8 }}>
              <Button type="button" variant="secondary" onClick={() => setEditingRow(null)}>
                Cancel
              </Button>
              <Button type="submit" variant="primary" disabled={updateMutation.isPending}>
                {updateMutation.isPending ? 'Saving...' : 'Save Changes'}
              </Button>
            </div>
          </form>
        </Modal>
      )}
    </div>
  );
}
