import type { Metadata } from "next";

import HomeClient from "./page-client";
import { buildOrganizationJsonLd, buildWebsiteJsonLd, normalizeBaseUrl } from "@/lib/seo";

const siteUrl = normalizeBaseUrl();

export const metadata: Metadata = {
  title: "Coreline Stock AI | 장중 단타·전략 검증 대시보드",
  description: "KRX 중심 단기 전략 추천, 장중 단타 신호, 검증 게이트(PBO/DSR)와 리스크 요약을 제공하는 대시보드",
  alternates: {
    canonical: "/",
  },
  keywords: ["KRX", "주식", "장중 단타", "전략 검증", "PBO", "DSR", "Coreline Stock"],
  openGraph: {
    type: "website",
    locale: "ko_KR",
    url: "/",
    title: "Coreline Stock AI",
    description: "장중 단타·종가 전략 추천 및 검증 대시보드",
    siteName: "Coreline Stock AI",
  },
  twitter: {
    card: "summary_large_image",
    title: "Coreline Stock AI",
    description: "장중 단타·종가 전략 추천 및 검증 대시보드",
  },
};

export default function Page() {
  const website = buildWebsiteJsonLd(siteUrl);
  const organization = buildOrganizationJsonLd(siteUrl);

  return (
    <>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(website) }}
      />
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(organization) }}
      />
      <HomeClient />
    </>
  );
}
