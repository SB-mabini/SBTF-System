import { describe, expect, it } from "vitest";

import {
  DatabaseNotReadyError,
  classifyDatabaseError,
  isDatabaseNotReady,
  toDatabaseNotReadyError,
} from "./errors";

describe("classifyDatabaseError", () => {
  it("reports a missing table (PGRST205) as a blocking schema problem", () => {
    const failure = classifyDatabaseError({
      message: 'Could not find the table \'public.profiles\' in the schema cache',
      code: "PGRST205",
      details: null,
      hint: null,
      status: 404,
    });

    expect(failure.kind).toBe("schema_missing");
    expect(failure.blocking).toBe(true);
    expect(failure.code).toBe("PGRST205");
  });

  it("reads a PostgreSQL code out of the message when no code field is set", () => {
    const failure = classifyDatabaseError({
      message: 'relation "public.franchise_applications" does not exist',
    });

    expect(failure.kind).toBe("schema_missing");
    expect(failure.code).toBeUndefined();
    expect(failure.hint).toContain("supabase/migrations");
  });

  it("reports a missing RPC (PGRST202) as a schema problem", () => {
    const failure = classifyDatabaseError({
      message: "Could not find the function public.rpc_analytics_overview() in the schema cache",
      code: "PGRST202",
    });

    expect(failure.kind).toBe("schema_missing");
  });

  it("reports a transport failure as unreachable", () => {
    const failure = classifyDatabaseError(new TypeError("fetch failed"));

    expect(failure.kind).toBe("unreachable");
    expect(failure.blocking).toBe(true);
  });

  it("reports a gateway response as unreachable", () => {
    const failure = classifyDatabaseError({ message: "Service Unavailable", status: 503 });

    expect(failure.kind).toBe("unreachable");
    expect(failure.status).toBe(503);
  });

  it("reports an insufficient-privilege error as unauthorised", () => {
    const failure = classifyDatabaseError({
      message: "permission denied for table profiles",
      code: "42501",
    });

    expect(failure.kind).toBe("unauthorised");
    expect(failure.blocking).toBe(true);
  });

  it("reports an expired JWT as unauthorised", () => {
    const failure = classifyDatabaseError({ message: "JWT expired", code: "PGRST300" });

    expect(failure.kind).toBe("unauthorised");
  });

  it("reports HTTP 401 as unauthorised, but GoTrue session errors stay non-blocking", () => {
    expect(classifyDatabaseError({ message: "No API key found in request", status: 401 }).kind).toBe(
      "unauthorised",
    );

    // An expired session is a normal part of authentication: it is classified,
    // but it must not be thrown as a DatabaseNotReadyError.
    const session = classifyDatabaseError({
      name: "AuthApiError",
      message: "Invalid Refresh Token",
      status: 400,
    });
    expect(session.kind).toBe("unauthorised");
    expect(session.blocking).toBe(false);
    expect(toDatabaseNotReadyError({ name: "AuthError", message: "Auth session missing!" })).toBeNull();
  });

  it("leaves an unrecognised failure as a non-blocking unknown", () => {
    const failure = classifyDatabaseError({ message: "check constraint violated", status: 400 });

    expect(failure.kind).toBe("unknown");
    expect(failure.blocking).toBe(false);
    expect(failure.reason).toBe("check constraint violated");
  });
});

describe("toDatabaseNotReadyError", () => {
  it("wraps a blocking failure in a DatabaseNotReadyError carrying the hint", () => {
    const error = toDatabaseNotReadyError({ message: "permission denied", status: 403 });

    expect(error).toBeInstanceOf(DatabaseNotReadyError);
    expect(error?.kind).toBe("unauthorised");
    expect(error?.hint.length).toBeGreaterThan(0);
  });

  it("returns null for a failure the interface can render normally", () => {
    expect(toDatabaseNotReadyError({ message: "duplicate key value", status: 409 })).toBeNull();
  });
});

describe("DatabaseNotReadyError", () => {
  it("is recognisable as a not-ready database even across a module boundary", () => {
    const error = new DatabaseNotReadyError(classifyDatabaseError(new TypeError("fetch failed")));

    expect(error).toBeInstanceOf(Error);
    expect(error.name).toBe("DatabaseNotReadyError");
    expect(isDatabaseNotReady(error)).toBe(true);
    expect(isDatabaseNotReady({ message: 'relation "x" does not exist' })).toBe(true);
    expect(isDatabaseNotReady({ message: "something else", status: 400 })).toBe(false);
  });
});
