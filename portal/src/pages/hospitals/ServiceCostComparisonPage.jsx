import { useEffect, useMemo, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import toast from 'react-hot-toast';
import {
  MagnifyingGlassIcon, BuildingOffice2Icon, CurrencyDollarIcon,
  XMarkIcon, ArrowsRightLeftIcon,
} from '@heroicons/react/24/outline';
import Table from '../../components/UI/Table';
import Button from '../../components/UI/Button';
import Modal from '../../components/UI/Modal';
import Spinner from '../../components/UI/Spinner';
import { getInstitutions } from '../../api/hospitals';
import {
  getServices,
  getServicePriceComparisons,
  createInstitutionServicePrice,
  updateInstitutionServicePrice,
} from '../../api/servicePrices';
import { useAuth } from '../../context/AuthContext';

const formatMoney = (price, currency) => {
  const value = Number(price || 0);
  if (!Number.isFinite(value)) return '—';
  return `${currency || 'UGX'} ${value.toLocaleString(undefined, { minimumFractionDigits: 0, maximumFractionDigits: 2 })}`;
};

const formatDate = (value) => {
  if (!value) return '—';
  try { return new Date(value).toLocaleDateString(); } catch { return value; }
};

export default function ServiceCostComparisonPage() {
  const qc = useQueryClient();
  const { user } = useAuth();
  const isAdmin = user?.role && ['admin', 'super_admin', 'support_admin'].includes(user.role);

  const [search, setSearch] = useState('');
  const [debounced, setDebounced] = useState('');
  const [selectedService, setSelectedService] = useState(null);
  const [city, setCity] = useState('');
  const [category, setCategory] = useState('');

  const [showAddModal, setShowAddModal] = useState(false);
  const [editingPrice, setEditingPrice] = useState(null);
  const [institutionInput, setInstitutionInput] = useState('');
  const [institutionIdInput, setInstitutionIdInput] = useState('');
  const [priceInput, setPriceInput] = useState('');
  const [currencyInput, setCurrencyInput] = useState('UGX');
  const [notesInput, setNotesInput] = useState('');

  useEffect(() => {
    const t = setTimeout(() => setDebounced(search.trim()), 250);
    return () => clearTimeout(t);
  }, [search]);

  const { data: suggestionsData, isFetching: suggestionsLoading } = useQuery({
    queryKey: ['service-suggestions', debounced],
    queryFn: () => getServices({ search: debounced }).then((r) => r.data || []),
    enabled: debounced.length >= 2 && !selectedService,
    placeholderData: [],
    retry: false,
  });
  const suggestions = suggestionsData || [];

  const { data: comparisonsData, isLoading: comparisonsLoading } = useQuery({
    queryKey: ['service-price-compare', selectedService?.id, city, category],
    queryFn: () => getServicePriceComparisons({
      serviceId: selectedService.id,
      ...(city ? { city } : {}),
      ...(category ? { category } : {}),
    }).then((r) => r.data || []),
    enabled: !!selectedService?.id,
    placeholderData: [],
    retry: false,
  });
  const comparisons = comparisonsData || [];

  const { data: institutionsData } = useQuery({
    queryKey: ['institutions-for-service-prices'],
    queryFn: () => getInstitutions().then((r) => r.data || []),
    enabled: showAddModal,
    placeholderData: [],
    retry: false,
  });
  const institutionOptions = useMemo(
    () => (institutionsData || [])
      .map((i) => ({ id: i.id, name: i.name || 'Unnamed', display: `${i.name || 'Unnamed'} (${i.category || 'unknown'})` }))
      .sort((a, b) => a.name.localeCompare(b.name)),
    [institutionsData]
  );

  const resolveInstitutionId = (value) => {
    const needle = String(value || '').trim().toLowerCase();
    if (!needle) return '';
    return (
      institutionOptions.find((i) => i.display.toLowerCase() === needle)?.id ||
      institutionOptions.find((i) => i.name.toLowerCase() === needle)?.id ||
      ''
    );
  };

  const savePrice = useMutation({
    mutationFn: (payload) => editingPrice?.id
      ? updateInstitutionServicePrice(editingPrice.id, payload)
      : createInstitutionServicePrice(payload),
    onSuccess: () => {
      toast.success(editingPrice ? 'Price updated' : 'Price added');
      setShowAddModal(false); setEditingPrice(null);
      setInstitutionInput(''); setInstitutionIdInput('');
      setPriceInput(''); setCurrencyInput('UGX'); setNotesInput('');
      qc.invalidateQueries({ queryKey: ['service-price-compare'] });
    },
    onError: (err) => toast.error(err.response?.data?.message || 'Failed to save price'),
  });

  const onPickSuggestion = (svc) => {
    setSelectedService({ id: svc.id, name: svc.name, category: svc.category });
    setSearch(svc.name);
  };

  const onClearSelection = () => {
    setSelectedService(null);
    setSearch(''); setDebounced(''); setCity(''); setCategory('');
  };

  const openAddPrice = () => {
    setEditingPrice(null);
    setInstitutionInput(''); setInstitutionIdInput('');
    setPriceInput(''); setCurrencyInput('UGX'); setNotesInput('');
    setShowAddModal(true);
  };

  const openEditPrice = (row) => {
    setEditingPrice(row);
    setInstitutionInput(`${row.institution_name} (${row.institution_category || row.institution_type})`);
    setInstitutionIdInput(row.institution_id || '');
    setPriceInput(String(row.price ?? ''));
    setCurrencyInput(row.currency || 'UGX');
    setNotesInput(row.notes || '');
    setShowAddModal(true);
  };

  const submitSavePrice = (e) => {
    e.preventDefault();
    const facilityId = institutionIdInput || resolveInstitutionId(institutionInput);
    if (!editingPrice && !facilityId) return toast.error('Pick a facility from the list');
    if (!priceInput) return toast.error('Price is required');
    savePrice.mutate({
      institutionId: facilityId,
      serviceId: selectedService.id,
      price: priceInput,
      currency: currencyInput,
      notes: notesInput || undefined,
    });
  };

  const columns = [
    {
      key: 'institution_name', header: 'Facility',
      render: (_, row) => (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
          <span style={{ fontWeight: 600, color: '#0f172a' }}>{row.institution_name || '—'}</span>
          <span style={{ fontSize: 12, color: '#64748b', textTransform: 'capitalize' }}>
            {(row.institution_category || row.institution_type || '—')}
            {row.institution_city ? ` · ${row.institution_city}` : ''}
          </span>
        </div>
      ),
    },
    {
      key: 'price', header: 'Price',
      render: (_, row, idx) => (
        <strong style={{ color: idx === 0 ? '#16a34a' : '#0f172a', fontSize: 15 }}>
          {formatMoney(row.price, row.currency)}
          {idx === 0 && <span style={{ marginLeft: 8, fontSize: 11, background: '#dcfce7', color: '#166534', padding: '2px 6px', borderRadius: 10 }}>Lowest</span>}
        </strong>
      ),
    },
    {
      key: 'effective_from', header: 'Updated',
      render: (_, row) => <span style={{ color: '#64748b', fontSize: 12 }}>{formatDate(row.effective_from || row.updated_at)}</span>,
    },
    {
      key: 'source_file_name', header: 'Source',
      render: (_, row) => row.source_file_path ? (
        <a href={row.source_file_path} target="_blank" rel="noreferrer" style={{ color: 'var(--primary)', textDecoration: 'none', fontSize: 12 }}>
          {row.source_file_name || 'View'}
        </a>
      ) : <span style={{ color: '#cbd5e1' }}>—</span>,
    },
    ...(isAdmin ? [{
      key: 'actions', header: 'Actions',
      render: (_, row) => (
        <Button variant="ghost" onClick={() => openEditPrice(row)} style={{ padding: '4px 8px', fontSize: 12 }}>Edit</Button>
      ),
    }] : []),
  ];

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 18 }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
        <ArrowsRightLeftIcon style={{ width: 24, height: 24, color: 'var(--primary)' }} />
        <div>
          <h2 style={{ margin: 0, color: 'var(--text)' }}>Service Cost Comparison</h2>
          <p style={{ margin: '4px 0 0', color: '#64748b', fontSize: 13 }}>
            Search for any procedure, test or service and compare prices across hospitals & pharmacies.
          </p>
        </div>
      </div>

      <div style={{ position: 'relative', background: '#fff', border: '1px solid #e2e8f0', borderRadius: 12, padding: 16 }}>
        <label style={{ display: 'block', fontSize: 13, fontWeight: 600, color: '#475569', marginBottom: 8 }}>
          Search for a service or procedure
        </label>
        <div style={{ position: 'relative' }}>
          <MagnifyingGlassIcon style={{ position: 'absolute', left: 12, top: '50%', transform: 'translateY(-50%)', width: 18, height: 18, color: '#94a3b8' }} />
          <input
            type="text"
            value={search}
            onChange={(e) => { setSearch(e.target.value); if (selectedService) setSelectedService(null); }}
            placeholder="e.g. CT Scan, MRI, Full Blood Count, Consultation…"
            autoFocus
            style={{
              width: '100%', padding: '12px 40px 12px 40px',
              borderRadius: 8, border: '1px solid #cbd5e1',
              fontSize: 15, fontFamily: 'inherit', boxSizing: 'border-box',
            }}
          />
          {(search || selectedService) && (
            <button
              type="button" onClick={onClearSelection}
              style={{ position: 'absolute', right: 8, top: '50%', transform: 'translateY(-50%)', background: 'transparent', border: 'none', cursor: 'pointer', padding: 6 }}
              aria-label="Clear"
            >
              <XMarkIcon style={{ width: 16, height: 16, color: '#94a3b8' }} />
            </button>
          )}
        </div>

        {!selectedService && debounced.length >= 2 && (
          <div style={{ marginTop: 8, maxHeight: 280, overflowY: 'auto', border: '1px solid #e2e8f0', borderRadius: 8, background: '#fff' }}>
            {suggestionsLoading ? (
              <div style={{ padding: 14, fontSize: 13, color: '#94a3b8' }}>Searching…</div>
            ) : suggestions.length === 0 ? (
              <div style={{ padding: 14, fontSize: 13, color: '#94a3b8' }}>
                No services match "{debounced}". {isAdmin && 'Upload a price list at /institution-price-lists.'}
              </div>
            ) : suggestions.map((s) => (
              <div
                key={s.id}
                onClick={() => onPickSuggestion(s)}
                style={{ padding: '10px 14px', cursor: 'pointer', borderBottom: '1px solid #f1f5f9', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}
                onMouseEnter={(e) => e.currentTarget.style.background = '#f8fafc'}
                onMouseLeave={(e) => e.currentTarget.style.background = '#fff'}
              >
                <div>
                  <div style={{ fontSize: 14, fontWeight: 500, color: '#0f172a' }}>{s.name}</div>
                  {s.category && <div style={{ fontSize: 11, color: '#94a3b8', marginTop: 2 }}>{s.category}</div>}
                </div>
                <BuildingOffice2Icon style={{ width: 16, height: 16, color: '#cbd5e1' }} />
              </div>
            ))}
          </div>
        )}
      </div>

      {selectedService && (
        <>
          <div style={{ background: '#fff', border: '1px solid #e2e8f0', borderRadius: 12, padding: 12, display: 'flex', gap: 10, flexWrap: 'wrap', alignItems: 'center' }}>
            <div style={{ flex: '1 1 240px', fontSize: 14 }}>
              Comparing <strong style={{ color: '#0f172a' }}>{selectedService.name}</strong>
              {selectedService.category && <span style={{ color: '#94a3b8', marginLeft: 6 }}>· {selectedService.category}</span>}
            </div>
            <input
              value={city} onChange={(e) => setCity(e.target.value)}
              placeholder="Filter by city"
              style={{ padding: '8px 10px', borderRadius: 6, border: '1px solid #e2e8f0', fontSize: 13, width: 160 }}
            />
            <select
              value={category} onChange={(e) => setCategory(e.target.value)}
              style={{ padding: '8px 10px', borderRadius: 6, border: '1px solid #e2e8f0', fontSize: 13 }}
            >
              <option value="">All facility types</option>
              <option value="outpatient">Outpatient</option>
              <option value="inpatient">Inpatient</option>
              <option value="pharmacy">Pharmacy</option>
              <option value="dental">Dental</option>
              <option value="optical">Optical</option>
            </select>
            {isAdmin && (
              <Button variant="primary" onClick={openAddPrice} style={{ fontSize: 13 }}>
                <CurrencyDollarIcon style={{ width: 14, height: 14 }} /> Add price
              </Button>
            )}
          </div>

          {!comparisonsLoading && comparisons.length > 0 && (
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 10 }}>
              <div style={{ background: '#dcfce7', border: '1px solid #86efac', borderRadius: 10, padding: 12 }}>
                <div style={{ fontSize: 11, color: '#166534', textTransform: 'uppercase', fontWeight: 600 }}>Lowest</div>
                <div style={{ fontSize: 18, fontWeight: 700, color: '#14532d', marginTop: 4 }}>
                  {formatMoney(comparisons[0].price, comparisons[0].currency)}
                </div>
                <div style={{ fontSize: 12, color: '#166534', marginTop: 2 }}>{comparisons[0].institution_name}</div>
              </div>
              <div style={{ background: '#fef3c7', border: '1px solid #fcd34d', borderRadius: 10, padding: 12 }}>
                <div style={{ fontSize: 11, color: '#92400e', textTransform: 'uppercase', fontWeight: 600 }}>Highest</div>
                <div style={{ fontSize: 18, fontWeight: 700, color: '#78350f', marginTop: 4 }}>
                  {formatMoney(comparisons[comparisons.length - 1].price, comparisons[comparisons.length - 1].currency)}
                </div>
                <div style={{ fontSize: 12, color: '#92400e', marginTop: 2 }}>{comparisons[comparisons.length - 1].institution_name}</div>
              </div>
              <div style={{ background: '#e0f2fe', border: '1px solid #7dd3fc', borderRadius: 10, padding: 12 }}>
                <div style={{ fontSize: 11, color: '#075985', textTransform: 'uppercase', fontWeight: 600 }}>Facilities</div>
                <div style={{ fontSize: 18, fontWeight: 700, color: '#0c4a6e', marginTop: 4 }}>{comparisons.length}</div>
                <div style={{ fontSize: 12, color: '#075985', marginTop: 2 }}>offering this service</div>
              </div>
            </div>
          )}

          <div style={{ background: '#fff', borderRadius: 12, border: '1px solid #e2e8f0', overflow: 'hidden' }}>
            {comparisonsLoading ? (
              <div style={{ padding: 30, display: 'flex', justifyContent: 'center' }}><Spinner /></div>
            ) : (
              <Table
                columns={columns}
                data={comparisons}
                emptyMessage="No facilities have published a price for this service yet."
              />
            )}
          </div>
        </>
      )}

      {!selectedService && debounced.length < 2 && (
        <div style={{ background: '#fff', border: '1px dashed #cbd5e1', borderRadius: 12, padding: 40, textAlign: 'center' }}>
          <MagnifyingGlassIcon style={{ width: 36, height: 36, color: '#cbd5e1', margin: '0 auto 12px' }} />
          <div style={{ fontSize: 15, fontWeight: 600, color: '#475569' }}>Start typing to find a service</div>
          <div style={{ fontSize: 13, color: '#94a3b8', marginTop: 6 }}>
            Try "CT Scan", "MRI", "Consultation" or any procedure name.
          </div>
          {isAdmin && (
            <div style={{ fontSize: 12, color: '#94a3b8', marginTop: 14 }}>
              Tip: upload facility price lists at <strong>/institution-price-lists</strong> — services are auto-extracted from Excel/CSV files.
            </div>
          )}
        </div>
      )}

      {showAddModal && selectedService && (
        <Modal title={editingPrice ? `Edit price · ${selectedService.name}` : `Add price · ${selectedService.name}`} onClose={() => setShowAddModal(false)} width="640px">
          <form onSubmit={submitSavePrice} style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
            <div style={{ gridColumn: '1 / -1' }}>
              <label style={{ display: 'block', fontSize: 13, fontWeight: 600, color: '#475569', marginBottom: 6 }}>Facility *</label>
              <input
                list="svc-price-facilities"
                value={institutionInput}
                onChange={(e) => { setInstitutionInput(e.target.value); setInstitutionIdInput(resolveInstitutionId(e.target.value)); }}
                placeholder="Type facility name…"
                disabled={!!editingPrice || savePrice.isPending}
                style={{ width: '100%', padding: '8px 10px', borderRadius: 6, border: '1px solid #e2e8f0', boxSizing: 'border-box' }}
              />
              <datalist id="svc-price-facilities">
                {institutionOptions.map((i) => <option key={i.id} value={i.display} />)}
              </datalist>
            </div>
            <div>
              <label style={{ display: 'block', fontSize: 13, fontWeight: 600, color: '#475569', marginBottom: 6 }}>Price *</label>
              <input
                type="number" min="0" step="0.01"
                value={priceInput} onChange={(e) => setPriceInput(e.target.value)}
                style={{ width: '100%', padding: '8px 10px', borderRadius: 6, border: '1px solid #e2e8f0', boxSizing: 'border-box' }}
              />
            </div>
            <div>
              <label style={{ display: 'block', fontSize: 13, fontWeight: 600, color: '#475569', marginBottom: 6 }}>Currency</label>
              <input
                value={currencyInput} onChange={(e) => setCurrencyInput(e.target.value.toUpperCase())}
                maxLength={10}
                style={{ width: '100%', padding: '8px 10px', borderRadius: 6, border: '1px solid #e2e8f0', boxSizing: 'border-box' }}
              />
            </div>
            <div style={{ gridColumn: '1 / -1' }}>
              <label style={{ display: 'block', fontSize: 13, fontWeight: 600, color: '#475569', marginBottom: 6 }}>Notes</label>
              <textarea
                value={notesInput} onChange={(e) => setNotesInput(e.target.value)} rows={2}
                style={{ width: '100%', padding: 10, borderRadius: 6, border: '1px solid #e2e8f0', fontFamily: 'inherit', boxSizing: 'border-box' }}
              />
            </div>
            <div style={{ gridColumn: '1 / -1', display: 'flex', justifyContent: 'flex-end', gap: 8 }}>
              <Button type="button" variant="secondary" onClick={() => setShowAddModal(false)}>Cancel</Button>
              <Button type="submit" variant="primary" disabled={savePrice.isPending}>
                {savePrice.isPending ? 'Saving…' : (editingPrice ? 'Save' : 'Add price')}
              </Button>
            </div>
          </form>
        </Modal>
      )}
    </div>
  );
}
