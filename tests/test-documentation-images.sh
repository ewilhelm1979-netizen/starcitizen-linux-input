#!/usr/bin/env bash
set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$root"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

svg=docs/images/citizen-input-manager-overview.svg
[[ -f $svg && ! -L $svg ]] || fail 'architecture SVG is not a regular file'
[[ $(stat -c '%h' "$svg") -eq 1 ]] || fail 'architecture SVG has multiple links'
xmllint --noout "$svg"
[[ $(xmllint --xpath 'count(/*[local-name()="svg"]/*[local-name()="title"])' "$svg") == 1 ]] ||
  fail 'architecture SVG title count'
[[ $(xmllint --xpath 'count(/*[local-name()="svg"]/*[local-name()="desc"])' "$svg") == 1 ]] ||
  fail 'architecture SVG description count'

private_user="$(printf '%s%s' enrico w79)"
private_marker='H''y3'
if rg -ni "<!DOCTYPE|<!ENTITY|<script\\b|\\son[a-z]+\\s*=|\\b(xlink:)?href\\s*=|<image\\b|base64|/home/|/mnt/|file://|${private_user}|${private_marker}" "$svg"; then
  fail 'unsafe SVG content'
fi
local_hostname=
if [[ -r /proc/sys/kernel/hostname ]]; then
  IFS= read -r local_hostname </proc/sys/kernel/hostname
fi
if [[ -n $local_hostname ]] && rg -Fi "$local_hostname" "$svg"; then
  fail 'local hostname found in architecture SVG'
fi

python3 - "$root" "$svg" <<'PY'
import pathlib
import re
import sys
import xml.etree.ElementTree as ET
from urllib.parse import unquote

root = pathlib.Path(sys.argv[1]).resolve()
svg = root / sys.argv[2]
tree = ET.parse(svg)
allowed = {"svg", "title", "desc", "rect", "circle", "line", "path", "text"}
external = re.compile(r"(?:https?://|file:|data:|url\s*\()", re.IGNORECASE)
for element in tree.iter():
    name = element.tag.rsplit("}", 1)[-1]
    if name not in allowed:
        raise SystemExit(f"disallowed SVG element: {name}")
    for attribute, value in element.attrib.items():
        local = attribute.rsplit("}", 1)[-1].lower()
        if local in {"href", "xlink:href"} or local.startswith("on"):
            raise SystemExit(f"disallowed SVG attribute: {local}")
        if external.search(value):
            raise SystemExit(f"external SVG attribute value: {local}")

image_pattern = re.compile(r"!\[[^]]*\]\(([^)]+)\)")
link_pattern = re.compile(r"(?<!!)\[[^]]+\]\(([^)]+)\)")
scheme = re.compile(r"^[A-Za-z][A-Za-z0-9+.-]*:")
for document in sorted(root.rglob("*.md")):
    text = document.read_text(encoding="utf-8")
    for raw_target in image_pattern.findall(text):
        target = raw_target.strip().split()[0].strip("<>")
        if scheme.match(target):
            raise SystemExit(f"external Markdown image: {document}: {target}")
        local = unquote(target.split("#", 1)[0].split("?", 1)[0])
        resolved = (document.parent / local).resolve()
        if not resolved.is_relative_to(root) or not resolved.is_file():
            raise SystemExit(f"unresolved Markdown image: {document}: {target}")
    for raw_target in link_pattern.findall(text):
        target = raw_target.strip().split()[0].strip("<>")
        if not target or target.startswith("#") or scheme.match(target):
            continue
        local = unquote(target.split("#", 1)[0].split("?", 1)[0])
        if not local:
            continue
        resolved = (document.parent / local).resolve()
        if not resolved.is_relative_to(root) or not resolved.exists():
            raise SystemExit(f"unresolved Markdown link: {document}: {target}")
PY

(cd docs/images && sha256sum --check SHA256SUMS >/dev/null) || fail 'architecture image checksum'
rg -F '](docs/images/citizen-input-manager-overview.svg)' README.md >/dev/null ||
  fail 'README architecture image reference'
rg -F '](images/citizen-input-manager-overview.svg)' docs/architecture.md >/dev/null ||
  fail 'architecture page image reference'
rg -F 'substantial assistance from OpenAI Codex' docs/images/README.md >/dev/null ||
  fail 'architecture image AI provenance'
rg -F 'The human maintainer' docs/images/README.md >/dev/null ||
  fail 'architecture image human responsibility'
rg -F 'Repository content, code comments, commit messages, and review replies must be' CONTRIBUTING.md >/dev/null ||
  fail 'English repository policy'
rg -F 'in English. Keep the AI-assistance disclosure' CONTRIBUTING.md >/dev/null ||
  fail 'English repository policy continuation'

jq -e '.support == {"nativeLinux":"tested","hidrawUaccess":"tested","wine":"tested","starCitizen":"tested"}' \
  manifests/3dconnexion/spacemouse-wireless-usb.json >/dev/null || fail 'SpaceMouse support state changed'
jq -e '.support == {"nativeLinux":"tested","hidrawUaccess":"candidate","wine":"tested","starCitizen":"tested"}' \
  manifests/saitek/x56-rhino.json >/dev/null || fail 'X-56 support state changed inconsistently'
if find . -type f \( -name '*.xml' -o -name 'actionmaps.xml' \) -print -quit | grep -q .; then
  fail 'unexpected Star Citizen controller profile'
fi

printf 'PASS: architecture SVG security, accessibility, documentation, and support boundaries\n'
