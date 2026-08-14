--!strict
--[[
	Every studded control in one frame — the page to open after changing Theme.luau,
	because a token edit that only looks right on one button is the failure mode this
	kit exists to prevent.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages.React)
local ReactRoblox = require(Packages.ReactRoblox)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local PillButton = require(UI.Components.PillButton)
local IconButton = require(UI.Components.IconButton)
local WideToggle = require(UI.Components.WideToggle)
local ExitButton = require(UI.Components.ExitButton)
local PlusButton = require(UI.Components.PlusButton)
local ProductCard = require(UI.Components.ProductCard)

local function row(order: number, height: number, children: { [any]: any })
	return React.createElement("Frame", {
		Size = UDim2.new(1, 0, 0, height),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = order,
	}, children)
end

return {
	react = React,
	reactRoblox = ReactRoblox,
	controls = {
		Label = "Sell",
		SlowMode = true,
	},
	story = function(props)
		local controls = props.controls

		return React.createElement("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.fromRGB(30, 36, 46),
			BorderSizePixel = 0,
		}, {
			Scale = React.createElement("UIScale", { Scale = 0.6 }),
			Padding = React.createElement("UIPadding", {
				PaddingTop = UDim.new(0, 24),
				PaddingLeft = UDim.new(0, 24),
			}),
			Layout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 24),
			}),

			Pills = row(1, 86, {
				Layout = React.createElement("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 23),
				}),
				Sell = React.createElement(PillButton, {
					Text = controls.Label,
					Skin = Theme.Skin.Sell,
					LayoutOrder = 1,
				}),
				Base = React.createElement(PillButton, {
					Text = "Base",
					Skin = Theme.Skin.Base,
					Wide = true,
					LayoutOrder = 2,
				}),
				Shop = React.createElement(PillButton, {
					Text = "Shop",
					Skin = Theme.Skin.Shop,
					LayoutOrder = 3,
				}),
			}),

			Icons = row(2, 150, {
				Layout = React.createElement("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 22),
				}),
				RobuxShop = React.createElement(IconButton, {
					Caption = "Shop",
					Skin = Theme.Skin.RobuxShop,
					Icon = Theme.Image.IconBasket,
					IconSize = Vector2.new(110, 110),
					LayoutOrder = 1,
				}),
				Rebirth = React.createElement(IconButton, {
					Caption = "Rebirth",
					Skin = Theme.Skin.Rebirth,
					Icon = Theme.Image.IconRebirth,
					IconSize = Vector2.new(99, 97),
					LayoutOrder = 2,
				}),
				Index = React.createElement(IconButton, {
					Caption = "Index",
					Skin = Theme.Skin.Index,
					Icon = Theme.Image.IconBook,
					IconSize = Vector2.new(91, 94),
					LayoutOrder = 3,
				}),
				Settings = React.createElement(IconButton, {
					Caption = "Settings",
					Skin = Theme.Skin.Settings,
					Icon = Theme.Image.IconGear,
					IconSize = Vector2.new(97, 97),
					LayoutOrder = 4,
				}),
			}),

			Misc = row(3, 340, {
				Layout = React.createElement("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					VerticalAlignment = Enum.VerticalAlignment.Top,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 32),
				}),
				SlowMode = React.createElement(WideToggle, {
					Text = if controls.SlowMode then "Slow mode: ON" else "Slow mode: OFF",
					Skin = Theme.Skin.SlowMode,
					LayoutOrder = 1,
				}),
				Exit = React.createElement(ExitButton, { LayoutOrder = 2 }),
				Plus = React.createElement(PlusButton, { LayoutOrder = 3 }),
				Card = React.createElement(ProductCard, {
					Title = "+50 Cash",
					Price = "999",
					LayoutOrder = 4,
				}),
			}),
		})
	end,
}
