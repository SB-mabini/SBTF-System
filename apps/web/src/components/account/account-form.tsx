"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { KeyRound, Save } from "lucide-react";

import { Alert, Button, Card, CardHeader, Field } from "@/components/ui";
import { updateProfileAction } from "@/lib/actions/profile";
import { sendPasswordResetAction } from "@/lib/actions/users";
import { isDemoMode } from "@/lib/env";
import type { Barangay, Profile } from "@/types/database";

export function AccountForm({
  profile,
  barangays,
}: {
  profile: Profile;
  barangays: Barangay[];
}) {
  const router = useRouter();
  const [, startTransition] = useTransition();
  const readOnly = isDemoMode();

  const [firstName, setFirstName] = useState(profile.first_name);
  const [middleName, setMiddleName] = useState(profile.middle_name ?? "");
  const [lastName, setLastName] = useState(profile.last_name);
  const [contactNumber, setContactNumber] = useState(profile.contact_number ?? "");
  const [addressLine, setAddressLine] = useState(profile.address_line ?? "");
  const [barangayCode, setBarangayCode] = useState(profile.barangay_code ?? "");
  const [emailNotifications, setEmailNotifications] = useState(profile.email_notifications);
  const [renewalReminders, setRenewalReminders] = useState(profile.renewal_reminders);

  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState<{ ok: boolean; text: string } | null>(null);
  const [resetMessage, setResetMessage] = useState<string | null>(null);

  async function save() {
    setBusy(true);
    const result = await updateProfileAction({
      firstName,
      middleName,
      lastName,
      contactNumber,
      addressLine,
      barangayCode,
      emailNotifications,
      renewalReminders,
    });
    setBusy(false);
    setMessage({ ok: result.ok, text: result.message });
    if (result.ok) startTransition(() => router.refresh());
  }

  async function requestReset() {
    setBusy(true);
    const result = await sendPasswordResetAction({ email: profile.email });
    setBusy(false);
    setResetMessage(result.message);
  }

  return (
    <div className="grid gap-4 xl:grid-cols-3">
      <Card className="xl:col-span-2">
        <CardHeader
          title="My details"
          description="Only these descriptive fields can be edited from the interface. Role and account status are changed by an administrator through the audited workflow."
        />

        {message ? (
          <div className="mb-4">
            <Alert tone={message.ok ? "success" : "danger"}>{message.text}</Alert>
          </div>
        ) : null}

        <div className="grid gap-4 sm:grid-cols-3">
          <Field label="First name" htmlFor="first-name">
            <input
              id="first-name"
              className="sbtf-input"
              value={firstName}
              onChange={(event) => setFirstName(event.target.value)}
            />
          </Field>
          <Field label="Middle name" htmlFor="middle-name">
            <input
              id="middle-name"
              className="sbtf-input"
              value={middleName}
              onChange={(event) => setMiddleName(event.target.value)}
            />
          </Field>
          <Field label="Last name" htmlFor="last-name">
            <input
              id="last-name"
              className="sbtf-input"
              value={lastName}
              onChange={(event) => setLastName(event.target.value)}
            />
          </Field>
        </div>

        <div className="mt-4 grid gap-4 sm:grid-cols-2">
          <Field label="Contact number" htmlFor="contact-number">
            <input
              id="contact-number"
              className="sbtf-input"
              value={contactNumber}
              onChange={(event) => setContactNumber(event.target.value)}
              placeholder="0917 123 4567"
            />
          </Field>
          <Field label="Barangay" htmlFor="barangay">
            <select
              id="barangay"
              className="sbtf-input"
              value={barangayCode}
              onChange={(event) => setBarangayCode(event.target.value)}
            >
              <option value="">Not specified</option>
              {barangays.map((barangay) => (
                <option key={barangay.code} value={barangay.code}>
                  {barangay.name}
                </option>
              ))}
            </select>
          </Field>
        </div>

        <div className="mt-4">
          <Field label="Address" htmlFor="address-line">
            <input
              id="address-line"
              className="sbtf-input"
              value={addressLine}
              onChange={(event) => setAddressLine(event.target.value)}
              placeholder="House number, street, sitio"
            />
          </Field>
        </div>

        <fieldset className="mt-4 space-y-2">
          <legend className="sbtf-label">Notification preferences</legend>
          <label className="flex items-center gap-2 text-[0.875rem] text-ink">
            <input
              type="checkbox"
              checked={emailNotifications}
              onChange={(event) => setEmailNotifications(event.target.checked)}
              className="h-4 w-4 rounded border-line-strong"
            />
            E-mail notifications about applications and decisions
          </label>
          <label className="flex items-center gap-2 text-[0.875rem] text-ink">
            <input
              type="checkbox"
              checked={renewalReminders}
              onChange={(event) => setRenewalReminders(event.target.checked)}
              className="h-4 w-4 rounded border-line-strong"
            />
            Renewal reminders at 90, 60 and 30 days before expiry
          </label>
        </fieldset>

        <div className="mt-5 flex gap-3">
          <Button onClick={save} loading={busy} disabled={readOnly}>
            <Save className="h-4 w-4" />
            Save details
          </Button>
          <Button variant="outline" onClick={requestReset} disabled={busy || readOnly}>
            <KeyRound className="h-4 w-4" />
            Send password reset link
          </Button>
        </div>

        {resetMessage ? (
          <div className="mt-3">
            <Alert tone="info">{resetMessage}</Alert>
          </div>
        ) : null}
      </Card>

      <Card>
        <CardHeader title="Account" description="Identity and access are managed by Supabase Auth." />
        <dl className="space-y-2.5 text-[0.8125rem]">
          <Row label="E-mail" value={profile.email} />
          <Row label="Role" value={profile.role} />
          <Row label="Account status" value={profile.account_status} />
          <Row label="Registered" value={new Date(profile.created_at).toLocaleDateString("en-PH")} />
          <Row
            label="Last sign-in"
            value={profile.last_login_at ? new Date(profile.last_login_at).toLocaleString("en-PH") : "—"}
          />
        </dl>
        <p className="mt-3 text-[0.75rem] text-muted">
          The system never stores a password: authentication is delegated to Supabase Auth, and only
          the resulting user identifier is referenced by your profile.
        </p>
      </Card>
    </div>
  );
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex justify-between gap-3">
      <dt className="text-muted">{label}</dt>
      <dd className="text-right font-medium text-ink">{value}</dd>
    </div>
  );
}
