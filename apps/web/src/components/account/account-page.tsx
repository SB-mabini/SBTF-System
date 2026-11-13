import { AccountForm } from "@/components/account/account-form";
import { ChangePasswordForm } from "@/components/account/change-password-form";
import { SectionTitle } from "@/components/ui";
import { listBarangays } from "@/lib/data";
import type { SessionContext } from "@/lib/data";

export async function AccountPage({ session }: { session: SessionContext }) {
  const barangays = await listBarangays();

  return (
    <div className="space-y-4">
      <SectionTitle
        title="My account"
        description="Your details as recorded in the franchising office's directory, your notification preferences and your password."
      />
      <AccountForm profile={session.profile} barangays={barangays} />
      <ChangePasswordForm />
    </div>
  );
}
