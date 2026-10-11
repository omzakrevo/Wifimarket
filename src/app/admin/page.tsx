import Link from "next/link";
import { Card, PageTitle } from "@/components/ui/card";
import { getT } from "@/lib/i18n";
import { createClient } from "@/lib/supabase/server";
import { formatPrice } from "@/lib/utils";

type Stats = {
  users: number; shops: number; listings: Record<string, number>; orders: Record<string, number>;
  sales_by_currency: Record<string, number>; commission_by_currency: Record<string, number>;
  open_reports: number; open_disputes: number; pending_listings: number; pending_shops: number; pending_deletions: number;
};

export default async function AdminDashboard() {
  const { t, lang } = await getT();
  const supabase = await createClient();
  const { data } = await supabase.rpc("admin_stats");
  const s = data as Stats | null;
  if (!s) return <p>{t("err.not_allowed")}</p>;
  const sum = (o: Record<string, number>) => Object.values(o).reduce((a, b) => a + Number(b), 0);
  const tiles: [string, number, string?][] = [
    [t("admin.users"), s.users], [t("nav.shops"), s.shops], [t("admin.listings_active"), s.listings.active ?? 0],
    [t("admin.pending_listings"), s.pending_listings, "/admin/annonces?status=pending_review"], [t("admin.open_reports"), s.open_reports, "/admin/signalements"],
    [t("admin.open_disputes"), s.open_disputes, "/admin/commandes"], [t("admin.pending_shops"), s.pending_shops, "/admin/boutiques"],
    [t("admin.orders"), sum(s.orders)], [t("admin.deletions"), s.pending_deletions, "/admin/suppressions"],
  ];
  return (
    <>
      <PageTitle>{t("admin.dashboard")}</PageTitle>
      <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-5">
        {tiles.map(([label, n, href]) => {
          const card = <Card className={`h-full p-4 ${href && n > 0 ? "border-promo" : ""}`}><p className="text-3xl font-extrabold">{n}</p><p className="text-sm text-muted">{label}</p></Card>;
          return href ? <Link key={label} href={href}>{card}</Link> : <div key={label}>{card}</div>;
        })}
      </div>
      <div className="mt-6 grid gap-4 md:grid-cols-2">
        <Card className="p-4">
          <h2 className="mb-2 font-bold">{t("admin.sales")}</h2>
          {Object.keys(s.sales_by_currency).length ? Object.entries(s.sales_by_currency).map(([c, v]) => <p key={c} className="flex justify-between text-sm"><span>{c}</span><strong>{formatPrice(v, c, lang)}</strong></p>) : <p className="text-sm text-muted">—</p>}
          <p className="mt-2 text-xs text-muted">{t("admin.no_conversion")}</p>
        </Card>
        <Card className="p-4">
          <h2 className="mb-2 font-bold">{t("admin.commissions")}</h2>
          {Object.keys(s.commission_by_currency).length ? Object.entries(s.commission_by_currency).map(([c, v]) => <p key={c} className="flex justify-between text-sm"><span>{c}</span><strong>{formatPrice(v, c, lang)}</strong></p>) : <p className="text-sm text-muted">—</p>}
        </Card>
        <Card className="p-4">
          <h2 className="mb-2 font-bold">{t("admin.listings")}</h2>
          {Object.entries(s.listings).map(([k, v]) => <p key={k} className="flex justify-between text-sm"><span>{k}</span><strong>{v}</strong></p>)}
        </Card>
        <Card className="p-4">
          <h2 className="mb-2 font-bold">{t("admin.orders")}</h2>
          {Object.keys(s.orders).length ? Object.entries(s.orders).map(([k, v]) => <p key={k} className="flex justify-between text-sm"><span>{k}</span><strong>{v}</strong></p>) : <p className="text-sm text-muted">—</p>}
        </Card>
      </div>
    </>
  );
}
