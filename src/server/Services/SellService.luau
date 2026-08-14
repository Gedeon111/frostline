--!strict
--[[
	RETIRED by D-017.

	Store revenue now flows through refrigerator reservations, RegisterService,
	an unclaimed-cash ledger, and CashPickupService. This module intentionally
	registers no RequestSell handler and awards no cash.
]]

local SellService = {}

function SellService.IsAtPad(_player: Player): boolean
	return false
end

function SellService.Sell(_player: Player): (boolean, string?)
	return false, "invalid_action"
end

function SellService.Init() end
function SellService.Start() end

return SellService
