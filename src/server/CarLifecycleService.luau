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
	Plot: Model,
	Model: Model,
	SoldParts: {[string]: boolean},
	SoldCount: number,
	IsCompleted: boolean,
}

local sessions: {[number]: CarSession} = {}
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

local spawnForPlayer: (Player, Model) -> ()

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
	EngineHoistService.ResetForCycle(session.OwnerUserId)
	cleanupCar(session.Model)
	task.wait(RESPAWN_DELAY)
	if player and sessions[session.OwnerUserId] == session and session.Plot:GetAttribute("OwnerUserId") == session.OwnerUserId then
		spawnForPlayer(player, session.Plot)
	end
end

spawnForPlayer = function(player: Player, plot: Model)
	local oldSession = sessions[player.UserId]
	if oldSession and oldSession.Model.Parent then oldSession.Model:Destroy() end
	EngineHoistService.RemoveForOwner(player.UserId)
	EconomyService.RemoveSellZone(player.UserId)

	local originPart = plot:FindFirstChild("Origin")
	assert(originPart and originPart:IsA("BasePart"), "Plot origin is missing")
	local origin = originPart.CFrame
	sessionCounter += 1
	local car = TrainingCarBuilder.create(origin * CFrame.new(0, -0.5, -4), "TrainingCar_" .. player.UserId)
	car:SetAttribute("CarSessionId", sessionCounter)
	car:SetAttribute("OwnerUserId", player.UserId)
	car:SetAttribute("CarCompleted", false)
	car:SetAttribute("SoldPartsCount", 0)
	car.Parent = Workspace

	PartRemovalService.setupCar(car, player.UserId)
	EngineHoistService.start(car, origin * CFrame.new(-15, 0.5, -15), player.UserId)
	EconomyService.CreateSellZone(player.UserId, origin * CFrame.new(16, 0, 0))
	PartRecoveryService.start(car)

	sessions[player.UserId] = {
		SessionId = sessionCounter,
		OwnerUserId = player.UserId,
		Plot = plot,
		Model = car,
		SoldParts = {},
		SoldCount = 0,
		IsCompleted = false,
	}
end

local function removeForPlayer(player: Player)
	local session = sessions[player.UserId]
	if session and session.Model.Parent then session.Model:Destroy() end
	sessions[player.UserId] = nil
	EngineHoistService.RemoveForOwner(player.UserId)
	EconomyService.RemoveSellZone(player.UserId)
end

function CarLifecycleService.start()
	for _, legacyName in { "TrainingCar01", "EngineHoist01", "SellZone" } do
		local legacy = Workspace:FindFirstChild(legacyName)
		if legacy then legacy:Destroy() end
	end

	EconomyService.OnPartSold:Connect(function(player: Player, car: Model?, sessionId: any, partId: any, _value: number)
		local session = sessions[player.UserId]
		if not session or session.IsCompleted then return end
		if car ~= session.Model or sessionId ~= session.SessionId then return end
		if typeof(partId) ~= "string" or not EXPECTED_PARTS[partId] or session.SoldParts[partId] then return end
		session.SoldParts[partId] = true
		session.SoldCount += 1
		session.Model:SetAttribute("SoldPartsCount", session.SoldCount)
		if session.SoldCount == TOTAL_PARTS then task.defer(completeSession, session) end
	end)

	PlotService.PlotAssigned:Connect(spawnForPlayer)
	PlotService.PlotReleased:Connect(removeForPlayer)
	for _, player in Players:GetPlayers() do
		local plot = PlotService.GetPlot(player)
		if plot then spawnForPlayer(player, plot) end
	end
end

return CarLifecycleService
