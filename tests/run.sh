#!/usr/bin/env bash
# Runs the headless Lua specs. From the repository root:
#
#     tests/run.sh              all specs
#     tests/run.sh spells       only specs whose name matches
#
# Needs luajit (apt-get install luajit). LuaJIT and not lua5.1: the client
# builds with LUAJIT=ON, so `goto` and labels are valid in module code.

set -uo pipefail

cd "$(dirname "$0")/.."

if ! command -v luajit >/dev/null 2>&1; then
    echo "luajit not found -- install it with: sudo apt-get install -y luajit" >&2
    exit 2
fi

FILTER="${1:-}"
failed=0
ran=0

for spec in tests/lua/*_spec.lua; do
    name="$(basename "$spec" _spec.lua)"
    if [ -n "$FILTER" ] && [[ "$name" != *"$FILTER"* ]]; then
        continue
    fi

    ran=$((ran + 1))
    echo "$name"
    # LUA_PATH so specs can `require('harness')` regardless of the caller's cwd.
    if ! LUA_PATH="tests/lua/?.lua;;" luajit -e "
        local t = dofile('$spec')
        os.exit(t.report('$name') and 0 or 1)
    "; then
        failed=$((failed + 1))
    fi
done

if [ "$ran" -eq 0 ]; then
    echo "no specs matched '${FILTER}'" >&2
    exit 2
fi

if [ "$failed" -ne 0 ]; then
    echo
    echo "$failed spec file(s) FAILED"
    exit 1
fi

echo
echo "all specs passed"
