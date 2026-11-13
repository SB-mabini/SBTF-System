import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";

import { ACTIVITY_ACTIONS } from "./activity-actions";

const MIGRATIONS_DIR = join(process.cwd(), "..", "..", "supabase", "migrations");

/**
 * The audit vocabulary is declared in PostgreSQL and mirrored in TypeScript for
 * filter dropdowns. If the two drift, a filter silently returns nothing, so the
 * mirror is checked against the migrations themselves.
 *
 * Values added by later migrations (`alter type … add value`) count too, in
 * file order, which mirrors the order PostgreSQL appends them.
 */
describe("activity action vocabulary", () => {
  const sql = readdirSync(MIGRATIONS_DIR)
    .filter((file) => file.endsWith(".sql"))
    .sort()
    .map((file) => readFileSync(join(MIGRATIONS_DIR, file), "utf8"))
    .join("\n");

  const enumBody = sql.match(
    /create type public\.activity_action as enum \(([\s\S]*?)\);/,
  )?.[1];

  const values = [
    ...Array.from(enumBody?.matchAll(/'([a-z_]+)'/g) ?? []).map((match) => match[1]),
    ...Array.from(
      sql.matchAll(/alter type public\.activity_action add value(?: if not exists)? '([a-z_]+)'/g),
    ).map((match) => match[1]),
  ];

  it("is declared in the types migration", () => {
    expect(enumBody, "activity_action enum not found").toBeDefined();
  });

  it("matches the enum values and their order", () => {
    expect(values).toEqual(ACTIVITY_ACTIONS);
  });

  it("has no duplicates", () => {
    expect(new Set(ACTIVITY_ACTIONS).size).toBe(ACTIVITY_ACTIONS.length);
  });
});
