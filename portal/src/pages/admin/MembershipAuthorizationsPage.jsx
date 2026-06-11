import { useMemo, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import toast from 'react-hot-toast';
import {
  ShieldCheckIcon,
  DocumentArrowUpIcon,
  TrashIcon,
  EyeIcon,
  MagnifyingGlassIcon,
} from '@heroicons/react/24/outline';
import {
  listMembershipAuthorizations,
  issueMembershipAuthorization,
  deleteMembershipAuthorization,
} from '../../api/membershipAuthorizations';
import { getMembers } from '../../api/members';
import Table from '../../components/UI/Table';
import Button from '../../components/UI/Button';
import Spinner from '../../components/UI/Spinner';

const fmtDate = (d) => (d ? new Date(d).toLocaleString('en-GB') : '—');
const fmtSize = (b) => {
  if (b == null) return '—';
  if (b < 1024) return `${b} B`;
  if (b < 1024 * 1024) return `${(b / 1024).toFixed(1)} KB`;
  return `${(b / 1024 / 1024).toFixed(2)} MB`;
};

export default function MembershipAuthorizationsPage() {
  const qc = useQueryClient();

  // ── Member search/select ────────────────────────────────────────────────
  const [memberSearch, setMemberSearch] = useState('');
  const [selectedMember, setSelectedMember] = useState(null);

  const { data: memberSearchData, isFetching: searching } = useQuery({
    queryKey: ['member-search', memberSearch],
    queryFn: () =>
      getMembers({ search: memberSearch, limit: 8 }).then((r) => r.data),
    enabled: memberSearch.trim().length >= 2,
    placeholderData: { members: [] },
  });
  const memberResults =
    memberSearchData?.members || memberSearchData?.data || memberSearchData || [];

  // ── Form state ───────────────────────────────────────────────────────────
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [file, setFile] = useState(null);

  const issueMutation = useMutation({
    mutationFn: issueMembershipAuthorization,
    onSuccess: () => {
      toast.success('Authorization document issued');
      setTitle('');
      setDescription('');
      setFile(null);
      qc.invalidateQueries({ queryKey: ['membership-authorizations'] });
    },
    onError: (err) =>
      toast.error(err.response?.data?.message || 'Failed to issue document'),
  });

  const deleteMutation = useMutation({
    mutationFn: deleteMembershipAuthorization,
    onSuccess: () => {
      toast.success('Document deleted');
      qc.invalidateQueries({ queryKey: ['membership-authorizations'] });
    },
    onError: (err) =>
      toast.error(err.response?.data?.message || 'Failed to delete'),
  });

  const onSubmit = (e) => {
    e.preventDefault();
    if (!selectedMember) return toast.error('Select a member first');
    if (!title.trim()) return toast.error('Enter a title');
    if (!file) return toast.error('Attach a document');
    const fd = new FormData();
    fd.append('member_id', selectedMember.id);
    fd.append('title', title.trim());
    if (description.trim()) fd.append('description', description.trim());
    fd.append('file', file);
    issueMutation.mutate(fd);
  };

  // ── Issued documents list ────────────────────────────────────────────────
  const [filterMemberId, setFilterMemberId] = useState('');
  const listParams = useMemo(
    () => (filterMemberId ? { member_id: filterMemberId } : {}),
    [filterMemberId]
  );
  const { data: docsData, isLoading: docsLoading } = useQuery({
    queryKey: ['membership-authorizations', listParams],
    queryFn: () => listMembershipAuthorizations(listParams).then((r) => r.data),
    placeholderData: { documents: [] },
  });
  const docs = docsData?.documents || [];

  const columns = [
    {
      key: 'member',
      header: 'Member',
      render: (_, r) => (
        <div>
          <div style={{ fontWeight: 600 }}>{r.member_name || '—'}</div>
          <div style={{ fontSize: 12, color: '#64748b' }}>
            {r.member_number || ''}
          </div>
        </div>
      ),
    },
    { key: 'title', header: 'Title' },
    {
      key: 'file_name',
      header: 'File',
      render: (_, r) => (
        <div style={{ fontSize: 13 }}>
          <div>{r.file_name || '—'}</div>
          <div style={{ fontSize: 11, color: '#64748b' }}>{fmtSize(r.file_size)}</div>
        </div>
      ),
    },
    { key: 'issued_by_name', header: 'Issued By', render: (v) => v || '—' },
    { key: 'issued_at', header: 'Issued At', render: (v) => fmtDate(v) },
    {
      key: 'actions',
      header: 'Actions',
      render: (_, r) => (
        <div style={{ display: 'flex', gap: 8 }}>
          <a
            href={r.file_url_abs || r.file_url}
            target="_blank"
            rel="noopener noreferrer"
            title="View"
            style={{
              display: 'inline-flex',
              alignItems: 'center',
              gap: 4,
              padding: '6px 10px',
              borderRadius: 6,
              background: '#eff6ff',
              color: '#1d4ed8',
              fontSize: 12,
              fontWeight: 500,
              textDecoration: 'none',
            }}
          >
            <EyeIcon style={{ width: 14, height: 14 }} /> View
          </a>
          <button
            onClick={() => {
              if (window.confirm('Delete this authorization document?')) {
                deleteMutation.mutate(r.id);
              }
            }}
            title="Delete"
            style={{
              border: 'none',
              background: '#fef2f2',
              color: '#b91c1c',
              padding: '6px 10px',
              borderRadius: 6,
              cursor: 'pointer',
              fontSize: 12,
              fontWeight: 500,
              display: 'inline-flex',
              alignItems: 'center',
              gap: 4,
            }}
          >
            <TrashIcon style={{ width: 14, height: 14 }} /> Delete
          </button>
        </div>
      ),
    },
  ];

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 24 }}>
      {/* Header */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
        <ShieldCheckIcon style={{ width: 28, height: 28, color: '#003DA5' }} />
        <div>
          <h1 style={{ margin: 0, fontSize: 22, fontWeight: 700, color: '#0f172a' }}>
            Membership Authorization Documents
          </h1>
          <p style={{ margin: '4px 0 0', fontSize: 13, color: '#64748b' }}>
            Issue authorization documents to members. They will appear on the
            member's Membership Card screen in the SanCare+ app.
          </p>
        </div>
      </div>

      {/* Issue Form */}
      <div
        style={{
          background: '#fff',
          borderRadius: 12,
          padding: 24,
          boxShadow: '0 1px 4px rgba(0,0,0,0.07)',
        }}
      >
        <h3 style={{ margin: '0 0 20px', fontSize: 16, fontWeight: 600 }}>
          📄 Issue New Document
        </h3>
        <form
          onSubmit={onSubmit}
          style={{ display: 'flex', flexDirection: 'column', gap: 16, maxWidth: 720 }}
        >
          {/* Member picker */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
            <label style={{ fontSize: 13, fontWeight: 500, color: '#475569' }}>
              Member *
            </label>
            {selectedMember ? (
              <div
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  padding: '10px 14px',
                  background: '#eff6ff',
                  borderRadius: 8,
                  border: '1px solid #bfdbfe',
                }}
              >
                <div>
                  <div style={{ fontWeight: 600, color: '#1e3a8a' }}>
                    {selectedMember.first_name} {selectedMember.last_name}
                  </div>
                  <div style={{ fontSize: 12, color: '#475569' }}>
                    {selectedMember.member_number}
                    {selectedMember.email ? ` · ${selectedMember.email}` : ''}
                  </div>
                </div>
                <button
                  type="button"
                  onClick={() => {
                    setSelectedMember(null);
                    setMemberSearch('');
                  }}
                  style={{
                    border: 'none',
                    background: 'transparent',
                    color: '#1d4ed8',
                    cursor: 'pointer',
                    fontSize: 13,
                  }}
                >
                  Change
                </button>
              </div>
            ) : (
              <div style={{ position: 'relative' }}>
                <MagnifyingGlassIcon
                  style={{
                    width: 16,
                    height: 16,
                    position: 'absolute',
                    left: 10,
                    top: 11,
                    color: '#94a3b8',
                  }}
                />
                <input
                  type="text"
                  placeholder="Search by name or member number…"
                  value={memberSearch}
                  onChange={(e) => setMemberSearch(e.target.value)}
                  style={{
                    width: '100%',
                    padding: '8px 12px 8px 32px',
                    borderRadius: 6,
                    border: '1px solid #e2e8f0',
                    fontSize: 14,
                  }}
                />
                {memberSearch.trim().length >= 2 && (
                  <div
                    style={{
                      marginTop: 6,
                      maxHeight: 220,
                      overflow: 'auto',
                      border: '1px solid #e2e8f0',
                      borderRadius: 8,
                      background: '#fff',
                    }}
                  >
                    {searching ? (
                      <div style={{ padding: 12, fontSize: 13, color: '#64748b' }}>
                        Searching…
                      </div>
                    ) : memberResults.length === 0 ? (
                      <div style={{ padding: 12, fontSize: 13, color: '#64748b' }}>
                        No members found.
                      </div>
                    ) : (
                      memberResults.map((m) => (
                        <div
                          key={m.id}
                          onClick={() => {
                            setSelectedMember(m);
                            setMemberSearch('');
                          }}
                          style={{
                            padding: '8px 12px',
                            cursor: 'pointer',
                            borderBottom: '1px solid #f1f5f9',
                            fontSize: 13,
                          }}
                          onMouseEnter={(e) =>
                            (e.currentTarget.style.background = '#f8fafc')
                          }
                          onMouseLeave={(e) =>
                            (e.currentTarget.style.background = '#fff')
                          }
                        >
                          <div style={{ fontWeight: 600 }}>
                            {m.first_name} {m.last_name}
                          </div>
                          <div style={{ fontSize: 11, color: '#64748b' }}>
                            {m.member_number}
                            {m.email ? ` · ${m.email}` : ''}
                          </div>
                        </div>
                      ))
                    )}
                  </div>
                )}
              </div>
            )}
          </div>

          {/* Title */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
            <label style={{ fontSize: 13, fontWeight: 500, color: '#475569' }}>
              Title *
            </label>
            <input
              type="text"
              placeholder="e.g. Treatment Authorization Letter"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              style={{
                padding: '8px 12px',
                borderRadius: 6,
                border: '1px solid #e2e8f0',
                fontSize: 14,
              }}
            />
          </div>

          {/* Description */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
            <label style={{ fontSize: 13, fontWeight: 500, color: '#475569' }}>
              Description (optional)
            </label>
            <textarea
              rows={3}
              placeholder="Short note that will be shown to the member"
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              style={{
                padding: '8px 12px',
                borderRadius: 6,
                border: '1px solid #e2e8f0',
                fontSize: 14,
                fontFamily: 'inherit',
                resize: 'vertical',
              }}
            />
          </div>

          {/* File */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
            <label style={{ fontSize: 13, fontWeight: 500, color: '#475569' }}>
              Document *
            </label>
            <input
              type="file"
              accept=".pdf,.jpg,.jpeg,.png,.webp,.heic,.heif,.doc,.docx"
              onChange={(e) => setFile(e.target.files?.[0] || null)}
              style={{ fontSize: 14 }}
            />
            <span style={{ fontSize: 11, color: '#94a3b8' }}>
              PDF or image, max 20 MB.
            </span>
          </div>

          <div>
            <Button
              variant="primary"
              type="submit"
              disabled={issueMutation.isPending}
              style={{ padding: '10px 20px' }}
            >
              <DocumentArrowUpIcon style={{ width: 16, height: 16 }} />
              {issueMutation.isPending ? 'Uploading…' : 'Issue Document'}
            </Button>
          </div>
        </form>
      </div>

      {/* List */}
      <div
        style={{
          background: '#fff',
          borderRadius: 12,
          boxShadow: '0 1px 4px rgba(0,0,0,0.07)',
          overflow: 'hidden',
        }}
      >
        <div
          style={{
            padding: '16px 20px',
            borderBottom: '1px solid #f1f5f9',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            gap: 12,
            flexWrap: 'wrap',
          }}
        >
          <h3 style={{ margin: 0, fontSize: 15, fontWeight: 600 }}>
            Issued Documents
          </h3>
          {selectedMember && (
            <label
              style={{
                fontSize: 12,
                color: '#475569',
                display: 'inline-flex',
                alignItems: 'center',
                gap: 6,
              }}
            >
              <input
                type="checkbox"
                checked={filterMemberId === selectedMember.id}
                onChange={(e) =>
                  setFilterMemberId(e.target.checked ? selectedMember.id : '')
                }
              />
              Filter by selected member
            </label>
          )}
        </div>
        {docsLoading ? (
          <Spinner />
        ) : (
          <Table
            columns={columns}
            data={docs}
            emptyMessage="No authorization documents issued yet."
          />
        )}
      </div>
    </div>
  );
}
