"use client";
import { MapPin } from "lucide-react";
import { useState, useTransition } from "react";
import { setLocation } from "@/app/actions/prefs";
import { useLang, useT } from "@/lib/i18n/client";
import { Select } from "@/components/ui/form";
import { Button } from "@/components/ui/button";

type Props = {
  countries: { code: string; name_fr: string; name_en: string }[];
  cities: { country_code: string; name: string }[];
  current: { country: string | null; city: string | null };
};

export function LocationPicker({ countries, cities, current }: Props) {
  const t = useT();
  const lang = useLang();
  const [open, setOpen] = useState(false);
  const [country, setCountry] = useState(current.country ?? "");
  const [city, setCity] = useState(current.city ?? "");
  const [pending, start] = useTransition();
  const label = current.country
    ? [current.city, countries.find((c) => c.code === current.country)?.[lang === "en" ? "name_en" : "name_fr"]].filter(Boolean).join(", ")
    : t("loc.all");
  return (
    <div className="relative">
      <button type="button" onClick={() => setOpen((o) => !o)} aria-expanded={open}
        className="inline-flex h-10 max-w-44 items-center gap-1 rounded-lg px-2 text-sm hover:bg-brand-soft/60">
        <MapPin size={16} className="shrink-0 text-brand" />
        <span className="truncate">{label}</span>
      </button>
      {open && (
        <div className="absolute right-0 z-50 mt-2 w-72 max-w-[calc(100vw-2rem)] rounded-xl border border-border bg-card p-4 shadow-lg">
          <p className="mb-3 text-sm font-semibold">{t("loc.title")}</p>
          <div className="space-y-2">
            <Select value={country} onChange={(e) => { setCountry(e.target.value); setCity(""); }} aria-label={t("common.country")}>
              <option value="">{t("loc.all")}</option>
              {countries.map((c) => <option key={c.code} value={c.code}>{lang === "en" ? c.name_en : c.name_fr}</option>)}
            </Select>
            <Select value={city} onChange={(e) => setCity(e.target.value)} disabled={!country} aria-label={t("common.city")}>
              <option value="">{t("loc.all_cities")}</option>
              {cities.filter((c) => c.country_code === country).map((c) => <option key={c.name} value={c.name}>{c.name}</option>)}
            </Select>
            <Button className="w-full" disabled={pending}
              onClick={() => start(async () => { await setLocation(country, city); setOpen(false); })}>
              {t("common.apply")}
            </Button>
          </div>
        </div>
      )}
    </div>
  );
}
