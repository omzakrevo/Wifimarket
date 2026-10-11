import type { Metadata } from "next";
import { Container, PageTitle } from "@/components/ui/card";
import { WantedForm } from "@/components/wanted-forms";
import { getProfile, requireUser } from "@/lib/auth";
import { getBrands, getCategories, getCities, getCountries, getCurrencies } from "@/lib/data";
import { getT } from "@/lib/i18n";

export const metadata: Metadata = { title: "Publier une demande", robots: { index: false } };

export default async function NewWantedPage() {
  await requireUser("/demandes/nouvelle");
  const { t } = await getT();
  const [categories, brands, countries, cities, currencies, profile] = await Promise.all([getCategories(), getBrands(), getCountries(), getCities(), getCurrencies(), getProfile()]);
  return (
    <Container className="max-w-2xl py-6">
      <PageTitle sub={t("wanted.new_sub")}>{t("home.post_wanted")}</PageTitle>
      <WantedForm categories={categories} brands={brands} countries={countries} cities={cities} currencies={currencies} defaults={{ country: profile?.country_code ?? "BF", city: profile?.city ?? "" }} />
    </Container>
  );
}
