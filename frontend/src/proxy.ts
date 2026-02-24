import type { NextRequest } from "next/server";
import { NextResponse } from "next/server";

function pickBucket(seed: string): "A" | "B" {
  let hash = 0;
  for (let idx = 0; idx < seed.length; idx += 1) {
    hash = (hash * 31 + seed.charCodeAt(idx)) >>> 0;
  }
  return hash % 2 === 0 ? "A" : "B";
}

export function proxy(request: NextRequest) {
  const response = NextResponse.next();
  const country = request.headers.get("x-vercel-ip-country") ?? request.headers.get("cf-ipcountry") ?? "KR";
  response.headers.set("x-region-hint", country);

  const existing = request.cookies.get("ab_bucket")?.value;
  if (!existing) {
    const forwarded = request.headers.get("x-forwarded-for") ?? "";
    const clientIp = forwarded.split(",")[0]?.trim() || "0.0.0.0";
    const key = `${clientIp}:${request.nextUrl.pathname}`;
    response.cookies.set("ab_bucket", pickBucket(key), {
      httpOnly: false,
      sameSite: "lax",
      secure: request.nextUrl.protocol === "https:",
      path: "/",
      maxAge: 60 * 60 * 24 * 14,
    });
  }

  if (request.method === "GET") {
    response.headers.set("x-edge-cache-hint", "eligible");
  }
  return response;
}

export const config = {
  matcher: ["/", "/history", "/api/:path*"],
};
