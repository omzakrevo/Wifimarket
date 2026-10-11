import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { BadgeCheck, MapPin, Star, Store } from "lucide-react";
import { Badge, Container } from "@/components/ui/card";
import { ListingGrid } from "@/components/listing-grid";
import { Pagination } from "@/components/pagination";
import { getUser } from "@/lib/auth";
import { PAGE_SIZE, getFavoriteIds, searchListings } from "@/lib/data";
import { getT } from "@/lib/i18n";
import { createClient } from "@/lib/supabase/server";
import { SITE_URL, publicStorageUrl, timeAgo } from "@/lib/utils";
import type { MessageKey } from "@/lib/i18n/messages";

type Props = { params: Promise<{ slug: string }>; searchParams: Promise<{ page?: string }> };

async function loadShop(slug: string) {
  const supabase = await createClient();
  const { data } = await supabase.from("shops").select("*").eq("slug", slug).eq("is_active", true).maybeSingle();
  return data;
}

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { slug } = await params;
  const s = await loadShop(slug);
  if (!s) return {};
  return {
    title: `${s.name} — boutique de matériel réseau`, description: s.description?.slice(0, 155) || `Catalogue de ${s.name} sur WiFiMarket`,
    alternates: { canonical: `/boutiques/${slug}` },
    openGraph: { title: s.name, url: `${SITE_URL}/boutiques/${slug}`, images: s.logo_url ? [publicStorageUrl("shop-assets", s.logo_url)] : undefined },
  };
}

export default async function ShopPage({ params, searchParams }: Props) {
  const [{ slug }, sp] = await Promise.all([params, searchParams]);
  const shop = await loadShop(slug);
  if (!shop) notFound();
  const { t, lang } = await getT();
  const [user, favorites, { items, total }] = await Promise.all([getUser(), getFavoriteIds(), searchListings({ shop: shop.id, sort: "newest", page: sp.page })]);
  const supabase = await createClient();
  const [{ data: rating }, { data: reviews }] = await Promise.all([
    supabase.from("shop_ratings").select("rating_avg,rating_count").eq("shop_id", shop.id).maybeSingle(),
    supabase.from("reviews").select("id,rating,comment,created_at,profiles:reviewer_id(display_name)").eq("shop_id", shop.id).order("created_at", { ascending: false }).limit(5),
  ]);
  const page = Math.max(1, Number(sp.page) || 1);
  const jsonLd = {
    "@context": "https://schema.org", "@type": "LocalBusiness", name: shop.name, description: shop.description ?? undefined, url: `${SITE_URL}/boutiques/${slug}`,
    image: shop.logo_url ? publicStorageUrl("shop-assets", shop.logo_url) : undefined,
    address: { "@type": "PostalAddress", addressLocality: shop.city ?? undefined, addressCountry: shop.country_code ?? undefined },
    aggregateRating: rating && rating.rating_count > 0 ? { "@type": "AggregateRating", ratingValue: rating.rating_avg, reviewCount: rating.rating_count } : undefined,
  };
  return (
    <>
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd).replace(/</g, "\\u003c") }} />
      <div className="h-32 bg-brand-soft sm:h-44">
        {shop.banner_url && <img src={publicStorageUrl("shop-assets", shop.banner_url)} alt="" className="h-full w-full object-cover" />}
      </div>
      <Container className="py-6">
        <div className="-mt-12 mb-6 flex flex-wrap items-end gap-4">
          <span className="flex h-24 w-24 items-center justify-center overflow-hidden rounded-2xl border-4 border-background bg-card shadow">
            {shop.logo_url ? <img src={publicStorageUrl("shop-assets", shop.logo_url)} alt="" className="h-full w-full object-cover" /> : <Store className="text-brand" size={36} />}
          </span>
          <div className="min-w-0">
            <h1 className="flex items-center gap-2 text-2xl font-bold">{shop.name}{shop.verification_status === "verified" && <BadgeCheck className="text-brand" size={22} aria-label={t("profile.verified")} />}</h1>
            <p className="flex items-center gap-1 text-sm text-muted"><MapPin size={14} />{[shop.city, shop.country_code].filter(Boolean).join(", ")}
              {rating && rating.rating_count > 0 && <span className="ml-3 flex items-center gap-1"><Star size={14} className="fill-promo text-promo" />{rating.rating_avg} ({rating.rating_count})</span>}</p>
            <Badge tone="navy" className="mt-1">{t(`plan.${shop.plan}` as MessageKey)}</Badge>
          </div>
        </div>
        {shop.description && <p className="mb-6 max-w-3xl whitespace-pre-line text-sm leading-6">{shop.description}</p>}
        <h2 className="mb-3 text-lg font-bold">{t("shop.catalog")} ({total})</h2>
        {items.length ? <ListingGrid items={items} lang={lang} t={t} favorites={favorites} signedIn={Boolean(user)} /> : <p className="text-sm text-muted">{t("common.no_results")}</p>}
        <Pagination page={page} total={total} pageSize={PAGE_SIZE} params={{}} basePath={`/boutiques/${slug}`} prev={t("common.prev")} next={t("common.next")} />
        {reviews && reviews.length > 0 && (
          <section className="mt-10">
            <h2 className="mb-3 text-lg font-bold">{t("listing.reviews")}</h2>
            <ul className="space-y-2">
              {(reviews as unknown as { id: string; rating: number; comment: string | null; created_at: string; profiles: { display_name: string } | null }[]).map((r) => (
                <li key={r.id} className="rounded-xl border border-border bg-card p-3 text-sm">
                  <span className="font-semibold">{r.profiles?.display_name}</span> · {"★".repeat(r.rating)} <span className="text-muted">· {timeAgo(r.created_at, lang)}</span>
                  {r.comment && <p className="mt-1 text-muted">{r.comment}</p>}
                </li>
              ))}
            </ul>
          </section>
        )}
      </Container>
    </>
  );
}
