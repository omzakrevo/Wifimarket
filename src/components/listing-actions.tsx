"use client";
import { Flag, MessageCircle, Share2, ShoppingCart, Handshake } from "lucide-react";
import { useActionState, useEffect, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { addToCart, createNegotiation, createReport, incrementViews, startConversation } from "@/app/actions/market";
import { Button } from "@/components/ui/button";
import { Field, Input, Select, Textarea } from "@/components/ui/form";
import { SubmitButton } from "@/components/submit-button";
import { FavoriteButton } from "@/components/favorite-button";
import { useT } from "@/lib/i18n/client";
import type { MessageKey } from "@/lib/i18n/messages";

export function ViewPing({ id }: { id: string }) {
  useEffect(() => {
    try {
      const key = `wm_v_${id}`;
      if (sessionStorage.getItem(key)) return;
      sessionStorage.setItem(key, "1");
    } catch { /* stockage indisponible : on compte quand même */ }
    void incrementViews(id);
  }, [id]);
  return null;
}

type Props = {
  listing: { id: string; slug: string; title: string; seller_id: string; currency_code: string; negotiable: boolean; exchange_possible: boolean; quantity: number; price: number };
  signedIn: boolean; isOwner: boolean; isFavorite: boolean; whatsapp: string | null;
  myListings: { id: string; title: string }[];
};

export function ListingActions({ listing, signedIn, isOwner, isFavorite, whatsapp, myListings }: Props) {
  const t = useT();
  const router = useRouter();
  const [panel, setPanel] = useState<null | "nego" | "report">(null);
  const [cartMsg, setCartMsg] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const [shareMsg, setShareMsg] = useState<string | null>(null);
  const [negoState, negoAction] = useActionState(createNegotiation, undefined);
  const [reportState, reportAction] = useActionState(createReport, undefined);
  const requireAuth = () => { router.push(`/connexion?next=${encodeURIComponent(`/annonces/${listing.slug}`)}`); };

  async function share() {
    const url = window.location.href;
    try {
      if (navigator.share) await navigator.share({ title: listing.title, url });
      else { await navigator.clipboard.writeText(url); setShareMsg(t("listing.link_copied")); setTimeout(() => setShareMsg(null), 2500); }
    } catch { /* partage annulé */ }
  }

  if (isOwner) return null;
  const available = listing.quantity > 0;
  return (
    <div className="space-y-3">
      <div className="grid grid-cols-2 gap-2">
        <form action={async () => { if (!signedIn) { requireAuth(); return; } await startConversation(listing.id, listing.seller_id); }}>
          <Button type="submit" className="w-full"><MessageCircle size={16} />{t("listing.contact")}</Button>
        </form>
        <Button variant="navy" disabled={!available || pending} onClick={() => {
          if (!signedIn) return requireAuth();
          start(async () => {
            const r = await addToCart(listing.id, 1);
            if (r.ok) router.push("/panier"); else setCartMsg(t((r.error ?? "err.generic") as MessageKey));
          });
        }}><ShoppingCart size={16} />{t("listing.buy")}</Button>
        {(listing.negotiable || listing.exchange_possible) && (
          <Button variant="outline" onClick={() => (signedIn ? setPanel(panel === "nego" ? null : "nego") : requireAuth())}><Handshake size={16} />{t("listing.negotiate")}</Button>
        )}
        <FavoriteButton listingId={listing.id} initial={isFavorite} signedIn={signedIn} label />
        <Button variant="outline" onClick={share}><Share2 size={16} />{t("listing.share")}</Button>
        <Button variant="ghost" onClick={() => (signedIn ? setPanel(panel === "report" ? null : "report") : requireAuth())}><Flag size={16} />{t("listing.report")}</Button>
      </div>
      {shareMsg && <p role="status" className="text-sm text-emerald-700">{shareMsg}</p>}
      {cartMsg && <p role="alert" className="text-sm text-red-600">{cartMsg}</p>}
      {whatsapp && (
        <a href={`https://wa.me/${whatsapp.replace(/\D/g, "")}?text=${encodeURIComponent(`${listing.title} — WiFiMarket`)}`} target="_blank" rel="noopener noreferrer"
          className="flex h-10 items-center justify-center rounded-lg bg-[#25D366] text-sm font-semibold text-slate-950 hover:brightness-95">
          {t("listing.whatsapp")}
        </a>
      )}

      {panel === "nego" && (
        <form action={negoAction} className="space-y-3 rounded-xl border border-border bg-card p-4">
          <input type="hidden" name="listing_id" value={listing.id} />
          <Field label={t("nego.type")}>
            <Select name="kind" defaultValue={listing.negotiable ? "offer" : "exchange"}>
              {listing.negotiable && <option value="offer">{t("nego.offer")}</option>}
              {listing.exchange_possible && <option value="exchange">{t("nego.exchange")}</option>}
            </Select>
          </Field>
          {listing.negotiable && <Field label={`${t("nego.your_price")} (${listing.currency_code})`}><Input name="offered_price" inputMode="decimal" type="number" min="0" step="any" placeholder={String(listing.price)} /></Field>}
          {listing.exchange_possible && (
            <>
              <Field label={t("nego.my_item")} hint={myListings.length ? undefined : t("nego.no_listing")}>
                <Select name="exchange_listing_id" defaultValue="">
                  <option value="">—</option>
                  {myListings.map((m) => <option key={m.id} value={m.id}>{m.title}</option>)}
                </Select>
              </Field>
              <Field label={`${t("nego.top_up")} (${listing.currency_code})`}><Input name="cash_top_up" inputMode="decimal" type="number" min="0" step="any" /></Field>
            </>
          )}
          <Field label={t("nego.note")}><Textarea name="note" maxLength={1000} /></Field>
          {negoState && <p role={negoState.ok ? "status" : "alert"} className={negoState.ok ? "text-sm text-emerald-700" : "text-sm text-red-600"}>{t((negoState.ok ? negoState.message : negoState.error) as MessageKey)}</p>}
          <SubmitButton>{t("nego.send")}</SubmitButton>
        </form>
      )}

      {panel === "report" && (
        <form action={reportAction} className="space-y-3 rounded-xl border border-border bg-card p-4">
          <input type="hidden" name="target_type" value="listing" />
          <input type="hidden" name="target_id" value={listing.id} />
          <Field label={t("report.reason")}>
            <Select name="reason" defaultValue="fraud">
              {(["fraud", "stolen", "prohibited", "counterfeit", "spam", "wrong_category", "other"] as const).map((r) => <option key={r} value={r}>{t(`report.r.${r}` as MessageKey)}</option>)}
            </Select>
          </Field>
          <Field label={t("report.details")}><Textarea name="details" maxLength={2000} /></Field>
          {reportState && <p role={reportState.ok ? "status" : "alert"} className={reportState.ok ? "text-sm text-emerald-700" : "text-sm text-red-600"}>{t((reportState.ok ? reportState.message : reportState.error) as MessageKey)}</p>}
          <SubmitButton variant="danger">{t("report.send")}</SubmitButton>
        </form>
      )}
    </div>
  );
}
