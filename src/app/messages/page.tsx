import type { Metadata } from "next";
import Link from "next/link";
import { MessageCircle } from "lucide-react";
import { Container, PageTitle } from "@/components/ui/card";
import { requireUser } from "@/lib/auth";
import { getT } from "@/lib/i18n";
import { createClient } from "@/lib/supabase/server";
import { publicStorageUrl, timeAgo } from "@/lib/utils";
import type { MessageKey } from "@/lib/i18n/messages";

export const metadata: Metadata = { title: "Messages", robots: { index: false } };

export default async function MessagesPage({ searchParams }: { searchParams: Promise<{ error?: string }> }) {
  const sp = await searchParams;
  const user = await requireUser("/messages");
  const { t, lang } = await getT();
  const supabase = await createClient();
  const { data: convs } = await supabase.from("conversations")
    .select("id,user_a,user_b,last_message_at,listing_id,request_id, listings(title), wanted_requests(title)")
    .order("last_message_at", { ascending: false }).limit(50);
  const ids = (convs ?? []).map((c) => c.id);
  const otherIds = [...new Set((convs ?? []).map((c) => (c.user_a === user.id ? c.user_b : c.user_a)))];
  const [{ data: msgs }, { data: people }] = await Promise.all([
    ids.length ? supabase.from("messages").select("conversation_id,sender_id,body,image_path,read_at,created_at").in("conversation_id", ids).order("created_at", { ascending: false }).limit(600) : Promise.resolve({ data: [] }),
    otherIds.length ? supabase.from("profiles").select("id,display_name,avatar_url").in("id", otherIds) : Promise.resolve({ data: [] }),
  ]);
  const byConv = new Map<string, { last?: NonNullable<typeof msgs>[number]; unread: number }>();
  for (const m of msgs ?? []) {
    const e = byConv.get(m.conversation_id) ?? { unread: 0 };
    if (!e.last) e.last = m;
    if (m.sender_id !== user.id && !m.read_at) e.unread++;
    byConv.set(m.conversation_id, e);
  }
  const person = new Map((people ?? []).map((p) => [p.id, p]));
  return (
    <Container className="max-w-2xl py-6">
      <PageTitle>{t("nav.messages")}</PageTitle>
      {sp.error?.startsWith("err.") && <p role="alert" className="mb-3 rounded-lg bg-red-50 p-3 text-sm text-red-700">{t(sp.error as MessageKey)}</p>}
      {!convs?.length ? (
        <div className="rounded-xl border border-dashed border-border p-10 text-center text-sm text-muted"><MessageCircle className="mx-auto mb-2" />{t("chat.none")}</div>
      ) : (
        <ul className="divide-y divide-border overflow-hidden rounded-xl border border-border bg-card">
          {convs.map((c) => {
            const other = person.get(c.user_a === user.id ? c.user_b : c.user_a);
            const info = byConv.get(c.id);
            const subject = (c.listings as unknown as { title: string } | null)?.title ?? (c.wanted_requests as unknown as { title: string } | null)?.title;
            return (
              <li key={c.id}>
                <Link href={`/messages/${c.id}`} className="flex items-center gap-3 p-3 hover:bg-brand-soft/40">
                  <span className="flex h-11 w-11 shrink-0 items-center justify-center overflow-hidden rounded-full bg-brand-soft font-bold text-navy">
                    {other?.avatar_url ? <img src={publicStorageUrl("avatars", other.avatar_url)} alt="" className="h-full w-full object-cover" /> : (other?.display_name ?? "?").slice(0, 1).toUpperCase()}
                  </span>
                  <span className="min-w-0 flex-1">
                    <span className="flex items-baseline justify-between gap-2"><span className="truncate font-semibold">{other?.display_name}</span><span className="shrink-0 text-xs text-muted">{timeAgo(c.last_message_at, lang)}</span></span>
                    {subject && <span className="block truncate text-xs text-brand">{subject}</span>}
                    <span className="block truncate text-sm text-muted">{info?.last ? (info.last.body || t("chat.image")) : t("chat.empty")}</span>
                  </span>
                  {info && info.unread > 0 && <span className="min-w-5 rounded-full bg-promo px-1.5 text-center text-xs font-bold text-slate-950">{info.unread}</span>}
                </Link>
              </li>
            );
          })}
        </ul>
      )}
    </Container>
  );
}
