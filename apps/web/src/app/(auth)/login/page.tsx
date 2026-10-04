import { Suspense } from "react";

import { LoginForm } from "@/components/auth/login-form";
import { Spinner } from "@/components/ui";

export const metadata = { title: "Sign in — SBTF System" };

export default function LoginPage() {
  return (
    <div className="w-full max-w-md">
      <div className="sbtf-card p-6">
        <h1 className="text-lg font-semibold text-ink">Sign in to the SBTF console</h1>
        <p className="mt-1 text-[0.8125rem] text-muted">
          Municipal staff and administrators only. Tricycle drivers and operators use the SBTF
          mobile application.
        </p>

        <div className="mt-6">
          <Suspense fallback={<Spinner />}>
            <LoginForm />
          </Suspense>
        </div>
      </div>

      <p className="mt-4 text-center text-[0.75rem] text-muted">
        Accounts are created by the municipal administrator. Sign-in attempts and account changes
        are recorded in the activity log.
      </p>
    </div>
  );
}
