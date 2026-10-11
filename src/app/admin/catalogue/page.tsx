import { Card, PageTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input, Select } from "@/components/ui/form";
import { ActionButton } from "@/components/action-button";
import { addBrand, addCategory, addModel, deleteBrand, deleteCategory, toggleBrand, toggleCategory } from "@/app/actions/admin";
import { getT } from "@/lib/i18n";
import { createClient } from "@/lib/supabase/server";

export default async function AdminCatalog() {
  const { t } = await getT();
  const supabase = await createClient();
  const [{ data: cats }, { data: brands }, { data: models }] = await Promise.all([
    supabase.from("categories").select("*").order("sort_order").order("name_fr"),
    supabase.from("brands").select("*").order("name"),
    supabase.from("product_models").select("id,name,brands(name)").order("name").limit(200),
  ]);
  const tops = (cats ?? []).filter((c) => !c.parent_id);
  return (
    <div className="grid gap-8 lg:grid-cols-2">
      <section>
        <PageTitle>{t("admin.categories")}</PageTitle>
        <form action={addCategory} className="mb-4 grid grid-cols-2 gap-2 rounded-xl border border-border bg-card p-3">
          <Input name="slug" placeholder="slug-ex" required pattern="[a-z0-9-]{2,60}" aria-label="slug" />
          <Select name="parent_id" defaultValue="" aria-label={t("admin.parent")}><option value="">{t("admin.top_level")}</option>{tops.map((c) => <option key={c.id} value={c.id}>{c.name_fr}</option>)}</Select>
          <Input name="name_fr" placeholder="Nom (FR)" required aria-label="Nom FR" /><Input name="name_en" placeholder="Name (EN)" required aria-label="Name EN" />
          <Button type="submit" className="col-span-2">{t("admin.add")}</Button>
        </form>
        <ul className="space-y-1">
          {tops.map((top) => (
            <li key={top.id}>
              <Card className="p-2"><div className="flex items-center justify-between gap-2"><strong>{top.name_fr}</strong>
                <span className="flex gap-1"><ActionButton variant="outline" action={toggleCategory.bind(null, top.id, !top.enabled)}>{top.enabled ? t("admin.disable") : t("admin.enable")}</ActionButton><ActionButton variant="ghost" confirm={t("admin.confirm_delete")} action={deleteCategory.bind(null, top.id)}>🗑</ActionButton></span></div>
                <ul className="mt-1 space-y-1 pl-4 text-sm">
                  {(cats ?? []).filter((c) => c.parent_id === top.id).map((c) => (
                    <li key={c.id} className="flex items-center justify-between gap-2"><span className={c.enabled ? "" : "text-muted line-through"}>{c.name_fr}</span>
                      <span className="flex gap-1"><ActionButton variant="outline" action={toggleCategory.bind(null, c.id, !c.enabled)}>{c.enabled ? t("admin.disable") : t("admin.enable")}</ActionButton><ActionButton variant="ghost" confirm={t("admin.confirm_delete")} action={deleteCategory.bind(null, c.id)}>🗑</ActionButton></span></li>
                  ))}
                </ul>
              </Card>
            </li>
          ))}
        </ul>
      </section>
      <section>
        <PageTitle>{t("admin.brands")}</PageTitle>
        <form action={addBrand} className="mb-4 flex gap-2"><Input name="name" placeholder="Ubiquiti" required aria-label={t("common.brand")} /><Button type="submit">{t("admin.add")}</Button></form>
        <ul className="mb-8 space-y-1">
          {(brands ?? []).map((b) => (
            <li key={b.id} className="flex items-center justify-between gap-2 rounded-lg border border-border bg-card px-3 py-1.5 text-sm"><span className={b.enabled ? "" : "text-muted line-through"}>{b.name}</span>
              <span className="flex gap-1"><ActionButton variant="outline" action={toggleBrand.bind(null, b.id, !b.enabled)}>{b.enabled ? t("admin.disable") : t("admin.enable")}</ActionButton><ActionButton variant="ghost" confirm={t("admin.confirm_delete")} action={deleteBrand.bind(null, b.id)}>🗑</ActionButton></span></li>
          ))}
        </ul>
        <PageTitle>{t("admin.models")}</PageTitle>
        <form action={addModel} className="mb-3 grid grid-cols-2 gap-2 rounded-xl border border-border bg-card p-3">
          <Select name="brand_id" required aria-label={t("common.brand")} defaultValue="">{<option value="" disabled>{t("common.brand")}</option>}{(brands ?? []).map((b) => <option key={b.id} value={b.id}>{b.name}</option>)}</Select>
          <Select name="category_id" aria-label={t("common.category")} defaultValue=""><option value="">—</option>{(cats ?? []).filter((c) => c.parent_id).map((c) => <option key={c.id} value={c.id}>{c.name_fr}</option>)}</Select>
          <Input name="name" placeholder="LiteBeam 5AC" required className="col-span-2" aria-label={t("listing.model")} />
          <Button type="submit" className="col-span-2">{t("admin.add")}</Button>
        </form>
        <ul className="text-sm text-muted">{(models ?? []).map((m) => <li key={m.id}>{(m.brands as unknown as { name: string } | null)?.name} — {m.name}</li>)}</ul>
      </section>
    </div>
  );
}
