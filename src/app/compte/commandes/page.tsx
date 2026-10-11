import type { Metadata } from "next";
import { Badge, Card, PageTitle } from "@/components/ui/card";
import { OrderActions } from "@/components/order-actions";
import { PayOnlineButton } from "@/components/pay-online-button";
import { ReviewForm } from "@/components/negotiation-actions";
import { getUser } from "@/lib/auth";
import { getT } from "@/lib/i18n";
import { createClient } from "@/lib/supabase/server";
import { formatPrice, timeAgo } from "@/lib/utils";
import type { MessageKey } from "@/lib/i18n/messages";

export const metadata: Metadata = { title: "Mes commandes", robots: { index: false } };

type Order = {
  id: string; order_number: string; status: string; total: number; subtotal: number; shipping_fee: number; currency_code: string; delivery_method: string;
  buyer_id: string; seller_id: string; created_at: string; payment_method: string | null; shipping_address: Record<string, string> | null; buyer_note: string | null;
  order_items: { id: string; title: string; quantity: number; unit_price: number }[];
  shipments: { status: string; tracking_number: string | null; carrier: string | null }[];
  payments: { status: string; provider: string; is_sandbox: boolean }[];
  buyer: { display_name: string } | null; seller: { display_name: string } | null;
  reviews?: { id: string }[];
};

export default async function OrdersPage({ searchParams }: { searchParams: Promise<{ placed?: string }> }) {
  const sp = await searchParams;
  const { t, lang } = await getT();
  const user = (await getUser())!;
  const supabase = await createClient();
  const { data } = await supabase.from("orders")
    .select("*, order_items(id,title,quantity,unit_price), shipments(status,tracking_number,carrier), payments(status,provider,is_sandbox), buyer:profiles!orders_buyer_id_fkey(display_name), seller:profiles!orders_seller_id_fkey(display_name)")
    .order("created_at", { ascending: false });
  const orders = (data ?? []) as unknown as Order[];
  const { data: myReviews } = await supabase.from("reviews").select("order_id").eq("reviewer_id", user.id).not("order_id", "is", null);
  const { data: paystack } = await supabase.from("payment_providers").select("enabled,eligibility_verified,currencies,sandbox").eq("code", "paystack").maybeSingle();
  const canPayOnline = (o: Order) => Boolean(paystack?.enabled && paystack.eligibility_verified && paystack.currencies.includes(o.currency_code) && process.env.PAYSTACK_SECRET_KEY)
    && ["pending", "awaiting_payment"].includes(o.status) && o.buyer_id === user.id && !o.payments.some((p) => p.status === "succeeded");
  const reviewed = new Set((myReviews ?? []).map((r) => r.order_id as string));
  const tone = (s: string) => (["completed", "delivered", "paid"].includes(s) ? "success" : ["cancelled", "refunded", "disputed"].includes(s) ? "danger" : "warn") as "success" | "danger" | "warn";
  const section = (title: string, list: Order[], role: "buyer" | "seller") => (
    <section className="mb-8">
      <h2 className="mb-3 text-lg font-bold">{title} ({list.length})</h2>
      {!list.length ? <p className="text-sm text-muted">{t("order.none")}</p> : (
        <ul className="space-y-3">
          {list.map((o) => (
            <li key={o.id}>
              <Card className="p-4">
                <div className="flex flex-wrap items-start justify-between gap-2">
                  <div>
                    <p className="font-semibold">{o.order_number}</p>
                    <p className="text-sm text-muted">{role === "buyer" ? o.seller?.display_name : o.buyer?.display_name} · {timeAgo(o.created_at, lang)} · {t(`ship.${o.delivery_method}` as MessageKey)}</p>
                  </div>
                  <Badge tone={tone(o.status)}>{t(`order.s.${o.status}` as MessageKey)}</Badge>
                </div>
                <ul className="mt-2 text-sm">{o.order_items.map((i) => <li key={i.id}>{i.quantity} × {i.title} — {formatPrice(i.unit_price, o.currency_code, lang)}</li>)}</ul>
                <p className="mt-2 text-sm">{t("cart.subtotal")} {formatPrice(o.subtotal, o.currency_code, lang)} + {t("order.shipping")} {formatPrice(o.shipping_fee, o.currency_code, lang)} = <strong>{formatPrice(o.total, o.currency_code, lang)}</strong></p>
                <p className="text-xs text-muted">{t("order.payment")} : {o.payments.length ? o.payments.map((p) => `${p.provider} (${p.status}${p.is_sandbox ? ", sandbox" : ""})`).join(", ") : t("checkout.pay_offline")}</p>
                {o.shipments[0]?.tracking_number && <p className="text-sm">{t("order.tracking")} : <strong>{o.shipments[0].tracking_number}</strong>{o.shipments[0].carrier ? ` (${o.shipments[0].carrier})` : ""}</p>}
                {o.shipping_address && <p className="text-xs text-muted">{[o.shipping_address.recipient, o.shipping_address.line1, o.shipping_address.city, o.shipping_address.country, o.shipping_address.phone].filter(Boolean).join(", ")}</p>}
                {canPayOnline(o) && <div className="mt-2"><PayOnlineButton orderId={o.id} sandbox={Boolean(paystack?.sandbox)} /></div>}
                <OrderActions id={o.id} role={role} status={o.status} method={o.delivery_method} />
                {role === "buyer" && ["delivered", "completed"].includes(o.status) && !reviewed.has(o.id) && <ReviewForm sellerId={o.seller_id} orderId={o.id} />}
              </Card>
            </li>
          ))}
        </ul>
      )}
    </section>
  );
  return (
    <>
      <PageTitle>{t("account.orders")}</PageTitle>
      {sp.placed && <p role="status" className="mb-4 rounded-lg bg-emerald-50 p-3 text-sm text-emerald-800 dark:bg-emerald-950/40 dark:text-emerald-200">{t("order.placed")}</p>}
      {section(t("order.purchases"), orders.filter((o) => o.buyer_id === user.id), "buyer")}
      {section(t("order.sales"), orders.filter((o) => o.seller_id === user.id), "seller")}
    </>
  );
}
