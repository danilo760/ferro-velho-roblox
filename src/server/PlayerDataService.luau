--!strict

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local CarLifecycleService = require(ServerScriptService.Server.CarLifecycleService)

local PlayerDataService = {}
local STORE_NAME = "FerroVelhoPlayerData_v1"
local AUTOSAVE_INTERVAL = 60
local DATASTORE_MAX_ATTEMPTS = 3
local SCHEMA_VERSION = 2
local USE_STUDIO_MEMORY_MOCK = RunService:IsStudio() and (game.PlaceId == 0 or game.GameId == 0)
local saving: {[Player]: boolean} = {}
local studioMockStore: {[string]: any} = {}

type PlayerData = {
	Cash: number,
	CarsDismantled: number,
	AuctionTickets: number,
	ToolLevel: number,
	SpeedLevel: number,
	UnlockedBoxes: number,
	BoxCars: {[string]: any}?,
	SchemaVersion: number,
}

local DEFAULT_DATA: PlayerData = {
	Cash = 0,
	CarsDismantled = 0,
	AuctionTickets = 3,
	ToolLevel = 1,
	SpeedLevel = 1,
	UnlockedBoxes = 1,
	BoxCars = {},
	SchemaVersion = SCHEMA_VERSION,
}

local function integerInRange(value: any, defaultValue: number, minimum: number, maximum: number): number
	if typeof(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then return defaultValue end
	return math.clamp(math.floor(value), minimum, maximum)
end

local function sanitize(raw: any): PlayerData
	if typeof(raw) ~= "table" then return table.clone(DEFAULT_DATA) end
	return {
		Cash = integerInRange(raw.Cash, 0, 0, 2_000_000_000),
		CarsDismantled = integerInRange(raw.CarsDismantled, 0, 0, 2_000_000_000),
		AuctionTickets = integerInRange(raw.AuctionTickets, 3, 0, 2_000_000_000),
		ToolLevel = integerInRange(raw.ToolLevel, 1, 1, 2),
		SpeedLevel = integerInRange(raw.SpeedLevel, 1, 1, 5),
		UnlockedBoxes = integerInRange(raw.UnlockedBoxes, 1, 1, 3),
		BoxCars = if typeof(raw.BoxCars) == "table" then raw.BoxCars else {},
		SchemaVersion = SCHEMA_VERSION,
	}
end

local function getStats(player: Player): (IntValue?, IntValue?, IntValue?)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then return nil, nil, nil end
	local money = leaderstats:FindFirstChild("Dinheiro")
	local cars = leaderstats:FindFirstChild("Carros Desmontados")
	local tickets = leaderstats:FindFirstChild("Tickets")
	return if money and money:IsA("IntValue") then money else nil,
		if cars and cars:IsA("IntValue") then cars else nil,
		if tickets and tickets:IsA("IntValue") then tickets else nil
end

local function waitForStats(player: Player): (IntValue?, IntValue?, IntValue?)
	local leaderstats = player:WaitForChild("leaderstats", 10)
	if not leaderstats then return nil, nil, nil end
	local money = leaderstats:WaitForChild("Dinheiro", 10)
	local cars = leaderstats:WaitForChild("Carros Desmontados", 10)
	local tickets = leaderstats:WaitForChild("Tickets", 10)
	return if money and money:IsA("IntValue") then money else nil,
		if cars and cars:IsA("IntValue") then cars else nil,
		if tickets and tickets:IsA("IntValue") then tickets else nil
end

local function applyData(player: Player, data: PlayerData)
	local money, cars, tickets = waitForStats(player)
	if not money or not cars or not tickets then
		warn("Leaderstats unavailable while loading data for " .. player.Name)
		player:SetAttribute("DataLoadFailed", true)
		return
	end
	money.Value = data.Cash
	cars.Value = data.CarsDismantled
	if tickets then tickets.Value = data.AuctionTickets end
	player:SetAttribute("AuctionTickets", data.AuctionTickets)
	player:SetAttribute("ToolLevel", data.ToolLevel)
	player:SetAttribute("SpeedLevel", data.SpeedLevel)
	player:SetAttribute("UnlockedBoxes", data.UnlockedBoxes)

	-- Restaurar configurações dos Boxes (CurrentCar e PendingCar)
	CarLifecycleService.LoadBoxCars(player, data.BoxCars)

	player:SetAttribute("DataLoadFailed", false)
	player:SetAttribute("DataLoaded", true)
end

local function snapshot(player: Player): PlayerData?
	local money, cars, tickets = getStats(player)
	local toolLevel = player:GetAttribute("ToolLevel")
	local speedLevel = player:GetAttribute("SpeedLevel")
	local unlockedBoxes = player:GetAttribute("UnlockedBoxes")
	if not money or not cars or not tickets or typeof(toolLevel) ~= "number" then return nil end
	return sanitize({
		Cash = money.Value,
		CarsDismantled = cars.Value,
		AuctionTickets = tickets.Value,
		ToolLevel = toolLevel,
		SpeedLevel = if typeof(speedLevel) == "number" then speedLevel else 1,
		UnlockedBoxes = if typeof(unlockedBoxes) == "number" then unlockedBoxes else 1,
		BoxCars = CarLifecycleService.SerializeBoxCars(player),
		SchemaVersion = SCHEMA_VERSION,
	})
end

local function loadPlayer(player: Player)
	player:SetAttribute("DataLoaded", false)
	player:SetAttribute("DataLoadFailed", false)
	local key = "Player_" .. player.UserId

	-- Mock apenas para lugares ainda não publicados no Studio. Ele não sobrevive ao encerramento do servidor.
	if USE_STUDIO_MEMORY_MOCK then
		player:SetAttribute("DataSessionMode", "StudioMock")
		local cached = studioMockStore[key]
		if cached then
			applyData(player, sanitize(cached))
		else
			applyData(player, table.clone(DEFAULT_DATA))
		end
		player:SetAttribute("DataLoaded", true)
		player:SetAttribute("DataLoadFailed", false)
		return
	end

	player:SetAttribute("DataSessionMode", "Persistent")
	local success = false
	local result: any = nil
	for attempt = 1, DATASTORE_MAX_ATTEMPTS do
		success, result = pcall(function()
			local dataStore = DataStoreService:GetDataStore(STORE_NAME)
			return dataStore:GetAsync(key)
		end)
		if success then break end
		if attempt < DATASTORE_MAX_ATTEMPTS then
			task.wait(2 ^ (attempt - 1))
		end
	end
	if not player.Parent then return end
	if not success then
		applyData(player, table.clone(DEFAULT_DATA))
		player:SetAttribute("DataLoadFailed", true)
		warn("DataStore unavailable; using a temporary unsaved session for " .. player.Name .. ": " .. tostring(result))
		return
	end
	applyData(player, sanitize(result))
end

local function initializePlayer(player: Player)
	task.spawn(loadPlayer, player)
end

local function savePlayer(player: Player): boolean
	if player:GetAttribute("DataLoaded") ~= true or player:GetAttribute("DataLoadFailed") == true or saving[player] then return false end
	local data = snapshot(player)
	if not data then return false end
	saving[player] = true
	local key = "Player_" .. player.UserId

	-- Em lugar não publicado no Studio, manter apenas durante a vida deste servidor de teste.
	if USE_STUDIO_MEMORY_MOCK then
		studioMockStore[key] = data
		saving[player] = nil
		return true
	end

	local success = false
	local result: any = nil
	for attempt = 1, DATASTORE_MAX_ATTEMPTS do
		success, result = pcall(function()
			local dataStore = DataStoreService:GetDataStore(STORE_NAME)
			return dataStore:UpdateAsync(key, function(_oldValue)
				return data
			end)
		end)
		if success then break end
		if attempt < DATASTORE_MAX_ATTEMPTS then
			task.wait(2 ^ (attempt - 1))
		end
	end
	saving[player] = nil
	if not success then
		warn("Failed to save data for " .. player.Name .. ": " .. tostring(result))
	end
	return success
end

function PlayerDataService.SavePlayer(player: Player): boolean
	return savePlayer(player)
end

function PlayerDataService.LoadPlayer(player: Player)
	loadPlayer(player)
end

function PlayerDataService.start()
	Players.PlayerAdded:Connect(initializePlayer)
	Players.PlayerRemoving:Connect(function(player)
		savePlayer(player)
		saving[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		initializePlayer(player)
	end

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for _, player in Players:GetPlayers() do
				task.spawn(savePlayer, player)
			end
		end
	end)

	game:BindToClose(function()
		local remaining = 0
		for _, player in Players:GetPlayers() do
			remaining += 1
			task.spawn(function()
				savePlayer(player)
				remaining -= 1
			end)
		end
		local deadline = os.clock() + 10
		while remaining > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return PlayerDataService
