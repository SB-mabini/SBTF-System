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
