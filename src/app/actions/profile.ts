"use server";
import { revalidatePath } from "next/cache";
import { z } from "zod";
import { createClient } from "@/lib/supabase/server";
import type { FormState } from "./auth";

const profileSchema = z.object({
  display_name: z.string().trim().min(2).max(60),
  bio: z.string().trim().max(500).optional(),
  country_code: z.string().regex(/^[A-Z]{2}$/).optional().or(z.literal("")),
  city: z.string().trim().max(60).optional(),
  whatsapp_number: z.string().trim().regex(/^\+?[0-9]{6,15}$/, "whatsapp").optional().or(z.literal("")),
});

export async function updateProfile(_prev: FormState, formData: FormData): Promise<FormState> {
  const parsed = profileSchema.safeParse({
    display_name: formData.get("display_name"), bio: formData.get("bio") ?? "", country_code: formData.get("country_code") ?? "",
    city: formData.get("city") ?? "", whatsapp_number: String(formData.get("whatsapp_number") ?? "").replace(/[\s.-]/g, ""),
  });
  if (!parsed.success) return { error: parsed.error.issues[0]?.message === "whatsapp" ? "profile.err_whatsapp" : "auth.err.generic" };
  const d = parsed.data;
  const supabase = await createClient();
  const { data: auth } = await supabase.auth.getUser();
  if (!auth.user) return { error: "auth.err.generic" };
  const show = formData.get("show_whatsapp") === "on" && Boolean(d.whatsapp_number);
  const { error } = await supabase.from("profiles").update({
    display_name: d.display_name, bio: d.bio || null, country_code: d.country_code || null, city: d.city || null, show_whatsapp: show,
  }).eq("id", auth.user.id);
  if (error) return { error: "auth.err.generic" };
  const { error: e2 } = await supabase.from("private_profiles").upsert({ id: auth.user.id, whatsapp_number: d.whatsapp_number || null });
  if (e2) return { error: "auth.err.generic" };
  revalidatePath("/compte", "layout");
  return { message: "profile.saved" };
}

export async function requestAccountDeletion(_prev: FormState, formData: FormData): Promise<FormState> {
  const supabase = await createClient();
  const { data: auth } = await supabase.auth.getUser();
  if (!auth.user) return { error: "auth.err.generic" };
  const { error } = await supabase.from("data_deletion_requests").insert({ user_id: auth.user.id, reason: String(formData.get("reason") ?? "").slice(0, 500) || null });
  return error ? { error: "auth.err.generic" } : { message: "profile.deletion_requested" };
}

export async function uploadedAvatar(path: string): Promise<{ ok: boolean }> {
  const supabase = await createClient();
  const { data: auth } = await supabase.auth.getUser();
  if (!auth.user || !path.startsWith(`${auth.user.id}/`) || path.includes("..")) return { ok: false };
  const { error } = await supabase.from("profiles").update({ avatar_url: path }).eq("id", auth.user.id);
  revalidatePath("/compte", "layout");
  return { ok: !error };
}
