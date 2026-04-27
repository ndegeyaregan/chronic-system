import React, { useMemo, useRef, useState, useEffect } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { useForm, useWatch } from 'react-hook-form';
import { useNavigate } from 'react-router-dom';
import toast from 'react-hot-toast';
import {
  MagnifyingGlassIcon, ArrowUpTrayIcon, ArrowDownTrayIcon,
  EyeIcon, LockClosedIcon, UserPlusIcon,
  DocumentArrowDownIcon,
} from '@heroicons/react/24/outline';
import { jsPDF } from 'jspdf';
import autoTable from 'jspdf-autotable';
import * as XLSX from 'xlsx';
import {
  createMember,
  getMembers,
  uploadMembersCSV,
  toggleMemberStatus,
  exportMembers,
} from '../../api/members';
import { resetMemberPassword } from '../../api/auth';
import { getConditions } from '../../api/conditions';
import { getSchemes } from '../../api/schemes';
import Table from '../../components/UI/Table';
import Badge from '../../components/UI/Badge';
import Button from '../../components/UI/Button';
import Modal from '../../components/UI/Modal';
import Spinner from '../../components/UI/Spinner';
import Input from '../../components/UI/Input';

const CSV_TEMPLATE = `member_number,first_name,last_name,email,phone,scheme,conditions,date_of_birth\nSAN001,John,Doe,john@example.com,0821234567,NEMA,Diabetes,1985-06-15\n`;

export default function MembersPage() {
  const navigate = useNavigate();
  const qc = useQueryClient();
  const [search, setSearch] = useState('');
  const [condition, setCondition] = useState('');
  const [status, setStatus] = useState('');
  const [page, setPage] = useState(1);
  const [showUpload, setShowUpload] = useState(false);
  const [showCreateMember, setShowCreateMember] = useState(false);
  const [dragOver, setDragOver] = useState(false);
  const [uploadFile, setUploadFile] = useState(null);
  const [selectedIds, setSelectedIds] = useState([]);
  const fileRef = useRef();
  const {
    register,
    handleSubmit,
    reset,
    control,
    formState: { errors },
  } = useForm({
    defaultValues: {
      conditions: [],
    },
  });

  const { data, isLoading } = useQuery({
    queryKey: ['members', { search, condition, status, page }],
    queryFn: () => getMembers({ search, condition, status, page, limit: 15 }).then((r) => r.data),
    retry: false,
    placeholderData: { members: [], total: 0, pages: 1 },
  });

  const { data: conditionsData = [] } = useQuery({
    queryKey: ['conditions-for-members'],
    queryFn: () => getConditions().then((r) => r.data),
    retry: false,
  });

  const { data: schemesData = [] } = useQuery({
    queryKey: ['schemes-for-members'],
    queryFn: () => getSchemes().then((r) => r.data),
    retry: false,
  });

  const schemes = Array.isArray(schemesData) ? schemesData : (schemesData?.schemes || []);



  const conditionOptions = useMemo(
    () => ['All', ...conditionsData.map((item) => item.name)],
    [conditionsData]
  );

  const toggleMutation = useMutation({
    mutationFn: toggleMemberStatus,
    onSuccess: () => { qc.invalidateQueries(['members']); toast.success('Member status updated'); },
    onError: () => toast.error('Failed to update status'),
  });

  const resetPwMutation = useMutation({
    mutationFn: resetMemberPassword,
    onSuccess: () => toast.success('Password reset link sent'),
    onError: () => toast.error('Failed to reset password'),
  });

  const uploadMutation = useMutation({
    mutationFn: uploadMembersCSV,
    onSuccess: (res) => {
      qc.invalidateQueries(['members']);
      toast.success(`Uploaded ${res.data?.inserted || 0} members`);
      setShowUpload(false);
      setUploadFile(null);
    },
    onError: () => toast.error('Upload failed'),
  });

  const createMemberMutation = useMutation({
    mutationFn: createMember,
    onSuccess: (res) => {
      qc.invalidateQueries(['members']);
      toast.success(`Registered ${res.data.first_name} ${res.data.last_name}`);
      reset({
        member_number: '',
        first_name: '',
        last_name: '',
        email: '',
        phone: '',
        scheme_id: '',
        date_of_birth: '',
        conditions: [],
      });
      setShowCreateMember(false);
    },
    onError: (err) => toast.error(err.response?.data?.message || 'Failed to register member'),
  });

  const handleExport = async () => {
    try {
      const res = await exportMembers();
      const url = URL.createObjectURL(new Blob([res.data], { type: 'text/csv' }));
      const a = document.createElement('a');
      a.href = url; a.download = 'members_report.csv'; a.click();
    } catch { toast.error('Export failed'); }
  };

  const getExportData = () => {
    const members = data?.members || [];
    const rows = selectedIds.length > 0
      ? members.filter((m) => selectedIds.includes(m.id))
      : members;
    return rows;
  };

  const handleExportPDF = () => {
    const rows = getExportData();
    if (rows.length === 0) return toast.error('No data to export');
    const doc = new jsPDF();
    doc.setFontSize(16);
    doc.text('Sanlam Chronic Care — Members Report', 14, 18);
    doc.setFontSize(9);
    doc.text(`Generated: ${new Date().toLocaleDateString()}  |  ${rows.length} member(s)`, 14, 25);
    autoTable(doc, {
      startY: 30,
      head: [['Member #', 'Name', 'Phone', 'Email', 'Conditions', 'Status']],
      body: rows.map((m) => [
        m.member_number,
        `${m.first_name} ${m.last_name}`,
        m.phone || '—',
        m.email || '—',
        (m.conditions || []).join(', ') || '—',
        m.is_active ? 'Active' : 'Inactive',
      ]),
      styles: { fontSize: 8 },
      headStyles: { fillColor: [0, 61, 165] },
    });
    doc.save('members_report.pdf');
    toast.success('PDF exported');
  };

  const handleExportExcel = () => {
    const rows = getExportData();
    if (rows.length === 0) return toast.error('No data to export');
    const wsData = rows.map((m) => ({
      'Member #': m.member_number,
      'First Name': m.first_name,
      'Last Name': m.last_name,
      Phone: m.phone || '',
      Email: m.email || '',
      Conditions: (m.conditions || []).join(', '),
      Status: m.is_active ? 'Active' : 'Inactive',
      'Date of Birth': m.date_of_birth || '',
    }));
    const ws = XLSX.utils.json_to_sheet(wsData);
    const wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, 'Members');
    XLSX.writeFile(wb, 'members_report.xlsx');
    toast.success('Excel exported');
  };

  const handleBulkToggleStatus = async () => {
    if (selectedIds.length === 0) return;
    const confirmed = window.confirm(`Toggle active status for ${selectedIds.length} member(s)?`);
    if (!confirmed) return;
    let success = 0;
    for (const id of selectedIds) {
      try {
        await toggleMemberStatus(id);
        success++;
      } catch {}
    }
    toast.success(`${success} member(s) updated`);
    setSelectedIds([]);
    qc.invalidateQueries(['members']);
  };

  const handleBulkResetPassword = async () => {
    if (selectedIds.length === 0) return;
    const confirmed = window.confirm(`Reset password for ${selectedIds.length} member(s)? They will receive OTP via SMS/email.`);
    if (!confirmed) return;
    let success = 0;
    for (const id of selectedIds) {
      try {
        await resetMemberPassword(id);
        success++;
      } catch {}
    }
    toast.success(`${success} password(s) reset`);
    setSelectedIds([]);
  };

  const handleUploadSubmit = () => {
    if (!uploadFile) return toast.error('Please select a CSV file');
    const fd = new FormData();
    fd.append('file', uploadFile);
    uploadMutation.mutate(fd);
  };

  const handleDrop = (e) => {
    e.preventDefault(); setDragOver(false);
    const file = e.dataTransfer.files[0];
    if (file) setUploadFile(file);
  };

  const downloadTemplate = () => {
    const blob = new Blob([CSV_TEMPLATE], { type: 'text/csv' });
    const a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = 'members_template.csv'; a.click();
  };

  const members = data?.members || [];
  const totalPages = data?.pages || 1;
  const selectedConditions = useWatch({ control, name: 'conditions' }) || [];

  const columns = [
    { key: 'member_number', header: 'Member #' },
    {
      key: 'first_name', header: 'Name',
      render: (_, row) => `${row.first_name || ''} ${row.last_name || ''}`.trim() || '—',
    },
    { key: 'scheme_name', header: 'Scheme', render: (v, row) => v || row.plan || '—' },
    {
      key: 'conditions', header: 'Conditions',
      render: (v) => Array.isArray(v) ? v.join(', ') : v || '—',
    },
    {
      key: 'is_active', header: 'Status',
      render: (v) => <Badge status={v ? 'active' : 'inactive'} />,
    },
    {
      key: 'actions', header: 'Actions',
      render: (_, row) => (
        <div style={{ display: 'flex', gap: '6px', flexWrap: 'wrap' }}>
          <Button variant="ghost" onClick={() => navigate(`/members/${row.id}`)} style={{ padding: '4px 8px', fontSize: '12px' }}>
            <EyeIcon style={{ width: 13, height: 13 }} /> View
          </Button>
          <Button
            variant={row.is_active ? 'secondary' : 'success'}
            onClick={() => toggleMutation.mutate(row.id)}
            style={{ padding: '4px 8px', fontSize: '12px' }}
          >
            {row.is_active ? 'Deactivate' : 'Activate'}
          </Button>
          <Button variant="secondary" onClick={() => resetPwMutation.mutate(row.id)} style={{ padding: '4px 8px', fontSize: '12px' }}>
            <LockClosedIcon style={{ width: 13, height: 13 }} /> Reset PW
          </Button>
        </div>
      ),
    },
  ];

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
      {/* Toolbar */}
      <div style={{ display: 'flex', gap: '12px', flexWrap: 'wrap', alignItems: 'center' }}>
        <div style={{ position: 'relative', flex: '1 1 220px' }}>
          <MagnifyingGlassIcon style={{ width: 16, height: 16, position: 'absolute', left: 10, top: '50%', transform: 'translateY(-50%)', color: '#94a3b8' }} />
          <input
            placeholder="Search members…"
            value={search}
            onChange={(e) => { setSearch(e.target.value); setPage(1); }}
            style={{ paddingLeft: '34px', padding: '8px 12px 8px 34px', borderRadius: '6px', border: '1px solid #e2e8f0', fontSize: '14px', width: '100%', boxSizing: 'border-box' }}
          />
        </div>
        <select
          value={condition}
          onChange={(e) => { setCondition(e.target.value); setPage(1); }}
          style={{ padding: '8px 12px', borderRadius: '6px', border: '1px solid #e2e8f0', fontSize: '14px' }}
        >
          {conditionOptions.map((c) => <option key={c} value={c === 'All' ? '' : c}>{c}</option>)}
        </select>
        <select
          value={status}
          onChange={(e) => { setStatus(e.target.value); setPage(1); }}
          style={{ padding: '8px 12px', borderRadius: '6px', border: '1px solid #e2e8f0', fontSize: '14px' }}
        >
          <option value="">All Statuses</option>
          <option value="active">Active</option>
          <option value="inactive">Inactive</option>
        </select>
        <div style={{ marginLeft: 'auto', display: 'flex', gap: '8px' }}>
          <Button variant="primary" onClick={() => setShowCreateMember(true)}>
            <UserPlusIcon style={{ width: 15, height: 15 }} /> Register Member
          </Button>
          <Button variant="secondary" onClick={handleExport}>
            <ArrowDownTrayIcon style={{ width: 15, height: 15 }} /> Export CSV
          </Button>
          <Button variant="secondary" onClick={handleExportPDF}>
            <DocumentArrowDownIcon style={{ width: 15, height: 15 }} /> PDF
          </Button>
          <Button variant="secondary" onClick={handleExportExcel}>
            <DocumentArrowDownIcon style={{ width: 15, height: 15 }} /> Excel
          </Button>
          <Button variant="ghost" onClick={() => setShowUpload(true)}>
            <ArrowUpTrayIcon style={{ width: 15, height: 15 }} /> Upload Members
          </Button>
        </div>
      </div>

      {/* Bulk Actions Bar */}
      {selectedIds.length > 0 && (
        <div style={{
          background: '#eff6ff', borderRadius: '8px', padding: '10px 16px',
          display: 'flex', alignItems: 'center', gap: '12px', border: '1px solid #bfdbfe',
        }}>
          <span style={{ fontWeight: 600, fontSize: '13px', color: '#1e40af' }}>
            {selectedIds.length} selected
          </span>
          <Button variant="secondary" onClick={handleBulkToggleStatus} style={{ fontSize: '12px', padding: '4px 12px' }}>
            Toggle Active/Inactive
          </Button>
          <Button variant="secondary" onClick={handleBulkResetPassword} style={{ fontSize: '12px', padding: '4px 12px' }}>
            <LockClosedIcon style={{ width: 13, height: 13 }} /> Reset Passwords
          </Button>
          <Button variant="ghost" onClick={() => setSelectedIds([])} style={{ fontSize: '12px', padding: '4px 8px', marginLeft: 'auto' }}>
            Clear Selection
          </Button>
        </div>
      )}

      {/* Table */}
      <div style={{ background: '#fff', borderRadius: '12px', boxShadow: '0 1px 4px rgba(0,0,0,0.07)', overflow: 'hidden' }}>
        {isLoading ? <Spinner /> : (
          <Table
            columns={columns}
            data={members}
            emptyMessage="No members found."
            selectable
            selectedIds={selectedIds}
            onSelectionChange={setSelectedIds}
          />
        )}
      </div>

      {/* Pagination */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <span style={{ fontSize: '13px', color: '#64748b' }}>
          Page {page} of {totalPages} — {data?.total || 0} total members
        </span>
        <div style={{ display: 'flex', gap: '6px' }}>
          <Button variant="secondary" onClick={() => setPage((p) => Math.max(1, p - 1))} disabled={page <= 1}>‹ Prev</Button>
          <Button variant="secondary" onClick={() => setPage((p) => Math.min(totalPages, p + 1))} disabled={page >= totalPages}>Next ›</Button>
        </div>
      </div>

      {/* Upload Modal */}
      {showUpload && (
        <Modal title="Upload Members CSV" onClose={() => { setShowUpload(false); setUploadFile(null); }}>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
            <div
              onDragOver={(e) => { e.preventDefault(); setDragOver(true); }}
              onDragLeave={() => setDragOver(false)}
              onDrop={handleDrop}
              onClick={() => fileRef.current.click()}
              style={{
                border: `2px dashed ${dragOver ? 'var(--primary)' : '#e2e8f0'}`,
                borderRadius: '10px',
                padding: '40px',
                textAlign: 'center',
                cursor: 'pointer',
                background: dragOver ? '#eff6ff' : '#f8fafc',
                transition: 'all 0.2s',
              }}
            >
              <ArrowUpTrayIcon style={{ width: 32, height: 32, color: '#94a3b8', margin: '0 auto 8px' }} />
              {uploadFile ? (
                <p style={{ margin: 0, color: 'var(--primary)', fontWeight: '600' }}>{uploadFile.name}</p>
              ) : (
                <>
                  <p style={{ margin: '0 0 4px', fontWeight: '500', color: 'var(--text)' }}>Drop CSV file here or click to browse</p>
                  <p style={{ margin: 0, fontSize: '12px', color: '#94a3b8' }}>Only .csv files accepted</p>
                </>
              )}
              <input ref={fileRef} type="file" accept=".csv" hidden onChange={(e) => setUploadFile(e.target.files[0])} />
            </div>
            <Button variant="ghost" onClick={downloadTemplate} style={{ alignSelf: 'flex-start' }}>
              ⬇ Download CSV Template
            </Button>
            <div style={{ display: 'flex', gap: '8px', justifyContent: 'flex-end' }}>
              <Button variant="secondary" onClick={() => { setShowUpload(false); setUploadFile(null); }}>Cancel</Button>
              <Button variant="primary" onClick={handleUploadSubmit} disabled={uploadMutation.isPending}>
                {uploadMutation.isPending ? 'Uploading…' : 'Upload'}
              </Button>
            </div>
          </div>
        </Modal>
      )}

      {showCreateMember && (
        <Modal
          title="Register Member"
          width="760px"
          onClose={() => {
            setShowCreateMember(false);
            reset({
              member_number: '',
              first_name: '',
              last_name: '',
              email: '',
              phone: '',
              scheme_id: '',
              date_of_birth: '',
              conditions: [],
            });
          }}
        >
          <form
            onSubmit={handleSubmit((formData) => createMemberMutation.mutate(formData))}
            style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}
          >
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, minmax(0, 1fr))', gap: '16px' }}>
              <Input label="Member Number" name="member_number" register={register} error={errors.member_number} placeholder="SAN001" />
              <div style={{ display: 'flex', flexDirection: 'column', gap: '4px' }}>
                <label style={{ fontSize: '13px', fontWeight: 500, color: '#475569' }}>Scheme *</label>
                <select
                  {...register('scheme_id', { required: 'Scheme is required' })}
                  style={{ 
                    padding: '10px 12px', 
                    borderRadius: '6px', 
                    border: '1px solid #e2e8f0', 
                    fontSize: '14px',
                    background: '#fff',
                    cursor: 'pointer'
                  }}
                >
                  <option value="">-- Select a scheme --</option>
                  {schemes.map(s => (
                    <option key={s.id} value={s.id}>{s.name}</option>
                  ))}
                </select>
                {errors.scheme_id && <span style={{ color: '#dc2626', fontSize: '12px' }}>{errors.scheme_id.message}</span>}
              </div>
              <Input label="First Name" name="first_name" register={register} error={errors.first_name} placeholder="John" />
              <Input label="Last Name" name="last_name" register={register} error={errors.last_name} placeholder="Doe" />
              <Input label="Date of Birth" type="date" name="date_of_birth" register={register} error={errors.date_of_birth} />
              <Input label="Email" type="email" name="email" register={register} error={errors.email} placeholder="john@example.com" />
              <Input label="Phone" name="phone" register={register} error={errors.phone} placeholder="0821234567" />
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
              <label style={{ fontSize: '13px', fontWeight: '500', color: '#475569' }}>Conditions</label>
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, minmax(0, 1fr))', gap: '10px' }}>
                {conditionsData.map((conditionItem) => (
                  <label
                    key={conditionItem.id}
                    style={{
                      display: 'flex',
                      alignItems: 'center',
                      gap: '8px',
                      border: '1px solid #e2e8f0',
                      borderRadius: '8px',
                      padding: '10px 12px',
                      background: selectedConditions.includes(conditionItem.name) ? '#eff6ff' : '#fff',
                      cursor: 'pointer',
                    }}
                  >
                    <input
                      type="checkbox"
                      value={conditionItem.name}
                      {...register('conditions')}
                    />
                    <span style={{ fontSize: '13px', color: 'var(--text)' }}>{conditionItem.name}</span>
                  </label>
                ))}
              </div>
            </div>

            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '8px' }}>
              <Button
                variant="secondary"
                onClick={() => {
                  setShowCreateMember(false);
                  reset({
                    member_number: '',
                    first_name: '',
                    last_name: '',
                    email: '',
                    phone: '',
                    scheme_id: '',
                    date_of_birth: '',
                    conditions: [],
                  });
                }}
              >
                Cancel
              </Button>
              <Button type="submit" variant="primary" disabled={createMemberMutation.isPending}>
                {createMemberMutation.isPending ? 'Registering…' : 'Register Member'}
              </Button>
            </div>
          </form>
        </Modal>
      )}
    </div>
  );
}
