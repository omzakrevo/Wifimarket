import { createHmac } from "node:crypto";
import { describe, expect, it, vi } from "vitest";

vi.mock("server-only", () => ({}));

import { isPaystackSandbox, toSubunit, verifyPaystackSignature } from "@/lib/payments/paystack";

describe("signature de webhook Paystack", () => {
  const secret = "sk_test_exemple";
  const body = JSON.stringify({ event: "charge.success", data: { reference: "WM-1" } });
  const sig = createHmac("sha512", secret).update(body).digest("hex");

  it("accepte une signature valide", () => expect(verifyPaystackSignature(body, sig, secret)).toBe(true));
  it("refuse un corps modifié", () => expect(verifyPaystackSignature(body + " ", sig, secret)).toBe(false));
  it("refuse une signature absente ou erronée", () => {
    expect(verifyPaystackSignature(body, null, secret)).toBe(false);
    expect(verifyPaystackSignature(body, "deadbeef", secret)).toBe(false);
  });
  it("refuse tout sans clé secrète configurée", () => expect(verifyPaystackSignature(body, sig, "")).toBe(false));
});

describe("helpers", () => {
  it("détecte le mode sandbox via le préfixe de la clé", () => {
    expect(isPaystackSandbox("sk_test_abc")).toBe(true);
    expect(isPaystackSandbox("sk_live_abc")).toBe(false);
  });
  it("convertit en plus petite unité selon les décimales", () => {
    expect(toSubunit(1500.5, 2)).toBe(150050);
    expect(toSubunit(45000, 0)).toBe(45000);
  });
});
