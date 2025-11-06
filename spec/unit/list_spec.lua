describe("List Module", function()
	local randomizer

	setup(function()
		randomizer = require("randomizer")
	end)

	describe("Constructor and Basic Operations", function()
		it("should create a list and convert back to table", function()
			local items = { 1, 2, 3, 4, 5 }
			local list = randomizer.list(items)

			assert.are.equal(5, list:size())
			assert.is_false(list:isEmpty())

			local result = list:toTable()
			assert.are.same({ 1, 2, 3, 4, 5 }, result)
		end)

		it("should handle empty lists gracefully", function()
			local list = randomizer.list({})
			assert.is_true(list:isEmpty())
			assert.are.equal(0, list:size())
		end)

		it("should get item at specific index", function()
			local list = randomizer.list({ "a", "b", "c" })
			assert.are.equal("a", list:get(1))
			assert.are.equal("b", list:get(2))
			assert.are.equal("c", list:get(3))
		end)

		it("should have string representation", function()
			local list = randomizer.list({ 1, 2, 3 })
			local str = tostring(list)
			assert.are.equal("List(3 items)", str)
		end)
	end)

	describe("fromField", function()
		it("should create a list using a field name", function()
			local objects = {
				{ value = 10 },
				{ value = 20 },
				{ value = nil },
				{ other = 5 },
			}

			local list = randomizer.listFromField(objects, "value")

			assert.are.same({ 10, 20 }, list:toTable())
		end)

		it("should create a list using a anonymous function", function()
			local objects = {
				{ value = 2, include = true },
				{ value = 3, include = false },
				{ value = 4, include = true },
			}

			local list = randomizer.listFromField(objects, function(obj)
				if obj.include then
					return obj.value
				end
			end)

			assert.are.same({ 2, 4 }, list:toTable())
		end)

		it("should create a list using a function name", function()
			local Object = {}
			Object.__index = Object

			-- define a constructor
			function Object.new(value)
				local instance = setmetatable({}, Object)
				instance.value = value or 0
				return instance
			end

			-- define a method
			function Object:getValue()
				return self.value
			end

			local objects = {
				Object.new(2),
				Object.new(3),
				Object.new(4),
			}

			local list = randomizer.listFromField(objects, "getValue")

			assert.are.same({ 2, 3, 4 }, list:toTable())
		end)

		it("should error when extractor is not string or function", function()
			local objects = { { value = 1 } }

			assert.has_error(function()
				randomizer.listFromField(objects, 123)
			end)
		end)
	end)

	describe("Filter", function()
		it("should filter items from a list", function()
			local list = randomizer.list({ 1, 2, 3, 4, 5, 6 })
			local filtered = list:filter(function(x)
				return x > 3
			end)

			assert.are.same({ 4, 5, 6 }, filtered:toTable())
		end)
	end)

	describe("Remove Duplicates", function()
		it("should remove duplicates from a list", function()
			local list = randomizer.list({ 1, 2, 2, 3, 3, 3, 4 })
			local unique = list:removeDuplicates()

			assert.are.same({ 1, 2, 3, 4 }, unique:toTable())
		end)

		it("should remove duplicate tables using serialization", function()
			local list = randomizer.list({
				{ id = 1, name = "a" },
				{ id = 2, name = "b" },
				{ id = 1, name = "a" }, -- duplicate
				{ id = 3, name = "c" },
				{ id = 2, name = "b" }, -- duplicate
			})

			local unique = list:removeDuplicates()
			local result = unique:toTable()

			assert.are.equal(3, #result)
		end)
	end)

	describe("Sort", function()
		it("should sort a list", function()
			local list = randomizer.list({ 5, 2, 8, 1, 9 })
			local sorted = list:sort()

			assert.are.same({ 1, 2, 5, 8, 9 }, sorted:toTable())
		end)

		it("should sort with custom comparator", function()
			local list = randomizer.list({ 5, 2, 8, 1, 9 })
			local sorted = list:sort(function(a, b)
				return a > b
			end)

			assert.are.same({ 9, 8, 5, 2, 1 }, sorted:toTable())
		end)
	end)

	describe("Select", function()
		it("should select/extract field values from objects", function()
			local list = randomizer.list({
				{ id = 1, name = "Alice" },
				{ id = 2, name = "Bob" },
				{ id = 3, name = "Charlie" },
			})
			local selected = list:select("name")

			assert.are.same({ "Alice", "Bob", "Charlie" }, selected:toTable())
		end)

		it("should select/extract using a function", function()
			local list = randomizer.list({
				{ value = 10, bonus = 5 },
				{ value = 20, bonus = 10 },
				{ value = 30, bonus = 15 },
			})
			local selected = list:select(function(item)
				return item.value + item.bonus
			end)

			assert.are.same({ 15, 30, 45 }, selected:toTable())
		end)

		it("should skip nil values when selecting", function()
			local list = randomizer.list({
				{ name = "Alice" },
				{ other = "data" },
				{ name = "Bob" },
			})
			local selected = list:select("name")

			assert.are.same({ "Alice", "Bob" }, selected:toTable())
		end)

		it("should work with method name strings", function()
			local Object = {}
			Object.__index = Object

			function Object.new(value)
				local instance = setmetatable({}, Object)
				instance.value = value
				return instance
			end

			function Object:getValue()
				return self.value * 2
			end

			local list = randomizer.list({
				Object.new(5),
				Object.new(10),
				Object.new(15),
			})

			local selected = list:select("getValue")
			assert.are.same({ 10, 20, 30 }, selected:toTable())
		end)

		it("should error when selector is invalid type", function()
			local list = randomizer.list({ 1, 2, 3 })

			assert.has_error(function()
				list:select(42)
			end)
		end)
	end)

	describe("Shuffle", function()
		it("should shuffle items", function()
			randomizer.setSeed(42)
			local list = randomizer.list({ 1, 2, 3, 4, 5 })
			local shuffled = list:shuffle()

			-- Should have same elements
			local sorted = shuffled:sort():toTable()
			assert.are.same({ 1, 2, 3, 4, 5 }, sorted)
		end)
	end)

	describe("Chaining", function()
		it("should chain multiple operations", function()
			local list = randomizer.list({ 5, 2, 8, 2, 1, 9, 5, 3 })
			local result = list:removeDuplicates():sort():filter(function(x)
				return x > 3
			end)

			assert.are.same({ 5, 8, 9 }, result:toTable())
		end)
	end)

	describe("Randomization", function()
		before_each(function()
			randomizer.setSeed(42)
		end)

		it("should randomize a target list from a list pool", function()
			local objects = {
				{ value = "A" },
				{ value = "B" },
				{ value = "C" },
			}
			local pool = randomizer.list({ "X", "Y", "Z" })

			local result = pool:useToRandomize(objects, "value")

			-- Should modify in place
			assert.are.equal(objects, result)
			-- All items should be from the pool
			for _, obj in ipairs(result) do
				assert.is_true(obj.value == "X" or obj.value == "Y" or obj.value == "Z")
			end
		end)

		it("should randomize object field with string setter", function()
			randomizer.setSeed(99)
			local objects = {
				{ id = 1, name = "old1" },
				{ id = 2, name = "old2" },
				{ id = 3, name = "old3" },
			}
			local pool = randomizer.list({ "new1", "new2", "new3" })

			pool:useToRandomize(objects, "name")

			-- All names should be from the pool
			for _, obj in ipairs(objects) do
				assert.is_true(obj.name == "new1" or obj.name == "new2" or obj.name == "new3")
				-- ID should be unchanged
				assert.is_number(obj.id)
			end
		end)

		it("should randomize with custom setter function", function()
			randomizer.setSeed(123)
			local objects = {
				{ value = 10, double = 20 },
				{ value = 20, double = 40 },
			}
			local pool = randomizer.list({ 5, 10, 15 })

			pool:useToRandomize(objects, function(obj, val)
				obj.value = val
				obj.double = val * 2
			end)

			-- Check values and doubles are consistent
			for _, obj in ipairs(objects) do
				assert.are.equal(obj.value * 2, obj.double)
				assert.is_true(obj.value == 5 or obj.value == 10 or obj.value == 15)
			end
		end)

	end)

	describe("Consumable Pools", function()
		it("should consume items without replacement when consumable=true", function()
			randomizer.setSeed(42)
			local pool = randomizer.list({ "A", "B", "C" })
			local target = { { val = 0 }, { val = 0 }, { val = 0 } }
			pool:useToRandomize(target, "val", { consumable = true, regenerate = false })
			-- target should be a permutation of the pool with no duplicates
			local values = { target[1].val, target[2].val, target[3].val }
			table.sort(values)
			assert.are.same({ "A", "B", "C" }, values)
		end)

		it("should error if requesting more than available without regenerate", function()
			randomizer.setSeed(99)
			local pool = randomizer.list({ 1, 2 })
			local target = { { val = 0 }, { val = 0 }, { val = 0 } }
			assert.has_error(function()
				pool:useToRandomize(target, "val", { consumable = true, regenerate = false })
			end)
		end)

		it("should regenerate when empty if regenerate=true", function()
			randomizer.setSeed(7)
			local pool = randomizer.list({ 1, 2 })
			local target = { { val = 0 }, { val = 0 }, { val = 0 }, { val = 0 } }
			pool:useToRandomize(target, "val", { consumable = true, regenerate = true })
			-- All values must be from original pool
			for _, obj in ipairs(target) do
				assert.is_true(obj.val == 1 or obj.val == 2)
			end
		end)

		it("should support consumable behavior with string setter", function()
			randomizer.setSeed(13)
			local objs = { { name = "" }, { name = "" }, { name = "" } }
			local pool = randomizer.list({ "X", "Y", "Z" })
			pool:useToRandomize(objs, "name", { consumable = true, regenerate = false })
			local names = { objs[1].name, objs[2].name, objs[3].name }
			table.sort(names)
			assert.are.same({ "X", "Y", "Z" }, names)
		end)
	end)

	describe("Immutability", function()
		it("should preserve immutability in operations", function()
			local original = randomizer.list({ 3, 1, 2 })
			local sorted = original:sort()

			-- Original should be unchanged
			assert.are.same({ 3, 1, 2 }, original:toTable())
			-- Sorted should be different
			assert.are.same({ 1, 2, 3 }, sorted:toTable())
		end)
	end)
end)
