#!/usr/bin/env node
// Vérifie que toutes les clés t("...") utilisées dans le code existent dans src/lib/i18n/messages.ts (FR + EN non vides).
import { readFileSync, readdirSync, statSync } from "node:fs";
import { join } from "node:path";

const root = new URL("../src", import.meta.url).pathname;
const files = [];
(function walk(d) { for (const f of readdirSync(d)) { const p = join(d, f); statSync(p).isDirectory() ? walk(p) : /\.(ts|tsx)$/.test(f) && files.push(p); } })(root);

const msgSrc = readFileSync(join(root, "lib/i18n/messages.ts"), "utf8");
const defined = new Map([...msgSrc.matchAll(/^\s*"([^"]+)":\s*\[\s*("(?:[^"\\]|\\.)*"|`[^`]*`)\s*,\s*("(?:[^"\\]|\\.)*"|`[^`]*`)\s*\]/gm)].map((m) => [m[1], [m[2], m[3]]]));

const used = new Map();
const dyn = new Map();
for (const f of files) {
  if (f.endsWith("messages.ts")) continue;
  const src = readFileSync(f, "utf8");
  for (const m of src.matchAll(/\bt\(\s*"([a-zA-Z0-9_.]+)"/g)) used.set(m[1], f);
  for (const m of src.matchAll(/\bt\(\s*`([a-zA-Z0-9_.]+)\$\{/g)) dyn.set(m[1], f);
  for (const m of src.matchAll(/(?:error|message|label)\s*[:=]\s*"((?:auth|err|profile|nego|report|wanted)\.[a-zA-Z0-9_.]+)"/g)) used.set(m[1], f);
  for (const m of src.matchAll(/\{\s*(?:error|message):\s*"((?:auth|err|profile|nego|report|wanted)\.[a-zA-Z0-9_.]+)"/g)) used.set(m[1], f);
}
let bad = 0;
for (const [k, f] of used) if (!defined.has(k)) { console.log(`MANQUANTE  ${k}   (${f.replace(root, "src")})`); bad++; }
for (const [k, v] of defined) if (v.some((s) => s.length <= 2)) { console.log(`VIDE       ${k}`); bad++; }
if (process.argv.includes("--dynamic")) for (const [k, f] of dyn) console.log(`dynamique  ${k}*   (${f.replace(root, "src")})`);
console.log(`${defined.size} clés définies, ${used.size} clés statiques utilisées, ${bad} problème(s)`);
process.exit(bad ? 1 : 0);
