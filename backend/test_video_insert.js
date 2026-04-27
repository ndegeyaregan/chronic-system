require('dotenv').config();
const pool = require('./src/config/db');

(async () => {
  try {
    console.log('1️⃣ Checking partner_videos table structure:');
    const schema = await pool.query(`
      SELECT column_name, data_type, is_nullable, column_default
      FROM information_schema.columns
      WHERE table_name = 'partner_videos'
      ORDER BY ordinal_position
    `);
    console.table(schema.rows);

    console.log('\n2️⃣ Checking lifestyle_partners table:');
    const partners = await pool.query(`SELECT id, name FROM lifestyle_partners LIMIT 3`);
    console.table(partners.rows);

    if (partners.rows.length > 0) {
      const partnerId = partners.rows[0].id;
      console.log(`\n3️⃣ Testing INSERT with partner ID: ${partnerId}`);
      
      const testResult = await pool.query(
        `INSERT INTO partner_videos
           (partner_id, title, youtube_video_id, duration_label, difficulty, category, sort_order)
         VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING *`,
        [
          partnerId,
          'Test Video',
          'testid123',
          '30 min',
          'Beginner',
          'Strength',
          0
        ]
      );
      console.log('✅ Test INSERT successful:', testResult.rows[0]);
      
      // Clean up
      await pool.query('DELETE FROM partner_videos WHERE id = $1', [testResult.rows[0].id]);
      console.log('✅ Test video cleaned up');
    }

    process.exit(0);
  } catch (err) {
    console.error('❌ Error:', err.message);
    console.error('SQL:', err.query);
    process.exit(1);
  }
})();
