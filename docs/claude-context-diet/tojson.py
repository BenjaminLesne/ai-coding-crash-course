#!/usr/bin/env python3
"""Strip // comments and trailing commas from a .jsonc file, print valid JSON.

    python3 tojson.py settings.catalogue.jsonc > ~/.claude/settings.json

Claude Code silently discards a settings.json containing comments, so the
.jsonc files in this directory must go through this script.
"""
import json, re, sys

src = open(sys.argv[1]).read()
out, in_str, esc = [], False, False
i = 0
while i < len(src):
    c = src[i]
    if in_str:
        out.append(c)
        if esc: esc = False
        elif c == '\\': esc = True
        elif c == '"': in_str = False
        i += 1
        continue
    if c == '"':
        in_str = True; out.append(c); i += 1; continue
    if c == '/' and src[i:i+2] == '//':
        while i < len(src) and src[i] != '\n': i += 1
        continue
    out.append(c); i += 1
stripped = ''.join(out)
stripped = re.sub(r',(\s*[}\]])', r'\1', stripped)
print(json.dumps(json.loads(stripped), indent=2))
