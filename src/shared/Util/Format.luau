--!strict
--[[
	FORMAT — number and time display.

	Every player-facing number goes through Abbreviate. Cash reaches the millions
	by Zone 4 and the billions after a few rebirths, and a raw 4839201773 is
	unreadable at a glance.

		Abbreviate(0)        -> "0"
		Abbreviate(999)      -> "999"
		Abbreviate(1000)     -> "1K"
		Abbreviate(1500)     -> "1.5K"
		Abbreviate(1234567)  -> "1.23M"
		Abbreviate(-1500)    -> "-1.5K"

	Trailing zeros are stripped: 1000 reads "1K", never "1.00K".
]]

local Format = {}

local SUFFIXES = { "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

--[[
	Short human-readable form. Two decimals maximum, trailing zeros removed.

	Negatives are formatted by magnitude and re-signed, so -1500 gives "-1.5K"
	rather than something nonsensical from a log of a negative number.
]]
function Format.Abbreviate(value: number): string
	if value ~= value then -- NaN
		return "0"
	end

	local sign = if value < 0 then "-" else ""
	local n = math.abs(value)

	if n < 1000 then
		-- Below the first suffix, show whole units. Fractional cash never
		-- exists in this game, so flooring is honest rather than lossy.
		return sign .. tostring(math.floor(n))
	end

	-- Which 1000-power bracket. Clamped so absurd values still render instead
	-- of indexing past the suffix list and returning nil.
	local tier = math.floor(math.log(n, 1000))
	tier = math.clamp(tier, 1, #SUFFIXES)

	local scaled = n / (1000 ^ tier)

	-- Guard the boundary. 999999 scales to 999.999 — under 1000, so a naive
	-- check passes it through — but rounding to 2dp then yields "1000.00" and
	-- renders "1000K" instead of "1M". Test the ROUNDED value, which is what
	-- actually gets displayed.
	if tonumber(string.format("%.2f", scaled)) :: number >= 1000 and tier < #SUFFIXES then
		tier += 1
		scaled = n / (1000 ^ tier)
	end

	local text = string.format("%.2f", scaled)
	text = string.gsub(text, "%.?0+$", "") -- 1.00 -> 1,  1.50 -> 1.5
	return sign .. text .. SUFFIXES[tier]
end

-- Thousands separators: 1234567 -> "1,234,567". For places where the exact
-- figure matters (a purchase confirmation), not for the HUD.
function Format.Comma(value: number): string
	local sign = if value < 0 then "-" else ""
	local whole = tostring(math.floor(math.abs(value)))

	local out = whole
	while true do
		local replaced: number
		out, replaced = string.gsub(out, "^(%d+)(%d%d%d)", "%1,%2")
		if replaced == 0 then
			break
		end
	end
	return sign .. out
end

--[[
	Duration as the two largest meaningful units.

		Time(45)    -> "45s"
		Time(1425)  -> "23m 45s"
		Time(5025)  -> "1h 23m"

	Two units, never three: countdowns are glanced at, not read.
]]
function Format.Time(seconds: number): string
	local n = math.max(0, math.floor(seconds))

	local days = n // 86400
	local hours = (n % 86400) // 3600
	local minutes = (n % 3600) // 60
	local secs = n % 60

	if days > 0 then
		return `{days}d {hours}h`
	elseif hours > 0 then
		return `{hours}h {minutes}m`
	elseif minutes > 0 then
		return `{minutes}m {secs}s`
	end
	return `{secs}s`
end

-- "84 / 128" for the pack bar (ART_BIBLE §6 — no label word, just the numbers).
function Format.Fraction(current: number, max: number): string
	return `{Format.Abbreviate(current)} / {Format.Abbreviate(max)}`
end

-- "x8.4" for the multiplier readout (G12). Drops a trailing .0 so a clean
-- multiplier reads "x2" rather than "x2.0".
function Format.Multiplier(value: number): string
	local text = string.format("%.1f", value)
	text = string.gsub(text, "%.0$", "")
	return "x" .. text
end

return Format
