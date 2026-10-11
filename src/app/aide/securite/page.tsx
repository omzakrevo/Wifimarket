import type { Metadata } from "next";
import { Container } from "@/components/ui/card";
import { LEGAL } from "@/lib/legal-content";
import { getLang } from "@/lib/i18n";

export const metadata: Metadata = { title: "Conseils de sécurité", alternates: { canonical: "/aide/securite" } };

export default async function SafetyPage() {
  const page = LEGAL.securite;
  const i = (await getLang()) === "en" ? 1 : 0;
  return (
    <Container className="max-w-3xl py-8">
      <h1 className="mb-6 text-2xl font-bold text-navy dark:text-foreground">{page.title[i]}</h1>
      {page.sections.map((s) => (<section key={s.h[0]} className="mb-5"><h2 className="mb-1 text-lg font-bold">{s.h[i]}</h2><p className="text-sm leading-6">{s.p[i]}</p></section>))}
    </Container>
  );
}
