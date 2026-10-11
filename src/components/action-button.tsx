"use client";
import { useRouter } from "next/navigation";
import { useState, useTransition } from "react";
import { Button } from "@/components/ui/button";
import { useT } from "@/lib/i18n/client";
import type { MessageKey } from "@/lib/i18n/messages";
import type { ComponentProps } from "react";

type Props = Omit<ComponentProps<typeof Button>, "onClick"> & {
  action: (reason?: string) => Promise<{ ok: boolean; error?: string }>;
  confirm?: string;
  prompt?: string;   // si défini, demande un motif avant d'exécuter
};

/** Bouton d'action serveur générique (modération, administration). Affiche l'erreur renvoyée par le serveur. */
export function ActionButton({ action, confirm, prompt, children, ...props }: Props) {
  const t = useT();
  const router = useRouter();
  const [pending, start] = useTransition();
  const [error, setError] = useState<string | null>(null);
  return (
    <span className="inline-flex flex-col">
      <Button size="sm" disabled={pending} {...props} onClick={() => {
        let reason: string | undefined;
        if (prompt) { const r = window.prompt(prompt); if (r === null) return; reason = r; }
        else if (confirm && !window.confirm(confirm)) return;
        start(async () => { const r = await action(reason); setError(r.ok ? null : t(`err.${r.error}` as MessageKey)); if (r.ok) router.refresh(); });
      }}>{children}</Button>
      {error && <span role="alert" className="text-xs text-red-600">{error}</span>}
    </span>
  );
}
