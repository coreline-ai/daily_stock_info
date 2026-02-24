type Metric = {
  id: string;
  name: string;
  value: number;
  rating: string;
};

const API_BASE = process.env.NEXT_PUBLIC_API_BASE_URL ?? "http://localhost:8000";
const SAMPLE_RATE = Number(process.env.NEXT_PUBLIC_WEB_VITALS_SAMPLE_RATE ?? "0.1");

export async function sendWebVital(metric: Metric): Promise<void> {
  if (Math.random() > Math.max(0, Math.min(1, SAMPLE_RATE))) {
    return;
  }
  try {
    await fetch(`${API_BASE}/api/v1/telemetry/web-vitals`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        id: metric.id,
        name: metric.name,
        value: metric.value,
        rating: metric.rating,
        path: window.location.pathname,
        ts: Date.now(),
      }),
      keepalive: true,
    });
  } catch {
    // Ignore telemetry transport errors.
  }
}
