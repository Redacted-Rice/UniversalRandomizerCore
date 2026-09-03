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

	describe("Each", function()
		it("should call the function for each item", function()
			local list = randomizer.list({ 1, 2, 3 })
			local seen = {}
			list:each(function(item, index)
				seen[index] = item
			end)
			assert.are.same({ 1, 2, 3 }, seen)
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

		it("should filter items using a field or method name", function()
			local list = randomizer.list({
				{ isAttack = function()
					return true
				end, name = "Bite" },
				{ isAttack = function()
					return false
				end, name = "Rest" },
				{ isPokePower = function()
					return true
				end, name = "Heal" },
			})

			assert.are.same({ "Bite" }, list:filter("isAttack"):select("name"):toTable())
			assert.are.same({ "Heal" }, list:filter("isPokePower"):select("name"):toTable())
		end)

		it("should filter items using a colon-separated getter path", function()
			local Host = {}
			Host.__index = Host

			function Host.new(typeName, isActive)
				local instance = setmetatable({}, Host)
				instance.type = typeName
				instance.isActive = isActive
				return instance
			end

			local Move = {}
			Move.__index = Move

			function Move.new(host, name)
				local instance = setmetatable({}, Move)
				instance.host = host
				instance.name = name
				return instance
			end

			function Move:getHost()
				return self.host
			end

			local list = randomizer.list({
				Move.new(Host.new("fire", true), "Bite"),
				Move.new(Host.new("water", false), "Splash"),
				Move.new(Host.new("fire", true), "Ember"),
			})

			assert.are.same({ "Bite", "Ember" }, list:filter("getHost:isActive"):select("name"):toTable())
			assert.are.same({ "Bite", "Splash", "Ember" }, list:filter("getHost:type"):select("name"):toTable())
		end)
	end)

	describe("GroupBy", function()
		it("should group items using a field or method name", function()
			local grouped = randomizer.list({
				{ type = "fire", name = "Ember" },
				{ type = "water", name = "Splash" },
				{ type = "fire", name = "Flamethrower" },
			}):groupBy("type")

			assert.are.same({ "Ember", "Flamethrower" }, grouped:get("fire"):select("name"):sort():toTable())
			assert.are.same({ "Splash" }, grouped:get("water"):select("name"):toTable())
		end)

		it("should chain filter and groupBy", function()
			local grouped = randomizer.list({
				{ type = "fire", isAttack = function()
					return true
				end, name = "Bite" },
				{ type = "fire", isAttack = function()
					return false
				end, name = "Rest" },
				{ type = "water", isAttack = function()
					return true
				end, name = "Splash" },
			}):filter("isAttack"):groupBy("type")

			assert.are.same({ "Bite" }, grouped:get("fire"):select("name"):toTable())
			assert.are.same({ "Splash" }, grouped:get("water"):select("name"):toTable())
		end)

		it("should groupBy using a colon-separated getter path", function()
			local Host = {}
			Host.__index = Host

			function Host.new(typeName)
				local instance = setmetatable({}, Host)
				instance.type = typeName
				return instance
			end

			local Move = {}
			Move.__index = Move

			function Move.new(host, name)
				local instance = setmetatable({}, Move)
				instance.host = host
				instance.name = name
				return instance
			end

			function Move:getHost()
				return self.host
			end

			local grouped = randomizer.list({
				Move.new(Host.new("fire"), "Ember"),
				Move.new(Host.new("water"), "Splash"),
				Move.new(Host.new("fire"), "Flamethrower"),
			}):groupBy("getHost:type")

			assert.are.same({ "Ember", "Flamethrower" }, grouped:get("fire"):select("name"):sort():toTable())
			assert.are.same({ "Splash" }, grouped:get("water"):select("name"):toTable())
		end)

		it("should chain filter and groupBy with colon-separated paths", function()
			local Host = {}
			Host.__index = Host

			function Host.new(typeName)
				local instance = setmetatable({}, Host)
				instance.type = typeName
				return instance
			end

			local Move = {}
			Move.__index = Move

			function Move.new(host, attack, name)
				local instance = setmetatable({}, Move)
				instance.host = host
				instance.attack = attack
				instance.name = name
				return instance
			end

			function Move:getHost()
				return self.host
			end

			function Move:isAttack()
				return self.attack
			end

			local grouped = randomizer.list({
				Move.new(Host.new("fire"), true, "Bite"),
				Move.new(Host.new("fire"), false, "Rest"),
				Move.new(Host.new("water"), true, "Splash"),
			}):filter("isAttack"):groupBy("getHost:type")

			assert.are.same({ "Bite" }, grouped:get("fire"):select("name"):toTable())
			assert.are.same({ "Splash" }, grouped:get("water"):select("name"):toTable())
		end)
	end)

	describe("Remove Duplicates", function()
		it("should remove duplicates from a list", function()
			local list = randomizer.list({ 1, 2, 2, 3, 3, 3, 4 })
			local unique = list:removeDuplicates()

			assert.are.same({ 1, 2, 3, 4 }, unique:toTable())
		end)

		it("should remove duplicate tables using deep comparison", function()
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

	describe("Max and Min", function()
		it("should return max and min values from a numeric list", function()
			local list = randomizer.list({ 5, 2, 8, 1, 9 })

			assert.are.equal(9, list:max())
			assert.are.equal(1, list:min())
		end)

		it("should return nil for max and min on an empty list", function()
			local list = randomizer.list({})

			assert.is_nil(list:max())
			assert.is_nil(list:min())
		end)

		it("should return max and min using a field extractor", function()
			local list = randomizer.list({
				{ hp = 40 },
				{ hp = 70 },
				{ hp = 50 },
			})

			assert.are.equal(70, list:max("hp"))
			assert.are.equal(40, list:min("hp"))
		end)

		it("should return max and min using a custom compare function", function()
			local list = randomizer.list({ 5, 10, 7 })

			local function closerToNine(a, b)
				return math.abs(a - 9) < math.abs(b - 9)
			end

			assert.are.equal(10, list:max(nil, closerToNine))
			assert.are.equal(5, list:min(nil, closerToNine))
		end)

		it("should return max and min using a field extractor and custom compare function", function()
			local list = randomizer.list({
				{ name = "low", hp = 40 },
				{ name = "high", hp = 70 },
				{ name = "mid", hp = 50 },
			})

			assert.are.equal(
				"mid",
				list:max("name", function(a, b)
					return #a > #b
				end)
			)
			assert.are.equal(
				"high",
				list:min("name", function(a, b)
					return #a > #b
				end)
			)
		end)
	end)

	describe("Flatten", function()
		it("should flatten nested array tables one level", function()
			local list = randomizer.list({
				{ 1, 2 },
				{ 3 },
				{ 4, 5, 6 },
			})
			assert.are.same({ 1, 2, 3, 4, 5, 6 }, list:flatten():toTable())
		end)

		it("should flatten nested Lists one level", function()
			local list = randomizer.list({
				randomizer.list({ "a", "b" }),
				randomizer.list({ "c" }),
			})
			assert.are.same({ "a", "b", "c" }, list:flatten():toTable())
		end)

		it("should keep non-list items when flattening", function()
			local list = randomizer.list({
				{ 1, 2 },
				"solo",
				{ name = "obj" },
			})
			local result = list:flatten():toTable()
			assert.are.equal(1, result[1])
			assert.are.equal(2, result[2])
			assert.are.equal("solo", result[3])
			assert.are.same({ name = "obj" }, result[4])
		end)
	end)

	describe("FlatMap", function()
		it("should map items to arrays and flatten", function()
			local list = randomizer.list({ 1, 2, 3 })
			local result = list:flatMap(function(n)
				return { n, n * 10 }
			end)
			assert.are.same({ 1, 10, 2, 20, 3, 30 }, result:toTable())
		end)

		it("should accept Lists returned from the mapper", function()
			local list = randomizer.list({ "a", "b" })
			local result = list:flatMap(function(s)
				return randomizer.list({ s, s .. s })
			end)
			assert.are.same({ "a", "aa", "b", "bb" }, result:toTable())
		end)
	end)

	describe("FlatMapNTimes", function()
		it("should expand items by a count field with default pairs", function()
			local list = randomizer.list({
				{ name = "a", n = 2 },
				{ name = "b", n = 1 },
			})
			local result = list:flatMapNTimes("n"):toTable()
			assert.are.equal(3, #result)
			assert.are.equal("a", result[1].item.name)
			assert.are.equal(1, result[1].index)
			assert.are.equal("a", result[2].item.name)
			assert.are.equal(2, result[2].index)
			assert.are.equal("b", result[3].item.name)
			assert.are.equal(1, result[3].index)
		end)

		it("should expand with a custom mapper and start index", function()
			local list = randomizer.list({
				{ id = "x", slots = 2 },
			})
			local result = list
				:flatMapNTimes("slots", function(item, slot)
					return item.id .. ":" .. slot
				end, 0)
				:toTable()
			assert.are.same({ "x:0", "x:1" }, result)
		end)

		it("should skip items with zero count", function()
			local list = randomizer.list({
				{ name = "a", n = 0 },
				{ name = "b", n = 1 },
			})
			local result = list:flatMapNTimes("n", function(item, index)
				return item.name
			end):toTable()
			assert.are.same({ "b" }, result)
		end)

		it("should skip nil values returned from the mapper", function()
			local list = randomizer.list({
				{ name = "a", n = 2 },
				{ name = "b", n = 1 },
			})
			local result = list
				:flatMapNTimes("n", function(item, index)
					if item.name == "a" and index == 2 then
						return nil
					end
					return item.name .. ":" .. index
				end)
				:toTable()
			assert.are.same({ "a:1", "b:1" }, result)
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

		it("should forward extra arguments to getter functions", function()
			local list = randomizer.list({
				{ value = 2 },
				{ value = 3 },
			})
			local selected = list:select(function(item, multiplier)
				return item.value * multiplier
			end, 10)

			assert.are.same({ 20, 30 }, selected:toTable())
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

		it("should select values using a colon-separated getter path", function()
			local Host = {}
			Host.__index = Host

			function Host.new(typeName)
				local instance = setmetatable({}, Host)
				instance.type = typeName
				return instance
			end

			local Move = {}
			Move.__index = Move

			function Move.new(host)
				local instance = setmetatable({}, Move)
				instance.host = host
				return instance
			end

			function Move:getHost()
				return self.host
			end

			local selected = randomizer.list({
				Move.new(Host.new("fire")),
				Move.new(Host.new("water")),
				Move.new(Host.new("fire")),
			}):select("getHost:type")

			assert.are.same({ "fire", "water", "fire" }, selected:toTable())
		end)

		it("should extract values from a source list via list then select", function()
			local objects = {
				{ value = 10 },
				{ value = 20 },
				{ value = nil },
				{ other = 5 },
			}

			local list = randomizer.list(objects):select("value")

			assert.are.same({ 10, 20 }, list:toTable())
		end)

		it("should extract values with a function via list then select", function()
			local objects = {
				{ value = 2, include = true },
				{ value = 3, include = false },
				{ value = 4, include = true },
			}

			local list = randomizer.list(objects):select(function(obj)
				if obj.include then
					return obj.value
				end
			end)

			assert.are.same({ 2, 4 }, list:toTable())
		end)

		it("should extract values with a method name via list then select", function()
			local Object = {}
			Object.__index = Object

			function Object.new(value)
				local instance = setmetatable({}, Object)
				instance.value = value or 0
				return instance
			end

			function Object:getValue()
				return self.value
			end

			local list = randomizer.list({
				Object.new(2),
				Object.new(3),
				Object.new(4),
			}):select("getValue")

			assert.are.same({ 2, 3, 4 }, list:toTable())
		end)
	end)

	describe("Map", function()
		it("should map items to new values", function()
			local list = randomizer.list({ 1, 2, 3 })
			local mapped = list:map(function(item)
				return item * 2
			end)

			assert.are.same({ 2, 4, 6 }, mapped:toTable())
		end)

		it("should pass the 1-based index to the map function", function()
			local list = randomizer.list({ "a", "b", "c" })
			local mapped = list:map(function(item, index)
				return item .. tostring(index)
			end)

			assert.are.same({ "a1", "b2", "c3" }, mapped:toTable())
		end)

		it("should skip nil results when mapping", function()
			local list = randomizer.list({ 1, 2, 3, 4 })
			local mapped = list:map(function(item)
				if item % 2 == 0 then
					return item
				end
			end)

			assert.are.same({ 2, 4 }, mapped:toTable())
		end)

		it("should not modify the original list", function()
			local original = { { value = 1 }, { value = 2 } }
			local list = randomizer.list(original)

			list:map(function(item)
				item.value = item.value * 10
				return item.value
			end)

			assert.are.equal(1, original[1].value)
			assert.are.equal(2, original[2].value)
		end)

		it("should error when map function is invalid type", function()
			local list = randomizer.list({ 1, 2, 3 })

			assert.has_error(function()
				list:map(42)
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

		it("should randomize using a colon-separated setter path", function()
			randomizer.setSeed(42)
			local objects = {
				{ host = { value = 0 } },
				{ host = { value = 0 } },
			}
			local pool = randomizer.list({ 10, 20, 30 })

			pool:useToRandomize(objects, "host:value")

			for _, obj in ipairs(objects) do
				assert.is_true(obj.host.value == 10 or obj.host.value == 20 or obj.host.value == 30)
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
