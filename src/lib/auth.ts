import { cache } from "react";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { isSupabaseConfigured } from "@/lib/env";
import type { Profile } from "@/lib/types";

/** Utilisateur authentifié (vérifié auprès du serveur d'authentification) ou null. */
export const getUser = cache(async () => {
  if (!isSupabaseConfigured()) return null;
  const supabase = await createClient();
  const { data } = await supabase.auth.getUser();
  return data.user ?? null;
});

export const getProfile = cache(async (): Promise<Profile | null> => {
  const user = await getUser();
  if (!user) return null;
  const supabase = await createClient();
  const { data } = await supabase.from("profiles").select("*").eq("id", user.id).single();
  return (data as Profile | null) ?? null;
});

export type RoleInfo = { role: string; country_code: string | null };

export const getRoles = cache(async (): Promise<RoleInfo[]> => {
  const user = await getUser();
  if (!user) return [];
  const supabase = await createClient();
  const { data } = await supabase.from("user_roles").select("role, country_code").eq("user_id", user.id);
  return (data as RoleInfo[] | null) ?? [];
});

export async function requireUser(next?: string) {
  const user = await getUser();
  if (!user) redirect(`/connexion${next ? `?next=${encodeURIComponent(next)}` : ""}`);
  return user;
}

/** Réservé au personnel (modérateur, admin pays, superadmin). La vraie barrière reste la RLS ; ceci n'est que de l'ergonomie. */
export async function requireStaff() {
  await requireUser("/admin");
  const roles = await getRoles();
  const staff = roles.some((r) => ["moderator", "country_admin", "superadmin"].includes(r.role));
  if (!staff) redirect("/");
  return roles;
}

export function isAdminRole(roles: RoleInfo[]) {
  return roles.some((r) => ["country_admin", "superadmin"].includes(r.role));
}
export function isSuperadminRole(roles: RoleInfo[]) {
  return roles.some((r) => r.role === "superadmin");
}
