import type { MetadataRoute } from "next";
import { createClient } from "@supabase/supabase-js";
import { SITE_URL } from "@/lib/utils";
import { isSupabaseConfigured, supabaseAnonKey, supabaseUrl } from "@/lib/env";

export const revalidate = 3600;

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const base: MetadataRoute.Sitemap = [
    { url: SITE_URL, changeFrequency: "daily", priority: 1 },
    { url: `${SITE_URL}/demandes`, changeFrequency: "daily", priority: 0.6 },
    { url: `${SITE_URL}/boutiques`, changeFrequency: "weekly", priority: 0.6 },
    ...["conditions", "confidentialite", "annonces-interdites"].map((s) => ({ url: `${SITE_URL}/legal/${s}`, changeFrequency: "yearly" as const, priority: 0.2 })),
  ];
  if (!isSupabaseConfigured()) return base;
  // Client anonyme sans cookies : le plan du site ne dépend d'aucune session (la RLS ne renvoie que le contenu public).
  const supabase = createClient(supabaseUrl, supabaseAnonKey, { auth: { persistSession: false } });
  const [cats, listings, shops, wanted] = await Promise.all([
    supabase.from("categories").select("slug").eq("enabled", true),
    supabase.from("listings").select("slug,updated_at").eq("status", "active").order("published_at", { ascending: false }).limit(5000),
    supabase.from("shops").select("slug,updated_at").eq("is_active", true).limit(1000),
    supabase.from("wanted_requests").select("id,updated_at").eq("status", "open").limit(1000),
  ]);
  return [
    ...base,
    ...(cats.data ?? []).map((c) => ({ url: `${SITE_URL}/categories/${c.slug}`, changeFrequency: "daily" as const, priority: 0.8 })),
    ...(listings.data ?? []).map((l) => ({ url: `${SITE_URL}/annonces/${l.slug}`, lastModified: l.updated_at, changeFrequency: "weekly" as const, priority: 0.7 })),
    ...(shops.data ?? []).map((s) => ({ url: `${SITE_URL}/boutiques/${s.slug}`, lastModified: s.updated_at, changeFrequency: "weekly" as const, priority: 0.5 })),
    ...(wanted.data ?? []).map((w) => ({ url: `${SITE_URL}/demandes/${w.id}`, lastModified: w.updated_at, changeFrequency: "weekly" as const, priority: 0.4 })),
  ];
}
