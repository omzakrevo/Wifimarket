import { PageTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input, Select } from "@/components/ui/form";
import { ActionButton } from "@/components/action-button";
import { addCity, addCountry, addCurrency, toggleCountry, toggleCurrency } from "@/app/actions/admin";
import { getT } from "@/lib/i18n";
import { createClient } from "@/lib/supabase/server";

export default async function AdminCountries() {
  const { t } = await getT();
  const supabase = await createClient();
  const [{ data: countries }, { data: currencies }, { data: cities }] = await Promise.all([
    supabase.from("countries").select("*").order("sort_order"), supabase.from("currencies").select("*").order("code"), supabase.from("cities").select("country_code,name"),
  ]);
  return (
    <div className="grid gap-8 lg:grid-cols-2">
      <section>
        <PageTitle>{t("admin.countries")}</PageTitle>
        <ul className="mb-4 space-y-1">
          {(countries ?? []).map((c) => (
            <li key={c.code} className="flex items-center justify-between gap-2 rounded-lg border border-border bg-card px-3 py-1.5 text-sm">
              <span className={c.enabled ? "" : "text-muted line-through"}>{c.name_fr} ({c.code}) · {c.currency_code} · {(cities ?? []).filter((x) => x.country_code === c.code).length} {t("admin.cities")}</span>
              <ActionButton variant="outline" action={toggleCountry.bind(null, c.code, !c.enabled)}>{c.enabled ? t("admin.disable") : t("admin.enable")}</ActionButton>
            </li>
          ))}
        </ul>
        <form action={addCountry} className="grid grid-cols-2 gap-2 rounded-xl border border-border bg-card p-3">
          <Input name="code" placeholder="BF" maxLength={2} required aria-label="Code" /><Select name="currency_code" aria-label={t("common.currency")} defaultValue="XOF">{(currencies ?? []).map((c) => <option key={c.code}>{c.code}</option>)}</Select>
          <Input name="name_fr" placeholder="Nom (FR)" required aria-label="Nom FR" /><Input name="name_en" placeholder="Name (EN)" required aria-label="Name EN" />
          <Input name="phone_prefix" placeholder="+226" aria-label="Préfixe" /><Button type="submit">{t("admin.add")}</Button>
        </form>
        <form action={addCity} className="mt-3 flex gap-2"><Select name="country_code" aria-label={t("common.country")} defaultValue="BF">{(countries ?? []).map((c) => <option key={c.code} value={c.code}>{c.name_fr}</option>)}</Select><Input name="name" placeholder={t("common.city")} required aria-label={t("common.city")} /><Button type="submit">{t("admin.add")}</Button></form>
      </section>
      <section>
        <PageTitle>{t("admin.currencies")}</PageTitle>
        <p className="mb-2 text-xs text-muted">{t("admin.no_conversion")}</p>
        <ul className="mb-4 space-y-1">
          {(currencies ?? []).map((c) => (
            <li key={c.code} className="flex items-center justify-between gap-2 rounded-lg border border-border bg-card px-3 py-1.5 text-sm"><span className={c.enabled ? "" : "text-muted line-through"}>{c.code} — {c.name} ({c.symbol})</span>
              <ActionButton variant="outline" action={toggleCurrency.bind(null, c.code, !c.enabled)}>{c.enabled ? t("admin.disable") : t("admin.enable")}</ActionButton></li>
          ))}
        </ul>
        <form action={addCurrency} className="grid grid-cols-2 gap-2 rounded-xl border border-border bg-card p-3">
          <Input name="code" placeholder="XOF" maxLength={3} required aria-label="Code" /><Input name="symbol" placeholder="FCFA" required aria-label="Symbole" />
          <Input name="name" placeholder="Franc CFA" required aria-label="Nom" /><Input name="decimals" type="number" min={0} max={3} defaultValue={0} aria-label="Décimales" />
          <Button type="submit" className="col-span-2">{t("admin.add")}</Button>
        </form>
      </section>
    </div>
  );
}
