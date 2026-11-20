/**
 * Google reCAPTCHA v2 ("I'm not a robot") verification for the sign-in form.
 *
 * The checkbox runs in the browser and submits a single-use token with the
 * sign-in request. Only this module's `verifyCaptchaToken` can confirm that
 * token, using the secret key that never leaves the server.
 */

const SITEVERIFY_URL = "https://www.google.com/recaptcha/api/siteverify";
const VERIFY_TIMEOUT_MS = 8_000;

export type CaptchaMode = "disabled" | "configured" | "misconfigured";

/**
 * Describes the deployment's reCAPTCHA setup.
 *
 * - `disabled`: neither key is set. Local development may still sign in; a
 *   production build refuses (see `signInAction`) rather than silently
 *   shipping without the protection it claims to have.
 * - `configured`: both keys are set and every sign-in must present a token.
 * - `misconfigured`: exactly one key is set. This is always an error, because
 *   either the widget cannot render or the token cannot be verified.
 */
export function captchaMode(): CaptchaMode {
  const siteKey = (process.env.NEXT_PUBLIC_RECAPTCHA_SITE_KEY ?? "").trim();
  const secretKey = (process.env.RECAPTCHA_SECRET_KEY ?? "").trim();

  if (!siteKey && !secretKey) return "disabled";
  if (siteKey && secretKey) return "configured";
  return "misconfigured";
}

export interface CaptchaVerification {
  /** True only when Google accepted the token. */
  ok: boolean;
  /** True when the deployment has no secret key to verify against. */
  unconfigured: boolean;
}

/**
 * Verifies a reCAPTCHA token against Google's siteverify endpoint.
 *
 * Tokens are single use and expire after about two minutes, so a failed
 * sign-in always needs a fresh checkbox tick. A network failure is treated as
 * a failed verification: the caller can retry, and no token is silently
 * trusted.
 */
export async function verifyCaptchaToken(
  token: string | null | undefined,
  remoteIp?: string,
): Promise<CaptchaVerification> {
  const secretKey = (process.env.RECAPTCHA_SECRET_KEY ?? "").trim();
  if (!secretKey) return { ok: false, unconfigured: true };
  if (!token?.trim()) return { ok: false, unconfigured: false };

  const body = new URLSearchParams({
    secret: secretKey,
    response: token.trim(),
  });
  if (remoteIp && remoteIp !== "unknown") body.set("remoteip", remoteIp);

  try {
    const response = await fetch(SITEVERIFY_URL, {
      method: "POST",
      body,
      headers: { "content-type": "application/x-www-form-urlencoded" },
      cache: "no-store",
      signal: AbortSignal.timeout(VERIFY_TIMEOUT_MS),
    });

    if (!response.ok) return { ok: false, unconfigured: false };

    const result = (await response.json()) as { success?: boolean };
    return { ok: result.success === true, unconfigured: false };
  } catch {
    return { ok: false, unconfigured: false };
  }
}
