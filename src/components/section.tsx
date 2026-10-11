import Link from "next/link";
import { ArrowRight } from "lucide-react";
import { Container } from "@/components/ui/card";

export function Section({ title, href, more, children }: { title: string; href?: string; more?: string; children: React.ReactNode }) {
  return (
    <section className="py-6">
      <Container>
        <div className="mb-3 flex items-end justify-between gap-3">
          <h2 className="text-lg font-bold text-navy dark:text-foreground sm:text-xl">{title}</h2>
          {href && <Link href={href} className="flex items-center gap-1 text-sm font-semibold text-brand hover:underline">{more}<ArrowRight size={14} /></Link>}
        </div>
        {children}
      </Container>
    </section>
  );
}
