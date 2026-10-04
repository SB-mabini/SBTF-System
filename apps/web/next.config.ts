import type { NextConfig } from "next";

// The sandbox/preview build runs inside an iframe on another host, so framing
// protection is applied to production deployments only (or when embedding is
// explicitly allowed). Deployments should additionally set a
// Content-Security-Policy frame-ancestors directive.
const allowEmbedding =
  process.env.NODE_ENV !== "production" || process.env.SBTF_ALLOW_EMBEDDING === "true";

const securityHeaders = [
  { key: "X-Content-Type-Options", value: "nosniff" },
  { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
  { key: "Permissions-Policy", value: "camera=(self), geolocation=(), microphone=()" },
  ...(allowEmbedding ? [] : [{ key: "X-Frame-Options", value: "SAMEORIGIN" }]),
];

const nextConfig: NextConfig = {
  reactStrictMode: true,
  poweredByHeader: false,
  // Development servers are reached through the preview proxy, whose host must
  // be allowed for Next.js dev assets to load.
  allowedDevOrigins: ["**.e2b.app", "**.arena.ai"],
  // The web application talks to Supabase directly (no custom REST API), so no
  // rewrites or proxying are required.
  experimental: {
    // Server Actions are used for every mutation; keep payloads small.
    serverActions: {
      bodySizeLimit: "2mb",
    },
  },
  async headers() {
    return [
      {
        source: "/(.*)",
        headers: securityHeaders,
      },
      {
        // Certificates and documents are always delivered through signed URLs.
        source: "/verify/:path*",
        headers: [{ key: "Cache-Control", value: "no-store" }],
      },
    ];
  },
};

export default nextConfig;
