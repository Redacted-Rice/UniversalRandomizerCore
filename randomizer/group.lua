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

-- Static factory method: Create a group from objects by grouping on one field and extracting another
-- objects: table of objects
-- groupField: string name of field to group by
-- valueField: string name of field to extract as values (optional, if nil uses whole objects)
-- Returns new Group with lists of values grouped by groupField
function Group.fromField(objects, groupField, valueField)
    assert(type(objects) == "table", "Expected table, got " .. type(objects))

    local groupFieldType = type(groupField)
    assert(groupFieldType == "string" or groupFieldType == "function",
        "Expected string or function for groupField, got " .. groupFieldType)

    local valueFieldType = type(valueField)
    if valueField ~= nil then
        assert(valueFieldType == "string" or valueFieldType == "function",
            "Expected string, function, or nil for valueField, got " .. valueFieldType)
    end

    local grouped = {}

    for _, obj in ipairs(objects) do
        local key = utils.extractValue(obj, groupField)

        if key ~= nil then
            if not grouped[key] then
                grouped[key] = {}
            end

            local value
            if valueField == nil then
                value = obj
            else
                value = utils.extractValue(obj, valueField, key)
            end
            if value ~= nil then
                table.insert(grouped[key], value)
            end
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

-- Use this grouped pool to randomize a target list using selector function to pick which pool to use per item
-- selectorFn: function(item, index) -> key
-- Modifies targetList in place
-- Returns the modified targetList for convenience
-- Optional setter: function(item, value, index) to set value on item, or string field name
-- Optional options: table with consumable (boolean) and regenerate (boolean) flags
function Group:useToRandomize(targetList, selectorFn, setter, options)
    assert(type(targetList) == "table", "Expected table, got " .. type(targetList))
    assert(type(selectorFn) == "function", "Expected function, got " .. type(selectorFn))

    -- Parse options (can be passed as 3rd arg when no setter, or 4th arg with setter)
    local consumable = false
    local regenerate = false
    local actualSetter = setter
    local actualOptions = options

    -- If setter is a table, it might be the options
    if type(setter) == "table" and options == nil then
        actualOptions = setter
        actualSetter = nil
    end

    if actualOptions ~= nil then
        assert(type(actualOptions) == "table", "Options must be a table, got " .. type(actualOptions))
        consumable = actualOptions.consumable or false
        regenerate = actualOptions.regenerate or false
    end

    -- For consumable pools, create working copies for each group
    local workingPools = {}
    if consumable then
        for key, list in pairs(self.lists) do
            workingPools[key] = utils.deepCopy(list.items)
        end
    end

    -- Helper function to get a random element from a specific group
    local function getRandomElementFromGroup(key)
        local list = self.lists[key]

        if not list then
            error("No list found for key '" .. tostring(key) .. "'")
        end

        if list:isEmpty() then
            error("List for key '" .. tostring(key) .. "' is empty")
        end

        if consumable then
            local pool = workingPools[key]
            if #pool == 0 then
                if regenerate then
                    -- Refill this group's pool
                    pool = utils.deepCopy(list.items)
                    workingPools[key] = pool
                else
                    error("Pool for key '" .. tostring(key) .. "' depleted and regenerate is false")
                end
            end
            -- Remove and return a random element
            local index = math.random(1, #pool)
            local element = pool[index]
            table.remove(pool, index)
            return element
        else
            return utils.randomElement(list.items)
        end
    end

    if actualSetter then
        -- Setter can be a field name (string) or a function
        if type(actualSetter) == "string" then
            local fieldName = actualSetter
            for i, item in ipairs(targetList) do
                local key = selectorFn(item, i)
                targetList[i][fieldName] = getRandomElementFromGroup(key)
            end
        elseif type(actualSetter) == "function" then
            for i, item in ipairs(targetList) do
                local key = selectorFn(item, i)
                actualSetter(targetList[i], getRandomElementFromGroup(key), i)
            end
        else
            error("Setter must be a string (field name) or function, got " .. type(actualSetter))
        end
    else
        -- Original behavior: replace array elements directly
        for i, item in ipairs(targetList) do
            local key = selectorFn(item, i)
            targetList[i] = getRandomElementFromGroup(key)
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



