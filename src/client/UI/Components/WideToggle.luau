--!strict
--[[
	WIDETOGGLE — the full-width left-rail control (Slow mode: ON).

	Text only, no icon. The label is centred rather than pinned at x=22 like the export,
	so "Slow mode: OFF" does not sit two pixels off from "Slow mode: ON".
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages.React)

local Theme = require(script.Parent.Parent.Theme)
local Studded = require(script.Parent.Parent.Primitives.Studded)
local StrokeText = require(script.Parent.Parent.Primitives.StrokeText)

export type Props = {
	Text: string,
	Skin: Theme.Skin,
	Position: UDim2?,
	ZIndex: number?,
	LayoutOrder: number?,
	OnActivated: (() -> ())?,
}

local function WideToggle(props: Props)
	return React.createElement(Studded, {
		Surface = Theme.Surface.WidePill,
		Skin = props.Skin,
		Position = props.Position,
		ZIndex = props.ZIndex,
		LayoutOrder = props.LayoutOrder,
		OnActivated = props.OnActivated,
	}, {
		Label = React.createElement(StrokeText, {
			Text = props.Text,
			Style = Theme.Text.Body,
		}),
	})
end

return WideToggle
