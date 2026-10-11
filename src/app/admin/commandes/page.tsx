import { Badge, Card, PageTitle } from "@/components/ui/card";
import { Select } from "@/components/ui/form";
import { ActionButton } from "@/components/action-button";
import { resolveDispute, setOrderStatus } from "@/app/actions/admin";
import { getT } from "@/lib/i18n";
import { createClient } from "@/lib/supabase/server";
import { formatPrice, timeAgo } from "@/lib/utils";
import type { MessageKey } from "@/lib/i18n/messages";

export default async function AdminOrders({ searchParams }: { searchParams: Promise<{ status?: string }> }) {
  const sp = await searchParams;
  const { t, lang } = await getT();
  const supabase = await createClient();
  let q = supabase.from("orders").select("id,order_number,status,total,currency_code,delivery_method,created_at,is_demo, buyer:profiles!orders_buyer_id_fkey(display_name), seller:profiles!orders_seller_id_fkey(display_name), payments(status,provider,is_sandbox)").order("created_at", { ascending: false }).limit(100);
  if (sp.status) q = q.eq("status", sp.status);
  const [{ data: orders }, { data: disputes }] = await Promise.all([
    q, supabase.from("disputes").select("id,reason,status,created_at,orders(order_number), opener:profiles!disputes_opened_by_fkey(display_name)").in("status", ["open", "investigating"]).order("created_at"),
  ]);
  const statuses = ["pending", "awaiting_payment", "paid", "processing", "shipped", "delivered", "completed", "cancelled", "refunded", "disputed"];
  return (
    <>
      <PageTitle>{t("admin.disputes")}</PageTitle>
      {!disputes?.length ? <p className="mb-6 text-sm text-muted">{t("admin.no_disputes")}</p> : (
        <ul className="mb-8 space-y-2">
          {disputes.map((d) => (
            <li key={d.id}><Card className="p-3">
              <p className="font-semibold">{(d.orders as unknown as { order_number: string } | null)?.order_number} — {(d.opener as unknown as { display_name: string } | null)?.display_name}</p>
              <p className="text-sm">{d.reason}</p><p className="text-xs text-muted">{timeAgo(d.created_at, lang)}</p>
              <div className="mt-2 flex flex-wrap gap-2">
                {d.status === "open" && <ActionButton variant="outline" action={resolveDispute.bind(null, d.id, "investigating", undefined)}>{t("admin.reviewing")}</ActionButton>}
                <ActionButton action={resolveDispute.bind(null, d.id, "resolved_buyer", "Résolu en faveur de l'acheteur")}>{t("admin.favor_buyer")}</ActionButton>
                <ActionButton action={resolveDispute.bind(null, d.id, "resolved_seller", "Résolu en faveur du vendeur")}>{t("admin.favor_seller")}</ActionButton>
                <ActionButton variant="ghost" action={resolveDispute.bind(null, d.id, "closed", undefined)}>{t("admin.close")}</ActionButton>
              </div>
            </Card></li>
          ))}
        </ul>
      )}
      <PageTitle>{t("admin.orders")}</PageTitle>
      <form className="mb-4 flex gap-2"><Select name="status" defaultValue={sp.status ?? ""} className="w-56" aria-label="Statut"><option value="">{t("common.all")}</option>{statuses.map((s) => <option key={s} value={s}>{t(`order.s.${s}` as MessageKey)}</option>)}</Select><button className="h-10 rounded-lg bg-brand px-4 text-sm font-semibold text-white dark:text-slate-950">{t("common.apply")}</button></form>
      <ul className="space-y-2">
        {(orders ?? []).map((o) => (
          <li key={o.id}><Card className="flex flex-wrap items-center justify-between gap-2 p-3">
            <div>
              <p className="font-semibold">{o.order_number} <span className="font-normal text-muted">· {formatPrice(o.total, o.currency_code, lang)} · {t(`ship.${o.delivery_method}` as MessageKey)}{o.is_demo ? " · DEMO" : ""}</span></p>
              <p className="text-sm text-muted">{(o.buyer as unknown as { display_name: string } | null)?.display_name} → {(o.seller as unknown as { display_name: string } | null)?.display_name} · {timeAgo(o.created_at, lang)} · {(o.payments as unknown as { provider: string; status: string; is_sandbox: boolean }[]).map((p) => `${p.provider}:${p.status}${p.is_sandbox ? " (sandbox)" : ""}`).join(", ") || "—"}</p>
            </div>
            <div className="flex items-center gap-2"><Badge>{t(`order.s.${o.status}` as MessageKey)}</Badge>
              {["pending", "processing", "shipped"].includes(o.status) && <ActionButton variant="outline" confirm={t("admin.confirm_cancel_order")} action={setOrderStatus.bind(null, o.id, "cancelled")}>{t("order.cancel")}</ActionButton>}</div>
          </Card></li>
        ))}
      </ul>
    </>
  );
}
