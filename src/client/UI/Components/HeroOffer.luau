--!strict
--[[
	HEROOFFER — the wide banner at the top of the shop.

	The export carried two separate "Short Description" TextLabels stacked 35px apart.
	They are one wrapped description here, driven by a list of lines, so a third line
	does not mean a fourth hand-placed label.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages.React)

local Theme = require(script.Parent.Parent.Theme)
local Studded = require(script.Parent.Parent.Primitives.Studded)
local StrokeText = require(script.Parent.Parent.Primitives.StrokeText)
local PriceTag = require(script.Parent.PriceTag)

-- Everything in the banner hangs off one left margin. The export had the title at 13
-- and the description at 0; a single edge reads as deliberate, two do not.
local MARGIN = 16
local LINE_HEIGHT = 35
local DESCRIPTION_TOP = 78

export type Props = {
	Title: string,
	Description: { string },
	Price: string,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	ZIndex: number?,
	OnActivated: (() -> ())?,
}

local function HeroOffer(props: Props)
	local lines: { [any]: any } = {}
	for index, line in ipairs(props.Description) do
		lines["Line" .. index] = React.createElement(StrokeText, {
			Text = line,
			Style = Theme.Text.Note,
			Size = UDim2.fromOffset(264, 30),
			Position = UDim2.fromOffset(MARGIN, DESCRIPTION_TOP + (index - 1) * LINE_HEIGHT),
			XAlign = Enum.TextXAlignment.Left,
			ZIndex = 2,
		})
	end

	return React.createElement(Studded, {
		Surface = Theme.Surface.HeroPanel,
		Skin = Theme.Skin.HeroPanel,
		Sheet = Theme.Stud.Fine,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		ZIndex = props.ZIndex,
	}, {
		Title = React.createElement(StrokeText, {
			Text = props.Title,
			Style = Theme.Text.Bundle,
			Size = UDim2.fromOffset(285, 78),
			Position = UDim2.fromOffset(MARGIN, 0),
			XAlign = Enum.TextXAlignment.Left,
			ZIndex = 1,
		}),
		Description = React.createElement("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 2,
		}, lines),
		Buy = React.createElement(Studded, {
			Surface = Theme.Surface.TopPill,
			Skin = Theme.Skin.HeroButton,
			Position = UDim2.fromOffset(MARGIN, 164),
			ZIndex = 3,
			OnActivated = props.OnActivated,
		}, {
			Price = React.createElement(PriceTag, { Amount = props.Price }),
		}),
	})
end

return HeroOffer
