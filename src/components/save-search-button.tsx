"use client";
import { Bell } from "lucide-react";
import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { saveSearch } from "@/app/actions/searches";
import { Button } from "@/components/ui/button";
import { useT } from "@/lib/i18n/client";

export function SaveSearchButton({ params, signedIn }: { params: Record<string, string | undefined>; signedIn: boolean }) {
  const t = useT();
  const router = useRouter();
  const [state, setState] = useState<"idle" | "saved" | "error">("idle");
  const [pending, start] = useTransition();
  return (
    <div className="flex items-center gap-2">
      <Button variant="outline" size="sm" disabled={pending || state === "saved"}
        onClick={() => {
          if (!signedIn) { router.push("/connexion?next=" + encodeURIComponent("/recherche?" + new URLSearchParams(Object.entries(params).filter(([, v]) => v) as [string, string][]).toString())); return; }
          start(async () => { const r = await saveSearch(params); setState(r.ok ? "saved" : "error"); });
        }}>
        <Bell size={14} />{state === "saved" ? t("search.saved") : t("search.save")}
      </Button>
      {state === "error" && <span role="alert" className="text-xs text-red-600">{t("common.error")}</span>}
    </div>
  );
}
