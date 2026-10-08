import "server-only";

import { cookies } from "next/headers";

import { createClient } from "@/lib/supabase/server";
import { isDemoMode } from "@/lib/env";
import { toDatabaseNotReadyError } from "@/lib/supabase/errors";
import { REQUIRED_DOCUMENTS } from "@/lib/constants";
import * as demo from "@/lib/data/demo-fixtures";
import type {
  ActivityAction,
  ActivityLog,
  AnalyticsOverview,
  ApplicationStatus,
  ApplicationType,
  Barangay,
  CertificateVerification,
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
  UserRole,
} from "@/types/database";

/* -------------------------------------------------------------------------- */
/* Query shapes                                                                */
/* -------------------------------------------------------------------------- */

export interface ApplicationFilters {
  search?: string;
  status?: ApplicationStatus | "all";
  type?: ApplicationType | "all";
  todaId?: string;
  from?: string;
  to?: string;
  page?: number;
  pageSize?: number;
}

export interface RecordFilters {
  search?: string;
  todaId?: string;
  state?: "active" | "expiring" | "expired" | "archived" | "all";
  from?: string;
  to?: string;
  page?: number;
  pageSize?: number;
}

export interface UserFilters {
  search?: string;
  role?: UserRole | "all";
  status?: "active" | "inactive" | "suspended" | "all";
  todaId?: string;
  page?: number;
  pageSize?: number;
}

export interface LogFilters {
  search?: string;
  action?: ActivityAction | "all";
  from?: string;
  to?: string;
  page?: number;
  pageSize?: number;
}

export interface ListResult<T> {
  rows: T[];
  count: number;
  page: number;
  pageSize: number;
}

const DEFAULT_PAGE_SIZE = 20;

/* -------------------------------------------------------------------------- */
/* Session                                                                     */
/* -------------------------------------------------------------------------- */

export interface SessionContext {
  profile: Profile;
  role: UserRole;
}

/**
 * Preview mode has no session, so the role is read from the `sbtf_demo_role`
 * cookie set by `?as=staff` / `?as=admin` in `middleware.ts`.
 */
async function demoSession(): Promise<SessionContext> {
  const store = await cookies();
  const role = store.get("sbtf_demo_role")?.value === "staff" ? "staff" : "administrator";
  const profile =
    demo.demoProfiles.find((candidate) => candidate.role === role) ?? demo.demoProfiles[0]!;
  return { profile, role };
}

export async function getSessionProfile(): Promise<SessionContext | null> {
  if (isDemoMode()) {
    return demoSession();
  }

  const supabase = await createClient();
  const { data, error } = await supabase.auth.getUser();

  // A failed session lookup used to be swallowed as "not signed in", which sent
  // every page to /login even when the real problem was an unreachable project
  // or a schema that was never applied. Blocking failures are re-thrown so the
  // middleware can send the visitor to /setup-required instead of looping.
  const sessionFailure = error ? toDatabaseNotReadyError(error) : null;
  if (sessionFailure) throw sessionFailure;

  const user = data?.user ?? null;
  if (!user) return null;

  const { data: profileRow, error: profileError } = await supabase
    .from("profiles")
    .select("*")
    .eq("auth_user_id", user.id)
    .maybeSingle();

  const profileFailure = profileError ? toDatabaseNotReadyError(profileError) : null;
  if (profileFailure) throw profileFailure;

  if (!profileRow) return null;
  const profile = profileRow as unknown as Profile;
  return { profile, role: profile.role };
}

export async function getAccountStateForCurrentUser(): Promise<
  { profile_id: string; role: UserRole; account_status: string; full_name: string } | null
> {
  if (isDemoMode()) {
    const session = await demoSession();
    return {
      profile_id: session.profile.id,
      role: session.role,
      account_status: session.profile.account_status,
      full_name: session.profile.full_name,
    };
  }

  const supabase = await createClient();
  const { data } = await supabase.rpc("current_account_state");
  const row = Array.isArray(data) ? data[0] : data;
  return row ?? null;
}

/* -------------------------------------------------------------------------- */
/* Reference data                                                              */
/* -------------------------------------------------------------------------- */

export async function listTodas(): Promise<Toda[]> {
  if (isDemoMode()) return demo.demoTodas;
  const supabase = await createClient();
  const { data } = await supabase.from("todas").select("*").order("name");
  return (data ?? []) as unknown as Toda[];
}

export async function listBarangays(): Promise<Barangay[]> {
  if (isDemoMode()) return demo.demoBarangays;
  const supabase = await createClient();
  const { data } = await supabase.from("barangays").select("code, name").order("sort_order");
  return (data ?? []) as unknown as Barangay[];
}

export async function listStaffMembers(): Promise<Profile[]> {
  if (isDemoMode()) return demo.demoProfiles.filter((p) => p.role !== "driver");
  const supabase = await createClient();
  const { data } = await supabase
    .from("profiles")
    .select("*")
    .in("role", ["staff", "administrator"])
    .order("last_name");
  return (data ?? []) as unknown as Profile[];
}

/* -------------------------------------------------------------------------- */
/* Analytics (computed in PostgreSQL; see rpc_analytics_* functions)           */
/* -------------------------------------------------------------------------- */

export async function getAnalyticsOverview(): Promise<AnalyticsOverview | null> {
  if (isDemoMode()) return demo.demoOverview;
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("rpc_analytics_overview");
  if (error) throw error;
  const row = Array.isArray(data) ? data[0] : data;
  return (row ?? null) as AnalyticsOverview | null;
}

export async function getApplicationTrends(months = 12): Promise<TrendPoint[]> {
  if (isDemoMode()) return demo.demoTrends.slice(-months);
  const supabase = await createClient();
  const { data } = await supabase.rpc("rpc_analytics_application_trends", { p_months: months });
  return ((data ?? []) as unknown as TrendPoint[]).map((row) => ({
    ...row,
    submitted: Number(row.submitted ?? 0),
    approved: Number(row.approved ?? 0),
    rejected: Number(row.rejected ?? 0),
  }));
}

export async function getApplicationsByToda(): Promise<TodaAnalytics[]> {
  if (isDemoMode()) return demo.demoTodaAnalytics;
  const supabase = await createClient();
  const { data } = await supabase.rpc("rpc_analytics_by_toda");
  return (data ?? []) as unknown as TodaAnalytics[];
}

export async function getProcessingTime(months = 12): Promise<ProcessingTimePoint[]> {
  if (isDemoMode()) return demo.demoProcessingTime.slice(-months);
  const supabase = await createClient();
  const { data } = await supabase.rpc("rpc_analytics_processing_time", { p_months: months });
  return (data ?? []) as unknown as ProcessingTimePoint[];
}

export async function getExpiringFranchises(days = 180): Promise<ExpiringRecord[]> {
  if (isDemoMode()) return demo.demoExpiring.filter((row) => row.days_remaining <= days);
  const supabase = await createClient();
  const { data } = await supabase.rpc("rpc_analytics_expiring", { p_days: days });
  return (data ?? []) as unknown as ExpiringRecord[];
}

export async function getDocumentCompliance(): Promise<DocumentComplianceRow[]> {
  if (isDemoMode()) return demo.demoDocumentCompliance;
  const supabase = await createClient();
  const { data } = await supabase.rpc("rpc_analytics_document_compliance");
  return (data ?? []) as unknown as DocumentComplianceRow[];
}

export async function getPrescriptiveIndicators(): Promise<PrescriptiveIndicator[]> {
  if (isDemoMode()) return demo.demoPrescriptive;
  const supabase = await createClient();
  const { data } = await supabase.rpc("rpc_analytics_prescriptive");
  return (data ?? []) as unknown as PrescriptiveIndicator[];
}

export async function getSystemHealth(): Promise<SystemHealth | null> {
  if (isDemoMode()) return demo.demoSystemHealth;
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("rpc_analytics_system_health");
  if (error) return null;
  const row = Array.isArray(data) ? data[0] : data;
  return (row ?? null) as SystemHealth | null;
}

/* -------------------------------------------------------------------------- */
/* Applications                                                                */
/* -------------------------------------------------------------------------- */

const APPLICATION_SELECT = `
  *,
  applicant:profiles!franchise_applications_applicant_id_fkey(id, full_name, email, contact_number, account_status),
  toda:todas!franchise_applications_toda_id_fkey(id, name, code),
  documents:franchise_documents(*),
  reviewer:profiles!franchise_applications_reviewed_by_fkey(id, full_name),
  record:franchise_records(id, franchise_number, issued_at, expires_at, archived)
`;

export async function listApplications(
  filters: ApplicationFilters = {},
): Promise<ListResult<FranchiseApplicationDetail>> {
  const page = Math.max(filters.page ?? 1, 1);
  const pageSize = filters.pageSize ?? DEFAULT_PAGE_SIZE;

  if (isDemoMode()) {
    const rows = filterDemoApplications(filters);
    return paginate(rows, page, pageSize);
  }

  const supabase = await createClient();
  let query = supabase
    .from("franchise_applications")
    .select(APPLICATION_SELECT, { count: "exact" });

  if (filters.status && filters.status !== "all") query = query.eq("status", filters.status);
  if (filters.type && filters.type !== "all") query = query.eq("application_type", filters.type);
  if (filters.todaId && filters.todaId !== "all") query = query.eq("toda_id", filters.todaId);
  if (filters.from) query = query.gte("submitted_at", filters.from);
  if (filters.to) query = query.lte("submitted_at", `${filters.to}T23:59:59.999Z`);
  if (filters.search) {
    const term = filters.search.replace(/[%,]/g, " ").trim();
    query = query.or(
      [
        `application_number.ilike.%${term}%`,
        `plate_number.ilike.%${term}%`,
        `operator_last_name.ilike.%${term}%`,
        `operator_first_name.ilike.%${term}%`,
      ].join(","),
    );
  }

  const { data, count } = await query
    .order("submitted_at", { ascending: false })
    .range((page - 1) * pageSize, page * pageSize - 1);

  return {
    rows: (data ?? []) as unknown as FranchiseApplicationDetail[],
    count: count ?? 0,
    page,
    pageSize,
  };
}

function filterDemoApplications(filters: ApplicationFilters): FranchiseApplicationDetail[] {
  return demo.demoApplications.filter((application) => {
    if (filters.status && filters.status !== "all" && application.status !== filters.status)
      return false;
    if (filters.type && filters.type !== "all" && application.application_type !== filters.type)
      return false;
    if (filters.todaId && filters.todaId !== "all" && application.toda_id !== filters.todaId)
      return false;
    if (filters.from && application.submitted_at < filters.from) return false;
    if (filters.to && application.submitted_at > `${filters.to}T23:59:59.999Z`) return false;
    if (filters.search) {
      const term = filters.search.toLowerCase();
      const haystack = [
        application.application_number,
        application.plate_number,
        application.operator_first_name,
        application.operator_last_name,
        application.applicant?.full_name ?? "",
        application.toda?.name ?? "",
      ]
        .join(" ")
        .toLowerCase();
      if (!haystack.includes(term)) return false;
    }
    return true;
  });
}

export async function getApplication(
  id: string,
): Promise<FranchiseApplicationDetail | null> {
  if (isDemoMode()) {
    return demo.demoApplications.find((application) => application.id === id) ?? null;
  }

  const supabase = await createClient();
  const { data } = await supabase
    .from("franchise_applications")
    .select(`${APPLICATION_SELECT}, timeline:application_status_history(*), reviewer:profiles!franchise_applications_reviewed_by_fkey(id, full_name), review_starter:profiles!franchise_applications_review_started_by_fkey(id, full_name)`)
    .eq("id", id)
    .maybeSingle();

  if (!data) return null;
  const application = data as unknown as FranchiseApplicationDetail & {
    timeline?: FranchiseApplicationDetail["timeline"];
  };
  application.timeline = (application.timeline ?? []).sort(
    (a, b) => new Date(a.created_at).getTime() - new Date(b.created_at).getTime(),
  );
  application.documents = (application.documents ?? []).sort(
    (a, b) =>
      REQUIRED_DOCUMENTS.indexOf(a.document_type) - REQUIRED_DOCUMENTS.indexOf(b.document_type),
  );
  return application;
}

export async function getApplicationDocumentsWithUrls(
  applicationId: string,
): Promise<Array<FranchiseDocument & { signed_url: string | null }>> {
  const application = await getApplication(applicationId);
  if (!application?.documents) return [];

  if (isDemoMode()) {
    return application.documents.map((document) => ({ ...document, signed_url: null }));
  }

  const supabase = await createClient();
  const withUrls = await Promise.all(
    application.documents.map(async (document) => {
      const { data } = await supabase.storage
        .from("franchise-documents")
        .createSignedUrl(document.storage_path, 120);
      return { ...document, signed_url: data?.signedUrl ?? null };
    }),
  );

  return withUrls;
}

export async function getPendingApplicationsForStaff(
  limit = 6,
): Promise<FranchiseApplicationDetail[]> {
  const result = await listApplications({ status: "pending", page: 1, pageSize: limit });
  return result.rows;
}

export async function getRecentDecisions(limit = 6): Promise<FranchiseApplicationDetail[]> {
  if (isDemoMode()) {
    return demo.demoApplications
      .filter((application) => application.status !== "pending")
      .slice(0, limit);
  }
  const supabase = await createClient();
  const { data } = await supabase
    .from("franchise_applications")
    .select(APPLICATION_SELECT)
    .neq("status", "pending")
    .order("reviewed_at", { ascending: false })
    .limit(limit);
  return (data ?? []) as unknown as FranchiseApplicationDetail[];
}

/* -------------------------------------------------------------------------- */
/* Franchise records                                                           */
/* -------------------------------------------------------------------------- */

const RECORD_SELECT = `
  *,
  operator:profiles!franchise_records_operator_id_fkey(id, full_name, email, contact_number),
  toda:todas!franchise_records_toda_id_fkey(id, name, code),
  application:franchise_applications!franchise_records_application_id_fkey(id, application_number, application_type, plate_number, vehicle_make, vehicle_model, vehicle_year)
`;

export async function listFranchiseRecords(
  filters: RecordFilters = {},
): Promise<ListResult<FranchiseRecordDetail>> {
  const page = Math.max(filters.page ?? 1, 1);
  const pageSize = filters.pageSize ?? DEFAULT_PAGE_SIZE;
  const now = new Date().toISOString();

  if (isDemoMode()) {
    const rows = demo.demoRecords.filter((record) => {
      if (filters.todaId && filters.todaId !== "all" && record.toda_id !== filters.todaId)
        return false;
      if (filters.state && filters.state !== "all") {
        const expired = record.expires_at < now;
        const expiring =
          !expired &&
          new Date(record.expires_at).getTime() - new Date(now).getTime() < 90 * 86400000;
        if (filters.state === "archived" && !record.archived) return false;
        if (filters.state === "active" && (record.archived || expired)) return false;
        if (filters.state === "expiring" && !(expiring && !record.archived)) return false;
        if (filters.state === "expired" && !(expired && !record.archived)) return false;
      }
      if (filters.from && record.issued_at < filters.from) return false;
      if (filters.to && record.issued_at > `${filters.to}T23:59:59.999Z`) return false;
      if (filters.search) {
        const term = filters.search.toLowerCase();
        const haystack = [
          record.franchise_number,
          record.operator?.full_name ?? "",
          record.toda?.name ?? "",
          record.application?.plate_number ?? "",
        ]
          .join(" ")
          .toLowerCase();
        if (!haystack.includes(term)) return false;
      }
      return true;
    });
    return paginate(rows, page, pageSize);
  }

  const supabase = await createClient();
  let query = supabase.from("franchise_records").select(RECORD_SELECT, { count: "exact" });

  if (filters.todaId && filters.todaId !== "all") query = query.eq("toda_id", filters.todaId);
  if (filters.from) query = query.gte("issued_at", filters.from);
  if (filters.to) query = query.lte("issued_at", `${filters.to}T23:59:59.999Z`);
  if (filters.state === "archived") query = query.eq("archived", true);
  if (filters.state === "active") query = query.eq("archived", false).gte("expires_at", now);
  if (filters.state === "expiring") {
    query = query
      .eq("archived", false)
      .gte("expires_at", now)
      .lt("expires_at", new Date(Date.now() + 90 * 86400000).toISOString());
  }
  if (filters.state === "expired") query = query.eq("archived", false).lt("expires_at", now);
  if (filters.search) {
    const term = filters.search.replace(/[%,]/g, " ").trim();
    query = query.or(
      [`franchise_number.ilike.%${term}%`, `verification_code.ilike.%${term}%`].join(","),
    );
  }

  const { data, count } = await query
    .order("issued_at", { ascending: false })
    .range((page - 1) * pageSize, page * pageSize - 1);

  return {
    rows: (data ?? []) as unknown as FranchiseRecordDetail[],
    count: count ?? 0,
    page,
    pageSize,
  };
}

export async function getFranchiseRecord(id: string): Promise<FranchiseRecordDetail | null> {
  if (isDemoMode()) {
    return demo.demoRecords.find((record) => record.id === id) ?? null;
  }
  const supabase = await createClient();
  const { data } = await supabase.from("franchise_records").select(RECORD_SELECT).eq("id", id).maybeSingle();
  return (data ?? null) as FranchiseRecordDetail | null;
}

export async function getCertificateSignedUrl(recordId: string): Promise<string | null> {
  const record = await getFranchiseRecord(recordId);
  if (!record?.certificate_storage_path) return null;
  if (isDemoMode()) return null;

  const supabase = await createClient();
  const { data } = await supabase.storage
    .from("certificates")
    .createSignedUrl(record.certificate_storage_path, 300);
  return data?.signedUrl ?? null;
}

/* -------------------------------------------------------------------------- */
/* Users                                                                       */
/* -------------------------------------------------------------------------- */

export async function listUsers(
  filters: UserFilters = {},
): Promise<ListResult<Profile>> {
  const page = Math.max(filters.page ?? 1, 1);
  const pageSize = filters.pageSize ?? DEFAULT_PAGE_SIZE;

  if (isDemoMode()) {
    const rows = demo.demoProfiles.filter((profile) => {
      if (filters.role && filters.role !== "all" && profile.role !== filters.role) return false;
      if (filters.status && filters.status !== "all" && profile.account_status !== filters.status)
        return false;
      if (filters.todaId && filters.todaId !== "all" && profile.toda_id !== filters.todaId)
        return false;
      if (filters.search) {
        const term = filters.search.toLowerCase();
        const haystack = [profile.full_name, profile.email, profile.contact_number ?? ""]
          .join(" ")
          .toLowerCase();
        if (!haystack.includes(term)) return false;
      }
      return true;
    });
    return paginate(rows, page, pageSize);
  }

  const supabase = await createClient();
  let query = supabase.from("profiles").select("*", { count: "exact" });
  if (filters.role && filters.role !== "all") query = query.eq("role", filters.role);
  if (filters.status && filters.status !== "all")
    query = query.eq("account_status", filters.status);
  if (filters.todaId && filters.todaId !== "all") query = query.eq("toda_id", filters.todaId);
  if (filters.search) {
    const term = filters.search.replace(/[%,]/g, " ").trim();
    query = query.or(
      [
        `first_name.ilike.%${term}%`,
        `last_name.ilike.%${term}%`,
        `email.ilike.%${term}%`,
      ].join(","),
    );
  }

  const { data, count } = await query
    .order("created_at", { ascending: false })
    .range((page - 1) * pageSize, page * pageSize - 1);

  return { rows: (data ?? []) as unknown as Profile[], count: count ?? 0, page, pageSize };
}

export async function getUserProfile(id: string): Promise<Profile | null> {
  if (isDemoMode()) return demo.demoProfiles.find((profile) => profile.id === id) ?? null;
  const supabase = await createClient();
  const { data } = await supabase.from("profiles").select("*").eq("id", id).maybeSingle();
  return (data ?? null) as Profile | null;
}

/* -------------------------------------------------------------------------- */
/* Activity log                                                                */
/* -------------------------------------------------------------------------- */

export async function listActivityLogs(
  filters: LogFilters = {},
): Promise<ListResult<ActivityLog>> {
  const page = Math.max(filters.page ?? 1, 1);
  const pageSize = filters.pageSize ?? DEFAULT_PAGE_SIZE;

  if (isDemoMode()) {
    const rows = demo.demoActivityLogs.filter((log) => {
      if (filters.action && filters.action !== "all" && log.action !== filters.action) return false;
      if (filters.from && log.timestamp < filters.from) return false;
      if (filters.to && log.timestamp > `${filters.to}T23:59:59.999Z`) return false;
      if (filters.search) {
        const term = filters.search.toLowerCase();
        const haystack = [log.action, log.actor?.full_name ?? "", JSON.stringify(log.metadata)]
          .join(" ")
          .toLowerCase();
        if (!haystack.includes(term)) return false;
      }
      return true;
    });
    return paginate(rows, page, pageSize);
  }

  const supabase = await createClient();
  let query = supabase
    .from("activity_logs")
    .select("*, actor:profiles!activity_logs_user_id_fkey(id, full_name, email, role)", {
      count: "exact",
    });

  if (filters.action && filters.action !== "all") query = query.eq("action", filters.action);
  if (filters.from) query = query.gte("timestamp", filters.from);
  if (filters.to) query = query.lte("timestamp", `${filters.to}T23:59:59.999Z`);
  if (filters.search) {
    const term = filters.search.replace(/[%,]/g, " ").trim();
    query = query.or(`action.ilike.%${term}%`);
  }

  const { data, count } = await query
    .order("timestamp", { ascending: false })
    .range((page - 1) * pageSize, page * pageSize - 1);

  return {
    rows: (data ?? []) as unknown as ActivityLog[],
    count: count ?? 0,
    page,
    pageSize,
  };
}

export async function listRecentActivity(limit = 8): Promise<ActivityLog[]> {
  const result = await listActivityLogs({ page: 1, pageSize: limit });
  return result.rows;
}

/* -------------------------------------------------------------------------- */
/* Notifications and settings                                                  */
/* -------------------------------------------------------------------------- */

export async function listNotifications(limit = 12): Promise<Notification[]> {
  if (isDemoMode()) return demo.demoNotifications.slice(0, limit);
  const supabase = await createClient();
  const { data } = await supabase
    .from("notifications")
    .select("*")
    .order("created_at", { ascending: false })
    .limit(limit);
  return (data ?? []) as unknown as Notification[];
}

export async function listSettings(): Promise<SystemSetting[]> {
  if (isDemoMode()) return demo.demoSettings;
  const supabase = await createClient();
  const { data } = await supabase.from("system_settings").select("*").order("category");
  return (data ?? []) as unknown as SystemSetting[];
}

/* -------------------------------------------------------------------------- */
/* Certificate verification (public)                                           */
/* -------------------------------------------------------------------------- */

export async function verifyCertificate(code: string): Promise<CertificateVerification> {
  if (isDemoMode()) {
    const record = demo.demoRecords.find(
      (candidate) => candidate.verification_code === code.toUpperCase(),
    );
    if (!record) {
      return {
        verification_status: "not_found",
        franchise_number: null,
        operator_display_name: null,
        toda_name: null,
        issued_at: null,
        expires_at: null,
        verified_at: new Date().toISOString(),
      };
    }
    return {
      verification_status: record.archived
        ? "archived"
        : new Date(record.expires_at) < new Date()
          ? "expired"
          : "valid",
      franchise_number: record.franchise_number,
      operator_display_name: `${record.operator?.full_name?.charAt(0) ?? "X"}*** ***`,
      toda_name: record.toda?.name ?? null,
      issued_at: record.issued_at,
      expires_at: record.expires_at,
      verified_at: new Date().toISOString(),
    };
  }

  const supabase = await createClient();
  const { data, error } = await supabase.rpc("rpc_verify_certificate", { p_code: code });
  if (error) {
    return {
      verification_status: "not_found",
      franchise_number: null,
      operator_display_name: null,
      toda_name: null,
      issued_at: null,
      expires_at: null,
      verified_at: new Date().toISOString(),
    };
  }
  const row = Array.isArray(data) ? data[0] : data;
  return row as CertificateVerification;
}

/* -------------------------------------------------------------------------- */
/* Helpers                                                                     */
/* -------------------------------------------------------------------------- */

function paginate<T>(rows: T[], page: number, pageSize: number): ListResult<T> {
  return {
    rows: rows.slice((page - 1) * pageSize, page * pageSize),
    count: rows.length,
    page,
    pageSize,
  };
}
