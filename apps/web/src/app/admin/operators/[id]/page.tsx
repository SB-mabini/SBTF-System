import { notFound } from "next/navigation";

import { OperatorProfile } from "@/components/operators/operator-profile";
import { getOperatorProfile, listBarangays } from "@/lib/data";
import { requireAdministrator } from "@/lib/auth-guard";

export const metadata = { title: "Operator profile — MTOP Administrator" };

export default async function AdminOperatorProfilePage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const session = await requireAdministrator();
  const { id } = await params;

  const [bundle, barangays] = await Promise.all([getOperatorProfile(id), listBarangays()]);
  if (!bundle) notFound();

  return (
    <OperatorProfile
      bundle={bundle}
      barangays={barangays}
      basePath="/admin"
      canEdit
      currentProfileId={session.profile.id}
    />
  );
}
