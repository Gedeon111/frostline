--!strict
--[[
	PRODUCTCARD — one developer-product tile in the shop grid.

	Title and buy button are both centred on the card. In the export the title sat at
	x=40 with a width of 175 inside a 255 card, which is dead centre plus rounding, and
	the button at x=22 against a centred 21.5 — same story.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages.React)

local Theme = require(script.Parent.Parent.Theme)
local Studded = require(script.Parent.Parent.Primitives.Studded)
local StrokeText = require(script.Parent.Parent.Primitives.StrokeText)
local PriceTag = require(script.Parent.PriceTag)

local TITLE_Y = 5
local BUTTON_Y = 253

export type Props = {
	Title: string,
	Price: string,
	Position: UDim2?,
	ZIndex: number?,
	LayoutOrder: number?,
	OnActivated: (() -> ())?,
}

local function ProductCard(props: Props)
	return React.createElement(Studded, {
		Surface = Theme.Surface.ProductCard,
		Skin = Theme.Skin.ProductCard,
		Sheet = Theme.Stud.Fine,
		Position = props.Position,
		ZIndex = props.ZIndex,
		LayoutOrder = props.LayoutOrder,
	}, {
		Title = React.createElement(StrokeText, {
			Text = props.Title,
			Style = Theme.Text.Subheading,
			Size = UDim2.new(1, 0, 0, 43),
			Position = UDim2.fromOffset(0, TITLE_Y),
			ZIndex = 1,
		}),
		Buy = React.createElement(Studded, {
			Surface = Theme.Surface.ProductButton,
			Skin = Theme.Skin.ProductButton,
			Position = UDim2.new(0.5, 0, 0, BUTTON_Y),
			AnchorPoint = Vector2.new(0.5, 0),
			ZIndex = 2,
			OnActivated = props.OnActivated,
		}, {
			Price = React.createElement(PriceTag, { Amount = props.Price, Small = true }),
		}),
	})
end

return ProductCard
