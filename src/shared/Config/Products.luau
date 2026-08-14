--!strict
--[[
	PRODUCTS — approved corrected-slice catalog.

	D-017 carries forward exactly one SKU: D-016 Auto-Swing. A zero assetId is
	unconfigured and must never trigger a purchase prompt.
]]

local Types = require(script.Parent.Parent.Types)

local Products = {}

Products.Gamepasses = {
	{
		id = "autoswing",
		displayName = "Auto-Swing",
		kind = "gamepass",
		assetId = 0,
		robux = 399,
		effect = "auto_swing",
		description = "Swing for you while a valid target is in range.",
	} :: Types.ProductDef,
}

Products.DevProducts = {}

function Products.All(): { Types.ProductDef }
	local out: { Types.ProductDef } = {}
	for _, product in ipairs(Products.Gamepasses) do
		table.insert(out, product)
	end
	for _, product in ipairs(Products.DevProducts) do
		table.insert(out, product)
	end
	return out
end

function Products.Get(id: string): Types.ProductDef?
	for _, product in ipairs(Products.All()) do
		if product.id == id then
			return product
		end
	end
	return nil
end

function Products.IsConfigured(id: string): boolean
	local product = Products.Get(id)
	return product ~= nil and product.assetId ~= 0
end

function Products.Unconfigured(): { string }
	local out: { string } = {}
	for _, product in ipairs(Products.All()) do
		if product.assetId == 0 then
			table.insert(out, product.id)
		end
	end
	return out
end

return Products
