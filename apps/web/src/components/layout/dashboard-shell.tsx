import type { ReactNode } from "react";

import { Sidebar } from "@/components/layout/sidebar";
import { Topbar } from "@/components/layout/topbar";
import { RealtimeRefresher } from "@/components/realtime-refresher";
import { listNotifications } from "@/lib/data";
import type { SessionContext } from "@/lib/data";
import { isDemoMode } from "@/lib/env";

/**
 * Shared chrome for the administrator and staff consoles.
 */
export async function DashboardShell({
  session,
  children,
}: {
  session: SessionContext;
  children: ReactNode;
}) {
  const notifications = await listNotifications(12);
  const unread = notifications.filter((notification) => !notification.read).length;

  return (
    <div className="flex min-h-screen bg-page">
      <Sidebar role={session.role} unreadCount={unread} />

      <div className="flex min-w-0 flex-1 flex-col">
        <Topbar
          fullName={session.profile.full_name}
          role={session.role}
          email={session.profile.email}
          notifications={notifications}
        />

        {isDemoMode() ? (
          <div className="border-b border-amber-200 bg-warning-50 px-4 py-2 text-[0.75rem] text-warning-600 lg:px-6">
            <strong className="font-semibold">Preview mode.</strong> Sample data is shown and every
            write action is disabled. Set <code>NEXT_PUBLIC_DEMO_MODE=false</code> and configure
            Supabase to use the live system.
          </div>
        ) : null}

        <main className="mx-auto w-full max-w-[1400px] flex-1 px-4 py-6 lg:px-8">{children}</main>

        <footer className="border-t border-line bg-white px-4 py-3 text-center text-[0.6875rem] text-muted lg:px-8">
          SBTF System — Municipality of Mabini, Batangas · Franchising and Tricycle Driver
          Registration with Descriptive and Prescriptive Analytics
        </footer>
      </div>

      {/* Live updates for notifications and application decisions. */}
      <RealtimeRefresher />
    </div>
  );
}
