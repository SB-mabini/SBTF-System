// ===========================================================================
// Edge Function: push-dispatch
//
// Drains public.push_outbox and delivers each notification to every device
// token registered for the recipient, using Firebase Cloud Messaging HTTP v1.
//
// Invocation: a Supabase scheduled job (pg_cron) POSTs here every minute.
// The caller authenticates with the project's service-role key (or the
// optional PUSH_CRON_SECRET shared secret), compared in constant time.
//
// Security:
//   * verify_jwt = false because a scheduler has no end-user JWT;
//   * the function never accepts client input — the batch comes from a
//     SECURITY DEFINER RPC that only the service role may execute;
//   * the FCM service-account key lives only in this function's environment
//     (FCM_SERVICE_ACCOUNT_JSON), never in the repo or the mobile app.
//
// Delivery semantics:
//   * one FCM request per token (HTTP v1 has no batch endpoint);
//   * UNREGISTERED / INVALID_ARGUMENT tokens are deleted from device_tokens;
//   * transient failures are retried by the outbox (up to 5 attempts);
//   * a profile with no registered device is marked 'skipped', not 'failed'.
// ===========================================================================

import { createClient } from "npm:@supabase/supabase-js@2";
import { corsHeaders, errorResponse, json } from "../_shared/http.ts";

const FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging";
const TOKEN_URL = "https://oauth2.googleapis.com/token";
const ANDROID_CHANNEL_ID = "sbtf_updates";
const RETRY_DELAY_MINUTES = 2;

type ServiceAccount = {
  project_id: string;
  client_email: string;
  private_key: string;
};

type ClaimedRow = {
  outbox_id: string;
  notification_id: string;
  profile_id: string;
  title: string;
  message: string;
  notification_type: string;
  target_type: string | null;
  target_id: string | null;
};

type SendOutcome = {
  ok: boolean;
  deadToken: boolean;
  error: string | null;
};

// ---------------------------------------------------------------------------
// Crypto / OAuth
// ---------------------------------------------------------------------------

function base64Url(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
}

function base64UrlText(value: string): string {
  return base64Url(new TextEncoder().encode(value));
}

async function importPrivateKey(pem: string): Promise<CryptoKey> {
  const der = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s+/g, "");
  const bytes = Uint8Array.from(atob(der), (char) => char.charCodeAt(0));
  return await crypto.subtle.importKey(
    "pkcs8",
    bytes,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
}

/** Exchanges the service account for an OAuth2 access token (cached). */
class FcmAuthorizer {
  #account: ServiceAccount;
  #key: Promise<CryptoKey> | null = null;
  #token: string | null = null;
  #expiresAt = 0;

  constructor(account: ServiceAccount) {
    this.#account = account;
  }

  get projectId(): string {
    return this.#account.project_id;
  }

  async accessToken(): Promise<string> {
    const now = Math.floor(Date.now() / 1000);
    if (this.#token && now < this.#expiresAt - 60) return this.#token;

    this.#key ??= importPrivateKey(this.#account.private_key);
    const key = await this.#key;

    const header = base64UrlText(JSON.stringify({ alg: "RS256", typ: "JWT" }));
    const claim = base64UrlText(
      JSON.stringify({
        iss: this.#account.client_email,
        scope: FCM_SCOPE,
        aud: TOKEN_URL,
        iat: now,
        exp: now + 3600,
      }),
    );
    const unsigned = `${header}.${claim}`;
    const signature = new Uint8Array(
      await crypto.subtle.sign(
        "RSASSA-PKCS1-v1_5",
        key,
        new TextEncoder().encode(unsigned),
      ),
    );
    const assertion = `${unsigned}.${base64Url(signature)}`;

    const response = await fetch(TOKEN_URL, {
      method: "POST",
      headers: { "content-type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
        assertion,
      }),
    });

    if (!response.ok) {
      const detail = await response.text();
      throw new Error(`OAuth token exchange failed (${response.status}): ${detail.slice(0, 300)}`);
    }

    const payload = await response.json();
    this.#token = payload.access_token as string;
    this.#expiresAt = now + Number(payload.expires_in ?? 3600);
    return this.#token!;
  }
}

// ---------------------------------------------------------------------------
// FCM HTTP v1
// ---------------------------------------------------------------------------

async function sendToToken(
  authorizer: FcmAuthorizer,
  accessToken: string,
  token: string,
  row: ClaimedRow,
): Promise<SendOutcome> {
  const body = {
    message: {
      token,
      notification: {
        title: row.title,
        body: pushBody(row.message),
      },
      // The app routes a tap with these values; they are all strings because
      // FCM data values must be strings.
      data: {
        notification_id: row.notification_id,
        notification_type: row.notification_type,
        target_type: row.target_type ?? "",
        target_id: row.target_id ?? "",
      },
      android: {
        priority: "HIGH",
        notification: {
          channel_id: ANDROID_CHANNEL_ID,
          sound: "default",
          default_vibrate_timings: true,
        },
      },
    },
  };

  let response: Response;
  try {
    response = await fetch(
      `https://fcm.googleapis.com/v1/projects/${authorizer.projectId}/messages:send`,
      {
        method: "POST",
        headers: {
          authorization: `Bearer ${accessToken}`,
          "content-type": "application/json",
        },
        body: JSON.stringify(body),
      },
    );
  } catch (cause) {
    return { ok: false, deadToken: false, error: `network: ${String(cause)}` };
  }

  if (response.ok) return { ok: true, deadToken: false, error: null };

  const raw = await response.text();
  const detail = parseFcmError(raw);
  const dead = detail.errorCode === "UNREGISTERED" ||
    detail.errorCode === "INVALID_ARGUMENT" ||
    detail.errorCode === "SENDER_ID_MISMATCH";

  return {
    ok: false,
    deadToken: dead,
    error: `${response.status} ${detail.errorCode ?? detail.status ?? ""}: ${
      (detail.message ?? raw).slice(0, 240)
    }`.trim(),
  };
}

function pushBody(message: string): string {
  const clean = message.replace(/\s+/g, " ").trim();
  return clean.length <= 200 ? clean : `${clean.slice(0, 197)}…`;
}

function parseFcmError(raw: string): {
  status?: string;
  message?: string;
  errorCode?: string;
} {
  try {
    const parsed = JSON.parse(raw);
    const error = parsed?.error ?? {};
    const details: Array<{ errorCode?: string }> = Array.isArray(error.details) ? error.details : [];
    return {
      status: error.status,
      message: error.message,
      errorCode: details.map((entry) => entry?.errorCode).find(Boolean),
    };
  } catch {
    return { message: raw };
  }
}

/** Runs `worker` over `items` with at most `limit` requests in flight. */
async function mapWithConcurrency<T, R>(
  items: T[],
  limit: number,
  worker: (item: T) => Promise<R>,
): Promise<R[]> {
  const results: R[] = new Array(items.length);
  let cursor = 0;

  async function run(): Promise<void> {
    while (cursor < items.length) {
      const index = cursor++;
      results[index] = await worker(items[index]);
    }
  }

  await Promise.all(
    Array.from({ length: Math.min(limit, items.length) }, () => run()),
  );
  return results;
}

// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------

function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let mismatch = 0;
  for (let index = 0; index < a.length; index++) {
    mismatch |= a.charCodeAt(index) ^ b.charCodeAt(index);
  }
  return mismatch === 0;
}

Deno.serve(async (request: Request) => {
  const origin = request.headers.get("origin");

  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders(origin) });
  }
  if (request.method !== "POST") {
    return errorResponse("method_not_allowed", "Use POST.", 405, origin);
  }

  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const expectedSecret = Deno.env.get("PUSH_CRON_SECRET") ?? serviceRoleKey;
  const providedSecret = request.headers.get("x-sbtf-cron-secret") ??
    (request.headers.get("Authorization")?.replace(/^Bearer\s+/i, "") ?? "");

  if (!expectedSecret) {
    return errorResponse("misconfigured", "No dispatcher secret is configured.", 500, origin);
  }
  if (!providedSecret || !timingSafeEqual(expectedSecret, providedSecret)) {
    return errorResponse("forbidden", "A valid dispatcher secret is required.", 403, origin);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  if (!supabaseUrl || !serviceRoleKey) {
    return errorResponse("misconfigured", "Supabase environment variables are missing.", 500, origin);
  }

  let account: ServiceAccount;
  try {
    account = JSON.parse(Deno.env.get("FCM_SERVICE_ACCOUNT_JSON") ?? "{}");
    if (!account.project_id || !account.client_email || !account.private_key) {
      throw new Error("missing project_id / client_email / private_key");
    }
  } catch (cause) {
    console.error("FCM_SERVICE_ACCOUNT_JSON is unusable", cause);
    return errorResponse(
      "misconfigured",
      "FCM_SERVICE_ACCOUNT_JSON is missing or invalid.",
      500,
      origin,
    );
  }

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false },
  });

  const limit = clampLimit(new URL(request.url).searchParams.get("limit"));
  const { data: claimed, error: claimError } = await admin.rpc("rpc_push_claim_batch", {
    p_limit: limit,
  });

  if (claimError) {
    console.error("push_claim_batch failed", claimError);
    return errorResponse("claim_failed", claimError.message, 500, origin);
  }

  const rows = (claimed ?? []) as ClaimedRow[];
  if (rows.length === 0) {
    return json({ ok: true, claimed: 0, sent: 0, skipped: 0, failed: 0, tokens_removed: 0 }, 200, origin);
  }

  // --- tokens for the whole batch, in one query -----------------------------
  const profileIds = [...new Set(rows.map((row) => row.profile_id))];
  const { data: tokenRows, error: tokenError } = await admin
    .from("device_tokens")
    .select("profile_id, token")
    .in("profile_id", profileIds);

  if (tokenError) {
    console.error("device token read failed", tokenError);
    return errorResponse("tokens_failed", tokenError.message, 500, origin);
  }

  const tokensByProfile = new Map<string, string[]>();
  for (const row of tokenRows ?? []) {
    const list = tokensByProfile.get(row.profile_id) ?? [];
    list.push(row.token);
    tokensByProfile.set(row.profile_id, list);
  }

  // --- send -----------------------------------------------------------------
  const authorizer = new FcmAuthorizer(account);
  let accessToken: string | null = null;
  try {
    accessToken = await authorizer.accessToken();
  } catch (cause) {
    console.error("FCM authorisation failed", cause);
    // Release the batch so the next tick retries instead of leaving it stuck.
    await requeue(admin, rows.map((row) => row.outbox_id), `authorisation: ${String(cause)}`);
    return errorResponse("fcm_auth_failed", "Could not authenticate with FCM.", 502, origin);
  }

  const deadTokens = new Set<string>();
  const outcomes: Array<{ row: ClaimedRow; sent: number; error: string | null }> = [];

  const work: Array<{ row: ClaimedRow; token: string }> = [];
  for (const row of rows) {
    for (const token of tokensByProfile.get(row.profile_id) ?? []) {
      work.push({ row, token });
    }
  }

  const results = await mapWithConcurrency(work, 10, async (item) => {
    const outcome = await sendToToken(authorizer, accessToken!, item.token, item.row);
    if (outcome.deadToken) deadTokens.add(item.token);
    return { ...item, outcome };
  });

  const perRow = new Map<string, { sent: number; error: string | null }>();
  for (const row of rows) perRow.set(row.outbox_id, { sent: 0, error: null });
  for (const result of results) {
    const entry = perRow.get(result.row.outbox_id)!;
    if (result.outcome.ok) {
      entry.sent += 1;
    } else {
      entry.error = result.outcome.error;
    }
  }

  for (const row of rows) {
    const entry = perRow.get(row.outbox_id)!;
    outcomes.push({ row, sent: entry.sent, error: entry.error });
  }

  // --- prune invalid tokens -------------------------------------------------
  let tokensRemoved = 0;
  if (deadTokens.size > 0) {
    const { error: pruneError } = await admin
      .from("device_tokens")
      .delete()
      .in("token", [...deadTokens]);
    if (pruneError) {
      console.error("token prune failed", pruneError);
    } else {
      tokensRemoved = deadTokens.size;
    }
  }

  // --- settle outbox rows ---------------------------------------------------
  let sent = 0;
  let skipped = 0;
  let failed = 0;

  for (const outcome of outcomes) {
    const hasTokens = (tokensByProfile.get(outcome.row.profile_id) ?? []).length > 0;

    if (outcome.sent > 0) {
      sent += 1;
      await admin.from("push_outbox").update({
        status: "sent",
        sent_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
        last_error: null,
      }).eq("id", outcome.row.outbox_id);
    } else if (!hasTokens) {
      skipped += 1;
      await admin.from("push_outbox").update({
        status: "skipped",
        updated_at: new Date().toISOString(),
        last_error: "no registered device",
      }).eq("id", outcome.row.outbox_id);
    } else {
      failed += 1;
      await admin.from("push_outbox").update({
        status: "pending",
        available_at: new Date(Date.now() + RETRY_DELAY_MINUTES * 60_000).toISOString(),
        updated_at: new Date().toISOString(),
        last_error: outcome.error,
      }).eq("id", outcome.row.outbox_id);
    }
  }

  return json(
    {
      ok: true,
      claimed: rows.length,
      notifications_queued: work.length,
      sent,
      skipped,
      retrying: failed,
      tokens_removed: tokensRemoved,
      ran_at: new Date().toISOString(),
    },
    200,
    origin,
  );
});

function clampLimit(raw: string | null): number {
  const parsed = Number(raw ?? 50);
  if (!Number.isFinite(parsed)) return 50;
  return Math.max(1, Math.min(Math.trunc(parsed), 200));
}

async function requeue(
  admin: ReturnType<typeof createClient>,
  ids: string[],
  reason: string,
): Promise<void> {
  if (ids.length === 0) return;
  await admin.from("push_outbox").update({
    status: "pending",
    available_at: new Date(Date.now() + RETRY_DELAY_MINUTES * 60_000).toISOString(),
    updated_at: new Date().toISOString(),
    last_error: reason.slice(0, 500),
  }).in("id", ids);
}
