import type { SupabaseClient } from "@supabase/supabase-js";

export type WebAccess =
  | { ok: true; role: "administrator" | "staff" }
  | { ok: false; message: string };

/**
 * Decides whether an authenticated account may use the web console.
 *
 * Sign-in and e-mail-code recovery both end with a Supabase session, and a
 * session alone is not enough: the profile decides the role, whether the account
 * was approved, and whether the account belongs on the web at all. Reading it
 * through the caller's own session keeps RLS as the authority — no service-role
 * key is involved.
 *
 * The messages are deliberately the same ones the sign-in screen has always
 * shown, so both entry points explain a blocked account identically.
 */
export async function resolveWebAccess(
  supabase: SupabaseClient,
  userId: string,
): Promise<WebAccess> {
  const { data: profile } = await supabase
    .from("profiles")
    .select("role, account_status")
    .eq("auth_user_id", userId)
    .maybeSingle();

  if (!profile) {
    return {
      ok: false,
      message: "No profile is linked to this account. Contact the municipal office.",
    };
  }

  if (profile.account_status !== "active") {
    return {
      ok: false,
      message:
        profile.account_status === "pending"
          ? "This account is awaiting approval by a municipal administrator. You will be able to sign in once it has been approved."
          : "This account is not active. Contact the administrator of the SBTF System at the municipal office.",
    };
  }

  if (profile.role !== "administrator" && profile.role !== "staff") {
    return {
      ok: false,
      message:
        "Tricycle drivers and operators use the SBTF mobile application. The web console is for municipal staff and administrators only.",
    };
  }

  return { ok: true, role: profile.role };
}
