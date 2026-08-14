--!strict
--[[
	SHOPPANEL — the full shop dialog.

	CHROME MODEL. The panel is one rectangle with a single black outline round the
	whole of it — top bar and body together — and black separators dividing it into
	cells. Every black line in the panel is `OUTLINE` thick and comes from exactly one
	element, so nothing can double up:

	    ┌──────────────────┬──────┐
	    │ SHOP!            │  X   │   <- two top-bar cells, split by SepV
	    ├──────────────────┴──────┤   <- SepH
	    │ body                    │
	    └─────────────────────────┘   <- Outline, drawn once, around everything

	This replaces the earlier arrangement where the bar came from a banner PNG with a
	black edge baked in, the close button was a ChunkyButton carrying its own stroke,
	and the body had a third stroke of its own. Three independent outlines meeting at
	one seam is what produced the doubled divider and the bar that would not sit level
	with the body — there was no single edge to align to. So the cells here are flat
	gradient fills with no baked chrome, and all the black is drawn on top of them.

	Colours are the SVG's body gradients (`Slide 16_9 - 1.svg`); the close cell reuses
	the exit button's own gradient and dark base from the export.

	The card row is a UIListLayout rather than the exported absolute positions
	(x = 0, 280, 559 for cards 255, 255 and 253 wide). Those gaps were 25 and 24 px for
	no reason anyone chose, and hardcoding three x values means the row cannot take a
	fourth product without a designer reopening Figma.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages.React)

local Theme = require(script.Parent.Parent.Theme)
local StrokeText = require(script.Parent.Parent.Primitives.StrokeText)
local HeroOffer = require(script.Parent.Parent.Components.HeroOffer)
local ProductCard = require(script.Parent.Parent.Components.ProductCard)

local PANEL_SIZE = Vector2.new(874, 788)

-- One weight for the panel outline and both separators.
local OUTLINE = 5
-- Top bar, measured above the separator rather than including it.
local HEADER_HEIGHT = 113
-- Right-hand cell of the top bar.
local CLOSE_WIDTH = 105
-- Left cell takes whatever is left once the separator and close cell are removed.
local TITLE_WIDTH = PANEL_SIZE.X - CLOSE_WIDTH - OUTLINE
-- Body starts below the separator. Lands on 118, which is where the export put the
-- scrim — the gap the export left under the header was this divider all along.
local BODY_TOP = HEADER_HEIGHT + OUTLINE
-- Darker band along the bottom of each top-bar cell, the "chunky" lip.
local LIP = 12
-- Lighter inline that hugs the inside of the black, the way the bundle's gold rim
-- does. Sits in the band OUTLINE..OUTLINE+RIM measured in from each cell edge.
local RIM = 4
-- Gap between the rim and the stud field. Zero: the studs run right up to the
-- highlight. Kept as a constant because it feeds the stud box height and tile
-- calibration below, so it is the one knob if the field ever needs pulling in.
local STUD_PAD = 0

-- Chrome eating into the cell vertically: the outline above, the lip and the outline
-- below. What is left is the face — the lit, studded part of the bar.
local FACE_TRIM = OUTLINE * 2 + LIP
-- The stud field, once the rim and its padding are taken off the face as well.
local STUD_BOX = BODY_TOP - FACE_TRIM - (RIM + STUD_PAD) * 2

local CARD_GAP = 25

local HEADER_GRADIENT = ColorSequence.new(Color3.fromHex("#22E9FF"), Color3.fromHex("#0095FF"))
local HEADER_LIP = Color3.fromHex("#0077CC")
local HEADER_RIM = Color3.fromHex("#59E6FF")

local CLOSE_GRADIENT = ColorSequence.new(Color3.fromHex("#FF6363"), Color3.fromHex("#FF2C2C"))
local CLOSE_LIP = Color3.fromHex("#8E1A1A")
local CLOSE_RIM = Color3.fromHex("#FF8181")

export type Product = {
	Title: string,
	Price: string,
	OnActivated: (() -> ())?,
}

export type Props = {
	Visible: boolean?,
	Position: UDim2?,
	Hero: {
		Title: string,
		Description: { string },
		Price: string,
		OnActivated: (() -> ())?,
	},
	Products: { Product },
	OnClose: (() -> ())?,
}

type CellSpec = {
	Position: UDim2,
	Size: UDim2,
	Gradient: ColorSequence,
	Lip: Color3,
	Rim: Color3,
	Stud: Theme.StudSheet,
	ZIndex: number,
	OnActivated: (() -> ())?,
	Label: any,
}

--[[
	One cell of the top bar: gradient fill, tiled stud texture, lighter inline rim,
	darker lip, label. No black of its own — the panel outline and the separators
	supply every black edge.

	Each cell is sized to run OUTLINE past its visible bounds on all four sides, so
	the black always overlaps it rather than merely abutting it. That is what lets the
	rim be a single uniform inset: without the overlap, the rim would hug the black on
	the sides the panel outline covers and float OUTLINE short of it on the sides a
	separator only touches.
]]
local function cell(spec: CellSpec)
	local className = if spec.OnActivated then "ImageButton" else "Frame"
	local rimInset = OUTLINE + RIM
	local studInset = rimInset + STUD_PAD
	local tile, studFrame = Theme.studTile(spec.Stud, spec.Size.X.Offset - studInset * 2, STUD_BOX)

	return React.createElement(className, {
		Image = if spec.OnActivated then "" else nil,
		AutoButtonColor = if spec.OnActivated then false else nil,
		[React.Event.Activated] = spec.OnActivated,

		Position = spec.Position,
		Size = spec.Size,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = spec.ZIndex,
	}, {
		Gradient = React.createElement("UIGradient", {
			Color = spec.Gradient,
			Rotation = 90,
		}),
		--[[
			Sits inside the rim by STUD_PAD, and stops short of the lip, so the stud
			field never runs into either. Centred, because studWidth is a whole number
			of tiles and so misses the box by a pixel or two.

			Untinted and fully opaque: the sheet already carries the Figma blend stack,
			and its black pixels are load-bearing. Tinting would multiply them away and
			take the shadow half of the emboss with it.
		]]
		Studs = React.createElement("ImageLabel", {
			Image = spec.Stud.Image,
			Position = UDim2.new(
				0.5,
				-studFrame.X // 2,
				0,
				studInset + (STUD_BOX - studFrame.Y) // 2
			),
			Size = UDim2.fromOffset(studFrame.X, studFrame.Y),
			ScaleType = Enum.ScaleType.Tile,
			TileSize = tile,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 1,
		}),
		--[[
			The lit half. Sits above the studs so it lifts the texture and the colour
			together rather than only the fill, which is how the bundle and the product
			cards read — a broad diagonal wedge, brighter under the text and buttons,
			falling off at a hard seam.

			Same ramp as Theme.Gloss, which the Studded surfaces use, so the top bar and
			the panels below it catch the light in the same place.
		]]
		Gloss = React.createElement("Frame", {
			Position = UDim2.fromOffset(OUTLINE, OUTLINE),
			Size = UDim2.new(1, -OUTLINE * 2, 1, -(OUTLINE * 2 + LIP)),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			ZIndex = 2,
		}, {
			Gradient = React.createElement("UIGradient", {
				Rotation = Theme.Gloss.Rotation,
				Transparency = Theme.Gloss.Transparency,
			}),
		}),
		--[[
			Encloses the face, not the whole cell. Inset by OUTLINE + RIM on the sides
			so the outward Border stroke lands immediately inside the black, and its
			bottom stops a lip's height early — which puts the rim's bottom run between
			the lip and the face rather than buried under the lip.
		]]
		Rim = React.createElement("Frame", {
			Position = UDim2.fromOffset(rimInset, rimInset),
			Size = UDim2.new(1, -rimInset * 2, 1, -(FACE_TRIM + RIM * 2)),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 3,
		}, {
			Stroke = React.createElement("UIStroke", {
				Color = spec.Rim,
				Thickness = RIM,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				LineJoinMode = Enum.LineJoinMode.Miter,
			}),
		}),
		Lip = React.createElement("Frame", {
			Size = UDim2.new(1, 0, 0, LIP),
			Position = UDim2.new(0, 0, 1, -(LIP + OUTLINE)),
			BackgroundColor3 = spec.Lip,
			BorderSizePixel = 0,
			ZIndex = 4,
		}),
		Label = spec.Label,
	})
end

local function separator(position: UDim2, size: UDim2)
	return React.createElement("Frame", {
		Position = position,
		Size = size,
		BackgroundColor3 = Theme.Color.Stroke,
		BorderSizePixel = 0,
		ZIndex = 5,
	})
end

local function ShopPanel(props: Props)
	local cards: { [any]: any } = {
		Layout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, CARD_GAP),
		}),
	}

	for index, product in ipairs(props.Products) do
		cards["Product" .. index] = React.createElement(ProductCard, {
			Title = product.Title,
			Price = product.Price,
			LayoutOrder = index,
			OnActivated = product.OnActivated,
		})
	end

	return React.createElement("Frame", {
		Size = UDim2.fromOffset(PANEL_SIZE.X, PANEL_SIZE.Y),
		Position = props.Position,
		Visible = props.Visible,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, {
		-- Runs up under SepH, so the divider overlaps the body rather than abutting it.
		Body = React.createElement("Frame", {
			Position = UDim2.fromOffset(0, HEADER_HEIGHT),
			Size = UDim2.fromOffset(PANEL_SIZE.X, PANEL_SIZE.Y - HEADER_HEIGHT),
			BackgroundColor3 = Theme.Color.Scrim,
			BackgroundTransparency = 0.5,
			BorderSizePixel = 0,
			ZIndex = 1,
		}),

		TitleCell = cell({
			Position = UDim2.fromOffset(0, 0),
			Size = UDim2.fromOffset(TITLE_WIDTH + OUTLINE, BODY_TOP),
			Gradient = HEADER_GRADIENT,
			Lip = HEADER_LIP,
			Rim = HEADER_RIM,
			Stud = Theme.Stud.Coarse,
			ZIndex = 2,
			Label = React.createElement(StrokeText, {
				Text = "SHOP!",
				Style = Theme.Text.Title,
				Size = UDim2.fromOffset(215, 78),
				Position = UDim2.fromOffset(24, 11),
				XAlign = Enum.TextXAlignment.Left,
				ZIndex = 5,
			}),
		}),

		-- Starts at TITLE_WIDTH so it passes under SepV. The black covers OUTLINE on
		-- its left (the separator) and OUTLINE on its right (the panel outline), so it
		-- stays symmetrical and the X still centres on the visible red.
		CloseCell = cell({
			Position = UDim2.fromOffset(TITLE_WIDTH, 0),
			Size = UDim2.fromOffset(CLOSE_WIDTH + OUTLINE, BODY_TOP),
			Gradient = CLOSE_GRADIENT,
			Lip = CLOSE_LIP,
			Rim = CLOSE_RIM,
			ZIndex = 2,
			Stud = Theme.Stud.Coarse,
			OnActivated = props.OnClose,
			Label = React.createElement(StrokeText, {
				Text = "X",
				Style = Theme.Text.Title,
				Size = UDim2.new(1, 0, 0, 78),
				Position = UDim2.fromOffset(0, 11),
				ZIndex = 5,
			}),
		}),

		Hero = React.createElement(HeroOffer, {
			Title = props.Hero.Title,
			Description = props.Hero.Description,
			Price = props.Hero.Price,
			Position = UDim2.new(0.5, 0, 0, 148),
			AnchorPoint = Vector2.new(0.5, 0),
			ZIndex = 3,
			OnActivated = props.Hero.OnActivated,
		}),

		Products = React.createElement("Frame", {
			Size = UDim2.fromOffset(812, 323),
			Position = UDim2.new(0.5, 0, 0, 433),
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 4,
		}, cards),

		-- Between the top bar and the body.
		SepH = separator(
			UDim2.fromOffset(0, HEADER_HEIGHT),
			UDim2.fromOffset(PANEL_SIZE.X, OUTLINE)
		),
		-- Between the title cell and the close cell.
		SepV = separator(
			UDim2.fromOffset(TITLE_WIDTH, 0),
			UDim2.fromOffset(OUTLINE, HEADER_HEIGHT)
		),

		--[[
			The one outline. Inset by its own thickness because a Roblox Border stroke
			renders wholly outside its frame — inset, the stroke's outer edge lands
			exactly on the panel bounds instead of growing past them. Drawn last so it
			sits over the cells it borders.
		]]
		Outline = React.createElement("Frame", {
			Position = UDim2.fromOffset(OUTLINE, OUTLINE),
			Size = UDim2.fromOffset(PANEL_SIZE.X - OUTLINE * 2, PANEL_SIZE.Y - OUTLINE * 2),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 6,
		}, {
			Stroke = React.createElement("UIStroke", {
				Color = Theme.Color.Stroke,
				Thickness = OUTLINE,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				LineJoinMode = Enum.LineJoinMode.Miter,
			}),
		}),
	})
end

return ShopPanel
