import Link from "next/link";

export function LogoMark({ className = "h-8 w-8" }: { className?: string }) {
  return (
    <svg viewBox="0 0 48 48" className={className} aria-hidden="true">
      <rect width="48" height="48" rx="12" fill="#2563EB" />
      <path d="M10 20a20 20 0 0 1 28 0" stroke="#fff" strokeWidth="3.5" strokeLinecap="round" fill="none" />
      <path d="M15 26a13 13 0 0 1 18 0" stroke="#fff" strokeWidth="3.5" strokeLinecap="round" fill="none" />
      <path d="M20 32a6 6 0 0 1 8 0" stroke="#F59E0B" strokeWidth="3.5" strokeLinecap="round" fill="none" />
      <circle cx="24" cy="38" r="2.6" fill="#F59E0B" />
    </svg>
  );
}

export function Logo() {
  return (
    <Link href="/" className="flex items-center gap-2" aria-label="WiFiMarket">
      <LogoMark />
      <span className="text-lg font-extrabold tracking-tight text-navy dark:text-foreground">
        WiFi<span className="text-brand">Market</span>
      </span>
    </Link>
  );
}
