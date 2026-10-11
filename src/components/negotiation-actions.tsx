"use client";
import { useRouter } from "next/navigation";
import { useState, useTransition } from "react";
import { confirmNegotiation, respondNegotiation, submitReview } from "@/app/actions/negotiations";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/form";
import { useT } from "@/lib/i18n/client";
import type { MessageKey } from "@/lib/i18n/messages";

export function NegotiationActions({ id, role, status, kind, myConfirmed, currency }: {
  id: string; role: "buyer" | "seller"; status: string; kind: string; myConfirmed: boolean; currency: string;
}) {
  const t = useT();
  const router = useRouter();
  const [pending, start] = useTransition();
  const [price, setPrice] = useState("");
  const [error, setError] = useState<string | null>(null);
  const run = (fn: () => Promise<{ ok: boolean; error?: string }>) => start(async () => {
    const r = await fn(); setError(r.ok ? null : t(`err.${r.error}` as MessageKey)); if (r.ok) router.refresh();
  });
  const canAnswer = (status === "pending" && role === "seller") || (status === "countered" && role === "buyer");
  return (
    <div className="mt-3 space-y-2">
      <div className="flex flex-wrap items-center gap-2">
        {canAnswer && <>
          <Button size="sm" disabled={pending} onClick={() => run(() => respondNegotiation(id, "accept"))}>{t("nego.accept")}</Button>
          <Button size="sm" variant="outline" disabled={pending} onClick={() => run(() => respondNegotiation(id, "decline"))}>{t("nego.decline")}</Button>
        </>}
        {status === "pending" && role === "seller" && (
          <span className="flex items-center gap-1">
            <Input aria-label={`${t("nego.counter")} (${currency})`} className="h-8 w-32" type="number" min="0" step="any" value={price} onChange={(e) => setPrice(e.target.value)} placeholder={currency} />
            <Button size="sm" variant="outline" disabled={pending || price === ""} onClick={() => run(() => respondNegotiation(id, "counter", Number(price)))}>{kind === "exchange" ? t("nego.counter_topup") : t("nego.counter")}</Button>
          </span>
        )}
        {(status === "pending" || status === "countered") && <Button size="sm" variant="ghost" disabled={pending} onClick={() => run(() => respondNegotiation(id, "cancel"))}>{t("common.cancel")}</Button>}
        {status === "accepted" && !myConfirmed && <Button size="sm" disabled={pending} onClick={() => run(() => confirmNegotiation(id))}>{t("nego.confirm")}</Button>}
        {status === "accepted" && myConfirmed && <span className="text-sm text-muted">{t("nego.waiting_other")}</span>}
      </div>
      {error && <p role="alert" className="text-sm text-red-600">{error}</p>}
    </div>
  );
}

export function ReviewForm({ sellerId, orderId }: { sellerId: string; orderId?: string }) {
  const t = useT();
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [msg, setMsg] = useState<string | null>(null);
  const [pending, start] = useTransition();
  if (!open) return <Button size="sm" variant="outline" onClick={() => setOpen(true)}>{t("review.leave")}</Button>;
  return (
    <form className="mt-2 space-y-2 rounded-lg border border-border p-3" action={(fd) => start(async () => {
      const r = await submitReview(fd); setMsg(r.ok ? t("review.thanks") : t(`err.${r.error}` as MessageKey)); if (r.ok) router.refresh();
    })}>
      <input type="hidden" name="seller_id" value={sellerId} />
      {orderId && <input type="hidden" name="order_id" value={orderId} />}
      <label className="block text-sm font-medium" htmlFor={`rating-${orderId ?? sellerId}`}>{t("review.rating")}</label>
      <select id={`rating-${orderId ?? sellerId}`} name="rating" defaultValue="5" className="h-10 w-full rounded-lg border border-border bg-card px-3 text-sm">
        {[5, 4, 3, 2, 1].map((n) => <option key={n} value={n}>{"★".repeat(n)}</option>)}
      </select>
      <textarea name="comment" maxLength={1500} rows={2} aria-label={t("review.comment")} placeholder={t("review.comment")} className="w-full rounded-lg border border-border bg-card px-3 py-2 text-sm" />
      {msg && <p role="status" className="text-sm">{msg}</p>}
      <Button type="submit" size="sm" disabled={pending}>{t("review.send")}</Button>
    </form>
  );
}
