/// Domain constants shared by the mobile data layer.
///
/// Every value here mirrors the database contract in `supabase/migrations`
/// (or the web console's `src/lib/constants.ts`) so the two clients cannot
/// drift. Nothing here is environment-specific; build configuration lives in
/// `env.dart`.
library;

/// The four documentary requirements of a tricycle franchise, in the order the
/// database defines them (`public.document_type`, migration 0.1).
///
/// The order matters: `rpc_driver_submit_application` requires exactly these
/// four types, and the UI lists them in this sequence.
const List<String> requiredDocumentTypes = [
  'member_association_certificate',
  'or_cr',
  'cedula',
  'barangay_clearance',
];

/// Human-readable labels for each [requiredDocumentTypes] entry.
const Map<String, String> documentLabels = {
  'member_association_certificate': 'Member Association Certificate',
  'or_cr': 'OR / CR (Official Receipt & Certificate of Registration)',
  'cedula': 'Cedula (Community Tax Certificate)',
  'barangay_clearance': 'Barangay Clearance',
};

/// Short labels, used where the full label would wrap (tiles, chips).
const Map<String, String> documentShortLabels = {
  'member_association_certificate': 'Member Association Certificate',
  'or_cr': 'OR / CR',
  'cedula': 'Cedula',
  'barangay_clearance': 'Barangay Clearance',
};

/// Private storage buckets. Files are never public; both clients request
/// short-lived signed URLs (`20260101091000_phase0_storage.sql`).
abstract final class StorageBuckets {
  static const String documents = 'franchise-documents';
  static const String certificates = 'certificates';
}

/// Upload limits enforced by the storage policies and re-checked server-side by
/// `rpc_driver_submit_application` / `rpc_driver_replace_document`.
const int maxUploadBytes = 10 * 1024 * 1024; // 10 MB
const List<String> acceptedUploadMimeTypes = [
  'application/pdf',
  'image/jpeg',
  'image/png',
];

/// Certificate verification-code shape, matching
/// `public.fn_generate_verification_code()` exactly: 12 characters from a
/// 32-symbol alphabet that omits the confusable I, O, 0 and 1.
const String verificationCodeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const int verificationCodeLength = 12;
