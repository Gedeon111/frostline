--!strict
--[[
	STUDDED — the layered plastic surface the whole kit is built from.

	MainShape sits slightly outside the frame because its drop shadow is baked into the
	artwork; that is why the offsets are negative. It carries the body colour, the
	vertical gradient and the black outline.

	The mask slot is where the FigBlox export goes wrong, and it goes wrong two
	different ways depending on the skin:

	  * On most skins it was a Figma alpha matte clipping the stud texture to the
	    button shape. A matte cannot be exported, so it came out as an opaque white
	    PNG. Drawn as-is it paints a white sheet over the colour and the outline —
	    that was the "gloss is straight up white" and "outline is missing" report.
	    Here it is reused as a *silhouette only*: a UIGradient (Theme.Gloss) makes
	    almost all of it transparent and leaves the diagonal sheen the source has.
	    Reusing it this way is what gets the sheen to follow the irregular
	    side-button outline without hand-authoring a shape per surface.

	  * On HeroPanel and ProductCard the slot holds the gem illustration instead.
	    Those set `MaskIsArt` and are drawn straight, at full opacity, with no gloss —
	    their sheen is already in the artwork and survives export intact.

	Stud texture is tinted per skin (Theme.Skin.*.StudTint) rather than left white,
	because the studs are tone-on-tone in the source.

	Pass `OnActivated` and the root becomes an ImageButton instead of a Frame. Nothing
	in the Figma export was clickable — every "button" came through as a plain Frame —
	so making the interactive ones actually interactive is part of the port, not a
	change to the design.

	Layers occupy ZIndex 1-3. Children start at 4; `ChildZIndex` shifts that if a
	caller needs to interleave.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages.React)

local Theme = require(script.Parent.Parent.Theme)

export type Props = {
	Surface: Theme.Surface,
	Skin: Theme.Skin,
	-- Supply one and the baked stud PNG is replaced by a tiled emboss sheet, the same
	-- construction the shop's top bar uses. See the STUD SHEETS note in Theme.
	Sheet: Theme.StudSheet?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	Size: UDim2?,
	ZIndex: number?,
	LayoutOrder: number?,
	Visible: boolean?,
	OnActivated: (() -> ())?,
	children: any?,
}

local function layer(
	image: string,
	spec: Theme.Layer,
	zIndex: number,
	extra: { [string]: any }?,
	inner: { [any]: any }?
)
	local layerProps: { [string]: any } = {
		Image = image,
		Size = UDim2.fromOffset(spec.Size.X, spec.Size.Y),
		Position = UDim2.fromOffset(spec.Offset.X, spec.Offset.Y),
		ScaleType = if spec.Fit then Enum.ScaleType.Fit else Enum.ScaleType.Stretch,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = zIndex,
	}
	if extra then
		for key, value in extra do
			layerProps[key] = value
		end
	end
	return React.createElement("ImageLabel", layerProps, inner)
end

local function Studded(props: Props)
	local surface = props.Surface
	local skin = props.Skin

	local children: { [any]: any } = {
		MainShape = layer(skin.Main, surface.Main, 1),
	}

	if props.Sheet then
		-- Tiled emboss. Drawn untinted and opaque: the sheet carries the Figma blend
		-- stack and its black pixels are the shadow half, which a tint would erase.
		local sheet = props.Sheet
		local tile, frame = Theme.studTile(sheet, surface.Stud.Size.X, surface.Stud.Size.Y)
		children.StudTexture = React.createElement("ImageLabel", {
			Image = sheet.Image,
			Position = UDim2.fromOffset(
				surface.Stud.Offset.X + (surface.Stud.Size.X - frame.X) // 2,
				surface.Stud.Offset.Y + (surface.Stud.Size.Y - frame.Y) // 2
			),
			Size = UDim2.fromOffset(frame.X, frame.Y),
			ScaleType = Enum.ScaleType.Tile,
			TileSize = tile,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 2,
		})
	else
		children.StudTexture = layer(skin.Stud, surface.Stud, 2, {
			ImageColor3 = skin.StudTint,
			ImageTransparency = if skin.StudTint then Theme.StudAlpha else nil,
		})
	end

	if skin.MaskIsArt then
		children.GroupMask = layer(skin.Mask, surface.Mask, 3)
	else
		children.Gloss = layer(skin.Mask, surface.Mask, 3, {
			-- Tinted, not white — see the GLOSS note in Theme.
			ImageColor3 = skin.StudTint,
		}, {
			Gradient = React.createElement("UIGradient", {
				Rotation = Theme.Gloss.Rotation,
				Transparency = Theme.Gloss.Transparency,
			}),
		})
	end

	if props.children ~= nil then
		children.Content = React.createElement("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 4,
		}, props.children)
	end

	local className = if props.OnActivated then "ImageButton" else "Frame"

	return React.createElement(className, {
		-- ImageButton with no image: we want the hit area, the artwork is in the layers.
		Image = if props.OnActivated then "" else nil,
		AutoButtonColor = if props.OnActivated then false else nil,
		[React.Event.Activated] = props.OnActivated,

		Size = props.Size or UDim2.fromOffset(surface.Size.X, surface.Size.Y),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = props.ZIndex,
		LayoutOrder = props.LayoutOrder,
		Visible = props.Visible,
	}, children)
end

return Studded
