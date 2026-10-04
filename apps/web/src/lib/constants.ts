import type { DocumentType, UserRole } from "@/types/database";

export const APP_NAME = "SBTF System";
export const MUNICIPALITY = "Municipality of Mabini";
export const PROVINCE = "Batangas";
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
