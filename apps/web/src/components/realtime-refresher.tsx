"use client";

import { useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { Wifi } from "lucide-react";

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
  const [live, setLive] = useState(false);
  const [pulse, setPulse] = useState(false);
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    if (isDemoMode()) return;

    const supabase = getBrowserClient();
    const schedule = () => {
      if (timer.current) clearTimeout(timer.current);
      timer.current = setTimeout(() => {
        router.refresh();
        setPulse(true);
        setTimeout(() => setPulse(false), 1200);
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
        { event: "*", schema: "public", table: "notifications" },
        schedule,
      )
      .subscribe((status) => setLive(status === "SUBSCRIBED"));

    return () => {
      if (timer.current) clearTimeout(timer.current);
      void supabase.removeChannel(channel);
    };
  }, [router]);

  if (isDemoMode()) return null;

  return (
    <div
      className="pointer-events-none fixed bottom-4 right-4 z-30"
      aria-live="polite"
      title={live ? "Live updates active" : "Connecting to live updates"}
    >
      <span
        className={`inline-flex items-center gap-1.5 rounded-full border px-2.5 py-1 text-[0.6875rem] font-medium shadow-card transition-colors ${
          pulse
            ? "border-primary-200 bg-primary-50 text-primary-700"
            : "border-line bg-white text-muted"
        }`}
      >
        <Wifi className={`h-3 w-3 ${live ? "text-primary" : "text-line-strong"}`} />
        {live ? (pulse ? "Updated" : "Live") : "Connecting…"}
      </span>
    </div>
  );
}
