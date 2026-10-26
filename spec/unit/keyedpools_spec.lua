describe("KeyedPools", function()
	local randomizer

	setup(function()
		randomizer = require("randomizer")
	end)

	describe("new", function()
		it("should coerce a map of arrays into pools", function()
			local group = randomizer.KeyedPools.new({
				a = { 1, 2 },
				b = { 3 },
			}, { consumable = true, regenerate = false })

			assert.are.equal(3, group:itemCount())
		end)

		it("should build one pool per list bucket when given a group", function()
			local lists = randomizer.group({
				a = { 1, 2 },
				b = { 3 },
			})
			local keyed = randomizer.KeyedPools.new(lists, { consumable = true, regenerate = false })

			assert.is_true(randomizer.isKeyedPools(keyed))
			assert.are.equal(2, keyed:poolCount())
			assert.are.equal(3, keyed:itemCount())
			assert.are.equal(2, keyed:get("a"):remainingCount())
			assert.are.equal(1, keyed:get("b"):remainingCount())
		end)

		it("should visit every key in each when built from a group", function()
			local lists = randomizer.group({ z = { 1 }, y = { 2 } }, { "z", "y" })
			local keyed = randomizer.KeyedPools.new(lists, {})
			local seen = {}
			keyed:each(function(key)
				seen[key] = true
			end)
			assert.is_true(seen.z)
			assert.is_true(seen.y)
		end)

		it("should copy an existing keyed pools via new", function()
			randomizer.setSeed(5)
			local lists = randomizer.group({ k = { 1, 2 } })
			local original = randomizer.KeyedPools.new(lists, { consumable = true, regenerate = false })
			original:get("k"):draw()
			local copy = randomizer.KeyedPools.new(original)
			assert.are_not.equal(original, copy)
			assert.are.equal(original:get("k"):remainingCount(), copy:get("k"):remainingCount())
			assert.are.equal(#original:get("k").used, #copy:get("k").used)
		end)

		it("should decrease itemCount when pools draw", function()
			randomizer.setSeed(1)
			local lists = randomizer.group({ k = { 1, 2, 3 } })
			local keyed = randomizer.KeyedPools.new(lists, { consumable = true, regenerate = false })
			keyed:get("k"):draw()
			assert.are.equal(2, keyed:itemCount())
		end)
	end)

	describe("remaining and draws", function()
		it("should sum remainingForKeys and drawFirstAvailable in key order", function()
			randomizer.setSeed(2)
			local keyed = randomizer.KeyedPools.new({
				a = { 1, 2 },
				b = { 3 },
			}, { consumable = true, regenerate = false })

			assert.are.equal(3, keyed:remainingForKeys({ "a", "b" }))
			assert.are.equal(0, keyed:remainingForKey("missing"))

			local value, key = keyed:drawFirstAvailable({ "b", "a" })
			assert.are.equal("b", key)
			assert.are.equal(3, value)
		end)

		it("should return nil when drawFirstAvailable finds no items", function()
			local keyed = randomizer.KeyedPools.new({ k = { 1 } }, { consumable = true, regenerate = false })
			keyed:get("k"):draw()
			local value, key = keyed:drawFirstAvailable({ "k" })
			assert.is_nil(value)
			assert.is_nil(key)
		end)

		it("should drawFirstAvailable when regenerate leaves items in used only", function()
			randomizer.setSeed(7)
			local keyed = randomizer.KeyedPools.new({ k = { 1, 2 } }, { consumable = true, regenerate = true })
			keyed:get("k"):draw()
			keyed:get("k"):draw()
			assert.are.equal(0, keyed:get("k"):remainingCount())
			local value, key = keyed:drawFirstAvailable({ "k" })
			assert.are.equal("k", key)
			assert.is_true(value == 1 or value == 2)
		end)

		it("should pick firstKeyWithCapacity and tryReserveKey with reservations", function()
			local keyed = randomizer.KeyedPools.new({ k = { 1 } }, { consumable = true })
			local reserved = {}
			local temp = {}
			assert.are.equal("k", keyed:firstKeyWithCapacity({ "k" }, reserved, temp))
			assert.are.equal("k", keyed:tryReserveKey({ "k" }, reserved, temp))
			assert.are.equal(1, temp.k)
			assert.is_nil(keyed:firstKeyWithCapacity({ "k" }, reserved, temp))
		end)

		it("should allow nil tempReserved without tracking the reservation", function()
			local keyed = randomizer.KeyedPools.new({ k = { 1 } }, { consumable = true })
			assert.are.equal("k", keyed:tryReserveKey({ "k" }, {}, nil))
			assert.are.equal("k", keyed:tryReserveKey({ "k" }, {}, nil))
		end)
	end)

	describe("__pairs", function()
		it("should iterate every keyed pool", function()
			local keyed = randomizer.KeyedPools.new({ a = { 1 }, b = { 2 } }, {})
			local count = 0
			for key, pool in pairs(keyed) do
				count = count + 1
				assert.is_true(key == "a" or key == "b")
				assert.is_true(randomizer.isPool(pool))
			end
			assert.are.equal(2, count)
		end)
	end)

	describe("__tostring", function()
		it("should list per-key remaining counts", function()
			local keyed = randomizer.KeyedPools.new({ a = { 1, 2 }, b = { 3 } })
			local text = tostring(keyed)
			assert.is_true(string.find(text, "a=2") ~= nil)
			assert.is_true(string.find(text, "b=1") ~= nil)
		end)
	end)

	describe("backedBy", function()
		it("should share array storage with caller tables", function()
			local a = { 1, 2 }
			local keyed = randomizer.KeyedPools.backedBy({ k = a }, { consumable = true })
			assert.are.equal(a, keyed:get("k").pool)
			keyed:get("k"):draw()
			assert.are.equal(1, #a)
		end)

		it("should use existing pools without wrapping", function()
			local pool = randomizer.Pool.backedBy({ 1, 2 })
			local keyed = randomizer.KeyedPools.backedBy({ k = pool })
			assert.are.equal(pool, keyed:get("k"))
		end)
	end)
end)
