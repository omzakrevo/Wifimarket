"use client";
import { useActionState, useState } from "react";
import { placeOrder } from "@/app/actions/orders";
import { Field, Input, Select, Textarea } from "@/components/ui/form";
import { SubmitButton } from "@/components/submit-button";
import { useLang, useT } from "@/lib/i18n/client";
import type { MessageKey } from "@/lib/i18n/messages";

export function CheckoutForm({ countries, defaults, allDeliverable }: {
  countries: { code: string; name_fr: string; name_en: string }[]; defaults: { country: string; city: string; name: string }; allDeliverable: boolean;
}) {
  const t = useT();
  const lang = useLang();
  const [state, action] = useActionState(placeOrder, undefined);
  const [method, setMethod] = useState("pickup");
  return (
    <form action={action} className="space-y-5">
      <fieldset className="space-y-2">
        <legend className="mb-1 font-bold">{t("checkout.delivery_mode")}</legend>
        {(["pickup", "local", "intercity", "international"] as const).map((m) => (
          <label key={m} className={`flex items-start gap-2 rounded-lg border border-border p-3 text-sm ${m !== "pickup" && !allDeliverable ? "opacity-50" : ""}`}>
            <input type="radio" name="delivery_method" value={m} checked={method === m} disabled={m !== "pickup" && !allDeliverable} onChange={() => setMethod(m)} className="mt-1" />
            <span><span className="font-semibold">{t(`ship.${m}` as MessageKey)}</span><span className="block text-xs text-muted">{t(`ship.${m}_hint` as MessageKey)}</span></span>
          </label>
        ))}
        {!allDeliverable && <p className="text-xs text-amber-700">{t("checkout.some_pickup_only")}</p>}
      </fieldset>
      {method !== "pickup" && (
        <fieldset className="space-y-3">
          <legend className="mb-1 font-bold">{t("checkout.address")}</legend>
          <Field label={t("checkout.recipient")} htmlFor="recipient"><Input id="recipient" name="recipient" defaultValue={defaults.name} required maxLength={80} /></Field>
          <Field label={t("auth.phone")} htmlFor="phone"><Input id="phone" name="phone" type="tel" required maxLength={30} /></Field>
          <div className="grid grid-cols-2 gap-3">
            <Field label={t("common.country")} htmlFor="country"><Select id="country" name="country" defaultValue={defaults.country} required>{countries.map((c) => <option key={c.code} value={c.code}>{lang === "en" ? c.name_en : c.name_fr}</option>)}</Select></Field>
            <Field label={t("common.city")} htmlFor="city"><Input id="city" name="city" defaultValue={defaults.city} required maxLength={60} /></Field>
          </div>
          <Field label={t("checkout.address_line")} htmlFor="line1"><Input id="line1" name="line1" required maxLength={200} /></Field>
        </fieldset>
      )}
      <fieldset className="space-y-2">
        <legend className="mb-1 font-bold">{t("checkout.payment")}</legend>
        <label className="flex items-start gap-2 rounded-lg border border-brand bg-brand-soft/30 p-3 text-sm">
          <input type="radio" name="payment_method" value="offline" defaultChecked className="mt-1" />
          <span><span className="font-semibold">{t("checkout.pay_offline")}</span><span className="block text-xs text-muted">{t("checkout.pay_offline_hint")}</span></span>
        </label>
        <p className="rounded-lg bg-brand-soft/40 p-3 text-xs">{t("checkout.online_unavailable")}</p>
      </fieldset>
      <Field label={t("checkout.note")} htmlFor="note"><Textarea id="note" name="note" maxLength={500} rows={2} /></Field>
      {state?.error && <p role="alert" className="rounded-lg bg-red-50 p-3 text-sm text-red-700 dark:bg-red-950/40 dark:text-red-200">{t(state.error as MessageKey)}</p>}
      <SubmitButton size="lg" className="w-full">{t("checkout.confirm")}</SubmitButton>
    </form>
  );
}
