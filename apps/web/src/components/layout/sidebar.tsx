"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  Activity,
  BarChart3,
  Bell,
  FileBarChart,
  FileText,
  LayoutDashboard,
  Settings,
  Sparkles,
  Stamp,
  Users,
} from "lucide-react";

import { can, type Capability } from "@/lib/permissions";
import type { UserRole } from "@/types/database";

interface NavItem {
  href: string;
  label: string;
  icon: React.ComponentType<{ className?: string }>;
  capability: Capability;
  exact?: boolean;
}

const ADMIN_NAV: NavItem[] = [
  { href: "/admin", label: "Dashboard", icon: LayoutDashboard, capability: "dashboard.view", exact: true },
  { href: "/admin/applications", label: "Applications", icon: FileText, capability: "applications.view_all" },
  { href: "/admin/franchises", label: "Franchise Records", icon: Stamp, capability: "records.view_all" },
  { href: "/admin/users", label: "Users", icon: Users, capability: "users.view" },
  { href: "/admin/analytics", label: "Analytics", icon: BarChart3, capability: "analytics.view_operational" },
  { href: "/admin/reports", label: "Reports", icon: FileBarChart, capability: "reports.export" },
  { href: "/admin/ai-support", label: "AI Decision Support", icon: Sparkles, capability: "ai.request" },
  { href: "/admin/activity-logs", label: "Activity Logs", icon: Activity, capability: "logs.view_all" },
  { href: "/admin/settings", label: "Settings", icon: Settings, capability: "settings.manage" },
];

const STAFF_NAV: NavItem[] = [
  { href: "/staff", label: "Dashboard", icon: LayoutDashboard, capability: "dashboard.view", exact: true },
  { href: "/staff/applications", label: "Applications", icon: FileText, capability: "applications.view_all" },
  { href: "/staff/franchises", label: "Franchise Records", icon: Stamp, capability: "records.view_all" },
  { href: "/staff/analytics", label: "Analytics", icon: BarChart3, capability: "analytics.view_operational" },
  { href: "/staff/reports", label: "Reports", icon: FileBarChart, capability: "reports.export" },
  { href: "/staff/notifications", label: "Notifications", icon: Bell, capability: "dashboard.view" },
];

export function Sidebar({
  role,
  unreadCount,
}: {
  role: UserRole;
  unreadCount: number;
}) {
  const pathname = usePathname();
  const items = role === "administrator" ? ADMIN_NAV : STAFF_NAV;

  return (
    <aside className="hidden w-64 shrink-0 flex-col border-r border-line bg-white lg:flex">
      <div className="flex h-16 items-center gap-2.5 border-b border-line px-5">
        <span className="grid h-9 w-9 place-items-center rounded-lg bg-primary text-[0.8125rem] font-semibold text-white">
          SBTF
        </span>
        <div className="leading-tight">
          <p className="text-[0.8125rem] font-semibold text-ink">SBTF System</p>
          <p className="text-[0.6875rem] text-muted">Mabini, Batangas</p>
        </div>
      </div>

      <nav className="flex-1 space-y-1 overflow-y-auto p-3" aria-label="Main">
        {items
          .filter((item) => can(role, item.capability))
          .map((item) => {
            const active = item.exact
              ? pathname === item.href
              : pathname === item.href || pathname.startsWith(`${item.href}/`);
            const Icon = item.icon;
            return (
              <Link
                key={item.href}
                href={item.href}
                aria-current={active ? "page" : undefined}
                className={`flex items-center gap-3 rounded-lg px-3 py-2 text-[0.8125rem] font-medium transition-colors ${
                  active
                    ? "bg-primary-50 text-primary-700"
                    : "text-muted hover:bg-page hover:text-ink"
                }`}
              >
                <Icon className={`h-4 w-4 ${active ? "text-primary" : ""}`} />
                <span className="flex-1">{item.label}</span>
                {item.href.endsWith("/notifications") && unreadCount > 0 ? (
                  <span className="rounded-full bg-secondary-500 px-1.5 py-0.5 text-[0.625rem] font-semibold text-white">
                    {unreadCount}
                  </span>
                ) : null}
              </Link>
            );
          })}
      </nav>

      <div className="border-t border-line px-4 py-3">
        <p className="text-[0.6875rem] leading-relaxed text-muted">
          {role === "administrator" ? "Administrator" : "Staff"} console
          <br />
          Municipality of Mabini, Batangas
        </p>
      </div>
    </aside>
  );
}
