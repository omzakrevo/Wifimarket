"use server";
import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { isUuid } from "@/lib/utils";

export async function blockUser(userId: string, blocked: boolean): Promise<{ ok: boolean }> {
  if (!isUuid(userId)) return { ok: false };
  const supabase = await createClient();
  const { data: auth } = await supabase.auth.getUser();
  if (!auth.user) return { ok: false };
  const { error } = blocked
    ? await supabase.from("user_blocks").upsert({ blocker_id: auth.user.id, blocked_id: userId })
    : await supabase.from("user_blocks").delete().eq("blocker_id", auth.user.id).eq("blocked_id", userId);
  revalidatePath("/messages", "layout");
  return { ok: !error };
}

export async function openChatFromRequest(requestId: string, otherUserId: string) {
  if (!isUuid(requestId) || !isUuid(otherUserId)) redirect("/demandes");
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("start_conversation", { p_other: otherUserId, p_listing: null, p_request: requestId });
  if (error || !data) redirect(`/demandes/${requestId}`);
  redirect(`/messages/${data}`);
}
