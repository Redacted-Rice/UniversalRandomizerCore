-- changedetector_spec.lua
-- Unit tests for the changedetector module

describe("ChangeDetector Module", function()
	local changedetector
	local randomizer

	-- Helper to suppress print output for tests that expect warnings or errors
	local function withSuppressedOutput(fn)
		local oldPrint = _G.print
		_G.print = function() end -- Suppress output
		local success, result = pcall(fn)
		_G.print = oldPrint -- Restore
		if not success then
			error(result)
		end
		return result
	end

	local function assignIds(objects)
		for index, object in ipairs(objects) do
			if object.id == nil then
				object.id = index
			end
		end
	end

	local function monitorFields(entryName, objects, fieldNames, primaryKeyField)
		assignIds(objects)
		local fields = {}
		for _, fieldName in ipairs(fieldNames) do
			table.insert(fields, { field = fieldName, header = fieldName })
		end

		changedetector.monitor(entryName, objects, {
			primaryKey = {
				field = primaryKeyField or "id",
				header = primaryKeyField or "ID",
				numeric = (primaryKeyField or "id") == "id",
			},
			fields = fields,
		})
	end

	setup(function()
		changedetector = require("randomizer.changedetector")
		randomizer = require("randomizer")
	end)

	before_each(function()
		-- Reset change detector state before each test
		changedetector.stopMonitoringAll()
		changedetector.configure(false)
	end)

	describe("configure", function()
		it("should set change detection", function()
			changedetector.configure(true)
			assert.is_true(changedetector.isActive())
			changedetector.configure(false)
			assert.is_false(changedetector.isActive())
			changedetector.configure()
			assert.is_false(changedetector.isActive())
		end)
	end)

	describe("isActive", function()
		it("should reflect configuration state", function()
			changedetector.configure(true)
			assert.is_true(changedetector.isActive())

			changedetector.configure(false)
			assert.is_false(changedetector.isActive())
		end)
	end)

	describe("monitor", function()
		it("should register a monitoring entry with simple fields", function()
			local objects = {
				{ name = "Item1", value = 10 },
				{ name = "Item2", value = 20 },
			}

			monitorFields("test_entry", objects, { "name", "value" })

			local entries = changedetector.getMonitoredEntryNames()
			assert.are.equal(1, #entries)
			assert.are.equal("test_entry", entries[1])
		end)

		it("should register multiple monitoring entries", function()
			local objects1 = { { value = 1 } }
			local objects2 = { { value = 2 } }

			monitorFields("entry1", objects1, { "value" })
			monitorFields("entry2", objects2, { "value" })

			local entries = changedetector.getMonitoredEntryNames()
			assert.are.equal(2, #entries)
		end)

		it("should handle custom primary key getter", function()
			local objects = {
				{ id = 1, value = 10 },
				{ id = 2, value = 20 },
			}

			changedetector.monitor("custom_id", objects, {
				primaryKey = {
					header = "ID",
					getter = function(obj)
						return "Object_" .. obj.id
					end,
				},
				fields = { { field = "value", header = "value" } },
			})

			local entries = changedetector.getMonitoredEntryNames()
			assert.are.equal(1, #entries)
		end)

		it("should warn and not register when missing required param", function()
			local objects = { { value = 1 } }
			withSuppressedOutput(function()
				changedetector.monitor(nil, objects, { fields = { { field = "value", header = "value" } } })
			end)
			assert.are.equal(0, #changedetector.getMonitoredEntryNames())

			withSuppressedOutput(function()
				changedetector.monitor("test", nil, { fields = { { field = "value", header = "value" } } })
			end)
			assert.are.equal(0, #changedetector.getMonitoredEntryNames())

			local objects = { { value = 1 } }
			withSuppressedOutput(function()
				changedetector.monitor("test", objects, nil)
			end)
			assert.are.equal(0, #changedetector.getMonitoredEntryNames())
		end)

		it("should warn when objects array is empty", function()
			withSuppressedOutput(function()
				changedetector.monitor("test", {}, {
					primaryKey = { field = "id", header = "ID" },
					fields = { { field = "value", header = "value" } },
				})
			end)
			assert.are.equal(0, #changedetector.getMonitoredEntryNames())
		end)

		it("should warn when config is invalid", function()
			local objects = { { value = 1 } }
			withSuppressedOutput(function()
				changedetector.monitor("test", objects, "value")
			end)
			assert.are.equal(0, #changedetector.getMonitoredEntryNames())

			withSuppressedOutput(function()
				changedetector.monitor("test", objects, {
					fields = { { field = "value", header = "value" } },
				})
			end)
			assert.are.equal(0, #changedetector.getMonitoredEntryNames())
		end)

		it("should accept fields with getter functions", function()
			local objects = {
				{ id = 1, _value = 10 },
			}

			changedetector.monitor("getter_test", objects, {
				primaryKey = { field = "id", header = "ID", numeric = true },
				fields = {
					{
						name = "value",
						header = "value",
						getter = function(obj)
							return obj._value
						end,
					},
				},
			})

			local entries = changedetector.getMonitoredEntryNames()
			assert.are.equal(1, #entries)
		end)
	end)

	describe("stopMonitoring", function()
		it("should stop monitoring a specific entry", function()
			local objects = { { value = 1 } }
			monitorFields("entry1", objects, { "value" })
			monitorFields("entry2", objects, { "value" })
			assert.are.equal(2, #changedetector.getMonitoredEntryNames())

			changedetector.stopMonitoring("entry1")

			local entries = changedetector.getMonitoredEntryNames()
			assert.are.equal(1, #entries)
			assert.are.equal("entry2", entries[1])
		end)

		it("should handle stopping nonexistent entry gracefully", function()
			changedetector.stopMonitoring("nonexistent")
			assert.are.equal(0, #changedetector.getMonitoredEntryNames())
		end)
	end)

	describe("stopMonitoringAll", function()
		it("should clear all monitoring entries", function()
			local objects = { { value = 1 } }
			monitorFields("entry1", objects, { "value" })
			monitorFields("entry2", objects, { "value" })
			monitorFields("entry3", objects, { "value" })
			assert.are.equal(3, #changedetector.getMonitoredEntryNames())

			changedetector.stopMonitoringAll()

			assert.are.equal(0, #changedetector.getMonitoredEntryNames())
		end)

		it("should handle clearing when no entries exist", function()
			changedetector.stopMonitoringAll()
			assert.are.equal(0, #changedetector.getMonitoredEntryNames())
		end)
	end)

	describe("getMonitoredEntryNames", function()
		it("should return empty list when no entries", function()
			local entries = changedetector.getMonitoredEntryNames()
			assert.are.equal(0, #entries)
		end)

		it("should return all entry names", function()
			local objects = { { value = 1 } }
			monitorFields("entry1", objects, { "value" })
			monitorFields("entry2", objects, { "value" })

			local entries = changedetector.getMonitoredEntryNames()
			assert.are.equal(2, #entries)

			-- Check both names are present in any order
			local hasEntry1 = false
			local hasEntry2 = false
			for _, name in ipairs(entries) do
				if name == "entry1" then
					hasEntry1 = true
				end
				if name == "entry2" then
					hasEntry2 = true
				end
			end
			assert.is_true(hasEntry1)
			assert.is_true(hasEntry2)
		end)
	end)

	describe("takeSnapshots", function()
		it("should do nothing when change detection is inactive", function()
			local objects = {
				{ value = 10 },
			}

			changedetector.configure(false)
			monitorFields("test", objects, { "value" })
			changedetector.takeSnapshots()
            -- we currently can't check the snapshots directly as they are not exposed
            -- Just make sure its still inactive and we dont error
			assert.is_false(changedetector.isActive())
		end)

		it("should capture initial state when active", function()
			local objects = {
				{ value = 10 },
			}

			changedetector.configure(true)
			monitorFields("test", objects, { "value" })
			changedetector.takeSnapshots()
            -- Again can't really verify beyond that it didn't error and doesn't show changes
			local changes = changedetector.detectChanges()
			assert.is_false(changedetector.hasChanges(changes))
		end)

		it("should update snapshot when called again", function()
			local objects = {
				{ value = 10 },
			}

            -- setup snapshot and then modify the object
			changedetector.configure(true)
			monitorFields("test", objects, { "value" })
			changedetector.takeSnapshots()
			objects[1].value = 20

			-- Take new snapshot and ensure it shows no changes since it
            -- should have been updated
			changedetector.takeSnapshots()
			local changes = changedetector.detectChanges()
			assert.is_false(changedetector.hasChanges(changes))
		end)

		it("should handle objects with method based getters", function()
			local Object = {}
			Object.__index = Object

			function Object.new(value)
				local instance = setmetatable({}, Object)
				instance._value = value
				return instance
			end

			function Object:getValue()
				return self._value
			end

			local objects = {
				Object.new(10),
				Object.new(20),
			}
			objects[1].id = 1
			objects[2].id = 2

			changedetector.configure(true)
			changedetector.monitor("test", objects, {
				primaryKey = { field = "id", header = "ID", numeric = true },
				fields = {
					{
						name = "value",
						header = "value",
						getter = function(obj)
							return obj:getValue()
						end,
					},
				},
			})
			changedetector.takeSnapshots()

            -- Methods should return the same values each time called so no changes
            -- will be shown
			local changes = changedetector.detectChanges()
			assert.is_false(changedetector.hasChanges(changes))
		end)

		it("should handle primary key getter errors gracefully", function()
			local objects = {
				{ id = 1, value = 10 },
			}

			changedetector.configure(true)
			changedetector.monitor("test", objects, {
				primaryKey = {
					header = "ID",
					getter = function()
						error("Key error")
					end,
				},
				fields = { { field = "value", header = "value" } },
			})

			withSuppressedOutput(function()
				changedetector.takeSnapshots()
			end)

			local changes = changedetector.detectChanges()
			assert.is_false(changedetector.hasChanges(changes))
		end)
	end)

	describe("detectChanges", function()
		it("should detect no changes when values are unchanged", function()
			local objects = {
				{ name = "Item1", value = 10 },
			}

			changedetector.configure(true)
			monitorFields("test", objects, { "name", "value" })
			changedetector.takeSnapshots()

			local changes = changedetector.detectChanges()
			assert.is_false(changedetector.hasChanges(changes))
		end)

		it("should detect simple field changes", function()
			local objects = {
				{ name = "Item1", value = 10 },
			}

            -- take snapshot then modify
			changedetector.configure(true)
			monitorFields("test", objects, { "name", "value" })
			changedetector.takeSnapshots()
			objects[1].value = 20

            -- Ensure it shows changes
			local changes = changedetector.detectChanges()
			assert.is_true(changedetector.hasChanges(changes))
			assert.is_not_nil(changes.test)
		end)

		it("should detect changes in multiple objects", function()
			local objects = {
				{ id = 1, value = 10 },
				{ id = 2, value = 20 },
				{ id = 3, value = 30 },
			}

            -- take snapshot and modify two of the 3
			changedetector.configure(true)
			monitorFields("test", objects, { "value" })
			changedetector.takeSnapshots()
			objects[1].value = 15
			objects[3].value = 35

			local changes = changedetector.detectChanges()
			assert.is_true(changedetector.hasChanges(changes))
			local changeCount = 0
			for rowKey in pairs(changes.test) do
				if rowKey ~= "_format" then
					changeCount = changeCount + 1
				end
			end

            -- All rows are included when any row changes
			assert.are.equal(3, changeCount)
		end)

		it("should detect changes in multiple fields", function()
			local objects = {
				{ name = "Item1", value = 10, status = "active" },
			}

            -- take snapshot and modify multiple fields
			changedetector.configure(true)
			monitorFields("test", objects, { "name", "value", "status" }, "name")
			changedetector.takeSnapshots()
			objects[1].value = 20
			objects[1].status = "inactive"

            -- Ensure both are shown
			local changes = changedetector.detectChanges()
			assert.is_true(changedetector.hasChanges(changes))

			local objChanges = changes.test["Item1"]
			assert.is_not_nil(objChanges.value)
			assert.is_not_nil(objChanges.status)
			assert.are.equal("Item1", objChanges.name.old)
			assert.are.equal("-", objChanges.name.new)
		end)

		it("should detect changes across multiple entries", function()
            -- Two monitor entries vs previous test which was multiple items in one entry
			local objects1 = { { value = 10 } }
			local objects2 = { { value = 20 } }

            -- take snapshot and modify both
			changedetector.configure(true)
			monitorFields("entry1", objects1, { "value" })
			monitorFields("entry2", objects2, { "value" })
			changedetector.takeSnapshots()
			objects1[1].value = 15
			objects2[1].value = 25

            -- Ensure both are shown
			local changes = changedetector.detectChanges()
			assert.is_true(changedetector.hasChanges(changes))
			assert.is_not_nil(changes.entry1)
			assert.is_not_nil(changes.entry2)
		end)

		it("should return empty changes when no snapshot exists", function()
			local objects = { { value = 10 } }

			changedetector.configure(true)
			monitorFields("test", objects, { "value" })
			-- Don't take snapshot

            -- Ensure no changes are shown and it doesn't crash
			local changes = changedetector.detectChanges()
			assert.is_false(changedetector.hasChanges(changes))
		end)

		it("should handle changes detected with custom primary key", function()
			local objects = {
				{ id = "A", value = 10 },
				{ id = "B", value = 20 },
			}

			changedetector.configure(true)
			changedetector.monitor("test", objects, {
				primaryKey = {
					header = "ID",
					getter = function(obj)
						return "Item_" .. obj.id
					end,
				},
				fields = { { field = "value", header = "value" } },
			})
			changedetector.takeSnapshots()
			objects[1].value = 15

			local changes = changedetector.detectChanges()
			assert.is_true(changedetector.hasChanges(changes))
			assert.is_not_nil(changes.test["Item_A"])
			assert.is_not_nil(changes.test["Item_B"])
		end)

		it("should provide old and new values in change records", function()
			local objects = {
				{ value = 10 },
			}

			changedetector.configure(true)
			monitorFields("test", objects, { "value" })
			changedetector.takeSnapshots()
			objects[1].value = 20

			local changes = changedetector.detectChanges()
			local objChanges = changes.test["1"]

            -- Check that the values are correct
			assert.are.equal("10", objChanges.value.old)
			assert.are.equal("20", objChanges.value.new)
		end)

		it("should detect changes with getter-based fields", function()
			local objects = {
				{ id = 1, _private = 10 },
			}

			changedetector.configure(true)
			changedetector.monitor("test", objects, {
				primaryKey = { field = "id", header = "ID", numeric = true },
				fields = {
					{
						name = "private",
						header = "private",
						getter = function(obj)
							return obj._private
						end,
					},
				},
			})
			changedetector.takeSnapshots()
			objects[1]._private = 20

			local changes = changedetector.detectChanges()
			assert.is_true(changedetector.hasChanges(changes))

			local objChanges = changes.test["1"]
			assert.is_not_nil(objChanges.private)
			assert.are.equal("10", objChanges.private.old)
			assert.are.equal("20", objChanges.private.new)
		end)

		it("should handle string value changes", function()
			local objects = {
				{ name = "original" },
			}

			changedetector.configure(true)
			monitorFields("test", objects, { "name" }, "name")
			changedetector.takeSnapshots()

			objects[1].name = "modified"

			local changes = changedetector.detectChanges()
			assert.is_true(changedetector.hasChanges(changes))

			local objChanges = changes.test["original"]
			assert.are.equal("original", objChanges.name.old)
			assert.are.equal("modified", objChanges.name.new)
		end)

		it("should handle boolean value changes", function()
			local objects = {
				{ active = true },
			}

			changedetector.configure(true)
			monitorFields("test", objects, { "active" })
			changedetector.takeSnapshots()

			objects[1].active = false

			local changes = changedetector.detectChanges()
			assert.is_true(changedetector.hasChanges(changes))
		end)

		it("should handle nil to value changes", function()
			local objects = {
				{ value = nil },
			}

			changedetector.configure(true)
			monitorFields("test", objects, { "value" })
			changedetector.takeSnapshots()

			objects[1].value = 10

			local changes = changedetector.detectChanges()
			-- nil fields are not captured in snapshot, so this shouldn't detect change
			-- This is expected behavior based on the implementation
			assert.is_false(changedetector.hasChanges(changes))
		end)

		it("should not detect changes when only unmonitored fields change", function()
			local objects = {
				{ monitored = 10, unmonitored = 20 },
			}

			changedetector.configure(true)
			monitorFields("test", objects, { "monitored" })
			changedetector.takeSnapshots()

			-- Only change unmonitored field
			objects[1].unmonitored = 30

			local changes = changedetector.detectChanges()
			assert.is_false(changedetector.hasChanges(changes))
		end)
	end)

	describe("hasChanges", function()
		it("should return false for empty changes", function()
			assert.is_false(changedetector.hasChanges({}))
		end)

		it("should return true for non-empty changes", function()
			local changes = {
				test = {
					["obj1"] = {
						value = { old = "10", new = "20" },
					},
				},
			}
			assert.is_true(changedetector.hasChanges(changes))
		end)
	end)

	describe("Edge cases and type handling", function()
		it("should handle changes from one type to another", function()
			local objects = {
				{ value = 10 },
			}

			changedetector.configure(true)
			monitorFields("test", objects, { "value" })
			changedetector.takeSnapshots()

			-- Change type from number to string
			objects[1].value = "ten"

			local changes = changedetector.detectChanges()
			assert.is_true(changedetector.hasChanges(changes))

			local objChanges = changes.test["1"]
			assert.are.equal("10", objChanges.value.old)
			assert.are.equal("ten", objChanges.value.new)
		end)

		it("should handle table value comparisons", function()
			local objects = {
				{ data = { x = 1, y = 2 } },
			}

			changedetector.configure(true)
			monitorFields("test", objects, { "data" })
			changedetector.takeSnapshots()

			-- Replace table with different table
			objects[1].data = { x = 3, y = 4 }

			local changes = changedetector.detectChanges()
			assert.is_true(changedetector.hasChanges(changes))
		end)

		it("should handle identical table values as unchanged", function()
			local sharedTable = { x = 1, y = 2 }
			local objects = {
				{ data = sharedTable },
			}

			changedetector.configure(true)
			monitorFields("test", objects, { "data" })
			changedetector.takeSnapshots()

			local changes = changedetector.detectChanges()
			-- Should not detect change since table reference is same
			assert.is_false(changedetector.hasChanges(changes))
		end)

		it("should handle number to nil changes", function()
			local objects = {
				{ value = 42 },
			}

			changedetector.configure(true)
			monitorFields("test", objects, { "value" })
			changedetector.takeSnapshots()

			-- Change to nil
			objects[1].value = nil

			local changes = changedetector.detectChanges()
			-- Should detect change from 42 to nil
			assert.is_true(changedetector.hasChanges(changes))
		end)
	end)

	describe("formatChangesTable", function()
		it("should return empty string when there are no changes", function()
			assert.are.equal("", changedetector.formatChangesTable({}))
		end)

		it("should format one row per object with field from/to columns from setup", function()
			changedetector.configure(true)
			local objects = {
				{ name = "Warrior", health = 101, damage = 21 },
				{ name = "Mage", health = 81, damage = 31 },
			}

			changedetector.monitor("entities", objects, {
				title = "entities",
				primaryKey = { field = "name", header = "Name" },
				fields = {
					{ field = "health", header = "health", align = "right" },
					{ field = "damage", header = "damage", align = "right" },
				},
			})
			changedetector.takeSnapshots()
			objects[1].health = 95
			objects[1].damage = 30
			objects[2].damage = 20

			local tableOutput = changedetector.formatChangesTable(changedetector.detectChanges())

			assert.matches("Changes detected for entities", tableOutput)
			assert.matches("|Name", tableOutput)
			assert.matches("|health From|health To|", tableOutput)
			assert.matches("|damage From|damage To|", tableOutput)
			assert.matches("|Warrior", tableOutput)
			assert.matches("101", tableOutput)
			assert.matches("95", tableOutput)
			assert.matches("|Mage", tableOutput)
		end)

		it("should use primary and description columns from setup", function()
			changedetector.configure(true)
			local objects = {
				{ id = 99, name = "Abra", hp = 30 },
			}

			changedetector.monitor("Monster Cards", objects, {
				title = "Monster Cards",
				primaryKey = { field = "id", header = "ID", align = "right", numeric = true },
				description = { field = "name", header = "Name" },
				fields = {
					{ field = "hp", header = "HP", align = "right" },
				},
			})
			changedetector.takeSnapshots()
			objects[1].hp = 40

			local tableOutput = changedetector.formatChangesTable(changedetector.detectChanges())

			assert.matches("|ID", tableOutput)
			assert.matches("|Name", tableOutput)
			assert.matches("|Abra", tableOutput)
			assert.matches("|99", tableOutput)
			assert.matches("HP From", tableOutput)
			assert.matches("HP To", tableOutput)
		end)

		it("should sort rows by numeric primary key", function()
			changedetector.configure(true)
			local objects = {
				{ id = 20, name = "B", hp = 1 },
				{ id = 10, name = "A", hp = 3 },
			}

			changedetector.monitor("cards", objects, {
				primaryKey = { field = "id", header = "ID", align = "right", numeric = true },
				description = { field = "name", header = "Name" },
				fields = { { field = "hp", header = "HP" } },
			})
			changedetector.takeSnapshots()
			objects[1].hp = 2
			objects[2].hp = 4

			local tableOutput = changedetector.formatChangesTable(changedetector.detectChanges())
			local first = tableOutput:find("|10|")
			local second = tableOutput:find("|20|")
			assert.is_true(first < second)
		end)

		it("should include all rows when any row has changes", function()
			changedetector.configure(true)
			local objects = {
				{ id = 1, name = "Warrior", health = 101 },
				{ id = 2, name = "Mage", health = 81 },
			}

			changedetector.monitor("entities", objects, {
				primaryKey = { field = "id", header = "ID", numeric = true },
				description = { field = "name", header = "Name" },
				fields = { { field = "health", header = "health", align = "right" } },
			})
			changedetector.takeSnapshots()
			objects[1].health = 95

			local tableOutput = changedetector.formatChangesTable(changedetector.detectChanges())
			assert.matches("|Warrior", tableOutput)
			assert.matches("|Mage", tableOutput)
			assert.matches("|        101|       95|", tableOutput)
			assert.matches("|         81|        %-|", tableOutput)
		end)

		it("should not crash when title is wider than initial table", function()
			changedetector.configure(true)
			local objects = { { id = 1, name = "A", hp = 10 } }

			changedetector.monitor("cards", objects, {
				title = "Monster Cards",
				primaryKey = { field = "id", header = "ID", align = "right", numeric = true },
				description = { field = "name", header = "Name" },
				fields = { { field = "hp", header = "HP", align = "right" } },
			})
			changedetector.takeSnapshots()
			objects[1].hp = 20

			local tableOutput = changedetector.formatChangesTable(changedetector.detectChanges())
			assert.matches("Changes detected for Monster Cards", tableOutput)
			assert.matches("HP From", tableOutput)
			assert.matches("HP To", tableOutput)
		end)

		it("should repeat the header every N rows when configured at setup", function()
			changedetector.configure(true)
			local objects = {}
			for index = 1, 35 do
				objects[index] = { id = "ITEM_" .. index, value = index }
			end

			changedetector.monitor("items", objects, {
				primaryKey = { field = "id", header = "ID" },
				fields = { { field = "value", header = "value" } },
				headerEvery = 30,
			})
			changedetector.takeSnapshots()
			for index = 1, 35 do
				objects[index].value = index + 1
			end

			local tableOutput = changedetector.formatChangesTable(changedetector.detectChanges())
			local _, headerCount = tableOutput:gsub("|value From|value To|", "")
			assert.are.equal(2, headerCount)
		end)

		it("should append a trailing header when configured at setup", function()
			changedetector.configure(true)
			local objects = { { id = 1, name = "A", hp = 10 } }

			changedetector.monitor("cards", objects, {
				primaryKey = { field = "id", header = "ID", numeric = true },
				description = { field = "name", header = "Name" },
				fields = { { field = "hp", header = "HP" } },
				trailingHeader = true,
			})
			changedetector.takeSnapshots()
			objects[1].hp = 20

			local tableOutput = changedetector.formatChangesTable(changedetector.detectChanges())
			local _, totalHeaderCount = tableOutput:gsub("HP From", "")
			assert.are.equal(2, totalHeaderCount)
		end)

		it("should emit one table per monitored entry", function()
			changedetector.configure(true)
			local entry1Objects = { { name = "ItemA", value = 10 } }
			local entry2Objects = { { name = "ItemB", value = 20 } }

			changedetector.monitor("entry1", entry1Objects, {
				primaryKey = { field = "name", header = "Name" },
				fields = { { field = "value", header = "value" } },
			})
			changedetector.monitor("entry2", entry2Objects, {
				primaryKey = { field = "name", header = "Name" },
				fields = { { field = "value", header = "value" } },
			})
			changedetector.takeSnapshots()
			entry1Objects[1].value = 15
			entry2Objects[1].value = 25

			local tableOutput = changedetector.formatChangesTable(changedetector.detectChanges())

			assert.matches("Changes detected for entry1", tableOutput)
			assert.matches("Changes detected for entry2", tableOutput)
			assert.matches("|ItemA", tableOutput)
			assert.matches("|15", tableOutput)
			assert.matches("|ItemB", tableOutput)
			assert.matches("|25", tableOutput)
		end)
	end)
end)
