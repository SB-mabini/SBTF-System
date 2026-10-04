/**
 * Preview-mode sample data.
 *
 * Used only when NEXT_PUBLIC_DEMO_MODE=true so the interface can be reviewed
 * without a Supabase project. All values are synthetic and consistent with the
 * anonymised dataset produced by scripts/generate_seed.py: 24 TODAs,
 * 817 TODA members, four documentary requirements and the same status flow.
 */

import type {
  ActivityLog,
  AnalyticsOverview,
  ApplicationStatusHistory,
  Barangay,
  DocumentComplianceRow,
  ExpiringRecord,
  FranchiseApplicationDetail,
  FranchiseDocument,
  FranchiseRecordDetail,
  Notification,
  PrescriptiveIndicator,
  ProcessingTimePoint,
  Profile,
  SystemHealth,
  SystemSetting,
  Toda,
  TodaAnalytics,
  TrendPoint,
} from "@/types/database";
import { REQUIRED_DOCUMENTS } from "@/lib/constants";

const TODAY = new Date("2026-01-05T09:00:00Z");

function iso(daysAgo: number, hour = 9): string {
  const date = new Date(TODAY);
  date.setUTCDate(date.getUTCDate() - daysAgo);
  date.setUTCHours(hour, 0, 0, 0);
  return date.toISOString();
}

function uuid(seed: number): string {
  const hex = seed.toString(16).padStart(12, "0");
  return `00000000-0000-4000-8000-${hex}`;
}

/**
 * Same 32-character alphabet as public.fn_generate_verification_code(): the
 * preview data must never contain a code the verification page would reject.
 */
const VERIFICATION_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";

function verificationCode(seed: number): string {
  // Eight pseudo-random characters for realism, followed by the record index
  // written in base 32 — which guarantees that no two preview records ever
  // share a code.
  let state = (seed + 1) >>> 0;
  let prefix = "";
  for (let index = 0; index < 8; index += 1) {
    state = (state * 1664525 + 1013904223) >>> 0;
    prefix += VERIFICATION_ALPHABET[(state >>> 15) % VERIFICATION_ALPHABET.length];
  }

  let suffix = "";
  let value = seed;
  for (let index = 0; index < 4; index += 1) {
    suffix = VERIFICATION_ALPHABET[value % VERIFICATION_ALPHABET.length] + suffix;
    value = Math.floor(value / VERIFICATION_ALPHABET.length);
  }

  return prefix + suffix;
}

function addMonths(value: string, months: number): string {
  const date = new Date(value);
  date.setUTCMonth(date.getUTCMonth() + months);
  return date.toISOString();
}

const TODA_NAMES: Array<[string, number]> = [
  ["TODA Anilao Proper", 63],
  ["TODA Anilao East", 57],
  ["TODA Bagalangit", 54],
  ["TODA Bulacan", 50],
  ["TODA Calamias", 46],
  ["TODA Estrella", 43],
  ["TODA Gasang", 41],
  ["TODA Laurel", 39],
  ["TODA Ligaya", 37],
  ["TODA Mainaga", 35],
  ["TODA Mainit", 33],
  ["TODA Majuben", 31],
  ["TODA Malimatoc", 30],
  ["TODA Nag-iba", 28],
  ["TODA Pilahan", 28],
  ["TODA Poblacion", 26],
  ["TODA Pulang Lupa", 26],
  ["TODA Pulong Anahao", 24],
  ["TODA Pulong Niogan", 24],
  ["TODA Saguing", 22],
  ["TODA Sampaguita", 22],
  ["TODA San Francisco", 20],
  ["TODA San Teodoro", 20],
  ["TODA Talaga", 18],
];

const BARANGAY_NAMES = [
  "Anilao Proper", "Anilao East", "Bagalangit", "Bulacan", "Calamias", "Estrella",
  "Gasang", "Laurel", "Ligaya", "Mainaga", "Mainit", "Majuben", "Malimatoc I",
  "Malimatoc II", "Nag-iba", "Pilahan", "Poblacion", "Pulang Lupa", "Pulong Anahao",
  "Pulong Balibaguhan", "Pulong Niogan", "Saguing", "Sampaguita", "San Francisco",
  "San Jose", "San Juan", "San Teodoro", "Santa Ana", "Santa Mesa", "Santo Niño",
  "Santo Tomas", "Solo", "Talaga East", "Talaga Proper",
];

const FIRST = ["Adrian", "Alvin", "Arnel", "Benjamin", "Carlito", "Danilo", "Dennis",
  "Edgar", "Efren", "Elmer", "Ernesto", "Ferdinand", "Gilbert", "Gregorio", "Henry",
  "Isagani", "Jaime", "Joel", "Jonathan", "Jose", "Julio", "Leonardo", "Lorenzo",
  "Manuel", "Marcelo", "Mario", "Marvin", "Melchor", "Michael", "Nestor", "Noel",
  "Oliver", "Orlando", "Oscar", "Pablo", "Pedro"];

const LAST = ["Abanto", "Agbayani", "Almario", "Atienza", "Balbuena", "Banaag",
  "Bautista", "Briones", "Buenaventura", "Cabrera", "Cantos", "Claveria", "Contreras",
  "Dalisay", "De Guzman", "Dimaculangan", "Dimaano", "Ebora", "Fajardo", "Feliciano",
  "Garcia", "Gonzales", "Guevarra", "Hernandez", "Javier", "Landicho", "Lipa",
  "Malabanan", "Mendoza", "Miranda", "Nolasco", "Ocampo", "Olivares", "Ortega",
  "Panganiban", "Pastor"];

const COLORS = ["Blue", "Red", "Black", "White", "Silver", "Green", "Yellow"];
const MAKES = ["Honda", "Kawasaki", "Yamaha", "Suzuki", "Rusi", "Motorstar"];
const MODELS = ["TMX 155", "Barako 175", "YBR 125", "GD 110", "CT100", "Classic 250"];

const REJECTION_REASONS = [
  "Barangay clearance presented has already expired; please submit a clearance issued within the current year.",
  "Photocopy of the Certificate of Registration is not legible; a clear copy or scanned original is required.",
  "Registered vehicle owner differs from the declared operator; please submit a deed of sale or authority to operate.",
  "Chassis number declared in the application does not match the OR/CR on file; please verify and re-submit.",
];

export const demoBarangays: Barangay[] = BARANGAY_NAMES.map((name, index) => ({
  code: `0410160${String(index + 1).padStart(2, "0")}`,
  name,
}));

export const demoTodas: Toda[] = TODA_NAMES.map(([name, members], index) => ({
  id: uuid(0x1000 + index),
  code: `TODA-${String(index + 1).padStart(3, "0")}`,
  name,
  barangay_code: demoBarangays[index % demoBarangays.length]!.code,
  zone: `Zone ${(index % 6) + 1}`,
  members_count: members,
  is_active: true,
  created_at: iso(420),
  updated_at: iso(30),
}));

export const demoProfiles: Profile[] = (() => {
  const profiles: Profile[] = [];

  const make = (
    seed: number,
    role: Profile["role"],
    first: string,
    last: string,
    todaIndex: number | null,
    daysAgo: number,
    status: Profile["account_status"] = "active",
  ): Profile => ({
    id: uuid(0x2000 + seed),
    auth_user_id: uuid(0x9000 + seed),
    role,
    first_name: first,
    middle_name: null,
    last_name: last,
    full_name: `${first} ${last}`,
    email:
      role === "driver"
        ? `driver${String(seed).padStart(3, "0")}@mabini-sbtf.test`
        : role === "staff"
          ? `staff${seed}@mabini-sbtf.test`
          : "admin@mabini-sbtf.test",
    contact_number: `0918${String(1000000 + seed * 37).slice(0, 7)}`,
    address_line: `Purok ${(seed % 5) + 1}`,
    barangay_code: demoBarangays[seed % demoBarangays.length]!.code,
    toda_id: todaIndex === null ? null : demoTodas[todaIndex]!.id,
    account_status: status,
    status_reason: status === "active" ? null : "Suspended pending compliance review.",
    email_notifications: true,
    renewal_reminders: seed % 17 !== 0,
    last_login_at: iso(seed % 14, 8),
    created_at: iso(daysAgo),
    updated_at: iso(2),
  });

  profiles.push(make(1, "administrator", "Apolinaria", "Domingo", null, 400));
  profiles.push(make(2, "staff", "Benigno", "Magsaysay", null, 380));
  profiles.push(make(3, "staff", "Corazon", "Villamor", null, 300));
  profiles.push(make(4, "staff", "Diosdado", "Panganiban", null, 120));

  for (let index = 0; index < 48; index += 1) {
    profiles.push(
      make(
        100 + index,
        "driver",
        FIRST[index % FIRST.length]!,
        LAST[(index * 3) % LAST.length]!,
        index % demoTodas.length,
        300 - index * 4,
        index % 23 === 0 ? "inactive" : "active",
      ),
    );
  }

  return profiles;
})();

const driverProfiles = demoProfiles.filter((profile) => profile.role === "driver");

export const demoApplications: FranchiseApplicationDetail[] = (() => {
  const applications: FranchiseApplicationDetail[] = [];
  const statuses: Array<"pending" | "approved" | "rejected"> = [
    ...Array(30).fill("approved"),
    ...Array(11).fill("pending"),
    ...Array(7).fill("rejected"),
  ];

  statuses.forEach((status, index) => {
    const driver = driverProfiles[(index * 5) % driverProfiles.length]!;
    const toda = demoTodas[(index * 7) % demoTodas.length]!;
    const type = index % 3 === 0 ? "renewal" : "new";
    const submittedDaysAgo = 620 - index * 12;
    const decided = status !== "pending";
    const reviewedDaysAgo = decided ? submittedDaysAgo - (2 + (index % 9)) : null;

    const documents: FranchiseDocument[] = REQUIRED_DOCUMENTS.map(
      (documentType, documentIndex) => {
        const verification =
          status === "approved"
            ? "verified"
            : status === "rejected" && documentIndex === 0
              ? "rejected"
              : status === "pending" && documentIndex < 2
                ? "verified"
                : status === "pending"
                  ? "pending"
                  : index % 2 === 0
                    ? "verified"
                    : "pending";

        return {
          id: uuid(0x4000 + index * 10 + documentIndex),
          application_id: uuid(0x3000 + index),
          document_type: documentType,
          storage_path: `${driver.id}/pending/${uuid(0x3000 + index)}-${documentType}.pdf`,
          file_name: `${documentType}.pdf`,
          file_size_bytes: 180000 + index * 977,
          mime_type: "application/pdf",
          verification_status: verification,
          verified_by: verification === "pending" ? null : demoProfiles[1]!.id,
          verified_at: verification === "pending" ? null : iso(submittedDaysAgo - 2, 14),
          remarks:
            verification === "rejected"
              ? "Document is not legible; please upload a clearer copy."
              : null,
          uploaded_at: iso(submittedDaysAgo),
          updated_at: iso(submittedDaysAgo - 2, 14),
        };
      },
    );

    const application: FranchiseApplicationDetail = {
      id: uuid(0x3000 + index),
      application_number: `APP-${2024 + (index % 2)}-${String(index + 1).padStart(6, "0")}`,
      applicant_id: driver.id,
      application_type: type,
      status,
      toda_id: toda.id,
      operator_first_name: driver.first_name,
      operator_middle_name: null,
      operator_last_name: driver.last_name,
      operator_contact_number: driver.contact_number ?? "09180000000",
      operator_address_line: `${driver.address_line ?? "Purok 1"}, ${toda.name}`,
      operator_barangay_code: driver.barangay_code,
      operator_email: driver.email,
      vehicle_make: MAKES[index % MAKES.length]!,
      vehicle_model: MODELS[index % MODELS.length]!,
      vehicle_year: 2005 + (index % 19),
      vehicle_color: COLORS[index % COLORS.length]!,
      plate_number: `TRI-${String(100 + index).padStart(3, "0")}${String.fromCharCode(65 + (index % 26))}`,
      engine_number: `ENG${String(1000 + index * 131)}`,
      chassis_number: `CHS${String(1000 + index * 197)}`,
      seating_capacity: 5,
      mtop_number: index % 4 === 0 ? `MTOP-2024-${String(index).padStart(4, "0")}` : null,
      body_number: null,
      renewal_of_record_id: type === "renewal" ? uuid(0x5000 + index) : null,
      remarks: null,
      submitted_at: iso(submittedDaysAgo),
      review_started_at: decided ? iso(submittedDaysAgo - 1, 11) : null,
      review_started_by: decided ? demoProfiles[1]!.id : null,
      reviewed_by: decided ? demoProfiles[(index % 2) + 1]!.id : null,
      reviewed_at: reviewedDaysAgo === null ? null : iso(reviewedDaysAgo, 15),
      rejection_reason:
        status === "rejected" ? REJECTION_REASONS[index % REJECTION_REASONS.length]! : null,
      created_at: iso(submittedDaysAgo),
      updated_at: iso(reviewedDaysAgo ?? submittedDaysAgo, 15),
      applicant: {
        id: driver.id,
        full_name: driver.full_name,
        email: driver.email,
        contact_number: driver.contact_number,
        account_status: driver.account_status,
      },
      toda: { id: toda.id, name: toda.name, code: toda.code },
      documents,
      reviewer: decided
        ? { id: demoProfiles[1]!.id, full_name: demoProfiles[1]!.full_name }
        : null,
      timeline: buildTimeline(index, submittedDaysAgo, reviewedDaysAgo, status),
    };

    if (status === "approved") {
      application.record = {
        id: uuid(0x5000 + index),
        franchise_number: `MAB-TR-${2024 + (index % 2)}-${String(index + 1).padStart(6, "0")}`,
        issued_at: iso(reviewedDaysAgo ?? submittedDaysAgo, 15),
        expires_at: iso((reviewedDaysAgo ?? submittedDaysAgo) - 365, 15),
        archived: false,
      };
    }

    applications.push(application);
  });

  return applications.sort(
    (a, b) => new Date(b.submitted_at).getTime() - new Date(a.submitted_at).getTime(),
  );
})();

function buildTimeline(
  index: number,
  submittedDaysAgo: number,
  reviewedDaysAgo: number | null,
  status: "pending" | "approved" | "rejected",
): ApplicationStatusHistory[] {
  const timeline: ApplicationStatusHistory[] = [
    {
      id: uuid(0x6000 + index * 10),
      application_id: uuid(0x3000 + index),
      event: "created",
      actor_id: driverProfiles[(index * 5) % driverProfiles.length]!.id,
      note: "Application submitted",
      created_at: iso(submittedDaysAgo),
    },
    ...REQUIRED_DOCUMENTS.map((documentType, position) => ({
      id: uuid(0x6000 + index * 10 + position + 1),
      application_id: uuid(0x3000 + index),
      event: "document_uploaded" as const,
      actor_id: driverProfiles[(index * 5) % driverProfiles.length]!.id,
      note: documentType.replace(/_/g, " "),
      created_at: iso(submittedDaysAgo, 10),
    })),
  ];

  if (reviewedDaysAgo !== null) {
    timeline.push({
      id: uuid(0x6100 + index),
      application_id: uuid(0x3000 + index),
      event: "review_started",
      actor_id: demoProfiles[1]!.id,
      note: "Review started",
      created_at: iso(reviewedDaysAgo + 1, 11),
    });
    timeline.push({
      id: uuid(0x6200 + index),
      application_id: uuid(0x3000 + index),
      event: status === "approved" ? "approved" : "rejected",
      actor_id: demoProfiles[1]!.id,
      note: status === "approved" ? "Franchise issued" : "Rejected",
      created_at: iso(reviewedDaysAgo, 15),
    });
  }

  return timeline;
}

export const demoRecords: FranchiseRecordDetail[] = demoApplications
  .filter((application) => application.status === "approved")
  .map((application, index) => {
    const recordId = uuid(0x5000 + index * 3);
    const issuedAt = application.reviewed_at ?? application.submitted_at;
    // A franchise runs for twelve months; the certificate is produced on issue.
    const expiresAt = addMonths(issuedAt, 12);
    const certificateGenerated = index % 5 !== 0;
    return {
      id: recordId,
      application_id: application.id,
      operator_id: application.applicant_id,
      toda_id: application.toda_id,
      franchise_number: `MAB-TR-${2024 + (index % 2)}-${String(index + 1).padStart(6, "0")}`,
      verification_code: verificationCode(index),
      issued_at: issuedAt,
      expires_at: expiresAt,
      certificate_storage_path: certificateGenerated
        ? `${application.applicant_id}/MAB-TR-${2024 + (index % 2)}-${String(index + 1).padStart(6, "0")}.pdf`
        : null,
      certificate_generated_at: certificateGenerated ? issuedAt : null,
      renewed_by_record_id: null,
      archived: index % 17 === 0,
      archived_at: index % 17 === 0 ? iso(20, 10) : null,
      archived_by: index % 17 === 0 ? demoProfiles[1]!.id : null,
      archive_reason: index % 17 === 0 ? "Operator ceased operations within the municipality." : null,
      created_at: application.reviewed_at ?? application.submitted_at,
      updated_at: iso(5),
      operator: application.applicant ?? null,
      toda: application.toda
        ? { id: application.toda.id, name: application.toda.name, code: application.toda.code }
        : null,
      application: {
        id: application.id,
        application_number: application.application_number,
        application_type: application.application_type,
        plate_number: application.plate_number,
        vehicle_make: application.vehicle_make,
        vehicle_model: application.vehicle_model,
        vehicle_year: application.vehicle_year,
      },
    };
  });

export const demoOverview: AnalyticsOverview = (() => {
  const total = demoApplications.length;
  const pending = demoApplications.filter((a) => a.status === "pending").length;
  const approved = demoApplications.filter((a) => a.status === "approved").length;
  const rejected = demoApplications.filter((a) => a.status === "rejected").length;
  const decided = approved + rejected;
  const activeFranchises = demoRecords.filter(
    (record) => !record.archived && new Date(record.expires_at) >= TODAY,
  ).length;

  return {
    total_applications: total,
    pending_applications: pending,
    approved_applications: approved,
    rejected_applications: rejected,
    new_applications: demoApplications.filter((a) => a.application_type === "new").length,
    renewal_applications: demoApplications.filter((a) => a.application_type === "renewal").length,
    approval_rate: decided === 0 ? null : Math.round((approved / decided) * 10000) / 100,
    rejection_rate: decided === 0 ? null : Math.round((rejected / decided) * 10000) / 100,
    avg_processing_days: 4.8,
    median_processing_days: 4,
    active_drivers: demoProfiles.filter((p) => p.role === "driver" && p.account_status === "active").length,
    active_franchises: activeFranchises,
    expiring_30: demoRecords.filter((r) => !r.archived && new Date(r.expires_at) >= TODAY && new Date(r.expires_at) < new Date(TODAY.getTime() + 30 * 86400000)).length,
    expiring_60: demoRecords.filter((r) => !r.archived && new Date(r.expires_at) >= TODAY && new Date(r.expires_at) < new Date(TODAY.getTime() + 60 * 86400000)).length,
    expiring_90: demoRecords.filter((r) => !r.archived && new Date(r.expires_at) >= TODAY && new Date(r.expires_at) < new Date(TODAY.getTime() + 90 * 86400000)).length,
    expired_franchises: demoRecords.filter((r) => !r.archived && new Date(r.expires_at) < TODAY).length,
    total_todas: demoTodas.length,
    total_toda_members: demoTodas.reduce((sum, toda) => sum + toda.members_count, 0),
    verified_documents: demoApplications.flatMap((a) => a.documents ?? []).filter((d) => d.verification_status === "verified").length,
    pending_documents: demoApplications.flatMap((a) => a.documents ?? []).filter((d) => d.verification_status === "pending").length,
    rejected_documents: demoApplications.flatMap((a) => a.documents ?? []).filter((d) => d.verification_status === "rejected").length,
    submitted_last_30_days: 9,
    submitted_previous_30_days: 6,
    decided_last_30_days: 7,
    unread_notifications: 4,
  };
})();

export const demoTrends: TrendPoint[] = (() => {
  const months: TrendPoint[] = [];
  const counts = [8, 14, 22, 17, 11, 9, 7, 12, 15, 10, 8, 9];
  for (let index = 0; index < 12; index += 1) {
    const date = new Date(Date.UTC(2025, index, 1));
    const submitted = counts[index]!;
    const approved = Math.round(submitted * 0.72);
    const rejected = Math.max(submitted - approved - 1, 0);
    months.push({
      month_start: date.toISOString().slice(0, 10),
      month_label: date.toLocaleString("en-PH", { month: "short", year: "numeric", timeZone: "UTC" }),
      submitted,
      new_count: Math.round(submitted * 0.66),
      renewal_count: submitted - Math.round(submitted * 0.66),
      approved,
      rejected,
      decided: approved + rejected,
      avg_process_days: Math.round((3.5 + (index % 5) * 0.6) * 100) / 100,
    });
  }
  return months;
})();

export const demoTodaAnalytics: TodaAnalytics[] = demoTodas.map((toda) => {
  const applications = demoApplications.filter((a) => a.toda_id === toda.id);
  const approved = applications.filter((a) => a.status === "approved").length;
  const rejected = applications.filter((a) => a.status === "rejected").length;
  const decided = approved + rejected;
  return {
    toda_id: toda.id,
    toda_name: toda.name,
    members_count: toda.members_count,
    applications: applications.length,
    new_applications: applications.filter((a) => a.application_type === "new").length,
    renewal_applications: applications.filter((a) => a.application_type === "renewal").length,
    approved,
    rejected,
    pending: applications.filter((a) => a.status === "pending").length,
    active_franchises: demoRecords.filter((r) => r.toda_id === toda.id && !r.archived).length,
    approval_rate: decided === 0 ? null : Math.round((approved / decided) * 10000) / 100,
    last_submission_at: applications[0]?.submitted_at ?? null,
  };
}).sort((a, b) => b.applications - a.applications);

export const demoProcessingTime: ProcessingTimePoint[] = demoTrends.map((trend, index) => ({
  month_start: trend.month_start,
  month_label: trend.month_label,
  decided: trend.decided,
  approved: trend.approved,
  rejected: trend.rejected,
  avg_days: trend.avg_process_days,
  median_days: trend.avg_process_days === null ? null : trend.avg_process_days - 0.8,
  p90_days: trend.avg_process_days === null ? null : trend.avg_process_days + 3.4,
  longest_days: trend.avg_process_days === null ? null : trend.avg_process_days + 11 - (index % 4),
}));

export const demoExpiring: ExpiringRecord[] = demoRecords
  .filter((record) => !record.archived)
  .map((record) => {
    const days = Math.round(
      (new Date(record.expires_at).getTime() - TODAY.getTime()) / 86400000,
    );
    return {
      record_id: record.id,
      franchise_number: record.franchise_number,
      operator_name: record.operator?.full_name ?? "—",
      toda_name: record.toda?.name ?? "—",
      expires_at: record.expires_at,
      days_remaining: days,
      bucket:
        days < 0
          ? "expired"
          : days <= 30
            ? "0-30 days"
            : days <= 60
              ? "31-60 days"
              : days <= 90
                ? "61-90 days"
                : "91+ days",
    } satisfies ExpiringRecord;
  })
  .sort((a, b) => a.days_remaining - b.days_remaining);

export const demoDocumentCompliance: DocumentComplianceRow[] = REQUIRED_DOCUMENTS.map(
  (documentType, index) => {
    const documents = demoApplications
      .flatMap((a) => a.documents ?? [])
      .filter((document) => document.document_type === documentType);
    const verified = documents.filter((d) => d.verification_status === "verified").length;
    const pending = documents.filter((d) => d.verification_status === "pending").length;
    const rejected = documents.filter((d) => d.verification_status === "rejected").length;

    return {
      document_type: documentType,
      total: documents.length,
      verified,
      pending,
      rejected,
      verified_rate: documents.length === 0 ? null : Math.round((verified / documents.length) * 10000) / 100,
      oldest_pending_days: pending === 0 ? null : 3 + index,
    };
  },
);

export const demoPrescriptive: PrescriptiveIndicator[] = [
  {
    indicator_key: "peak_period_staffing",
    severity: "attention",
    category: "Staffing",
    finding: "Application volume peaks in March 2025 with 22 submissions against a monthly average of 11.8.",
    recommendation:
      "Consider assigning additional processing staff or extending review hours during February, March and the immediately following month.",
    data_basis: "franchise_applications.submitted_at grouped by month, last 12 months",
    metric_value: 22,
    threshold_value: 15.4,
  },
  {
    indicator_key: "pending_backlog",
    severity: "attention",
    category: "Processing capacity",
    finding: "11 application(s) are awaiting a decision; the oldest has been pending for 63 day(s).",
    recommendation:
      "Prioritise the oldest pending applications first and consider batch document verification to reduce the queue.",
    data_basis: "franchise_applications where status = 'pending'",
    metric_value: 11,
    threshold_value: 5,
  },
  {
    indicator_key: "renewal_pipeline",
    severity: "attention",
    category: "Renewal",
    finding: "6 franchise(s) expire within 30 days and 9 within 60 days.",
    recommendation:
      "Prioritise renewal reminders for the nearest expirations and prepare counter capacity for the expected renewal submissions.",
    data_basis: "franchise_records.expires_at buckets for active, non-archived records",
    metric_value: 6,
    threshold_value: 10,
  },
];

export const demoSystemHealth: SystemHealth = {
  users_total: demoProfiles.length,
  users_administrators: demoProfiles.filter((p) => p.role === "administrator").length,
  users_staff: demoProfiles.filter((p) => p.role === "staff").length,
  users_drivers: demoProfiles.filter((p) => p.role === "driver").length,
  users_inactive: demoProfiles.filter((p) => p.account_status !== "active").length,
  activity_logs_7d: 128,
  ai_requests_30d: 6,
  ai_requests_failed_30d: 0,
  certificates_issued: demoRecords.filter((r) => r.certificate_storage_path).length,
  document_objects: demoApplications.flatMap((a) => a.documents ?? []).length,
  certificate_objects: demoRecords.filter((r) => r.certificate_storage_path).length,
  last_activity_at: iso(0, 16),
};

export const demoActivityLogs: ActivityLog[] = (() => {
  const logs: ActivityLog[] = [];
  const now = TODAY.getTime();

  demoApplications.slice(0, 30).forEach((application, index) => {
    const actor = demoProfiles[index % demoProfiles.length]!;
    const base = now - (index + 1) * 3600 * 1000;
    logs.push({
      id: uuid(0x7000 + index * 5),
      user_id: actor.id,
      action: application.application_type === "renewal" ? "application_renewal_submitted" : "application_submitted",
      target_type: "franchise_application",
      target_id: application.id,
      metadata: { application_number: application.application_number },
      context: {},
      timestamp: new Date(base).toISOString(),
      actor,
    });

    if (application.status !== "pending") {
      logs.push({
        id: uuid(0x7100 + index * 5),
        user_id: demoProfiles[1]!.id,
        action: application.status === "approved" ? "application_approved" : "application_rejected",
        target_type: "franchise_application",
        target_id: application.id,
        metadata: { application_number: application.application_number },
        context: {},
        timestamp: new Date(base + 7200000).toISOString(),
        actor: demoProfiles[1]!,
      });
    }
  });

  logs.push({
    id: uuid(0x7900),
    user_id: demoProfiles[0]!.id,
    action: "settings_update",
    target_type: "system_setting",
    target_id: null,
    metadata: { key: "franchise_validity_months", new_value: 12 },
    context: {},
    timestamp: new Date(now - 86400000).toISOString(),
    actor: demoProfiles[0]!,
  });

  return logs.sort((a, b) => new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime());
})();

export const demoNotifications: Notification[] = [
  {
    id: uuid(0x8000),
    user_id: demoProfiles[0]!.id,
    title: "New franchise application",
    message: "Application APP-2025-000041 was submitted for TODA Poblacion.",
    notification_type: "application_submitted",
    target_type: "franchise_application",
    target_id: uuid(0x3000 + 12),
    read: false,
    read_at: null,
    created_at: iso(0, 11),
  },
  {
    id: uuid(0x8001),
    user_id: demoProfiles[0]!.id,
    title: "Document uploaded",
    message: "Barangay clearance was uploaded for application APP-2025-000040.",
    notification_type: "application_submitted",
    target_type: "franchise_document",
    target_id: uuid(0x4000 + 5),
    read: false,
    read_at: null,
    created_at: iso(1, 9),
  },
  {
    id: uuid(0x8002),
    user_id: demoProfiles[0]!.id,
    title: "Franchise renewal reminder",
    message: "Franchise MAB-TR-2025-000006 expires soon.",
    notification_type: "renewal_reminder",
    target_type: "franchise_record",
    target_id: uuid(0x5006),
    read: true,
    read_at: iso(2, 10),
    created_at: iso(3, 8),
  },
];

export const demoSettings: SystemSetting[] = [
  ["municipality_name", "Municipality of Mabini", "string", "general", "Municipality name", "Displayed on the interface, reports and certificates.", true],
  ["province_name", "Batangas", "string", "general", "Province", "Displayed on the interface, reports and certificates.", true],
  ["office_name", "Sangguniang Bayan ng Mabini — Committee on Transportation", "string", "general", "Implementing office", "Office responsible for tricycle franchising.", true],
  ["office_email", "sb.mabini@example.gov.ph", "string", "general", "Official e-mail", "Published contact address.", true],
  ["office_contact_number", "(043) 000-0000", "string", "general", "Official contact number", "Published contact number.", true],
  ["franchise_validity_months", 12, "number", "franchise", "Franchise validity (months)", "Validity applied to newly issued records.", true],
  ["franchise_number_prefix", "MAB-TR", "string", "franchise", "Franchise number prefix", "Prefix used when generating franchise numbers.", true],
  ["renewal_reminder_days", [90, 60, 30], "json", "notifications", "Renewal reminder windows (days)", "Days before expiry a reminder is raised.", true],
  ["ai_model", "llama-3.3-70b-versatile", "string", "ai", "Groq model", "Model used by the AI decision-support function.", false],
  ["ai_enabled", true, "boolean", "ai", "AI decision support enabled", "When disabled the advisory endpoint refuses to run.", false],
  ["ai_max_requests_per_user_per_day", 20, "number", "ai", "AI requests per user per day", "Soft rate limit protecting the shared quota.", false],
  ["certificate_signatory_name", "HON. MARIA TERESA DELA CRUZ", "string", "certificate", "Certificate signatory", "Name printed on the certificate.", true],
  ["certificate_signatory_position", "Municipal Mayor", "string", "certificate", "Signatory position", "Position printed under the signatory.", true],
  ["certificate_footer_note", "This certificate is verifiable through the QR code printed on it.", "string", "certificate", "Certificate footer note", "Advisory note printed at the bottom.", true],
  ["certificate_verification_base_url", "http://localhost:3000/verify", "string", "certificate", "Certificate verification URL", "Base URL encoded in the certificate QR code.", true],
].map(([key, value, data_type, category, label, description, is_public], index) => ({
  key: key as string,
  value,
  data_type: data_type as SystemSetting["data_type"],
  category: category as SystemSetting["category"],
  label: label as string,
  description: description as string,
  is_public: is_public as boolean,
  updated_by: index % 3 === 0 ? demoProfiles[0]!.id : null,
  updated_at: iso(30 - index),
}));
