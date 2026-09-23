--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PartsCatalog = require(ReplicatedStorage.Shared.PartsCatalog)

local PartRemovalService = {}

local MAX_SERVER_DISTANCE = 12

local function isPlayerCloseEnough(player: Player, part: BasePart): boolean
	local character = player.Character
	if not character then
		return false
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end

	return (root.Position - part.Position).Magnitude <= MAX_SERVER_DISTANCE
end

function PartRemovalService.setupHood(car: Model)
	local hood = car:FindFirstChild("Hood")
	assert(hood and hood:IsA("BasePart"), "Training car Hood is missing")

	local definition = PartsCatalog.Hood
	hood:SetAttribute("PartId", definition.Id)
	hood:SetAttribute("PartState", "Installed")

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RemovePrompt"
	prompt.ActionText = "Remover"
	prompt.ObjectText = definition.DisplayName
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = definition.RemovalSeconds
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = hood

	local removing = false

	prompt.Triggered:Connect(function(player: Player)
		if removing or hood:GetAttribute("PartState") ~= "Installed" then
			return
		end

		if not Players:FindFirstChild(player.Name) or not isPlayerCloseEnough(player, hood) then
			return
		end

		removing = true
		hood:SetAttribute("PartState", "Removed")
		prompt.Enabled = false
		hood.Anchored = false
		hood.AssemblyLinearVelocity = Vector3.new(0, 3, -2)
		hood.AssemblyAngularVelocity = Vector3.new(0, 0, 0.8)
	end)
end

return PartRemovalService
