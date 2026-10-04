"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { Bell, ChevronDown, LogOut, Menu, Search, X } from "lucide-react";
import { useEffect, useRef, useState } from "react";

import { getBrowserClient } from "@/lib/supabase/client";
import { isDemoMode } from "@/lib/env";
import { initials, relativeTime, roleLabel } from "@/lib/format";
import type { Notification, UserRole } from "@/types/database";

export function Topbar({
  fullName,
  role,
  email,
  notifications,
}: {
  fullName: string;
  role: UserRole;
  email: string;
  notifications: Notification[];
}) {
  const router = useRouter();
  const [menuOpen, setMenuOpen] = useState(false);
  const [notificationsOpen, setNotificationsOpen] = useState(false);
  const [query, setQuery] = useState("");
  const [mobileNavOpen, setMobileNavOpen] = useState(false);
  const menuRef = useRef<HTMLDivElement>(null);

  const unread = notifications.filter((notification) => !notification.read).length;

  useEffect(() => {
    function onClick(event: MouseEvent) {
      if (menuRef.current && !menuRef.current.contains(event.target as Node)) {
        setMenuOpen(false);
        setNotificationsOpen(false);
      }
    }
    document.addEventListener("mousedown", onClick);
    return () => document.removeEventListener("mousedown", onClick);
  }, []);

  async function signOut() {
    if (!isDemoMode()) {
      const supabase = getBrowserClient();
      const { data } = await supabase.auth.getUser();
      if (data.user) {
        await supabase.rpc("rpc_log_activity", { p_action: "logout" });
      }
      await supabase.auth.signOut();
    }
    router.push("/login");
    router.refresh();
  }

  function submitSearch(event: React.FormEvent) {
    event.preventDefault();
    const term = query.trim();
    if (!term) return;
    const base = role === "administrator" ? "/admin" : "/staff";
    router.push(`${base}/applications?q=${encodeURIComponent(term)}`);
  }

  return (
    <header className="sticky top-0 z-20 flex h-16 items-center gap-3 border-b border-line bg-white px-4 lg:px-6">
      <button
        type="button"
        className="rounded-md p-2 text-muted hover:bg-page lg:hidden"
        onClick={() => setMobileNavOpen((open) => !open)}
        aria-label="Toggle navigation"
      >
        {mobileNavOpen ? <X className="h-5 w-5" /> : <Menu className="h-5 w-5" />}
      </button>

      <form onSubmit={submitSearch} className="relative hidden max-w-md flex-1 md:block">
        <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted" />
        <input
          className="sbtf-input pl-9"
          placeholder="Search application number, plate number or operator…"
          value={query}
          onChange={(event) => setQuery(event.target.value)}
          aria-label="Search applications"
        />
      </form>

      <div className="ml-auto flex items-center gap-2" ref={menuRef}>
        <div className="relative">
          <button
            type="button"
            className="relative rounded-md p-2 text-muted hover:bg-page"
            onClick={() => {
              setNotificationsOpen((open) => !open);
              setMenuOpen(false);
            }}
            aria-label={`Notifications (${unread} unread)`}
          >
            <Bell className="h-5 w-5" />
            {unread > 0 ? (
              <span className="absolute right-1 top-1 grid h-4 min-w-4 place-items-center rounded-full bg-secondary-500 px-1 text-[0.625rem] font-semibold text-white">
                {unread}
              </span>
            ) : null}
          </button>

          {notificationsOpen ? (
            <div className="absolute right-0 mt-2 w-80 rounded-lg border border-line bg-white shadow-raised">
              <div className="flex items-center justify-between border-b border-line px-3 py-2">
                <p className="text-[0.8125rem] font-semibold text-ink">Notifications</p>
                <Link
                  className="text-[0.75rem] text-primary hover:underline"
                  href={role === "administrator" ? "/staff/notifications" : "/staff/notifications"}
                  onClick={() => setNotificationsOpen(false)}
                >
                  View all
                </Link>
              </div>
              <ul className="max-h-80 divide-y divide-line overflow-y-auto">
                {notifications.length === 0 ? (
                  <li className="px-3 py-6 text-center text-[0.8125rem] text-muted">
                    No notifications yet.
                  </li>
                ) : (
                  notifications.slice(0, 8).map((notification) => (
                    <li key={notification.id} className="px-3 py-2.5">
                      <div className="flex items-start gap-2">
                        {!notification.read ? (
                          <span className="mt-1.5 h-1.5 w-1.5 shrink-0 rounded-full bg-secondary-500" />
                        ) : (
                          <span className="mt-1.5 h-1.5 w-1.5 shrink-0 rounded-full bg-line-strong" />
                        )}
                        <div>
                          <p className="text-[0.8125rem] font-medium text-ink">
                            {notification.title}
                          </p>
                          <p className="mt-0.5 line-clamp-2 text-[0.75rem] text-muted">
                            {notification.message}
                          </p>
                          <p className="mt-1 text-[0.6875rem] text-muted">
                            {relativeTime(notification.created_at)}
                          </p>
                        </div>
                      </div>
                    </li>
                  ))
                )}
              </ul>
            </div>
          ) : null}
        </div>

        <div className="relative">
          <button
            type="button"
            className="flex items-center gap-2 rounded-lg border border-line px-2 py-1.5 text-left hover:bg-page"
            onClick={() => {
              setMenuOpen((open) => !open);
              setNotificationsOpen(false);
            }}
          >
            <span className="grid h-7 w-7 place-items-center rounded-full bg-primary-50 text-[0.6875rem] font-semibold text-primary-700">
              {initials(fullName)}
            </span>
            <span className="hidden leading-tight sm:block">
              <span className="block text-[0.75rem] font-medium text-ink">{fullName}</span>
              <span className="block text-[0.6875rem] text-muted">{roleLabel(role)}</span>
            </span>
            <ChevronDown className="h-3.5 w-3.5 text-muted" />
          </button>

          {menuOpen ? (
            <div className="absolute right-0 mt-2 w-64 rounded-lg border border-line bg-white shadow-raised">
              <div className="border-b border-line px-3 py-2.5">
                <p className="text-[0.8125rem] font-medium text-ink">{fullName}</p>
                <p className="truncate text-[0.75rem] text-muted">{email}</p>
              </div>
              <button
                type="button"
                onClick={signOut}
                className="flex w-full items-center gap-2 px-3 py-2.5 text-left text-[0.8125rem] text-ink hover:bg-page"
              >
                <LogOut className="h-4 w-4 text-muted" />
                Sign out
              </button>
            </div>
          ) : null}
        </div>
      </div>
    </header>
  );
}
