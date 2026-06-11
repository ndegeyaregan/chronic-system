import { useMemo, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import toast from 'react-hot-toast';
import {
  CurrencyDollarIcon,
  MagnifyingGlassIcon,
  EyeIcon,
  CheckCircleIcon,
  XCircleIcon,
  DocumentArrowDownIcon,
  ArrowPathIcon,
} from '@heroicons/react/24/outline';
import { listReimbursements, updateReimbursementStatus } from '../../api/reimbursements';
import Table from '../../components/UI/Table';
import Modal from '../../components/UI/Modal';
import Button from '../../components/UI/Button';
import Spinner from '../../components/UI/Spinner';

const STATUS_OPTIONS = [
  { value: '', label: 'All statuses' },
  { value: 'pending', label: 'Pending' },
  { value: 'under_review', label: 'Under review' },
  { value: 'paid', label: 'Paid' },
  { value: 'rejected', label: 'Rejected' },
];

const statusBadge = (s) => {
  const map = {
    pending:      { bg: '#fef3c7', fg: '#92400e' },
    under_review: { bg: '#dbeafe', fg: '#1e40af' },
    paid:         { bg: '#d1fae5', fg: '#065f46' },
    rejected:     { bg: '#fee2e2', fg: '#991b1b' },
  };
  return map[s] || { bg: '#f1f5f9', fg: '#475569' };
};

const fmtMoney = (v, ccy = 'UGX') =>
  v == null || v === '' ? '—' : `${ccy} ${Number(v).toLocaleString()}`;

const fmtDate = (d) => (d ? new Date(d).toLocaleString('en-GB') : '—');

const fileUrl = (url) => {
  if (!url) return null;
  if (/^https?:/i.test(url)) return url;
  // backend stores like "/uploads/reimbursements/xxx" → served from same origin
  const apiBase = import.meta.env.VITE_API_URL || '';
  const host = apiBase.replace(/\/api\/?$/, '');
  return `${host}${url.startsWith('/') ? '' : '/'}${url}`;
};

export default function ReimbursementsPage() {
  const qc = useQueryClient();
  const [statusFilter, setStatusFilter] = useState('');
  const [search, setSearch] = useState('');
  const [detail, setDetail] = useState(null);
  const [decisionStatus, setDecisionStatus] = useState('');
  const [adminNotes, setAdminNotes] = useState('');
  const [paidAmount, setPaidAmount] = useState('');
  const [paymentRef, setPaymentRef] = useState('');

  const params = useMemo(
    () => ({ ...(statusFilter && { status: statusFilter }) }),
    [statusFilter]
  );

  const { data = [], isLoading, isFetching, refetch } = useQuery({
    queryKey: ['reimbursements', params],
    queryFn: () => listReimbursements(params),
    placeholderData: (prev) => prev,
  });

  const filtered = useMemo(() => {
    if (!search) return data;
    const q = search.toLowerCase();
    return data.filter((r) =>
      [r.first_name, r.last_name, r.member_number, r.hospital_name, r.email]
        .filter(Boolean)
        .some((v) => v.toString().toLowerCase().includes(q))
    );
  }, [data, search]);

  const counts = useMemo(() => {
    const c = { pending: 0, under_review: 0, paid: 0, rejected: 0 };
    data.forEach((r) => { if (c[r.status] != null) c[r.status]++; });
    return c;
  }, [data]);

  const updateMutation = useMutation({
    mutationFn: ({ id, payload }) => updateReimbursementStatus(id, payload),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['reimbursements'] });
      toast.success('Reimbursement updated');
      setDetail(null);
    },
    onError: (e) =>
      toast.error(e.response?.data?.message || 'Failed to update'),
  });

  const openDetail = (row) => {
    setDetail(row);
    setDecisionStatus(row.status);
    setAdminNotes(row.admin_notes || '');
    setPaidAmount(row.paid_amount || '');
    setPaymentRef(row.payment_reference || '');
  };

  const submitDecision = () => {
    if (!detail) return;
    const payload = {
      status: decisionStatus,
      adminNotes: adminNotes || null,
      paidAmount: paidAmount === '' ? null : Number(paidAmount),
      paymentReference: paymentRef || null,
    };
    updateMutation.mutate({ id: detail.id, payload });
  };

  const columns = [
    {
      key: 'created_at', label: 'Submitted',
      render: (_, r) => <span style={{ color: 'var(--text)' }}>{fmtDate(r.created_at)}</span>,
    },
    {
      key: 'member', label: 'Member',
      render: (_, r) => (
        <div>
          <div style={{ color: 'var(--text)', fontWeight: 500 }}>
            {r.first_name} {r.last_name}
          </div>
          <div style={{ fontSize: 12, color: '#64748b', fontFamily: 'monospace' }}>
            {r.member_number}
          </div>
        </div>
      ),
    },
    {
      key: 'hospital_name', label: 'Hospital',
      render: (_, r) => <span style={{ color: 'var(--text)' }}>{r.hospital_name}</span>,
    },
    {
      key: 'amount', label: 'Amount',
      render: (_, r) => (
        <span style={{ color: 'var(--text)' }}>
          {fmtMoney(r.amount, r.currency || 'UGX')}
        </span>
      ),
    },
    {
      key: 'payout_method', label: 'Payout',
      render: (_, r) => (
        <span style={{ color: 'var(--text)', fontSize: 12 }}>
          {r.payout_method === 'bank' ? 'Bank' : 'Mobile money'}
        </span>
      ),
    },
    {
      key: 'status', label: 'Status',
      render: (_, r) => {
        const s = statusBadge(r.status);
        return (
          <span style={{
            display: 'inline-block', padding: '2px 8px', borderRadius: 12,
            background: s.bg, color: s.fg, fontSize: 11, fontWeight: 600,
            textTransform: 'capitalize',
          }}>
            {(r.status || '').replace('_', ' ')}
          </span>
        );
      },
    },
    {
      key: 'actions', label: '',
      render: (_, r) => (
        <Button variant="ghost" onClick={() => openDetail(r)} style={{ padding: '4px 8px', fontSize: 12 }}>
          <EyeIcon style={{ width: 13, height: 13 }} /> Review
        </Button>
      ),
    },
  ];

  return (
    <div style={{ padding: 24 }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 16 }}>
        <CurrencyDollarIcon style={{ width: 26, height: 26, color: 'var(--primary)' }} />
        <div>
          <h1 style={{ margin: 0, fontSize: 22, color: 'var(--text)' }}>Reimbursement Requests</h1>
          <p style={{ margin: '4px 0 0', color: '#64748b', fontSize: 13 }}>
            Member-submitted reimbursement claims for care received at non-network facilities.
          </p>
        </div>
        <div style={{ marginLeft: 'auto' }}>
          <Button variant="ghost" onClick={() => refetch()} style={{ padding: '6px 10px' }}>
            <ArrowPathIcon style={{ width: 14, height: 14 }} /> Refresh
          </Button>
        </div>
      </div>

      <div style={{
        display: 'grid', gridTemplateColumns: 'repeat(4, minmax(0, 1fr))',
        gap: 12, marginBottom: 16,
      }}>
        {[
          { label: 'Pending', value: counts.pending, color: '#92400e', bg: '#fef3c7' },
          { label: 'Under review', value: counts.under_review, color: '#1e40af', bg: '#dbeafe' },
          { label: 'Paid', value: counts.paid, color: '#065f46', bg: '#d1fae5' },
          { label: 'Rejected', value: counts.rejected, color: '#991b1b', bg: '#fee2e2' },
        ].map((s) => (
          <div key={s.label} style={{
            background: 'var(--surface, #fff)', border: '1px solid #e2e8f0',
            borderRadius: 10, padding: '14px 16px',
          }}>
            <div style={{ fontSize: 12, color: '#64748b' }}>{s.label}</div>
            <div style={{
              display: 'inline-block', marginTop: 4,
              padding: '2px 10px', borderRadius: 12, background: s.bg, color: s.color,
              fontSize: 18, fontWeight: 600,
            }}>{s.value}</div>
          </div>
        ))}
      </div>

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
            placeholder="Search name, member #, hospital…"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            style={{
              width: '100%', padding: '8px 12px 8px 32px',
              border: '1px solid #e2e8f0', borderRadius: 8, fontSize: 13,
            }}
          />
        </div>
        <select
          value={statusFilter}
          onChange={(e) => setStatusFilter(e.target.value)}
          style={{ padding: '8px 12px', border: '1px solid #e2e8f0', borderRadius: 8, fontSize: 13 }}
        >
          {STATUS_OPTIONS.map((o) => (
            <option key={o.value} value={o.value}>{o.label}</option>
          ))}
        </select>
      </div>

      {isLoading ? (
        <div style={{ display: 'flex', justifyContent: 'center', padding: 40 }}><Spinner /></div>
      ) : (
        <>
          <Table columns={columns} data={filtered} emptyMessage="No reimbursement requests yet." />
          {isFetching && <div style={{ fontSize: 12, color: '#64748b', marginTop: 8 }}>Refreshing…</div>}
        </>
      )}

      {detail && (
        <Modal title={`Reimbursement — ${detail.first_name} ${detail.last_name}`} onClose={() => setDetail(null)}>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 12, maxWidth: 560 }}>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8, fontSize: 13 }}>
              <div><b>Member:</b> {detail.member_number}</div>
              <div><b>Submitted:</b> {fmtDate(detail.created_at)}</div>
              <div><b>Hospital:</b> {detail.hospital_name}</div>
              <div><b>Amount:</b> {fmtMoney(detail.amount, detail.currency)}</div>
              <div><b>Email:</b> {detail.email || '—'}</div>
              <div><b>Phone:</b> {detail.phone || '—'}</div>
            </div>
            <div style={{ fontSize: 13 }}>
              <b>Reason</b>
              <div style={{
                marginTop: 4, padding: 8, background: '#f8fafc',
                borderRadius: 6, color: '#334155', whiteSpace: 'pre-wrap',
              }}>{detail.reason}</div>
            </div>

            <div style={{ fontSize: 13 }}>
              <b>Payout details</b>
              <div style={{ marginTop: 4, color: '#334155' }}>
                {detail.payout_method === 'bank' ? (
                  <>
                    Bank: {detail.payout_bank_name || '—'} · Acct: {detail.payout_account_number || '—'}
                    {detail.payout_branch ? ` · Branch: ${detail.payout_branch}` : ''} · Name: {detail.payout_account_name || '—'}
                  </>
                ) : (
                  <>
                    Mobile money: {detail.payout_phone || '—'} · Name: {detail.payout_account_name || '—'}
                  </>
                )}
              </div>
            </div>

            <div style={{ fontSize: 13 }}>
              <b>Attachments</b>
              <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', marginTop: 4 }}>
                {detail.invoice_url && (
                  <a href={fileUrl(detail.invoice_url)} target="_blank" rel="noopener noreferrer"
                     style={{ display: 'inline-flex', alignItems: 'center', gap: 4, color: 'var(--primary)' }}>
                    <DocumentArrowDownIcon style={{ width: 14, height: 14 }} /> Invoice
                  </a>
                )}
                {detail.report_url && (
                  <a href={fileUrl(detail.report_url)} target="_blank" rel="noopener noreferrer"
                     style={{ display: 'inline-flex', alignItems: 'center', gap: 4, color: 'var(--primary)' }}>
                    <DocumentArrowDownIcon style={{ width: 14, height: 14 }} /> Medical report
                  </a>
                )}
                {!detail.invoice_url && !detail.report_url && <span style={{ color: '#94a3b8' }}>None</span>}
              </div>
            </div>

            <hr style={{ border: 0, borderTop: '1px solid #e2e8f0', margin: '4px 0' }} />

            <label style={{ fontSize: 13, fontWeight: 500 }}>Decision</label>
            <select
              value={decisionStatus}
              onChange={(e) => setDecisionStatus(e.target.value)}
              style={{ padding: '8px 10px', border: '1px solid #e2e8f0', borderRadius: 8, fontSize: 13 }}
            >
              <option value="pending">Pending</option>
              <option value="under_review">Under review</option>
              <option value="paid">Mark as PAID</option>
              <option value="rejected">Reject</option>
            </select>

            {decisionStatus === 'paid' && (
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
                <input
                  type="number"
                  step="0.01"
                  placeholder="Paid amount"
                  value={paidAmount}
                  onChange={(e) => setPaidAmount(e.target.value)}
                  style={{ padding: '8px 10px', border: '1px solid #e2e8f0', borderRadius: 8, fontSize: 13 }}
                />
                <input
                  type="text"
                  placeholder="Payment reference"
                  value={paymentRef}
                  onChange={(e) => setPaymentRef(e.target.value)}
                  style={{ padding: '8px 10px', border: '1px solid #e2e8f0', borderRadius: 8, fontSize: 13 }}
                />
              </div>
            )}

            <textarea
              placeholder="Admin notes (visible only internally)"
              value={adminNotes}
              onChange={(e) => setAdminNotes(e.target.value)}
              rows={3}
              style={{ padding: '8px 10px', border: '1px solid #e2e8f0', borderRadius: 8, fontSize: 13 }}
            />

            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 8 }}>
              <Button variant="ghost" onClick={() => setDetail(null)}>Cancel</Button>
              <Button
                variant={decisionStatus === 'rejected' ? 'danger' : 'primary'}
                disabled={updateMutation.isPending}
                onClick={submitDecision}
              >
                {decisionStatus === 'rejected'
                  ? <><XCircleIcon style={{ width: 14, height: 14 }} /> Reject</>
                  : <><CheckCircleIcon style={{ width: 14, height: 14 }} /> Save Decision</>}
              </Button>
            </div>
          </div>
        </Modal>
      )}
    </div>
  );
}
