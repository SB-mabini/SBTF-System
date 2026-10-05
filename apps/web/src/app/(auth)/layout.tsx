import Link from "next/link";
import type { ReactNode } from "react";

import { MUNICIPALITY, PROVINCE, SYSTEM_TITLE } from "@/lib/constants";
import { BrandMark } from "@/components/layout/brand-mark";

/**
 * Layout for the unauthenticated screens: sign-in, password recovery and the
 * e-mail verification notice. Deliberately plain — the municipality's own
 * identity, one card, no navigation.
 */
export default function AuthLayout({ children }: { children: ReactNode }) {
  return (
    <div className="flex min-h-screen flex-col bg-page">
      <header className="border-b border-line bg-primary text-white">
        <div className="mx-auto flex max-w-6xl items-center gap-3 px-6 py-4">
          <BrandMark priority />
          <div className="leading-tight">
            <p className="text-sm font-semibold">{SYSTEM_TITLE}</p>
            <p className="text-[0.6875rem] text-white/70">
              {MUNICIPALITY}, {PROVINCE}
            </p>
          </div>
        </div>
      </header>

      <main className="mx-auto flex w-full max-w-6xl flex-1 items-center justify-center px-6 py-10">
        {children}
      </main>

      <footer className="border-t border-line bg-white px-6 py-4 text-center text-[0.6875rem] text-muted">
        <p>
          Web and Mobile-Based Franchising and Tricycle Driver Registration System with Descriptive
          and Prescriptive Analytics and Decision Support.
        </p>
        <p className="mt-1">
          <Link className="text-primary hover:underline" href="/verify">
            Verify a franchise certificate
          </Link>
          {" · "}
          Data privacy notice: personal data is processed under RA 10173 and used only for
          franchise regulation in {MUNICIPALITY}.
        </p>
      </footer>
    </div>
  );
}
