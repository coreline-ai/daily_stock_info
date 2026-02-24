"use client";

import { useReportWebVitals } from "next/web-vitals";

import { sendWebVital } from "@/app/reportWebVitals";

export default function WebVitalsReporter() {
  useReportWebVitals((metric) => {
    void sendWebVital(metric);
  });
  return null;
}
