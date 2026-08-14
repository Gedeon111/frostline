--!strict
--[[
	ICONBUTTON — the left rail squares (Shop, Index, Rebirth, Settings).

	Icon sizes genuinely differ per button in the source (110, 91, 99 and 97 px square)
	so that stays a prop, but all four are centred on the same point: the export had
	them at x = 8/19/13/22 against a frame centre of 64.5, which is the same placement
	plus drafting jitter.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages.React)

local Theme = require(script.Parent.Parent.Theme)
local Studded = require(script.Parent.Parent.Primitives.Studded)
local StrokeText = require(script.Parent.Parent.Primitives.StrokeText)

-- Icons sit centred on this point inside the 129x145 face; the caption sits below it.
local ICON_CENTRE_Y = 60
local CAPTION_Y = 105
local CAPTION_HEIGHT = 40

export type Props = {
	Caption: string,
	Skin: Theme.Skin,
	Icon: string,
	IconSize: Vector2,
	Position: UDim2?,
	ZIndex: number?,
	LayoutOrder: number?,
	OnActivated: (() -> ())?,
}

local function IconButton(props: Props)
	return React.createElement(Studded, {
		Surface = Theme.Surface.SideButton,
		Skin = props.Skin,
		Position = props.Position,
		ZIndex = props.ZIndex,
		LayoutOrder = props.LayoutOrder,
		OnActivated = props.OnActivated,
	}, {
		Icon = React.createElement("ImageLabel", {
			Image = props.Icon,
			Size = UDim2.fromOffset(props.IconSize.X, props.IconSize.Y),
			Position = UDim2.new(0.5, 0, 0, ICON_CENTRE_Y),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 1,
		}),
		Caption = React.createElement(StrokeText, {
			Text = props.Caption,
			Style = Theme.Text.Caption,
			Size = UDim2.new(1, 0, 0, CAPTION_HEIGHT),
			Position = UDim2.fromOffset(0, CAPTION_Y),
			ZIndex = 2,
		}),
	})
end

return IconButton
