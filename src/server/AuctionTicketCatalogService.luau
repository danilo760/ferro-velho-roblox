--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local AuctionCatalog = require(ReplicatedStorage.Shared.AuctionCatalog)
local EconomyService = require(ServerScriptService.Server.EconomyService)
local CarLifecycleService = require(ServerScriptService.Server.CarLifecycleService)
local PlotService = require(ServerScriptService.Server.PlotService)

local AuctionTicketCatalogService = {}

local CATALOG_REFRESH_INTERVAL = 300 -- 5 minutos
local nextRefreshTime = os.time() + CATALOG_REFRESH_INTERVAL

-- Catálogo global unificado compartilhado por todos os jogadores no servidor
local currentServerCatalog: {AuctionCatalog.CatalogOffer} = {}
-- Rastreamento de compras por jogador nesta rodada de 5 minutos
local playerPurchases: {[number]: {[string]: boolean}} = {}
-- Mutex contra cliques / compras concorrentes simultâneas
local buyingDebounce: {[number]: boolean} = {}

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

local function refreshServerCatalog()
	currentServerCatalog = AuctionCatalog.GenerateCatalog()
	playerPurchases = {}
	nextRefreshTime = os.time() + CATALOG_REFRESH_INTERVAL
	if catalogRefreshedRemote then
		catalogRefreshedRemote:FireAllClients(nextRefreshTime)
	end
end

function AuctionTicketCatalogService.RefreshCatalog()
	refreshServerCatalog()
end

function AuctionTicketCatalogService.GetPlayerCatalog(player: Player): {
	Offers: {AuctionCatalog.CatalogOffer},
	TimeRemaining: number,
	Tickets: number,
	PurchasedOffers: {[string]: boolean},
	Boxes: {CarLifecycleService.BoxSummary},
}
	if #currentServerCatalog == 0 then
		currentServerCatalog = AuctionCatalog.GenerateCatalog()
	end

	local remaining = math.max(0, nextRefreshTime - os.time())
	local tickets = EconomyService.GetTickets(player)
	local purchased = playerPurchases[player.UserId] or {}
	local boxes = CarLifecycleService.GetUnlockedBoxesSummary(player)

	return {
		Offers = currentServerCatalog,
		TimeRemaining = remaining,
		Tickets = tickets,
		PurchasedOffers = purchased,
		Boxes = boxes,
	}
end

local function processPurchase(player: Player, targetBoxIndex: any, offerId: any, transaction: { Charged: number }): (boolean, string)
	if player.Parent ~= Players then
		return false, "Jogador não está mais conectado."
	end

	-- Trava 1: dados do jogador carregados
	if player:GetAttribute("DataLoaded") ~= true or player:GetAttribute("DataLoadFailed") == true then
		return false, "Aguarde o carregamento completo dos seus dados antes de realizar compras."
	end

	if typeof(targetBoxIndex) ~= "number" or targetBoxIndex ~= targetBoxIndex or targetBoxIndex < 1 or targetBoxIndex > 3 or targetBoxIndex % 1 ~= 0 then
		return false, "Box selecionado inválido."
	end

	if typeof(offerId) ~= "string" or #offerId == 0 or #offerId > 100 then
		return false, "Identificador de oferta inválido."
	end

	local unlocked = player:GetAttribute("UnlockedBoxes")
	local maxUnlocked = if typeof(unlocked) == "number" then math.clamp(unlocked, 1, 3) else 1
	if targetBoxIndex > maxUnlocked then
		return false, string.format("O Box %d está bloqueado! Desbloqueie-o primeiro.", targetBoxIndex)
	end

	-- Trava 3: Já comprou esta oferta nesta rodada de 5 min?
	if playerPurchases[player.UserId] and playerPurchases[player.UserId][offerId] == true then
		return false, "Você já adquiriu esta oferta nesta rodada de 5 minutos."
	end

	-- Encontrar a oferta no catálogo global
	local targetOffer: AuctionCatalog.CatalogOffer? = nil
	for _, offer in currentServerCatalog do
		if offer.OfferId == offerId then
			targetOffer = offer
			break
		end
	end

	if not targetOffer then
		return false, "Esta oferta expirou ou não está mais disponível."
	end

	-- Trava 4: Proteção de fila cheia no Box (impedir sobrescrever PendingCar anterior sem aviso)
	if CarLifecycleService.HasPendingCar(player, targetBoxIndex) then
		local slot = CarLifecycleService.GetBoxSlot(player, targetBoxIndex)
		local pendingName = if slot and slot.PendingConfig then slot.PendingConfig.DisplayName else "outro veículo"
		return false, string.format("O Box %d já possui %s aguardando na fila pendente. Conclua a desmontagem antes de adquirir outro!", targetBoxIndex, pendingName)
	end

	-- Trava 4.5: Jogador possui lote ativo atribuído?
	local plot = PlotService.GetPlot(player)
	if not plot then
		return false, "Você ainda não possui um lote atribuído. Aguarde a liberação do seu lote."
	end

	-- Trava 5: Saldo de Tickets
	if typeof(targetOffer.TicketCost) ~= "number" or targetOffer.TicketCost <= 0 or targetOffer.TicketCost % 1 ~= 0 then
		warn("Invalid ticket cost in server catalog for offer " .. offerId)
		return false, "Esta oferta está inválida. Aguarde a próxima atualização do catálogo."
	end
	local currentTickets = EconomyService.GetTickets(player)
	if currentTickets < targetOffer.TicketCost then
		return false, string.format("Saldo insuficiente! Você possui %d e o veículo requer %d Tickets.", currentTickets, targetOffer.TicketCost)
	end

	-- Debitar tickets
	local deducted = EconomyService.DeductTickets(player, targetOffer.TicketCost)
	if not deducted then
		return false, "Falha na transação de Tickets."
	end
	transaction.Charged = targetOffer.TicketCost

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

	local assignCallOk, assignResult = pcall(function()
		return CarLifecycleService.AssignCarToBox(player, targetBoxIndex, carConfig)
	end)
	if not assignCallOk then
		EconomyService.AddTickets(player, transaction.Charged)
		transaction.Charged = 0
		warn("Failed to assign purchased auction car: " .. tostring(assignResult))
		return false, "A entrega falhou e seus Tickets foram estornados. Tente novamente."
	end

	if assignResult == "QueuedPending" then
		transaction.Charged = 0
	elseif assignResult == "AlreadyPending" then
		-- Fallback de segurança caso a fila tenha mudado no microsegundo
		EconomyService.AddTickets(player, transaction.Charged)
		transaction.Charged = 0
		return false, "O Box selecionado já possui um veículo pendente. Tickets estornados."
	elseif assignResult == "NoPlot" then
		EconomyService.AddTickets(player, transaction.Charged)
		transaction.Charged = 0
		return false, "Você não possui um lote ativo para receber o veículo. Tickets estornados."
	elseif assignResult == "SpawnedImmediately" then
		transaction.Charged = 0
	else
		EconomyService.AddTickets(player, transaction.Charged)
		transaction.Charged = 0
		warn("Unexpected car assignment result: " .. tostring(assignResult))
		return false, "A entrega não foi confirmada e seus Tickets foram estornados."
	end

	-- Registrar somente depois que a entrega ou fila foi confirmada.
	if not playerPurchases[player.UserId] then
		playerPurchases[player.UserId] = {}
	end
	playerPurchases[player.UserId][offerId] = true

	if assignResult == "QueuedPending" then
		return true, string.format("✅ Compra confirmada! Como o Box %d está em desmontagem, o novo veículo (%s) entrará automaticamente na fila pendente.", targetBoxIndex, carConfig.DisplayName)
	end
	return true, string.format("✅ Veículo entregue! O %s agora é o veículo permanente do seu Box %d.", carConfig.DisplayName, targetBoxIndex)
end

function AuctionTicketCatalogService.BuyCar(player: Player, targetBoxIndex: any, offerId: any): (boolean, string)
	if buyingDebounce[player.UserId] then
		return false, "Uma compra já está sendo processada. Aguarde um instante."
	end
	buyingDebounce[player.UserId] = true

	local transaction = { Charged = 0 }
	local callOk, purchaseOk, message = pcall(processPurchase, player, targetBoxIndex, offerId, transaction)
	buyingDebounce[player.UserId] = nil

	if not callOk then
		if transaction.Charged > 0 and player.Parent == Players then
			EconomyService.AddTickets(player, transaction.Charged)
		end
		warn("Unexpected auction purchase error: " .. tostring(purchaseOk))
		return false, "A compra falhou de forma segura. Nenhum Ticket foi perdido."
	end

	return purchaseOk, message
end

function AuctionTicketCatalogService.start()
	ensureRemotes()
	refreshServerCatalog()

	getCatalogRemote.OnServerInvoke = function(player: Player)
		return AuctionTicketCatalogService.GetPlayerCatalog(player)
	end

	buyCarRemote.OnServerInvoke = function(player: Player, targetBoxIndex: any, offerId: any)
		return AuctionTicketCatalogService.BuyCar(player, targetBoxIndex, offerId)
	end

	Players.PlayerRemoving:Connect(function(player)
		-- As compras da rodada permanecem por UserId até o próximo refresh,
		-- impedindo recomprar a mesma oferta ao sair e voltar ao mesmo servidor.
		buyingDebounce[player.UserId] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(1)
			if os.time() >= nextRefreshTime then
				refreshServerCatalog()
			end
		end
	end)
end

return AuctionTicketCatalogService
