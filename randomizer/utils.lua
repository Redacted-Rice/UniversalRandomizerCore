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
-- handles nested tables and preserves metatables
-- @param tbl table to copy
-- @return deep copy
function utils.deepCopy(tbl)
	if type(tbl) ~= "table" then
		return tbl
	end

	local copy = {}
	for key, value in pairs(tbl) do
		if type(value) == "table" then
			copy[key] = utils.deepCopy(value)
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

--- remove duplicate values from an array like table
-- note cannot not handle tables with circular references
-- @param tbl table to remove duplicates from
-- @return new table with duplicates removed preserving order
function utils.removeDuplicates(tbl)
	assert(type(tbl) == "table", "Expected table, got " .. type(tbl))

	local seen = {}
	local result = {}

	for _, value in ipairs(tbl) do
		-- todo later theres probably a better way to do this than serializing and comparing the strings but it works
		local key = value
		if type(value) == "table" then
			key = utils.serializeForComparison(value)
		end

		if not seen[key] then
			seen[key] = true
			table.insert(result, value)
		end
	end

	return result
end

--- quick serialization for duplicate checking
-- not a real serializer just good enough for comparison
-- @local
-- @param tbl table to serialize
-- @return string representation
function utils.serializeForComparison(tbl)
	if type(tbl) ~= "table" then
		return tostring(tbl)
	end

	local parts = {}
	-- sort keys for consistent comparison
	local keys = {}
	for k in pairs(tbl) do
		table.insert(keys, k)
	end
	table.sort(keys, function(a, b)
		return tostring(a) < tostring(b)
	end)

	for _, k in ipairs(keys) do
		local v = tbl[k]
		table.insert(parts, tostring(k) .. "=" .. utils.serializeForComparison(v))
	end

	return "{" .. table.concat(parts, ",") .. "}"
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

--- get a value from an object using a
-- 1 function like getvalue obj and function o return o x plus o y end
-- 2 field name like getvalue obj and health returns obj health
-- 3 method name like getvalue obj and gethealth calls obj gethealth
-- also converts userdata like java enums to strings for use as table keys
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
		-- handle non table objects gracefully
		if type(object) ~= "table" then
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
	else
		-- call the getter function
		value = getterFnOrField(object, ...)
	end

	-- convert userdata to string for java enums etc so it works as table keys
	if value ~= nil and type(value) == "userdata" then
		value = tostring(value)
	end

	return value
end

--- set a value on an object using a
-- 1 function like setvalue obj and function o v then o x equals v end and value
-- 2 field name like setvalue obj and health and value sets obj health equals value
-- 3 method name like setvalue obj and sethealth and value calls obj sethealth value
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
		local member = object[setterFnOrField]
		if type(member) == "function" then
			-- its a method
			member(object, value, ...)
		else
			-- just a field
			object[setterFnOrField] = value
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
