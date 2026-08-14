--!strict
--[[
	The whole client UI, wired. Clicking Shop, the Robux basket or the "+" opens the
	shop panel; the X closes it; Slow mode toggles.

	This is the story that earns the port: none of the exported Frames were clickable,
	so before this the only way to see the shop open was to build and playtest.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages.React)
local ReactRoblox = require(Packages.ReactRoblox)

local App = require(script.Parent.Parent.App)

return {
	react = React,
	reactRoblox = ReactRoblox,
	controls = {
		Cash = "$9,999,999",
	},
	story = function(props)
		return React.createElement(App, {
			Cash = props.controls.Cash,
		})
	end,
}
