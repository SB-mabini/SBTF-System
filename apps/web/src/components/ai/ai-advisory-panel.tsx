"use client";

import { useState } from "react";
import { AlertTriangle, Brain, CalendarRange, RefreshCw, ShieldCheck, Sparkles } from "lucide-react";

import { AdvisoryBanner, Alert, Badge, Button, Card, CardHeader, Spinner } from "@/components/ui";
import { isDemoMode } from "@/lib/env";
import { formatDateTime, humanizeKey } from "@/lib/format";
import { getBrowserClient } from "@/lib/supabase/client";
import type { AiAdvisory } from "@/types/database";

const PRIORITY_TONE = {
  high: "danger",
  medium: "warning",
  low: "neutral",
} as const;

/**
 * AI decision-support panel.
 *
 * The browser never sees the Groq API key: the request goes to the
 * `ai-decision-support` Supabase Edge Function with the caller's own access
 * token, and the function talks to Groq server-side using aggregated,
 * anonymised statistics only.
 */
export function AiAdvisoryPanel({
  sampleAdvisory,
  maxRequestsPerDay,
  enabled,
}: {
  sampleAdvisory: AiAdvisory | null;
  maxRequestsPerDay: number;
  enabled: boolean;
}) {
  const [months, setMonths] = useState(12);
  const [busy, setBusy] = useState(false);
  const [advisory, setAdvisory] = useState<AiAdvisory | null>(sampleAdvisory);
  const [error, setError] = useState<string | null>(null);
  const demo = isDemoMode();

  async function generate() {
    setBusy(true);
    setError(null);

    if (demo) {
      setAdvisory(sampleAdvisory);
      setBusy(false);
      return;
    }

    const supabase = getBrowserClient();
    const { data, error: invokeError } = await supabase.functions.invoke<AiAdvisory>(
      "ai-decision-support",
      { body: { months } },
    );

    setBusy(false);

    if (invokeError) {
      setError(
        `The advisory could not be generated (${invokeError.message}). The franchising office can still process applications normally — this feature is optional.`,
      );
      return;
    }
    if (!data) {
      setError("The AI service returned an empty response.");
      return;
    }
    setAdvisory(data);
  }

  return (
    <div className="space-y-4">
      <Card>
        <CardHeader
          title="Generate a decision-support briefing"
          description="The model receives aggregated counters and rates only: no names, no contact details, no plate or engine numbers."
          icon={Brain}
          action={
            <Badge tone={enabled ? "success" : "warning"}>
              {enabled ? "AI enabled" : "AI disabled by the administrator"}
            </Badge>
          }
        />

        <div className="flex flex-wrap items-end gap-3">
          <div className="min-w-[180px]">
            <label className="sbtf-label" htmlFor="ai-months">
              Analysis period
            </label>
            <select
              id="ai-months"
              className="sbtf-input"
              value={months}
              onChange={(event) => setMonths(Number(event.target.value))}
              disabled={busy}
            >
              <option value={3}>Last 3 months</option>
              <option value={6}>Last 6 months</option>
              <option value={12}>Last 12 months</option>
              <option value={24}>Last 24 months</option>
            </select>
          </div>

          <Button onClick={generate} loading={busy} disabled={!enabled && !demo}>
            {advisory ? <RefreshCw className="h-4 w-4" /> : <Sparkles className="h-4 w-4" />}
            {advisory ? "Regenerate briefing" : "Generate briefing"}
          </Button>
        </div>

        <p className="mt-3 text-[0.75rem] text-muted">
          Each request is logged with the model, latency, token counts and hashes of the prompt — never
          the text of personal records. The daily limit is {maxRequestsPerDay} request(s) per user.
        </p>

        {demo ? (
          <div className="mt-3">
            <Alert tone="warning" title="Preview mode">
              The briefing below is sample content shipped with the demonstration dataset. In a
              connected environment the button calls the Groq model through the Supabase Edge
              Function.
            </Alert>
          </div>
        ) : null}

        {error ? (
          <div className="mt-3">
            <Alert tone="danger" title="Advisory unavailable">
              {error}
            </Alert>
          </div>
        ) : null}

        {busy && !demo ? (
          <div className="mt-4 flex items-center gap-2 rounded-lg border border-line bg-page px-3 py-6">
            <Spinner label="Preparing aggregated statistics and asking the model…" />
          </div>
        ) : null}
      </Card>

      {advisory ? (
        <>
          <AdvisoryBanner>{advisory.advisory_notice}</AdvisoryBanner>

          <div className="grid gap-4 xl:grid-cols-3">
            <Card className="xl:col-span-2">
              <CardHeader
                title="Descriptive summary"
                description={`Generated ${formatDateTime(advisory.generated_at)} · model ${advisory.model} · period ${advisory.period_months} months`}
                icon={Sparkles}
              />
              <p className="text-[0.875rem] leading-relaxed text-ink">{advisory.descriptive_summary}</p>

              {advisory.key_findings.length > 0 ? (
                <>
                  <h3 className="mt-4 text-[0.8125rem] font-semibold uppercase tracking-wide text-muted">
                    Key findings
                  </h3>
                  <ul className="mt-2 space-y-2">
                    {advisory.key_findings.map((finding, index) => (
                      <li key={index} className="flex gap-2.5 text-[0.8125rem] text-ink">
                        <span className="mt-1.5 h-1.5 w-1.5 shrink-0 rounded-full bg-primary" />
                        {finding}
                      </li>
                    ))}
                  </ul>
                </>
              ) : null}
            </Card>

            <Card>
              <CardHeader title="How to read this" icon={ShieldCheck} />
              <ul className="space-y-2.5 text-[0.8125rem] text-muted">
                <li>
                  The briefing is <span className="font-medium text-ink">advisory only</span>. Every
                  approval, rejection and record change is made by a member of the franchising office
                  through the normal workflow.
                </li>
                <li>
                  Recommendations are generated from aggregate statistics; they can be wrong. Staff
                  should check the underlying figures in the Analytics screen before acting.
                </li>
                <li>
                  Nothing the model returns is written back into applications, franchise records,
                  accounts or settings.
                </li>
              </ul>

              {advisory.limitations.length > 0 ? (
                <>
                  <h3 className="mt-4 text-[0.8125rem] font-semibold uppercase tracking-wide text-muted">
                    Stated limitations
                  </h3>
                  <ul className="mt-2 space-y-2">
                    {advisory.limitations.map((limitation, index) => (
                      <li key={index} className="flex gap-2 text-[0.8125rem] text-muted">
                        <AlertTriangle className="mt-0.5 h-3.5 w-3.5 shrink-0 text-warning-600" />
                        {limitation}
                      </li>
                    ))}
                  </ul>
                </>
              ) : null}
            </Card>
          </div>

          {advisory.recommendations.length > 0 ? (
            <Card>
              <CardHeader
                title="Recommendations"
                description="Each recommendation cites the statistic it is based on so it can be verified."
                icon={Sparkles}
              />
              <ol className="space-y-3">
                {advisory.recommendations.map((recommendation, index) => (
                  <li key={index} className="rounded-lg border border-line p-4">
                    <div className="flex flex-wrap items-start justify-between gap-2">
                      <h3 className="text-[0.875rem] font-semibold text-ink">{recommendation.title}</h3>
                      <Badge tone={PRIORITY_TONE[recommendation.priority]}>
                        {recommendation.priority} priority
                      </Badge>
                    </div>
                    <p className="mt-2 text-[0.8125rem] text-ink">{recommendation.detail}</p>
                    <dl className="mt-3 space-y-1.5 text-[0.75rem]">
                      <div>
                        <dt className="inline font-medium text-muted">Reason: </dt>
                        <dd className="inline text-ink">{recommendation.reason}</dd>
                      </div>
                      <div>
                        <dt className="inline font-medium text-muted">Data basis: </dt>
                        <dd className="inline text-ink">{recommendation.data_basis}</dd>
                      </div>
                    </dl>
                  </li>
                ))}
              </ol>
            </Card>
          ) : null}

          <Card>
            <CardHeader
              title="Statistics sent to the model"
              description="The complete payload: aggregated figures only, reproducible from the Analytics screen."
              icon={CalendarRange}
            />
            <div className="grid gap-2 sm:grid-cols-2 lg:grid-cols-3">
              {Object.entries(advisory.data_basis ?? {})
                .filter(([, value]) => typeof value !== "object")
                .map(([key, value]) => (
                  <div key={key} className="rounded-md bg-page px-3 py-2">
                    <p className="text-[0.6875rem] uppercase tracking-wide text-muted">
                      {humanizeKey(key)}
                    </p>
                    <p className="text-[0.875rem] font-medium tabular-nums text-ink">{String(value)}</p>
                  </div>
                ))}
            </div>
            <p className="mt-3 text-[0.75rem] text-muted">
              Data as of {advisory.data_as_of ? formatDateTime(advisory.data_as_of) : "the time of the request"}.
              Nested values in the same payload are aggregate breakdowns by month and by association
              code; no individual record is included.
            </p>
          </Card>
        </>
      ) : (
        <Card>
          <div className="py-6 text-center">
            <p className="text-[0.875rem] font-medium text-ink">No briefing has been generated yet</p>
            <p className="mx-auto mt-1 max-w-xl text-[0.8125rem] text-muted">
              Generating a briefing sends the aggregated statistics for the selected period to the
              configured Groq model and records the request in the AI request log.
            </p>
          </div>
        </Card>
      )}
    </div>
  );
}
