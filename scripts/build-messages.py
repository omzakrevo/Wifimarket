#!/usr/bin/env python3
"""Génère src/lib/i18n/messages.ts à partir de scripts/messages.src.txt (format : clé | français | anglais)."""
import os
root = os.path.join(os.path.dirname(__file__), "..")
lines = [l.rstrip("\n") for l in open(os.path.join(root, "scripts/messages.src.txt"), encoding="utf-8") if l.strip() and not l.startswith("#")]
out = ["// Généré par scripts/build-messages.py depuis scripts/messages.src.txt — ne pas éditer à la main.",
       "// Chaque clé : [français, anglais]. Variables : {nom}.", "export const messages = {"]
seen = set()
q = lambda s: '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'
for l in lines:
    parts = [p.strip() for p in l.split(" | ")]
    assert len(parts) == 3, l
    k, fr, en = parts
    assert k not in seen, f"clé en double : {k}"
    seen.add(k)
    out.append(f'  "{k}": [{q(fr)}, {q(en)}],')
out += ["} as const satisfies Record<string, readonly [string, string]>;", "export type MessageKey = keyof typeof messages;"]
open(os.path.join(root, "src/lib/i18n/messages.ts"), "w", encoding="utf-8").write("\n".join(out) + "\n")
print(len(seen), "messages")
