"use server";
import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { isUuid } from "@/lib/utils";

/**
 * Demande de mise en avant. La promotion reste « pending » : elle n'est activée par un administrateur
 * qu'APRÈS un paiement vérifié côté serveur (webhook) ou une validation manuelle. Aucun paiement n'est simulé ici.
 */
export async function requestPromotion(listingId: string): Promise<{ ok: boolean }> {
  if (!isUuid(listingId)) return { ok: false };
  const supabase = await createClient();
  const { data: auth } = await supabase.auth.getUser();
  if (!auth.user) return { ok: false };
  const { error } = await supabase.from("promotions").insert({ listing_id: listingId, requested_by: auth.user.id, plan_code: "sponsored_7d", status: "pending" });
  revalidatePath("/compte/annonces");
  return { ok: !error };
}
