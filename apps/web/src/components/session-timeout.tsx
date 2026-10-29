"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { Clock } from "lucide-react";

import { Modal } from "@/components/dialog";
import { Button } from "@/components/ui";
import { getBrowserClient } from "@/lib/supabase/client";
import { isDemoMode } from "@/lib/env";

/**
 * Signs the user out after a period of inactivity.
 *
 * The time-out used to drop straight to /login with no warning, so anyone who
 * paused to read or think was silently discarded mid-task. It now raises a
 * countdown modal first, giving them the chance to stay signed in. Any activity
 * (including using the buttons) resets the idle clock.
 */
const TIMEOUT_MS = 5 * 60 * 1000; // total idle time before sign-out
const WARNING_MS = 30 * 1000; // how long before sign-out the warning appears
const ACTIVITY_EVENTS = ["keydown", "click", "scroll", "touchstart"] as const;

export function SessionTimeout() {
  const router = useRouter();
  const signOutTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const warningTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const countdownTimer = useRef<ReturnType<typeof setInterval> | null>(null);
  const [secondsLeft, setSecondsLeft] = useState<number | null>(null);

  const clearTimers = useCallback(() => {
    if (signOutTimer.current) clearTimeout(signOutTimer.current);
    if (warningTimer.current) clearTimeout(warningTimer.current);
    if (countdownTimer.current) clearInterval(countdownTimer.current);
    signOutTimer.current = null;
    warningTimer.current = null;
    countdownTimer.current = null;
  }, []);

  const signOut = useCallback(async () => {
    clearTimers();
    setSecondsLeft(null);

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
  }, [clearTimers, router]);

  // Schedules the warning and the sign-out without touching state, so it can run
  // from inside the effect without tripping the "setState in effect" rule.
  const schedule = useCallback(() => {
    clearTimers();

    // Show the warning first, then run the visible countdown down to sign-out.
    warningTimer.current = setTimeout(() => {
      setSecondsLeft(Math.ceil(WARNING_MS / 1000));
      countdownTimer.current = setInterval(() => {
        setSecondsLeft((previous) => (previous === null ? null : Math.max(previous - 1, 0)));
      }, 1000);
    }, TIMEOUT_MS - WARNING_MS);

    signOutTimer.current = setTimeout(() => {
      void signOut();
    }, TIMEOUT_MS);
  }, [clearTimers, signOut]);

  // Invoked by user activity: dismiss any visible warning and restart the clock.
  const resetIdle = useCallback(() => {
    setSecondsLeft(null);
    schedule();
  }, [schedule]);

  useEffect(() => {
    schedule();

    for (const event of ACTIVITY_EVENTS) {
      document.addEventListener(event, resetIdle);
    }

    return () => {
      clearTimers();
      for (const event of ACTIVITY_EVENTS) {
        document.removeEventListener(event, resetIdle);
      }
    };
  }, [clearTimers, resetIdle, schedule]);

  const remaining = secondsLeft ?? 0;

  return (
    <Modal
      open={secondsLeft !== null}
      title="Are you still there?"
      description="For your security, the SBTF System signs you out automatically when you are inactive."
      onClose={resetIdle}
      width="sm"
      footer={
        <>
          <Button variant="outline" onClick={() => void signOut()}>
            Sign out now
          </Button>
          <Button onClick={resetIdle}>Stay signed in</Button>
        </>
      }
    >
      <div className="flex items-center gap-3">
        <span className="rounded-md bg-warning-50 p-2 text-warning-600">
          <Clock className="h-4 w-4" />
        </span>
        <p className="text-[0.875rem] text-ink">
          You have been inactive for a while. You will be signed out in{" "}
          <span className="font-semibold tabular-nums text-ink">
            {remaining} second{remaining === 1 ? "" : "s"}
          </span>
          .
        </p>
      </div>
    </Modal>
  );
}
