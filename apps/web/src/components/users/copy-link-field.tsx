"use client";

import { useRef, useState } from "react";
import { Check, Copy } from "lucide-react";

/**
 * A read-only single-line field for a one-time link, with a copy button.
 *
 * `navigator.clipboard` is unavailable outside a secure context (plain HTTP on a
 * LAN address, for example), so the copy attempt is wrapped and, when it fails,
 * the text is selected instead — the administrator can always copy by hand. The
 * field is never disabled, precisely so that fallback keeps working.
 */
export function CopyLinkField({
  label,
  value,
  hint,
}: {
  label: string;
  value: string;
  hint?: string;
}) {
  const inputRef = useRef<HTMLInputElement>(null);
  const [copied, setCopied] = useState(false);

  async function copy() {
    try {
      if (navigator.clipboard?.writeText) {
        await navigator.clipboard.writeText(value);
        setCopied(true);
        window.setTimeout(() => setCopied(false), 2000);
        return;
      }
    } catch {
      // Fall through to manual selection.
    }
    inputRef.current?.select();
    setCopied(false);
  }

  return (
    <div>
      <label className="sbtf-label" htmlFor={`link-${label}`}>
        {label}
      </label>
      <div className="mt-1 flex gap-2">
        <input
          id={`link-${label}`}
          ref={inputRef}
          readOnly
          value={value}
          onFocus={(event) => event.currentTarget.select()}
          className="sbtf-input flex-1 font-mono text-[0.75rem]"
        />
        <button
          type="button"
          onClick={copy}
          className="inline-flex shrink-0 items-center gap-1.5 rounded-lg border border-line-strong bg-white px-3 py-2 text-[0.8125rem] font-medium text-ink hover:bg-page"
        >
          {copied ? <Check className="h-4 w-4 text-emerald-600" /> : <Copy className="h-4 w-4" />}
          {copied ? "Copied" : "Copy"}
        </button>
      </div>
      {hint ? <p className="sbtf-hint mt-1">{hint}</p> : null}
    </div>
  );
}
