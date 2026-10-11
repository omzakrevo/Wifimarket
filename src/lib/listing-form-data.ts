import { getBrands, getCategories, getCities, getCountries, getCurrencies } from "@/lib/data";
import { createClient } from "@/lib/supabase/server";

/** Données de référence communes à la création / édition d'une annonce. */
export async function getListingFormData(uid: string) {
  const supabase = await createClient();
  const [categories, brands, countries, cities, currencies, modelsRes, shopsRes, profileRes] = await Promise.all([
    getCategories(), getBrands(), getCountries(), getCities(), getCurrencies(),
    supabase.from("product_models").select("id,brand_id,name").order("name"),
    supabase.from("shop_members").select("shops(id,name)").eq("user_id", uid),
    supabase.from("profiles").select("country_code,city").eq("id", uid).single(),
  ]);
  const shops = ((shopsRes.data ?? []) as unknown as { shops: { id: string; name: string } | null }[]).map((r) => r.shops).filter(Boolean) as { id: string; name: string }[];
  return {
    categories, brands, countries, cities, currencies, shops,
    models: (modelsRes.data ?? []) as { id: number; brand_id: number; name: string }[],
    defaults: { country: profileRes.data?.country_code ?? "BF", city: profileRes.data?.city ?? "" },
  };
}
