"use client";

import { useState } from "react";
import { UserPlus } from "lucide-react";

import { Modal } from "@/components/dialog";
import { CopyLinkField } from "@/components/users/copy-link-field";
import { Alert, Button, Field } from "@/components/ui";
import { createStaffUserAction } from "@/lib/actions/users";
import { isDemoMode } from "@/lib/env";

/**
 * Creates a staff or administrator account.
 *
 * Self-registration is driver-only by design: the mobile app calls `signUp`, and
 * the profile trigger reads the role from `raw_app_meta_data`, which only the
 * service role can write. This dialog is therefore the ONLY supported way to
 * create a municipal account — it goes through the admin-users Edge Function,
 * which holds the service-role key and sets the role in app metadata itself.
 *
 * The Edge Function sends the invitation through Supabase's SMTP mailer, so the
 * new staff member receives the link directly. The manual-link panel below is a
 * fallback for a project still running an older deployed function; once
 * admin-users is redeployed it never appears.
 */
export function CreateStaffDialog({
  open,
  onClose,
}: {
  open: boolean;
  onClose: () => void;
}) {
  const [firstName, setFirstName] = useState("");
  const [lastName, setLastName] = useState("");
  const [email, setEmail] = useState("");
  const [contactNumber, setContactNumber] = useState("");
  const role = "staff" as const;

  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [fieldErrors, setFieldErrors] = useState<{
    firstName?: string;
    lastName?: string;
    email?: string;
    contactNumber?: string;
  }>({});
  const [message, setMessage] = useState<string | null>(null);
  const [setupLink, setSetupLink] = useState<string | null>(null);
  const [created, setCreated] = useState(false);

  const readOnly = isDemoMode();

  /**
   * The dialog is reset on close rather than on open (a `useEffect` on `open`
   * would set state during the render pass of the newly mounted modal). Closing
   * always returns the component to its initial state, so the next open starts
   * from a clean slate and a stale setup link never sits next to a new one.
   */
  function handleClose() {
    setFirstName("");
    setLastName("");
    setEmail("");
    setContactNumber("");
    setError(null);
    setFieldErrors({});
    setMessage(null);
    setSetupLink(null);
    setCreated(false);
    setBusy(false);
    onClose();
  }

  function validate(): boolean {
    const errors: typeof fieldErrors = {};

    if (!firstName.trim()) {
      errors.firstName = "First name is required.";
    } else if (firstName.trim().length < 2) {
      errors.firstName = "First name must be at least 2 characters.";
    }

    if (!lastName.trim()) {
      errors.lastName = "Last name is required.";
    } else if (lastName.trim().length < 2) {
      errors.lastName = "Last name must be at least 2 characters.";
    }

    const emailTrimmed = email.trim().toLowerCase();
    if (!emailTrimmed) {
      errors.email = "Official e-mail address is required.";
    } else if (!/^[^\s@]+@[^\s@.]+\.[^\s@]+$/.test(emailTrimmed)) {
      errors.email = "Enter a valid official e-mail address (e.g. name@mabini.gov.ph).";
    }

    if (contactNumber.trim()) {
      const cleaned = contactNumber.replace(/[\s-]/g, "");
      if (!/^09\d{9}$/.test(cleaned)) {
        errors.contactNumber = "Must be an 11-digit mobile number starting with 09 (e.g. 0917 123 4567).";
      }
    }

    setFieldErrors(errors);
    return Object.keys(errors).length === 0;
  }

  async function submit() {
    if (!validate()) {
      return;
    }

    setBusy(true);
    setError(null);
    setMessage(null);
    setSetupLink(null);
    setCreated(false);

    const result = await createStaffUserAction({
      email: email.trim().toLowerCase(),
      firstName: firstName.trim(),
      lastName: lastName.trim(),
      contactNumber: contactNumber.trim() || undefined,
      role,
    });

    setBusy(false);

    if (!result.ok) {
      setError(result.message);
      return;
    }

    const link = result.details?.setup_link;
    setMessage(result.message);
    setSetupLink(typeof link === "string" && link.length > 0 ? link : null);
    setCreated(true);
  }

  return (
    <Modal
      open={open}
      title="Add staff account"
      description="Create a municipal staff account for processing, verification, and records."
      onClose={handleClose}
      width="lg"
      footer={
        created ? (
          <Button variant="outline" onClick={handleClose}>
            Done
          </Button>
        ) : (
          <>
            <Button variant="outline" onClick={handleClose} disabled={busy}>
              Cancel
            </Button>
            <Button onClick={submit} loading={busy} disabled={readOnly}>
              <UserPlus className="h-4 w-4" />
              Add staff account
            </Button>
          </>
        )
      }
    >
      {readOnly ? (
        <div className="mb-4">
          <Alert tone="warning" title="Preview mode">
            Preview mode is read-only. Connect a Supabase project to create accounts.
          </Alert>
        </div>
      ) : null}

      {error ? (
        <div className="mb-4">
          <Alert tone="danger">{error}</Alert>
        </div>
      ) : null}

      {setupLink ? (
        <div className="space-y-3">
          <Alert tone="warning" title="Account created — manual link">
            {message}
          </Alert>

          <CopyLinkField
            label="Password setup link"
            value={setupLink}
            hint="This fallback appears only while the deployed admin-users function is older than this console. Send the link through whatever channel the office uses; it works once."
          />

          <div className="rounded-lg bg-page px-3.5 py-3 text-[0.75rem] text-muted">
            <p className="font-medium text-ink">Automatic e-mail is not active yet</p>
            <p className="mt-1">
              The console received a setup link instead of a send confirmation, so the deployed
              Edge Function is still the old manual flow. Redeploy
              <code className="mx-1 rounded bg-white px-1 py-0.5 font-mono">admin-users</code>
              to switch to invitation e-mails.
            </p>
          </div>
        </div>
      ) : created ? (
        <div className="space-y-3">
          <Alert tone="success" title="Invitation e-mail sent">
            {message}
          </Alert>

          <div className="rounded-lg bg-page px-3.5 py-3 text-[0.75rem] text-muted">
            <p className="font-medium text-ink">What happens next</p>
            <ol className="mt-1 list-decimal space-y-1 pl-4">
              <li>
                The new staff member receives the invitation at the e-mail address you entered.
              </li>
              <li>
                They open the link, choose their own password, and are taken to the sign-in screen.
              </li>
              <li>
                Approve the account from the Users list. Until it is approved, signing in shows
                “awaiting approval”.
              </li>
            </ol>
          </div>

          <p className="text-[0.75rem] text-muted">
            If the message has not arrived after a few minutes, ask them to check the spam folder.
            Once the account is approved, the staff member can also use “Forgot your password?” on
            the sign-in page.
          </p>
        </div>
      ) : (
        <div className="space-y-3">
          {message ? <Alert tone="warning">{message}</Alert> : null}

          <div className="grid gap-3 sm:grid-cols-2">
            <Field label="First name" htmlFor="staff-first-name">
              <input
                id="staff-first-name"
                className={`sbtf-input ${fieldErrors.firstName ? "border-secondary-500 focus-visible:outline-secondary-500" : ""}`}
                value={firstName}
                autoComplete="off"
                onChange={(event) => {
                  setFirstName(event.target.value);
                  setFieldErrors((prev) => ({ ...prev, firstName: undefined }));
                }}
                placeholder="e.g. Juan"
              />
              {fieldErrors.firstName ? (
                <p className="mt-1 text-[0.75rem] font-medium text-secondary-600">{fieldErrors.firstName}</p>
              ) : null}
            </Field>
            <Field label="Last name" htmlFor="staff-last-name">
              <input
                id="staff-last-name"
                className={`sbtf-input ${fieldErrors.lastName ? "border-secondary-500 focus-visible:outline-secondary-500" : ""}`}
                value={lastName}
                autoComplete="off"
                onChange={(event) => {
                  setLastName(event.target.value);
                  setFieldErrors((prev) => ({ ...prev, lastName: undefined }));
                }}
                placeholder="e.g. Dela Cruz"
              />
              {fieldErrors.lastName ? (
                <p className="mt-1 text-[0.75rem] font-medium text-secondary-600">{fieldErrors.lastName}</p>
              ) : null}
            </Field>
          </div>

          <Field
            label="Official e-mail address"
            htmlFor="staff-email"
            hint="The address the staff account signs in with. It must be an address reachable by the municipal office."
          >
            <input
              id="staff-email"
              className={`sbtf-input ${fieldErrors.email ? "border-secondary-500 focus-visible:outline-secondary-500" : ""}`}
              type="email"
              autoComplete="off"
              value={email}
              onChange={(event) => {
                setEmail(event.target.value);
                setFieldErrors((prev) => ({ ...prev, email: undefined }));
              }}
              placeholder="name@mabini.gov.ph"
            />
            {fieldErrors.email ? (
              <p className="mt-1 text-[0.75rem] font-medium text-secondary-600">{fieldErrors.email}</p>
            ) : null}
          </Field>

          <Field label="Contact number (optional)" htmlFor="staff-contact">
            <input
              id="staff-contact"
              className={`sbtf-input ${fieldErrors.contactNumber ? "border-secondary-500 focus-visible:outline-secondary-500" : ""}`}
              value={contactNumber}
              autoComplete="off"
              onChange={(event) => {
                setContactNumber(event.target.value);
                setFieldErrors((prev) => ({ ...prev, contactNumber: undefined }));
              }}
              placeholder="0917 123 4567"
            />
            {fieldErrors.contactNumber ? (
              <p className="mt-1 text-[0.75rem] font-medium text-secondary-600">{fieldErrors.contactNumber}</p>
            ) : null}
          </Field>

          <Field
            label="Role"
            htmlFor="staff-role"
            hint="Administrators can only create Staff accounts. New administrator accounts cannot be created here."
          >
            <div className="flex items-center justify-between rounded-lg border border-line bg-page px-3.5 py-2.5">
              <span className="text-sm font-semibold text-primary-700">Staff</span>
              <span className="text-[0.75rem] text-muted">
                Processing, verification, decisions, and records
              </span>
            </div>
          </Field>

          <div className="rounded-lg bg-page px-3.5 py-3 text-[0.75rem] text-muted">
            <p className="font-medium text-ink">Invitation e-mail</p>
            <p className="mt-1">
              The system creates the account and sends an invitation to the address above through
              the project&apos;s Supabase SMTP. The staff member opens the link, sets their own
              password, and is returned to the sign-in screen.
            </p>
            <p className="mt-2">
              Roles live in Supabase Auth app metadata only, which client SDKs cannot write. A
              self-registered account is therefore always a driver, whatever it asks for.
            </p>
          </div>
        </div>
      )}
    </Modal>
  );
}
