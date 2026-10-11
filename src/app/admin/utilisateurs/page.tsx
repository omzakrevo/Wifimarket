import { BadgeCheck } from "lucide-react";
import { Badge, Card, PageTitle } from "@/components/ui/card";
import { Input, Select } from "@/components/ui/form";
import { Button } from "@/components/ui/button";
import { ActionButton } from "@/components/action-button";
import { grantRole, revokeRole, setSuspended, setVerification } from "@/app/actions/admin";
import { getRoles, isSuperadminRole } from "@/lib/auth";
import { getCountries } from "@/lib/data";
import { getT } from "@/lib/i18n";
import { createClient } from "@/lib/supabase/server";
import { sanitizeSearch, timeAgo } from "@/lib/utils";
import type { MessageKey } from "@/lib/i18n/messages";

export default async function AdminUsers({ searchParams }: { searchParams: Promise<{ q?: string; status?: string }> }) {
  const sp = await searchParams;
  const { t, lang } = await getT();
  const roles = await getRoles();
  const superadmin = isSuperadminRole(roles);
  const supabase = await createClient();
  const countries = await getCountries();
  let q = supabase.from("profiles").select("id,display_name,country_code,city,verification_status,is_suspended,created_at,is_demo").order("created_at", { ascending: false }).limit(60);
  if (sp.q) q = q.ilike("display_name", `%${sanitizeSearch(sp.q)}%`);
  if (sp.status === "pending") q = q.eq("verification_status", "pending");
  const { data: users } = await q;
  const ids = (users ?? []).map((u) => u.id);
  const { data: roleRows } = superadmin && ids.length ? await supabase.from("user_roles").select("id,user_id,role,country_code").in("user_id", ids) : { data: [] };
  return (
    <>
      <PageTitle>{t("admin.users")}</PageTitle>
      <form className="mb-4 flex flex-wrap gap-2"><Input name="q" defaultValue={sp.q} placeholder={t("common.search")} className="w-64" aria-label={t("common.search")} />
        <Select name="status" defaultValue={sp.status ?? ""} className="w-56" aria-label="Filtre"><option value="">{t("common.all")}</option><option value="pending">{t("verif.pending")}</option></Select>
        <button className="h-10 rounded-lg bg-brand px-4 text-sm font-semibold text-white dark:text-slate-950">{t("common.apply")}</button></form>
      <ul className="space-y-2">
        {(users ?? []).map((u) => {
          const userRoles = (roleRows ?? []).filter((r) => r.user_id === u.id);
          return (
            <li key={u.id}><Card className="p-3">
              <div className="flex flex-wrap items-start justify-between gap-2">
                <div>
                  <p className="flex items-center gap-1 font-semibold">{u.display_name}{u.verification_status === "verified" && <BadgeCheck size={14} className="text-brand" />}{u.is_demo && <Badge>DEMO</Badge>}</p>
                  <p className="text-sm text-muted">{[u.city, u.country_code].filter(Boolean).join(", ")} · {timeAgo(u.created_at, lang)} · <span className="font-mono text-xs">{u.id.slice(0, 8)}</span></p>
                </div>
                <div className="flex gap-1"><Badge tone={u.verification_status === "verified" ? "success" : u.verification_status === "pending" ? "warn" : "default"}>{t(`verif.${u.verification_status}` as MessageKey)}</Badge>{u.is_suspended && <Badge tone="danger">{t("admin.suspended")}</Badge>}</div>
              </div>
              <div className="mt-2 flex flex-wrap gap-2">
                {u.verification_status !== "verified" && <ActionButton action={setVerification.bind(null, "profile", u.id, "verified")}>{t("admin.verify")}</ActionButton>}
                {u.verification_status === "pending" && <ActionButton variant="outline" action={setVerification.bind(null, "profile", u.id, "rejected")}>{t("admin.reject")}</ActionButton>}
                {u.verification_status === "verified" && <ActionButton variant="outline" action={setVerification.bind(null, "profile", u.id, "unverified")}>{t("admin.unverify")}</ActionButton>}
                <ActionButton variant={u.is_suspended ? "outline" : "danger"} confirm={u.is_suspended ? undefined : t("admin.confirm_suspend")} action={setSuspended.bind(null, u.id, !u.is_suspended)}>{u.is_suspended ? t("admin.reinstate") : t("admin.suspend")}</ActionButton>
              </div>
              {superadmin && (
                <div className="mt-3 border-t border-border pt-2">
                  <div className="flex flex-wrap gap-1">{userRoles.map((r) => <span key={r.id} className="inline-flex items-center gap-1 rounded-full bg-navy px-2 py-0.5 text-xs text-white">{t(`role.${r.role}` as MessageKey)}{r.country_code ? ` · ${r.country_code}` : ""}<ActionButton size="sm" variant="ghost" className="h-5 px-1 text-white" confirm={t("admin.confirm_revoke")} action={revokeRole.bind(null, r.id)}>×</ActionButton></span>)}</div>
                  <form action={grantRole} className="mt-2 flex flex-wrap items-center gap-2">
                    <input type="hidden" name="user_id" value={u.id} />
                    <Select name="role" className="h-8 w-44 text-xs" aria-label="Rôle" defaultValue="moderator">
                      {(["moderator", "country_admin", "superadmin", "shop_manager"] as const).map((r) => <option key={r} value={r}>{t(`role.${r}` as MessageKey)}</option>)}
                    </Select>
                    <Select name="country_code" className="h-8 w-40 text-xs" aria-label={t("common.country")} defaultValue=""><option value="">{t("admin.all_countries")}</option>{countries.map((c) => <option key={c.code} value={c.code}>{lang === "en" ? c.name_en : c.name_fr}</option>)}</Select>
                    <Button size="sm" variant="outline" type="submit">{t("admin.grant_role")}</Button>
                  </form>
                </div>
              )}
            </Card></li>
          );
        })}
      </ul>
    </>
  );
}
