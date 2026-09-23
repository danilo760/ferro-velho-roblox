--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PartsCatalog = require(ReplicatedStorage.Shared.PartsCatalog)
local TrainingCarConfig = require(ReplicatedStorage.Shared.TrainingCarConfig)

local PartRemovalService = {}

local MAX_SERVER_DISTANCE = 12
local CARRY_OFFSET = CFrame.new(0, 0.5, -4)
local ENABLED_PARTS = { "Hood", "Battery", "HeadlightLeft", "HeadlightRight" }

type PartRuntime = {
	part: BasePart,
	prompt: ProximityPrompt,
	dependencies: {string},
	removalSlot: number,
	busy: boolean,
	carryWeld: WeldConstraint?,
}

local function getRoot(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end

	return nil
end

local function isPlayerCloseEnough(player: Player, part: BasePart): boolean
	local root = getRoot(player)
	return root ~= nil and (root.Position - part.Position).Magnitude <= MAX_SERVER_DISTANCE
end

local function getDependencies(partId: string): {string}
	for _, config in TrainingCarConfig.Parts do
		if config.PartId == partId then
			return config.RequiredPartsRemoved
		end
	end
	return {}
end

function PartRemovalService.setupCar(car: Model)
	local runtimes: {[string]: PartRuntime} = {}

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
		if not definition then
			return
		end

		if state == "Installed" then
			local allowed, blockerName = dependenciesRemoved(runtime)
			runtime.prompt.ActionText = if allowed then "Remover" else "Bloqueado"
			runtime.prompt.ObjectText = if allowed then definition.DisplayName else "Remova " .. (blockerName or "a peça anterior")
			runtime.prompt.HoldDuration = if allowed then definition.RemovalSeconds else 0
		elseif state == "Removed" then
			runtime.prompt.ActionText = "Pegar"
			runtime.prompt.ObjectText = definition.DisplayName
			runtime.prompt.HoldDuration = 0.25
		elseif state == "Carried" then
			runtime.prompt.ActionText = "Soltar"
			runtime.prompt.ObjectText = definition.DisplayName
			runtime.prompt.HoldDuration = 0
		end
	end

	local function refreshAll()
		for _, runtime in runtimes do
			refreshPrompt(runtime)
		end
	end

	local function placeRemoved(runtime: PartRuntime)
		local part = runtime.part
		local carPosition = car:GetPivot().Position
		local groundHeight = part.Size.Y / 2 + 0.05
		local slotZ = -5 + ((runtime.removalSlot - 1) * 2.4)
		part.Anchored = true
		part.CanCollide = true
		part.Massless = false
		part.AssemblyLinearVelocity = Vector3.zero
		part.AssemblyAngularVelocity = Vector3.zero
		part.CFrame = CFrame.new(carPosition.X - 7.5, groundHeight, carPosition.Z + slotZ)
	end

	local function dropPart(player: Player, runtime: PartRuntime)
		local root = getRoot(player)
		if not root then
			return
		end

		if runtime.carryWeld then
			runtime.carryWeld:Destroy()
			runtime.carryWeld = nil
		end

		local part = runtime.part
		part.Anchored = true
		part.CanCollide = true
		part.Massless = false
		part.CFrame = CFrame.new(root.Position + root.CFrame.LookVector * 5 + Vector3.new(0, -2.7 + part.Size.Y / 2, 0))
		part:SetAttribute("PartState", "Removed")
		part:SetAttribute("CarrierUserId", 0)
		player:SetAttribute("CarriedPartId", nil)
		refreshAll()
	end

	for slot, partId in ENABLED_PARTS do
		local instance = car:FindFirstChild(partId)
		assert(instance and instance:IsA("BasePart"), "Training car part is missing: " .. partId)
		local part = instance :: BasePart
		local definition = PartsCatalog[partId]
		assert(definition, "Part catalog entry is missing: " .. partId)

		part:SetAttribute("PartId", definition.Id)
		part:SetAttribute("PartState", "Installed")
		part:SetAttribute("CarrierUserId", 0)

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "PartPrompt"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = part

		local runtime: PartRuntime = {
			part = part,
			prompt = prompt,
			dependencies = getDependencies(partId),
			removalSlot = slot,
			busy = false,
			carryWeld = nil,
		}
		runtimes[partId] = runtime

		prompt.Triggered:Connect(function(player: Player)
			if runtime.busy or not Players:FindFirstChild(player.Name) then
				return
			end

			local state = part:GetAttribute("PartState")
			if state == "Installed" then
				local allowed = dependenciesRemoved(runtime)
				if not allowed or not isPlayerCloseEnough(player, part) then
					return
				end

				runtime.busy = true
				part:SetAttribute("PartState", "Removed")
				placeRemoved(runtime)
				runtime.busy = false
				refreshAll()
				return
			end

			if state == "Removed" then
				if player:GetAttribute("CarriedPartId") ~= nil or not isPlayerCloseEnough(player, part) then
					return
				end

				local root = getRoot(player)
				if not root then
					return
				end

				runtime.busy = true
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
		end)
	end

	refreshAll()
end

return PartRemovalService
