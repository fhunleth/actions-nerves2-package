#!/usr/bin/env bash
set -euo pipefail

if [[ "${GITHUB_REF_TYPE:-}" != "tag" ]]; then
  echo "::error::Hex publishing requires a tagged release"
  exit 1
fi

unset MIX_OS_DEPS_COMPILE_PARTITION_COUNT

cp deploy/system/checksum.exs checksum.exs
mix local.hex --force
mix deps.get

# Documentation may fetch artifacts, which must be publicly downloadable first.
gh release edit "$GITHUB_REF_NAME" --draft=false
mix nerves.artifact.get
# Finish Nerves compilation before Hex snapshots code paths for publishing docs.
mix docs
mix hex.publish --yes
