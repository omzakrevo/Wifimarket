import { cookies, headers } from "next/headers";
import type { MessageKey } from "./messages";
import { translate } from "./translate";
export { translate };

export type Lang = "fr" | "en";
export const LANG_COOKIE = "wm_lang";

export async function getLang(): Promise<Lang> {
  const c = (await cookies()).get(LANG_COOKIE)?.value;
  if (c === "en" || c === "fr") return c;
  const accept = (await headers()).get("accept-language") ?? "";
  return /^en/i.test(accept) ? "en" : "fr";
}

/** Fonction de traduction liée à la langue courante (Server Components). */
export async function getT() {
  const lang = await getLang();
  return { lang, t: (key: MessageKey, vars?: Record<string, string | number>) => translate(lang, key, vars) };
}
