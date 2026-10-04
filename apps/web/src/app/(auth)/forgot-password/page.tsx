import { ForgotPasswordForm } from "@/components/auth/forgot-password-form";

export const metadata = { title: "Password recovery — SBTF System" };

export default function ForgotPasswordPage() {
  return (
    <div className="w-full max-w-md">
      <div className="sbtf-card p-6">
        <h1 className="text-lg font-semibold text-ink">Reset your password</h1>
        <p className="mt-1 text-[0.8125rem] text-muted">
          Enter the e-mail address of your SBTF account. Supabase Auth sends the recovery link; the
          SBTF System never stores or displays passwords.
        </p>
        <div className="mt-6">
          <ForgotPasswordForm />
        </div>
      </div>
    </div>
  );
}
