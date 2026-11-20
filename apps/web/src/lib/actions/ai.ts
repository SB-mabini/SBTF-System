"use server";

import { createClient } from "@/lib/supabase/server";
import { getSessionProfile } from "@/lib/data";
import { isDemoMode } from "@/lib/env";
import type { AiAdvisory } from "@/types/database";

const GROQ_ENDPOINT = "https://api.groq.com/openai/v1/chat/completions";
const DEFAULT_MODEL = "openai/gpt-oss-120b";
const FALLBACK_MODEL = "llama-3.3-70b-versatile";
const MAX_COMPLETION_TOKENS = 4000;
const ADVISORY_NOTICE = "Advisory — For Decision Support Only";
const BRIEFING_TTL_MS = 24 * 60 * 60 * 1000;

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

export async function generateAiBriefingAction(
  months: number,
): Promise<{ ok: true; advisory: AiAdvisory } | { ok: false; message: string }> {
  if (isDemoMode()) {
    return {
      ok: false,
      message: "Preview mode: AI briefing generation is simulated with sample data.",
    };
  }

  const groqApiKey = (process.env.GROQ_API_KEY ?? "").trim();
  if (!groqApiKey) {
    return {
      ok: false,
      message:
        "GROQ_API_KEY is not configured. Please add GROQ_API_KEY=gsk_... to apps/web/.env.local (or set it in your environment).",
    };
  }

  const session = await getSessionProfile();
  if (!session || !session.profile) {
    return { ok: false, message: "A valid session is required." };
  }

  if (session.profile.account_status !== "active") {
    return { ok: false, message: "This account is not active." };
  }

  if (session.role !== "administrator" && session.role !== "staff") {
    return {
      ok: false,
      message: "AI decision support is limited to the franchising office.",
    };
  }

  const supabase = await createClient();

  // Settings check
  const { data: settings } = await supabase
    .from("system_settings")
    .select("key, value")
    .in("key", ["ai_enabled", "ai_model", "ai_max_requests_per_user_per_day"]);

  const settingValue = (key: string): unknown =>
    settings?.find((row) => row.key === key)?.value ?? null;

  if (settingValue("ai_enabled") === false) {
    return {
      ok: false,
      message: "AI decision support is currently disabled by the administrator.",
    };
  }

  const boundedMonths = Math.min(Math.max(Number(months ?? 12), 3), 24);

  const { data: context, error: contextError } = await supabase.rpc(
    "rpc_analytics_ai_context",
    { p_months: boundedMonths },
  );

  if (contextError || !context) {
    console.error("AI context RPC failed", contextError);
    return {
      ok: false,
      message: "Aggregated statistics could not be prepared.",
    };
  }

  const requestedModel = String(settingValue("ai_model") ?? DEFAULT_MODEL);
  const contextJson = JSON.stringify(context, null, 2);
  const userPrompt = `Aggregated franchising statistics for the Municipality of Mabini, Batangas.

Period analysed: last ${boundedMonths} months.
Statistics (JSON):
${contextJson}

Provide the advisory briefing as specified.`;

  async function callGroq(modelName: string): Promise<Response> {
    return fetch(GROQ_ENDPOINT, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${groqApiKey}`,
      },
      body: JSON.stringify({
        model: modelName,
        temperature: 0.2,
        max_tokens: MAX_COMPLETION_TOKENS,
        response_format: { type: "json_object" },
        messages: [
          { role: "system", content: SYSTEM_PROMPT },
          { role: "user", content: userPrompt },
        ],
      }),
    });
  }

  let usedModel = requestedModel;
  let groqResponse: Response;
  try {
    groqResponse = await callGroq(usedModel);
    if (!groqResponse.ok && usedModel !== FALLBACK_MODEL) {
      console.warn(`Groq request with ${usedModel} failed (${groqResponse.status}), trying ${FALLBACK_MODEL}...`);
      const fallbackResponse = await callGroq(FALLBACK_MODEL);
      if (fallbackResponse.ok) {
        groqResponse = fallbackResponse;
        usedModel = FALLBACK_MODEL;
      }
    }
  } catch (err) {
    console.error("Groq request failed", err);
    return {
      ok: false,
      message: "The Groq AI service could not be reached. Check your network connection.",
    };
  }

  if (!groqResponse.ok) {
    const errorText = await groqResponse.text();
    console.error("Groq API error", groqResponse.status, errorText);
    return {
      ok: false,
      message: `Groq AI returned an error (HTTP ${groqResponse.status}): ${errorText.slice(0, 200)}`,
    };
  }

  const completion = await groqResponse.json();
  const rawContent: string = completion?.choices?.[0]?.message?.content ?? "";

  let advisory: {
    descriptive_summary?: string;
    key_findings?: string[];
    recommendations?: Array<{
      title?: string;
      detail?: string;
      reason?: string;
      data_basis?: string;
      priority?: string;
    }>;
    limitations?: string[];
  };

  try {
    advisory = JSON.parse(rawContent);
  } catch {
    advisory = {
      descriptive_summary: rawContent.slice(0, 4000) || "The AI service returned an empty response.",
      key_findings: [],
      recommendations: [],
      limitations: ["The model response could not be parsed as structured output; the raw text is shown instead."],
    };
  }

  const generatedAt = new Date();
  const expiresAt = new Date(generatedAt.getTime() + BRIEFING_TTL_MS);

  const responseBody: AiAdvisory = {
    advisory_notice: ADVISORY_NOTICE,
    notice_detail:
      "This output is generated from aggregated statistics and is provided for decision support only. It cannot approve, reject or modify any application, franchise record or account.",
    generated_at: generatedAt.toISOString(),
    expires_at: expiresAt.toISOString(),
    model: usedModel,
    period_months: boundedMonths,
    data_as_of: (context as { generated_at?: string })?.generated_at ?? null,
    descriptive_summary: advisory.descriptive_summary ?? "",
    key_findings: Array.isArray(advisory.key_findings) ? advisory.key_findings.slice(0, 12) : [],
    recommendations: Array.isArray(advisory.recommendations)
      ? advisory.recommendations.slice(0, 8).map((item) => ({
          title: String(item?.title ?? "Recommendation"),
          detail: String(item?.detail ?? ""),
          reason: String(item?.reason ?? ""),
          data_basis: String(item?.data_basis ?? ""),
          priority: (["high", "medium", "low"].includes(item?.priority as string)
            ? item?.priority
            : "medium") as "high" | "medium" | "low",
        }))
      : [],
    limitations: Array.isArray(advisory.limitations) ? advisory.limitations.slice(0, 8) : [],
    data_basis: summarizeContext(context as Record<string, unknown>),
  };

  return { ok: true, advisory: responseBody };
}
