"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { KeyRound, ShieldCheck, UserCheck, UserX } from "lucide-react";

import { Alert, Badge, Button, Field } from "@/components/ui";
import { Modal } from "@/components/dialog";
import { CopyLinkField } from "@/components/users/copy-link-field";
import {
  sendPasswordResetAction,
  setAccountStatusAction,
  setUserRoleAction,
} from "@/lib/actions/users";
import { isDemoMode } from "@/lib/env";
import { roleLabel } from "@/lib/format";
import type { AccountStatus, Profile, UserRole } from "@/types/database";

const ASSIGNABLE_ROLES: UserRole[] = ["administrator", "staff"];

export function UserActions({
  profile,
  currentProfileId,
}: {
  profile: Profile;
  currentProfileId: string;
}) {
  const router = useRouter();
  const [, startTransition] = useTransition();
  const [message, setMessage] = useState<{ ok: boolean; text: string } | null>(null);
  const [roleOpen, setRoleOpen] = useState(false);
  const [statusOpen, setStatusOpen] = useState(false);
  const [resetOpen, setResetOpen] = useState(false);

  const [role, setRole] = useState<UserRole>(profile.role === "driver" ? "staff" : profile.role);
  const [status, setStatus] = useState<AccountStatus>("inactive");
  const [reason, setReason] = useState("");
  const [busy, setBusy] = useState(false);
  const [resetLink, setResetLink] = useState<string | null>(null);
  const [resetNotice, setResetNotice] = useState<string | null>(null);

  const isSelf = profile.id === currentProfileId;
  const readOnly = isDemoMode();

  function afterSuccess(result: { ok: boolean; message: string }) {
    setMessage({ ok: result.ok, text: result.message });
    setBusy(false);
    if (result.ok) {
      setRoleOpen(false);
      setStatusOpen(false);
      startTransition(() => router.refresh());
    }
  }

  async function applyRole() {
    setBusy(true);
    afterSuccess(await setUserRoleAction({ profileId: profile.id, role }));
  }

  async function applyStatus() {
    setBusy(true);
    afterSuccess(
      await setAccountStatusAction({
        profileId: profile.id,
        status,
        reason: status === "active" ? undefined : reason,
      }),
    );
  }

  async function sendReset() {
    setBusy(true);
    setResetLink(null);
    setResetNotice(null);
    setMessage(null);

    const result = await sendPasswordResetAction({ email: profile.email });
    setBusy(false);

    const link = result.details?.reset_link;

    if (!result.ok) {
      setMessage({ ok: false, text: result.message });
      // The dialog stays open so the failure can be retried in place.
      return;
    }

    setMessage({ ok: true, text: result.message });
    setResetNotice(result.message);

    if (typeof link === "string" && link.length > 0) {
      setResetLink(link);
      // The dialog deliberately stays open: the link is shown here and only here,
      // it is never stored anywhere, so closing early would lose it.
      return;
    }

    // The action succeeded but no link came back (generateLink failed). The
    // message already explains the fallback, so the dialog closes.
    setResetOpen(false);
    startTransition(() => router.refresh());
  }

  return (
    <div className="space-y-3">
      {message ? <Alert tone={message.ok ? "success" : "danger"}>{message.text}</Alert> : null}

      <div className="flex flex-wrap items-center gap-2">
        <Badge tone={profile.account_status === "active" ? "success" : "warning"}>
          {profile.account_status}
        </Badge>
        <Badge tone="neutral">{roleLabel(profile.role)}</Badge>
        {isSelf ? <Badge tone="info">This is your account</Badge> : null}
      </div>

      <div className="flex flex-wrap gap-2">
        <Button
          variant="outline"
          disabled={isSelf || readOnly}
          title={isSelf ? "You cannot change your own role" : undefined}
          onClick={() => setRoleOpen(true)}
        >
          <ShieldCheck className="h-4 w-4" />
          Assign role
        </Button>

        {profile.account_status === "active" ? (
          <Button
            variant="outline"
            disabled={isSelf || readOnly}
            title={isSelf ? "You cannot change your own account status" : undefined}
            onClick={() => {
              setStatus("suspended");
              setStatusOpen(true);
            }}
          >
            <UserX className="h-4 w-4" />
            Deactivate
          </Button>
        ) : (
          <Button
            variant="outline"
            disabled={readOnly}
            onClick={() => {
              setStatus("active");
              setStatusOpen(true);
            }}
          >
            <UserCheck className="h-4 w-4" />
            Activate
          </Button>
        )}

        <Button variant="ghost" disabled={readOnly} onClick={() => setResetOpen(true)}>
          <KeyRound className="h-4 w-4" />
          Send password reset
        </Button>
      </div>

      <p className="text-[0.75rem] text-muted">
        Role and status changes run through administrator-only database functions, are refused when
        the target is your own account or the last active administrator, and are written to the
        activity log.
      </p>

      {/* Role assignment */}
      <Modal
        open={roleOpen}
        title="Assign a role"
        description={`${profile.full_name} currently holds the ${roleLabel(profile.role)} role.`}
        onClose={() => setRoleOpen(false)}
        footer={
          <>
            <Button variant="outline" onClick={() => setRoleOpen(false)} disabled={busy}>
              Cancel
            </Button>
            <Button onClick={applyRole} loading={busy}>
              Save role
            </Button>
          </>
        }
      >
        <Field label="New role" htmlFor="role">
          <select
            id="role"
            className="sbtf-input"
            value={role}
            onChange={(event) => setRole(event.target.value as UserRole)}
          >
            {ASSIGNABLE_ROLES.map((option) => (
              <option key={option} value={option}>
                {roleLabel(option)}
              </option>
            ))}
          </select>
        </Field>
        <p className="mt-2 text-[0.75rem] text-muted">
          The driver/operator role is granted at mobile registration and is not assignable here.
        </p>
      </Modal>

      {/* Account status */}
      <Modal
        open={statusOpen}
        title={status === "active" ? "Activate account" : "Deactivate account"}
        description={
          status === "active"
            ? `Restore access for ${profile.full_name}.`
            : `Block every database request from ${profile.full_name}.`
        }
        onClose={() => setStatusOpen(false)}
        footer={
          <>
            <Button variant="outline" onClick={() => setStatusOpen(false)} disabled={busy}>
              Cancel
            </Button>
            <Button variant={status === "active" ? "primary" : "danger"} onClick={applyStatus} loading={busy}>
              {status === "active" ? "Activate" : "Deactivate"}
            </Button>
          </>
        }
      >
        {status !== "active" ? (
          <>
            <Field label="Status" htmlFor="status">
              <select
                id="status"
                className="sbtf-input"
                value={status}
                onChange={(event) => setStatus(event.target.value as AccountStatus)}
              >
                <option value="suspended">Suspended</option>
                <option value="inactive">Inactive</option>
              </select>
            </Field>
            <div className="mt-3">
              <Field label="Reason (required, recorded in the activity log)" htmlFor="reason">
                <textarea
                  id="reason"
                  className="sbtf-input min-h-[80px]"
                  value={reason}
                  onChange={(event) => setReason(event.target.value)}
                  placeholder="For example: duplicate account created during migration."
                />
              </Field>
            </div>
            <div className="mt-3">
              <Alert tone="warning">
                The account keeps its Supabase Auth session token, but the profile stops resolving,
                so row level security returns no rows and every write is refused.
              </Alert>
            </div>
          </>
        ) : (
          <p className="text-[0.875rem] text-muted">
            The account will be able to sign in again immediately.
          </p>
        )}
      </Modal>

      {/* Password reset */}
      <Modal
        open={resetOpen}
        title="Create a password reset link"
        description={`A single-use recovery link for ${profile.email}.`}
        onClose={() => {
          if (busy) return;
          setResetOpen(false);
          setResetLink(null);
          setResetNotice(null);
        }}
        width={resetLink ? "lg" : "md"}
        footer={
          resetLink ? (
            <Button
              variant="outline"
              onClick={() => {
                setResetOpen(false);
                setResetLink(null);
                setResetNotice(null);
              }}
            >
              Done
            </Button>
          ) : (
            <>
              <Button variant="outline" onClick={() => setResetOpen(false)} disabled={busy}>
                Cancel
              </Button>
              <Button onClick={sendReset} loading={busy} disabled={readOnly}>
                Create link
              </Button>
            </>
          )
        }
      >
        {resetLink ? (
          <div className="space-y-3">
            <Alert tone="success" title="Reset link created">
              {resetNotice ??
                "A new password reset link has been created. No e-mail is sent automatically — copy it and pass it to the account holder yourself."}
            </Alert>

            <CopyLinkField
              label="Password reset link"
              value={resetLink}
              hint="Send this to the account holder through whatever channel the office uses. It is single-use, it is not stored in the system, and it expires; creating a new link invalidates the previous one."
            />

            <p className="text-[0.75rem] text-muted">
              The SBTF System never sees or stores the password itself — only this one-time link is
              returned here.
            </p>
          </div>
        ) : (
          <div className="flex gap-3">
            <span className="mt-0.5 rounded-md bg-primary-50 p-2 text-primary-700">
              <KeyRound className="h-4 w-4" />
            </span>
            <p className="text-[0.875rem] text-ink">
              A single-use recovery link will be generated for {profile.email}. No e-mail is sent
              automatically — the link is shown here so you can pass it on yourself. If the account
              holder can still sign in, they can use “Forgot your password?” on the sign-in page
              instead.
            </p>
          </div>
        )}
      </Modal>
    </div>
  );
}
