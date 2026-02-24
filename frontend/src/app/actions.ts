"use server";

const API_BASE = process.env.NEXT_PUBLIC_API_BASE_URL ?? "http://localhost:8000";
const USER_KEY = "default";

export async function addWatchlistAction(tickers: string[]): Promise<string[]> {
  const res = await fetch(`${API_BASE}/api/v1/watchlist`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ user_key: USER_KEY, tickers }),
    cache: "no-store",
  });
  if (!res.ok) {
    throw new Error(`watchlist add failed (${res.status})`);
  }
  const payload = (await res.json()) as { tickers?: string[] };
  return Array.isArray(payload.tickers) ? payload.tickers : [];
}

export async function removeWatchlistAction(ticker: string): Promise<string[]> {
  const res = await fetch(`${API_BASE}/api/v1/watchlist/${encodeURIComponent(ticker)}?user_key=${USER_KEY}`, {
    method: "DELETE",
    cache: "no-store",
  });
  if (!res.ok) {
    throw new Error(`watchlist remove failed (${res.status})`);
  }
  const payload = (await res.json()) as { tickers?: string[] };
  return Array.isArray(payload.tickers) ? payload.tickers : [];
}
