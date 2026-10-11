import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { ChatRoom } from "@/components/chat-room";
import { Container } from "@/components/ui/card";
import { getWhatsapp } from "@/app/actions/market";
import { requireUser } from "@/lib/auth";
import { getT } from "@/lib/i18n";
import { createClient } from "@/lib/supabase/server";
import { isUuid } from "@/lib/utils";

export const metadata: Metadata = { title: "Conversation", robots: { index: false } };

export default async function ChatPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  if (!isUuid(id)) notFound();
  const user = await requireUser(`/messages/${id}`);
  const { t } = await getT();
  const supabase = await createClient();
  const { data: conv } = await supabase.from("conversations").select("id,user_a,user_b,listing_id,request_id, listings(title,slug), wanted_requests(title)").eq("id", id).maybeSingle();
  if (!conv) notFound();
  const otherId = conv.user_a === user.id ? conv.user_b : conv.user_a;
  const [{ data: other }, { data: msgs }, { data: block }, whatsapp] = await Promise.all([
    supabase.from("profiles").select("display_name").eq("id", otherId).single(),
    supabase.from("messages").select("id,sender_id,body,image_path,read_at,created_at").eq("conversation_id", id).order("created_at", { ascending: true }).limit(300),
    supabase.from("user_blocks").select("blocked_id").eq("blocker_id", user.id).eq("blocked_id", otherId).maybeSingle(),
    getWhatsapp(otherId),
  ]);
  const listing = conv.listings as unknown as { title: string; slug: string } | null;
  const request = conv.wanted_requests as unknown as { title: string } | null;
  return (
    <Container className="max-w-2xl py-4">
      <p className="mb-2 text-sm"><Link href="/messages" className="text-brand hover:underline">← {t("nav.messages")}</Link>
        {listing && <> · <Link href={`/annonces/${listing.slug}`} className="hover:underline">{listing.title}</Link></>}
        {request && conv.request_id && <> · <Link href={`/demandes/${conv.request_id}`} className="hover:underline">{request.title}</Link></>}
      </p>
      <ChatRoom conversationId={id} me={user.id} otherId={otherId} otherName={other?.display_name ?? "?"} initial={msgs ?? []} initiallyBlocked={Boolean(block)} whatsapp={whatsapp} />
    </Container>
  );
}
