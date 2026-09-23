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
		elseif action == "RunMultiplayerTest" then
			local p1 = Players:GetPlayers()[1]
			if not p1 then return { Success = false, Error = "No Player 1" } end

			AuctionTicketCatalogService.RefreshCatalog()

			p1:SetAttribute("AuctionTickets", 15)
			local ls1 = p1:FindFirstChild("leaderstats")
			local t1 = ls1 and ls1:FindFirstChild("Tickets")
			if t1 and t1:IsA("IntValue") then t1.Value = 15 end

			local p2Attributes: {[string]: any} = {
				DataLoaded = true,
				DataLoadFailed = false,
				UnlockedBoxes = 1,
				AuctionTickets = 15,
			}
			local ls2 = Instance.new("Folder")
			ls2.Name = "leaderstats"
			local t2 = Instance.new("IntValue")
			t2.Name = "Tickets"
			t2.Value = 15
			t2.Parent = ls2

			local p2 = {
				Name = "Player_Two",
				DisplayName = "Player_Two",
				UserId = 88888888,
				Parent = Players,
				Character = nil,
				FindFirstChild = function(_self, name)
					if name == "leaderstats" then return ls2 end
					return nil
				end,
				GetAttribute = function(_self, attr)
					return p2Attributes[attr]
				end,
				SetAttribute = function(_self, attr, val)
					p2Attributes[attr] = val
				end,
				GetAttributeChangedSignal = function(_self, _attr)
					return Instance.new("BindableEvent").Event
				end,
			}

			local cat1 = AuctionTicketCatalogService.GetPlayerCatalog(p1)
			local cat2 = AuctionTicketCatalogService.GetPlayerCatalog(p2 :: any)

			local sameOffersCount = #cat1.Offers == 5 and #cat2.Offers == 5
			local allFiveOffersIdentical = true
			for i = 1, 5 do
				if cat1.Offers[i].OfferId ~= cat2.Offers[i].OfferId then
					allFiveOffersIdentical = false
				end
			end

			local targetOffer = cat1.Offers[1]
			local targetOfferId = targetOffer.OfferId

			local buy1Ok, buy1Msg = AuctionTicketCatalogService.BuyCar(p1, 1, targetOfferId)
			local buy1RepeatOk, buy1RepeatMsg = AuctionTicketCatalogService.BuyCar(p1, 1, targetOfferId)

			local cat2After = AuctionTicketCatalogService.GetPlayerCatalog(p2 :: any)
			local offerStillInCatalogForP2 = false
			for _, off in cat2After.Offers do
				if off.OfferId == targetOfferId then
					offerStillInCatalogForP2 = true
					break
				end
			end
			local isMarkedPurchasedForP2 = cat2After.PurchasedOffers[targetOfferId] == true

			local buy2Ok, buy2Msg = AuctionTicketCatalogService.BuyCar(p2 :: any, 1, targetOfferId)
			local buy2RepeatOk, buy2RepeatMsg = AuctionTicketCatalogService.BuyCar(p2 :: any, 1, targetOfferId)

			-- Teste de isolamento de peças entre jogadores
			local p1Car = game:GetService("Workspace"):FindFirstChild(string.format("BoxCar_%d_1", p1.UserId))
			local p1CarHood = p1Car and p1Car:FindFirstChild("Hood")
			local p1HoodOwner = p1CarHood and p1CarHood:GetAttribute("OwnerUserId")
			local p2CannotTriggerP1Part = p1HoodOwner == p1.UserId and p1HoodOwner ~= p2.UserId

			return {
				Success = true,
				sameOffersCount = sameOffersCount,
				allFiveOffersIdentical = allFiveOffersIdentical,
				targetOfferName = targetOffer.DisplayName,
				targetOfferCost = targetOffer.TicketCost,
				player1 = {
					FirstBuyOk = buy1Ok,
					FirstBuyMsg = buy1Msg,
					RepeatBuyOk = buy1RepeatOk,
					RepeatBuyMsg = buy1RepeatMsg,
					TicketsRemaining = p1:GetAttribute("AuctionTickets"),
				},
				player2 = {
					OfferStillAvailableInCatalog = offerStillInCatalogForP2,
					IsMarkedPurchasedBeforeBuy = isMarkedPurchasedForP2,
					BuyOk = buy2Ok,
					BuyMsg = buy2Msg,
					RepeatBuyOk = buy2RepeatOk,
					RepeatBuyMsg = buy2RepeatMsg,
					TicketsRemaining = p2Attributes.AuctionTickets,
				},
				isolation = {
					P1CarOwnerUserId = p1.UserId,
					P2UserId = p2.UserId,
					P1PartProtectedFromP2 = p2CannotTriggerP1Part,
				}
			}
		end
		return nil
	end
	testingBridge.Parent = ServerScriptService
end
