--!strict
--[[
	UICONTROLLER — creates the ScreenGui and mounts the React tree into it.

	Follows the two-phase loader contract (ARCHITECTURE §2): no remote traffic in Init,
	everything real happens in Start.

	ZIndexBehavior is Sibling so ZIndex is scoped to each parent. The whole kit assumes
	it — a card's buy button is ZIndex 2 inside that card, not 2 across the entire
	screen. Under the Global behaviour every layer would fight every other layer.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages.React)
local ReactRoblox = require(Packages.ReactRoblox)

local Log = require(ReplicatedStorage:WaitForChild("Shared").Util.Log)

local UI = script.Parent.Parent:WaitForChild("UI")
local App = require(UI.App)

local UIController = {}

local root: any = nil
local screenGui: ScreenGui? = nil

function UIController.Init() end

function UIController.Start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = "Frostline"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui
	screenGui = gui

	root = ReactRoblox.createRoot(gui)
	root:render(React.createElement(App, {}))

	Log.info("ui", "mounted")
end

function UIController.Stop()
	if root then
		root:unmount()
		root = nil
	end
	if screenGui then
		screenGui:Destroy()
		screenGui = nil
	end
end

return UIController
