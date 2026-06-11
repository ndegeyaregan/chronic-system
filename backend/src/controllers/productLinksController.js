const pool = require('../config/db');

// Stable keys recognised by the mobile login-screen popup. Updates to other
// keys are rejected so a typo cannot silently break the app.
const ALLOWED_KEYS = new Set([
  'microinsurance',
  'existing_customer',
  'other_life_products',
]);

// Public: returns every product link keyed by `key` so the mobile app can
// look them up without an extra round-trip per option.
const listProductLinks = async (_req, res) => {
  try {
    const result = await pool.query(
      `SELECT key, label, description, url, updated_at
         FROM product_links
        ORDER BY key ASC`
    );
    return res.json(result.rows);
  } catch (err) {
    console.error('listProductLinks error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

// Admin: update a single product link by key. The key itself is fixed; only
// label / description / url can change so the mobile-app contract stays stable.
const updateProductLink = async (req, res) => {
  try {
    const { key } = req.params;
    if (!ALLOWED_KEYS.has(key)) {
      return res.status(404).json({ message: 'Unknown product link key' });
    }

    const url = (req.body.url || '').toString().trim();
    const label = req.body.label != null ? req.body.label.toString().trim() : null;
    const description = req.body.description != null
      ? req.body.description.toString().trim()
      : null;

    if (!url) {
      return res.status(400).json({ message: 'URL is required' });
    }
    if (!/^https?:\/\//i.test(url)) {
      return res.status(400)
        .json({ message: 'URL must start with http:// or https://' });
    }

    const result = await pool.query(
      `UPDATE product_links SET
         url = $1,
         label = COALESCE($2, label),
         description = COALESCE($3, description),
         updated_at = NOW(),
         updated_by = $4
       WHERE key = $5
       RETURNING key, label, description, url, updated_at`,
      [url, label || null, description, req.user?.id || null, key]
    );

    if (!result.rows.length) {
      return res.status(404).json({ message: 'Product link not found' });
    }

    await pool.query(
      `INSERT INTO audit_logs (actor_id, actor_type, action, entity, entity_id, details, ip_address)
       VALUES ($1, 'admin', 'update', 'product_link', $2, $3, $4)`,
      [req.user.id, key, JSON.stringify({ url, label }), req.ip]
    ).catch((e) => console.warn('product_link audit log failed:', e.message));

    return res.json(result.rows[0]);
  } catch (err) {
    console.error('updateProductLink error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

module.exports = { listProductLinks, updateProductLink, ALLOWED_KEYS };
