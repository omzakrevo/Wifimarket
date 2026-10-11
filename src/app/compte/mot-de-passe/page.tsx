import type { Metadata } from "next";
import { AuthShell } from "@/components/auth-shell";
import { NewPasswordForm } from "@/components/auth-forms";
import { getT } from "@/lib/i18n";

export const metadata: Metadata = { title: "Nouveau mot de passe", robots: { index: false } };

export default async function NewPasswordPage() {
  const { t } = await getT();
  return <AuthShell title={t("auth.new_password")}><NewPasswordForm /></AuthShell>;
}
