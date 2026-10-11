import Link from "next/link";
import { Bell, MessageCircle, Plus, Search, User } from "lucide-react";
import { Logo } from "./logo";
import { ThemeToggle } from "./theme-toggle";
import { LangToggle } from "./lang-toggle";
import { LocationPicker } from "./location-picker";
import { LinkButton } from "@/components/ui/button";
import { getUser } from "@/lib/auth";
import { getCities, getCountries, getLocation } from "@/lib/data";
import { getT } from "@/lib/i18n";
import { createClient } from "@/lib/supabase/server";

export async function Header() {
  const [{ t }, user, countries, cities, loc] = await Promise.all([getT(), getUser(), getCountries(), getCities(), getLocation()]);
  let unread = 0;
  if (user) {
    const supabase = await createClient();
    const { count } = await supabase.from("notifications").select("id", { count: "exact", head: true }).is("read_at", null);
    unread = count ?? 0;
  }
  return (
    <header className="sticky top-0 z-40 border-b border-border bg-card/95 backdrop-blur">
      <div className="mx-auto flex h-16 w-full max-w-6xl items-center gap-1 px-3 sm:gap-2 sm:px-4">
        <Logo />
        <form action="/recherche" role="search" className="mx-2 hidden flex-1 md:flex">
          <label className="sr-only" htmlFor="hq">{t("common.search")}</label>
          <div className="relative w-full max-w-xl">
            <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-muted" />
            <input id="hq" name="q" type="search" placeholder={t("home.search_placeholder")}
              className="h-10 w-full rounded-lg border border-border bg-background pl-9 pr-3 text-sm focus-visible:outline-2 focus-visible:outline-brand" />
          </div>
        </form>
        <div className="ml-auto flex items-center gap-1">
          <LocationPicker countries={countries} cities={cities} current={loc} />
          <LangToggle />
          <ThemeToggle />
          {user ? (
            <>
              <Link href="/messages" className="hidden h-10 w-10 items-center justify-center rounded-lg hover:bg-brand-soft/60 sm:inline-flex" aria-label={t("nav.messages")}>
                <MessageCircle size={20} />
              </Link>
              <Link href="/compte/notifications" className="relative inline-flex h-10 w-10 items-center justify-center rounded-lg hover:bg-brand-soft/60" aria-label={t("nav.notifications")}>
                <Bell size={20} />
                {unread > 0 && <span className="absolute right-1 top-1 min-w-4 rounded-full bg-promo px-1 text-center text-[10px] font-bold text-slate-950">{unread > 99 ? "99+" : unread}</span>}
              </Link>
              <Link href="/compte" className="hidden h-10 w-10 items-center justify-center rounded-lg hover:bg-brand-soft/60 sm:inline-flex" aria-label={t("nav.account")}>
                <User size={20} />
              </Link>
            </>
          ) : (
            <LinkButton href="/connexion" variant="outline" size="sm" className="hidden sm:inline-flex">{t("auth.login")}</LinkButton>
          )}
          <LinkButton href="/vendre" variant="promo" size="sm" className="hidden sm:inline-flex"><Plus size={16} />{t("nav.sell")}</LinkButton>
        </div>
      </div>
    </header>
  );
}
