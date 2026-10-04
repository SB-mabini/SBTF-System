import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";

import { ACTIVITY_ACTIONS } from "./activity-actions";

const TYPES_MIGRATION = join(
  process.cwd(),
  "..",
  "..",
  "supabase",
  "migrations",
  "20260101090000_phase0_types.sql",
);

/**
 * The audit vocabulary is declared in PostgreSQL and mirrored in TypeScript for
 * filter dropdowns. If the two drift, a filter silently returns nothing, so the
 * mirror is checked against the migration itself.
 */
describe("activity action vocabulary", () => {
  const sql = readFileSync(TYPES_MIGRATION, "utf8");
  const enumBody = sql.match(
    /create type public\.activity_action as enum \(([\s\S]*?)\);/,
  )?.[1];

  it("is declared in the types migration", () => {
    expect(enumBody, "activity_action enum not found").toBeDefined();
  });

  it("matches the enum values and their order", () => {
    const values = Array.from(enumBody!.matchAll(/'([a-z_]+)'/g)).map((match) => match[1]);
    expect(values).toEqual(ACTIVITY_ACTIONS);
  });

  it("has no duplicates", () => {
    expect(new Set(ACTIVITY_ACTIONS).size).toBe(ACTIVITY_ACTIONS.length);
  });
});
