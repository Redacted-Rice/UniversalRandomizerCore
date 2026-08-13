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
-- @param keyOrder optional array defining iteration order for keys
-- @return group object
function Group.new(listsMap, keyOrder)
	assert(type(listsMap) == "table", "Expected table, got " .. type(listsMap))

	local self = setmetatable({}, Group)
	self._type = "Group"
	self.lists = {}
	self.keyOrder = {}

	local function addKey(key)
		if listsMap[key] == nil or self.lists[key] ~= nil then
			return
		end
		self.lists[key] = toListObject(listsMap[key], key)
		table.insert(self.keyOrder, key)
	end

	if keyOrder then
		for _, key in ipairs(keyOrder) do
			addKey(key)
		end
	end

	for key in pairs(listsMap) do
		addKey(key)
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
	local keyOrder = {}

	for _, item in ipairs(items) do
		-- asTableKey so java enums become stable string keys
		local key = utils.asTableKey(utils.getValue(item, groupingFnOrField))
		if key ~= nil then
			if grouped[key] == nil then
				grouped[key] = {}
				table.insert(keyOrder, key)
			end
			table.insert(grouped[key], item)
		end
	end

	return Group.new(grouped, keyOrder)
end

--- create a group from a table or list by grouping on one field and extracting another
-- static factory function
-- equivalent to groupBy then per-key select when a value extractor is given;
-- the grouping key is forwarded to function and method value extractors
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

	local selected = {}
	local keyOrder = {}
	grouped:each(function(key, list)
		selected[key] = list:select(valueFnOrField, key)
		table.insert(keyOrder, key)
	end)
	return Group.new(selected, keyOrder)
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
	local keyOrder = {}
	for _, key in ipairs(self.keyOrder) do
		local list = self.lists[key]
		local method = list[methodName]
		assert(type(method) == "function", "List has no method '" .. methodName .. "'")
		applied[key] = toListObject(method(list, table.unpack(args, 1, args.n)), key)
		table.insert(keyOrder, key)
	end

	return Group.new(applied, keyOrder)
end

--- call a function for each key/list pair in the group
-- keys are visited in insertion order
-- @param fn function that takes key and list
-- @return self to support chaining
function Group:each(fn)
	assert(type(fn) == "function", "Expected function, got " .. type(fn))

	for _, key in ipairs(self.keyOrder) do
		fn(key, self.lists[key])
	end

	return self
end

--- map each key/list pair to a value, returning a List of results
-- nil results are skipped. keys are visited in insertion order
-- @param fn function that takes key and list and returns a value
-- @return List of mapped values
function Group:map(fn)
	assert(type(fn) == "function", "Expected function, got " .. type(fn))

	local mapped = {}
	for _, key in ipairs(self.keyOrder) do
		local value = fn(key, self.lists[key])
		if value ~= nil then
			table.insert(mapped, value)
		end
	end

	return List.new(mapped)
end

--- concatenate all grouped lists into a single List
-- useful when feeding group results into APIs that expect one stream
-- items are ordered by key insertion order, then list order within each key
-- @return new List of all items across all keys
function Group:toList()
	local flat = {}
	for _, key in ipairs(self.keyOrder) do
		local list = self.lists[key]
		for _, item in ipairs(list.items) do
			table.insert(flat, item)
		end
	end
	return List.new(flat)
end

--- reorder keys, returning a new Group with the same lists
-- @param compareFn optional function(a, b) returning true when a comes before b
-- @return new Group with keys sorted
function Group:sort(compareFn)
	local keys = utils.deepCopy(self.keyOrder)

	if compareFn then
		assert(type(compareFn) == "function", "Expected function or nil, got " .. type(compareFn))
		table.sort(keys, compareFn)
	else
		table.sort(keys)
	end

	return Group.new(self.lists, keys)
end

--- randomize key order, returning a new Group with the same lists
-- @return new Group with shuffled key order
function Group:shuffle()
	local keys = utils.deepCopy(self.keyOrder)
	utils.shuffle(keys)
	return Group.new(self.lists, keys)
end

--- support pairs(group) so callers can iterate key, list without :keys()/:get()
-- iteration order matches insertion order
-- @return iterator suitable for for key, list in pairs(group)
function Group:__pairs()
	local keyOrder = self.keyOrder
	local index = 0
	return function()
		index = index + 1
		local key = keyOrder[index]
		if key == nil then
			return nil
		end
		return key, self.lists[key]
	end
end

--- add a table or list to the group with the given key
-- @param key key to associate with the list
-- @param list table or list to add
-- @return self to support chaining
function Group:add(key, list)
	assert(key ~= nil, "Key cannot be nil")
	if self.lists[key] == nil then
		table.insert(self.keyOrder, key)
	end
	self.lists[key] = toListObject(list, key)
	return self
end

--- remove the key and associated list from the group
-- @param key key to remove
-- @return self to support chaining
function Group:remove(key)
	if self.lists[key] ~= nil then
		self.lists[key] = nil
		for i, k in ipairs(self.keyOrder) do
			if k == key then
				table.remove(self.keyOrder, i)
				break
			end
		end
	end
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
		for _, key in ipairs(self.keyOrder) do
			workingPools[key] = utils.deepCopy(self.lists[key].items)
		end
	end

	for i, item in ipairs(targets) do
		-- same asTableKey normalization as groupBy so enum selectors match
		local key = utils.asTableKey(utils.getValue(item, selectorFnOrField, i))
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
	local keyOrder = {}
	self:each(function(key, list)
		if not list:isEmpty() then
			kept[key] = list
			table.insert(keyOrder, key)
		end
	end)
	return Group.new(kept, keyOrder)
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
	return #self.keyOrder
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
-- @return List of all keys in insertion order
function Group:keys()
	return List.new(utils.deepCopy(self.keyOrder))
end

-- string representation for debugging
function Group:__tostring()
	return "Group(" .. self:groupCount() .. " groups, " .. self:itemCount() .. " items)"
end

return Group
