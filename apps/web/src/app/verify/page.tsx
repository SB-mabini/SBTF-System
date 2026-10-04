import Link from "next/link";
import { Suspense } from "react";

import { VerifyCertificate } from "@/components/verify-certificate";
import { Spinner } from "@/components/ui";
import { MUNICIPALITY, PROVINCE, SYSTEM_TITLE } from "@/lib/constants";

export const metadata = {
  title: "Verify a franchise certificate — SBTF System",
  description:
    "Public verification of a tricycle franchise certificate issued by the Municipality of Mabini, Batangas.",
};

/**
 * Public page, reachable without signing in — this is where the QR code printed
 * on a certificate points. It is the only page in the system that runs without
 * a session.
 */
export default function VerifyPage() {
  return (
    <div className="min-h-screen bg-page">
      <header className="bg-primary text-white">
        <div className="mx-auto flex max-w-3xl items-center gap-3 px-6 py-5">
          <span className="grid h-10 w-10 place-items-center rounded-lg bg-white/10 text-sm font-semibold">
            SBTF
          </span>
          <div className="leading-tight">
            <p className="text-sm font-semibold">Franchise certificate verification</p>
            <p className="text-[0.6875rem] text-white/70">
              {MUNICIPALITY}, {PROVINCE}
            </p>
          </div>
        </div>
      </header>

      <main className="mx-auto max-w-3xl px-6 py-8">
        <h1 className="text-xl font-semibold text-ink">Check a franchise certificate</h1>
        <p className="mt-1 text-[0.875rem] text-muted">
          Scan the QR code on the certificate, or type the twelve-character verification code printed
          underneath it. The registry confirms whether the franchise exists and whether it is still
          valid.
        </p>

        <div className="sbtf-card mt-6 p-6">
          <Suspense fallback={<Spinner label="Loading the verification form…" />}>
            <VerifyCertificate />
          </Suspense>
        </div>

        <section className="mt-6 rounded-lg border border-line bg-white p-5">
          <h2 className="text-[0.9375rem] font-semibold text-ink">What this page does and does not show</h2>
          <ul className="mt-2 space-y-1.5 text-[0.8125rem] text-muted">
            <li>
              It shows the franchise number, the TODA, the validity dates and the operator&apos;s
              initials only.
            </li>
            <li>
              It never shows a full name, address, contact number or plate number — the QR code
              itself carries nothing but the opaque verification code.
            </li>
            <li>
              Every check is answered by the database function
              <code className="mx-1 rounded bg-page px-1 font-mono text-[0.75rem]">
                rpc_verify_certificate
              </code>
              inside the municipality&apos;s Supabase project.
            </li>
          </ul>
        </section>

        <p className="mt-6 text-center text-[0.75rem] text-muted">
          {SYSTEM_TITLE}
          {" · "}
          <Link className="text-primary hover:underline" href="/login">
            Municipal staff sign-in
          </Link>
        </p>
      </main>
    </div>
  );
}
