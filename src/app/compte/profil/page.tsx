import type { Metadata } from "next";
import { Card, PageTitle } from "@/components/ui/card";
import { DeletionForm, ProfileForm } from "@/components/profile-forms";
import { getProfile } from "@/lib/auth";
import { getCountries } from "@/lib/data";
import { getT } from "@/lib/i18n";
import { createClient } from "@/lib/supabase/server";
import { Button } from "@/components/ui/button";
import Link from "next/link";

export const metadata: Metadata = { title: "Mon profil", robots: { index: false } };

export default async function ProfilePage() {
  const { t } = await getT();
  const [profile, countries] = await Promise.all([getProfile(), getCountries()]);
  const supabase = await createClient();
  const { data: priv } = await supabase.from("private_profiles").select("whatsapp_number").eq("id", profile!.id).maybeSingle();
  const { data: pending } = await supabase.from("data_deletion_requests").select("id").eq("status", "pending").maybeSingle();
  return (
    <div className="max-w-xl space-y-8">
      <div>
        <PageTitle>{t("account.profile")}</PageTitle>
        <ProfileForm profile={profile!} whatsapp={priv?.whatsapp_number ?? null} countries={countries} />
      </div>
      <Card className="p-4">
        <h2 className="mb-2 font-bold">{t("profile.security")}</h2>
        <Link href="/compte/mot-de-passe"><Button variant="outline" size="sm">{t("auth.new_password")}</Button></Link>
      </Card>
      <Card className="border-red-200 p-4">
        <h2 className="mb-1 font-bold">{t("profile.privacy")}</h2>
        <p className="mb-3 text-sm text-muted">{t("profile.deletion_info")}</p>
        {pending ? <p className="text-sm text-amber-700">{t("profile.deletion_pending")}</p> : <DeletionForm />}
      </Card>
    </div>
  );
}
