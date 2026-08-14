--!strict
--[[
	CURRENCYBAR — bottom-left cash readout and its "+" button.

	The amount stays left-aligned (unlike the buttons, which centre) because a readout
	that recentres every time the player earns a digit is unreadable in motion.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages.React)

local Theme = require(script.Parent.Parent.Theme)
local StrokeText = require(script.Parent.Parent.Primitives.StrokeText)
local PlusButton = require(script.Parent.PlusButton)

export type Props = {
	Amount: string,
	Position: UDim2?,
	ZIndex: number?,
	OnPlusActivated: (() -> ())?,
}

local function CurrencyBar(props: Props)
	return React.createElement("Frame", {
		Size = UDim2.fromOffset(428, 78),
		Position = props.Position,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = props.ZIndex,
	}, {
		Amount = React.createElement(StrokeText, {
			Text = props.Amount,
			Style = Theme.Text.Cash,
			Size = UDim2.fromOffset(366, 78),
			XAlign = Enum.TextXAlignment.Left,
			ZIndex = 1,
		}),
		Plus = React.createElement(PlusButton, {
			Position = UDim2.fromOffset(385, 16),
			ZIndex = 2,
			OnActivated = props.OnPlusActivated,
		}),
	})
end

return CurrencyBar
