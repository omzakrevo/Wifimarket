import type { Metadata } from "next";
import { Container } from "@/components/ui/card";
import { AccountNav } from "@/components/account-nav";
import { isAdminRole, isSuperadminRole, requireStaff } from "@/lib/auth";
import { getT } from "@/lib/i18n";

export const metadata: Metadata = { title: "Administration", robots: { index: false, follow: false } };

export default async function AdminLayout({ children }: { children: React.ReactNode }) {
  const roles = await requireStaff();
  const { t } = await getT();
  const admin = isAdminRole(roles);
  const items = [
    { href: "/admin", label: t("admin.dashboard") },
    { href: "/admin/annonces", label: t("admin.listings") },
    { href: "/admin/signalements", label: t("admin.reports") },
    { href: "/admin/utilisateurs", label: t("admin.users") },
    { href: "/admin/boutiques", label: t("nav.shops") },
    ...(admin ? [
      { href: "/admin/commandes", label: t("admin.orders") },
      { href: "/admin/promotions", label: t("admin.promotions") },
      { href: "/admin/catalogue", label: t("admin.catalog") },
      { href: "/admin/pays", label: t("admin.countries") },
      { href: "/admin/parametres", label: t("admin.settings") },
      { href: "/admin/audit", label: t("admin.audit") },
    ] : []),
    ...(isSuperadminRole(roles) ? [{ href: "/admin/suppressions", label: t("admin.deletions") }] : []),
  ];
  return (
    <Container className="max-w-6xl py-6">
      <h1 className="mb-3 text-sm font-semibold uppercase tracking-wide text-muted">{t("admin.title")}</h1>
      <AccountNav items={items} />
      {children}
    </Container>
  );
}
