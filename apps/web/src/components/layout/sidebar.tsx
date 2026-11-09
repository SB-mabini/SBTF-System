import { BrandMark } from "@/components/layout/brand-mark";
import { NavPanel } from "@/components/layout/nav-panel";
import type { UserRole } from "@/types/database";

/**
 * Desktop sidebar (lg and wider).
 *
 * The destinations are grouped by function in `lib/navigation.ts`; the same
 * groups feed the tablet/laptop drawer and the phone "More" sheet.
 */
export function Sidebar({
  role,
  unreadCount,
}: {
  role: UserRole;
  unreadCount: number;
}) {
  return (
    <aside className="sticky top-0 z-30 hidden h-screen w-64 shrink-0 flex-col border-r border-line bg-white lg:flex">
      <div className="flex h-16 shrink-0 items-center gap-2.5 border-b border-line px-5">
        <BrandMark size="sm" priority />
        <div className="leading-tight">
          <p className="text-[0.8125rem] font-semibold text-ink">SBTF System</p>
          <p className="text-[0.6875rem] text-muted">Mabini, Batangas</p>
        </div>
      </div>

      <div className="min-h-0 flex-1 overflow-y-auto">
        <NavPanel role={role} unreadCount={unreadCount} />
      </div>

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
