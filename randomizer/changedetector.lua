--- Change detection module for tracking object modifications
-- Supports multiple entries to track with their own associated parameters
-- Snapshots and comparisons must be called manually when desired
-- @module randomizer.changedetector

local asciitable = require("randomizer.asciitable")
local tablelayout = require("randomizer.tablelayout")

local changedetector = {}

-- Monitored data keyed by entry name
local monitoredEntries = {}
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

	entry.columns = tablelayout._buildChangeColumns(entry)
	return entry, nil
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
		print("Warning: Change detector: monitor requires entryName, objects, and config")
		return
	end

	if #objects == 0 then
		print("Warning: Change detector: no objects provided for '" .. entryName .. "'")
		return
	end

	local entry, configError = changedetector._normalizeMonitorConfig(config)
	if not entry then
		print(
			"Warning: Change detector: invalid monitor config for '"
				.. entryName
				.. "': "
				.. (configError or "unknown error")
		)
		return
	end

	-- store data for the entry
	entry.objects = objects
	entry.snapshot = nil -- Will be set when takeSnapshots is called
	monitoredEntries[entryName] = entry
end

--- Stop monitoring a specific entry
-- @param entryName string name of the entry to stop monitoring
function changedetector.stopMonitoring(entryName)
	monitoredEntries[entryName] = nil
end

--- Stop monitoring all entries
function changedetector.stopMonitoringAll()
	monitoredEntries = {}
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
				state = tablelayout._captureFieldState(rowData.object, entry.fields),
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
	if type(v1) ~= type(v2) then
		return false
	end

	if type(v1) ~= "table" and type(v1) ~= "userdata" then
		return v1 == v2
	end

	-- For userdata and tables, use tostring comparison
	-- TODO: for a true deep compare it should probably recurse
	return tostring(v1) == tostring(v2)
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
			local currentState = tablelayout._captureFieldState(snapshot.object, entry.fields)
			local rowData = {
				_primary = snapshot.primary,
				_primarySort = snapshot.primarySort,
				_description = snapshot.description,
			}

			for _, field in ipairs(entry.fields) do
				local oldValue = snapshot.state[field.key]
				local newValue = currentState[field.key]

				if oldValue ~= nil and not changedetector._deepCompare(oldValue, newValue) then
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
		end
	end

	return values
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
			local columns = formatConfig.columns
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
