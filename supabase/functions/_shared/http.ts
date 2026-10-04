// Shared HTTP helpers for the SBTF Edge Functions.
//
// CORS is deliberately restricted to the configured web origin(s). Secrets
// (GROQ_API_KEY, SUPABASE_SERVICE_ROLE_KEY) only ever exist inside the Edge
// Function runtime — never in the browser or the mobile application.

export const ADVISORY_NOTICE = "Advisory — For Decision Support Only";

export function allowedOrigins(): string[] {
  const configured = Deno.env.get("ALLOWED_WEB_ORIGINS") ?? "";
  const fallback = [
    "http://localhost:3000",
    "http://127.0.0.1:3000",
  ];
  const list = configured
    .split(",")
    .map((origin) => origin.trim())
    .filter(Boolean);

  return [...new Set([...list, ...fallback, ...wildcardOrigins(list)])];
}

/**
 * Vercel preview deployments use generated host names. When an origin is
 * configured as `https://*.vercel.app`, allow any matching subdomain instead
 * of hard-coding every preview URL.
 */
function wildcardOrigins(origins: string[]): string[] {
  const wildcards = origins.filter((origin) => origin.includes("*"));
  if (wildcards.length === 0) return [];
  return wildcards;
}

export function corsHeaders(origin: string | null): Record<string, string> {
  const allowed = allowedOrigins();
  const wildcards = allowed.filter((entry) => entry.includes("*"));

  const isAllowed =
    origin !== null &&
    (allowed.includes(origin) ||
      wildcards.some((pattern) => matchWildcard(pattern, origin)));

  return {
    "Access-Control-Allow-Origin": isAllowed ? origin : allowed[0] ?? "http://localhost:3000",
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type, x-sbtf-cron-secret",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Max-Age": "86400",
    Vary: "Origin",
  };
}

function matchWildcard(pattern: string, origin: string): boolean {
  const [scheme, hostPattern] = pattern.split("://");
  if (!hostPattern || !origin.startsWith(`${scheme}://`)) return false;
  const host = origin.slice(scheme.length + 3);
  const suffix = hostPattern.replace(/^\*/, "");
  return host.endsWith(suffix);
}

export function json(
  body: unknown,
  status: number,
  origin: string | null,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store",
      ...corsHeaders(origin),
    },
  });
}

export function errorResponse(
  code: string,
  message: string,
  status: number,
  origin: string | null,
  extra: Record<string, unknown> = {},
): Response {
  return json({ error: code, message, ...extra }, status, origin);
}

export async function sha256Hex(value: string): Promise<string> {
  const data = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest("SHA-256", data);
  return [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}
