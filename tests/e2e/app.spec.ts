import { expect, test, type Page } from "@playwright/test";

/**
 * Parcours complets contre un VRAI projet Supabase (migrations + supabase/seed_demo.sql appliqués).
 * Exécution : E2E_SUPABASE=1 NEXT_PUBLIC_SUPABASE_URL=... NEXT_PUBLIC_SUPABASE_ANON_KEY=... npm run build && npm run test:e2e
 * Comptes de démo : <nom>@demo.wifimarket.test / Demo!2345 (demo_buyer, ibrahim, demo_admin…).
 */
test.skip(!process.env.E2E_SUPABASE, "nécessite un projet Supabase configuré (E2E_SUPABASE=1)");
test.describe.configure({ mode: "serial" });

const PASSWORD = "Demo!2345";

async function login(page: Page, user: string, next = "/compte") {
  await page.goto(`/connexion?next=${encodeURIComponent(next)}`);
  await page.getByLabel("Adresse e-mail").fill(`${user}@demo.wifimarket.test`);
  await page.getByLabel("Mot de passe").fill(PASSWORD);
  await page.locator("form").getByRole("button", { name: "Connexion" }).click();
  await expect(page).toHaveURL(new RegExp(next.replace(/[/?]/g, "\\$&")));
}

test("inscription", async ({ page }) => {
  const email = `e2e-${Date.now()}@demo.wifimarket.test`;
  await page.goto("/inscription");
  await page.getByLabel("Nom affiché").fill("Testeur E2E");
  await page.getByLabel("Adresse e-mail").fill(email);
  await page.getByLabel("Mot de passe").fill(PASSWORD);
  await page.getByRole("checkbox").check();
  await page.getByRole("button", { name: "Créer un compte" }).click();
  // Selon le réglage « confirmation e-mail » du projet : redirection directe ou message
  await expect(page.getByText(/Bonjour Testeur E2E|Compte créé/)).toBeVisible();
});

test("connexion, recherche, filtres, favori", async ({ page }) => {
  await login(page, "demo_buyer");
  await page.goto("/recherche?q=litebeam");
  await expect(page.getByRole("article")).toHaveCount(1);
  await page.goto("/recherche?currency=XOF&min=40000&max=50000&sort=price_asc");
  expect(await page.getByRole("article").count()).toBeGreaterThanOrEqual(2);
  await page.goto("/recherche?q=nanostation");
  await page.getByRole("article").first().getByRole("button", { name: "Ajouter aux favoris" }).click();
  await page.goto("/compte/favoris");
  await expect(page.getByRole("article")).toHaveCount(1);
});

test("fiche produit : boutons et données structurées", async ({ page }) => {
  await login(page, "demo_buyer");
  await page.goto("/recherche?q=litebeam");
  await page.getByRole("article").first().getByRole("link").first().click();
  for (const name of ["Contacter", "Acheter", "Partager", "Signaler"]) await expect(page.getByRole("button", { name })).toBeVisible();
  const ld = await page.locator('script[type="application/ld+json"]').first().textContent();
  expect(JSON.parse(ld!)["@type"]).toBe("Product");
});

test("messagerie : envoi d'un message à un vendeur", async ({ page }) => {
  await login(page, "demo_buyer");
  await page.goto("/messages");
  await page.getByRole("link", { name: /Ibrahim/ }).first().click();
  const text = `Bonjour E2E ${Date.now()}`;
  await page.getByPlaceholder("Écrivez votre message…").fill(text);
  await page.getByRole("button", { name: "Envoyer", exact: true }).click();
  await expect(page.getByText(text)).toBeVisible();
});

test("publication d'une annonce (brouillon puis publication)", async ({ page }) => {
  await login(page, "demo_buyer", "/vendre");
  await page.getByLabel("Catégorie").selectOption({ label: "Switchs" });
  await page.getByLabel("Titre de l'annonce").fill(`Switch test E2E ${Date.now()}`);
  await page.getByLabel("Prix", { exact: true }).fill("12000");
  await page.getByRole("button", { name: "Enregistrer le brouillon" }).click();
  await expect(page.getByText("Brouillon enregistré.")).toBeVisible();
  await page.getByRole("button", { name: "Publier l'annonce" }).click();
  await expect(page).toHaveURL(/\/annonces\//);
});

test("commande : panier → retrait → vue vendeur", async ({ page, browser }) => {
  await login(page, "demo_buyer");
  await page.goto("/recherche?q=hap");
  await page.getByRole("article").first().getByRole("link").first().click();
  await page.getByRole("button", { name: "Acheter" }).click();
  await expect(page).toHaveURL(/\/panier/);
  await page.getByRole("link", { name: "Passer la commande" }).click();
  await page.getByRole("button", { name: "Confirmer la commande" }).click();
  await expect(page).toHaveURL(/\/compte\/commandes\?placed=1/);
  const seller = await browser.newPage();
  await login(seller, "ibrahim", "/compte/commandes");
  await expect(seller.getByRole("button", { name: "Confirmer la commande" }).first()).toBeVisible();
  await seller.close();
});

test("administration : refus pour un simple utilisateur, accès pour l'admin", async ({ page }) => {
  await login(page, "demo_buyer");
  await page.goto("/admin");
  await expect(page).not.toHaveURL(/\/admin/);
  await page.context().clearCookies();
  await login(page, "demo_admin", "/admin");
  await expect(page.getByRole("heading", { name: "Tableau de bord" })).toBeVisible();
  await page.goto("/admin/annonces?status=all");
  await expect(page.getByRole("button", { name: "Retirer" }).first()).toBeVisible();
});
