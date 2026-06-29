-- datatable_spec.lua
-- Unit tests for the datatable module

describe("DataTable Module", function()
	local datatable

	setup(function()
		datatable = require("randomizer.datatable")
	end)

	it("should return empty string when there are no objects", function()
		assert.are.equal("", datatable.format({}, {
			primaryKey = { field = "id", header = "ID" },
			fields = { { field = "value", header = "value" } },
		}))
	end)

	it("should format objects with primary key, description, and field columns", function()
		local objects = {
			{ id = 20, name = "otherMonster", level = 10, hp = 40, move1 = "moveA", move2 = "" },
			{ id = 10, name = "monster", level = 15, hp = 30, move1 = "moveB", move2 = "moveC" },
		}

		local tableOutput = datatable.format(objects, {
			title = "Monster Cards",
			primaryKey = { field = "id", header = "ID", align = "right", numeric = true },
			description = { field = "name", header = "Name" },
			fields = {
				{ field = "level", header = "Lvl", align = "right" },
				{ field = "hp", header = "HP", align = "right" },
				{ field = "move1", header = "Move 1" },
				{ field = "move2", header = "Move 2" },
			},
		})

		assert.matches("Monster Cards", tableOutput)
		assert.matches("|ID|Name", tableOutput)
		assert.matches("|Lvl|", tableOutput)
		assert.matches("Move 1", tableOutput)
		assert.matches("|monster", tableOutput)
		assert.matches("|otherMonster", tableOutput)
		assert.matches("moveB", tableOutput)

		local monsterPos = tableOutput:find("|monster")
		local otherMonsterPos = tableOutput:find("|otherMonster")
		assert.is_true(monsterPos < otherMonsterPos)
	end)

	it("should prepend a newline when leadingNewline is enabled", function()
		local objects = { { id = 1, name = "A", hp = 10 } }

		local tableOutput = datatable.format(objects, {
			primaryKey = { field = "id", header = "ID", numeric = true },
			fields = { { field = "hp", header = "HP" } },
		}, {
			leadingNewline = true,
		})

		assert.matches("^\n", tableOutput)
	end)
end)
