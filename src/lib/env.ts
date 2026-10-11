export const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL ?? "";
export const supabaseAnonKey =
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ?? process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY ?? "";

/** Vrai si les variables Supabase publiques sont renseignées. */
export function isSupabaseConfigured() {
  return Boolean(supabaseUrl && supabaseAnonKey);
}

/** Valeurs de repli : sans configuration, les requêtes échouent proprement (données vides) au lieu de faire planter le rendu. */
export const supabaseUrlOrFallback = supabaseUrl || "http://127.0.0.1:9";
export const supabaseKeyOrFallback = supabaseAnonKey || "unconfigured";
