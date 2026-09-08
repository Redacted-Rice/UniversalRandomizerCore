local utils = require("randomizer.utils")

describe("Utils Module - getValue and setValue", function()
	describe("getValue", function()
		-- Case 1: Field name
		it("should get a field value by name", function()
			local obj = { health = 100, name = "Hero" }
			assert.are.equal(100, utils.getValue(obj, "health"))
			assert.are.equal("Hero", utils.getValue(obj, "name"))
		end)

		it("should return nil when field does not exist", function()
			local obj = { health = 100 }
			assert.is_nil(utils.getValue(obj, "missing"))
		end)

		-- Case 2: Method name (function to call)
		it("should call a method by name", function()
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

			function Object:getScaled(multiplier)
				return self._value * multiplier
			end

			local obj = Object.new(10)
			assert.are.equal(10, utils.getValue(obj, "getValue"))
			assert.are.equal(30, utils.getValue(obj, "getScaled", 3))
		end)

		-- Case 3: Function
		it("should invoke a provided getter function", function()
			local obj = { x = 5, y = 10 }
			local result = utils.getValue(obj, function(subject)
				return subject.x + subject.y
			end)
			assert.are.equal(15, result)
		end)

		it("should pass additional arguments to getter function", function()
			local obj = { value = 5 }
			local result = utils.getValue(obj, function(subject, factor, bonus)
				return subject.value * factor + bonus
			end, 3, 7)
			assert.are.equal(22, result) -- 5 * 3 + 7
		end)

		-- Metatable support
		it("should access values via __index metamethod", function()
			local proxy = setmetatable({}, {
				__index = function(_, key)
					if key == "getDouble" then
						return function(self)
							return (self._base or 10) * 2
						end
					elseif key == "computed" then
						return 99
					end
				end,
			})
			proxy._base = 7

			assert.are.equal(14, utils.getValue(proxy, "getDouble"))
			assert.are.equal(99, utils.getValue(proxy, "computed"))
		end)

		-- Error cases
		it("should error when getter type is invalid", function()
			assert.has_error(function()
				utils.getValue({}, 123)
			end)
		end)

		it("should return nil for non-table subject with string getter", function()
			-- Non-table values should return null
			assert.is_nil(utils.getValue(123, "value"))
			assert.is_nil(utils.getValue("string", "value"))
			assert.is_nil(utils.getValue(nil, "value"))
		end)

		it("should resolve colon-separated getter paths", function()
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

			local move = Move.new(Host.new("fire"))
			assert.are.equal("fire", utils.getValue(move, "getHost:type"))
		end)

		it("should return nil when a colon-separated path step is missing", function()
			local move = {
				getHost = function()
					return nil
				end,
			}
			assert.is_nil(utils.getValue(move, "getHost:type"))
		end)

		it("should forward extra arguments through colon-separated getter paths", function()
			local Host = {}
			Host.__index = Host

			function Host.new(value)
				local instance = setmetatable({}, Host)
				instance.value = value
				return instance
			end

			function Host:getScaled(multiplier)
				return self.value * multiplier
			end

			local Wrapper = {}
			Wrapper.__index = Wrapper

			function Wrapper.new(host)
				local instance = setmetatable({}, Wrapper)
				instance.host = host
				return instance
			end

			function Wrapper:getHost()
				return self.host
			end

			local wrapper = Wrapper.new(Host.new(5))
			assert.are.equal(15, utils.getValue(wrapper, "getHost:getScaled", 3))
		end)

	end)

	describe("asTableKey", function()
		it("should leave strings numbers and nil unchanged", function()
			assert.are.equal("BASIC", utils.asTableKey("BASIC"))
			assert.are.equal(2, utils.asTableKey(2))
			assert.is_nil(utils.asTableKey(nil))
		end)

		it("should leave plain tables unchanged", function()
			local tbl = { a = 1 }
			assert.are.equal(tbl, utils.asTableKey(tbl))
		end)

		-- enum userdata behavior is covered in RandomizerEnumSelectTest.java.
		-- pure lua busted specs cannot construct userdata
	end)

	describe("getValue vs asTableKey", function()
		it("should leave string extraction unchanged while asTableKey handles key normalization", function()
			local obj = { label = "FIRE" }
			assert.are.equal("FIRE", utils.getValue(obj, "label"))
			assert.are.equal("FIRE", utils.asTableKey(utils.getValue(obj, "label")))
		end)
	end)

	describe("setValue", function()
		-- Case 1: Field name
		it("should set a field value by name", function()
			local obj = { health = 100 }
			utils.setValue(obj, "health", 150)
			assert.are.equal(150, obj.health)
		end)

		it("should create new fields when setting by name", function()
			local obj = {}
			utils.setValue(obj, "newField", 42)
			assert.are.equal(42, obj.newField)
		end)

		-- Case 2: Method name (setter function)
		it("should call a setter method by name", function()
			local Object = {}
			Object.__index = Object

			function Object.new()
				local instance = setmetatable({}, Object)
				instance._value = 0
				return instance
			end

			function Object:setValue(value)
				self._value = value
			end

			function Object:setScaled(value, multiplier)
				self._value = value * multiplier
			end

			local obj = Object:new()
			utils.setValue(obj, "setValue", 50)
			assert.are.equal(50, obj._value)

			utils.setValue(obj, "setScaled", 10, 3)
			assert.are.equal(30, obj._value)
		end)

		-- Case 3: Function
		it("should invoke a provided setter function", function()
			local obj = { x = 5, y = 10 }
			utils.setValue(obj, function(subject, value)
				subject.x = value
				subject.y = value * 2
			end, 20)

			assert.are.equal(20, obj.x)
			assert.are.equal(40, obj.y)
		end)

		it("should pass additional arguments to setter function", function()
			local obj = { values = {} }
			utils.setValue(obj, function(subject, value, index)
				subject.values[index] = value
			end, 100, 5)

			assert.are.equal(100, obj.values[5])
		end)

		-- Metatable support
		it("should work with __newindex metamethod", function()
			local storage = {}
			local proxy = setmetatable({}, {
				__index = function(_, key)
					if key == "setCustom" then
						return function(_self, value)
							storage.custom = value .. "_modified"
						end
					end
					return storage[key]
				end,
				__newindex = function(_, key, value)
					storage[key] = value .. "_stored"
				end,
			})

			-- Setting field through __newindex
			utils.setValue(proxy, "field", "data")
			assert.are.equal("data_stored", storage.field)

			-- Setting via method
			utils.setValue(proxy, "setCustom", "value")
			assert.are.equal("value_modified", storage.custom)
		end)

		-- Combined with getValue
		it("should work in combination with getValue", function()
			local obj = {
				_health = 100,
				getHealth = function(self)
					return self._health
				end,
				setHealth = function(self, value)
					self._health = value
				end,
			}

			local current = utils.getValue(obj, "getHealth")
			assert.are.equal(100, current)

			utils.setValue(obj, "setHealth", 200)
			assert.are.equal(200, utils.getValue(obj, "getHealth"))
		end)

		it("should set values using a colon-separated field path", function()
			local obj = {
				host = { value = 0 },
			}

			utils.setValue(obj, "host:value", 42)

			assert.are.equal(42, obj.host.value)
		end)

		it("should set values using a colon-separated method path", function()
			local Host = {}
			Host.__index = Host

			function Host.new()
				local instance = setmetatable({ value = 0 }, Host)
				return instance
			end

			function Host:setValue(value)
				self.value = value
			end

			local Wrapper = {}
			Wrapper.__index = Wrapper

			function Wrapper.new(host)
				local instance = setmetatable({}, Wrapper)
				instance.host = host
				return instance
			end

			function Wrapper:getHost()
				return self.host
			end

			local wrapper = Wrapper.new(Host.new())
			utils.setValue(wrapper, "getHost:setValue", 99)

			assert.are.equal(99, wrapper.host.value)
		end)

		it("should forward extra arguments to the final setter in a colon-separated path", function()
			local Host = {}
			Host.__index = Host

			function Host.new()
				local instance = setmetatable({ value = 0 }, Host)
				return instance
			end

			function Host:setScaled(value, multiplier)
				self.value = value * multiplier
			end

			local Wrapper = {}
			Wrapper.__index = Wrapper

			function Wrapper.new(host)
				local instance = setmetatable({}, Wrapper)
				instance.host = host
				return instance
			end

			function Wrapper:getHost()
				return self.host
			end

			local wrapper = Wrapper.new(Host.new())
			utils.setValue(wrapper, "getHost:setScaled", 10, 3)

			assert.are.equal(30, wrapper.host.value)
		end)

		it("should error when a colon-separated setter path step is missing", function()
			local obj = {
				getHost = function()
					return nil
				end,
			}

			assert.has_error(function()
				utils.setValue(obj, "getHost:value", 10)
			end)
		end)

		-- Error cases
		it("should error when setter type is invalid", function()
			assert.has_error(function()
				utils.setValue({}, 123, "value")
			end)
		end)
	end)

	describe("getValue and setValue integration", function()
		it("should handle all three cases for getter and setter", function()
			-- Test object with field, methods, and custom functions
			local TestObject = {}
			TestObject.__index = TestObject

			function TestObject.new()
				local instance = setmetatable({}, TestObject)
				instance.directField = 0
				instance._privateValue = 0
				return instance
			end

			function TestObject:getPrivate()
				return self._privateValue
			end

			function TestObject:setPrivate(value)
				self._privateValue = value
			end

			local obj = TestObject.new()

			-- Case 1: Direct field access
			utils.setValue(obj, "directField", 10)
			assert.are.equal(10, utils.getValue(obj, "directField"))

			-- Case 2: Method name
			utils.setValue(obj, "setPrivate", 20)
			assert.are.equal(20, utils.getValue(obj, "getPrivate"))

			-- Case 3: Functions
			utils.setValue(obj, function(o, v)
				o.directField = v * 2
			end, 15)
			assert.are.equal(
				30,
				utils.getValue(obj, function(o)
					return o.directField
				end)
			)
		end)
	end)
end)
-- utils_spec.lua
-- Unit tests for utility functions

describe("Utils Module", function()
	describe("Shuffle", function()
		it("should shuffle a table", function()
			local randomizer = require("randomizer")
			randomizer.setSeed(42)

			local tbl = { 1, 2, 3, 4, 5 }
			utils.shuffle(tbl)

			-- Should have same elements
			table.sort(tbl)
			assert.are.same({ 1, 2, 3, 4, 5 }, tbl)
		end)
	end)

	describe("Deep Copy", function()
		it("should deepCopy non-table values", function()
			assert.are.equal(42, utils.deepCopy(42))
			assert.are.equal("hello", utils.deepCopy("hello"))
			assert.are.equal(true, utils.deepCopy(true))
			assert.is_nil(utils.deepCopy(nil))
		end)

		it("should deepCopy tables", function()
			local original = { a = 1, b = 2, c = { d = 3 } }
			local copy = utils.deepCopy(original)

			-- Should have same values
			assert.are.equal(1, copy.a)
			assert.are.equal(2, copy.b)
			assert.are.equal(3, copy.c.d)

			-- Should be different table
			assert.are_not.equal(original, copy)

			-- Modifying copy shouldn't affect original
			copy.a = 999
			assert.are.equal(1, original.a)
		end)

		it("should deepCopy table with metatable", function()
			local mt = {
				__tostring = function()
					return "test"
				end,
			}
			local original = setmetatable({ a = 1 }, mt)

			local copy = utils.deepCopy(original)

			assert.are.equal(1, copy.a)
			assert.are.equal(mt, getmetatable(copy))
			assert.are.equal("test", tostring(copy))
		end)
	end)

	describe("deepEqual", function()
		it("should return true for equal primitives", function()
			assert.is_true(utils.deepEqual(1, 1))
			assert.is_true(utils.deepEqual("a", "a"))
			assert.is_true(utils.deepEqual(true, true))
		end)

		it("should return false for unequal primitives", function()
			assert.is_false(utils.deepEqual(1, 2))
			assert.is_false(utils.deepEqual("a", "b"))
		end)

		it("should return false for type mismatches", function()
			assert.is_false(utils.deepEqual(1, "1"))
			assert.is_false(utils.deepEqual({}, 1))
		end)

		it("should handle nil values", function()
			assert.is_true(utils.deepEqual(nil, nil))
			assert.is_false(utils.deepEqual(nil, 1))
			assert.is_false(utils.deepEqual(1, nil))
		end)

		it("should compare flat tables with equal content", function()
			assert.is_true(utils.deepEqual({ a = 1, b = 2 }, { a = 1, b = 2 }))
			assert.is_true(utils.deepEqual({ b = 2, a = 1 }, { a = 1, b = 2 }))
		end)

		it("should return false when table keys or values differ", function()
			assert.is_false(utils.deepEqual({ a = 1 }, { a = 2 }))
			assert.is_false(utils.deepEqual({ a = 1 }, { b = 1 }))
			assert.is_false(utils.deepEqual({ a = 1, b = 2 }, { a = 1 }))
		end)

		it("should compare nested tables recursively", function()
			local left = { stats = { hp = 100, moves = { "Tackle", "Growl" } } }
			local right = { stats = { hp = 100, moves = { "Tackle", "Growl" } } }
			assert.is_true(utils.deepEqual(left, right))
			right.stats.moves[2] = "Scratch"
			assert.is_false(utils.deepEqual(left, right))
		end)

		it("should return true for the same table reference", function()
			local tbl = { x = 1 }
			assert.is_true(utils.deepEqual(tbl, tbl))
		end)

		it("should handle circular table references", function()
			local left = { name = "loop" }
			left.self = left
			local right = { name = "loop" }
			right.self = right

			assert.is_true(utils.deepEqual(left, right))
		end)

		it("should return false for circular tables with different content", function()
			local left = { name = "a" }
			left.self = left
			local right = { name = "b" }
			right.self = right

			assert.is_false(utils.deepEqual(left, right))
		end)
	end)

	describe("Remove Duplicates", function()
		it("should remove duplicates from array", function()
			local result = utils.removeDuplicates({ 1, 2, 2, 3, 3, 3, 4 })
			assert.are.same({ 1, 2, 3, 4 }, result)
		end)

		it("should handle empty array", function()
			local result = utils.removeDuplicates({})
			assert.are.same({}, result)
		end)

		it("should remove duplicate tables with equal content", function()
			local result = utils.removeDuplicates({
				{ id = 1, name = "a" },
				{ id = 2, name = "b" },
				{ id = 1, name = "a" },
				{ id = 3, name = "c" },
				{ id = 2, name = "b" },
			})

			assert.are.equal(3, #result)
			assert.are.same({ id = 1, name = "a" }, result[1])
			assert.are.same({ id = 2, name = "b" }, result[2])
			assert.are.same({ id = 3, name = "c" }, result[3])
		end)

		it("should treat tables with different key order as duplicates", function()
			local result = utils.removeDuplicates({
				{ a = 1, b = 2 },
				{ b = 2, a = 1 },
			})

			assert.are.equal(1, #result)
			assert.are.same({ a = 1, b = 2 }, result[1])
		end)

		it("should keep distinct nested tables", function()
			local result = utils.removeDuplicates({
				{ nested = { x = 1 } },
				{ nested = { x = 2 } },
				{ nested = { x = 1 } },
			})

			assert.are.equal(2, #result)
		end)

		it("should dedupe primitives without deep comparing every prior value", function()
			local result = utils.removeDuplicates({
				"a",
				"b",
				"a",
				1,
				2,
				1,
				true,
				true,
			})

			assert.are.same({ "a", "b", 1, 2, true }, result)
		end)

		it("should remove duplicate circular tables with equal content", function()
			local first = { tag = "shared" }
			first.self = first
			local second = { tag = "shared" }
			second.self = second

			local result = utils.removeDuplicates({ first, second })

			assert.are.equal(1, #result)
			assert.is_true(utils.deepEqual(result[1], first))
		end)
	end)

	describe("Type Checking", function()
		it("should check if value is List", function()
			local randomizer = require("randomizer")
			local list = randomizer.list({ 1, 2, 3 })

			assert.is_true(utils.isList(list))
			assert.is_false(utils.isList({ 1, 2, 3 }))
			assert.is_false(utils.isList("not a list"))
		end)

		it("should check if value is Group", function()
			local randomizer = require("randomizer")
			local group = randomizer.group({ a = { 1, 2 } })

			assert.is_true(utils.isGroup(group))
			assert.is_false(utils.isGroup({ a = { 1, 2 } }))
			assert.is_false(utils.isGroup("not a group"))
		end)
	end)

	describe("Random Seed", function()
		it("should set random seed", function()
			local randomizer = require("randomizer")

			randomizer.setSeed(12345)
			local first = math.random(1, 100)

			randomizer.setSeed(12345)
			local second = math.random(1, 100)

			-- Same seed should produce same random number
			assert.are.equal(first, second)
		end)
	end)

	describe("Random Element", function()
		it("should get random element from table", function()
			local tbl = { 10, 20, 30 }
			local element = utils.randomElement(tbl)

			-- Should be one of the elements
			assert.is_true(element == 10 or element == 20 or element == 30)
		end)
	end)

	describe("isArrayLike and asArray", function()
		it("should treat empty tables as array-like", function()
			assert.is_true(utils.isArrayLike({}))
		end)

		it("should treat sequential tables as array-like", function()
			assert.is_true(utils.isArrayLike({ 1, 2, 3 }))
		end)

		it("should reject sparse or map-shaped tables", function()
			assert.is_false(utils.isArrayLike({ [2] = 1 }))
			assert.is_false(utils.isArrayLike({ a = 1 }))
		end)

		it("should unwrap List objects in asArray", function()
			local list = require("randomizer.list").new({ 1, 2, 3 })
			assert.are.same({ 1, 2, 3 }, utils.asArray(list))
		end)

		it("should accept array-like tables in asArray", function()
			assert.are.same({ 1, 2 }, utils.asArray({ 1, 2 }))
		end)

		it("should error on non-array-like tables in asArray", function()
			assert.has_error(function()
				utils.asArray({ a = 1 })
			end)
		end)
	end)
end)
