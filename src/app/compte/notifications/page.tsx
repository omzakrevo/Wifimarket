import type { Metadata } from "next";
import Link from "next/link";
import { Bell } from "lucide-react";
import { PageTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { getT } from "@/lib/i18n";
import { createClient } from "@/lib/supabase/server";
import { timeAgo } from "@/lib/utils";
import { markAllNotificationsRead } from "@/app/actions/notifications";

export const metadata: Metadata = { title: "Notifications", robots: { index: false } };

export default async function NotificationsPage() {
  const { t, lang } = await getT();
  const supabase = await createClient();
  const { data } = await supabase.from("notifications").select("*").order("created_at", { ascending: false }).limit(100);
  return (
    <>
      <div className="flex items-start justify-between gap-2">
        <PageTitle>{t("nav.notifications")}</PageTitle>
        {data?.some((n) => !n.read_at) && <form action={markAllNotificationsRead}><Button type="submit" variant="outline" size="sm">{t("notif.mark_all")}</Button></form>}
      </div>
      {!data?.length ? <p className="text-sm text-muted">{t("notif.none")}</p> : (
        <ul className="space-y-2">
          {data.map((n) => (
            <li key={n.id} className={`rounded-xl border p-3 ${n.read_at ? "border-border bg-card" : "border-brand bg-brand-soft/40"}`}>
              <Link href={n.link ?? "/compte"} className="flex items-start gap-3">
                <Bell size={16} className="mt-0.5 shrink-0 text-brand" />
                <span className="min-w-0">
                  <span className="block text-sm font-semibold">{n.title}</span>
                  {n.body && <span className="block truncate text-sm text-muted">{n.body}</span>}
                  <span className="text-xs text-muted">{timeAgo(n.created_at, lang)}</span>
                </span>
              </Link>
            </li>
          ))}
        </ul>
      )}
    </>
  );
}
