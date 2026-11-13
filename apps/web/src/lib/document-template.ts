import { DEFAULT_SECTION_ORDER, type DocumentBlockKey } from "@/lib/certificate";
import type { SystemSetting } from "@/types/database";

export type DocumentAlign = "left" | "center" | "right";

export interface DocumentTemplate {
  logoEnabled: boolean;
  logoPosition: DocumentAlign;
  logoWidth: number;
  headerAlign: DocumentAlign;
  boardName: string;
  officeName: string;
  signatoryName: string;
  signatoryPosition: string;
  footerNote: string;
  verificationBaseUrl: string;
  sectionOrder: DocumentBlockKey[];
}

export const DEFAULT_DOCUMENT_TEMPLATE: DocumentTemplate = {
  logoEnabled: true,
  logoPosition: "left",
  logoWidth: 22,
  headerAlign: "center",
  boardName: "SANGGUNIANG BAYAN NG MABINI",
  officeName: "Sangguniang Bayan ng Mabini — Committee on Transportation",
  signatoryName: "Municipal Mayor",
  signatoryPosition: "Municipal Mayor",
  footerNote: "This Authority is verifiable through the QR code printed on it.",
  verificationBaseUrl: "",
  sectionOrder: DEFAULT_SECTION_ORDER,
};

function settingValue<T>(
  settings: SystemSetting[],
  key: string,
  fallback: T,
): T {
  const setting = settings.find((candidate) => candidate.key === key);
  if (!setting) return fallback;
  return setting.value as T;
}

function align(value: unknown, fallback: DocumentAlign): DocumentAlign {
  return value === "left" || value === "center" || value === "right" ? value : fallback;
}

/** Maps the stored `system_settings` rows into the document builder contract. */
export function documentTemplateFrom(settings: SystemSetting[]): DocumentTemplate {
  const order = settingValue<unknown>(settings, "document_section_order", DEFAULT_SECTION_ORDER);

  return {
    logoEnabled:
      settingValue<boolean>(settings, "document_logo_enabled", true) !== false,
    logoPosition: align(settingValue(settings, "document_logo_position", "left"), "left"),
    logoWidth: Number(settingValue(settings, "document_logo_width", 22)) || 22,
    headerAlign: align(settingValue(settings, "document_header_align", "center"), "center"),
    boardName: String(
      settingValue(settings, "document_board_name", DEFAULT_DOCUMENT_TEMPLATE.boardName),
    ),
    officeName: String(
      settingValue(settings, "office_name", DEFAULT_DOCUMENT_TEMPLATE.officeName),
    ),
    signatoryName: String(
      settingValue(
        settings,
        "certificate_signatory_name",
        DEFAULT_DOCUMENT_TEMPLATE.signatoryName,
      ),
    ),
    signatoryPosition: String(
      settingValue(
        settings,
        "certificate_signatory_position",
        DEFAULT_DOCUMENT_TEMPLATE.signatoryPosition,
      ),
    ),
    footerNote: String(
      settingValue(settings, "certificate_footer_note", DEFAULT_DOCUMENT_TEMPLATE.footerNote),
    ),
    verificationBaseUrl: String(settingValue(settings, "certificate_verification_base_url", "")),
    sectionOrder: Array.isArray(order)
      ? (order.filter((key) =>
          DEFAULT_SECTION_ORDER.includes(key as DocumentBlockKey),
        ) as DocumentBlockKey[])
      : DEFAULT_SECTION_ORDER,
  };
}

/**
 * Loads the official logo as a data URL for the browser-only PDF builders.
 * Returns null when the asset cannot be read so a document still generates
 * without branding rather than failing outright.
 */
export async function loadDocumentLogoDataUrl(): Promise<string | null> {
  try {
    const response = await fetch("/mabini-logo.png");
    if (!response.ok) return null;
    const blob = await response.blob();
    return await new Promise<string>((resolve, reject) => {
      const reader = new FileReader();
      reader.onloadend = () => resolve(String(reader.result));
      reader.onerror = reject;
      reader.readAsDataURL(blob);
    });
  } catch {
    return null;
  }
}
