"use server";
import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { isUuid } from "@/lib/utils";

export async function respondNegotiation(id: string, action: "accept" | "decline" | "counter" | "cancel", price?: number, note?: string): Promise<{ ok: boolean; error?: string }> {
  if (!isUuid(id)) return { ok: false, error: "generic" };
  const supabase = await createClient();
  const { error } = await supabase.rpc("negotiation_respond", { p_id: id, p_action: action, p_price: price ?? null, p_note: note?.slice(0, 1000) ?? null });
  revalidatePath("/compte/negociations");
  return error ? { ok: false, error: /^[a-z_]+$/.test(error.message) ? error.message : "generic" } : { ok: true };
}

export async function confirmNegotiation(id: string): Promise<{ ok: boolean; error?: string }> {
  if (!isUuid(id)) return { ok: false, error: "generic" };
  const supabase = await createClient();
  const { error } = await supabase.rpc("negotiation_confirm", { p_id: id });
  revalidatePath("/compte/negociations");
  return error ? { ok: false, error: /^[a-z_]+$/.test(error.message) ? error.message : "generic" } : { ok: true };
}

export async function submitReview(formData: FormData): Promise<{ ok: boolean; error?: string }> {
  const sellerId = String(formData.get("seller_id") ?? "");
  const orderId = String(formData.get("order_id") ?? "");
  const rating = Number(formData.get("rating"));
  if (!isUuid(sellerId) || !(rating >= 1 && rating <= 5) || (orderId && !isUuid(orderId))) return { ok: false, error: "generic" };
  const supabase = await createClient();
  const { data: auth } = await supabase.auth.getUser();
  if (!auth.user) return { ok: false, error: "auth" };
  const { error } = await supabase.from("reviews").insert({
    reviewer_id: auth.user.id, seller_id: sellerId, order_id: orderId || null, rating,
    comment: String(formData.get("comment") ?? "").trim().slice(0, 1500) || null,
  });
  revalidatePath("/compte/negociations");
  revalidatePath("/compte/commandes");
  return error ? { ok: false, error: /^[a-z_]+$/.test(error.message) ? error.message : (error.code === "23505" ? "already_reviewed" : "generic") } : { ok: true };
}
