import Link from "next/link";
import { Logo } from "./logo";
import { getT } from "@/lib/i18n";
import { getCategories } from "@/lib/data";

export async function Footer() {
  const [{ t, lang }, cats] = await Promise.all([getT(), getCategories()]);
  const top = cats.filter((c) => !c.parent_id);
  return (
    <footer className="mt-12 border-t border-border bg-navy text-slate-200 dark:bg-[#08122a]">
      <div className="mx-auto grid max-w-6xl gap-8 px-4 py-10 sm:grid-cols-2 lg:grid-cols-4">
        <div>
          <div className="[&_span]:!text-white"><Logo /></div>
          <p className="mt-3 text-sm text-slate-300">{t("footer.about")}</p>
        </div>
        <div>
          <h2 className="mb-3 text-sm font-bold text-white">{t("footer.categories")}</h2>
          <ul className="space-y-1.5 text-sm">
            {top.map((c) => <li key={c.id}><Link className="hover:underline" href={`/categories/${c.slug}`}>{lang === "en" ? c.name_en : c.name_fr}</Link></li>)}
          </ul>
        </div>
        <div>
          <h2 className="mb-3 text-sm font-bold text-white">{t("footer.marketplace")}</h2>
          <ul className="space-y-1.5 text-sm">
            <li><Link className="hover:underline" href="/vendre">{t("nav.sell")}</Link></li>
            <li><Link className="hover:underline" href="/demandes">{t("nav.wanted")}</Link></li>
            <li><Link className="hover:underline" href="/boutiques">{t("nav.shops")}</Link></li>
            <li><Link className="hover:underline" href="/aide/securite">{t("footer.safety")}</Link></li>
          </ul>
        </div>
        <div>
          <h2 className="mb-3 text-sm font-bold text-white">{t("footer.legal")}</h2>
          <ul className="space-y-1.5 text-sm">
            <li><Link className="hover:underline" href="/legal/conditions">{t("footer.terms")}</Link></li>
            <li><Link className="hover:underline" href="/legal/confidentialite">{t("footer.privacy")}</Link></li>
            <li><Link className="hover:underline" href="/legal/annonces-interdites">{t("footer.prohibited")}</Link></li>
          </ul>
        </div>
      </div>
      <div className="border-t border-white/10 py-4 text-center text-xs text-slate-400">
        © {new Date().getFullYear()} WiFiMarket — wifimarket.tech · {t("footer.zone")}
      </div>
    </footer>
  );
}
