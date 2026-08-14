--!strict
--[[
	STROKETEXT — a TextLabel with the kit's outline, and optionally its extruded bottom.

	Every piece of text in the Figma file is Montserrat ExtraBold with a UIStroke, so
	the pair is one component rather than two elements repeated forty times.

	The display sizes also carry `Depth` (see Theme.Text): the glyphs sit on a black
	copy of themselves pushed straight down, which is how the source file gets its
	moulded-plastic look. Figma draws that as a zero-blur drop shadow. Roblox has no
	equivalent on TextLabel, so it is a second label.

	The copy has to be a *sibling* of the face, not a child. Under
	ZIndexBehavior.Sibling — which this whole kit assumes — a descendant always draws
	above its ancestor regardless of ZIndex, so a child would cover the text it is
	meant to sit behind. That is the only reason the extruded path adds a wrapper
	Frame; flat styles stay a bare TextLabel.

	Alignment defaults to centre-fill instead of the exported Left/Top. FigBlox writes
	a tight box around the glyphs and positions it by hand — "Sell" came out at x=89,
	width 91, inside a 266-wide button, which centres at 134.5 against a true centre of
	133. Centre-filling lands in the same place to within two pixels and, unlike the
	exported version, survives the string getting longer.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages.React)

local Theme = require(script.Parent.Parent.Theme)

export type Props = {
	Text: string,
	Style: Theme.TextStyle,
	Color: Color3?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	XAlign: Enum.TextXAlignment?,
	YAlign: Enum.TextYAlignment?,
	ZIndex: number?,
	LayoutOrder: number?,
	Wrapped: boolean?,
	AutomaticSize: Enum.AutomaticSize?,
}

local function StrokeText(props: Props)
	local style = props.Style
	local depth = style.Depth or 0

	-- The glyphs themselves. `extra` supplies layout and is applied last so the
	-- extruded copy can override the colour.
	local function label(extra: { [string]: any })
		local labelProps: { [string]: any } = {
			Text = props.Text,
			FontFace = Theme.Font,
			TextSize = style.Size,
			TextColor3 = props.Color or style.Color,
			TextXAlignment = props.XAlign or Enum.TextXAlignment.Center,
			TextYAlignment = props.YAlign or Enum.TextYAlignment.Center,
			TextWrapped = props.Wrapped,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}
		for key, value in extra do
			labelProps[key] = value
		end

		return React.createElement("TextLabel", labelProps, {
			Stroke = React.createElement("UIStroke", {
				Thickness = style.Stroke,
				Color = Theme.Color.Stroke,
				LineJoinMode = style.Join,
			}),
		})
	end

	if depth <= 0 then
		return label({
			Size = props.Size or UDim2.fromScale(1, 1),
			Position = props.Position,
			AnchorPoint = props.AnchorPoint,
			ZIndex = props.ZIndex,
			LayoutOrder = props.LayoutOrder,
			AutomaticSize = props.AutomaticSize,
		})
	end

	--[[
		AutomaticSize has to be pushed down onto the labels as well as the wrapper.
		A Frame sizes itself to its children's extents, so on an auto axis the child
		must measure itself — left at fromScale(1, 1) it would resolve against a
		zero-wide parent, collapse, and the text would spill out of the box. That is
		what put the Robux icon on top of the bundle's price: Heading gained a Depth,
		PriceTag's amount took this path, and its AutomaticSize.X stopped reaching the
		label that needed it.
	]]
	local auto = props.AutomaticSize
	local autoX = auto == Enum.AutomaticSize.X or auto == Enum.AutomaticSize.XY
	local autoY = auto == Enum.AutomaticSize.Y or auto == Enum.AutomaticSize.XY
	local innerSize = UDim2.fromScale(if autoX then 0 else 1, if autoY then 0 else 1)

	return React.createElement("Frame", {
		Size = props.Size or UDim2.fromScale(1, 1),
		AutomaticSize = auto,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = props.ZIndex,
		LayoutOrder = props.LayoutOrder,
	}, {
		Extrude = label({
			Size = innerSize,
			AutomaticSize = auto,
			Position = UDim2.fromOffset(0, depth),
			TextColor3 = Theme.Color.Stroke,
			ZIndex = 1,
		}),
		Face = label({
			Size = innerSize,
			AutomaticSize = auto,
			ZIndex = 2,
		}),
	})
end

return StrokeText
