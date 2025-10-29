-- utils.lua
-- Helper utilities for the randomizer library

local utils = {}

-- Fisher-Yates shuffle algorithm (in-place)
-- Returns the shuffled table for chaining
function utils.shuffle(tbl)
    assert(type(tbl) == "table", "Expected table, got " .. type(tbl))

    for i = #tbl, 2, -1 do
        local j = math.random(1, i)
        tbl[i], tbl[j] = tbl[j], tbl[i]
    end

    return tbl
end

-- Deep copy a table (handles nested tables)
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

    -- Preserve metatable
    local mt = getmetatable(tbl)
    if mt then
        setmetatable(copy, mt)
    end

    return copy
end

-- Remove duplicate values from a table (array-like)
-- Returns a new table with duplicates removed, preserving order
function utils.removeDuplicates(tbl)
    assert(type(tbl) == "table", "Expected table, got " .. type(tbl))

    local seen = {}
    local result = {}

    for _, value in ipairs(tbl) do
        -- For simple values, use direct comparison
        -- For tables, we need to serialize them for comparison
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

-- Simple serialization for comparison purposes only
function utils.serializeForComparison(tbl)
    if type(tbl) ~= "table" then
        return tostring(tbl)
    end

    local parts = {}
    -- Sort keys for consistent comparison
    local keys = {}
    for k in pairs(tbl) do
        table.insert(keys, k)
    end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)

    for _, k in ipairs(keys) do
        local v = tbl[k]
        table.insert(parts, tostring(k) .. "=" .. utils.serializeForComparison(v))
    end

    return "{" .. table.concat(parts, ",") .. "}"
end

-- Check if a value is a List instance
function utils.isList(value)
    return type(value) == "table" and value._type == "List"
end

-- Check if a value is a Group instance
function utils.isGroup(value)
    return type(value) == "table" and value._type == "Group"
end

-- Set random seed for reproducibility
function utils.setSeed(seed)
    math.randomseed(seed)
end

-- Get a random element from a table
function utils.randomElement(tbl)
    assert(type(tbl) == "table", "Expected table, got " .. type(tbl))
    assert(#tbl > 0, "Cannot get random element from empty table")

    return tbl[math.random(1, #tbl)]
end

-- Select multiple random elements from a table (with replacement)
function utils.selectRandom(tbl, count)
    assert(type(tbl) == "table", "Expected table, got " .. type(tbl))
    assert(type(count) == "number" and count > 0, "Count must be a positive number")
    assert(#tbl > 0, "Cannot select from empty table")

    local result = {}
    for i = 1, count do
        table.insert(result, utils.randomElement(tbl))
    end

    return result
end

-- Check if table is array-like (has sequential integer keys starting from 1)
function utils.isArray(tbl)
    if type(tbl) ~= "table" then
        return false
    end

    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end

    return count == #tbl
end

return utils



