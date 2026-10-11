"use client";
import { ImagePlus, Send, ShieldBan, Flag } from "lucide-react";
import { useCallback, useEffect, useRef, useState } from "react";
import { blockUser } from "@/app/actions/chat";
import { createReport } from "@/app/actions/market";
import { Button } from "@/components/ui/button";
import { createClient } from "@/lib/supabase/client";
import { compressImage } from "@/lib/image";
import { useT } from "@/lib/i18n/client";
import { cn } from "@/lib/utils";
import type { MessageKey } from "@/lib/i18n/messages";

export type ChatMessage = { id: string; sender_id: string; body: string; image_path: string | null; read_at: string | null; created_at: string };

export function ChatRoom({ conversationId, me, otherId, otherName, initial, initiallyBlocked, whatsapp }: {
  conversationId: string; me: string; otherId: string; otherName: string; initial: ChatMessage[]; initiallyBlocked: boolean; whatsapp: string | null;
}) {
  const t = useT();
  const [supabase] = useState(() => createClient());
  const [messages, setMessages] = useState<ChatMessage[]>(initial);
  const [text, setText] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [blocked, setBlocked] = useState(initiallyBlocked);
  const [urls, setUrls] = useState<Record<string, string>>({});
  const [reported, setReported] = useState(false);
  const endRef = useRef<HTMLDivElement>(null);
  const fileRef = useRef<HTMLInputElement>(null);

  const markRead = useCallback(() => { void supabase.rpc("mark_conversation_read", { p_conv: conversationId }); }, [supabase, conversationId]);

  // Realtime : nouveaux messages et accusés de lecture (la RLS filtre côté serveur)
  useEffect(() => {
    markRead();
    const channel = supabase
      .channel(`chat:${conversationId}`)
      .on("postgres_changes", { event: "INSERT", schema: "public", table: "messages", filter: `conversation_id=eq.${conversationId}` }, (payload) => {
        const m = payload.new as ChatMessage;
        setMessages((prev) => (prev.some((x) => x.id === m.id) ? prev : [...prev, m]));
        if (m.sender_id !== me) markRead();
      })
      .on("postgres_changes", { event: "UPDATE", schema: "public", table: "messages", filter: `conversation_id=eq.${conversationId}` }, (payload) => {
        const m = payload.new as ChatMessage;
        setMessages((prev) => prev.map((x) => (x.id === m.id ? { ...x, read_at: m.read_at } : x)));
      })
      .subscribe();
    return () => { void supabase.removeChannel(channel); };
  }, [supabase, conversationId, me, markRead]);

  // Images privées : URLs signées temporaires
  useEffect(() => {
    const missing = messages.filter((m) => m.image_path && !urls[m.image_path]).map((m) => m.image_path!) ;
    if (!missing.length) return;
    void supabase.storage.from("chat-images").createSignedUrls(missing, 3600).then(({ data }) => {
      if (!data) return;
      setUrls((u) => ({ ...u, ...Object.fromEntries(data.filter((d) => d.path && d.signedUrl).map((d) => [d.path as string, d.signedUrl as string])) }));
    });
  }, [messages, urls, supabase]);

  useEffect(() => { endRef.current?.scrollIntoView({ block: "end" }); }, [messages.length]);

  function explain(msg: string) {
    const code = /^[a-z_]+$/.test(msg) ? msg : "generic";
    return t(`err.${code}` as MessageKey);
  }

  async function send(e: React.FormEvent) {
    e.preventDefault();
    const body = text.trim();
    if (!body || busy) return;
    setBusy(true); setError(null);
    const { error: err } = await supabase.from("messages").insert({ conversation_id: conversationId, sender_id: me, body });
    setBusy(false);
    if (err) { setError(explain(err.message)); return; }
    setText("");
  }

  async function sendImage(files: FileList | null) {
    const f = files?.[0];
    if (!f) return;
    setBusy(true); setError(null);
    try {
      const blob = await compressImage(f, 1280);
      const path = `${conversationId}/${me}/${crypto.randomUUID()}.${blob.type === "image/webp" ? "webp" : "jpg"}`;
      const up = await supabase.storage.from("chat-images").upload(path, blob, { contentType: blob.type });
      if (up.error) throw up.error;
      const { error: err } = await supabase.from("messages").insert({ conversation_id: conversationId, sender_id: me, body: "", image_path: path });
      if (err) { await supabase.storage.from("chat-images").remove([path]); setError(explain(err.message)); }
    } catch { setError(t("form.err_image")); }
    setBusy(false);
  }

  return (
    <div className="flex h-[calc(100dvh-9.5rem)] flex-col rounded-xl border border-border bg-card sm:h-[calc(100dvh-8rem)]">
      <div className="flex items-center justify-between gap-2 border-b border-border px-3 py-2">
        <p className="truncate font-semibold">{otherName}</p>
        <div className="flex items-center gap-1">
          {whatsapp && <a href={`https://wa.me/${whatsapp.replace(/\D/g, "")}`} target="_blank" rel="noopener noreferrer" className="rounded-lg bg-[#25D366] px-2 py-1 text-xs font-semibold text-slate-950">WhatsApp</a>}
          <Button size="sm" variant="ghost" title={blocked ? t("chat.unblock") : t("chat.block")} onClick={async () => { const r = await blockUser(otherId, !blocked); if (r.ok) setBlocked(!blocked); }}>
            <ShieldBan size={14} />{blocked ? t("chat.unblock") : t("chat.block")}
          </Button>
          <form action={async (fd) => { const r = await createReport(undefined, fd); if (r.ok) setReported(true); }}>
            <input type="hidden" name="target_type" value="conversation" /><input type="hidden" name="target_id" value={conversationId} /><input type="hidden" name="reason" value="harassment" />
            <Button size="sm" variant="ghost" type="submit" disabled={reported} title={t("chat.report")}><Flag size={14} />{reported ? t("report.sent") : t("chat.report")}</Button>
          </form>
        </div>
      </div>
      <ul className="flex-1 space-y-2 overflow-y-auto p-3" aria-live="polite">
        {messages.map((m) => {
          const mine = m.sender_id === me;
          return (
            <li key={m.id} className={cn("flex", mine ? "justify-end" : "justify-start")}>
              <div className={cn("max-w-[80%] rounded-2xl px-3 py-2 text-sm", mine ? "bg-brand text-white dark:text-slate-950" : "bg-brand-soft text-navy dark:text-blue-50")}>
                {m.image_path && (urls[m.image_path]
                  ? <img src={urls[m.image_path]} alt="" className="mb-1 max-h-60 rounded-lg" /> : <span className="text-xs opacity-70">…</span>)}
                {m.body && <p className="whitespace-pre-wrap break-words">{m.body}</p>}
                <p className={cn("mt-0.5 text-right text-[10px]", mine ? "text-white/80 dark:text-slate-800" : "text-muted")}>
                  {new Date(m.created_at).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })}
                  {mine && <span aria-label={m.read_at ? t("chat.read") : t("chat.sent")}> {m.read_at ? "✓✓" : "✓"}</span>}
                </p>
              </div>
            </li>
          );
        })}
        <div ref={endRef} />
      </ul>
      {error && <p role="alert" className="px-3 pb-1 text-xs text-red-600">{error}</p>}
      {blocked ? <p className="border-t border-border p-3 text-center text-sm text-muted">{t("chat.blocked_info")}</p> : (
        <form onSubmit={send} className="flex items-end gap-2 border-t border-border p-2">
          <input ref={fileRef} type="file" accept="image/*" className="sr-only" aria-label={t("chat.send_image")} onChange={(e) => { void sendImage(e.target.files); e.target.value = ""; }} />
          <Button type="button" variant="ghost" size="icon" aria-label={t("chat.send_image")} onClick={() => fileRef.current?.click()} disabled={busy}><ImagePlus size={18} /></Button>
          <textarea value={text} onChange={(e) => setText(e.target.value)} rows={1} maxLength={4000} placeholder={t("chat.placeholder")} aria-label={t("chat.placeholder")}
            onKeyDown={(e) => { if (e.key === "Enter" && !e.shiftKey) { e.preventDefault(); e.currentTarget.form?.requestSubmit(); } }}
            className="max-h-32 min-h-10 flex-1 resize-none rounded-lg border border-border bg-background px-3 py-2 text-sm focus-visible:outline-2 focus-visible:outline-brand" />
          <Button type="submit" size="icon" disabled={busy || !text.trim()} aria-label={t("chat.send")}><Send size={18} /></Button>
        </form>
      )}
    </div>
  );
}
