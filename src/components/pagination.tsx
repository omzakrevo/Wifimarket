import Link from "next/link";
import { ChevronLeft, ChevronRight } from "lucide-react";

export function Pagination({ page, total, pageSize, params, basePath, prev, next }: {
  page: number; total: number; pageSize: number; params: Record<string, string | undefined>; basePath: string; prev: string; next: string;
}) {
  const pages = Math.ceil(total / pageSize);
  if (pages <= 1) return null;
  const href = (p: number) => {
    const sp = new URLSearchParams(Object.entries({ ...params, page: String(p) }).filter(([, v]) => v) as [string, string][]);
    return `${basePath}?${sp.toString()}`;
  };
  return (
    <nav className="mt-6 flex items-center justify-center gap-3 text-sm" aria-label="Pagination">
      {page > 1 && <Link className="inline-flex items-center gap-1 rounded-lg border border-border bg-card px-3 py-2 font-semibold hover:bg-brand-soft/60" href={href(page - 1)} rel="prev"><ChevronLeft size={14} />{prev}</Link>}
      <span className="text-muted">{page} / {pages}</span>
      {page < pages && <Link className="inline-flex items-center gap-1 rounded-lg border border-border bg-card px-3 py-2 font-semibold hover:bg-brand-soft/60" href={href(page + 1)} rel="next">{next}<ChevronRight size={14} /></Link>}
    </nav>
  );
}
