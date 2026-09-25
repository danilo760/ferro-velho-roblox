--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local PartsCatalog = require(ReplicatedStorage.Shared.PartsCatalog)
local TrainingCarConfig = require(ReplicatedStorage.Shared.TrainingCarConfig)
local ToolUpgradeConfig = require(ReplicatedStorage.Shared.ToolUpgradeConfig)
local PartRemovalService = {}

type ActiveCarry = {
	Part: BasePart,
	Weld: WeldConstraint,
	Prompt: ProximityPrompt,
	SafeCFrame: CFrame,
}

local activeCarries: {[Player]: ActiveCarry} = {}
local MAX_SERVER_DISTANCE = 16
local CARRY_OFFSET = CFrame.new(0, 0.5, -4)
local ENABLED_PARTS = {
	"Hood", "Battery", "HeadlightLeft", "HeadlightRight", "DoorLeft", "DoorRight",
	"Trunk", "WheelFrontLeft", "WheelFrontRight", "WheelRearLeft", "WheelRearRight",
}

type PartRuntime = {
	part: BasePart, prompt: ProximityPrompt, dependencies: {string},
	removalSlot: number, busy: boolean, carryWeld: WeldConstraint?,
	triggerHandler: (Player) -> (),
}

local userRuntimes: {[number]: {[string]: PartRuntime}} = {}
local userBoxRuntimes: {[number]: {[number]: {[string]: PartRuntime}}} = {}

local function getRoot(player: Player): BasePart?
	local character = player.Character
	if not character then return nil end
	local root = character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function isPlayerCloseEnough(player: Player, part: BasePart): boolean
	local root = getRoot(player)
	return root ~= nil and (root.Position - part.Position).Magnitude <= MAX_SERVER_DISTANCE
end

local function getDependencies(partId: string): {string}
	for _, config in TrainingCarConfig.Parts do
		if config.PartId == partId then return config.RequiredPartsRemoved end
	end
	return {}
end

function PartRemovalService.setupCar(car: Model, ownerUserId: number?, plotGroundY: number?)
	local boxIndex = car:GetAttribute("BoxIndex") or 1
	local runtimes: {[string]: PartRuntime} = {}
	if ownerUserId then
		userRuntimes[ownerUserId] = runtimes
		if not userBoxRuntimes[ownerUserId] then
			userBoxRuntimes[ownerUserId] = {}
		end
		userBoxRuntimes[ownerUserId][boxIndex] = runtimes
	end

	local function getRemovalSeconds(defaultSeconds: number): number
		if not ownerUserId then return defaultSeconds end
		local owner = Players:GetPlayerByUserId(ownerUserId)
		local level = owner and owner:GetAttribute("ToolLevel")
		if typeof(level) ~= "number" then return defaultSeconds end
		local toolDefinition = ToolUpgradeConfig.Get(level)
		return if toolDefinition then toolDefinition.RemovalSeconds else defaultSeconds
	end

	local function dependenciesRemoved(runtime: PartRuntime): (boolean, string?)
		for _, dependencyId in runtime.dependencies do
			local dependency = car:FindFirstChild(dependencyId)
			if dependency and dependency:IsA("BasePart") and dependency:GetAttribute("PartState") == "Installed" then
				local definition = PartsCatalog[dependencyId]
				return false, if definition then definition.DisplayName else dependencyId
			end
		end
		return true, nil
	end

	local function refreshPrompt(runtime: PartRuntime)
		local state = runtime.part:GetAttribute("PartState")
		local definition = PartsCatalog[runtime.part.Name]
		if not definition then return end
		if state == "Installed" then
			local allowed, _blockerName = dependenciesRemoved(runtime)
			runtime.prompt.Enabled = allowed
			runtime.prompt.ActionText = "Remover"
			runtime.prompt.ObjectText = definition.DisplayName
			runtime.prompt.HoldDuration = getRemovalSeconds(definition.RemovalSeconds)
		elseif state == "Removed" then
			runtime.prompt.Enabled = true
			runtime.prompt.ActionText = "Pegar"
			runtime.prompt.ObjectText = definition.DisplayName
			runtime.prompt.HoldDuration = 0.25
		elseif state == "Carried" then
			runtime.prompt.Enabled = true
			runtime.prompt.ActionText = "Soltar"
			runtime.prompt.ObjectText = definition.DisplayName
			runtime.prompt.HoldDuration = 0
		else
			runtime.prompt.Enabled = false
		end
	end

	local function refreshAll()
		for _, runtime in runtimes do refreshPrompt(runtime) end
	end

	local function animateRemoved(runtime: PartRuntime)
		local part = runtime.part
		local carPivot = car:GetPivot()
		local groundHeight = (plotGroundY or 0) + part.Size.Y / 2 + 0.05
		local row = math.floor((runtime.removalSlot - 1) / 6)
		local column = (runtime.removalSlot - 1) % 6
		local side = if row == 0 then -1 else 1
		local localTarget = carPivot * CFrame.new(side * 7, 0, -6 + column * 2.5)
		local targetPosition = Vector3.new(localTarget.Position.X, groundHeight, localTarget.Position.Z)
		part.Anchored = true
		part.CanCollide = false
		part.Massless = false
		part.AssemblyLinearVelocity = Vector3.zero
		part.AssemblyAngularVelocity = Vector3.zero
		local liftTarget = part.CFrame * CFrame.new(0, 1.25, 0) * CFrame.Angles(math.rad(8), 0, math.rad(5))
		local liftTween = TweenService:Create(part, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = liftTarget })
		liftTween:Play()
		liftTween.Completed:Wait()
		local dropTarget = CFrame.new(targetPosition) * carPivot.Rotation * CFrame.Angles(0, math.rad(8 * runtime.removalSlot), 0)
		local moveTween = TweenService:Create(part, TweenInfo.new(0.38, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { CFrame = dropTarget })
		moveTween:Play()
		moveTween.Completed:Wait()
		part.CanCollide = true
	end

	local function dropPart(player: Player, runtime: PartRuntime)
		local root = getRoot(player)
		if not root then return end
		local carryData = activeCarries[player]
		if runtime.carryWeld then runtime.carryWeld:Destroy() runtime.carryWeld = nil end
		activeCarries[player] = nil
		local part = runtime.part
		part.Anchored = true
		part.CanCollide = true
		part.Massless = false
		local horizontalRadius = math.max(part.Size.X, part.Size.Z) / 2
		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
		local character = player.Character
		raycastParams.FilterDescendantsInstances = if character then { character, part } else { part }

		local function availableDistance(direction: Vector3): number
			local obstruction = Workspace:Raycast(root.Position, direction * 5, raycastParams)
			if obstruction and obstruction.Instance.CanCollide then
				return obstruction.Distance - horizontalRadius - 0.5
			end
			return 5
		end

		local dropDirection = root.CFrame.LookVector
		local desiredDistance = availableDistance(dropDirection)
		if desiredDistance < 1.5 then
			local reverseDirection = -dropDirection
			local reverseDistance = availableDistance(reverseDirection)
			if reverseDistance >= 1.5 then
				dropDirection = reverseDirection
				desiredDistance = reverseDistance
			elseif carryData then
				part.CFrame = carryData.SafeCFrame
				desiredDistance = 0
			else
				desiredDistance = 1.5
			end
		end
		if desiredDistance > 0 then
			local dropPosition = root.Position + dropDirection * math.min(desiredDistance, 5)
			local dropY = (plotGroundY or 0) + part.Size.Y / 2 + 0.05
			part.CFrame = CFrame.new(dropPosition.X, dropY, dropPosition.Z)
		end
		part:SetAttribute("PartState", "Removed")
		part:SetAttribute("CarrierUserId", 0)
		part:SetAttribute("OwnerUserId", ownerUserId or 0)
		player:SetAttribute("CarriedPartId", nil)
		refreshAll()
	end

	for slot, partId in ENABLED_PARTS do
		local instance = car:FindFirstChild(partId)
		if not instance or not instance:IsA("BasePart") then
			continue
		end
		local part = instance :: BasePart
		local definition = PartsCatalog[partId]
		assert(definition, "Part catalog entry is missing: " .. partId)
		part:SetAttribute("PartId", definition.Id)
		part:SetAttribute("PartState", "Installed")
		part:SetAttribute("CarrierUserId", 0)
		part:SetAttribute("OwnerUserId", ownerUserId or 0)
		part:SetAttribute("CarSessionId", car:GetAttribute("CarSessionId"))
		part:SetAttribute("BoxIndex", car:GetAttribute("BoxIndex") or 1)
		local interactionPoint = Instance.new("Attachment")
		interactionPoint.Name = "InteractionPoint"
		interactionPoint.Position = Vector3.new(0, math.max(part.Size.Y / 2 + 1.2, 1.5), 0)
		interactionPoint.Parent = part

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "PartPrompt"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.MaxActivationDistance = if partId == "Hood" then 16 else 13
		prompt.RequiresLineOfSight = false
		prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
		prompt.UIOffset = Vector2.new(0, -12)
		prompt.Parent = interactionPoint

		local runtime: PartRuntime
		local function handleTrigger(player: Player)
			if ownerUserId and player.UserId ~= ownerUserId then return end
			if runtime.busy or not Players:FindFirstChild(player.Name) then return end
			local state = part:GetAttribute("PartState")
			if state == "Installed" then
				local allowed = dependenciesRemoved(runtime)
				if not allowed or not isPlayerCloseEnough(player, part) then return end
				runtime.busy = true
				part:SetAttribute("PartState", "Removing")
				refreshAll()
				animateRemoved(runtime)
				part:SetAttribute("PartState", "Removed")
				runtime.busy = false
				refreshAll()
				return
			end
			if state == "Removed" then
				if player:GetAttribute("CarriedPartId") ~= nil or not isPlayerCloseEnough(player, part) then return end
				local root = getRoot(player)
				if not root then return end
				runtime.busy = true
				local safeCFrame = part.CFrame
				part.Anchored = false
				part.CanCollide = false
				part.Massless = true
				part.CFrame = root.CFrame * CARRY_OFFSET
				local weld = Instance.new("WeldConstraint")
				weld.Name = "CarryWeld"
				weld.Part0 = root
				weld.Part1 = part
				weld.Parent = part
				runtime.carryWeld = weld
				activeCarries[player] = {
					Part = part,
					Weld = weld,
					Prompt = prompt,
					SafeCFrame = safeCFrame,
				}
				part:SetAttribute("PartState", "Carried")
				part:SetAttribute("CarrierUserId", player.UserId)
				player:SetAttribute("CarriedPartId", definition.Id)
				runtime.busy = false
				refreshAll()
				return
			end
			if state == "Carried" and part:GetAttribute("CarrierUserId") == player.UserId then
				runtime.busy = true
				dropPart(player, runtime)
				runtime.busy = false
			end
		end

		runtime = {
			part = part, prompt = prompt, dependencies = getDependencies(partId),
			removalSlot = slot, busy = false, carryWeld = nil, triggerHandler = handleTrigger,
		}
		runtimes[partId] = runtime
		prompt.Triggered:Connect(handleTrigger)

		local testTrigger = Instance.new("BindableFunction")
		testTrigger.Name = "TestTrigger"
		testTrigger.OnInvoke = function(p: Player)
			handleTrigger(p)
			return true
		end
		testTrigger.Parent = prompt
	end

	local owner = if ownerUserId then Players:GetPlayerByUserId(ownerUserId) else nil
	if owner then
		local toolLevelConnection = owner:GetAttributeChangedSignal("ToolLevel"):Connect(refreshAll)
		car.Destroying:Once(function()
			toolLevelConnection:Disconnect()
			if ownerUserId then
				if userRuntimes[ownerUserId] == runtimes then
					userRuntimes[ownerUserId] = nil
				end
				if userBoxRuntimes[ownerUserId] and userBoxRuntimes[ownerUserId][boxIndex] == runtimes then
					userBoxRuntimes[ownerUserId][boxIndex] = nil
				end
			end
		end)
	end
	refreshAll()
end

function PartRemovalService.TriggerPart(player: Player, partId: string, boxIndex: number?): boolean
	local runtimes = if boxIndex and userBoxRuntimes[player.UserId]
		then userBoxRuntimes[player.UserId][boxIndex]
		else userRuntimes[player.UserId]
	local runtime = runtimes and runtimes[partId]
	if runtime then
		runtime.triggerHandler(player)
		return true
	end
	return false
end

function PartRemovalService.GetCarriedPart(player: Player): BasePart?
	local data = activeCarries[player]
	if data and data.Part and data.Part.Parent then
		return data.Part
	end
	return nil
end

function PartRemovalService.ClearCarriedPart(player: Player)
	activeCarries[player] = nil
	player:SetAttribute("CarriedPartId", nil)
end

function PartRemovalService.HandlePlayerLoss(player: Player)
	local data = activeCarries[player]
	if not data then
		player:SetAttribute("CarriedPartId", nil)
		return
	end

	if data.Weld.Parent then data.Weld:Destroy() end
	local part = data.Part
	if part.Parent then
		part.Anchored = true
		part.CanCollide = true
		part.Massless = false
		part.CFrame = data.SafeCFrame
		part:SetAttribute("PartState", "Removed")
		part:SetAttribute("CarrierUserId", 0)
		data.Prompt.ActionText = "Pegar"
		data.Prompt.HoldDuration = 0.25
		data.Prompt.Enabled = true
	end

	activeCarries[player] = nil
	player:SetAttribute("CarriedPartId", nil)
end

return PartRemovalService
