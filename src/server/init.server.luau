--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local RecyclingCenterService = require(ServerScriptService.Server.RecyclingCenterService)
local EconomyService = require(ServerScriptService.Server.EconomyService)
local PlayerDataService = require(ServerScriptService.Server.PlayerDataService)
local PlayerSafetyService = require(ServerScriptService.Server.PlayerSafetyService)
local PlotService = require(ServerScriptService.Server.PlotService)
local CarLifecycleService = require(ServerScriptService.Server.CarLifecycleService)
local ToolUpgradeService = require(ServerScriptService.Server.ToolUpgradeService)
local SpeedUpgradeService = require(ServerScriptService.Server.SpeedUpgradeService)
local AuctionTicketCatalogService = require(ServerScriptService.Server.AuctionTicketCatalogService)

RecyclingCenterService.start()
EconomyService.start()
PlayerDataService.start()
PlayerSafetyService.start()
ToolUpgradeService.start()
SpeedUpgradeService.start()
PlotService.start()
CarLifecycleService.start()
AuctionTicketCatalogService.start()

-- Bridge interna para testes automatizados e verificação de integridade no Studio
local testingBridge = Instance.new("BindableFunction")
testingBridge.Name = "ServerTestingBridge"
testingBridge.OnInvoke = function(action: string, args: any)
	if action == "SavePlayer" then
		return PlayerDataService.SavePlayer(args)
	elseif action == "LoadPlayer" then
		PlayerDataService.LoadPlayer(args)
		return true
	elseif action == "SerializeBoxCars" then
		return CarLifecycleService.SerializeBoxCars(args)
	elseif action == "GetBoxSlot" then
		return CarLifecycleService.GetBoxSlot(args.Player, args.BoxIndex)
	elseif action == "SimulatePartSold" then
		local p = args.Player
		local car = game:GetService("Workspace"):FindFirstChild(string.format("BoxCar_%d_%d", p.UserId, args.BoxIndex or 1))
			or game:GetService("Workspace"):FindFirstChild(string.format("TrainingCar_%d_%d", p.UserId, args.BoxIndex or 1))
		if car then
			EconomyService.SimulatePartSold(p, car, args.PartId or "Trunk", 100)
			return true
		end
		return false
	elseif action == "BuyCar" then
		local ok, msg = AuctionTicketCatalogService.BuyCar(args.Player, args.BoxIndex, args.OfferId)
		return { Success = ok, Message = msg }
	elseif action == "GetCatalog" then
		return AuctionTicketCatalogService.GetPlayerCatalog(args)
	elseif action == "RefreshCatalog" then
		AuctionTicketCatalogService.RefreshCatalog()
		return true
	end
	return nil
end
testingBridge.Parent = ServerScriptService
