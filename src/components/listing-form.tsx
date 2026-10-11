"use client";
import { Camera, ImagePlus, Star, Trash2, Video } from "lucide-react";
import Link from "next/link";
import { useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { saveListing } from "@/app/actions/listings";
import { Button } from "@/components/ui/button";
import { Field, Input, Select, Textarea } from "@/components/ui/form";
import { createClient } from "@/lib/supabase/client";
import { ALLOWED_VIDEO, MAX_VIDEO_BYTES, compressImage } from "@/lib/image";
import { useLang, useT } from "@/lib/i18n/client";
import { CONDITIONS, publicStorageUrl } from "@/lib/utils";
import type { MessageKey } from "@/lib/i18n/messages";

type Cat = { id: number; parent_id: number | null; name_fr: string; name_en: string };
type MediaItem = { key: string; kind: "image" | "video"; path?: string; blob?: Blob; preview: string };

export type ListingFormProps = {
  uid: string;
  categories: Cat[];
  brands: { id: number; name: string }[];
  models: { id: number; brand_id: number; name: string }[];
  countries: { code: string; name_fr: string; name_en: string; currency_code: string }[];
  cities: { country_code: string; name: string }[];
  currencies: { code: string }[];
  shops: { id: string; name: string }[];
  defaults: { country: string; city: string };
  initial?: {
    id: string; category_id: number; brand_id: number | null; model_id: number | null; model_text: string | null; title: string; description: string;
    condition: string; price: number; currency_code: string; quantity: number; country_code: string; city: string | null;
    delivery_available: boolean; defects: string | null; warranty: string | null; negotiable: boolean; exchange_possible: boolean;
    exchange_wanted: string | null; shop_id: string | null; status: string;
  };
  initialMedia?: { path: string; kind: "image" | "video" }[];
};

export function ListingForm(p: ListingFormProps) {
  const t = useT();
  const lang = useLang();
  const router = useRouter();
  const i = p.initial;
  const [id] = useState(() => i?.id ?? crypto.randomUUID());
  const [categoryId, setCategoryId] = useState(String(i?.category_id ?? ""));
  const [brandId, setBrandId] = useState(String(i?.brand_id ?? ""));
  const [modelText, setModelText] = useState(i?.model_text ?? "");
  const [country, setCountry] = useState(i?.country_code ?? p.defaults.country);
  const [currency, setCurrency] = useState(i?.currency_code ?? p.countries.find((c) => c.code === (i?.country_code ?? p.defaults.country))?.currency_code ?? "XOF");
  const [media, setMedia] = useState<MediaItem[]>(() =>
    (p.initialMedia ?? []).map((m) => ({ key: m.path, kind: m.kind, path: m.path, preview: publicStorageUrl("listing-media", m.path) })));
  const [removed, setRemoved] = useState<string[]>([]);
  const [busy, setBusy] = useState<null | "draft" | "active">(null);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const camRef = useRef<HTMLInputElement>(null);
  const galRef = useRef<HTMLInputElement>(null);
  const vidRef = useRef<HTMLInputElement>(null);
  const formRef = useRef<HTMLFormElement>(null);

  const tops = p.categories.filter((c) => !c.parent_id);
  const nm = (c: { name_fr: string; name_en: string }) => (lang === "en" ? c.name_en : c.name_fr);
  const modelOptions = p.models.filter((m) => !brandId || m.brand_id === Number(brandId));
  const images = media.filter((m) => m.kind === "image").length;

  async function addFiles(files: FileList | null) {
    if (!files) return;
    setError(null);
    const next: MediaItem[] = [];
    for (const f of Array.from(files)) {
      if (images + next.filter((n) => n.kind === "image").length >= 8) { setError(t("form.err_max_photos")); break; }
      try {
        const blob = await compressImage(f);
        next.push({ key: crypto.randomUUID(), kind: "image", blob, preview: URL.createObjectURL(blob) });
      } catch { setError(t("form.err_image")); }
    }
    setMedia((m) => [...m, ...next]);
  }

  function addVideo(files: FileList | null) {
    const f = files?.[0];
    if (!f) return;
    if (!ALLOWED_VIDEO.includes(f.type) || f.size > MAX_VIDEO_BYTES) { setError(t("form.err_video")); return; }
    setError(null);
    setMedia((m) => [...m.filter((x) => x.kind !== "video"), { key: crypto.randomUUID(), kind: "video", blob: f, preview: URL.createObjectURL(f) }]);
  }

  function remove(it: MediaItem) {
    if (it.path) setRemoved((r) => [...r, it.path!]);
    setMedia((m) => m.filter((x) => x.key !== it.key));
  }
  function makeCover(it: MediaItem) {
    setMedia((m) => [it, ...m.filter((x) => x.key !== it.key)]);
  }

  async function submit(status: "draft" | "active") {
    setError(null); setNotice(null);
    const form = formRef.current!;
    if (!form.reportValidity()) return;
    const fd = new FormData(form);
    const s = (k: string) => String(fd.get(k) ?? "").trim();
    setBusy(status);
    const supabase = createClient();
    const uploaded: { path: string; kind: "image" | "video" }[] = [];
    try {
      const ordered: { path: string; kind: "image" | "video" }[] = [];
      for (const m of media) {
        if (m.path) { ordered.push({ path: m.path, kind: m.kind }); continue; }
        const ext = m.kind === "video" ? (m.blob!.type === "video/webm" ? "webm" : "mp4") : m.blob!.type === "image/webp" ? "webp" : "jpg";
        const path = `${p.uid}/${id}/${crypto.randomUUID()}.${ext}`;
        const { error: upErr } = await supabase.storage.from("listing-media").upload(path, m.blob!, { contentType: m.blob!.type, upsert: false });
        if (upErr) throw new Error("upload");
        uploaded.push({ path, kind: m.kind });
        ordered.push({ path, kind: m.kind });
      }
      const model = p.models.find((x) => x.name.toLowerCase() === modelText.trim().toLowerCase() && (!brandId || x.brand_id === Number(brandId)));
      const res = await saveListing({
        id, status,
        category_id: Number(categoryId), brand_id: brandId ? Number(brandId) : null, model_id: model?.id ?? null,
        model_text: modelText.trim() || null, title: s("title"), description: s("description"), condition: s("condition") as "new",
        price: Number(s("price")), currency_code: currency, quantity: Number(s("quantity") || 1), country_code: country, city: s("city") || null,
        delivery_available: fd.get("delivery_available") === "on", defects: s("defects") || null, warranty: s("warranty") || null,
        negotiable: fd.get("negotiable") === "on", exchange_possible: fd.get("exchange_possible") === "on", exchange_wanted: s("exchange_wanted") || null,
        shop_id: s("shop_id") || null, media: ordered, removed_media: removed,
      });
      if (!res.ok) {
        if (uploaded.length) await supabase.storage.from("listing-media").remove(uploaded.map((u) => u.path));
        setError(res.error?.startsWith("invalid:") ? t("form.err_invalid", { field: res.error.slice(8) }) : t(`err.${res.error}` as MessageKey));
        setBusy(null);
        return;
      }
      if (status === "draft") { setNotice(t("form.saved_draft")); setBusy(null); router.replace(`/vendre/${id}/modifier`); router.refresh(); return; }
      router.push(res.status === "pending_review" ? "/compte/annonces?review=1" : `/annonces/${res.slug}`);
    } catch {
      if (uploaded.length) await supabase.storage.from("listing-media").remove(uploaded.map((u) => u.path));
      setError(t("form.err_upload"));
      setBusy(null);
    }
  }

  return (
    <form ref={formRef} onSubmit={(e) => { e.preventDefault(); void submit("active"); }} className="space-y-6">
      <section className="space-y-3 rounded-xl border border-border bg-card p-4">
        <h2 className="font-bold">{t("form.photos")}</h2>
        <p className="text-xs text-muted">{t("form.photos_hint")}</p>
        <div className="flex flex-wrap gap-2">
          <input ref={camRef} type="file" accept="image/*" capture="environment" className="sr-only" onChange={(e) => { void addFiles(e.target.files); e.target.value = ""; }} aria-label={t("form.take_photo")} />
          <input ref={galRef} type="file" accept="image/jpeg,image/png,image/webp,image/avif,image/heic" multiple className="sr-only" onChange={(e) => { void addFiles(e.target.files); e.target.value = ""; }} aria-label={t("form.add_photos")} />
          <input ref={vidRef} type="file" accept="video/mp4,video/webm" className="sr-only" onChange={(e) => { addVideo(e.target.files); e.target.value = ""; }} aria-label={t("form.add_video")} />
          <Button type="button" variant="outline" onClick={() => camRef.current?.click()}><Camera size={16} />{t("form.take_photo")}</Button>
          <Button type="button" variant="outline" onClick={() => galRef.current?.click()}><ImagePlus size={16} />{t("form.add_photos")}</Button>
          <Button type="button" variant="outline" onClick={() => vidRef.current?.click()}><Video size={16} />{t("form.add_video")}</Button>
        </div>
        {media.length > 0 && (
          <ul className="grid grid-cols-3 gap-2 sm:grid-cols-4">
            {media.map((m, idx) => (
              <li key={m.key} className="relative aspect-square overflow-hidden rounded-lg border border-border bg-black/5">
                {m.kind === "video" ? <video src={m.preview} className="h-full w-full object-cover" muted /> :
                  <img src={m.preview} alt="" className="h-full w-full object-cover" />}
                {idx === 0 && <span className="absolute left-1 top-1 rounded bg-promo px-1.5 text-[10px] font-bold text-slate-950">{t("form.cover")}</span>}
                <div className="absolute inset-x-0 bottom-0 flex justify-between bg-black/50 p-1">
                  {idx !== 0 && m.kind === "image" ? <button type="button" onClick={() => makeCover(m)} aria-label={t("form.make_cover")} className="text-white"><Star size={16} /></button> : <span />}
                  <button type="button" onClick={() => remove(m)} aria-label={t("common.delete")} className="text-white"><Trash2 size={16} /></button>
                </div>
              </li>
            ))}
          </ul>
        )}
      </section>

      <section className="space-y-4 rounded-xl border border-border bg-card p-4">
        <h2 className="font-bold">{t("form.product")}</h2>
        <Field label={t("common.category")} htmlFor="category">
          <Select id="category" required value={categoryId} onChange={(e) => setCategoryId(e.target.value)}>
            <option value="" disabled>—</option>
            {tops.map((top) => (
              <optgroup key={top.id} label={nm(top)}>
                {p.categories.filter((c) => c.parent_id === top.id).map((c) => <option key={c.id} value={c.id}>{nm(c)}</option>)}
              </optgroup>
            ))}
          </Select>
        </Field>
        <div className="grid gap-4 sm:grid-cols-2">
          <Field label={t("common.brand")} htmlFor="brand">
            <Select id="brand" value={brandId} onChange={(e) => setBrandId(e.target.value)}>
              <option value="">—</option>
              {p.brands.map((b) => <option key={b.id} value={b.id}>{b.name}</option>)}
            </Select>
          </Field>
          <Field label={t("listing.model")} htmlFor="model">
            <Input id="model" list="models" value={modelText} onChange={(e) => setModelText(e.target.value)} maxLength={120} placeholder="LiteBeam 5AC Gen2" />
            <datalist id="models">{modelOptions.map((m) => <option key={m.id} value={m.name} />)}</datalist>
          </Field>
        </div>
        <Field label={t("form.title")} htmlFor="title"><Input id="title" name="title" required minLength={5} maxLength={140} defaultValue={i?.title} placeholder={t("form.title_ph")} /></Field>
        <Field label={t("listing.description")} htmlFor="description"><Textarea id="description" name="description" rows={5} maxLength={5000} defaultValue={i?.description} /></Field>
        <div className="grid gap-4 sm:grid-cols-2">
          <Field label={t("listing.condition")} htmlFor="condition">
            <Select id="condition" name="condition" required defaultValue={i?.condition ?? "used"}>
              {CONDITIONS.map((c) => <option key={c} value={c}>{t(`cond.${c}` as MessageKey)}</option>)}
            </Select>
          </Field>
          <Field label={t("listing.quantity")} htmlFor="quantity"><Input id="quantity" name="quantity" type="number" min={1} max={100000} defaultValue={i?.quantity ?? 1} required /></Field>
        </div>
        <Field label={t("listing.defects")} htmlFor="defects" hint={t("form.defects_hint")}><Textarea id="defects" name="defects" rows={2} maxLength={1000} defaultValue={i?.defects ?? ""} /></Field>
        <Field label={t("listing.warranty")} htmlFor="warranty"><Input id="warranty" name="warranty" maxLength={300} defaultValue={i?.warranty ?? ""} placeholder="3 mois" /></Field>
      </section>

      <section className="space-y-4 rounded-xl border border-border bg-card p-4">
        <h2 className="font-bold">{t("form.price_place")}</h2>
        <div className="grid grid-cols-[1fr_6rem] gap-3">
          <Field label={t("common.price")} htmlFor="price"><Input id="price" name="price" type="number" inputMode="decimal" min={0} step="any" required defaultValue={i?.price} /></Field>
          <Field label={t("common.currency")} htmlFor="currency">
            <Select id="currency" value={currency} onChange={(e) => setCurrency(e.target.value)}>{p.currencies.map((c) => <option key={c.code} value={c.code}>{c.code}</option>)}</Select>
          </Field>
        </div>
        <div className="grid gap-4 sm:grid-cols-2">
          <Field label={t("common.country")} htmlFor="country">
            <Select id="country" required value={country} onChange={(e) => { setCountry(e.target.value); const c = p.countries.find((x) => x.code === e.target.value); if (c) setCurrency(c.currency_code); }}>
              <option value="" disabled>—</option>
              {p.countries.map((c) => <option key={c.code} value={c.code}>{lang === "en" ? c.name_en : c.name_fr}</option>)}
            </Select>
          </Field>
          <Field label={t("common.city")} htmlFor="city">
            <Input id="city" name="city" list="cities" defaultValue={i?.city ?? p.defaults.city} maxLength={60} />
            <datalist id="cities">{p.cities.filter((c) => c.country_code === country).map((c) => <option key={c.name} value={c.name} />)}</datalist>
          </Field>
        </div>
        <div className="space-y-2 text-sm">
          <label className="flex items-center gap-2"><input type="checkbox" name="delivery_available" defaultChecked={i?.delivery_available} />{t("form.delivery")}</label>
          <label className="flex items-center gap-2"><input type="checkbox" name="negotiable" defaultChecked={i?.negotiable ?? true} />{t("form.negotiable")}</label>
          <label className="flex items-center gap-2"><input type="checkbox" name="exchange_possible" defaultChecked={i?.exchange_possible} />{t("form.exchange")}</label>
        </div>
        <Field label={t("form.exchange_wanted")} htmlFor="exchange_wanted"><Input id="exchange_wanted" name="exchange_wanted" maxLength={300} defaultValue={i?.exchange_wanted ?? ""} placeholder="LiteBeam 5AC" /></Field>
        {p.shops.length > 0 && (
          <Field label={t("form.publish_as")} htmlFor="shop_id">
            <Select id="shop_id" name="shop_id" defaultValue={i?.shop_id ?? ""}>
              <option value="">{t("form.as_individual")}</option>
              {p.shops.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
            </Select>
          </Field>
        )}
      </section>

      {error && <p role="alert" className="rounded-lg bg-red-50 p-3 text-sm text-red-700 dark:bg-red-950/40 dark:text-red-200">{error}</p>}
      {notice && <p role="status" className="rounded-lg bg-emerald-50 p-3 text-sm text-emerald-800 dark:bg-emerald-950/40 dark:text-emerald-200">{notice}</p>}
      <p className="text-xs text-muted">{t("form.moderation_note")} <Link href="/legal/annonces-interdites" className="text-brand underline">{t("footer.prohibited")}</Link></p>
      <div className="sticky bottom-16 z-30 flex gap-2 rounded-xl border border-border bg-card/95 p-3 backdrop-blur sm:bottom-2">
        <Button type="button" variant="outline" disabled={busy !== null} onClick={() => void submit("draft")} className="flex-1">{busy === "draft" ? "…" : t("form.save_draft")}</Button>
        <Button type="submit" disabled={busy !== null} className="flex-1">{busy === "active" ? "…" : i && i.status !== "draft" ? t("common.save") : t("form.publish")}</Button>
      </div>
    </form>
  );
}
