--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local PartsCatalog = require(ReplicatedStorage.Shared.PartsCatalog)
local EconomyService = {}

local SELL_ZONE_POSITION = Vector3.new(14, 0.55, -28)
local SELL_ZONE_SIZE = Vector3.new(9, 1, 9)
local touchDebounce: {[Player]: boolean} = {}

local function getMoney(player: Player): IntValue?
	local leaderstats = player:FindFirstChild("leaderstats")
	local money = leaderstats and leaderstats:FindFirstChild("Dinheiro")
	return if money and money:IsA("IntValue") then money else nil
end

local function setupPlayer(player: Player)
	if player:FindFirstChild("leaderstats") then return end
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player
	local money = Instance.new("IntValue")
	money.Name = "Dinheiro"
	money.Value = 0
	money.Parent = leaderstats
end

local function findCarriedPart(player: Player): BasePart?
	local car = Workspace:FindFirstChild("TrainingCar01")
	if not car then return nil end
	for _, descendant in car:GetDescendants() do
		if descendant:IsA("BasePart") and descendant:GetAttribute("PartState") == "Carried" and descendant:GetAttribute("CarrierUserId") == player.UserId then
			return descendant
		end
	end
	return nil
end

local function parkSoldEngineHoist(player: Player)
	local hoist = Workspace:FindFirstChild("EngineHoist01")
	if not hoist or not hoist:IsA("Model") or hoist:GetAttribute("CarrierUserId") ~= player.UserId then return end
	local base = hoist.PrimaryPart
	if base then
		local carryWeld = base:FindFirstChild("CarryWeld")
		if carryWeld then carryWeld:Destroy() end
	end
	for _, descendant in hoist:GetDescendants() do
		if descendant:IsA("BasePart") then descendant.Anchored = true end
	end
	hoist:SetAttribute("State", "Empty")
	hoist:SetAttribute("CarrierUserId", 0)
	local prompt = base and base:FindFirstChild("HoistPrompt")
	if prompt and prompt:IsA("ProximityPrompt") then
		prompt.ActionText = "Motor vendido"
		prompt.Enabled = false
	end
end

local function sellCarriedPart(player: Player)
	if touchDebounce[player] then return end
	touchDebounce[player] = true
	local part = findCarriedPart(player)
	local money = getMoney(player)
	if part and money then
		local partId = part:GetAttribute("PartId")
		local definition = if typeof(partId) == "string" then PartsCatalog[partId] else nil
		if definition then
			money.Value += definition.SellValue
			player:SetAttribute("CarriedPartId", nil)
			if partId == "Engine" then parkSoldEngineHoist(player) end
			part:Destroy()
		end
	end
	task.delay(1, function() touchDebounce[player] = nil end)
end

local function createSellZone(): Part
	local existing = Workspace:FindFirstChild("SellZone")
	if existing and existing:IsA("Part") then return existing end
	local zone = Instance.new("Part")
	zone.Name = "SellZone"
	zone.Size = SELL_ZONE_SIZE
	zone.Position = SELL_ZONE_POSITION
	zone.Anchored = true
	zone.CanCollide = true
	zone.Material = Enum.Material.Neon
	zone.Color = Color3.fromRGB(50, 210, 105)
	zone.Transparency = 0.2
	zone.TopSurface = Enum.SurfaceType.Smooth
	zone.BottomSurface = Enum.SurfaceType.Smooth
	zone.Parent = Workspace
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "SellLabel"
	billboard.Size = UDim2.fromOffset(260, 60)
	billboard.StudsOffset = Vector3.new(0, 3.5, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = zone
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "VENDER PEÇAS"
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.25
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = billboard
	return zone
end

function EconomyService.start()
	Players.PlayerAdded:Connect(setupPlayer)
	for _, player in Players:GetPlayers() do setupPlayer(player) end
	Players.PlayerRemoving:Connect(function(player) touchDebounce[player] = nil end)
	local sellZone = createSellZone()
	sellZone.Touched:Connect(function(hit: BasePart)
		local character = hit:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)
		if player then sellCarriedPart(player) end
	end)
end

return EconomyService
