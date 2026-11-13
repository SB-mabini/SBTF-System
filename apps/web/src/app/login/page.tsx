import Image from "next/image";
import Link from "next/link";
import { Suspense } from "react";

import { LoginForm } from "@/components/auth/login-form";
import { BrandMark } from "@/components/layout/brand-mark";
import { Alert, Spinner } from "@/components/ui";
import { MUNICIPALITY, PROVINCE, SYSTEM_TITLE } from "@/lib/constants";

export const metadata = { title: "Sign in — SBTF System" };

export default async function LoginPage({
  searchParams,
}: {
  searchParams: Promise<{ notice?: string }>;
}) {
  const { notice } = await searchParams;
  const passwordSet = notice === "password-set";

  return (
    <main className="flex min-h-screen flex-col bg-primary-900">
      <header className="relative z-20 border-b border-white/10 bg-primary">
        <div className="mx-auto flex w-full max-w-6xl items-center gap-3 px-4 py-3 sm:px-6">
          <BrandMark priority />
          <div className="leading-tight">
            <p className="text-sm font-semibold text-white">{SYSTEM_TITLE}</p>
            <p className="text-[0.6875rem] text-white/70">
              {MUNICIPALITY}, {PROVINCE}
            </p>
          </div>
        </div>
      </header>

      <section className="relative flex flex-1 items-center justify-center overflow-hidden px-4 py-10 sm:px-6">
        <Image
          src="/sign-in-bg.jpg"
          alt=""
          aria-hidden
          fill
          priority
          sizes="100vw"
          className="object-cover"
        />
        <div className="absolute inset-0 bg-gradient-to-br from-primary-900/85 via-primary-900/60 to-primary-800/75" />

        <div className="relative z-10 w-full max-w-[26rem]">
          <div className="rounded-2xl border border-white/60 bg-white/95 p-6 shadow-[0_24px_70px_-20px_rgba(21,10,56,0.65)] backdrop-blur-md sm:p-8">
            <div className="text-center">
              <h1 className="text-lg font-semibold text-ink">Sign in to the SBTF System</h1>
              <p className="mt-1 text-[0.8125rem] text-muted">
                Municipal staff and administrators only.
              </p>
            </div>

            {passwordSet ? (
              <div className="mt-4">
                <Alert tone="success" title="Password set">
                  Your password has been saved. Sign in with your new password.
                </Alert>
              </div>
            ) : null}

            <div className="mt-6">
              <Suspense fallback={<Spinner />}>
                <LoginForm />
              </Suspense>
            </div>
          </div>

          <div className="mt-5 space-y-1 text-center text-[0.6875rem] text-white/75">
            <p>
              Accounts are created by the municipal administrator. Sign-in attempts are recorded in
              the activity log.
            </p>
            <p>
              <Link className="text-white underline-offset-2 hover:underline" href="/verify">
                Verify a franchise certificate
              </Link>
            </p>
          </div>
        </div>
      </section>
    </main>
  );
}
