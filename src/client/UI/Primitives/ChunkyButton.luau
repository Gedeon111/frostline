--!strict
--[[
	CHUNKYBUTTON — the extruded slab button (shop close "X", currency "+").

	Unlike the studded controls these two are drawn from primitives rather than baked
	artwork: a shadow image, a dark slab offset downward, a bright slab on top with a
	border stroke, and an optional stud overlay. Same construction in both, different
	colours and one extra layer on the exit button, so they share this component.

	Because they are primitives they are also the only controls with no black outline
	baked into a PNG, and the export could not supply one: in the SVG every shape
	carries BOTH a black outside stroke and a lighter inside rim, but a Roblox
	GuiObject takes a single UIStroke, so FigBlox kept the rim (#FF8181 on the X) and
	dropped the black. That is why the close button read as a floating pink-edged
	square while every other button looked outlined.

	`Outline` restores it: a transparent frame spanning the union of the two slabs,
	carrying a black Border stroke.

	That frame is inset by the stroke thickness, and the outline draws *over* the
	slabs rather than under them. Both details matter. A Roblox Border stroke renders
	wholly outside its frame, so an un-inset outline would grow the button past its
	own box — on the shop's close button that pushed 4px past the panel edge and made
	the whole top bar look shifted against the body outline below it. Insetting puts
	the stroke's outer edge back on the union bounds, which is where Figma's centred
	stroke sits. Drawing it on top is then required, because an inset ring would
	otherwise be hidden behind the slabs it is meant to outline.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages.React)

local Theme = require(script.Parent.Parent.Theme)
local StrokeText = require(script.Parent.StrokeText)

export type Slab = {
	Color: Color3,
	Size: Vector2,
	Offset: Vector2,
	StrokeColor: Color3?,
	StrokeThickness: number?,
	Gradient: ColorSequence?,
}

export type Props = {
	Size: Vector2,
	ShadowImage: string,
	ShadowSize: Vector2,
	ShadowOffset: Vector2,
	Base: Slab,
	Top: Slab,
	OverlayImage: string?,
	OutlineThickness: number?,
	Label: string,
	LabelStyle: Theme.TextStyle,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	ZIndex: number?,
	LayoutOrder: number?,
	OnActivated: (() -> ())?,
}

local function slab(spec: Slab, zIndex: number)
	local children: { [any]: any } = {}

	if spec.StrokeColor then
		children.Stroke = React.createElement("UIStroke", {
			Color = spec.StrokeColor,
			Thickness = spec.StrokeThickness,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			LineJoinMode = Enum.LineJoinMode.Miter,
		})
	end

	if spec.Gradient then
		children.Gradient = React.createElement("UIGradient", {
			Color = spec.Gradient,
			Rotation = 90,
		})
	end

	return React.createElement("Frame", {
		BackgroundColor3 = spec.Color,
		Size = UDim2.fromOffset(spec.Size.X, spec.Size.Y),
		Position = UDim2.fromOffset(spec.Offset.X, spec.Offset.Y),
		BorderSizePixel = 0,
		ZIndex = zIndex,
	}, children)
end

-- Box enclosing both slabs. The dark base is offset downward, so the button's real
-- silhouette is taller than either slab on its own.
local function union(a: Slab, b: Slab): (Vector2, Vector2)
	local minX = math.min(a.Offset.X, b.Offset.X)
	local minY = math.min(a.Offset.Y, b.Offset.Y)
	local maxX = math.max(a.Offset.X + a.Size.X, b.Offset.X + b.Size.X)
	local maxY = math.max(a.Offset.Y + a.Size.Y, b.Offset.Y + b.Size.Y)
	return Vector2.new(minX, minY), Vector2.new(maxX - minX, maxY - minY)
end

local function ChunkyButton(props: Props)
	local outlineOffset, outlineSize = union(props.Base, props.Top)
	local outline = props.OutlineThickness or 4

	local children: { [any]: any } = {
		Shadow = React.createElement("ImageLabel", {
			Image = props.ShadowImage,
			Size = UDim2.fromOffset(props.ShadowSize.X, props.ShadowSize.Y),
			Position = UDim2.fromOffset(props.ShadowOffset.X, props.ShadowOffset.Y),
			ScaleType = Enum.ScaleType.Fit,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 1,
		}),
		Base = slab(props.Base, 2),
		Top = slab(props.Top, 3),
		Outline = React.createElement("Frame", {
			Size = UDim2.fromOffset(outlineSize.X - outline * 2, outlineSize.Y - outline * 2),
			Position = UDim2.fromOffset(outlineOffset.X + outline, outlineOffset.Y + outline),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 5,
		}, {
			Stroke = React.createElement("UIStroke", {
				Color = Theme.Color.Stroke,
				Thickness = outline,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				LineJoinMode = Enum.LineJoinMode.Miter,
			}),
		}),
		Label = React.createElement(StrokeText, {
			Text = props.Label,
			Style = props.LabelStyle,
			ZIndex = 6,
		}),
	}

	if props.OverlayImage then
		children.Overlay = React.createElement("ImageLabel", {
			Image = props.OverlayImage,
			Size = UDim2.fromOffset(props.Top.Size.X, props.Top.Size.Y),
			Position = UDim2.fromOffset(props.Top.Offset.X, props.Top.Offset.Y),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			ZIndex = 4,
		})
	end

	local className = if props.OnActivated then "ImageButton" else "Frame"

	return React.createElement(className, {
		Image = if props.OnActivated then "" else nil,
		AutoButtonColor = if props.OnActivated then false else nil,
		[React.Event.Activated] = props.OnActivated,

		Size = UDim2.fromOffset(props.Size.X, props.Size.Y),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = props.ZIndex,
		LayoutOrder = props.LayoutOrder,
	}, children)
end

return ChunkyButton
