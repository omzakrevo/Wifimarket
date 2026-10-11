import type { Metadata } from "next";
import Link from "next/link";
import { ArrowLeftRight, Tag } from "lucide-react";
import { Badge, Card, PageTitle } from "@/components/ui/card";
import { NegotiationActions, ReviewForm } from "@/components/negotiation-actions";
import { getUser } from "@/lib/auth";
import { getT } from "@/lib/i18n";
import { createClient } from "@/lib/supabase/server";
import { formatPrice, timeAgo } from "@/lib/utils";
import type { MessageKey } from "@/lib/i18n/messages";

export const metadata: Metadata = { title: "Négociations et échanges", robots: { index: false } };

type Nego = {
  id: string; kind: string; status: string; offered_price: number | null; cash_top_up: number | null; currency_code: string; note: string | null;
  buyer_id: string; seller_id: string; buyer_confirmed: boolean; seller_confirmed: boolean; created_at: string;
  listing: { title: string; slug: string; price: number } | null; exchange: { title: string; slug: string } | null;
  buyer: { display_name: string } | null; seller: { display_name: string } | null;
  negotiation_events: { id: number; action: string; created_at: string; detail: Record<string, unknown>; actor_id: string | null }[];
};

export default async function NegotiationsPage() {
  const { t, lang } = await getT();
  const user = (await getUser())!;
  const supabase = await createClient();
  const { data } = await supabase.from("negotiations")
    .select("*, listing:listings!negotiations_listing_id_fkey(title,slug,price), exchange:listings!negotiations_exchange_listing_id_fkey(title,slug), buyer:profiles!negotiations_buyer_id_fkey(display_name), seller:profiles!negotiations_seller_id_fkey(display_name), negotiation_events(id,action,created_at,detail,actor_id)")
    .order("created_at", { ascending: false });
  const items = (data ?? []) as unknown as Nego[];
  const tone = (s: string) => (s === "accepted" || s === "completed" ? "success" : s === "declined" || s === "cancelled" ? "danger" : "warn") as "success" | "danger" | "warn";
  return (
    <>
      <PageTitle sub={t("nego.page_sub")}>{t("account.negotiations")}</PageTitle>
      {!items.length ? <p className="text-sm text-muted">{t("nego.none")}</p> : (
        <ul className="space-y-3">
          {items.map((n) => {
            const role = n.buyer_id === user.id ? "buyer" : "seller";
            const other = role === "buyer" ? n.seller?.display_name : n.buyer?.display_name;
            return (
              <li key={n.id}>
                <Card className="p-4">
                  <div className="flex flex-wrap items-start justify-between gap-2">
                    <div>
                      <p className="flex items-center gap-2 font-semibold">{n.kind === "exchange" ? <ArrowLeftRight size={16} className="text-brand" /> : <Tag size={16} className="text-brand" />}
                        {n.listing ? <Link href={`/annonces/${n.listing.slug}`} className="hover:underline">{n.listing.title}</Link> : "—"}</p>
                      <p className="text-sm text-muted">{role === "buyer" ? t("nego.with_seller", { name: other ?? "" }) : t("nego.from_buyer", { name: other ?? "" })} · {timeAgo(n.created_at, lang)}</p>
                    </div>
                    <Badge tone={tone(n.status)}>{t(`nego.s.${n.status}` as MessageKey)}</Badge>
                  </div>
                  <p className="mt-2 text-sm">
                    {n.kind === "offer" && n.offered_price != null && <>{t("nego.offer")} : <strong>{formatPrice(n.offered_price, n.currency_code, lang)}</strong>{n.listing && <span className="text-muted"> ({t("nego.asking")} {formatPrice(n.listing.price, n.currency_code, lang)})</span>}</>}
                    {n.kind === "exchange" && <>{t("nego.exchange")} : <strong>{n.exchange?.title ?? "—"}</strong>{n.cash_top_up ? <> + {formatPrice(n.cash_top_up, n.currency_code, lang)}</> : null}</>}
                  </p>
                  {n.note && <p className="mt-1 text-sm text-muted">« {n.note} »</p>}
                  <NegotiationActions id={n.id} role={role} status={n.status} kind={n.kind} currency={n.currency_code} myConfirmed={role === "buyer" ? n.buyer_confirmed : n.seller_confirmed} />
                  {n.status === "completed" && role === "buyer" && <ReviewForm sellerId={n.seller_id} />}
                  <details className="mt-3 text-xs text-muted">
                    <summary className="cursor-pointer">{t("nego.history")}</summary>
                    <ol className="mt-2 space-y-1">
                      {[...n.negotiation_events].sort((a, b) => a.created_at.localeCompare(b.created_at)).map((e) => (
                        <li key={e.id}>{new Date(e.created_at).toLocaleString(lang === "en" ? "en-GB" : "fr-FR")} — {e.actor_id === user.id ? t("nego.you") : other} : {e.action}{e.detail?.price != null ? ` (${e.detail.price})` : ""}</li>
                      ))}
                    </ol>
                  </details>
                </Card>
              </li>
            );
          })}
        </ul>
      )}
    </>
  );
}
