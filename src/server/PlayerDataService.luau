--!strict

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local PlayerDataService = {}
local STORE_NAME = "FerroVelhoPlayerData_v1"
local AUTOSAVE_INTERVAL = 60
local saving: {[Player]: boolean} = {}

type PlayerData = {
	Cash: number,
	CarsDismantled: number,
	ToolLevel: number,
	SchemaVersion: number,
}

local DEFAULT_DATA: PlayerData = {
	Cash = 0,
	CarsDismantled = 0,
	ToolLevel = 1,
	SchemaVersion = 1,
}

local function integerInRange(value: any, defaultValue: number, minimum: number, maximum: number): number
	if typeof(value) ~= "number" or value ~= value then return defaultValue end
	return math.clamp(math.floor(value), minimum, maximum)
end

local function sanitize(raw: any): PlayerData
	if typeof(raw) ~= "table" then return table.clone(DEFAULT_DATA) end
	return {
		Cash = integerInRange(raw.Cash, 0, 0, 2_000_000_000),
		CarsDismantled = integerInRange(raw.CarsDismantled, 0, 0, 2_000_000_000),
		ToolLevel = integerInRange(raw.ToolLevel, 1, 1, 2),
		SchemaVersion = 1,
	}
end

local function getStats(player: Player): (IntValue?, IntValue?)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then return nil, nil end
	local money = leaderstats:FindFirstChild("Dinheiro")
	local cars = leaderstats:FindFirstChild("Carros Desmontados")
	return if money and money:IsA("IntValue") then money else nil,
		if cars and cars:IsA("IntValue") then cars else nil
end

local function waitForStats(player: Player): (IntValue?, IntValue?)
	local leaderstats = player:WaitForChild("leaderstats", 10)
	if not leaderstats then return nil, nil end
	local money = leaderstats:WaitForChild("Dinheiro", 10)
	local cars = leaderstats:WaitForChild("Carros Desmontados", 10)
	return if money and money:IsA("IntValue") then money else nil,
		if cars and cars:IsA("IntValue") then cars else nil
end

local function applyData(player: Player, data: PlayerData)
	local money, cars = waitForStats(player)
	if not money or not cars then
		warn("Leaderstats unavailable while loading data for " .. player.Name)
		player:SetAttribute("DataLoadFailed", true)
		return
	end
	money.Value = data.Cash
	cars.Value = data.CarsDismantled
	player:SetAttribute("ToolLevel", data.ToolLevel)
	player:SetAttribute("DataLoadFailed", false)
	player:SetAttribute("DataLoaded", true)
end

local function snapshot(player: Player): PlayerData?
	local money, cars = getStats(player)
	local toolLevel = player:GetAttribute("ToolLevel")
	if not money or not cars or typeof(toolLevel) ~= "number" then return nil end
	return sanitize({
		Cash = money.Value,
		CarsDismantled = cars.Value,
		ToolLevel = toolLevel,
		SchemaVersion = 1,
	})
end

local function loadPlayer(player: Player)
	player:SetAttribute("DataLoaded", false)
	player:SetAttribute("DataLoadFailed", false)
	local key = "Player_" .. player.UserId
	local success, result = pcall(function()
		local dataStore = DataStoreService:GetDataStore(STORE_NAME)
		return dataStore:GetAsync(key)
	end)
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
	if game.PlaceId == 0 or game.GameId == 0 then
		player:SetAttribute("DataLoaded", false)
		player:SetAttribute("DataLoadFailed", false)
		applyData(player, table.clone(DEFAULT_DATA))
		player:SetAttribute("DataLoadFailed", true)
		player:SetAttribute("DataSessionMode", "Temporary")
		return
	end
	player:SetAttribute("DataSessionMode", "Persistent")
	task.spawn(loadPlayer, player)
end

local function savePlayer(player: Player): boolean
	if player:GetAttribute("DataLoaded") ~= true or player:GetAttribute("DataLoadFailed") == true or saving[player] then return false end
	local data = snapshot(player)
	if not data then return false end
	saving[player] = true
	local key = "Player_" .. player.UserId
	local success, result = pcall(function()
		local dataStore = DataStoreService:GetDataStore(STORE_NAME)
		return dataStore:UpdateAsync(key, function(_oldValue)
			return data
		end)
	end)
	saving[player] = nil
	if not success then
		warn("Failed to save data for " .. player.Name .. ": " .. tostring(result))
	end
	return success
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
