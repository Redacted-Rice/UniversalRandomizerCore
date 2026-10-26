--- Stateful pool for incremental random draws.
-- Unlike List:useToRandomize, callers draw one value at a time
-- @classmod Pool

local utils = require("randomizer.utils")
local List = require("randomizer.list")

--- Pool with working and used array tables for consumable draws.
local Pool = {}
Pool.__index = Pool

--- Creates a pool from a list or array table, copying items so the source is not modified
-- @param list List or array table of choices
-- @param poolOptions optional table with consumable and regenerate flags (same as useToRandomize)
-- @return new Pool instance
function Pool.new(list, poolOptions)
	assert(type(list) == "table", "Expected table or List, got " .. type(list))
	if utils.isPool(list) then
		return Pool.copy(list, poolOptions)
	end

	return Pool._create(utils.copyArrayLike(list), poolOptions)
end

--- deep copy an existing pool including pool and used arrays
-- @param source Pool to copy
-- @param poolOptions optional flags. when omitted, copies consumable and regenerate from source
-- @return new Pool instance
function Pool.copy(source, poolOptions)
	assert(utils.isPool(source), "Expected Pool, got " .. type(source))

	local consumable, regenerate
	if poolOptions == nil then
		consumable = source.consumable
		regenerate = source.regenerate
	else
		consumable, regenerate = utils.parsePoolOptions(poolOptions)
		if not consumable then
			regenerate = false
		end
	end

	local self = setmetatable({}, Pool)
	self._type = "Pool"
	self.consumable = consumable
	self.regenerate = regenerate
	self.pool = utils.deepCopy(source.pool)
	self.used = utils.deepCopy(source.used)
	return self
end

--- Transfer ownership of an array-like table to the pool. Does not copy. Table should not continue to be used
-- after transferring ownership
-- @param array array-like table to back the working pool
-- @param poolOptions optional table with consumable and regenerate flags
-- @return new Pool instance
function Pool.backedBy(array, poolOptions)
	assert(type(array) == "table", "Expected table, got " .. type(array))
	assert(not utils.isList(array), "Expected array table, got List. Use Pool.new to copy a List")
	assert(utils.isArrayLike(array), "Expected array-like table for Pool.backedBy")

	return Pool._create(array, poolOptions)
end

--- Creates the pool object with the passed data. Common helper for new and backedBy
function Pool._create(data, poolOptions)
	local consumable, regenerate = utils.parsePoolOptions(poolOptions)
	if not consumable then
		regenerate = false
	end

	local self = setmetatable({}, Pool)
	self._type = "Pool"
	self.pool = data
	self.consumable = consumable
	self.regenerate = regenerate
	self.used = {}
	return self
end

--- whether draw would succeed without allowExhausted
-- with regenerate, true when the working pool is empty but used still has items
-- @return boolean
function Pool:canDraw()
	if #self.pool > 0 then
		return true
	end
	return self.consumable and self.regenerate and #self.used > 0
end

--- draw one random element from the pool
-- non consumable pools put the choice back immediately and ignore regenerate
-- consumable pools move choices to used, then swap used into pool when empty if regenerate
-- regenerate here swaps used back into the working pool, unlike List:useToRandomize which refills from the original list
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

--- count of values in the working pool only
-- does not include used even when regenerate would make the pool drawable via canDraw
-- @return number of items in the working pool array
function Pool:remainingCount()
	return #self.pool
end

-- string representation for debugging
function Pool:__tostring()
	return "Pool(" .. self:remainingCount() .. " remaining, " .. #self.used .. " used)"
end

return Pool
