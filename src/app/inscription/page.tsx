import Link from "next/link";
import type { Metadata } from "next";
import { redirect } from "next/navigation";
import { AuthShell } from "@/components/auth-shell";
import { SignupForm } from "@/components/auth-forms";
import { getUser } from "@/lib/auth";
import { getCountries } from "@/lib/data";
import { getT } from "@/lib/i18n";
import { safeNext } from "@/lib/safe-redirect";

export const metadata: Metadata = { title: "Inscription", robots: { index: false } };

export default async function SignupPage({ searchParams }: { searchParams: Promise<{ next?: string }> }) {
  const sp = await searchParams;
  const next = safeNext(sp.next);
  if (await getUser()) redirect(next);
  const [{ t }, countries] = await Promise.all([getT(), getCountries()]);
  return (
    <AuthShell title={t("auth.signup")} footer={<>{t("auth.have_account")} <Link href={`/connexion?next=${encodeURIComponent(next)}`} className="font-semibold text-brand hover:underline">{t("auth.login")}</Link></>}>
      <SignupForm next={next} countries={countries} />
    </AuthShell>
  );
}
