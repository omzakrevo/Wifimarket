import { NextResponse } from "next/server";
import { createAdminClient } from "@/lib/supabase/admin";
import { paystackSecret, verifyPaystackSignature, verifyTransaction } from "@/lib/payments/paystack";

/**
 * Webhook Paystack. Un paiement n'est JAMAIS considéré comme réussi sur la seule foi du webhook :
 *  1) la signature HMAC-SHA512 est vérifiée sur le corps brut ;
 *  2) la transaction est revérifiée auprès de l'API Paystack (statut, montant, devise) ;
 *  3) le traitement est idempotent (un paiement déjà « succeeded » n'est pas retraité).
 */
export async function POST(request: Request) {
  const raw = await request.text();
  const signature = request.headers.get("x-paystack-signature");
  const admin = createAdminClient();

  if (!verifyPaystackSignature(raw, signature)) {
    await admin.from("payment_events").insert({ provider: "paystack", event_type: "invalid_signature", signature_valid: false, payload: { length: raw.length } });
    return NextResponse.json({ error: "invalid_signature" }, { status: 401 });
  }
  if (!paystackSecret()) return NextResponse.json({ error: "not_configured" }, { status: 503 });

  let event: { event?: string; data?: { reference?: string } };
  try { event = JSON.parse(raw); } catch { return NextResponse.json({ error: "invalid_json" }, { status: 400 }); }
  const reference = event.data?.reference;
  if (!reference) return NextResponse.json({ ok: true });

  const { data: payment } = await admin.from("payments").select("id,order_id,status,amount,currency_code").eq("provider", "paystack").eq("provider_reference", reference).maybeSingle();
  await admin.from("payment_events").insert({ payment_id: payment?.id ?? null, provider: "paystack", event_type: event.event ?? "unknown", signature_valid: true, payload: event as object });
  if (!payment) return NextResponse.json({ ok: true });                  // référence inconnue : on acquitte sans rien faire
  if (payment.status === "succeeded") return NextResponse.json({ ok: true }); // idempotence

  if (event.event === "charge.success") {
    const check = await verifyTransaction(reference);
    const { data: cur } = await admin.from("currencies").select("decimals").eq("code", payment.currency_code).single();
    const expected = Math.round(Number(payment.amount) * 10 ** (cur?.decimals ?? 2));
    const ok = check.status && check.data.status === "success" && check.data.currency === payment.currency_code && Number(check.data.amount) === expected;
    if (ok) {
      await admin.from("payments").update({ status: "succeeded", verified_at: new Date().toISOString() }).eq("id", payment.id);
      await admin.from("orders").update({ status: "paid" }).eq("id", payment.order_id).in("status", ["pending", "awaiting_payment"]);
    } else {
      await admin.from("payments").update({ status: "failed" }).eq("id", payment.id);
      await admin.from("payment_events").insert({ payment_id: payment.id, provider: "paystack", event_type: "verification_mismatch", signature_valid: true, payload: { reference } });
    }
  } else if (event.event === "charge.failed") {
    await admin.from("payments").update({ status: "failed" }).eq("id", payment.id);
  }
  return NextResponse.json({ ok: true });
}
