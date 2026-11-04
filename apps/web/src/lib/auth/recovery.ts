import { cookies } from "next/headers";

/**
 * The address waiting for a verification code.
 *
 * Self-service recovery sends a 6-digit code by e-mail. The address is kept in
 * an httpOnly cookie rather than the URL so it does not end up in browser
 * history, a shared screen or a referrer header.
 *
 * Lifetime matches the code itself (`mailer_otp_exp`, 10 minutes). The cookie is
 * only an identifier for the pending request: it grants nothing on its own, and
 * the code is still checked by GoTrue against the account that requested it.
 */
export const RECOVERY_EMAIL_COOKIE = "sbtf-recovery-email";

export const RECOVERY_EMAIL_MAX_AGE = 600;

export async function readRecoveryEmail(): Promise<string | null> {
  const value = (await cookies()).get(RECOVERY_EMAIL_COOKIE)?.value;
  if (!value) return null;

  // base64url keeps the cookie to a cookie-safe alphabet and avoids relying on
  // whether the framework already percent-decoded the value.
  const email = Buffer.from(value, "base64url").toString("utf8");
  return email.includes("@") ? email : null;
}

export async function saveRecoveryEmail(email: string): Promise<void> {
  (await cookies()).set(
    RECOVERY_EMAIL_COOKIE,
    Buffer.from(email, "utf8").toString("base64url"),
    {
      httpOnly: true,
      sameSite: "lax",
      secure: process.env.NODE_ENV === "production",
      path: "/",
      maxAge: RECOVERY_EMAIL_MAX_AGE,
    },
  );
}

export async function clearRecoveryEmail(): Promise<void> {
  (await cookies()).delete(RECOVERY_EMAIL_COOKIE);
}
