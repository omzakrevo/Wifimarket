import type { Condition } from "./utils";

export type Country = { code: string; name_fr: string; name_en: string; currency_code: string; phone_prefix: string | null; enabled: boolean };
export type Currency = { code: string; name: string; symbol: string; decimals: number; enabled: boolean };
export type Category = { id: number; parent_id: number | null; slug: string; name_fr: string; name_en: string; icon: string | null; sort_order: number; enabled: boolean };
export type Brand = { id: number; slug: string; name: string; enabled: boolean };
export type ProductModel = { id: number; brand_id: number; category_id: number | null; name: string; specs: Record<string, string> };

export type Profile = {
  id: string; display_name: string; avatar_url: string | null; bio: string | null; country_code: string | null; city: string | null;
  show_whatsapp: boolean; verification_status: "unverified" | "pending" | "verified" | "rejected"; is_suspended: boolean; created_at: string;
};

export type ListingStatus = "draft" | "pending_review" | "active" | "paused" | "sold" | "rejected" | "expired" | "removed";

export type Listing = {
  id: string; seller_id: string; shop_id: string | null; category_id: number; brand_id: number | null; model_id: number | null; model_text: string | null;
  title: string; slug: string; description: string; condition: Condition; price: number; currency_code: string; quantity: number;
  country_code: string; city: string | null; delivery_available: boolean; defects: string | null; warranty: string | null;
  negotiable: boolean; exchange_possible: boolean; exchange_wanted: string | null; status: ListingStatus; rejection_reason: string | null;
  is_sponsored: boolean; sponsored_until: string | null; views_count: number; published_at: string | null; expires_at: string | null;
  created_at: string; updated_at: string; is_demo: boolean;
};

export type ListingMedia = { id: string; listing_id: string; kind: "image" | "video"; storage_path: string; position: number };

export type ListingCard = Listing & {
  listing_media: Pick<ListingMedia, "storage_path" | "kind" | "position">[];
  categories: Pick<Category, "slug" | "name_fr" | "name_en" | "icon"> | null;
  brands: Pick<Brand, "name" | "slug"> | null;
  profiles: Pick<Profile, "id" | "display_name" | "verification_status"> | null;
};

export type Shop = {
  id: string; owner_id: string; slug: string; name: string; description: string | null; logo_url: string | null; banner_url: string | null;
  country_code: string | null; city: string | null; plan: "free" | "pro" | "premium"; verification_status: Profile["verification_status"]; is_active: boolean; created_at: string;
};

export type WantedRequest = {
  id: string; requester_id: string; title: string; category_id: number | null; brand_id: number | null; model_text: string | null;
  condition_wanted: Condition | "any" | null; budget: number | null; currency_code: string | null; country_code: string; city: string | null;
  description: string; status: "open" | "fulfilled" | "closed" | "removed"; created_at: string;
};
