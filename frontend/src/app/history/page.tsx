import type { Metadata } from "next";

import HistoryClient from "./history-client";

export const metadata: Metadata = {
  title: "백테스트 히스토리 | Coreline Stock AI",
  description: "Top5 추천 전략의 T+1/T+3/T+5 수익률과 순수익 성과를 조회합니다.",
  alternates: {
    canonical: "/history",
  },
  keywords: ["백테스트", "주식 전략", "수익률", "Coreline Stock"],
  openGraph: {
    type: "website",
    locale: "ko_KR",
    url: "/history",
    title: "백테스트 히스토리 | Coreline Stock AI",
    description: "Top5 추천 전략의 기간별 성과 조회",
    siteName: "Coreline Stock AI",
  },
  twitter: {
    card: "summary",
    title: "백테스트 히스토리 | Coreline Stock AI",
    description: "Top5 추천 전략의 기간별 성과 조회",
  },
};

export default function HistoryPage() {
  return <HistoryClient />;
}
