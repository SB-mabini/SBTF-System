import { AccountForm } from "@/components/account/account-form";
import { ChangePasswordForm } from "@/components/account/change-password-form";
import { SettingsEditor } from "@/components/settings/settings-editor";
import { SettingsTabs } from "@/components/settings/settings-tabs";
import { Card, CardHeader, SectionTitle } from "@/components/ui";
import { listSettings, listTodas, listBarangays } from "@/lib/data";
import { requireAdministrator } from "@/lib/auth-guard";

export const metadata = { title: "Settings — SBTF Administrator" };

export default async function AdminSettingsPage() {
  const session = await requireAdministrator();

  const [settings, todas, barangays] = await Promise.all([
    listSettings(),
    listTodas(),
    listBarangays(),
  ]);

  return (
    <div>
      <SectionTitle
        title="Settings"
        description="Your account and security, the operational values used by the workflow, and the franchise document template."
      />

      <SettingsTabs
        profile={
          <div className="space-y-4">
            <AccountForm profile={session.profile} barangays={barangays} />
            <ChangePasswordForm />
          </div>
        }
        system={
          <div>
            <SettingsEditor settings={settings} />

            <Card className="mt-4">
              <CardHeader
                title="Reference data"
                description="Read-only values loaded by migration; they describe the municipality rather than the office's preferences."
              />
              <dl className="grid gap-3 text-[0.8125rem] sm:grid-cols-3">
                <div>
                  <dt className="text-muted">Barangays</dt>
                  <dd className="font-medium text-ink">{barangays.length} (PSA codes)</dd>
                </div>
                <div>
                  <dt className="text-muted">TODAs</dt>
                  <dd className="font-medium text-ink">
                    {todas.length} associations ·{" "}
                    {todas.reduce((sum, toda) => sum + toda.members_count, 0)} masterlist members
                  </dd>
                </div>
                <div>
                  <dt className="text-muted">Secrets</dt>
                  <dd className="font-medium text-ink">
                    Held only as Supabase Edge Function secrets
                  </dd>
                </div>
              </dl>
            </Card>
          </div>
        }
      />
    </div>
  );
}
