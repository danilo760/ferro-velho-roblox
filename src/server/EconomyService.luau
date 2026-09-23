--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local PartsCatalog = require(ReplicatedStorage.Shared.PartsCatalog)
local ServerScriptService = game:GetService("ServerScriptService")
local PartRemovalService = require(ServerScriptService.Server.PartRemovalService)
local EconomyService = {}
local partSoldEvent = Instance.new("BindableEvent")
EconomyService.OnPartSold = partSoldEvent.Event
local SELL_ZONE_POSITION = Vector3.new(14, 0.55, -28)
local SELL_ZONE_SIZE = Vector3.new(9, 1, 9)
local SELL_COLOR = Color3.fromRGB(50, 210, 105)
local touchDebounce: {[Player]: boolean} = {}
local sellZoneReference: Part? = nil

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

	local cars = Instance.new("IntValue")
	cars.Name = "Carros Desmontados"
	cars.Value = 0
	cars.Parent = leaderstats
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

local function pulseSellZone()
	local zone = sellZoneReference
	if not zone then return end
	zone.Color = Color3.fromRGB(225, 255, 120)
	zone.Transparency = 0
	local tween = TweenService:Create(zone, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Color = SELL_COLOR,
		Transparency = 0.2,
	})
	tween:Play()
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
		prompt.ActionText = "Empurrar vazio"
		prompt.ObjectText = "Guincho de motor"
		prompt.Enabled = true
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
			local car = part:FindFirstAncestor("TrainingCar01")
			local sessionId = if car and car:IsA("Model") then car:GetAttribute("CarSessionId") else nil
			money.Value += definition.SellValue
			PartRemovalService.ClearCarriedPart(player)
			if partId == "Engine" then parkSoldEngineHoist(player) end
			pulseSellZone()
			part:SetAttribute("SoldConfirmed", true)
			partSoldEvent:Fire(player, car, sessionId, partId, definition.SellValue)
			part:Destroy()
		end
	end
	task.delay(1, function() touchDebounce[player] = nil end)
end

local function resolvePlayerFromTouch(hit: BasePart): Player?
	local carrierId = hit:GetAttribute("CarrierUserId")
	if typeof(carrierId) == "number" and carrierId > 0 then return Players:GetPlayerByUserId(carrierId) end
	local hoist = hit:FindFirstAncestor("EngineHoist01")
	if hoist and hoist:IsA("Model") then
		local hoistCarrierId = hoist:GetAttribute("CarrierUserId")
		if typeof(hoistCarrierId) == "number" and hoistCarrierId > 0 then return Players:GetPlayerByUserId(hoistCarrierId) end
	end
	local character = hit:FindFirstAncestorOfClass("Model")
	return if character then Players:GetPlayerFromCharacter(character) else nil
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
	zone.Color = SELL_COLOR
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

function EconomyService.AwardBonus(player: Player, amount: number)
	local money = getMoney(player)
	if money then money.Value += amount end
end

function EconomyService.IncrementCars(player: Player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local cars = leaderstats and leaderstats:FindFirstChild("Carros Desmontados")
	if cars and cars:IsA("IntValue") then cars.Value += 1 end
end

function EconomyService.start()
	Players.PlayerAdded:Connect(setupPlayer)
	for _, player in Players:GetPlayers() do setupPlayer(player) end
	Players.PlayerRemoving:Connect(function(player) touchDebounce[player] = nil end)
	local sellZone = createSellZone()
	sellZoneReference = sellZone
	sellZone.Touched:Connect(function(hit: BasePart)
		local player = resolvePlayerFromTouch(hit)
		if player then sellCarriedPart(player) end
	end)
end

return EconomyService
