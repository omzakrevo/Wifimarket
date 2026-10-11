import { PageTitle } from "@/components/ui/card";
import { getT } from "@/lib/i18n";
import { createClient } from "@/lib/supabase/server";

export default async function AdminAudit() {
  const { t } = await getT();
  const supabase = await createClient();
  const { data } = await supabase.from("audit_logs").select("id,actor_id,action,entity_type,entity_id,created_at,detail").order("created_at", { ascending: false }).limit(200);
  const ids = [...new Set((data ?? []).map((l) => l.actor_id).filter(Boolean))] as string[];
  const { data: people } = ids.length ? await supabase.from("profiles").select("id,display_name").in("id", ids) : { data: [] };
  const names = new Map((people ?? []).map((p) => [p.id, p.display_name]));
  return (
    <>
      <PageTitle sub={t("admin.audit_sub")}>{t("admin.audit")}</PageTitle>
      <div className="overflow-x-auto rounded-xl border border-border bg-card">
        <table className="w-full min-w-[40rem] text-left text-sm">
          <thead className="border-b border-border text-xs uppercase text-muted"><tr><th className="p-2">Date</th><th className="p-2">Acteur</th><th className="p-2">Action</th><th className="p-2">Entité</th></tr></thead>
          <tbody>
            {(data ?? []).map((l) => (
              <tr key={l.id} className="border-b border-border last:border-0">
                <td className="whitespace-nowrap p-2">{new Date(l.created_at).toLocaleString()}</td>
                <td className="p-2">{l.actor_id ? names.get(l.actor_id) ?? l.actor_id.slice(0, 8) : "système"}</td>
                <td className="p-2">{l.action}</td>
                <td className="p-2"><code className="text-xs">{l.entity_type}</code> {String(l.entity_id ?? "").slice(0, 12)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </>
  );
}
