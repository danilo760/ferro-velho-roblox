--!strict

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")

local TrainingCarBuilder = require(ServerScriptService.Server.TrainingCarBuilder)
local PartRemovalService = require(ServerScriptService.Server.PartRemovalService)
local EngineHoistService = require(ServerScriptService.Server.EngineHoistService)
local EconomyService = require(ServerScriptService.Server.EconomyService)
local PartRecoveryService = require(ServerScriptService.Server.PartRecoveryService)

local CarLifecycleService = {}

local COMPLETION_BONUS = 225
local RESPAWN_DELAY = 3
local EXPECTED_PARTS: {[string]: boolean} = {
	Engine = true,
	Battery = true,
	WheelFrontLeft = true,
	WheelFrontRight = true,
	WheelRearLeft = true,
	WheelRearRight = true,
	Hood = true,
	DoorLeft = true,
	DoorRight = true,
	Trunk = true,
	HeadlightLeft = true,
	HeadlightRight = true,
}
local TOTAL_PARTS = 12

type CarSession = {
	SessionId: number,
	Model: Model,
	OwnerUserId: number?,
	LastSellerUserId: number?,
	SoldParts: {[string]: boolean},
	SoldCount: number,
	IsCompleted: boolean,
}

local currentSession: CarSession? = nil
local sessionCounter = 0

local function disableInteractions(model: Model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("ProximityPrompt") then descendant.Enabled = false end
	end
end

local function animateCleanup(model: Model)
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

local spawnNextCar: () -> ()

local function completeSession(session: CarSession)
	if session.IsCompleted then return end
	session.IsCompleted = true
	session.Model:SetAttribute("CarCompleted", true)

	local rewardUserId = session.OwnerUserId or session.LastSellerUserId
	local player = if rewardUserId then Players:GetPlayerByUserId(rewardUserId) else nil
	if player then
		EconomyService.AwardBonus(player, COMPLETION_BONUS)
		EconomyService.IncrementCars(player)
		player:SetAttribute("LastCarBonus", COMPLETION_BONUS)
		local serial = player:GetAttribute("CarCompletionSerial")
		player:SetAttribute("CarCompletionSerial", if typeof(serial) == "number" then serial + 1 else 1)
	end

	EngineHoistService.ResetForCycle()
	animateCleanup(session.Model)
	task.wait(RESPAWN_DELAY)
	if currentSession == session then spawnNextCar() end
end

spawnNextCar = function()
	sessionCounter += 1
	local car = TrainingCarBuilder.create()
	car:SetAttribute("CarSessionId", sessionCounter)
	car:SetAttribute("CarCompleted", false)
	car.Parent = workspace

	PartRemovalService.setupCar(car)
	EngineHoistService.start(car)
	PartRecoveryService.start(car)

	currentSession = {
		SessionId = sessionCounter,
		Model = car,
		OwnerUserId = nil,
		LastSellerUserId = nil,
		SoldParts = {},
		SoldCount = 0,
		IsCompleted = false,
	}
end

function CarLifecycleService.start()
	EconomyService.OnPartSold:Connect(function(player: Player, car: Model?, sessionId: any, partId: any, _value: number)
		local session = currentSession
		if not session or session.IsCompleted then return end
		if car ~= session.Model or sessionId ~= session.SessionId then return end
		if typeof(partId) ~= "string" or not EXPECTED_PARTS[partId] or session.SoldParts[partId] then return end

		session.OwnerUserId = session.OwnerUserId or player.UserId
		session.LastSellerUserId = player.UserId
		session.SoldParts[partId] = true
		session.SoldCount += 1
		session.Model:SetAttribute("SoldPartsCount", session.SoldCount)

		if session.SoldCount == TOTAL_PARTS then
			task.defer(completeSession, session)
		end
	end)

	spawnNextCar()
end

return CarLifecycleService
