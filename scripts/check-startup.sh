#!/bin/zsh
set -eu
project_dir="${0:A:h:h}"
check_dir="$(mktemp -d /private/tmp/gaibreanno-startup-checks.XXXXXX)"
trap 'rm -rf "$check_dir"' EXIT
swiftc -module-cache-path "$check_dir/module-cache" "$project_dir/Gaibreanno/Config/GaibreannoLegacyStartupCleanup.swift" "$project_dir/Tests/GaibreannoStartupChecks.swift" -o "$check_dir/startup-checks"
"$check_dir/startup-checks"
