import { cache } from "react";
import { cookies } from "next/headers";
import { createClient } from "@/lib/supabase/server";
import { isSupabaseConfigured } from "@/lib/env";
import type { Brand, Category, Country, Currency, ListingCard } from "@/lib/types";

export const LISTING_SELECT =
  "*, listing_media(storage_path,kind,position), categories(slug,name_fr,name_en,icon), brands(name,slug), profiles(id,display_name,verification_status)";

export const getCategories = cache(async (): Promise<Category[]> => {
  if (!isSupabaseConfigured()) return [];
  const supabase = await createClient();
  const { data } = await supabase.from("categories").select("*").eq("enabled", true).order("sort_order").order("name_fr");
  return (data as Category[] | null) ?? [];
});

export const getBrands = cache(async (): Promise<Brand[]> => {
  if (!isSupabaseConfigured()) return [];
  const supabase = await createClient();
  const { data } = await supabase.from("brands").select("*").eq("enabled", true).order("name");
  return (data as Brand[] | null) ?? [];
});

export const getCountries = cache(async (): Promise<Country[]> => {
  if (!isSupabaseConfigured()) return [];
  const supabase = await createClient();
  const { data } = await supabase.from("countries").select("*").eq("enabled", true).order("sort_order");
  return (data as Country[] | null) ?? [];
});

export const getCurrencies = cache(async (): Promise<Currency[]> => {
  if (!isSupabaseConfigured()) return [];
  const supabase = await createClient();
  const { data } = await supabase.from("currencies").select("*").eq("enabled", true).order("code");
  return (data as Currency[] | null) ?? [];
});

export const getCities = cache(async (country?: string): Promise<{ country_code: string; name: string }[]> => {
  if (!isSupabaseConfigured()) return [];
  const supabase = await createClient();
  let q = supabase.from("cities").select("country_code,name").order("name");
  if (country) q = q.eq("country_code", country);
  const { data } = await q;
  return data ?? [];
});

/** Localisation choisie par le visiteur (cookie) : sert aux sections « près de chez vous ». */
export async function getLocation(): Promise<{ country: string | null; city: string | null }> {
  const raw = (await cookies()).get("wm_loc")?.value;
  if (!raw) return { country: null, city: null };
  const [country, city] = decodeURIComponent(raw).split("|");
  return { country: country || null, city: city || null };
}

export type SearchParams = {
  q?: string; category?: string; brand?: string; country?: string; city?: string;
  min?: string; max?: string; currency?: string; condition?: string;
  stock?: string; delivery?: string; exchange?: string; since?: string; sort?: string; page?: string;
  shop?: string; seller?: string;
};

export const PAGE_SIZE = 24;

function num(v?: string) {
  if (v === undefined || v === "") return null;
  const n = Number(v.replace(/\s/g, "").replace(",", "."));
  return Number.isFinite(n) ? n : null;
}

function rpcArgs(sp: SearchParams) {
  const conditions = ["new", "used", "refurbished", "broken", "for_parts"];
  const since = sp.since ? Number(sp.since) : null;
  return {
    p_q: sp.q?.trim() || null,
    p_category: sp.category || null,
    p_brand: sp.brand || null,
    p_country: sp.country || null,
    p_city: sp.city || null,
    p_min: num(sp.min),
    p_max: num(sp.max),
    p_currency: sp.currency || null,
    p_condition: sp.condition && conditions.includes(sp.condition) ? sp.condition : null,
    p_in_stock: sp.stock === "1",
    p_delivery: sp.delivery === "1",
    p_exchange: sp.exchange === "1",
    p_since_days: since && [1, 7, 30].includes(since) ? since : null,
    p_shop: sp.shop || null,
    p_seller: sp.seller || null,
  };
}

export async function searchListings(sp: SearchParams, opts: { limit?: number; offset?: number } = {}) {
  if (!isSupabaseConfigured()) return { items: [] as ListingCard[], total: 0 };
  const supabase = await createClient();
  const limit = opts.limit ?? PAGE_SIZE;
  const page = Math.max(1, Number(sp.page) || 1);
  const offset = opts.offset ?? (page - 1) * limit;
  const sort = ["relevance", "newest", "price_asc", "price_desc"].includes(sp.sort ?? "") ? sp.sort! : sp.q ? "relevance" : "newest";
  const args = rpcArgs(sp);
  const [list, count] = await Promise.all([
    supabase.rpc("search_listings", { ...args, p_sort: sort, p_limit: limit, p_offset: offset }).select(LISTING_SELECT),
    supabase.rpc("count_listings", args),
  ]);
  return { items: ((list.data as unknown as ListingCard[]) ?? []), total: Number(count.data ?? 0) };
}

export async function getListingBySlug(slug: string) {
  const supabase = await createClient();
  const { data } = await supabase.from("listings").select(LISTING_SELECT).eq("slug", slug).maybeSingle();
  return data as unknown as ListingCard | null;
}

export function listingImage(l: Pick<ListingCard, "listing_media">) {
  const imgs = (l.listing_media ?? []).filter((m) => m.kind === "image").sort((a, b) => a.position - b.position);
  return imgs[0]?.storage_path ?? null;
}

export const getFavoriteIds = cache(async (): Promise<Set<string>> => {
  if (!isSupabaseConfigured()) return new Set();
  const supabase = await createClient();
  const { data: auth } = await supabase.auth.getUser();
  if (!auth.user) return new Set();
  const { data } = await supabase.from("favorites").select("listing_id").eq("user_id", auth.user.id);
  return new Set((data ?? []).map((f) => f.listing_id as string));
});

export async function getSponsoredListings(limit = 8) {
  if (!isSupabaseConfigured()) return [] as ListingCard[];
  const supabase = await createClient();
  const { data } = await supabase.from("listings").select(LISTING_SELECT)
    .eq("status", "active").eq("is_sponsored", true).gte("sponsored_until", new Date().toISOString())
    .order("published_at", { ascending: false }).limit(limit);
  return (data as unknown as ListingCard[] | null) ?? [];
}

export async function getFeaturedShops(limit = 6) {
  if (!isSupabaseConfigured()) return [];
  const supabase = await createClient();
  const { data } = await supabase.from("shops").select("id,slug,name,description,logo_url,country_code,city,plan,verification_status")
    .eq("is_active", true).order("plan", { ascending: false }).order("created_at").limit(limit);
  return data ?? [];
}
