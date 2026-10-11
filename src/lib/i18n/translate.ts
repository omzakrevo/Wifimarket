import { messages } from "./messages";

type Entry = readonly [string, string];

/** Traduit une clé ; une clé d'erreur inconnue retombe sur « err.generic » plutôt que d'afficher la clé brute. */
export function translate(lang: "fr" | "en", key: string, vars?: Record<string, string | number>) {
  const table = messages as Record<string, Entry>;
  const entry = table[key] ?? (key.startsWith("err.") ? table["err.generic"] : undefined);
  let s = entry ? (lang === "en" ? entry[1] : entry[0]) : key;
  if (vars) for (const [k, v] of Object.entries(vars)) s = s.replaceAll(`{${k}}`, String(v));
  return s;
}
