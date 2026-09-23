--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local PartsCatalog = require(ReplicatedStorage.Shared.PartsCatalog)
local PartRemovalService = require(ServerScriptService.Server.PartRemovalService)
local EngineHoistService = require(ServerScriptService.Server.EngineHoistService)
local RecyclingCenterService = require(ServerScriptService.Server.RecyclingCenterService)

local EconomyService = {}
local partSoldEvent = Instance.new("BindableEvent")
EconomyService.OnPartSold = partSoldEvent.Event
local touchDebounce: {[Player]: boolean} = {}

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
	local tickets = Instance.new("IntValue")
	tickets.Name = "Tickets"
	local existingTickets = player:GetAttribute("AuctionTickets")
	tickets.Value = if typeof(existingTickets) == "number" then existingTickets else 3
	tickets.Parent = leaderstats
end

local function getMoney(player: Player): IntValue?
	local leaderstats = player:FindFirstChild("leaderstats")
	local money = leaderstats and leaderstats:FindFirstChild("Dinheiro")
	return if money and money:IsA("IntValue") then money else nil
end

local function getTickets(player: Player): IntValue?
	local leaderstats = player:FindFirstChild("leaderstats")
	local tickets = leaderstats and leaderstats:FindFirstChild("Tickets")
	return if tickets and tickets:IsA("IntValue") then tickets else nil
end

function EconomyService.GetTickets(player: Player): number
	local tickets = getTickets(player)
	if tickets then return tickets.Value end
	local attr = player:GetAttribute("AuctionTickets")
	return if typeof(attr) == "number" then attr else 0
end

function EconomyService.AddTickets(player: Player, amount: number): number
	if amount <= 0 then return EconomyService.GetTickets(player) end
	local tickets = getTickets(player)
	local current = if tickets then tickets.Value else (player:GetAttribute("AuctionTickets") or 0)
	local newTotal = current + amount
	if tickets then tickets.Value = newTotal end
	player:SetAttribute("AuctionTickets", newTotal)
	return newTotal
end

function EconomyService.DeductTickets(player: Player, amount: number): boolean
	if amount <= 0 then return false end
	local tickets = getTickets(player)
	local current = if tickets then tickets.Value else (player:GetAttribute("AuctionTickets") or 0)
	if current < amount then return false end
	local newTotal = current - amount
	if tickets then tickets.Value = newTotal end
	player:SetAttribute("AuctionTickets", newTotal)
	return true
end

local function findCarriedPart(player: Player): BasePart?
	local carried = PartRemovalService.GetCarriedPart(player)
	if carried and carried:GetAttribute("OwnerUserId") == player.UserId then
		return carried
	end
	local engine = EngineHoistService.GetCarriedEngine(player)
	if engine and engine:GetAttribute("OwnerUserId") == player.UserId then
		return engine
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

local function sellCarriedPart(player: Player, zone: Part)
	if player:GetAttribute("DataLoaded") ~= true then return end
	local zoneOwner = zone:GetAttribute("OwnerUserId")
	if touchDebounce[player] or zoneOwner ~= player.UserId then return end
	touchDebounce[player] = true
	local part = findCarriedPart(player)
	local money = getMoney(player)
	if part and money then
		local partId = part:GetAttribute("PartId")
		local definition = if typeof(partId) == "string" then PartsCatalog[partId] else nil
		if definition then
			local car = findCarModel(part)
			local sessionId = car and car:GetAttribute("CarSessionId")
			local mult = car and car:GetAttribute("ScrapMultiplier")
			local multiplier = if typeof(mult) == "number" and mult > 0 then mult else 1
			local sellValue = math.round(definition.SellValue * multiplier)
			money.Value += sellValue
			PartRemovalService.ClearCarriedPart(player)
			if partId == "Engine" then EngineHoistService.CompleteEngineSale(player) end
			RecyclingCenterService.PulseDropZone(zone)
			part:SetAttribute("SoldConfirmed", true)
			partSoldEvent:Fire(player, car, sessionId, partId, sellValue)
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

local function registerZoneListeners(zone: Part)
	zone.Touched:Connect(function(hit)
		local ownerUserId = zone:GetAttribute("OwnerUserId")
		if typeof(ownerUserId) == "number" and ownerUserId > 0 then
			local player = resolveTouchPlayer(hit, ownerUserId)
			if player then sellCarriedPart(player, zone) end
		end
	end)

	task.spawn(function()
		while zone.Parent do
			local ownerUserId = zone:GetAttribute("OwnerUserId")
			if typeof(ownerUserId) == "number" and ownerUserId > 0 then
				local player = Players:GetPlayerByUserId(ownerUserId)
				local character = player and player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if player and root and root:IsA("BasePart") then
					local localPosition = zone.CFrame:PointToObjectSpace(root.Position)
					local insideHorizontalArea = math.abs(localPosition.X) <= zone.Size.X / 2 + 1.8
						and math.abs(localPosition.Z) <= zone.Size.Z / 2 + 1.8
					local closeVertically = math.abs(localPosition.Y) <= 8
					if insideHorizontalArea and closeVertically then
						sellCarriedPart(player, zone)
					end
				end
			end
			task.wait(0.1)
		end
	end)
end

function EconomyService.CreateSellZone(_ownerUserId: number, _cframe: CFrame): Part?
	return nil
end

function EconomyService.RemoveSellZone(_ownerUserId: number)
end

function EconomyService.TrySpend(player: Player, amount: number): boolean
	if amount < 0 then return false end
	local money = getMoney(player)
	if not money or money.Value < amount then return false end
	money.Value -= amount
	return true
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

	for _, dock in RecyclingCenterService.GetAllDocks() do
		registerZoneListeners(dock.PartsDropZone)
		registerZoneListeners(dock.EngineBayZone)
	end
end

return EconomyService
