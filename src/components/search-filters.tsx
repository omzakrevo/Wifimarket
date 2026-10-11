"use client";
import { SlidersHorizontal } from "lucide-react";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { Button } from "@/components/ui/button";
import { Input, Select, Label } from "@/components/ui/form";
import { useLang, useT } from "@/lib/i18n/client";
import { CONDITIONS } from "@/lib/utils";
import type { MessageKey } from "@/lib/i18n/messages";

type Props = {
  values: Record<string, string | undefined>;
  categories: { slug: string; parent_id: number | null; id: number; name_fr: string; name_en: string }[];
  brands: { slug: string; name: string }[];
  countries: { code: string; name_fr: string; name_en: string; currency_code: string }[];
  cities: { country_code: string; name: string }[];
  currencies: { code: string }[];
};

export function SearchFilters({ values, categories, brands, countries, cities, currencies }: Props) {
  const t = useT();
  const lang = useLang();
  const router = useRouter();
  const [country, setCountry] = useState(values.country ?? "");
  const [open, setOpen] = useState(false);

  function submit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const fd = new FormData(e.currentTarget);
    const p = new URLSearchParams();
    for (const [k, v] of fd.entries()) { const s = String(v).trim(); if (s) p.set(k, s); }
    router.push(`/recherche?${p.toString()}`);
    setOpen(false);
  }

  const tops = categories.filter((c) => !c.parent_id);
  const cn = (c: { name_fr: string; name_en: string }) => (lang === "en" ? c.name_en : c.name_fr);

  return (
    <div>
      <button type="button" onClick={() => setOpen((o) => !o)} className="mb-3 inline-flex h-10 items-center gap-2 rounded-lg border border-border bg-card px-4 text-sm font-semibold lg:hidden" aria-expanded={open}>
        <SlidersHorizontal size={16} />{t("search.filters")}
      </button>
      <form onSubmit={submit} className={`${open ? "block" : "hidden"} space-y-4 rounded-xl border border-border bg-card p-4 lg:block`} role="search">
        <div><Label htmlFor="f-q">{t("search.product")}</Label><Input id="f-q" name="q" defaultValue={values.q} placeholder={t("home.search_placeholder")} /></div>
        <div>
          <Label htmlFor="f-cat">{t("common.category")}</Label>
          <Select id="f-cat" name="category" defaultValue={values.category ?? ""}>
            <option value="">{t("common.all")}</option>
            {tops.map((top) => (
              <optgroup key={top.id} label={cn(top)}>
                <option value={top.slug}>{cn(top)} — {t("common.all")}</option>
                {categories.filter((c) => c.parent_id === top.id).map((c) => <option key={c.slug} value={c.slug}>{cn(c)}</option>)}
              </optgroup>
            ))}
          </Select>
        </div>
        <div>
          <Label htmlFor="f-brand">{t("common.brand")}</Label>
          <Select id="f-brand" name="brand" defaultValue={values.brand ?? ""}>
            <option value="">{t("common.all")}</option>
            {brands.map((b) => <option key={b.slug} value={b.slug}>{b.name}</option>)}
          </Select>
        </div>
        <div className="grid grid-cols-2 gap-2">
          <div>
            <Label htmlFor="f-country">{t("common.country")}</Label>
            <Select id="f-country" name="country" value={country} onChange={(e) => setCountry(e.target.value)}>
              <option value="">{t("common.all")}</option>
              {countries.map((c) => <option key={c.code} value={c.code}>{lang === "en" ? c.name_en : c.name_fr}</option>)}
            </Select>
          </div>
          <div>
            <Label htmlFor="f-city">{t("common.city")}</Label>
            <Select id="f-city" name="city" defaultValue={values.city ?? ""} key={country}>
              <option value="">{t("common.all")}</option>
              {cities.filter((c) => c.country_code === country).map((c) => <option key={c.name} value={c.name}>{c.name}</option>)}
            </Select>
          </div>
        </div>
        <div>
          <Label htmlFor="f-currency">{t("search.price_range")}</Label>
          <div className="grid grid-cols-[1fr_1fr_5.5rem] gap-2">
            <Input aria-label={t("search.min")} name="min" inputMode="decimal" placeholder={t("search.min")} defaultValue={values.min} />
            <Input aria-label={t("search.max")} name="max" inputMode="decimal" placeholder={t("search.max")} defaultValue={values.max} />
            <Select id="f-currency" name="currency" defaultValue={values.currency ?? ""} aria-label={t("common.currency")}>
              <option value="">—</option>
              {currencies.map((c) => <option key={c.code} value={c.code}>{c.code}</option>)}
            </Select>
          </div>
          <p className="mt-1 text-xs text-muted">{t("search.currency_hint")}</p>
        </div>
        <div>
          <Label htmlFor="f-cond">{t("listing.condition")}</Label>
          <Select id="f-cond" name="condition" defaultValue={values.condition ?? ""}>
            <option value="">{t("common.all")}</option>
            {CONDITIONS.map((c) => <option key={c} value={c}>{t(`cond.${c}` as MessageKey)}</option>)}
          </Select>
        </div>
        <div>
          <Label htmlFor="f-since">{t("search.published")}</Label>
          <Select id="f-since" name="since" defaultValue={values.since ?? ""}>
            <option value="">{t("search.any_time")}</option>
            <option value="1">{t("search.last_24h")}</option>
            <option value="7">{t("search.last_7d")}</option>
            <option value="30">{t("search.last_30d")}</option>
          </Select>
        </div>
        <div className="space-y-2 text-sm">
          <label className="flex items-center gap-2"><input type="checkbox" name="stock" value="1" defaultChecked={values.stock === "1"} />{t("search.in_stock")}</label>
          <label className="flex items-center gap-2"><input type="checkbox" name="delivery" value="1" defaultChecked={values.delivery === "1"} />{t("search.delivery_only")}</label>
          <label className="flex items-center gap-2"><input type="checkbox" name="exchange" value="1" defaultChecked={values.exchange === "1"} />{t("search.exchange_only")}</label>
        </div>
        <div>
          <Label htmlFor="f-sort">{t("search.sort")}</Label>
          <Select id="f-sort" name="sort" defaultValue={values.sort ?? ""}>
            <option value="">{t("search.sort_relevance")}</option>
            <option value="newest">{t("search.sort_newest")}</option>
            <option value="price_asc">{t("search.sort_price_asc")}</option>
            <option value="price_desc">{t("search.sort_price_desc")}</option>
          </Select>
        </div>
        <div className="flex gap-2">
          <Button type="submit" className="flex-1">{t("common.apply")}</Button>
          <Button type="button" variant="outline" onClick={() => router.push("/recherche")}>{t("common.reset")}</Button>
        </div>
      </form>
    </div>
  );
}
