--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PartsCatalog = require(ReplicatedStorage.Shared.PartsCatalog)

local PartRemovalService = {}

local MAX_SERVER_DISTANCE = 12
local CARRY_OFFSET = CFrame.new(0, 0.5, -4)

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

function PartRemovalService.setupHood(car: Model)
	local hood = car:FindFirstChild("Hood")
	assert(hood and hood:IsA("BasePart"), "Training car Hood is missing")

	local definition = PartsCatalog.Hood
	hood:SetAttribute("PartId", definition.Id)
	hood:SetAttribute("PartState", "Installed")
	hood:SetAttribute("CarrierUserId", 0)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PartPrompt"
	prompt.ActionText = "Remover"
	prompt.ObjectText = definition.DisplayName
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = definition.RemovalSeconds
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = hood

	local busy = false
	local carryWeld: WeldConstraint? = nil

	local function dropPart(player: Player)
		local root = getRoot(player)
		if not root then
			return
		end

		if carryWeld then
			carryWeld:Destroy()
			carryWeld = nil
		end

		hood.Anchored = true
		hood.CanCollide = true
		hood.Massless = false
		hood.CFrame = CFrame.new(root.Position + root.CFrame.LookVector * 5 + Vector3.new(0, -2.7, 0))
		hood:SetAttribute("PartState", "Removed")
		hood:SetAttribute("CarrierUserId", 0)
		player:SetAttribute("CarriedPartId", nil)
		prompt.ActionText = "Pegar"
		prompt.ObjectText = definition.DisplayName
		prompt.HoldDuration = 0.25
	end

	prompt.Triggered:Connect(function(player: Player)
		if busy or not Players:FindFirstChild(player.Name) then
			return
		end

		local state = hood:GetAttribute("PartState")
		if state == "Installed" then
			if not isPlayerCloseEnough(player, hood) then
				return
			end

			busy = true
			hood:SetAttribute("PartState", "Removed")
			hood.Anchored = true
			hood.AssemblyLinearVelocity = Vector3.zero
			hood.AssemblyAngularVelocity = Vector3.zero
			hood.CFrame = CFrame.new(hood.Position + Vector3.new(-6.5, -3.4, 1.5))
			prompt.ActionText = "Pegar"
			prompt.HoldDuration = 0.25
			busy = false
			return
		end

		if state == "Removed" then
			if player:GetAttribute("CarriedPartId") ~= nil or not isPlayerCloseEnough(player, hood) then
				return
			end

			local root = getRoot(player)
			if not root then
				return
			end

			busy = true
			hood.Anchored = false
			hood.CanCollide = false
			hood.Massless = true
			hood.CFrame = root.CFrame * CARRY_OFFSET

			carryWeld = Instance.new("WeldConstraint")
			carryWeld.Name = "CarryWeld"
			carryWeld.Part0 = root
			carryWeld.Part1 = hood
			carryWeld.Parent = hood

			hood:SetAttribute("PartState", "Carried")
			hood:SetAttribute("CarrierUserId", player.UserId)
			player:SetAttribute("CarriedPartId", definition.Id)
			prompt.ActionText = "Soltar"
			prompt.ObjectText = definition.DisplayName
			prompt.HoldDuration = 0
			busy = false
			return
		end

		if state == "Carried" and hood:GetAttribute("CarrierUserId") == player.UserId then
			busy = true
			dropPart(player)
			busy = false
		end
	end)
end

return PartRemovalService
