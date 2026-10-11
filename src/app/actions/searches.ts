"use server";
import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { isUuid } from "@/lib/utils";

function toNum(v?: string) {
  if (!v) return null;
  const n = Number(v.replace(",", "."));
  return Number.isFinite(n) ? n : null;
}

export async function saveSearch(p: Record<string, string | undefined>): Promise<{ ok: boolean }> {
  const supabase = await createClient();
  const { data: auth } = await supabase.auth.getUser();
  if (!auth.user) return { ok: false };
  let categoryId: number | null = null;
  let brandId: number | null = null;
  if (p.category) categoryId = (await supabase.from("categories").select("id").eq("slug", p.category).maybeSingle()).data?.id ?? null;
  if (p.brand) brandId = (await supabase.from("brands").select("id").eq("slug", p.brand).maybeSingle()).data?.id ?? null;
  const label = [p.q, p.category, p.brand, p.city, p.country].filter(Boolean).join(" · ").slice(0, 80) || "Toutes les annonces";
  const { error } = await supabase.from("saved_searches").insert({
    user_id: auth.user.id, label, query: p.q?.slice(0, 80) || null, category_id: categoryId, brand_id: brandId,
    country_code: p.country || null, city: p.city || null,
    condition: ["new", "used", "refurbished", "broken", "for_parts"].includes(p.condition ?? "") ? p.condition : null,
    min_price: toNum(p.min), max_price: toNum(p.max), currency_code: p.currency || null,
  });
  revalidatePath("/compte/recherches");
  return { ok: !error };
}

export async function deleteSavedSearch(id: string) {
  if (!isUuid(id)) return;
  const supabase = await createClient();
  await supabase.from("saved_searches").delete().eq("id", id);
  revalidatePath("/compte/recherches");
}

export async function toggleSavedSearchNotify(id: string, notify: boolean) {
  if (!isUuid(id)) return;
  const supabase = await createClient();
  await supabase.from("saved_searches").update({ notify }).eq("id", id);
  revalidatePath("/compte/recherches");
}
