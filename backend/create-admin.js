require('dotenv').config();
const bcrypt = require('bcryptjs');
const pool = require('./src/config/db');
const { v4: uuidv4 } = require('uuid');

async function createAdmin() {
  const hash = await bcrypt.hash('Admin@1234', 10);
  const res = await pool.query(
    `INSERT INTO admins (id, name, email, password_hash, role)
     VALUES ($1, $2, $3, $4, $5)
     ON CONFLICT (email) DO UPDATE SET password_hash = EXCLUDED.password_hash
     RETURNING id, name, email, role`,
    [uuidv4(), 'Eddy Regan', 'eddyregan4@gmail.com', hash, 'super_admin']
  );
  console.log('✅ Super Admin created:');
  console.log(JSON.stringify(res.rows[0], null, 2));
  console.log('\n🔑 Login credentials:');
  console.log('   Email   : eddyregan4@gmail.com');
  console.log('   Password: Admin@1234');
  process.exit(0);
}

createAdmin().catch(e => { console.error('❌', e.message); process.exit(1); });
