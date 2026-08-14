--!strict
--[[
	PILLBUTTON — the top-bar buttons (Sell, Base, Shop).

	`Wide` selects the 298x78 BaseButton geometry; everything else is the 266x70 pill.
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
	Wide: boolean?,
	Position: UDim2?,
	ZIndex: number?,
	LayoutOrder: number?,
	OnActivated: (() -> ())?,
}

local function PillButton(props: Props)
	return React.createElement(Studded, {
		Surface = if props.Wide then Theme.Surface.TopPillWide else Theme.Surface.TopPill,
		Skin = props.Skin,
		Position = props.Position,
		ZIndex = props.ZIndex,
		LayoutOrder = props.LayoutOrder,
		OnActivated = props.OnActivated,
	}, {
		Label = React.createElement(StrokeText, {
			Text = props.Text,
			Style = Theme.Text.Heading,
		}),
	})
end

return PillButton
