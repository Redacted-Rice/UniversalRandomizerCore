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
	local items = utils.asArray(list)
	-- type validation for groupingfnorfield is handled by utils getvalue

	local grouped = {}

	for _, item in ipairs(items) do
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
-- equivalent to groupBy then applyToEachList("select", value) when a value extractor is given;
-- for whole items use groupBy instead
-- @param list list or table of items
-- @param groupingFnOrField function or function name or field that returns the value to group by
-- @param valueFnOrField optional function or function name or field that returns the value to keep
-- @return new group object with extracted values grouped by the extracted keys
function Group.fromField(list, groupingFnOrField, valueFnOrField)
	local grouped = Group.groupBy(list, groupingFnOrField)
	if valueFnOrField == nil then
		return grouped
	end
	return grouped:applyToEachList("select", valueFnOrField)
end

--- apply a List method to every keyed list, returning a new Group
-- use this instead of duplicating List APIs on Group (filter, select, flatMap, etc.)
-- the method must return a List or array-like table
-- @param methodName string name of a List instance method (e.g. "filter", "flatMap")
-- @param ... arguments forwarded to that method on each list
-- @return new Group with each list replaced by the method result
function Group:applyToEachList(methodName, ...)
	assert(type(methodName) == "string", "Expected method name string, got " .. type(methodName))

	local args = table.pack(...)
	local applied = {}
	for key, list in pairs(self.lists) do
		local method = list[methodName]
		assert(type(method) == "function", "List has no method '" .. methodName .. "'")
		applied[key] = toListObject(method(list, table.unpack(args, 1, args.n)), key)
	end

	return Group.new(applied)
end

--- call a function for each key/list pair in the group
-- useful for side effects when working with grouped streams
-- @param fn function that takes key and list
-- @return self to support chaining
function Group:each(fn)
	assert(type(fn) == "function", "Expected function, got " .. type(fn))

	for key, list in pairs(self.lists) do
		fn(key, list)
	end

	return self
end

--- map each key/list pair to a value, returning a List of results
-- nil results are skipped. useful for collecting e.g. the first item of each group
-- @param fn function that takes key and list and returns a value
-- @return List of mapped values
function Group:map(fn)
	assert(type(fn) == "function", "Expected function, got " .. type(fn))

	local mapped = {}
	for key, list in pairs(self.lists) do
		local value = fn(key, list)
		if value ~= nil then
			table.insert(mapped, value)
		end
	end

	return List.new(mapped)
end

--- concatenate all grouped lists into a single List
-- useful when feeding group results into APIs that expect one stream
-- @return new List of all items across all keys
function Group:toList()
	return self:map(function(_, list)
		return list
	end):flatten()
end

--- support pairs(group) so callers can iterate key, list without :keys()/:get()
-- @return iterator suitable for for key, list in pairs(group)
function Group:__pairs()
	return next, self.lists, nil
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
	local targets = utils.asArray(toRandomize)
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

	for i, item in ipairs(targets) do
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

		utils.setValue(targets[i], setterFnOrField, element)
	end

	return toRandomize
end

--- remove keys whose lists are empty
-- @return new Group without empty lists
function Group:prune()
	local kept = {}
	self:each(function(key, list)
		if not list:isEmpty() then
			kept[key] = list
		end
	end)
	return Group.new(kept)
end

--- convert back to plain table of tables
-- @return new table containing deepcopies of all lists in the group
function Group:toTable()
	local result = {}
	self:each(function(key, list)
		result[key] = list:toTable()
	end)
	return result
end

--- number of keyed lists in the group
-- @return number of groups/keys
function Group:groupCount()
	local count = 0
	for _ in pairs(self.lists) do
		count = count + 1
	end
	return count
end

--- total number of items across all keyed lists
-- @return sum of list sizes
function Group:itemCount()
	local count = 0
	self:each(function(_, list)
		count = count + list:size()
	end)
	return count
end

--- get the list for the passed key
-- @param key key to look up
-- @return list for the passed key or nil if the key is not found
function Group:get(key)
	return self.lists[key]
end

--- get all keys in the group
-- @return List of all keys in the group
function Group:keys()
	return self:map(function(key)
		return key
	end)
end

-- string representation for debugging
function Group:__tostring()
	return "Group(" .. self:groupCount() .. " groups, " .. self:itemCount() .. " items)"
end

return Group
