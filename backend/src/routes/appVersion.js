const express = require('express');
const fs = require('fs');
const path = require('path');

const router = express.Router();

const MANIFEST_PATH = path.join(
  __dirname,
  '..',
  '..',
  'uploads',
  'apk',
  'version.json',
);

// Public, unauthenticated endpoint: lets the mobile app check whether a newer
// build is available, and lets the public download page render the latest
// version + release notes.
router.get('/version', (_req, res) => {
  fs.readFile(MANIFEST_PATH, 'utf8', (err, raw) => {
    if (err) {
      return res.status(404).json({ error: 'Version manifest not found' });
    }
    try {
      const manifest = JSON.parse(raw);
      // Always serve a fully-qualified URL so the mobile app can launch it.
      const host = `${req_protocol(res.req)}://${res.req.get('host')}`;
      const absUrl = manifest.url && manifest.url.startsWith('http')
        ? manifest.url
        : `${host}${manifest.url}`;
      res.set('Cache-Control', 'public, max-age=60');
      res.json({ ...manifest, url: absUrl });
    } catch (e) {
      res.status(500).json({ error: 'Invalid version manifest', details: e.message });
    }
  });
});

function req_protocol(req) {
  return req.headers['x-forwarded-proto'] || req.protocol || 'https';
}

module.exports = router;
