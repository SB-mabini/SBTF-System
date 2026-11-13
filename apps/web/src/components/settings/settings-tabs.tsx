"use client";

import { useState, type ReactNode } from "react";

export function SettingsTabs({
  profile,
  system,
}: {
  profile: ReactNode;
  system: ReactNode;
}) {
  const [tab, setTab] = useState<"profile" | "system">("profile");

  const tabs = [
    {
      key: "profile" as const,
      label: "My profile & security",
      description: "Account details, notification preferences and password.",
    },
    {
      key: "system" as const,
      label: "System settings",
      description: "Operational values used by the workflow and reminders.",
    },
  ];

  return (
    <div>
      <div
        role="tablist"
        aria-label="Settings sections"
        className="mb-4 flex flex-wrap gap-1.5 rounded-xl border border-line bg-white p-1.5"
      >
        {tabs.map((item) => (
          <button
            key={item.key}
            role="tab"
            type="button"
            id={`settings-tab-${item.key}`}
            aria-selected={tab === item.key}
            aria-controls={`settings-panel-${item.key}`}
            onClick={() => setTab(item.key)}
            className={`flex-1 rounded-lg px-3 py-2 text-left transition-colors ${
              tab === item.key ? "bg-primary text-white" : "text-muted hover:bg-page"
            }`}
          >
            <span className="block text-[0.8125rem] font-medium">{item.label}</span>
            <span
              className={`block text-[0.7rem] ${tab === item.key ? "text-white/80" : "text-muted"}`}
            >
              {item.description}
            </span>
          </button>
        ))}
      </div>

      <div
        role="tabpanel"
        id="settings-panel-profile"
        aria-labelledby="settings-tab-profile"
        hidden={tab !== "profile"}
      >
        {profile}
      </div>
      <div
        role="tabpanel"
        id="settings-panel-system"
        aria-labelledby="settings-tab-system"
        hidden={tab !== "system"}
      >
        {system}
      </div>
    </div>
  );
}
