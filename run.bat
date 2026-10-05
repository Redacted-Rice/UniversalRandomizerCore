@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"

REM Run tests, coverage, or static analysis with Lua 5.2 (officially supported version)
REM Usage: run.bat [-t|-c|-s] [busted args...]
REM   -t  run tests (default)
REM   -c  run tests with coverage
REM   -s  run luacheck static analysis

set "MODE=test"
set "ARGS="

:parse_args
if "%~1"=="" goto setup_env
if /i "%~1"=="-t" (
	set "MODE=test"
	shift
	goto parse_args
)
if /i "%~1"=="-c" (
	set "MODE=coverage"
	shift
	goto parse_args
)
if /i "%~1"=="-s" (
	set "MODE=static"
	shift
	goto parse_args
)
set "ARGS=!ARGS! %1"
shift
goto parse_args

:setup_env
REM Use local Lua 5.2 install when present (override with LUA52_ROOT)
if not defined LUA52_ROOT set "LUA52_ROOT=C:\Lua52"
if exist "!LUA52_ROOT!\bin\lua52.exe" (
	set "PATH=!LUA52_ROOT!\bin;!LUA52_ROOT!\lib;!PATH!"
)

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

if /i "!MODE!"=="static" goto run_static
if /i "!MODE!"=="coverage" goto run_coverage
goto run_tests

:run_static
where luacheck >nul 2>&1
if errorlevel 1 (
	echo luacheck not found for Lua 5.2. Install dev tools: 1>&2
	echo   luarocks install --lua-version=5.2 --local luacheck 1>&2
	exit /b 1
)
if "!ARGS!"=="" (
	call luacheck .
) else (
	call luacheck !ARGS!
)
exit /b %ERRORLEVEL%

:run_coverage
where busted >nul 2>&1
if errorlevel 1 (
	echo busted not found for Lua 5.2. Install dev tools: 1>&2
	echo   luarocks install --lua-version=5.2 --local busted 1>&2
	echo   luarocks install --lua-version=5.2 --local luacov 1>&2
	echo   luarocks install --lua-version=5.2 --local luacheck 1>&2
	exit /b 1
)
call busted --coverage !ARGS!
exit /b %ERRORLEVEL%

:run_tests
where busted >nul 2>&1
if errorlevel 1 (
	echo busted not found for Lua 5.2. Install dev tools: 1>&2
	echo   luarocks install --lua-version=5.2 --local busted 1>&2
	echo   luarocks install --lua-version=5.2 --local luacov 1>&2
	echo   luarocks install --lua-version=5.2 --local luacheck 1>&2
	exit /b 1
)
call busted !ARGS!
exit /b %ERRORLEVEL%
