"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { Receipt } from "lucide-react";

import { Alert, Button, Card, CardHeader } from "@/components/ui";
import { recordFranchisePaymentAction } from "@/lib/actions/applications";
import type { FranchiseRecordDetail } from "@/types/database";

export function RecordPayment({
  record,
  readOnly = false,
}: {
  record: FranchiseRecordDetail;
  readOnly?: boolean;
}) {
  const router = useRouter();
  const [orNumber, setOrNumber] = useState(record.official_receipt_number ?? "");
  const [orDate, setOrDate] = useState(record.official_receipt_date ?? "");
  const [amount, setAmount] = useState(
    record.amount_paid !== null && record.amount_paid !== undefined
      ? String(record.amount_paid)
      : "",
  );
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState<{ ok: boolean; text: string } | null>(null);

  async function save() {
    setBusy(true);
    setMessage(null);
    const parsed = amount.trim() === "" ? null : Number(amount);
    if (parsed !== null && (Number.isNaN(parsed) || parsed < 0)) {
      setMessage({ ok: false, text: "Amount paid must be a positive number." });
      setBusy(false);
      return;
    }

    const result = await recordFranchisePaymentAction({
      recordId: record.id,
      orNumber: orNumber.trim(),
      orDate: orDate ? orDate : null,
      amountPaid: parsed,
    });
    setMessage({ ok: result.ok, text: result.message });
    setBusy(false);
    if (result.ok) router.refresh();
  }

  return (
    <Card>
      <CardHeader
        title="Payment details"
        description="Printed under PAID UNDER O.R. NO. on the Authority to Operate."
        icon={Receipt}
      />

      {message ? (
        <div className="mb-3">
          <Alert tone={message.ok ? "success" : "danger"}>{message.text}</Alert>
        </div>
      ) : null}

      <div className="grid gap-3 sm:grid-cols-3">
        <label className="text-[0.8125rem] text-ink">
          <span className="mb-1 block text-muted">O.R. number</span>
          <input
            className="w-full rounded-lg border border-line-strong bg-white px-3 py-2 text-[0.875rem]"
            value={orNumber}
            onChange={(event) => setOrNumber(event.target.value)}
            disabled={readOnly}
            placeholder="e.g. 1234567"
          />
        </label>
        <label className="text-[0.8125rem] text-ink">
          <span className="mb-1 block text-muted">O.R. date</span>
          <input
            type="date"
            className="w-full rounded-lg border border-line-strong bg-white px-3 py-2 text-[0.875rem]"
            value={orDate}
            onChange={(event) => setOrDate(event.target.value)}
            disabled={readOnly}
          />
        </label>
        <label className="text-[0.8125rem] text-ink">
          <span className="mb-1 block text-muted">Amount paid (PHP)</span>
          <input
            type="number"
            min="0"
            step="0.01"
            className="w-full rounded-lg border border-line-strong bg-white px-3 py-2 text-[0.875rem]"
            value={amount}
            onChange={(event) => setAmount(event.target.value)}
            disabled={readOnly}
            placeholder="0.00"
          />
        </label>
      </div>

      {readOnly ? null : (
        <div className="mt-3">
          <Button onClick={save} loading={busy}>
            Save payment details
          </Button>
        </div>
      )}
    </Card>
  );
}
