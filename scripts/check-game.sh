#!/bin/zsh
set -eu
project_dir="${0:A:h:h}"
check_dir="$(mktemp -d /private/tmp/gaibreanno-checks.XXXXXX)"
trap 'rm -rf "$check_dir"' EXIT
swiftc -module-cache-path "$check_dir/module-cache" "$project_dir/Gaibreanno/Game/GameModel.swift" "$project_dir/Tests/GameEngineChecks.swift" -o "$check_dir/game-checks"
"$check_dir/game-checks"
