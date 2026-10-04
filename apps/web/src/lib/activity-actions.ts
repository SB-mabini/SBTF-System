import type { ActivityAction } from "@/types/database";

/**
 * The audit vocabulary, in the order the enum is declared in the database.
 * Kept as a plain array so that filter dropdowns and exports cannot drift from
 * the schema without a visible change here.
 */
export const ACTIVITY_ACTIONS: ActivityAction[] = [
  "login",
  "logout",
  "registration",
  "profile_update",
  "notification_preferences_update",
  "application_submitted",
  "application_renewal_submitted",
  "document_upload",
  "document_replaced",
  "document_verification",
  "review_started",
  "application_approved",
  "application_rejected",
  "record_created",
  "record_update",
  "franchise_archived",
  "certificate_generation",
  "role_change",
  "user_activated",
  "user_deactivated",
  "user_created",
  "settings_update",
  "ai_request",
  "renewal_reminder_sent",
  "security_event",
];
