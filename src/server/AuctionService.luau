--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local AuctionCatalog = require(ReplicatedStorage.Shared.AuctionCatalog)
local AuctionHouseService = require(ServerScriptService.Server.AuctionHouseService)
local EconomyService = require(ServerScriptService.Server.EconomyService)
local CarLifecycleService = require(ServerScriptService.Server.CarLifecycleService)
local TrainingCarBuilder = require(ServerScriptService.Server.TrainingCarBuilder)

local AuctionService = {}

type AuctionState = "Waiting" | "Inspection" | "Bidding" | "Sold" | "Passed"

local currentState: AuctionState = "Waiting"
local currentLot: AuctionCatalog.AuctionLot? = nil
local currentHighestBid = 0
local currentHighestBidder: Player? = nil
local roundTimer = 0
local lotCounter = 0

local WAITING_DURATION = 35
local INSPECTION_DURATION = 12
local BIDDING_DURATION = 20

local function getPlayerMoney(player: Player): number
	local leaderstats = player:FindFirstChild("leaderstats")
	local money = leaderstats and leaderstats:FindFirstChild("Dinheiro")
	return if money and money:IsA("IntValue") then money.Value else 0
end

function AuctionService.GetCurrentState(): AuctionState
	return currentState
end

function AuctionService.GetCurrentLot(): AuctionCatalog.AuctionLot?
	return currentLot
end

function AuctionService.GetHighestBid(): (number, Player?)
	return currentHighestBid, currentHighestBidder
end

function AuctionService.PlaceBid(player: Player, bidAmount: number): (boolean, string)
	if typeof(bidAmount) ~= "number" or bidAmount ~= bidAmount or bidAmount <= 0 or bidAmount == math.huge or bidAmount % 1 ~= 0 then
		return false, "Valor de lance inválido."
	end

	if currentState ~= "Bidding" then
		return false, "O leilão não está na fase de lances."
	end

	if not currentLot then
		return false, "Nenhum lote ativo."
	end

	local minRequired = if currentHighestBidder == nil then currentLot.StartingBid else (currentHighestBid + 50)
	if bidAmount < minRequired then
		return false, string.format("Lance mínimo deve ser R$ %d.", minRequired)
	end

	if currentHighestBidder == player then
		return false, "Você já é o maior ofertante."
	end

	local playerMoney = getPlayerMoney(player)
	if playerMoney < bidAmount then
		return false, "Saldo insuficiente para cobrir o lance."
	end

	local availableBox = CarLifecycleService.GetAvailableBox(player)
	if not availableBox then
		return false, "Você não tem nenhum box livre para receber o carro."
	end

	currentHighestBid = bidAmount
	currentHighestBidder = player

	-- Anti-snipe: se o lance ocorrer nos últimos 4 segundos, estende em +3s
	if roundTimer <= 4 then
		roundTimer = math.clamp(roundTimer + 3, 0, 30)
	end

	AuctionHouseService.PlayGavelEffect()
	AuctionHouseService.UpdateBoard(
		string.format("LOTE #%d: %s", currentLot.LotId, currentLot.ModelConfig.DisplayName),
		"FASE DE LANCES!",
		string.format("⏱️ 00:%02d", roundTimer),
		string.format("Maior Lance: R$ %d", currentHighestBid),
		string.format("Líder: %s (+R$ %d)", player.DisplayName, currentHighestBid),
		Color3.fromRGB(80, 255, 140)
	)

	return true, "Lance aceito com sucesso!"
end

local function runAuctionCycle()
	while true do
		-- FASE 1: WAITING
		currentState = "Waiting"
		currentLot = nil
		currentHighestBid = 0
		currentHighestBidder = nil
		AuctionHouseService.SetDisplayedCar(nil)

		for t = WAITING_DURATION, 1, -1 do
			roundTimer = t
			AuctionHouseService.UpdateBoard(
				"LEILÃO DE SUCATAS",
				"AGUARDANDO PRÓXIMO LOTE...",
				string.format("⏱️ 00:%02d", t),
				"Lance: --",
				"Líder: Aguarde o leiloeiro",
				Color3.fromRGB(150, 190, 230)
			)
			task.wait(1)
		end

		-- FASE 2: INSPECTION
		lotCounter += 1
		local lot = AuctionCatalog.GenerateLot(lotCounter)
		currentLot = lot
		currentHighestBid = lot.StartingBid
		currentHighestBidder = nil

		-- Gera o carro modelo para exibição na mesa giratória
		local displayCar = TrainingCarBuilder.create(CFrame.identity, "DisplayCar_" .. lot.LotId, {
			BodyColor = lot.ModelConfig.BodyColor,
			AccentColor = lot.ModelConfig.AccentColor,
			InstalledParts = lot.InstalledParts,
			ScrapMultiplier = lot.ModelConfig.ScrapMultiplier,
		})
		AuctionHouseService.SetDisplayedCar(displayCar)

		currentState = "Inspection"
		for t = INSPECTION_DURATION, 1, -1 do
			roundTimer = t
			AuctionHouseService.UpdateBoard(
				string.format("LOTE #%d: %s", lot.LotId, lot.ModelConfig.DisplayName),
				"INSPEÇÃO DE SUCATA (Peças na mesa)",
				string.format("⏱️ 00:%02d", t),
				string.format("Lance Inicial: R$ %d", lot.StartingBid),
				string.format("Valor Estimado: ~R$ %d", lot.EstimatedScrapValue),
				Color3.fromRGB(255, 215, 60)
			)
			task.wait(1)
		end

		-- FASE 3: BIDDING
		currentState = "Bidding"
		roundTimer = BIDDING_DURATION

		while roundTimer > 0 do
			local leaderName = if currentHighestBidder then currentHighestBidder.DisplayName else "Nenhum (Lance Inicial)"
			local statusColor = if roundTimer <= 5 then Color3.fromRGB(255, 80, 70) else Color3.fromRGB(100, 255, 150)
			AuctionHouseService.UpdateBoard(
				string.format("LOTE #%d: %s", lot.LotId, lot.ModelConfig.DisplayName),
				if roundTimer <= 5 then "⚠️ DOU-LHE DUAS... ÚLTIMOS SEGUNDOS!" else "🔥 LANCES ABERTOS!",
				string.format("⏱️ 00:%02d", roundTimer),
				string.format("Maior Lance: R$ %d", currentHighestBid),
				string.format("Líder: %s", leaderName),
				statusColor
			)
			task.wait(1)
			roundTimer -= 1
		end

		-- FASE 4: RESOLUÇÃO (SOLD OU PASSED)
		if currentHighestBidder and currentHighestBid > 0 then
			currentState = "Sold"
			local winner = currentHighestBidder
			local finalBid = currentHighestBid

			-- 1. Revalidar box disponível ANTES de debitar
			local boxTarget = CarLifecycleService.GetAvailableBox(winner)
			if not boxTarget then
				AuctionHouseService.UpdateBoard(
					string.format("LOTE #%d: %s", lot.LotId, lot.ModelConfig.DisplayName),
					"LOTE CANCELADO (Vencedor sem box livre)",
					"--",
					"Cancelado",
					"Nenhum valor foi debitado",
					Color3.fromRGB(255, 120, 60)
				)
			else
				-- 2. Tentar debitar
				local spent = EconomyService.TrySpend(winner, finalBid)
				if not spent then
					AuctionHouseService.UpdateBoard(
						string.format("LOTE #%d: %s", lot.LotId, lot.ModelConfig.DisplayName),
						"FALHA NO PAGAMENTO (Saldo insuficiente)",
						"--",
						"Cancelado",
						"Lote descartado",
						Color3.fromRGB(255, 60, 60)
					)
				else
					-- 3. Spawna o carro arrematado no box do jogador
					local spawnedCar = CarLifecycleService.SpawnAuctionCar(winner, boxTarget, {
						BodyColor = lot.ModelConfig.BodyColor,
						AccentColor = lot.ModelConfig.AccentColor,
						InstalledParts = lot.InstalledParts,
						ScrapMultiplier = lot.ModelConfig.ScrapMultiplier,
					})

					if spawnedCar then
						AuctionHouseService.PlayGavelEffect()
						AuctionHouseService.UpdateBoard(
							string.format("LOTE #%d: %s", lot.LotId, lot.ModelConfig.DisplayName),
							"🔨 VENDIDO! MARTELO BATIDO!",
							"CONCLUÍDO",
							string.format("Valor Final: R$ %d", finalBid),
							string.format("🎉 Arrematado por %s (Entregue no Box %d)", winner.DisplayName, boxTarget),
							Color3.fromRGB(80, 255, 120)
						)
					else
						-- Falha inesperada no spawn: estorno garantido!
						EconomyService.AwardBonus(winner, finalBid)
						AuctionHouseService.UpdateBoard(
							string.format("LOTE #%d: %s", lot.LotId, lot.ModelConfig.DisplayName),
							"ERRO NA ENTREGA (Valor Estornado)",
							"--",
							"Estornado",
							"R$ " .. finalBid .. " devolvidos ao jogador",
							Color3.fromRGB(255, 60, 60)
						)
					end
				end
			end
		else
			currentState = "Passed"
			AuctionHouseService.UpdateBoard(
				string.format("LOTE #%d: %s", lot.LotId, lot.ModelConfig.DisplayName),
				"LOTE NÃO ARREMATADO (Sem lances)",
				"--",
				"R$ 0",
				"Retornando ao pátio de leilões...",
				Color3.fromRGB(180, 180, 190)
			)
		end

		task.wait(5)
	end
end

local function syncAuctionState()
	local house = Workspace:FindFirstChild("AuctionHouse")
	if not house then return end
	house:SetAttribute("AuctionState", currentState)
	house:SetAttribute("LotId", if currentLot then currentLot.LotId else 0)
	house:SetAttribute("VehicleName", if currentLot then currentLot.ModelConfig.DisplayName else "")
	house:SetAttribute("StartingBid", if currentLot then currentLot.StartingBid else 0)
	house:SetAttribute("CurrentBid", currentHighestBid)
	house:SetAttribute("EstimatedScrap", if currentLot then currentLot.EstimatedScrapValue else 0)
	house:SetAttribute("TimeRemaining", roundTimer)
	house:SetAttribute("LeaderName", if currentHighestBidder then currentHighestBidder.DisplayName else "Nenhum")
end

local lastBidTime: {[Player]: number} = {}
local ALLOWED_INCREMENTS = { [50] = true, [100] = true, [250] = true }

function AuctionService.start()
	AuctionHouseService.build()

	local bidRemote = ReplicatedStorage:FindFirstChild("PlaceAuctionBid")
	if not bidRemote then
		local newRemote = Instance.new("RemoteFunction")
		newRemote.Name = "PlaceAuctionBid"
		newRemote.Parent = ReplicatedStorage
		bidRemote = newRemote
	end
	(bidRemote :: RemoteFunction).OnServerInvoke = function(player: Player, increment: any)
		if typeof(increment) ~= "number" or increment ~= increment or not ALLOWED_INCREMENTS[increment] then
			return false, "Incremento de lance inválido."
		end

		local now = os.clock()
		local last = lastBidTime[player] or 0
		if now - last < 0.35 then
			return false, "Aguarde um momento antes de enviar outro lance."
		end
		lastBidTime[player] = now

		if currentState ~= "Bidding" or not currentLot then
			return false, "O leilão não está na fase de lances."
		end
		local targetBid: number
		if currentHighestBidder == nil then
			targetBid = currentLot.StartingBid
		else
			targetBid = currentHighestBid + increment
		end
		return AuctionService.PlaceBid(player, targetBid)
	end

	-- Conectar cliques nos pads de lance rápido
	AuctionHouseService.OnQuickBidTriggered:Connect(function(player: Player, increment: number)
		if currentState ~= "Bidding" or not currentLot then return end
		local targetBid: number
		if currentHighestBidder == nil then
			targetBid = currentLot.StartingBid
		else
			targetBid = currentHighestBid + increment
		end
		AuctionService.PlaceBid(player, targetBid)
	end)

	task.spawn(function()
		while true do
			syncAuctionState()
			task.wait(0.5)
		end
	end)

	task.spawn(runAuctionCycle)
end

return AuctionService
