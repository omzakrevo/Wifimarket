import { Badge, Card, PageTitle } from "@/components/ui/card";
import { ActionButton } from "@/components/action-button";
import { activatePromotion, activateSubscription, cancelSubscription, rejectPromotion } from "@/app/actions/admin";
import { getT } from "@/lib/i18n";
import { createClient } from "@/lib/supabase/server";
import { timeAgo } from "@/lib/utils";

export default async function AdminPromotions() {
  const { t, lang } = await getT();
  const supabase = await createClient();
  const [{ data: promos }, { data: subs }] = await Promise.all([
    supabase.from("promotions").select("id,status,plan_code,created_at,ends_at, listings(title), requester:profiles!promotions_requested_by_fkey(display_name)").order("created_at", { ascending: false }).limit(60),
    supabase.from("subscriptions").select("id,status,plan_code,created_at,ends_at, shops(name)").order("created_at", { ascending: false }).limit(60),
  ]);
  return (
    <>
      <p className="mb-4 rounded-lg bg-amber-50 p-3 text-sm text-amber-900 dark:bg-amber-950/40 dark:text-amber-100">{t("admin.activate_after_payment")}</p>
      <PageTitle>{t("admin.sponsored")}</PageTitle>
      <ul className="mb-8 space-y-2">
        {(promos ?? []).map((p) => (
          <li key={p.id}><Card className="flex flex-wrap items-center justify-between gap-2 p-3">
            <div><p className="font-semibold">{(p.listings as unknown as { title: string } | null)?.title}</p><p className="text-sm text-muted">{(p.requester as unknown as { display_name: string } | null)?.display_name} · {p.plan_code} · {timeAgo(p.created_at, lang)}{p.ends_at ? ` · → ${new Date(p.ends_at).toLocaleDateString()}` : ""}</p></div>
            <div className="flex items-center gap-2"><Badge tone={p.status === "active" ? "success" : "warn"}>{p.status}</Badge>
              {p.status === "pending" && <><ActionButton action={activatePromotion.bind(null, p.id)}>{t("admin.activate")}</ActionButton><ActionButton variant="outline" action={rejectPromotion.bind(null, p.id)}>{t("admin.reject")}</ActionButton></>}</div>
          </Card></li>
        ))}
      </ul>
      <PageTitle>{t("admin.subscriptions")}</PageTitle>
      <ul className="space-y-2">
        {(subs ?? []).map((s) => (
          <li key={s.id}><Card className="flex flex-wrap items-center justify-between gap-2 p-3">
            <div><p className="font-semibold">{(s.shops as unknown as { name: string } | null)?.name}</p><p className="text-sm text-muted">{s.plan_code} · {timeAgo(s.created_at, lang)}{s.ends_at ? ` · → ${new Date(s.ends_at).toLocaleDateString()}` : ""}</p></div>
            <div className="flex items-center gap-2"><Badge tone={s.status === "active" ? "success" : "warn"}>{s.status}</Badge>
              {s.status === "pending" && <ActionButton action={activateSubscription.bind(null, s.id)}>{t("admin.activate")}</ActionButton>}
              {s.status === "active" && <ActionButton variant="outline" confirm={t("admin.confirm_revoke")} action={cancelSubscription.bind(null, s.id)}>{t("common.cancel")}</ActionButton>}</div>
          </Card></li>
        ))}
      </ul>
    </>
  );
}
