--!strict
--[[
	APP — the root element. Owns which screens are open.

	Data is still placeholder. The values below are the ones baked into the Figma mock
	($9,999,999, "+50 Cash", 999 Robux); binding them to real state is job B1, which
	feeds `Cash` and `SlowMode` in from State.Observe. Everything under here already
	takes its content as props, so that change lands in this file and nowhere else.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages.React)

local Canvas = require(script.Parent.Primitives.Canvas)
local Hud = require(script.Parent.Screens.Hud)
local ShopPanel = require(script.Parent.Screens.ShopPanel)

export type Props = {
	Cash: string?,
}

local function App(props: Props)
	local shopOpen, setShopOpen = React.useState(false)
	local slowMode, setSlowMode = React.useState(true)

	return React.createElement(Canvas, nil, {
		Hud = React.createElement(Hud, {
			Cash = props.Cash or "$9,999,999",
			SlowMode = slowMode,
			Handlers = {
				OnShop = function()
					setShopOpen(true)
				end,
				OnRobuxShop = function()
					setShopOpen(true)
				end,
				OnPlus = function()
					setShopOpen(true)
				end,
				OnSlowMode = function()
					setSlowMode(function(current)
						return not current
					end)
				end,
			},
		}),

		Shop = React.createElement(ShopPanel, {
			Visible = shopOpen,
			Position = UDim2.fromOffset(522, 167),
			Hero = {
				Title = "BUNDLE",
				Description = { "Short Description", "Short Description" },
				Price = "999",
			},
			Products = {
				{ Title = "+50 Cash", Price = "999" },
				{ Title = "+50 Cash", Price = "999" },
				{ Title = "+50 Cash", Price = "999" },
			},
			OnClose = function()
				setShopOpen(false)
			end,
		}),
	})
end

return App
