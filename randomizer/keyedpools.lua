--- Keyed pools for incremental draws
-- @classmod KeyedPools

local utils = require("randomizer.utils")
local Pool = require("randomizer.pool")

--- keyed map of Pool instances for incremental draws.
local KeyedPools = {}
KeyedPools.__index = KeyedPools

--- build keyed pools from a group or a map of pools/lists/array-like tables
-- @param poolsMap Group or map of pools/lists/array-like tables
-- @param poolOptions optional consumable and regenerate flags
-- @return new KeyedPools
function KeyedPools.new(poolsMap, poolOptions)
	assert(type(poolsMap) == "table", "Expected table, got " .. type(poolsMap))

	-- If its already keyed pools, redirect to the copy fn
	if utils.isKeyedPools(poolsMap) then
		return KeyedPools.copy(poolsMap, poolOptions)
	end

	local self = setmetatable({}, KeyedPools)
	self._type = "KeyedPools"
	self.pools = {}

	-- Group or a table, we can just iterate over and create the pools from
	for key, pool in pairs(poolsMap) do
		self.pools[key] = Pool.new(pool, poolOptions)
	end

	return self
end

--- Deep copy an existing keyed pools including each pool state
-- @param source KeyedPools to copy
-- @param poolOptions optional flags passed to Pool.copy for every keyed pool. when omitted each pool keeps its flags
-- @return new KeyedPools
function KeyedPools.copy(source, poolOptions)
	assert(utils.isKeyedPools(source), "Expected KeyedPools, got " .. type(source))

	local self = setmetatable({}, KeyedPools)
	self._type = "KeyedPools"
	self.pools = {}

	for key, pool in pairs(source.pools) do
		self.pools[key] = Pool.copy(pool, poolOptions)
	end

	return self
end

--- Transfer ownership of map and all its pool or array-like tables values to the keyedPools. Does not copy.
-- Map and its values should not continue to be used after transferring ownership.
-- @param poolsMap table keyed by Pool instances or array-like tables
-- @param poolOptions optional flags when coercing arrays to pools
-- @return new KeyedPools
function KeyedPools.backedBy(poolsMap, poolOptions)
	assert(type(poolsMap) == "table", "Expected table, got " .. type(poolsMap))
	assert(not utils.isKeyedPools(poolsMap), "Use KeyedPools.new to copy a KeyedPools")
	assert(not utils.isGroup(poolsMap), "Expected table map for KeyedPools.backedBy, got Group")

	local self = setmetatable({}, KeyedPools)
	self._type = "KeyedPools"
	self.pools = {}

	-- For each entry, either take the pool, make a pool backed by the array like table or throw an error
	for key, entry in pairs(poolsMap) do
		-- if its a pool, just use it
		if utils.isPool(entry) then
			self.pools[key] = entry
		elseif utils.isList(entry) then
			error("Expected array-like table or Pool for key '" .. tostring(key) .. "', got List")
		elseif type(entry) == "table" and utils.isArrayLike(entry) then
			self.pools[key] = Pool.backedBy(entry, poolOptions)
		else
			error("Expected array-like table or Pool for key '" .. tostring(key) .. "', got " .. type(entry))
		end
	end

	return self
end

--- get the pool for a key
-- @param key key to look up
-- @return Pool or nil
function KeyedPools:get(key)
	return self.pools[key]
end

--- working pool size for one key, or 0 when missing
-- uses remainingCount only, not canDraw. intended for regenerate = false capacity checks
-- @param key pool key
-- @return remainingCount for that pool
function KeyedPools:remainingForKey(key)
	local pool = self.pools[key]
	if pool == nil then
		return 0
	end
	return pool:remainingCount()
end

--- sum remainingForKey across keys in order
-- counts working pool sizes only. see remainingForKey for regenerate behavior
-- @param keys array of pool keys
-- @return total remaining draws
function KeyedPools:remainingForKeys(keys)
	local total = 0
	for _, key in ipairs(keys) do
		total = total + self:remainingForKey(key)
	end
	return total
end

--- first key in keys with at least one unreserved draw left
-- Note this is "soft" reservations and does not change the objects state
-- uses remainingCount, so regenerate pools may report no capacity while canDraw is still true
-- @param keys array of pool keys in priority order
-- @param reservedCounts map of key to committed reservation count
-- @param tempReserved optional map of uncommitted reservations for this attempt
-- @return key or nil
function KeyedPools:firstKeyWithCapacity(keys, reservedCounts, tempReserved)
	for _, key in ipairs(keys) do
		local alreadyReserved = (reservedCounts[key] or 0) + ((tempReserved and tempReserved[key]) or 0)
		if self:remainingForKey(key) - alreadyReserved >= 1 then
			return key
		end
	end
	return nil
end

--- reserve one draw against the first key with capacity, updating tempReserved when provided
-- Note this is "soft" reservations and does not change the objects state
-- @param tempReserved optional map of uncommitted reservations for this attempt
-- @return reserved key or nil
function KeyedPools:tryReserveKey(keys, reservedCounts, tempReserved)
	local key = self:firstKeyWithCapacity(keys, reservedCounts, tempReserved)
	if key == nil then
		return nil
	end
	if tempReserved ~= nil then
		tempReserved[key] = (tempReserved[key] or 0) + 1
	end
	return key
end

--- draw from the first key in priority order that can still draw
-- @param keys array of pool keys
-- @return drawn value and the key it came from, or nil and nil when nothing left
function KeyedPools:drawFirstAvailable(keys)
	for _, key in ipairs(keys) do
		local pool = self:get(key)
		if pool ~= nil and pool:canDraw() then
			return pool:draw(), key
		end
	end
	return nil, nil
end

--- call fn(key, pool) for each keyed pool
-- @param fn callback
function KeyedPools:each(fn)
	assert(type(fn) == "function", "Expected function, got " .. type(fn))
	for key, pool in pairs(self.pools) do
		fn(key, pool)
	end
end

--- support pairs(keyedPools) so callers can iterate key, pool without :each()
-- @return iterator suitable for for key, pool in pairs(keyedPools)
function KeyedPools:__pairs()
	return pairs(self.pools)
end

--- total working pool size across all keyed pools
-- sum of remainingCount only, not canDraw
-- @return sum of each pool remainingCount
function KeyedPools:itemCount()
	local total = 0
	self:each(function(_, pool)
		total = total + pool:remainingCount()
	end)
	return total
end

--- number of keyed pools
-- @return number of keys
function KeyedPools:poolCount()
	local count = 0
	for _ in pairs(self.pools) do
		count = count + 1
	end
	return count
end

-- string representation for debugging
function KeyedPools:__tostring()
	local parts = {}
	self:each(function(key, pool)
		table.insert(parts, tostring(key) .. "=" .. pool:remainingCount())
	end)
	return "KeyedPools(" .. table.concat(parts, ", ") .. ")"
end

return KeyedPools
