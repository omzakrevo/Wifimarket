import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { Container, PageTitle } from "@/components/ui/card";
import { ListingGrid } from "@/components/listing-grid";
import { Pagination } from "@/components/pagination";
import { getUser } from "@/lib/auth";
import { PAGE_SIZE, getCategories, getFavoriteIds, searchListings } from "@/lib/data";
import { getT } from "@/lib/i18n";
import { SITE_URL } from "@/lib/utils";

type Props = { params: Promise<{ slug: string }>; searchParams: Promise<{ page?: string; sort?: string; condition?: string }> };

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { slug } = await params;
  const cat = (await getCategories()).find((c) => c.slug === slug);
  if (!cat) return {};
  const title = `${cat.name_fr} — achat et vente en Afrique de l'Ouest`;
  return {
    title,
    description: `Annonces ${cat.name_fr} neuves et d'occasion : comparez les offres de vendeurs au Burkina Faso, Mali, Côte d'Ivoire, Sénégal, Ghana, Nigeria et plus.`,
    alternates: { canonical: `/categories/${slug}` },
    openGraph: { title, url: `${SITE_URL}/categories/${slug}` },
  };
}

export default async function CategoryPage({ params, searchParams }: Props) {
  const [{ slug }, sp] = await Promise.all([params, searchParams]);
  const [{ t, lang }, cats, user, favorites] = await Promise.all([getT(), getCategories(), getUser(), getFavoriteIds()]);
  const cat = cats.find((c) => c.slug === slug);
  if (!cat) notFound();
  const parent = cat.parent_id ? cats.find((c) => c.id === cat.parent_id) : null;
  const children = cats.filter((c) => c.parent_id === cat.id);
  const name = (c: typeof cat) => (lang === "en" ? c.name_en : c.name_fr);
  const { items, total } = await searchListings({ category: slug, sort: sp.sort ?? "newest", condition: sp.condition, page: sp.page });
  const page = Math.max(1, Number(sp.page) || 1);
  return (
    <Container className="py-6">
      <nav aria-label="Fil d'Ariane" className="mb-3 text-sm text-muted">
        <Link href="/" className="hover:underline">{t("nav.home")}</Link> /{" "}
        {parent && <><Link href={`/categories/${parent.slug}`} className="hover:underline">{name(parent)}</Link> / </>}
        <span className="text-foreground">{name(cat)}</span>
      </nav>
      <PageTitle sub={t("search.count", { n: total })}>{name(cat)}</PageTitle>
      {children.length > 0 && (
        <ul className="mb-5 flex flex-wrap gap-2">
          {children.map((c) => <li key={c.id}><Link href={`/categories/${c.slug}`} className="inline-block rounded-full border border-border bg-card px-3 py-1.5 text-sm hover:border-brand">{name(c)}</Link></li>)}
        </ul>
      )}
      {items.length ? <ListingGrid items={items} lang={lang} t={t} favorites={favorites} signedIn={Boolean(user)} /> : <p className="text-sm text-muted">{t("common.no_results")}</p>}
      <Pagination page={page} total={total} pageSize={PAGE_SIZE} params={sp} basePath={`/categories/${slug}`} prev={t("common.prev")} next={t("common.next")} />
    </Container>
  );
}
