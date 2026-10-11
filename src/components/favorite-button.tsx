"use client";
import { Heart } from "lucide-react";
import { useRouter } from "next/navigation";
import { useState, useTransition } from "react";
import { toggleFavorite } from "@/app/actions/favorites";
import { useT } from "@/lib/i18n/client";
import { cn } from "@/lib/utils";

export function FavoriteButton({ listingId, initial, signedIn, label = false }: { listingId: string; initial: boolean; signedIn: boolean; label?: boolean }) {
  const [fav, setFav] = useState(initial);
  const [pending, start] = useTransition();
  const router = useRouter();
  const t = useT();
  return (
    <button
      type="button"
      disabled={pending}
      aria-pressed={fav}
      aria-label={fav ? t("fav.remove") : t("fav.add")}
      onClick={(e) => {
        e.preventDefault();
        if (!signedIn) { router.push(`/connexion?next=${encodeURIComponent(window.location.pathname)}`); return; }
        const prev = fav;
        setFav(!prev);
        start(async () => {
          const res = await toggleFavorite(listingId);
          if (!res.ok) setFav(prev); else router.refresh();
        });
      }}
      className={cn(
        label
          ? "inline-flex h-10 items-center gap-2 rounded-lg border border-border bg-card px-4 text-sm font-semibold hover:bg-brand-soft/60"
          : "flex h-8 w-8 items-center justify-center rounded-full bg-card/90 shadow hover:bg-card",
      )}
    >
      <Heart size={label ? 18 : 16} className={fav ? "fill-red-500 text-red-500" : ""} />
      {label && <span>{fav ? t("fav.saved") : t("fav.add")}</span>}
    </button>
  );
}
