@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"

REM Run UniversalRandomizerCore tests with Lua 5.2 (officially supported version)

where lua52 >nul 2>&1
if errorlevel 1 (
	where lua5.2 >nul 2>&1
	if errorlevel 1 (
		echo lua5.2 not found. Install Lua 5.2 and add lua52 to PATH. 1>&2
		exit /b 1
	)
)

for /f "delims=" %%P in ('luarocks path --lua-version^=5.2 --lr-path') do set "LR_LUA_PATH=%%P"
for /f "delims=" %%P in ('luarocks path --lua-version^=5.2 --lr-cpath') do set "LR_LUA_CPATH=%%P"
for /f "delims=" %%P in ('luarocks path --lua-version^=5.2 --lr-bin') do set "LR_BIN=%%P"

set "LUA_PATH=!LR_LUA_PATH!;.\?.lua;.\?\init.lua"
set "LUA_CPATH=!LR_LUA_CPATH!;.\?.dll"
set "PATH=!LR_BIN!;!PATH!"

where busted >nul 2>&1
if errorlevel 1 (
	echo busted not found for Lua 5.2. Install dev tools: 1>&2
	echo   luarocks install --lua-version=5.2 --local busted 1>&2
	echo   luarocks install --lua-version=5.2 --local luacov 1>&2
	echo   luarocks install --lua-version=5.2 --local luacheck 1>&2
	exit /b 1
)

call busted %*
exit /b %ERRORLEVEL%
