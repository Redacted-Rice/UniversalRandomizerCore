--- Stateful pool for incremental random draws.
-- Unlike List:useToRandomize, callers draw one value at a time
-- @classmod Pool

local utils = require("randomizer.utils")
local List = require("randomizer.list")

--- Pool with separate active and used lists for consumable draws.
local Pool = {}
Pool.__index = Pool

--- create a pool from a list or table
-- @param list List or array table of choices
-- @param poolOptions optional table with consumable flag (regenerate is ignored here)
-- @return new Pool instance
function Pool.new(list, poolOptions)
	assert(type(list) == "table", "Expected table or List, got " .. type(list))

	local consumable = utils.parsePoolOptions(poolOptions)
	local poolList = List.new(list)

	local self = setmetatable({}, Pool)
	self._type = "Pool"
	self.consumable = consumable
	self.pool = poolList
	self.used = List.new({})

	return self
end

--- draw one random element from the pool
-- non consumable pools put the choice back immediately
-- consumable pools move choices to used and recycle used into pool when the active pool is empty
-- @param allowExhausted when true return nil if nothing left to draw in consumable mode
-- @return drawn element or nil
function Pool:draw(allowExhausted)
	if self.pool:isEmpty() then
		if self.consumable and not self.used:isEmpty() then
			self.pool = self.used
			self.used = List.new({})
		elseif allowExhausted then
			return nil
		else
			error("Pool state items unexpectedly exhausted!")
		end
	end

	local choice = utils.consumeRandomElement(self.pool.items)
	if not self.consumable then
		table.insert(self.pool.items, choice)
	else
		table.insert(self.used.items, choice)
	end
	return choice
end

return Pool
