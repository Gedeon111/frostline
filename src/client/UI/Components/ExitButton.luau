--!strict
--[[
	EXITBUTTON — the red "X" in the shop header.
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

local function ExitButton(props: Props)
	return React.createElement(ChunkyButton, {
		Size = Vector2.new(108, 113),
		ShadowImage = Theme.Image.ExitShadow,
		ShadowSize = Vector2.new(118, 124),
		ShadowOffset = Vector2.new(-5, -5),
		Base = {
			Color = Color3.fromRGB(142, 26, 26),
			Size = Vector2.new(108, 99),
			Offset = Vector2.new(0, 13),
		},
		Top = {
			Color = Color3.fromRGB(255, 255, 255),
			Size = Vector2.new(108, 105),
			Offset = Vector2.new(0, 0),
			StrokeColor = Color3.fromRGB(255, 129, 129),
			StrokeThickness = 4,
			Gradient = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 99, 99)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 44, 44)),
			}),
		},
		OverlayImage = Theme.Image.ExitStuds,
		Label = "X",
		LabelStyle = Theme.Text.Title,
		Position = props.Position,
		ZIndex = props.ZIndex,
		LayoutOrder = props.LayoutOrder,
		OnActivated = props.OnActivated,
	})
end

return ExitButton
