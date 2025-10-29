-- list.lua
-- List class for managing and randomizing single lists

local utils = require("randomizer.utils")

local List = {}
List.__index = List

-- Constructor
-- items: table of items
-- options: optional table with {consumable = bool, regenerate = bool}
--   consumable: if true, items are removed after being selected
--   regenerate: if true and consumable, regenerate pool when empty; if false, error when empty
function List.new(items, options)
    assert(type(items) == "table", "Expected table, got " .. type(items))

    local self = setmetatable({}, List)
    self._type = "List"
    self.originalItems = utils.deepCopy(items)  -- Keep original for regeneration
    self.items = utils.deepCopy(items)

    -- Parse options
    options = options or {}
    self.consumable = options.consumable or false
    self.regenerate = options.regenerate or false

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

    -- Check for empty list
    if #self.items == 0 then
        if self.consumable and self.regenerate then
            self:_regenerate()
        else
            error("Cannot randomize from empty list")
        end
    end

    if setter then
        -- Setter can be a field name (string) or a function
        if type(setter) == "string" then
            local fieldName = setter
            for i = 1, #targetList do
                local value = self:_selectItem()
                targetList[i][fieldName] = value
            end
        elseif type(setter) == "function" then
            for i = 1, #targetList do
                local value = self:_selectItem()
                setter(targetList[i], value, i)
            end
        else
            error("Setter must be a string (field name) or function, got " .. type(setter))
        end
    else
        -- Original behavior: replace array elements directly
        for i = 1, #targetList do
            local value = self:_selectItem()
            targetList[i] = value
        end
    end

    return targetList
end

-- Internal method to select an item (and consume if needed)
function List:_selectItem()
    if #self.items == 0 then
        if self.consumable and self.regenerate then
            self:_regenerate()
        else
            error("Cannot select from empty list")
        end
    end

    if self.consumable then
        -- Pick a random index and remove it
        local index = math.random(1, #self.items)
        local value = table.remove(self.items, index)
        return value
    else
        -- Non-consumable: just pick random element
        return utils.randomElement(self.items)
    end
end

-- Internal method to regenerate the pool
function List:_regenerate()
    self.items = utils.deepCopy(self.originalItems)
end

-- Convert back to plain table
function List:toTable()
    return utils.deepCopy(self.items)
end

-- Get the number of items in the list
function List:size()
    return #self.items
end

-- Get the number of remaining items (useful for consumable lists)
function List:remaining()
    return #self.items
end

-- Check if this list is consumable
function List:isConsumable()
    return self.consumable
end

-- Check if this list will regenerate when empty
function List:willRegenerate()
    return self.regenerate
end

-- Manually regenerate the pool (reset to original items)
function List:regenerate()
    if not self.consumable then
        error("Cannot regenerate non-consumable list")
    end
    self:_regenerate()
    return self
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



