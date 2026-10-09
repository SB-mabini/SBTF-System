#!/usr/bin/env node
/**
 * Bundles every migration into one paste-ready SQL transaction.
 *
 *   npm run db:bundle         → supabase/setup-all.sql
 *   npm run db:bundle:seed    → supabase/setup-all-with-seed.sql (migrations + seed.sql)
 *
 * Why this exists: the SQL Editor in the Supabase dashboard has no migration
 * runner, and `supabase db push` needs the CLI plus a logged-in access token.
 * When neither is available the whole schema can still be applied by pasting one
 * file into the editor. Concatenating by hand is how statements get lost, so the
 * file is generated instead.
 *
 * The bundle is wrapped in a single transaction: either the whole schema lands or
 * nothing does, which matters because a half-applied schema leaves RLS disabled
 * on tables that already exist. The seed's own BEGIN/COMMIT are stripped so they
 * cannot end the outer transaction early.
 *
 * The final DO block is the receipt: it refuses to commit unless at least 15
 * public tables and exactly 34 barangays are present.
 *
 * The output is a build artefact and is git-ignored (supabase/setup-all*.sql).
 */
import { readdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = fileURLToPath(new URL("..", import.meta.url));
const MIGRATIONS_DIR = join(ROOT, "supabase", "migrations");
const SEED_FILE = join(ROOT, "supabase", "seed.sql");

const EXPECTED_BARANGAYS = 34;
const MINIMUM_TABLES = 15;

const withSeed = process.argv.includes("--with-seed");
const outputName = withSeed ? "setup-all-with-seed.sql" : "setup-all.sql";
const outputPath = join(ROOT, "supabase", outputName);

/* -------------------------------------------------------------------------- */

const migrations = readdirSync(MIGRATIONS_DIR)
  .filter((file) => file.endsWith(".sql"))
  .sort();

if (migrations.length === 0) {
  console.error(`  ✗ no migration files found in ${MIGRATIONS_DIR}`);
  process.exit(1);
}

const parts = [];

parts.push(`-- ===========================================================================
-- SBTF System — complete schema bundle
-- Municipality of Mabini, Batangas
--
-- GENERATED FILE — do not edit. Regenerate with:
--     npm run db:bundle${withSeed ? ":seed" : ""}
--
-- Source: ${migrations.length} migration file(s) from supabase/migrations/${
  withSeed ? "\n--         plus supabase/seed.sql (demonstration data — development only)" : ""
}
--
-- How to apply:
--   1. Supabase Dashboard → SQL Editor → New query
--   2. Paste this file in full
--   3. Run. The whole thing is one transaction: it either completes or the
--      database is left exactly as it was.
--
-- Re-running is safe: every migration is written to be idempotent.
-- ===========================================================================

begin;
`);

for (const file of migrations) {
  const body = readFileSync(join(MIGRATIONS_DIR, file), "utf8").trim();
  parts.push(`\n-- ---------------------------------------------------------------------------\n-- ${file}\n-- ---------------------------------------------------------------------------\n${body}\n`);
}

if (withSeed) {
  const seed = readFileSync(SEED_FILE, "utf8")
    .split("\n")
    // The seed carries its own BEGIN/COMMIT so it can be run standalone. Inside
    // this bundle they would close the outer transaction after the seed and
    // leave the verification block outside it.
    .filter((line) => !/^\s*(begin|commit|rollback|start\s+transaction)\s*;\s*$/i.test(line))
    .join("\n")
    .trim();

  parts.push(`\n-- ---------------------------------------------------------------------------\n-- seed.sql — anonymised demonstration data (DEVELOPMENT ONLY)\n-- Its own BEGIN/COMMIT have been removed: the bundle is one transaction.\n-- ---------------------------------------------------------------------------\n${seed}\n`);
}

parts.push(`
-- ---------------------------------------------------------------------------
-- Verification — this is the receipt. If the schema is incomplete the whole
-- transaction is rolled back and the SQL Editor reports the reason.
-- ---------------------------------------------------------------------------
do $$
declare
  v_tables     integer;
  v_barangays  integer;
begin
  select count(*) into v_tables
    from information_schema.tables
   where table_schema = 'public'
     and table_type = 'BASE TABLE';

  select count(*) into v_barangays from public.barangays;

  if v_tables < ${MINIMUM_TABLES} then
    raise exception
      'SBTF setup incomplete: % public table(s) found, expected at least ${MINIMUM_TABLES}',
      v_tables
      using hint = 'A migration probably failed. Read the message above this one.';
  end if;

  if v_barangays <> ${EXPECTED_BARANGAYS} then
    raise exception
      'SBTF setup incomplete: % barangay row(s) found, expected exactly ${EXPECTED_BARANGAYS}',
      v_barangays
      using hint = 'supabase/migrations/20260101090100_phase0_reference_data.sql did not apply.';
  end if;

  raise notice 'SBTF setup complete: % public table(s), % barangay row(s).', v_tables, v_barangays;
end
$$;

commit;
`);

const bundle = parts.join("");
writeFileSync(outputPath, bundle, "utf8");

const lines = bundle.split("\n").length;
console.log(
  `  ✓ ${outputName} — ${migrations.length} migration file(s)${
    withSeed ? " + seed.sql" : ""
  }, ${lines} lines, ${(Buffer.byteLength(bundle) / 1024).toFixed(0)} KB`,
);
console.log(`    Paste the whole file into the Supabase SQL Editor and run it.`);
