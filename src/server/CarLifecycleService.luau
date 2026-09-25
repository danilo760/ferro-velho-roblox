--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local PlotService = require(ServerScriptService.Server.PlotService)
local TrainingCarBuilder = require(ServerScriptService.Server.TrainingCarBuilder)
local PartRemovalService = require(ServerScriptService.Server.PartRemovalService)
local EngineHoistService = require(ServerScriptService.Server.EngineHoistService)
local EconomyService = require(ServerScriptService.Server.EconomyService)
local PartRecoveryService = require(ServerScriptService.Server.PartRecoveryService)
local AuctionCatalog = require(ReplicatedStorage.Shared.AuctionCatalog)

local CarLifecycleService = {}
local COMPLETION_BONUS = AuctionCatalog.COMPLETION_BONUS
local RESPAWN_DELAY = 3
local TOTAL_PARTS = 12
local EXPECTED_PARTS: {[string]: boolean} = {
	Engine = true, Battery = true, WheelFrontLeft = true, WheelFrontRight = true,
	WheelRearLeft = true, WheelRearRight = true, Hood = true, DoorLeft = true,
	DoorRight = true, Trunk = true, HeadlightLeft = true, HeadlightRight = true,
}
local TRAINING_PARTS = {
	"Engine", "Battery", "WheelFrontLeft", "WheelFrontRight",
	"WheelRearLeft", "WheelRearRight", "Hood", "DoorLeft",
	"DoorRight", "Trunk", "HeadlightLeft", "HeadlightRight",
}
local ALLOWED_SAVED_PARTS: {[string]: boolean} = {
	Chassis = true, Engine = true, Battery = true, WheelFrontLeft = true, WheelFrontRight = true,
	WheelRearLeft = true, WheelRearRight = true, Hood = true, DoorLeft = true,
	DoorRight = true, Trunk = true, HeadlightLeft = true, HeadlightRight = true,
}
local ALLOWED_CONSERVATION_NAMES: {[string]: boolean} = {
	Sucateado = true,
	Danificado = true,
	Usado = true,
	Preservado = true,
	Excelente = true,
	["Leilão"] = true,
}
local MAX_SAVED_MULTIPLIER = 10

export type BoxCarConfig = {
	ModelId: string,
	DisplayName: string,
	ScrapMultiplier: number,
	InstalledParts: {string}?,
	BodyColor: Color3?,
	AccentColor: Color3?,
	ConservationName: string?,
}

export type BoxCarSlot = {
	CurrentConfig: BoxCarConfig?,
	PendingConfig: BoxCarConfig?,
}

export type BoxSummary = {
	BoxIndex: number,
	CurrentCarName: string,
	CycleValue: number,
	TotalParts: number,
	ScrapMultiplier: number,
	IsTrainingCar: boolean,
	HasPending: boolean,
	PendingCarName: string?,
}

type CarSession = {
	SessionId: number,
	OwnerUserId: number,
	BoxIndex: number,
	Plot: Model,
	Model: Model,
	SoldParts: {[string]: boolean},
	SoldCount: number,
	TotalParts: number?,
	IsCompleted: boolean,
}

local playerSessions: {[number]: {[number]: CarSession}} = {}
local playerBoxSlots: {[number]: {[number]: BoxCarSlot}} = {}
local sessionCounter = 0

local function isFiniteNumber(value: any): boolean
	return typeof(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function colorToTable(color: Color3?): {number}?
	if not color then return nil end
	return {
		math.clamp(math.floor(color.R * 255 + 0.5), 0, 255),
		math.clamp(math.floor(color.G * 255 + 0.5), 0, 255),
		math.clamp(math.floor(color.B * 255 + 0.5), 0, 255),
	}
end

local function tableToColor(tab: any): Color3?
	if typeof(tab) ~= "table" or #tab < 3 then return nil end
	if not isFiniteNumber(tab[1]) or not isFiniteNumber(tab[2]) or not isFiniteNumber(tab[3]) then return nil end
	local r = math.clamp(math.round(tab[1]), 0, 255)
	local g = math.clamp(math.round(tab[2]), 0, 255)
	local b = math.clamp(math.round(tab[3]), 0, 255)
	return Color3.fromRGB(r, g, b)
end

local function serializeConfig(config: BoxCarConfig?): any
	if not config then return nil end
	local installedParts: {string}? = nil
	if config.InstalledParts then
		installedParts = table.clone(config.InstalledParts)
	end
	return {
		ModelId = config.ModelId,
		DisplayName = config.DisplayName,
		ScrapMultiplier = config.ScrapMultiplier,
		InstalledParts = installedParts,
		BodyColor = colorToTable(config.BodyColor),
		AccentColor = colorToTable(config.AccentColor),
		ConservationName = config.ConservationName,
	}
end

local function deserializeConfig(raw: any): BoxCarConfig?
	if typeof(raw) ~= "table" or typeof(raw.ModelId) ~= "string" then
		return nil
	end
	local model = AuctionCatalog.GetModel(raw.ModelId)
	if not model and raw.ModelId ~= "AuctionCar" then return nil end

	local mult = if isFiniteNumber(raw.ScrapMultiplier)
		then math.clamp(raw.ScrapMultiplier, 0.1, MAX_SAVED_MULTIPLIER)
		else 1
	local parts: {string}? = nil
	if typeof(raw.InstalledParts) == "table" then
		parts = {}
		local seen: {[string]: boolean} = {}
		for _, p in raw.InstalledParts do
			if typeof(p) == "string" and ALLOWED_SAVED_PARTS[p] and not seen[p] then
				seen[p] = true
				table.insert(parts, p)
			end
		end
	end

	local fallbackName = if model then model.DisplayName else "Carro Adquirido"
	local displayName = if typeof(raw.DisplayName) == "string" and #raw.DisplayName > 0 and #raw.DisplayName <= 120
		then raw.DisplayName
		else fallbackName
	local conservationName = if typeof(raw.ConservationName) == "string" and ALLOWED_CONSERVATION_NAMES[raw.ConservationName]
		then raw.ConservationName
		else nil
	local bodyColor = tableToColor(raw.BodyColor)
	local accentColor = tableToColor(raw.AccentColor)
	if model then
		bodyColor = bodyColor or model.BaseBodyColor
		accentColor = accentColor or model.BaseAccentColor
	end
	return {
		ModelId = raw.ModelId,
		DisplayName = displayName,
		ScrapMultiplier = mult,
		InstalledParts = parts,
		BodyColor = bodyColor,
		AccentColor = accentColor,
		ConservationName = conservationName,
	}
end

local function getOrCreateBoxSlot(userId: number, boxIndex: number): BoxCarSlot
	if not playerBoxSlots[userId] then
		playerBoxSlots[userId] = {}
	end
	if not playerBoxSlots[userId][boxIndex] then
		playerBoxSlots[userId][boxIndex] = {
			CurrentConfig = nil,
			PendingConfig = nil,
		}
	end
	return playerBoxSlots[userId][boxIndex]
end

local function disableInteractions(model: Model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("ProximityPrompt") then descendant.Enabled = false end
	end
end

local function cleanupCar(model: Model)
	disableInteractions(model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			TweenService:Create(descendant, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Transparency = 1,
				Position = descendant.Position - Vector3.new(0, 2, 0),
			}):Play()
		end
	end
	task.wait(0.65)
	if model.Parent then model:Destroy() end
end

local spawnCarForBox: (Player, Model, number) -> ()

local function completeSession(session: CarSession)
	if session.IsCompleted then return end
	session.IsCompleted = true
	session.Model:SetAttribute("CarCompleted", true)

	local player = Players:GetPlayerByUserId(session.OwnerUserId)
	if player then
		EconomyService.AwardBonus(player, COMPLETION_BONUS)
		EconomyService.IncrementCars(player)
		local totalParts = session.TotalParts or TOTAL_PARTS
		local ticketsAwarded, remainingPoints = EconomyService.AddTicketPoints(player, totalParts)
		player:SetAttribute("LastCarBonus", COMPLETION_BONUS)
		player:SetAttribute("LastTicketReward", ticketsAwarded)
		local serial = player:GetAttribute("CarCompletionSerial")
		player:SetAttribute("CarCompletionSerial", if typeof(serial) == "number" then serial + 1 else 1)

		-- Promover PendingConfig para CurrentConfig se houver carro na fila do Box
			local userSlots = playerBoxSlots[session.OwnerUserId]
			local slot = userSlots and userSlots[session.BoxIndex]
			if slot and slot.PendingConfig then
				local promotedConfig = slot.PendingConfig
				slot.CurrentConfig = promotedConfig
				slot.PendingConfig = nil
				player:SetAttribute(string.format("Box_%d_Pending", session.BoxIndex), nil)
				player:SetAttribute(string.format("Box_%d_Current", session.BoxIndex), promotedConfig.DisplayName)
			end
	end

	EngineHoistService.ResetForCycle(session.OwnerUserId, session.BoxIndex)
	cleanupCar(session.Model)
	task.wait(RESPAWN_DELAY)

	if player and playerSessions[session.OwnerUserId] and playerSessions[session.OwnerUserId][session.BoxIndex] == session and session.Plot:GetAttribute("OwnerUserId") == session.OwnerUserId then
		local unlocked = player:GetAttribute("UnlockedBoxes")
		local maxUnlocked = if typeof(unlocked) == "number" then unlocked else 1
		if session.BoxIndex <= maxUnlocked then
			spawnCarForBox(player, session.Plot, session.BoxIndex)
		end
	end
end

local function getFallbackBoxXOffset(plotPositionX: number, boxIndex: number): number
	local isLeft = plotPositionX < 0
	if boxIndex == 1 then
		return if isLeft then 15 else -15
	elseif boxIndex == 3 then
		return if isLeft then -15 else 15
	end
	return 0
end

spawnCarForBox = function(player: Player, plot: Model, boxIndex: number)
	if not playerSessions[player.UserId] then
		playerSessions[player.UserId] = {}
	end

	local oldSession = playerSessions[player.UserId][boxIndex]
	if oldSession and oldSession.Model.Parent then oldSession.Model:Destroy() end
	local oldBoxCar = Workspace:FindFirstChild(string.format("BoxCar_%d_%d", player.UserId, boxIndex))
	if oldBoxCar then oldBoxCar:Destroy() end
	local oldTrainingCar = Workspace:FindFirstChild(string.format("TrainingCar_%d_%d", player.UserId, boxIndex))
	if oldTrainingCar then oldTrainingCar:Destroy() end
	EngineHoistService.RemoveForOwner(player.UserId, boxIndex)

	local pad = plot:FindFirstChild("Pad")
	assert(pad and pad:IsA("BasePart"), "Plot pad is missing")
	local plotGroundY = pad.Position.Y + pad.Size.Y / 2

	local boxOrigin = PlotService.GetBoxOrigin(player, boxIndex)
	local hoistOrigin = PlotService.GetBoxHoistOrigin(player, boxIndex)

	if not boxOrigin or not hoistOrigin then
		local originPart = plot:FindFirstChild("Origin")
		assert(originPart and originPart:IsA("BasePart"), "Plot origin is missing")
		local xOffset = getFallbackBoxXOffset(originPart.Position.X, boxIndex)
		boxOrigin = originPart.CFrame * CFrame.new(xOffset, 0, -4)
		hoistOrigin = originPart.CFrame * CFrame.new(xOffset - 4.5, 0.5, -9)
	end

	sessionCounter += 1
	local slot = getOrCreateBoxSlot(player.UserId, boxIndex)
	local car: Model
	local displayName: string

	if slot.CurrentConfig then
		local cfg = slot.CurrentConfig
		displayName = cfg.DisplayName
		local carName = string.format("BoxCar_%d_%d", player.UserId, boxIndex)
		local opts: TrainingCarBuilder.CustomCarOptions = {
			ModelId = cfg.ModelId,
			BodyColor = cfg.BodyColor,
			AccentColor = cfg.AccentColor,
			InstalledParts = cfg.InstalledParts,
			ScrapMultiplier = cfg.ScrapMultiplier,
			ConservationName = cfg.ConservationName,
		}
		car = TrainingCarBuilder.create(boxOrigin * CFrame.new(0, -0.5, 0), carName, opts)
	else
		displayName = "Carro de Treinamento"
		local carName = string.format("TrainingCar_%d_%d", player.UserId, boxIndex)
		car = TrainingCarBuilder.create(boxOrigin * CFrame.new(0, -0.5, 0), carName)
	end

	car:SetAttribute("CarSessionId", sessionCounter)
	car:SetAttribute("OwnerUserId", player.UserId)
	car:SetAttribute("BoxIndex", boxIndex)
	car:SetAttribute("CarCompleted", false)
	car:SetAttribute("SoldPartsCount", 0)
	car:SetAttribute("DisplayName", displayName)

	local partsCount = 0
	for _, child in car:GetChildren() do
		if child:IsA("BasePart") and EXPECTED_PARTS[child.Name] then
			partsCount += 1
		end
	end
	car:SetAttribute("TotalPartsCount", partsCount)
	car.Parent = Workspace

	PartRemovalService.setupCar(car, player.UserId, plotGroundY)
	EngineHoistService.start(car, hoistOrigin, player.UserId, boxIndex)
	PartRecoveryService.start(car, plotGroundY, boxOrigin)

	local session: CarSession = {
		SessionId = sessionCounter,
		OwnerUserId = player.UserId,
		BoxIndex = boxIndex,
		Plot = plot,
		Model = car,
		SoldParts = {},
		SoldCount = 0,
		TotalParts = partsCount,
		IsCompleted = false,
	}
	playerSessions[player.UserId][boxIndex] = session

	player:SetAttribute(string.format("Box_%d_Current", boxIndex), displayName)
	player:SetAttribute(string.format("Box_%d_Pending", boxIndex), if slot.PendingConfig then slot.PendingConfig.DisplayName else nil)
end

local function spawnForPlayer(player: Player, plot: Model)
	local unlockedBoxes = player:GetAttribute("UnlockedBoxes")
	local unlockedCount = if typeof(unlockedBoxes) == "number" then math.clamp(unlockedBoxes, 1, 3) else 1

	for b = 1, unlockedCount do
		spawnCarForBox(player, plot, b)
	end

	player:GetAttributeChangedSignal("UnlockedBoxes"):Connect(function()
		local newCount = player:GetAttribute("UnlockedBoxes")
		if typeof(newCount) == "number" then
			local count = math.clamp(newCount, 1, 3)
			for b = 1, count do
				local currentSessions = playerSessions[player.UserId]
				if not currentSessions or not currentSessions[b] then
					spawnCarForBox(player, plot, b)
				end
			end
		end
	end)
end

local function removeForPlayer(player: Player)
	local userId = player.UserId
	local sessions = playerSessions[userId]
	if sessions then
		for _, session in sessions do
			if session.Model.Parent then session.Model:Destroy() end
		end
	end
	playerSessions[userId] = nil
	EngineHoistService.RemoveForOwner(userId)

	-- Manter playerBoxSlots por 15 segundos para permitir que o PlayerDataService salve os dados sem risco de corrida
	task.delay(15, function()
		if not Players:GetPlayerByUserId(userId) then
			playerBoxSlots[userId] = nil
		end
	end)
end

function CarLifecycleService.SerializeBoxCars(player: Player): {[string]: any}
	local result: {[string]: any} = {}
	local userSlots = playerBoxSlots[player.UserId]
	if not userSlots then return result end

	for b = 1, 3 do
		local slot = userSlots[b]
		if slot then
			result[tostring(b)] = {
				Current = serializeConfig(slot.CurrentConfig),
				Pending = serializeConfig(slot.PendingConfig),
			}
		end
	end
	return result
end

function CarLifecycleService.LoadBoxCars(player: Player, savedData: any)
	if not playerBoxSlots[player.UserId] then
		playerBoxSlots[player.UserId] = {}
	end
	for b = 1, 3 do
		local slot = getOrCreateBoxSlot(player.UserId, b)
		slot.CurrentConfig = nil
		slot.PendingConfig = nil
		player:SetAttribute(string.format("Box_%d_Current", b), nil)
		player:SetAttribute(string.format("Box_%d_Pending", b), nil)
	end

	if typeof(savedData) == "table" then
		for b = 1, 3 do
			local boxKey = tostring(b)
			local boxData = savedData[boxKey]
			if typeof(boxData) == "table" then
				local slot = getOrCreateBoxSlot(player.UserId, b)
				slot.CurrentConfig = deserializeConfig(boxData.Current)
				slot.PendingConfig = deserializeConfig(boxData.Pending)
				if slot.CurrentConfig then
					player:SetAttribute(string.format("Box_%d_Current", b), slot.CurrentConfig.DisplayName)
				end
				if slot.PendingConfig then
					player:SetAttribute(string.format("Box_%d_Pending", b), slot.PendingConfig.DisplayName)
				end
			end
		end
	end

	-- Se o lote já estiver atribuído, sincronizar os boxes ativos com os carros restaurados
	local plot = PlotService.GetPlot(player)
	if plot then
		local unlocked = player:GetAttribute("UnlockedBoxes")
		local maxUnlocked = if typeof(unlocked) == "number" then math.clamp(unlocked, 1, 3) else 1
		for b = 1, maxUnlocked do
			local slot = playerBoxSlots[player.UserId][b]
			if slot and slot.CurrentConfig then
				spawnCarForBox(player, plot, b)
			end
		end
	end
end

function CarLifecycleService.HasPendingCar(player: Player, boxIndex: number): boolean
	local userSlots = playerBoxSlots[player.UserId]
	local slot = userSlots and userSlots[boxIndex]
	return slot ~= nil and slot.PendingConfig ~= nil
end

function CarLifecycleService.GetBoxSlot(player: Player, boxIndex: number): BoxCarSlot?
	local userSlots = playerBoxSlots[player.UserId]
	return if userSlots then userSlots[boxIndex] else nil
end

function CarLifecycleService.start()
	for _, child in Workspace:GetChildren() do
		if child.Name:match("^SellZone") or child.Name:match("^TrainingCar") or child.Name:match("^BoxCar") or child.Name:match("^AuctionCar") or child.Name:match("^EngineHoist") then
			child:Destroy()
		end
	end

	EconomyService.OnPartSold:Connect(function(player: Player, car: Model?, sessionId: any, partId: any, _value: number)
		local sessions = playerSessions[player.UserId]
		if not sessions then return end
		local boxIndex = if car then car:GetAttribute("BoxIndex") else nil
		local targetBox = if typeof(boxIndex) == "number" then boxIndex else 1
		local session = sessions[targetBox]

		if not session or session.IsCompleted then return end
		if sessionId ~= session.SessionId and (not car or car ~= session.Model) then return end
		if typeof(partId) ~= "string" or not EXPECTED_PARTS[partId] or session.SoldParts[partId] then return end

		session.SoldParts[partId] = true
		session.SoldCount += 1
		session.Model:SetAttribute("SoldPartsCount", session.SoldCount)
		local total = session.TotalParts or TOTAL_PARTS
		if session.SoldCount >= total then task.defer(completeSession, session) end
	end)

	PlotService.PlotAssigned:Connect(spawnForPlayer)
	PlotService.PlotReleased:Connect(removeForPlayer)
	PlotService.BoxUnlocked:Connect(function(player: Player, boxIndex: number)
		local plot = PlotService.GetPlot(player)
		if plot then
			spawnCarForBox(player, plot, boxIndex)
		end
	end)

	for _, player in Players:GetPlayers() do
		local plot = PlotService.GetPlot(player)
		if plot then spawnForPlayer(player, plot) end
	end
end

function CarLifecycleService.GetAvailableBox(player: Player): number?
	local unlockedBoxes = player:GetAttribute("UnlockedBoxes")
	local maxUnlocked = if typeof(unlockedBoxes) == "number" then math.clamp(unlockedBoxes, 1, 3) else 1
	local userSessions = playerSessions[player.UserId]
	if not userSessions then return 1 end

	-- Prioridade 1: Box totalmente vazio ou com ciclo concluído
	for b = 1, maxUnlocked do
		local session = userSessions[b]
		if not session or session.IsCompleted or not session.Model.Parent then
			return b
		end
	end

	-- Prioridade 2: Box com carro de treinamento padrão intacto (0 peças vendidas)
	for b = 1, maxUnlocked do
		local session = userSessions[b]
		if session and session.SoldCount == 0 and not session.Model.Name:match("^BoxCar") and not session.Model.Name:match("^AuctionCar") then
			return b
		end
	end

	return nil
end

function CarLifecycleService.AssignCarToBox(player: Player, boxIndex: number, config: BoxCarConfig): string
	if player.Parent ~= Players or boxIndex < 1 or boxIndex > 3 or boxIndex % 1 ~= 0 then
		return "InvalidRequest"
	end
	local normalizedConfig = deserializeConfig(serializeConfig(config))
	if not normalizedConfig then return "InvalidConfig" end

	local plot = PlotService.GetPlot(player)
	if not plot then
		return "NoPlot"
	end

	local slot = getOrCreateBoxSlot(player.UserId, boxIndex)
	local session = playerSessions[player.UserId] and playerSessions[player.UserId][boxIndex]

	local isDisassembling = session ~= nil and not session.IsCompleted and session.SoldCount > 0
	if isDisassembling then
		if slot.PendingConfig ~= nil then
			return "AlreadyPending"
		end
		slot.PendingConfig = normalizedConfig
		player:SetAttribute(string.format("Box_%d_Pending", boxIndex), normalizedConfig.DisplayName)
		return "QueuedPending"
	else
		slot.CurrentConfig = normalizedConfig
		slot.PendingConfig = nil
		player:SetAttribute(string.format("Box_%d_Pending", boxIndex), nil)
		player:SetAttribute(string.format("Box_%d_Current", boxIndex), normalizedConfig.DisplayName)
		spawnCarForBox(player, plot, boxIndex)
		return "SpawnedImmediately"
	end
end

function CarLifecycleService.GetBoxStatus(player: Player, boxIndex: number): {
	IsUnlocked: boolean,
	IsInProgress: boolean,
	SoldCount: number,
	TotalParts: number,
	CurrentCarName: string,
	PendingCarName: string?,
}
	local unlocked = player:GetAttribute("UnlockedBoxes")
	local maxUnlocked = if typeof(unlocked) == "number" then unlocked else 1
	local isUnlocked = boxIndex <= maxUnlocked

	local session = playerSessions[player.UserId] and playerSessions[player.UserId][boxIndex]
	local isInProgress = session ~= nil and not session.IsCompleted and session.SoldCount > 0
	local soldCount = if session then session.SoldCount else 0
	local totalParts = if session and session.TotalParts then session.TotalParts else TOTAL_PARTS

	local slot = playerBoxSlots[player.UserId] and playerBoxSlots[player.UserId][boxIndex]
	local currentName = if slot and slot.CurrentConfig then slot.CurrentConfig.DisplayName else "Carro de Treinamento"
	local pendingName = if slot and slot.PendingConfig then slot.PendingConfig.DisplayName else nil

	return {
		IsUnlocked = isUnlocked,
		IsInProgress = isInProgress,
		SoldCount = soldCount,
		TotalParts = totalParts,
		CurrentCarName = currentName,
		PendingCarName = pendingName,
	}
end

function CarLifecycleService.SpawnAuctionCar(player: Player, boxIndex: number, carOptions: TrainingCarBuilder.CustomCarOptions): Model?
	local config: BoxCarConfig = {
		ModelId = "AuctionCar",
		DisplayName = "Carro Adquirido",
		ScrapMultiplier = carOptions.ScrapMultiplier or 1,
		InstalledParts = carOptions.InstalledParts,
		BodyColor = carOptions.BodyColor,
		AccentColor = carOptions.AccentColor,
		ConservationName = "Leilão",
	}
	CarLifecycleService.AssignCarToBox(player, boxIndex, config)
	local session = playerSessions[player.UserId] and playerSessions[player.UserId][boxIndex]
	return if session then session.Model else nil
end

function CarLifecycleService.CompleteSession(player: Player, boxIndex: number): boolean
	local sessions = playerSessions[player.UserId]
	local session = sessions and sessions[boxIndex]
	if not session or session.IsCompleted then return false end
	completeSession(session)
	return true
end

function CarLifecycleService.GetBoxSummary(player: Player, boxIndex: number): BoxSummary
	local slot = playerBoxSlots[player.UserId] and playerBoxSlots[player.UserId][boxIndex]
	local currentCfg = slot and slot.CurrentConfig
	local pendingCfg = slot and slot.PendingConfig

	if currentCfg then
		local installed = currentCfg.InstalledParts or {}
		local vendibleCount = AuctionCatalog.CountVendibleParts(installed)
		local mult = currentCfg.ScrapMultiplier or 1
		local cycleVal = AuctionCatalog.CalculateCycleValue(installed, mult)

		return {
			BoxIndex = boxIndex,
			CurrentCarName = currentCfg.DisplayName,
			CycleValue = cycleVal,
			TotalParts = vendibleCount,
			ScrapMultiplier = mult,
			IsTrainingCar = false,
			HasPending = pendingCfg ~= nil,
			PendingCarName = if pendingCfg then pendingCfg.DisplayName else nil,
		}
	else
		-- Carro de Treinamento padrão
		return {
			BoxIndex = boxIndex,
			CurrentCarName = "Carro de Treinamento",
			CycleValue = AuctionCatalog.CalculateCycleValue(TRAINING_PARTS, 1.0),
			TotalParts = 12,
			ScrapMultiplier = 1.0,
			IsTrainingCar = true,
			HasPending = pendingCfg ~= nil,
			PendingCarName = if pendingCfg then pendingCfg.DisplayName else nil,
		}
	end
end

function CarLifecycleService.GetUnlockedBoxesSummary(player: Player): {BoxSummary}
	local unlocked = player:GetAttribute("UnlockedBoxes")
	local maxUnlocked = if typeof(unlocked) == "number" then math.clamp(unlocked, 1, 3) else 1
	local summaries: {BoxSummary} = {}
	for b = 1, maxUnlocked do
		table.insert(summaries, CarLifecycleService.GetBoxSummary(player, b))
	end
	return summaries
end

return CarLifecycleService
