/**
 * Server-side sign-in lockout.
 *
 * Five incorrect passwords for the same e-mail address from the same client IP
 * lock that pair out for fifteen minutes. The counters live in the server
 * process, not in the browser, so clearing site data or calling the Supabase
 * endpoint directly cannot reset them.
 *
 * This complements — it does not replace — Supabase Auth's own IP rate limits.
 * A multi-instance deployment gets one store per instance; the shared Supabase
 * limits still apply across all of them.
 */

export const MAX_FAILED_LOGIN_ATTEMPTS = 5;
export const LOGIN_LOCKOUT_MS = 15 * 60 * 1000;
export const LOGIN_ATTEMPT_WINDOW_MS = 15 * 60 * 1000;

interface LoginAttemptRecord {
  /** Timestamps of failures still inside the attempt window. */
  failures: number[];
  /** Epoch milliseconds when the lockout ends, or null when not locked. */
  lockedUntil: number | null;
}

type LoginAttemptStore = Map<string, LoginAttemptRecord>;

export interface LoginLockStatus {
  locked: boolean;
  retryAfterSeconds: number;
  remainingAttempts: number;
}

const globalForLoginGuard = globalThis as typeof globalThis & {
  __sbtfLoginAttempts?: LoginAttemptStore;
};

/**
 * Kept on globalThis so the counters survive module reloads in development.
 * Without that, every edit to a server file would silently reset the lockout.
 */
function attempts(): LoginAttemptStore {
  globalForLoginGuard.__sbtfLoginAttempts ??= new Map();
  return globalForLoginGuard.__sbtfLoginAttempts;
}

/** One bucket per e-mail address and client IP pair. */
export function loginAttemptKey(email: string, ip: string): string {
  const normalizedEmail = email.trim().toLowerCase();
  const normalizedIp = ip.trim() || "unknown";
  return `${normalizedEmail}|${normalizedIp}`;
}

function fullAllowance(): LoginLockStatus {
  return {
    locked: false,
    retryAfterSeconds: 0,
    remainingAttempts: MAX_FAILED_LOGIN_ATTEMPTS,
  };
}

function recentFailures(record: LoginAttemptRecord, now: number): number[] {
  return record.failures.filter((timestamp) => now - timestamp < LOGIN_ATTEMPT_WINDOW_MS);
}

/** Reads the current state without changing the number of recorded failures. */
export function getLoginLockStatus(key: string, now = Date.now()): LoginLockStatus {
  const store = attempts();
  const record = store.get(key);

  if (!record) return fullAllowance();

  if (record.lockedUntil !== null) {
    if (record.lockedUntil > now) {
      return {
        locked: true,
        retryAfterSeconds: Math.ceil((record.lockedUntil - now) / 1000),
        remainingAttempts: 0,
      };
    }

    // The lockout has elapsed: the next attempt starts with a clean slate.
    store.delete(key);
    return fullAllowance();
  }

  record.failures = recentFailures(record, now);

  if (record.failures.length === 0) {
    store.delete(key);
    return fullAllowance();
  }

  return {
    locked: false,
    retryAfterSeconds: 0,
    remainingAttempts: Math.max(0, MAX_FAILED_LOGIN_ATTEMPTS - record.failures.length),
  };
}

/**
 * Records one incorrect password and returns the resulting state. Calling this
 * while a lock is already active does not extend the lockout.
 */
export function recordFailedLogin(key: string, now = Date.now()): LoginLockStatus {
  const store = attempts();
  const existing = store.get(key);

  if (existing?.lockedUntil != null && existing.lockedUntil > now) {
    return getLoginLockStatus(key, now);
  }

  // An expired lock (or no record) starts over; an unlocked record is reused so
  // failures inside the window still accumulate.
  const record: LoginAttemptRecord =
    existing && existing.lockedUntil === null
      ? existing
      : { failures: [], lockedUntil: null };

  record.failures = recentFailures(record, now);
  record.failures.push(now);

  if (record.failures.length >= MAX_FAILED_LOGIN_ATTEMPTS) {
    record.lockedUntil = now + LOGIN_LOCKOUT_MS;
    store.set(key, record);
    return {
      locked: true,
      retryAfterSeconds: Math.ceil(LOGIN_LOCKOUT_MS / 1000),
      remainingAttempts: 0,
    };
  }

  store.set(key, record);
  return {
    locked: false,
    retryAfterSeconds: 0,
    remainingAttempts: MAX_FAILED_LOGIN_ATTEMPTS - record.failures.length,
  };
}

/** Clears the bucket after a successful sign-in. */
export function clearLoginFailures(key: string): void {
  attempts().delete(key);
}

/** Test-only reset. */
export function __resetLoginGuardForTests(): void {
  attempts().clear();
}
