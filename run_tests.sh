#!/usr/bin/env bash
# Run UniversalRandomizerCore tests with Lua 5.2 (matches Luaj 3.x used by URJava).
set -euo pipefail

cd "$(dirname "$0")"

if ! command -v lua5.2 >/dev/null 2>&1; then
	echo "lua5.2 not found. On Debian/Ubuntu: sudo apt install lua5.2 liblua5.2-dev" >&2
	exit 1
fi

eval "$(luarocks path --lua-version=5.2)"

if ! command -v busted >/dev/null 2>&1; then
	echo "busted not found for Lua 5.2. Install dev tools:" >&2
	echo "  luarocks install --lua-version=5.2 --local busted" >&2
	echo "  luarocks install --lua-version=5.2 --local luacov" >&2
	echo "  luarocks install --lua-version=5.2 --local luacheck" >&2
	exit 1
fi

exec busted "$@"
