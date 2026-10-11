import type { Metadata } from "next";
import { PageTitle } from "@/components/ui/card";
import { ListingGrid } from "@/components/listing-grid";
import { LISTING_SELECT } from "@/lib/data";
import { getT } from "@/lib/i18n";
import { createClient } from "@/lib/supabase/server";
import type { ListingCard } from "@/lib/types";

export const metadata: Metadata = { title: "Mes favoris", robots: { index: false } };

export default async function FavoritesPage() {
  const { t, lang } = await getT();
  const supabase = await createClient();
  const { data } = await supabase.from("favorites").select(`listing_id, listings(${LISTING_SELECT})`).order("created_at", { ascending: false });
  const items = ((data ?? []) as unknown as { listings: ListingCard | null }[]).map((f) => f.listings).filter(Boolean) as ListingCard[];
  return (
    <>
      <PageTitle>{t("account.favorites")}</PageTitle>
      {items.length ? <ListingGrid items={items} lang={lang} t={t} favorites={new Set(items.map((i) => i.id))} signedIn /> : <p className="text-sm text-muted">{t("account.no_favorites")}</p>}
    </>
  );
}
