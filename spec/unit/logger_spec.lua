-- logger_spec.lua
-- Unit tests for the standalone logger stub / host override

describe("Logger Module", function()
	local function withClearedLogger(fn)
		local previous = _G.logger
		_G.logger = nil
		package.loaded["randomizer.logger"] = nil
		local success, result = pcall(fn)
		package.loaded["randomizer.logger"] = nil
		_G.logger = previous
		if not success then
			error(result)
		end
		return result
	end

	it("provides a print-based stub when no host logger exists", function()
		withClearedLogger(function()
			local logger = require("randomizer.logger")
			assert.is_function(logger.warn)
			assert.is_function(logger.error)
			assert.is_function(logger.info)
			assert.is_function(logger.debug)

			local printed = {}
			local oldPrint = _G.print
			_G.print = function(msg)
				table.insert(printed, tostring(msg))
			end
			logger.warn("hello", "world")
			_G.print = oldPrint

			assert.equals(1, #printed)
			assert.equals("[WARN]\thello\tworld", printed[1])
		end)
	end)

	it("returns the host logger when already injected", function()
		withClearedLogger(function()
			local host = {
				debug = function() end,
				info = function() end,
				warn = function() end,
				error = function() end,
				marker = "host",
			}
			_G.logger = host
			local logger = require("randomizer.logger")
			assert.equals("host", logger.marker)
			assert.equals(host, logger)
		end)
	end)
end)
