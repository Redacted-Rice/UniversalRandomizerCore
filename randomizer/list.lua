--- A module/class for managing tables for randomization convenience.
-- Can wrap tables to create lists of items to randomize or to build value pools.
-- @classmod List

local utils = require("randomizer.utils")

--- A List object that supports randomization helpers.
-- Provides table-like containers with utility methods.
local List = {}
List.__index = List

--- wraps a native table in a randomizer list
-- constructor
-- the original is not modified
-- @param list table or list of items
-- @return new list object containing the items
function List.new(list)
	assert(type(list) == "table", "Expected table, got " .. type(list))

	local self = setmetatable({}, List)
	self._type = "List" -- for type checking
	self.items = utils.deepCopy(list) -- deep copy to avoid side effects

	return self
end

--- select or extract values from items in the list using a field or function
-- creates a new list with one entry for each item in the current list
-- @param selectorFnOrField function or function name or field to extract values from items
-- @param ... optional extra arguments forwarded to function or method getters
-- @return new list with extracted values. java enum fields come back as userdata for assignment
function List:select(selectorFnOrField, ...)
	-- type validation for selectorfnorfield is handled by utils getvalue

	local selected = {}
	for _, item in ipairs(self.items) do
		local value = utils.getValue(item, selectorFnOrField, ...)
		if value ~= nil then
			table.insert(selected, value)
		end
	end

	return List.new(selected)
end

--- map each item to a new value, returning a new List
-- nil results are skipped
-- @param fn function that takes item and optional 1-based index and returns a value
-- @return new list of mapped values
function List:map(fn)
	assert(type(fn) == "function", "Expected function, got " .. type(fn))

	local mapped = {}
	for i, item in ipairs(self.items) do
		local value = fn(item, i)
		if value ~= nil then
			table.insert(mapped, value)
		end
	end

	return List.new(mapped)
end

--- flatten one level of nested lists or array like tables into a single list
-- non list items (scalars, objects) are kept as is
-- @return new flattened list
function List:flatten()
	local flat = {}
	for _, item in ipairs(self.items) do
		if utils.isList(item) then
			for _, nested in ipairs(item.items) do
				table.insert(flat, nested)
			end
		elseif type(item) == "table" and not utils.isGroup(item) and utils.isArrayLike(item) then
			for _, nested in ipairs(item) do
				table.insert(flat, nested)
			end
		else
			table.insert(flat, item)
		end
	end

	return List.new(flat)
end

--- map each item to a list or array, then flatten one level
-- @param fn function that takes an item and optional 1-based index and returns a List, array table, or nil
-- @return new flattened list of mapped values
function List:flatMap(fn)
	assert(type(fn) == "function", "Expected function, got " .. type(fn))

	local flat = {}
	for i, item in ipairs(self.items) do
		local mapped = fn(item, i)
		if mapped ~= nil then
			local nestedItems
			if utils.isList(mapped) then
				nestedItems = mapped.items
			else
				assert(type(mapped) == "table", "flatMap function must return List, table, or nil")
				nestedItems = mapped
			end
			for _, nested in ipairs(nestedItems) do
				table.insert(flat, nested)
			end
		end
	end

	return List.new(flat)
end

--- flat map each item N times based on a count field or function
-- for each item, calls mapFn(item, index) for index from startIndex to startIndex + count - 1
-- useful for expanding by a count
-- @param countFnOrField function or field returning a non negative integer count
-- @param mapFn optional function(item, index) returning each expanded value or nil to skip;
--   defaults to { item = item, index = index }
-- @param startIndex optional first index (default 1)
-- @return new list of expanded values
function List:flatMapNTimes(countFnOrField, mapFn, startIndex)
	if mapFn ~= nil then
		assert(type(mapFn) == "function", "Expected function for mapFn, got " .. type(mapFn))
	end
	if startIndex == nil then
		startIndex = 1
	else
		assert(type(startIndex) == "number", "Expected number for startIndex, got " .. type(startIndex))
	end

	local expanded = {}
	for _, item in ipairs(self.items) do
		local count = utils.getValue(item, countFnOrField)
		assert(type(count) == "number", "flatMapNTimes count must be a number")
		assert(count >= 0, "flatMapNTimes count must be non-negative")
		for offset = 0, count - 1 do
			local index = startIndex + offset
			if mapFn ~= nil then
				local mapped = mapFn(item, index)
				if mapped ~= nil then
					table.insert(expanded, mapped)
				end
			else
				table.insert(expanded, { item = item, index = index })
			end
		end
	end

	return List.new(expanded)
end

--- call a function for each item in the list
-- useful for side effects when chaining stream operations
-- @param fn function that takes an item and optional 1 based index
-- @return self to support chaining
function List:each(fn)
	assert(type(fn) == "function", "Expected function, got " .. type(fn))

	for i, item in ipairs(self.items) do
		fn(item, i)
	end

	return self
end

--- applies the filter to the list keeping only matching items
-- the original list is not modified
-- @param predicateFnOrField function that takes an item and returns whether to keep it,
--   or a field/method name (including colon-separated paths like "getHost:type") resolved via
--   utils.getValue; truthy values are kept
-- @return new list with filtered items
function List:filter(predicateFnOrField)
	local predicateType = type(predicateFnOrField)
	assert(
		predicateType == "function" or predicateType == "string",
		"Expected function or string, got " .. predicateType
	)

	local filtered = {}
	for i, item in ipairs(self.items) do
		local keep
		if predicateType == "string" then
			keep = utils.getValue(item, predicateFnOrField)
		else
			keep = predicateFnOrField(item, i)
		end
		if keep then
			table.insert(filtered, item)
		end
	end

	return List.new(filtered)
end

--- group items in this list by a field or method, returning a Group
-- Functionally equivalent to Group.groupBy(list, groupingFnOrField) to support better chaining
-- @param groupingFnOrField function or function name or field that returns the value to group by;
--   colon-separated paths such as "getSourceCard:type" are supported via utils.getValue.
--   userdata keys (java enums) are normalized with utils.asTableKey
-- @return new Group with items grouped by the extracted keys
function List:groupBy(groupingFnOrField)
	local Group = require("randomizer.group")
	return Group.groupBy(self.items, groupingFnOrField)
end

--- remove duplicate values
-- note preserves order
-- its not the fastest but works for most cases
-- @return new list with duplicates removed
function List:removeDuplicates()
	local unique = utils.removeDuplicates(self.items)
	return List.new(unique)
end

--- shuffle items randomly
-- the original is not modified
-- @return new list with shuffled items
function List:shuffle()
	local shuffled = utils.deepCopy(self.items)
	utils.shuffle(shuffled)
	return List.new(shuffled)
end

--- sort items with optional comparator function
-- @param compareFn optional function that takes two items and returns true if first should come before second
-- @return new list with sorted items
function List:sort(compareFn)
	local sorted = utils.deepCopy(self.items)

	if compareFn then
		assert(type(compareFn) == "function", "Expected function or nil, got " .. type(compareFn))
		table.sort(sorted, compareFn)
	else
		-- default sort uses luas built in comparison
		table.sort(sorted)
	end

	return List.new(sorted)
end

--- find a min or max value from items using an optional extractor and compare function
-- @local
-- @param items array of items to inspect
-- @param valueFnOrField optional extractor passed to utils.getValue
-- @param compareFn optional function(a, b) returning true when a wins over b
-- @param defaultCompare compare function used when compareFn is nil
-- @param isMax true for max, false for min
-- @return winning value, or nil when no comparable values were found
local function findMinMax(items, valueFnOrField, compareFn, defaultCompare, isMax)
	local wins
	if compareFn == nil then
		wins = defaultCompare
	else
		assert(type(compareFn) == "function", "Expected function for compareFn, got " .. type(compareFn))
		if valueFnOrField == nil then
			if isMax then
				wins = compareFn
			else
				wins = function(a, b)
					return compareFn(b, a)
				end
			end
		elseif isMax then
			wins = function(a, b)
				return not compareFn(a, b)
			end
		else
			wins = compareFn
		end
	end

	local best = nil
	for _, item in ipairs(items) do
		local value = valueFnOrField ~= nil and utils.getValue(item, valueFnOrField) or item
		if value ~= nil and (best == nil or wins(value, best)) then
			best = value
		end
	end

	return best
end

--- return the maximum value in the list
-- @param valueFnOrField optional function, method name, or field used to extract a comparable value from each item;
--   when omitted each item is compared directly
-- @param compareFn optional function(a, b) returning true when a should win over b as the maximum
-- @return maximum value, or nil when the list is empty
function List:max(valueFnOrField, compareFn)
	if self:isEmpty() then
		return nil
	end

	return findMinMax(self.items, valueFnOrField, compareFn, function(a, b)
		return a > b
	end, true)
end

--- return the minimum value in the list
-- @param valueFnOrField optional function, method name, or field used to extract a comparable value from each item;
--   when omitted each item is compared directly
-- @param compareFn optional function(a, b) returning true when a should win over b as the minimum
-- @return minimum value, or nil when the list is empty
function List:min(valueFnOrField, compareFn)
	if self:isEmpty() then
		return nil
	end

	return findMinMax(self.items, valueFnOrField, compareFn, function(a, b)
		return a < b
	end, false)
end

--- randomize a field of the items in the torandomize list using this pool
-- @param toRandomize list or table of items to randomize in place
-- @param setterFnOrField function or function name or field that sets the value on the item
-- @param poolOptions optional table with additional parameters for controlling pool behavior consumable is
-- boolean if true the pool will be consumed and regenerated when empty default is false regenerate is
-- boolean if true the pool will be regenerated when empty default is false if the pool is consumable
-- and regenerate is false an error will be thrown if the pool is depleted and is tried to be used
-- @return the modified torandomize list
function List:useToRandomize(toRandomize, setterFnOrField, poolOptions)
	local targets = utils.asArray(toRandomize)
	assert(#self.items > 0, "Cannot apply from empty list")

	-- parse options
	local consumable, regenerate = utils.parsePoolOptions(poolOptions)

	-- for consumable pools create a working copy that well remove items from
	-- non consumable pools just pick randomly each time
	local workingPool
	if consumable then
		workingPool = utils.deepCopy(self.items)
	end

	for i = 1, #targets do
		local element
		if consumable then
			if #workingPool == 0 then
				if regenerate then
					-- refill the pool
					workingPool = utils.deepCopy(self.items)
				else
					error("Pool depleted and regenerate is false")
				end
			end
			element = utils.consumeRandomElement(workingPool)
		else
			element = utils.randomElement(self.items)
		end

		utils.setValue(targets[i], setterFnOrField, element)
	end

	return toRandomize
end

--- convert back to plain table
-- @return new table containing a deep copy of the list items
function List:toTable()
	return utils.deepCopy(self.items)
end

--- get the number of items in the list
-- @return number of items
function List:size()
	return #self.items
end

--- check if list is empty
-- @return true if empty
function List:isEmpty()
	return #self.items == 0
end

--- get item at specific index
-- @param index index to get
-- @return item at the specified index or nil if not found
function List:get(index)
	return self.items[index]
end

-- string representation for debugging
function List:__tostring()
	return "List(" .. #self.items .. " items)"
end

return List
