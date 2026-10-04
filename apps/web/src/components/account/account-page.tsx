import { AccountForm } from "@/components/account/account-form";
import { SectionTitle } from "@/components/ui";
import { listBarangays } from "@/lib/data";
import type { SessionContext } from "@/lib/data";

export async function AccountPage({ session }: { session: SessionContext }) {
  const barangays = await listBarangays();

  return (
    <div>
      <SectionTitle
        title="My account"
        description="Your details as recorded in the franchising office's directory, and your notification preferences."
      />
      <AccountForm profile={session.profile} barangays={barangays} />
    </div>
  );
}
