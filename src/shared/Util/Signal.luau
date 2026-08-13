--!strict
--[[
	SIGNAL — minimal event object.

	Pure Lua, not a BindableEvent. BindableEvents serialize their arguments across
	a boundary, which means tables get copied and Instance identity is preserved
	but table identity is not. Services pass tables around constantly, so a copy
	would be a subtle and very annoying class of bug.

		local sig = Signal.new()
		local conn = sig:Connect(function(a, b) end)
		sig:Fire(1, 2)
		conn:Disconnect()

	Handlers are called in connection order. A handler that throws is caught and
	warned about — one bad listener must not stop the others from being called,
	because the caller of Fire() usually has no relationship to the listeners.
]]

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

export type Signal = {
	Connect: (self: Signal, fn: (...any) -> ()) -> Connection,
	Once: (self: Signal, fn: (...any) -> ()) -> Connection,
	Fire: (self: Signal, ...any) -> (),
	DisconnectAll: (self: Signal) -> (),
	Destroy: (self: Signal) -> (),
}

local Connection = {}
Connection.__index = Connection

function Connection:Disconnect()
	if not self.Connected then
		return
	end
	self.Connected = false
	local handlers = self._signal._handlers
	local index = table.find(handlers, self)
	if index then
		table.remove(handlers, index)
	end
end

local Signal = {}
Signal.__index = Signal

function Signal.new(): Signal
	return (setmetatable({ _handlers = {} }, Signal) :: any) :: Signal
end

function Signal:Connect(fn: (...any) -> ()): Connection
	local conn = setmetatable({ Connected = true, _fn = fn, _signal = self }, Connection)
	table.insert(self._handlers, conn)
	return (conn :: any) :: Connection
end

function Signal:Once(fn: (...any) -> ()): Connection
	local conn
	conn = self:Connect(function(...)
		conn:Disconnect()
		fn(...)
	end)
	return conn
end

function Signal:Fire(...)
	-- Iterate a copy: a handler may disconnect itself (or others) mid-fire, and
	-- mutating the list we're walking would silently skip the next handler.
	local snapshot = table.clone(self._handlers)
	for _, conn in ipairs(snapshot) do
		if conn.Connected then
			local ok, err = pcall(conn._fn, ...)
			if not ok then
				warn(`[Signal] handler errored: {err}`)
			end
		end
	end
end

function Signal:DisconnectAll()
	for _, conn in ipairs(table.clone(self._handlers)) do
		conn.Connected = false
	end
	table.clear(self._handlers)
end

function Signal:Destroy()
	self:DisconnectAll()
end

return Signal
