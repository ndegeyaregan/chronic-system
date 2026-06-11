/*
 * Claims analysis controller.
 *
 * The upload endpoint responds to the client as soon as the file is on disk
 * and an `claim_uploads` row is created (status='processing'). The actual
 * Excel parse + bulk insert is delegated to a detached child worker so that:
 *   1. The HTTP request returns in <1 second instead of blocking 10–60 s.
 *   2. A heavy parse (70 MB workbook → ~2 GB heap) cannot stall or crash
 *      the main API event loop — login and other requests stay responsive.
 *   3. We can set a generous --max-old-space-size on the worker only.
 *
 * The frontend polls GET /api/claims-analysis to see status transitions
 * (processing → ready / failed).
 */
const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');
const pool = require('../config/db');

const WORKER_SCRIPT = path.join(__dirname, '../workers/claimsParserWorker.js');

const uploadClaims = async (req, res) => {
  if (!req.file) return res.status(400).json({ message: 'No file uploaded' });
  const { path: filepath, originalname: filename, size: sizeBytes } = req.file;
  const userId = req.user?.id || null;

  try {
    const ins = await pool.query(
      `INSERT INTO claim_uploads (filename, size_bytes, status, uploaded_by)
       VALUES ($1, $2, 'processing', $3) RETURNING id, filename, size_bytes, row_count, total_amount, status, created_at`,
      [filename, sizeBytes, userId]
    );
    const upload = ins.rows[0];

    // Spawn parser as a detached child with its own 4 GB heap.
    const child = spawn(
      process.execPath,
      ['--max-old-space-size=4096', WORKER_SCRIPT, upload.id, filepath],
      {
        detached: true,
        stdio: ['ignore', 'inherit', 'inherit'],
        env: process.env,
      }
    );
    child.on('error', async (err) => {
      console.error('claims worker spawn error:', err);
      await pool.query(
        `UPDATE claim_uploads SET status = 'failed', error = $1 WHERE id = $2`,
        [`Failed to spawn parser: ${err.message}`.slice(0, 1000), upload.id]
      ).catch(() => {});
    });
    child.unref();

    console.log(`📥 Claims upload ${upload.id}: spawned worker pid ${child.pid} for ${filename} (${(sizeBytes / 1024 / 1024).toFixed(1)} MB)`);
    return res.status(202).json(upload);
  } catch (err) {
    console.error('uploadClaims error:', err);
    fs.unlink(filepath, () => {});
    return res.status(500).json({ message: err.message || 'Failed to accept upload' });
  }
};

const listUploads = async (_req, res) => {
  try {
    const r = await pool.query(
      `SELECT id, filename, size_bytes, row_count, total_amount, status, error, columns, created_at, updated_at
         FROM claim_uploads ORDER BY created_at DESC LIMIT 100`
    );
    return res.json(r.rows);
  } catch (err) {
    console.error('listUploads error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const getUpload = async (req, res) => {
  try {
    const { id } = req.params;
    const r = await pool.query(
      `SELECT id, filename, size_bytes, row_count, total_amount, status, error, columns, created_at, updated_at
         FROM claim_uploads WHERE id = $1`,
      [id]
    );
    if (!r.rows.length) return res.status(404).json({ message: 'Upload not found' });
    return res.json(r.rows[0]);
  } catch (err) {
    console.error('getUpload error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const previewUpload = async (req, res) => {
  try {
    const { id } = req.params;
    const limit = Math.min(parseInt(req.query.limit, 10) || 25, 200);
    const r = await pool.query(
      `SELECT claim_date, provider, provider_type, scheme, member_name, member_no, diagnosis, amount, raw
         FROM claims WHERE upload_id = $1 ORDER BY id ASC LIMIT $2`,
      [id, limit]
    );
    return res.json(r.rows);
  } catch (err) {
    console.error('previewUpload error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

const deleteUpload = async (req, res) => {
  try {
    const { id } = req.params;
    const r = await pool.query(`DELETE FROM claim_uploads WHERE id = $1 RETURNING id`, [id]);
    if (!r.rows.length) return res.status(404).json({ message: 'Upload not found' });
    return res.json({ message: 'Deleted' });
  } catch (err) {
    console.error('deleteUpload error:', err);
    return res.status(500).json({ message: 'Server error' });
  }
};

module.exports = { uploadClaims, listUploads, getUpload, previewUpload, deleteUpload };
