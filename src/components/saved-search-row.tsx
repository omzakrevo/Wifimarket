"use client";
import { Bell, BellOff, Search, Trash2 } from "lucide-react";
import Link from "next/link";
import { useTransition } from "react";
import { deleteSavedSearch, toggleSavedSearchNotify } from "@/app/actions/searches";
import { Button } from "@/components/ui/button";
import { useT } from "@/lib/i18n/client";

export function SavedSearchRow({ s }: { s: { id: string; label: string; notify: boolean; href: string } }) {
  const t = useT();
  const [pending, start] = useTransition();
  return (
    <li className="flex flex-wrap items-center justify-between gap-2 rounded-xl border border-border bg-card p-3">
      <Link href={s.href} className="flex items-center gap-2 font-medium hover:underline"><Search size={14} />{s.label}</Link>
      <div className="flex gap-1">
        <Button size="sm" variant="outline" disabled={pending} onClick={() => start(() => toggleSavedSearchNotify(s.id, !s.notify))}>
          {s.notify ? <><Bell size={14} />{t("search.alerts_on")}</> : <><BellOff size={14} />{t("search.alerts_off")}</>}
        </Button>
        <Button size="sm" variant="ghost" disabled={pending} aria-label={t("common.delete")} onClick={() => start(() => deleteSavedSearch(s.id))}><Trash2 size={14} /></Button>
      </div>
    </li>
  );
}
