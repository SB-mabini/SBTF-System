import Link from "next/link";
import { ClipboardList } from "lucide-react";

import { FormRequestActions } from "@/components/form-requests/form-request-actions";
import { Badge, Card, CardHeader, EmptyState, SectionTitle } from "@/components/ui";
import { listFormRequests } from "@/lib/data";
import { APPLICATION_TYPE_LABELS, FORM_REQUEST_STATUS_LABELS } from "@/lib/constants";
import { formatDateTime } from "@/lib/format";
import type { FormRequestStatus } from "@/types/database";

const STATUS_TABS: Array<{ value: FormRequestStatus | "all"; label: string }> = [
  { value: "all", label: "All" },
  { value: "requested", label: "Requested" },
  { value: "issued", label: "Issued" },
  { value: "rejected", label: "Returned" },
  { value: "converted", label: "Converted" },
  { value: "cancelled", label: "Cancelled" },
];

const STATUS_TONE: Record<FormRequestStatus, "info" | "warning" | "success" | "danger" | "neutral"> = {
  requested: "warning",
  issued: "info",
  rejected: "danger",
  converted: "success",
  cancelled: "neutral",
};

export async function FormRequestsPage({
  searchParams,
}: {
  searchParams: Record<string, string | string[] | undefined>;
}) {
  const statusParam = typeof searchParams.status === "string" ? searchParams.status : "all";
  const status = STATUS_TABS.some((tab) => tab.value === statusParam)
    ? (statusParam as FormRequestStatus | "all")
    : "all";

  const result = await listFormRequests({ status });

  return (
    <div className="space-y-5">
      <SectionTitle
        title="Form Requests"
        description="Requests raised by drivers in the mobile app. Issue the form, then link it to the submitted application."
      />

      <div className="flex flex-wrap gap-2">
        {STATUS_TABS.map((tab) => {
          const active = tab.value === status;
          return (
            <Link
              key={tab.value}
              href={tab.value === "all" ? "/staff/form-requests" : `/staff/form-requests?status=${tab.value}`}
              className={`rounded-lg border px-3 py-1.5 text-[0.8125rem] font-medium transition-colors ${
                active
                  ? "border-primary-100 bg-primary-50 text-primary-700"
                  : "border-line-strong bg-white text-muted hover:bg-page hover:text-ink"
              }`}
            >
              {tab.label}
            </Link>
          );
        })}
      </div>

      <Card>
        <CardHeader
          title={`${result.count} request${result.count === 1 ? "" : "s"}`}
          description={status === "all" ? "All statuses" : FORM_REQUEST_STATUS_LABELS[status as FormRequestStatus]}
          icon={ClipboardList}
        />

        {result.rows.length === 0 ? (
          <EmptyState title="No form requests" description="Requests raised by drivers will appear here." />
        ) : (
          <ul className="space-y-3">
            {result.rows.map((request) => (
              <li key={request.id} className="rounded-lg border border-line p-3.5">
                <div className="flex flex-wrap items-start justify-between gap-3">
                  <div className="min-w-0">
                    <div className="flex flex-wrap items-center gap-2">
                      <Link
                        href={`/staff/form-requests/${request.id}`}
                        className="font-mono text-[0.875rem] font-medium text-primary-700 hover:underline"
                      >
                        {request.form_number}
                      </Link>
                      {request.review_due_at && request.status === "requested" ? (
                        <Badge
                          tone={
                            new Date(request.review_due_at).getTime() < Date.now()
                              ? "danger"
                              : "neutral"
                          }
                        >
                          {new Date(request.review_due_at).getTime() < Date.now()
                            ? "Review overdue"
                            : `Review by ${formatDateTime(request.review_due_at)}`}
                        </Badge>
                      ) : null}
                      {request.printed_at ? <Badge tone="success">Printed</Badge> : null}
                    </div>
                    <p className="mt-0.5 text-[0.75rem] text-muted">
                      {request.applicant?.full_name ?? "Unknown applicant"} ·{" "}
                      {request.toda?.name ?? "No TODA"} ·{" "}
                      {APPLICATION_TYPE_LABELS[request.application_type]} · requested{" "}
                      {formatDateTime(request.requested_at)}
                    </p>
                    {request.plate_number ? (
                      <p className="mt-1 text-[0.8125rem] text-ink">
                        {[request.vehicle_make, request.vehicle_model].filter(Boolean).join(" ")} · Plate{" "}
                        {request.plate_number}
                        {request.engine_number ? ` · Engine ${request.engine_number}` : ""}
                      </p>
                    ) : null}
                    {request.purpose ? (
                      <p className="mt-1 text-[0.8125rem] text-ink">{request.purpose}</p>
                    ) : null}
                    {request.rejection_reason ? (
                      <p className="mt-1 text-[0.75rem] text-danger-600">
                        Returned: {request.rejection_reason}
                      </p>
                    ) : null}
                    {request.cancel_reason ? (
                      <p className="mt-1 text-[0.75rem] text-muted">Cancelled: {request.cancel_reason}</p>
                    ) : null}
                  </div>
                  <div className="flex items-center gap-2">
                    <Badge tone={STATUS_TONE[request.status]}>
                      {FORM_REQUEST_STATUS_LABELS[request.status]}
                    </Badge>
                    <Link
                      href={`/staff/form-requests/${request.id}`}
                      className="text-[0.75rem] font-medium text-primary-700 hover:underline"
                    >
                      View
                    </Link>
                  </div>
                </div>

                <div className="mt-3">
                  <FormRequestActions
                    formRequestId={request.id}
                    status={request.status}
                    printed={Boolean(request.printed_at)}
                  />
                </div>
              </li>
            ))}
          </ul>
        )}
      </Card>
    </div>
  );
}
