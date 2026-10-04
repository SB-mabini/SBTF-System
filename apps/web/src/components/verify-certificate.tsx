"use client";

import { useEffect, useState } from "react";
import { useSearchParams } from "next/navigation";
import { BadgeCheck, CalendarClock, CircleSlash, QrCode, ShieldAlert } from "lucide-react";

import { Alert, Badge, Button, Field, Spinner } from "@/components/ui";
import { formatDate } from "@/lib/format";
import { isDemoMode } from "@/lib/env";
import type { CertificateVerification } from "@/types/database";

type Result = CertificateVerification | null;

export function VerifyCertificate() {
  const searchParams = useSearchParams();
  const initialCode = searchParams.get("code") ?? "";

  const [code, setCode] = useState(initialCode);
  const [result, setResult] = useState<Result>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (initialCode.length === 12) void verify(initialCode);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  async function verify(value: string) {
    const normalized = value.trim().toUpperCase().replace(/[^A-Z0-9]/g, "");
    setError(null);
    setResult(null);

    if (normalized.length !== 12) {
      setError("Enter the 12-character code printed under the QR code.");
      return;
    }

    setLoading(true);
    try {
      const response = await fetch(`/api/verify?code=${encodeURIComponent(normalized)}`, {
        cache: "no-store",
      });
      const payload = (await response.json()) as CertificateVerification;
      setResult(payload);
    } catch {
      setError("The verification service is unavailable. Please try again.");
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="space-y-5">
      <form
        className="space-y-3"
        onSubmit={(event) => {
          event.preventDefault();
          void verify(code);
        }}
      >
        <Field
          label="Certificate verification code"
          htmlFor="code"
          hint="Twelve characters, printed under the QR code on the certificate."
        >
          <input
            id="code"
            className="sbtf-input font-mono tracking-[0.2em]"
            maxLength={12}
            placeholder="ABCD2345EFGH"
            value={code}
            onChange={(event) => setCode(event.target.value.toUpperCase())}
          />
        </Field>

        <Button type="submit" loading={loading} className="w-full">
          <BadgeCheck className="h-4 w-4" />
          Verify certificate
        </Button>
      </form>

      {error ? <Alert tone="danger">{error}</Alert> : null}
      {loading ? <Spinner label="Checking the franchise registry…" /> : null}

      {result ? <VerificationResult result={result} /> : null}

      {isDemoMode() ? (
        <Alert tone="warning" title="Preview mode">
          Verification runs against the bundled sample registry. Try{" "}
          <code className="font-mono">MAB-TR-2025-000123</code> in the demo dataset or any code
          shown on a sample record.
        </Alert>
      ) : null}
    </div>
  );
}

function VerificationResult({ result }: { result: CertificateVerification }) {
  const status = result.verification_status;

  if (status === "not_found") {
    return (
      <div className="rounded-lg border border-line bg-white p-5">
        <div className="flex items-center gap-2 text-secondary-600">
          <CircleSlash className="h-5 w-5" />
          <p className="text-sm font-semibold">No franchise matches this code</p>
        </div>
        <p className="mt-2 text-[0.8125rem] text-muted">
          The code is not in the municipal franchise registry. Check the characters carefully —
          letters I, L, O, 0 and 1 are never used — or bring the certificate to the franchise
          office for confirmation.
        </p>
      </div>
    );
  }

  const tone = status === "valid" ? "success" : status === "expired" ? "warning" : "neutral";
  const label =
    status === "valid" ? "Valid franchise" : status === "expired" ? "Expired franchise" : "Archived franchise";
  const Icon = status === "valid" ? BadgeCheck : status === "expired" ? CalendarClock : ShieldAlert;

  return (
    <div className="rounded-lg border border-line bg-white p-5">
      <div className="flex items-start justify-between gap-3">
        <div className="flex items-center gap-2">
          <Icon
            className={`h-5 w-5 ${
              tone === "success"
                ? "text-success-600"
                : tone === "warning"
                  ? "text-warning-600"
                  : "text-muted"
            }`}
          />
          <p className="text-sm font-semibold text-ink">{label}</p>
        </div>
        <Badge tone={tone === "success" ? "success" : tone === "warning" ? "warning" : "neutral"}>
          {status}
        </Badge>
      </div>

      <dl className="mt-4 grid gap-3 sm:grid-cols-2">
        <Detail label="Franchise number" value={result.franchise_number ?? "—"} mono />
        <Detail label="Operator" value={result.operator_display_name ?? "—"} />
        <Detail label="TODA" value={result.toda_name ?? "—"} />
        <Detail label="Issued on" value={formatDate(result.issued_at)} />
        <Detail label="Valid until" value={formatDate(result.expires_at)} />
        <Detail label="Checked at" value={formatDate(result.verified_at)} />
      </dl>

      <p className="mt-4 flex items-start gap-2 text-[0.75rem] text-muted">
        <QrCode className="mt-0.5 h-3.5 w-3.5 shrink-0" />
        The QR code on the certificate contains only this verification code — never a name, an
        address or a plate number. Personal details are masked here by design.
      </p>
    </div>
  );
}

function Detail({ label, value, mono = false }: { label: string; value: string; mono?: boolean }) {
  return (
    <div>
      <dt className="text-[0.6875rem] uppercase tracking-wide text-muted">{label}</dt>
      <dd className={`text-[0.875rem] text-ink ${mono ? "font-mono" : ""}`}>{value}</dd>
    </div>
  );
}
