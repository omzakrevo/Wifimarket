"use server";
import { createClient } from "@/lib/supabase/server";
import { isUuid } from "@/lib/utils";

export async function toggleFavorite(listingId: string): Promise<{ ok: boolean; favorite?: boolean; error?: string }> {
  if (!isUuid(listingId)) return { ok: false, error: "invalid" };
  const supabase = await createClient();
  const { data: auth } = await supabase.auth.getUser();
  if (!auth.user) return { ok: false, error: "auth" };
  const { data: existing } = await supabase.from("favorites").select("listing_id").eq("listing_id", listingId).eq("user_id", auth.user.id).maybeSingle();
  if (existing) {
    const { error } = await supabase.from("favorites").delete().eq("listing_id", listingId).eq("user_id", auth.user.id);
    return error ? { ok: false, error: error.message } : { ok: true, favorite: false };
  }
  const { error } = await supabase.from("favorites").insert({ listing_id: listingId, user_id: auth.user.id });
  return error ? { ok: false, error: error.message } : { ok: true, favorite: true };
}
