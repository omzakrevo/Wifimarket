"use client";
import { CreditCard } from "lucide-react";
import { useState } from "react";
import { Button } from "@/components/ui/button";
import { useT } from "@/lib/i18n/client";

export function PayOnlineButton({ orderId, sandbox }: { orderId: string; sandbox: boolean }) {
  const t = useT();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(false);
  return (
    <span className="inline-flex flex-col">
      <Button size="sm" variant="navy" disabled={busy} onClick={async () => {
        setBusy(true); setError(false);
        const res = await fetch("/api/payments/paystack/initialize", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ order_id: orderId }) });
        const json = await res.json().catch(() => ({}));
        if (res.ok && json.authorization_url) window.location.href = json.authorization_url; else { setError(true); setBusy(false); }
      }}><CreditCard size={14} />{t("order.pay_online")}{sandbox ? " (sandbox)" : ""}</Button>
      {error && <span role="alert" className="text-xs text-red-600">{t("order.pay_error")}</span>}
    </span>
  );
}
