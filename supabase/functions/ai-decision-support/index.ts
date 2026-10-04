// ===========================================================================
// Edge Function: ai-decision-support
//
// Produces an advisory briefing for administrators and staff from AGGREGATED,
// ANONYMISED franchising statistics. This is the only component in the system
// that talks to the Groq API, and it runs server-side so the API key never
// reaches the browser or the mobile application.
//
// Guarantees implemented here:
//   * caller must be an authenticated, active administrator or staff member;
//   * only aggregated counters/rates are sent to the model — the context comes
//     from public.rpc_analytics_ai_context(), which contains no personal data;
//   * the model is instructed to never approve, reject or modify anything, and
//     the response is labelled "Advisory — For Decision Support Only";
//   * every call is logged in ai_request_logs with SHA-256 hashes only;
//   * per-user daily rate limit and an enable/disable switch from settings.
// ===========================================================================

import { createClient } from "npm:@supabase/supabase-js@2";
import {
  ADVISORY_NOTICE,
  corsHeaders,
  errorResponse,
  json,
  sha256Hex,
} from "../_shared/http.ts";

const GROQ_ENDPOINT = "https://api.groq.com/openai/v1/chat/completions";
const DEFAULT_MODEL = "llama-3.3-70b-versatile";

const SYSTEM_PROMPT = `You are the decision-support analyst for the tricycle franchising office of the Municipality of Mabini, Batangas.

You receive aggregated, anonymised statistics about franchise applications. You must:
1. Summarise descriptively what the numbers show (trends, approval/rejection rates, processing times, expirations, TODA distribution).
2. Give prescriptive, operational recommendations for the franchising office: staffing during high-volume periods, renewal reminder prioritisation, document-verification bottlenecks, unusual approval or rejection movements, outreach to TODAs with no filings.
3. For every recommendation state the reason, the data basis (which statistic it comes from) and its limitation.

Hard rules:
- You NEVER approve, reject, modify or delete an application, franchise record or account. You NEVER make the final administrative decision. You are advisory only.
- You never ask for or infer personal data; you have none. Do not invent names, plate numbers or identifiers.
- If the data is insufficient for a conclusion, say so explicitly instead of guessing.
- Do not reference any individual applicant, operator or vehicle.

Respond with a single JSON object using exactly this shape:
{
  "descriptive_summary": string,
  "key_findings": string[],
  "recommendations": [{ "title": string, "detail": string, "reason": string, "data_basis": string, "priority": "high" | "medium" | "low" }],
  "limitations": string[]
}`;

type Advisory = {
  descriptive_summary: string;
  key_findings: string[];
  recommendations: Array<{
    title: string;
    detail: string;
    reason: string;
    data_basis: string;
    priority: "high" | "medium" | "low";
  }>;
  limitations: string[];
};

Deno.serve(async (request: Request) => {
  const origin = request.headers.get("origin");

  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders(origin) });
  }
  if (request.method !== "POST") {
    return errorResponse("method_not_allowed", "Use POST.", 405, origin);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const groqApiKey = Deno.env.get("GROQ_API_KEY");

  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    return errorResponse("misconfigured", "Supabase environment variables are missing.", 500, origin);
  }
  if (!groqApiKey) {
    return errorResponse("ai_not_configured", "GROQ_API_KEY is not configured for this project.", 503, origin);
  }

  const authHeader = request.headers.get("Authorization") ?? "";
  if (!authHeader.startsWith("Bearer ")) {
    return errorResponse("unauthorised", "A bearer token is required.", 401, origin);
  }

  // --- Identify the caller with their own JWT (never the service role) -------
  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false },
  });

  const { data: userData, error: userError } = await userClient.auth.getUser();
  if (userError || !userData?.user) {
    return errorResponse("unauthorised", "The session is not valid.", 401, origin);
  }

  // The caller's profile and role are resolved through RLS with their own token.
  const { data: profile, error: profileError } = await userClient
    .from("profiles")
    .select("id, role, account_status, full_name")
    .eq("auth_user_id", userData.user.id)
    .maybeSingle();

  if (profileError || !profile) {
    return errorResponse("unauthorised", "No profile is associated with this account.", 403, origin);
  }
  if (profile.account_status !== "active") {
    return errorResponse("account_inactive", "This account is not active.", 403, origin);
  }
  if (profile.role !== "administrator" && profile.role !== "staff") {
    return errorResponse("forbidden", "AI decision support is limited to the franchising office.", 403, origin);
  }

  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false },
  });

  // --- Settings-driven enable switch and rate limit -------------------------
  const { data: settings } = await adminClient
    .from("system_settings")
    .select("key, value")
    .in("key", ["ai_enabled", "ai_model", "ai_max_requests_per_user_per_day"]);

  const settingValue = (key: string): unknown =>
    settings?.find((row) => row.key === key)?.value ?? null;

  if (settingValue("ai_enabled") === false) {
    return errorResponse("ai_disabled", "AI decision support is currently disabled by the administrator.", 503, origin);
  }

  const dailyLimit = Number(settingValue("ai_max_requests_per_user_per_day") ?? 20);
  const { count: usedToday } = await adminClient
    .from("ai_request_logs")
    .select("id", { count: "exact", head: true })
    .eq("requester_id", profile.id)
    .gte("created_at", new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString());

  if (typeof usedToday === "number" && usedToday >= dailyLimit) {
    await adminClient.from("ai_request_logs").insert({
      requester_id: profile.id,
      requested_by_role: profile.role,
      model: String(settingValue("ai_model") ?? DEFAULT_MODEL),
      prompt_hash: await sha256Hex(SYSTEM_PROMPT),
      context_hash: await sha256Hex("rate-limited"),
      status: "rejected",
      error_code: "rate_limit_exceeded",
    });
    return errorResponse(
      "rate_limit_exceeded",
      `The daily AI advisory limit of ${dailyLimit} requests has been reached.`,
      429,
      origin,
    );
  }

  // --- Aggregated, anonymised context ---------------------------------------
  const body = await request.json().catch(() => ({}));
  const months = Math.min(Math.max(Number(body?.months ?? 12), 3), 24);

  const { data: context, error: contextError } = await adminClient.rpc(
    "rpc_analytics_ai_context",
    { p_months: months },
  );

  if (contextError || !context) {
    return errorResponse("context_unavailable", "Aggregated statistics could not be prepared.", 500, origin);
  }

  const model = String(settingValue("ai_model") ?? DEFAULT_MODEL);
  const contextJson = JSON.stringify(context, null, 2);
  const userPrompt = `Aggregated franchising statistics for the Municipality of Mabini, Batangas.

Period analysed: last ${months} months.
Statistics (JSON):
${contextJson}

Provide the advisory briefing as specified.`;

  const startedAt = Date.now();
  let groqResponse: Response;
  try {
    groqResponse = await fetch(GROQ_ENDPOINT, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${groqApiKey}`,
      },
      body: JSON.stringify({
        model,
        temperature: 0.2,
        max_tokens: 1600,
        response_format: { type: "json_object" },
        messages: [
          { role: "system", content: SYSTEM_PROMPT },
          { role: "user", content: userPrompt },
        ],
      }),
    });
  } catch (error) {
    await adminClient.from("ai_request_logs").insert({
      requester_id: profile.id,
      requested_by_role: profile.role,
      model,
      prompt_hash: await sha256Hex(userPrompt),
      context_hash: await sha256Hex(contextJson),
      context_summary: summarizeContext(context),
      status: "error",
      error_code: "groq_unreachable",
      latency_ms: Date.now() - startedAt,
    });
    console.error("Groq request failed", error);
    return errorResponse("ai_unavailable", "The AI service could not be reached.", 502, origin);
  }

  const latencyMs = Date.now() - startedAt;

  if (!groqResponse.ok) {
    const detail = await groqResponse.text();
    await adminClient.from("ai_request_logs").insert({
      requester_id: profile.id,
      requested_by_role: profile.role,
      model,
      prompt_hash: await sha256Hex(userPrompt),
      context_hash: await sha256Hex(contextJson),
      context_summary: summarizeContext(context),
      status: "error",
      error_code: `groq_${groqResponse.status}`,
      latency_ms: latencyMs,
    });
    console.error("Groq error", groqResponse.status, detail.slice(0, 500));
    return errorResponse("ai_unavailable", "The AI service returned an error.", 502, origin);
  }

  const completion = await groqResponse.json();
  const rawContent: string = completion?.choices?.[0]?.message?.content ?? "";
  const usage = completion?.usage ?? {};

  let advisory: Advisory;
  try {
    advisory = JSON.parse(rawContent);
  } catch {
    // The model is instructed to return JSON; fall back to a readable shape
    // rather than failing the whole request.
    advisory = {
      descriptive_summary: rawContent.slice(0, 4000) || "The AI service returned an empty response.",
      key_findings: [],
      recommendations: [],
      limitations: [
        "The model response could not be parsed as structured output; the raw text is shown instead.",
      ],
    };
  }

  await adminClient.from("ai_request_logs").insert({
    requester_id: profile.id,
    requested_by_role: profile.role,
    model,
    // Only hashes are stored: no prompt text, no personal data.
    prompt_hash: await sha256Hex(userPrompt),
    context_hash: await sha256Hex(contextJson),
    context_summary: summarizeContext(context),
    status: "success",
    latency_ms: latencyMs,
    prompt_tokens: usage.prompt_tokens ?? null,
    output_tokens: usage.completion_tokens ?? null,
  });

  return json(
    {
      advisory_notice: ADVISORY_NOTICE,
      notice_detail:
        "This output is generated from aggregated statistics and is provided for decision support only. It cannot approve, reject or modify any application, franchise record or account.",
      generated_at: new Date().toISOString(),
      model,
      period_months: months,
      data_as_of: context?.generated_at ?? null,
      descriptive_summary: advisory.descriptive_summary ?? "",
      key_findings: Array.isArray(advisory.key_findings) ? advisory.key_findings.slice(0, 12) : [],
      recommendations: Array.isArray(advisory.recommendations)
        ? advisory.recommendations.slice(0, 8).map((item) => ({
            title: String(item?.title ?? "Recommendation"),
            detail: String(item?.detail ?? ""),
            reason: String(item?.reason ?? ""),
            data_basis: String(item?.data_basis ?? ""),
            priority: ["high", "medium", "low"].includes(item?.priority as string)
              ? item.priority
              : "medium",
          }))
        : [],
      limitations: Array.isArray(advisory.limitations) ? advisory.limitations.slice(0, 8) : [],
      data_basis: summarizeContext(context),
    },
    200,
    origin,
  );
});

/**
 * Compact, non-identifying description of the aggregate context that was sent,
 * stored with the audit row so a reviewer can see the basis of the advisory.
 */
function summarizeContext(context: Record<string, unknown> | null): Record<string, unknown> {
  if (!context) return {};
  const totals = (context.totals ?? {}) as Record<string, unknown>;
  const expirations = (context.expirations ?? {}) as Record<string, unknown>;

  return {
    applications_total: totals.applications_total ?? null,
    applications_pending: totals.applications_pending ?? null,
    active_franchises: totals.active_franchises ?? null,
    accredited_todas: totals.accredited_todas ?? null,
    expiring_within_30_days: expirations.within_30_days ?? null,
    contains_personal_data: false,
  };
}
