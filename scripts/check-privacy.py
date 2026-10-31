#!/usr/bin/env python3
"""Check publishable files without printing matched values. Not a full secret scanner."""
import argparse
import pathlib
import re
import subprocess
import sys


def git(*args):
    return subprocess.check_output(['git', *args])


parser = argparse.ArgumentParser()
parser.add_argument('--ref', help='Check a committed tree before pushing')
args = parser.parse_args()
root = pathlib.Path(git('rev-parse', '--show-toplevel').decode().strip())
if args.ref:
    paths = git('ls-tree', '-rz', '--name-only', args.ref).split(b'\0')
else:
    paths = git('ls-files', '-z', '--cached', '--others', '--exclude-standard').split(b'\0')

patterns = [
    ('private key', rb'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----'),
    ('GitHub token', rb'\b(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,})\b'),
    ('OpenAI key', rb'\bsk-(?:proj-)?[A-Za-z0-9_-]{40,}\b'),
    ('AWS key', rb'\b(?:AKIA|ASIA)[A-Z0-9]{16}\b'),
    ('local home path', rb'/(?:Users|home)/[A-Za-z0-9_.-]+/'),
    ('session cookie', rb'(?i)\b(?:SESSDATA|bili_jct)\s*[=:]\s*[\"\']?[A-Za-z0-9%_-]{16,}'),
]
issues = []
for raw in sorted(set(paths)):
    if not raw:
        continue
    name = raw.decode()
    p = pathlib.PurePosixPath(name)
    if p.name == '.DS_Store' or p.suffix in {'.p12', '.p8', '.mobileprovision', '.log'} or p.name in {'.env', 'Local.xcconfig', 'ExportOptions.local.plist'} or 'private-assets' in p.parts:
        issues.append((name, 'private/local file'))
        continue
    if args.ref:
        data = git('show', f'{args.ref}:{name}')
    else:
        path = root / name
        if not path.is_file():
            continue
        data = path.read_bytes()
    if b'\0' in data:
        continue  # Images and binary metadata require manual review.
    for label, pattern in patterns:
        if re.search(pattern, data):
            issues.append((name, label))
    if p.suffix == '.pbxproj' and re.search(rb'DEVELOPMENT_TEAM\s*=\s*[A-Z0-9]{10}\s*;', data):
        issues.append((name, 'hard-coded signing team'))
    if name == 'config/ExportOptions.plist' and b'<key>teamID</key>' in data:
        issues.append((name, 'hard-coded export team'))
for name, label in issues:
    print(f'{name}: {label}', file=sys.stderr)
if issues:
    sys.exit(1)
print('Privacy checks passed. Review image content, metadata and commit identity separately.')
