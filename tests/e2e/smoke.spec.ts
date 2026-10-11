import { expect, test } from "@playwright/test";

// Ces tests ne nécessitent PAS Supabase : ils vérifient le rendu public, la PWA, le responsive et les garde-fous.

const PUBLIC_PAGES = ["/", "/connexion", "/inscription", "/recherche", "/demandes", "/boutiques", "/legal/conditions", "/aide/securite", "/offline"];

test.describe("pages publiques", () => {
  for (const path of PUBLIC_PAGES) {
    test(`${path} s'affiche sans débordement horizontal`, async ({ page }) => {
      const res = await page.goto(path);
      expect(res?.status()).toBeLessThan(500);
      await expect(page.locator("h1").first()).toBeVisible();
      const overflow = await page.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth);
      expect(overflow, "scroll horizontal").toBeLessThanOrEqual(1);
    });
  }

  test("l'accueil expose recherche, vendre, demande et pied de page", async ({ page }) => {
    await page.goto("/");
    await expect(page.getByRole("heading", { level: 1 })).toContainText("matériel Wi-Fi");
    await expect(page.locator("main").getByRole("link", { name: "Vendre un matériel" })).toBeVisible();
    await expect(page.locator("main").getByRole("link", { name: "Publier une demande" })).toBeVisible();
    await expect(page.getByRole("search").first()).toBeVisible();
    await expect(page.getByRole("contentinfo")).toContainText("wifimarket.tech");
  });

  test("la recherche envoie vers /recherche?q=", async ({ page }) => {
    await page.goto("/");
    await page.locator("#hero-q").fill("litebeam");
    await page.locator("#hero-q").press("Enter");
    await expect(page).toHaveURL(/\/recherche\?q=litebeam/);
  });
});

test.describe("accès protégés", () => {
  for (const path of ["/compte", "/vendre", "/messages", "/panier", "/admin", "/demandes/nouvelle"]) {
    test(`${path} redirige vers la connexion`, async ({ page }) => {
      await page.goto(path);
      await expect(page).toHaveURL(/\/connexion/);
    });
  }
  test("la redirection ?next= refuse les URL externes", async ({ page }) => {
    await page.goto("/connexion?next=//evil.com");
    await expect(page.locator("form").first()).toBeVisible();
    await expect(page.locator('input[name="next"]').first()).toHaveValue("/compte");
  });
});

test.describe("préférences", () => {
  test("bascule FR → EN", async ({ page }) => {
    await page.goto("/connexion");
    await page.getByRole("button", { name: "Switch to English" }).click();
    await expect(page.getByRole("heading", { level: 1 })).toHaveText("Log in");
    await expect(page.locator("html")).toHaveAttribute("lang", "en");
  });

  test("mode sombre", async ({ page }) => {
    await page.goto("/connexion");
    await page.getByRole("button", { name: /thème|theme/i }).click();
    await expect(page.locator("html")).toHaveClass(/dark|light/);
    const cls = await page.locator("html").getAttribute("class");
    await page.getByRole("button", { name: /thème|theme/i }).click();
    await expect(page.locator("html")).not.toHaveAttribute("class", cls ?? "");
  });
});

test.describe("mobile", () => {
  test("le menu inférieur est visible sur mobile et masqué sur grand écran", async ({ page, isMobile }) => {
    await page.goto("/");
    const nav = page.getByRole("navigation", { name: "Navigation principale" });
    if (isMobile) {
      await expect(nav).toBeVisible();
      await nav.getByRole("link", { name: "Vendre" }).click();
      await expect(page).toHaveURL(/\/connexion/); // non connecté
    } else {
      await expect(nav).toBeHidden();
    }
  });
});

test.describe("PWA, SEO et sécurité", () => {
  test("manifest valide", async ({ request }) => {
    const res = await request.get("/manifest.webmanifest");
    expect(res.ok()).toBeTruthy();
    const m = await res.json();
    expect(m.display).toBe("standalone");
    expect(m.icons.map((i: { sizes: string }) => i.sizes)).toEqual(expect.arrayContaining(["192x192", "512x512"]));
    for (const i of m.icons) expect((await request.get(i.src)).ok(), i.src).toBeTruthy();
  });
  test("service worker servi et sans cache agressif", async ({ request }) => {
    const res = await request.get("/sw.js");
    expect(res.ok()).toBeTruthy();
    expect(res.headers()["cache-control"]).toContain("no-cache");
    expect(await res.text()).toContain("/offline");
  });
  test("robots.txt et sitemap.xml", async ({ request }) => {
    const robots = await (await request.get("/robots.txt")).text();
    expect(robots).toContain("Sitemap: https://wifimarket.tech/sitemap.xml");
    expect(robots).toContain("Disallow: /admin");
    const sm = await request.get("/sitemap.xml");
    expect(sm.ok()).toBeTruthy();
    expect(await sm.text()).toContain("<urlset");
  });
  test("en-têtes de sécurité", async ({ request }) => {
    const h = (await request.get("/")).headers();
    expect(h["x-content-type-options"]).toBe("nosniff");
    expect(h["strict-transport-security"]).toContain("max-age");
    expect(h["x-frame-options"]).toBe("SAMEORIGIN");
  });
  test("métadonnées Open Graph et canonical", async ({ page }) => {
    await page.goto("/legal/conditions");
    await expect(page.locator('link[rel="canonical"]')).toHaveAttribute("href", /\/legal\/conditions$/);
    await page.goto("/");
    await expect(page.locator('meta[property="og:site_name"]')).toHaveAttribute("content", "WiFiMarket");
    await expect(page.locator('link[rel="manifest"]')).toHaveCount(1);
  });
  test("page 404 gérée", async ({ page }) => {
    const res = await page.goto("/cette-page-n-existe-pas");
    expect(res?.status()).toBe(404);
    await expect(page.getByRole("heading", { level: 1 })).toContainText("introuvable");
  });
});
