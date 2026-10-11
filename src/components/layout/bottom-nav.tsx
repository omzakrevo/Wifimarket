"use client";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { Home, MessageCircle, Plus, Search, User } from "lucide-react";
import { useT } from "@/lib/i18n/client";
import { cn } from "@/lib/utils";

export function BottomNav() {
  const path = usePathname();
  const t = useT();
  const items = [
    { href: "/", label: t("nav.home"), icon: Home, match: (p: string) => p === "/" },
    { href: "/recherche", label: t("common.search"), icon: Search, match: (p: string) => p.startsWith("/recherche") || p.startsWith("/categories") },
    { href: "/vendre", label: t("nav.sell_short"), icon: Plus, match: (p: string) => p.startsWith("/vendre"), accent: true },
    { href: "/messages", label: t("nav.messages"), icon: MessageCircle, match: (p: string) => p.startsWith("/messages") },
    { href: "/compte", label: t("nav.account"), icon: User, match: (p: string) => p.startsWith("/compte") },
  ];
  if (path.startsWith("/admin")) return null;
  return (
    <nav aria-label="Navigation principale" className="safe-bottom fixed inset-x-0 bottom-0 z-40 border-t border-border bg-card/95 backdrop-blur sm:hidden">
      <ul className="mx-auto grid max-w-md grid-cols-5">
        {items.map(({ href, label, icon: Icon, match, accent }) => {
          const active = match(path);
          return (
            <li key={href}>
              <Link href={href} aria-current={active ? "page" : undefined}
                className={cn("flex flex-col items-center gap-0.5 py-2 text-[11px] font-medium", active ? "text-brand" : "text-muted")}>
                {accent ? (
                  <span className="-mt-5 flex h-11 w-11 items-center justify-center rounded-full bg-promo text-slate-950 shadow-md"><Icon size={22} /></span>
                ) : (
                  <Icon size={20} />
                )}
                <span>{label}</span>
              </Link>
            </li>
          );
        })}
      </ul>
    </nav>
  );
}
