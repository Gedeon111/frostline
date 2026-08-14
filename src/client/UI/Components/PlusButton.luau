--!strict
--[[
	PLUSBUTTON — the green "+" beside the cash readout. Opens the Robux shop.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages.React)

local Theme = require(script.Parent.Parent.Theme)
local ChunkyButton = require(script.Parent.Parent.Primitives.ChunkyButton)

export type Props = {
	Position: UDim2?,
	ZIndex: number?,
	LayoutOrder: number?,
	OnActivated: (() -> ())?,
}

local function PlusButton(props: Props)
	return React.createElement(ChunkyButton, {
		Size = Vector2.new(43, 48),
		ShadowImage = Theme.Image.PlusShadow,
		ShadowSize = Vector2.new(48, 51),
		ShadowOffset = Vector2.new(-3, 0),
		Base = {
			Color = Color3.fromRGB(23, 161, 28),
			Size = Vector2.new(43, 40),
			Offset = Vector2.new(0, 8),
		},
		Top = {
			Color = Color3.fromRGB(48, 255, 55),
			Size = Vector2.new(43, 40),
			Offset = Vector2.new(0, 3),
			StrokeColor = Color3.fromRGB(190, 255, 161),
			StrokeThickness = 3,
		},
		Label = "+",
		LabelStyle = Theme.Text.Subheading,
		Position = props.Position,
		ZIndex = props.ZIndex,
		LayoutOrder = props.LayoutOrder,
		OnActivated = props.OnActivated,
	})
end

return PlusButton
