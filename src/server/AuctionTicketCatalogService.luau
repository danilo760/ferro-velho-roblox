--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local AuctionCatalog = require(ReplicatedStorage.Shared.AuctionCatalog)
local EconomyService = require(ServerScriptService.Server.EconomyService)
local CarLifecycleService = require(ServerScriptService.Server.CarLifecycleService)

local AuctionTicketCatalogService = {}

local CATALOG_REFRESH_INTERVAL = 300 -- 5 minutos
local nextRefreshTime = os.time() + CATALOG_REFRESH_INTERVAL
local playerCatalogs: {[number]: {AuctionCatalog.CatalogOffer}} = {}

local getCatalogRemote: RemoteFunction
local buyCarRemote: RemoteFunction
local catalogRefreshedRemote: RemoteEvent

local function ensureRemotes()
	local existingGet = ReplicatedStorage:FindFirstChild("GetAuctionCatalog")
	if existingGet and existingGet:IsA("RemoteFunction") then
		getCatalogRemote = existingGet
	else
		getCatalogRemote = Instance.new("RemoteFunction")
		getCatalogRemote.Name = "GetAuctionCatalog"
		getCatalogRemote.Parent = ReplicatedStorage
	end

	local existingBuy = ReplicatedStorage:FindFirstChild("BuyAuctionCatalogCar")
	if existingBuy and existingBuy:IsA("RemoteFunction") then
		buyCarRemote = existingBuy
	else
		buyCarRemote = Instance.new("RemoteFunction")
		buyCarRemote.Name = "BuyAuctionCatalogCar"
		buyCarRemote.Parent = ReplicatedStorage
	end

	local existingEvent = ReplicatedStorage:FindFirstChild("AuctionCatalogRefreshed")
	if existingEvent and existingEvent:IsA("RemoteEvent") then
		catalogRefreshedRemote = existingEvent
	else
		catalogRefreshedRemote = Instance.new("RemoteEvent")
		catalogRefreshedRemote.Name = "AuctionCatalogRefreshed"
		catalogRefreshedRemote.Parent = ReplicatedStorage
	end
end

local function refreshCatalogForPlayer(player: Player)
	playerCatalogs[player.UserId] = AuctionCatalog.GenerateCatalog()
end

local function refreshAllCatalogs()
	nextRefreshTime = os.time() + CATALOG_REFRESH_INTERVAL
	for _, player in Players:GetPlayers() do
		refreshCatalogForPlayer(player)
	end
	if catalogRefreshedRemote then
		catalogRefreshedRemote:FireAllClients(nextRefreshTime)
	end
end

function AuctionTicketCatalogService.GetPlayerCatalog(player: Player): {
	Offers: {AuctionCatalog.CatalogOffer},
	TimeRemaining: number,
	Tickets: number,
}
	if not playerCatalogs[player.UserId] then
		refreshCatalogForPlayer(player)
	end

	local remaining = math.max(0, nextRefreshTime - os.time())
	local tickets = EconomyService.GetTickets(player)

	return {
		Offers = playerCatalogs[player.UserId],
		TimeRemaining = remaining,
		Tickets = tickets,
	}
end

function AuctionTicketCatalogService.BuyCar(player: Player, targetBoxIndex: number, offerId: string): (boolean, string)
	if typeof(targetBoxIndex) ~= "number" or targetBoxIndex ~= targetBoxIndex or targetBoxIndex < 1 or targetBoxIndex > 3 or targetBoxIndex % 1 ~= 0 then
		return false, "Box inválido."
	end

	if typeof(offerId) ~= "string" or #offerId == 0 then
		return false, "Identificador de oferta inválido."
	end

	local unlocked = player:GetAttribute("UnlockedBoxes")
	local maxUnlocked = if typeof(unlocked) == "number" then math.clamp(unlocked, 1, 3) else 1
	if targetBoxIndex > maxUnlocked then
		return false, string.format("O Box %d ainda está bloqueado! Desbloqueie-o primeiro.", targetBoxIndex)
	end

	local catalog = playerCatalogs[player.UserId]
	if not catalog then
		return false, "Catálogo não carregado para seu jogador."
	end

	local targetOffer: AuctionCatalog.CatalogOffer? = nil
	local offerIndex: number? = nil
	for idx, offer in catalog do
		if offer.OfferId == offerId then
			targetOffer = offer
			offerIndex = idx
			break
		end
	end

	if not targetOffer or not offerIndex then
		return false, "Esta oferta já foi adquirida ou expirou."
	end

	local currentTickets = EconomyService.GetTickets(player)
	if currentTickets < targetOffer.TicketCost then
		return false, string.format("Saldo de Tickets insuficiente! Você possui %d e o veículo requer %d Tickets.", currentTickets, targetOffer.TicketCost)
	end

	-- Debitar tickets
	local deducted = EconomyService.DeductTickets(player, targetOffer.TicketCost)
	if not deducted then
		return false, "Falha na transação de Tickets."
	end

	-- Remover oferta adquirida da lista do jogador
	table.remove(catalog, offerIndex)

	-- Montar configuração de permanência para o Box
	local carConfig: CarLifecycleService.BoxCarConfig = {
		ModelId = targetOffer.ModelId,
		DisplayName = string.format("%s (%s)", targetOffer.DisplayName, targetOffer.Conservation.Name),
		ScrapMultiplier = targetOffer.ScrapMultiplier,
		InstalledParts = targetOffer.InstalledParts,
		BodyColor = targetOffer.BodyColor,
		AccentColor = targetOffer.AccentColor,
		ConservationName = targetOffer.Conservation.Name,
	}

	local assignResult = CarLifecycleService.AssignCarToBox(player, targetBoxIndex, carConfig)

	if assignResult == "QueuedPending" then
		return true, string.format("✅ Compra confirmada! Como o Box %d está em desmontagem, o novo veículo (%s) entrará automaticamente na fila pendente.", targetBoxIndex, carConfig.DisplayName)
	else
		return true, string.format("✅ Veículo entregue! O %s agora é o veículo permanente do seu Box %d.", carConfig.DisplayName, targetBoxIndex)
	end
end

function AuctionTicketCatalogService.start()
	ensureRemotes()

	getCatalogRemote.OnServerInvoke = function(player: Player)
		return AuctionTicketCatalogService.GetPlayerCatalog(player)
	end

	buyCarRemote.OnServerInvoke = function(player: Player, targetBoxIndex: any, offerId: any)
		return AuctionTicketCatalogService.BuyCar(player, targetBoxIndex, offerId)
	end

	Players.PlayerAdded:Connect(function(player)
		refreshCatalogForPlayer(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		playerCatalogs[player.UserId] = nil
	end)

	for _, player in Players:GetPlayers() do
		refreshCatalogForPlayer(player)
	end

	task.spawn(function()
		while true do
			task.wait(1)
			if os.time() >= nextRefreshTime then
				refreshAllCatalogs()
			end
		end
	end)
end

return AuctionTicketCatalogService
