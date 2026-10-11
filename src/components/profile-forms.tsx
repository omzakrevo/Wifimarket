"use client";
import { useActionState, useRef, useState } from "react";
import { requestAccountDeletion, updateProfile, uploadedAvatar } from "@/app/actions/profile";
import type { FormState } from "@/app/actions/auth";
import { Button } from "@/components/ui/button";
import { Field, Input, Select, Textarea } from "@/components/ui/form";
import { SubmitButton } from "@/components/submit-button";
import { createClient } from "@/lib/supabase/client";
import { compressImage } from "@/lib/image";
import { useLang, useT } from "@/lib/i18n/client";
import { publicStorageUrl } from "@/lib/utils";
import type { MessageKey } from "@/lib/i18n/messages";

function Msg({ s }: { s: FormState }) {
  const t = useT();
  if (!s) return null;
  return s.error
    ? <p role="alert" className="text-sm text-red-600">{t(s.error as MessageKey)}</p>
    : <p role="status" className="text-sm text-emerald-700">{t(s.message as MessageKey)}</p>;
}

export function ProfileForm({ profile, whatsapp, countries }: {
  profile: { id: string; display_name: string; bio: string | null; country_code: string | null; city: string | null; show_whatsapp: boolean; avatar_url: string | null };
  whatsapp: string | null; countries: { code: string; name_fr: string; name_en: string }[];
}) {
  const t = useT();
  const lang = useLang();
  const [state, action] = useActionState(updateProfile, undefined);
  const [avatar, setAvatar] = useState(profile.avatar_url);
  const [avatarErr, setAvatarErr] = useState(false);
  const fileRef = useRef<HTMLInputElement>(null);

  async function onAvatar(files: FileList | null) {
    const f = files?.[0];
    if (!f) return;
    setAvatarErr(false);
    try {
      const blob = await compressImage(f, 512);
      const path = `${profile.id}/avatar-${Date.now()}.${blob.type === "image/webp" ? "webp" : "jpg"}`;
      const { error } = await createClient().storage.from("avatars").upload(path, blob, { contentType: blob.type });
      if (error) throw error;
      const r = await uploadedAvatar(path);
      if (!r.ok) throw new Error();
      setAvatar(path);
    } catch { setAvatarErr(true); }
  }

  return (
    <div className="space-y-4">
      <div className="flex items-center gap-4">
        <span className="flex h-16 w-16 items-center justify-center overflow-hidden rounded-full bg-brand-soft text-2xl font-bold text-navy">
          {avatar ? <img src={publicStorageUrl("avatars", avatar)} alt="" className="h-full w-full object-cover" /> : profile.display_name.slice(0, 1).toUpperCase()}
        </span>
        <div>
          <input ref={fileRef} type="file" accept="image/*" className="sr-only" aria-label={t("profile.photo")} onChange={(e) => void onAvatar(e.target.files)} />
          <Button type="button" variant="outline" size="sm" onClick={() => fileRef.current?.click()}>{t("profile.photo")}</Button>
          {avatarErr && <p role="alert" className="mt-1 text-xs text-red-600">{t("form.err_image")}</p>}
        </div>
      </div>
      <form action={action} className="space-y-4">
        <Field label={t("auth.display_name")} htmlFor="display_name"><Input id="display_name" name="display_name" defaultValue={profile.display_name} required minLength={2} maxLength={60} /></Field>
        <Field label={t("profile.bio")} htmlFor="bio"><Textarea id="bio" name="bio" defaultValue={profile.bio ?? ""} maxLength={500} rows={3} /></Field>
        <div className="grid grid-cols-2 gap-3">
          <Field label={t("common.country")} htmlFor="country_code">
            <Select id="country_code" name="country_code" defaultValue={profile.country_code ?? ""}>
              <option value="">—</option>
              {countries.map((c) => <option key={c.code} value={c.code}>{lang === "en" ? c.name_en : c.name_fr}</option>)}
            </Select>
          </Field>
          <Field label={t("common.city")} htmlFor="city"><Input id="city" name="city" defaultValue={profile.city ?? ""} maxLength={60} /></Field>
        </div>
        <Field label={t("profile.whatsapp")} htmlFor="whatsapp_number" hint={t("profile.whatsapp_hint")}><Input id="whatsapp_number" name="whatsapp_number" type="tel" defaultValue={whatsapp ?? ""} placeholder="+22670000000" /></Field>
        <label className="flex items-start gap-2 text-sm"><input type="checkbox" name="show_whatsapp" defaultChecked={profile.show_whatsapp} className="mt-1" />{t("profile.show_whatsapp")}</label>
        <Msg s={state} />
        <SubmitButton>{t("common.save")}</SubmitButton>
      </form>
    </div>
  );
}

export function DeletionForm() {
  const t = useT();
  const [state, action] = useActionState(requestAccountDeletion, undefined);
  return (
    <form action={action} className="space-y-3">
      <Field label={t("profile.deletion_reason")} htmlFor="reason"><Textarea id="reason" name="reason" maxLength={500} rows={2} /></Field>
      <Msg s={state} />
      <SubmitButton variant="danger">{t("profile.request_deletion")}</SubmitButton>
    </form>
  );
}
