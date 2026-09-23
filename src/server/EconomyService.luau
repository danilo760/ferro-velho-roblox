--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local PartsCatalog = require(ReplicatedStorage.Shared.PartsCatalog)
local PartRemovalService = require(ServerScriptService.Server.PartRemovalService)
local EngineHoistService = require(ServerScriptService.Server.EngineHoistService)

local EconomyService = {}
local partSoldEvent = Instance.new("BindableEvent")
EconomyService.OnPartSold = partSoldEvent.Event
local zonesByOwner: {[number]: Part} = {}
local touchDebounce: {[Player]: boolean} = {}
local SELL_COLOR = Color3.fromRGB(50, 210, 105)

local function setupPlayer(player: Player)
	if player:FindFirstChild("leaderstats") then return end
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player
	local money = Instance.new("IntValue")
	money.Name = "Dinheiro"
	money.Parent = leaderstats
	local cars = Instance.new("IntValue")
	cars.Name = "Carros Desmontados"
	cars.Parent = leaderstats
end

local function getMoney(player: Player): IntValue?
	local leaderstats = player:FindFirstChild("leaderstats")
	local money = leaderstats and leaderstats:FindFirstChild("Dinheiro")
	return if money and money:IsA("IntValue") then money else nil
end

local function findCarriedPart(player: Player): BasePart?
	for _, descendant in Workspace:GetDescendants() do
		if descendant:IsA("BasePart")
			and descendant:GetAttribute("PartState") == "Carried"
			and descendant:GetAttribute("CarrierUserId") == player.UserId
			and descendant:GetAttribute("OwnerUserId") == player.UserId then
			return descendant
		end
	end
	return nil
end

local function findCarModel(part: BasePart): Model?
	local current: Instance? = part.Parent
	while current do
		if current:IsA("Model") and current:GetAttribute("CarSessionId") ~= nil then return current end
		current = current.Parent
	end
	return nil
end

local function pulse(zone: Part)
	zone.Color = Color3.fromRGB(225, 255, 120)
	zone.Transparency = 0
	TweenService:Create(zone, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Color = SELL_COLOR, Transparency = 0.2,
	}):Play()
end

local function sellCarriedPart(player: Player, zone: Part)
	if touchDebounce[player] or zone:GetAttribute("OwnerUserId") ~= player.UserId then return end
	touchDebounce[player] = true
	local part = findCarriedPart(player)
	local money = getMoney(player)
	if part and money then
		local partId = part:GetAttribute("PartId")
		local definition = if typeof(partId) == "string" then PartsCatalog[partId] else nil
		if definition then
			local car = findCarModel(part)
			local sessionId = car and car:GetAttribute("CarSessionId")
			money.Value += definition.SellValue
			PartRemovalService.ClearCarriedPart(player)
			if partId == "Engine" then EngineHoistService.CompleteEngineSale(player) end
			pulse(zone)
			part:SetAttribute("SoldConfirmed", true)
			partSoldEvent:Fire(player, car, sessionId, partId, definition.SellValue)
			part:Destroy()
		end
	end
	touchDebounce[player] = nil
end

local function resolveTouchPlayer(hit: BasePart, ownerUserId: number): Player?
	local carrierId = hit:GetAttribute("CarrierUserId")
	if carrierId == ownerUserId then return Players:GetPlayerByUserId(ownerUserId) end
	local ancestor = hit.Parent
	while ancestor do
		if ancestor:GetAttribute("CarrierUserId") == ownerUserId then return Players:GetPlayerByUserId(ownerUserId) end
		ancestor = ancestor.Parent
	end
	local character = hit:FindFirstAncestorOfClass("Model")
	local player = character and Players:GetPlayerFromCharacter(character)
	return if player and player.UserId == ownerUserId then player else nil
end

function EconomyService.CreateSellZone(ownerUserId: number, cframe: CFrame): Part
	EconomyService.RemoveSellZone(ownerUserId)
	local zone = Instance.new("Part")
	zone.Name = "SellZone_" .. ownerUserId
	zone:SetAttribute("OwnerUserId", ownerUserId)
	zone.Size = Vector3.new(9, 1, 9)
	zone.CFrame = cframe
	zone.Anchored = true
	zone.CanCollide = true
	zone.Material = Enum.Material.Neon
	zone.Color = SELL_COLOR
	zone.Transparency = 0.2
	zone.Parent = Workspace
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(260, 60)
	billboard.StudsOffset = Vector3.new(0, 3.5, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = zone
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "VENDER PEÇAS"
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.25
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = billboard
	zone.Touched:Connect(function(hit)
		local player = resolveTouchPlayer(hit, ownerUserId)
		if player then sellCarriedPart(player, zone) end
	end)
	zonesByOwner[ownerUserId] = zone
	return zone
end

function EconomyService.RemoveSellZone(ownerUserId: number)
	local zone = zonesByOwner[ownerUserId]
	if zone and zone.Parent then zone:Destroy() end
	zonesByOwner[ownerUserId] = nil
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
end

return EconomyService
