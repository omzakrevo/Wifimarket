import { Card } from "@/components/ui/card";

export function AuthShell({ title, children, footer }: { title: string; children: React.ReactNode; footer?: React.ReactNode }) {
  return (
    <div className="mx-auto w-full max-w-md px-4 py-8">
      <Card className="p-6">
        <h1 className="mb-5 text-2xl font-bold text-navy dark:text-foreground">{title}</h1>
        {children}
      </Card>
      {footer && <p className="mt-4 text-center text-sm">{footer}</p>}
    </div>
  );
}
