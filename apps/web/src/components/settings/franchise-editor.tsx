"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { ArrowDown, ArrowUp, Eye, Save, Stamp } from "lucide-react";

import {
  Alert,
  Badge,
  Button,
  Card,
  CardHeader,
  Field,
  SectionTitle,
} from "@/components/ui";
import { saveDocumentTemplateAction } from "@/lib/actions/settings";
import { buildCertificatePdf, type DocumentBlockKey } from "@/lib/certificate";
import { MUNICIPALITY, PROVINCE } from "@/lib/constants";
import {
  documentTemplateFrom,
  loadDocumentLogoDataUrl,
  type DocumentAlign,
  type DocumentTemplate,
} from "@/lib/document-template";
import { resolveVerificationBaseUrl } from "@/lib/verification";
import type { FranchiseRecordDetail, SystemSetting } from "@/types/database";

const OPTIONAL_BLOCKS: Array<{ key: DocumentBlockKey; label: string; description: string }> = [
  { key: "conditions", label: "Conditions of the franchise", description: "Numbered obligations of the operator." },
  { key: "order", label: "SO ORDERED", description: "The order line and its date." },
  { key: "signatures", label: "Signatories", description: "Approving authority and conforme signature." },
  { key: "payment", label: "O.R. payment details", description: "Receipt number, date and amount paid." },
];

const FIXED_BLOCKS: Array<{ key: DocumentBlockKey; label: string }> = [
  { key: "particulars", label: "Applicant particulars" },
  { key: "footer", label: "QR verification footer" },
];

function logoJustify(position: DocumentAlign): string {
  return position === "left" ? "justify-start" : position === "right" ? "justify-end" : "justify-center";
}

function textAlignClass(align: DocumentAlign): string {
  return align === "left" ? "text-left" : align === "right" ? "text-right" : "text-center";
}

export function FranchiseEditor({
  settings,
  sampleRecord,
}: {
  settings: SystemSetting[];
  sampleRecord: FranchiseRecordDetail | null;
}) {
  const router = useRouter();
  const [template, setTemplate] = useState<DocumentTemplate>(() => documentTemplateFrom(settings));
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState<{ ok: boolean; text: string } | null>(null);

  function set<K extends keyof DocumentTemplate>(key: K, value: DocumentTemplate[K]) {
    setTemplate((current) => ({ ...current, [key]: value }));
  }

  function move(key: DocumentBlockKey, direction: -1 | 1) {
    const optional = template.sectionOrder.filter((item) =>
      OPTIONAL_BLOCKS.some((block) => block.key === item),
    );
    const index = optional.indexOf(key);
    const next = index + direction;
    if (index < 0 || next < 0 || next >= optional.length) return;

    const reordered = [...optional];
    [reordered[index], reordered[next]] = [reordered[next]!, reordered[index]!];

    const result: DocumentBlockKey[] = ["particulars"];
    let cursor = 0;
    for (const item of template.sectionOrder) {
      if (!OPTIONAL_BLOCKS.some((block) => block.key === item)) continue;
      result.push(reordered[cursor]!);
      cursor += 1;
    }
    // Keep the footer anchored last.
    if (!result.includes("footer")) result.push("footer");
    set("sectionOrder", result);
  }

  async function save() {
    if (busy) return;
    setBusy(true);
    setMessage(null);
    const result = await saveDocumentTemplateAction({
      office_name: template.officeName,
      document_board_name: template.boardName,
      certificate_signatory_name: template.signatoryName,
      certificate_signatory_position: template.signatoryPosition,
      certificate_footer_note: template.footerNote,
      certificate_verification_base_url: template.verificationBaseUrl,
      document_logo_enabled: template.logoEnabled,
      document_logo_position: template.logoPosition,
      document_logo_width: template.logoWidth,
      document_header_align: template.headerAlign,
      document_section_order: template.sectionOrder,
    });
    setBusy(false);
    setMessage({ ok: result.ok, text: result.message });
    if (result.ok) router.refresh();
  }

  async function preview() {
    if (busy) return;
    if (!sampleRecord) {
      setMessage({
        ok: false,
        text: "Register at least one franchise record to preview the document with real data.",
      });
      return;
    }
    setBusy(true);
    setMessage(null);
    try {
      const logoDataUrl = template.logoEnabled ? await loadDocumentLogoDataUrl() : null;
      const application = sampleRecord.application;
      const operatorName =
        sampleRecord.operator?.full_name ??
        ([application?.operator_first_name, application?.operator_middle_name, application?.operator_last_name]
          .filter(Boolean)
          .join(" ") ||
          "Operator");
      const address = [application?.operator_address_line, MUNICIPALITY, PROVINCE]
        .filter((part) => Boolean(part && String(part).trim()))
        .join(", ");

      const doc = await buildCertificatePdf({
        franchiseNumber: sampleRecord.franchise_number,
        verificationCode: sampleRecord.verification_code,
        operatorName,
        operatorAddress: address,
        todaName: sampleRecord.toda?.name ?? "TODA",
        plateNumber: application?.plate_number ?? "—",
        vehicleMake: application?.vehicle_make ?? "—",
        vehicleModel: application?.vehicle_model ?? "—",
        vehicleYear: application?.vehicle_year ?? new Date().getFullYear(),
        vehicleColor: application?.vehicle_color ?? "—",
        engineNumber: application?.engine_number ?? "—",
        chassisNumber: application?.chassis_number ?? "—",
        seatingCapacity: application?.seating_capacity ?? 1,
        issuedAt: sampleRecord.issued_at,
        expiresAt: sampleRecord.expires_at,
        signatoryName: template.signatoryName,
        signatoryPosition: template.signatoryPosition,
        officeName: template.officeName,
        footerNote: template.footerNote,
        verificationBaseUrl: resolveVerificationBaseUrl(template.verificationBaseUrl, {
          requestOrigin: window.location.origin,
        }),
        logoDataUrl,
        logoEnabled: template.logoEnabled,
        logoPosition: template.logoPosition,
        logoWidth: template.logoWidth,
        headerAlign: template.headerAlign,
        sectionOrder: template.sectionOrder,
        applicationNumber: application?.application_number ?? undefined,
        route: application?.applied_route ?? undefined,
        registeredOwner: application?.registered_owner ?? undefined,
        ownershipType: application?.ownership_type ?? undefined,
        boardName: template.boardName,
        officialReceiptNumber: sampleRecord.official_receipt_number,
        officialReceiptDate: sampleRecord.official_receipt_date,
        amountPaid: sampleRecord.amount_paid,
        conformeName: operatorName,
      });

      const url = doc.output("bloburl");
      window.open(String(url), "_blank", "noopener,noreferrer");
    } catch (error) {
      setMessage({
        ok: false,
        text: `The preview could not be generated: ${error instanceof Error ? error.message : "unknown error"}`,
      });
    } finally {
      setBusy(false);
    }
  }

  return (
    <div>
      <SectionTitle
        title="Franchise Editor"
        description="Control the official document template: letterhead, logo placement, signatory and the order of optional blocks. Existing stored PDFs are unchanged until they are regenerated."
        action={
          <div className="flex gap-2">
            <Button variant="outline" onClick={preview} loading={busy}>
              <Eye className="h-4 w-4" /> Preview PDF
            </Button>
            <Button onClick={save} loading={busy}>
              <Save className="h-4 w-4" /> Save template
            </Button>
          </div>
        }
      />

      {message ? (
        <div className="mb-4">
          <Alert tone={message.ok ? "success" : "danger"}>{message.text}</Alert>
        </div>
      ) : null}

      <div className="grid gap-4 xl:grid-cols-[1.1fr_0.9fr]">
        <div className="space-y-4">
          <Card>
            <CardHeader
              title="Letterhead"
              description="Official identity printed on every Authority to Operate and application form."
              icon={Stamp}
            />
            <div className="grid gap-3 sm:grid-cols-2">
              <Field label="Board / office heading" htmlFor="editor-board">
                <input
                  id="editor-board"
                  className="sbtf-input"
                  value={template.boardName}
                  onChange={(event) => set("boardName", event.target.value)}
                />
              </Field>
              <Field label="Implementing office" htmlFor="editor-office">
                <input
                  id="editor-office"
                  className="sbtf-input"
                  value={template.officeName}
                  onChange={(event) => set("officeName", event.target.value)}
                />
              </Field>
              <Field label="Letterhead alignment" htmlFor="editor-align">
                <select
                  id="editor-align"
                  className="sbtf-input"
                  value={template.headerAlign}
                  onChange={(event) => set("headerAlign", event.target.value as DocumentAlign)}
                >
                  <option value="center">Center</option>
                  <option value="left">Left</option>
                  <option value="right">Right</option>
                </select>
              </Field>
            </div>
          </Card>

          <Card>
            <CardHeader
              title="Official logo"
              description="Mabini logo shown in the document header, preview and printed output."
            />
            <div className="grid gap-3 sm:grid-cols-3">
              <Field label="Logo" htmlFor="editor-logo-enabled">
                <label className="flex min-h-10 items-center gap-2 rounded-lg border border-line px-3 text-[0.8125rem]">
                  <input
                    id="editor-logo-enabled"
                    type="checkbox"
                    checked={template.logoEnabled}
                    onChange={(event) => set("logoEnabled", event.target.checked)}
                  />
                  Show logo
                </label>
              </Field>
              <Field label="Placement" htmlFor="editor-logo-position">
                <select
                  id="editor-logo-position"
                  className="sbtf-input"
                  value={template.logoPosition}
                  onChange={(event) => set("logoPosition", event.target.value as DocumentAlign)}
                  disabled={!template.logoEnabled}
                >
                  <option value="left">Left</option>
                  <option value="center">Center (above text)</option>
                  <option value="right">Right</option>
                </select>
              </Field>
              <Field label="Width (mm)" htmlFor="editor-logo-width" hint="16–40 mm">
                <input
                  id="editor-logo-width"
                  type="number"
                  min={16}
                  max={40}
                  className="sbtf-input"
                  value={template.logoWidth}
                  onChange={(event) => set("logoWidth", Number(event.target.value))}
                  disabled={!template.logoEnabled}
                />
              </Field>
            </div>
          </Card>

          <Card>
            <CardHeader
              title="Signatory and footer"
              description="Required official information always stays on the document."
            />
            <div className="grid gap-3 sm:grid-cols-2">
              <Field label="Signatory name" htmlFor="editor-signatory">
                <input
                  id="editor-signatory"
                  className="sbtf-input"
                  value={template.signatoryName}
                  onChange={(event) => set("signatoryName", event.target.value)}
                />
              </Field>
              <Field label="Signatory position" htmlFor="editor-signatory-position">
                <input
                  id="editor-signatory-position"
                  className="sbtf-input"
                  value={template.signatoryPosition}
                  onChange={(event) => set("signatoryPosition", event.target.value)}
                />
              </Field>
              <Field label="Verification URL" htmlFor="editor-verify">
                <input
                  id="editor-verify"
                  className="sbtf-input"
                  value={template.verificationBaseUrl}
                  onChange={(event) => set("verificationBaseUrl", event.target.value)}
                  placeholder="https://your-domain/verify"
                />
              </Field>
              <Field label="Footer note" htmlFor="editor-footer">
                <input
                  id="editor-footer"
                  className="sbtf-input"
                  value={template.footerNote}
                  onChange={(event) => set("footerNote", event.target.value)}
                />
              </Field>
            </div>
          </Card>

          <Card>
            <CardHeader
              title="Optional block order"
              description="Required blocks are locked. Reorder the optional blocks to match your office's layout."
            />
            <div className="mb-3 flex flex-wrap gap-1.5">
              {FIXED_BLOCKS.map((block) => (
                <Badge key={block.key} tone="approved">
                  {block.label} · locked
                </Badge>
              ))}
            </div>
            <ol className="space-y-2">
              {template.sectionOrder
                .filter((key) => OPTIONAL_BLOCKS.some((block) => block.key === key))
                .map((key, index, list) => {
                  const block = OPTIONAL_BLOCKS.find((candidate) => candidate.key === key)!;
                  return (
                    <li
                      key={key}
                      className="flex items-center justify-between gap-3 rounded-lg border border-line bg-page/40 px-3 py-2"
                    >
                      <div>
                        <p className="text-[0.8125rem] font-medium text-ink">
                          {index + 1}. {block.label}
                        </p>
                        <p className="text-[0.75rem] text-muted">{block.description}</p>
                      </div>
                      <div className="flex gap-1">
                        <Button
                          variant="ghost"
                          onClick={() => move(key, -1)}
                          disabled={index === 0}
                          title="Move up"
                        >
                          <ArrowUp className="h-4 w-4" />
                        </Button>
                        <Button
                          variant="ghost"
                          onClick={() => move(key, 1)}
                          disabled={index === list.length - 1}
                          title="Move down"
                        >
                          <ArrowDown className="h-4 w-4" />
                        </Button>
                      </div>
                    </li>
                  );
                })}
            </ol>
          </Card>
        </div>

        <Card className="h-fit xl:sticky xl:top-4">
          <CardHeader title="Live preview" description="Mirrors the saved template before you print." />
          <div className="rounded-lg border border-line bg-white p-4 text-[0.6875rem] text-[#161213] shadow-sm">
            <div className={`mb-2 flex ${logoJustify(template.logoPosition)}`}>
              {template.logoEnabled ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img
                  src="/mabini-logo.png"
                  alt="Mabini logo"
                  style={{ width: `${template.logoWidth * 1.6}px`, height: `${template.logoWidth * 1.6}px` }}
                  className="object-contain"
                />
              ) : null}
            </div>
            <div className={textAlignClass(template.headerAlign)}>
              <p>Republic of the Philippines</p>
              <p>Province of {PROVINCE}</p>
              <p>{MUNICIPALITY}</p>
              <p className="mt-1 font-semibold uppercase">{template.boardName || "Board heading"}</p>
            </div>
            <hr className="my-2 border-primary-700" />
            <p className="text-center text-[0.8125rem] font-bold">AUTHORITY TO OPERATE</p>
            <p className="text-center text-[0.75rem] font-bold">MOTORIZED TRICYCLE SERVICE</p>
            <p className="mt-2 text-justify leading-relaxed">
              This Authority is issued to <strong>{sampleRecord?.operator?.full_name ?? "Operator name"}</strong>, of{" "}
              {sampleRecord?.application?.operator_address_line ?? "address"}, authorizing the operation of ONE (1)
              tricycle unit for public service under the following particulars:
            </p>
            <div className="mt-2 space-y-1">
              <div className="flex justify-between border-b border-gray-300 py-0.5">
                <span className="font-semibold">Franchise No.</span>
                <span>{sampleRecord?.franchise_number ?? "MAB-TR-YYYY-NNNNNN"}</span>
              </div>
              <div className="flex justify-between border-b border-gray-300 py-0.5">
                <span className="font-semibold">Plate No.</span>
                <span>{sampleRecord?.application?.plate_number ?? "—"}</span>
              </div>
            </div>

            {template.sectionOrder
              .filter((key) => OPTIONAL_BLOCKS.some((block) => block.key === key))
              .map((key) => (
                <div key={key} className="mt-3">
                  <p className="font-semibold">
                    {OPTIONAL_BLOCKS.find((block) => block.key === key)!.label}
                  </p>
                  <div className="mt-1 space-y-1">
                    <div className="h-1 rounded bg-gray-200" />
                    <div className="h-1 w-11/12 rounded bg-gray-200" />
                    <div className="h-1 w-4/5 rounded bg-gray-200" />
                  </div>
                </div>
              ))}

            <div className="mt-4 border-t border-primary-700 pt-2">
              <p className="text-right font-semibold">{template.signatoryName}</p>
              <p className="text-right">{template.signatoryPosition}</p>
            </div>
            <p className="mt-2 text-[0.625rem] text-gray-600">{template.footerNote}</p>
          </div>
          <p className="mt-3 text-[0.75rem] text-muted">
            {sampleRecord
              ? `Preview uses ${sampleRecord.franchise_number} as live sample data.`
              : "No franchise record yet — the preview shows the template only."}
          </p>
        </Card>
      </div>
    </div>
  );
}
