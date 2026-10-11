import { redirect } from "next/navigation";
import { Card, PageTitle } from "@/components/ui/card";
import { ActionButton } from "@/components/action-button";
import { processDeletion } from "@/app/actions/admin";
import { getRoles, isSuperadminRole } from "@/lib/auth";
import { getT } from "@/lib/i18n";
import { createClient } from "@/lib/supabase/server";
import { timeAgo } from "@/lib/utils";

export default async function AdminDeletions() {
  if (!isSuperadminRole(await getRoles())) redirect("/admin");
  const { t, lang } = await getT();
  const supabase = await createClient();
  const { data } = await supabase.from("data_deletion_requests").select("id,user_id,status,reason,created_at, profiles(display_name)").order("created_at", { ascending: false }).limit(100);
  return (
    <>
      <PageTitle sub={t("admin.deletions_sub")}>{t("admin.deletions")}</PageTitle>
      {!data?.length ? <p className="text-sm text-muted">{t("common.no_results")}</p> : (
        <ul className="space-y-2">
          {data.map((r) => (
            <li key={r.id}><Card className="p-3">
              <p className="font-semibold">{(r.profiles as unknown as { display_name: string } | null)?.display_name} <span className="font-normal text-muted">· {timeAgo(r.created_at, lang)} · {r.status}</span></p>
              {r.reason && <p className="text-sm">{r.reason}</p>}
              {r.status === "pending" && <div className="mt-2 flex gap-2">
                <ActionButton variant="danger" confirm={t("admin.confirm_delete_account")} action={processDeletion.bind(null, r.id, "execute")}>{t("admin.execute_deletion")}</ActionButton>
                <ActionButton variant="outline" action={processDeletion.bind(null, r.id, "reject")}>{t("admin.reject")}</ActionButton>
              </div>}
            </Card></li>
          ))}
        </ul>
      )}
    </>
  );
}
