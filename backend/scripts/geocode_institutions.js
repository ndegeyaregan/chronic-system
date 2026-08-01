// Backfill: geocodes hospitals/pharmacies that are missing latitude/longitude
// (or that were previously stuck with a fake generic city-center match), using
// OpenStreetMap Nominatim, so the mobile app's "Find a Facility" list has real
// coordinates to sort nearest-first on.
//
// Two safety features this version adds over the original:
//
// 1. Query guard: if a facility's address/street/area are all blank and all
//    we have is a city name (e.g. "Kampala"), we no longer send that alone to
//    Nominatim -- it happily resolves "Kampala, Uganda" to the city centroid,
//    and dozens of unrelated facilities end up sharing that exact point.
//    Those rows are left NULL (sorts safely to the bottom of the list)
//    instead of getting a coordinate that looks precise but isn't.
//
// 2. Response guard: even with a detailed query, Nominatim can still fall
//    back to a city/town/administrative-boundary match if it can't resolve
//    the specific street. We request addressdetails=1 and reject any result
//    whose class/type indicates a place-level (not building/POI-level) match.
//
// 3. Cleanup pass: rows that already have a coordinate previously written by
//    the old (unguarded) version of this script are detected by finding
//    coordinate values shared by 5+ unrelated rows, and reset to NULL so
//    they get a real chance to be re-geocoded properly.
//
// Usage:
//   node scripts/geocode_institutions.js                    dry run (default) -- prints results, writes nothing
//   node scripts/geocode_institutions.js --apply             writes results back to hospitals/pharmacies
//   node scripts/geocode_institutions.js --apply --limit=20  only process the first 20 rows needing geocoding

require('dotenv').config();
const axios = require('axios');
const pool = require('../src/config/db');

const APPLY = process.argv.includes('--apply');
const limitArg = process.argv.find((a) => a.startsWith('--limit='));
const LIMIT = limitArg ? parseInt(limitArg.split('=')[1], 10) : null;

const NOMINATIM_URL = 'https://nominatim.openstreetmap.org/search';
const USER_AGENT = 'SanlamChronicCareApp-GeocodeBackfill/1.1 (systems@sanlamallianz4u.co.ug)';

// A match classified as one of these is a place/region, not a specific
// building or address -- too coarse to trust for "nearest facility" sorting.
const GENERIC_TYPES = new Set([
  'city', 'town', 'village', 'suburb', 'county', 'state', 'administrative',
  'region', 'municipality', 'hamlet', 'quarter', 'neighbourhood',
]);
const GENERIC_CLASSES = new Set(['boundary', 'place']);

// A coordinate shared by this many or more unrelated rows is almost
// certainly a leftover generic-fallback match from an earlier run, not a
// real address that many facilities happen to occupy.
const SHARED_COORD_THRESHOLD = 5;

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function buildAddressQuery(row) {
  const specific = [row.address, row.street, row.area]
    .filter((p) => p && String(p).trim().length > 0);
  const cityPart = [row.city, row.province, 'Uganda']
    .filter((p) => p && String(p).trim().length > 0);
  return {
    hasSpecific: specific.length > 0,
    query: [...specific, ...cityPart].join(', '),
  };
}

async function geocode(query) {
  const resp = await axios.get(NOMINATIM_URL, {
    params: { q: query, format: 'json', limit: 1, addressdetails: 1 },
    headers: { 'User-Agent': USER_AGENT },
    timeout: 10000,
  });
  const hit = resp.data && resp.data[0];
  if (!hit) return null;
  const tooGeneric = GENERIC_CLASSES.has(hit.class) || GENERIC_TYPES.has(hit.type);
  return {
    latitude: parseFloat(hit.lat),
    longitude: parseFloat(hit.lon),
    matchedName: hit.display_name,
    matchedType: `${hit.class}/${hit.type}`,
    tooGeneric,
  };
}

async function fetchMissing(table) {
  const provinceCol = table === 'hospitals' ? 'province' : 'NULL::text AS province';
  const { rows } = await pool.query(
    `SELECT id, name, address, street, city, ${provinceCol}, area
       FROM ${table}
      WHERE latitude IS NULL OR longitude IS NULL
      ORDER BY name`
  );
  return rows;
}

async function findSharedFallbackCoords(table) {
  const { rows } = await pool.query(
    `SELECT latitude, longitude, COUNT(*) AS cnt
       FROM ${table}
      WHERE latitude IS NOT NULL AND longitude IS NOT NULL
      GROUP BY latitude, longitude
      HAVING COUNT(*) >= $1
      ORDER BY cnt DESC`,
    [SHARED_COORD_THRESHOLD]
  );
  return rows;
}

async function resetSharedFallbacks(table, clusters) {
  let total = 0;
  for (const c of clusters) {
    const res = await pool.query(
      `UPDATE ${table} SET latitude = NULL, longitude = NULL
        WHERE latitude = $1 AND longitude = $2`,
      [c.latitude, c.longitude]
    );
    total += res.rowCount;
  }
  return total;
}

async function run() {
  const tables = ['hospitals', 'pharmacies'];
  const summary = {
    resetFakeClusters: 0, geocoded: 0, skippedTooGeneric: 0,
    noMatch: 0, skippedNoAddress: 0, errors: 0,
  };

  for (const table of tables) {
    const clusters = await findSharedFallbackCoords(table);
    if (clusters.length > 0) {
      console.log(`\n=== ${table}: ${clusters.length} fake shared-coordinate cluster(s) found ===`);
      for (const c of clusters) {
        console.log(`  (${c.latitude}, ${c.longitude}) shared by ${c.cnt} rows -- ${APPLY ? 'RESETTING to NULL' : 'WOULD RESET to NULL'}`);
      }
      if (APPLY) {
        const reset = await resetSharedFallbacks(table, clusters);
        summary.resetFakeClusters += reset;
        console.log(`  Reset ${reset} rows in ${table}.`);
      }
    }
  }

  for (const table of tables) {
    let rows = await fetchMissing(table);
    if (LIMIT) rows = rows.slice(0, LIMIT);
    console.log(`\n=== ${table}: ${rows.length} rows to geocode ===\n`);

    for (const row of rows) {
      const { query, hasSpecific } = buildAddressQuery(row);
      if (!hasSpecific) {
        console.log(`  SKIP        ${row.name} -- no street/area detail, only city-level info (would only match city center)`);
        summary.skippedNoAddress++;
        continue;
      }

      try {
        const result = await geocode(query);
        if (!result) {
          console.log(`  NO MATCH    ${row.name} -- query: "${query}"`);
          summary.noMatch++;
        } else if (result.tooGeneric) {
          console.log(`  SKIP        ${row.name} -- match too generic (${result.matchedType}: "${result.matchedName}"), leaving unset`);
          summary.skippedTooGeneric++;
        } else {
          console.log(
            `  ${APPLY ? 'APPLIED' : 'WOULD APPLY'}  ${row.name} -> ` +
              `(${result.latitude}, ${result.longitude}) via "${result.matchedName}"`
          );
          summary.geocoded++;
          if (APPLY) {
            await pool.query(
              `UPDATE ${table} SET latitude = $1, longitude = $2 WHERE id = $3`,
              [result.latitude, result.longitude, row.id]
            );
          }
        }
      } catch (err) {
        console.log(`  ERROR       ${row.name} -- ${err.message}`);
        summary.errors++;
      }

      await sleep(1100);
    }
  }

  console.log('\n=== Summary ===');
  console.log(summary);
  console.log(
    APPLY
      ? '\nDone -- fake clusters cleared and coordinates written where a precise match was found.'
      : '\nDry run only -- nothing was written. Re-run with --apply to save these results.'
  );
  await pool.end();
}

run().catch((err) => {
  console.error('Fatal error:', err);
  process.exit(1);
});
