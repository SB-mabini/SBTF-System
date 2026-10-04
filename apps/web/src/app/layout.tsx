import type { Metadata, Viewport } from "next";

// Inter is bundled with the application instead of being fetched from a
// third-party font service: the municipal system should not make every visitor
// contact Google just to render a page, and the build stays reproducible
// offline.
import "@fontsource-variable/inter";
import "./globals.css";

export const metadata: Metadata = {
  title: {
    default: "SBTF System — Municipality of Mabini, Batangas",
    template: "%s · SBTF System",
  },
  description:
    "Franchising and Tricycle Driver Registration System with Descriptive and Prescriptive Analytics and Decision Support for the Municipality of Mabini, Batangas.",
  applicationName: "SBTF System",
  robots: { index: false, follow: false },
};

export const viewport: Viewport = {
  themeColor: "#271564",
  width: "device-width",
  initialScale: 1,
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body className="min-h-screen antialiased">{children}</body>
    </html>
  );
}
