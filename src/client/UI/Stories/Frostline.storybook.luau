--!strict
--[[
	STORYBOOK — entry point UI Labs scans for.

	UI Labs walks the game tree looking for ModuleScripts whose name ends in
	".storybook", then searches each `storyRoots` entry for ModuleScripts ending in
	".story". Rojo turns `Frostline.storybook.luau` into a ModuleScript named
	"Frostline.storybook", which is exactly what that matcher wants.

	Nothing requires this file at runtime, so it costs the shipped place one unused
	module and nothing else.
]]

return {
	name = "FROSTLINE",
	storyRoots = { script.Parent },
}
