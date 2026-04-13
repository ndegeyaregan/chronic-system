require('dotenv').config();
const { Pool } = require('pg');
const bcrypt = require('bcryptjs');

const p = new Pool({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT,
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
});

async function run() {
  // Check columns
  const cols = await p.query(
    "SELECT column_name FROM information_schema.columns WHERE table_name='members'"
  );
  console.log('Columns:', cols.rows.map(r => r.column_name).join(', '));

  // Check count
  const cnt = await p.query('SELECT COUNT(*) FROM members');
  console.log('Member count:', cnt.rows[0].count);

  // Create test member
  const hash = await bcrypt.hash('Test1234!', 12);
  await p.query(
    `INSERT INTO members (member_number, first_name, last_name, email, date_of_birth, plan_type, is_active, password_hash, is_password_set)
     VALUES ('TEST-001', 'Test', 'User', 'test@sanlam.co.ug', '1990-01-01', 'Standard', TRUE, $1, TRUE)
     ON CONFLICT (member_number) DO UPDATE SET password_hash=$1, is_password_set=TRUE, is_active=TRUE`,
    [hash]
  );
  console.log('Test member upserted: TEST-001 / Test1234!');

  // Test login
  const res = await p.query('SELECT * FROM members WHERE member_number=$1', ['TEST-001']);
  const m = res.rows[0];
  const valid = await bcrypt.compare('Test1234!', m.password_hash);
  console.log('Password check:', valid ? 'PASS' : 'FAIL');
  console.log('is_active:', m.is_active, '| is_password_set:', m.is_password_set);
}

run().then(() => p.end()).catch(e => { console.error('ERROR:', e.message); p.end(); });
