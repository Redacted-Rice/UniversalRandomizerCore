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

			assert.are.equal(2, group:size())
			assert.is_false(group:isEmpty())
		end)

		it("should handle empty groups gracefully", function()
			local group = randomizer.group({})
			assert.is_true(group:isEmpty())
			assert.are.equal(0, group:size())
		end)

		it("should have string representation", function()
			local group = randomizer.group({
				a = { 1, 2 },
				b = { 3, 4 },
				c = { 5, 6 },
			})

			local str = tostring(group)
			assert.are.equal("Group(3 lists)", str)
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
			assert.are.equal(2, group:size())

			group:remove("type_a")
			assert.are.equal(1, group:size())
		end)

		it("should add List instance to group", function()
			local group = randomizer.group({ a = { 1, 2 } })
			local newList = randomizer.list({ 3, 4, 5 })

			group:add("b", newList)

			assert.are.equal(2, group:size())
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

		it("should return all keys", function()
			local group = randomizer.group({
				melee = { 1, 2 },
				ranged = { 3, 4 },
				magic = { 5, 6 },
			})

			local keys = group:keys()
			table.sort(keys)
			assert.are.same({ "magic", "melee", "ranged" }, keys)
		end)
	end)

	describe("Select", function()
		it("should select/extract field values from all lists", function()
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

			local selected = group:select("name")
			local result = selected:toTable()

			assert.are.same({ "Alice", "Bob" }, result.group1)
			assert.are.same({ "Charlie", "David" }, result.group2)
		end)

		it("should select/extract using a function from all lists", function()
			local group = randomizer.group({
				weapons = {
					{ name = "Sword", damage = 10 },
					{ name = "Axe", damage = 15 },
				},
				armor = {
					{ name = "Shield", defense = 10 },
					{ name = "Plate", defense = 20 },
				},
			})

			local selected = group:select(function(item)
				return item.damage or item.defense or 0
			end)

			local result = selected:toTable()
			assert.are.same({ 10, 15 }, result.weapons)
			assert.are.same({ 10, 20 }, result.armor)
		end)

		it("should skip nil values when selecting", function()
			local group = randomizer.group({
				a = { { name = "Alice" }, { other = "data" }, { name = "Bob" } },
				b = { { name = "Charlie" }, { name = "David" } },
			})

			local selected = group:select("name")
			local result = selected:toTable()

			assert.are.same({ "Alice", "Bob" }, result.a)
			assert.are.same({ "Charlie", "David" }, result.b)
		end)

		it("should error when selector is invalid type", function()
			local group = randomizer.group({
				a = { { value = 1 }, { value = 2 } },
			})

			assert.has_error(function()
				group:select(42)
			end)
		end)
	end)

	describe("Filter", function()
		it("should filter all lists in a group", function()
			local group = randomizer.group({
				group1 = { 1, 2, 3, 4, 5 },
				group2 = { 6, 7, 8, 9, 10 },
			})

			local filtered = group:filter(function(x)
				return x % 2 == 0
			end)
			local result = filtered:toTable()

			assert.are.same({ 2, 4 }, result.group1)
			assert.are.same({ 6, 8, 10 }, result.group2)
		end)
	end)

	describe("Remove Duplicates", function()
		it("should remove duplicates from all lists in a group", function()
			local group = randomizer.group({
				group1 = { 1, 1, 2, 2, 3 },
				group2 = { 4, 4, 5, 5, 6 },
			})

			local unique = group:removeDuplicates()
			local result = unique:toTable()

			assert.are.same({ 1, 2, 3 }, result.group1)
			assert.are.same({ 4, 5, 6 }, result.group2)
		end)
	end)

	describe("Shuffle", function()
		it("should shuffle all lists in group", function()
			randomizer.setSeed(42)
			local group = randomizer.group({
				a = { 1, 2, 3, 4, 5 },
				b = { 6, 7, 8, 9, 10 },
			})

			local shuffled = group:shuffle()
			local result = shuffled:toTable()

			-- Should have same elements but possibly different order
			table.sort(result.a)
			table.sort(result.b)
			assert.are.same({ 1, 2, 3, 4, 5 }, result.a)
			assert.are.same({ 6, 7, 8, 9, 10 }, result.b)
		end)
	end)

	describe("Sort", function()
		it("should sort all lists in group", function()
			local group = randomizer.group({
				a = { 5, 2, 8, 1 },
				b = { 9, 3, 7, 4 },
			})

			local sorted = group:sort()
			local result = sorted:toTable()

			assert.are.same({ 1, 2, 5, 8 }, result.a)
			assert.are.same({ 3, 4, 7, 9 }, result.b)
		end)

		it("should sort all lists with custom comparator", function()
			local group = randomizer.group({
				a = { 1, 2, 3 },
				b = { 4, 5, 6 },
			})

			local sorted = group:sort(function(a, b)
				return a > b
			end)
			local result = sorted:toTable()

			assert.are.same({ 3, 2, 1 }, result.a)
			assert.are.same({ 6, 5, 4 }, result.b)
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

			assert.are.equal(2, grouped:size())

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
			assert.are.equal(2, grouped:size())
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
