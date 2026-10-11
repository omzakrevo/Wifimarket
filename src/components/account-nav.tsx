"use client";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { cn } from "@/lib/utils";

export function AccountNav({ items }: { items: { href: string; label: string }[] }) {
  const path = usePathname();
  return (
    <nav aria-label="Compte" className="-mx-4 mb-6 overflow-x-auto px-4">
      <ul className="flex w-max gap-1 border-b border-border">
        {items.map((it) => {
          const active = it.href === "/compte" ? path === "/compte" : path.startsWith(it.href);
          return (
            <li key={it.href}>
              <Link href={it.href} aria-current={active ? "page" : undefined}
                className={cn("block whitespace-nowrap border-b-2 px-3 py-2 text-sm font-medium", active ? "border-brand text-brand" : "border-transparent text-muted hover:text-foreground")}>
                {it.label}
              </Link>
            </li>
          );
        })}
      </ul>
    </nav>
  );
}
