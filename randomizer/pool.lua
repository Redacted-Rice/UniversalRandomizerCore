--- Stateful pool for incremental random draws.
-- Unlike List:useToRandomize, callers draw one value at a time
-- @classmod Pool

local utils = require("randomizer.utils")

--- Pool with working and used array tables for consumable draws.
local Pool = {}
Pool.__index = Pool

--- Creates a pool from a list or array table, copying items so the source is not modified
-- @param list List or array table of choices
-- TODO: List out the options here
-- @param poolOptions optional table (consumesSelected, autoRegenerates, errorOnExhausted, constraintFn)
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
-- @param poolOptions optional table (consumesSelected, autoRegenerates, errorOnExhausted, constraintFn). See Pool.new. when omitted, copies option fields from source
-- @return new Pool instance
function Pool.copy(source, poolOptions)
	assert(utils.isPool(source), "Expected Pool, got " .. type(source))

	local self = setmetatable({}, Pool)
	self._type = "Pool"
	self.pool = utils.deepCopy(source.pool)
	self.used = utils.deepCopy(source.used)

	if poolOptions == nil then
		self:_setPoolOptions(source)
	else
		self:_setPoolOptions(poolOptions)
	end
	return self
end

--- Transfer ownership of an array-like table to the pool. Does not copy. Table should not continue to be used
-- after transferring ownership
-- @param array array-like table to back the working pool
-- @param poolOptions optional table (consumesSelected, autoRegenerates, errorOnExhausted, constraintFn). See Pool.new
-- @return new Pool instance
function Pool.backedBy(array, poolOptions)
	assert(type(array) == "table", "Expected table, got " .. type(array))
	assert(not utils.isList(array), "Expected array table, got List. Use Pool.new to copy a List")
	assert(utils.isArrayLike(array), "Expected array-like table for Pool.backedBy")

	return Pool._create(array, poolOptions)
end

--- Creates the pool object with the passed data. Common helper for new and backedBy
function Pool._create(data, poolOptions)
	local self = setmetatable({}, Pool)
	self._type = "Pool"
	self.pool = data
	self.used = {}
	self:_setPoolOptions(poolOptions)
	return self
end

--- copy pool option fields from a poolOptions table onto self
-- @param poolOptions optional options table
function Pool:_setPoolOptions(poolOptions)
	poolOptions = poolOptions or {}
	self.consumesSelected = poolOptions.consumesSelected or false
	self.autoRegenerates = poolOptions.autoRegenerates or false
	self.errorOnExhausted = poolOptions.errorOnExhausted or false
	self.constraintFn = poolOptions.constraintFn or nil
end

--- whether draw would succeed without treating exhaustion as an error
-- with regenerate, true when the working pool is empty but used still has items
-- @return boolean
function Pool:canDraw()
	if #self.pool > 0 then
		return true
	end
	return self.consumesSelected and self.autoRegenerates and #self.used > 0
end

--- Regenereates the pool from the used pile
function Pool:regenerate()
	if #self.pool <= 0 then
		self.pool = self.used
	else
		for _, item in ipairs(self.used) do
			table.insert(self.pool, item)
		end
	end
	self.used = {}
end

--- refill working pool from used when regenerate allows another draw
-- @return true when the pool can take another draw
function Pool:_ensureDrawable()
	if #self.pool > 0 then
		return true
	end
	if self.consumesSelected and self.autoRegenerates and #self.used > 0 then
		self:regenerate()
		return true
	end
	if not self.errorOnExhausted then
		return false
	end
	if self.consumesSelected and not self.autoRegenerates then
		error("Pool depleted and regenerate is false")
	end
	error("Pool state items unexpectedly exhausted!")
end

--- draw one random element from the pool
-- non consumable pools sample with replacement. consumable pools move choices to used.
-- exhaustion behavior follows self.errorOnExhausted
-- @return drawn element or nil
function Pool:draw()
	if not self:_ensureDrawable() then
		return nil
	end

	-- Choose a random element. We just use our set options so we can pass ourselfs
	-- instead of making a temp table
	local choice = utils.randomElement(self.pool, self)
	if self.consumesSelected and choice ~= nil then
		table.insert(self.used, choice)
	end
	return choice
end

--- pick from the working pool for target using the pools constraintFn
-- @param target object being randomized
-- @return drawn element or nil
function Pool:_pickConstrained(target)
	if not self:_ensureDrawable() then
		return nil
	end

	-- Keep trying to draw until we exhaust our pool or find a working option
	local choice = nil
	local tried = {}
	while #self.pool > 0 do
		-- Always remove the element. We will add it back in if we want
		choice = utils.randomElement(self.pool, {
			consumesSelected = true,
		})
		-- Choice will always be non-nil here as we loop while we have items
		-- If we pass teh constraint, we're done
		if self.constraintFn(target, choice) then
			break
		else
			-- if it doesn't pass, add it to our tried list
			table.insert(tried, choice)
		end
	end

	-- Reapply the items to the pool if needed before returning
	for _, item in ipairs(tried) do
		table.insert(self.pool, item)
	end

	-- if its consumable, add it to the used pile
	if choice ~= nil and self.constraintFn(target, choice) then
		if self.consumesSelected then
			table.insert(self.used, choice)
		else
			table.insert(self.pool, choice)
		end
		return choice
	end
	return nil
end

--- draw one random element that passes the pools constraintFn for target
-- rejected options stay in the working pool. uses constraint fallback when regenerate is on
-- @param target object being randomized
-- @return drawn element
function Pool:drawWithConstraint(target)
	if self.constraintFn == nil then
		return self:draw()
	end

	local element = self:_pickConstrained(target)
	if element == nil and self.autoRegenerates then
		self:regenerate()
		element = self:_pickConstrained(target)
		if element == nil then
			element = self:draw()
		end
	elseif element == nil then
		error("No acceptable value in pool for target")
	end
	return element
end

--- drop every matching value from the working pool and optionally from used
-- @param value value to match against
-- @param matcherFn optional function(item, value) passed to utils.resolveMatcher
-- @param removeFromUsed when true also filter used (default true). false only touches pool
-- @return self for chaining
function Pool:removeFromPool(value, matcherFn, removeFromUsed)
	if removeFromUsed == nil then
		removeFromUsed = true
	end

	local matches = utils.resolveMatcher(matcherFn)
	utils.filterArrayInPlace(self.pool, function(item)
		return not matches(item, value)
	end)
	if self.consumesSelected and removeFromUsed then
		utils.filterArrayInPlace(self.used, function(item)
			return not matches(item, value)
		end)
	end
	return self
end

--- count of values in the working pool only
-- does not include used even when regenerate would make the pool drawable via canDraw
-- @return number of items in the working pool array
function Pool:remainingCount()
	return #self.pool
end

--- count of values in the used pile (consumable draws only)
-- @return number of items in the used array
function Pool:usedCount()
	return #self.used
end

-- string representation for debugging
function Pool:__tostring()
	return "Pool(" .. self:remainingCount() .. " remaining, " .. self:usedCount() .. " used)"
end

return Pool
