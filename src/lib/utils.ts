import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export const SITE_URL = (process.env.NEXT_PUBLIC_SITE_URL ?? "https://wifimarket.tech").replace(/\/$/, "");

/** Affiche un prix dans sa devise d'origine (aucune conversion). */
export function formatPrice(amount: number | string, currency: string, lang = "fr") {
  const n = Number(amount);
  const noDecimals = ["XOF", "GNF", "CVE"].includes(currency);
  const symbol: Record<string, string> = { XOF: "FCFA", GNF: "GNF", CVE: "CVE" };
  try {
    const num = new Intl.NumberFormat(lang === "en" ? "en-US" : "fr-FR", {
      maximumFractionDigits: noDecimals ? 0 : 2,
      minimumFractionDigits: 0,
    }).format(n);
    return `${num} ${symbol[currency] ?? currency}`;
  } catch {
    return `${n} ${currency}`;
  }
}

export function timeAgo(date: string | Date, lang = "fr") {
  const d = typeof date === "string" ? new Date(date) : date;
  const diff = (Date.now() - d.getTime()) / 1000;
  const rtf = new Intl.RelativeTimeFormat(lang, { numeric: "auto" });
  if (diff < 60) return rtf.format(0, "second");
  if (diff < 3600) return rtf.format(-Math.floor(diff / 60), "minute");
  if (diff < 86400) return rtf.format(-Math.floor(diff / 3600), "hour");
  if (diff < 86400 * 30) return rtf.format(-Math.floor(diff / 86400), "day");
  return d.toLocaleDateString(lang === "en" ? "en-GB" : "fr-FR", { day: "numeric", month: "short", year: "numeric" });
}

export const CONDITIONS = ["new", "used", "refurbished", "broken", "for_parts"] as const;
export type Condition = (typeof CONDITIONS)[number];

export function publicStorageUrl(bucket: string, path: string) {
  const base = process.env.NEXT_PUBLIC_SUPABASE_URL;
  return base ? `${base}/storage/v1/object/public/${bucket}/${path}` : "";
}

/** Nettoie un terme de recherche pour une requête PostgREST (supprime les caractères de syntaxe). */
export function sanitizeSearch(q: string) {
  return q.replace(/[(),%*\\"']/g, " ").replace(/\s+/g, " ").trim().slice(0, 80);
}

export function isUuid(v: string) {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(v);
}
