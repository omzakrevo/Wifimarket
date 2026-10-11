import type { Metadata } from "next";
import Link from "next/link";
import { BadgeCheck, Heart, Layers, MessageCircle, ShoppingBag, Store } from "lucide-react";
import { Card, PageTitle } from "@/components/ui/card";
import { LinkButton } from "@/components/ui/button";
import { getProfile, getRoles, isAdminRole } from "@/lib/auth";
import { getT } from "@/lib/i18n";
import { createClient } from "@/lib/supabase/server";
import { signOut } from "@/app/actions/auth";
import { Button } from "@/components/ui/button";

export const metadata: Metadata = { title: "Mon compte", robots: { index: false } };

export default async function AccountPage() {
  const { t } = await getT();
  const [profile, roles] = await Promise.all([getProfile(), getRoles()]);
  const supabase = await createClient();
  const [active, drafts, favs, convs, orders] = await Promise.all([
    supabase.from("listings").select("id", { count: "exact", head: true }).eq("status", "active").eq("seller_id", profile?.id ?? ""),
    supabase.from("listings").select("id", { count: "exact", head: true }).in("status", ["draft", "pending_review"]).eq("seller_id", profile?.id ?? ""),
    supabase.from("favorites").select("listing_id", { count: "exact", head: true }),
    supabase.from("conversations").select("id", { count: "exact", head: true }),
    supabase.from("orders").select("id", { count: "exact", head: true }),
  ]);
  const tiles = [
    { href: "/compte/annonces", icon: Layers, label: t("account.my_listings"), value: `${active.count ?? 0} / ${drafts.count ?? 0}`, hint: t("account.active_drafts") },
    { href: "/compte/favoris", icon: Heart, label: t("account.favorites"), value: favs.count ?? 0 },
    { href: "/messages", icon: MessageCircle, label: t("nav.messages"), value: convs.count ?? 0 },
    { href: "/compte/commandes", icon: ShoppingBag, label: t("account.orders"), value: orders.count ?? 0 },
  ];
  return (
    <>
      <PageTitle sub={profile ? `${profile.display_name}` : undefined}>{t("account.hello", { name: profile?.display_name ?? "" })}</PageTitle>
      <div className="mb-4 flex flex-wrap items-center gap-2 text-sm">
        {profile?.verification_status === "verified"
          ? <span className="inline-flex items-center gap-1 text-brand"><BadgeCheck size={16} />{t("profile.verified")}</span>
          : <span className="text-muted">{t("profile.unverified")}</span>}
        {roles.length > 0 && roles.map((r) => <span key={r.role + r.country_code} className="rounded-full bg-navy px-2 py-0.5 text-xs text-white">{t(`role.${r.role}` as never)}{r.country_code ? ` · ${r.country_code}` : ""}</span>)}
      </div>
      <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
        {tiles.map(({ href, icon: Icon, label, value, hint }) => (
          <Link key={href} href={href}>
            <Card className="h-full p-4 transition hover:border-brand">
              <Icon className="text-brand" size={20} />
              <p className="mt-2 text-2xl font-extrabold">{value}</p>
              <p className="text-sm text-muted">{label}</p>
              {hint && <p className="text-xs text-muted">{hint}</p>}
            </Card>
          </Link>
        ))}
      </div>
      <div className="mt-6 flex flex-wrap gap-2">
        <LinkButton href="/vendre" variant="promo">{t("nav.sell")}</LinkButton>
        <LinkButton href="/demandes/nouvelle" variant="outline">{t("home.post_wanted")}</LinkButton>
        <LinkButton href="/compte/boutique" variant="outline"><Store size={16} />{t("account.shop")}</LinkButton>
        {roles.some((r) => ["moderator", "country_admin", "superadmin"].includes(r.role)) && <LinkButton href="/admin" variant="navy">{isAdminRole(roles) ? t("admin.title") : t("admin.moderation")}</LinkButton>}
        <form action={signOut}><Button type="submit" variant="ghost">{t("auth.logout")}</Button></form>
      </div>
    </>
  );
}
