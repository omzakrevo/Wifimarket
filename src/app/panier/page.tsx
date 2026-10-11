import type { Metadata } from "next";
import Link from "next/link";
import { ShoppingCart } from "lucide-react";
import { Card, Container, PageTitle } from "@/components/ui/card";
import { LinkButton } from "@/components/ui/button";
import { CartItemControls } from "@/components/cart-item-controls";
import { requireUser } from "@/lib/auth";
import { getT } from "@/lib/i18n";
import { createClient } from "@/lib/supabase/server";
import { formatPrice } from "@/lib/utils";

export const metadata: Metadata = { title: "Panier", robots: { index: false } };

type Row = { quantity: number; listings: { id: string; title: string; slug: string; price: number; currency_code: string; quantity: number; status: string; seller_id: string; profiles: { display_name: string } | null } };

export default async function CartPage() {
  const user = await requireUser("/panier");
  const { t, lang } = await getT();
  const supabase = await createClient();
  const { data } = await supabase.from("cart_items").select("quantity, listings(id,title,slug,price,currency_code,quantity,status,seller_id, profiles(display_name))").eq("user_id", user.id).order("added_at");
  const rows = (data ?? []) as unknown as Row[];
  const totals = new Map<string, number>();
  for (const r of rows) totals.set(r.listings.currency_code, (totals.get(r.listings.currency_code) ?? 0) + r.listings.price * r.quantity);
  const unavailable = rows.some((r) => r.listings.status !== "active" || r.quantity > r.listings.quantity);
  return (
    <Container className="max-w-3xl py-6">
      <PageTitle>{t("cart.title")}</PageTitle>
      {!rows.length ? (
        <div className="rounded-xl border border-dashed border-border p-10 text-center text-sm text-muted"><ShoppingCart className="mx-auto mb-2" />{t("cart.empty")}<div className="mt-4"><LinkButton href="/recherche">{t("cart.browse")}</LinkButton></div></div>
      ) : (
        <>
          <ul className="space-y-3">
            {rows.map((r) => (
              <li key={r.listings.id}>
                <Card className="flex flex-wrap items-center justify-between gap-3 p-4">
                  <div className="min-w-0">
                    <Link href={`/annonces/${r.listings.slug}`} className="font-semibold hover:underline">{r.listings.title}</Link>
                    <p className="text-sm text-muted">{r.listings.profiles?.display_name} · {formatPrice(r.listings.price, r.listings.currency_code, lang)}</p>
                    {(r.listings.status !== "active" || r.quantity > r.listings.quantity) && <p className="text-sm text-red-600">{t("err.listing_unavailable")}</p>}
                  </div>
                  <div className="flex items-center gap-4">
                    <CartItemControls listingId={r.listings.id} quantity={r.quantity} max={r.listings.quantity} />
                    <p className="w-28 text-right font-bold">{formatPrice(r.listings.price * r.quantity, r.listings.currency_code, lang)}</p>
                  </div>
                </Card>
              </li>
            ))}
          </ul>
          <Card className="mt-4 p-4">
            {[...totals.entries()].map(([cur, amount]) => (
              <p key={cur} className="flex justify-between text-lg font-bold"><span>{t("cart.subtotal")} ({cur})</span><span>{formatPrice(amount, cur, lang)}</span></p>
            ))}
            {totals.size > 1 && <p className="mt-1 text-xs text-muted">{t("cart.multi_currency")}</p>}
            <p className="mt-2 text-xs text-muted">{t("cart.shipping_note")}</p>
            <LinkButton href="/commande" size="lg" className={`mt-4 w-full ${unavailable ? "pointer-events-none opacity-50" : ""}`} aria-disabled={unavailable}>{t("cart.checkout")}</LinkButton>
          </Card>
        </>
      )}
    </Container>
  );
}
