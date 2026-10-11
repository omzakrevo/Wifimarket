import { Badge, PageTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input, Select } from "@/components/ui/form";
import { ActionButton } from "@/components/action-button";
import { addKeyword, addShippingRule, deleteKeyword, deleteShippingRule, updatePlan, updateProvider, updateSetting } from "@/app/actions/admin";
import { getCountries, getCurrencies } from "@/lib/data";
import { getT } from "@/lib/i18n";
import { createClient } from "@/lib/supabase/server";

export default async function AdminSettings() {
  const { t } = await getT();
  const supabase = await createClient();
  const [countries, currencies, { data: settings }, { data: plans }, { data: rules }, { data: providers }, { data: keywords }] = await Promise.all([
    getCountries(), getCurrencies(),
    supabase.from("platform_settings").select("*").order("key"), supabase.from("plans").select("*").order("code"),
    supabase.from("shipping_rules").select("*").order("id"), supabase.from("payment_providers").select("*").order("code"),
    supabase.from("banned_keywords").select("*").order("keyword"),
  ]);
  return (
    <div className="space-y-10">
      <section>
        <PageTitle sub={t("admin.settings_sub")}>{t("admin.settings")}</PageTitle>
        <ul className="space-y-2">
          {(settings ?? []).map((s) => (
            <li key={s.key}><form action={updateSetting} className="flex flex-wrap items-center gap-2 rounded-xl border border-border bg-card p-3">
              <input type="hidden" name="key" value={s.key} />
              <div className="min-w-48 flex-1"><p className="font-mono text-sm font-semibold">{s.key}</p><p className="text-xs text-muted">{s.description}</p></div>
              <Input name="value" defaultValue={JSON.stringify(s.value)} className="w-32" aria-label={s.key} /><Button size="sm" type="submit">{t("common.save")}</Button>
            </form></li>
          ))}
        </ul>
      </section>
      <section>
        <PageTitle sub={t("admin.plans_sub")}>{t("admin.plans")}</PageTitle>
        <ul className="space-y-2">
          {(plans ?? []).map((p) => (
            <li key={p.code}><form action={updatePlan} className="flex flex-wrap items-center gap-2 rounded-xl border border-border bg-card p-3">
              <input type="hidden" name="code" value={p.code} />
              <div className="min-w-48 flex-1"><p className="font-semibold">{p.name} {p.is_demo_price && <Badge tone="promo">démo</Badge>}</p><p className="font-mono text-xs text-muted">{p.code} · {p.currency_code}</p></div>
              <Input name="price" type="number" step="any" min={0} defaultValue={p.price} className="w-28" aria-label="Prix" />
              <Input name="duration_days" type="number" min={1} defaultValue={p.duration_days} className="w-20" aria-label="Jours" />
              <label className="flex items-center gap-1 text-sm"><input type="checkbox" name="enabled" defaultChecked={p.enabled} />{t("admin.enable")}</label>
              <Button size="sm" type="submit">{t("common.save")}</Button>
            </form></li>
          ))}
        </ul>
      </section>
      <section>
        <PageTitle sub={t("admin.shipping_sub")}>{t("admin.shipping")}</PageTitle>
        <ul className="mb-3 space-y-1 text-sm">
          {(rules ?? []).map((r) => (
            <li key={r.id} className="flex items-center justify-between gap-2 rounded-lg border border-border bg-card px-3 py-1.5"><span>{r.method} · {r.from_country}→{r.to_country}{r.same_city != null ? (r.same_city ? " · même ville" : " · autre ville") : ""} · <strong>{r.fee} {r.currency_code}</strong> {r.carrier ? `· ${r.carrier}` : ""}</span>
              <ActionButton variant="ghost" confirm={t("admin.confirm_delete")} action={deleteShippingRule.bind(null, r.id)}>🗑</ActionButton></li>
          ))}
        </ul>
        <form action={addShippingRule} className="grid grid-cols-2 gap-2 rounded-xl border border-border bg-card p-3 sm:grid-cols-4">
          <Select name="method" aria-label="Méthode" defaultValue="local"><option value="local">local</option><option value="intercity">intercity</option><option value="international">international</option></Select>
          <Select name="from_country" aria-label="Départ" defaultValue="BF">{countries.map((c) => <option key={c.code} value={c.code}>{c.code}</option>)}</Select>
          <Select name="to_country" aria-label="Arrivée" defaultValue="BF">{countries.map((c) => <option key={c.code} value={c.code}>{c.code}</option>)}</Select>
          <Select name="same_city" aria-label="Même ville" defaultValue=""><option value="">indifférent</option><option value="true">même ville</option><option value="false">autre ville</option></Select>
          <Input name="fee" type="number" step="any" min={0} required placeholder="Frais" aria-label="Frais" />
          <Select name="currency_code" aria-label="Devise" defaultValue="XOF">{currencies.map((c) => <option key={c.code}>{c.code}</option>)}</Select>
          <Input name="eta_days_min" type="number" min={0} placeholder="Jours min" aria-label="Jours min" /><Input name="eta_days_max" type="number" min={0} placeholder="Jours max" aria-label="Jours max" />
          <Input name="carrier" placeholder="Transporteur" className="col-span-2" aria-label="Transporteur" /><Button type="submit" className="col-span-2">{t("admin.add")}</Button>
        </form>
      </section>
      <section>
        <PageTitle sub={t("admin.providers_sub")}>{t("admin.providers")}</PageTitle>
        <ul className="space-y-3">
          {(providers ?? []).map((p) => (
            <li key={p.code}><form action={updateProvider} className="space-y-2 rounded-xl border border-border bg-card p-3">
              <input type="hidden" name="code" value={p.code} />
              <p className="font-semibold">{p.name} <Badge tone={p.enabled ? "success" : "warn"}>{p.enabled ? "activé" : "désactivé"}</Badge></p>
              <div className="grid gap-2 sm:grid-cols-3">
                <Input name="countries" defaultValue={p.countries.join(",")} placeholder="Pays (BF,CI…)" aria-label="Pays" /><Input name="currencies" defaultValue={p.currencies.join(",")} placeholder="Devises (XOF…)" aria-label="Devises" /><Input name="methods" defaultValue={p.methods.join(",")} placeholder="orange_money,wave,card" aria-label="Moyens" />
              </div>
              <Input name="notes" defaultValue={p.notes ?? ""} aria-label="Notes" />
              <div className="flex flex-wrap items-center gap-4 text-sm">
                <label className="flex items-center gap-1"><input type="checkbox" name="enabled" defaultChecked={p.enabled} />{t("admin.enable")}</label>
                <label className="flex items-center gap-1"><input type="checkbox" name="sandbox" defaultChecked={p.sandbox} />sandbox</label>
                <label className="flex items-center gap-1"><input type="checkbox" name="eligibility_verified" defaultChecked={p.eligibility_verified} />{t("admin.eligibility_verified")}</label>
                <Button size="sm" type="submit">{t("common.save")}</Button>
              </div>
            </form></li>
          ))}
        </ul>
        <p className="mt-2 text-xs text-muted">{t("admin.providers_note")}</p>
      </section>
      <section>
        <PageTitle sub={t("admin.keywords_sub")}>{t("admin.keywords")}</PageTitle>
        <div className="mb-3 flex flex-wrap gap-2">{(keywords ?? []).map((k) => <span key={k.id} className="inline-flex items-center gap-1 rounded-full border border-border bg-card px-2 py-0.5 text-sm">{k.keyword}<ActionButton size="sm" variant="ghost" className="h-5 px-1" action={deleteKeyword.bind(null, k.id)}>×</ActionButton></span>)}</div>
        <form action={addKeyword} className="flex flex-wrap gap-2"><Input name="keyword" required placeholder="mot interdit" className="w-48" aria-label="Mot" /><Input name="reason" placeholder="Motif" className="w-64" aria-label="Motif" /><Button type="submit">{t("admin.add")}</Button></form>
      </section>
    </div>
  );
}
