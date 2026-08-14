--!strict
--[[
	PRICETAG — Robux icon followed by an amount.

	Appears at two scales: the hero offer's buy button (46px icon, 58pt text) and the
	product card's (27px icon, 34pt text). The export positioned the icon and the number
	absolutely, which broke as soon as the price gained a digit; a list layout with an
	auto-sized label centres the pair at any length.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages.React)

local Theme = require(script.Parent.Parent.Theme)
local StrokeText = require(script.Parent.Parent.Primitives.StrokeText)

export type Props = {
	Amount: string,
	Small: boolean?,
	ZIndex: number?,
}

local function PriceTag(props: Props)
	local small = props.Small == true

	local icon = if small then Theme.Image.RobuxSmall else Theme.Image.RobuxLarge
	local iconSize = if small then Vector2.new(27, 30) else Vector2.new(46, 51)
	local style = if small then Theme.Text.Price else Theme.Text.Heading
	local gap = if small then 6 else 11

	return React.createElement("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = props.ZIndex,
	}, {
		Layout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, gap),
		}),
		RobuxIcon = React.createElement("ImageLabel", {
			Image = icon,
			Size = UDim2.fromOffset(iconSize.X, iconSize.Y),
			ScaleType = Enum.ScaleType.Fit,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = 1,
		}),
		Amount = React.createElement(StrokeText, {
			Text = props.Amount,
			Style = style,
			Size = UDim2.fromOffset(0, style.Size + 1),
			AutomaticSize = Enum.AutomaticSize.X,
			LayoutOrder = 2,
		}),
	})
end

return PriceTag
