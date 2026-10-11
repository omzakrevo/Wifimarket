import type { Metadata } from "next";
import Link from "next/link";
import { BadgeCheck, Store } from "lucide-react";
import { Container, PageTitle } from "@/components/ui/card";
import { getT } from "@/lib/i18n";
import { createClient } from "@/lib/supabase/server";
import { publicStorageUrl } from "@/lib/utils";

export const metadata: Metadata = {
  title: "Boutiques professionnelles de matériel réseau",
  description: "Découvrez les boutiques et revendeurs professionnels de matériel Wi-Fi, radio et réseau en Afrique de l'Ouest.",
  alternates: { canonical: "/boutiques" },
};

export default async function ShopsPage() {
  const { t } = await getT();
  const supabase = await createClient();
  const { data } = await supabase.from("shops").select("id,slug,name,description,logo_url,country_code,city,plan,verification_status").eq("is_active", true).order("plan", { ascending: false }).order("name").limit(60);
  return (
    <Container className="py-6">
      <PageTitle sub={t("shop.sub")}>{t("nav.shops")}</PageTitle>
      {!data?.length ? <p className="text-sm text-muted">{t("shop.none")}</p> : (
        <ul className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
          {data.map((s) => (
            <li key={s.id}>
              <Link href={`/boutiques/${s.slug}`} className="flex h-full gap-3 rounded-xl border border-border bg-card p-4 shadow-sm hover:border-brand">
                <span className="flex h-14 w-14 shrink-0 items-center justify-center overflow-hidden rounded-lg bg-brand-soft text-brand">
                  {s.logo_url ? <img src={publicStorageUrl("shop-assets", s.logo_url)} alt="" className="h-full w-full object-cover" /> : <Store />}
                </span>
                <span className="min-w-0">
                  <span className="flex items-center gap-1 font-semibold">{s.name}{s.verification_status === "verified" && <BadgeCheck size={16} className="text-brand" />}</span>
                  <span className="block text-xs text-muted">{[s.city, s.country_code].filter(Boolean).join(", ")}</span>
                  {s.description && <span className="mt-1 line-clamp-2 block text-sm text-muted">{s.description}</span>}
                </span>
              </Link>
            </li>
          ))}
        </ul>
      )}
    </Container>
  );
}
