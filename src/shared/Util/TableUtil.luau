--!strict
--[[
	TABLEUTIL — the three table operations this project actually needs.

	Reconcile is the one that matters most: DataService (A1) runs it against the
	profile template on every load, so a field added to the schema appears on an
	existing player's profile instead of being nil and crashing something three
	systems away.

	Diff feeds StateService (A2) — it sends only what changed, so 20 mutations in
	one frame become one small packet instead of the whole state.
]]

local TableUtil = {}

-- Recursive copy. Keys are not copied (they're immutable in practice here);
-- values that are tables are copied all the way down.
function TableUtil.DeepCopy<T>(source: T): T
	if type(source) ~= "table" then
		return source
	end
	local out = {}
	for key, value in pairs(source :: any) do
		out[key] = if type(value) == "table" then TableUtil.DeepCopy(value) else value
	end
	return (out :: any) :: T
end

--[[
	Fill in anything `template` has that `data` lacks, recursively.

	Existing values are never overwritten — that is the whole point. A returning
	player keeps their cash; they merely gain the fields that didn't exist when
	they last played.

	Returns a new table; `data` is not mutated.
]]
function TableUtil.Reconcile<T>(data: { [any]: any }?, template: T): T
	local out = TableUtil.DeepCopy(template) :: any

	if type(data) == "table" then
		for key, value in pairs(data) do
			local templateValue = (template :: any)[key]

			if templateValue == nil then
				-- Not in the template: a field from an older schema version, or
				-- a dynamic key like companions[id]. Keep it — dropping player
				-- data because the template doesn't enumerate it is destructive.
				out[key] = TableUtil.DeepCopy(value)
			elseif type(value) == "table" and type(templateValue) == "table" then
				out[key] = TableUtil.Reconcile(value, templateValue)
			else
				out[key] = value
			end
		end
	end

	return (out :: any) :: T
end

--[[
	Keys whose values differ between `old` and `new`.

	Removed keys are reported with the sentinel `TableUtil.None`, because a plain
	nil cannot be stored in a Lua table and would silently vanish from the diff —
	the client would then never learn the key was cleared.

	Shallow by design: StateService replicates whole sub-tables (`pack`,
	`upgrades`) rather than trying to patch inside them.
]]
TableUtil.None = newproxy(false)

local function shallowEqual(a: any, b: any): boolean
	if a == b then
		return true
	end
	if type(a) ~= "table" or type(b) ~= "table" then
		return false
	end
	for key, value in pairs(a) do
		if b[key] ~= value then
			return false
		end
	end
	for key in pairs(b) do
		if a[key] == nil then
			return false
		end
	end
	return true
end

function TableUtil.Diff(old: { [any]: any }, new: { [any]: any }): { [any]: any }
	local out = {}

	for key, value in pairs(new) do
		if not shallowEqual(old[key], value) then
			out[key] = value
		end
	end

	for key in pairs(old) do
		if new[key] == nil then
			out[key] = TableUtil.None
		end
	end

	return out
end

function TableUtil.IsEmpty(t: { [any]: any }): boolean
	return next(t) == nil
end

function TableUtil.Count(t: { [any]: any }): number
	local n = 0
	for _ in pairs(t) do
		n += 1
	end
	return n
end

return TableUtil
