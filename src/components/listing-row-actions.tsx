"use client";
import { useRouter } from "next/navigation";
import { useTransition } from "react";
import { Pause, Play, CheckCircle2, RefreshCw, Trash2, Pencil, Eye } from "lucide-react";
import Link from "next/link";
import { deleteListing, renewListing, setListingStatus } from "@/app/actions/listings";
import { Button, buttonVariants } from "@/components/ui/button";
import { useT } from "@/lib/i18n/client";
import { cn } from "@/lib/utils";

export function ListingRowActions({ id, slug, status }: { id: string; slug: string; status: string }) {
  const t = useT();
  const router = useRouter();
  const [pending, start] = useTransition();
  const run = (fn: () => Promise<unknown>) => start(async () => { await fn(); router.refresh(); });
  return (
    <div className="flex flex-wrap gap-1.5">
      <Link href={`/annonces/${slug}`} className={cn(buttonVariants({ variant: "ghost", size: "sm" }))}><Eye size={14} />{t("common.view")}</Link>
      <Link href={`/vendre/${id}/modifier`} className={cn(buttonVariants({ variant: "outline", size: "sm" }))}><Pencil size={14} />{t("common.edit")}</Link>
      {status === "active" && <Button size="sm" variant="outline" disabled={pending} onClick={() => run(() => setListingStatus(id, "paused"))}><Pause size={14} />{t("listing.pause")}</Button>}
      {status === "paused" && <Button size="sm" variant="outline" disabled={pending} onClick={() => run(() => setListingStatus(id, "active"))}><Play size={14} />{t("listing.resume")}</Button>}
      {(status === "active" || status === "paused") && <Button size="sm" variant="outline" disabled={pending} onClick={() => run(() => setListingStatus(id, "sold"))}><CheckCircle2 size={14} />{t("listing.mark_sold")}</Button>}
      {(status === "active" || status === "expired" || status === "paused") && <Button size="sm" variant="outline" disabled={pending} onClick={() => run(() => renewListing(id))}><RefreshCw size={14} />{t("listing.renew")}</Button>}
      <Button size="sm" variant="ghost" disabled={pending} className="text-red-600" onClick={() => { if (window.confirm(t("listing.confirm_delete"))) run(() => deleteListing(id)); }}><Trash2 size={14} />{t("common.delete")}</Button>
    </div>
  );
}
