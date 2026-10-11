import Link from "next/link";
import { Cable, MapPin, Radio, Router, Satellite, Wrench, ImageOff, BadgeCheck, Truck } from "lucide-react";
import { Badge } from "@/components/ui/card";
import { FavoriteButton } from "@/components/favorite-button";
import { formatPrice, publicStorageUrl, timeAgo } from "@/lib/utils";
import { listingImage } from "@/lib/data";
import type { ListingCard as L } from "@/lib/types";
import type { MessageKey } from "@/lib/i18n/messages";

const ICONS: Record<string, typeof Radio> = { radio: Radio, router: Router, satellite: Satellite, cable: Cable, wrench: Wrench };

export function CategoryIcon({ name, size = 28 }: { name?: string | null; size?: number }) {
  const Icon = (name && ICONS[name]) || ImageOff;
  return <Icon size={size} />;
}

export function ListingCard({
  l, lang, t, favorites, signedIn,
}: {
  l: L; lang: "fr" | "en"; t: (k: MessageKey, v?: Record<string, string | number>) => string; favorites?: Set<string>; signedIn: boolean;
}) {
  const img = listingImage(l);
  const sponsored = l.is_sponsored && (!l.sponsored_until || new Date(l.sponsored_until) > new Date());
  return (
    <article className="group relative overflow-hidden rounded-xl border border-border bg-card shadow-sm transition-shadow hover:shadow-md">
      <div className="relative aspect-[4/3] bg-brand-soft/50">
        <Link href={`/annonces/${l.slug}`} className="absolute inset-0" aria-label={l.title}>
          {img ? (
            <img src={publicStorageUrl("listing-media", img)} alt={l.title} loading="lazy" className="h-full w-full object-cover" />
          ) : (
            <span className="flex h-full w-full items-center justify-center text-brand/60"><CategoryIcon name={l.categories?.icon} size={40} /></span>
          )}
        </Link>
        <div className="pointer-events-none absolute left-2 top-2 flex flex-wrap gap-1">
          {sponsored && <Badge tone="promo">{t("listing.sponsored")}</Badge>}
          <Badge tone={l.condition === "new" ? "success" : l.condition === "broken" || l.condition === "for_parts" ? "warn" : "default"}>{t(`cond.${l.condition}` as MessageKey)}</Badge>
        </div>
        <div className="absolute right-2 top-2"><FavoriteButton listingId={l.id} initial={favorites?.has(l.id) ?? false} signedIn={signedIn} /></div>
      </div>
      <div className="space-y-1 p-3">
        <p className="text-base font-extrabold text-navy dark:text-foreground">{formatPrice(l.price, l.currency_code, lang)}</p>
        <h3 className="line-clamp-2 min-h-10 text-sm font-medium leading-5">
          <Link href={`/annonces/${l.slug}`} className="hover:underline">{l.title}</Link>
        </h3>
        <p className="flex items-center gap-1 text-xs text-muted"><MapPin size={12} />{[l.city, l.country_code].filter(Boolean).join(", ")}</p>
        <div className="flex items-center justify-between text-xs text-muted">
          <span>{l.published_at ? timeAgo(l.published_at, lang) : ""}</span>
          <span className="flex items-center gap-1">
            {l.delivery_available && <Truck size={12} aria-label={t("listing.delivery")} />}
            {l.profiles?.verification_status === "verified" && <BadgeCheck size={14} className="text-brand" aria-label={t("profile.verified")} />}
          </span>
        </div>
      </div>
    </article>
  );
}
