"use client";

import { useEffect, useRef, useState } from "react";

/**
 * Google reCAPTCHA v2 "I'm not a robot" checkbox for the sign-in form.
 *
 * The widget is rendered explicitly so that only one script is ever injected
 * and the token can be handed straight to the server action. Tokens are single
 * use, so the parent passes a new `resetKey` after every attempt to clear the
 * checkbox for the next try.
 */

type ReCaptchaOptions = {
  sitekey: string;
  theme?: "light" | "dark";
  size?: "normal" | "compact";
  callback: (token: string) => void;
  "expired-callback"?: () => void;
  "error-callback"?: () => void;
};

type ReCaptchaApi = {
  ready: (callback: () => void) => void;
  render: (container: HTMLElement, options: ReCaptchaOptions) => number;
  reset: (widgetId?: number) => void;
};

declare global {
  interface Window {
    grecaptcha?: ReCaptchaApi;
  }
}

const SCRIPT_ID = "sbtf-recaptcha-script";
const SCRIPT_SRC = "https://www.google.com/recaptcha/api.js?render=explicit";
const LOAD_TIMEOUT_MS = 15_000;

let scriptPromise: Promise<void> | null = null;

/** Loads the reCAPTCHA script once per page and resolves when it is ready. */
function loadReCaptcha(): Promise<void> {
  if (typeof window === "undefined") return Promise.resolve();
  if (window.grecaptcha) return Promise.resolve();
  if (scriptPromise) return scriptPromise;

  scriptPromise = new Promise<void>((resolve, reject) => {
    const existing = document.getElementById(SCRIPT_ID) as HTMLScriptElement | null;

    if (existing?.dataset.sbtfLoaded === "true") {
      // The script finished before this component mounted but the reCAPTCHA
      // API is missing, so retrying the same element cannot help.
      scriptPromise = null;
      reject(new Error("The security check could not be loaded."));
      return;
    }

    const script = existing ?? document.createElement("script");
    const timer = window.setTimeout(() => {
      failed();
    }, LOAD_TIMEOUT_MS);

    const ready = () => {
      window.clearTimeout(timer);
      script.dataset.sbtfLoaded = "true";
      resolve();
    };
    const failed = () => {
      window.clearTimeout(timer);
      script.remove();
      scriptPromise = null;
      reject(new Error("The security check could not be loaded."));
    };

    script.addEventListener("load", ready, { once: true });
    script.addEventListener("error", failed, { once: true });

    if (!existing) {
      script.id = SCRIPT_ID;
      script.src = SCRIPT_SRC;
      script.async = true;
      script.defer = true;
      document.head.appendChild(script);
    }
  });

  return scriptPromise;
}

export function ReCaptcha({
  siteKey,
  resetKey,
  onVerify,
  onExpire,
}: {
  siteKey: string;
  /** Change this value to clear the checkbox after a sign-in attempt. */
  resetKey: number;
  onVerify: (token: string) => void;
  onExpire?: () => void;
}) {
  const containerRef = useRef<HTMLDivElement>(null);
  const widgetIdRef = useRef<number | null>(null);
  const verifyRef = useRef(onVerify);
  const expireRef = useRef(onExpire);
  const [failed, setFailed] = useState(false);

  useEffect(() => {
    verifyRef.current = onVerify;
  }, [onVerify]);

  useEffect(() => {
    expireRef.current = onExpire;
  }, [onExpire]);

  useEffect(() => {
    if (!siteKey) return;

    let cancelled = false;
    const container = containerRef.current;
    if (!container) return;

    setFailed(false);

    loadReCaptcha()
      .then(() => {
        if (cancelled || !window.grecaptcha || !containerRef.current) return;

        window.grecaptcha.ready(() => {
          if (cancelled || !window.grecaptcha || !containerRef.current) return;

          widgetIdRef.current = window.grecaptcha.render(containerRef.current, {
            sitekey: siteKey,
            theme: "light",
            size: "normal",
            callback: (token) => verifyRef.current(token),
            "expired-callback": () => expireRef.current?.(),
            "error-callback": () => {
              setFailed(true);
              expireRef.current?.();
            },
          });
        });
      })
      .catch(() => {
        if (!cancelled) setFailed(true);
      });

    return () => {
      cancelled = true;
      widgetIdRef.current = null;
    };
  }, [siteKey]);

  useEffect(() => {
    if (resetKey > 0 && widgetIdRef.current !== null && window.grecaptcha) {
      window.grecaptcha.reset(widgetIdRef.current);
    }
  }, [resetKey]);

  if (!siteKey) return null;

  return (
    <div>
      <p className="mb-2 text-[0.8125rem] font-medium text-ink">Security check</p>
      <div ref={containerRef} />
      {failed ? (
        <p className="mt-1 text-[0.75rem] text-red-700">
          The security check could not load. Disable any ad blocker for this page and try again.
        </p>
      ) : null}
    </div>
  );
}
