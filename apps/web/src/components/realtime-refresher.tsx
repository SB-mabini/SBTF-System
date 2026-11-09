"use client";

import { useEffect, useRef } from "react";
import { useRouter } from "next/navigation";

import { getBrowserClient } from "@/lib/supabase/client";
import { isDemoMode } from "@/lib/env";

/**
 * Keeps the current console in sync with Supabase Realtime.
 *
 * Subscriptions rely on RLS: a staff or administrator session only receives the
 * rows its policies expose. Updates are coalesced so a burst of changes results
 * in a single server render.
 */
export function RealtimeRefresher() {
  const router = useRouter();
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    if (isDemoMode()) return;

    const supabase = getBrowserClient();
    const schedule = () => {
      if (timer.current) clearTimeout(timer.current);
      timer.current = setTimeout(() => {
        router.refresh();
      }, 600);
    };

    const channel = supabase
      .channel("sbtf-console")
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "franchise_applications" },
        schedule,
      )
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "franchise_documents" },
        schedule,
      )
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "franchise_records" },
        schedule,
      )
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "application_appointments" },
        schedule,
      )
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "form_requests" },
        schedule,
      )
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "document_releases" },
        schedule,
      )
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "notifications" },
        schedule,
      )
      .subscribe();

    return () => {
      if (timer.current) clearTimeout(timer.current);
      void supabase.removeChannel(channel);
    };
  }, [router]);

  // The connection now refreshes the console silently; the old bottom-right
  // "Live" pill overlapped the action buttons, so it is no longer rendered.
  return null;
}
