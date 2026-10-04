import { NextResponse } from "next/server";

import { verifyCertificate } from "@/lib/data";
import {
  isWellFormedVerificationCode,
  normaliseVerificationCode,
} from "@/lib/verification";

/**
 * Server-side proxy for public certificate verification.
 *
 * The verification RPC is the one function granted to anonymous callers, but it
 * is still called from the server so that the browser never needs a Supabase
 * client, and so the response can be cached and rate-limited here later without
 * touching the database function.
 */
export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const code = normaliseVerificationCode(searchParams.get("code") ?? "");

  if (!isWellFormedVerificationCode(code)) {
    return NextResponse.json(
      {
        verification_status: "not_found",
        franchise_number: null,
        operator_display_name: null,
        toda_name: null,
        issued_at: null,
        expires_at: null,
        verified_at: new Date().toISOString(),
      },
      { status: 200 },
    );
  }

  try {
    const result = await verifyCertificate(code);
    return NextResponse.json(result, {
      headers: { "Cache-Control": "no-store" },
    });
  } catch {
    return NextResponse.json(
      { error: "verification_unavailable" },
      { status: 503, headers: { "Cache-Control": "no-store" } },
    );
  }
}
