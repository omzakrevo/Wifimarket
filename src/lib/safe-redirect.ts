/** N'autorise que les chemins internes (anti « open redirect »). */
export function safeNext(next: string | null | undefined, fallback = "/compte") {
  if (!next || !next.startsWith("/") || next.startsWith("//") || next.includes("\\")) return fallback;
  return next;
}
