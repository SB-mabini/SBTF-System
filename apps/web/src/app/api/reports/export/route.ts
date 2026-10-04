import { NextResponse } from "next/server";
import { Parser } from "json2csv";

import {
  getApplicationTrends,
  getApplicationsByToda,
  getDocumentCompliance,
  getExpiringFranchises,
  getProcessingTime,
  getSessionProfile,
  listActivityLogs,
  listApplications,
  listFranchiseRecords,
  listUsers,
} from "@/lib/data";

/**
 * CSV export for the Reports screen.
 *
 * The export is rendered server-side with the caller's own Supabase session, so
 * row level security applies exactly as it does on screen — an administrator
 * cannot export rows their session could not read, and staff exports never
 * include the user directory.
 */
export const dynamic = "force-dynamic";

type Row = Record<string, unknown>;

const ADMIN_ONLY = new Set(["users"]);

const DATASETS: Record<string, { label: string; adminOnly?: boolean }> = {
  applications: { label: "franchise-applications" },
  records: { label: "franchise-records" },
  activity: { label: "activity-log" },
  users: { label: "user-directory", adminOnly: true },
  toda: { label: "toda-summary" },
  compliance: { label: "document-compliance" },
  expiring: { label: "expiring-franchises" },
  processing: { label: "processing-performance" },
  trends: { label: "monthly-trends" },
};

function scalar(value: unknown): string | number | boolean | null {
  if (value === null || value === undefined) return null;
  if (typeof value === "object") return JSON.stringify(value);
  return value as string | number | boolean;
}

export async function GET(request: Request) {
  const session = await getSessionProfile();
  if (!session) {
    return NextResponse.json({ error: "unauthorised", message: "Sign in first." }, { status: 401 });
  }
  if (session.profile.account_status !== "active") {
    return NextResponse.json({ error: "account_inactive" }, { status: 403 });
  }

  const url = new URL(request.url);
  const dataset = url.searchParams.get("dataset") ?? "applications";
  const specification = DATASETS[dataset];

  if (!specification) {
    return NextResponse.json(
      { error: "unknown_dataset", message: `Unknown dataset. Use one of: ${Object.keys(DATASETS).join(", ")}.` },
      { status: 400 },
    );
  }
  if ((specification.adminOnly || ADMIN_ONLY.has(dataset)) && session.role !== "administrator") {
    return NextResponse.json(
      { error: "forbidden", message: "This export is restricted to administrators." },
      { status: 403 },
    );
  }

  const from = url.searchParams.get("from") ?? undefined;
  const to = url.searchParams.get("to") ?? undefined;
  const status = url.searchParams.get("status") ?? undefined;
  const action = url.searchParams.get("action") ?? undefined;

  let rows: Row[];
  try {
    rows = await loadRows(dataset, { from, to, status, action });
  } catch (error) {
    return NextResponse.json(
      {
        error: "export_failed",
        message: error instanceof Error ? error.message : "The export could not be produced.",
      },
      { status: 500 },
    );
  }

  if (rows.length === 0) {
    return NextResponse.json(
      { error: "empty", message: "There is nothing to export for the selected filters." },
      { status: 404 },
    );
  }

  const fields = Array.from(
    rows.reduce<Set<string>>((keys, row) => {
      Object.keys(row).forEach((key) => keys.add(key));
      return keys;
    }, new Set<string>()),
  );

  // Prepend a byte-order mark so Excel opens the UTF-8 file with the correct
  // encoding, and prefix text fields that Excel would otherwise reinterpret.
  const csv = new Parser({ fields, withBOM: true, defaultValue: "" }).parse(rows);
  const stamp = new Date().toISOString().slice(0, 10);

  return new NextResponse(csv, {
    headers: {
      "content-type": "text/csv; charset=utf-8",
      "content-disposition": `attachment; filename="sbtf-${specification.label}-${stamp}.csv"`,
      "cache-control": "no-store",
    },
  });
}

async function loadRows(
  dataset: string,
  filters: { from?: string; to?: string; status?: string; action?: string },
): Promise<Row[]> {
  switch (dataset) {
    case "applications": {
      const result = await listApplications({
        page: 1,
        pageSize: 5000,
        from: filters.from,
        to: filters.to,
        status: (filters.status as never) ?? "all",
      });
      return result.rows.map((application) => ({
        application_number: application.application_number,
        application_type: application.application_type,
        status: application.status,
        submitted_at: application.submitted_at,
        reviewed_at: scalar(application.reviewed_at),
        operator_last_name: application.operator_last_name,
        operator_first_name: application.operator_first_name,
        operator_contact_number: application.operator_contact_number,
        operator_email: scalar(application.operator_email),
        operator_address_line: application.operator_address_line,
        toda: application.toda?.name ?? "",
        plate_number: application.plate_number,
        vehicle: `${application.vehicle_make} ${application.vehicle_model} ${application.vehicle_year}`,
        engine_number: application.engine_number,
        chassis_number: application.chassis_number,
        seating_capacity: application.seating_capacity,
        mtop_number: scalar(application.mtop_number),
        body_number: scalar(application.body_number),
        documents_verified: (application.documents ?? []).filter((d) => d.verification_status === "verified").length,
        documents_rejected: (application.documents ?? []).filter((d) => d.verification_status === "rejected").length,
        rejection_reason: scalar(application.rejection_reason),
      }));
    }

    case "records": {
      const result = await listFranchiseRecords({
        page: 1,
        pageSize: 5000,
        from: filters.from,
        to: filters.to,
        state: "all",
      });
      return result.rows.map((record) => ({
        franchise_number: record.franchise_number,
        verification_code: record.verification_code,
        operator_name: record.operator?.full_name ?? "",
        toda: record.toda?.name ?? "",
        plate_number: record.application?.plate_number ?? "",
        issued_at: record.issued_at,
        expires_at: record.expires_at,
        archived: record.archived,
        archived_at: scalar(record.archived_at),
        archive_reason: scalar(record.archive_reason),
        certificate_generated: Boolean(record.certificate_storage_path),
        renewed_by_record: scalar(record.renewed_by_record_id),
      }));
    }

    case "activity": {
      const result = await listActivityLogs({
        page: 1,
        pageSize: 5000,
        from: filters.from,
        to: filters.to,
        action: (filters.action as never) ?? "all",
      });
      return result.rows.map((log) => ({
        timestamp: log.timestamp,
        actor: log.actor?.full_name ?? "System",
        actor_role: log.actor?.role ?? "",
        action: log.action,
        target_type: log.target_type ?? "",
        target_id: log.target_id ?? "",
        metadata: log.metadata ?? {},
      }));
    }

    case "users": {
      const result = await listUsers({ page: 1, pageSize: 5000 });
      return result.rows.map((profile) => ({
        full_name: profile.full_name,
        email: profile.email,
        role: profile.role,
        account_status: profile.account_status,
        contact_number: scalar(profile.contact_number),
        address_line: scalar(profile.address_line),
        barangay_code: scalar(profile.barangay_code),
        registered_at: profile.created_at,
        last_sign_in: scalar(profile.last_login_at),
        status_reason: scalar(profile.status_reason),
      }));
    }

    case "toda": {
      const rows = await getApplicationsByToda();
      return rows.map((row) => ({
        toda: row.toda_name,
        members: row.members_count,
        applications: row.applications,
        new_applications: row.new_applications,
        renewal_applications: row.renewal_applications,
        approved: row.approved,
        pending: row.pending,
        rejected: row.rejected,
        active_franchises: row.active_franchises,
        approval_rate: scalar(row.approval_rate),
        last_submission_at: scalar(row.last_submission_at),
      }));
    }

    case "compliance": {
      const rows = await getDocumentCompliance();
      return rows.map((row) => ({
        document_type: row.document_type,
        total: row.total,
        verified: row.verified,
        pending: row.pending,
        rejected: row.rejected,
        verified_rate: scalar(row.verified_rate),
        oldest_pending_days: scalar(row.oldest_pending_days),
      }));
    }

    case "expiring": {
      const rows = await getExpiringFranchises(180);
      return rows.map((row) => ({
        franchise_number: row.franchise_number,
        operator_name: row.operator_name,
        toda: row.toda_name ?? "",
        expires_at: row.expires_at,
        days_remaining: row.days_remaining,
        bucket: row.bucket,
      }));
    }

    case "processing": {
      const rows = await getProcessingTime(24);
      return rows.map((row) => ({
        month: row.month_label,
        decided: row.decided,
        approved: row.approved,
        rejected: row.rejected,
        average_days: scalar(row.avg_days),
        median_days: scalar(row.median_days),
        p90_days: scalar(row.p90_days),
        longest_days: scalar(row.longest_days),
      }));
    }

    case "trends": {
      const rows = await getApplicationTrends(24);
      return rows.map((row) => ({
        month: row.month_label,
        submitted: row.submitted,
        new_applications: row.new_count,
        renewals: row.renewal_count,
        approved: row.approved,
        rejected: row.rejected,
        decided: row.decided,
        average_process_days: scalar(row.avg_process_days),
      }));
    }

    default:
      return [];
  }
}
