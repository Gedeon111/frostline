--!strict
--[[
	PRODUCTS — 22 SKUs (11 gamepasses + 11 dev products), source: docs/MONETIZATION.md §4.

	Note: MONETIZATION §4 originally said "19" because its table collapsed the four
	cash packs and two egg bundles into single rows. 22 is the real count; the doc
	has been corrected to match.

	EVERY assetId IS 0 UNTIL JOB P5 creates these on the creator dashboard and
	writes the real ids back. P5 filling in ids is the one sanctioned exception to
	"Architect owns Config" — ids only, nothing else.

	A 0 must never be treated as a real id. MonetizationService skips unconfigured
	products rather than prompting a purchase for asset 0, which fails in a
	confusing way in front of a player.

	Design rule these all obey: monetize depth, not access. No paywalled content,
	no pay-to-win against other players, no Robux-bought loot boxes — eggs cost
	in-game cash; Robux buys cash, luck, and speed.
]]

local Types = require(script.Parent.Parent.Types)

local Products = {}

Products.Gamepasses = {
	{ id = "cash2x",       displayName = "2x Cash",           kind = "gamepass", assetId = 0, robux = 199, effect = "cash_multiplier",   amount = 2,   description = "Double every sell payout." } :: Types.ProductDef,
	{ id = "drops2x",      displayName = "2x Drops",          kind = "gamepass", assetId = 0, robux = 249, effect = "drop_multiplier",   amount = 2,   description = "Double the meat from every kill." } :: Types.ProductDef,
	{ id = "pack100",      displayName = "+100 Pack",         kind = "gamepass", assetId = 0, robux = 149, effect = "capacity_bonus",    amount = 100, description = "Carry 100 more weight." } :: Types.ProductDef,
	{ id = "autoswing",    displayName = "Auto-Swing",        kind = "gamepass", assetId = 0, robux = 399, effect = "auto_swing",                      description = "Swing for you while in range." } :: Types.ProductDef,
	{ id = "autosell",     displayName = "Auto-Sell",         kind = "gamepass", assetId = 0, robux = 299, effect = "auto_sell",                       description = "Sell from anywhere when your pack fills." } :: Types.ProductDef,
	{ id = "lucky",        displayName = "Lucky",             kind = "gamepass", assetId = 0, robux = 399, effect = "luck_multiplier",   amount = 2,   description = "Double rare hatch and rare spawn chance." } :: Types.ProductDef,
	{ id = "slots3",       displayName = "+3 Companion Slots",kind = "gamepass", assetId = 0, robux = 349, effect = "companion_slots",   amount = 3,   description = "Equip 6 companions instead of 3." } :: Types.ProductDef,
	{ id = "autohatch",    displayName = "Auto-Hatch",        kind = "gamepass", assetId = 0, robux = 199, effect = "auto_hatch",                      description = "Hatch continuously." } :: Types.ProductDef,
	{ id = "fasthatch",    displayName = "Fast Hatch",        kind = "gamepass", assetId = 0, robux = 149, effect = "hatch_speed",       amount = 3,   description = "Hatch three times faster." } :: Types.ProductDef,
	{ id = "triplegolden", displayName = "Triple Golden",     kind = "gamepass", assetId = 0, robux = 299, effect = "golden_multiplier", amount = 3,   description = "Triple the golden creature spawn rate." } :: Types.ProductDef,
	{ id = "vip",          displayName = "VIP",               kind = "gamepass", assetId = 0, robux = 499, effect = "vip",                             description = "Private sell pad in every zone, chat tag, daily bonus, exclusive companion." } :: Types.ProductDef,
}

Products.DevProducts = {
	{ id = "cash_s",       displayName = "Small Cash",        kind = "product", assetId = 0, robux = 49,   effect = "grant_cash_scaled", amount = 1,  description = "Cash, scaled to your best zone." } :: Types.ProductDef,
	{ id = "cash_m",       displayName = "Medium Cash",       kind = "product", assetId = 0, robux = 199,  effect = "grant_cash_scaled", amount = 5,  description = "Cash, scaled to your best zone." } :: Types.ProductDef,
	{ id = "cash_l",       displayName = "Large Cash",        kind = "product", assetId = 0, robux = 799,  effect = "grant_cash_scaled", amount = 25, description = "Cash, scaled to your best zone." } :: Types.ProductDef,
	{ id = "cash_xl",      displayName = "Huge Cash",         kind = "product", assetId = 0, robux = 1999, effect = "grant_cash_scaled", amount = 80, description = "Cash, scaled to your best zone." } :: Types.ProductDef,
	{ id = "eggs_3",       displayName = "3 Hatches",         kind = "product", assetId = 0, robux = 99,   effect = "grant_hatches",     amount = 3,  description = "Three instant hatches." } :: Types.ProductDef,
	{ id = "eggs_10",      displayName = "10 Hatches",        kind = "product", assetId = 0, robux = 299,  effect = "grant_hatches",     amount = 10, description = "Ten instant hatches." } :: Types.ProductDef,
	-- The highest-converting SKU in the game (MONETIZATION §4). One-time, 24h
	-- window, shown at the END of the first session — not on join.
	{ id = "starter",      displayName = "Starter Pack",      kind = "product", assetId = 0, robux = 99,   effect = "starter_pack",                   description = "2x Cash, an exclusive companion, and a cash boost. First 24 hours only." } :: Types.ProductDef,
	{ id = "potion_luck",  displayName = "Luck Potion",       kind = "product", assetId = 0, robux = 49,   effect = "boost_luck",        amount = 1800, description = "Double luck for 30 minutes." } :: Types.ProductDef,
	{ id = "potion_cash",  displayName = "Cash Potion",       kind = "product", assetId = 0, robux = 49,   effect = "boost_cash",        amount = 1800, description = "Double cash for 30 minutes." } :: Types.ProductDef,
	{ id = "fillpack",     displayName = "Instant Full Pack", kind = "product", assetId = 0, robux = 99,   effect = "fill_pack",                      description = "Fill your pack instantly." } :: Types.ProductDef,
	{ id = "season",       displayName = "Season Pass",       kind = "product", assetId = 0, robux = 599,  effect = "season_premium",                 description = "Unlock the premium reward track, including every tier you already earned." } :: Types.ProductDef,
}

function Products.All(): { Types.ProductDef }
	local out = {}
	for _, p in ipairs(Products.Gamepasses) do table.insert(out, p) end
	for _, p in ipairs(Products.DevProducts) do table.insert(out, p) end
	return out
end

function Products.Get(id: string): Types.ProductDef?
	for _, p in ipairs(Products.All()) do
		if p.id == id then return p end
	end
	return nil
end

-- False until P5 writes a real id. Guard every purchase prompt on this.
function Products.IsConfigured(id: string): boolean
	local p = Products.Get(id)
	return p ~= nil and p.assetId ~= 0
end

function Products.Unconfigured(): { string }
	local out = {}
	for _, p in ipairs(Products.All()) do
		if p.assetId == 0 then table.insert(out, p.id) end
	end
	return out
end

return Products
