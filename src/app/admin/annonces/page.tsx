import Link from "next/link";
import { Badge, Card, PageTitle } from "@/components/ui/card";
import { Select } from "@/components/ui/form";
import { ActionButton } from "@/components/action-button";
import { approveListing, rejectListing, removeListing } from "@/app/actions/admin";
import { getT } from "@/lib/i18n";
import { createClient } from "@/lib/supabase/server";
import { formatPrice, timeAgo } from "@/lib/utils";
import type { MessageKey } from "@/lib/i18n/messages";

export default async function AdminListings({ searchParams }: { searchParams: Promise<{ status?: string }> }) {
  const sp = await searchParams;
  const { t, lang } = await getT();
  const status = sp.status ?? "pending_review";
  const supabase = await createClient();
  let q = supabase.from("listings").select("id,slug,title,price,currency_code,status,country_code,city,created_at,rejection_reason,is_demo, profiles(display_name)").order("created_at", { ascending: false }).limit(100);
  if (status !== "all") q = q.eq("status", status);
  const { data } = await q;
  return (
    <>
      <PageTitle>{t("admin.listings")}</PageTitle>
      <form className="mb-4 flex gap-2"><Select name="status" defaultValue={status} className="w-56" aria-label="Statut">
        {["pending_review", "active", "rejected", "removed", "paused", "sold", "expired", "draft", "all"].map((s) => <option key={s} value={s}>{s === "all" ? t("common.all") : t(`status.${s}` as MessageKey)}</option>)}
      </Select><button className="h-10 rounded-lg bg-brand px-4 text-sm font-semibold text-white dark:text-slate-950">{t("common.apply")}</button></form>
      {!data?.length ? <p className="text-sm text-muted">{t("common.no_results")}</p> : (
        <ul className="space-y-2">
          {data.map((l) => (
            <li key={l.id}><Card className="p-3">
              <div className="flex flex-wrap items-start justify-between gap-2">
                <div className="min-w-0">
                  <Link href={`/annonces/${l.slug}`} className="font-semibold hover:underline">{l.title}</Link>
                  <p className="text-sm text-muted">{(l.profiles as unknown as { display_name: string } | null)?.display_name} · {formatPrice(l.price, l.currency_code, lang)} · {[l.city, l.country_code].filter(Boolean).join(", ")} · {timeAgo(l.created_at, lang)}{l.is_demo ? " · DEMO" : ""}</p>
                  {l.rejection_reason && <p className="text-xs text-red-600">{l.rejection_reason}</p>}
                </div>
                <Badge>{t(`status.${l.status}` as MessageKey)}</Badge>
              </div>
              <div className="mt-2 flex flex-wrap gap-2">
                {l.status !== "active" && l.status !== "removed" && <ActionButton action={approveListing.bind(null, l.id)}>{t("admin.approve")}</ActionButton>}
                {l.status !== "rejected" && l.status !== "removed" && <ActionButton variant="outline" prompt={t("admin.reason_prompt")} action={rejectListing.bind(null, l.id)}>{t("admin.reject")}</ActionButton>}
                {l.status !== "removed" && <ActionButton variant="danger" prompt={t("admin.reason_prompt")} action={removeListing.bind(null, l.id)}>{t("admin.remove")}</ActionButton>}
              </div>
            </Card></li>
          ))}
        </ul>
      )}
    </>
  );
}
