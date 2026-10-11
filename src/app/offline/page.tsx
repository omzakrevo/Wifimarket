import type { Metadata } from "next";
import { WifiOff } from "lucide-react";
import { Container } from "@/components/ui/card";
import { getT } from "@/lib/i18n";

export const metadata: Metadata = { title: "Hors connexion", robots: { index: false } };

export default async function OfflinePage() {
  const { t } = await getT();
  return (
    <Container className="max-w-md py-20 text-center">
      <WifiOff className="mx-auto mb-4 text-brand" size={48} />
      <h1 className="text-2xl font-bold">{t("offline.title")}</h1>
      <p className="mt-2 text-sm text-muted">{t("offline.body")}</p>
    </Container>
  );
}
