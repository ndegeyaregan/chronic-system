import { useMemo, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import toast from 'react-hot-toast';
import {
  IdentificationIcon,
  MagnifyingGlassIcon,
  EyeIcon,
  ArrowPathIcon,
} from '@heroicons/react/24/outline';
import { listCardReprints, updateCardReprintStatus } from '../../api/cardReprints';
import Table from '../../components/UI/Table';
import Modal from '../../components/UI/Modal';
import Button from '../../components/UI/Button';
import Spinner from '../../components/UI/Spinner';

const STATUS_OPTIONS = [
  { value: '', label: 'All statuses' },
  { value: 'pending_payment', label: 'Pending payment' },
  { value: 'paid', label: 'Paid' },
  { value: 'processing', label: 'Processing' },
  { value: 'fulfilled', label: 'Fulfilled' },
  { value: 'cancelled', label: 'Cancelled' },
];

const PAYMENT_STATUS_OPTIONS = [
  { value: '', label: 'Any payment status' },
  { value: 'pending', label: 'Pending' },
  { value: 'completed', label: 'Completed' },
  { value: 'failed', label: 'Failed' },
  { value: 'reversed', label: 'Reversed' },
  { value: 'invalid', label: 'Invalid' },
];

const statusBadge = (s) => {
  const map = {
    pending_payment: { bg: '#fef3c7', fg: '#92400e' },
    paid:            { bg: '#dbeafe', fg: '#1e40af' },
    processing:      { bg: '#e0f2fe', fg: '#0369a1' },
    fulfilled:       { bg: '#d1fae5', fg: '#065f46' },
    cancelled:       { bg: '#fee2e2', fg: '#991b1b' },
  };
  return map[s] || { bg: '#f1f5f9', fg: '#475569' };
};

const paymentBadge = (s) => {
  const map = {
    pending:   { bg: '#fef3c7', fg: '#92400e' },
    completed: { bg: '#d1fae5', fg: '#065f46' },
    failed:    { bg: '#fee2e2', fg: '#991b1b' },
    reversed:  { bg: '#fde68a', fg: '#78350f' },
    invalid:   { bg: '#fee2e2', fg: '#991b1b' },
  };
  return map[s] || { bg: '#f1f5f9', fg: '#475569' };
};

const fmtDate = (d) => (d ? new Date(d).toLocaleString('en-GB') : '—');
const fmtMoney = (v, ccy = 'UGX') =>
  v == null ? '—' : `${ccy} ${Number(v).toLocaleString()}`;

export default function CardReprintsPage() {
  const qc = useQueryClient();
  const [statusFilter, setStatusFilter] = useState('');
  const [paymentFilter, setPaymentFilter] = useState('');
  const [search, setSearch] = useState('');
  const [detail, setDetail] = useState(null);
  const [nextStatus, setNextStatus] = useState('');

  const params = useMemo(() => ({
    ...(statusFilter && { status: statusFilter }),
    ...(paymentFilter && { payment_status: paymentFilter }),
    ...(search && { search }),
  }), [statusFilter, paymentFilter, search]);

  const { data = [], isLoading, isFetching, refetch } = useQuery({
    queryKey: ['card-reprints', params],
    queryFn: () => listCardReprints(params),
    placeholderData: (prev) => prev,
  });

  const counts = useMemo(() => {
    const c = { pending_payment: 0, paid: 0, processing: 0, fulfilled: 0 };
    data.forEach((r) => { if (c[r.status] != null) c[r.status]++; });
    return c;
  }, [data]);

  const updateMutation = useMutation({
    mutationFn: ({ id, status }) => updateCardReprintStatus(id, { status }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['card-reprints'] });
      toast.success('Reprint request updated');
      setDetail(null);
    },
    onError: (e) => toast.error(e.response?.data?.message || 'Failed to update'),
  });

  const openDetail = (row) => {
    setDetail(row);
    setNextStatus(row.status);
  };

  const columns = [
    { key: 'created_at', label: 'Submitted', render: (_, r) => <span style={{ color: 'var(--text)' }}>{fmtDate(r.created_at)}</span> },
    {
      key: 'principal', label: 'Principal',
      render: (_, r) => (
        <div>
          <div style={{ color: 'var(--text)', fontWeight: 500 }}>
            {r.first_name} {r.last_name}
          </div>
          <div style={{ fontSize: 12, color: '#64748b', fontFamily: 'monospace' }}>
            {r.principal_member_number}
          </div>
        </div>
      ),
    },
    {
      key: 'card_for', label: 'Card for',
      render: (_, r) => (
        <div>
          <div style={{ color: 'var(--text)' }}>{r.target_member_name}</div>
          <div style={{ fontSize: 12, color: '#64748b' }}>
            {r.target_relation} · <span style={{ fontFamily: 'monospace' }}>{r.target_member_no}</span>
          </div>
        </div>
      ),
    },
    {
      key: 'reason', label: 'Reason',
      render: (_, r) => (
        <span style={{ color: 'var(--text)', textTransform: 'capitalize' }}>{r.reason}</span>
      ),
    },
    {
      key: 'amount', label: 'Fee',
      render: (_, r) => <span style={{ color: 'var(--text)' }}>{fmtMoney(r.amount, r.currency)}</span>,
    },
    {
      key: 'payment_status', label: 'Payment',
      render: (_, r) => {
        const p = paymentBadge(r.payment_status || 'pending');
        return (
          <span style={{
            display: 'inline-block', padding: '2px 8px', borderRadius: 12,
            background: p.bg, color: p.fg, fontSize: 11, fontWeight: 600,
            textTransform: 'capitalize',
          }}>
            {r.payment_status || 'pending'}
          </span>
        );
      },
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
          <EyeIcon style={{ width: 13, height: 13 }} /> Manage
        </Button>
      ),
    },
  ];

  return (
    <div style={{ padding: 24 }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 16 }}>
        <IdentificationIcon style={{ width: 26, height: 26, color: 'var(--primary)' }} />
        <div>
          <h1 style={{ margin: 0, fontSize: 22, color: 'var(--text)' }}>Card Reprint Requests</h1>
          <p style={{ margin: '4px 0 0', color: '#64748b', fontSize: 13 }}>
            Member-submitted requests to reprint a membership card (principal or dependant).
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
          { label: 'Pending payment', value: counts.pending_payment, color: '#92400e', bg: '#fef3c7' },
          { label: 'Paid',            value: counts.paid,            color: '#1e40af', bg: '#dbeafe' },
          { label: 'Processing',      value: counts.processing,      color: '#0369a1', bg: '#e0f2fe' },
          { label: 'Fulfilled',       value: counts.fulfilled,       color: '#065f46', bg: '#d1fae5' },
        ].map((s) => (
          <div key={s.label} style={{
            background: 'var(--surface, #fff)', border: '1px solid #e2e8f0',
            borderRadius: 10, padding: '14px 16px',
          }}>
            <div style={{ fontSize: 12, color: '#64748b' }}>{s.label}</div>
            <div style={{
              display: 'inline-block', marginTop: 4, padding: '2px 10px', borderRadius: 12,
              background: s.bg, color: s.color, fontSize: 18, fontWeight: 600,
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
            placeholder="Search name, member #, target name…"
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
          {STATUS_OPTIONS.map((o) => <option key={o.value} value={o.value}>{o.label}</option>)}
        </select>
        <select
          value={paymentFilter}
          onChange={(e) => setPaymentFilter(e.target.value)}
          style={{ padding: '8px 12px', border: '1px solid #e2e8f0', borderRadius: 8, fontSize: 13 }}
        >
          {PAYMENT_STATUS_OPTIONS.map((o) => <option key={o.value} value={o.value}>{o.label}</option>)}
        </select>
      </div>

      {isLoading ? (
        <div style={{ display: 'flex', justifyContent: 'center', padding: 40 }}><Spinner /></div>
      ) : (
        <>
          <Table columns={columns} data={data} emptyMessage="No card reprint requests yet." />
          {isFetching && <div style={{ fontSize: 12, color: '#64748b', marginTop: 8 }}>Refreshing…</div>}
        </>
      )}

      {detail && (
        <Modal title={`Reprint — ${detail.target_member_name}`} onClose={() => setDetail(null)}>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 12, maxWidth: 540 }}>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8, fontSize: 13 }}>
              <div><b>Submitted:</b> {fmtDate(detail.created_at)}</div>
              <div><b>Principal:</b> {detail.first_name} {detail.last_name}</div>
              <div><b>Principal #:</b> {detail.principal_member_number}</div>
              <div><b>Card for:</b> {detail.target_member_name}</div>
              <div><b>Relation:</b> {detail.target_relation}</div>
              <div><b>Target #:</b> {detail.target_member_no}</div>
              <div><b>Reason:</b> <span style={{ textTransform: 'capitalize' }}>{detail.reason}</span></div>
              <div><b>Fee:</b> {fmtMoney(detail.amount, detail.currency)}</div>
              <div><b>Payment phone:</b> {detail.payment_phone}</div>
              <div><b>Paid at:</b> {fmtDate(detail.paid_at)}</div>
              <div><b>Fulfilled at:</b> {fmtDate(detail.fulfilled_at)}</div>
              <div><b>Pesapal ref:</b> {detail.pesapal_merchant_ref || '—'}</div>
            </div>

            {detail.reason_notes && (
              <div style={{ fontSize: 13 }}>
                <b>Notes</b>
                <div style={{
                  marginTop: 4, padding: 8, background: '#f8fafc',
                  borderRadius: 6, color: '#334155', whiteSpace: 'pre-wrap',
                }}>{detail.reason_notes}</div>
              </div>
            )}

            {(detail.payment_confirmation_code || detail.payment_proof_url) && (
              <div style={{ fontSize: 13 }}>
                <b>Member-supplied payment proof</b>
                <div style={{
                  marginTop: 4, padding: 10, background: '#fef3c7',
                  borderRadius: 6, color: '#78350f',
                  border: '1px solid #fcd34d',
                  display: 'flex', flexDirection: 'column', gap: 6,
                }}>
                  {detail.payment_confirmation_code && (
                    <div>
                      <span style={{ opacity: 0.8 }}>Transaction ID:</span>{' '}
                      <span style={{ fontFamily: 'monospace', fontWeight: 600 }}>
                        {detail.payment_confirmation_code}
                      </span>
                    </div>
                  )}
                  {detail.payment_proof_url && (
                    <div>
                      <span style={{ opacity: 0.8 }}>Screenshot:</span>{' '}
                      <a
                        href={(import.meta.env.VITE_API_URL || '/api')
                          .replace(/\/api\/?$/, '') + detail.payment_proof_url}
                        target="_blank"
                        rel="noopener noreferrer"
                        style={{ color: '#1d4ed8', fontWeight: 600 }}
                      >
                        {detail.payment_proof_name || 'View attachment'}
                      </a>
                    </div>
                  )}
                </div>
              </div>
            )}

            <hr style={{ border: 0, borderTop: '1px solid #e2e8f0', margin: '4px 0' }} />

            <label style={{ fontSize: 13, fontWeight: 500 }}>Update fulfilment status</label>
            <select
              value={nextStatus}
              onChange={(e) => setNextStatus(e.target.value)}
              style={{ padding: '8px 10px', border: '1px solid #e2e8f0', borderRadius: 8, fontSize: 13 }}
            >
              <option value="pending_payment">Pending payment</option>
              <option value="paid">Paid</option>
              <option value="processing">Processing</option>
              <option value="fulfilled">Fulfilled (delivered)</option>
              <option value="cancelled">Cancelled</option>
            </select>

            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 8 }}>
              <Button variant="ghost" onClick={() => setDetail(null)}>Cancel</Button>
              <Button
                variant="primary"
                disabled={updateMutation.isPending || nextStatus === detail.status}
                onClick={() => updateMutation.mutate({ id: detail.id, status: nextStatus })}
              >
                Save
              </Button>
            </div>
          </div>
        </Modal>
      )}
    </div>
  );
}
