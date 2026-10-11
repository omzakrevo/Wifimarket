/**
 * Redimensionne et ré-encode une image côté navigateur (max 1280 px, WebP/JPEG).
 * Le ré-encodage via <canvas> supprime les métadonnées EXIF (dont la géolocalisation) et vérifie
 * que le fichier est réellement une image décodable. Hors navigateur ou sans canvas, renvoie le fichier d'origine.
 */
export async function compressImage(file: File, maxSide = 1280, quality = 0.82): Promise<Blob> {
  if (!file.type.startsWith("image/")) throw new Error("not_image");
  const bitmap = await createImageBitmap(file, { imageOrientation: "from-image" });
  const scale = Math.min(1, maxSide / Math.max(bitmap.width, bitmap.height));
  const w = Math.max(1, Math.round(bitmap.width * scale));
  const h = Math.max(1, Math.round(bitmap.height * scale));
  const canvas = document.createElement("canvas");
  canvas.width = w; canvas.height = h;
  const ctx = canvas.getContext("2d");
  if (!ctx) throw new Error("no_canvas");
  ctx.drawImage(bitmap, 0, 0, w, h);
  bitmap.close?.();
  const blob: Blob | null = await new Promise((res) => canvas.toBlob(res, "image/webp", quality));
  if (blob && blob.type === "image/webp") return blob;
  const jpeg: Blob | null = await new Promise((res) => canvas.toBlob(res, "image/jpeg", quality));
  if (!jpeg) throw new Error("encode_failed");
  return jpeg;
}

export const MAX_VIDEO_BYTES = 50 * 1024 * 1024;
export const ALLOWED_VIDEO = ["video/mp4", "video/webm"];
