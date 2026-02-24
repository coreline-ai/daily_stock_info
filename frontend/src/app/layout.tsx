import type { Metadata, Viewport } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";
import ServiceWorkerRegister from "@/components/ServiceWorkerRegister";
import WebVitalsReporter from "@/components/WebVitalsReporter";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  metadataBase: new URL(process.env.NEXT_PUBLIC_SITE_URL ?? "http://localhost:3000"),
  title: {
    default: "Coreline Stock AI",
    template: "%s | Coreline Stock AI",
  },
  description: "KRX 중심 단기 전략 추천, 장중 단타 신호, 검증 게이트(PBO/DSR)와 리스크 요약 대시보드",
  keywords: ["KRX", "장중 단타", "주식 전략", "전략 검증", "Coreline Stock"],
  alternates: {
    canonical: "/",
  },
  openGraph: {
    type: "website",
    locale: "ko_KR",
    url: "/",
    siteName: "Coreline Stock AI",
    title: "Coreline Stock AI",
    description: "장중 단타·종가 전략 추천 및 검증 대시보드",
  },
  twitter: {
    card: "summary_large_image",
    title: "Coreline Stock AI",
    description: "장중 단타·종가 전략 추천 및 검증 대시보드",
  },
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="ko" suppressHydrationWarning>
      <body
        className={`${geistSans.variable} ${geistMono.variable} antialiased`}
      >
        <WebVitalsReporter />
        <ServiceWorkerRegister />
        {children}
      </body>
    </html>
  );
}
