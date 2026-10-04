import { cookies } from "next/headers";
import { createServerClient } from "@supabase/ssr";
import type { SupabaseClient } from "@supabase/supabase-js";

import { SUPABASE_ANON_KEY, SUPABASE_URL, isDemoMode } from "@/lib/env";

/**
 * Server-side Supabase client.
 *
 * Uses the signed-in user's session (cookies) — the anon key plus RLS is the
 * only authority. The service-role key is deliberately NOT available to the web
 * application; privileged operations go through Edge Functions.
 */
export async function createClient(): Promise<SupabaseClient> {
  if (isDemoMode()) {
    throw new Error(
      "createClient() must not be called in preview mode: use the data layer in src/lib/data.",
    );
  }

  const cookieStore = await cookies();

  return createServerClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    cookies: {
      getAll() {
        return cookieStore.getAll();
      },
      setAll(cookiesToSet) {
        try {
          cookiesToSet.forEach(({ name, value, options }) => {
            cookieStore.set(name, value, options);
          });
        } catch {
          // Called from a Server Component: cookie writes are performed by the
          // middleware session refresh instead.
        }
      },
    },
    auth: {
      persistSession: true,
      autoRefreshToken: false,
      detectSessionInUrl: false,
    },
  });
}
