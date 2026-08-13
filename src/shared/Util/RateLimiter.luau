--!strict
--[[
	RATELIMITER — token bucket, keyed.

	Used in exactly one place: Net (F4) wraps every inbound remote handler with
	it, using the budgets in GameConfig.RateLimits. No service writes its own
	rate check — WORKFLOW §5 and ARCHITECTURE §3.

		if not RateLimiter.Check(`{player.UserId}:RequestSwing`, 10, 1) then return end

	Token bucket rather than a fixed window because a window lets a client fire
	its whole budget at the boundary, then the whole next budget immediately
	after — a 2x burst that a bucket refilling continuously does not permit.

	Buckets are created lazily. Call Forget() when a player leaves or the table
	grows without bound over a long server's life.
]]

type Bucket = {
	tokens: number,
	updated: number,
}

local RateLimiter = {}

local buckets: { [string]: Bucket } = {}

--[[
	Consumes one token. Returns true if the caller is within budget.

	`budget` tokens refill over `perSeconds`. Both are read from config by the
	caller, never hardcoded here.
]]
function RateLimiter.Check(key: string, budget: number, perSeconds: number): boolean
	if budget <= 0 or perSeconds <= 0 then
		return false
	end

	local now = os.clock()
	local bucket = buckets[key]

	if not bucket then
		-- Start full, minus the token this call consumes.
		buckets[key] = { tokens = budget - 1, updated = now }
		return true
	end

	local refill = (now - bucket.updated) * (budget / perSeconds)
	bucket.tokens = math.min(budget, bucket.tokens + refill)
	bucket.updated = now

	if bucket.tokens >= 1 then
		bucket.tokens -= 1
		return true
	end

	return false
end

-- Tokens currently available, without consuming one. For diagnostics only —
-- never branch gameplay on this, since it is stale the moment it returns.
function RateLimiter.Peek(key: string, budget: number, perSeconds: number): number
	local bucket = buckets[key]
	if not bucket then
		return budget
	end
	local refill = (os.clock() - bucket.updated) * (budget / perSeconds)
	return math.min(budget, bucket.tokens + refill)
end

function RateLimiter.Forget(key: string)
	buckets[key] = nil
end

-- Drop every bucket whose key starts with `prefix`. Net calls this with the
-- player's UserId on PlayerRemoving so buckets don't accumulate forever.
function RateLimiter.ForgetPrefix(prefix: string)
	for key in pairs(buckets) do
		if string.sub(key, 1, #prefix) == prefix then
			buckets[key] = nil
		end
	end
end

function RateLimiter.Reset()
	table.clear(buckets)
end

function RateLimiter.Count(): number
	local n = 0
	for _ in pairs(buckets) do
		n += 1
	end
	return n
end

return RateLimiter
