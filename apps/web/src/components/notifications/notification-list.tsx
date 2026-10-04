"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { Bell, CheckCheck, Inbox } from "lucide-react";

import { Alert, Button, Card, EmptyState } from "@/components/ui";
import {
  markAllNotificationsReadAction,
  markNotificationReadAction,
} from "@/lib/actions/notifications";
import { formatDateTime, humanizeKey } from "@/lib/format";
import { isDemoMode } from "@/lib/env";
import type { Notification } from "@/types/database";

const TYPE_LABELS: Record<string, string> = {
  application_submitted: "Application submitted",
  application_approved: "Application approved",
  application_rejected: "Application rejected",
  document_verified: "Document verified",
  document_rejected: "Document rejected",
  renewal_reminder: "Renewal reminder",
  application_under_review: "Application under review",
  account_updated: "Account updated",
  system: "System",
};

export function NotificationList({
  notifications,
  basePath,
}: {
  notifications: Notification[];
  basePath: "/admin" | "/staff";
}) {
  const router = useRouter();
  const [, startTransition] = useTransition();
  const [busy, setBusy] = useState<string | null>(null);
  const [message, setMessage] = useState<{ ok: boolean; text: string } | null>(null);
  const readOnly = isDemoMode();

  const unread = notifications.filter((notification) => !notification.read);

  async function markRead(id: string) {
    setBusy(id);
    const result = await markNotificationReadAction(id);
    setBusy(null);
    setMessage({ ok: result.ok, text: result.message });
    if (result.ok) startTransition(() => router.refresh());
  }

  async function markAll() {
    setBusy("all");
    const result = await markAllNotificationsReadAction();
    setBusy(null);
    setMessage({ ok: result.ok, text: result.message });
    if (result.ok) startTransition(() => router.refresh());
  }

  if (notifications.length === 0) {
    return (
      <EmptyState
        title="No notifications yet"
        description="Applications, decisions, document remarks, renewal reminders and account changes appear here."
        icon={Inbox}
      />
    );
  }

  return (
    <div className="space-y-3">
      {message ? <Alert tone={message.ok ? "success" : "danger"}>{message.text}</Alert> : null}

      <div className="flex flex-wrap items-center justify-between gap-2">
        <p className="text-[0.8125rem] text-muted">
          {unread.length === 0
            ? "Everything has been read."
            : `${unread.length} unread notification(s).`}
        </p>
        <Button variant="outline" onClick={markAll} loading={busy === "all"} disabled={readOnly || unread.length === 0}>
          <CheckCheck className="h-4 w-4" />
          Mark all as read
        </Button>
      </div>

      <ul className="space-y-2">
        {notifications.map((notification) => (
          <li key={notification.id}>
            <Card className={notification.read ? "" : "border-primary-200 bg-primary-50/40"}>
              <div className="flex items-start gap-3">
                <span
                  className={`mt-0.5 rounded-md p-2 ${
                    notification.read ? "bg-page text-muted" : "bg-primary-100 text-primary-700"
                  }`}
                >
                  <Bell className="h-4 w-4" />
                </span>

                <div className="min-w-0 flex-1">
                  <div className="flex flex-wrap items-center gap-2">
                    <p className="text-[0.875rem] font-semibold text-ink">{notification.title}</p>
                    <span className="rounded-full border border-line px-2 py-0.5 text-[0.6875rem] text-muted">
                      {TYPE_LABELS[notification.notification_type] ?? humanizeKey(notification.notification_type)}
                    </span>
                    {notification.read ? null : (
                      <span className="rounded-full bg-primary px-2 py-0.5 text-[0.6875rem] font-medium text-white">
                        New
                      </span>
                    )}
                  </div>

                  <p className="mt-1 text-[0.8125rem] text-ink">{notification.message}</p>
                  <p className="mt-1 text-[0.75rem] text-muted">
                    {formatDateTime(notification.created_at)}
                    {notification.read && notification.read_at
                      ? ` · read ${formatDateTime(notification.read_at)}`
                      : ""}
                  </p>

                  <div className="mt-2 flex flex-wrap items-center gap-3">
                    {notification.target_type === "franchise_application" && notification.target_id ? (
                      <Link
                        className="text-[0.8125rem] font-medium text-primary hover:underline"
                        href={`${basePath}/applications/${notification.target_id}`}
                      >
                        Open application
                      </Link>
                    ) : null}
                    {notification.target_type === "franchise_record" && notification.target_id ? (
                      <Link
                        className="text-[0.8125rem] font-medium text-primary hover:underline"
                        href={`${basePath}/franchises/${notification.target_id}`}
                      >
                        Open franchise record
                      </Link>
                    ) : null}

                    {notification.read ? null : (
                      <Button
                        variant="ghost"
                        onClick={() => markRead(notification.id)}
                        loading={busy === notification.id}
                        disabled={readOnly}
                      >
                        Mark as read
                      </Button>
                    )}
                  </div>
                </div>
              </div>
            </Card>
          </li>
        ))}
      </ul>
    </div>
  );
}
