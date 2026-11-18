"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { Save } from "lucide-react";

import { Alert, Button, Field } from "@/components/ui";
import { updateOperatorDetailsAction } from "@/lib/actions/operators";
import { isDemoMode } from "@/lib/env";
import type { Barangay, Profile } from "@/types/database";

/**
 * The minimal administrator edit surface for an operator account.
 *
 * Name, e-mail, TODA, role and account status are rendered elsewhere as
 * read-only: they belong to registration, the TODA roster or the audited
 * account-status workflow. Only the descriptive contact fields are mutable
 * here, and the server action re-checks the role before writing.
 */
export function OperatorDetailsForm({
  profile,
  barangays,
}: {
  profile: Profile;
  barangays: Barangay[];
}) {
  const router = useRouter();
  const [, startTransition] = useTransition();
  const readOnly = isDemoMode();

  const [contactNumber, setContactNumber] = useState(profile.contact_number ?? "");
  const [addressLine, setAddressLine] = useState(profile.address_line ?? "");
  const [barangayCode, setBarangayCode] = useState(profile.barangay_code ?? "");
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState<{ ok: boolean; text: string } | null>(null);

  async function save() {
    setBusy(true);
    const result = await updateOperatorDetailsAction({
      profileId: profile.id,
      contactNumber,
      addressLine,
      barangayCode,
    });
    setBusy(false);
    setMessage({ ok: result.ok, text: result.message });
    if (result.ok) startTransition(() => router.refresh());
  }

  return (
    <div>
      {message ? (
        <div className="mb-4">
          <Alert tone={message.ok ? "success" : "danger"}>{message.text}</Alert>
        </div>
      ) : null}

      <div className="grid gap-4 sm:grid-cols-2">
        <Field label="Contact number" htmlFor="operator-contact">
          <input
            id="operator-contact"
            className="sbtf-input"
            value={contactNumber}
            onChange={(event) => setContactNumber(event.target.value)}
            placeholder="0917 123 4567"
            disabled={readOnly}
          />
        </Field>
        <Field label="Barangay" htmlFor="operator-barangay">
          <select
            id="operator-barangay"
            className="sbtf-input"
            value={barangayCode}
            onChange={(event) => setBarangayCode(event.target.value)}
            disabled={readOnly}
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
        <Field label="Address" htmlFor="operator-address">
          <input
            id="operator-address"
            className="sbtf-input"
            value={addressLine}
            onChange={(event) => setAddressLine(event.target.value)}
            placeholder="House number, street, sitio"
            disabled={readOnly}
          />
        </Field>
      </div>

      <p className="mt-3 text-[0.75rem] text-muted">
        The operator&apos;s name, e-mail address, TODA and account status are not editable here.
        The TODA and membership entry are set when the operator registers and are shown for
        reference only; use the Users screen for account status.
      </p>

      <div className="mt-4">
        <Button onClick={save} loading={busy} disabled={readOnly}>
          <Save className="h-4 w-4" />
          Save details
        </Button>
      </div>
    </div>
  );
}
