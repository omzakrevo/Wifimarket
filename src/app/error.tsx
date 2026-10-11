"use client";
import { Container } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { useT } from "@/lib/i18n/client";

export default function ErrorPage({ reset }: { error: Error & { digest?: string }; reset: () => void }) {
  const t = useT();
  return (
    <Container className="max-w-md py-20 text-center">
      <h1 className="text-2xl font-bold">{t("error.generic")}</h1>
      <p className="mt-2 text-sm text-muted">{t("error.generic_body")}</p>
      <Button className="mt-6" onClick={reset}>{t("error.retry")}</Button>
    </Container>
  );
}
