import { useEffect, useMemo, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Link } from 'react-router-dom';
import toast from 'react-hot-toast';
import {
  ArrowLeftIcon,
  DocumentTextIcon,
  PencilSquareIcon,
  MagnifyingGlassIcon,
  XMarkIcon,
  DocumentIcon,
} from '@heroicons/react/24/outline';
import Table from '../../components/UI/Table';
import Button from '../../components/UI/Button';
import Modal from '../../components/UI/Modal';
import Spinner from '../../components/UI/Spinner';
import {
  getInstitutions,
  getInstitutionPriceLists,
  updateInstitutionPriceList,
} from '../../api/hospitals';

const ACCEPTED_FILE_TYPES = '.xlsx,.xls,.csv,.doc,.docx,.pdf';

const formatDateTime = (value) => {
  if (!value) return '—';
  try { return new Date(value).toLocaleString(); } catch { return '—'; }
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
        style={{ background: 'transparent', border: 'none', cursor: disabled ? 'not-allowed' : 'pointer', padding: 6, color: '#64748b' }}
      >
        <XMarkIcon style={{ width: 18, height: 18 }} />
      </button>
    </div>
  );
};

export default function AllInstitutionPriceListsPage() {
  const qc = useQueryClient();

  const [search, setSearch] = useState('');
  const [debouncedSearch, setDebouncedSearch] = useState('');
  const [filterInstitutionId, setFilterInstitutionId] = useState('');
  const [categoryFilter, setCategoryFilter] = useState('');
  const [page, setPage] = useState(1);
  const PAGE_SIZE = 15;

  const [editingRow, setEditingRow] = useState(null);
  const [editInstitutionId, setEditInstitutionId] = useState('');
  const [editInstitutionInput, setEditInstitutionInput] = useState('');
  const [editNotes, setEditNotes] = useState('');
  const [editFile, setEditFile] = useState(null);

  useEffect(() => {
    const t = setTimeout(() => setDebouncedSearch(search.trim()), 300);
    return () => clearTimeout(t);
  }, [search]);

  useEffect(() => { setPage(1); }, [debouncedSearch, filterInstitutionId, categoryFilter]);

  const { data: institutionsData } = useQuery({
    queryKey: ['institutions-for-price-lists'],
    queryFn: () => getInstitutions().then((r) => r.data || []),
    placeholderData: [],
    retry: false,
  });
  const institutions = institutionsData || [];
  const institutionOptions = useMemo(
    () => institutions
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
    return (
      institutionOptions.find((i) => i.display.toLowerCase() === raw)?.id ||
      institutionOptions.find((i) => i.name.toLowerCase() === raw)?.id ||
      ''
    );
  };

  const { data: priceListsData, isLoading: listsLoading } = useQuery({
    queryKey: ['institution-price-lists', debouncedSearch, filterInstitutionId],
    queryFn: () => getInstitutionPriceLists({
      ...(debouncedSearch ? { search: debouncedSearch } : {}),
      ...(filterInstitutionId ? { institutionId: filterInstitutionId } : {}),
    }).then((r) => r.data || []),
    placeholderData: [],
    retry: false,
  });

  const priceLists = priceListsData || [];
  const filteredPriceLists = useMemo(
    () => categoryFilter
      ? priceLists.filter((p) => (p.institution_category || p.institution_type || '').toLowerCase() === categoryFilter)
      : priceLists,
    [priceLists, categoryFilter]
  );
  const totalPages = Math.max(1, Math.ceil(filteredPriceLists.length / PAGE_SIZE));
  const currentPage = Math.min(page, totalPages);
  const pagedPriceLists = useMemo(
    () => filteredPriceLists.slice((currentPage - 1) * PAGE_SIZE, currentPage * PAGE_SIZE),
    [filteredPriceLists, currentPage]
  );

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
    onError: (err) => toast.error(err.response?.data?.message || 'Failed to update price list'),
  });

  const openEditModal = (row) => {
    setEditingRow(row);
    setEditInstitutionId(row.institution_id || '');
    const opt = institutionOptions.find((i) => i.id === row.institution_id);
    setEditInstitutionInput(opt ? opt.display : (row.institution_name || ''));
    setEditNotes(row.notes || '');
    setEditFile(null);
  };

  const onEdit = (e) => {
    e.preventDefault();
    const resolvedId = editInstitutionId || resolveInstitutionId(editInstitutionInput);
    if (!resolvedId) return toast.error('Choose a facility from the suggestions');
    const formData = new FormData();
    formData.append('institutionId', resolvedId);
    if (editNotes) formData.append('notes', editNotes);
    if (editFile) formData.append('file', editFile);
    updateMutation.mutate({ id: editingRow.id, payload: formData });
  };

  const columns = [
    {
      key: 'institution_name',
      header: 'Facility',
      render: (value, row) => (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
          <span style={{ fontWeight: 600, color: '#0f172a' }}>{value || '—'}</span>
          <span style={{ fontSize: 11, color: '#94a3b8', textTransform: 'capitalize' }}>
            {row.institution_category || row.institution_type || '—'}
          </span>
        </div>
      ),
    },
    {
      key: 'file_name',
      header: 'Price List File',
      render: (value, row) => (
        <a href={row.file_path} target="_blank" rel="noreferrer" style={{ color: 'var(--primary)', textDecoration: 'none', fontWeight: 500 }}>
          {value || 'Open file'}
        </a>
      ),
    },
    { key: 'file_size', header: 'Size', render: (value) => <span style={{ color: '#64748b' }}>{formatBytes(value)}</span> },
    { key: 'uploaded_by_name', header: 'Uploaded By', render: (value) => <span style={{ color: 'var(--text)' }}>{value || '—'}</span> },
    { key: 'created_at', header: 'Uploaded At', render: (value) => <span style={{ color: '#64748b' }}>{formatDateTime(value)}</span> },
    {
      key: 'updated_at', header: 'Last Updated',
      render: (_, row) => (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
          <span style={{ color: '#64748b' }}>{formatDateTime(row.updated_at)}</span>
          <span style={{ fontSize: 11, color: '#94a3b8' }}>{row.updated_by_name ? `by ${row.updated_by_name}` : '—'}</span>
        </div>
      ),
    },
    {
      key: 'actions', header: 'Actions',
      render: (_, row) => (
        <Button variant="secondary" onClick={() => openEditModal(row)} style={{ padding: '4px 10px', fontSize: 12 }}>
          <PencilSquareIcon style={{ width: 14, height: 14 }} /> Edit
        </Button>
      ),
    },
  ];

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 18 }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
        <Link to="/institution-price-lists" style={{ display: 'flex', alignItems: 'center', gap: 4, color: 'var(--primary)', textDecoration: 'none', fontSize: 14 }}>
          <ArrowLeftIcon style={{ width: 16, height: 16 }} /> Back to Upload
        </Link>
      </div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
        <DocumentTextIcon style={{ width: 24, height: 24, color: 'var(--primary)' }} />
        <div>
          <h2 style={{ margin: 0, color: 'var(--text)' }}>All Institution Price Lists</h2>
          <p style={{ margin: '4px 0 0', color: '#64748b', fontSize: 13 }}>
            Search, filter and manage every uploaded price list.
          </p>
        </div>
      </div>

      <div style={{ background: '#fff', border: '1px solid #e2e8f0', borderRadius: 12, padding: 14, display: 'flex', gap: 10, flexWrap: 'wrap', alignItems: 'center' }}>
        <div style={{ position: 'relative', flex: '2 1 240px', minWidth: 220 }}>
          <MagnifyingGlassIcon style={{ position: 'absolute', left: 10, top: '50%', transform: 'translateY(-50%)', width: 16, height: 16, color: '#94a3b8' }} />
          <input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search by facility or file name..."
            style={{ width: '100%', borderRadius: 6, border: '1px solid #e2e8f0', padding: '8px 10px 8px 32px', fontSize: 14, boxSizing: 'border-box' }}
          />
        </div>
        <select value={filterInstitutionId} onChange={(e) => setFilterInstitutionId(e.target.value)}
          style={{ minWidth: 220, borderRadius: 6, border: '1px solid #e2e8f0', padding: '8px 10px' }}>
          <option value="">All facilities</option>
          {institutionOptions.map((i) => <option key={i.id} value={i.id}>{i.name}</option>)}
        </select>
        <select value={categoryFilter} onChange={(e) => setCategoryFilter(e.target.value)}
          style={{ minWidth: 160, borderRadius: 6, border: '1px solid #e2e8f0', padding: '8px 10px' }}>
          <option value="">All types</option>
          <option value="hospital">Hospital</option>
          <option value="pharmacy">Pharmacy</option>
          <option value="outpatient">Outpatient</option>
          <option value="inpatient">Inpatient</option>
          <option value="dental">Dental</option>
          <option value="optical">Optical</option>
        </select>
        {(search || filterInstitutionId || categoryFilter) && (
          <button type="button"
            onClick={() => { setSearch(''); setFilterInstitutionId(''); setCategoryFilter(''); }}
            style={{ background: 'transparent', border: '1px solid #e2e8f0', borderRadius: 6, padding: '8px 12px', cursor: 'pointer', fontSize: 13, color: '#475569' }}>
            Clear filters
          </button>
        )}
        <div style={{ marginLeft: 'auto', fontSize: 13, color: '#64748b' }}>
          {listsLoading ? 'Loading…' : (
            <>
              <strong style={{ color: '#0f172a' }}>{filteredPriceLists.length}</strong> price list{filteredPriceLists.length === 1 ? '' : 's'}
              {filteredPriceLists.length > PAGE_SIZE && <> · page <strong>{currentPage}</strong> of <strong>{totalPages}</strong></>}
            </>
          )}
        </div>
      </div>

      <div style={{ background: '#fff', borderRadius: 12, border: '1px solid #e2e8f0', overflow: 'hidden' }}>
        {listsLoading ? (
          <div style={{ padding: 30, display: 'flex', justifyContent: 'center' }}><Spinner /></div>
        ) : (
          <Table columns={columns} data={pagedPriceLists} emptyMessage="No price lists match the current filters." />
        )}
        {filteredPriceLists.length > PAGE_SIZE && (
          <div style={{ padding: 12, display: 'flex', justifyContent: 'space-between', alignItems: 'center', borderTop: '1px solid #e2e8f0', background: '#f8fafc' }}>
            <span style={{ fontSize: 13, color: '#64748b' }}>
              Showing {(currentPage - 1) * PAGE_SIZE + 1}–{Math.min(currentPage * PAGE_SIZE, filteredPriceLists.length)} of {filteredPriceLists.length}
            </span>
            <div style={{ display: 'flex', gap: 6 }}>
              <Button variant="secondary" disabled={currentPage <= 1} onClick={() => setPage((p) => Math.max(1, p - 1))} style={{ padding: '6px 12px', fontSize: 13 }}>← Previous</Button>
              <Button variant="secondary" disabled={currentPage >= totalPages} onClick={() => setPage((p) => Math.min(totalPages, p + 1))} style={{ padding: '6px 12px', fontSize: 13 }}>Next →</Button>
            </div>
          </div>
        )}
      </div>

      {editingRow && (
        <Modal title="Edit Price List" onClose={() => setEditingRow(null)} width="680px">
          <form onSubmit={onEdit} style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
            <div>
              <label style={{ fontSize: 13, fontWeight: 600, color: '#475569', marginBottom: 6, display: 'block' }}>Facility *</label>
              <input
                list="institution-price-list-options-edit"
                value={editInstitutionInput}
                onChange={(e) => { setEditInstitutionInput(e.target.value); setEditInstitutionId(resolveInstitutionId(e.target.value)); }}
                placeholder="Type facility name and choose from suggestions"
                style={{ width: '100%', padding: '8px 10px', borderRadius: 6, border: '1px solid #e2e8f0' }}
                disabled={updateMutation.isPending}
              />
              <datalist id="institution-price-list-options-edit">
                {institutionOptions.map((i) => <option key={i.id} value={i.display} />)}
              </datalist>
            </div>
            <div>
              <label style={{ fontSize: 13, fontWeight: 600, color: '#475569', marginBottom: 6, display: 'block' }}>Replace File (optional)</label>
              <input
                type="file"
                accept={ACCEPTED_FILE_TYPES}
                onChange={(e) => setEditFile(e.target.files?.[0] || null)}
                disabled={updateMutation.isPending}
                style={{ width: '100%' }}
                key={editFile ? editFile.name + editFile.size : 'empty-edit'}
              />
              <small style={{ color: '#64748b' }}>Current: {editingRow.file_name || '—'}</small>
              <FilePreviewCard file={editFile} onClear={() => setEditFile(null)} disabled={updateMutation.isPending} />
            </div>
            <div style={{ gridColumn: '1 / -1' }}>
              <label style={{ fontSize: 13, fontWeight: 600, color: '#475569', marginBottom: 6, display: 'block' }}>Notes</label>
              <textarea value={editNotes} onChange={(e) => setEditNotes(e.target.value)} rows={3}
                style={{ width: '100%', borderRadius: 6, border: '1px solid #e2e8f0', padding: 10, fontFamily: 'inherit' }}
                disabled={updateMutation.isPending} />
            </div>
            <div style={{ gridColumn: '1 / -1', display: 'flex', justifyContent: 'flex-end', gap: 8 }}>
              <Button type="button" variant="secondary" onClick={() => setEditingRow(null)}>Cancel</Button>
              <Button type="submit" variant="primary" disabled={updateMutation.isPending}>
                {updateMutation.isPending ? 'Saving...' : 'Save changes'}
              </Button>
            </div>
          </form>
        </Modal>
      )}
    </div>
  );
}
