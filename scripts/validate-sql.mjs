#!/usr/bin/env node
/**
 * Static SQL validation for the SBTF System.
 *
 * The build environment has no PostgreSQL server, so this script runs the real
 * PostgreSQL grammar through libpg-query (the parser PostgreSQL itself uses):
 *
 *   1. every statement in every migration and in seed.sql is parsed;
 *   2. every plpgsql function body (including DO blocks) is parsed with the
 *      plpgsql grammar, which catches unbalanced BEGIN/END, IF/END IF,
 *      LOOP/END LOOP and CASE/END CASE plus genuine syntax errors;
 *   3. cross-file consistency: policies, triggers, indexes and REFERENCES
 *      clauses must point at tables that some migration creates, and calls to
 *      public.fn_x / public.rpc_x helpers must resolve.
 *
 * This is a lint, not a substitute for `supabase test db` (see docs/testing.md).
 *
 * Usage: node scripts/validate-sql.mjs
 */
import { readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import pgQuery from "libpg-query";

const ROOT = fileURLToPath(new URL("..", import.meta.url));
const MIGRATIONS_DIR = join(ROOT, "supabase", "migrations");

const KNOWN_EXTERNAL_TABLES = new Set([
  "storage.objects",
  "storage.buckets",
  "auth.users",
  "auth.identities",
]);

const FUNCTION_PREFIXES = ["fn_", "rpc_", "is_", "current_", "seed_"];

let errors = 0;
let warnings = 0;
let parsedStatements = 0;

const fail = (file, line, message) => {
  errors++;
  console.error(`  ✗ ${file}:${line}  ${message}`);
};
const warn = (file, line, message) => {
  warnings++;
  console.warn(`  ! ${file}:${line}  ${message}`);
};

/** Split a script into statements, honouring dollar quoting and comments. */
function splitStatements(sql) {
  const out = [];
  let current = "";
  let startLine = 1;
  let line = 1;
  let dollarTag = null;
  let inSingle = false;
  let inDouble = false;
  let inLineComment = false;
  let inBlockComment = false;
  let pendingStart = null;

  for (let i = 0; i < sql.length; i++) {
    const ch = sql[i];
    const next = sql[i + 1];

    if (ch === "\n") line++;
    if (pendingStart === null && !/\s/.test(ch)) pendingStart = line;

    if (inLineComment) {
      current += ch;
      if (ch === "\n") inLineComment = false;
      continue;
    }
    if (inBlockComment) {
      current += ch;
      if (ch === "*" && next === "/") {
        current += next;
        i++;
        inBlockComment = false;
      }
      continue;
    }
    if (dollarTag) {
      current += ch;
      if (ch === "$" && sql.startsWith(dollarTag, i)) {
        current += dollarTag.slice(1);
        i += dollarTag.length - 1;
        if (ch === "\n") line -= 0;
        dollarTag = null;
      }
      continue;
    }
    if (inSingle) {
      current += ch;
      if (ch === "'" && next === "'") {
        current += next;
        i++;
      } else if (ch === "'") inSingle = false;
      continue;
    }
    if (inDouble) {
      current += ch;
      if (ch === '"') inDouble = false;
      continue;
    }
    if (ch === "-" && next === "-") {
      inLineComment = true;
      current += ch + next;
      i++;
      continue;
    }
    if (ch === "/" && next === "*") {
      inBlockComment = true;
      current += ch + next;
      i++;
      continue;
    }
    if (ch === "'") {
      inSingle = true;
      current += ch;
      continue;
    }
    if (ch === '"') {
      inDouble = true;
      current += ch;
      continue;
    }
    if (ch === "$") {
      const match = /^\$[A-Za-z_0-9]*\$/.exec(sql.slice(i));
      if (match) {
        dollarTag = match[0];
        current += dollarTag;
        i += dollarTag.length - 1;
        continue;
      }
    }
    if (ch === ";") {
      if (current.trim() && stripLeadingComments(current).trim()) {
        out.push({ sql: current.trim(), line: pendingStart ?? startLine });
      }
      current = "";
      pendingStart = null;
      startLine = line;
      continue;
    }
    current += ch;
  }
  if (current.trim() && stripLeadingComments(current).trim()) {
    out.push({ sql: current.trim(), line: pendingStart ?? startLine });
  }
  return out;
}

function stripLeadingComments(text) {
  return text.replace(/^(\s*(--[^\n]*|\/\*[\s\S]*?\*\/))*\s*/, "");
}

function extractFunctionBody(statement) {
  const match = /\$([A-Za-z_0-9]*)\$([\s\S]*)\$\1\$/.exec(statement);
  if (!match) return null;
  const start = statement.indexOf(match[0]) + match[0].indexOf(match[2]);
  return { tag: match[1], body: match[2], start, end: start + match[2].length, outer: match[0] };
}

/**
 * libpg-query parses plpgsql WITHOUT a catalog, so a local variable declared
 * with a project-defined type (e.g. `v_status public.certificate_verification_status`)
 * is treated as a RECORD and trips a spurious "record variable cannot be part of
 * multiple-item INTO list" error. Inside DECLARE sections we therefore validate
 * structure only, substituting text for such types. Everything outside the
 * DECLARE section — control flow, statements, expressions — is still checked
 * exactly as written.
 */
function loosenDeclareTypes(statement) {
  const body = extractFunctionBody(statement);
  if (!body) return statement;
  const text = body.body;
  const declareIdx = text.search(/\bdeclare\b/i);
  if (declareIdx === -1) return statement;
  const beginIdx = text.search(/\bbegin\b/i);
  if (beginIdx === -1 || beginIdx < declareIdx) return statement;
  const patched =
    text.slice(0, declareIdx) +
    text.slice(declareIdx, beginIdx).replace(/public\.[a-z_0-9]+/gi, "text") +
    text.slice(beginIdx);
  return statement.slice(0, body.start) + patched + statement.slice(body.end);
}

/** Best-effort line offset of a parse error inside a statement. */
function errorLine(statement, error) {
  const cursor = error?.cursor?.line ?? null;
  if (!cursor) return null;
  return cursor;
}

// ---------------------------------------------------------------------------
const files = [
  ...readdirSync(MIGRATIONS_DIR)
    .filter((f) => f.endsWith(".sql"))
    .sort()
    .map((f) => join(MIGRATIONS_DIR, f)),
  join(ROOT, "supabase", "seed.sql"),
  ...readdirSync(join(ROOT, "supabase", "tests"))
    .filter((f) => f.endsWith(".sql"))
    .sort()
    .map((f) => join(ROOT, "supabase", "tests", f)),
];

console.log("SBTF static SQL validation (libpg-query)\n");

const knownTables = new Set();
const knownFunctions = new Set();

// Pass 1 — collect declared objects so cross-file references can be resolved.
for (const file of files) {
  const raw = readFileSync(file, "utf8");
  for (const m of raw.matchAll(/create\s+table\s+(?:if\s+not\s+exists\s+)?(?:public|storage)\.([a-z_]+)/gi)) {
    knownTables.add(`public.${m[1].toLowerCase()}`);
  }
  for (const m of raw.matchAll(/create\s+(?:or\s+replace\s+)?function\s+public\.([a-z_0-9]+)/gi)) {
    knownFunctions.add(m[1].toLowerCase());
  }
}

// Pass 2 — parse everything.
for (const file of files) {
  const name = file.split("/").pop();
  const sql = readFileSync(file, "utf8");
  const statements = splitStatements(sql);
  let fileErrors = 0;
  const before = errors;

  for (const { sql: statement, line } of statements) {
    const normalized = stripLeadingComments(statement).trim();
    const upper = normalized.toUpperCase();
    const isFunction = /^CREATE\s+(OR\s+REPLACE\s+)?FUNCTION\b/i.test(normalized);
    const isDoBlock = /^DO\b/i.test(normalized);
    const isPlpgsql = /\bLANGUAGE\s+plpgsql\b/i.test(normalized);

    // 1. Outer SQL syntax (the real PostgreSQL grammar).
    try {
      await pgQuery.parse(statement);
      parsedStatements++;
    } catch (error) {
      const inner = errorLine(statement, error);
      fail(
        name,
        line + (inner ?? 0),
        `${(error.message || String(error)).split("\n").slice(0, 3).join(" | ")}`,
      );
      fileErrors++;
      continue;
    }

    const body = extractFunctionBody(statement);

    // 2. plpgsql body validation.
    if (body && (isPlpgsql || isDoBlock)) {
      const wrapped = isDoBlock
        ? `create function pg_temp.sbtf_do_block() returns void language plpgsql as $sbtf$${body.body}$sbtf$;`
        : statement;
      try {
        await pgQuery.parsePlPgSQL(loosenDeclareTypes(wrapped));
      } catch (error) {
        const inner = errorLine(statement, error);
        fail(
          name,
          line + (inner ?? 0),
          `plpgsql: ${(error.message || String(error)).split("\n")[0]}`,
        );
        fileErrors++;
        continue;
      }
    }

    // 3. Cross-file table references.
    const tableRefs = [
      ...normalized.matchAll(/\b(?:on|alter\s+table|references|join|from|into|update|delete\s+from|table)\s+public\.([a-z_]+)/gi),
    ];
    for (const m of tableRefs) {
      const table = `public.${m[1].toLowerCase()}`;
      // `from public.rpc_x(...)` is a function call, not a table reference.
      if (knownFunctions.has(m[1].toLowerCase())) continue;
      if (!knownTables.has(table) && !KNOWN_EXTERNAL_TABLES.has(table)) {
        warn(name, line, `references ${table}, which no migration creates`);
      }
    }

    // 4. Cross-file function references (only our own helper prefixes).
    for (const m of normalized.matchAll(/\bpublic\.([a-z_0-9]+)\s*\(/gi)) {
      const fn = m[1].toLowerCase();
      if (!FUNCTION_PREFIXES.some((p) => fn.startsWith(p))) continue;
      if (!knownFunctions.has(fn)) {
        fail(name, line, `calls public.${fn}(), which is never defined`);
      }
    }
  }

  const delta = errors - before;
  console.log(
    `  ${delta === 0 ? "✓" : "✗"} ${name.padEnd(46)} ${String(statements.length).padStart(3)} statements — ${
      delta === 0 ? "ok" : `${delta} error(s)`
    }`,
  );
  void fileErrors;
}

console.log(
  `\n${parsedStatements} statements parsed with the PostgreSQL grammar, ${errors} error(s), ${warnings} warning(s).`,
);
process.exit(errors > 0 ? 1 : 0);
