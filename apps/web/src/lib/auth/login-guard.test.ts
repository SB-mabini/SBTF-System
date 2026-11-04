import { beforeEach, describe, expect, it } from "vitest";

import {
  LOGIN_ATTEMPT_WINDOW_MS,
  LOGIN_LOCKOUT_MS,
  MAX_FAILED_LOGIN_ATTEMPTS,
  __resetLoginGuardForTests,
  clearLoginFailures,
  getLoginLockStatus,
  loginAttemptKey,
  recordFailedLogin,
} from "./login-guard";

const KEY = "staff@mabini.gov.ph|203.0.113.7";
const START = 1_700_000_000_000;

function failTimes(times: number, start = START) {
  for (let index = 0; index < times; index += 1) {
    recordFailedLogin(KEY, start);
  }
}

beforeEach(() => {
  __resetLoginGuardForTests();
});

describe("loginAttemptKey", () => {
  it("normalises the e-mail address and trims the IP", () => {
    expect(loginAttemptKey("  Staff@Mabini.GOV.ph ", " 203.0.113.7 ")).toBe(
      "staff@mabini.gov.ph|203.0.113.7",
    );
  });

  it("falls back to an unknown IP when the header is blank", () => {
    expect(loginAttemptKey("staff@mabini.gov.ph", "   ")).toBe("staff@mabini.gov.ph|unknown");
  });

  it("keeps different addresses and different IPs apart", () => {
    expect(loginAttemptKey("a@mabini.gov.ph", "203.0.113.7")).not.toBe(
      loginAttemptKey("b@mabini.gov.ph", "203.0.113.7"),
    );
    expect(loginAttemptKey("a@mabini.gov.ph", "203.0.113.7")).not.toBe(
      loginAttemptKey("a@mabini.gov.ph", "198.51.100.4"),
    );
  });
});

describe("login lockout", () => {
  it("locks after five incorrect passwords", () => {
    for (let attempt = 1; attempt < MAX_FAILED_LOGIN_ATTEMPTS; attempt += 1) {
      const status = recordFailedLogin(KEY, START + attempt);
      expect(status.locked).toBe(false);
      expect(status.remainingAttempts).toBe(MAX_FAILED_LOGIN_ATTEMPTS - attempt);
    }

    const locked = recordFailedLogin(KEY, START + MAX_FAILED_LOGIN_ATTEMPTS);
    expect(locked.locked).toBe(true);
    expect(locked.remainingAttempts).toBe(0);
    expect(locked.retryAfterSeconds).toBe(LOGIN_LOCKOUT_MS / 1000);
  });

  it("reports the remaining lockout time and counts down", () => {
    failTimes(MAX_FAILED_LOGIN_ATTEMPTS);

    expect(getLoginLockStatus(KEY, START).retryAfterSeconds).toBe(LOGIN_LOCKOUT_MS / 1000);
    expect(getLoginLockStatus(KEY, START + 60_000).retryAfterSeconds).toBe(
      (LOGIN_LOCKOUT_MS - 60_000) / 1000,
    );
    expect(getLoginLockStatus(KEY, START + LOGIN_LOCKOUT_MS - 1).retryAfterSeconds).toBe(1);
  });

  it("does not extend an active lock when more attempts arrive", () => {
    failTimes(MAX_FAILED_LOGIN_ATTEMPTS);

    const status = recordFailedLogin(KEY, START + 60_000);
    expect(status.locked).toBe(true);
    expect(status.retryAfterSeconds).toBe((LOGIN_LOCKOUT_MS - 60_000) / 1000);
  });

  it("unlocks after the lockout and restores the full allowance", () => {
    failTimes(MAX_FAILED_LOGIN_ATTEMPTS);

    const status = getLoginLockStatus(KEY, START + LOGIN_LOCKOUT_MS + 1);
    expect(status.locked).toBe(false);
    expect(status.retryAfterSeconds).toBe(0);
    expect(status.remainingAttempts).toBe(MAX_FAILED_LOGIN_ATTEMPTS);
  });

  it("forgets failures older than the attempt window", () => {
    failTimes(MAX_FAILED_LOGIN_ATTEMPTS - 1);

    const status = getLoginLockStatus(KEY, START + LOGIN_ATTEMPT_WINDOW_MS + MAX_FAILED_LOGIN_ATTEMPTS);
    expect(status.locked).toBe(false);
    expect(status.remainingAttempts).toBe(MAX_FAILED_LOGIN_ATTEMPTS);
  });

  it("clears the bucket after a successful sign-in", () => {
    failTimes(MAX_FAILED_LOGIN_ATTEMPTS);

    clearLoginFailures(KEY);

    const status = getLoginLockStatus(KEY, START);
    expect(status.locked).toBe(false);
    expect(status.remainingAttempts).toBe(MAX_FAILED_LOGIN_ATTEMPTS);
  });

  it("keeps each e-mail and IP pair isolated", () => {
    failTimes(MAX_FAILED_LOGIN_ATTEMPTS);

    expect(getLoginLockStatus(loginAttemptKey("other@mabini.gov.ph", "203.0.113.7"), START).locked).toBe(
      false,
    );
    expect(getLoginLockStatus(loginAttemptKey("staff@mabini.gov.ph", "198.51.100.4"), START).locked).toBe(
      false,
    );
  });
});
