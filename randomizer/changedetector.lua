--- Change detection module for tracking object modifications
-- Supports multiple entries to track with their own associated parameters
-- Snapshots and comparisons must be called manually when desired
-- @module randomizer.changedetector

local asciitable = require("randomizer.asciitable")
local tablelayout = require("randomizer.tablelayout")
local logger = require("randomizer.logger")
local utils = require("randomizer.utils")

local changedetector = {}

-- Monitored data keyed by entry name
local monitoredEntries = {}
-- Temporary display overrides keyed by entry name (stacked per entry)
local displaySettingsStack = {}
-- Is change detection active
local isChangeDetectionActive = false

-- Internal row metadata keys stored alongside per-object change data
local RESERVED_ROW_KEYS = {
	_primary = true,
	_description = true,
	_primarySort = true,
	_format = true,
}

--- Check whether a key is internal row metadata rather than a row identifier
-- @param key any key from an entry changes table
-- @return boolean
function changedetector._isReservedRowKey(key)
	return RESERVED_ROW_KEYS[key] == true
end

--- Configure global change detection settings
-- @param active boolean whether change detection is active. Defaults to false
function changedetector.configure(active)
	isChangeDetectionActive = active or false
end

--- Validate and normalize monitor config into a stored entry definition
-- @param config table monitor config passed to changedetector.monitor
-- @return table|nil normalized entry definition
-- @return string|nil error message when invalid
function changedetector._normalizeMonitorConfig(config)
	local entry, configError = tablelayout._normalizeLayoutConfig(config)
	if not entry then
		return nil, configError
	end

	return entry, nil
end

--- Shallow-copy one normalized field definition
-- @param field table normalized field definition
-- @return table copied field definition
function changedetector._copyField(field)
	return {
		key = field.key,
		header = field.header,
		align = field.align,
		read = field.read,
		changeDisplay = field.changeDisplay,
		summaryGroup = field.summaryGroup,
		summaryLabel = field.summaryLabel,
	}
end

--- Copy a list of normalized field definitions
-- @param fields table array of normalized field definitions
-- @return table copied field definitions
function changedetector._copyFields(fields)
	local copies = {}
	for _, field in ipairs(fields) do
		table.insert(copies, changedetector._copyField(field))
	end
	return copies
end

--- Shallow-copy a display override spec
-- @param overrides table override spec passed to _applyDisplayOverrides
-- @return table copied override spec
function changedetector._copyDisplayOverrides(overrides)
	if not overrides then
		return nil
	end

	local copy = {}

	if overrides.detail then
		copy.detail = {}
		for _, fieldKey in ipairs(overrides.detail) do
			table.insert(copy.detail, fieldKey)
		end
	end

	if overrides.summary then
		copy.summary = {}
		for _, summarySpec in ipairs(overrides.summary) do
			table.insert(copy.summary, {
				field = summarySpec.field,
				label = summarySpec.label,
				group = summarySpec.group,
			})
		end
	end

	if overrides.summaryGroups then
		copy.summaryGroups = {}
		for _, groupSpec in ipairs(overrides.summaryGroups) do
			table.insert(copy.summaryGroups, {
				field = groupSpec.field,
				header = groupSpec.header,
				group = groupSpec.group,
				align = groupSpec.align,
			})
		end
	end

	return copy
end

--- Warn when a display override references a field not tracked on the entry
-- @param entryName string monitored entry name
-- @param baseFields table canonical tracked field definitions
-- @param overrides table override spec passed to _applyDisplayOverrides
function changedetector._validateDisplayOverrides(entryName, baseFields, overrides)
	if not overrides then
		return
	end

	local fieldsByKey = {}
	for _, field in ipairs(baseFields) do
		fieldsByKey[field.key] = true
	end

	local warned = {}

	local function warnUnknownField(fieldKey)
		if fieldKey == nil or fieldsByKey[fieldKey] or warned[fieldKey] then
			return
		end
		warned[fieldKey] = true
		logger.warn(
			"Change detector: unknown display field '"
				.. tostring(fieldKey)
				.. "' for entry '"
				.. tostring(entryName)
				.. "'"
		)
	end

	if overrides.detail then
		for _, fieldKey in ipairs(overrides.detail) do
			warnUnknownField(fieldKey)
		end
	end

	local summaryGroupIds = {}
	if overrides.summaryGroups then
		for _, groupSpec in ipairs(overrides.summaryGroups) do
			if groupSpec.group then
				summaryGroupIds[groupSpec.group] = true
			end

			if groupSpec.field and fieldsByKey[groupSpec.field] then
				local collisionKey = "collision:" .. groupSpec.field
				if not warned[collisionKey] then
					warned[collisionKey] = true
					logger.warn(
						"Change detector: summaryGroups field '"
							.. tostring(groupSpec.field)
							.. "' collides with tracked field on entry '"
							.. tostring(entryName)
							.. "'"
					)
				end
			end
		end
	end

	if overrides.summary then
		for _, summarySpec in ipairs(overrides.summary) do
			warnUnknownField(summarySpec.field)

			if summarySpec.group and not summaryGroupIds[summarySpec.group] then
				local orphanKey = "orphanGroup:" .. summarySpec.group
				if not warned[orphanKey] then
					warned[orphanKey] = true
					logger.warn(
						"Change detector: summary field references group '"
							.. tostring(summarySpec.group)
							.. "' with no summaryGroups entry for '"
							.. tostring(entryName)
							.. "'"
					)
				end
			end
		end
	end
end

--- Merge runtime display overrides onto the base tracked fields
-- Tracking always uses baseFields. Display/layout uses the merged result.
-- @param baseFields table canonical tracked field definitions
-- @param overrides table|nil override spec with detail, summary, and summaryGroups arrays
-- @return table field definitions used for columns and summary rollups
function changedetector._applyDisplayOverrides(baseFields, overrides)
	local displayFields = changedetector._copyFields(baseFields)
	if not overrides then
		return displayFields
	end

	local fieldsByKey = {}
	for _, field in ipairs(displayFields) do
		fieldsByKey[field.key] = field
	end

	if overrides.detail then
		for _, fieldKey in ipairs(overrides.detail) do
			local field = fieldsByKey[fieldKey]
			if field then
				field.changeDisplay = "detail"
			end
		end
	end

	if overrides.summary then
		for _, summarySpec in ipairs(overrides.summary) do
			local field = fieldsByKey[summarySpec.field]
			if field then
				field.changeDisplay = "summary"
				field.summaryGroup = summarySpec.group
				field.summaryLabel = summarySpec.label or summarySpec.field
			end
		end
	end

	if overrides.summaryGroups then
		for _, groupSpec in ipairs(overrides.summaryGroups) do
			table.insert(displayFields, {
				key = groupSpec.field,
				header = groupSpec.header or groupSpec.field,
				align = groupSpec.align or "left",
				changeDisplay = "summaryGroup",
				summaryGroup = groupSpec.group,
				read = function()
					return nil
				end,
			})
		end
	end

	return displayFields
end

--- Rebuild display columns from baseFields plus the current override stack top
-- @param entry table monitored entry definition
function changedetector._rebuildEntryDisplay(entry)
	local overrides = nil
	local stack = displaySettingsStack[entry.entryName]
	if stack and #stack > 0 then
		overrides = stack[#stack]
	end

	entry.displayFields = changedetector._applyDisplayOverrides(entry.baseFields, overrides)
	entry.columns = tablelayout._buildChangeColumns({
		primaryKey = entry.primaryKey,
		description = entry.description,
		fields = entry.displayFields,
	})
end

--- Push temporary display overrides for one monitored entry
-- Use popDisplaySettings to restore the previous layout. Typical flow for module scripts is
-- to push at the start of execute, let the module postscript detect/format, then pop there.
-- @param entryName string monitored entry name
-- @param overrides table override spec passed to _applyDisplayOverrides
-- @return boolean true when overrides were pushed
function changedetector.pushDisplaySettings(entryName, overrides)
	local entry = monitoredEntries[entryName]
	if not entry then
		logger.warn("Change detector: no monitored entry '" .. tostring(entryName) .. "' to push display settings onto")
		return false
	end

	if not displaySettingsStack[entryName] then
		displaySettingsStack[entryName] = {}
	end

	changedetector._validateDisplayOverrides(entryName, entry.baseFields, overrides)
	table.insert(displaySettingsStack[entryName], overrides or {})
	changedetector._rebuildEntryDisplay(entry)
	return true
end

--- Pop the most recent display override stack entry and restore layout
-- @param entryName string monitored entry name
-- @return boolean true when an override was popped
function changedetector.popDisplaySettings(entryName)
	local entry = monitoredEntries[entryName]
	local stack = displaySettingsStack[entryName]
	if not entry or not stack or #stack == 0 then
		return false
	end

	table.remove(stack)
	changedetector._rebuildEntryDisplay(entry)
	return true
end

--- Return a copy of the current display override for one entry, if any
-- @param entryName string monitored entry name
-- @return table or nil active override spec
function changedetector.getDisplaySettings(entryName)
	local stack = displaySettingsStack[entryName]
	if not stack or #stack == 0 then
		return nil
	end
	return changedetector._copyDisplayOverrides(stack[#stack])
end

--- Run a function with temporary display overrides, restoring afterward
-- Useful when detect/format happen in the same script. Module postscript flows should
-- use pushDisplaySettings/popDisplaySettings instead.
-- @param entryName string monitored entry name
-- @param overrides table override spec passed to _applyDisplayOverrides
-- @param fn function callback to run while overrides are active
-- @return any return value from fn
function changedetector.withDisplaySettings(entryName, overrides, fn)
	changedetector.pushDisplaySettings(entryName, overrides)
	local ok, result = pcall(fn)
	changedetector.popDisplaySettings(entryName)
	if not ok then
		error(result)
	end
	return result
end

--- Add a monitoring entry of objects
-- @param entryName string name for this entry for tracking/logging
-- @param objects array of objects to monitor
-- @param config table monitor config:
--   title (optional) table title shown in formatted output
--   headerEvery (optional) repeat column headers every N data rows
--   trailingHeader (optional) repeat column headers after the final data row
--   primaryKey table { header, align, numeric, field or getter } sort/display key
--   description (optional) table { header, align, field or getter } display-only column
--   fields array of { field or getter, header, align } tracked values
function changedetector.monitor(entryName, objects, config)
	if not entryName or not objects or not config then
		logger.warn("Change detector: monitor requires entryName, objects, and config")
		return
	end

	if #objects == 0 then
		logger.warn("Change detector: no objects provided for '" .. entryName .. "'")
		return
	end

	local entry, configError = changedetector._normalizeMonitorConfig(config)
	if not entry then
		logger.warn(
			"Change detector: invalid monitor config for '"
				.. entryName
				.. "': "
				.. (configError or "unknown error")
		)
		return
	end

	-- store data for the entry
	entry.entryName = entryName
	entry.objects = objects
	entry.snapshot = nil -- Will be set when takeSnapshots is called
	entry.baseFields = changedetector._copyFields(entry.fields)
	displaySettingsStack[entryName] = {}
	changedetector._rebuildEntryDisplay(entry)
	monitoredEntries[entryName] = entry
end

--- Add fields to an existing monitor entry when those field keys are not already present
-- Rebuilds change columns. Newly added fields are treated as nil in any existing
-- snapshot so the next detectChanges can report nil -> value assignments.
-- If a key already exists, it will be skipped. Returned count can be used to see if any
-- keys were skipped if needed
-- @param entryName string name of an existing monitor entry
-- @param fieldSpecs array of field specs (same shape as monitor config fields)
-- @return number count of fields actually added
function changedetector.addFields(entryName, fieldSpecs)
	if not entryName or type(fieldSpecs) ~= "table" then
		logger.warn("Change detector: addFields requires entryName and fieldSpecs")
		return 0
	end

	local entry = monitoredEntries[entryName]
	if not entry then
		logger.warn("Change detector: no monitored entry '" .. tostring(entryName) .. "' to add fields to")
		return 0
	end

	local existingKeys = {}
	for _, field in ipairs(entry.baseFields) do
		existingKeys[field.key] = true
	end

	local addedCount = 0
	for index, fieldSpec in ipairs(fieldSpecs) do
		local field, fieldError = tablelayout._normalizeFieldSpec(fieldSpec)
		if not field or not field.key then
			logger.warn(
				"Change detector: invalid field at index "
					.. index
					.. " for '"
					.. entryName
					.. "': "
					.. (fieldError or "field requires field or name key")
			)
			-- If the key already exists, just skip it silently instead of erroring
			-- There are cases where multiple may try to add the key in an expected way
			-- If they want to make sure the key is added, they can check the returned
			-- count
		elseif not existingKeys[field.key] then
			table.insert(entry.baseFields, field)
			existingKeys[field.key] = true
			addedCount = addedCount + 1
		end
	end

	if addedCount == 0 then
		return 0
	end

	changedetector._rebuildEntryDisplay(entry)
	return addedCount
end

--- Stop monitoring a specific entry
-- @param entryName string name of the entry to stop monitoring
function changedetector.stopMonitoring(entryName)
	displaySettingsStack[entryName] = nil
	monitoredEntries[entryName] = nil
end

--- Stop monitoring all entries
function changedetector.stopMonitoringAll()
	monitoredEntries = {}
	displaySettingsStack = {}
end

--- Deep copy captured field values for snapshot storage
-- snapshots need their own copies so later in place table edits still show up as changes
-- @param state table captured field state
-- @return table frozen snapshot state
function changedetector._freezeSnapshotState(state)
	local frozen = {}
	for key, value in pairs(state) do
		frozen[key] = utils.deepCopy(value)
	end
	return frozen
end

--- Take a new snapshot of all configured monitoring entries
function changedetector.takeSnapshots()
	if not changedetector.isActive() then
		return
	end

	for _, entry in pairs(monitoredEntries) do
		local newSnapshot = {}

		for _, rowData in ipairs(tablelayout._sortedRows(entry.objects, entry)) do
			table.insert(newSnapshot, {
				object = rowData.object,
				rowKey = tostring(rowData.primarySort),
				primary = rowData.primary,
				primarySort = rowData.primarySort,
				description = rowData.description,
				state = changedetector._freezeSnapshotState(
					tablelayout._captureFieldState(rowData.object, entry.baseFields)
				),
			})
		end

		-- save the new snapshot
		entry.snapshot = newSnapshot
	end
end

--- Deep compare two values
-- @param v1 first value
-- @param v2 second value
-- @return true if values are equal
function changedetector._deepCompare(v1, v2)
	return utils.deepEqual(v1, v2)
end

--- Whether two captured field values should count as a change
-- handles nil -> value and value -> nil as changes.
-- @param oldValue any snapshot value (nil when absent)
-- @param newValue any current value (nil when absent)
-- @return boolean
function changedetector._valuesDiffer(oldValue, newValue)
	if oldValue == nil and newValue == nil then
		return false
	end
	if oldValue == nil or newValue == nil then
		return true
	end
	return not changedetector._deepCompare(oldValue, newValue)
end

--- Fill summaryGroup columns from tracked summary fields on one change row
-- @param rowData table per object change data being built
-- @param fields table normalized field definitions for the entry
function changedetector._applySummaryGroups(rowData, fields)
	for _, field in ipairs(fields) do
		if field.changeDisplay ~= "summaryGroup" then
			goto continue
		end

		local changedLabels = {}
		for _, summaryField in ipairs(fields) do
			if summaryField.changeDisplay == "summary" and summaryField.summaryGroup == field.summaryGroup then
				local change = rowData[summaryField.key]
				if change and change.new ~= "-" then
					table.insert(changedLabels, summaryField.summaryLabel)
				end
			end
		end

		if #changedLabels > 0 then
			rowData[field.key] = {
				old = "-",
				new = table.concat(changedLabels, ", "),
			}
		else
			rowData[field.key] = {
				old = "-",
				new = "-",
			}
		end

		::continue::
	end
end

--- Detect changes since last snapshot for all monitoring entries
-- When any row in an entry changes, all rows for that entry are included in the result.
-- Changed fields use old/new values; unchanged fields use current value in From and "-" in To.
-- @return table mapping entry names to object changes with attached _format metadata
function changedetector.detectChanges()
	local allChanges = {}

	for entryName, entry in pairs(monitoredEntries) do
		if not entry.snapshot then
			-- Lua doesn't have continue... use goto instead
			goto continue
		end

		local entryChanges = {}
		local anyChanged = false

		for _, snapshot in ipairs(entry.snapshot) do
			local currentState = tablelayout._captureFieldState(snapshot.object, entry.baseFields)
			local rowData = {
				_primary = snapshot.primary,
				_primarySort = snapshot.primarySort,
				_description = snapshot.description,
			}

			for _, field in ipairs(entry.baseFields) do
				local oldValue = snapshot.state[field.key]
				local newValue = currentState[field.key]

				if changedetector._valuesDiffer(oldValue, newValue) then
					anyChanged = true
					rowData[field.key] = {
						old = tablelayout._valueToString(oldValue),
						new = tablelayout._valueToString(newValue),
					}
				else
					rowData[field.key] = {
						old = tablelayout._valueToString(newValue),
						new = "-",
					}
				end
			end

			changedetector._applySummaryGroups(rowData, entry.displayFields)

			entryChanges[snapshot.rowKey] = rowData
		end

		-- Only add entry if it has changes
		if anyChanged then
			entryChanges._format = {
				columns = entry.columns,
				title = entry.title or entryName,
				headerEvery = entry.headerEvery,
				trailingHeader = entry.trailingHeader,
				primaryNumeric = entry.primaryKey.numeric,
			}
			allChanges[entryName] = entryChanges
		end

		::continue::
	end

	return allChanges
end

--- Check if there are any changes in the changes table
-- @param changes table of changes from detectChanges()
-- @return boolean true if there are changes
function changedetector.hasChanges(changes)
	if not changes then
		return false
	end

	for entryName, entryChanges in pairs(changes) do
		if entryName ~= "_format" then
			for rowKey in pairs(entryChanges) do
				if not changedetector._isReservedRowKey(rowKey) then
					return true
				end
			end
		end
	end

	return false
end

--- Check if change detection is active
-- @return boolean
function changedetector.isActive()
	return isChangeDetectionActive
end

--- Get list of monitored entry names
-- @return table of entry names
function changedetector.getMonitoredEntryNames()
	local names = {}
	for name in pairs(monitoredEntries) do
		table.insert(names, name)
	end
	return names
end

--- Build the ordered cell values for one change row
-- @param rowChanges table per-object change data from detectChanges()
-- @param columns table column definitions from monitor setup
-- @return table cell values in column order
function changedetector._buildRowValues(rowChanges, columns)
	local values = {}

	for _, column in ipairs(columns) do
		if column.role == "primary" then
			table.insert(values, rowChanges._primary or "")
		elseif column.role == "description" then
			table.insert(values, rowChanges._description or "")
		elseif column.role == "from" then
			local change = rowChanges[column.fieldKey]
			table.insert(values, change and change.old or "")
		elseif column.role == "to" then
			local change = rowChanges[column.fieldKey]
			table.insert(values, change and change.new or "")
		elseif column.role == "summary" then
			local change = rowChanges[column.fieldKey]
			table.insert(values, change and change.new or "")
		end
	end

	return values
end

--- Whether any row has a real change for the given field key
-- unchanged fields are stored with new = "-"
-- @param entryChanges table per-entry change data from detectChanges()
-- @param fieldKey string field key to check
-- @return boolean
function changedetector._fieldHasChanges(entryChanges, fieldKey)
	for rowKey, rowChanges in pairs(entryChanges) do
		if not changedetector._isReservedRowKey(rowKey) then
			local change = rowChanges[fieldKey]
			if change and change.new ~= "-" then
				return true
			end
		end
	end
	return false
end

--- Keep identity columns plus From/To pairs only for fields that changed
-- @param entryChanges table per-entry change data from detectChanges()
-- @param columns table full column definitions from monitor setup
-- @return table filtered column definitions
function changedetector._columnsWithChanges(entryChanges, columns)
	local filtered = {}
	local changedFields = {}

	for _, column in ipairs(columns) do
		if column.role == "from" or column.role == "to" then
			if changedFields[column.fieldKey] == nil then
				changedFields[column.fieldKey] =
					changedetector._fieldHasChanges(entryChanges, column.fieldKey)
			end
			if changedFields[column.fieldKey] then
				table.insert(filtered, column)
			end
		elseif column.role == "summary" then
			if changedFields[column.fieldKey] == nil then
				changedFields[column.fieldKey] =
					changedetector._fieldHasChanges(entryChanges, column.fieldKey)
			end
			if changedFields[column.fieldKey] then
				table.insert(filtered, column)
			end
		else
			table.insert(filtered, column)
		end
	end

	return filtered
end

--- Return row keys sorted by the configured primary key
-- @param entryChanges table per-entry change data from detectChanges()
-- @param primaryNumeric boolean whether the primary key sorts numerically
-- @return table sorted row keys
function changedetector._sortedRowKeys(entryChanges, primaryNumeric)
	local rowKeys = {}
	for rowKey in pairs(entryChanges) do
		if not changedetector._isReservedRowKey(rowKey) then
			table.insert(rowKeys, rowKey)
		end
	end

	table.sort(rowKeys, function(leftKey, rightKey)
		local leftSort = entryChanges[leftKey]._primarySort
		local rightSort = entryChanges[rightKey]._primarySort

		if primaryNumeric then
			return (tonumber(leftSort) or 0) < (tonumber(rightSort) or 0)
		end

		return tostring(leftSort) < tostring(rightSort)
	end)

	return rowKeys
end

--- Format detected changes as ASCII tables
-- Layout is defined at monitor setup time and stored in each entry's _format metadata.
-- Only From/To columns for fields that actually changed are included.
-- @param changes table result from detectChanges()
-- @param options table|nil optional formatting options:
--   title string full title row text
--   moduleName string used to build "{moduleName} changes" when title is omitted
--   leadingNewline boolean prepend a newline before the formatted output
-- @return string formatted tables, or empty string when there are no changes
function changedetector.formatChangesTable(changes, options)
	if not changedetector.hasChanges(changes) then
		return ""
	end

	options = options or {}
	local outputLines = {}

	for _, entryChanges in pairs(changes) do
		if entryChanges._format then
			local formatConfig = entryChanges._format
			local columns = changedetector._columnsWithChanges(entryChanges, formatConfig.columns)
			local rowKeys = changedetector._sortedRowKeys(entryChanges, formatConfig.primaryNumeric)
			local rows = {}

			for _, rowKey in ipairs(rowKeys) do
				table.insert(rows, changedetector._buildRowValues(entryChanges[rowKey], columns))
			end

			local title = asciitable.resolveTitle(options, formatConfig.title .. " changes")

			table.insert(outputLines, asciitable.render({
				title = title,
				columns = columns,
				rows = rows,
				headerEvery = formatConfig.headerEvery,
				trailingHeader = formatConfig.trailingHeader,
			}))
			table.insert(outputLines, "")
		end
	end

	return asciitable.applyOutputOptions(table.concat(outputLines, "\n"), options)
end

return changedetector
