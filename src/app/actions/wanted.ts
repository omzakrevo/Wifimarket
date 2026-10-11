"use server";
import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { z } from "zod";
import { createClient } from "@/lib/supabase/server";
import { isUuid } from "@/lib/utils";
import type { ActionResult } from "./market";

const dbErr = (m: string) => `err.${/^[a-z_]+$/.test(m) ? m : "generic"}`;
const num = z.preprocess((v) => (v === "" || v == null ? undefined : v), z.coerce.number().min(0).max(999_999_999_999).optional());

const wantedSchema = z.object({
  title: z.string().trim().min(5).max(140),
  category_id: z.preprocess((v) => (v === "" ? undefined : v), z.coerce.number().int().positive().optional()),
  brand_id: z.preprocess((v) => (v === "" ? undefined : v), z.coerce.number().int().positive().optional()),
  model_text: z.string().trim().max(120).optional(),
  condition_wanted: z.enum(["new", "used", "refurbished", "broken", "for_parts", "any"]),
  budget: num,
  currency_code: z.string().regex(/^[A-Z]{3}$/).optional().or(z.literal("")),
  country_code: z.string().regex(/^[A-Z]{2}$/),
  city: z.string().trim().max(60).optional(),
  description: z.string().trim().max(3000).default(""),
});

export async function createWanted(_prev: ActionResult | undefined, formData: FormData): Promise<ActionResult> {
  const parsed = wantedSchema.safeParse(Object.fromEntries(formData.entries()));
  if (!parsed.success) return { ok: false, error: "err.generic" };
  const d = parsed.data;
  const supabase = await createClient();
  const { data: auth } = await supabase.auth.getUser();
  if (!auth.user) return { ok: false, error: "auth" };
  const { data, error } = await supabase.from("wanted_requests").insert({
    requester_id: auth.user.id, title: d.title, category_id: d.category_id ?? null, brand_id: d.brand_id ?? null, model_text: d.model_text || null,
    condition_wanted: d.condition_wanted, budget: d.budget ?? null, currency_code: d.budget != null ? (d.currency_code || null) : null,
    country_code: d.country_code, city: d.city || null, description: d.description,
  }).select("id").single();
  if (error || !data) return { ok: false, error: dbErr(error?.message ?? "") };
  revalidatePath("/demandes");
  redirect(`/demandes/${data.id}`);
}

export async function setWantedStatus(id: string, status: "open" | "fulfilled" | "closed"): Promise<{ ok: boolean }> {
  if (!isUuid(id)) return { ok: false };
  const supabase = await createClient();
  const { error } = await supabase.from("wanted_requests").update({ status }).eq("id", id);
  revalidatePath(`/demandes/${id}`);
  revalidatePath("/demandes");
  return { ok: !error };
}

const offerSchema = z.object({
  request_id: z.uuid(),
  price: z.coerce.number().min(0).max(999_999_999_999),
  currency_code: z.string().regex(/^[A-Z]{3}$/),
  condition: z.enum(["new", "used", "refurbished", "broken", "for_parts"]).optional(),
  listing_id: z.preprocess((v) => (v === "" ? undefined : v), z.uuid().optional()),
  message: z.string().trim().max(1000).optional(),
});

export async function submitOffer(_prev: ActionResult | undefined, formData: FormData): Promise<ActionResult> {
  const parsed = offerSchema.safeParse(Object.fromEntries(formData.entries()));
  if (!parsed.success) return { ok: false, error: "err.generic" };
  const d = parsed.data;
  const supabase = await createClient();
  const { data: auth } = await supabase.auth.getUser();
  if (!auth.user) return { ok: false, error: "auth" };
  const { error } = await supabase.from("wanted_offers").insert({
    request_id: d.request_id, seller_id: auth.user.id, price: d.price, currency_code: d.currency_code, condition: d.condition ?? null,
    listing_id: d.listing_id ?? null, message: d.message || null,
  });
  if (error) return { ok: false, error: error.code === "23505" ? "err.already_offered" : dbErr(error.message) };
  revalidatePath(`/demandes/${d.request_id}`);
  return { ok: true, message: "wanted.offer_sent" };
}

export async function respondOffer(offerId: string, requestId: string, status: "accepted" | "declined" | "withdrawn"): Promise<{ ok: boolean }> {
  if (!isUuid(offerId) || !isUuid(requestId)) return { ok: false };
  const supabase = await createClient();
  const { error } = await supabase.from("wanted_offers").update({ status }).eq("id", offerId);
  revalidatePath(`/demandes/${requestId}`);
  return { ok: !error };
}
