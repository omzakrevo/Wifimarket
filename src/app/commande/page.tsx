import type { Metadata } from "next";
import { redirect } from "next/navigation";
import { Card, Container, PageTitle } from "@/components/ui/card";
import { CheckoutForm } from "@/components/checkout-form";
import { getProfile, requireUser } from "@/lib/auth";
import { getCountries } from "@/lib/data";
import { getT } from "@/lib/i18n";
import { createClient } from "@/lib/supabase/server";
import { formatPrice } from "@/lib/utils";

export const metadata: Metadata = { title: "Commande", robots: { index: false } };

export default async function CheckoutPage() {
  const user = await requireUser("/commande");
  const { t, lang } = await getT();
  const supabase = await createClient();
  const [{ data }, countries, profile] = await Promise.all([
    supabase.from("cart_items").select("quantity, listings(title,price,currency_code,delivery_available)").eq("user_id", user.id),
    getCountries(), getProfile(),
  ]);
  const rows = (data ?? []) as unknown as { quantity: number; listings: { title: string; price: number; currency_code: string; delivery_available: boolean } }[];
  if (!rows.length) redirect("/panier");
  const totals = new Map<string, number>();
  for (const r of rows) totals.set(r.listings.currency_code, (totals.get(r.listings.currency_code) ?? 0) + r.listings.price * r.quantity);
  return (
    <Container className="max-w-2xl py-6">
      <PageTitle>{t("checkout.title")}</PageTitle>
      <Card className="mb-5 p-4">
        <h2 className="mb-2 font-bold">{t("checkout.summary")}</h2>
        <ul className="space-y-1 text-sm">{rows.map((r, i) => <li key={i} className="flex justify-between gap-3"><span className="truncate">{r.quantity} × {r.listings.title}</span><span>{formatPrice(r.listings.price * r.quantity, r.listings.currency_code, lang)}</span></li>)}</ul>
        {[...totals.entries()].map(([c, a]) => <p key={c} className="mt-2 flex justify-between border-t border-border pt-2 font-bold"><span>{t("cart.subtotal")}</span><span>{formatPrice(a, c, lang)}</span></p>)}
        <p className="mt-2 text-xs text-muted">{t("cart.shipping_note")}</p>
      </Card>
      <CheckoutForm countries={countries} defaults={{ country: profile?.country_code ?? "BF", city: profile?.city ?? "", name: profile?.display_name ?? "" }} allDeliverable={rows.every((r) => r.listings.delivery_available)} />
    </Container>
  );
}
