"use client";
import { useState } from "react";
import { ChevronLeft, ChevronRight, ImageOff } from "lucide-react";
import { useT } from "@/lib/i18n/client";

export function ListingGallery({ media, title }: { media: { url: string; kind: "image" | "video" }[]; title: string }) {
  const [i, setI] = useState(0);
  const t = useT();
  if (!media.length) {
    return <div className="flex aspect-[4/3] items-center justify-center rounded-xl bg-brand-soft/50 text-brand/60"><ImageOff size={48} aria-label={t("listing.no_photo")} /></div>;
  }
  const cur = media[i];
  return (
    <div>
      <div className="relative aspect-[4/3] overflow-hidden rounded-xl bg-black/5">
        {cur.kind === "video" ? (
          <video src={cur.url} controls playsInline preload="metadata" className="h-full w-full bg-black object-contain" />
        ) : (
          <img src={cur.url} alt={`${title} (${i + 1}/${media.length})`} className="h-full w-full object-contain" />
        )}
        {media.length > 1 && (
          <>
            <button type="button" aria-label={t("common.prev")} onClick={() => setI((i - 1 + media.length) % media.length)} className="absolute left-2 top-1/2 flex h-9 w-9 -translate-y-1/2 items-center justify-center rounded-full bg-card/90 shadow"><ChevronLeft size={18} /></button>
            <button type="button" aria-label={t("common.next")} onClick={() => setI((i + 1) % media.length)} className="absolute right-2 top-1/2 flex h-9 w-9 -translate-y-1/2 items-center justify-center rounded-full bg-card/90 shadow"><ChevronRight size={18} /></button>
          </>
        )}
      </div>
      {media.length > 1 && (
        <ul className="mt-2 flex gap-2 overflow-x-auto pb-1">
          {media.map((m, idx) => (
            <li key={m.url}>
              <button type="button" onClick={() => setI(idx)} aria-label={`${idx + 1}`} aria-current={idx === i} className={`h-16 w-20 overflow-hidden rounded-lg border-2 ${idx === i ? "border-brand" : "border-transparent"}`}>
                {m.kind === "video" ? <span className="flex h-full w-full items-center justify-center bg-black text-xs text-white">▶</span> :
                  <img src={m.url} alt="" loading="lazy" className="h-full w-full object-cover" />}
              </button>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
