import type { Metadata } from "next";
import Link from "next/link";
import { Badge, Card, PageTitle } from "@/components/ui/card";
import { LinkButton } from "@/components/ui/button";
import { ListingRowActions } from "@/components/listing-row-actions";
import { PromoteButton } from "@/components/promote-button";
import { getT } from "@/lib/i18n";
import { createClient } from "@/lib/supabase/server";
import { getUser } from "@/lib/auth";
import { formatPrice, timeAgo } from "@/lib/utils";
import type { MessageKey } from "@/lib/i18n/messages";

export const metadata: Metadata = { title: "Mes annonces", robots: { index: false } };

const TONE: Record<string, "default" | "success" | "warn" | "danger"> = { active: "success", draft: "default", pending_review: "warn", paused: "warn", sold: "default", rejected: "danger", expired: "warn", removed: "danger" };

export default async function MyListingsPage({ searchParams }: { searchParams: Promise<{ review?: string }> }) {
  const sp = await searchParams;
  const { t, lang } = await getT();
  const user = await getUser();
  const supabase = await createClient();
  const { data } = await supabase.from("listings").select("id,slug,title,price,currency_code,status,views_count,created_at,expires_at,rejection_reason,is_sponsored,listing_media(storage_path,position)")
    .eq("seller_id", user!.id).order("created_at", { ascending: false });
  const { data: plan } = await supabase.from("plans").select("code,price,currency_code,duration_days").eq("code", "sponsored_7d").maybeSingle();
  return (
    <>
      <div className="mb-4 flex items-start justify-between gap-3">
        <PageTitle>{t("account.my_listings")}</PageTitle>
        <LinkButton href="/vendre" variant="promo" size="sm">{t("nav.sell")}</LinkButton>
      </div>
      {sp.review && <p role="status" className="mb-4 rounded-lg bg-amber-50 p-3 text-sm text-amber-900 dark:bg-amber-950/40 dark:text-amber-100">{t("form.under_review")}</p>}
      {!data?.length ? <p className="text-sm text-muted">{t("account.no_listings")}</p> : (
        <ul className="space-y-3">
          {data.map((l) => (
            <li key={l.id}>
              <Card className="p-4">
                <div className="flex flex-wrap items-start justify-between gap-2">
                  <div className="min-w-0">
                    <Link href={`/annonces/${l.slug}`} className="font-semibold hover:underline">{l.title}</Link>
                    <p className="text-sm text-muted">{formatPrice(l.price, l.currency_code, lang)} · {l.views_count} {t("listing.views")} · {timeAgo(l.created_at, lang)}</p>
                    {l.rejection_reason && <p className="mt-1 text-sm text-red-600">{l.rejection_reason}</p>}
                    {l.expires_at && l.status === "active" && <p className="text-xs text-muted">{t("listing.expires")} {new Date(l.expires_at).toLocaleDateString(lang === "en" ? "en-GB" : "fr-FR")}</p>}
                  </div>
                  <div className="flex gap-1">{l.is_sponsored && <Badge tone="promo">{t("listing.sponsored")}</Badge>}<Badge tone={TONE[l.status]}>{t(`status.${l.status}` as MessageKey)}</Badge></div>
                </div>
                <div className="mt-3 flex flex-wrap items-center gap-2">
                  <ListingRowActions id={l.id} slug={l.slug} status={l.status} />
                  {l.status === "active" && !l.is_sponsored && plan && <PromoteButton listingId={l.id} priceLabel={formatPrice(plan.price, plan.currency_code, lang)} days={plan.duration_days} />}
                </div>
              </Card>
            </li>
          ))}
        </ul>
      )}
    </>
  );
}
