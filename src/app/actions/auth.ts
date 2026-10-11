"use server";
import { redirect } from "next/navigation";
import { headers } from "next/headers";
import { z } from "zod";
import { createClient } from "@/lib/supabase/server";
import { safeNext } from "@/lib/safe-redirect";
import { SITE_URL } from "@/lib/utils";

export type FormState = { error?: string; message?: string } | undefined;

const emailSchema = z.string().trim().toLowerCase().email();

async function origin() {
  const h = await headers();
  const host = h.get("x-forwarded-host") ?? h.get("host");
  const proto = h.get("x-forwarded-proto") ?? "https";
  return host ? `${host.startsWith("localhost") ? "http" : proto}://${host}` : SITE_URL;
}

function mapAuthError(message: string): string {
  const m = message.toLowerCase();
  if (m.includes("invalid login")) return "auth.err.invalid_credentials";
  if (m.includes("email not confirmed")) return "auth.err.email_not_confirmed";
  if (m.includes("already registered") || m.includes("already been registered")) return "auth.err.already_registered";
  if (m.includes("rate limit") || m.includes("too many")) return "auth.err.rate_limit";
  if (m.includes("password")) return "auth.err.weak_password";
  if (m.includes("provider") && m.includes("not enabled")) return "auth.err.provider_disabled";
  if (m.includes("sms") || m.includes("phone")) return "auth.err.phone";
  return "auth.err.generic";
}

export async function signIn(_prev: FormState, formData: FormData): Promise<FormState> {
  const email = emailSchema.safeParse(formData.get("email"));
  const password = String(formData.get("password") ?? "");
  if (!email.success || !password) return { error: "auth.err.invalid_credentials" };
  const supabase = await createClient();
  const { error } = await supabase.auth.signInWithPassword({ email: email.data, password });
  if (error) return { error: mapAuthError(error.message) };
  redirect(safeNext(String(formData.get("next") ?? "")));
}

const signUpSchema = z.object({
  email: emailSchema,
  password: z.string().min(8).max(72),
  display_name: z.string().trim().min(2).max(60),
  country_code: z.string().length(2).optional().or(z.literal("")),
  city: z.string().trim().max(60).optional(),
});

export async function signUp(_prev: FormState, formData: FormData): Promise<FormState> {
  const parsed = signUpSchema.safeParse({
    email: formData.get("email"), password: formData.get("password"), display_name: formData.get("display_name"),
    country_code: formData.get("country_code") ?? "", city: formData.get("city") ?? "",
  });
  if (!parsed.success) {
    const field = parsed.error.issues[0]?.path[0];
    return { error: field === "password" ? "auth.err.weak_password" : field === "email" ? "auth.err.invalid_email" : "auth.err.generic" };
  }
  if (formData.get("terms") !== "on") return { error: "auth.err.terms" };
  const supabase = await createClient();
  const { data, error } = await supabase.auth.signUp({
    email: parsed.data.email,
    password: parsed.data.password,
    options: {
      emailRedirectTo: `${await origin()}/auth/callback?next=/compte`,
      data: { display_name: parsed.data.display_name, country_code: parsed.data.country_code || null, city: parsed.data.city || null },
    },
  });
  if (error) return { error: mapAuthError(error.message) };
  if (data.session) redirect(safeNext(String(formData.get("next") ?? "")));
  return { message: "auth.check_email" };
}

export async function signOut() {
  const supabase = await createClient();
  await supabase.auth.signOut();
  redirect("/");
}

export async function signInWithGoogle(formData: FormData) {
  const supabase = await createClient();
  const next = safeNext(String(formData.get("next") ?? ""));
  const { data, error } = await supabase.auth.signInWithOAuth({
    provider: "google",
    options: { redirectTo: `${await origin()}/auth/callback?next=${encodeURIComponent(next)}` },
  });
  if (error || !data.url) redirect(`/connexion?error=${mapAuthError(error?.message ?? "")}`);
  redirect(data.url);
}

export async function sendPhoneOtp(_prev: FormState, formData: FormData): Promise<FormState> {
  const phone = String(formData.get("phone") ?? "").replace(/[\s.-]/g, "");
  if (!/^\+[1-9][0-9]{7,14}$/.test(phone)) return { error: "auth.err.phone_format" };
  const supabase = await createClient();
  const { error } = await supabase.auth.signInWithOtp({ phone });
  if (error) return { error: mapAuthError(error.message) };
  return { message: `otp:${phone}` };
}

export async function verifyPhoneOtp(_prev: FormState, formData: FormData): Promise<FormState> {
  const phone = String(formData.get("phone") ?? "");
  const token = String(formData.get("token") ?? "").trim();
  if (!/^[0-9]{4,8}$/.test(token)) return { error: "auth.err.otp" };
  const supabase = await createClient();
  const { error } = await supabase.auth.verifyOtp({ phone, token, type: "sms" });
  if (error) return { error: "auth.err.otp" };
  redirect(safeNext(String(formData.get("next") ?? "")));
}

export async function requestPasswordReset(_prev: FormState, formData: FormData): Promise<FormState> {
  const email = emailSchema.safeParse(formData.get("email"));
  if (!email.success) return { error: "auth.err.invalid_email" };
  const supabase = await createClient();
  await supabase.auth.resetPasswordForEmail(email.data, { redirectTo: `${await origin()}/auth/callback?next=/compte/mot-de-passe` });
  // Réponse identique que le compte existe ou non (pas d'énumération d'utilisateurs)
  return { message: "auth.reset_sent" };
}

export async function updatePassword(_prev: FormState, formData: FormData): Promise<FormState> {
  const password = String(formData.get("password") ?? "");
  if (password.length < 8 || password.length > 72) return { error: "auth.err.weak_password" };
  const supabase = await createClient();
  const { error } = await supabase.auth.updateUser({ password });
  if (error) return { error: mapAuthError(error.message) };
  return { message: "auth.password_updated" };
}
