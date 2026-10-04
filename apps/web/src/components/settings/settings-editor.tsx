"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { Save } from "lucide-react";

import { Alert, Badge, Button, Card, CardHeader, Field } from "@/components/ui";
import { updateSettingAction } from "@/lib/actions/settings";
import { isDemoMode } from "@/lib/env";
import type { SystemSetting } from "@/types/database";

function toInputValue(setting: SystemSetting): string {
  if (setting.value === null || setting.value === undefined) return "";
  if (Array.isArray(setting.value)) return setting.value.join(", ");
  if (typeof setting.value === "object") return JSON.stringify(setting.value, null, 2);
  return String(setting.value);
}

export function SettingsEditor({ settings }: { settings: SystemSetting[] }) {
  const router = useRouter();
  const [, startTransition] = useTransition();
  const readOnly = isDemoMode();

  const categories: Array<{ key: SystemSetting["category"]; title: string; description: string }> = [
    {
      key: "general",
      title: "Office identity",
      description: "Printed on the certificate and used in notifications.",
    },
    {
      key: "franchise",
      title: "Franchising rules",
      description: "Validity period and numbering. Changing the validity affects franchises issued afterwards only — existing records keep their dates.",
    },
    {
      key: "certificate",
      title: "Certificate",
      description: "Signatory, footer note and the public verification address embedded in the QR code.",
    },
    {
      key: "notifications",
      title: "Notifications and retention",
      description: "Renewal reminder offsets and how long notifications are kept.",
    },
    {
      key: "ai",
      title: "AI decision support",
      description: "Model, switch and the per-user daily request limit. The provider key itself is stored as an Edge Function secret and never appears here.",
    },
  ];

  const [expanded, setExpanded] = useState<Record<string, boolean>>({});

  return (
    <div className="space-y-4">
      {readOnly ? (
        <Alert tone="warning" title="Preview mode">
          Settings are shown as they ship in the database. Connect a Supabase project to change them;
          every change is written to the activity log with the previous and new value.
        </Alert>
      ) : (
        <Alert tone="info" title="Changes are audited">
          Updating a setting writes the key, the previous value and the new value to the activity log,
          together with the administrator who made the change.
        </Alert>
      )}

      {categories.map((category) => {
        const rows = settings.filter((setting) => setting.category === category.key);
        if (rows.length === 0) return null;

        return (
          <Card key={category.key}>
            <CardHeader title={category.title} description={category.description} />
            <div className="space-y-4">
              {rows.map((setting) => (
                <SettingRow
                  key={setting.key}
                  setting={setting}
                  readOnly={readOnly}
                  open={expanded[setting.key] ?? false}
                  onToggle={() =>
                    setExpanded((current) => ({ ...current, [setting.key]: !current[setting.key] }))
                  }
                  onSaved={() => startTransition(() => router.refresh())}
                />
              ))}
            </div>
          </Card>
        );
      })}
    </div>
  );
}

function SettingRow({
  setting,
  readOnly,
  open,
  onToggle,
  onSaved,
}: {
  setting: SystemSetting;
  readOnly: boolean;
  open: boolean;
  onToggle: () => void;
  onSaved: () => void;
}) {
  const [value, setValue] = useState(toInputValue(setting));
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState<{ ok: boolean; text: string } | null>(null);

  const multiline = setting.data_type === "json" || setting.value !== null && typeof setting.value === "object";

  async function save() {
    setBusy(true);
    const result = await updateSettingAction({
      key: setting.key,
      value,
      dataType: setting.data_type,
    });
    setBusy(false);
    setMessage({ ok: result.ok, text: result.message });
    if (result.ok) onSaved();
  }

  return (
    <div className="rounded-lg border border-line p-3.5">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="min-w-0">
          <p className="text-[0.875rem] font-medium text-ink">{setting.label}</p>
          <p className="mt-0.5 font-mono text-[0.6875rem] text-muted">{setting.key}</p>
          <p className="mt-1 text-[0.8125rem] text-muted">{setting.description}</p>
        </div>
        <div className="flex items-center gap-2">
          <Badge tone="neutral">{setting.data_type}</Badge>
          {setting.is_public ? <Badge tone="info">public</Badge> : null}
          <Button variant="ghost" onClick={onToggle}>
            {open ? "Hide" : "Edit"}
          </Button>
        </div>
      </div>

      <p className="mt-2 rounded-md bg-page px-3 py-2 text-[0.8125rem] text-ink">
        Current: <span className="font-medium">{toInputValue(setting) || "—"}</span>
      </p>

      {open ? (
        <div className="mt-3">
          <Field
            label={`New value for ${setting.key}`}
            htmlFor={`setting-${setting.key}`}
            hint={
              setting.data_type === "string_array"
                ? "Comma-separated list, for example: 90, 60, 30"
                : setting.data_type === "json"
                  ? "Valid JSON."
                  : undefined
            }
          >
            {multiline ? (
              <textarea
                id={`setting-${setting.key}`}
                className="sbtf-input min-h-[90px] font-mono text-[0.8125rem]"
                value={value}
                onChange={(event) => setValue(event.target.value)}
              />
            ) : (
              <input
                id={`setting-${setting.key}`}
                className="sbtf-input"
                value={value}
                onChange={(event) => setValue(event.target.value)}
              />
            )}
          </Field>

          <div className="mt-3 flex items-center gap-3">
            <Button onClick={save} loading={busy} disabled={readOnly}>
              <Save className="h-4 w-4" />
              Save setting
            </Button>
            <Button variant="ghost" onClick={() => setValue(toInputValue(setting))} disabled={busy}>
              Reset field
            </Button>
          </div>
        </div>
      ) : null}

      {message ? (
        <div className="mt-3">
          <Alert tone={message.ok ? "success" : "danger"}>{message.text}</Alert>
        </div>
      ) : null}
    </div>
  );
}
