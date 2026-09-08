--- Randomizer Utilities
-- Helper functions shared across the randomizer project.
-- @module randomizer.utils

local utils = {}

--- fisher yates shuffle in place
-- luas built in shuffle can behave oddly this is guaranteed unbiased
-- @param tbl table to shuffle
-- @return the shuffled table
function utils.shuffle(tbl)
	assert(type(tbl) == "table", "Expected table, got " .. type(tbl))

	for i = #tbl, 2, -1 do
		local j = math.random(1, i)
		tbl[i], tbl[j] = tbl[j], tbl[i]
	end

	return tbl
end

--- deep copy a table
-- handles nested tables, circular references, and preserves metatables
-- @param tbl table to copy
-- @return deep copy
local function deepCopyImpl(tbl, visited)
	if type(tbl) ~= "table" then
		return tbl
	end

	if visited[tbl] then
		return visited[tbl]
	end

	local copy = {}
	visited[tbl] = copy

	for key, value in pairs(tbl) do
		if type(value) == "table" then
			copy[key] = deepCopyImpl(value, visited)
		else
			copy[key] = value
		end
	end

	-- preserve metatable
	local mt = getmetatable(tbl)
	if mt then
		setmetatable(copy, mt)
	end

	return copy
end

function utils.deepCopy(tbl)
	return deepCopyImpl(tbl, {})
end

--- deep compare two values
-- tables are compared recursively. userdata uses tostring
-- circular table references are handled without recursing forever
-- @param a first value
-- @param b second value
-- @return true if values are equal
local function deepEqualImpl(a, b, visited)
	if a == b then
		return true
	end

	local typeA = type(a)
	local typeB = type(b)
	if typeA ~= typeB then
		return false
	end

	if typeA ~= "table" then
		if typeA == "userdata" then
			return tostring(a) == tostring(b)
		end
		return false
	end

	local seenForA = visited[a]
	if seenForA and seenForA[b] then
		return true
	end

	if not seenForA then
		seenForA = {}
		visited[a] = seenForA
	end
	seenForA[b] = true

	for key, value in pairs(a) do
		if not deepEqualImpl(value, b[key], visited) then
			return false
		end
	end

	for key in pairs(b) do
		if a[key] == nil then
			return false
		end
	end

	return true
end

function utils.deepEqual(a, b)
	return deepEqualImpl(a, b, {})
end

--- remove duplicate values from an array like table
-- table values are compared with deepEqual
-- @param tbl table to remove duplicates from
-- @return new table with duplicates removed preserving order
function utils.removeDuplicates(tbl)
	assert(type(tbl) == "table", "Expected table, got " .. type(tbl))

	local seen = {}
	local result = {}

	for _, value in ipairs(tbl) do
		if type(value) == "table" then
			local isDuplicate = false
			for _, existing in ipairs(result) do
				if type(existing) == "table" and utils.deepEqual(value, existing) then
					isDuplicate = true
					break
				end
			end

			if not isDuplicate then
				table.insert(result, value)
			end
		else
			local key = utils.asTableKey(value)
			if not seen[key] then
				seen[key] = true
				table.insert(result, value)
			end
		end
	end

	return result
end

--- check if object is a list instance
-- @param object object to check
-- @return true if its a list
function utils.isList(object)
	return type(object) == "table" and object._type == "List"
end

--- check if object is a group instance
-- @param object object to check
-- @return true if its a group
function utils.isGroup(object)
	return type(object) == "table" and object._type == "Group"
end

--- check if a table is array like (sequential integer keys from 1..n, or empty)
-- empty tables are treated as empty arrays
-- @param tbl table to check
-- @return true if array like
function utils.isArrayLike(tbl)
	if type(tbl) ~= "table" then
		return false
	end

	local length = #tbl
	if length == 0 then
		return next(tbl) == nil
	end

	for i = 1, length do
		if tbl[i] == nil then
			return false
		end
	end

	return true
end

--- normalize a List or plain array like table to the underlying items array
-- allows stream APIs to accept either List objects or raw tables easily
-- and handle them in a consistent way
-- @param listOrTable List or table of items
-- @return array like table of items
function utils.asArray(listOrTable)
	if utils.isList(listOrTable) then
		return listOrTable.items
	end
	assert(type(listOrTable) == "table", "Expected List or table, got " .. type(listOrTable))
	assert(utils.isArrayLike(listOrTable), "Expected array-like table, got non-sequential table")
	return listOrTable
end

--- set underlying random seed for reproducibility
-- @param seed number to use as random seed
function utils.setSeed(seed)
	math.randomseed(seed)
end

--- get a random element from a table
-- @param tbl table to select from
-- @return random element from the table
function utils.randomElement(tbl)
	assert(type(tbl) == "table", "Expected table, got " .. type(tbl))
	assert(#tbl > 0, "Cannot get random element from empty table")

	return tbl[math.random(1, #tbl)]
end

--- remove and return a random element from a table
-- consumes from the table
-- modified in place
-- @param tbl table to consume from
-- @return random element from the table and removes it from tbl
function utils.consumeRandomElement(tbl)
	assert(type(tbl) == "table", "Expected table, got " .. type(tbl))
	assert(#tbl > 0, "Cannot consume from empty table")

	local index = math.random(1, #tbl)
	local element = tbl[index]
	table.remove(tbl, index)
	return element
end

--- split a colon-separated field or method path into segments
-- @local
-- @param path string path with colon-separated segments
-- @return array of path segments
local function splitColonPath(path)
	local parts = {}
	for part in string.gmatch(path, "[^:]+") do
		table.insert(parts, part)
	end
	return parts
end

--- check whether a string path uses colon-separated segments
-- @local
-- @param path string path to inspect
-- @return true when the path contains a colon
local function hasColonPath(path)
	return string.find(path, ":", 1, true) ~= nil
end

--- normalize a value for use as a lua table key
-- java enums and other userdata become tostring so groupBy / lookups stay stable
-- leave other values alone so ints and strings keep working as keys
-- @param value value that will be used as a table key
-- @return key-safe value
function utils.asTableKey(value)
	if value ~= nil and type(value) == "userdata" then
		return tostring(value)
	end
	return value
end

--- get a value from an object using a
-- 1 function like getvalue obj and function o return o x plus o y end
-- 2 field name like getvalue obj and health returns obj health
-- 3 method name like getvalue obj and gethealth calls obj gethealth
-- 4 colon-separated path like getvalue obj and gethost type calls gethost then reads type
-- returns the raw value including java enum userdata. for table keys use asTableKey
-- this function is the common function used by any apis that take a function to handle multiple
-- options cleanly and consistently
-- @param object table or object to get value from
-- @param getterFnOrField function or function name or field that returns the value to get
-- @param ... extra args for function or method calls
-- @return value from object
function utils.getValue(object, getterFnOrField, ...)
	local getterType = type(getterFnOrField or "")
	assert(
		getterType == "string" or getterType == "function",
		"Expected string or function for getterFnOrField, got " .. getterType
	)

	local value
	if getterType == "string" then
		if hasColonPath(getterFnOrField) then
			value = object
			for _, part in ipairs(splitColonPath(getterFnOrField)) do
				value = utils.getValue(value, part, ...)
				if value == nil then
					return nil
				end
			end
		else
			-- handle non table/userdata objects gracefully
			local objectType = type(object)
			if objectType ~= "table" and objectType ~= "userdata" then
				return nil
			end

			-- try field or method access
			local member = object[getterFnOrField]
			if member == nil then
				return nil
			end

			-- if its a function call it otherwise just return the field
			if type(member) == "function" then
				value = member(object, ...)
			else
				value = member
			end
		end
	else
		-- call the getter function
		value = getterFnOrField(object, ...)
	end

	return value
end

--- set a value on an object using a
-- 1 function like setvalue obj and function o v then o x equals v end and value
-- 2 field name like setvalue obj and health and value sets obj health equals value
-- 3 method name like setvalue obj and sethealth and value calls obj sethealth value
-- 4 colon-separated path like setvalue obj and host value and 10 sets obj host value to 10
-- @param object table or object to set value on
-- @param setterFnOrField function or function name or field that sets the value on the object
-- @param value the value to set
-- @param ... extra args for function or method calls
function utils.setValue(object, setterFnOrField, value, ...)
	local setterType = type(setterFnOrField or "")
	assert(
		setterType == "string" or setterType == "function",
		"Expected string or function for setterFnOrField, got " .. setterType
	)

	if setterType == "string" then
		if hasColonPath(setterFnOrField) then
			local parts = splitColonPath(setterFnOrField)
			assert(#parts > 0, "Invalid empty colon-separated path")

			local target = object
			for i = 1, #parts - 1 do
				target = utils.getValue(target, parts[i])
				if target == nil then
					error("Cannot set value: path segment '" .. parts[i] .. "' resolved to nil")
				end
			end

			utils.setValue(target, parts[#parts], value, ...)
		else
			local member = object[setterFnOrField]
			if type(member) == "function" then
				-- its a method
				member(object, value, ...)
			else
				-- just a field
				object[setterFnOrField] = value
			end
		end
	else
		-- call the setter function
		setterFnOrField(object, value, ...)
	end
end

--- parse pool options to support randomization functions
-- @param poolOptions optional table with consumable and regenerate flags
-- @return consumable bool and regenerate bool both default to false
function utils.parsePoolOptions(poolOptions)
	local consumable = false
	local regenerate = false

	if poolOptions ~= nil then
		assert(type(poolOptions) == "table", "Options must be a table, got " .. type(poolOptions))
		if poolOptions.consumable then
			consumable = poolOptions.consumable
		end
		if poolOptions.regenerate then
			regenerate = poolOptions.regenerate
		end
	end

	return consumable, regenerate
end

return utils
