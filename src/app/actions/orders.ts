"use server";
import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { z } from "zod";
import { createClient } from "@/lib/supabase/server";
import { isUuid } from "@/lib/utils";

const dbErr = (m: string) => (/^[a-z_]+$/.test(m) ? m : "generic");

export async function setCartQuantity(listingId: string, qty: number): Promise<{ ok: boolean; error?: string }> {
  if (!isUuid(listingId)) return { ok: false, error: "generic" };
  const supabase = await createClient();
  const { error } = await supabase.rpc("cart_set", { p_listing: listingId, p_qty: Math.max(0, Math.min(99, Math.floor(qty))) });
  revalidatePath("/panier");
  return error ? { ok: false, error: dbErr(error.message) } : { ok: true };
}

const checkoutSchema = z.object({
  delivery_method: z.enum(["pickup", "local", "intercity", "international"]),
  payment_method: z.enum(["offline"]),
  country: z.string().optional(), city: z.string().trim().max(60).optional(), line1: z.string().trim().max(200).optional(),
  phone: z.string().trim().max(30).optional(), recipient: z.string().trim().max(80).optional(), note: z.string().trim().max(500).optional(),
});

export async function placeOrder(_prev: { error?: string } | undefined, formData: FormData): Promise<{ error?: string }> {
  const parsed = checkoutSchema.safeParse(Object.fromEntries(formData.entries()));
  if (!parsed.success) return { error: "err.generic" };
  const d = parsed.data;
  const address = d.delivery_method === "pickup" ? null : { country: d.country, city: d.city, line1: d.line1, phone: d.phone, recipient: d.recipient };
  const supabase = await createClient();
  const { error } = await supabase.rpc("place_order", { p_delivery_method: d.delivery_method, p_address: address, p_payment_method: d.payment_method, p_note: d.note || null });
  if (error) return { error: `err.${dbErr(error.message)}` };
  revalidatePath("/panier");
  redirect("/compte/commandes?placed=1");
}

export async function advanceOrder(orderId: string, status: string, tracking?: string, carrier?: string): Promise<{ ok: boolean; error?: string }> {
  if (!isUuid(orderId)) return { ok: false, error: "generic" };
  const supabase = await createClient();
  const { error } = await supabase.rpc("advance_order", { p_order: orderId, p_status: status, p_tracking: tracking || null, p_carrier: carrier || null });
  revalidatePath("/compte/commandes");
  return error ? { ok: false, error: dbErr(error.message) } : { ok: true };
}

export async function cancelOrder(orderId: string, reason?: string): Promise<{ ok: boolean; error?: string }> {
  if (!isUuid(orderId)) return { ok: false, error: "generic" };
  const supabase = await createClient();
  const { error } = await supabase.rpc("cancel_order", { p_order: orderId, p_reason: reason?.slice(0, 300) || null });
  revalidatePath("/compte/commandes");
  return error ? { ok: false, error: dbErr(error.message) } : { ok: true };
}

export async function openDispute(orderId: string, reason: string): Promise<{ ok: boolean; error?: string }> {
  if (!isUuid(orderId) || reason.trim().length < 5) return { ok: false, error: "generic" };
  const supabase = await createClient();
  const { error } = await supabase.rpc("open_dispute", { p_order: orderId, p_reason: reason.trim().slice(0, 2000) });
  revalidatePath("/compte/commandes");
  return error ? { ok: false, error: dbErr(error.message) } : { ok: true };
}
