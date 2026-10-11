import type { Metadata } from "next";
import Link from "next/link";
import { Badge, Card, PageTitle } from "@/components/ui/card";
import { LinkButton } from "@/components/ui/button";
import { getUser } from "@/lib/auth";
import { getT } from "@/lib/i18n";
import { createClient } from "@/lib/supabase/server";
import { timeAgo } from "@/lib/utils";
import type { MessageKey } from "@/lib/i18n/messages";

export const metadata: Metadata = { title: "Mes demandes", robots: { index: false } };

export default async function MyWantedPage() {
  const { t, lang } = await getT();
  const user = (await getUser())!;
  const supabase = await createClient();
  const [{ data: mine }, { data: sent }] = await Promise.all([
    supabase.from("wanted_requests").select("id,title,status,created_at, wanted_offers(count)").eq("requester_id", user.id).order("created_at", { ascending: false }),
    supabase.from("wanted_offers").select("id,price,currency_code,status,created_at, wanted_requests(id,title)").eq("seller_id", user.id).order("created_at", { ascending: false }),
  ]);
  return (
    <>
      <div className="flex items-start justify-between"><PageTitle>{t("account.my_wanted")}</PageTitle><LinkButton href="/demandes/nouvelle" size="sm" variant="promo">{t("home.post_wanted")}</LinkButton></div>
      {!mine?.length ? <p className="text-sm text-muted">{t("wanted.none_mine")}</p> : (
        <ul className="space-y-2">
          {mine.map((w) => (
            <li key={w.id}><Card className="flex items-center justify-between gap-2 p-3">
              <Link href={`/demandes/${w.id}`} className="font-medium hover:underline">{w.title}</Link>
              <span className="flex items-center gap-2 text-sm text-muted">{t("wanted.offers_count", { n: (w.wanted_offers as unknown as { count: number }[])?.[0]?.count ?? 0 })} · {timeAgo(w.created_at, lang)} <Badge>{t(`wanted.s.${w.status}` as MessageKey)}</Badge></span>
            </Card></li>
          ))}
        </ul>
      )}
      <h2 className="mb-2 mt-8 text-lg font-bold">{t("wanted.my_offers")}</h2>
      {!sent?.length ? <p className="text-sm text-muted">{t("wanted.no_offers_sent")}</p> : (
        <ul className="space-y-2">
          {sent.map((o) => {
            const r = o.wanted_requests as unknown as { id: string; title: string } | null;
            return <li key={o.id}><Card className="flex items-center justify-between gap-2 p-3"><Link href={`/demandes/${r?.id}`} className="font-medium hover:underline">{r?.title}</Link><Badge>{t(`wanted.os.${o.status}` as MessageKey)}</Badge></Card></li>;
          })}
        </ul>
      )}
    </>
  );
}
