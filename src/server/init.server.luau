--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

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

-- A ponte de diagnóstico nunca existe em servidores publicados.
if RunService:IsStudio() then
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
			local player = args.Player
			local boxIndex = args.BoxIndex or 1
			local workspace = game:GetService("Workspace")
			local car = workspace:FindFirstChild(string.format("BoxCar_%d_%d", player.UserId, boxIndex))
				or workspace:FindFirstChild(string.format("TrainingCar_%d_%d", player.UserId, boxIndex))
			return if car and car:IsA("Model")
				then EconomyService.SimulatePartSold(player, car, args.PartId or "Trunk", 100)
				else false
		elseif action == "BuyCar" then
			local ok, message = AuctionTicketCatalogService.BuyCar(args.Player, args.BoxIndex, args.OfferId)
			return { Success = ok, Message = message }
		elseif action == "GetCatalog" then
			return AuctionTicketCatalogService.GetPlayerCatalog(args)
		elseif action == "RefreshCatalog" then
			AuctionTicketCatalogService.RefreshCatalog()
			return true
		elseif action == "GetMockData" then
			return PlayerDataService.GetStoredMockData(args)
		elseif action == "SetMockData" then
			PlayerDataService.SetStoredMockData(args.UserId, args.Data)
			return true
		end
		return nil
	end
	testingBridge.Parent = ServerScriptService
end
