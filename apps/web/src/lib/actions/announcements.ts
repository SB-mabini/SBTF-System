"use server";

import { revalidatePath } from "next/cache";

import { createClient } from "@/lib/supabase/server";
import { isDemoMode } from "@/lib/env";
import { DEMO_WRITE_BLOCKED, type ActionState } from "@/lib/actions/types";
import type { AnnouncementAudience, AnnouncementStatus } from "@/types/database";

function revalidateAnnouncements() {
  revalidatePath("/admin/announcements");
  revalidatePath("/staff/announcements");
  revalidatePath("/admin/notifications");
  revalidatePath("/staff/notifications");
  revalidatePath("/admin");
  revalidatePath("/staff");
}

export interface SaveAnnouncementInput {
  id: string | null;
  title: string;
  body: string;
  audience: AnnouncementAudience;
  todaIds: string[];
  profileIds: string[];
  status: AnnouncementStatus;
  publishedAt?: string | null;
}

export async function saveAnnouncementAction(
  input: SaveAnnouncementInput,
): Promise<ActionState> {
  if (isDemoMode()) return DEMO_WRITE_BLOCKED;

  const title = input.title.trim();
  const body = input.body.trim();

  if (!title) return { ok: false, message: "Give the announcement a title." };
  if (title.length > 120)
    return { ok: false, message: "Keep the title to 120 characters or fewer." };
  if (!body) return { ok: false, message: "Write the announcement message." };
  if (body.length > 4000)
    return { ok: false, message: "Keep the message to 4,000 characters or fewer." };
  if (input.audience === "toda" && input.todaIds.length === 0)
    return { ok: false, message: "Select at least one TODA." };
  if (input.audience === "drivers" && input.profileIds.length === 0)
    return { ok: false, message: "Select at least one driver." };
  if (input.status === "published" && !title) {
    return { ok: false, message: "A published announcement needs a title." };
  }

  const supabase = await createClient();
  const { data, error } = await supabase.rpc("rpc_save_announcement", {
    p_id: input.id,
    p_title: title,
    p_body: body,
    p_audience: input.audience,
    p_toda_ids: input.audience === "toda" ? input.todaIds : [],
    p_profile_ids: input.audience === "drivers" ? input.profileIds : [],
    p_status: input.status,
    p_published_at: input.publishedAt ?? null,
  });

  if (error) return { ok: false, message: error.message };

  revalidateAnnouncements();

  const row = Array.isArray(data) ? data[0] : data;
  const recipients = Number(
    (row as { recipient_count?: number } | null)?.recipient_count ?? 0,
  );
  const saved = input.status === "published" ? "published" : input.status === "archived" ? "archived" : "saved as a draft";

  return {
    ok: true,
    message:
      input.status === "published"
        ? `Announcement ${saved} to ${recipients} recipient${recipients === 1 ? "" : "s"}.`
        : `Announcement ${saved}.`,
    details: { id: (row as { id?: string } | null)?.id ?? input.id },
  };
}

export async function deleteAnnouncementAction(id: string): Promise<ActionState> {
  if (isDemoMode()) return DEMO_WRITE_BLOCKED;

  const supabase = await createClient();
  const { error } = await supabase.rpc("rpc_delete_announcement", { p_id: id });
  if (error) return { ok: false, message: error.message };

  revalidateAnnouncements();
  return { ok: true, message: "Announcement deleted." };
}
