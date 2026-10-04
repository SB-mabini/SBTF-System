"use client";

import { useEffect, useState } from "react";
import QRCode from "qrcode";
import { QrCode } from "lucide-react";

import { buildVerificationUrl } from "@/lib/verification";

/**
 * Renders the same QR payload that is printed on the certificate: the public
 * verification URL plus the opaque verification code. No personal data is
 * encoded — scanning it only reveals the identifier the municipality published.
 */
export function VerificationQr({
  code,
  baseUrl,
  size = 168,
}: {
  code: string;
  baseUrl: string;
  size?: number;
}) {
  const [dataUrl, setDataUrl] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;

    const url = buildVerificationUrl(baseUrl, code);

    QRCode.toDataURL(url, {
      errorCorrectionLevel: "M",
      margin: 1,
      width: size * 2,
      color: { dark: "#271564", light: "#FFFFFF" },
    })
      .then((result) => {
        if (!cancelled) setDataUrl(result);
      })
      .catch((cause: unknown) => {
        if (!cancelled) setError(cause instanceof Error ? cause.message : "QR generation failed");
      });

    return () => {
      cancelled = true;
    };
  }, [code, baseUrl, size]);

  return (
    <div className="flex flex-col items-center">
      <div
        className="flex items-center justify-center rounded-lg border border-line bg-white p-3"
        style={{ width: size, height: size }}
      >
        {dataUrl ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img src={dataUrl} alt={`Verification QR code for ${code}`} width={size - 24} height={size - 24} />
        ) : (
          <span className="text-center text-[0.6875rem] text-muted">
            {error ?? <QrCode className="h-6 w-6 animate-pulse text-line-strong" />}
          </span>
        )}
      </div>
      <p className="mt-2 font-mono text-[0.8125rem] font-medium text-ink">{code}</p>
      <p className="text-center text-[0.6875rem] text-muted">
        Points to the public verification page
      </p>
    </div>
  );
}
