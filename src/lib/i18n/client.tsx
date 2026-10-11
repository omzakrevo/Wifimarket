"use client";
import { createContext, useContext, useMemo } from "react";
import { translate } from "./translate";
import type { MessageKey } from "./messages";

type Lang = "fr" | "en";
const Ctx = createContext<Lang>("fr");

export function I18nProvider({ lang, children }: { lang: Lang; children: React.ReactNode }) {
  return <Ctx.Provider value={lang}>{children}</Ctx.Provider>;
}

export function useLang() {
  return useContext(Ctx);
}

export function useT() {
  const lang = useContext(Ctx);
  return useMemo(() => (key: MessageKey, vars?: Record<string, string | number>) => translate(lang, key, vars), [lang]);
}
