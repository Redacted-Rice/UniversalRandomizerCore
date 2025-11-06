describe("Init Module - Standalone Functions", function()
	local randomizer

	setup(function()
		randomizer = require("randomizer")
	end)

	describe("Universal Randomize Function", function()
		before_each(function()
			randomizer.setSeed(42)
		end)

		it("should work with plain table", function()
			local target = { { val = 1 }, { val = 2 }, { val = 3 }, { val = 4 } }
			local pool = { 10, 20, 30 }

			randomizer.randomize(target, pool, "val")

			-- All items should be from the pool
			for _, obj in ipairs(target) do
				assert.is_true(obj.val == 10 or obj.val == 20 or obj.val == 30)
			end
		end)

		it("should work with List instance", function()
			local target = { { val = 1 }, { val = 2 }, { val = 3 } }
			local pool = randomizer.list({ 10, 20, 30 })

			randomizer.randomize(target, pool, "val")

			for _, obj in ipairs(target) do
				assert.is_true(obj.val == 10 or obj.val == 20 or obj.val == 30)
			end
		end)

		it("should work with Group instance", function()
			local items = {
				{ char = "a", replacement = "" },
				{ char = "b", replacement = "" },
				{ char = "c", replacement = "" },
			}
			local groups = randomizer.group({
				vowel = { "A", "E", "I" },
				consonant = { "B", "C", "D" },
			})

			local function isVowel(char)
				return char == "a" or char == "e" or char == "i" or char == "o" or char == "u"
			end

			randomizer.randomize(items, groups, function(item)
				return isVowel(item.char) and "vowel" or "consonant"
			end, "replacement")

			-- Verify first item (vowel) came from vowel pool
			assert.is_true(items[1].replacement == "A" or items[1].replacement == "E" or items[1].replacement == "I")

			-- Verify second and third items (consonants) came from consonant pool
			assert.is_true(items[2].replacement == "B" or items[2].replacement == "C" or items[2].replacement == "D")
			assert.is_true(items[3].replacement == "B" or items[3].replacement == "C" or items[3].replacement == "D")
		end)

		it("should error when source is invalid type", function()
			local target = { 1, 2, 3 }

			assert.has_error(function()
				randomizer.randomize(target, "not a valid source")
			end)
		end)
	end)

	describe("Module Metadata", function()
		it("should have version information", function()
			assert.are.equal("0.9.0", randomizer._VERSION)
			assert.is_string(randomizer._DESCRIPTION)
		end)

		it("should expose List class", function()
			assert.is_table(randomizer.List)
			assert.is_function(randomizer.List.new)
		end)

		it("should expose Group class", function()
			assert.is_table(randomizer.Group)
			assert.is_function(randomizer.Group.new)
		end)
	end)
end)
