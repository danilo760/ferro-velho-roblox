--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local PartsCatalog = require(ReplicatedStorage.Shared.PartsCatalog)

local EngineHoistService = {}

type HoistRuntime = {
	OwnerUserId: number,
	BoxIndex: number,
	Home: CFrame,
	Model: Model,
	Engine: BasePart,
	MoveWeld: WeldConstraint?,
	TriggerEngine: (Player) -> boolean,
	TriggerHoist: (Player) -> boolean,
}

local runtimes: {[string]: HoistRuntime} = {}

local function hoistKey(ownerUserId: number, boxIndex: number): string
	return string.format("%d_%d", ownerUserId, boxIndex)
end

local function createPart(model: Model, home: CFrame, name: string, size: Vector3, offset: Vector3, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = home * CFrame.new(offset)
	part.Anchored = true
	part.CanCollide = true
	part.Material = Enum.Material.Metal
	part.Color = color
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = model
	return part
end

local function weld(base: BasePart, part: BasePart, name: string)
	local joint = Instance.new("WeldConstraint")
	joint.Name = name
	joint.Part0 = base
	joint.Part1 = part
	joint.Parent = part
end

local function createHoist(home: CFrame, ownerUserId: number, boxIndex: number): Model
	local model = Instance.new("Model")
	model.Name = string.format("EngineHoist_%d_%d", ownerUserId, boxIndex)
	model:SetAttribute("OwnerUserId", ownerUserId)
	model:SetAttribute("BoxIndex", boxIndex)
	model:SetAttribute("CarrierUserId", 0)
	model:SetAttribute("State", "Empty")
	local red = Color3.fromRGB(190, 45, 38)
	local dark = Color3.fromRGB(35, 35, 38)
	local base = createPart(model, home, "Base", Vector3.new(5, 0.45, 6), Vector3.zero, red)
	model.PrimaryPart = base
	for _, data in {
		{ "Upright", Vector3.new(0.5, 5.5, 0.5), Vector3.new(0, 2.75, 2.3), red },
		{ "Boom", Vector3.new(0.45, 0.45, 5.5), Vector3.new(0, 5.3, -0.25), red },
		{ "Hook", Vector3.new(0.25, 2.2, 0.25), Vector3.new(0, 4.2, -2.8), dark },
	} do
		local part = createPart(model, home, data[1] :: string, data[2] :: Vector3, data[3] :: Vector3, data[4] :: Color3)
		weld(base, part, "HoistWeld")
	end
	for index, offset in {
		Vector3.new(-2.1, -0.45, -2.3), Vector3.new(2.1, -0.45, -2.3),
		Vector3.new(-2.1, -0.45, 2.3), Vector3.new(2.1, -0.45, 2.3),
	} do
		local wheel = createPart(model, home, "Caster" .. index, Vector3.new(0.7, 0.7, 0.7), offset, dark)
		wheel.Shape = Enum.PartType.Ball
		weld(base, wheel, "HoistWeld")
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "HoistPrompt"
	prompt.ActionText = "Aguardando motor"
	prompt.ObjectText = string.format("Guincho de motor (Box %d)", boxIndex)
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt.Parent = base
	model.Parent = Workspace
	return model
end

local function dependencyRemoved(car: Model, name: string): boolean
	local part = car:FindFirstChild(name)
	return part == nil or (part:IsA("BasePart") and part:GetAttribute("PartState") ~= "Installed")
end

local function setAnchored(model: Model, value: boolean)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = value
			descendant.CanCollide = value
			descendant.Massless = not value
		end
	end
end

function EngineHoistService.start(car: Model, home: CFrame, ownerUserId: number, boxIndex: number?)
	local bIndex = boxIndex or 1
	EngineHoistService.RemoveForOwner(ownerUserId, bIndex)
	local engine = car:FindFirstChild("Engine")
	assert(engine and engine:IsA("BasePart"), "Training car Engine is missing")
	local definition = PartsCatalog.Engine
	local hoist = createHoist(home, ownerUserId, bIndex)
	local base = hoist.PrimaryPart :: BasePart
	local hoistPrompt = base:FindFirstChild("HoistPrompt") :: ProximityPrompt
	local runtime: HoistRuntime
	local key = hoistKey(ownerUserId, bIndex)

	engine:SetAttribute("PartId", definition.Id)
	engine:SetAttribute("PartState", "Installed")
	engine:SetAttribute("CarrierUserId", 0)
	engine:SetAttribute("OwnerUserId", ownerUserId)
	engine:SetAttribute("BoxIndex", bIndex)
	engine:SetAttribute("CarSessionId", car:GetAttribute("CarSessionId"))

	local point = Instance.new("Attachment")
	point.Position = Vector3.new(0, engine.Size.Y / 2 + 0.8, 0)
	point.Parent = engine
	local enginePrompt = Instance.new("ProximityPrompt")
	enginePrompt.Name = "EnginePrompt"
	enginePrompt.KeyboardKeyCode = Enum.KeyCode.E
	enginePrompt.MaxActivationDistance = 11
	enginePrompt.RequiresLineOfSight = false
	enginePrompt.Parent = point

	local function refresh()
		if engine:GetAttribute("PartState") ~= "Installed" then
			enginePrompt.Enabled = false
			return
		end
		if not dependencyRemoved(car, "Hood") or not dependencyRemoved(car, "Battery") then
			enginePrompt.Enabled = false
			return
		end
		enginePrompt.Enabled = true
		enginePrompt.ActionText = "Usar guincho"
		enginePrompt.ObjectText = definition.DisplayName .. string.format(" (Box %d)", bIndex)
		enginePrompt.HoldDuration = definition.RemovalSeconds
	end

	refresh()
	for _, dependencyName in { "Hood", "Battery" } do
		local dependency = car:FindFirstChild(dependencyName)
		if dependency then dependency:GetAttributeChangedSignal("PartState"):Connect(refresh) end
	end

	local busy = false
	local function handleEngineTrigger(player: Player): boolean
		if player.UserId ~= ownerUserId or busy then return false end
		if not dependencyRemoved(car, "Hood") or not dependencyRemoved(car, "Battery") then return false end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") or (root.Position - engine.Position).Magnitude > 16 then return false end
		busy = true
		enginePrompt.Enabled = false
		engine.Anchored = false
		engine.CanCollide = false
		engine.Massless = true
		engine.CFrame = base.CFrame * CFrame.new(0, 2.1, 0)
		weld(base, engine, "EngineToHoist")
		engine:SetAttribute("PartState", "OnHoist")
		hoist:SetAttribute("State", "Loaded")
		hoistPrompt.ActionText = "Empurrar"
		hoistPrompt.ObjectText = string.format("Guincho com motor (Box %d)", bIndex)
		hoistPrompt.Enabled = true
		busy = false
		return true
	end

	local function handleHoistTrigger(player: Player): boolean
		if player.UserId ~= ownerUserId or busy then return false end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then return false end
		local state = hoist:GetAttribute("State")
		if state == "Loaded" or state == "Empty" then
			if (root.Position - base.Position).Magnitude > 16 then return false end
			if state == "Loaded" and player:GetAttribute("CarriedPartId") ~= nil then return false end
			busy = true
			hoist:PivotTo(root.CFrame * CFrame.new(0, -2.3, -6))
			setAnchored(hoist, false)
			local moveWeld = Instance.new("WeldConstraint")
			moveWeld.Name = "CarryWeld"
			moveWeld.Part0 = root
			moveWeld.Part1 = base
			moveWeld.Parent = base
			runtime.MoveWeld = moveWeld
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
			return true
		elseif state == "Moving" or state == "MovingEmpty" then
			if hoist:GetAttribute("CarrierUserId") ~= player.UserId then return false end
			busy = true
			if runtime.MoveWeld then runtime.MoveWeld:Destroy() runtime.MoveWeld = nil end
			setAnchored(hoist, true)
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
			return true
		end
		return false
	end

	runtime = {
		OwnerUserId = ownerUserId, BoxIndex = bIndex, Home = home, Model = hoist,
		Engine = engine, MoveWeld = nil, TriggerEngine = handleEngineTrigger, TriggerHoist = handleHoistTrigger,
	}
	runtimes[key] = runtime

	enginePrompt.Triggered:Connect(function(player) handleEngineTrigger(player) end)
	hoistPrompt.Triggered:Connect(function(player) handleHoistTrigger(player) end)

	local engineTestTrigger = Instance.new("BindableFunction")
	engineTestTrigger.Name = "TestTrigger"
	engineTestTrigger.OnInvoke = function(p: Player)
		return handleEngineTrigger(p)
	end
	engineTestTrigger.Parent = enginePrompt

	local hoistTestTrigger = Instance.new("BindableFunction")
	hoistTestTrigger.Name = "TestTrigger"
	hoistTestTrigger.OnInvoke = function(p: Player)
		return handleHoistTrigger(p)
	end
	hoistTestTrigger.Parent = hoistPrompt
end

function EngineHoistService.TriggerEngine(player: Player, boxIndex: number?): boolean
	local bIndex = boxIndex or 1
	local runtime = runtimes[hoistKey(player.UserId, bIndex)]
	return if runtime then runtime.TriggerEngine(player) else false
end

function EngineHoistService.TriggerHoist(player: Player, boxIndex: number?): boolean
	local bIndex = boxIndex or 1
	local runtime = runtimes[hoistKey(player.UserId, bIndex)]
	return if runtime then runtime.TriggerHoist(player) else false
end

function EngineHoistService.GetCarriedEngine(player: Player): BasePart?
	for _, runtime in runtimes do
		if runtime.OwnerUserId == player.UserId and runtime.Model:GetAttribute("CarrierUserId") == player.UserId then
			if runtime.Engine and runtime.Engine.Parent and runtime.Engine:GetAttribute("PartState") == "Carried" then
				return runtime.Engine
			end
		end
	end
	return nil
end

function EngineHoistService.CompleteEngineSale(player: Player)
	for _, runtime in runtimes do
		if runtime.OwnerUserId == player.UserId and runtime.Model:GetAttribute("CarrierUserId") == player.UserId then
			if runtime.MoveWeld then runtime.MoveWeld:Destroy() runtime.MoveWeld = nil end
			setAnchored(runtime.Model, true)
			runtime.Model:SetAttribute("State", "Empty")
			runtime.Model:SetAttribute("CarrierUserId", 0)
			local base = runtime.Model.PrimaryPart
			local prompt = base and base:FindFirstChild("HoistPrompt")
			if prompt and prompt:IsA("ProximityPrompt") then
				prompt.ActionText = "Empurrar vazio"
				prompt.Enabled = true
			end
			return
		end
	end
end

function EngineHoistService.ReleasePlayer(player: Player)
	for _, runtime in runtimes do
		if runtime.OwnerUserId == player.UserId and runtime.Model:GetAttribute("CarrierUserId") == player.UserId then
			if runtime.MoveWeld then runtime.MoveWeld:Destroy() runtime.MoveWeld = nil end
			setAnchored(runtime.Model, true)
			runtime.Model:PivotTo(runtime.Home)
			runtime.Model:SetAttribute("CarrierUserId", 0)
			if runtime.Engine.Parent and runtime.Engine:GetAttribute("PartState") == "Carried" then
				runtime.Engine:SetAttribute("PartState", "OnHoist")
				runtime.Engine:SetAttribute("CarrierUserId", 0)
				runtime.Model:SetAttribute("State", "Loaded")
			else
				runtime.Model:SetAttribute("State", "Empty")
			end
			player:SetAttribute("CarriedPartId", nil)
		end
	end
end

function EngineHoistService.ResetForCycle(ownerUserId: number, boxIndex: number?)
	if boxIndex then
		local runtime = runtimes[hoistKey(ownerUserId, boxIndex)]
		if runtime then
			if runtime.MoveWeld then runtime.MoveWeld:Destroy() runtime.MoveWeld = nil end
			setAnchored(runtime.Model, true)
			runtime.Model:PivotTo(runtime.Home)
			runtime.Model:SetAttribute("State", "Empty")
			runtime.Model:SetAttribute("CarrierUserId", 0)
		end
	else
		for _, runtime in runtimes do
			if runtime.OwnerUserId == ownerUserId then
				if runtime.MoveWeld then runtime.MoveWeld:Destroy() runtime.MoveWeld = nil end
				setAnchored(runtime.Model, true)
				runtime.Model:PivotTo(runtime.Home)
				runtime.Model:SetAttribute("State", "Empty")
				runtime.Model:SetAttribute("CarrierUserId", 0)
			end
		end
	end
end

function EngineHoistService.RemoveForOwner(ownerUserId: number, boxIndex: number?)
	if boxIndex then
		local key = hoistKey(ownerUserId, boxIndex)
		local runtime = runtimes[key]
		if runtime then
			if runtime.MoveWeld then runtime.MoveWeld:Destroy() end
			if runtime.Model.Parent then runtime.Model:Destroy() end
			runtimes[key] = nil
		end
	else
		local keysToRemove = {}
		for key, runtime in runtimes do
			if runtime.OwnerUserId == ownerUserId then
				if runtime.MoveWeld then runtime.MoveWeld:Destroy() end
				if runtime.Model.Parent then runtime.Model:Destroy() end
				table.insert(keysToRemove, key)
			end
		end
		for _, key in keysToRemove do runtimes[key] = nil end
	end
end

return EngineHoistService
