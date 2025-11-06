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

		-- Note: Userdata conversion can't be tested in pure Lua since we can't create userdata
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

	describe("Remove Duplicates", function()
		it("should remove duplicates from array", function()
			local result = utils.removeDuplicates({ 1, 2, 2, 3, 3, 3, 4 })
			assert.are.same({ 1, 2, 3, 4 }, result)
		end)

		it("should handle empty array", function()
			local result = utils.removeDuplicates({})
			assert.are.same({}, result)
		end)
	end)

	describe("Serialization", function()
		it("should serialize tables for comparison", function()
			local tbl1 = { a = 1, b = 2 }
			local tbl2 = { b = 2, a = 1 } -- Same content, different order

			local ser1 = utils.serializeForComparison(tbl1)
			local ser2 = utils.serializeForComparison(tbl2)

			-- Should be equal because serialization sorts keys
			assert.are.equal(ser1, ser2)
		end)

		it("should serialize non-table values", function()
			assert.are.equal("42", utils.serializeForComparison(42))
			assert.are.equal("hello", utils.serializeForComparison("hello"))
		end)

		it("should serialize nested tables", function()
			local tbl = {
				a = 1,
				b = {
					c = 2,
					d = 3,
				},
			}

			local serialized = utils.serializeForComparison(tbl)
			assert.is_string(serialized)
			assert.is_true(#serialized > 0)
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
end)
