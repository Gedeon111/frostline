--!strict
--[[
	The shop dialog on its own. `Products` is a control so the card row can be pushed
	past three — the export hardcoded three x positions and this is the story that
	proves the list layout replacing them actually holds up.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages.React)
local ReactRoblox = require(Packages.ReactRoblox)

local UI = script.Parent.Parent
local Canvas = require(UI.Primitives.Canvas)
local ShopPanel = require(UI.Screens.ShopPanel)

return {
	react = React,
	reactRoblox = ReactRoblox,
	controls = {
		Title = "BUNDLE",
		Price = "999",
		Products = 3,
	},
	story = function(props)
		local controls = props.controls

		local products = {}
		for index = 1, math.max(1, math.floor(controls.Products)) do
			table.insert(products, { Title = "+50 Cash", Price = tostring(index * 111) })
		end

		return React.createElement(Canvas, nil, {
			Shop = React.createElement(ShopPanel, {
				Visible = true,
				Position = UDim2.fromOffset(522, 167),
				Hero = {
					Title = controls.Title,
					Description = { "Short Description", "Short Description" },
					Price = controls.Price,
				},
				Products = products,
			}),
		})
	end,
}
