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

/**
 * Result of checking an e-mailed recovery code.
 *
 * `expired` means the pending-address cookie is gone, so the visitor has to
 * start again from the recovery screen; it is a different action from a wrong
 * digit, and the form words it differently.
 */
export interface RecoveryCodeState extends ActionState {
  expired?: boolean;
}

export const DEMO_WRITE_BLOCKED: ActionState = {
  ok: false,
  message:
    "Preview mode is read-only. Connect a Supabase project (NEXT_PUBLIC_DEMO_MODE=false) to perform this action.",
};
