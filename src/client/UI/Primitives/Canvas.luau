--!strict
--[[
	CANVAS — fixed design canvas with uniform scaling.

	The Figma frame is 1920x1081 and every position in this kit is an absolute offset
	inside it. Rather than rewrite four hundred numbers as scale values, the whole
	canvas is one fixed-size Frame scaled by a single UIScale — which is what FigBlox
	itself did, except it baked in `Scale = 0.3719`, the value that happened to fit the
	Studio viewport the day of the export. On a real screen that is simply wrong.

	Here the scale is recomputed from the available space, so the layout is identical
	on a 1080p monitor and a phone. `math.min` on both axes letterboxes rather than
	stretches; the alternative distorts the studs.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages.React)

local Theme = require(script.Parent.Parent.Theme)

export type Props = {
	children: any?,
}

local function Canvas(props: Props)
	local viewportRef = React.useRef(nil :: Frame?)
	local scale, setScale = React.useState(1)

	React.useEffect(function()
		local viewport = viewportRef.current
		if not viewport then
			return
		end

		local function update()
			local available = viewport.AbsoluteSize
			if available.X <= 0 or available.Y <= 0 then
				return
			end
			setScale(math.min(available.X / Theme.CanvasSize.X, available.Y / Theme.CanvasSize.Y))
		end

		update()
		local connection = viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(update)
		return function()
			connection:Disconnect()
		end
	end, {})

	return React.createElement("Frame", {
		ref = viewportRef,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, {
		Canvas = React.createElement("Frame", {
			Size = UDim2.fromOffset(Theme.CanvasSize.X, Theme.CanvasSize.Y),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, {
			Scale = React.createElement("UIScale", { Scale = scale }),
			Content = React.createElement(React.Fragment, nil, props.children),
		}),
	})
end

return Canvas
