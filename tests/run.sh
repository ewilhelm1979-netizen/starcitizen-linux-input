#!/usr/bin/env bash
set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$root"

while IFS= read -r script; do
  bash -n "$script"
done < <(find bin lib tests -type f \( -name '*.sh' -o -path 'bin/sc-input' -o -path 'bin/sc-input-gui' \) -print | sort)

shellcheck bin/sc-input bin/sc-input-gui lib/*.sh tests/*.sh tests/fixtures/*.sh
shfmt -d -i 2 -ci bin/sc-input bin/sc-input-gui lib/*.sh tests/*.sh tests/fixtures/*.sh

while IFS= read -r json; do
  jq empty "$json" >/dev/null
done < <(find manifests schemas -type f -name '*.json' -print | sort)

grep -F '## AI-assisted development' README.md >/dev/null
grep -F 'OpenAI Codex' README.md >/dev/null
grep -F 'The human maintainer remains responsible for architecture, implementation' README.md >/dev/null

tests/test-discovery.sh
tests/test-e2e.sh
tests/test-cli.sh
tests/test-cli-contracts.sh
tests/test-manifests.sh
tests/test-udev.sh
tests/test-gui-backend.sh
tests/test-gui-mocks.sh
tests/test-privacy.sh
tests/test-diagnostics.sh
tests/test-adversarial.sh
tests/test-documentation-images.sh
tests/test-ecosystem-attribution.sh
bash tests/test-documentation-onboarding.sh
python3 tests/property_fuzz.py
tests/test-nix.sh
tests/security-scan.sh

printf 'All tests passed.\n'
