--!strict
--[[
	COMBATSERVICE — turns a swing request into damage, or rejects it.

	This is the single most attacked surface in the game. `RequestSwing` is the
	remote that produces money, so it is the one an exploiter automates first:
	fire it a thousand times a second, fire it at a creature across the map,
	fire it at a creature in a zone they never paid to unlock.

	Every check below exists because of one of those. The client sends only
	"I swung at this creature" — it never sends damage, never sends a position,
	never says whether it killed anything (ARCHITECTURE §3).

	Checks run cheapest-first: a rejected request should cost as close to
	nothing as possible, because rejected requests are exactly what arrives in
	volume during an attack.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Log = require(Shared.Util.Log)

local Net = require(ServerScriptService.Services.Net)
local DataService = require(ServerScriptService.Services.DataService)
local CreatureService = require(ServerScriptService.Services.CreatureService)
local UpgradeService = require(ServerScriptService.Services.UpgradeService)

local CombatService = {}

--[[
	Last swing time per player, measured with the SERVER clock.

	Never derived from anything the client sends. A client-supplied timestamp is
	just a number an exploiter picks, and the cooldown becomes decorative.
]]
local lastSwing: { [Player]: number } = {}

-- Rejections are counted rather than logged per event. Under an attack, one log
-- line per rejected swing floods the console and hides everything else. A12
-- reads these counts for escalation; Net only drops, it does not judge.
local rejections: { [string]: number } = {}

local function reject(player: Player, reason: string)
	rejections[reason] = (rejections[reason] or 0) + 1
	Log.once(`swing_{player.UserId}_{reason}`, "Combat", "%s rejected: %s (first of possibly many)", player.Name, reason)
end

function CombatService.GetRejectionCounts(): { [string]: number }
	return table.clone(rejections)
end

--[[
	Damage for this player's current AXE level (D-017 renamed the track).

	Goes through UpgradeService rather than reading `data.upgrades` directly, so
	the level lookup and the unloaded-profile guard stay in one place. ECONOMY
	§3 owns the curve; a literal here would diverge from the doc the moment
	anyone tunes it.
]]
local function damageFor(player: Player): number
	return UpgradeService.GetValue(player, "axe") or 0
end

local function onSwing(player: Player, creature: any)
	-- 1. Cooldown. Cheapest possible check, and the one an auto-clicker trips.
	--    Net's rate limiter already throttles the remote; this enforces the
	--    actual game rule, which is stricter and config-driven.
	local now = os.clock()
	local last = lastSwing[player]
	if last and (now - last) < GameConfig.SwingCooldown then
		return reject(player, "cooldown")
	end

	-- 2. Argument sanity. An exploiter can pass ANY Instance here, or a number,
	--    or nil. Verify it is a Model that we ourselves spawned before touching
	--    anything on it.
	if typeof(creature) ~= "Instance" or not creature:IsA("Model") then
		return reject(player, "bad_argument")
	end
	if not creature:IsDescendantOf(workspace) then
		return reject(player, "not_in_workspace")
	end

	local info = CreatureService.GetInfo(creature)
	if not info or not info.alive then
		-- Unregistered model, or something another player killed a frame ago.
		return reject(player, "not_a_live_creature")
	end

	-- 3. The player must actually exist in the world to swing.
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (root and humanoid) or humanoid.Health <= 0 then
		return reject(player, "no_character")
	end

	-- 4. Range. Tolerance is config, not a magic number: a player on a bad
	--    connection is genuinely a little behind where the server thinks they
	--    are, and punishing latency feels identical to a broken game.
	local reach = GameConfig.SwingRange * GameConfig.SwingRangeTolerance
	local offset = (root :: BasePart).Position - creature:GetPivot().Position
	if offset:Dot(offset) > reach * reach then
		return reject(player, "out_of_range")
	end

	--[[
		5. Profile loaded.

		The V1 zone gate lived here — a player could otherwise farm a locked
		zone's creatures by aiming across its border. D-017 removed zones
		entirely: there is ONE shared hunting wilderness and everyone may hunt
		all of it (GDD §4), so there is nothing left to gate on.

		The profile check stays. Damage is derived from the axe level, and a
		player whose profile has not loaded has no level to derive it from.
	]]
	local data = DataService.GetData(player)
	if not data then
		return reject(player, "not_loaded")
	end

	-- Passed. Commit the cooldown only now, so a rejected swing cannot be used
	-- to keep the timer warm.
	lastSwing[player] = now

	local damage = damageFor(player)
	if damage <= 0 then
		return reject(player, "no_damage")
	end

	--[[
		The cleave (D-015). The client nominated ONE creature and that nomination
		has now passed every check above — but it does not decide who gets hit.
		The server rebuilds the hitbox from the character's own CFrame and finds
		the victims itself, so a crafted client cannot widen its own cleave or
		nominate creatures it isn't standing next to.

		The validated `creature` is still struck, even in the odd case where it
		falls outside the recomputed box: the range check already passed, and
		rejecting a swing the player was told would land feels like a bug.
	]]
	local rootPart = root :: BasePart
	local box = rootPart.CFrame * CFrame.new(0, 0, -GameConfig.HitboxForwardOffset)
	local targets = CreatureService.GetAliveInBox(box, GameConfig.HitboxSize, GameConfig.MaxCleaveTargets)

	if not table.find(targets, creature) then
		table.insert(targets, 1, creature)
	end

	for _, target in ipairs(targets) do
		local targetInfo = CreatureService.GetInfo(target)
		-- Still re-checked per target, minus the zone clause: a creature can die
		-- to another player between the box query and this loop, and damaging a
		-- corpse would double-count the kill.
		if targetInfo and targetInfo.alive then
			local died = CreatureService.Damage(target, damage, player)

			-- Feedback is cosmetic and scoped to who can see it. Broadcasting every
			-- hit server-wide is a lot of traffic for VFX nobody is looking at.
			Net.FireNear(
				target:GetPivot().Position,
				GameConfig.FeedbackRadius,
				"CombatFeedback",
				target,
				damage,
				died
			)

			if died then
				data.stats.kills += 1
				if targetInfo.variant == "golden" then
					data.stats.goldenKills += 1
				end
			end
		end
	end
end

function CombatService.Init()
	Net.On("RequestSwing", onSwing)
end

function CombatService.Start()
	Players.PlayerRemoving:Connect(function(player)
		lastSwing[player] = nil
	end)
end

return CombatService
