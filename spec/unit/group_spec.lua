describe("Group Module", function()
	local randomizer

	setup(function()
		randomizer = require("randomizer")
	end)

	describe("Constructor and Basic Operations", function()
		it("should create a group from plain tables", function()
			local group = randomizer.group({
				type_a = { 1, 2, 3 },
				type_b = { 4, 5, 6 },
			})

			assert.are.equal(2, group:groupCount())
			assert.are.equal(6, group:itemCount())
		end)

		it("should handle empty groups gracefully", function()
			local group = randomizer.group({})
			assert.are.equal(0, group:groupCount())
			assert.are.equal(0, group:itemCount())
		end)

		it("should count items separately from empty keyed lists", function()
			local group = randomizer.group({
				a = { 1, 2 },
				b = {},
			})
			assert.are.equal(2, group:groupCount())
			assert.are.equal(2, group:itemCount())
		end)

		it("should have string representation", function()
			local group = randomizer.group({
				a = { 1, 2 },
				b = { 3, 4 },
				c = { 5, 6 },
			})

			local str = tostring(group)
			assert.are.equal("Group(3 groups, 6 items)", str)
		end)

		it("should error when creating group with invalid value", function()
			assert.has_error(function()
				randomizer.group({
					a = { 1, 2 },
					b = "not a table",
				})
			end)
		end)
	end)

	describe("Prune", function()
		it("should remove keys with empty lists", function()
			local group = randomizer.group({
				a = { 1, 2 },
				b = {},
				c = { 3 },
			})

			local pruned = group:prune()
			assert.are.equal(2, pruned:groupCount())
			assert.are.equal(3, pruned:itemCount())
			assert.is_nil(pruned:get("b"))
			assert.are.same({ 1, 2 }, pruned:get("a"):toTable())
			assert.are.same({ 3 }, pruned:get("c"):toTable())
		end)

		it("should return an empty group when all lists are empty", function()
			local pruned = randomizer.group({ a = {}, b = {} }):prune()
			assert.are.equal(0, pruned:groupCount())
			assert.are.equal(0, pruned:itemCount())
		end)

		it("should not modify the original group", function()
			local group = randomizer.group({ a = { 1 }, b = {} })
			group:prune()
			assert.are.equal(2, group:groupCount())
			assert.is_not_nil(group:get("b"))
		end)
	end)

	describe("fromField", function()
		it("should create a group using field names", function()
			local objects = {
				{ type = "melee", name = "Sword" },
				{ type = "ranged", name = "Bow" },
				{ type = "melee", name = "Axe" },
				{ type = "magic", name = "Wand" },
				{ type = "magic" }, -- Missing name should be skipped
			}

			local group = randomizer.groupFromField(objects, "type", "name")
			local result = group:toTable()

			assert.are.same({ "Sword", "Axe" }, result.melee)
			assert.are.same({ "Bow" }, result.ranged)
			assert.are.same({ "Wand" }, result.magic)
		end)

		it("should create a group using getter functions", function()
			local objects = {
				{ meta = { category = "A", stats = { damage = 10 } } },
				{ meta = { category = "B", stats = { damage = 20 } } },
				{ meta = { category = "A", stats = { damage = 15 } } },
				{ meta = { category = nil, stats = { damage = 100 } } },
			}

			local group = randomizer.groupFromField(objects, function(obj)
				return obj.meta and obj.meta.category
			end, function(obj, _key)
				if obj.meta and obj.meta.stats then
					return obj.meta.stats.damage
				end
			end)

			local result = group:toTable()
			table.sort(result.A)
			table.sort(result.B)

			assert.are.same({ 10, 15 }, result.A)
			assert.are.same({ 20 }, result.B)
			assert.is_nil(result["nil"])
		end)

		it("should pass the grouping key to value extractor functions", function()
			local objects = {
				{ type = "A", values = { A = 1, B = 99 } },
				{ type = "B", values = { A = 10, B = 20 } },
				{ type = "A", values = { A = 3, B = 99 } },
			}

			local group = randomizer.groupFromField(objects, "type", function(obj, groupKey)
				return obj.values[groupKey]
			end)
			local result = group:toTable()

			table.sort(result.A)
			assert.are.same({ 1, 3 }, result.A)
			assert.are.same({ 20 }, result.B)
		end)

		it("should create a group with whole items when valueFnOrField is nil", function()
			local objects = {
				{ type = "A", name = "Item1", value = 10 },
				{ type = "B", name = "Item2", value = 20 },
				{ type = "A", name = "Item3", value = 15 },
			}

			local group = randomizer.groupFromField(objects, "type", nil)
			local result = group:toTable()

			assert.are.equal(2, #result.A)
			assert.are.equal(1, #result.B)

			-- Verify whole items are preserved
			assert.are.same(objects[1], result.A[1])
			assert.are.same(objects[3], result.A[2])
			assert.are.same(objects[2], result.B[1])
		end)

		it("should error when group extractor is invalid type", function()
			local objects = {
				{ type = "A", value = 1 },
			}

			assert.has_error(function()
				randomizer.groupFromField(objects, 42, "value")
			end)
		end)

		it("should create a group using method name strings", function()
			local Entity = {}
			Entity.__index = Entity

			function Entity.new(category, damage)
				local instance = setmetatable({}, Entity)
				instance.category = category
				instance.damage = damage
				return instance
			end

			function Entity:getCategory()
				return self.category
			end

			function Entity:getDamage()
				return self.damage
			end

			local objects = {
				Entity.new("A", 10),
				Entity.new("B", 20),
				Entity.new("A", 15),
			}

			local group = randomizer.groupFromField(objects, "getCategory", "getDamage")
			local result = group:toTable()
			table.sort(result.A)
			table.sort(result.B)

			assert.are.same({ 10, 15 }, result.A)
			assert.are.same({ 20 }, result.B)
		end)

		it("should create a group using function references", function()
			local Entity = {}
			Entity.__index = Entity

			function Entity.new(category, damage)
				local instance = setmetatable({}, Entity)
				instance.category = category
				instance.damage = damage
				return instance
			end

			function Entity:getCategory()
				return self.category
			end

			function Entity:getDamage()
				return self.damage
			end

			local objects = {
				Entity.new("X", 5),
				Entity.new("Y", 7),
				Entity.new("X", 9),
			}

			local group = randomizer.groupFromField(objects, Entity.getCategory, Entity.getDamage)
			local result = group:toTable()
			table.sort(result.X)
			table.sort(result.Y)

			assert.are.same({ 5, 9 }, result.X)
			assert.are.same({ 7 }, result.Y)
		end)
	end)

	describe("Add and Remove", function()
		it("should add and remove lists from group", function()
			local group = randomizer.group({
				type_a = { 1, 2, 3 },
			})

			group:add("type_b", { 4, 5, 6 })
			assert.are.equal(2, group:groupCount())

			group:remove("type_a")
			assert.are.equal(1, group:groupCount())
		end)

		it("should add List instance to group", function()
			local group = randomizer.group({ a = { 1, 2 } })
			local newList = randomizer.list({ 3, 4, 5 })

			group:add("b", newList)

			assert.are.equal(2, group:groupCount())
			assert.are.same({ 3, 4, 5 }, group:get("b"):toTable())
		end)

		it("should error when adding non-table/list to group", function()
			local group = randomizer.group({ a = { 1, 2 } })

			assert.has_error(function()
				group:add("b", "not a table")
			end)
		end)
	end)

	describe("Get and Keys", function()
		it("should get list by key", function()
			local group = randomizer.group({
				a = { 1, 2, 3 },
				b = { 4, 5, 6 },
			})

			local listA = group:get("a")
			assert.are.same({ 1, 2, 3 }, listA:toTable())
		end)

		it("should return all keys as a List", function()
			local group = randomizer.group({
				melee = { 1, 2 },
				ranged = { 3, 4 },
				magic = { 5, 6 },
			})

			local keys = group:keys():sort():toTable()
			assert.are.same({ "magic", "melee", "ranged" }, keys)
		end)
	end)

	describe("Sort and Shuffle", function()
		it("should sort keys with a comparator", function()
			local group = randomizer.group({
				[10] = { 1 },
				[2] = { 2 },
				[1] = { 3 },
			})

			assert.are.same({ 1, 2, 10 }, group:sort(function(a, b)
				return a < b
			end):keys():toTable())
		end)

		it("should iterate sorted keys with each after sort", function()
			local group = randomizer.group({
				c = { 3 },
				a = { 1 },
				b = { 2 },
			})

			local visited = {}
			group:sort(function(a, b)
				return a < b
			end):each(function(key)
				table.insert(visited, key)
			end)

			assert.are.same({ "a", "b", "c" }, visited)
		end)

		it("should shuffle key order", function()
			randomizer.setSeed(42)
			local original = { "a", "b", "c", "d", "e" }
			local group = randomizer.group({
				a = { 1 },
				b = { 2 },
				c = { 3 },
				d = { 4 },
				e = { 5 },
			}, original)

			local shuffled = group:shuffle():keys():toTable()
			assert.are_not.same(original, shuffled)

			local sorted = {}
			for _, key in ipairs(shuffled) do
				table.insert(sorted, key)
			end
			table.sort(sorted)
			assert.are.same(original, sorted)

			randomizer.setSeed(42)
			assert.are.same(shuffled, group:shuffle():keys():toTable())
		end)
	end)

	describe("Map", function()
		it("should map each group list to a value", function()
			local grouped = randomizer.groupBy({
				{ name = "a", group = 1 },
				{ name = "b", group = 1 },
				{ name = "c", group = 2 },
			}, "group")

			local firstNames = grouped:map(function(_, list)
				return list:get(1).name
			end):toTable()

			assert.are.same({ "a", "c" }, firstNames)
		end)
	end)

	describe("ApplyToEachList", function()
		it("should apply a List method to each keyed list", function()
			local group = randomizer.group({
				group1 = { 1, 2, 3, 4, 5 },
				group2 = { 6, 7, 8, 9, 10 },
			})

			local filtered = group:applyToEachList("filter", function(x)
				return x % 2 == 0
			end)
			local result = filtered:toTable()

			assert.are.same({ 2, 4 }, result.group1)
			assert.are.same({ 6, 8, 10 }, result.group2)
		end)

		it("should forward extra args for methods like flatMap", function()
			local group = randomizer.group({
				a = { 1, 2 },
				b = { 3 },
			})
			local result = group
				:applyToEachList("flatMap", function(n)
					return { n, n * 10 }
				end)
				:toTable()
			assert.are.same({ 1, 10, 2, 20 }, result.a)
			assert.are.same({ 3, 30 }, result.b)
		end)

		it("should chain applied List methods", function()
			local group = randomizer.group({
				a = { 3, 1, 2, 2 },
				b = { 9, 5, 5 },
			})
			local result = group:applyToEachList("removeDuplicates"):applyToEachList("sort"):toTable()
			assert.are.same({ 1, 2, 3 }, result.a)
			assert.are.same({ 5, 9 }, result.b)
		end)

		it("should apply flatMapNTimes with nil-skipping mappers", function()
			local group = randomizer.groupBy({
				{ type = "x", n = 2, keep = true },
				{ type = "x", n = 1, keep = false },
				{ type = "y", n = 1, keep = true },
			}, "type")

			local result = group
				:applyToEachList("flatMapNTimes", "n", function(item, index)
					if not item.keep then
						return nil
					end
					return item.type .. ":" .. index
				end)
				:toTable()

			assert.are.same({ "x:1", "x:2" }, result.x)
			assert.are.same({ "y:1" }, result.y)
		end)

		it("should apply select across all lists", function()
			local group = randomizer.group({
				group1 = {
					{ id = 1, name = "Alice" },
					{ id = 2, name = "Bob" },
				},
				group2 = {
					{ id = 3, name = "Charlie" },
					{ id = 4, name = "David" },
				},
			})

			local result = group:applyToEachList("select", "name"):toTable()

			assert.are.same({ "Alice", "Bob" }, result.group1)
			assert.are.same({ "Charlie", "David" }, result.group2)
		end)

		it("should error when method name is unknown", function()
			local group = randomizer.group({ a = { 1, 2 } })
			assert.has_error(function()
				group:applyToEachList("notAListMethod")
			end)
		end)

		it("should error when method name is not a string", function()
			local group = randomizer.group({ a = { 1, 2 } })
			assert.has_error(function()
				group:applyToEachList(42)
			end)
		end)
	end)

	describe("ToList", function()
		it("should concatenate all grouped lists into one List", function()
			local group = randomizer.group({
				a = { 1, 2 },
				b = { 3 },
			})
			local result = group:toList():sort():toTable()
			assert.are.same({ 1, 2, 3 }, result)
		end)

		it("should concatenate lists in sorted key order when sort is called", function()
			local group = randomizer.group({
				z = { 30 },
				a = { 10, 11 },
				m = { 20 },
			})
			assert.are.same(
				{ 10, 11, 20, 30 },
				group:sort(function(a, b)
					return tostring(a) < tostring(b)
				end):toList():toTable()
			)
		end)

		it("should concatenate lists in groupBy key order", function()
			local items = {
				{ id = 1, category = "fruit" },
				{ id = 2, category = "vegetable" },
				{ id = 3, category = "fruit" },
			}

			local group = randomizer.groupBy(items, "category")
			assert.are.same({ 1, 3, 2 }, group:toList():map(function(item)
				return item.id
			end):toTable())
		end)
	end)

	describe("GroupBy", function()
		it("should create groups from a list using keyExtractor", function()
			local items = {
				{ name = "Apple", category = "fruit" },
				{ name = "Carrot", category = "vegetable" },
				{ name = "Banana", category = "fruit" },
				{ name = "Broccoli", category = "vegetable" },
			}

			local grouped = randomizer.groupBy(items, function(item)
				return item.category
			end)

			assert.are.equal(2, grouped:groupCount())

			local result = grouped:toTable()
			assert.are.equal(2, #result.fruit)
			assert.are.equal(2, #result.vegetable)
		end)

		it("should handle items with nil keys", function()
			local items = {
				{ name = "Item1", category = "A" },
				{ name = "Item2", category = nil },
				{ name = "Item3", category = "B" },
			}

			local grouped = randomizer.groupBy(items, function(item)
				return item.category
			end)

			-- Should only have 2 groups (nil key items are skipped)
			assert.are.equal(2, grouped:groupCount())
		end)

		it("should accept a List stream without converting to a table first", function()
			local items = randomizer.list({
				{ name = "Apple", category = "fruit" },
				{ name = "Carrot", category = "vegetable" },
				{ name = "Banana", category = "fruit" },
			}):filter(function(item)
				return item.category == "fruit"
			end)

			local grouped = randomizer.groupBy(items, "category")
			assert.are.equal(1, grouped:groupCount())
			assert.are.equal(2, grouped:get("fruit"):size())
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

			function Move.new(host)
				local instance = setmetatable({}, Move)
				instance.host = host
				return instance
			end

			function Move:getHost()
				return self.host
			end

			local grouped = randomizer.groupBy({
				Move.new(Host.new("fire")),
				Move.new(Host.new("water")),
				Move.new(Host.new("fire")),
			}, "getHost:type")

			assert.are.equal(2, grouped:groupCount())
			assert.are.equal(2, grouped:get("fire"):size())
			assert.are.equal(1, grouped:get("water"):size())
		end)
	end)

	describe("Each and pairs", function()
		it("should iterate key and list with each", function()
			local grouped = randomizer.group({
				a = { 1, 2 },
				b = { 3 },
			})
			local seen = {}
			grouped:each(function(key, list)
				seen[key] = list:size()
			end)
			assert.are.equal(2, seen.a)
			assert.are.equal(1, seen.b)
		end)

		it("should support pairs(group) for key, list iteration", function()
			local grouped = randomizer.group({
				a = { 1, 2 },
				b = { 3 },
			})
			local seen = {}
			for key, list in pairs(grouped) do
				seen[key] = list:size()
			end
			assert.are.equal(2, seen.a)
			assert.are.equal(1, seen.b)
		end)
	end)

	describe("Randomization", function()
		before_each(function()
			randomizer.setSeed(99)
		end)

		it("should randomize based on selector function", function()
			local weapons = {
				{ name = "weapon1", type = "melee" },
				{ name = "weapon2", type = "ranged" },
				{ name = "weapon3", type = "melee" },
				{ name = "weapon4", type = "ranged" },
			}

			local pools = randomizer.group({
				melee = { "Sword", "Axe", "Mace" },
				ranged = { "Bow", "Gun", "Crossbow" },
			})

			pools:useToRandomize(weapons, function(weapon)
				return weapon.type
			end, "name")

			-- Check that melee weapons got melee replacements
			assert.is_true(weapons[1].name == "Sword" or weapons[1].name == "Axe" or weapons[1].name == "Mace")
			assert.is_true(weapons[3].name == "Sword" or weapons[3].name == "Axe" or weapons[3].name == "Mace")

			-- Check that ranged weapons got ranged replacements
			assert.is_true(weapons[2].name == "Bow" or weapons[2].name == "Gun" or weapons[2].name == "Crossbow")
			assert.is_true(weapons[4].name == "Bow" or weapons[4].name == "Gun" or weapons[4].name == "Crossbow")
		end)

		it("should error when group key not found", function()
			local group = randomizer.group({
				type_a = { 1, 2, 3 },
			})

			local target = { { value = "x" } }

			assert.has_error(function()
				group:useToRandomize(target, function()
					return "nonexistent"
				end, "value")
			end)
		end)

		it("should randomize object field with string setter", function()
			randomizer.setSeed(42)
			local weapons = {
				{ id = 1, name = "old_melee", type = "melee" },
				{ id = 2, name = "old_ranged", type = "ranged" },
			}
			local pools = randomizer.group({
				melee = { "Sword", "Axe" },
				ranged = { "Bow", "Gun" },
			})

			pools:useToRandomize(weapons, function(weapon)
				return weapon.type
			end, "name")

			-- Check melee got melee name, ranged got ranged name
			assert.is_true(weapons[1].name == "Sword" or weapons[1].name == "Axe")
			assert.is_true(weapons[2].name == "Bow" or weapons[2].name == "Gun")
			-- IDs should be unchanged
			assert.are.equal(1, weapons[1].id)
			assert.are.equal(2, weapons[2].id)
		end)

		it("should randomize using a colon-separated selector path", function()
			randomizer.setSeed(42)

			local targets = {
				{ host = { type = "fire" }, value = 0 },
				{ host = { type = "water" }, value = 0 },
			}

			local pools = randomizer.group({
				fire = { 10, 20 },
				water = { 30, 40 },
			})

			pools:useToRandomize(targets, "host:type", "value")

			assert.is_true(targets[1].value == 10 or targets[1].value == 20)
			assert.is_true(targets[2].value == 30 or targets[2].value == 40)
		end)

		it("should randomize with custom setter function", function()
			randomizer.setSeed(99)
			local items = {
				{ category = "A", value = 0, valueSquared = 0 },
				{ category = "B", value = 0, valueSquared = 0 },
			}
			local groups = randomizer.group({
				A = { 5, 10 },
				B = { 20, 30 },
			})

			groups:useToRandomize(items, function(item)
				return item.category
			end, function(item, val)
				item.value = val
				item.valueSquared = val * val
			end)

			-- Check values and squares are consistent
			for _, item in ipairs(items) do
				assert.are.equal(item.value * item.value, item.valueSquared)
			end

			-- Check category A got A values, B got B values
			assert.is_true(items[1].value == 5 or items[1].value == 10)
			assert.is_true(items[2].value == 20 or items[2].value == 30)
		end)
	end)

	describe("Consumable Pools", function()
		it("should consume within each group without replacement", function()
			randomizer.setSeed(21)
			local pools = randomizer.group({
				A = { "a1", "a2" },
				B = { "b1", "b2", "b3" },
			})
			local targets = { { val = 0 }, { val = 0 }, { val = 0 }, { val = 0 }, { val = 0 } }
			local selectors = { "A", "A", "B", "B", "B" }
			pools:useToRandomize(targets, function(_, i)
				return selectors[i]
			end, "val", { consumable = true, regenerate = false })
			-- group A results should be a permutation of its pool with no duplicates
			local aResults = { targets[1].val, targets[2].val }
			table.sort(aResults)
			assert.are.same({ "a1", "a2" }, aResults)
			-- group B results should be a permutation of its pool with no duplicates
			local bResults = { targets[3].val, targets[4].val, targets[5].val }
			table.sort(bResults)
			assert.are.same({ "b1", "b2", "b3" }, bResults)
		end)

		it("should error if a group depletes and regenerate=false", function()
			randomizer.setSeed(33)
			local pools = randomizer.group({ K = { 1 } })
			local targets = { { val = 0 }, { val = 0 } }
			assert.has_error(function()
				pools:useToRandomize(targets, function()
					return "K"
				end, "val", { consumable = true, regenerate = false })
			end)
		end)

		it("should regenerate per group when regenerate=true", function()
			randomizer.setSeed(44)
			local pools = randomizer.group({ K = { 1, 2 } })
			local targets = { { val = 0 }, { val = 0 }, { val = 0 } }
			pools:useToRandomize(targets, function()
				return "K"
			end, "val", { consumable = true, regenerate = true })
			for _, obj in ipairs(targets) do
				assert.is_true(obj.val == 1 or obj.val == 2)
			end
		end)

		it("should support consumable with field-name setter", function()
			randomizer.setSeed(55)
			local items = {
				{ key = "A", name = "" },
				{ key = "A", name = "" },
				{ key = "B", name = "" },
			}
			local pools = randomizer.group({ A = { "x", "y" }, B = { "u", "v", "w" } })
			pools:useToRandomize(items, function(item)
				return item.key
			end, "name", { consumable = true, regenerate = false })
			-- A names should be unique and from its pool
			local a = {}
			for _, it in ipairs(items) do
				if it.key == "A" then
					table.insert(a, it.name)
				end
			end
			table.sort(a)
			assert.are.same({ "x", "y" }, a)
		end)
	end)

	describe("ToTable", function()
		it("should convert to plain table of tables", function()
			local group = randomizer.group({
				a = { 1, 2 },
				b = { 3, 4 },
			})

			local result = group:toTable()

			assert.are.same({ 1, 2 }, result.a)
			assert.are.same({ 3, 4 }, result.b)
		end)
	end)
end)
