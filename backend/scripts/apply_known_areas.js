// Applies a curated set of known Kampala/Wakiso neighborhood coordinates to
// hospitals/pharmacies that still have no latitude/longitude, by matching
// each facility's name or area text against a keyword list.
//
// Most entries below were derived directly from this database's own
// already-correctly-geocoded rows (tight-cluster average of real matches),
// so they are trustworthy. A few marked "estimate" had no real geocoded
// example to learn from (e.g. Kitintale never appears in the area column,
// only inside facility names) and use a general-knowledge coordinate
// instead -- worth spot-checking on a map if exact precision matters.
//
// This does not call any external API, so it is instant and has no rate
// limit. It only ever touches rows where latitude/longitude is NULL.
//
// Usage:
//   node scripts/apply_known_areas.js            dry run (default) -- prints matches, writes nothing
//   node scripts/apply_known_areas.js --apply     writes the matched coordinates

require('dotenv').config();
const pool = require('../src/config/db');

const APPLY = process.argv.includes('--apply');

// [keyword to search for in name/area (case-insensitive), latitude, longitude, note]
const KNOWN_AREAS = [
  ['kitintale', 0.3480, 32.6295, 'estimate'],
  ['kabalagala', 0.3016, 32.5996, 'data'],
  ['buganda road', 0.3196, 32.5759, 'data'],
  ['buganda rd', 0.3196, 32.5759, 'data'],
  ['kololo', 0.3231, 32.5859, 'data'],
  ['kamwokya', 0.3440, 32.5892, 'data'],
  ['lugogo', 0.3259, 32.6045, 'data'],
  ['bugolobi', 0.3198, 32.6227, 'data'],
  ['bukoto', 0.3477, 32.5994, 'data'],
  ['ntinda', 0.3581, 32.6499, 'data'],
  ['naalya', 0.3654, 32.6345, 'data'],
  ['kasangati', 0.4381, 32.6036, 'data'],
  ['namugongo', 0.3837, 32.6536, 'data'],
  ['wandegeya', 0.3301, 32.5748, 'data'],
  ['naguru', 0.3411, 32.6018, 'data'],
  ['kisaasi', 0.3582, 32.5990, 'data'],
  ['nakasero', 0.3269, 32.5795, 'data'],
  ['kansanga', 0.3051, 32.6107, 'data'],
  ['kibuye', 0.2902, 32.5754, 'data'],
  ['makindye', 0.2902, 32.5754, 'data'],
  ['sseguku', 0.2343, 32.5552, 'data'],
  ['seguku', 0.2325, 32.5514, 'data'],
  ['bunga', 0.2680, 32.6234, 'data'],
  ['kiwatule', 0.3670, 32.6332, 'data'],
  ['zzana', 0.2557, 32.5640, 'data'],
  ['mengo', 0.3101, 32.5557, 'data'],
  ['namuwongo', 0.3051, 32.6107, 'data'],
  ['old kampala', 0.3170, 32.5686, 'data'],
  ['nsambya', 0.2999, 32.5939, 'data'],
  ['kawempe', 0.3664, 32.5779, 'data'],
  ['lubowa', 0.3068, 32.5945, 'data'],
  ['kyaliwajala', 0.3723, 32.6493, 'data'],
  ['bwebajja', 0.1904, 32.5391, 'data'],
  ['gayaza', 0.4518, 32.6111, 'data'],
  ['muyenga', 0.2900, 32.6050, 'estimate'],
  ['kiruddu', 0.2800, 32.5880, 'estimate'],
  ['najjera', 0.3749, 32.6252, 'data (weak, n=2)'],
];

async function applyToTable(table) {
  const { rows } = await pool.query(
    `SELECT id, name, area FROM ${table} WHERE latitude IS NULL OR longitude IS NULL`
  );

  console.log(`\n=== ${table}: ${rows.length} rows missing coordinates ===\n`);

  const summary = { matched: 0, unmatched: 0 };

  for (const row of rows) {
    const haystack = `${row.name || ''} ${row.area || ''}`.toLowerCase();
    const hit = KNOWN_AREAS.find(([keyword]) => haystack.includes(keyword));

    if (!hit) {
      summary.unmatched++;
      continue;
    }

    const [keyword, lat, lng, note] = hit;
    console.log(`  ${APPLY ? 'APPLIED' : 'WOULD APPLY'}  ${row.name} -> (${lat}, ${lng}) matched "${keyword}" [${note}]`);
    summary.matched++;

    if (APPLY) {
      await pool.query(
        `UPDATE ${table} SET latitude = $1, longitude = $2 WHERE id = $3`,
        [lat, lng, row.id]
      );
    }
  }

  console.log(`\n${table} summary:`, summary);
  return summary;
}

async function run() {
  const hospitalSummary = await applyToTable('hospitals');
  const pharmacySummary = await applyToTable('pharmacies');

  console.log('\n=== Totals ===');
  console.log({
    matched: hospitalSummary.matched + pharmacySummary.matched,
    unmatched: hospitalSummary.unmatched + pharmacySummary.unmatched,
  });
  console.log(
    APPLY
      ? '\nDone -- coordinates written for matched facilities.'
      : '\nDry run only -- nothing was written. Re-run with --apply to save these results.'
  );
  await pool.end();
}

run().catch((err) => {
  console.error('Fatal error:', err);
  process.exit(1);
});
