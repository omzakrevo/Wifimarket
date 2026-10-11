import { getT } from "@/lib/i18n";
import { isSupabaseConfigured } from "@/lib/env";

/** Affiche un bandeau explicite quand Supabase n'est pas encore configuré (au lieu d'une page cassée). */
export async function SetupNotice() {
  if (isSupabaseConfigured()) return null;
  const { t } = await getT();
  return (
    <div className="mx-auto my-6 max-w-3xl rounded-xl border border-amber-300 bg-amber-50 p-4 text-sm text-amber-900 dark:bg-amber-950/40 dark:text-amber-100" role="alert">
      <p className="font-semibold">{t("setup.title")}</p>
      <p className="mt-1">{t("setup.body")}</p>
      <code className="mt-2 block rounded bg-black/10 p-2 text-xs">NEXT_PUBLIC_SUPABASE_URL · NEXT_PUBLIC_SUPABASE_ANON_KEY</code>
    </div>
  );
}
