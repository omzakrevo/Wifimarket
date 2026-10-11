import { describe, expect, it } from "vitest";
import { formatPrice, isUuid, sanitizeSearch } from "@/lib/utils";
import { safeNext } from "@/lib/safe-redirect";
import { translate } from "@/lib/i18n/translate";
import { messages } from "@/lib/i18n/messages";

describe("formatPrice", () => {
  it("affiche le franc CFA sans décimales, dans sa devise d'origine", () => {
    expect(formatPrice(45000, "XOF", "fr").replace(/\s/g, " ")).toMatch(/^45 000 FCFA$/);
  });
  it("garde le code de devise pour les autres monnaies (aucune conversion)", () => {
    expect(formatPrice(650, "GHS", "en")).toBe("650 GHS");
    expect(formatPrice("1250.5", "NGN", "en")).toBe("1,250.5 NGN");
  });
});

describe("sanitizeSearch", () => {
  it("retire les caractères de syntaxe PostgREST", () => {
    expect(sanitizeSearch(`a,b)(c%d*e"f'g\\h`)).toBe("a b c d e f g h");
  });
  it("limite la longueur", () => {
    expect(sanitizeSearch("x".repeat(500)).length).toBe(80);
  });
});

describe("safeNext (anti open-redirect)", () => {
  it("accepte les chemins internes", () => expect(safeNext("/vendre?x=1")).toBe("/vendre?x=1"));
  it.each(["//evil.com", "https://evil.com", "/\\evil.com", "javascript:alert(1)", "", null, undefined])("refuse %s", (v) => {
    expect(safeNext(v as string)).toBe("/compte");
  });
});

describe("isUuid", () => {
  it("valide les UUID", () => {
    expect(isUuid("5d0c2f0e-4a49-4c8e-9a62-0a5a4d0a1111")).toBe(true);
    expect(isUuid("1; drop table")).toBe(false);
  });
});

describe("i18n", () => {
  it("toutes les clés ont un texte FR et EN non vide", () => {
    for (const [k, v] of Object.entries(messages)) {
      expect(v[0].length, `${k} FR`).toBeGreaterThan(0);
      expect(v[1].length, `${k} EN`).toBeGreaterThan(0);
    }
  });
  it("les variables {x} sont présentes dans les deux langues", () => {
    for (const [k, v] of Object.entries(messages)) {
      const vars = (s: string) => [...s.matchAll(/\{(\w+)\}/g)].map((m) => m[1]).sort().join(",");
      expect(vars(v[0]), k).toBe(vars(v[1]));
    }
  });
  it("interpole et retombe sur err.generic pour une erreur inconnue", () => {
    expect(translate("fr", "search.count", { n: 3 })).toBe("3 annonce(s)");
    expect(translate("en", "err.inconnue_xyz")).toBe(translate("en", "err.generic"));
  });
});
