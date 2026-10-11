import "server-only";
import { createClient } from "@supabase/supabase-js";
import { supabaseUrl } from "@/lib/env";

/**
 * Client à clé de service (contourne la RLS). RÉSERVÉ aux routes serveur de confiance (webhooks de paiement,
 * suppression de compte…). Ne jamais importer depuis un composant client. Les droits de l'appelant
 * doivent être vérifiés AVANT tout usage.
 */
export function createAdminClient() {
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!key) throw new Error("SUPABASE_SERVICE_ROLE_KEY manquante");
  return createClient(supabaseUrl, key, { auth: { persistSession: false, autoRefreshToken: false } });
}
