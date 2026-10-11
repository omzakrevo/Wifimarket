import Link from "next/link";
import { Plus, Search, HandHelping, Store, BadgeCheck } from "lucide-react";
import { LinkButton } from "@/components/ui/button";
import { Container } from "@/components/ui/card";
import { Section } from "@/components/section";
import { ListingGrid } from "@/components/listing-grid";
import { CategoryIcon } from "@/components/listing-card";
import { SetupNotice } from "@/components/setup-notice";
import { getUser } from "@/lib/auth";
import { getCategories, getFavoriteIds, getFeaturedShops, getLocation, getSponsoredListings, searchListings } from "@/lib/data";
import { getT } from "@/lib/i18n";
import { publicStorageUrl } from "@/lib/utils";

export default async function Home() {
  const { t, lang } = await getT();
  const [user, favorites, categories, loc] = await Promise.all([getUser(), getFavoriteIds(), getCategories(), getLocation()]);
  const signedIn = Boolean(user);
  const top = categories.filter((c) => !c.parent_id);

  const [recent, used, fresh, sponsored, shops, near] = await Promise.all([
    searchListings({ sort: "newest" }, { limit: 8 }),
    searchListings({ condition: "used", sort: "newest" }, { limit: 4 }),
    searchListings({ condition: "new", sort: "newest" }, { limit: 4 }),
    getSponsoredListings(4),
    getFeaturedShops(6),
    loc.country ? searchListings({ country: loc.country, city: loc.city ?? undefined, sort: "newest" }, { limit: 4 }) : Promise.resolve(null),
  ]);
  const grid = (items: typeof recent.items) => <ListingGrid items={items} lang={lang} t={t} favorites={favorites} signedIn={signedIn} />;

  return (
    <>
      <section className="bg-navy text-white dark:bg-[#0a1630]">
        <Container className="py-10 text-center sm:py-14">
          <h1 className="mx-auto max-w-2xl text-3xl font-extrabold tracking-tight sm:text-4xl">{t("home.hero_title")}</h1>
          <p className="mx-auto mt-3 max-w-xl text-sm text-blue-100 sm:text-base">{t("home.hero_sub")}</p>
          <form action="/recherche" role="search" className="mx-auto mt-6 flex max-w-xl gap-2">
            <label htmlFor="hero-q" className="sr-only">{t("common.search")}</label>
            <div className="relative flex-1">
              <Search size={18} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-500" />
              <input id="hero-q" name="q" type="search" placeholder={t("home.search_placeholder")}
                className="h-12 w-full rounded-lg bg-white pl-10 pr-3 text-base text-slate-900 placeholder:text-slate-500 focus-visible:outline-2 focus-visible:outline-promo" />
            </div>
            <button className="h-12 rounded-lg bg-brand px-5 font-semibold text-white hover:bg-blue-700">{t("common.search")}</button>
          </form>
          <div className="mt-5 flex flex-wrap justify-center gap-3">
            <LinkButton href="/vendre" variant="promo" size="lg"><Plus size={18} />{t("nav.sell")}</LinkButton>
            <LinkButton href="/demandes/nouvelle" size="lg" className="bg-white/10 text-white hover:bg-white/20 dark:text-white"><HandHelping size={18} />{t("home.post_wanted")}</LinkButton>
          </div>
        </Container>
      </section>

      <SetupNotice />

      <Section title={t("home.popular_categories")}>
        <ul className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-5">
          {top.map((c) => (
            <li key={c.id}>
              <Link href={`/categories/${c.slug}`} className="flex h-full flex-col items-center gap-2 rounded-xl border border-border bg-card p-4 text-center text-sm font-semibold shadow-sm transition hover:border-brand hover:shadow-md">
                <span className="flex h-12 w-12 items-center justify-center rounded-full bg-brand-soft text-brand"><CategoryIcon name={c.icon} /></span>
                {lang === "en" ? c.name_en : c.name_fr}
              </Link>
            </li>
          ))}
        </ul>
      </Section>

      {near && near.items.length > 0 && (
        <Section title={t("home.near_you", { place: [loc.city, loc.country].filter(Boolean).join(", ") })} href={`/recherche?country=${loc.country}${loc.city ? `&city=${encodeURIComponent(loc.city)}` : ""}`} more={t("common.see_all")}>
          {grid(near.items)}
        </Section>
      )}

      {sponsored.length > 0 && <Section title={t("home.sponsored")}>{grid(sponsored)}</Section>}

      <Section title={t("home.recent")} href="/recherche?sort=newest" more={t("common.see_all")}>
        {recent.items.length ? grid(recent.items) : <p className="text-sm text-muted">{t("common.no_results")}</p>}
      </Section>

      <Section title={t("home.used")} href="/recherche?condition=used" more={t("common.see_all")}>{grid(used.items)}</Section>
      <Section title={t("home.new")} href="/recherche?condition=new" more={t("common.see_all")}>{grid(fresh.items)}</Section>

      {shops.length > 0 && (
        <Section title={t("home.shops")} href="/boutiques" more={t("common.see_all")}>
          <ul className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
            {shops.map((s) => (
              <li key={s.id}>
                <Link href={`/boutiques/${s.slug}`} className="flex items-center gap-3 rounded-xl border border-border bg-card p-4 shadow-sm hover:border-brand">
                  <span className="flex h-12 w-12 shrink-0 items-center justify-center overflow-hidden rounded-lg bg-brand-soft text-brand">
                    {s.logo_url ? <img src={publicStorageUrl("shop-assets", s.logo_url)} alt="" className="h-full w-full object-cover" /> : <Store />}
                  </span>
                  <span className="min-w-0">
                    <span className="flex items-center gap-1 font-semibold">{s.name}{s.verification_status === "verified" && <BadgeCheck size={16} className="text-brand" />}</span>
                    <span className="block truncate text-xs text-muted">{[s.city, s.country_code].filter(Boolean).join(", ")}</span>
                  </span>
                </Link>
              </li>
            ))}
          </ul>
        </Section>
      )}
    </>
  );
}
