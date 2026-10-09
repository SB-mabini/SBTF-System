/**
 * Classification of Supabase failures.
 *
 * The web console talks to PostgreSQL through PostgREST and to Supabase Auth
 * through GoTrue. Both answer with HTTP status codes and short error strings
 * rather than typed errors, so "the database is unreachable", "the migrations
 * were never applied" and "this session is not allowed" all arrive as
 * `{ message: "...", code: "..." }`.
 *
 * Without classification every one of those becomes `null` in the data layer,
 * which the route guards read as "not signed in" and answer with a redirect to
 * /login. The visitor then signs in successfully, the next request fails the
 * same way, and the console bounces between /login and /unauthorized forever
 * with nothing on screen to explain why.
 *
 * This module turns that into a decision: either the failure is a normal
 * condition the interface can explain (an expired session), or the database is
 * not in a usable state, in which case a `DatabaseNotReadyError` is thrown and
 * the middleware sends the visitor to /setup-required instead of looping.
 */

export type DatabaseFailureKind =
  /** A table, column, function or policy the code expects is not in the schema. */
  | "schema_missing"
  /** The key, session or policy refused the request. */
  | "unauthorised"
  /** The project could not be reached at all. */
  | "unreachable"
  /** Anything not recognised above. Never treated as blocking. */
  | "unknown";

export interface ClassifiedFailure {
  kind: DatabaseFailureKind;
  /**
   * True when no page can render usefully. Blocking failures are surfaced on
   * /setup-required; everything else is shown inline as a normal error.
   */
  blocking: boolean;
  /** One sentence, safe to show to a municipal user. */
  reason: string;
  /** What to do about it. Shown under the reason. */
  hint: string;
  /** The PostgREST / PostgreSQL code when the error carried one. */
  code?: string;
  status?: number;
}

/** Everything we can read out of the error shapes supabase-js produces. */
interface ErrorShape {
  message?: string;
  code?: string;
  status?: number;
  statusCode?: string | number;
  details?: string;
  hint?: string;
  name?: string;
  cause?: unknown;
  /** Next.js error-boundary digest, carried through for logging only. */
  digest?: string;
}

const UNREACHABLE_MESSAGES = [
  "fetch failed",
  "failed to fetch",
  "networkerror",
  "network request failed",
  "econnrefused",
  "econnreset",
  "enotfound",
  "eai_again",
  "etimedout",
  "socket hang up",
  "load failed",
  "terminated",
  "abort",
];

const UNREACHABLE_CODES = ["ETIMEDOUT", "ECONNREFUSED", "ECONNRESET", "ENOTFOUND", "EAI_AGAIN"];

/** PostgREST / PostgreSQL codes that mean "the schema is not what the code expects". */
const SCHEMA_MISSING_CODES = new Set([
  "PGRST200", // relationship not found in the schema cache
  "PGRST201", // embedded resource not found
  "PGRST202", // function not found in the schema cache
  "PGRST203", // ambiguous function (usually a dropped overload)
  "PGRST204", // column not found in the schema cache
  "PGRST205", // table not found in the schema cache
  "42P01", // undefined_table
  "42703", // undefined_column
  "42704", // undefined_object
  "42883", // undefined_function
  "42P17", // infinite recursion detected in the policy — a policy references a missing object
]);

const SCHEMA_MISSING_PATTERNS = [
  /could not find the ['"]?([a-z_.]+)['"]?( table| column| function)?/i,
  /relation ["']?[a-z_.]+["']? does not exist/i,
  /column ["']?[a-z_.]+["']? (does not exist|of relation)/i,
  /function [a-z_.]+\(.*\) does not exist/i,
  /schema cache/i,
  /is not present in the schema cache/i,
];

const UNAUTHORISED_CODES = new Set([
  "PGRST300", // JWT expired
  "PGRST301", // JWT invalid
  "PGRST302", // JWT not provided
  "42501", // insufficient_privilege
  "28000", // invalid_authorization_specification
  "28P01", // invalid_password
]);

const UNAUTHORISED_PATTERNS = [
  /permission denied/i,
  /row[- ]level security/i,
  /new row violates row[- ]level security/i,
  /jwt (expired|is invalid|malformed|not valid)/i,
  /invalid (api key|jwt)/i,
  /no api key found/i,
  /\bunauthorized\b/i,
  /\bforbidden\b/i,
];

function asErrorShape(error: unknown): ErrorShape {
  if (error && typeof error === "object") return error as ErrorShape;
  return { message: String(error) };
}

function text(error: unknown): string {
  const shape = asErrorShape(error);
  const parts = [
    shape.message,
    shape.code,
    shape.details,
    shape.hint,
    typeof shape.status === "number" ? String(shape.status) : undefined,
    shape.name,
  ].filter(Boolean) as string[];

  // supabase-js nests the real cause (a fetch TypeError, for example).
  const cause = shape.cause;
  if (cause) parts.push(text(cause));

  return parts.join(" ").toLowerCase();
}

function statusOf(error: unknown): number | undefined {
  const shape = asErrorShape(error);
  if (typeof shape.status === "number") return shape.status;
  if (typeof shape.statusCode === "number") return shape.statusCode;
  if (typeof shape.statusCode === "string" && /^\d+$/.test(shape.statusCode)) {
    return Number(shape.statusCode);
  }
  return undefined;
}

function codeOf(error: unknown): string | undefined {
  const shape = asErrorShape(error);
  if (shape.code) return String(shape.code);
  // PostgreSQL and PostgREST both put the code in parentheses inside the message.
  const match = /\(([0-9a-z]{5})\)/i.exec(shape.message ?? "");
  return match ? match[1]?.toUpperCase() : undefined;
}

/**
 * True for GoTrue *session* errors: an expired cookie, an invalid refresh token,
 * a missing session. These are a normal part of authentication — the visitor
 * simply signs in again — and must not be treated as a broken environment.
 *
 * PostgREST refusals (rotated key, missing RLS) look similar from the status
 * code alone, so the distinction is made on the error's identity: supabase-js
 * marks auth failures with an `Auth*` error name and `__isAuthError`.
 */
function isGoTrueSessionError(error: unknown): boolean {
  let current: unknown = error;
  for (let depth = 0; depth < 4 && current; depth++) {
    const shape = asErrorShape(current);
    const name = shape.name ?? "";
    const message = shape.message ?? "";
    if (/^Auth[A-Za-z]*Error$/.test(name) || name === "AuthError") return true;
    if ((current as { __isAuthError?: unknown })?.__isAuthError === true) return true;
    if (
      /auth session|session (missing|expired)|invalid refresh token|refresh token.*(invalid|expired|not found)|sign in again|email not confirmed/i.test(
        message,
      )
    ) {
      return true;
    }
    current = shape.cause;
  }
  return false;
}

const NETWORK_PATTERNS = UNREACHABLE_MESSAGES.map((message) => literalPattern(message));

function literalPattern(value: string): RegExp {
  return new RegExp(value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"), "i");
}

function isTransportFailure(error: unknown, status: number | undefined, code: string | undefined): boolean {
  if (status === 0) return true;
  if (status === 502 || status === 503 || status === 504) return true;
  if (code && UNREACHABLE_CODES.includes(code)) return true;
  if (error instanceof TypeError) return true;
  const haystack = text(error);
  return NETWORK_PATTERNS.some((pattern) => pattern.test(haystack));
}

/**
 * Maps any Supabase-shaped failure onto one of the four kinds.
 *
 * The order matters. A schema error arrives as an ordinary 400 with a five
 * character code somewhere in the message, so the code and message patterns are
 * checked first; only when nothing identifies the failure as a schema or
 * transport problem is it treated as an authorisation problem.
 *
 * @param error anything thrown by supabase-js, or the `{ error }` object it returns
 */
export function classifyDatabaseError(error: unknown): ClassifiedFailure {
  const shape = asErrorShape(error);
  const haystack = text(error);
  const status = statusOf(error);
  const code = codeOf(error);

  const matches = (patterns: RegExp[]) => patterns.some((pattern) => pattern.test(haystack));

  // --- 1. the schema is not what the code expects ---------------------------
  if ((code && SCHEMA_MISSING_CODES.has(code)) || matches(SCHEMA_MISSING_PATTERNS)) {
    return {
      kind: "schema_missing",
      blocking: true,
      reason: "The database does not match the schema this application expects.",
      hint:
        "Apply supabase/migrations to the project. `npm run db:bundle` writes a single paste-ready file for the SQL Editor; " +
        "see docs/deployment.md §2.",
      code,
      status,
    };
  }

  // --- 2. the project could not be reached ----------------------------------
  if (isTransportFailure(error, status, code)) {
    return {
      kind: "unreachable",
      blocking: true,
      reason: "The Supabase project could not be reached.",
      hint:
        "Check NEXT_PUBLIC_SUPABASE_URL, the project's status in the Supabase dashboard, and that the network allows outbound HTTPS. " +
        "Run `npm run db:check` for a step-by-step diagnosis.",
      code,
      status,
    };
  }

  // --- 3. the session or the key was refused --------------------------------
  if (
    (code && UNAUTHORISED_CODES.has(code)) ||
    status === 401 ||
    status === 403 ||
    matches(UNAUTHORISED_PATTERNS) ||
    isGoTrueSessionError(error)
  ) {
    // A GoTrue *session* error (expired cookie, stale refresh token) is a normal
    // part of authentication — the visitor signs in again. Only project-level
    // refusals (rotated key, missing RLS) are blocking.
    const sessionLevel = isGoTrueSessionError(error);
    return {
      kind: "unauthorised",
      blocking: !sessionLevel,
      reason: sessionLevel
        ? "The session is no longer valid."
        : "The database refused the request from this session.",
      hint: sessionLevel
        ? "Sign in again. If this keeps happening, run `npm run db:check`."
        : "This usually means the key in NEXT_PUBLIC_SUPABASE_ANON_KEY was rotated, or the row level security " +
          "policies are not applied. Sign in again, then run `npm run db:check`.",
      code,
      status,
    };
  }

  // --- 4. recognised as nothing in particular --------------------------------
  return {
    kind: "unknown",
    blocking: false,
    reason: shape.message || "The database request failed.",
    hint: "The failure has been logged. Retry, or check the Supabase dashboard logs for the same minute.",
    code,
    status,
  };
}

/**
 * Thrown when the database is not in a usable state — unmigrated, unreachable or
 * refusing the session. The middleware turns it into a redirect to
 * /setup-required instead of bouncing the visitor through /login.
 */
export class DatabaseNotReadyError extends Error {
  readonly kind: DatabaseFailureKind;
  readonly hint: string;
  readonly code?: string;
  readonly status?: number;

  constructor(failure: ClassifiedFailure) {
    super(failure.reason);
    this.name = "DatabaseNotReadyError";
    this.kind = failure.kind;
    this.hint = failure.hint;
    this.code = failure.code;
    this.status = failure.status;
    // Restore the prototype chain: the class extends a built-in and is compiled
    // to ES5-compatible output in some build targets.
    Object.setPrototypeOf(this, DatabaseNotReadyError.prototype);
  }
}

/** True for the thrown error and for anything that classifies as blocking. */
export function isDatabaseNotReady(error: unknown): boolean {
  if (error instanceof DatabaseNotReadyError) return true;
  if (error && typeof error === "object" && (error as { name?: string }).name === "DatabaseNotReadyError") {
    return true;
  }
  return classifyDatabaseError(error).blocking;
}

/**
 * Classifies and, when the failure is blocking, wraps it in a
 * `DatabaseNotReadyError`. Returns null for failures the interface can render
 * normally.
 */
export function toDatabaseNotReadyError(error: unknown): DatabaseNotReadyError | null {
  if (error instanceof DatabaseNotReadyError) return error;
  const failure = classifyDatabaseError(error);
  return failure.blocking ? new DatabaseNotReadyError(failure) : null;
}
