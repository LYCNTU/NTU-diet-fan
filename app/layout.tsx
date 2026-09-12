import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "DIET 飯 — 今天吃什麼？順便幫你帶。",
  description: "AI 餐點推薦與順路代買媒合互動示範。",
  manifest: "/manifest.webmanifest",
  other: {
    "codex-preview": "development",
  },
  icons: {
    icon: "/favicon.svg",
    shortcut: "/favicon.svg",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="zh-Hant">
      <body className="antialiased">{children}</body>
    </html>
  );
}
