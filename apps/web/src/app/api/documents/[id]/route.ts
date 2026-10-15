import { NextResponse } from "next/server";

import { createClient } from "@/lib/supabase/server";
import { SITE_URL, isDemoMode } from "@/lib/env";
import { STORAGE_BUCKETS } from "@/lib/constants";

/**
 * Streams an uploaded applicant document to the signed-in user.
 *
 * The "Open file" control links straight here instead of minting a signed URL
 * in the browser. That keeps the request a normal user-initiated navigation
 * (a signed URL opened from `window.open` after an `await` is treated as
 * programmatic and silently blocked), and it means the storage link is created
 * only at the moment of the click, so it can never be a stale, expired link.
 *
 * Authorisation is unchanged from every other read path: the caller's own
 * session and RLS decide whether the document row and its storage object are
 * visible.
 */
export const dynamic = "force-dynamic";

export async function GET(
  _request: Request,
  { params }: { params: Promise<{ id: string }> },
) {
  if (isDemoMode()) {
    return new NextResponse("Preview mode — no document file is stored.", { status: 404 });
  }

  const { id } = await params;
  const supabase = await createClient();

  const { data: auth } = await supabase.auth.getUser();
  if (!auth?.user) {
    return NextResponse.redirect(new URL("/login", SITE_URL));
  }

  const { data: document, error } = await supabase
    .from("franchise_documents")
    .select("storage_path, file_name, mime_type")
    .eq("id", id)
    .maybeSingle<{ storage_path: string; file_name: string | null; mime_type: string | null }>();

  if (error || !document) {
    return new NextResponse("The document record could not be found.", { status: 404 });
  }

  const { data: file, error: downloadError } = await supabase.storage
    .from(STORAGE_BUCKETS.documents)
    .download(document.storage_path);

  if (downloadError || !file) {
    return new NextResponse(
      downloadError?.message ?? "The file is not available in storage.",
      { status: 404 },
    );
  }

  const fileName = document.file_name ?? document.storage_path.split("/").pop() ?? "document";
  const mimeType = document.mime_type ?? file.type ?? "application/octet-stream";

  return new NextResponse(file, {
    headers: {
      "content-type": mimeType,
      "content-disposition": `inline; filename="${fileName.replace(/["\\]/g, "")}"`,
      "cache-control": "private, no-store",
    },
  });
}
