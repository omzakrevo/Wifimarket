"use client";
import { useTransition } from "react";
import { setLang } from "@/app/actions/prefs";
import { useLang } from "@/lib/i18n/client";

export function LangToggle() {
  const lang = useLang();
  const [pending, start] = useTransition();
  const next = lang === "fr" ? "en" : "fr";
  return (
    <button
      type="button"
      disabled={pending}
      onClick={() => start(() => setLang(next))}
      className="inline-flex h-10 items-center rounded-lg px-2 text-sm font-semibold uppercase hover:bg-brand-soft/60"
      aria-label={next === "en" ? "Switch to English" : "Passer en français"}
    >
      {next}
    </button>
  );
}
