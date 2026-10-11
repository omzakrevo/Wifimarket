import type { Metadata } from "next";
import { AuthShell } from "@/components/auth-shell";
import { ResetRequestForm } from "@/components/auth-forms";
import { getT } from "@/lib/i18n";

export const metadata: Metadata = { title: "Mot de passe oublié", robots: { index: false } };

export default async function ForgotPage() {
  const { t } = await getT();
  return <AuthShell title={t("auth.forgot")}><ResetRequestForm /></AuthShell>;
}
