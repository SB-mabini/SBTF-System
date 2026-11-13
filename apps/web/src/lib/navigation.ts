import {
  Activity,
  BarChart3,
  Bell,
  CalendarClock,
  ClipboardList,
  FileBarChart,
  FileText,
  LayoutDashboard,
  Megaphone,
  Settings,
  Sparkles,
  Stamp,
  Users,
  type LucideIcon,
} from "lucide-react";

import { can, type Capability } from "@/lib/permissions";
import type { UserRole } from "@/types/database";

/**
 * One destination in the staff/administrator consoles.
 *
 * The same list drives the desktop sidebar, the tablet/laptop drawer and the
 * phone bottom bar, so a route is never added to one shell and forgotten in
 * another.
 */
export interface NavItem {
  href: string;
  label: string;
  /** Shorter label for the narrow phone tabs. Falls back to [label]. */
  shortLabel?: string;
  icon: LucideIcon;
  capability: Capability;
  /** Dashboard must not look active on every nested page. */
  exact?: boolean;
  /** Shown in the phone bottom bar; the rest move under "More". */
  mobilePrimary?: boolean;
}

/** A functional group, rendered with its own heading in the navigation. */
export interface NavGroup {
  label: string;
  items: NavItem[];
}

const ADMIN_NAV: NavGroup[] = [
  {
    label: "Overview",
    items: [
      {
        href: "/admin",
        label: "Dashboard",
        icon: LayoutDashboard,
        capability: "dashboard.view",
        exact: true,
        mobilePrimary: true,
      },
    ],
  },
  {
    label: "Franchise operations",
    items: [
      {
        href: "/admin/applications",
        label: "Applications",
        icon: FileText,
        capability: "applications.view_all",
        mobilePrimary: true,
      },
      {
        href: "/admin/franchises",
        label: "Franchise Records",
        shortLabel: "Records",
        icon: Stamp,
        capability: "records.view_all",
        mobilePrimary: true,
      },
    ],
  },
  {
    label: "Insights and reports",
    items: [
      {
        href: "/admin/analytics",
        label: "Analytics",
        icon: BarChart3,
        capability: "analytics.view_operational",
      },
      {
        href: "/admin/reports",
        label: "Reports",
        icon: FileBarChart,
        capability: "reports.export",
      },
      {
        href: "/admin/ai-support",
        label: "AI Decision Support",
        shortLabel: "AI support",
        icon: Sparkles,
        capability: "ai.request",
      },
    ],
  },
  {
    label: "Administration",
    items: [
      {
        href: "/admin/users",
        label: "Users",
        icon: Users,
        capability: "users.view",
        mobilePrimary: true,
      },
      {
        href: "/admin/activity-logs",
        label: "Activity Logs",
        shortLabel: "Activity",
        icon: Activity,
        capability: "logs.view_all",
      },
      {
        href: "/admin/franchise-editor",
        label: "Franchise Editor",
        shortLabel: "Documents",
        icon: Stamp,
        capability: "settings.manage",
      },
      {
        href: "/admin/settings",
        label: "Settings",
        icon: Settings,
        capability: "settings.manage",
      },
    ],
  },
  {
    label: "Updates",
    items: [
      {
        href: "/admin/announcements",
        label: "Announcements",
        icon: Megaphone,
        capability: "announcements.manage",
      },
      {
        href: "/admin/notifications",
        label: "Notifications",
        icon: Bell,
        capability: "dashboard.view",
      },
    ],
  },
];

const STAFF_NAV: NavGroup[] = [
  {
    label: "Overview",
    items: [
      {
        href: "/staff",
        label: "Dashboard",
        icon: LayoutDashboard,
        capability: "dashboard.view",
        exact: true,
        mobilePrimary: true,
      },
    ],
  },
  {
    label: "Service desk",
    items: [
      {
        href: "/staff/applications",
        label: "Applications",
        icon: FileText,
        capability: "applications.view_all",
        mobilePrimary: true,
      },
      {
        href: "/staff/appointments",
        label: "Appointments",
        shortLabel: "Visits",
        icon: CalendarClock,
        capability: "applications.view_all",
        mobilePrimary: true,
      },
      {
        href: "/staff/form-requests",
        label: "Form Requests",
        shortLabel: "Requests",
        icon: ClipboardList,
        capability: "form_requests.manage",
        mobilePrimary: true,
      },
    ],
  },
  {
    label: "Records",
    items: [
      {
        href: "/staff/franchises",
        label: "Franchise Records",
        shortLabel: "Records",
        icon: Stamp,
        capability: "records.view_all",
      },
    ],
  },
  {
    label: "Insights and reports",
    items: [
      {
        href: "/staff/analytics",
        label: "Analytics",
        icon: BarChart3,
        capability: "analytics.view_operational",
      },
      {
        href: "/staff/reports",
        label: "Reports",
        icon: FileBarChart,
        capability: "reports.export",
      },
      {
        href: "/staff/ai-support",
        label: "AI Decision Support",
        shortLabel: "AI support",
        icon: Sparkles,
        capability: "ai.request",
      },
    ],
  },
  {
    label: "Updates",
    items: [
      {
        href: "/staff/announcements",
        label: "Announcements",
        icon: Megaphone,
        capability: "announcements.manage",
      },
      {
        href: "/staff/notifications",
        label: "Notifications",
        icon: Bell,
        capability: "dashboard.view",
      },
    ],
  },
];

/**
 * The groups this role may actually open. Empty groups are dropped, so staff
 * never see an "Administration" heading with nothing under it.
 */
export function navGroupsFor(role: UserRole): NavGroup[] {
  const source = role === "administrator" ? ADMIN_NAV : STAFF_NAV;

  return source
    .map((group) => ({
      ...group,
      items: group.items.filter((item) => can(role, item.capability)),
    }))
    .filter((group) => group.items.length > 0);
}

/** Flattened destination list, useful for lookups and tests. */
export function navItemsFor(role: UserRole): NavItem[] {
  return navGroupsFor(role).flatMap((group) => group.items);
}

/**
 * Four primary phone tabs, in configuration order, plus the "More" button.
 */
export function mobilePrimaryItemsFor(role: UserRole): NavItem[] {
  return navItemsFor(role)
    .filter((item) => item.mobilePrimary)
    .slice(0, 4);
}

/** True when [pathname] belongs to [item]; the dashboard only matches exactly. */
export function isNavItemActive(pathname: string, item: NavItem): boolean {
  if (item.exact) return pathname === item.href;
  return pathname === item.href || pathname.startsWith(`${item.href}/`);
}

/** The notification destination carries the live unread badge. */
export function showsUnreadBadge(item: NavItem): boolean {
  return item.href.endsWith("/notifications");
}
