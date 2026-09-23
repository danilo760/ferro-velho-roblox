--!strict

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local PlotService = require(ServerScriptService.Server.PlotService)
local TrainingCarBuilder = require(ServerScriptService.Server.TrainingCarBuilder)
local PartRemovalService = require(ServerScriptService.Server.PartRemovalService)
local EngineHoistService = require(ServerScriptService.Server.EngineHoistService)
local EconomyService = require(ServerScriptService.Server.EconomyService)
local PartRecoveryService = require(ServerScriptService.Server.PartRecoveryService)

local CarLifecycleService = {}
local COMPLETION_BONUS = 225
local RESPAWN_DELAY = 3
local TOTAL_PARTS = 12
local EXPECTED_PARTS: {[string]: boolean} = {
	Engine = true, Battery = true, WheelFrontLeft = true, WheelFrontRight = true,
	WheelRearLeft = true, WheelRearRight = true, Hood = true, DoorLeft = true,
	DoorRight = true, Trunk = true, HeadlightLeft = true, HeadlightRight = true,
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
local sessionCounter = 0

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
		player:SetAttribute("LastCarBonus", COMPLETION_BONUS)
		local serial = player:GetAttribute("CarCompletionSerial")
		player:SetAttribute("CarCompletionSerial", if typeof(serial) == "number" then serial + 1 else 1)
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

spawnCarForBox = function(player: Player, plot: Model, boxIndex: number)
	if not playerSessions[player.UserId] then
		playerSessions[player.UserId] = {}
	end

	local oldSession = playerSessions[player.UserId][boxIndex]
	if oldSession and oldSession.Model.Parent then oldSession.Model:Destroy() end
	EngineHoistService.RemoveForOwner(player.UserId, boxIndex)

	local pad = plot:FindFirstChild("Pad")
	assert(pad and pad:IsA("BasePart"), "Plot pad is missing")
	local plotGroundY = pad.Position.Y + pad.Size.Y / 2

	local boxOrigin = PlotService.GetBoxOrigin(player, boxIndex)
	local hoistOrigin = PlotService.GetBoxHoistOrigin(player, boxIndex)

	if not boxOrigin or not hoistOrigin then
		local originPart = plot:FindFirstChild("Origin")
		assert(originPart and originPart:IsA("BasePart"), "Plot origin is missing")
		local xOffset = if boxIndex == 1 then -15 elseif boxIndex == 2 then 0 else 15
		boxOrigin = originPart.CFrame * CFrame.new(xOffset, 0, -4)
		hoistOrigin = originPart.CFrame * CFrame.new(xOffset - 4.5, 0.5, -9)
	end

	sessionCounter += 1
	local carName = string.format("TrainingCar_%d_%d", player.UserId, boxIndex)
	local car = TrainingCarBuilder.create(boxOrigin * CFrame.new(0, -0.5, 0), carName)
	car:SetAttribute("CarSessionId", sessionCounter)
	car:SetAttribute("OwnerUserId", player.UserId)
	car:SetAttribute("BoxIndex", boxIndex)
	car:SetAttribute("CarCompleted", false)
	car:SetAttribute("SoldPartsCount", 0)
	car.Parent = Workspace

	PartRemovalService.setupCar(car, player.UserId, plotGroundY)
	EngineHoistService.start(car, hoistOrigin, player.UserId, boxIndex)
	PartRecoveryService.start(car, plotGroundY, boxOrigin.Position)

	local session: CarSession = {
		SessionId = sessionCounter,
		OwnerUserId = player.UserId,
		BoxIndex = boxIndex,
		Plot = plot,
		Model = car,
		SoldParts = {},
		SoldCount = 0,
		IsCompleted = false,
	}
	playerSessions[player.UserId][boxIndex] = session
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
	local sessions = playerSessions[player.UserId]
	if sessions then
		for _, session in sessions do
			if session.Model.Parent then session.Model:Destroy() end
		end
	end
	playerSessions[player.UserId] = nil
	EngineHoistService.RemoveForOwner(player.UserId)
end

function CarLifecycleService.start()
	for _, child in Workspace:GetChildren() do
		if child.Name:match("^SellZone") or child.Name:match("^TrainingCar") or child.Name:match("^EngineHoist") then
			child:Destroy()
		end
	end

	EconomyService.OnPartSold:Connect(function(player: Player, car: Model?, sessionId: any, partId: any, _value: number)
		local sessions = playerSessions[player.UserId]
		if not sessions or not car then return end
		local boxIndex = car:GetAttribute("BoxIndex")
		local targetBox = if typeof(boxIndex) == "number" then boxIndex else 1
		local session = sessions[targetBox]

		if not session or session.IsCompleted then return end
		if car ~= session.Model or sessionId ~= session.SessionId then return end
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
		if session and session.SoldCount == 0 and not session.Model.Name:match("^AuctionCar") then
			return b
		end
	end

	return nil
end

function CarLifecycleService.SpawnAuctionCar(player: Player, boxIndex: number, carOptions: TrainingCarBuilder.CustomCarOptions): Model?
	local plot = PlotService.GetPlot(player)
	if not plot then return nil end

	if not playerSessions[player.UserId] then
		playerSessions[player.UserId] = {}
	end

	local oldSession = playerSessions[player.UserId][boxIndex]
	if oldSession and oldSession.Model.Parent then oldSession.Model:Destroy() end
	EngineHoistService.RemoveForOwner(player.UserId, boxIndex)

	local pad = plot:FindFirstChild("Pad")
	assert(pad and pad:IsA("BasePart"), "Plot pad is missing")
	local plotGroundY = pad.Position.Y + pad.Size.Y / 2

	local boxOrigin = PlotService.GetBoxOrigin(player, boxIndex)
	local hoistOrigin = PlotService.GetBoxHoistOrigin(player, boxIndex)

	if not boxOrigin or not hoistOrigin then
		local originPart = plot:FindFirstChild("Origin")
		assert(originPart and originPart:IsA("BasePart"), "Plot origin is missing")
		local xOffset = if boxIndex == 1 then -15 elseif boxIndex == 2 then 0 else 15
		boxOrigin = originPart.CFrame * CFrame.new(xOffset, 0, -4)
		hoistOrigin = originPart.CFrame * CFrame.new(xOffset - 4.5, 0.5, -9)
	end

	sessionCounter += 1
	local carName = string.format("AuctionCar_%d_%d", player.UserId, boxIndex)
	local car = TrainingCarBuilder.create(boxOrigin * CFrame.new(0, -0.5, 0), carName, carOptions)
	car:SetAttribute("CarSessionId", sessionCounter)
	car:SetAttribute("OwnerUserId", player.UserId)
	car:SetAttribute("BoxIndex", boxIndex)
	car:SetAttribute("CarCompleted", false)
	car:SetAttribute("SoldPartsCount", 0)

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
	PartRecoveryService.start(car, plotGroundY, boxOrigin.Position)

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
	return car
end

return CarLifecycleService
