import type {
  AppointmentKind,
  AppointmentStatus,
  ApplicationStage,
  DocumentType,
  FormRequestStatus,
  UserRole,
} from "@/types/database";

export const APP_NAME = "SBTF System";
export const MUNICIPALITY = "Municipality of Mabini";
export const PROVINCE = "Batangas";

/**
 * The municipality's civil time zone. Every date shown in the interface and
 * every `datetime-local` value is interpreted in this zone, so a booking reads
 * the same whether it is rendered on a UTC server or in the operator's browser.
 * Philippine Standard Time is UTC+8 all year — it has never observed DST — so
 * the fixed offset below is exact.
 */
export const APP_TIME_ZONE = "Asia/Manila";
export const APP_TIME_ZONE_OFFSET = "+08:00";
export const SYSTEM_TITLE =
  "Franchising and Tricycle Driver Registration System";
export const SYSTEM_TITLE_LONG =
  "A Web and Mobile-Based Franchising and Tricycle Driver Registration System with Descriptive and Prescriptive Analytics and Decision Support";

export const ROLE_LABELS: Record<UserRole, string> = {
  administrator: "Administrator",
  staff: "Staff",
  driver: "Tricycle Driver / Operator",
};

export const ACCOUNT_STATUS_LABELS = {
  active: "Active",
  pending: "Awaiting approval",
  inactive: "Inactive",
  suspended: "Suspended",
} as const;

export const APPLICATION_TYPE_LABELS = {
  new: "New franchise",
  renewal: "Renewal",
} as const;

export const APPLICATION_STATUS_LABELS = {
  pending: "Pending",
  approved: "Approved",
  rejected: "Rejected",
} as const;

export const APPLICATION_STAGE_LABELS: Record<ApplicationStage, string> = {
  submitted: "Submitted",
  under_verification: "Under Verification",
  for_compliance: "For Compliance",
  verified: "Verified",
  recorded: "Application Recorded",
  for_endorsement: "For Endorsement",
  for_approval: "For Approval",
  ready_for_release: "Ready for Release",
  released: "Released",
  completed: "Completed",
  rejected: "Rejected",
};

export const APPLICATION_STAGE_ORDER: ApplicationStage[] = [
  "submitted",
  "under_verification",
  "for_compliance",
  "verified",
  "recorded",
  "for_endorsement",
  "for_approval",
  "ready_for_release",
  "released",
  "completed",
];

export const FORM_REQUEST_STATUS_LABELS: Record<FormRequestStatus, string> = {
  requested: "Requested",
  issued: "Issued",
  converted: "Converted",
  cancelled: "Cancelled",
};

export const APPOINTMENT_KIND_LABELS: Record<AppointmentKind, string> = {
  evaluation: "Evaluation",
  physical_documents: "Physical document submission",
  hearing: "Hearing",
  release: "Document release",
  other: "Other",
};

export const APPOINTMENT_STATUS_LABELS: Record<AppointmentStatus, string> = {
  scheduled: "Scheduled",
  completed: "Completed",
  no_show: "No show",
  rescheduled: "Rescheduled",
  cancelled: "Cancelled",
};

export const DOCUMENT_LABELS: Record<DocumentType, string> = {
  member_association_certificate: "Member Association Certificate",
  or_cr: "OR / CR (Official Receipt & Certificate of Registration)",
  cedula: "Cedula (Community Tax Certificate)",
  barangay_clearance: "Barangay Clearance",
};

export const DOCUMENT_SHORT_LABELS: Record<DocumentType, string> = {
  member_association_certificate: "Member Association Certificate",
  or_cr: "OR / CR",
  cedula: "Cedula",
  barangay_clearance: "Barangay Clearance",
};

export const REQUIRED_DOCUMENTS: DocumentType[] = [
  "member_association_certificate",
  "or_cr",
  "cedula",
  "barangay_clearance",
];

export const ADVISORY_NOTICE = "Advisory — For Decision Support Only";

export const STORAGE_BUCKETS = {
  documents: "franchise-documents",
  certificates: "certificates",
} as const;

export const MAX_UPLOAD_BYTES = 10 * 1024 * 1024;
export const ACCEPTED_UPLOAD_TYPES = [
  "application/pdf",
  "image/jpeg",
  "image/png",
];
