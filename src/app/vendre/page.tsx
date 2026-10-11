import type { Metadata } from "next";
import { Container, PageTitle } from "@/components/ui/card";
import { ListingForm } from "@/components/listing-form";
import { requireUser } from "@/lib/auth";
import { getT } from "@/lib/i18n";
import { getListingFormData } from "@/lib/listing-form-data";

export const metadata: Metadata = { title: "Vendre un matériel", robots: { index: false } };

export default async function SellPage() {
  const user = await requireUser("/vendre");
  const { t } = await getT();
  const data = await getListingFormData(user.id);
  return (
    <Container className="max-w-2xl py-6">
      <PageTitle sub={t("form.sell_sub")}>{t("nav.sell")}</PageTitle>
      <ListingForm uid={user.id} {...data} />
    </Container>
  );
}
