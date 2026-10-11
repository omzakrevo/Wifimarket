"use client";
import { Minus, Plus, Trash2 } from "lucide-react";
import { useRouter } from "next/navigation";
import { useState, useTransition } from "react";
import { setCartQuantity } from "@/app/actions/orders";
import { Button } from "@/components/ui/button";
import { useT } from "@/lib/i18n/client";
import type { MessageKey } from "@/lib/i18n/messages";

export function CartItemControls({ listingId, quantity, max }: { listingId: string; quantity: number; max: number }) {
  const t = useT();
  const router = useRouter();
  const [pending, start] = useTransition();
  const [error, setError] = useState<string | null>(null);
  const set = (q: number) => start(async () => { const r = await setCartQuantity(listingId, q); setError(r.ok ? null : t(`err.${r.error}` as MessageKey)); router.refresh(); });
  return (
    <div>
      <div className="flex items-center gap-1">
        <Button size="icon" variant="outline" className="h-8 w-8" disabled={pending || quantity <= 1} aria-label="−" onClick={() => set(quantity - 1)}><Minus size={14} /></Button>
        <span className="w-8 text-center text-sm font-semibold" aria-live="polite">{quantity}</span>
        <Button size="icon" variant="outline" className="h-8 w-8" disabled={pending || quantity >= max} aria-label="+" onClick={() => set(quantity + 1)}><Plus size={14} /></Button>
        <Button size="icon" variant="ghost" className="h-8 w-8 text-red-600" disabled={pending} aria-label={t("common.delete")} onClick={() => set(0)}><Trash2 size={14} /></Button>
      </div>
      {error && <p role="alert" className="text-xs text-red-600">{error}</p>}
    </div>
  );
}
