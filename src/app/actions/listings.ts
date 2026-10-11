"use server";
import { revalidatePath } from "next/cache";
import { z } from "zod";
import { createClient } from "@/lib/supabase/server";
import { isUuid } from "@/lib/utils";

const text = (max: number) => z.string().trim().max(max).optional().nullable().transform((v) => (v ? v : null));

const listingSchema = z.object({
  id: z.uuid(),
  status: z.enum(["draft", "active"]),
  category_id: z.number().int().positive(),
  brand_id: z.number().int().positive().nullable(),
  model_id: z.number().int().positive().nullable(),
  model_text: text(120),
  title: z.string().trim().min(5).max(140),
  description: z.string().trim().max(5000),
  condition: z.enum(["new", "used", "refurbished", "broken", "for_parts"]),
  price: z.number().min(0).max(999_999_999_999),
  currency_code: z.string().regex(/^[A-Z]{3}$/),
  quantity: z.number().int().min(0).max(100000),
  country_code: z.string().regex(/^[A-Z]{2}$/),
  city: text(60),
  delivery_available: z.boolean(),
  defects: text(1000),
  warranty: text(300),
  negotiable: z.boolean(),
  exchange_possible: z.boolean(),
  exchange_wanted: text(300),
  shop_id: z.uuid().nullable(),
  media: z.array(z.object({ path: z.string().min(3).max(300), kind: z.enum(["image", "video"]) })).max(12),
  removed_media: z.array(z.string().max(300)).max(24),
});

export type SaveListingInput = z.input<typeof listingSchema>;
export type SaveListingResult = { ok: boolean; error?: string; id?: string; slug?: string; status?: string };

export async function saveListing(input: SaveListingInput): Promise<SaveListingResult> {
  const parsed = listingSchema.safeParse(input);
  if (!parsed.success) return { ok: false, error: `invalid:${parsed.error.issues[0]?.path.join(".")}` };
  const d = parsed.data;
  const supabase = await createClient();
  const { data: auth } = await supabase.auth.getUser();
  if (!auth.user) return { ok: false, error: "auth" };
  const uid = auth.user.id;

  // Les fichiers doivent se trouver dans le dossier de l'utilisateur (la politique Storage l'impose aussi à l'envoi).
  for (const m of d.media) if (!m.path.startsWith(`${uid}/`) || m.path.includes("..")) return { ok: false, error: "invalid:media" };

  const row = {
    category_id: d.category_id, brand_id: d.brand_id, model_id: d.model_id, model_text: d.model_text,
    title: d.title, description: d.description, condition: d.condition, price: d.price, currency_code: d.currency_code,
    quantity: d.quantity, country_code: d.country_code, city: d.city, delivery_available: d.delivery_available,
    defects: d.defects, warranty: d.warranty, negotiable: d.negotiable, exchange_possible: d.exchange_possible,
    exchange_wanted: d.exchange_wanted, shop_id: d.shop_id, status: d.status,
  };

  const { data: existing } = await supabase.from("listings").select("id,seller_id,status").eq("id", d.id).maybeSingle();
  let status: string;
  let slug: string;
  if (existing) {
    if (existing.seller_id !== uid) return { ok: false, error: "not_allowed" };
    // Une annonce déjà en ligne reste en ligne pendant l'édition ; un brouillon ne repasse pas par « draft » si publié.
    const nextStatus = d.status === "draft" && existing.status !== "draft" ? existing.status : d.status;
    const { data, error } = await supabase.from("listings").update({ ...row, status: nextStatus }).eq("id", d.id).select("status,slug").single();
    if (error) return { ok: false, error: /^[a-z_]+$/.test(error.message) ? error.message : "generic" };
    status = data.status; slug = data.slug;
  } else {
    const { data, error } = await supabase.from("listings").insert({ ...row, id: d.id, seller_id: uid }).select("status,slug").single();
    if (error) return { ok: false, error: /^[a-z_]+$/.test(error.message) ? error.message : "generic" };
    status = data.status; slug = data.slug;
  }

  // Médias : suppression puis ajout, avec positions recalculées
  if (d.removed_media.length) {
    await supabase.from("listing_media").delete().eq("listing_id", d.id).in("storage_path", d.removed_media);
    await supabase.storage.from("listing-media").remove(d.removed_media.filter((p) => p.startsWith(`${uid}/`)));
  }
  const { data: current } = await supabase.from("listing_media").select("storage_path").eq("listing_id", d.id);
  const have = new Set((current ?? []).map((m) => m.storage_path as string));
  const toAdd = d.media.filter((m) => !have.has(m.path));
  if (toAdd.length) {
    const { error } = await supabase.from("listing_media").insert(toAdd.map((m) => ({ listing_id: d.id, kind: m.kind, storage_path: m.path, position: 0 })));
    if (error) return { ok: false, error: "media", id: d.id, slug, status };
  }
  // Ordre final = ordre envoyé par le client
  await Promise.all(d.media.map((m, i) => supabase.from("listing_media").update({ position: i }).eq("listing_id", d.id).eq("storage_path", m.path)));

  revalidatePath("/compte/annonces");
  revalidatePath(`/annonces/${slug}`);
  revalidatePath("/");
  return { ok: true, id: d.id, slug, status };
}

export async function setListingStatus(id: string, status: "paused" | "active" | "sold" | "draft"): Promise<{ ok: boolean; error?: string }> {
  if (!isUuid(id)) return { ok: false };
  const supabase = await createClient();
  const { error } = await supabase.from("listings").update({ status }).eq("id", id);
  if (error) return { ok: false, error: error.message };
  revalidatePath("/compte/annonces");
  revalidatePath("/");
  return { ok: true };
}

export async function renewListing(id: string): Promise<{ ok: boolean }> {
  if (!isUuid(id)) return { ok: false };
  const supabase = await createClient();
  const { error } = await supabase.rpc("renew_listing", { p_id: id });
  revalidatePath("/compte/annonces");
  return { ok: !error };
}

export async function deleteListing(id: string): Promise<{ ok: boolean }> {
  if (!isUuid(id)) return { ok: false };
  const supabase = await createClient();
  const { data: media } = await supabase.from("listing_media").select("storage_path").eq("listing_id", id);
  const { error } = await supabase.from("listings").delete().eq("id", id);
  if (!error && media?.length) await supabase.storage.from("listing-media").remove(media.map((m) => m.storage_path as string));
  revalidatePath("/compte/annonces");
  revalidatePath("/");
  return { ok: !error };
}
