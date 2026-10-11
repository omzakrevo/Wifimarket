import type { Metadata } from "next";
import Link from "next/link";
import { HandHelping, MapPin } from "lucide-react";
import { Badge, Container, PageTitle } from "@/components/ui/card";
import { LinkButton } from "@/components/ui/button";
import { Input, Select } from "@/components/ui/form";
import { getCountries } from "@/lib/data";
import { getT } from "@/lib/i18n";
import { createClient } from "@/lib/supabase/server";
import { formatPrice, sanitizeSearch, timeAgo } from "@/lib/utils";
import type { MessageKey } from "@/lib/i18n/messages";

export const metadata: Metadata = {
  title: "Demandes de matériel — Je recherche",
  description: "Parcourez les demandes d'acheteurs en Afrique de l'Ouest et proposez votre matériel Wi-Fi, radio ou réseau.",
  alternates: { canonical: "/demandes" },
};

export default async function WantedPage({ searchParams }: { searchParams: Promise<{ q?: string; country?: string }> }) {
  const sp = await searchParams;
  const { t, lang } = await getT();
  const supabase = await createClient();
  const countries = await getCountries();
  let q = supabase.from("wanted_requests").select("id,title,budget,currency_code,condition_wanted,country_code,city,created_at,status, wanted_offers(count)").eq("status", "open").order("created_at", { ascending: false }).limit(48);
  const term = sp.q ? sanitizeSearch(sp.q) : "";
  if (term) q = q.or(`title.ilike.%${term}%,model_text.ilike.%${term}%,description.ilike.%${term}%`);
  if (sp.country && /^[A-Z]{2}$/.test(sp.country)) q = q.eq("country_code", sp.country);
  const { data } = await q;
  return (
    <Container className="py-6">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <PageTitle sub={t("wanted.sub")}>{t("nav.wanted")}</PageTitle>
        <LinkButton href="/demandes/nouvelle" variant="promo"><HandHelping size={16} />{t("home.post_wanted")}</LinkButton>
      </div>
      <form className="mb-5 flex flex-wrap gap-2" role="search">
        <Input name="q" defaultValue={sp.q} placeholder={t("common.search")} aria-label={t("common.search")} className="min-w-48 flex-1" />
        <Select name="country" defaultValue={sp.country ?? ""} aria-label={t("common.country")} className="w-48"><option value="">{t("common.all")}</option>{countries.map((c) => <option key={c.code} value={c.code}>{lang === "en" ? c.name_en : c.name_fr}</option>)}</Select>
        <button className="h-10 rounded-lg bg-brand px-4 text-sm font-semibold text-white dark:text-slate-950">{t("common.search")}</button>
      </form>
      {!data?.length ? <p className="text-sm text-muted">{t("wanted.none")}</p> : (
        <ul className="grid gap-3 sm:grid-cols-2">
          {data.map((w) => {
            const offers = (w.wanted_offers as unknown as { count: number }[])?.[0]?.count ?? 0;
            return (
              <li key={w.id}>
                <Link href={`/demandes/${w.id}`} className="block rounded-xl border border-border bg-card p-4 shadow-sm hover:border-brand">
                  <p className="font-semibold">{w.title}</p>
                  <p className="mt-1 flex items-center gap-1 text-sm text-muted"><MapPin size={13} />{[w.city, w.country_code].filter(Boolean).join(", ")} · {timeAgo(w.created_at, lang)}</p>
                  <div className="mt-2 flex flex-wrap items-center gap-2 text-sm">
                    {w.budget != null && w.currency_code && <Badge tone="promo">{t("wanted.budget")} {formatPrice(w.budget, w.currency_code, lang)}</Badge>}
                    {w.condition_wanted && w.condition_wanted !== "any" && <Badge>{t(`cond.${w.condition_wanted}` as MessageKey)}</Badge>}
                    <span className="text-muted">{t("wanted.offers_count", { n: offers })}</span>
                  </div>
                </Link>
              </li>
            );
          })}
        </ul>
      )}
    </Container>
  );
}
