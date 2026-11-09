"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

import {
  isNavItemActive,
  navGroupsFor,
  showsUnreadBadge,
} from "@/lib/navigation";
import type { UserRole } from "@/types/database";

/**
 * The categorized navigation list.
 *
 * Shared by the desktop sidebar, the tablet/laptop drawer and the phone "More"
 * sheet so every shell exposes exactly the same routes, groups and badges.
 */
export function NavPanel({
  role,
  unreadCount,
  onNavigate,
}: {
  role: UserRole;
  unreadCount: number;
  onNavigate?: () => void;
}) {
  const pathname = usePathname();
  const groups = navGroupsFor(role);

  return (
    <nav className="space-y-4 p-3" aria-label="Main">
      {groups.map((group) => (
        <div key={group.label}>
          <p className="px-3 pb-1.5 text-[0.625rem] font-semibold uppercase tracking-[0.09em] text-muted">
            {group.label}
          </p>
          <ul className="space-y-0.5">
            {group.items.map((item) => {
              const active = isNavItemActive(pathname, item);
              const Icon = item.icon;

              return (
                <li key={item.href}>
                  <Link
                    href={item.href}
                    aria-current={active ? "page" : undefined}
                    onClick={onNavigate}
                    className={`flex items-center gap-3 rounded-lg px-3 py-2 text-[0.8125rem] font-medium transition-colors ${
                      active
                        ? "bg-primary-50 text-primary-700"
                        : "text-muted hover:bg-page hover:text-ink"
                    }`}
                  >
                    <Icon className={`h-4 w-4 shrink-0 ${active ? "text-primary" : ""}`} />
                    <span className="flex-1">{item.label}</span>
                    {showsUnreadBadge(item) && unreadCount > 0 ? (
                      <span className="rounded-full bg-secondary-500 px-1.5 py-0.5 text-[0.625rem] font-semibold text-white">
                        {unreadCount}
                      </span>
                    ) : null}
                  </Link>
                </li>
              );
            })}
          </ul>
        </div>
      ))}
    </nav>
  );
}
