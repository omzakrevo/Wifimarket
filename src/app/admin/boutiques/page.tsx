import Link from "next/link";
import { Badge, Card, PageTitle } from "@/components/ui/card";
import { ActionButton } from "@/components/action-button";
import { setShopActive, setVerification } from "@/app/actions/admin";
import { getT } from "@/lib/i18n";
import { createClient } from "@/lib/supabase/server";
import type { MessageKey } from "@/lib/i18n/messages";

export default async function AdminShops() {
  const { t } = await getT();
  const supabase = await createClient();
  const { data } = await supabase.from("shops").select("id,slug,name,plan,verification_status,is_active,country_code,city,is_demo").order("verification_status", { ascending: false }).order("created_at", { ascending: false }).limit(100);
  return (
    <>
      <PageTitle>{t("nav.shops")}</PageTitle>
      <ul className="space-y-2">
        {(data ?? []).map((s) => (
          <li key={s.id}><Card className="p-3">
            <div className="flex flex-wrap items-center justify-between gap-2">
              <div><Link href={`/boutiques/${s.slug}`} className="font-semibold hover:underline">{s.name}</Link><p className="text-sm text-muted">{[s.city, s.country_code].filter(Boolean).join(", ")}{s.is_demo ? " · DEMO" : ""}</p></div>
              <div className="flex gap-1"><Badge tone="navy">{t(`plan.${s.plan}` as MessageKey)}</Badge><Badge tone={s.verification_status === "verified" ? "success" : s.verification_status === "pending" ? "warn" : "default"}>{t(`verif.${s.verification_status}` as MessageKey)}</Badge>{!s.is_active && <Badge tone="danger">{t("admin.suspended")}</Badge>}</div>
            </div>
            <div className="mt-2 flex flex-wrap gap-2">
              {s.verification_status !== "verified" && <ActionButton action={setVerification.bind(null, "shop", s.id, "verified")}>{t("admin.verify")}</ActionButton>}
              {s.verification_status === "pending" && <ActionButton variant="outline" action={setVerification.bind(null, "shop", s.id, "rejected")}>{t("admin.reject")}</ActionButton>}
              {s.verification_status === "verified" && <ActionButton variant="outline" action={setVerification.bind(null, "shop", s.id, "unverified")}>{t("admin.unverify")}</ActionButton>}
              <ActionButton variant={s.is_active ? "danger" : "outline"} action={setShopActive.bind(null, s.id, !s.is_active)}>{s.is_active ? t("admin.suspend") : t("admin.reinstate")}</ActionButton>
            </div>
          </Card></li>
        ))}
      </ul>
    </>
  );
}
