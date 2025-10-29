-- init.lua
-- Main entry point for the randomizer library

local utils = require("randomizer.utils")
local List = require("randomizer.list")
local Group = require("randomizer.group")

local randomizer = {}

-- Expose utility functions
randomizer.setSeed = utils.setSeed

-- Expose constructors
randomizer.list = function(items)
    return List.new(items)
end

randomizer.group = function(listsMap)
    return Group.new(listsMap)
end

-- Expose static methods
randomizer.groupBy = function(list, keyExtractor)
    return Group.groupBy(list, keyExtractor)
end

-- Standalone helper functions for working with plain tables
randomizer.shuffle = function(tbl)
    return utils.shuffle(utils.deepCopy(tbl))
end

randomizer.filter = function(tbl, predicate)
    assert(type(tbl) == "table", "Expected table, got " .. type(tbl))
    assert(type(predicate) == "function", "Expected function, got " .. type(predicate))

    local filtered = {}
    for i, item in ipairs(tbl) do
        if predicate(item, i) then
            table.insert(filtered, item)
        end
    end
    return filtered
end

randomizer.removeDuplicates = function(tbl)
    return utils.removeDuplicates(tbl)
end

randomizer.sort = function(tbl, compareFn)
    local sorted = utils.deepCopy(tbl)
    if compareFn then
        table.sort(sorted, compareFn)
    else
        table.sort(sorted)
    end
    return sorted
end

randomizer.selectRandom = function(tbl, count)
    return utils.selectRandom(tbl, count)
end

-- Universal randomize function that works with both List and Group
-- For List: randomizer.randomize(targetList, list)
-- For Group: randomizer.randomize(targetList, group, selectorFn)
randomizer.randomize = function(targetList, source, selectorFn)
    assert(type(targetList) == "table", "Expected table for targetList, got " .. type(targetList))

    if utils.isList(source) then
        -- Simple list randomization
        return source:randomize(targetList)
    elseif utils.isGroup(source) then
        -- Grouped randomization
        assert(type(selectorFn) == "function", "selectorFn is required for Group randomization")
        return source:randomize(targetList, selectorFn)
    elseif type(source) == "table" then
        -- Plain table, treat as list
        local list = List.new(source)
        return list:randomize(targetList)
    else
        error("Expected List, Group, or table for source, got " .. type(source))
    end
end

-- Expose the classes for advanced usage
randomizer.List = List
randomizer.Group = Group

-- Version info
randomizer._VERSION = "0.7.0"
randomizer._DESCRIPTION = "Lua based randomization functions to support randomizing arbitrary lists of objects and their parameters"

return randomizer



