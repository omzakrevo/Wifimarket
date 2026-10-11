import { ListingCard } from "@/components/listing-card";
import type { ListingCard as L } from "@/lib/types";
import type { MessageKey } from "@/lib/i18n/messages";

export function ListingGrid({ items, lang, t, favorites, signedIn }: {
  items: L[]; lang: "fr" | "en"; t: (k: MessageKey, v?: Record<string, string | number>) => string; favorites?: Set<string>; signedIn: boolean;
}) {
  return (
    <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4">
      {items.map((l) => <ListingCard key={l.id} l={l} lang={lang} t={t} favorites={favorites} signedIn={signedIn} />)}
    </div>
  );
}
