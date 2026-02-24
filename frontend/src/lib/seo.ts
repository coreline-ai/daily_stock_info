export function normalizeBaseUrl(raw?: string): string {
  const value = (raw ?? process.env.NEXT_PUBLIC_SITE_URL ?? "http://localhost:3000").trim();
  try {
    const parsed = new URL(value);
    return parsed.origin;
  } catch {
    return "http://localhost:3000";
  }
}

export function assertSeoSlug(slug: string): string {
  const normalized = (slug || "").trim();
  if (!normalized) return "";
  if (!/^[a-z0-9\/-]+$/.test(normalized)) {
    throw new Error(`Invalid SEO slug: ${slug}`);
  }
  return normalized;
}

export function buildWebsiteJsonLd(siteUrl: string): Record<string, unknown> {
  return {
    "@context": "https://schema.org",
    "@type": "WebSite",
    name: "Coreline Stock AI",
    url: siteUrl,
    inLanguage: "ko-KR",
  };
}

export function buildOrganizationJsonLd(siteUrl: string): Record<string, unknown> {
  return {
    "@context": "https://schema.org",
    "@type": "Organization",
    name: "Coreline Stock AI",
    url: siteUrl,
    logo: `${siteUrl}/favicon.ico`,
  };
}
