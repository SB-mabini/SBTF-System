import { SettingsEditor } from "@/components/settings/settings-editor";
import { Card, CardHeader, SectionTitle } from "@/components/ui";
import { listSettings, listTodas, listBarangays } from "@/lib/data";
import { requireAdministrator } from "@/lib/auth-guard";

export const metadata = { title: "Settings — SBTF Administrator" };

export default async function AdminSettingsPage() {
  await requireAdministrator();

  const [settings, todas, barangays] = await Promise.all([listSettings(), listTodas(), listBarangays()]);

  return (
    <div>
      <SectionTitle
        title="System settings"
        description="Operational values used by the workflow, the certificate and the scheduled renewal reminders."
      />

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
              {todas.length} associations · {todas.reduce((sum, toda) => sum + toda.members_count, 0)} masterlist members
            </dd>
          </div>
          <div>
            <dt className="text-muted">Secrets</dt>
            <dd className="font-medium text-ink">Held only as Supabase Edge Function secrets</dd>
          </div>
        </dl>
        <p className="mt-3 text-[0.75rem] text-muted">
          The Groq API key and the Supabase service-role key never reach the browser: the web
          application only holds the project URL and the anonymous key, which are safe to expose
          because every table is protected by row level security.
        </p>
      </Card>
    </div>
  );
}
