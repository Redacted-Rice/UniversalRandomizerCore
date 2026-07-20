@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"

REM Run UniversalRandomizerCore tests with Lua 5.2 (officially supported version)

set "LUA52_BIN="
for /f "delims=" %%P in ('where lua52 2^>nul') do (
	if not defined LUA52_BIN set "LUA52_BIN=%%P"
)
if not defined LUA52_BIN (
	for /f "delims=" %%P in ('where lua5.2 2^>nul') do (
		if not defined LUA52_BIN set "LUA52_BIN=%%P"
	)
)
if not defined LUA52_BIN (
	echo lua5.2 not found. Install Lua 5.2 and add lua52 to PATH. 1>&2
	exit /b 1
)

REM Use Lua 5.2 rocks only. Do not inherit LUA_PATH/LUA_CPATH from Lua 5.4.
set "LUA_PATH=%APPDATA%\luarocks\share\lua\5.2\?.lua;%APPDATA%\luarocks\share\lua\5.2\?\init.lua;.\?.lua;.\?\init.lua"
set "LUA_CPATH=%APPDATA%\luarocks\lib\lua\5.2\?.dll;.\?.dll"

set "BUSTED_SCRIPT="
for /f "delims=" %%D in ('dir /b /ad "%APPDATA%\luarocks\lib\luarocks\rocks-5.2\busted" 2^>nul') do (
	set "BUSTED_SCRIPT=%APPDATA%\luarocks\lib\luarocks\rocks-5.2\busted\%%D\bin\busted"
)
if not exist "!BUSTED_SCRIPT!" (
	echo busted not found for Lua 5.2. Install dev tools: 1>&2
	echo   luarocks install --lua-version=5.2 --local busted 1>&2
	echo   luarocks install --lua-version=5.2 --local luacov 1>&2
	echo   luarocks install --lua-version=5.2 --local luacheck 1>&2
	exit /b 1
)

"!LUA52_BIN!" "!BUSTED_SCRIPT!" %*
exit /b %ERRORLEVEL%
