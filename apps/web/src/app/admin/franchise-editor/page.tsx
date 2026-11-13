import { FranchiseEditor } from "@/components/settings/franchise-editor";
import { requireAdministrator } from "@/lib/auth-guard";
import { listFranchiseRecords, listSettings } from "@/lib/data";

export default async function AdminFranchiseEditorPage() {
  await requireAdministrator();
  const [settings, records] = await Promise.all([
    listSettings(),
    listFranchiseRecords({ pageSize: 1 }),
  ]);

  return <FranchiseEditor settings={settings} sampleRecord={records.rows[0] ?? null} />;
}
