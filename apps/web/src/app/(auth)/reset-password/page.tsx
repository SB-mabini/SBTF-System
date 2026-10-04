import { ResetPasswordForm } from "@/components/auth/reset-password-form";

export const metadata = { title: "Set a new password — SBTF System" };

export default function ResetPasswordPage() {
  return (
    <div className="w-full max-w-md">
      <div className="sbtf-card p-6">
        <h1 className="text-lg font-semibold text-ink">Set a new password</h1>
        <p className="mt-1 text-[0.8125rem] text-muted">
          Choose a password you do not use for another service.
        </p>
        <div className="mt-6">
          <ResetPasswordForm />
        </div>
      </div>
    </div>
  );
}
