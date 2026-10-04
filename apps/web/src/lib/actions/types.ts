/** Result contract shared by every server action. */
export interface ActionState {
  ok: boolean;
  message: string;
  details?: Record<string, unknown>;
}

export const DEMO_WRITE_BLOCKED: ActionState = {
  ok: false,
  message:
    "Preview mode is read-only. Connect a Supabase project (NEXT_PUBLIC_DEMO_MODE=false) to perform this action.",
};
