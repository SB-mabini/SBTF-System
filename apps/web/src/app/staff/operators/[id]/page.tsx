import { notFound } from "next/navigation";

import { OperatorProfile } from "@/components/operators/operator-profile";
import { getOperatorProfile, listBarangays } from "@/lib/data";
import { requireStaff } from "@/lib/auth-guard";

export const metadata = { title: "Operator profile — MTOP Staff" };

export default async function StaffOperatorProfilePage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const session = await requireStaff();
  const { id } = await params;

  const [bundle, barangays] = await Promise.all([getOperatorProfile(id), listBarangays()]);
  if (!bundle) notFound();

  return (
    <OperatorProfile
      bundle={bundle}
      barangays={barangays}
      basePath="/staff"
      canEdit={false}
      currentProfileId={session.profile.id}
    />
  );
}
