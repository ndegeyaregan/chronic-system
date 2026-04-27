require('dotenv').config();
const { Pool } = require('pg');
const p = new Pool({
  host: process.env.DB_HOST, port: process.env.DB_PORT,
  database: process.env.DB_NAME, user: process.env.DB_USER, password: process.env.DB_PASSWORD,
});
async function run() {
  const tables = ['meal_logs','fitness_logs','vitals','conditions','psychosocial_checkins','content'];
  for (const t of tables) {
    const r = await p.query("SELECT column_name FROM information_schema.columns WHERE table_name=$1 ORDER BY ordinal_position", [t]);
    console.log(t + ': ' + r.rows.map(x => x.column_name).join(', '));
  }
  // Check if cms_content table exists
  const cms = await p.query("SELECT table_name FROM information_schema.tables WHERE table_name IN ('content','cms_content')");
  console.log('CMS tables:', cms.rows.map(x=>x.table_name).join(', '));
}
run().then(() => p.end()).catch(e => { console.error(e.message); p.end(); });
