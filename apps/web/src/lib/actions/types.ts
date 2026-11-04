/** Result contract shared by every server action. */
export interface ActionState {
  ok: boolean;
  message: string;
  details?: Record<string, unknown>;
}

/** Extra fields the sign-in screen needs to render its lockout countdown. */
export interface SignInState extends ActionState {
  locked?: boolean;
  retryAfterSeconds?: number;
  remainingAttempts?: number;
  destination?: string;
}

export const DEMO_WRITE_BLOCKED: ActionState = {
  ok: false,
  message:
    "Preview mode is read-only. Connect a Supabase project (NEXT_PUBLIC_DEMO_MODE=false) to perform this action.",
};
