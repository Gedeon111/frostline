--!strict
--[[
	HUD — the always-on layer: top button bar, left rail, cash readout.

	The top bar is a list layout. The export gave the three buttons x = 0, 290 and 610
	with LayoutOrder 0, 1 and 2 — an order that does not match their positions, because
	FigBlox writes LayoutOrder from the Figma z-stack, not from left to right. Reading
	the x values instead: Sell, Base, Shop.

	The left rail keeps absolute positions. It is a bespoke five-element arrangement —
	one full-width toggle over a 2x2 grid — and expressing that as nested layouts would
	be more machinery than the thing it lays out.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages.React)

local Theme = require(script.Parent.Parent.Theme)
local PillButton = require(script.Parent.Parent.Components.PillButton)
local IconButton = require(script.Parent.Parent.Components.IconButton)
local WideToggle = require(script.Parent.Parent.Components.WideToggle)
local CurrencyBar = require(script.Parent.Parent.Components.CurrencyBar)

local TOP_BAR_GAP = 23
local RAIL_COLUMN = 151
local RAIL_ROW_ONE = 102
local RAIL_ROW_TWO = 261

export type Handlers = {
	OnSell: (() -> ())?,
	OnBase: (() -> ())?,
	OnShop: (() -> ())?,
	OnRobuxShop: (() -> ())?,
	OnIndex: (() -> ())?,
	OnRebirth: (() -> ())?,
	OnSettings: (() -> ())?,
	OnSlowMode: (() -> ())?,
	OnPlus: (() -> ())?,
}

export type Props = {
	Cash: string,
	SlowMode: boolean,
	Handlers: Handlers,
}

local function Hud(props: Props)
	local handlers = props.Handlers

	return React.createElement("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, {
		TopButtons = React.createElement("Frame", {
			Size = UDim2.fromOffset(877, 78),
			Position = UDim2.fromOffset(522, 22),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 1,
		}, {
			Layout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, TOP_BAR_GAP),
			}),
			Sell = React.createElement(PillButton, {
				Text = "Sell",
				Skin = Theme.Skin.Sell,
				LayoutOrder = 1,
				OnActivated = handlers.OnSell,
			}),
			Base = React.createElement(PillButton, {
				Text = "Base",
				Skin = Theme.Skin.Base,
				Wide = true,
				LayoutOrder = 2,
				OnActivated = handlers.OnBase,
			}),
			Shop = React.createElement(PillButton, {
				Text = "Shop",
				Skin = Theme.Skin.Shop,
				LayoutOrder = 3,
				OnActivated = handlers.OnShop,
			}),
		}),

		LeftRail = React.createElement("Frame", {
			Size = UDim2.fromOffset(282, 406),
			Position = UDim2.fromOffset(40, 333),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 2,
		}, {
			SlowMode = React.createElement(WideToggle, {
				Text = if props.SlowMode then "Slow mode: ON" else "Slow mode: OFF",
				Skin = Theme.Skin.SlowMode,
				Position = UDim2.fromOffset(0, 0),
				ZIndex = 1,
				OnActivated = handlers.OnSlowMode,
			}),
			RobuxShop = React.createElement(IconButton, {
				Caption = "Shop",
				Skin = Theme.Skin.RobuxShop,
				Icon = Theme.Image.IconBasket,
				IconSize = Vector2.new(110, 110),
				Position = UDim2.fromOffset(0, RAIL_ROW_ONE),
				ZIndex = 2,
				OnActivated = handlers.OnRobuxShop,
			}),
			Rebirth = React.createElement(IconButton, {
				Caption = "Rebirth",
				Skin = Theme.Skin.Rebirth,
				Icon = Theme.Image.IconRebirth,
				IconSize = Vector2.new(99, 97),
				Position = UDim2.fromOffset(RAIL_COLUMN, RAIL_ROW_ONE),
				ZIndex = 3,
				OnActivated = handlers.OnRebirth,
			}),
			Index = React.createElement(IconButton, {
				Caption = "Index",
				Skin = Theme.Skin.Index,
				Icon = Theme.Image.IconBook,
				IconSize = Vector2.new(91, 94),
				Position = UDim2.fromOffset(0, RAIL_ROW_TWO),
				ZIndex = 4,
				OnActivated = handlers.OnIndex,
			}),
			Settings = React.createElement(IconButton, {
				Caption = "Settings",
				Skin = Theme.Skin.Settings,
				Icon = Theme.Image.IconGear,
				IconSize = Vector2.new(97, 97),
				Position = UDim2.fromOffset(RAIL_COLUMN, RAIL_ROW_TWO),
				ZIndex = 5,
				OnActivated = handlers.OnSettings,
			}),
		}),

		Currency = React.createElement(CurrencyBar, {
			Amount = props.Cash,
			Position = UDim2.fromOffset(24, 992),
			ZIndex = 3,
			OnPlusActivated = handlers.OnPlus,
		}),
	})
end

return Hud
