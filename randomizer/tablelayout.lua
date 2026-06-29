--- Shared table layout configuration for object display and change tables
-- @module randomizer.tablelayout

local tablelayout = {}

--- Convert a captured value to a display string
-- @param value any captured field or key value
-- @return string
function tablelayout._valueToString(value)
	if value == nil then
		return ""
	end

	if type(value) == "userdata" and value.toString then
		local result = value:toString()
		if result ~= nil then
			return tostring(result)
		end
	end

	return tostring(value)
end

--- Read a value from an object using a normalized key or field spec
-- Uses pcall because getters may raise errors from Java bindings.
-- @param obj object being read
-- @param spec table with a read function
-- @return any raw value, or nil when the read fails
function tablelayout._readRaw(obj, spec)
	if not spec or not spec.read then
		return nil
	end

	local ok, result = pcall(spec.read, obj)
	if not ok or result == nil then
		return nil
	end

	return result
end

--- Normalize a field spec from table layout config
-- @param spec table with field or getter, plus optional header and align
-- @return table|nil normalized field definition
-- @return string|nil error message when invalid
function tablelayout._normalizeFieldSpec(spec)
	if type(spec) ~= "table" or (not spec.field and not spec.getter and not spec.name) then
		return nil, "field requires field or getter"
	end

	local key = spec.field or spec.name
	return {
		key = key,
		header = spec.header or key,
		align = spec.align or "left",
		read = spec.getter or function(obj)
			return obj[spec.field]
		end,
	}, nil
end

--- Normalize a primary key or description spec from table layout config
-- @param spec table with field or getter, plus optional header, align, and numeric
-- @param defaultHeader string fallback column header
-- @return table|nil normalized key definition
-- @return string|nil error message when invalid
function tablelayout._normalizeKeySpec(spec, defaultHeader)
	if type(spec) ~= "table" then
		return nil, "key spec is required"
	end

	return {
		header = spec.header or defaultHeader,
		align = spec.align or "left",
		numeric = spec.numeric or false,
		read = spec.getter or function(obj)
			return obj[spec.field]
		end,
	}, nil
end

--- Validate and normalize a table layout config
-- @param config table layout config with primaryKey, optional description, and fields
-- @return table|nil normalized layout entry
-- @return string|nil error message when invalid
function tablelayout._normalizeLayoutConfig(config)
	if type(config) ~= "table" then
		return nil, "layout config must be a table"
	end

	if type(config.fields) ~= "table" then
		return nil, "layout config requires fields"
	end

	if not config.primaryKey then
		return nil, "layout config requires primaryKey"
	end

	local primaryKey, primaryKeyError = tablelayout._normalizeKeySpec(config.primaryKey, "ID")
	if not primaryKey then
		return nil, primaryKeyError
	end

	local description = nil
	if config.description then
		description, primaryKeyError = tablelayout._normalizeKeySpec(config.description, "Description")
		if not description then
			return nil, primaryKeyError
		end
	end

	local entry = {
		title = config.title,
		headerEvery = config.headerEvery,
		trailingHeader = config.trailingHeader or false,
		primaryKey = primaryKey,
		description = description,
		fields = {},
	}

	for index, fieldSpec in ipairs(config.fields) do
		local field, fieldError = tablelayout._normalizeFieldSpec(fieldSpec)
		if not field then
			return nil, fieldError or ("invalid field at index " .. index)
		end
		table.insert(entry.fields, field)
	end

	return entry, nil
end

--- Build display columns: primary key, optional description, then one column per field
-- @param entry table normalized layout entry
-- @return table column definitions for asciitable.render
function tablelayout._buildDisplayColumns(entry)
	local columns = {
		{
			role = "primary",
			header = entry.primaryKey.header,
			align = entry.primaryKey.align,
		},
	}

	if entry.description then
		table.insert(columns, {
			role = "description",
			header = entry.description.header,
			align = entry.description.align,
		})
	end

	for _, field in ipairs(entry.fields) do
		table.insert(columns, {
			role = "field",
			fieldKey = field.key,
			header = field.header,
			align = field.align,
		})
	end

	return columns
end

--- Build change columns: primary key, optional description, then From/To pairs per field
-- @param entry table normalized layout entry
-- @return table column definitions for change tables
function tablelayout._buildChangeColumns(entry)
	local columns = {
		{
			role = "primary",
			header = entry.primaryKey.header,
			align = entry.primaryKey.align,
		},
	}

	if entry.description then
		table.insert(columns, {
			role = "description",
			header = entry.description.header,
			align = entry.description.align,
		})
	end

	for _, field in ipairs(entry.fields) do
		table.insert(columns, {
			role = "from",
			fieldKey = field.key,
			header = field.header .. " From",
			align = field.align,
		})
		table.insert(columns, {
			role = "to",
			fieldKey = field.key,
			header = field.header .. " To",
			align = field.align,
		})
	end

	return columns
end

--- Format a key value for display in table output
-- @param raw any raw key value
-- @param keySpec table normalized primary or description key spec
-- @return string
function tablelayout._formatKeyDisplay(raw, keySpec)
	if raw == nil then
		return ""
	end

	if keySpec.numeric then
		local numberValue = tonumber(raw)
		if numberValue then
			return tostring(numberValue)
		end
	end

	return tablelayout._valueToString(raw)
end

--- Get the sortable value for a key column
-- @param raw any raw key value
-- @param keySpec table normalized primary key spec
-- @return number|string value used for row sorting
function tablelayout._keySortValue(raw, keySpec)
	if raw == nil then
		return keySpec.numeric and 0 or ""
	end

	if keySpec.numeric then
		return tonumber(raw) or 0
	end

	return tablelayout._valueToString(raw)
end

--- Read display and sort values for a configured key column
-- @param obj object being read
-- @param keySpec table normalized key spec
-- @return string display value, number|string sort value
function tablelayout._readKeyFields(obj, keySpec)
	local raw = tablelayout._readRaw(obj, keySpec)
	return tablelayout._formatKeyDisplay(raw, keySpec), tablelayout._keySortValue(raw, keySpec)
end

--- Sort objects by the configured primary key
-- @param objects table array of objects
-- @param primaryKey table normalized primary key spec
-- @return table sorted array of { object, primary, primarySort, description }
function tablelayout._sortedRows(objects, entry)
	local rows = {}

	for _, obj in ipairs(objects) do
		local primary, primarySort = tablelayout._readKeyFields(obj, entry.primaryKey)
		local description = ""
		if entry.description then
			description = tablelayout._formatKeyDisplay(
				tablelayout._readRaw(obj, entry.description),
				entry.description
			)
		end

		table.insert(rows, {
			object = obj,
			primary = primary,
			primarySort = primarySort,
			description = description,
		})
	end

	table.sort(rows, function(leftRow, rightRow)
		if entry.primaryKey.numeric then
			return (tonumber(leftRow.primarySort) or 0) < (tonumber(rightRow.primarySort) or 0)
		end

		return tostring(leftRow.primarySort) < tostring(rightRow.primarySort)
	end)

	return rows
end

--- Build display cell values for one object row
-- @param rowData table row metadata from _sortedRows
-- @param entry table normalized layout entry
-- @return table cell values in column order
function tablelayout._buildDisplayRowValues(rowData, entry)
	local values = { rowData.primary }

	if entry.description then
		table.insert(values, rowData.description)
	end

	for _, field in ipairs(entry.fields) do
		table.insert(values, tablelayout._valueToString(tablelayout._readRaw(rowData.object, field)))
	end

	return values
end

--- Capture current field values for one object
-- @param obj object being captured
-- @param fields table normalized field definitions
-- @return table field values keyed by field key
function tablelayout._captureFieldState(obj, fields)
	local state = {}

	for _, field in ipairs(fields) do
		local value = tablelayout._readRaw(obj, field)
		if value ~= nil then
			state[field.key] = value
		end
	end

	return state
end

return tablelayout
