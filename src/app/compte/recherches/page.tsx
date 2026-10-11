import type { Metadata } from "next";
import { PageTitle } from "@/components/ui/card";
import { SavedSearchRow } from "@/components/saved-search-row";
import { getT } from "@/lib/i18n";
import { createClient } from "@/lib/supabase/server";

export const metadata: Metadata = { title: "Mes recherches", robots: { index: false } };

export default async function SavedSearchesPage() {
  const { t } = await getT();
  const supabase = await createClient();
  const { data } = await supabase.from("saved_searches").select("*, categories(slug), brands(slug)").order("created_at", { ascending: false });
  return (
    <>
      <PageTitle sub={t("search.alerts_hint")}>{t("account.searches")}</PageTitle>
      {!data?.length ? <p className="text-sm text-muted">{t("account.no_searches")}</p> : (
        <ul className="space-y-2">
          {data.map((s) => {
            const p = new URLSearchParams();
            if (s.query) p.set("q", s.query);
            if (s.categories?.slug) p.set("category", s.categories.slug);
            if (s.brands?.slug) p.set("brand", s.brands.slug);
            if (s.country_code) p.set("country", s.country_code);
            if (s.city) p.set("city", s.city);
            if (s.condition) p.set("condition", s.condition);
            if (s.min_price != null) p.set("min", String(s.min_price));
            if (s.max_price != null) p.set("max", String(s.max_price));
            if (s.currency_code) p.set("currency", s.currency_code);
            return <SavedSearchRow key={s.id} s={{ id: s.id, label: s.label, notify: s.notify, href: `/recherche?${p.toString()}` }} />;
          })}
        </ul>
      )}
    </>
  );
}
