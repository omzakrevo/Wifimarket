import type { Metadata } from "next";
import { notFound } from "next/navigation";
import Link from "next/link";
import { MapPin } from "lucide-react";
import { Badge, Card, Container } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { OfferActions, OfferForm, WantedStatusButtons } from "@/components/wanted-forms";
import { openChatFromRequest } from "@/app/actions/chat";
import { getUser } from "@/lib/auth";
import { getCurrencies } from "@/lib/data";
import { getT } from "@/lib/i18n";
import { createClient } from "@/lib/supabase/server";
import { formatPrice, isUuid, timeAgo } from "@/lib/utils";
import type { MessageKey } from "@/lib/i18n/messages";

type Props = { params: Promise<{ id: string }> };

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { id } = await params;
  if (!isUuid(id)) return {};
  const supabase = await createClient();
  const { data } = await supabase.from("wanted_requests").select("title,description").eq("id", id).maybeSingle();
  return data ? { title: data.title, description: data.description?.slice(0, 155) || undefined, alternates: { canonical: `/demandes/${id}` } } : {};
}

export default async function WantedDetail({ params }: Props) {
  const { id } = await params;
  if (!isUuid(id)) notFound();
  const { t, lang } = await getT();
  const supabase = await createClient();
  const user = await getUser();
  const { data: w } = await supabase.from("wanted_requests").select("*, profiles(display_name), categories(name_fr,name_en), brands(name)").eq("id", id).maybeSingle();
  if (!w) notFound();
  const isOwner = user?.id === w.requester_id;
  const [{ data: offers }, currencies, mine] = await Promise.all([
    supabase.from("wanted_offers").select("*, profiles(display_name), listings(slug,title)").eq("request_id", id).order("price"),
    getCurrencies(),
    user && !isOwner ? supabase.from("listings").select("id,title,price,currency_code,condition").eq("seller_id", user.id).eq("status", "active") : Promise.resolve({ data: [] }),
  ]);
  const alreadyOffered = (offers ?? []).some((o) => o.seller_id === user?.id);
  return (
    <Container className="max-w-3xl py-6">
      <nav className="mb-3 text-sm text-muted"><Link href="/demandes" className="hover:underline">← {t("nav.wanted")}</Link></nav>
      <Card className="p-5">
        <div className="flex flex-wrap items-start justify-between gap-2">
          <h1 className="text-xl font-bold">{w.title}</h1>
          <Badge tone={w.status === "open" ? "success" : "default"}>{t(`wanted.s.${w.status}` as MessageKey)}</Badge>
        </div>
        <p className="mt-1 flex items-center gap-1 text-sm text-muted"><MapPin size={14} />{[w.city, w.country_code].filter(Boolean).join(", ")} · {w.profiles?.display_name} · {timeAgo(w.created_at, lang)}</p>
        <dl className="mt-3 grid grid-cols-2 gap-2 text-sm">
          {w.budget != null && w.currency_code && <><dt className="text-muted">{t("wanted.budget")}</dt><dd className="font-semibold">{formatPrice(w.budget, w.currency_code, lang)}</dd></>}
          {w.categories && <><dt className="text-muted">{t("common.category")}</dt><dd>{lang === "en" ? w.categories.name_en : w.categories.name_fr}</dd></>}
          {w.brands && <><dt className="text-muted">{t("common.brand")}</dt><dd>{w.brands.name}</dd></>}
          {w.model_text && <><dt className="text-muted">{t("listing.model")}</dt><dd>{w.model_text}</dd></>}
          {w.condition_wanted && <><dt className="text-muted">{t("wanted.condition")}</dt><dd>{w.condition_wanted === "any" ? t("wanted.any") : t(`cond.${w.condition_wanted}` as MessageKey)}</dd></>}
        </dl>
        {w.description && <p className="mt-3 whitespace-pre-line text-sm">{w.description}</p>}
        {isOwner && <div className="mt-4"><WantedStatusButtons id={w.id} status={w.status} /></div>}
      </Card>

      <section className="mt-6">
        <h2 className="mb-3 text-lg font-bold">{t("wanted.offers")} ({offers?.length ?? 0})</h2>
        {!offers?.length ? <p className="text-sm text-muted">{t("wanted.no_offers")}</p> : (
          <ul className="space-y-3">
            {offers.map((o) => (
              <li key={o.id}>
                <Card className="p-4">
                  <div className="flex flex-wrap items-start justify-between gap-2">
                    <div>
                      <p className="text-lg font-extrabold">{formatPrice(o.price, o.currency_code, lang)}</p>
                      <p className="text-sm text-muted">{o.profiles?.display_name}{o.condition ? ` · ${t(`cond.${o.condition}` as MessageKey)}` : ""} · {timeAgo(o.created_at, lang)}</p>
                      {o.listings && <Link href={`/annonces/${(o.listings as { slug: string }).slug}`} className="text-sm text-brand hover:underline">{(o.listings as { title: string }).title}</Link>}
                    </div>
                    <Badge tone={o.status === "accepted" ? "success" : o.status === "declined" || o.status === "withdrawn" ? "danger" : "default"}>{t(`wanted.os.${o.status}` as MessageKey)}</Badge>
                  </div>
                  {o.message && <p className="mt-2 text-sm">{o.message}</p>}
                  {isOwner && (
                    <div className="mt-3 flex flex-wrap items-center gap-2">
                      <OfferActions offerId={o.id} requestId={w.id} status={o.status} />
                      <form action={openChatFromRequest.bind(null, w.id, o.seller_id)}><Button type="submit" size="sm" variant="outline">{t("listing.contact")}</Button></form>
                    </div>
                  )}
                </Card>
              </li>
            ))}
          </ul>
        )}
      </section>

      {!isOwner && w.status === "open" && (
        <section className="mt-6">
          {!user ? <Link href={`/connexion?next=/demandes/${w.id}`} className="font-semibold text-brand hover:underline">{t("wanted.login_to_offer")}</Link>
            : alreadyOffered ? <p className="text-sm text-muted">{t("err.already_offered")}</p>
            : <OfferForm requestId={w.id} currencies={currencies} defaultCurrency={w.currency_code ?? "XOF"} myListings={(mine.data ?? []) as { id: string; title: string; price: number; currency_code: string; condition: string }[]} />}
        </section>
      )}
    </Container>
  );
}
