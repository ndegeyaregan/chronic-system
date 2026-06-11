import { useMemo, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import {
  ClockIcon,
  UsersIcon,
  MagnifyingGlassIcon,
  ChevronLeftIcon,
  ChevronRightIcon,
  ArrowDownTrayIcon,
} from '@heroicons/react/24/outline';
import { getMemberLogins } from '../../api/auditLogs';
import Table from '../../components/UI/Table';
import Button from '../../components/UI/Button';
import Spinner from '../../components/UI/Spinner';

const fmtTimestamp = (d) =>
  new Date(d).toLocaleString('en-GB', {
    day: '2-digit', month: 'short', year: 'numeric',
    hour: '2-digit', minute: '2-digit', second: '2-digit',
  });

const todayISO = () => new Date().toISOString().split('T')[0];

export default function MemberLoginsPage() {
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState('');
  const [from, setFrom] = useState('');
  const [to, setTo] = useState('');

  const params = useMemo(() => ({
    page,
    limit: 25,
    ...(search && { search }),
    ...(from && { from }),
    ...(to && { to: `${to}T23:59:59.999Z` }),
  }), [page, search, from, to]);

  const { data, isLoading, isFetching } = useQuery({
    queryKey: ['member-logins', params],
    queryFn: () => getMemberLogins(params),
    placeholderData: (prev) => prev,
  });

  const logins = data?.logins || [];
  const total = data?.total || 0;
  const pages = data?.pages || 1;

  const today = todayISO();
  const todayCount = logins.filter((l) => (l.created_at || '').startsWith(today)).length;
  const uniqueMembers = new Set(logins.map((l) => l.member_id).filter(Boolean)).size;

  const fullName = (row) =>
    `${row?.first_name || ''} ${row?.last_name || ''}`.trim() ||
    row?.details?.name ||
    '—';

  const handleExportCsv = () => {
    const header = ['Date/Time', 'Member Number', 'Name', 'Email', 'Phone', 'IP Address'];
    const rows = logins.map((l) => [
      fmtTimestamp(l.created_at),
      l.member_number || '',
      fullName(l),
      l.email || '',
      l.phone || '',
      l.ip_address || '',
    ]);
    const csv = [header, ...rows]
      .map((r) => r.map((c) => `"${String(c).replace(/"/g, '""')}"`).join(','))
      .join('\n');
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `member-logins-${today}.csv`;
    a.click();
    URL.revokeObjectURL(url);
  };

  const columns = [
    {
      key: 'created_at',
      label: 'Date / Time',
      render: (_, row) => (
        <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6, color: 'var(--text)' }}>
          <ClockIcon style={{ width: 14, height: 14, color: '#64748b' }} />
          {row?.created_at ? fmtTimestamp(row.created_at) : '—'}
        </span>
      ),
    },
    {
      key: 'member_number',
      label: 'Member #',
      render: (_, row) => (
        <span style={{ fontFamily: 'monospace', color: 'var(--text)' }}>
          {row?.member_number || row?.details?.member_number || '—'}
        </span>
      ),
    },
    {
      key: 'name',
      label: 'Name',
      render: (_, row) => <span style={{ color: 'var(--text)' }}>{fullName(row)}</span>,
    },
    {
      key: 'email',
      label: 'Email',
      render: (_, row) => <span style={{ color: 'var(--text)' }}>{row?.email || '—'}</span>,
    },
    {
      key: 'phone',
      label: 'Phone',
      render: (_, row) => <span style={{ color: 'var(--text)' }}>{row?.phone || '—'}</span>,
    },
    {
      key: 'ip_address',
      label: 'IP Address',
      render: (_, row) => (
        <span style={{ fontFamily: 'monospace', color: '#64748b', fontSize: 12 }}>
          {row?.ip_address || '—'}
        </span>
      ),
    },
  ];

  return (
    <div style={{ padding: 24 }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 16 }}>
        <UsersIcon style={{ width: 26, height: 26, color: 'var(--primary)' }} />
        <div>
          <h1 style={{ margin: 0, fontSize: 22, color: 'var(--text)' }}>Member Login Activity</h1>
          <p style={{ margin: '4px 0 0', color: '#64748b', fontSize: 13 }}>
            Every member sign-in is recorded here with the timestamp.
          </p>
        </div>
      </div>

      {/* Stats */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, minmax(0, 1fr))', gap: 12, marginBottom: 16 }}>
        {[
          { label: 'Total logins (filtered)', value: total },
          { label: 'Logins today (this page)', value: todayCount },
          { label: 'Unique members (this page)', value: uniqueMembers },
        ].map((s) => (
          <div key={s.label} style={{
            background: 'var(--surface, #fff)',
            border: '1px solid #e2e8f0',
            borderRadius: 10,
            padding: '14px 16px',
          }}>
            <div style={{ fontSize: 12, color: '#64748b' }}>{s.label}</div>
            <div style={{ fontSize: 22, fontWeight: 600, color: 'var(--text)' }}>{s.value}</div>
          </div>
        ))}
      </div>

      {/* Filters */}
      <div style={{
        display: 'flex', flexWrap: 'wrap', gap: 8, alignItems: 'center',
        marginBottom: 12, padding: 12, background: 'var(--surface, #fff)',
        border: '1px solid #e2e8f0', borderRadius: 10,
      }}>
        <div style={{ position: 'relative', flex: '1 1 240px', maxWidth: 340 }}>
          <MagnifyingGlassIcon style={{
            position: 'absolute', left: 10, top: '50%', transform: 'translateY(-50%)',
            width: 16, height: 16, color: '#94a3b8',
          }} />
          <input
            type="text"
            placeholder="Search by name, member #, email…"
            value={search}
            onChange={(e) => { setSearch(e.target.value); setPage(1); }}
            style={{
              width: '100%', padding: '8px 12px 8px 32px',
              border: '1px solid #e2e8f0', borderRadius: 8, fontSize: 13,
            }}
          />
        </div>
        <input
          type="date"
          value={from}
          onChange={(e) => { setFrom(e.target.value); setPage(1); }}
          style={{ padding: '8px 12px', border: '1px solid #e2e8f0', borderRadius: 8, fontSize: 13 }}
          title="From date"
        />
        <span style={{ color: '#94a3b8', fontSize: 12 }}>to</span>
        <input
          type="date"
          value={to}
          onChange={(e) => { setTo(e.target.value); setPage(1); }}
          style={{ padding: '8px 12px', border: '1px solid #e2e8f0', borderRadius: 8, fontSize: 13 }}
          title="To date"
        />
        {(search || from || to) && (
          <Button
            variant="ghost"
            onClick={() => { setSearch(''); setFrom(''); setTo(''); setPage(1); }}
            style={{ padding: '6px 10px', fontSize: 12 }}
          >
            Clear
          </Button>
        )}
        <div style={{ marginLeft: 'auto' }}>
          <Button
            variant="secondary"
            onClick={handleExportCsv}
            disabled={!logins.length}
            style={{ padding: '6px 10px', fontSize: 12 }}
          >
            <ArrowDownTrayIcon style={{ width: 14, height: 14 }} /> Export CSV
          </Button>
        </div>
      </div>

      {/* Table */}
      {isLoading ? (
        <div style={{ display: 'flex', justifyContent: 'center', padding: 40 }}>
          <Spinner />
        </div>
      ) : (
        <>
          <Table
            columns={columns}
            data={logins}
            emptyMessage="No member logins recorded yet."
          />
          <div style={{
            display: 'flex', alignItems: 'center', justifyContent: 'space-between',
            marginTop: 12, fontSize: 13, color: '#64748b',
          }}>
            <span>
              Page {page} of {pages} · {total} total {isFetching && '· refreshing…'}
            </span>
            <div style={{ display: 'flex', gap: 6 }}>
              <Button
                variant="ghost"
                onClick={() => setPage((p) => Math.max(1, p - 1))}
                disabled={page <= 1}
                style={{ padding: '4px 8px' }}
              >
                <ChevronLeftIcon style={{ width: 14, height: 14 }} /> Prev
              </Button>
              <Button
                variant="ghost"
                onClick={() => setPage((p) => Math.min(pages, p + 1))}
                disabled={page >= pages}
                style={{ padding: '4px 8px' }}
              >
                Next <ChevronRightIcon style={{ width: 14, height: 14 }} />
              </Button>
            </div>
          </div>
        </>
      )}
    </div>
  );
}
