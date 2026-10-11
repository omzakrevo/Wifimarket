import Link from "next/link";
import { requireUser } from "@/lib/auth";
import { getT } from "@/lib/i18n";
import { Container } from "@/components/ui/card";
import { AccountNav } from "@/components/account-nav";

export default async function AccountLayout({ children }: { children: React.ReactNode }) {
  await requireUser("/compte");
  const { t } = await getT();
  const items = [
    { href: "/compte", label: t("account.overview") },
    { href: "/compte/annonces", label: t("account.my_listings") },
    { href: "/compte/favoris", label: t("account.favorites") },
    { href: "/compte/recherches", label: t("account.searches") },
    { href: "/compte/negociations", label: t("account.negotiations") },
    { href: "/compte/commandes", label: t("account.orders") },
    { href: "/compte/demandes", label: t("account.my_wanted") },
    { href: "/compte/boutique", label: t("account.shop") },
    { href: "/compte/notifications", label: t("nav.notifications") },
    { href: "/compte/profil", label: t("account.profile") },
  ];
  return (
    <Container className="py-6">
      <AccountNav items={items} />
      {children}
      <p className="mt-10 text-xs text-muted"><Link href="/aide/securite" className="underline">{t("footer.safety")}</Link></p>
    </Container>
  );
}
