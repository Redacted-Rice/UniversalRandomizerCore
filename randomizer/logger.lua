--- Fallback logger for UniversalRandomizerCore when no host injects one.
-- Under UniversalRandomizerJava, the sandbox sets a global `logger` that bridges to
-- Java logging; this module returns that host logger when present.
-- Standalone (busted / plain Lua) gets a print-based stub so URC has no URJ dependency.
--
-- Avoid rawget/rawset: the URJ sandbox removes those base functions.
-- @module randomizer.logger

local function concatArgs(...)
	local count = select("#", ...)
	if count == 0 then
		return ""
	end
	local parts = {}
	for i = 1, count do
		parts[i] = tostring(select(i, ...))
	end
	return table.concat(parts, "\t")
end

local function isUsableLogger(candidate)
	return type(candidate) == "table"
		and type(candidate.debug) == "function"
		and type(candidate.info) == "function"
		and type(candidate.warn) == "function"
		and type(candidate.error) == "function"
end

local function makeStub()
	local stub = {}

	function stub.debug(...)
		print("[DEBUG]\t" .. concatArgs(...))
	end

	function stub.info(...)
		print("[INFO]\t" .. concatArgs(...))
	end

	function stub.warn(...)
		print("[WARN]\t" .. concatArgs(...))
	end

	function stub.error(...)
		print("[ERROR]\t" .. concatArgs(...))
	end

	--- Minimal stand-in; hosts may provide a richer implementation.
	function stub.tableToString(value)
		return tostring(value)
	end

	return stub
end

-- Prefer host-injected global (URJ). Do not use rawget — removed in the URJ sandbox.
local hostLogger = _G.logger
if isUsableLogger(hostLogger) then
	return hostLogger
end

local stub = makeStub()
-- Best-effort install for other code that reads the global; ignore if _G is locked (URJ sandbox).
pcall(function()
	_G.logger = stub
end)

return stub
