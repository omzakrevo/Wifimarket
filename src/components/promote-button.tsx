"use client";
import { Megaphone } from "lucide-react";
import { useState, useTransition } from "react";
import { requestPromotion } from "@/app/actions/promotions";
import { Button } from "@/components/ui/button";
import { useT } from "@/lib/i18n/client";

export function PromoteButton({ listingId, priceLabel, days }: { listingId: string; priceLabel: string; days: number }) {
  const t = useT();
  const [pending, start] = useTransition();
  const [done, setDone] = useState<null | boolean>(null);
  if (done) return <span role="status" className="text-sm text-emerald-700">{t("promo.requested")}</span>;
  return (
    <Button size="sm" variant="outline" disabled={pending} title={t("promo.hint")}
      onClick={() => start(async () => { const r = await requestPromotion(listingId); setDone(r.ok); })}>
      <Megaphone size={14} />{t("promo.sponsor", { days, price: priceLabel })}
    </Button>
  );
}
