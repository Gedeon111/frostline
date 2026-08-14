--!strict
--[[
	The HUD at full canvas scale. Resize the UI Labs preview pane and the layout should
	track it without reflowing — that is the check Canvas.luau exists to pass.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages.React)
local ReactRoblox = require(Packages.ReactRoblox)

local UI = script.Parent.Parent
local Canvas = require(UI.Primitives.Canvas)
local Hud = require(UI.Screens.Hud)

return {
	react = React,
	reactRoblox = ReactRoblox,
	controls = {
		Cash = "$9,999,999",
		SlowMode = true,
	},
	story = function(props)
		local controls = props.controls

		return React.createElement(Canvas, nil, {
			Hud = React.createElement(Hud, {
				Cash = controls.Cash,
				SlowMode = controls.SlowMode,
				Handlers = {},
			}),
		})
	end,
}
