--- A module/class for managing multiple lists with key-based selection.
-- Useful for bulk-building pools and randomizing lists without defining separate pools.
-- @classmod Group

local utils = require("randomizer.utils")
local List = require("randomizer.list")

--- A Group object to support coordinated randomization across lists.
-- Provides keyed access to list pools.
local Group = {}
Group.__index = Group

--- helper to convert a list or table to a list object
-- @local
-- @param list list or table to convert
-- @param key optional key for better error messages
-- @return list object
local function toListObject(list, key)
	if utils.isList(list) then
		return list
	elseif type(list) == "table" then
		return List.new(list)
	else
		local keyMsg = key and (" for key '" .. tostring(key) .. "'") or ""
		error("Expected List or table" .. keyMsg .. ", got " .. type(list))
	end
end

--- wraps native tables in randomizer group of lists
-- constructor
-- preferred to use this when you have multiple pools
-- @param listsMap table of lists or tables
-- @return group object
function Group.new(listsMap)
	assert(type(listsMap) == "table", "Expected table, got " .. type(listsMap))

	local self = setmetatable({}, Group)
	self._type = "Group"
	self.lists = {}

	-- convert plain tables to list objects and store them
	for key, list in pairs(listsMap) do
		self.lists[key] = toListObject(list, key)
	end

	return self
end

--- create a group from a list by grouping items based on groupingfn
-- static factory function
-- useful when you want to map to the whole item
-- if you want only a field use fromfield instead
-- @param list table or list of items
-- @param groupingFnOrField function or function name or field that returns the value to group by
-- @return new group object with the items grouped by the extracted keys
function Group.groupBy(list, groupingFnOrField)
	assert(type(list) == "table", "Expected table, got " .. type(list))
	-- type validation for groupingfnorfield is handled by utils getvalue

	local grouped = {}

	for _, item in ipairs(list) do
		local key = utils.getValue(item, groupingFnOrField)
		if key ~= nil then
			if grouped[key] == nil then
				grouped[key] = {}
			end
			table.insert(grouped[key], item)
		end
	end

	return Group.new(grouped)
end

--- create a group from a table or list by grouping on one field and extracting another
-- static factory function
-- useful when you want to map a field instead of the whole item
-- for whole items use groupby instead
-- @param list list or table of items
-- @param groupingFnOrField function or function name or field that returns the value to group by
-- @param valueFnOrField function or function name or field that returns the value to map by the key
-- @return new group object with extracted values grouped by the extracted keys
function Group.fromField(list, groupingFnOrField, valueFnOrField)
	assert(type(list) == "table", "Expected table, got " .. type(list))
	-- type validation for groupingfnorfield and valuefnorfield is handled by utils getvalue

	local grouped = {}

	for _, item in ipairs(list) do
		local key = utils.getValue(item, groupingFnOrField)

		if key ~= nil then
			if grouped[key] == nil then
				grouped[key] = {}
			end

		local value
		if valueFnOrField == nil then
			-- no value extractor so use the whole item
			value = item
			else
				value = utils.getValue(item, valueFnOrField, key)
			end
			if value ~= nil then
				table.insert(grouped[key], value)
			end
		end
	end

	return Group.new(grouped)
end

--- add a table or list to the group with the given key
-- @param key key to associate with the list
-- @param list table or list to add
-- @return self to support chaining
function Group:add(key, list)
	assert(key ~= nil, "Key cannot be nil")
	self.lists[key] = toListObject(list, key)
	return self
end

--- remove the key and associated list from the group
-- @param key key to remove
-- @return self to support chaining
function Group:remove(key)
	self.lists[key] = nil
	return self
end

--- select or extract values from items in all lists using a field or function
-- calls list select on each list in the group
-- @param selectorFnOrField function or function name or field to extract values from items
-- @return new group with extracted values from each list
function Group:select(selectorFnOrField)
	local selected = {}
	for key, list in pairs(self.lists) do
		selected[key] = list:select(selectorFnOrField)
	end

	return Group.new(selected)
end

--- applies the filter to each list and returns a new group with filtered lists
-- @param predicate function that takes an item and returns whether to keep it or not true means keep
-- @return new group with filtered lists
function Group:filter(predicate)
	assert(type(predicate) == "function", "Expected function, got " .. type(predicate))

	local filtered = {}
	for key, list in pairs(self.lists) do
		filtered[key] = list:filter(predicate)
	end

	return Group.new(filtered)
end

--- remove duplicates from all lists in the group
-- @return new group with duplicates removed
function Group:removeDuplicates()
	local deduplicated = {}
	for key, list in pairs(self.lists) do
		deduplicated[key] = list:removeDuplicates()
	end

	return Group.new(deduplicated)
end

--- shuffle all lists in the group
-- @return new group with shuffled lists
function Group:shuffle()
	local shuffled = {}
	for key, list in pairs(self.lists) do
		shuffled[key] = list:shuffle()
	end

	return Group.new(shuffled)
end

--- sort all lists in the group with optional comparator
-- if no comparator is passed it will sort in natural order
-- @param compareFn optional function that takes two items returns true if first should come before second
-- @return new group with sorted lists
function Group:sort(compareFn)
	local sorted = {}
	for key, list in pairs(self.lists) do
		sorted[key] = list:sort(compareFn)
	end

	return Group.new(sorted)
end

--- randomize the items in the torandomize list using this grouped pool
-- to randomize a target list using selector function to pick which pool to use per item
-- this is modified in place
-- @param toRandomize list or table of items to randomize
-- @param selectorFnOrField function or function name or field that gets the key to use for the group
-- to get the list to use for the item
-- @param setterFnOrField function or function name or field that sets the value on the item
-- @param poolOptions optional table with additional parameters for controlling pool behavior consumable
-- is boolean if true the pool will be consumed and regenerated when empty default is false regenerate
-- is boolean if true the pool will be regenerated when empty default is false if the pool is consumable
-- and regenerate is false an error will be thrown if the pool is depleted and is tried to be used
-- @return the modified torandomize list
function Group:useToRandomize(toRandomize, selectorFnOrField, setterFnOrField, poolOptions)
	assert(type(toRandomize) == "table", "Expected table, got " .. type(toRandomize))
	-- type validation for selectorfnorfield and setterfnorfield is handled by utils getvalue

	-- parse options
	local consumable, regenerate = utils.parsePoolOptions(poolOptions)

	-- for consumable pools create working copies for each group
	local workingPools = {}
	if consumable then
		for key, list in pairs(self.lists) do
			workingPools[key] = utils.deepCopy(list.items)
		end
	end

	for i, item in ipairs(toRandomize) do
		local key = utils.getValue(item, selectorFnOrField, i)
		local list = self.lists[key]

		if not list then
			error("No list found for key '" .. tostring(key) .. "'")
		end

		if list:isEmpty() then
			error("List for key '" .. tostring(key) .. "' is empty")
		end

		local element
		if consumable then
			local pool = workingPools[key]
			if #pool == 0 then
				if regenerate then
					-- refill this groups pool
                    workingPools[key] = utils.deepCopy(list.items)
                    pool = workingPools[key]
				else
					error("Pool for key '" .. tostring(key) .. "' depleted and regenerate is false")
				end
			end
			element = utils.consumeRandomElement(pool)
		else
			element = utils.randomElement(list.items)
		end

		utils.setValue(toRandomize[i], setterFnOrField, element)
	end

	return toRandomize
end

--- convert back to plain table of tables
-- @return new table containing deepcopies of all lists in the group
function Group:toTable()
	local result = {}
	for key, list in pairs(self.lists) do
		result[key] = list:toTable()
	end
	return result
end

--- get the number of groups or keys or lists in the group
-- @return number of keys or lists in the group
function Group:size()
	local count = 0
	for _ in pairs(self.lists) do
		count = count + 1
	end
	return count
end

--- check if group is empty
-- @return true if there are no keys or lists in the group
function Group:isEmpty()
	return self:size() == 0
end

--- get the list for the passed key
-- @param key key to look up
-- @return list for the passed key or nil if the key is not found
function Group:get(key)
	return self.lists[key]
end

--- get all keys in the group
-- @return table of all keys in the group
function Group:keys()
	local keys = {}
	for key in pairs(self.lists) do
		table.insert(keys, key)
	end
	return keys
end

-- string representation for debugging
function Group:__tostring()
	return "Group(" .. self:size() .. " lists)"
end

return Group
