import Link from "next/link";
import { Badge, Card, PageTitle } from "@/components/ui/card";
import { ActionButton } from "@/components/action-button";
import { removeListing, resolveReport, setSuspended } from "@/app/actions/admin";
import { getT } from "@/lib/i18n";
import { createClient } from "@/lib/supabase/server";
import { isUuid, timeAgo } from "@/lib/utils";
import type { MessageKey } from "@/lib/i18n/messages";

export default async function AdminReports() {
  const { t, lang } = await getT();
  const supabase = await createClient();
  const { data } = await supabase.from("reports").select("*, reporter:profiles!reports_reporter_id_fkey(display_name)").in("status", ["open", "reviewing"]).order("created_at").limit(100);
  return (
    <>
      <PageTitle>{t("admin.reports")}</PageTitle>
      {!data?.length ? <p className="text-sm text-muted">{t("admin.no_reports")}</p> : (
        <ul className="space-y-2">
          {data.map((r) => (
            <li key={r.id}><Card className="p-3">
              <div className="flex flex-wrap items-start justify-between gap-2">
                <div>
                  <p className="font-semibold">{t(`report.r.${r.reason}` as MessageKey)} — {r.target_type}</p>
                  <p className="text-sm text-muted">{(r.reporter as unknown as { display_name: string } | null)?.display_name} · {timeAgo(r.created_at, lang)}</p>
                  {r.details && <p className="mt-1 text-sm">{r.details}</p>}
                  {r.target_type === "listing" && isUuid(r.target_id) && <Link href={`/admin/annonces?status=all`} className="text-sm text-brand hover:underline">{r.target_id.slice(0, 8)}…</Link>}
                </div>
                <Badge tone={r.status === "open" ? "warn" : "default"}>{r.status}</Badge>
              </div>
              <div className="mt-2 flex flex-wrap gap-2">
                {r.target_type === "listing" && <ActionButton variant="danger" prompt={t("admin.reason_prompt")} action={async (reason) => { "use server"; const x = await removeListing(r.target_id, reason ?? ""); if (x.ok) await resolveReport(r.id, "actioned", "Annonce retirée"); return x; }}>{t("admin.remove")}</ActionButton>}
                {r.target_type === "user" && isUuid(r.target_id) && <ActionButton variant="danger" confirm={t("admin.confirm_suspend")} action={async () => { "use server"; const x = await setSuspended(r.target_id, true); if (x.ok) await resolveReport(r.id, "actioned", "Compte suspendu"); return x; }}>{t("admin.suspend")}</ActionButton>}
                {r.status === "open" && <ActionButton variant="outline" action={resolveReport.bind(null, r.id, "reviewing", undefined)}>{t("admin.reviewing")}</ActionButton>}
                <ActionButton variant="outline" action={resolveReport.bind(null, r.id, "actioned", undefined)}>{t("admin.mark_actioned")}</ActionButton>
                <ActionButton variant="ghost" action={resolveReport.bind(null, r.id, "dismissed", undefined)}>{t("admin.dismiss")}</ActionButton>
              </div>
            </Card></li>
          ))}
        </ul>
      )}
    </>
  );
}
