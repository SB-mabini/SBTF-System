"use server";

import { revalidatePath } from "next/cache";

import { createClient } from "@/lib/supabase/server";
import { isDemoMode } from "@/lib/env";
import { DEMO_WRITE_BLOCKED, type ActionState } from "@/lib/actions/types";

export async function markNotificationReadAction(
  notificationId: string,
): Promise<ActionState> {
  if (isDemoMode()) return DEMO_WRITE_BLOCKED;

  const supabase = await createClient();
  const { error } = await supabase
    .from("notifications")
    .update({ read: true, read_at: new Date().toISOString() })
    .eq("id", notificationId);

  revalidatePath("/staff/notifications");
  revalidatePath("/admin");
  revalidatePath("/staff");
  return error ? { ok: false, message: error.message } : { ok: true, message: "Marked as read." };
}

export async function markAllNotificationsReadAction(): Promise<ActionState> {
  if (isDemoMode()) return DEMO_WRITE_BLOCKED;

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { ok: false, message: "Not signed in." };

  const { data: profile } = await supabase
    .from("profiles")
    .select("id")
    .eq("auth_user_id", user.id)
    .maybeSingle();

  if (!profile) return { ok: false, message: "Profile not found." };

  const { error } = await supabase
    .from("notifications")
    .update({ read: true, read_at: new Date().toISOString() })
    .eq("user_id", profile.id)
    .eq("read", false);

  revalidatePath("/staff/notifications");
  revalidatePath("/admin");
  revalidatePath("/staff");
  return error
    ? { ok: false, message: error.message }
    : { ok: true, message: "All notifications marked as read." };
}
