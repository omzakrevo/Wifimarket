#!/usr/bin/env python3
"""Génère lib/core/i18n/strings.g.dart depuis tool/strings.src.txt (format : clé | français | anglais)."""
import os
root = os.path.join(os.path.dirname(__file__), "..")
lines = [l.rstrip("\n") for l in open(os.path.join(root, "tool/strings.src.txt"), encoding="utf-8") if l.strip() and not l.startswith("#")]
def q(s): return "'" + s.replace("\\", "\\\\").replace("'", "\\'").replace("$", "\\$") + "'"
out = ["// GENERATED CODE - DO NOT EDIT. Source : tool/strings.src.txt (python3 tool/build_strings.py)", "const Map<String, List<String>> kStrings = {"]
seen = set()
for l in lines:
    parts = [p.strip() for p in l.split(" | ")]
    assert len(parts) == 3, l
    k, fr, en = parts
    assert k not in seen, f"clé en double : {k}"
    seen.add(k)
    out.append(f"  {q(k)}: [{q(fr)}, {q(en)}],")
out.append("};")
open(os.path.join(root, "lib/core/i18n/strings.g.dart"), "w", encoding="utf-8").write("\n".join(out) + "\n")
print(len(seen), "chaînes")
