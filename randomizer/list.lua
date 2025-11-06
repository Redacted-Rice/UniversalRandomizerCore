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

--- create a list from a table or list by extracting values from items
-- the new list will contain one entry for each item in the passed list
-- static factory function
-- @param list table or list of items to extract values from
-- @param valueFnOrField function or function name or field to extract values from objects
-- @return new list with extracted values
function List.fromField(list, valueFnOrField)
	assert(type(list) == "table", "Expected table, got " .. type(list))
	-- type validation for valuefnorfield is handled by utils getvalue

	local values = {}
	for _, item in ipairs(list) do
		local value = utils.getValue(item, valueFnOrField)
		if value ~= nil then
			table.insert(values, value)
		end
	end

	return List.new(values)
end

--- select or extract values from items in the list using a field or function
-- creates a new list with one entry for each item in the current list
-- @param selectorFnOrField function or function name or field to extract values from items
-- @return new list with extracted values
function List:select(selectorFnOrField)
	-- type validation for selectorfnorfield is handled by utils getvalue

	local selected = {}
	for _, item in ipairs(self.items) do
		local value = utils.getValue(item, selectorFnOrField)
		if value ~= nil then
			table.insert(selected, value)
		end
	end

	return List.new(selected)
end

--- applies the filter to the list keeping only matching items
-- the original list is not modified
-- @param predicate function that takes an item that returns whether or not to keep the item true means keep
-- @return new list with filtered items
function List:filter(predicate)
	assert(type(predicate) == "function", "Expected function, got " .. type(predicate))

	local filtered = {}
	for i, item in ipairs(self.items) do
		if predicate(item, i) then
			table.insert(filtered, item)
		end
	end

	return List.new(filtered)
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

--- randomize a field of the items in the torandomize list using this pool
-- @param toRandomize list or table of items to randomize in place
-- @param setterFnOrField function or function name or field that sets the value on the item
-- @param poolOptions optional table with additional parameters for controlling pool behavior consumable is
-- boolean if true the pool will be consumed and regenerated when empty default is false regenerate is
-- boolean if true the pool will be regenerated when empty default is false if the pool is consumable
-- and regenerate is false an error will be thrown if the pool is depleted and is tried to be used
-- @return the modified torandomize list
function List:useToRandomize(toRandomize, setterFnOrField, poolOptions)
	assert(type(toRandomize) == "table", "Expected table, got " .. type(toRandomize))
	assert(#self.items > 0, "Cannot apply from empty list")

	-- parse options
	local consumable, regenerate = utils.parsePoolOptions(poolOptions)

	-- for consumable pools create a working copy that well remove items from
	-- non consumable pools just pick randomly each time
	local workingPool
	if consumable then
		workingPool = utils.deepCopy(self.items)
	end

	for i = 1, #toRandomize do
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

		utils.setValue(toRandomize[i], setterFnOrField, element)
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
