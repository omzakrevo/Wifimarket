import { createBrowserClient } from "@supabase/ssr";
import { supabaseKeyOrFallback, supabaseUrlOrFallback } from "@/lib/env";

export function createClient() {
  return createBrowserClient(supabaseUrlOrFallback, supabaseKeyOrFallback);
}
