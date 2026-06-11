import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import toast from 'react-hot-toast';
import { LinkIcon, CheckIcon } from '@heroicons/react/24/outline';
import { getProductLinks, updateProductLink } from '../../api/productLinks';
import Button from '../../components/UI/Button';
import Spinner from '../../components/UI/Spinner';

// Friendly copy shown above each link's input. The `key` values must stay in
// sync with the backend seed in 048_product_links.sql and the mobile-app
// login-screen popup.
const LINK_META = {
  microinsurance: {
    title: 'Micro Insurance',
    hint: 'Destination for the "Micro Insurance" option on the mobile login popup.',
  },
  existing_customer: {
    title: 'Existing Customer',
    hint: 'Where members already with Sanlam Allianz are sent to log in.',
  },
  other_life_products: {
    title: 'Other Life Products',
    hint: 'Landing page for the rest of Sanlam Allianz Uganda\u2019s life products.',
  },
};

const KEY_ORDER = ['microinsurance', 'existing_customer', 'other_life_products'];

export default function ProductLinksPage() {
  const qc = useQueryClient();
  // Local edits, keyed by link.key. Until the admin types into a field the
  // entry is `undefined` and the input falls back to the server-side URL —
  // this avoids the "setState in effect" anti-pattern of mirroring fetched
  // data into local state.
  const [edits, setEdits] = useState({});

  const { data: links = [], isLoading } = useQuery({
    queryKey: ['product-links'],
    queryFn: () => getProductLinks().then((r) => r.data),
    retry: false,
  });

  const updateMutation = useMutation({
    mutationFn: ({ key, url }) => updateProductLink(key, { url }),
    onSuccess: (_resp, vars) => {
      qc.invalidateQueries(['product-links']);
      // Clear the local edit for this key so the input reflects the fresh
      // server value once the query refetches.
      setEdits((prev) => {
        const next = { ...prev };
        delete next[vars.key];
        return next;
      });
      toast.success(`Updated "${LINK_META[vars.key]?.title || vars.key}"`);
    },
    onError: (err) =>
      toast.error(err.response?.data?.message || 'Failed to update link'),
  });

  if (isLoading) {
    return (
      <div style={{ display: 'flex', justifyContent: 'center', padding: '60px' }}>
        <Spinner />
      </div>
    );
  }

  // Show server links in a stable, business-friendly order, falling back to
  // alphabetical for anything new the backend might add later.
  const ordered = [...links].sort((a, b) => {
    const ia = KEY_ORDER.indexOf(a.key);
    const ib = KEY_ORDER.indexOf(b.key);
    return (ia === -1 ? 99 : ia) - (ib === -1 ? 99 : ib);
  });

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '20px', maxWidth: '820px' }}>
      <div>
        <h2 style={{ margin: '0 0 6px', fontSize: '20px', fontWeight: 700, color: 'var(--text)' }}>
          App Product Links
        </h2>
        <p style={{ margin: 0, color: '#64748b', fontSize: '13.5px', lineHeight: 1.5 }}>
          These URLs power the &ldquo;Other Sanlam Allianz Products&rdquo; popup that
          appears on the mobile app&apos;s login screen. Changes take effect the
          next time a member opens the popup.
        </p>
      </div>

      {ordered.map((l) => {
        const meta = LINK_META[l.key] || { title: l.label || l.key, hint: '' };
        const current = edits[l.key] ?? l.url ?? '';
        const dirty = current.trim() !== (l.url || '').trim();
        const valid = /^https?:\/\/\S+$/i.test(current.trim());

        return (
          <div
            key={l.key}
            style={{
              background: '#fff',
              borderRadius: '12px',
              padding: '20px 22px',
              boxShadow: '0 1px 4px rgba(0,0,0,0.07)',
              border: '1px solid #eef2f7',
            }}
          >
            <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '6px' }}>
              <LinkIcon style={{ width: 18, height: 18, color: 'var(--primary)' }} />
              <h3 style={{ margin: 0, fontSize: '15px', fontWeight: 600, color: 'var(--text)' }}>
                {meta.title}
              </h3>
              {l.updated_at && (
                <span style={{ marginLeft: 'auto', color: '#94a3b8', fontSize: '11px' }}>
                  Updated {new Date(l.updated_at).toLocaleString()}
                </span>
              )}
            </div>
            {meta.hint && (
              <p style={{ margin: '0 0 12px', color: '#64748b', fontSize: '12.5px' }}>
                {meta.hint}
              </p>
            )}

            <div style={{ display: 'flex', gap: '10px', alignItems: 'flex-start' }}>
              <input
                type="url"
                value={current}
                onChange={(e) => setEdits({ ...edits, [l.key]: e.target.value })}
                placeholder="https://example.com"
                style={{
                  flex: 1,
                  padding: '10px 12px',
                  border: `1px solid ${current && !valid ? '#ef4444' : '#cbd5e1'}`,
                  borderRadius: '8px',
                  fontSize: '14px',
                  fontFamily: 'inherit',
                  outline: 'none',
                }}
              />
              <Button
                onClick={() =>
                  updateMutation.mutate({ key: l.key, url: current.trim() })
                }
                disabled={!dirty || !valid || updateMutation.isPending}
              >
                <CheckIcon style={{ width: 14, height: 14, marginRight: 4 }} />
                Save
              </Button>
            </div>
            {current && !valid && (
              <p style={{ margin: '6px 0 0', color: '#ef4444', fontSize: '12px' }}>
                URL must start with http:// or https://
              </p>
            )}
          </div>
        );
      })}
    </div>
  );
}
