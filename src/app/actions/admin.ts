"use server";
import { revalidatePath } from "next/cache";
import { z } from "zod";
import { createClient } from "@/lib/supabase/server";
import { createAdminClient } from "@/lib/supabase/admin";
import { isUuid } from "@/lib/utils";

export type R = { ok: boolean; error?: string };
const fail = (m?: string): R => ({ ok: false, error: m ? (/^[a-z_]+$/.test(m) ? m : "generic") : "generic" });
const done = (...paths: string[]): R => { paths.forEach((p) => revalidatePath(p)); return { ok: true }; };

// NB : toutes ces actions s'appuient sur la RLS / les fonctions SQL (droits vérifiés côté base).
// Un utilisateur sans le rôle requis voit ses requêtes refusées (0 ligne modifiée → erreur « not_allowed »).

async function updateOne(table: string, id: string | number, patch: Record<string, unknown>, idCol = "id"): Promise<R> {
  const supabase = await createClient();
  const { data, error } = await supabase.from(table).update(patch).eq(idCol, id).select(idCol);
  if (error) return fail(error.message);
  if (!data?.length) return fail("not_allowed");
  return { ok: true };
}

export async function approveListing(id: string): Promise<R> {
  if (!isUuid(id)) return fail();
  const r = await updateOne("listings", id, { status: "active", rejection_reason: null });
  return r.ok ? done("/admin/annonces", "/admin") : r;
}
export async function rejectListing(id: string, reason = ""): Promise<R> {
  if (!isUuid(id)) return fail();
  const r = await updateOne("listings", id, { status: "rejected", rejection_reason: reason.slice(0, 300) || "Non conforme" });
  return r.ok ? done("/admin/annonces", "/admin") : r;
}
export async function removeListing(id: string, reason = ""): Promise<R> {
  if (!isUuid(id)) return fail();
  const r = await updateOne("listings", id, { status: "removed", rejection_reason: reason.slice(0, 300) || "Retirée par la modération" });
  return r.ok ? done("/admin/annonces", "/admin/signalements") : r;
}

export async function setSuspended(userId: string, suspended: boolean): Promise<R> {
  if (!isUuid(userId)) return fail();
  const r = await updateOne("profiles", userId, { is_suspended: suspended });
  return r.ok ? done("/admin/utilisateurs") : r;
}
export async function setVerification(kind: "profile" | "shop", id: string, status: "verified" | "rejected" | "unverified"): Promise<R> {
  if (!isUuid(id)) return fail();
  const r = await updateOne(kind === "profile" ? "profiles" : "shops", id, { verification_status: status });
  return r.ok ? done("/admin/utilisateurs", "/admin/boutiques") : r;
}
export async function setShopActive(id: string, active: boolean): Promise<R> {
  if (!isUuid(id)) return fail();
  const r = await updateOne("shops", id, { is_active: active });
  return r.ok ? done("/admin/boutiques") : r;
}

export async function resolveReport(id: string, status: "actioned" | "dismissed" | "reviewing", note?: string): Promise<R> {
  if (!isUuid(id)) return fail();
  const supabase = await createClient();
  const { data: auth } = await supabase.auth.getUser();
  const r = await updateOne("reports", id, {
    status, resolution_note: note?.slice(0, 500) || null, handled_by: auth.user?.id ?? null, resolved_at: status === "reviewing" ? null : new Date().toISOString(),
  });
  return r.ok ? done("/admin/signalements", "/admin") : r;
}

export async function resolveDispute(id: string, status: "investigating" | "resolved_buyer" | "resolved_seller" | "closed", resolution?: string): Promise<R> {
  if (!isUuid(id)) return fail();
  const supabase = await createClient();
  const { data: auth } = await supabase.auth.getUser();
  const r = await updateOne("disputes", id, {
    status, resolution: resolution?.slice(0, 1000) || null, handled_by: auth.user?.id ?? null, resolved_at: status === "investigating" ? null : new Date().toISOString(),
  });
  return r.ok ? done("/admin/commandes") : r;
}

export async function setOrderStatus(id: string, status: string): Promise<R> {
  if (!isUuid(id)) return fail();
  const allowed = ["pending", "awaiting_payment", "paid", "processing", "shipped", "delivered", "completed", "cancelled", "refunded", "disputed"];
  if (!allowed.includes(status)) return fail();
  const r = await updateOne("orders", id, { status });
  return r.ok ? done("/admin/commandes") : r;
}

export async function activatePromotion(id: string): Promise<R> {
  if (!isUuid(id)) return fail();
  const r = await updateOne("promotions", id, { status: "active" });
  return r.ok ? done("/admin/promotions") : r;
}
export async function rejectPromotion(id: string): Promise<R> {
  if (!isUuid(id)) return fail();
  const r = await updateOne("promotions", id, { status: "rejected" });
  return r.ok ? done("/admin/promotions") : r;
}
export async function activateSubscription(id: string): Promise<R> {
  if (!isUuid(id)) return fail();
  const r = await updateOne("subscriptions", id, { status: "active" });
  return r.ok ? done("/admin/promotions") : r;
}
export async function cancelSubscription(id: string): Promise<R> {
  if (!isUuid(id)) return fail();
  const r = await updateOne("subscriptions", id, { status: "cancelled" });
  return r.ok ? done("/admin/promotions") : r;
}

// ---------------------------------------------------------------- Catalogue
const catSchema = z.object({
  slug: z.string().trim().regex(/^[a-z0-9-]{2,60}$/), name_fr: z.string().trim().min(2).max(80), name_en: z.string().trim().min(2).max(80),
  parent_id: z.preprocess((v) => (v === "" || v == null ? null : v), z.coerce.number().int().positive().nullable()),
});
export async function addCategory(formData: FormData): Promise<void> {
  const p = catSchema.safeParse(Object.fromEntries(formData.entries()));
  if (!p.success) return;
  const supabase = await createClient();
  await supabase.from("categories").insert(p.data);
  revalidatePath("/admin/catalogue");
}
export async function toggleCategory(id: number, enabled: boolean): Promise<R> {
  const r = await updateOne("categories", id, { enabled });
  return r.ok ? done("/admin/catalogue", "/") : r;
}
export async function deleteCategory(id: number): Promise<R> {
  const supabase = await createClient();
  const { error } = await supabase.from("categories").delete().eq("id", id);
  return error ? fail(error.code === "23503" ? "in_use" : error.message) : done("/admin/catalogue");
}
export async function addBrand(formData: FormData): Promise<void> {
  const name = String(formData.get("name") ?? "").trim().slice(0, 60);
  if (name.length < 2) return;
  const slug = name.normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");
  const supabase = await createClient();
  await supabase.from("brands").insert({ name, slug });
  revalidatePath("/admin/catalogue");
}
export async function toggleBrand(id: number, enabled: boolean): Promise<R> {
  const r = await updateOne("brands", id, { enabled });
  return r.ok ? done("/admin/catalogue") : r;
}
export async function deleteBrand(id: number): Promise<R> {
  const supabase = await createClient();
  const { error } = await supabase.from("brands").delete().eq("id", id);
  return error ? fail(error.code === "23503" ? "in_use" : error.message) : done("/admin/catalogue");
}
export async function addModel(formData: FormData): Promise<void> {
  const brand_id = Number(formData.get("brand_id"));
  const category_id = formData.get("category_id") ? Number(formData.get("category_id")) : null;
  const name = String(formData.get("name") ?? "").trim().slice(0, 80);
  if (!brand_id || name.length < 2) return;
  const supabase = await createClient();
  await supabase.from("product_models").insert({ brand_id, category_id, name });
  revalidatePath("/admin/catalogue");
}

// ---------------------------------------------------------------- Pays, devises, villes
export async function toggleCountry(code: string, enabled: boolean): Promise<R> {
  const r = await updateOne("countries", code, { enabled }, "code");
  return r.ok ? done("/admin/pays") : r;
}
export async function toggleCurrency(code: string, enabled: boolean): Promise<R> {
  const r = await updateOne("currencies", code, { enabled }, "code");
  return r.ok ? done("/admin/pays") : r;
}
export async function addCity(formData: FormData): Promise<void> {
  const country_code = String(formData.get("country_code") ?? "");
  const name = String(formData.get("name") ?? "").trim().slice(0, 60);
  if (!/^[A-Z]{2}$/.test(country_code) || name.length < 2) return;
  const supabase = await createClient();
  await supabase.from("cities").insert({ country_code, name });
  revalidatePath("/admin/pays");
}
export async function addCountry(formData: FormData): Promise<void> {
  const p = z.object({
    code: z.string().regex(/^[A-Z]{2}$/), name_fr: z.string().min(2).max(60), name_en: z.string().min(2).max(60),
    currency_code: z.string().regex(/^[A-Z]{3}$/), phone_prefix: z.string().max(6).optional(),
  }).safeParse(Object.fromEntries(formData.entries()));
  if (!p.success) return;
  const supabase = await createClient();
  await supabase.from("countries").insert(p.data);
  revalidatePath("/admin/pays");
}
export async function addCurrency(formData: FormData): Promise<void> {
  const p = z.object({ code: z.string().regex(/^[A-Z]{3}$/), name: z.string().min(2).max(60), symbol: z.string().min(1).max(6), decimals: z.coerce.number().int().min(0).max(3) })
    .safeParse(Object.fromEntries(formData.entries()));
  if (!p.success) return;
  const supabase = await createClient();
  await supabase.from("currencies").insert(p.data);
  revalidatePath("/admin/pays");
}

// ---------------------------------------------------------------- Paramètres, tarifs, livraison, prestataires
export async function updateSetting(formData: FormData): Promise<void> {
  const key = String(formData.get("key") ?? "");
  const raw = String(formData.get("value") ?? "").trim();
  if (!/^[a-z_]+$/.test(key)) return;
  let value: unknown;
  try { value = JSON.parse(raw); } catch { return; }
  const supabase = await createClient();
  const { data: auth } = await supabase.auth.getUser();
  await supabase.from("platform_settings").update({ value, updated_at: new Date().toISOString(), updated_by: auth.user?.id }).eq("key", key);
  revalidatePath("/admin/parametres");
}
export async function updatePlan(formData: FormData): Promise<void> {
  const code = String(formData.get("code") ?? "");
  const price = Number(formData.get("price"));
  const duration = Number(formData.get("duration_days"));
  if (!/^[a-z0-9_]+$/.test(code) || !(price >= 0) || !(duration > 0)) return;
  const supabase = await createClient();
  await supabase.from("plans").update({ price, duration_days: duration, enabled: formData.get("enabled") === "on", is_demo_price: false }).eq("code", code);
  revalidatePath("/admin/parametres");
}
export async function addShippingRule(formData: FormData): Promise<void> {
  const p = z.object({
    method: z.enum(["local", "intercity", "international"]), from_country: z.string().regex(/^[A-Z]{2}$/), to_country: z.string().regex(/^[A-Z]{2}$/),
    same_city: z.enum(["", "true", "false"]), fee: z.coerce.number().min(0), currency_code: z.string().regex(/^[A-Z]{3}$/),
    eta_days_min: z.preprocess((v) => (v === "" ? undefined : v), z.coerce.number().int().min(0).optional()),
    eta_days_max: z.preprocess((v) => (v === "" ? undefined : v), z.coerce.number().int().min(0).optional()),
    carrier: z.string().max(60).optional(),
  }).safeParse(Object.fromEntries(formData.entries()));
  if (!p.success) return;
  const { same_city, ...rest } = p.data;
  const supabase = await createClient();
  await supabase.from("shipping_rules").insert({ ...rest, same_city: same_city === "" ? null : same_city === "true", carrier: rest.carrier || null });
  revalidatePath("/admin/parametres");
}
export async function deleteShippingRule(id: number): Promise<R> {
  const supabase = await createClient();
  const { error } = await supabase.from("shipping_rules").delete().eq("id", id);
  return error ? fail(error.message) : done("/admin/parametres");
}
export async function updateProvider(formData: FormData): Promise<void> {
  const code = String(formData.get("code") ?? "");
  if (!/^[a-z_]+$/.test(code)) return;
  const list = (k: string) => String(formData.get(k) ?? "").split(",").map((s) => s.trim()).filter(Boolean);
  const supabase = await createClient();
  await supabase.from("payment_providers").update({
    countries: list("countries").map((s) => s.toUpperCase()), currencies: list("currencies").map((s) => s.toUpperCase()), methods: list("methods"),
    enabled: formData.get("enabled") === "on", sandbox: formData.get("sandbox") === "on", eligibility_verified: formData.get("eligibility_verified") === "on",
    notes: String(formData.get("notes") ?? "").slice(0, 500) || null,
  }).eq("code", code);
  revalidatePath("/admin/parametres");
}
export async function addKeyword(formData: FormData): Promise<void> {
  const keyword = String(formData.get("keyword") ?? "").trim().toLowerCase().slice(0, 60);
  if (keyword.length < 2) return;
  const supabase = await createClient();
  await supabase.from("banned_keywords").insert({ keyword, reason: String(formData.get("reason") ?? "").slice(0, 200) || null });
  revalidatePath("/admin/parametres");
}
export async function deleteKeyword(id: number): Promise<R> {
  const supabase = await createClient();
  const { error } = await supabase.from("banned_keywords").delete().eq("id", id);
  return error ? fail(error.message) : done("/admin/parametres");
}

// ---------------------------------------------------------------- Rôles (superadministrateur)
export async function grantRole(formData: FormData): Promise<void> {
  const p = z.object({
    user_id: z.uuid(), role: z.enum(["shop_manager", "moderator", "country_admin", "superadmin"]),
    country_code: z.string().regex(/^[A-Z]{2}$/).optional().or(z.literal("")),
  }).safeParse(Object.fromEntries(formData.entries()));
  if (!p.success) return;
  const supabase = await createClient();
  const { data: auth } = await supabase.auth.getUser();
  await supabase.from("user_roles").insert({ user_id: p.data.user_id, role: p.data.role, country_code: p.data.country_code || null, created_by: auth.user?.id });
  revalidatePath("/admin/utilisateurs");
}
export async function revokeRole(id: number): Promise<R> {
  const supabase = await createClient();
  const { error } = await supabase.from("user_roles").delete().eq("id", id);
  return error ? fail(error.message) : done("/admin/utilisateurs");
}

// ---------------------------------------------------------------- Demandes de suppression de données
export async function processDeletion(requestId: string, decision: "execute" | "reject"): Promise<R> {
  if (!isUuid(requestId)) return fail();
  const supabase = await createClient();
  const { data: isSuper } = await supabase.rpc("is_superadmin");
  if (!isSuper) return fail("not_allowed");
  const { data: req } = await supabase.from("data_deletion_requests").select("id,user_id,status").eq("id", requestId).maybeSingle();
  if (!req || req.status !== "pending") return fail("invalid_state");
  const { data: auth } = await supabase.auth.getUser();
  if (decision === "reject") {
    await supabase.from("data_deletion_requests").update({ status: "rejected", processed_at: new Date().toISOString(), processed_by: auth.user?.id }).eq("id", requestId);
    return done("/admin/suppressions");
  }
  const { error: e1 } = await supabase.rpc("anonymize_user", { p_user: req.user_id });
  if (e1) return fail(e1.message);
  const { data: hasOrders } = await supabase.rpc("user_has_orders", { p_user: req.user_id });
  const admin = createAdminClient();
  if (hasOrders) {
    // Commandes conservées : compte désactivé et adresse e-mail rendue inutilisable
    await admin.auth.admin.updateUserById(req.user_id, { ban_duration: "876000h", email: `deleted-${req.user_id}@deleted.invalid` });
  } else {
    const { error } = await admin.auth.admin.deleteUser(req.user_id);
    if (error) return fail("generic");
  }
  // Après suppression complète, la demande disparaît en cascade ; sinon on la marque terminée.
  await supabase.from("data_deletion_requests").update({ status: "done", processed_at: new Date().toISOString(), processed_by: auth.user?.id }).eq("id", requestId);
  return done("/admin/suppressions");
}
