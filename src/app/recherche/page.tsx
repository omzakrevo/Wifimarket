import type { Metadata } from "next";
import { Container, PageTitle } from "@/components/ui/card";
import { SearchFilters } from "@/components/search-filters";
import { SaveSearchButton } from "@/components/save-search-button";
import { ListingGrid } from "@/components/listing-grid";
import { Pagination } from "@/components/pagination";
import { SetupNotice } from "@/components/setup-notice";
import { getUser } from "@/lib/auth";
import { PAGE_SIZE, getBrands, getCategories, getCities, getCountries, getCurrencies, getFavoriteIds, searchListings, type SearchParams } from "@/lib/data";
import { getT } from "@/lib/i18n";

export const metadata: Metadata = { title: "Rechercher du matériel", robots: { index: false, follow: true }, alternates: { canonical: "/recherche" } };

export default async function SearchPage({ searchParams }: { searchParams: Promise<SearchParams> }) {
  const sp = await searchParams;
  const { t, lang } = await getT();
  const [user, favorites, categories, brands, countries, cities, currencies, { items, total }] = await Promise.all([
    getUser(), getFavoriteIds(), getCategories(), getBrands(), getCountries(), getCities(), getCurrencies(), searchListings(sp),
  ]);
  const page = Math.max(1, Number(sp.page) || 1);
  const { page: _p, ...saveable } = sp;
  void _p;
  const needsCurrency = (sp.sort === "price_asc" || sp.sort === "price_desc" || sp.min || sp.max) && !sp.currency;
  return (
    <Container className="py-6">
      <SetupNotice />
      <PageTitle sub={t("search.count", { n: total })}>{sp.q ? t("search.results_for", { q: sp.q }) : t("search.title")}</PageTitle>
      <div className="grid gap-6 lg:grid-cols-[18rem_1fr]">
        <aside><SearchFilters values={sp} categories={categories} brands={brands} countries={countries} cities={cities} currencies={currencies} /></aside>
        <div>
          <div className="mb-3 flex flex-wrap items-center justify-between gap-2">
            {needsCurrency ? <p className="text-xs text-amber-700 dark:text-amber-300">{t("search.currency_warning")}</p> : <span />}
            <SaveSearchButton params={saveable} signedIn={Boolean(user)} />
          </div>
          {items.length ? (
            <ListingGrid items={items} lang={lang} t={t} favorites={favorites} signedIn={Boolean(user)} />
          ) : (
            <div className="rounded-xl border border-dashed border-border p-10 text-center text-sm text-muted">
              <p>{t("common.no_results")}</p>
              <p className="mt-1">{t("search.no_results_hint")}</p>
            </div>
          )}
          <Pagination page={page} total={total} pageSize={PAGE_SIZE} params={sp} basePath="/recherche" prev={t("common.prev")} next={t("common.next")} />
        </div>
      </div>
    </Container>
  );
}
