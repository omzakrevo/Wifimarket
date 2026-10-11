import { NextResponse } from "next/server";
import { z } from "zod";
import { createClient } from "@/lib/supabase/server";
import { createAdminClient } from "@/lib/supabase/admin";
import { initializeTransaction, isPaystackSandbox, paystackSecret, toSubunit } from "@/lib/payments/paystack";
import { SITE_URL } from "@/lib/utils";

/**
 * Démarre un paiement Paystack pour UNE commande de l'utilisateur connecté.
 * Le montant et la devise viennent de la base (jamais du client). Refusé tant que le prestataire n'est pas
 * activé ET que son éligibilité (pays / devise) n'a pas été vérifiée par un administrateur.
 */
export async function POST(request: Request) {
  const body = z.object({ order_id: z.uuid() }).safeParse(await request.json().catch(() => null));
  if (!body.success) return NextResponse.json({ error: "invalid_request" }, { status: 400 });
  if (!paystackSecret()) return NextResponse.json({ error: "provider_not_configured" }, { status: 503 });

  const supabase = await createClient();
  const { data: auth } = await supabase.auth.getUser();
  if (!auth.user) return NextResponse.json({ error: "auth" }, { status: 401 });

  // RLS : l'utilisateur ne voit que ses propres commandes
  const { data: order } = await supabase.from("orders").select("id,buyer_id,status,total,currency_code,order_number,seller_id").eq("id", body.data.order_id).maybeSingle();
  if (!order || order.buyer_id !== auth.user.id) return NextResponse.json({ error: "not_found" }, { status: 404 });
  if (!["pending", "awaiting_payment"].includes(order.status)) return NextResponse.json({ error: "invalid_state" }, { status: 409 });

  const [{ data: provider }, { data: currency }, { data: sellerProfile }] = await Promise.all([
    supabase.from("payment_providers").select("enabled,eligibility_verified,currencies,countries").eq("code", "paystack").maybeSingle(),
    supabase.from("currencies").select("decimals").eq("code", order.currency_code).maybeSingle(),
    supabase.from("profiles").select("country_code").eq("id", order.seller_id).maybeSingle(),
  ]);
  const eligible = provider?.enabled && provider.eligibility_verified && provider.currencies.includes(order.currency_code)
    && (provider.countries.length === 0 || (sellerProfile?.country_code && provider.countries.includes(sellerProfile.country_code)));
  if (!eligible || !currency) return NextResponse.json({ error: "provider_not_eligible" }, { status: 403 });

  const reference = `${order.order_number}-${Date.now().toString(36)}`;
  const admin = createAdminClient();
  const { error: insErr } = await admin.from("payments").insert({
    order_id: order.id, provider: "paystack", provider_reference: reference, status: "initiated", amount: order.total,
    currency_code: order.currency_code, is_sandbox: isPaystackSandbox(),
  });
  if (insErr) return NextResponse.json({ error: "server" }, { status: 500 });

  const init = await initializeTransaction({
    email: auth.user.email ?? `${auth.user.id}@users.wifimarket.tech`,
    amountSubunit: toSubunit(Number(order.total), currency.decimals), currency: order.currency_code, reference,
    callbackUrl: `${SITE_URL}/compte/commandes`, metadata: { order_id: order.id },
  });
  if (!init.status) {
    await admin.from("payments").update({ status: "failed" }).eq("provider", "paystack").eq("provider_reference", reference);
    return NextResponse.json({ error: "provider_error", message: init.message }, { status: 502 });
  }
  await admin.from("payments").update({ status: "pending" }).eq("provider", "paystack").eq("provider_reference", reference);
  await admin.from("orders").update({ status: "awaiting_payment" }).eq("id", order.id).eq("status", "pending");
  return NextResponse.json({ authorization_url: init.data.authorization_url, sandbox: isPaystackSandbox() });
}
