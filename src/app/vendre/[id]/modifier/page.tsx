import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { Container, PageTitle } from "@/components/ui/card";
import { ListingForm } from "@/components/listing-form";
import { requireUser } from "@/lib/auth";
import { getT } from "@/lib/i18n";
import { getListingFormData } from "@/lib/listing-form-data";
import { createClient } from "@/lib/supabase/server";
import { isUuid } from "@/lib/utils";

export const metadata: Metadata = { title: "Modifier l'annonce", robots: { index: false } };

export default async function EditListingPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  if (!isUuid(id)) notFound();
  const user = await requireUser(`/vendre/${id}/modifier`);
  const supabase = await createClient();
  const { data: l } = await supabase.from("listings").select("*").eq("id", id).maybeSingle();
  if (!l || l.seller_id !== user.id) notFound();
  const [{ data: media }, data, { t }] = await Promise.all([
    supabase.from("listing_media").select("storage_path,kind,position").eq("listing_id", id).order("position"),
    getListingFormData(user.id),
    getT(),
  ]);
  return (
    <Container className="max-w-2xl py-6">
      <PageTitle>{t("common.edit")} — {l.title}</PageTitle>
      <ListingForm uid={user.id} {...data} initial={l} initialMedia={(media ?? []).map((m) => ({ path: m.storage_path, kind: m.kind }))} />
    </Container>
  );
}
