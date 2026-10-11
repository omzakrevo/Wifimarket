"use server";
import { redirect } from "next/navigation";
import { revalidatePath } from "next/cache";
import { z } from "zod";
import { createClient } from "@/lib/supabase/server";
import { isUuid } from "@/lib/utils";

export type ActionResult = { ok: boolean; error?: string; message?: string };

function dbError(message: string): string {
  // Les exceptions métier levées par la base sont des codes courts (ex. "not_negotiable").
  const m = /^[a-z_]+$/.test(message) ? message : "generic";
  return `err.${m}`;
}

export async function startConversation(listingId: string | null, otherUserId: string, requestId?: string | null) {
  if (!isUuid(otherUserId) || (listingId && !isUuid(listingId)) || (requestId && !isUuid(requestId))) redirect("/");
  const supabase = await createClient();
  const { data: auth } = await supabase.auth.getUser();
  if (!auth.user) redirect(`/connexion?next=${encodeURIComponent(listingId ? "/recherche" : "/")}`);
  const { data, error } = await supabase.rpc("start_conversation", { p_other: otherUserId, p_listing: listingId, p_request: requestId ?? null });
  if (error || !data) redirect(`/messages?error=${dbError(error?.message ?? "")}`);
  redirect(`/messages/${data}`);
}

export async function incrementViews(listingId: string) {
  if (!isUuid(listingId)) return;
  const supabase = await createClient();
  await supabase.rpc("increment_listing_views", { p_id: listingId });
}

export async function addToCart(listingId: string, quantity = 1): Promise<ActionResult> {
  if (!isUuid(listingId)) return { ok: false, error: "err.generic" };
  const supabase = await createClient();
  const { data: auth } = await supabase.auth.getUser();
  if (!auth.user) return { ok: false, error: "auth" };
  const { error } = await supabase.rpc("cart_set", { p_listing: listingId, p_qty: Math.max(1, Math.min(99, Math.floor(quantity))) });
  if (error) return { ok: false, error: dbError(error.message) };
  revalidatePath("/panier");
  return { ok: true };
}

const negotiationSchema = z.object({
  listing_id: z.uuid(),
  kind: z.enum(["offer", "exchange"]),
  offered_price: z.coerce.number().min(0).optional(),
  exchange_listing_id: z.uuid().optional(),
  cash_top_up: z.coerce.number().min(0).optional(),
  note: z.string().trim().max(1000).optional(),
});

export async function createNegotiation(_prev: ActionResult | undefined, formData: FormData): Promise<ActionResult> {
  const raw = Object.fromEntries([...formData.entries()].filter(([, v]) => v !== ""));
  const parsed = negotiationSchema.safeParse(raw);
  if (!parsed.success) return { ok: false, error: "err.generic" };
  const d = parsed.data;
  if (d.kind === "offer" && d.offered_price === undefined) return { ok: false, error: "err.price_required" };
  if (d.kind === "exchange" && !d.exchange_listing_id) return { ok: false, error: "err.invalid_exchange_listing" };
  const supabase = await createClient();
  const { data: auth } = await supabase.auth.getUser();
  if (!auth.user) return { ok: false, error: "auth" };
  const { error } = await supabase.from("negotiations").insert({
    listing_id: d.listing_id, buyer_id: auth.user.id, seller_id: auth.user.id, kind: d.kind,
    offered_price: d.kind === "offer" ? d.offered_price : null,
    exchange_listing_id: d.kind === "exchange" ? d.exchange_listing_id : null,
    cash_top_up: d.kind === "exchange" ? (d.cash_top_up ?? null) : null,
    note: d.note || null,
  });
  if (error) return { ok: false, error: dbError(error.message) };
  revalidatePath("/compte/negociations");
  return { ok: true, message: "nego.sent" };
}

const reportSchema = z.object({
  target_type: z.enum(["listing", "user", "conversation", "shop", "wanted_request", "message"]),
  target_id: z.string().min(1).max(64),
  reason: z.enum(["fraud", "stolen", "prohibited", "counterfeit", "spam", "harassment", "wrong_category", "other"]),
  details: z.string().trim().max(2000).optional(),
});

export async function createReport(_prev: ActionResult | undefined, formData: FormData): Promise<ActionResult> {
  const parsed = reportSchema.safeParse(Object.fromEntries(formData.entries()));
  if (!parsed.success) return { ok: false, error: "err.generic" };
  const supabase = await createClient();
  const { data: auth } = await supabase.auth.getUser();
  if (!auth.user) return { ok: false, error: "auth" };
  const { error } = await supabase.from("reports").insert({ ...parsed.data, details: parsed.data.details || null, reporter_id: auth.user.id });
  if (error) return { ok: false, error: dbError(error.message) };
  return { ok: true, message: "report.sent" };
}

export async function getWhatsapp(userId: string): Promise<string | null> {
  if (!isUuid(userId)) return null;
  const supabase = await createClient();
  const { data } = await supabase.rpc("get_whatsapp", { p_user: userId });
  return (data as string | null) ?? null;
}
