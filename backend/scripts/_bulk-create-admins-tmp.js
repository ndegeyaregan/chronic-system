require('dotenv').config();
const bcrypt = require('bcryptjs');
const pool = require('../src/config/db');

const TEMP_PASSWORD = 'SanlamUg@2026!';

const users = [
  ['Isaac Musuubo', 'isaac.musuubo@ug.sanlamallianz.com', 'admin'],
  ['Benard Ojiambo', 'benard.ojiambo@ug.sanlamallianz.com', 'staff'],
  ['Betty Nimusiima', 'betty.nimusiima@ug.sanlamallianz.com', 'staff'],
  ['Charles Buyinza', 'charles.buyinza@ug.sanlamallianz.com', 'staff'],
  ['Clare Auma', 'clare.auma@ug.sanlamallianz.com', 'staff'],
  ['Coletta Mugabekazi', 'coletta.mugabekazi@ug.sanlamallianz.com', 'staff'],
  ['Esther Nakiwala', 'esther.nakiwala@ug.sanlamallianz.com', 'staff'],
  ['Jane Frances Nalubaale', 'jane.nalubaale@ug.sanlamallianz.com', 'staff'],
  ['Jesca Nalubowa', 'jesca.nalubowa@ug.sanlamallianz.com', 'staff'],
  ['Joanita Tusubira', 'joanita.tusubira@ug.sanlamallianz.com', 'staff'],
  ['Josephine Namutebi', 'josephine.namutebi@ug.sanlamallianz.com', 'staff'],
  ['Jovans Ariye', 'jovans.ariye@ug.sanlamallianz.com', 'staff'],
  ['Julius Kinyera', 'julius.kinyera@ug.sanlamallianz.com', 'staff'],
  ['Mable Nsangi', 'mable.nsangi@ug.sanlamallianz.com', 'staff'],
  ['Newton Bakiwandiise', 'newton.bakiwandiise@ug.sanlamallianz.com', 'staff'],
  ['Nicholas Ssenfuma', 'nicholas.ssenfuma@ug.sanlamallianz.com', 'staff'],
  ['Racheal Tumwijukye', 'racheal.tumwijukye@ug.sanlamallianz.com', 'staff'],
  ['Ruth Kisori', 'ruth.kisori@ug.sanlamallianz.com', 'staff'],
  ['Sharon Barbara Nabasumba Kalenge', 'sharon.nabasumba@ug.sanlamallianz.com', 'staff'],
  ['Stacey Mugarura', 'stacey.mugarura@sanlamallianz4u.co.ug', 'staff'],
  ['Victoria Tusuubira', 'victoria.tusuubira@ug.sanlamallianz.com', 'staff'],
];

function splitName(fullName) {
  const parts = fullName.trim().split(/\s+/);
  const first_name = parts[0];
  const last_name = parts.slice(1).join(' ') || parts[0];
  return { first_name, last_name };
}

async function run() {
  const hash = await bcrypt.hash(TEMP_PASSWORD, 12);
  const created = [];
  const skipped = [];

  for (const [name, email, role] of users) {
    const { first_name, last_name } = splitName(name);
    const result = await pool.query(
      `INSERT INTO admins (name, email, first_name, last_name, role, password_hash, is_active)
       VALUES ($1, $2, $3, $4, $5, $6, TRUE)
       ON CONFLICT (email) DO NOTHING
       RETURNING id, name, email, role`,
      [name, email, first_name, last_name, role, hash]
    );
    if (result.rows.length) {
      created.push(result.rows[0]);
    } else {
      skipped.push(email);
    }
  }

  console.log(`\nCreated ${created.length} admin(s):`);
  created.forEach((u) => console.log(`  - ${u.name} <${u.email}> [${u.role}]`));

  if (skipped.length) {
    console.log(`\nSkipped ${skipped.length} (email already exists):`);
    skipped.forEach((e) => console.log(`  - ${e}`));
  }

  console.log(`\nTemp password for all created accounts: ${TEMP_PASSWORD}`);
  process.exit(0);
}

run().catch((e) => {
  console.error('Bulk admin creation failed:', e.message);
  process.exit(1);
});
