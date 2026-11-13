"use server";

import { revalidatePath } from "next/cache";

import { createClient } from "@/lib/supabase/server";
import { isDemoMode } from "@/lib/env";
import { DEMO_WRITE_BLOCKED, type ActionState } from "@/lib/actions/types";

/**
 * System settings updates (administrators only — the RLS policy enforces it).
 * Values are normalised against the declared data type before saving.
 */
export async function updateSettingAction(input: {
  key: string;
  value: string;
  dataType: "string" | "number" | "boolean" | "json" | "string_array";
}): Promise<ActionState> {
  if (isDemoMode()) return DEMO_WRITE_BLOCKED;

  let parsed: unknown;
  try {
    switch (input.dataType) {
      case "number": {
        const numeric = Number(input.value);
        if (!Number.isFinite(numeric)) throw new Error("not a number");
        parsed = numeric;
        break;
      }
      case "boolean":
        parsed = input.value === "true" || input.value === "on" || input.value === "1";
        break;
      case "json":
      case "string_array": {
        parsed = JSON.parse(input.value);
        if (input.dataType === "string_array" && !Array.isArray(parsed)) {
          throw new Error("expected an array");
        }
        break;
      }
      default:
        parsed = input.value;
    }
  } catch {
    return { ok: false, message: `The value is not valid for a ${input.dataType} setting.` };
  }

  const supabase = await createClient();
  const { error } = await supabase
    .from("system_settings")
    .update({ value: parsed })
    .eq("key", input.key);

  revalidatePath("/admin/settings");
  revalidatePath("/admin");
  revalidatePath("/staff");
  return error
    ? { ok: false, message: error.message }
    : { ok: true, message: "Setting saved. The change is recorded in the activity log." };
}

/** Keys the Franchise Editor is allowed to write. */
const DOCUMENT_SETTING_KEYS = [
  "office_name",
  "certificate_signatory_name",
  "certificate_signatory_position",
  "certificate_footer_note",
  "certificate_verification_base_url",
  "document_logo_enabled",
  "document_logo_position",
  "document_logo_width",
  "document_header_align",
  "document_board_name",
  "document_section_order",
] as const;

/**
 * Saves the whole document template in one round trip so a partial template
 * can never be persisted. Values are normalised here and re-validated by the
 * settings data type check in PostgreSQL.
 */
export async function saveDocumentTemplateAction(
  values: Record<string, unknown>,
): Promise<ActionState> {
  if (isDemoMode()) return DEMO_WRITE_BLOCKED;

  const allowed = new Set<string>(DOCUMENT_SETTING_KEYS);
  const rows = Object.entries(values).filter(([key]) => allowed.has(key));

  if (rows.length === 0) return { ok: false, message: "No document settings to save." };

  const number = values.document_logo_width;
  if (
    number !== undefined &&
    (!Number.isFinite(Number(number)) || Number(number) < 16 || Number(number) > 40)
  ) {
    return { ok: false, message: "Logo width must be between 16 and 40 mm." };
  }

  const position = String(values.document_logo_position ?? "left");
  if (!["left", "center", "right"].includes(position)) {
    return { ok: false, message: "Choose left, center or right for the logo." };
  }

  const align = String(values.document_header_align ?? "center");
  if (!["left", "center", "right"].includes(align)) {
    return { ok: false, message: "Choose left, center or right for the letterhead." };
  }

  const sectionOrder = values.document_section_order;
  if (!Array.isArray(sectionOrder) || sectionOrder.length === 0) {
    return { ok: false, message: "Keep at least one document block enabled." };
  }

  const supabase = await createClient();
  for (const [key, value] of rows) {
    const { error } = await supabase
      .from("system_settings")
      .update({ value })
      .eq("key", key);
    if (error) return { ok: false, message: `${key}: ${error.message}` };
  }

  revalidatePath("/admin/franchise-editor");
  revalidatePath("/admin/settings");
  revalidatePath("/admin");
  revalidatePath("/staff");
  return {
    ok: true,
    message: "Franchise template saved. Newly generated documents will use it.",
  };
}
