/**
 * Application-level types mirroring the PostgreSQL schema in
 * supabase/migrations. Kept hand-written (and reviewed against the migrations)
 * so that the web application compiles without a live Supabase project.
 */

export type UserRole = "administrator" | "staff" | "driver";
export type AccountStatus = "active" | "inactive" | "suspended";
export type ApplicationType = "new" | "renewal";
export type ApplicationStatus = "pending" | "approved" | "rejected";
export type DocumentType =
  | "member_association_certificate"
  | "or_cr"
  | "cedula"
  | "barangay_clearance";
export type DocumentVerificationStatus = "pending" | "verified" | "rejected";
export type NotificationType =
  | "application_submitted"
  | "application_approved"
  | "application_rejected"
  | "document_verified"
  | "document_rejected"
  | "renewal_reminder"
  | "application_under_review"
  | "account_updated"
  | "system";
export type ActivityAction =
  | "login"
  | "logout"
  | "registration"
  | "profile_update"
  | "notification_preferences_update"
  | "application_submitted"
  | "application_renewal_submitted"
  | "document_upload"
  | "document_replaced"
  | "document_verification"
  | "review_started"
  | "application_approved"
  | "application_rejected"
  | "record_created"
  | "record_update"
  | "franchise_archived"
  | "certificate_generation"
  | "role_change"
  | "user_activated"
  | "user_deactivated"
  | "user_created"
  | "settings_update"
  | "ai_request"
  | "renewal_reminder_sent"
  | "security_event";
export type LogTargetType =
  | "profile"
  | "franchise_application"
  | "franchise_document"
  | "franchise_record"
  | "system_setting"
  | "toda"
  | "system";

export interface Profile {
  id: string;
  auth_user_id: string | null;
  role: UserRole;
  first_name: string;
  middle_name: string | null;
  last_name: string;
  full_name: string;
  email: string;
  contact_number: string | null;
  address_line: string | null;
  barangay_code: string | null;
  toda_id: string | null;
  account_status: AccountStatus;
  status_reason: string | null;
  email_notifications: boolean;
  renewal_reminders: boolean;
  last_login_at: string | null;
  created_at: string;
  updated_at: string;
}

export interface Barangay {
  code: string;
  name: string;
}

export interface Toda {
  id: string;
  code: string;
  name: string;
  barangay_code: string | null;
  zone: string | null;
  members_count: number;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export interface FranchiseApplication {
  id: string;
  application_number: string;
  applicant_id: string;
  application_type: ApplicationType;
  status: ApplicationStatus;
  toda_id: string;
  operator_first_name: string;
  operator_middle_name: string | null;
  operator_last_name: string;
  operator_contact_number: string;
  operator_address_line: string;
  operator_barangay_code: string | null;
  operator_email: string | null;
  vehicle_make: string;
  vehicle_model: string;
  vehicle_year: number;
  vehicle_color: string;
  plate_number: string;
  engine_number: string;
  chassis_number: string;
  seating_capacity: number;
  mtop_number: string | null;
  body_number: string | null;
  renewal_of_record_id: string | null;
  remarks: string | null;
  submitted_at: string;
  review_started_at: string | null;
  review_started_by: string | null;
  reviewed_by: string | null;
  reviewed_at: string | null;
  rejection_reason: string | null;
  created_at: string;
  updated_at: string;
}

export interface FranchiseApplicationDetail extends FranchiseApplication {
  applicant?: Pick<Profile, "id" | "full_name" | "email" | "contact_number" | "account_status"> | null;
  toda?: Pick<Toda, "id" | "name" | "code"> | null;
  documents?: FranchiseDocument[];
  reviewer?: Pick<Profile, "id" | "full_name"> | null;
  record?: Pick<FranchiseRecord, "id" | "franchise_number" | "issued_at" | "expires_at" | "archived"> | null;
  timeline?: ApplicationStatusHistory[];
}

export interface FranchiseDocument {
  id: string;
  application_id: string;
  document_type: DocumentType;
  storage_path: string;
  file_name: string;
  file_size_bytes: number | null;
  mime_type: string | null;
  verification_status: DocumentVerificationStatus;
  verified_by: string | null;
  verified_at: string | null;
  remarks: string | null;
  uploaded_at: string;
  updated_at: string;
}

export interface FranchiseRecord {
  id: string;
  application_id: string;
  operator_id: string;
  toda_id: string;
  franchise_number: string;
  verification_code: string;
  issued_at: string;
  expires_at: string;
  certificate_storage_path: string | null;
  certificate_generated_at: string | null;
  renewed_by_record_id: string | null;
  archived: boolean;
  archived_at: string | null;
  archived_by: string | null;
  archive_reason: string | null;
  created_at: string;
  updated_at: string;
}

export interface FranchiseRecordDetail extends FranchiseRecord {
  operator?: Pick<Profile, "id" | "full_name" | "email" | "contact_number"> | null;
  toda?: Pick<Toda, "id" | "name" | "code"> | null;
  application?: Pick<FranchiseApplication, "id" | "application_number" | "application_type" | "plate_number" | "vehicle_make" | "vehicle_model" | "vehicle_year"> | null;
}

export interface ApplicationStatusHistory {
  id: string;
  application_id: string;
  event:
    | "created"
    | "document_uploaded"
    | "document_replaced"
    | "document_verified"
    | "document_rejected"
    | "review_started"
    | "approved"
    | "rejected"
    | "certificate_issued"
    | "archived";
  actor_id: string | null;
  note: string | null;
  created_at: string;
}

export interface Notification {
  id: string;
  user_id: string;
  title: string;
  message: string;
  notification_type: NotificationType;
  target_type: LogTargetType | null;
  target_id: string | null;
  read: boolean;
  read_at: string | null;
  created_at: string;
}

export interface ActivityLog {
  id: string;
  user_id: string | null;
  action: ActivityAction;
  target_type: LogTargetType | null;
  target_id: string | null;
  metadata: Record<string, unknown>;
  context: Record<string, unknown>;
  timestamp: string;
  actor?: Pick<Profile, "id" | "full_name" | "email" | "role"> | null;
}

export interface SystemSetting {
  key: string;
  value: unknown;
  data_type: "string" | "number" | "boolean" | "json" | "string_array";
  category: "general" | "franchise" | "notifications" | "ai" | "certificate";
  label: string;
  description: string;
  is_public: boolean;
  updated_by: string | null;
  updated_at: string;
}

// --- analytics --------------------------------------------------------------

export interface AnalyticsOverview {
  total_applications: number;
  pending_applications: number;
  approved_applications: number;
  rejected_applications: number;
  new_applications: number;
  renewal_applications: number;
  approval_rate: number | null;
  rejection_rate: number | null;
  avg_processing_days: number | null;
  median_processing_days: number | null;
  active_drivers: number;
  active_franchises: number;
  expiring_30: number;
  expiring_60: number;
  expiring_90: number;
  expired_franchises: number;
  total_todas: number;
  total_toda_members: number;
  verified_documents: number;
  pending_documents: number;
  rejected_documents: number;
  submitted_last_30_days: number;
  submitted_previous_30_days: number;
  decided_last_30_days: number;
  unread_notifications: number;
}

export interface TrendPoint {
  month_start: string;
  month_label: string;
  submitted: number;
  new_count: number;
  renewal_count: number;
  approved: number;
  rejected: number;
  decided: number;
  avg_process_days: number | null;
}

export interface TodaAnalytics {
  toda_id: string;
  toda_name: string;
  members_count: number;
  applications: number;
  new_applications: number;
  renewal_applications: number;
  approved: number;
  rejected: number;
  pending: number;
  active_franchises: number;
  approval_rate: number | null;
  last_submission_at: string | null;
}

export interface ProcessingTimePoint {
  month_start: string;
  month_label: string;
  decided: number;
  approved: number;
  rejected: number;
  avg_days: number | null;
  median_days: number | null;
  p90_days: number | null;
  longest_days: number | null;
}

export interface ExpiringRecord {
  record_id: string;
  franchise_number: string;
  operator_name: string;
  toda_name: string;
  expires_at: string;
  days_remaining: number;
  bucket: "expired" | "0-30 days" | "31-60 days" | "61-90 days" | "91+ days";
}

export interface DocumentComplianceRow {
  document_type: DocumentType;
  total: number;
  verified: number;
  pending: number;
  rejected: number;
  verified_rate: number | null;
  oldest_pending_days: number | null;
}

export interface PrescriptiveIndicator {
  indicator_key: string;
  severity: "attention" | "critical";
  category: string;
  finding: string;
  recommendation: string;
  data_basis: string;
  metric_value: number | null;
  threshold_value: number | null;
}

export interface SystemHealth {
  users_total: number;
  users_administrators: number;
  users_staff: number;
  users_drivers: number;
  users_inactive: number;
  activity_logs_7d: number;
  ai_requests_30d: number;
  ai_requests_failed_30d: number;
  certificates_issued: number;
  document_objects: number;
  certificate_objects: number;
  last_activity_at: string | null;
}

export interface AiRecommendation {
  title: string;
  detail: string;
  reason: string;
  data_basis: string;
  priority: "high" | "medium" | "low";
}

export interface AiAdvisory {
  advisory_notice: string;
  notice_detail: string;
  generated_at: string;
  model: string;
  period_months: number;
  data_as_of: string | null;
  descriptive_summary: string;
  key_findings: string[];
  recommendations: AiRecommendation[];
  limitations: string[];
  data_basis: Record<string, unknown>;
}

export interface CertificateVerification {
  verification_status: "valid" | "expired" | "archived" | "not_found";
  franchise_number: string | null;
  operator_display_name: string | null;
  toda_name: string | null;
  issued_at: string | null;
  expires_at: string | null;
  verified_at: string;
}
