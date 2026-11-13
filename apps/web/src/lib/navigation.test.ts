import { describe, expect, it } from "vitest";

import {
  isNavItemActive,
  mobilePrimaryItemsFor,
  navGroupsFor,
  navItemsFor,
} from "./navigation";

describe("navigation", () => {
  it("groups administrator destinations by function", () => {
    const groups = navGroupsFor("administrator");

    expect(groups.map((group) => group.label)).toEqual([
      "Overview",
      "Franchise operations",
      "Insights and reports",
      "Administration",
      "Updates",
    ]);
    expect(groups.flatMap((group) => group.items).map((item) => item.href)).toContain(
      "/admin/settings",
    );
    expect(groups.flatMap((group) => group.items).map((item) => item.href)).toContain(
      "/admin/franchise-editor",
    );
    expect(groups.flatMap((group) => group.items).map((item) => item.href)).toContain(
      "/admin/announcements",
    );
  });

  it("keeps staff service work together and administration out", () => {
    const groups = navGroupsFor("staff");
    const hrefs = groups.flatMap((group) => group.items).map((item) => item.href);

    expect(groups.find((group) => group.label === "Service desk")?.items.map((item) => item.href)).toEqual([
      "/staff/applications",
      "/staff/appointments",
      "/staff/form-requests",
    ]);
    expect(hrefs).not.toContain("/admin/users");
  });

  it("gives the phone four primary tabs and leaves the rest under More", () => {
    const primary = mobilePrimaryItemsFor("administrator");

    expect(primary).toHaveLength(4);
    expect(primary.map((item) => item.href)).toEqual([
      "/admin",
      "/admin/applications",
      "/admin/franchises",
      "/admin/users",
    ]);
    expect(navItemsFor("administrator").length).toBeGreaterThan(primary.length);
  });

  it("matches nested routes but keeps the dashboard exact", () => {
    const dashboard = navItemsFor("staff").find((item) => item.href === "/staff");
    const applications = navItemsFor("staff").find(
      (item) => item.href === "/staff/applications",
    );

    expect(dashboard).toBeDefined();
    expect(applications).toBeDefined();
    expect(isNavItemActive("/staff/applications/abc", applications!)).toBe(true);
    expect(isNavItemActive("/staff/applications/abc", dashboard!)).toBe(false);
    expect(isNavItemActive("/staff", dashboard!)).toBe(true);
  });
});
