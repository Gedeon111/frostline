--!strict
--[[
	NET (client) — the only place the client touches a remote.

		Net.Fire("RequestSell")
		local ok, reason = Net.Invoke("RequestPurchase", "pack", 4)
		Net.On("Notify", function(kind, text, amount) ... end)

	No controller calls :FireServer() directly. One wrapper means one place to
	add logging, one place a timeout is enforced, and one place to look when a
	request goes missing.

	Remember what the client is: it sends INTENT, never OUTCOME (ARCHITECTURE
	§3). Everything here can be dropped or rejected by the server, so never
	assume a request succeeded — wait for StateChanged, or use Invoke and read
	the result.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Log = require(Shared.Util.Log)

local INVOKE_TIMEOUT = 10

local Net = {}

-- The server creates these at require time, but the client can load first, so
-- wait rather than assume. Blocking here is correct: nothing the client does is
-- meaningful before the remotes exist.
local folder = ReplicatedStorage:WaitForChild(Remotes.FolderName)

local function get(name: string): Instance
	local remote = folder:FindFirstChild(name)
	if not remote then
		-- WaitForChild with a timeout rather than forever: a typo'd name would
		-- otherwise hang the calling controller with no error, which is a
		-- genuinely horrible thing to debug.
		remote = folder:WaitForChild(name, 5)
	end
	if not remote then
		error(`[Net] remote '{name}' never appeared — is it in Shared.Remotes?`, 3)
	end
	return remote
end

function Net.Fire(name: string, ...)
	local remote = get(name)
	if not remote:IsA("RemoteEvent") then
		error(`[Net] '{name}' is a {remote.ClassName}; use Net.Invoke`, 2)
	end
	remote:FireServer(...)
end

--[[
	Calls a RemoteFunction and waits for the answer.

	Returns (false, "not_loaded") if the server doesn't reply within
	INVOKE_TIMEOUT. A raw InvokeServer yields forever if the server never
	returns — a disabled handler, an error before the return, a shutdown
	mid-call — and a UI button waiting forever looks like the game froze.

	The shape matches every RemoteFunction in Shared.Remotes: (ok, reason?).
]]
function Net.Invoke(name: string, ...): ...any
	local remote = get(name)
	if not remote:IsA("RemoteFunction") then
		error(`[Net] '{name}' is a {remote.ClassName}; use Net.Fire`, 2)
	end

	local fn = remote :: RemoteFunction
	local args = table.pack(...)
	local thread = coroutine.running()
	local resumed = false

	local function finish(...)
		if resumed then
			return
		end
		resumed = true
		task.spawn(thread, ...)
	end

	task.spawn(function()
		local results = table.pack(pcall(fn.InvokeServer, fn, table.unpack(args, 1, args.n)))
		if results[1] then
			finish(table.unpack(results, 2, results.n))
		else
			Log.warn("Net", "%s failed: %s", name, tostring(results[2]))
			finish(false, "not_loaded")
		end
	end)

	task.delay(INVOKE_TIMEOUT, function()
		if not resumed then
			Log.warn("Net", "%s timed out after %ds", name, INVOKE_TIMEOUT)
			finish(false, "not_loaded")
		end
	end)

	return coroutine.yield()
end

function Net.On(name: string, handler: (...any) -> ())
	local remote = get(name)
	if not remote:IsA("RemoteEvent") then
		error(`[Net] cannot listen on a {remote.ClassName}`, 2)
	end
	remote.OnClientEvent:Connect(function(...)
		-- A throwing handler must not break the connection for every later
		-- message on this remote.
		local ok, err = pcall(handler, ...)
		if not ok then
			Log.error("Net", "%s handler errored: %s", name, tostring(err))
		end
	end)
end

function Net.Init() end
function Net.Start() end

return Net
