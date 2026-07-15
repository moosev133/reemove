#!/usr/bin/env python3
import argparse, subprocess, pathlib, re

p = argparse.ArgumentParser()
p.add_argument('--from-tag', required=True)
p.add_argument('--to', default='HEAD')
p.add_argument('--version', required=True)
p.add_argument('--output', default='release_evidence/release-notes.md')
a = p.parse_args()
log = subprocess.check_output(['git','log','--pretty=format:%s',f'{a.from_tag}..{a.to}'], text=True)
items=[]
for line in log.splitlines():
    line=re.sub(r'^(feat|fix|perf|refactor|docs|test|chore)(\([^)]*\))?!?:\s*','',line,flags=re.I).strip()
    if line and not line.lower().startswith(('merge ', 'release ')):
        items.append(line)
out=pathlib.Path(a.output); out.parent.mkdir(parents=True,exist_ok=True)
out.write_text(f'# ReeMove {a.version}\n\n' + ''.join(f'- {x}\n' for x in items), encoding='utf-8')
print(out)
