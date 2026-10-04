import { AiAdvisoryPanel } from "@/components/ai/ai-advisory-panel";
import { SectionTitle } from "@/components/ui";
import { listSettings, listTodas } from "@/lib/data";
import { requireAdministrator } from "@/lib/auth-guard";
import type { AiAdvisory, SystemSetting } from "@/types/database";

export const metadata = { title: "AI decision support — SBTF Administrator" };

function setting(settings: SystemSetting[], key: string): SystemSetting | undefined {
  return settings.find((candidate) => candidate.key === key);
}

/**
 * In preview mode there is no Edge Function to call, so the page builds a small
 * sample briefing from the demonstration dataset. It is labelled as sample
 * content in the panel; nothing here is presented as a live model output.
 */
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
      "Sample content. In the demonstration dataset the municipality processes a steady volume of new and renewal applications, most licenses are decided inside the service target, and the documentary requirement most likely to need a second submission is the OR/CR.",
    key_findings: [
      "Sample finding: renewal applications cluster in the same months as new applications, which concentrates counter work.",
      "Sample finding: a small share of documents is rejected at first reading, mostly for legibility.",
      "Sample finding: several associations file far fewer applications than their masterlist size.",
    ],
    recommendations: [
      {
        title: "Sample recommendation: stagger renewal reminders",
        detail:
          "Send the 90-day reminder to associations in two groups so the counter work is spread over the month.",
        reason: "Renewal volume and new applications peak together.",
        data_basis: "Monthly submitted counts and application type split.",
        priority: "medium",
      },
      {
        title: "Sample recommendation: verify documents in one pass",
        detail:
          "Reserve the first working hour for document verification so applications do not wait on the reviewer.",
        reason: "The median processing time tracks the document verification queue.",
        data_basis: "Oldest pending document age per requirement.",
        priority: "low",
      },
    ],
    limitations: [
      "Sample content: no model was called to produce this preview.",
      "Aggregated statistics cannot attribute a delay to a specific counter or officer.",
    ],
    data_basis: {
      generated_at: new Date().toISOString(),
      sample: true,
      note: "Preview mode — no request was sent to Groq and nothing was written to ai_request_logs.",
    },
  };
}

export default async function AdminAiSupportPage() {
  await requireAdministrator();

  const [settings, todas] = await Promise.all([listSettings(), listTodas()]);

  const enabled = Boolean(setting(settings, "ai_enabled")?.value ?? true);
  const limit = Number(setting(settings, "ai_max_requests_per_user_per_day")?.value ?? 20);

  return (
    <div>
      <SectionTitle
        title="AI decision support"
        description={`Advisory briefings for the franchising office, generated from aggregated statistics of ${todas.length} associations. The model never approves, rejects or modifies anything.`}
      />
      <AiAdvisoryPanel sampleAdvisory={sampleAdvisory(settings)} maxRequestsPerDay={limit} enabled={enabled} />
    </div>
  );
}
