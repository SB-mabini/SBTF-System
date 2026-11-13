"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { ShieldCheck, Trash2, UserCheck, UserX } from "lucide-react";

import { Alert, Badge, Button, Field } from "@/components/ui";
import { Modal } from "@/components/dialog";
import {
  purgeAccountAction,
  setAccountStatusAction,
  setUserRoleAction,
} from "@/lib/actions/users";
import { isDemoMode } from "@/lib/env";
import { accountStatusLabel, roleLabel } from "@/lib/format";
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
  const [deleteOpen, setDeleteOpen] = useState(false);

  const [role, setRole] = useState<UserRole>(profile.role === "driver" ? "staff" : profile.role);
  const [status, setStatus] = useState<AccountStatus>("inactive");
  const [reason, setReason] = useState("");
  const [deleteReason, setDeleteReason] = useState("");
  const [deleteConfirm, setDeleteConfirm] = useState("");
  const [busy, setBusy] = useState(false);

  const isSelf = profile.id === currentProfileId;
  const readOnly = isDemoMode();
  // Operators recover access with a one-time password in the mobile app, and a
  // staff account cannot be recovered until an administrator has approved it.
  const isOperator = profile.role === "driver";
  const awaitingApproval = profile.role === "staff" && profile.account_status !== "active";

  function afterSuccess(result: { ok: boolean; message: string }) {
    setMessage({ ok: result.ok, text: result.message });
    setBusy(false);
    if (result.ok) {
      setRoleOpen(false);
      setStatusOpen(false);
      setDeleteOpen(false);
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

  async function applyDelete() {
    setBusy(true);
    afterSuccess(
      await purgeAccountAction({
        profileId: profile.id,
        reason: deleteReason,
      }),
    );
  }

  return (
    <div className="space-y-3">
      {message ? <Alert tone={message.ok ? "success" : "danger"}>{message.text}</Alert> : null}

      <div className="flex flex-wrap items-center gap-2">
        <Badge tone={profile.account_status === "active" ? "success" : "warning"}>
          {accountStatusLabel(profile.account_status)}
        </Badge>
        <Badge tone="neutral">{roleLabel(profile.role)}</Badge>
        {isSelf ? <Badge tone="info">This is your account</Badge> : null}
      </div>

      <div className="flex flex-wrap gap-2">
        {profile.role === "driver" ? null : (
          <Button
            variant="outline"
            disabled={isSelf || readOnly}
            title={isSelf ? "You cannot change your own role" : undefined}
            onClick={() => setRoleOpen(true)}
          >
            <ShieldCheck className="h-4 w-4" />
            Assign role
          </Button>
        )}

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
            {profile.account_status === "pending" ? "Approve account" : "Activate"}
          </Button>
        )}

        {isSelf ? null : (
          <Button
            variant="danger"
            disabled={readOnly}
            onClick={() => {
              setDeleteConfirm("");
              setDeleteReason("");
              setDeleteOpen(true);
            }}
          >
            <Trash2 className="h-4 w-4" />
            Delete account
          </Button>
        )}
      </div>

      {awaitingApproval ? (
        <p className="text-[0.75rem] text-muted">
          This account is awaiting approval. Approve it so the holder can sign in; they set their
          password from the invitation e-mail.
        </p>
      ) : isOperator ? (
        <p className="text-[0.75rem] text-muted">
          Drivers and operators recover access with the one-time password option in the SBTF mobile
          app; no recovery link is issued from this console.
        </p>
      ) : (
        <p className="text-[0.75rem] text-muted">
          Role and status changes run through administrator-only database functions, are refused when
          the target is your own account or the last active administrator, and are written to the
          activity log.
        </p>
      )}

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

      {/* Permanent deletion */}
      <Modal
        open={deleteOpen}
        title="Delete account permanently"
        description={`Erase ${profile.full_name} and everything connected to ${profile.email}.`}
        onClose={() => setDeleteOpen(false)}
        footer={
          <>
            <Button variant="outline" onClick={() => setDeleteOpen(false)} disabled={busy}>
              Cancel
            </Button>
            <Button
              variant="danger"
              onClick={applyDelete}
              loading={busy}
              disabled={
                deleteConfirm.trim().toLowerCase() !== profile.email.toLowerCase() ||
                deleteReason.trim().length < 5
              }
            >
              Delete permanently
            </Button>
          </>
        }
      >
        <Alert tone="danger">
          This cannot be undone. The account, its franchise applications, records, documents,
          notifications and audit-log entries are erased, the stored files are deleted, and the
          Supabase Auth account can no longer sign in.
        </Alert>

        <div className="mt-3 space-y-3">
          <Field
            label={`Type ${profile.email} to confirm`}
            htmlFor="delete-confirm"
          >
            <input
              id="delete-confirm"
              className="sbtf-input"
              value={deleteConfirm}
              onChange={(event) => setDeleteConfirm(event.target.value)}
              autoComplete="off"
              spellCheck={false}
              placeholder={profile.email}
            />
          </Field>

          <Field label="Reason (required, recorded in the admin audit log)" htmlFor="delete-reason">
            <textarea
              id="delete-reason"
              className="sbtf-input min-h-[80px]"
              value={deleteReason}
              onChange={(event) => setDeleteReason(event.target.value)}
              placeholder="For example: duplicate account created during migration."
            />
          </Field>
        </div>

        <p className="mt-3 text-[0.75rem] text-muted">
          {isOperator
            ? "All applications, franchise records, uploaded documents and certificates owned by this operator are removed."
            : "If this staff member has reviewed, verified, issued or released another person's records, deletion is refused to protect that history — deactivate the account instead."}
        </p>
      </Modal>
    </div>
  );
}
