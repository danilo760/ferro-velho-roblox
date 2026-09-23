--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local PartsCatalog = require(ReplicatedStorage.Shared.PartsCatalog)

local EngineHoistService = {}

local HOIST_HOME = CFrame.new(9, 1, -37)

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

	local upright = createHoistPart(model, "Upright", Vector3.new(0.5, 5.5, 0.5), Vector3.new(0, 2.75, 2.3), red)
	local boom = createHoistPart(model, "Boom", Vector3.new(0.45, 0.45, 5.5), Vector3.new(0, 5.3, -0.25), red)
	local hook = createHoistPart(model, "Hook", Vector3.new(0.25, 2.2, 0.25), Vector3.new(0, 4.2, -2.8), dark)
	weldToBase(base, upright)
	weldToBase(base, boom)
	weldToBase(base, hook)

	for index, offset in {
		Vector3.new(-2.1, -0.45, -2.3),
		Vector3.new(2.1, -0.45, -2.3),
		Vector3.new(-2.1, -0.45, 2.3),
		Vector3.new(2.1, -0.45, 2.3),
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
	local base = hoist.PrimaryPart :: BasePart
	local hoistPrompt = base:FindFirstChild("HoistPrompt") :: ProximityPrompt

	engine:SetAttribute("PartId", definition.Id)
	engine:SetAttribute("PartState", "Installed")
	engine:SetAttribute("CarrierUserId", 0)

	local enginePrompt = Instance.new("ProximityPrompt")
	enginePrompt.Name = "EnginePrompt"
	enginePrompt.KeyboardKeyCode = Enum.KeyCode.E
	enginePrompt.MaxActivationDistance = 10
	enginePrompt.RequiresLineOfSight = false
	enginePrompt.Parent = engine

	local function refreshEnginePrompt()
		if engine:GetAttribute("PartState") ~= "Installed" then
			enginePrompt.Enabled = false
			return
		end
		enginePrompt.Enabled = true
		if not dependencyRemoved(car, "Hood") then
			enginePrompt.ActionText = "Bloqueado"
			enginePrompt.ObjectText = "Remova Capô"
			enginePrompt.HoldDuration = 0
		elseif not dependencyRemoved(car, "Battery") then
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
		if dependency then
			dependency:GetAttributeChangedSignal("PartState"):Connect(refreshEnginePrompt)
		end
	end

	local busy = false
	local engineWeld: WeldConstraint? = nil
	local moveWeld: WeldConstraint? = nil

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

		engineWeld = Instance.new("WeldConstraint")
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
		if busy or hoist:GetAttribute("State") == "Empty" then return end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then return end

		local state = hoist:GetAttribute("State")
		if state == "Loaded" then
			if player:GetAttribute("CarriedPartId") ~= nil or (root.Position - base.Position).Magnitude > 12 then return end
			busy = true
			hoist:PivotTo(root.CFrame * CFrame.new(0, -2.3, -6))
			for _, descendant in hoist:GetDescendants() do
				if descendant:IsA("BasePart") then descendant.Anchored = false end
			end
			moveWeld = Instance.new("WeldConstraint")
			moveWeld.Name = "CarryWeld"
			moveWeld.Part0 = root
			moveWeld.Part1 = base
			moveWeld.Parent = base
			engine:SetAttribute("PartState", "Carried")
			engine:SetAttribute("CarrierUserId", player.UserId)
			player:SetAttribute("CarriedPartId", "Engine")
			hoist:SetAttribute("State", "Moving")
			hoist:SetAttribute("CarrierUserId", player.UserId)
			hoistPrompt.ActionText = "Soltar guincho"
			busy = false
		elseif state == "Moving" and hoist:GetAttribute("CarrierUserId") == player.UserId then
			busy = true
			if moveWeld then moveWeld:Destroy() moveWeld = nil end
			for _, descendant in hoist:GetDescendants() do
				if descendant:IsA("BasePart") then descendant.Anchored = true end
			end
			engine:SetAttribute("PartState", "OnHoist")
			engine:SetAttribute("CarrierUserId", 0)
			player:SetAttribute("CarriedPartId", nil)
			hoist:SetAttribute("State", "Loaded")
			hoist:SetAttribute("CarrierUserId", 0)
			hoistPrompt.ActionText = "Empurrar"
			busy = false
		end
	end)
end

return EngineHoistService
