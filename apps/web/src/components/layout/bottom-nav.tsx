"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { MoreHorizontal, X } from "lucide-react";
import { useEffect, useState } from "react";

import { NavPanel } from "@/components/layout/nav-panel";
import {
  isNavItemActive,
  mobilePrimaryItemsFor,
  navItemsFor,
  showsUnreadBadge,
} from "@/lib/navigation";
import type { UserRole } from "@/types/database";

/**
 * Phone navigation (below the md breakpoint).
 *
 * Four primary destinations stay one tap away; everything else lives under
 * "More", which opens the same categorized list used by the desktop sidebar.
 * Tablets and small laptops use the topbar drawer instead.
 */
export function BottomNav({
  role,
  unreadCount,
}: {
  role: UserRole;
  unreadCount: number;
}) {
  const pathname = usePathname();
  const [moreOpen, setMoreOpen] = useState(false);

  const primary = mobilePrimaryItemsFor(role);
  const hiddenCount = navItemsFor(role).length - primary.length;

  // A route change means the choice was made; the links close the sheet before
  // navigating, so it never covers the page the person just asked for.
  useEffect(() => {
    if (!moreOpen) return;

    function onKeyDown(event: KeyboardEvent) {
      if (event.key === "Escape") setMoreOpen(false);
    }

    document.addEventListener("keydown", onKeyDown);
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";

    return () => {
      document.removeEventListener("keydown", onKeyDown);
      document.body.style.overflow = previousOverflow;
    };
  }, [moreOpen]);

  return (
    <>
      <nav
        className="fixed inset-x-0 bottom-0 z-30 border-t border-line bg-white pb-[env(safe-area-inset-bottom)] md:hidden"
        aria-label="Primary navigation"
      >
        <ul
          className="grid"
          style={{
            gridTemplateColumns: `repeat(${primary.length + (hiddenCount > 0 ? 1 : 0)}, minmax(0, 1fr))`,
          }}
        >
          {primary.map((item) => {
            const active = isNavItemActive(pathname, item);
            const Icon = item.icon;

            return (
              <li key={item.href}>
                <Link
                  href={item.href}
                  aria-current={active ? "page" : undefined}
                  className={`relative flex h-14 flex-col items-center justify-center gap-0.5 px-1 text-[0.625rem] font-medium transition-colors ${
                    active ? "text-primary-700" : "text-muted hover:text-ink"
                  }`}
                >
                  {active ? (
                    <span className="absolute inset-x-4 top-0 h-0.5 rounded-full bg-primary" />
                  ) : null}
                  <span className="relative">
                    <Icon className="h-5 w-5" />
                    {showsUnreadBadge(item) && unreadCount > 0 ? (
                      <span className="absolute -right-2 -top-1 grid h-3.5 min-w-3.5 place-items-center rounded-full bg-secondary-500 px-1 text-[0.5625rem] font-semibold text-white">
                        {unreadCount}
                      </span>
                    ) : null}
                  </span>
                  <span className="max-w-full truncate">
                    {item.shortLabel ?? item.label}
                  </span>
                </Link>
              </li>
            );
          })}

          {hiddenCount > 0 ? (
            <li>
              <button
                type="button"
                onClick={() => setMoreOpen(true)}
                aria-haspopup="dialog"
                aria-expanded={moreOpen}
                className="flex h-14 w-full flex-col items-center justify-center gap-0.5 px-1 text-[0.625rem] font-medium text-muted transition-colors hover:text-ink"
              >
                <MoreHorizontal className="h-5 w-5" />
                <span>More</span>
              </button>
            </li>
          ) : null}
        </ul>
      </nav>

      {moreOpen ? (
        <div className="fixed inset-0 z-50 md:hidden">
          <button
            type="button"
            className="absolute inset-0 bg-ink/40"
            aria-label="Close navigation"
            onClick={() => setMoreOpen(false)}
          />

          <div
            role="dialog"
            aria-modal="true"
            aria-label="All navigation"
            className="absolute inset-x-0 bottom-0 flex max-h-[85vh] flex-col rounded-t-2xl border-t border-line bg-white shadow-raised"
          >
            <div className="flex shrink-0 items-center justify-between border-b border-line px-4 py-3">
              <div>
                <p className="text-[0.875rem] font-semibold text-ink">All navigation</p>
                <p className="text-[0.6875rem] text-muted">
                  {role === "administrator" ? "Administrator" : "Staff"} console
                </p>
              </div>
              <button
                type="button"
                onClick={() => setMoreOpen(false)}
                className="rounded-md p-2 text-muted hover:bg-page hover:text-ink"
                aria-label="Close navigation"
              >
                <X className="h-5 w-5" />
              </button>
            </div>

            <div className="min-h-0 flex-1 overflow-y-auto pb-[env(safe-area-inset-bottom)]">
              <NavPanel
                role={role}
                unreadCount={unreadCount}
                onNavigate={() => setMoreOpen(false)}
              />
            </div>
          </div>
        </div>
      ) : null}
    </>
  );
}
