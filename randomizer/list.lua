-- list.lua
-- List class for managing and randomizing single lists

local utils = require("randomizer.utils")

local List = {}
List.__index = List

-- Constructor
function List.new(items)
    assert(type(items) == "table", "Expected table, got " .. type(items))

    local self = setmetatable({}, List)
    self._type = "List"
    self.items = utils.deepCopy(items)

    return self
end

-- Filter items based on predicate function
-- Returns new List with filtered items
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

-- Sort items with optional comparator function
-- Returns new List with sorted items
function List:sort(compareFn)
    local sorted = utils.deepCopy(self.items)

    if compareFn then
        assert(type(compareFn) == "function", "Expected function or nil, got " .. type(compareFn))
        table.sort(sorted, compareFn)
    else
        table.sort(sorted)
    end

    return List.new(sorted)
end

-- Remove duplicate values
-- Returns new List with duplicates removed
function List:removeDuplicates()
    local unique = utils.removeDuplicates(self.items)
    return List.new(unique)
end

-- Select specific items by indices
-- indices can be a single index or a table of indices
-- Returns new List with selected items
function List:select(indices)
    if type(indices) == "number" then
        indices = {indices}
    end

    assert(type(indices) == "table", "Expected number or table, got " .. type(indices))

    local selected = {}
    for _, index in ipairs(indices) do
        if self.items[index] then
            table.insert(selected, self.items[index])
        end
    end

    return List.new(selected)
end

-- Shuffle items randomly
-- Returns new List with shuffled items
function List:shuffle()
    local shuffled = utils.deepCopy(self.items)
    utils.shuffle(shuffled)
    return List.new(shuffled)
end

-- Randomize a target list by replacing each item with a random value from this list
-- Modifies targetList in place
-- Returns the modified targetList for convenience
-- Optional setter: function(item, value) to set value on item, or string field name
function List:randomize(targetList, setter)
    assert(type(targetList) == "table", "Expected table, got " .. type(targetList))
    assert(#self.items > 0, "Cannot randomize from empty list")

    if setter then
        -- Setter can be a field name (string) or a function
        if type(setter) == "string" then
            local fieldName = setter
            for i = 1, #targetList do
                targetList[i][fieldName] = utils.randomElement(self.items)
            end
        elseif type(setter) == "function" then
            for i = 1, #targetList do
                setter(targetList[i], utils.randomElement(self.items), i)
            end
        else
            error("Setter must be a string (field name) or function, got " .. type(setter))
        end
    else
        -- Original behavior: replace array elements directly
        for i = 1, #targetList do
            targetList[i] = utils.randomElement(self.items)
        end
    end

    return targetList
end

-- Convert back to plain table
function List:toTable()
    return utils.deepCopy(self.items)
end

-- Get the number of items in the list
function List:size()
    return #self.items
end

-- Check if list is empty
function List:isEmpty()
    return #self.items == 0
end

-- Get item at specific index
function List:get(index)
    return self.items[index]
end

-- String representation for debugging
function List:__tostring()
    return "List(" .. #self.items .. " items)"
end

return List



