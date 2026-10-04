import { describe, expect, it } from "vitest";

import { can, homePathForRole, isStaffRole } from "./permissions";

describe("capability matrix", () => {
  it("lets administrators manage users and settings", () => {
    expect(can("administrator", "users.manage")).toBe(true);
    expect(can("administrator", "settings.manage")).toBe(true);
    expect(can("administrator", "logs.view_all")).toBe(true);
    expect(can("administrator", "analytics.view_system_health")).toBe(true);
  });

  it("lets staff process applications but not administer the system", () => {
    expect(can("staff", "applications.review")).toBe(true);
    expect(can("staff", "applications.approve")).toBe(true);
    expect(can("staff", "records.generate_certificate")).toBe(true);

    expect(can("staff", "users.manage")).toBe(false);
    expect(can("staff", "settings.manage")).toBe(false);
    expect(can("staff", "analytics.view_system_health")).toBe(false);
  });

  it("gives a driver no web capability at all", () => {
    expect(can("driver", "applications.approve")).toBe(false);
    expect(can("driver", "records.view_all")).toBe(false);
    expect(can("driver", "ai.request")).toBe(false);
  });

  it("denies everything without a role", () => {
    expect(can(null, "applications.review")).toBe(false);
    expect(can(undefined, "dashboard.view")).toBe(false);
  });

  it("treats only staff and administrators as back-office roles", () => {
    expect(isStaffRole("administrator")).toBe(true);
    expect(isStaffRole("staff")).toBe(true);
    expect(isStaffRole("driver")).toBe(false);
    expect(isStaffRole(null)).toBe(false);
  });

  it("routes each role to its own landing page", () => {
    expect(homePathForRole("administrator")).toBe("/admin");
    expect(homePathForRole("staff")).toBe("/staff");
    expect(homePathForRole("driver")).toBe("/unauthorized");
    expect(homePathForRole(null)).toBe("/unauthorized");
  });
});
