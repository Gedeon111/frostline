--!strict
--[[
	CARRYVISUALS — bounded cosmetic representation of authoritative carry state.
]]

return {
	AssetFolderName = "CarryRacks",
	MeatAssetFolderName = "Meat",
	RackThresholds = {
		{ minLevel = 1, modelName = "carrier_sticks_small" },
		{ minLevel = 4, modelName = "carrier_sticks_medium" },
		{ minLevel = 7, modelName = "carrier_sticks_large" },
		{ minLevel = 10, modelName = "carrier_sticks_max" },
	},
	VisualPieceCap = 18,
	Columns = 3,
	RowsPerLayer = 2,
	PieceSpacing = Vector3.new(1.4, 0.8, 1.1),
	StackBaseOffset = Vector3.new(0, 0.6, 0),
	MaxStackHeight = 12,
	TransferArcHeight = 6,
	TransferSeconds = 0.55,
	ReducedEffectPieceCap = 4,
}
