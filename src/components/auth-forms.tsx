"use client";
import { useActionState } from "react";
import Link from "next/link";
import { requestPasswordReset, sendPhoneOtp, signIn, signUp, updatePassword, verifyPhoneOtp, type FormState } from "@/app/actions/auth";
import { Field, Input, Select } from "@/components/ui/form";
import { SubmitButton } from "@/components/submit-button";
import { useLang, useT } from "@/lib/i18n/client";
import type { MessageKey } from "@/lib/i18n/messages";

function Feedback({ state }: { state: FormState }) {
  const t = useT();
  if (!state) return null;
  if (state.error) return <p role="alert" className="rounded-lg bg-red-50 p-3 text-sm text-red-700 dark:bg-red-950/40 dark:text-red-200">{t(state.error as MessageKey)}</p>;
  if (state.message && !state.message.startsWith("otp:")) return <p role="status" className="rounded-lg bg-emerald-50 p-3 text-sm text-emerald-800 dark:bg-emerald-950/40 dark:text-emerald-200">{t(state.message as MessageKey)}</p>;
  return null;
}

export function LoginForm({ next }: { next: string }) {
  const t = useT();
  const [state, action] = useActionState(signIn, undefined);
  return (
    <form action={action} className="space-y-4">
      <input type="hidden" name="next" value={next} />
      <Field label={t("auth.email")} htmlFor="email"><Input id="email" name="email" type="email" autoComplete="email" required /></Field>
      <Field label={t("auth.password")} htmlFor="password"><Input id="password" name="password" type="password" autoComplete="current-password" required /></Field>
      <Feedback state={state} />
      <SubmitButton className="w-full">{t("auth.login")}</SubmitButton>
      <p className="text-center text-sm"><Link href="/mot-de-passe-oublie" className="text-brand hover:underline">{t("auth.forgot")}</Link></p>
    </form>
  );
}

export function SignupForm({ next, countries }: { next: string; countries: { code: string; name_fr: string; name_en: string }[] }) {
  const t = useT();
  const lang = useLang();
  const [state, action] = useActionState(signUp, undefined);
  return (
    <form action={action} className="space-y-4">
      <input type="hidden" name="next" value={next} />
      <Field label={t("auth.display_name")} htmlFor="display_name"><Input id="display_name" name="display_name" autoComplete="name" required minLength={2} maxLength={60} /></Field>
      <Field label={t("auth.email")} htmlFor="email"><Input id="email" name="email" type="email" autoComplete="email" required /></Field>
      <Field label={t("auth.password")} htmlFor="password" hint={t("auth.password_hint")}><Input id="password" name="password" type="password" autoComplete="new-password" required minLength={8} maxLength={72} /></Field>
      <div className="grid grid-cols-2 gap-3">
        <Field label={t("common.country")} htmlFor="country_code">
          <Select id="country_code" name="country_code" defaultValue="">
            <option value="">—</option>
            {countries.map((c) => <option key={c.code} value={c.code}>{lang === "en" ? c.name_en : c.name_fr}</option>)}
          </Select>
        </Field>
        <Field label={t("common.city")} htmlFor="city"><Input id="city" name="city" autoComplete="address-level2" maxLength={60} /></Field>
      </div>
      <label className="flex items-start gap-2 text-sm"><input type="checkbox" name="terms" required className="mt-1" /><span>{t("auth.accept_terms")} <Link href="/legal/conditions" className="text-brand underline">{t("footer.terms")}</Link></span></label>
      <Feedback state={state} />
      <SubmitButton className="w-full">{t("auth.signup")}</SubmitButton>
    </form>
  );
}

export function PhoneForm({ next }: { next: string }) {
  const t = useT();
  const [sent, sendAction] = useActionState(sendPhoneOtp, undefined);
  const [verified, verifyAction] = useActionState(verifyPhoneOtp, undefined);
  const phone = sent?.message?.startsWith("otp:") ? sent.message.slice(4) : null;
  return phone ? (
    <form action={verifyAction} className="space-y-4">
      <input type="hidden" name="phone" value={phone} />
      <input type="hidden" name="next" value={next} />
      <Field label={t("auth.otp_code", { phone })} htmlFor="token"><Input id="token" name="token" inputMode="numeric" autoComplete="one-time-code" required /></Field>
      <Feedback state={verified} />
      <SubmitButton className="w-full">{t("auth.verify")}</SubmitButton>
    </form>
  ) : (
    <form action={sendAction} className="space-y-4">
      <Field label={t("auth.phone")} htmlFor="phone" hint={t("auth.phone_hint")}><Input id="phone" name="phone" type="tel" inputMode="tel" autoComplete="tel" placeholder="+226 70 00 00 00" required /></Field>
      <Feedback state={sent} />
      <SubmitButton className="w-full">{t("auth.send_code")}</SubmitButton>
    </form>
  );
}

export function ResetRequestForm() {
  const t = useT();
  const [state, action] = useActionState(requestPasswordReset, undefined);
  return (
    <form action={action} className="space-y-4">
      <Field label={t("auth.email")} htmlFor="email"><Input id="email" name="email" type="email" required /></Field>
      <Feedback state={state} />
      <SubmitButton className="w-full">{t("auth.send_link")}</SubmitButton>
    </form>
  );
}

export function NewPasswordForm() {
  const t = useT();
  const [state, action] = useActionState(updatePassword, undefined);
  return (
    <form action={action} className="space-y-4">
      <Field label={t("auth.new_password")} htmlFor="password" hint={t("auth.password_hint")}><Input id="password" name="password" type="password" autoComplete="new-password" required minLength={8} maxLength={72} /></Field>
      <Feedback state={state} />
      <SubmitButton className="w-full">{t("common.save")}</SubmitButton>
    </form>
  );
}
