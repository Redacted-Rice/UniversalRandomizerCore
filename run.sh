#!/usr/bin/env bash
# Run tests, coverage, or static analysis with Lua 5.2 (matches Luaj 3.x used by URJava).
# Usage: ./run.sh [-t|-c|-s] [busted args...]
#   -t  run tests (default)
#   -c  run tests with coverage
#   -s  run luacheck static analysis
set -euo pipefail

cd "$(dirname "$0")"

MODE="test"
ARGS=()

while [[ $# -gt 0 ]]; do
	case "$1" in
		-t)
			MODE="test"
			shift
			;;
		-c)
			MODE="coverage"
			shift
			;;
		-s)
			MODE="static"
			shift
			;;
		*)
			ARGS+=("$1")
			shift
			;;
	esac
done

# Use local Lua 5.2 install when present (override with LUA52_ROOT)
LUA52_ROOT="${LUA52_ROOT:-${HOME}/.lua52}"
if [[ -x "${LUA52_ROOT}/bin/lua5.2" ]] || [[ -x "${LUA52_ROOT}/bin/lua52" ]]; then
	export PATH="${LUA52_ROOT}/bin:${LUA52_ROOT}/lib:${PATH}"
fi

if ! command -v lua5.2 >/dev/null 2>&1 && ! command -v lua52 >/dev/null 2>&1; then
	echo "lua5.2 not found. On Debian/Ubuntu: sudo apt install lua5.2 liblua5.2-dev" >&2
	echo "Or install Lua 5.2 and set LUA52_ROOT." >&2
	exit 1
fi

eval "$(luarocks path --lua-version=5.2)"
export LUA_PATH="${LUA_PATH};./?.lua;./?/init.lua"
export LUA_CPATH="${LUA_CPATH};./?.dll"

case "${MODE}" in
	static)
		if ! command -v luacheck >/dev/null 2>&1; then
			echo "luacheck not found for Lua 5.2. Install dev tools:" >&2
			echo "  luarocks install --lua-version=5.2 --local luacheck" >&2
			exit 1
		fi
		if [[ ${#ARGS[@]} -eq 0 ]]; then
			exec luacheck .
		else
			exec luacheck "${ARGS[@]}"
		fi
		;;
	coverage)
		if ! command -v busted >/dev/null 2>&1; then
			echo "busted not found for Lua 5.2. Install dev tools:" >&2
			echo "  luarocks install --lua-version=5.2 --local busted" >&2
			echo "  luarocks install --lua-version=5.2 --local luacov" >&2
			echo "  luarocks install --lua-version=5.2 --local luacheck" >&2
			exit 1
		fi
		exec busted --coverage "${ARGS[@]}"
		;;
	test)
		if ! command -v busted >/dev/null 2>&1; then
			echo "busted not found for Lua 5.2. Install dev tools:" >&2
			echo "  luarocks install --lua-version=5.2 --local busted" >&2
			echo "  luarocks install --lua-version=5.2 --local luacov" >&2
			echo "  luarocks install --lua-version=5.2 --local luacheck" >&2
			exit 1
		fi
		exec busted "${ARGS[@]}"
		;;
esac
