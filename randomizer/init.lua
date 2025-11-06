--- main entry point for the randomizer library
-- provides lightweight wrappers for creating lists and groups
-- and universal randomization helpers
-- @module randomizer

local utils = require("randomizer.utils")
local List = require("randomizer.list")
local Group = require("randomizer.group")

local randomizer = {}
randomizer._VERSION = "0.9.0"
randomizer._DESCRIPTION =
	"Lua based randomization functions to support randomizing arbitrary lists of objects and their parameters"

--- set random seed for reproducibility
-- @function setSeed
randomizer.setSeed = utils.setSeed

--- check if object is a list instance
-- @function isList
randomizer.isList = utils.isList

--- check if object is a group instance
-- @function isGroup
randomizer.isGroup = utils.isGroup

--- create a new list from a table
-- @function list
randomizer.list = List.new

--- create a new group from a table of lists
-- @function group
randomizer.group = Group.new

--- create a group by grouping items based on a field or function
-- @function groupBy
randomizer.groupBy = Group.groupBy

--- create a list by extracting values from items
-- @function listFromField
randomizer.listFromField = List.fromField

--- create a group by grouping on one field and extracting another
-- @function groupFromField
randomizer.groupFromField = Group.fromField

--- randomize wrapper that handles calling list or group userandomize based on pool type
-- also handles native lua tables
-- @param toRandomize table of items to randomize
-- @param pool list group or table to use as pool
-- @param ... additional arguments passed to userandomize
-- @return the modified toRandomize table
function randomizer.randomize(toRandomize, pool, ...)
	assert(type(toRandomize) == "table", "Expected table for toRandomize, got " .. type(toRandomize))

	if utils.isList(pool) or utils.isGroup(pool) then
		return pool:useToRandomize(toRandomize, ...)
	elseif type(pool) == "table" then
		return List.new(pool):useToRandomize(toRandomize, ...)
	else
		error("Expected List, Group, or table for pool, got " .. type(pool))
	end
end

--- list class
-- @field List
randomizer.List = List

--- group class
-- @field Group
randomizer.Group = Group

return randomizer
