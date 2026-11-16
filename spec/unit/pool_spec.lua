describe("Pool", function()
	local randomizer

	setup(function()
		randomizer = require("randomizer")
	end)

	describe("construction", function()
		it("should wrap a table in a copied array", function()
			local pool = randomizer.pool({ 1, 2, 3 })
			assert.is_true(randomizer.isPool(pool))
			assert.are.equal(3, #pool.pool)
			assert.are.equal(0, #pool.used)
			assert.is_false(pool.consumesSelected)
			assert.is_false(pool.autoRegenerates)
		end)

		it("should copy an existing list so draws do not mutate the source", function()
			randomizer.setSeed(1)
			local list = randomizer.list({ "a", "b" })
			local pool = randomizer.pool(list, { consumesSelected = true })
			assert.are_not.equal(list.items, pool.pool)
			pool:draw()
			assert.are.equal(2, list:size())
			assert.are.equal(1, #pool.pool)
		end)

		it("should honor consumable and regenerate in pool options", function()
			local pool = randomizer.pool({ 1 }, { consumesSelected = true, autoRegenerates = true })
			assert.is_true(pool.consumesSelected)
			assert.is_true(pool.autoRegenerates)
		end)

		it("should wrap an array without copying via backedBy", function()
			local items = { 1, 2, 3 }
			local pool = randomizer.Pool.backedBy(items)

			assert.are.equal(items, pool.pool)
			assert.are.equal(0, #pool.used)
		end)

		it("should share backing storage when drawing consumable backedBy pools", function()
			randomizer.setSeed(1)
			local items = { "a", "b" }
			local pool = randomizer.Pool.backedBy(items, { consumesSelected = true })
			pool:draw()
			assert.are.equal(1, #items)
		end)

		it("should error when backedBy receives a List", function()
			local list = randomizer.list({ 1 })
			assert.has_error(function()
				randomizer.Pool.backedBy(list)
			end)
		end)
	end)

	describe("copy", function()
		it("should deep copy pool and used state", function()
			randomizer.setSeed(3)
			local original = randomizer.pool({ 1, 2, 3 }, { consumesSelected = true, autoRegenerates = false })
			original:draw()
			local copy = randomizer.Pool.new(original)
			assert.are_not.equal(original, copy)
			assert.are_not.equal(original.pool, copy.pool)
			assert.are.equal(original:remainingCount(), copy:remainingCount())
			assert.are.equal(#original.used, #copy.used)
			assert.is_true(copy.consumesSelected)
			assert.is_false(copy.autoRegenerates)
		end)

		it("should override options when poolOptions are passed to new", function()
			local original = randomizer.pool({ 1 }, { consumesSelected = false })
			local copy = randomizer.Pool.new(original, { consumesSelected = true, autoRegenerates = true })
			assert.is_true(copy.consumesSelected)
			assert.is_true(copy.autoRegenerates)
		end)
	end)

	describe("draw", function()
		it("should sample with replacement when not consumable", function()
			randomizer.setSeed(42)
			local pool = randomizer.pool({ 1, 2 })
			pool:draw()
			pool:draw()
			assert.are.equal(2, #pool.pool)
			assert.are.equal(0, #pool.used)
		end)

		it("should consume without replacement when consumable and not regenerating", function()
			randomizer.setSeed(42)
			local pool = randomizer.pool({ "A", "B", "C" }, { consumesSelected = true, autoRegenerates = false })
			local seen = {}
			for _ = 1, 3 do
				table.insert(seen, pool:draw())
			end
			assert.are.equal(0, #pool.pool)
			assert.are.equal(3, #pool.used)
			table.sort(seen)
			assert.are.same({ "A", "B", "C" }, seen)
		end)

		it("should not draw again when consumable pool is depleted without regenerate", function()
			randomizer.setSeed(7)
			local pool = randomizer.pool({ 1, 2 }, { consumesSelected = true, autoRegenerates = false })
			pool:draw()
			pool:draw()
			pool.errorOnExhausted = false
			assert.is_nil(pool:draw())
			pool.errorOnExhausted = true
			assert.has_error(function()
				pool:draw()
			end)
		end)

		it("should swap used back into pool when regenerate is true", function()
			randomizer.setSeed(7)
			local pool = randomizer.pool({ 1, 2 }, { consumesSelected = true, autoRegenerates = true })
			pool:draw()
			pool:draw()
			local third = pool:draw()
			assert.is_true(third == 1 or third == 2)
			assert.are.equal(1, #pool.pool)
			assert.are.equal(1, #pool.used)
		end)

		it("should return nil when pool and used are empty and errorOnExhausted is false", function()
			local pool = randomizer.pool(randomizer.list({}), {
				consumesSelected = true,
				autoRegenerates = true,
				errorOnExhausted = false,
			})
			assert.is_nil(pool:draw())
		end)

		it("should error when pool and used are empty and errorOnExhausted is true", function()
			local pool = randomizer.pool(randomizer.list({}), {
				consumesSelected = true,
				autoRegenerates = true,
				errorOnExhausted = true,
			})
			assert.has_error(function()
				pool:draw()
			end)
		end)
	end)

	describe("removeFromPool", function()
		it("should remove matches from pool and used by default", function()
			local pool = randomizer.pool({ 1, 2, 3 }, { consumesSelected = true, autoRegenerates = false })
			pool:removeFromPool(2, function(a, b)
				return a == b
			end)
			assert.are.equal(2, #pool.pool)
			for _, value in ipairs(pool.pool) do
				assert.are_not.equal(2, value)
			end
		end)

		it("should remove from pool only when removeFromUsed is false", function()
			randomizer.setSeed(42)
			local pool = randomizer.pool({ 1, 2, 3 }, { consumesSelected = true, autoRegenerates = false })
			local drawn = pool:draw()
			pool:removeFromPool(drawn, function(a, b)
				return a == b
			end, false)
			assert.are.equal(1, #pool.used)
			assert.are.equal(drawn, pool.used[1])
		end)
	end)

	describe("remainingCount", function()
		it("should reflect the working pool size", function()
			local pool = randomizer.pool({ 1, 2, 3 })
			assert.are.equal(3, pool:remainingCount())
			randomizer.setSeed(1)
			pool:draw()
			assert.are.equal(3, pool:remainingCount())
		end)
	end)

	describe("usedCount", function()
		it("should count consumable draws in used", function()
			randomizer.setSeed(1)
			local pool = randomizer.pool({ 1, 2 }, { consumesSelected = true, autoRegenerates = false })
			pool:draw()
			assert.are.equal(1, pool:usedCount())
			assert.are.equal(1, pool:remainingCount())
		end)
	end)

	describe("drawWithConstraint", function()
		it("should draw only values that pass constraintFn without removing rejected options", function()
			randomizer.setSeed(42)
			local target = { banned = "B" }
			local pool = randomizer.pool({ "A", "B", "C" }, {
				constraintFn = function(t, value)
					return value ~= t.banned
				end,
			})

			local drawn = pool:drawWithConstraint(target)

			assert.is_true(drawn == "A" or drawn == "C")
			assert.are.equal(3, pool:remainingCount())
		end)

		it("should drop constraint failures from the pool when constraintRemovesFailures is true", function()
			randomizer.setSeed(1)
			local target = { banned = "B" }
			local pool = randomizer.pool({ "B", "B", "C" }, {
				consumesSelected = true,
				autoRegenerates = true,
				constraintRemovesFailures = true,
				constraintFn = function(t, value)
					return value ~= t.banned
				end,
			})

			local drawn = pool:drawWithConstraint(target)

			assert.are.equal("C", drawn)
			for _, item in ipairs(pool.pool) do
				assert.are_not.equal("B", item)
			end
		end)

		it("should handle nil constraintFn", function()
			randomizer.setSeed(1)
			local pool = randomizer.pool({ 9, 10 })
			local drawn = pool:drawWithConstraint({ id = 1 })
			assert.is_true(drawn == 9 or drawn == 10)
			assert.are.equal(2, pool:remainingCount())
			assert.are.equal(0, pool:usedCount())
		end)

		it("should return nil or error when the pool is empty after constraint failures based on errorOnExhausted", function()
			local pool = randomizer.pool({ 1, 2, 3 }, {
				consumesSelected = true,
				autoRegenerates = false,
				constraintRemovesFailures = false,
				errorOnExhausted = false,
				constraintFn = function()
					return false
				end,
			})

			assert.is_nil(pool:drawWithConstraint({ id = 1 }))

			pool.errorOnExhausted = true
			assert.has_error(function()
				pool:drawWithConstraint({ id = 1 })
			end)
		end)

		it("should return rejected draws to the working if constraintRemovesFailures is false", function()
			randomizer.setSeed(42)
			local pool = randomizer.pool({ 1, 2, 3 }, {
				consumesSelected = true,
				constraintRemovesFailures = false,
				constraintFn = function(_, value)
					return value == 3
				end,
			})

			local drawn = pool:drawWithConstraint({ id = 1 })

			assert.are.equal(3, drawn)
			assert.are.equal(2, pool:remainingCount())
			assert.are.equal(1, pool:usedCount())
			for _, value in ipairs(pool.pool) do
				assert.are_not.equal(3, value)
			end
		end)

		it("should return rejected draws to the used pool if constraintRemovesFailures is true", function()
			randomizer.setSeed(42)
			local pool = randomizer.pool({ 1, 2, 3 }, {
				consumesSelected = true,
				constraintRemovesFailures = true,
				constraintFn = function(_, value)
					return value == 3
				end,
			})

			local drawn = pool:drawWithConstraint({ id = 1 })

			assert.are.equal(3, drawn)
			assert.are.equal(1, pool:remainingCount())
			assert.are_not.equal(3, pool.pool[1])
			assert.are.equal(2, pool:usedCount())
			local inUsed = {}
			for _, value in ipairs(pool.used) do
				inUsed[value] = true
			end
			assert.is_true(inUsed[3])
		end)

		it("should not return the selected value to the working pool when consumesSelected is true", function()
			randomizer.setSeed(1)
			local pool = randomizer.pool({ "A", "B" }, {
				consumesSelected = true,
				constraintFn = function()
					return true
				end,
			})

			local drawn = pool:drawWithConstraint({ id = 1 })

			assert.is_not_nil(drawn)
			for _, value in ipairs(pool.pool) do
				assert.are_not.equal(drawn, value)
			end
			assert.are.equal(1, pool:usedCount())
			assert.are.equal(drawn, pool.used[1])
		end)

		it("should return the selected value to the working pool when consumesSelected is false even if constraintRemovesFailures is true", function()
			randomizer.setSeed(3)
			local pool = randomizer.pool({ "A", "B" }, {
				consumesSelected = false,
				constraintRemovesFailures = true,
				constraintFn = function(_, value)
					return value == "B"
				end,
			})

			local drawn = pool:drawWithConstraint({ id = 1 })

			assert.are.equal("B", drawn)
			assert.are.equal(1, pool:remainingCount())
			assert.are.equal("B", pool.pool[1])
			assert.are.equal(1, pool:usedCount())
			assert.are.equal("A", pool.used[1])
		end)

		it("should regenerate from used when the working pool is empty and autoRegenerates is true", function()
			randomizer.setSeed(1)
			local pool = randomizer.pool({ 11 }, {
				consumesSelected = true,
				autoRegenerates = true,
				constraintFn = function(_, value)
					return value == 11
				end,
			})
			pool:draw()
			assert.are.equal(0, pool:remainingCount())
			assert.are.equal(1, pool:usedCount())

			local drawn = pool:drawWithConstraint({ id = 1 })

			assert.are.equal(11, drawn)
			assert.are.equal(0, pool:remainingCount())
			assert.are.equal(1, pool:usedCount())
		end)

		it("should return nil when autoRegenerates cannot satisfy the constraint after regen", function()
			local pool = randomizer.pool({ "bad" }, {
				consumesSelected = true,
				autoRegenerates = true,
				constraintRemovesFailures = true,
				constraintFn = function()
					return false
				end,
			})

			assert.is_nil(pool:drawWithConstraint({ id = 1 }))
			assert.are.equal(0, pool:remainingCount())
			assert.are.equal(1, pool:usedCount())
		end)
	end)

	describe("regenerate", function()
		it("should refill the working pool from used when called manually", function()
			local pool = randomizer.pool({ "bad" }, {
				consumesSelected = true,
				autoRegenerates = false,
				constraintRemovesFailures = true,
				constraintFn = function()
					return false
				end,
			})

			assert.is_nil(pool:drawWithConstraint({ id = 1 }))
			assert.are.equal(0, pool:remainingCount())
			assert.are.equal(1, pool:usedCount())

			pool:regenerate()

			assert.are.equal(1, pool:remainingCount())
			assert.are.equal(0, pool:usedCount())
			assert.are.equal("bad", pool.pool[1])
		end)

		it("should append used into a non empty working pool", function()
			local pool = randomizer.pool({ "a" }, { consumesSelected = true, autoRegenerates = false })
			pool:draw()
			pool.pool = { "b" }
			pool:regenerate()
			assert.are.same({ "b", "a" }, pool.pool)
			assert.are.equal(0, pool:usedCount())
		end)
	end)

	describe("canDraw", function()
		it("should be true when the working pool has items", function()
			local pool = randomizer.pool({ 1 })
			assert.is_true(pool:canDraw())
		end)

		it("should be true when regenerate can swap used back into the working pool", function()
			randomizer.setSeed(7)
			local pool = randomizer.pool({ 1, 2 }, { consumesSelected = true, autoRegenerates = true })
			pool:draw()
			pool:draw()
			assert.are.equal(0, pool:remainingCount())
			assert.is_true(pool:canDraw())
		end)

		it("should be false when consumable pool is depleted without regenerate", function()
			randomizer.setSeed(7)
			local pool = randomizer.pool({ 1, 2 }, { consumesSelected = true, autoRegenerates = false })
			pool:draw()
			pool:draw()
			assert.is_false(pool:canDraw())
		end)
	end)

	describe("__tostring", function()
		it("should summarize remaining and used counts", function()
			randomizer.setSeed(1)
			local pool = randomizer.pool({ 1, 2 }, { consumesSelected = true })
			assert.are.equal("Pool(2 remaining, 0 used)", tostring(pool))
			pool:draw()
			assert.are.equal("Pool(1 remaining, 1 used)", tostring(pool))
		end)
	end)
end)
