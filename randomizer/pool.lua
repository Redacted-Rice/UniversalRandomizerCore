--- Stateful pool for incremental random draws.
-- Unlike List:useToRandomize, callers draw one value at a time
-- @classmod Pool

local utils = require("randomizer.utils")

--- Pool with working (`pool`) and `used` array tables for stateful and constrained draws.
local Pool = {}
Pool.__index = Pool

--- Creates a pool from a list or array table, copying items so the source is not modified
-- @param list List or array table of choices
-- @param poolOptions optional table (see README **poolOptions** for more detail):
--   consumesSelected remove accepted draws from the working pool
--   autoRegenerates refill the working pool from used when empty (uses consumesSelected)
--   errorOnExhausted when true, draw errors on exhaustion. When false, draw returns nil
--   constraintFn function(target, candidate). Truthy candidates only will be returned by drawWithConstraint
--   constraintRemovesFailures when true, values rejected by constraintFn stay removed from the pool
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
-- @param poolOptions optional flags. See Pool.new. When omitted, copies option fields from source
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
-- @param poolOptions optional flags. See Pool.new
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
	self.constraintRemovesFailures = poolOptions.constraintRemovesFailures or false
end

--- whether draw would succeed without treating exhaustion as an error
-- with autoRegenerates, true when the working pool is empty but used still has items
-- @return boolean
function Pool:canDraw()
	if #self.pool > 0 then
		return true
	end
	return self.consumesSelected and self.autoRegenerates and #self.used > 0
end

--- Refills the working pool from the used pile
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

--- refill working pool from used when autoRegenerates allows another draw
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
		error("Pool depleted and autoRegenerates is false")
	end
	error("Pool state items unexpectedly exhausted!")
end

--- draw one random element from the pool
-- when consumesSelected is false, sample with replacement; when true, move choices to used.
-- exhaustion behavior follows self.errorOnExhausted
-- @return drawn element or nil
function Pool:draw()
	if not self:_ensureDrawable() then
		return nil
	end

	-- Pass self as drawOptions so consumesSelected is honored without a temp options table
	-- instead of making a temp table
	local choice = utils.randomElement(self.pool, self)
	if self.consumesSelected and choice ~= nil then
		table.insert(self.used, choice)
	end
	return choice
end

--- 1 based indexes into pool left to try for this constrained draw
function Pool:_unpickedPoolIndexes()
	local indexes = {}
	for i = 1, #self.pool do
		indexes[i] = i
	end
	return indexes
end

--- remove indexes from the working pool high to low and append each to used
function Pool:removeIndexesHighToLow(indexes)
	if #indexes == 0 then
		return
	end
	table.sort(indexes, function(a, b)
		return a > b
	end)
	for _, index in ipairs(indexes) do
		local item = self.pool[index]
		table.remove(self.pool, index)
		table.insert(self.used, item)
	end
end

--- Pick from the working pool for target using the pools constraintFn
-- probes by pool index so skipped items keep their order. Each index is tried at most once
-- in this pass.
-- @param target object being randomized
-- @return drawn element or nil
function Pool:_pickConstrained(target)
	local choice = nil
	-- Get indexes of all items to try in a list we can modify as we try and fail to prevent
	-- retyring the same index while not mutating the pool
	local unpicked = self:_unpickedPoolIndexes()
	local toRemove = {}
	while #unpicked > 0 do
		-- pick and consume a random index and get the pool item for it
		local poolIndex = utils.randomElement(unpicked, { consumesSelected = true })
		choice = self.pool[poolIndex]

		-- See if it passes the contraint
		if self.constraintFn(target, choice) then
			-- If we consume selected, add it to the list to remove and break which will handle
			-- cleanup of the attempted lists appropriately
			if self.consumesSelected then
				table.insert(toRemove, poolIndex)
			end
			break
		end
		choice = nil

		-- If it does not, add it to the list of items to move if we are removing failures
		if self.constraintRemovesFailures then
			table.insert(toRemove, poolIndex)
		end
	end

	-- If we have any items to remove, remove them at the end to reduce churn
	if #toRemove > 0 then
		self:removeIndexesHighToLow(toRemove)
	end
	return choice
end

--- draw one random element that passes the pools constraintFn for target
-- rejected options stay in the working pool unless constraintRemovesFailures is true (see Pool.new)
-- @param target object being randomized
-- @return drawn element or nil when nothing passes
function Pool:drawWithConstraint(target)
	-- If there is no constraint, just draw
	if self.constraintFn == nil then
		return self:draw()
	end

	-- Ensure we can draw from the pool/its regenerated if empty
	if not self:_ensureDrawable() then
		return nil
	end

	-- Try to find a valid contrained item
	local element = self:_pickConstrained(target)

	-- If it fails, we have used items and we are set to autoregenerate, try once more
	if element == nil and self.autoRegenerates and #self.used > 0 then
		self:regenerate()
		element = self:_pickConstrained(target)
	end

	-- If we failed error if set to
	if element == nil and self.errorOnExhausted then
		error("Pool constraint could not be satisfied")
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
-- does not include used even when autoRegenerates would make the pool drawable via canDraw
-- @return number of items in the working pool array
function Pool:remainingCount()
	return #self.pool
end

--- count of values in the used pile (consumesSelected draws and constraintRemovesFailures rejects)
-- @return number of items in the used array
function Pool:usedCount()
	return #self.used
end

-- string representation for debugging
function Pool:__tostring()
	return "Pool(" .. self:remainingCount() .. " remaining, " .. self:usedCount() .. " used)"
end

return Pool
