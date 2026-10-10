"use client";

import { useEffect, useRef } from "react";
import { useRouter } from "next/navigation";
import { getBrowserClient } from "@/lib/supabase/client";
import { isDemoMode } from "@/lib/env";

const TIMEOUT_MS = 5 * 60 * 1000; // 5 minutes

export function SessionTimeout() {
  const router = useRouter();
  const timeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    async function logout() {
      if (!isDemoMode()) {
        const supabase = getBrowserClient();
        const { data } = await supabase.auth.getUser();
        if (data.user) {
          await supabase.rpc("rpc_log_activity", { p_action: "logout" });
        }
        await supabase.auth.signOut();
      }
      router.push("/login");
      router.refresh();
    }

    function resetTimeout() {
      if (timeoutRef.current) {
        clearTimeout(timeoutRef.current);
      }
      timeoutRef.current = setTimeout(logout, TIMEOUT_MS);
    }

    resetTimeout();

    const events = ["mousemove", "keydown", "click", "scroll", "touchstart"];
    for (const event of events) {
      document.addEventListener(event, resetTimeout);
    }

    return () => {
      if (timeoutRef.current) {
        clearTimeout(timeoutRef.current);
      }
      for (const event of events) {
        document.removeEventListener(event, resetTimeout);
      }
    };
  }, [router]);

  return null;
}
