"use client";

import { useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { Archive, Megaphone, Pencil, Plus, Send, Trash2, Users } from "lucide-react";

import { ConfirmDialog, Modal } from "@/components/dialog";
import { Alert, Badge, Button, Card, CardHeader, EmptyState, Field } from "@/components/ui";
import {
  deleteAnnouncementAction,
  saveAnnouncementAction,
} from "@/lib/actions/announcements";
import {
  ANNOUNCEMENT_AUDIENCE_LABELS,
  ANNOUNCEMENT_STATUS_LABELS,
} from "@/lib/constants";
import { formatDateTime } from "@/lib/format";
import type {
  Announcement,
  AnnouncementAudience,
  AnnouncementStatus,
  Profile,
  Toda,
} from "@/types/database";

const STATUS_TONE: Record<AnnouncementStatus, "neutral" | "success" | "warning"> = {
  draft: "neutral",
  published: "success",
  archived: "warning",
};

function describeAudience(item: Announcement, todas: Toda[], drivers: Profile[]): string {
  if (item.audience === "all_drivers" || item.audience === "all_members") {
    return ANNOUNCEMENT_AUDIENCE_LABELS[item.audience];
  }
  const todaNames = (item.targets ?? [])
    .map((target) => todas.find((toda) => toda.id === target.toda_id)?.name)
    .filter(Boolean) as string[];
  const driverNames = (item.targets ?? [])
    .map((target) => drivers.find((driver) => driver.id === target.profile_id)?.full_name)
    .filter(Boolean) as string[];

  const names = item.audience === "toda" ? todaNames : driverNames;
  if (names.length === 0) return ANNOUNCEMENT_AUDIENCE_LABELS[item.audience];
  if (names.length <= 2) return names.join(", ");
  return `${names.slice(0, 2).join(", ")} +${names.length - 2} more`;
}

interface Draft {
  id: string | null;
  title: string;
  body: string;
  audience: AnnouncementAudience;
  todaIds: string[];
  profileIds: string[];
}

const EMPTY_DRAFT: Draft = {
  id: null,
  title: "",
  body: "",
  audience: "all_drivers",
  todaIds: [],
  profileIds: [],
};

export function AnnouncementManager({
  announcements,
  todas,
  drivers,
}: {
  announcements: Announcement[];
  todas: Toda[];
  drivers: Profile[];
}) {
  const router = useRouter();
  const [filter, setFilter] = useState<AnnouncementStatus | "all">("all");
  const [search, setSearch] = useState("");
  const [draft, setDraft] = useState<Draft | null>(null);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState<{ ok: boolean; text: string } | null>(null);
  const [confirmDelete, setConfirmDelete] = useState<Announcement | null>(null);

  const rows = useMemo(() => {
    const term = search.trim().toLowerCase();
    return announcements.filter((item) => {
      if (filter !== "all" && item.status !== filter) return false;
      if (term && !`${item.title} ${item.body}`.toLowerCase().includes(term)) return false;
      return true;
    });
  }, [announcements, filter, search]);

  function openNew() {
    setMessage(null);
    setDraft({ ...EMPTY_DRAFT });
  }

  function openEdit(item: Announcement) {
    setMessage(null);
    setDraft({
      id: item.id,
      title: item.title,
      body: item.body,
      audience: item.audience,
      todaIds: (item.targets ?? []).map((target) => target.toda_id).filter(Boolean) as string[],
      profileIds: (item.targets ?? []).map((target) => target.profile_id).filter(Boolean) as string[],
    });
  }

  async function save(status: AnnouncementStatus, existing?: Announcement) {
    if (busy) return;
    const source: Draft | null = existing
      ? {
          id: existing.id,
          title: existing.title,
          body: existing.body,
          audience: existing.audience,
          todaIds: (existing.targets ?? []).map((t) => t.toda_id).filter(Boolean) as string[],
          profileIds: (existing.targets ?? []).map((t) => t.profile_id).filter(Boolean) as string[],
        }
      : draft;
    if (!source) return;

    setBusy(true);
    setMessage(null);
    const result = await saveAnnouncementAction({
      id: source.id,
      title: source.title,
      body: source.body,
      audience: source.audience,
      todaIds: source.todaIds,
      profileIds: source.profileIds,
      status,
    });
    setBusy(false);
    setMessage({ ok: result.ok, text: result.message });
    if (result.ok) {
      setDraft(null);
      router.refresh();
    }
  }

  async function remove(item: Announcement) {
    setBusy(true);
    const result = await deleteAnnouncementAction(item.id);
    setBusy(false);
    setConfirmDelete(null);
    setMessage({ ok: result.ok, text: result.message });
    if (result.ok) router.refresh();
  }

  return (
    <div className="space-y-4">
      {message ? (
        <Alert tone={message.ok ? "success" : "danger"}>{message.text}</Alert>
      ) : null}

      <Card>
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div className="flex flex-wrap gap-1.5" role="group" aria-label="Filter by status">
            {(["all", "draft", "published", "archived"] as const).map((value) => (
              <button
                key={value}
                type="button"
                onClick={() => setFilter(value)}
                aria-pressed={filter === value}
                className={`rounded-full border px-3 py-1 text-[0.75rem] font-medium transition-colors ${
                  filter === value
                    ? "border-primary bg-primary text-white"
                    : "border-line bg-white text-muted hover:bg-page"
                }`}
              >
                {value === "all" ? "All" : ANNOUNCEMENT_STATUS_LABELS[value]}
              </button>
            ))}
          </div>
          <div className="flex flex-1 items-center justify-end gap-2">
            <input
              value={search}
              onChange={(event) => setSearch(event.target.value)}
              placeholder="Search announcements"
              aria-label="Search announcements"
              className="sbtf-input max-w-xs"
            />
            <Button onClick={openNew}>
              <Plus className="h-4 w-4" /> New announcement
            </Button>
          </div>
        </div>
      </Card>

      {rows.length === 0 ? (
        <Card>
          <EmptyState
            title="No announcements here yet"
            description="Create an announcement to reach all drivers, TODA members or selected drivers. Published announcements also appear in the notification feed."
            icon={Megaphone}
          />
        </Card>
      ) : (
        <div className="space-y-3">
          {rows.map((item) => (
            <Card key={item.id}>
              <CardHeader
                title={item.title}
                description={`${describeAudience(item, todas, drivers)} · ${
                  item.recipient_count
                } recipient${item.recipient_count === 1 ? "" : "s"}`}
                icon={Megaphone}
                action={
                  <Badge tone={STATUS_TONE[item.status]}>
                    {ANNOUNCEMENT_STATUS_LABELS[item.status]}
                  </Badge>
                }
              />
              <p className="whitespace-pre-line text-[0.875rem] leading-relaxed text-ink">
                {item.body}
              </p>
              <div className="mt-4 flex flex-wrap items-center justify-between gap-3 border-t border-line pt-3">
                <p className="text-[0.75rem] text-muted">
                  {item.published_at
                    ? `Published ${formatDateTime(item.published_at)}`
                    : `Created ${formatDateTime(item.created_at)}`}
                  {item.author_name ? ` · ${item.author_name}` : ""}
                </p>
                <div className="flex flex-wrap gap-2">
                  <Button variant="outline" onClick={() => openEdit(item)}>
                    <Pencil className="h-4 w-4" /> Edit
                  </Button>
                  {item.status !== "published" ? (
                    <Button
                      loading={busy}
                      onClick={() => save("published", item)}
                      title={
                        (item.targets ?? []).length === 0 &&
                        (item.audience === "toda" || item.audience === "drivers")
                          ? "Add recipients first by editing this announcement"
                          : undefined
                      }
                    >
                      <Send className="h-4 w-4" /> Publish
                    </Button>
                  ) : null}
                  {item.status === "published" ? (
                    <Button variant="secondary" loading={busy} onClick={() => save("archived", item)}>
                      <Archive className="h-4 w-4" /> Archive
                    </Button>
                  ) : null}
                  <Button variant="danger" onClick={() => setConfirmDelete(item)}>
                    <Trash2 className="h-4 w-4" /> Delete
                  </Button>
                </div>
              </div>
            </Card>
          ))}
        </div>
      )}

      <Modal
        open={draft !== null}
        title={draft?.id ? "Edit announcement" : "New announcement"}
        description="Published announcements are delivered through the existing notification feed, so every driver sees them in one place."
        onClose={() => setDraft(null)}
        width="lg"
        footer={
          <>
            <Button variant="outline" onClick={() => setDraft(null)} disabled={busy}>
              Cancel
            </Button>
            <Button variant="secondary" loading={busy} onClick={() => save("draft")}>
              Save draft
            </Button>
            <Button loading={busy} onClick={() => save("published")}>
              <Send className="h-4 w-4" /> Publish
            </Button>
          </>
        }
      >
        {draft ? (
          <div className="space-y-4">
            <Field label="Title" htmlFor="announcement-title">
              <input
                id="announcement-title"
                className="sbtf-input"
                value={draft.title}
                maxLength={120}
                onChange={(event) => setDraft({ ...draft, title: event.target.value })}
                placeholder="e.g. Franchise renewal window now open"
              />
            </Field>
            <Field
              label="Message"
              htmlFor="announcement-body"
              hint={`${draft.body.length}/4000 characters`}
            >
              <textarea
                id="announcement-body"
                className="sbtf-input min-h-32"
                value={draft.body}
                maxLength={4000}
                onChange={(event) => setDraft({ ...draft, body: event.target.value })}
                placeholder="Write the announcement exactly as drivers should read it."
              />
            </Field>
            <Field label="Recipients" htmlFor="announcement-audience">
              <select
                id="announcement-audience"
                className="sbtf-input"
                value={draft.audience}
                onChange={(event) =>
                  setDraft({ ...draft, audience: event.target.value as AnnouncementAudience })
                }
              >
                {Object.entries(ANNOUNCEMENT_AUDIENCE_LABELS).map(([value, label]) => (
                  <option key={value} value={value}>
                    {label}
                  </option>
                ))}
              </select>
            </Field>

            {draft.audience === "toda" ? (
              <fieldset>
                <legend className="sbtf-label">Select TODAs</legend>
                <div className="max-h-52 space-y-1 overflow-y-auto rounded-lg border border-line p-2">
                  {todas.map((toda) => {
                    const checked = draft.todaIds.includes(toda.id);
                    return (
                      <label
                        key={toda.id}
                        className="flex min-h-9 cursor-pointer items-center gap-2 rounded px-2 text-[0.8125rem] hover:bg-page"
                      >
                        <input
                          type="checkbox"
                          checked={checked}
                          onChange={() =>
                            setDraft({
                              ...draft,
                              todaIds: checked
                                ? draft.todaIds.filter((id) => id !== toda.id)
                                : [...draft.todaIds, toda.id],
                            })
                          }
                        />
                        <span className="text-ink">{toda.name}</span>
                        <span className="ml-auto text-[0.7rem] text-muted">
                          {toda.members_count} members
                        </span>
                      </label>
                    );
                  })}
                </div>
              </fieldset>
            ) : null}

            {draft.audience === "drivers" ? (
              <fieldset>
                <legend className="sbtf-label">Select drivers</legend>
                <div className="max-h-52 space-y-1 overflow-y-auto rounded-lg border border-line p-2">
                  {drivers.map((driver) => {
                    const checked = draft.profileIds.includes(driver.id);
                    return (
                      <label
                        key={driver.id}
                        className="flex min-h-9 cursor-pointer items-center gap-2 rounded px-2 text-[0.8125rem] hover:bg-page"
                      >
                        <input
                          type="checkbox"
                          checked={checked}
                          onChange={() =>
                            setDraft({
                              ...draft,
                              profileIds: checked
                                ? draft.profileIds.filter((id) => id !== driver.id)
                                : [...draft.profileIds, driver.id],
                            })
                          }
                        />
                        <span className="text-ink">{driver.full_name}</span>
                        <span className="ml-auto text-[0.7rem] text-muted">{driver.email}</span>
                      </label>
                    );
                  })}
                </div>
              </fieldset>
            ) : null}

            <p className="flex items-center gap-1.5 text-[0.75rem] text-muted">
              <Users className="h-3.5 w-3.5" />
              {draft.audience === "all_drivers"
                ? "Every active driver account will receive this announcement."
                : draft.audience === "all_members"
                  ? "Every active driver linked to a TODA will receive this announcement."
                  : "Only the selected recipients will see this announcement."}
            </p>
          </div>
        ) : null}
      </Modal>

      <ConfirmDialog
        open={confirmDelete !== null}
        title="Delete announcement?"
        message={`“${confirmDelete?.title ?? ""}” will be removed, along with the notifications already delivered from it. This cannot be undone.`}
        confirmLabel="Delete announcement"
        destructive
        loading={busy}
        onCancel={() => setConfirmDelete(null)}
        onConfirm={() => confirmDelete && remove(confirmDelete)}
      />
    </div>
  );
}
