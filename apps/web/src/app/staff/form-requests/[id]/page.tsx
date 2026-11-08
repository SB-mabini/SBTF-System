import { notFound } from "next/navigation";

import { FormRequestDetailView } from "@/components/form-requests/form-request-detail";
import { getFormRequest, getFormRequestOrCrSignedUrl, listSettings } from "@/lib/data";
import { isDemoMode } from "@/lib/env";
import { requireStaff } from "@/lib/auth-guard";
import { createClient } from "@/lib/supabase/server";

export const metadata = { title: "Form Request — SBTF Staff" };

export default async function StaffFormRequestDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  await requireStaff();
  const { id } = await params;

  const [request, settings, orCrUrl] = await Promise.all([
    getFormRequest(id),
    listSettings(),
    getFormRequestOrCrSignedUrl(id),
  ]);
  if (!request) notFound();

  const values = Object.fromEntries(
    settings
      .filter((setting) => setting.category === "forms")
      .map((setting) => [setting.key, String(setting.value ?? "")]),
  );

  let signatureDataUrl: string | null = null;
  if (!isDemoMode() && request.signature_storage_path) {
    try {
      const supabase = await createClient();
      const { data } = await supabase.storage
        .from("franchise-documents")
        .download(request.signature_storage_path);
      if (data) {
        const buffer = Buffer.from(await data.arrayBuffer());
        signatureDataUrl = `data:${data.type || "image/png"};base64,${buffer.toString("base64")}`;
      }
    } catch {
      // A missing signature file must not block the page; the letter prints
      // without the drawing.
      signatureDataUrl = null;
    }
  }

  return (
    <FormRequestDetailView
      request={request}
      settings={values}
      signatureDataUrl={signatureDataUrl}
      orCrUrl={orCrUrl}
    />
  );
}
