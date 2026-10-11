"use server";
import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { z } from "zod";
import { createClient } from "@/lib/supabase/server";
import { isUuid } from "@/lib/utils";
import type { FormState } from "./auth";

const shopSchema = z.object({
  name: z.string().trim().min(2).max(80),
  description: z.string().trim().max(2000).optional(),
  country_code: z.string().regex(/^[A-Z]{2}$/),
  city: z.string().trim().max(60).optional(),
});

export async function createShop(_prev: FormState, formData: FormData): Promise<FormState> {
  const parsed = shopSchema.safeParse(Object.fromEntries(formData.entries()));
  if (!parsed.success) return { error: "auth.err.generic" };
  const d = parsed.data;
  const supabase = await createClient();
  const { data: auth } = await supabase.auth.getUser();
  if (!auth.user) return { error: "auth.err.generic" };
  const base = d.name.normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "").slice(0, 50) || "boutique";
  for (let i = 0; i < 5; i++) {
    const slug = i === 0 ? base : `${base}-${Math.random().toString(36).slice(2, 6)}`;
    const { error } = await supabase.from("shops").insert({ owner_id: auth.user.id, slug, name: d.name, description: d.description || null, country_code: d.country_code, city: d.city || null });
    if (!error) { revalidatePath("/compte/boutique"); redirect("/compte/boutique"); }
    if (error.code !== "23505") return { error: "auth.err.generic" };
  }
  return { error: "auth.err.generic" };
}

export async function updateShop(_prev: FormState, formData: FormData): Promise<FormState> {
  const id = String(formData.get("id") ?? "");
  const parsed = shopSchema.safeParse(Object.fromEntries(formData.entries()));
  if (!isUuid(id) || !parsed.success) return { error: "auth.err.generic" };
  const d = parsed.data;
  const supabase = await createClient();
  const { error } = await supabase.from("shops").update({ name: d.name, description: d.description || null, country_code: d.country_code, city: d.city || null }).eq("id", id);
  revalidatePath("/compte/boutique");
  return error ? { error: "auth.err.generic" } : { message: "profile.saved" };
}

export async function setShopImage(shopId: string, kind: "logo_url" | "banner_url", path: string): Promise<{ ok: boolean }> {
  if (!isUuid(shopId) || !path.startsWith(`${shopId}/`) || path.includes("..")) return { ok: false };
  const supabase = await createClient();
  const { error } = await supabase.from("shops").update({ [kind]: path }).eq("id", shopId);
  revalidatePath("/compte/boutique");
  return { ok: !error };
}

export async function requestVerification(shopId?: string): Promise<{ ok: boolean }> {
  if (shopId && !isUuid(shopId)) return { ok: false };
  const supabase = await createClient();
  const { error } = await supabase.rpc("request_verification", { p_shop: shopId ?? null });
  revalidatePath("/compte/boutique");
  revalidatePath("/compte/profil");
  return { ok: !error };
}

/** Demande d'abonnement : reste « pending » jusqu'à validation par l'administration après paiement vérifié. */
export async function requestSubscription(shopId: string, planCode: string): Promise<{ ok: boolean }> {
  if (!isUuid(shopId) || !/^[a-z_]+$/.test(planCode)) return { ok: false };
  const supabase = await createClient();
  const { error } = await supabase.from("subscriptions").insert({ shop_id: shopId, plan_code: planCode, status: "pending" });
  revalidatePath("/compte/boutique");
  return { ok: !error };
}
