import type { Metadata, Viewport } from "next";
import { ThemeProvider } from "next-themes";
import "./globals.css";
import { Header } from "@/components/layout/header";
import { Footer } from "@/components/layout/footer";
import { BottomNav } from "@/components/layout/bottom-nav";
import { PwaRegister } from "@/components/pwa-register";
import { I18nProvider } from "@/lib/i18n/client";
import { getLang } from "@/lib/i18n";
import { SITE_URL } from "@/lib/utils";

export const metadata: Metadata = {
  metadataBase: new URL(SITE_URL),
  title: { default: "WiFiMarket — Matériel Wi-Fi et réseau en Afrique de l'Ouest", template: "%s | WiFiMarket" },
  description:
    "La marketplace du matériel Wi-Fi, radio, Starlink et réseau : achetez, vendez, échangez du neuf et de l'occasion en Afrique de l'Ouest.",
  applicationName: "WiFiMarket",
  manifest: "/manifest.webmanifest",
  openGraph: { type: "website", siteName: "WiFiMarket", locale: "fr_FR", url: SITE_URL },
  twitter: { card: "summary_large_image" },
  appleWebApp: { capable: true, title: "WiFiMarket", statusBarStyle: "default" },
  alternates: { canonical: "/" },
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  themeColor: [{ media: "(prefers-color-scheme: light)", color: "#102A56" }, { media: "(prefers-color-scheme: dark)", color: "#0B1220" }],
};

export default async function RootLayout({ children }: { children: React.ReactNode }) {
  const lang = await getLang();
  return (
    <html lang={lang} suppressHydrationWarning>
      <body className="flex min-h-dvh flex-col pb-16 sm:pb-0">
        <ThemeProvider attribute="class" defaultTheme="system" enableSystem>
          <I18nProvider lang={lang}>
            <a href="#contenu" className="sr-only focus:not-sr-only focus:absolute focus:z-50 focus:bg-card focus:p-2">Aller au contenu</a>
            <Header />
            <main id="contenu" className="flex-1">{children}</main>
            <Footer />
            <BottomNav />
            <PwaRegister />
          </I18nProvider>
        </ThemeProvider>
      </body>
    </html>
  );
}
