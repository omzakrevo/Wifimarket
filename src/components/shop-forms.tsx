"use client";
import { useActionState, useRef, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { createShop, requestSubscription, requestVerification, setShopImage, updateShop } from "@/app/actions/shops";
import type { FormState } from "@/app/actions/auth";
import { Button } from "@/components/ui/button";
import { Field, Input, Select, Textarea } from "@/components/ui/form";
import { SubmitButton } from "@/components/submit-button";
import { createClient } from "@/lib/supabase/client";
import { compressImage } from "@/lib/image";
import { useLang, useT } from "@/lib/i18n/client";
import { publicStorageUrl } from "@/lib/utils";
import type { MessageKey } from "@/lib/i18n/messages";

type Shop = { id: string; name: string; description: string | null; country_code: string | null; city: string | null; logo_url: string | null; banner_url: string | null };
type Countries = { code: string; name_fr: string; name_en: string }[];

function Msg({ s }: { s: FormState }) {
  const t = useT();
  if (!s) return null;
  return s.error ? <p role="alert" className="text-sm text-red-600">{t(s.error as MessageKey)}</p> : <p role="status" className="text-sm text-emerald-700">{t(s.message as MessageKey)}</p>;
}

export function ShopForm({ shop, countries, defaults }: { shop?: Shop; countries: Countries; defaults: { country: string; city: string } }) {
  const t = useT();
  const lang = useLang();
  const [state, action] = useActionState(shop ? updateShop : createShop, undefined);
  return (
    <form action={action} className="space-y-4">
      {shop && <input type="hidden" name="id" value={shop.id} />}
      <Field label={t("shop.name")} htmlFor="name"><Input id="name" name="name" required minLength={2} maxLength={80} defaultValue={shop?.name} /></Field>
      <Field label={t("listing.description")} htmlFor="description"><Textarea id="description" name="description" rows={4} maxLength={2000} defaultValue={shop?.description ?? ""} /></Field>
      <div className="grid grid-cols-2 gap-3">
        <Field label={t("common.country")} htmlFor="country_code"><Select id="country_code" name="country_code" required defaultValue={shop?.country_code ?? defaults.country}>{countries.map((c) => <option key={c.code} value={c.code}>{lang === "en" ? c.name_en : c.name_fr}</option>)}</Select></Field>
        <Field label={t("common.city")} htmlFor="city"><Input id="city" name="city" maxLength={60} defaultValue={shop?.city ?? defaults.city} /></Field>
      </div>
      <Msg s={state} />
      <SubmitButton>{shop ? t("common.save") : t("shop.create")}</SubmitButton>
    </form>
  );
}

export function ShopImages({ shop }: { shop: Shop }) {
  const t = useT();
  const router = useRouter();
  const [err, setErr] = useState(false);
  const [busy, setBusy] = useState(false);
  const logoRef = useRef<HTMLInputElement>(null);
  const bannerRef = useRef<HTMLInputElement>(null);
  async function upload(kind: "logo_url" | "banner_url", files: FileList | null) {
    const f = files?.[0];
    if (!f) return;
    setBusy(true); setErr(false);
    try {
      const blob = await compressImage(f, kind === "logo_url" ? 512 : 1600);
      const path = `${shop.id}/${kind === "logo_url" ? "logo" : "banner"}-${Date.now()}.${blob.type === "image/webp" ? "webp" : "jpg"}`;
      const { error } = await createClient().storage.from("shop-assets").upload(path, blob, { contentType: blob.type });
      if (error) throw error;
      const r = await setShopImage(shop.id, kind, path);
      if (!r.ok) throw new Error();
      router.refresh();
    } catch { setErr(true); }
    setBusy(false);
  }
  return (
    <div className="space-y-3">
      <div className="relative h-28 overflow-hidden rounded-xl bg-brand-soft/60">
        {shop.banner_url && <img src={publicStorageUrl("shop-assets", shop.banner_url)} alt="" className="h-full w-full object-cover" />}
        <span className="absolute -bottom-0 left-3 flex h-16 w-16 items-center justify-center overflow-hidden rounded-xl border-2 border-card bg-card">
          {shop.logo_url ? <img src={publicStorageUrl("shop-assets", shop.logo_url)} alt="" className="h-full w-full object-cover" /> : <span className="text-xl font-bold text-brand">{shop.name.slice(0, 1)}</span>}
        </span>
      </div>
      <div className="flex gap-2">
        <input ref={logoRef} type="file" accept="image/*" className="sr-only" aria-label={t("shop.logo")} onChange={(e) => void upload("logo_url", e.target.files)} />
        <input ref={bannerRef} type="file" accept="image/*" className="sr-only" aria-label={t("shop.banner")} onChange={(e) => void upload("banner_url", e.target.files)} />
        <Button type="button" size="sm" variant="outline" disabled={busy} onClick={() => logoRef.current?.click()}>{t("shop.logo")}</Button>
        <Button type="button" size="sm" variant="outline" disabled={busy} onClick={() => bannerRef.current?.click()}>{t("shop.banner")}</Button>
      </div>
      {err && <p role="alert" className="text-sm text-red-600">{t("form.err_image")}</p>}
    </div>
  );
}

export function ShopPlanActions({ shopId, plans, verification }: { shopId: string; plans: { code: string; name: string; price_label: string; duration_days: number }[]; verification: string }) {
  const t = useT();
  const router = useRouter();
  const [pending, start] = useTransition();
  const [msg, setMsg] = useState<string | null>(null);
  return (
    <div className="space-y-4">
      <div>
        <p className="mb-2 text-sm font-semibold">{t("shop.verification")} : {t(`verif.${verification}` as MessageKey)}</p>
        {(verification === "unverified" || verification === "rejected") && (
          <Button size="sm" variant="outline" disabled={pending} onClick={() => start(async () => { await requestVerification(shopId); router.refresh(); })}>{t("shop.request_verification")}</Button>
        )}
      </div>
      <div>
        <p className="mb-2 text-sm font-semibold">{t("shop.subscriptions")}</p>
        <div className="grid gap-2 sm:grid-cols-2">
          {plans.map((p) => (
            <div key={p.code} className="rounded-xl border border-border p-3">
              <p className="font-semibold">{p.name}</p>
              <p className="text-sm text-muted">{p.price_label} / {p.duration_days} {t("common.days")}</p>
              <Button size="sm" className="mt-2" disabled={pending} onClick={() => start(async () => { const r = await requestSubscription(shopId, p.code); setMsg(r.ok ? t("shop.subscription_requested") : t("common.error")); router.refresh(); })}>{t("shop.subscribe")}</Button>
            </div>
          ))}
        </div>
        <p className="mt-2 text-xs text-muted">{t("shop.subscription_note")}</p>
        {msg && <p role="status" className="mt-1 text-sm">{msg}</p>}
      </div>
    </div>
  );
}
