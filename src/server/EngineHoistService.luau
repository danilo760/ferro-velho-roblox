--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local PartsCatalog = require(ReplicatedStorage.Shared.PartsCatalog)
local EngineHoistService = {}
local HOIST_HOME = CFrame.new(9, 1, -37)
local activeHoist: Model? = nil
local activeEngine: BasePart? = nil

local function createHoistPart(model: Model, name: string, size: Vector3, relativePosition: Vector3, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = HOIST_HOME * CFrame.new(relativePosition)
	part.Anchored = true
	part.CanCollide = true
	part.Material = Enum.Material.Metal
	part.Color = color
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = model
	return part
end

local function weldToBase(base: BasePart, part: BasePart)
	local weld = Instance.new("WeldConstraint")
	weld.Name = "HoistWeld"
	weld.Part0 = base
	weld.Part1 = part
	weld.Parent = part
end

local function createHoist(): Model
	local old = Workspace:FindFirstChild("EngineHoist01")
	if old then old:Destroy() end
	local model = Instance.new("Model")
	model.Name = "EngineHoist01"
	model:SetAttribute("State", "Empty")
	model:SetAttribute("CarrierUserId", 0)
	local red = Color3.fromRGB(190, 45, 38)
	local dark = Color3.fromRGB(35, 35, 38)
	local base = createHoistPart(model, "Base", Vector3.new(5, 0.45, 6), Vector3.new(0, 0, 0), red)
	model.PrimaryPart = base
	for _, data in {
		{ "Upright", Vector3.new(0.5, 5.5, 0.5), Vector3.new(0, 2.75, 2.3), red },
		{ "Boom", Vector3.new(0.45, 0.45, 5.5), Vector3.new(0, 5.3, -0.25), red },
		{ "Hook", Vector3.new(0.25, 2.2, 0.25), Vector3.new(0, 4.2, -2.8), dark },
	} do
		local part = createHoistPart(model, data[1] :: string, data[2] :: Vector3, data[3] :: Vector3, data[4] :: Color3)
		weldToBase(base, part)
	end
	for index, offset in {
		Vector3.new(-2.1, -0.45, -2.3), Vector3.new(2.1, -0.45, -2.3),
		Vector3.new(-2.1, -0.45, 2.3), Vector3.new(2.1, -0.45, 2.3),
	} do
		local wheel = createHoistPart(model, "Caster" .. index, Vector3.new(0.7, 0.7, 0.7), offset, dark)
		wheel.Shape = Enum.PartType.Ball
		weldToBase(base, wheel)
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "HoistPrompt"
	prompt.ActionText = "Aguardando motor"
	prompt.ObjectText = "Guincho de motor"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt.Parent = base
	model.Parent = Workspace
	return model
end

local function dependencyRemoved(car: Model, partName: string): boolean
	local part = car:FindFirstChild(partName)
	return part == nil or (part:IsA("BasePart") and part:GetAttribute("PartState") ~= "Installed")
end

function EngineHoistService.start(car: Model)
	local engine = car:FindFirstChild("Engine")
	assert(engine and engine:IsA("BasePart"), "Training car Engine is missing")
	local definition = PartsCatalog.Engine
	local hoist = createHoist()
	activeHoist = hoist
	activeEngine = engine
	local base = hoist.PrimaryPart :: BasePart
	local hoistPrompt = base:FindFirstChild("HoistPrompt") :: ProximityPrompt
	engine:SetAttribute("PartId", definition.Id)
	engine:SetAttribute("PartState", "Installed")
	engine:SetAttribute("CarrierUserId", 0)

	local enginePoint = Instance.new("Attachment")
	enginePoint.Name = "EngineInteractionPoint"
	enginePoint.Position = Vector3.new(0, engine.Size.Y / 2 + 0.8, 0)
	enginePoint.Parent = engine

	local enginePrompt = Instance.new("ProximityPrompt")
	enginePrompt.Name = "EnginePrompt"
	enginePrompt.KeyboardKeyCode = Enum.KeyCode.E
	enginePrompt.MaxActivationDistance = 11
	enginePrompt.RequiresLineOfSight = false
	enginePrompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
	enginePrompt.Parent = enginePoint

	local function refreshEnginePrompt()
		if engine:GetAttribute("PartState") ~= "Installed" then enginePrompt.Enabled = false return end
		if not dependencyRemoved(car, "Hood") then
			enginePrompt.Enabled = false
			return
		end
		enginePrompt.Enabled = true
		if not dependencyRemoved(car, "Battery") then
			enginePrompt.ActionText = "Bloqueado"
			enginePrompt.ObjectText = "Remova Bateria"
			enginePrompt.HoldDuration = 0
		else
			enginePrompt.ActionText = "Usar guincho"
			enginePrompt.ObjectText = definition.DisplayName
			enginePrompt.HoldDuration = definition.RemovalSeconds
		end
	end

	refreshEnginePrompt()
	for _, dependencyName in { "Hood", "Battery" } do
		local dependency = car:FindFirstChild(dependencyName)
		if dependency then dependency:GetAttributeChangedSignal("PartState"):Connect(refreshEnginePrompt) end
	end

	local busy = false
	local moveWeld: WeldConstraint? = nil

	local function setAnchored(value: boolean)
		for _, descendant in hoist:GetDescendants() do
			if descendant:IsA("BasePart") then descendant.Anchored = value end
		end
	end

	enginePrompt.Triggered:Connect(function(player: Player)
		if busy or not dependencyRemoved(car, "Hood") or not dependencyRemoved(car, "Battery") then return end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") or (root.Position - engine.Position).Magnitude > 12 then return end
		busy = true
		enginePrompt.Enabled = false
		engine.Anchored = false
		engine.CanCollide = false
		engine.Massless = true
		engine.CFrame = base.CFrame * CFrame.new(0, 2.1, 0)
		local engineWeld = Instance.new("WeldConstraint")
		engineWeld.Name = "EngineToHoist"
		engineWeld.Part0 = base
		engineWeld.Part1 = engine
		engineWeld.Parent = engine
		engine:SetAttribute("PartState", "OnHoist")
		hoist:SetAttribute("State", "Loaded")
		hoistPrompt.ActionText = "Empurrar"
		hoistPrompt.ObjectText = "Guincho com motor"
		hoistPrompt.Enabled = true
		busy = false
	end)

	hoistPrompt.Triggered:Connect(function(player: Player)
		if busy then return end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then return end
		local state = hoist:GetAttribute("State")

		if state == "Loaded" or state == "Empty" then
			if (root.Position - base.Position).Magnitude > 12 then return end
			if state == "Loaded" and player:GetAttribute("CarriedPartId") ~= nil then return end
			busy = true
			hoist:PivotTo(root.CFrame * CFrame.new(0, -2.3, -6))
			setAnchored(false)
			moveWeld = Instance.new("WeldConstraint")
			moveWeld.Name = "CarryWeld"
			moveWeld.Part0 = root
			moveWeld.Part1 = base
			moveWeld.Parent = base
			hoist:SetAttribute("CarrierUserId", player.UserId)
			if state == "Loaded" then
				engine:SetAttribute("PartState", "Carried")
				engine:SetAttribute("CarrierUserId", player.UserId)
				player:SetAttribute("CarriedPartId", "Engine")
				hoist:SetAttribute("State", "Moving")
			else
				hoist:SetAttribute("State", "MovingEmpty")
			end
			hoistPrompt.ActionText = "Soltar guincho"
			busy = false
			return
		end

		if (state == "Moving" or state == "MovingEmpty") and hoist:GetAttribute("CarrierUserId") == player.UserId then
			busy = true
			if moveWeld then
				moveWeld:Destroy()
				moveWeld = nil
			else
				local existingWeld = base:FindFirstChild("CarryWeld")
				if existingWeld then existingWeld:Destroy() end
			end
			setAnchored(true)
			hoist:SetAttribute("CarrierUserId", 0)
			if state == "Moving" and engine.Parent then
				engine:SetAttribute("PartState", "OnHoist")
				engine:SetAttribute("CarrierUserId", 0)
				player:SetAttribute("CarriedPartId", nil)
				hoist:SetAttribute("State", "Loaded")
				hoistPrompt.ActionText = "Empurrar"
			else
				hoist:SetAttribute("State", "Empty")
				hoistPrompt.ActionText = "Empurrar vazio"
			end
			busy = false
		end
	end)
end

function EngineHoistService.ReleasePlayer(player: Player)
	local hoist = activeHoist
	if not hoist or hoist:GetAttribute("CarrierUserId") ~= player.UserId then return end
	local base = hoist.PrimaryPart
	if not base then return end

	local carryWeld = base:FindFirstChild("CarryWeld")
	if carryWeld then carryWeld:Destroy() end
	for _, descendant in hoist:GetDescendants() do
		if descendant:IsA("BasePart") then descendant.Anchored = true end
	end
	hoist:PivotTo(HOIST_HOME)
	hoist:SetAttribute("CarrierUserId", 0)

	local engine = activeEngine
	local prompt = base:FindFirstChild("HoistPrompt")
	if engine and engine.Parent and engine:GetAttribute("PartState") == "Carried" then
		engine:SetAttribute("PartState", "OnHoist")
		engine:SetAttribute("CarrierUserId", 0)
		hoist:SetAttribute("State", "Loaded")
		if prompt and prompt:IsA("ProximityPrompt") then
			prompt.ActionText = "Empurrar"
			prompt.ObjectText = "Guincho com motor"
			prompt.Enabled = true
		end
	else
		hoist:SetAttribute("State", "Empty")
		if prompt and prompt:IsA("ProximityPrompt") then
			prompt.ActionText = "Empurrar vazio"
			prompt.ObjectText = "Guincho de motor"
			prompt.Enabled = true
		end
	end

	player:SetAttribute("CarriedPartId", nil)
end

return EngineHoistService
