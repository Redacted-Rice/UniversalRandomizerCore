-- group.lua
-- Group class for managing multiple lists with key-based selection

local utils = require("randomizer.utils")
local List = require("randomizer.list")

local Group = {}
Group.__index = Group

-- Constructor
-- listsMap: table of {key = list/table}
function Group.new(listsMap)
    assert(type(listsMap) == "table", "Expected table, got " .. type(listsMap))

    local self = setmetatable({}, Group)
    self._type = "Group"
    self.lists = {}

    -- Convert plain tables to List objects and store
    for key, list in pairs(listsMap) do
        if utils.isList(list) then
            self.lists[key] = list
        elseif type(list) == "table" then
            self.lists[key] = List.new(list)
        else
            error("Expected List or table for key '" .. tostring(key) .. "', got " .. type(list))
        end
    end

    return self
end

-- Static method: Create a group from a list by grouping items based on keyExtractor function
-- list: table of items
-- keyExtractor: function that takes an item and returns a key
function Group.groupBy(list, keyExtractor)
    assert(type(list) == "table", "Expected table, got " .. type(list))
    assert(type(keyExtractor) == "function", "Expected function, got " .. type(keyExtractor))

    local grouped = {}

    for i, item in ipairs(list) do
        local key = keyExtractor(item, i)
        if key ~= nil then
            if not grouped[key] then
                grouped[key] = {}
            end
            table.insert(grouped[key], item)
        end
    end

    return Group.new(grouped)
end

-- Add a list to the group
-- Returns self for chaining
function Group:add(key, list)
    assert(key ~= nil, "Key cannot be nil")

    if utils.isList(list) then
        self.lists[key] = list
    elseif type(list) == "table" then
        self.lists[key] = List.new(list)
    else
        error("Expected List or table, got " .. type(list))
    end

    return self
end

-- Remove a list from the group
-- Returns self for chaining
function Group:remove(key)
    self.lists[key] = nil
    return self
end

-- Get a list by key
function Group:get(key)
    return self.lists[key]
end

-- Get all keys in the group
function Group:keys()
    local keys = {}
    for key in pairs(self.lists) do
        table.insert(keys, key)
    end
    return keys
end

-- Filter all lists in the group with the same predicate
-- Returns new Group with filtered lists
function Group:filter(predicate)
    assert(type(predicate) == "function", "Expected function, got " .. type(predicate))

    local filtered = {}
    for key, list in pairs(self.lists) do
        filtered[key] = list:filter(predicate)
    end

    return Group.new(filtered)
end

-- Remove duplicates from all lists in the group
-- Returns new Group with deduplicated lists
function Group:removeDuplicates()
    local deduplicated = {}
    for key, list in pairs(self.lists) do
        deduplicated[key] = list:removeDuplicates()
    end

    return Group.new(deduplicated)
end

-- Shuffle all lists in the group
-- Returns new Group with shuffled lists
function Group:shuffle()
    local shuffled = {}
    for key, list in pairs(self.lists) do
        shuffled[key] = list:shuffle()
    end

    return Group.new(shuffled)
end

-- Sort all lists in the group with optional comparator
-- Returns new Group with sorted lists
function Group:sort(compareFn)
    local sorted = {}
    for key, list in pairs(self.lists) do
        sorted[key] = list:sort(compareFn)
    end

    return Group.new(sorted)
end

-- Randomize a target list using selector function to pick which list to use per item
-- selectorFn: function(item, index) -> key
-- Modifies targetList in place
-- Returns the modified targetList for convenience
-- Optional setter: function(item, value, index) to set value on item, or string field name
function Group:randomize(targetList, selectorFn, setter)
    assert(type(targetList) == "table", "Expected table, got " .. type(targetList))
    assert(type(selectorFn) == "function", "Expected function, got " .. type(selectorFn))

    if setter then
        -- Setter can be a field name (string) or a function
        if type(setter) == "string" then
            local fieldName = setter
            for i, item in ipairs(targetList) do
                local key = selectorFn(item, i)
                local list = self.lists[key]

                if not list then
                    error("No list found for key '" .. tostring(key) .. "' at index " .. i)
                end

                if list:isEmpty() then
                    error("List for key '" .. tostring(key) .. "' is empty")
                end

                targetList[i][fieldName] = utils.randomElement(list.items)
            end
        elseif type(setter) == "function" then
            for i, item in ipairs(targetList) do
                local key = selectorFn(item, i)
                local list = self.lists[key]

                if not list then
                    error("No list found for key '" .. tostring(key) .. "' at index " .. i)
                end

                if list:isEmpty() then
                    error("List for key '" .. tostring(key) .. "' is empty")
                end

                setter(targetList[i], utils.randomElement(list.items), i)
            end
        else
            error("Setter must be a string (field name) or function, got " .. type(setter))
        end
    else
        -- Original behavior: replace array elements directly
        for i, item in ipairs(targetList) do
            local key = selectorFn(item, i)
            local list = self.lists[key]

            if not list then
                error("No list found for key '" .. tostring(key) .. "' at index " .. i)
            end

            if list:isEmpty() then
                error("List for key '" .. tostring(key) .. "' is empty")
            end

            targetList[i] = utils.randomElement(list.items)
        end
    end

    return targetList
end

-- Convert back to plain table of tables
function Group:toTable()
    local result = {}
    for key, list in pairs(self.lists) do
        result[key] = list:toTable()
    end
    return result
end

-- Get the number of lists in the group
function Group:size()
    local count = 0
    for _ in pairs(self.lists) do
        count = count + 1
    end
    return count
end

-- Check if group is empty
function Group:isEmpty()
    return self:size() == 0
end

-- String representation for debugging
function Group:__tostring()
    return "Group(" .. self:size() .. " lists)"
end

return Group



