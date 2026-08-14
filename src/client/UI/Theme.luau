--!strict
--[[
	THEME — design tokens for the studded UI kit.

	Extracted from the FigBlox import of the Figma file (StarterGui."Slide 16:9 - 1").
	Every number and asset id here was read off the live instances, not eyeballed.

	Two things were deliberately NOT copied verbatim:

	1. Sub-pixel noise. Figma exports percentages, so FigBlox emitted sizes like
	   UDim2.new(-0.0015, 307, 0.0006, 86) — a garbage scale component next to the real
	   offset. Scale is dropped; offsets are kept. Inside a fixed 1920x1081 canvas the
	   visual difference is under 3px, and the layout stops drifting when the canvas
	   resizes.
	2. Near-duplicate geometry. The four side buttons were exported at 129x145, 129x145,
	   129x145 and 137x145 with mask sizes 124/126/124/126. Those are export artifacts,
	   not design intent, so each family collapses to one canonical geometry.

	If a control ever needs to break a token, add a variant here rather than passing a
	raw number at the call site — that is the whole point of the file.
]]

local Theme = {}

-- Design canvas. Everything is authored at these dimensions and scaled as a unit
-- by Canvas.luau. The Figma frame was "Slide 16:9 - 1" at 1920x1081.
Theme.CanvasSize = Vector2.new(1920, 1081)

Theme.Font = Font.new(
	"rbxasset://fonts/families/Montserrat.json",
	Enum.FontWeight.ExtraBold,
	Enum.FontStyle.Normal
)

Theme.Color = {
	Text = Color3.fromRGB(255, 255, 255),
	Cash = Color3.fromRGB(0, 255, 9),
	Bundle = Color3.fromRGB(255, 246, 0),
	Stroke = Color3.fromRGB(0, 0, 0),
	Scrim = Color3.fromRGB(0, 0, 0),
	-- FigBlox exported this white; the SVG is unambiguous that it is black:
	--   <rect ... fill="black" fill-opacity="0.5" stroke="black" stroke-width="5"/>
	-- A white border round the shop panel is the "outline missing round the panel"
	-- report — it was there, just inverted.
	ScrimStroke = Color3.fromRGB(0, 0, 0),
}

export type TextStyle = {
	Size: number,
	Stroke: number,
	Color: Color3,
	Join: Enum.LineJoinMode?,
	Depth: number?,
}

--[[
	`Depth` is the extruded-bottom look from the Figma file: the glyphs sit on a black
	mass offset straight down, so the type reads as moulded plastic rather than flat.
	Figma draws it as a 0-blur drop shadow; StrokeText reproduces it with a black copy
	of the label behind the real one.

	Every style carries one, scaled to roughly size/20 so the extrusion stays in
	proportion from the 77pt title down to the 29pt notes. The source only draws it on
	the display sizes, but applying it throughout is a deliberate call — it reads as
	one typographic system rather than two.
]]
-- Stroke thickness tracks text size in the source file (77->4, 58->3, 34->1.78).
-- The fractional 1.7774 on the small price labels is rounded to 2.
Theme.Text = {
	Title = { Size = 77, Stroke = 4, Color = Theme.Color.Text, Depth = 4 } :: TextStyle,
	-- Same size as Title but a thinner outline and the cash colour — that is how the
	-- currency readout is drawn in the source, not an oversight.
	Cash = { Size = 77, Stroke = 3, Color = Theme.Color.Cash, Depth = 5 } :: TextStyle,
	Bundle = { Size = 77, Stroke = 3, Color = Theme.Color.Bundle, Depth = 4 } :: TextStyle,
	Heading = { Size = 58, Stroke = 3, Color = Theme.Color.Text, Depth = 3 } :: TextStyle,
	Subheading = { Size = 43, Stroke = 3, Color = Theme.Color.Text, Depth = 3 } :: TextStyle,
	Caption = { Size = 37, Stroke = 3, Color = Theme.Color.Text, Depth = 2 } :: TextStyle,
	Body = { Size = 35, Stroke = 3, Color = Theme.Color.Text, Depth = 2 } :: TextStyle,
	Price = { Size = 34, Stroke = 2, Color = Theme.Color.Text, Depth = 2 } :: TextStyle,
	Note = {
		Size = 29,
		Stroke = 2,
		Color = Theme.Color.Text,
		Join = Enum.LineJoinMode.Miter,
		Depth = 2,
	} :: TextStyle,
}

--[[
	SURFACES — geometry of the three-layer studded look.

	Every studded control is the same sandwich:
	  MainShape   the coloured body plus its baked drop shadow, sitting slightly
	              outside the frame (that negative offset is the shadow bleed)
	  GroupMask   the flat fill
	  StudTexture the stud overlay

	`Order` records which of the two upper layers draws first. Buttons stack
	mask-then-studs; the hero panel and product cards stack studs-then-mask. That
	inversion is in the source file and it is load-bearing — flipping it changes how
	the studs read against the fill.
]]
export type Layer = {
	Size: Vector2,
	Offset: Vector2,
	Fit: boolean?,
}

export type Surface = {
	Size: Vector2,
	Main: Layer,
	Mask: Layer,
	Stud: Layer,
	Order: "MaskFirst" | "StudFirst",
}

Theme.Surface = {
	-- Top bar, wide variant (BaseButton)
	TopPillWide = {
		Size = Vector2.new(298, 78),
		Main = { Size = Vector2.new(307, 86), Offset = Vector2.new(-5, -3), Fit = true },
		Mask = { Size = Vector2.new(298, 73), Offset = Vector2.new(0, 0), Fit = true },
		Stud = { Size = Vector2.new(298, 73), Offset = Vector2.new(0, 0) },
		Order = "MaskFirst",
	} :: Surface,

	-- Top bar, standard (SellButton / ShopButton) and the hero offer's buy button
	TopPill = {
		Size = Vector2.new(266, 70),
		Main = { Size = Vector2.new(274, 78), Offset = Vector2.new(-3, -3), Fit = true },
		Mask = { Size = Vector2.new(266, 65), Offset = Vector2.new(0, 0), Fit = true },
		Stud = { Size = Vector2.new(266, 65), Offset = Vector2.new(0, 0) },
		Order = "MaskFirst",
	} :: Surface,

	-- Left rail square buttons
	SideButton = {
		Size = Vector2.new(129, 145),
		Main = { Size = Vector2.new(137, 143), Offset = Vector2.new(-5, -5), Fit = true },
		Mask = { Size = Vector2.new(126, 126), Offset = Vector2.new(0, 0), Fit = true },
		Stud = { Size = Vector2.new(126, 126), Offset = Vector2.new(3, 3) },
		Order = "MaskFirst",
	} :: Surface,

	-- Left rail wide toggle (SlowMode)
	WidePill = {
		Size = Vector2.new(280, 81),
		Main = { Size = Vector2.new(288, 89), Offset = Vector2.new(-5, -3), Fit = true },
		Mask = { Size = Vector2.new(277, 73), Offset = Vector2.new(0, 0), Fit = true },
		Stud = { Size = Vector2.new(277, 73), Offset = Vector2.new(3, 3) },
		Order = "MaskFirst",
	} :: Surface,

	-- Shop hero banner
	HeroPanel = {
		Size = Vector2.new(815, 261),
		Main = { Size = Vector2.new(820, 269), Offset = Vector2.new(-3, -3), Fit = true },
		Mask = { Size = Vector2.new(812, 250), Offset = Vector2.new(0, 3), Fit = true },
		Stud = { Size = Vector2.new(815, 250), Offset = Vector2.new(0, 3) },
		Order = "StudFirst",
	} :: Surface,

	-- Shop product card
	ProductCard = {
		Size = Vector2.new(255, 323),
		Main = { Size = Vector2.new(261, 333), Offset = Vector2.new(-3, -5), Fit = true },
		Mask = { Size = Vector2.new(255, 312), Offset = Vector2.new(0, 0), Fit = true },
		Stud = { Size = Vector2.new(255, 309), Offset = Vector2.new(0, 3) },
		Order = "StudFirst",
	} :: Surface,

	-- Small buy button inside a product card
	ProductButton = {
		Size = Vector2.new(212, 40),
		Main = { Size = Vector2.new(218, 46), Offset = Vector2.new(-3, -3), Fit = true },
		Mask = { Size = Vector2.new(212, 38), Offset = Vector2.new(0, 0), Fit = true },
		Stud = { Size = Vector2.new(212, 38), Offset = Vector2.new(0, 0) },
		Order = "MaskFirst",
	} :: Surface,
}

--[[
	SKINS — the three asset ids for one colourway.

	The Figma export bakes colour into the artwork, so a red button and a green button
	are different images rather than the same image with a tint. Mask and stud ids are
	shared across a family; MainShape is what carries the colour.

	THE MASK SLOT IS USUALLY NOT ARTWORK. In Figma these were alpha mattes clipping the
	stud texture to the button shape. FigBlox cannot export a matte, so it flattened
	each one to a solid white PNG. Drawing those as a visible layer paints a white
	sheet over the colour and the baked black outline underneath — which is exactly
	what "the gloss is straight up white" and "the outline is missing" were.

	Two skins are the exception: HeroPanel and ProductCard put the gem illustration in
	that slot, so it is real art and must be drawn. Those set `MaskIsArt`. Studded
	renders the mask layer only for them and skips the mattes entirely.
]]
export type Skin = {
	Main: string,
	Mask: string,
	Stud: string,
	MaskIsArt: boolean?,
	StudTint: Color3?,
}

--[[
	GLOSS — the diagonal sheen across the top-left of every studded control.

	In Figma this is a blend-mode layer. Neither export path survives it: the PNG
	pack flattens it to opaque white, and the SVG export drops mix-blend-mode
	entirely (there is not one in `Slide 16_9 - 1.svg` — that is why the SVG looks
	as washed out as the PNG build did).

	So it is rebuilt here instead of imported. The white matte PNG is reused purely
	as a *silhouette* — an ImageLabel of it, driven by this UIGradient, paints a
	correctly-shaped sheen and nothing else. That gets exact shape fidelity for the
	irregular side-button outlines without hand-authoring a corner radius per surface.

	The sheen is tinted to the skin's StudTint, not left white. A white sheen is what
	both export paths produce and it reads as a wash over the colour; in the source
	the lit half of a green button is lighter *green*. Tinting is also why this can
	stay fairly opaque without looking blown out.

	The hard step at 0.56 is deliberate: the source has a visible diagonal seam
	rather than a smooth falloff.
]]
Theme.Gloss = {
	Rotation = 20,
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(0.55, 0.68),
		NumberSequenceKeypoint.new(0.56, 1),
		NumberSequenceKeypoint.new(1, 1),
	}),
}

-- Studs are tone-on-tone in the source, not white. Tint comes from the light stop of
-- each body gradient in the SVG export; StudAlpha keeps them as surface texture
-- rather than a pattern sitting on top of the colour.
Theme.StudAlpha = 0.25

-- Body gradients read out of `Slide 16_9 - 1.svg`. Each StudTint below is the light
-- stop of the surface it sits on, so the studs read as moulded into the plastic.
local GREEN = Color3.fromHex("#80F057")
local RED = Color3.fromHex("#FF6363")
local SKY = Color3.fromHex("#22E9FF")
local BLUE = Color3.fromHex("#00D0FF")
local GOLD = Color3.fromHex("#FFC400")
local MAGENTA = Color3.fromHex("#DB35BD")
local GREY = Color3.fromHex("#CFCFCF")

Theme.Skin = {
	Base = {
		Main = "rbxassetid://94030131086027",
		Mask = "rbxassetid://76355334650542",
		Stud = "rbxassetid://91992120457880",
		StudTint = GREEN,
	} :: Skin,
	Sell = {
		Main = "rbxassetid://127219994493631",
		Mask = "rbxassetid://121603449873015",
		Stud = "rbxassetid://125644774812210",
		StudTint = RED,
	} :: Skin,
	Shop = {
		Main = "rbxassetid://72516667534668",
		Mask = "rbxassetid://121603449873015",
		Stud = "rbxassetid://125644774812210",
		StudTint = SKY,
	} :: Skin,
	RobuxShop = {
		Main = "rbxassetid://78912478377380",
		Mask = "rbxassetid://121206190201948",
		Stud = "rbxassetid://130127790065258",
		StudTint = BLUE,
	} :: Skin,
	Index = {
		Main = "rbxassetid://98037670503852",
		Mask = "rbxassetid://121206190201948",
		Stud = "rbxassetid://130127790065258",
		StudTint = GREEN,
	} :: Skin,
	Rebirth = {
		Main = "rbxassetid://79609247642654",
		Mask = "rbxassetid://121206190201948",
		Stud = "rbxassetid://130127790065258",
		StudTint = MAGENTA,
	} :: Skin,
	Settings = {
		Main = "rbxassetid://93687037070685",
		Mask = "rbxassetid://121206190201948",
		Stud = "rbxassetid://130127790065258",
		StudTint = GREY,
	} :: Skin,
	SlowMode = {
		Main = "rbxassetid://95244551817446",
		Mask = "rbxassetid://114611655597063",
		Stud = "rbxassetid://122912856104604",
		StudTint = GREEN,
	} :: Skin,
	HeroPanel = {
		Main = "rbxassetid://135516138510125",
		-- Gem illustration, not a matte.
		Mask = "rbxassetid://85749020577790",
		MaskIsArt = true,
		Stud = "rbxassetid://111783570152159",
		StudTint = GOLD,
	} :: Skin,
	HeroButton = {
		Main = "rbxassetid://139409156643524",
		Mask = "rbxassetid://121603449873015",
		Stud = "rbxassetid://125644774812210",
		StudTint = GREEN,
	} :: Skin,
	ProductCard = {
		Main = "rbxassetid://133837716633039",
		-- Gem illustration, not a matte.
		Mask = "rbxassetid://90938734720299",
		MaskIsArt = true,
		Stud = "rbxassetid://103344333733995",
		StudTint = BLUE,
	} :: Skin,
	ProductButton = {
		Main = "rbxassetid://140596104070476",
		Mask = "rbxassetid://97940872967271",
		Stud = "rbxassetid://124442905422996",
		StudTint = GREEN,
	} :: Skin,
}

--[[
	STUD SHEETS — tileable stud textures with the Figma blend stack baked in.

	In Figma a studded surface is the stud sheet twice over the body gradient: Overlay
	at 60% fill, then Plus Lighter at 25%. Roblox ScreenGui has no blend modes, so
	neither pass can be reproduced live, and stacking the sheet on itself makes it
	fainter rather than stronger (0.85x the original alpha).

	So each sheet is pre-baked by `tools/stud_bake.py` into a *signed emboss*: white
	pixels where the stud is lighter than mid-grey, black where darker, alpha carrying
	the magnitude. Normal alpha compositing then reproduces Overlay's behaviour on any
	backdrop, which is why one asset serves every colourway instead of needing a bake
	per colour. The script also crops the export to a single tile, so these repeat
	seamlessly at any size.

	The bake is asymmetric on purpose. Measured against renders of the same swatch,
	Figma and a plain symmetric Overlay agree on the highlight (+13.3 vs +12.7 mean)
	but not the shadow (-9.0 vs -36.0). Figma's dark half is about a quarter as
	strong, and that is the whole reason its studs look smoothly integrated rather
	than punched into the surface. `--dark 0.25` reproduces it; `--strength 1.4` then
	restores the peaks lost to downscaling the tile in-engine.

	To add another: export the stud layer from Figma, run

	    python tools/stud_bake.py <export>.png -o <name>.png --preview

	upload the result, and add a row here with the stud count from the script's output.

	ALWAYS DRAW THESE UNTINTED AND FULLY OPAQUE. ImageColor3 multiplies, so a tint
	erases the black pixels and takes the shadow half of the emboss with them; the
	bake already carries its intended strength.
]]
export type StudSheet = {
	Image: string,
	-- Studs along one edge of the tile. Sheets are square, and this is what lets a
	-- caller size a tile for a consistent on-screen stud regardless of sheet density.
	Studs: number,
}

Theme.Stud = {
	Coarse = { Image = "rbxassetid://137757393342413", Studs = 4 } :: StudSheet,
	Fine = { Image = "rbxassetid://125545885010313", Studs = 2 } :: StudSheet,
}

-- Target on-screen size of one stud, in canvas px. Tile sizes are derived from this
-- and the sheet's stud count, so Coarse and Fine render studs at the same scale.
Theme.StudSize = 22

--[[
	Size one stud tile for a box, in canvas units.

	The ideal tile is StudSize * the sheet's stud count, which is what makes a stud
	come out the same size on screen whether the sheet packs 2 per tile or 4. That
	ideal is then snapped to a whole number of repeats per axis, so the field ends on
	the same phase it began on rather than being cut off mid-stud.

	Returns the tile plus the size the stud frame should be — rows/columns times the
	tile, not the raw box. Those differ by a pixel or two; centre the frame so the
	slack splits evenly and neither edge shows a seam.

	THE TILE COMES BACK IN SCALE, NOT OFFSET, AND THAT IS LOAD-BEARING. TileSize
	offsets are absolute screen pixels that UIScale does not touch, so on this kit's
	scaled canvas an offset tile keeps its screen size while the frame around it
	shrinks — at ~32% scale a 44px tile in a 28px-tall frame renders less than one
	row, and you see a cropped slice of each stud instead of a stud. Scale components
	are relative to the image's own size, so 1/columns by 1/rows holds at any scale.
]]
function Theme.studTile(sheet: StudSheet, boxWidth: number, boxHeight: number): (UDim2, Vector2)
	local ideal = Theme.StudSize * sheet.Studs
	local rows = math.max(1, math.round(boxHeight / ideal))
	local tileHeight = math.round(boxHeight / rows)
	local columns = math.max(1, math.round(boxWidth / tileHeight))
	local tileWidth = math.round(boxWidth / columns)
	return UDim2.fromScale(1 / columns, 1 / rows),
		Vector2.new(tileWidth * columns, tileHeight * rows)
end

-- Standalone artwork that is not part of a studded sandwich.
Theme.Image = {
	RobuxLarge = "rbxassetid://94215767275071",
	RobuxSmall = "rbxassetid://111376154180659",
	ShopHeaderBanner = "rbxassetid://108044249436351",
	ExitShadow = "rbxassetid://126664579001704",
	ExitStuds = "rbxassetid://95608878390357",
	PlusShadow = "rbxassetid://118834064364130",
	IconBasket = "rbxassetid://134650088524236",
	IconBook = "rbxassetid://132394357246332",
	IconRebirth = "rbxassetid://81152125966933",
	IconGear = "rbxassetid://101209905216967",
}

return Theme
