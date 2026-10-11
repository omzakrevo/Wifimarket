"use client";
import { useActionState, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { createWanted, respondOffer, setWantedStatus, submitOffer } from "@/app/actions/wanted";
import { Button } from "@/components/ui/button";
import { Field, Input, Select, Textarea } from "@/components/ui/form";
import { SubmitButton } from "@/components/submit-button";
import { useLang, useT } from "@/lib/i18n/client";
import { CONDITIONS } from "@/lib/utils";
import type { MessageKey } from "@/lib/i18n/messages";

type Cat = { id: number; parent_id: number | null; name_fr: string; name_en: string };

export function WantedForm({ categories, brands, countries, cities, currencies, defaults }: {
  categories: Cat[]; brands: { id: number; name: string }[]; countries: { code: string; name_fr: string; name_en: string; currency_code: string }[];
  cities: { country_code: string; name: string }[]; currencies: { code: string }[]; defaults: { country: string; city: string };
}) {
  const t = useT();
  const lang = useLang();
  const [state, action] = useActionState(createWanted, undefined);
  const [country, setCountry] = useState(defaults.country);
  const [currency, setCurrency] = useState(countries.find((c) => c.code === defaults.country)?.currency_code ?? "XOF");
  const nm = (c: { name_fr: string; name_en: string }) => (lang === "en" ? c.name_en : c.name_fr);
  return (
    <form action={action} className="space-y-4">
      <Field label={t("wanted.what")} htmlFor="title"><Input id="title" name="title" required minLength={5} maxLength={140} placeholder={t("wanted.what_ph")} /></Field>
      <div className="grid gap-4 sm:grid-cols-2">
        <Field label={t("common.category")} htmlFor="category_id">
          <Select id="category_id" name="category_id" defaultValue="">
            <option value="">—</option>
            {categories.filter((c) => !c.parent_id).map((top) => (
              <optgroup key={top.id} label={nm(top)}>{categories.filter((c) => c.parent_id === top.id).map((c) => <option key={c.id} value={c.id}>{nm(c)}</option>)}</optgroup>
            ))}
          </Select>
        </Field>
        <Field label={t("common.brand")} htmlFor="brand_id"><Select id="brand_id" name="brand_id" defaultValue=""><option value="">—</option>{brands.map((b) => <option key={b.id} value={b.id}>{b.name}</option>)}</Select></Field>
        <Field label={t("listing.model")} htmlFor="model_text"><Input id="model_text" name="model_text" maxLength={120} placeholder="LiteAP AC 120" /></Field>
        <Field label={t("wanted.condition")} htmlFor="condition_wanted">
          <Select id="condition_wanted" name="condition_wanted" defaultValue="any"><option value="any">{t("wanted.any")}</option>{CONDITIONS.map((c) => <option key={c} value={c}>{t(`cond.${c}` as MessageKey)}</option>)}</Select>
        </Field>
      </div>
      <div className="grid grid-cols-[1fr_6rem] gap-3">
        <Field label={t("wanted.budget")} htmlFor="budget"><Input id="budget" name="budget" type="number" min={0} step="any" inputMode="decimal" /></Field>
        <Field label={t("common.currency")} htmlFor="currency_code"><Select id="currency_code" name="currency_code" value={currency} onChange={(e) => setCurrency(e.target.value)}>{currencies.map((c) => <option key={c.code}>{c.code}</option>)}</Select></Field>
      </div>
      <div className="grid gap-4 sm:grid-cols-2">
        <Field label={t("common.country")} htmlFor="country_code">
          <Select id="country_code" name="country_code" required value={country} onChange={(e) => { setCountry(e.target.value); const c = countries.find((x) => x.code === e.target.value); if (c) setCurrency(c.currency_code); }}>
            {countries.map((c) => <option key={c.code} value={c.code}>{nm(c)}</option>)}
          </Select>
        </Field>
        <Field label={t("common.city")} htmlFor="city">
          <Input id="city" name="city" list="wcities" defaultValue={defaults.city} maxLength={60} />
          <datalist id="wcities">{cities.filter((c) => c.country_code === country).map((c) => <option key={c.name} value={c.name} />)}</datalist>
        </Field>
      </div>
      <Field label={t("listing.description")} htmlFor="description"><Textarea id="description" name="description" rows={4} maxLength={3000} /></Field>
      {state?.error && <p role="alert" className="rounded-lg bg-red-50 p-3 text-sm text-red-700">{t(state.error as MessageKey)}</p>}
      <SubmitButton size="lg" className="w-full">{t("wanted.publish")}</SubmitButton>
    </form>
  );
}

export function OfferForm({ requestId, currencies, defaultCurrency, myListings }: {
  requestId: string; currencies: { code: string }[]; defaultCurrency: string; myListings: { id: string; title: string; price: number; currency_code: string; condition: string }[];
}) {
  const t = useT();
  const [state, action] = useActionState(submitOffer, undefined);
  const [sel, setSel] = useState("");
  const l = myListings.find((x) => x.id === sel);
  return (
    <form action={action} className="space-y-3 rounded-xl border border-border bg-card p-4">
      <h3 className="font-bold">{t("wanted.make_offer")}</h3>
      <input type="hidden" name="request_id" value={requestId} />
      {myListings.length > 0 && (
        <Field label={t("wanted.from_listing")} htmlFor="listing_id">
          <Select id="listing_id" name="listing_id" value={sel} onChange={(e) => setSel(e.target.value)}>
            <option value="">—</option>
            {myListings.map((m) => <option key={m.id} value={m.id}>{m.title}</option>)}
          </Select>
        </Field>
      )}
      <div className="grid grid-cols-[1fr_6rem] gap-3" key={sel}>
        <Field label={t("common.price")} htmlFor="price"><Input id="price" name="price" type="number" min={0} step="any" required defaultValue={l?.price} /></Field>
        <Field label={t("common.currency")} htmlFor="currency"><Select id="currency" name="currency_code" defaultValue={l?.currency_code ?? defaultCurrency}>{currencies.map((c) => <option key={c.code}>{c.code}</option>)}</Select></Field>
      </div>
      <Field label={t("listing.condition")} htmlFor="condition">
        <Select id="condition" name="condition" key={l?.condition} defaultValue={l?.condition ?? "used"}>{CONDITIONS.map((c) => <option key={c} value={c}>{t(`cond.${c}` as MessageKey)}</option>)}</Select>
      </Field>
      <Field label={t("nego.note")} htmlFor="message"><Textarea id="message" name="message" rows={3} maxLength={1000} /></Field>
      {state && <p role={state.ok ? "status" : "alert"} className={state.ok ? "text-sm text-emerald-700" : "text-sm text-red-600"}>{t((state.ok ? state.message : state.error) as MessageKey)}</p>}
      <SubmitButton>{t("wanted.send_offer")}</SubmitButton>
    </form>
  );
}

export function OfferActions({ offerId, requestId, status }: { offerId: string; requestId: string; status: string }) {
  const t = useT();
  const router = useRouter();
  const [pending, start] = useTransition();
  if (status !== "sent") return null;
  const run = (s: "accepted" | "declined") => start(async () => { await respondOffer(offerId, requestId, s); router.refresh(); });
  return (
    <div className="flex gap-2">
      <Button size="sm" disabled={pending} onClick={() => run("accepted")}>{t("nego.accept")}</Button>
      <Button size="sm" variant="outline" disabled={pending} onClick={() => run("declined")}>{t("nego.decline")}</Button>
    </div>
  );
}

export function WantedStatusButtons({ id, status }: { id: string; status: string }) {
  const t = useT();
  const router = useRouter();
  const [pending, start] = useTransition();
  const set = (s: "open" | "fulfilled" | "closed") => start(async () => { await setWantedStatus(id, s); router.refresh(); });
  return (
    <div className="flex flex-wrap gap-2">
      {status === "open" ? <>
        <Button size="sm" variant="outline" disabled={pending} onClick={() => set("fulfilled")}>{t("wanted.mark_fulfilled")}</Button>
        <Button size="sm" variant="ghost" disabled={pending} onClick={() => set("closed")}>{t("wanted.close")}</Button>
      </> : <Button size="sm" variant="outline" disabled={pending} onClick={() => set("open")}>{t("wanted.reopen")}</Button>}
    </div>
  );
}
