#!/usr/bin/env bash
set -euo pipefail

step=$1
shift
log_dir="${RUNNER_TEMP}/nerves-package-logs"
mkdir -p "$log_dir"
log_path="$log_dir/$step.log"

printf 'Running %s. Full output will be saved in the nerves-package-logs artifact.\n' "$step"

status=0
if [[ "$step" == "artifact-build" ]]; then
  "$@" > "$log_path" 2>&1 || status=$?
else
  "$@" 2>&1 | tee "$log_path" || status=$?
fi

if (( status == 0 )); then
  printf '%s completed successfully.\n' "$step"
else
  output=$(tail -n 100 "$log_path" | tail -c 16384 |
    sed -E 's/\x1B\[[0-9;]*[[:alpha:]]//g; s/\r//g')

  printf '::error::%s failed with exit status %s. See the nerves-package-logs artifact for full output.\n' "$step" "$status"
  if [[ "$step" == "artifact-build" ]]; then
    printf '%s\n' "$output"
  fi

  {
    printf '### Nerves package: %s failed\n\n' "$step"
    printf 'Exit status: **%s**. Full output: **%s.log** in the **nerves-package-logs** artifact.\n\n' "$status" "$step"
    printf 'Last output (up to 100 lines / 16 KiB):\n\n~~~text\n%s\n~~~\n\n' "$output"
  } >> "$GITHUB_STEP_SUMMARY"

  exit "$status"
fi
