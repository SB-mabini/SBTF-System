"use client";

import { createBrowserClient } from "@supabase/ssr";
import type { SupabaseClient } from "@supabase/supabase-js";

import { SUPABASE_ANON_KEY, SUPABASE_URL } from "@/lib/env";

let browserClient: SupabaseClient | null = null;

/**
 * Browser Supabase client used for Realtime subscriptions and Storage uploads.
 * Authorisation is still enforced by RLS for every request it makes.
 */
export function getBrowserClient(): SupabaseClient {
  if (!browserClient) {
    browserClient = createBrowserClient(SUPABASE_URL, SUPABASE_ANON_KEY);
  }
  return browserClient;
}
