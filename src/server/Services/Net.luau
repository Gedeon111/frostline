--!strict
--[[
	NET (server) — the only thing that creates or touches remotes.

	Creates every remote in Shared.Remotes under ReplicatedStorage.Remotes, and
	wraps every inbound handler in a rate limiter and a pcall. Services register
	handlers through Net.On and never see a RemoteEvent.

		Net.On("RequestSell", function(player) ... end)
		Net.Fire(player, "Notify", "cash", "Sold!", 1240)
		Net.FireNear(position, radius, "CombatFeedback", creature, dmg, killed)

	WHY REMOTES ARE CREATED AT MODULE SCOPE, NOT IN Init()

	The bootstrap requires every service, then calls Init() on all of them. The
	order within a phase is whatever GetChildren() returns — arbitrary. If Net
	built its remotes in Init(), a service whose Init() ran first and called
	Net.On would find nothing there.

	A module body runs on first require, which is strictly before any Init().
	So building here makes "remotes exist" true for every service, in every
	order, without a dependency declaration. See ARCHITECTURE §3.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local GameConfig = require(Shared.Config.GameConfig)
local RateLimiter = require(Shared.Util.RateLimiter)
local Log = require(Shared.Util.Log)

local Net = {}

-- ── Build the remote objects (runs at require time, see header) ─────────────

local folder = ReplicatedStorage:FindFirstChild(Remotes.FolderName)
if not folder then
	folder = Instance.new("Folder")
	folder.Name = Remotes.FolderName
	folder.Parent = ReplicatedStorage
end

local instances: { [string]: Instance } = {}

for name, className in pairs(Remotes.All()) do
	local existing = folder:FindFirstChild(name)
	if existing and existing.ClassName ~= className then
		-- Rojo may have synced a stale one, or a previous run left the wrong
		-- class. Replace rather than limp along with a RemoteEvent where the
		-- code expects a RemoteFunction.
		Log.warn("Net", "replacing %s: was %s, want %s", name, existing.ClassName, className)
		existing:Destroy()
		existing = nil
	end
	if not existing then
		existing = Instance.new(className)
		existing.Name = name
		existing.Parent = folder
	end
	instances[name] = existing
end

-- ── Inbound ─────────────────────────────────────────────────────────────────

local function limitFor(name: string)
	local limits: any = GameConfig.RateLimits
	return limits[name] or limits._default
end

--[[
	Registers the one handler for an inbound remote.

	Everything a service would otherwise have to remember is applied here:
	rate limiting (budget from GameConfig, never written per-service, per
	WORKFLOW §5) and a pcall so a thrown handler cannot kill the remote or
	take down the server.

	Over-budget calls are dropped silently for events, and answered with
	(false, "rate_limited") for functions — the client gets a typed reason it
	can render, rather than a hang.
]]
function Net.On(name: string, handler: (Player, ...any) -> ...any)
	local remote = instances[name]
	if not remote then
		error(`[Net] unknown remote '{name}' — add it to Shared.Remotes first`, 2)
	end
	if not Remotes.IsInbound(name) then
		error(`[Net] '{name}' is server→client; use Net.Fire, not Net.On`, 2)
	end

	local limit = limitFor(name)

	if remote:IsA("RemoteEvent") then
		remote.OnServerEvent:Connect(function(player, ...)
			if not RateLimiter.Check(`{player.UserId}:{name}`, limit.budget, limit.perSeconds) then
				Log.info("Net", "rate limited %s from %s", name, player.Name)
				return
			end
			local ok, err = pcall(handler, player, ...)
			if not ok then
				Log.error("Net", "%s handler errored: %s", name, tostring(err))
			end
		end)
	else
		local fn = remote :: RemoteFunction
		fn.OnServerInvoke = function(player, ...)
			if not RateLimiter.Check(`{player.UserId}:{name}`, limit.budget, limit.perSeconds) then
				Log.info("Net", "rate limited %s from %s", name, player.Name)
				return false, "rate_limited"
			end
			local results = table.pack(pcall(handler, player, ...))
			if not results[1] then
				Log.error("Net", "%s handler errored: %s", name, tostring(results[2]))
				-- Never leak an internal error string to the client.
				return false, "not_loaded"
			end
			return table.unpack(results, 2, results.n)
		end
	end
end

-- ── Outbound ────────────────────────────────────────────────────────────────

local function outbound(name: string, caller: string): RemoteEvent
	local remote = instances[name]
	if not remote then
		error(`[Net] unknown remote '{name}'`, 3)
	end
	if not remote:IsA("RemoteEvent") then
		error(`[Net] {caller} needs a RemoteEvent; '{name}' is a {remote.ClassName}`, 3)
	end
	return remote
end

function Net.Fire(player: Player, name: string, ...)
	outbound(name, "Net.Fire"):FireClient(player, ...)
end

function Net.FireAll(name: string, ...)
	outbound(name, "Net.FireAll"):FireAllClients(...)
end

function Net.FireExcept(except: Player, name: string, ...)
	local remote = outbound(name, "Net.FireExcept")
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= except then
			remote:FireClient(player, ...)
		end
	end
end

--[[
	Fires only to players within `radius` of `position`.

	CombatFeedback at 100 hits/minute × 20 players broadcast server-wide is a
	lot of traffic for VFX nobody can see. ARCHITECTURE §3 requires this be
	scoped; GameConfig.FeedbackRadius is the value.
]]
function Net.FireNear(position: Vector3, radius: number, name: string, ...)
	local remote = outbound(name, "Net.FireNear")
	local radiusSq = radius * radius
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			local offset = (root :: BasePart).Position - position
			-- Compare squared distances; a square root per player per hit is
			-- pure waste when only the comparison matters.
			if offset:Dot(offset) <= radiusSq then
				remote:FireClient(player, ...)
			end
		end
	end
end

-- ── Lifecycle ───────────────────────────────────────────────────────────────

function Net.Init() end

function Net.Start()
	-- Buckets are keyed by UserId and would otherwise accumulate for the life
	-- of the server. A busy server churns hundreds of players.
	Players.PlayerRemoving:Connect(function(player)
		RateLimiter.ForgetPrefix(`{player.UserId}:`)
	end)

	local n = 0
	for _ in pairs(instances) do
		n += 1
	end
	Log.info("Net", "%d remotes ready", n)
end

-- Test/diagnostic surface.
function Net.GetRemote(name: string): Instance?
	return instances[name]
end

return Net
