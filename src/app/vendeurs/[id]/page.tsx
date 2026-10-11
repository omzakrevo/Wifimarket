import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { BadgeCheck, MapPin, Star } from "lucide-react";
import { Container } from "@/components/ui/card";
import { ListingGrid } from "@/components/listing-grid";
import { getUser } from "@/lib/auth";
import { getFavoriteIds, searchListings } from "@/lib/data";
import { getT } from "@/lib/i18n";
import { createClient } from "@/lib/supabase/server";
import { isUuid, publicStorageUrl, timeAgo } from "@/lib/utils";

type Props = { params: Promise<{ id: string }> };

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { id } = await params;
  if (!isUuid(id)) return {};
  const supabase = await createClient();
  const { data } = await supabase.from("profiles").select("display_name").eq("id", id).maybeSingle();
  return data ? { title: `${data.display_name} — vendeur`, alternates: { canonical: `/vendeurs/${id}` } } : {};
}

export default async function SellerPage({ params }: Props) {
  const { id } = await params;
  if (!isUuid(id)) notFound();
  const supabase = await createClient();
  const { data: p } = await supabase.from("profiles").select("*").eq("id", id).maybeSingle();
  if (!p) notFound();
  const { t, lang } = await getT();
  const [user, favorites, { items }, { data: rating }, { data: reviews }] = await Promise.all([
    getUser(), getFavoriteIds(), searchListings({ seller: id, sort: "newest" }, { limit: 24 }),
    supabase.from("seller_ratings").select("rating_avg,rating_count").eq("seller_id", id).maybeSingle(),
    supabase.from("reviews").select("id,rating,comment,created_at,profiles:reviewer_id(display_name)").eq("seller_id", id).order("created_at", { ascending: false }).limit(10),
  ]);
  return (
    <Container className="py-6">
      <div className="mb-6 flex items-center gap-4">
        <span className="flex h-20 w-20 items-center justify-center overflow-hidden rounded-full bg-brand-soft text-3xl font-bold text-navy">
          {p.avatar_url ? <img src={publicStorageUrl("avatars", p.avatar_url)} alt="" className="h-full w-full object-cover" /> : p.display_name.slice(0, 1).toUpperCase()}
        </span>
        <div>
          <h1 className="flex items-center gap-2 text-2xl font-bold">{p.display_name}{p.verification_status === "verified" && <BadgeCheck className="text-brand" aria-label={t("profile.verified")} />}</h1>
          <p className="flex items-center gap-1 text-sm text-muted"><MapPin size={14} />{[p.city, p.country_code].filter(Boolean).join(", ")} · {t("profile.member_since", { date: new Date(p.created_at).toLocaleDateString(lang === "en" ? "en-GB" : "fr-FR", { month: "long", year: "numeric" }) })}</p>
          {rating && rating.rating_count > 0 && <p className="flex items-center gap-1 text-sm"><Star size={14} className="fill-promo text-promo" />{rating.rating_avg} ({rating.rating_count})</p>}
          {p.bio && <p className="mt-1 text-sm">{p.bio}</p>}
        </div>
      </div>
      <h2 className="mb-3 text-lg font-bold">{t("account.my_listings")}</h2>
      {items.length ? <ListingGrid items={items} lang={lang} t={t} favorites={favorites} signedIn={Boolean(user)} /> : <p className="text-sm text-muted">{t("common.no_results")}</p>}
      {reviews && reviews.length > 0 && (
        <section className="mt-10">
          <h2 className="mb-3 text-lg font-bold">{t("listing.reviews")}</h2>
          <ul className="space-y-2">
            {(reviews as unknown as { id: string; rating: number; comment: string | null; created_at: string; profiles: { display_name: string } | null }[]).map((r) => (
              <li key={r.id} className="rounded-xl border border-border bg-card p-3 text-sm"><span className="font-semibold">{r.profiles?.display_name}</span> · {"★".repeat(r.rating)} <span className="text-muted">· {timeAgo(r.created_at, lang)}</span>{r.comment && <p className="mt-1 text-muted">{r.comment}</p>}</li>
            ))}
          </ul>
        </section>
      )}
    </Container>
  );
}
