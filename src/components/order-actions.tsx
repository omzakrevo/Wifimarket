"use client";
import { useRouter } from "next/navigation";
import { useState, useTransition } from "react";
import { advanceOrder, cancelOrder, openDispute } from "@/app/actions/orders";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/form";
import { useT } from "@/lib/i18n/client";
import type { MessageKey } from "@/lib/i18n/messages";

export function OrderActions({ id, role, status, method }: { id: string; role: "buyer" | "seller"; status: string; method: string }) {
  const t = useT();
  const router = useRouter();
  const [pending, start] = useTransition();
  const [error, setError] = useState<string | null>(null);
  const [tracking, setTracking] = useState("");
  const [carrier, setCarrier] = useState("");
  const [dispute, setDispute] = useState<string | null>(null);
  const run = (fn: () => Promise<{ ok: boolean; error?: string }>) => start(async () => {
    const r = await fn(); setError(r.ok ? null : t(`err.${r.error}` as MessageKey)); if (r.ok) router.refresh();
  });
  const canCancel = ["pending", "awaiting_payment", "paid", "processing"].includes(status) && (role === "seller" || ["pending", "awaiting_payment"].includes(status));
  return (
    <div className="mt-3 space-y-2">
      <div className="flex flex-wrap items-center gap-2">
        {role === "seller" && (status === "pending" || status === "paid") && <Button size="sm" disabled={pending} onClick={() => run(() => advanceOrder(id, "processing"))}>{t("order.confirm")}</Button>}
        {role === "seller" && status === "processing" && method !== "pickup" && (
          <span className="flex flex-wrap items-center gap-1">
            <Input className="h-8 w-36" aria-label={t("order.carrier")} placeholder={t("order.carrier")} value={carrier} onChange={(e) => setCarrier(e.target.value)} maxLength={60} />
            <Input className="h-8 w-40" aria-label={t("order.tracking")} placeholder={t("order.tracking")} value={tracking} onChange={(e) => setTracking(e.target.value)} maxLength={80} />
            <Button size="sm" disabled={pending} onClick={() => run(() => advanceOrder(id, "shipped", tracking, carrier))}>{t("order.mark_shipped")}</Button>
          </span>
        )}
        {role === "seller" && (status === "shipped" || (status === "processing" && method === "pickup")) && <Button size="sm" disabled={pending} onClick={() => run(() => advanceOrder(id, "delivered"))}>{t("order.mark_delivered")}</Button>}
        {role === "buyer" && status === "delivered" && <Button size="sm" disabled={pending} onClick={() => run(() => advanceOrder(id, "completed"))}>{t("order.confirm_receipt")}</Button>}
        {canCancel && <Button size="sm" variant="outline" disabled={pending} onClick={() => { if (window.confirm(t("order.confirm_cancel"))) run(() => cancelOrder(id)); }}>{t("order.cancel")}</Button>}
        {["shipped", "delivered", "completed", "processing"].includes(status) && dispute === null && <Button size="sm" variant="ghost" onClick={() => setDispute("")}>{t("order.dispute")}</Button>}
      </div>
      {dispute !== null && (
        <div className="flex flex-wrap gap-2">
          <Input aria-label={t("order.dispute_reason")} placeholder={t("order.dispute_reason")} value={dispute} onChange={(e) => setDispute(e.target.value)} className="min-w-60 flex-1" maxLength={2000} />
          <Button size="sm" variant="danger" disabled={pending || dispute.trim().length < 5} onClick={() => run(() => openDispute(id, dispute))}>{t("order.dispute_send")}</Button>
        </div>
      )}
      {error && <p role="alert" className="text-sm text-red-600">{error}</p>}
    </div>
  );
}
