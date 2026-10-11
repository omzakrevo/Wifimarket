import { Container } from "@/components/ui/card";
import { LinkButton } from "@/components/ui/button";
import { getT } from "@/lib/i18n";

export default async function NotFound() {
  const { t } = await getT();
  return (
    <Container className="max-w-md py-20 text-center">
      <p className="text-5xl font-extrabold text-brand">404</p>
      <h1 className="mt-2 text-2xl font-bold">{t("error.not_found")}</h1>
      <p className="mt-2 text-sm text-muted">{t("error.not_found_body")}</p>
      <LinkButton href="/" className="mt-6">{t("nav.home")}</LinkButton>
    </Container>
  );
}
