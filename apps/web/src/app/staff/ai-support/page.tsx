import { AiAdvisoryPanel } from "@/components/ai/ai-advisory-panel";
import { SectionTitle } from "@/components/ui";
import { listSettings } from "@/lib/data";
import { requireStaff } from "@/lib/auth-guard";
import type { AiAdvisory, SystemSetting } from "@/types/database";

export const metadata = { title: "AI decision support — SBTF Staff" };

function setting(settings: SystemSetting[], key: string) {
  return settings.find((candidate) => candidate.key === key);
}

function sampleAdvisory(settings: SystemSetting[]): AiAdvisory {
  return {
    advisory_notice: String(setting(settings, "ai_advisory_notice")?.value ?? "Advisory — For Decision Support Only"),
    notice_detail:
      "Sample briefing shipped with the preview dataset. In a connected environment this content is produced by the configured Groq model from aggregated statistics.",
    generated_at: new Date().toISOString(),
    model: String(setting(settings, "ai_model")?.value ?? "llama-3.3-70b-versatile"),
    period_months: 12,
    data_as_of: new Date().toISOString(),
    descriptive_summary:
      "Sample content. The operations view shows how many applications are waiting, how long documents sit unverified, and which associations are renewing on schedule.",
    key_findings: [
      "Sample finding: the pending queue is dominated by applications awaiting document verification, not by decisions.",
      "Sample finding: processing time improves when documents are verified within two days of upload.",
    ],
    recommendations: [
      {
        title: "Sample recommendation: clear the document queue first",
        detail: "Verify uploaded documents before opening new applications each morning.",
        reason: "Applications with all four documents verified are decided the same week.",
        data_basis: "Pending document count and oldest pending age.",
        priority: "medium",
      },
    ],
    limitations: [
      "Sample content: no model was called to produce this preview.",
      "The operational figures are aggregates and cannot identify an individual case.",
    ],
    data_basis: {
      generated_at: new Date().toISOString(),
      sample: true,
      note: "Preview mode — no request was sent to Groq.",
    },
  };
}

export default async function StaffAiSupportPage() {
  await requireStaff();
  const settings = await listSettings();
  const enabled = Boolean(setting(settings, "ai_enabled")?.value ?? true);
  const limit = Number(setting(settings, "ai_max_requests_per_user_per_day")?.value ?? 20);

  return (
    <div>
      <SectionTitle
        title="AI decision support"
        description="Operational briefings drawn from aggregated statistics. Use them to plan the day, never as a substitute for the documentary requirements."
      />
      <AiAdvisoryPanel sampleAdvisory={sampleAdvisory(settings)} maxRequestsPerDay={limit} enabled={enabled} />
    </div>
  );
}
