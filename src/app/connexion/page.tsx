import Link from "next/link";
import type { Metadata } from "next";
import { redirect } from "next/navigation";
import { AuthShell } from "@/components/auth-shell";
import { LoginForm, PhoneForm } from "@/components/auth-forms";
import { Button } from "@/components/ui/button";
import { signInWithGoogle } from "@/app/actions/auth";
import { getUser } from "@/lib/auth";
import { getT } from "@/lib/i18n";
import { safeNext } from "@/lib/safe-redirect";
import type { MessageKey } from "@/lib/i18n/messages";

export const metadata: Metadata = { title: "Connexion", robots: { index: false } };

export default async function LoginPage({ searchParams }: { searchParams: Promise<{ next?: string; error?: string }> }) {
  const sp = await searchParams;
  const next = safeNext(sp.next);
  if (await getUser()) redirect(next);
  const { t } = await getT();
  const google = process.env.NEXT_PUBLIC_AUTH_GOOGLE_ENABLED === "true";
  const phone = process.env.NEXT_PUBLIC_AUTH_PHONE_ENABLED === "true";
  return (
    <AuthShell title={t("auth.login")} footer={<>{t("auth.no_account")} <Link href={`/inscription?next=${encodeURIComponent(next)}`} className="font-semibold text-brand hover:underline">{t("auth.signup")}</Link></>}>
      {sp.error?.startsWith("auth.err.") && <p role="alert" className="mb-4 rounded-lg bg-red-50 p-3 text-sm text-red-700 dark:bg-red-950/40 dark:text-red-200">{t(sp.error as MessageKey)}</p>}
      <LoginForm next={next} />
      {google && (
        <form action={signInWithGoogle} className="mt-4">
          <input type="hidden" name="next" value={next} />
          <Button type="submit" variant="outline" className="w-full">{t("auth.google")}</Button>
        </form>
      )}
      {phone && (
        <details className="mt-6 border-t border-border pt-4">
          <summary className="cursor-pointer text-sm font-semibold">{t("auth.phone_login")}</summary>
          <div className="mt-4"><PhoneForm next={next} /></div>
        </details>
      )}
    </AuthShell>
  );
}
