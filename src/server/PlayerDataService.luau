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
local SCHEMA_VERSION = 3
local LOCK_TTL = 120
local LOCK_ACQUIRE_RETRIES = 3
local LOCK_RETRY_DELAY = 5
local USE_STUDIO_MEMORY_MOCK = RunService:IsStudio() and (game.PlaceId == 0 or game.GameId == 0)
local saving: {[Player]: boolean} = {}
local studioMockStore: {[string]: any} = {}

type SessionLockInfo = {
	JobId: string,
	PlaceId: number,
	Timestamp: number,
}

type PlayerData = {
	Cash: number,
	CarsDismantled: number,
	AuctionTickets: number,
	ToolLevel: number,
	SpeedLevel: number,
	UnlockedBoxes: number,
	BoxCars: {[string]: any}?,
	Lock: SessionLockInfo?,
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
	Lock = nil,
	SchemaVersion = SCHEMA_VERSION,
}

local function integerInRange(value: any, defaultValue: number, minimum: number, maximum: number): number
	if typeof(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then return defaultValue end
	return math.clamp(math.floor(value), minimum, maximum)
end

local function sanitize(raw: any): PlayerData
	if typeof(raw) ~= "table" then return table.clone(DEFAULT_DATA) end
	local lock: SessionLockInfo? = nil
	if typeof(raw.Lock) == "table" and typeof(raw.Lock.JobId) == "string" and typeof(raw.Lock.Timestamp) == "number" then
		lock = {
			JobId = raw.Lock.JobId,
			PlaceId = if typeof(raw.Lock.PlaceId) == "number" then raw.Lock.PlaceId else 0,
			Timestamp = raw.Lock.Timestamp,
		}
	end
	return {
		Cash = integerInRange(raw.Cash, 0, 0, 2_000_000_000),
		CarsDismantled = integerInRange(raw.CarsDismantled, 0, 0, 2_000_000_000),
		AuctionTickets = integerInRange(raw.AuctionTickets, 3, 0, 2_000_000_000),
		ToolLevel = integerInRange(raw.ToolLevel, 1, 1, 2),
		SpeedLevel = integerInRange(raw.SpeedLevel, 1, 1, 5),
		UnlockedBoxes = integerInRange(raw.UnlockedBoxes, 1, 1, 3),
		BoxCars = if typeof(raw.BoxCars) == "table" then raw.BoxCars else {},
		Lock = lock,
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
	local currentJobId = if game.JobId ~= "" then game.JobId else "StudioSession"

	-- Mock apenas para lugares ainda não publicados no Studio. Ele não sobrevive ao encerramento do servidor.
	if USE_STUDIO_MEMORY_MOCK then
		player:SetAttribute("DataSessionMode", "StudioMock")
		local cached = studioMockStore[key]
		if cached then
			local currentLock = cached.Lock
			local now = os.time()
			if currentLock and typeof(currentLock.JobId) == "string" and currentLock.JobId ~= "" and currentLock.JobId ~= currentJobId then
				if (now - currentLock.Timestamp) < LOCK_TTL then
					warn(string.format("Player %s is locked by session %s in mock store.", player.Name, currentLock.JobId))
					player:Kick("Seus dados estão sendo salvos no servidor anterior. Aguarde cerca de 1 minuto e reconecte.")
					return
				end
			end
			local sanitized = sanitize(cached)
			sanitized.Lock = {
				JobId = currentJobId,
				PlaceId = game.PlaceId,
				Timestamp = now,
			}
			studioMockStore[key] = sanitized
			applyData(player, sanitized)
		else
			local initialData = table.clone(DEFAULT_DATA)
			initialData.Lock = {
				JobId = currentJobId,
				PlaceId = game.PlaceId,
				Timestamp = os.time(),
			}
			studioMockStore[key] = initialData
			applyData(player, initialData)
		end
		player:SetAttribute("DataLoaded", true)
		player:SetAttribute("DataLoadFailed", false)
		return
	end

	player:SetAttribute("DataSessionMode", "Persistent")
	local loadedData: PlayerData? = nil
	local lockedByOther = false
	local otherJobId = ""

	for attempt = 1, LOCK_ACQUIRE_RETRIES do
		if not player.Parent then return end
		lockedByOther = false
		otherJobId = ""

		local success, err = pcall(function()
			local dataStore = DataStoreService:GetDataStore(STORE_NAME)
			dataStore:UpdateAsync(key, function(oldValue)
				local now = os.time()
				if oldValue == nil then
					local newData = table.clone(DEFAULT_DATA)
					newData.Lock = {
						JobId = currentJobId,
						PlaceId = game.PlaceId,
						Timestamp = now,
					}
					loadedData = newData
					return newData
				end

				local sanitized = sanitize(oldValue)
				local existingLock = sanitized.Lock

				if existingLock and typeof(existingLock.JobId) == "string" and existingLock.JobId ~= "" then
					local isLockedByOther = existingLock.JobId ~= currentJobId
					local isExpired = (now - existingLock.Timestamp) >= LOCK_TTL
					if isLockedByOther and not isExpired then
						lockedByOther = true
						otherJobId = existingLock.JobId
						return nil -- Aborta o UpdateAsync mantendo os dados intactos no DataStore
					end
				end

				-- Lock livre, expirado ou pertencente a este mesmo servidor: adquirir lock
				sanitized.Lock = {
					JobId = currentJobId,
					PlaceId = game.PlaceId,
					Timestamp = now,
				}
				loadedData = sanitized
				return sanitized
			end)
		end)

		if loadedData then
			break
		end

		if lockedByOther then
			warn(string.format("Player %s (UserId: %d) data is locked by server %s. Retry %d/%d in %ds...", player.Name, player.UserId, otherJobId, attempt, LOCK_ACQUIRE_RETRIES, LOCK_RETRY_DELAY))
			if attempt < LOCK_ACQUIRE_RETRIES then
				task.wait(LOCK_RETRY_DELAY)
			end
		elseif not success then
			warn(string.format("DataStore UpdateAsync error for %s (attempt %d/%d): %s", player.Name, attempt, LOCK_ACQUIRE_RETRIES, tostring(err)))
			if attempt < LOCK_ACQUIRE_RETRIES then
				task.wait(2 ^ (attempt - 1))
			end
		end
	end

	if not player.Parent then return end

	if loadedData then
		applyData(player, loadedData)
	elseif lockedByOther then
		warn(string.format("Player %s kicked to prevent session overlap with server %s.", player.Name, otherJobId))
		player:Kick("Seus dados estão sendo salvos no servidor anterior. Aguarde cerca de 1 minuto e reconecte.")
	else
		applyData(player, table.clone(DEFAULT_DATA))
		player:SetAttribute("DataLoadFailed", true)
		warn("DataStore unavailable; using a temporary unsaved session for " .. player.Name)
	end
end

local function initializePlayer(player: Player)
	task.spawn(loadPlayer, player)
end

local function savePlayer(player: Player, releaseLock: boolean?): boolean
	if player:GetAttribute("DataLoaded") ~= true or player:GetAttribute("DataLoadFailed") == true or saving[player] then return false end
	local data = snapshot(player)
	if not data then return false end
	saving[player] = true
	local key = "Player_" .. player.UserId
	local currentJobId = if game.JobId ~= "" then game.JobId else "StudioSession"
	local shouldRelease = releaseLock == true

	-- Em lugar não publicado no Studio, manter apenas durante a vida deste servidor de teste.
	if USE_STUDIO_MEMORY_MOCK then
		if shouldRelease then
			data.Lock = nil
		else
			data.Lock = {
				JobId = currentJobId,
				PlaceId = game.PlaceId,
				Timestamp = os.time(),
			}
		end
		studioMockStore[key] = data
		saving[player] = nil
		return true
	end

	local success = false
	local stolenLock = false
	local result: any = nil

	for attempt = 1, DATASTORE_MAX_ATTEMPTS do
		stolenLock = false
		success, result = pcall(function()
			local dataStore = DataStoreService:GetDataStore(STORE_NAME)
			return dataStore:UpdateAsync(key, function(oldValue)
				local now = os.time()
				if oldValue ~= nil then
					local currentStored = sanitize(oldValue)
					local lock = currentStored.Lock
					if lock and typeof(lock.JobId) == "string" and lock.JobId ~= "" and lock.JobId ~= currentJobId then
						local isExpired = (now - lock.Timestamp) >= LOCK_TTL
						if not isExpired then
							stolenLock = true
							return nil -- Não sobrescrever dados de um servidor mais novo!
						end
					end
				end

				if shouldRelease then
					data.Lock = nil
				else
					data.Lock = {
						JobId = currentJobId,
						PlaceId = game.PlaceId,
						Timestamp = now,
					}
				end
				return data
			end)
		end)

		if success or stolenLock then break end
		if attempt < DATASTORE_MAX_ATTEMPTS then
			task.wait(2 ^ (attempt - 1))
		end
	end

	saving[player] = nil

	if stolenLock then
		warn(string.format("Save aborted for %s: session lock was acquired by another server.", player.Name))
		return false
	end

	if not success then
		warn("Failed to save data for " .. player.Name .. ": " .. tostring(result))
	end
	return success
end

function PlayerDataService.SavePlayer(player: Player, releaseLock: boolean?): boolean
	return savePlayer(player, releaseLock)
end

function PlayerDataService.LoadPlayer(player: Player)
	loadPlayer(player)
end

function PlayerDataService.GetStoredMockData(userId: number): any
	return studioMockStore["Player_" .. userId]
end

function PlayerDataService.SetStoredMockData(userId: number, data: any)
	studioMockStore["Player_" .. userId] = data
end

function PlayerDataService.start()
	Players.PlayerAdded:Connect(initializePlayer)
	Players.PlayerRemoving:Connect(function(player)
		savePlayer(player, true)
		saving[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		initializePlayer(player)
	end

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for _, player in Players:GetPlayers() do
				task.spawn(savePlayer, player, false)
			end
		end
	end)

	game:BindToClose(function()
		local remaining = 0
		for _, player in Players:GetPlayers() do
			remaining += 1
			task.spawn(function()
				savePlayer(player, true)
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
