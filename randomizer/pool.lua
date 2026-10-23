--- Stateful pool for incremental random draws.
-- Unlike List:useToRandomize, callers draw one value at a time
-- @classmod Pool

local utils = require("randomizer.utils")
local List = require("randomizer.list")

--- Pool with working and used array tables for consumable draws.
local Pool = {}
Pool.__index = Pool

--- create a pool from a list or table
-- @param list List or array table of choices
-- @param poolOptions optional table with consumable and regenerate flags (same as useToRandomize)
-- @return new Pool instance
function Pool.new(list, poolOptions)
	assert(type(list) == "table", "Expected table or List, got " .. type(list))

	local consumable, regenerate = utils.parsePoolOptions(poolOptions)
	if not consumable then
		regenerate = false
	end

	local self = setmetatable({}, Pool)
	self._type = "Pool"
	self.consumable = consumable
	self.regenerate = regenerate
	self.pool = utils.copyArrayLike(list)
	self.used = {}

	return self
end

--- draw one random element from the pool
-- non consumable pools put the choice back immediately and ignore regenerate
-- consumable pools move choices to used, then swap used into pool when empty if regenerate
-- @param allowExhausted when true return nil if nothing left to draw
-- @return drawn element or nil
function Pool:draw(allowExhausted)
	if #self.pool == 0 then
		if self.consumable and self.regenerate and #self.used > 0 then
			self.pool = self.used
			self.used = {}
		elseif allowExhausted then
			return nil
		elseif self.consumable and not self.regenerate then
			error("Pool depleted and regenerate is false")
		else
			error("Pool state items unexpectedly exhausted!")
		end
	end

	local choice = utils.consumeRandomElement(self.pool)
	if not self.consumable then
		table.insert(self.pool, choice)
	else
		table.insert(self.used, choice)
	end
	return choice
end

--- drop every matching value from the working pool and optionally from used
-- @param value value to match against
-- @param matcherFn optional function(item, value) forwarded to List:removeAllMatches
-- @param removeFromUsed when true also filter used (default true). false only touches pool
-- @return self for chaining
function Pool:removeFromPool(value, matcherFn, removeFromUsed)
	if removeFromUsed == nil then
		removeFromUsed = true
	end

	self.pool = List.backedBy(self.pool):removeAllMatches(value, matcherFn).items
	if self.consumable and removeFromUsed then
		self.used = List.backedBy(self.used):removeAllMatches(value, matcherFn).items
	end
	return self
end

--- count of values still available to draw from the working pool
-- @return number of items left in pool
function Pool:remainingCount()
	return #self.pool
end

return Pool
