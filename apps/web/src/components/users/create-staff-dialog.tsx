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
 * No e-mail is sent. The Edge Function returns the password-setup link and the
 * administrator passes it on by hand; see the comment in
 * supabase/functions/admin-users/index.ts for why.
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
  const [role, setRole] = useState<"staff" | "administrator">("staff");

  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);
  const [setupLink, setSetupLink] = useState<string | null>(null);

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
    setRole("staff");
    setError(null);
    setMessage(null);
    setSetupLink(null);
    setBusy(false);
    onClose();
  }

  async function submit() {
    setBusy(true);
    setError(null);
    setMessage(null);
    setSetupLink(null);

    const result = await createStaffUserAction({
      email,
      firstName,
      lastName,
      contactNumber,
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

    if (!link) {
      // The account exists but no link came back; keep the dialog open so the
      // administrator reads the fallback instruction before closing.
      return;
    }
  }

  return (
    <Modal
      open={open}
      title="Create a municipal account"
      description="Staff and administrator accounts are created here. Drivers and operators register themselves in the mobile application."
      onClose={handleClose}
      width="lg"
      footer={
        setupLink ? (
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
              Create account
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
          <Alert tone="success" title="Account created">
            {message}
          </Alert>

          <CopyLinkField
            label="Password setup link"
            value={setupLink}
            hint="Send this to the new user through whatever channel the office uses. It works once, it is not stored anywhere in the system, and it can be replaced at any time with “Send password reset”."
          />

          <div className="rounded-lg bg-page px-3.5 py-3 text-[0.75rem] text-muted">
            <p className="font-medium text-ink">What the new user sees</p>
            <ol className="mt-1 list-decimal space-y-1 pl-4">
              <li>They open the link and choose their own password.</li>
              <li>They sign in at /login with the e-mail address above.</li>
              <li>
                The role is already set — it lives in the Supabase Auth app metadata and is read
                from there on every sign-in.
              </li>
            </ol>
          </div>
        </div>
      ) : (
        <div className="space-y-3">
          {message ? <Alert tone="warning">{message}</Alert> : null}

          <div className="grid gap-3 sm:grid-cols-2">
            <Field label="First name" htmlFor="staff-first-name">
              <input
                id="staff-first-name"
                className="sbtf-input"
                value={firstName}
                autoComplete="off"
                onChange={(event) => setFirstName(event.target.value)}
              />
            </Field>
            <Field label="Last name" htmlFor="staff-last-name">
              <input
                id="staff-last-name"
                className="sbtf-input"
                value={lastName}
                autoComplete="off"
                onChange={(event) => setLastName(event.target.value)}
              />
            </Field>
          </div>

          <Field
            label="Official e-mail address"
            htmlFor="staff-email"
            hint="The address the account signs in with. It must be one the office can reach."
          >
            <input
              id="staff-email"
              className="sbtf-input"
              type="email"
              autoComplete="off"
              value={email}
              onChange={(event) => setEmail(event.target.value)}
              placeholder="name@mabini.gov.ph"
            />
          </Field>

          <Field label="Contact number (optional)" htmlFor="staff-contact">
            <input
              id="staff-contact"
              className="sbtf-input"
              value={contactNumber}
              autoComplete="off"
              onChange={(event) => setContactNumber(event.target.value)}
              placeholder="09XX XXX XXXX"
            />
          </Field>

          <Field label="Role" htmlFor="staff-role">
            <select
              id="staff-role"
              className="sbtf-input"
              value={role}
              onChange={(event) => setRole(event.target.value as "staff" | "administrator")}
            >
              <option value="staff">Staff — processing, verification, decisions, records</option>
              <option value="administrator">
                Administrator — full oversight, users, settings, analytics
              </option>
            </select>
          </Field>

          <div className="rounded-lg bg-page px-3.5 py-3 text-[0.75rem] text-muted">
            <p className="font-medium text-ink">No e-mail is sent</p>
            <p className="mt-1">
              The system creates the account and hands the password-setup link back to you in this
              dialog. Supabase&apos;s built-in mailer is rate-limited and on a project without SMTP
              often only reaches addresses already on the project team, so an invitation left to it
              would silently never arrive. Passing the link on yourself is the reliable path.
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
