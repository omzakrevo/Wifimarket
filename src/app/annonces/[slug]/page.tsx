import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { BadgeCheck, MapPin, Truck, ShieldCheck, Star, Pencil } from "lucide-react";
import { Badge, Card, Container } from "@/components/ui/card";
import { LinkButton } from "@/components/ui/button";
import { ListingGallery } from "@/components/listing-gallery";
import { ListingActions, ViewPing } from "@/components/listing-actions";
import { ListingGrid } from "@/components/listing-grid";
import { getUser } from "@/lib/auth";
import { getFavoriteIds, getListingBySlug, listingImage, searchListings } from "@/lib/data";
import { getT } from "@/lib/i18n";
import { createClient } from "@/lib/supabase/server";
import { SITE_URL, formatPrice, publicStorageUrl, timeAgo } from "@/lib/utils";
import { getWhatsapp } from "@/app/actions/market";
import type { MessageKey } from "@/lib/i18n/messages";

type Props = { params: Promise<{ slug: string }> };

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { slug } = await params;
  const l = await getListingBySlug(slug);
  if (!l) return { title: "Annonce introuvable", robots: { index: false } };
  const img = listingImage(l);
  const title = `${l.title} — ${formatPrice(l.price, l.currency_code)}`;
  const description = (l.description || l.title).slice(0, 155);
  return {
    title, description,
    alternates: { canonical: `/annonces/${l.slug}` },
    robots: l.status === "active" || l.status === "sold" ? undefined : { index: false },
    openGraph: { title, description, url: `${SITE_URL}/annonces/${l.slug}`, type: "website", images: img ? [publicStorageUrl("listing-media", img)] : undefined },
  };
}

const AVAILABILITY: Record<string, string> = { active: "InStock", sold: "SoldOut" };
const ITEM_CONDITION: Record<string, string> = {
  new: "NewCondition", used: "UsedCondition", refurbished: "RefurbishedCondition", broken: "DamagedCondition", for_parts: "DamagedCondition",
};

export default async function ListingPage({ params }: Props) {
  const { slug } = await params;
  const l = await getListingBySlug(slug);
  if (!l) notFound();
  const { t, lang } = await getT();
  const supabase = await createClient();
  const user = await getUser();
  const isOwner = user?.id === l.seller_id;

  const [attrsRes, reviewsRes, ratingRes, favorites, whatsapp, mineRes, modelRes, similar] = await Promise.all([
    supabase.from("listing_attributes").select("key,value").eq("listing_id", l.id).order("key"),
    supabase.from("reviews").select("id,rating,comment,created_at,profiles:reviewer_id(display_name)").eq("seller_id", l.seller_id).order("created_at", { ascending: false }).limit(5),
    supabase.from("seller_ratings").select("rating_avg,rating_count").eq("seller_id", l.seller_id).maybeSingle(),
    getFavoriteIds(),
    l.status === "active" ? getWhatsapp(l.seller_id) : Promise.resolve(null),
    user && !isOwner && l.exchange_possible
      ? supabase.from("listings").select("id,title").eq("seller_id", user.id).eq("status", "active").order("created_at", { ascending: false }).limit(50)
      : Promise.resolve({ data: [] as { id: string; title: string }[] }),
    l.model_id ? supabase.from("product_models").select("specs").eq("id", l.model_id).maybeSingle() : Promise.resolve({ data: null }),
    searchListings({ category: l.categories?.slug, country: l.country_code, sort: "newest" }, { limit: 5 }),
  ]);
  const attrs = (attrsRes.data ?? []) as { key: string; value: string }[];
  const specs = Object.entries((modelRes.data?.specs ?? {}) as Record<string, string>);
  const shop = l.shop_id ? (await supabase.from("shops").select("name,slug,verification_status").eq("id", l.shop_id).maybeSingle()).data : null;
  const media = [...(l.listing_media ?? [])].sort((a, b) => a.position - b.position)
    .map((m) => ({ url: publicStorageUrl("listing-media", m.storage_path), kind: m.kind }));
  const rating = ratingRes.data as { rating_avg: number; rating_count: number } | null;
  const reviews = (reviewsRes.data ?? []) as unknown as { id: string; rating: number; comment: string | null; created_at: string; profiles: { display_name: string } | null }[];
  const others = similar.items.filter((x) => x.id !== l.id).slice(0, 4);
  const catName = l.categories ? (lang === "en" ? l.categories.name_en : l.categories.name_fr) : null;

  const jsonLd = {
    "@context": "https://schema.org", "@type": "Product", name: l.title, description: l.description || l.title,
    image: media.filter((m) => m.kind === "image").map((m) => m.url), sku: l.id,
    brand: l.brands ? { "@type": "Brand", name: l.brands.name } : undefined,
    category: catName ?? undefined,
    itemCondition: `https://schema.org/${ITEM_CONDITION[l.condition]}`,
    offers: {
      "@type": "Offer", url: `${SITE_URL}/annonces/${l.slug}`, price: l.price, priceCurrency: l.currency_code,
      availability: `https://schema.org/${AVAILABILITY[l.status] ?? "OutOfStock"}`,
      seller: { "@type": "Person", name: l.profiles?.display_name },
    },
    aggregateRating: rating && rating.rating_count > 0 ? { "@type": "AggregateRating", ratingValue: rating.rating_avg, reviewCount: rating.rating_count } : undefined,
  };

  return (
    <Container className="py-6">
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd).replace(/</g, "\\u003c") }} />
      <ViewPing id={l.id} />
      <nav aria-label="Fil d'Ariane" className="mb-3 text-sm text-muted">
        <Link href="/" className="hover:underline">{t("nav.home")}</Link> /{" "}
        {l.categories && <><Link href={`/categories/${l.categories.slug}`} className="hover:underline">{catName}</Link> / </>}
        <span className="text-foreground">{l.title}</span>
      </nav>

      {l.status !== "active" && (
        <p className="mb-4 rounded-lg bg-amber-50 p-3 text-sm font-medium text-amber-900 dark:bg-amber-950/40 dark:text-amber-100" role="status">
          {t(`status.${l.status}` as MessageKey)}{l.rejection_reason ? ` — ${l.rejection_reason}` : ""}
        </p>
      )}

      <div className="grid gap-6 lg:grid-cols-[1.3fr_1fr]">
        <div><ListingGallery media={media} title={l.title} /></div>
        <div className="space-y-4">
          <div>
            <div className="mb-2 flex flex-wrap gap-1.5">
              {l.is_sponsored && <Badge tone="promo">{t("listing.sponsored")}</Badge>}
              <Badge tone={l.condition === "new" ? "success" : l.condition === "broken" || l.condition === "for_parts" ? "warn" : "default"}>{t(`cond.${l.condition}` as MessageKey)}</Badge>
              {l.negotiable && <Badge>{t("listing.negotiable")}</Badge>}
              {l.exchange_possible && <Badge>{t("listing.exchange_ok")}</Badge>}
            </div>
            <h1 className="text-2xl font-bold leading-tight">{l.title}</h1>
            <p className="mt-2 text-3xl font-extrabold text-navy dark:text-brand">{formatPrice(l.price, l.currency_code, lang)}</p>
            <p className="mt-1 flex items-center gap-1 text-sm text-muted"><MapPin size={14} />{[l.city, l.country_code].filter(Boolean).join(", ")} · {l.published_at ? timeAgo(l.published_at, lang) : ""}</p>
          </div>

          <dl className="grid grid-cols-2 gap-x-4 gap-y-2 rounded-xl border border-border bg-card p-4 text-sm">
            {l.brands && <><dt className="text-muted">{t("common.brand")}</dt><dd className="font-medium">{l.brands.name}</dd></>}
            {l.model_text && <><dt className="text-muted">{t("listing.model")}</dt><dd className="font-medium">{l.model_text}</dd></>}
            <dt className="text-muted">{t("listing.quantity")}</dt><dd className="font-medium">{l.quantity}</dd>
            <dt className="text-muted">{t("listing.delivery")}</dt><dd className="flex items-center gap-1 font-medium"><Truck size={14} />{l.delivery_available ? t("common.yes") : t("listing.pickup_only")}</dd>
            {l.warranty && <><dt className="text-muted">{t("listing.warranty")}</dt><dd className="font-medium">{l.warranty}</dd></>}
          </dl>

          {isOwner ? (
            <div className="flex flex-wrap gap-2">
              <LinkButton href={`/vendre/${l.id}/modifier`} variant="outline"><Pencil size={16} />{t("common.edit")}</LinkButton>
              <LinkButton href="/compte/annonces" variant="ghost">{t("account.my_listings")}</LinkButton>
            </div>
          ) : l.status === "active" ? (
            <ListingActions
              listing={{ id: l.id, slug: l.slug, title: l.title, seller_id: l.seller_id, currency_code: l.currency_code, negotiable: l.negotiable, exchange_possible: l.exchange_possible, quantity: l.quantity, price: l.price }}
              signedIn={Boolean(user)} isOwner={false} isFavorite={favorites.has(l.id)} whatsapp={whatsapp} myListings={(mineRes.data ?? []) as { id: string; title: string }[]}
            />
          ) : null}

          <Card className="p-4">
            <p className="mb-2 text-xs font-semibold uppercase tracking-wide text-muted">{t("listing.seller")}</p>
            <div className="flex items-center gap-3">
              <span className="flex h-11 w-11 items-center justify-center rounded-full bg-brand-soft text-lg font-bold text-navy">{(l.profiles?.display_name ?? "?").slice(0, 1).toUpperCase()}</span>
              <div className="min-w-0">
                <Link href={`/vendeurs/${l.seller_id}`} className="flex items-center gap-1 font-semibold hover:underline">
                  {l.profiles?.display_name}{l.profiles?.verification_status === "verified" && <BadgeCheck size={16} className="text-brand" aria-label={t("profile.verified")} />}
                </Link>
                {rating && rating.rating_count > 0 ? (
                  <p className="flex items-center gap-1 text-sm text-muted"><Star size={14} className="fill-promo text-promo" />{rating.rating_avg} ({rating.rating_count})</p>
                ) : <p className="text-sm text-muted">{t("profile.no_reviews")}</p>}
                {shop && <Link href={`/boutiques/${shop.slug}`} className="text-sm text-brand hover:underline">{shop.name}</Link>}
              </div>
            </div>
          </Card>

          <p className="flex items-start gap-2 rounded-lg bg-brand-soft/60 p-3 text-xs text-navy dark:text-blue-100"><ShieldCheck size={16} className="mt-0.5 shrink-0" />{t("listing.safety_tip")}</p>
        </div>
      </div>

      <div className="mt-8 grid gap-6 lg:grid-cols-[1.3fr_1fr]">
        <div className="space-y-6">
          <section>
            <h2 className="mb-2 text-lg font-bold">{t("listing.description")}</h2>
            <p className="whitespace-pre-line text-sm leading-6">{l.description || t("listing.no_description")}</p>
            {l.defects && <p className="mt-3 rounded-lg bg-amber-50 p-3 text-sm text-amber-900 dark:bg-amber-950/40 dark:text-amber-100"><strong>{t("listing.defects")} :</strong> {l.defects}</p>}
          </section>
          {(attrs.length > 0 || specs.length > 0) && (
            <section>
              <h2 className="mb-2 text-lg font-bold">{t("listing.specs")}</h2>
              <dl className="divide-y divide-border rounded-xl border border-border bg-card text-sm">
                {[...specs, ...attrs.map((a) => [a.key, a.value] as [string, string])].map(([k, v]) => (
                  <div key={k} className="flex justify-between gap-4 px-4 py-2"><dt className="capitalize text-muted">{k}</dt><dd className="text-right font-medium">{v}</dd></div>
                ))}
              </dl>
            </section>
          )}
        </div>
        <section>
          <h2 className="mb-2 text-lg font-bold">{t("listing.reviews")}</h2>
          {reviews.length ? (
            <ul className="space-y-3">
              {reviews.map((r) => (
                <li key={r.id} className="rounded-xl border border-border bg-card p-3 text-sm">
                  <div className="flex items-center justify-between"><span className="font-semibold">{r.profiles?.display_name}</span><span className="flex" aria-label={`${r.rating}/5`}>{Array.from({ length: r.rating }).map((_, i) => <Star key={i} size={13} className="fill-promo text-promo" />)}</span></div>
                  {r.comment && <p className="mt-1 text-muted">{r.comment}</p>}
                </li>
              ))}
            </ul>
          ) : <p className="text-sm text-muted">{t("profile.no_reviews")}</p>}
        </section>
      </div>

      {others.length > 0 && (
        <section className="mt-10">
          <h2 className="mb-3 text-lg font-bold">{t("listing.similar")}</h2>
          <ListingGrid items={others} lang={lang} t={t} favorites={favorites} signedIn={Boolean(user)} />
        </section>
      )}
    </Container>
  );
}
