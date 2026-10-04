import type { UserRole } from "@/types/database";

/**
 * Capability matrix.
 *
 * IMPORTANT: these helpers exist so the interface can hide or disable actions a
 * role may not perform. They are NOT the authorisation mechanism — PostgreSQL
 * Row Level Security and the SECURITY DEFINER RPCs enforce every rule. If a
 * capability is missing here but permitted in the database, the database still
 * wins; if it is present here but refused by the database, the database wins.
 */
export const CAPABILITIES = {
  administrator: [
    "dashboard.view",
    "users.view",
    "users.manage",
    "users.assign_role",
    "users.set_status",
    "users.create_staff",
    "applications.view_all",
    "applications.review",
    "applications.verify_documents",
    "applications.approve",
    "applications.reject",
    "records.view_all",
    "records.archive",
    "records.generate_certificate",
    "analytics.view_operational",
    "analytics.view_system_health",
    "reports.export",
    "ai.request",
    "logs.view_all",
    "settings.view",
    "settings.manage",
    "toda.manage",
  ],
  staff: [
    "dashboard.view",
    "applications.view_all",
    "applications.review",
    "applications.verify_documents",
    "applications.approve",
    "applications.reject",
    "records.view_all",
    "records.generate_certificate",
    "analytics.view_operational",
    "reports.export",
    "ai.request",
    "logs.view_all",
  ],
  driver: [],
} as const satisfies Record<UserRole, readonly string[]>;

export type Capability =
  (typeof CAPABILITIES)["administrator"][number];

export function can(
  role: UserRole | null | undefined,
  capability: Capability,
): boolean {
  if (!role) return false;
  return (CAPABILITIES[role] as readonly string[]).includes(capability);
}

export function isStaffRole(role: UserRole | null | undefined): boolean {
  return role === "staff" || role === "administrator";
}

export function homePathForRole(role: UserRole | null | undefined): string {
  if (role === "administrator") return "/admin";
  if (role === "staff") return "/staff";
  return "/unauthorized";
}
