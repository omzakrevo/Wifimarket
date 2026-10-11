import type { Metadata } from "next";
import Link from "next/link";
import { Badge, Card, PageTitle } from "@/components/ui/card";
import { ShopForm, ShopImages, ShopPlanActions } from "@/components/shop-forms";
import { getProfile, getUser } from "@/lib/auth";
import { getCountries } from "@/lib/data";
import { getT } from "@/lib/i18n";
import { createClient } from "@/lib/supabase/server";
import { formatPrice } from "@/lib/utils";
import type { MessageKey } from "@/lib/i18n/messages";

export const metadata: Metadata = { title: "Ma boutique", robots: { index: false } };

export default async function MyShopPage() {
  const { t, lang } = await getT();
  const user = (await getUser())!;
  const supabase = await createClient();
  const [countries, profile, { data: members }] = await Promise.all([
    getCountries(), getProfile(),
    supabase.from("shop_members").select("shops(*)").eq("user_id", user.id),
  ]);
  const shops = ((members ?? []) as unknown as { shops: Record<string, unknown> | null }[]).map((m) => m.shops).filter(Boolean) as unknown as {
    id: string; slug: string; name: string; description: string | null; country_code: string | null; city: string | null; logo_url: string | null; banner_url: string | null; plan: string; verification_status: string;
  }[];
  const defaults = { country: profile?.country_code ?? "BF", city: profile?.city ?? "" };
  if (!shops.length) {
    return (
      <div className="max-w-xl">
        <PageTitle sub={t("shop.create_sub")}>{t("shop.create")}</PageTitle>
        <ShopForm countries={countries} defaults={defaults} />
      </div>
    );
  }
  const { data: planRows } = await supabase.from("plans").select("code,name,price,currency_code,duration_days").eq("kind", "shop_subscription").eq("enabled", true);
  const plans = (planRows ?? []).map((p) => ({ code: p.code, name: p.name, duration_days: p.duration_days, price_label: formatPrice(p.price, p.currency_code, lang) }));
  return (
    <div className="space-y-8">
      {await Promise.all(shops.map(async (s) => {
        const { data: stats } = await supabase.rpc("shop_stats", { p_shop: s.id });
        const st = (stats ?? {}) as Record<string, number | null>;
        const { data: subs } = await supabase.from("subscriptions").select("id,plan_code,status,ends_at").eq("shop_id", s.id).order("created_at", { ascending: false }).limit(3);
        return (
          <section key={s.id} className="space-y-4">
            <div className="flex flex-wrap items-center justify-between gap-2">
              <h2 className="text-xl font-bold">{s.name}</h2>
              <div className="flex gap-2"><Badge tone="navy">{t(`plan.${s.plan}` as MessageKey)}</Badge><Link href={`/boutiques/${s.slug}`} className="text-sm text-brand hover:underline">{t("shop.view_public")}</Link></div>
            </div>
            <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
              {([["listings_active", t("shop.stat_listings")], ["views_total", t("shop.stat_views")], ["favorites_total", t("shop.stat_favorites")], ["orders_total", t("shop.stat_orders")]] as const).map(([k, label]) => (
                <Card key={k} className="p-3"><p className="text-2xl font-extrabold">{st[k] ?? 0}</p><p className="text-xs text-muted">{label}</p></Card>
              ))}
              <Card className="p-3"><p className="text-2xl font-extrabold">{st.rating_avg ?? "—"}</p><p className="text-xs text-muted">{t("shop.stat_rating", { n: st.rating_count ?? 0 })}</p></Card>
            </div>
            <ShopImages shop={s} />
            <ShopForm shop={s} countries={countries} defaults={defaults} />
            <ShopPlanActions shopId={s.id} plans={plans} verification={s.verification_status} />
            {subs && subs.length > 0 && <ul className="text-sm text-muted">{subs.map((x) => <li key={x.id}>{x.plan_code} — {x.status}{x.ends_at ? ` (${new Date(x.ends_at).toLocaleDateString()})` : ""}</li>)}</ul>}
            <p className="text-sm"><Link href={`/recherche?shop=${s.id}`} className="text-brand hover:underline">{t("shop.manage_listings")}</Link> · <Link href="/vendre" className="text-brand hover:underline">{t("nav.sell")}</Link></p>
          </section>
        );
      }))}
    </div>
  );
}
