import "server-only";
import { createHmac, timingSafeEqual } from "node:crypto";

const API = "https://api.paystack.co";

export function paystackSecret() {
  return process.env.PAYSTACK_SECRET_KEY ?? "";
}

/** Une clé « sk_test_… » correspond au mode sandbox de Paystack. */
export function isPaystackSandbox(secret = paystackSecret()) {
  return secret.startsWith("sk_test_");
}

/** Vérifie l'en-tête x-paystack-signature : HMAC-SHA512 du corps brut avec la clé secrète. */
export function verifyPaystackSignature(rawBody: string, signature: string | null, secret = paystackSecret()) {
  if (!secret || !signature) return false;
  const expected = createHmac("sha512", secret).update(rawBody).digest("hex");
  const a = Buffer.from(expected, "utf8");
  const b = Buffer.from(signature, "utf8");
  return a.length === b.length && timingSafeEqual(a, b);
}

/** Montant en plus petite unité de la devise. À CONFIRMER avec Paystack pour chaque devise avant activation. */
export function toSubunit(amount: number, decimals: number) {
  return Math.round(amount * 10 ** decimals);
}

type PaystackResponse<T> = { status: boolean; message: string; data: T };

async function call<T>(path: string, init?: RequestInit): Promise<PaystackResponse<T>> {
  const res = await fetch(`${API}${path}`, {
    ...init,
    headers: { Authorization: `Bearer ${paystackSecret()}`, "Content-Type": "application/json", ...(init?.headers ?? {}) },
    cache: "no-store",
  });
  return (await res.json()) as PaystackResponse<T>;
}

export function initializeTransaction(p: { email: string; amountSubunit: number; currency: string; reference: string; callbackUrl: string; metadata?: Record<string, unknown> }) {
  return call<{ authorization_url: string; access_code: string; reference: string }>("/transaction/initialize", {
    method: "POST",
    body: JSON.stringify({ email: p.email, amount: p.amountSubunit, currency: p.currency, reference: p.reference, callback_url: p.callbackUrl, metadata: p.metadata }),
  });
}

export function verifyTransaction(reference: string) {
  return call<{ status: string; amount: number; currency: string; reference: string }>(`/transaction/verify/${encodeURIComponent(reference)}`);
}
