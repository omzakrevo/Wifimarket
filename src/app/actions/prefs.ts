"use server";
import { cookies } from "next/headers";
import { revalidatePath } from "next/cache";
import { LANG_COOKIE } from "@/lib/i18n";

const ONE_YEAR = 60 * 60 * 24 * 365;

export async function setLang(lang: string) {
  if (lang !== "fr" && lang !== "en") return;
  (await cookies()).set(LANG_COOKIE, lang, { maxAge: ONE_YEAR, path: "/", sameSite: "lax" });
  revalidatePath("/", "layout");
}

export async function setLocation(country: string, city: string) {
  const c = /^[A-Z]{2}$/.test(country) ? country : "";
  const v = c ? `${c}|${city.slice(0, 60)}` : "";
  const store = await cookies();
  if (v) store.set("wm_loc", encodeURIComponent(v), { maxAge: ONE_YEAR, path: "/", sameSite: "lax" });
  else store.delete("wm_loc");
  revalidatePath("/", "layout");
}
