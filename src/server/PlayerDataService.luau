--!strict

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local CarLifecycleService = require(ServerScriptService.Server.CarLifecycleService)

local PlayerDataService = {}
local STORE_NAME = "FerroVelhoPlayerData_v1"
local AUTOSAVE_INTERVAL = 60
local LOCK_HEARTBEAT_INTERVAL = 30
local DATASTORE_MAX_ATTEMPTS = 3
local SCHEMA_VERSION = 4
local LOCK_TTL = 300
local LOCK_ACQUIRE_RETRIES = 3
local LOCK_RETRY_DELAY = 5
local SHUTDOWN_SAVE_TIMEOUT = 25
local MAX_CLOCK_SKEW = 30
-- O Studio usa memória temporária para não depender da opção "Enable Studio Access to API Services".
-- Servidores publicados continuam usando DataStore e session locking normalmente.
local USE_STUDIO_MEMORY_MOCK = RunService:IsStudio()
local CURRENT_SESSION_ID = if game.JobId ~= "" then game.JobId else "Studio-" .. HttpService:GenerateGUID(false)
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
	TicketPoints: number,
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
	TicketPoints = 0,
	ToolLevel = 1,
	SpeedLevel = 1,
	UnlockedBoxes = 1,
	BoxCars = {},
	Lock = nil,
	SchemaVersion = SCHEMA_VERSION,
}

local function newDefaultData(): PlayerData
	return {
		Cash = DEFAULT_DATA.Cash,
		CarsDismantled = DEFAULT_DATA.CarsDismantled,
		AuctionTickets = DEFAULT_DATA.AuctionTickets,
		TicketPoints = DEFAULT_DATA.TicketPoints,
		ToolLevel = DEFAULT_DATA.ToolLevel,
		SpeedLevel = DEFAULT_DATA.SpeedLevel,
		UnlockedBoxes = DEFAULT_DATA.UnlockedBoxes,
		BoxCars = {},
		Lock = nil,
		SchemaVersion = SCHEMA_VERSION,
	}
end

local function isFiniteNumber(value: any): boolean
	return typeof(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function integerInRange(value: any, defaultValue: number, minimum: number, maximum: number): number
	if not isFiniteNumber(value) then return defaultValue end
	return math.clamp(math.floor(value), minimum, maximum)
end

local function sanitizeLock(rawLock: any): SessionLockInfo?
	if typeof(rawLock) ~= "table" then return nil end
	if typeof(rawLock.JobId) ~= "string" or #rawLock.JobId == 0 or #rawLock.JobId > 128 then return nil end
	if not isFiniteNumber(rawLock.Timestamp) or rawLock.Timestamp <= 0 then return nil end

	return {
		JobId = rawLock.JobId,
		PlaceId = integerInRange(rawLock.PlaceId, 0, 0, 2_000_000_000),
		Timestamp = math.floor(rawLock.Timestamp),
	}
end

local function sanitize(raw: any): PlayerData
	if typeof(raw) ~= "table" then return newDefaultData() end
	local rawTicketPoints = integerInRange(raw.TicketPoints, 0, 0, 2_000_000_000)
	local convertedTickets = math.floor(rawTicketPoints / 12)
	local surplusPoints = rawTicketPoints % 12
	local rawTickets = integerInRange(raw.AuctionTickets, 3, 0, 2_000_000_000)

	return {
		Cash = integerInRange(raw.Cash, 0, 0, 2_000_000_000),
		CarsDismantled = integerInRange(raw.CarsDismantled, 0, 0, 2_000_000_000),
		AuctionTickets = rawTickets + convertedTickets,
		TicketPoints = surplusPoints,
		ToolLevel = integerInRange(raw.ToolLevel, 1, 1, 2),
		SpeedLevel = integerInRange(raw.SpeedLevel, 1, 1, 5),
		UnlockedBoxes = integerInRange(raw.UnlockedBoxes, 1, 1, 3),
		BoxCars = if typeof(raw.BoxCars) == "table" then raw.BoxCars else {},
		Lock = sanitizeLock(raw.Lock),
		SchemaVersion = SCHEMA_VERSION,
	}
end

local function makeCurrentLock(timestamp: number): SessionLockInfo
	return {
		JobId = CURRENT_SESSION_ID,
		PlaceId = game.PlaceId,
		Timestamp = timestamp,
	}
end

local function isLockOwnedByCurrentSession(lock: SessionLockInfo?): boolean
	return lock ~= nil and lock.JobId == CURRENT_SESSION_ID
end

local function isLockActive(lock: SessionLockInfo?, timestamp: number): boolean
	if not lock then return false end
	local age = timestamp - lock.Timestamp
	return age >= -MAX_CLOCK_SKEW and age < LOCK_TTL
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

local function applyData(player: Player, data: PlayerData): boolean
	local money, cars, tickets = waitForStats(player)
	if not money or not cars or not tickets then
		warn("Leaderstats unavailable while loading data for " .. player.Name)
		player:SetAttribute("DataLoadFailed", true)
		return false
	end
	money.Value = data.Cash
	cars.Value = data.CarsDismantled
	if tickets then tickets.Value = data.AuctionTickets end
	player:SetAttribute("AuctionTickets", data.AuctionTickets)
	player:SetAttribute("TicketPoints", data.TicketPoints)
	player:SetAttribute("ToolLevel", data.ToolLevel)
	player:SetAttribute("SpeedLevel", data.SpeedLevel)
	player:SetAttribute("UnlockedBoxes", data.UnlockedBoxes)

	-- Restaurar configurações dos Boxes (CurrentCar e PendingCar)
	CarLifecycleService.LoadBoxCars(player, data.BoxCars)

	player:SetAttribute("DataLoadFailed", false)
	player:SetAttribute("DataLoaded", true)
	return true
end

local function snapshot(player: Player): PlayerData?
	local money, cars, tickets = getStats(player)
	local toolLevel = player:GetAttribute("ToolLevel")
	local speedLevel = player:GetAttribute("SpeedLevel")
	local unlockedBoxes = player:GetAttribute("UnlockedBoxes")
	local ticketPoints = player:GetAttribute("TicketPoints")
	if not money or not cars or not tickets or typeof(toolLevel) ~= "number" then return nil end
	return sanitize({
		Cash = money.Value,
		CarsDismantled = cars.Value,
		AuctionTickets = tickets.Value,
		TicketPoints = if typeof(ticketPoints) == "number" then ticketPoints else 0,
		ToolLevel = toolLevel,
		SpeedLevel = if typeof(speedLevel) == "number" then speedLevel else 1,
		UnlockedBoxes = if typeof(unlockedBoxes) == "number" then unlockedBoxes else 1,
		BoxCars = CarLifecycleService.SerializeBoxCars(player),
		SchemaVersion = SCHEMA_VERSION,
	})
end

local function releaseCurrentLockOnly(key: string): boolean
	if USE_STUDIO_MEMORY_MOCK then
		local storedData = studioMockStore[key]
		local stored = if storedData ~= nil then sanitize(storedData) else nil
		if not stored or not isLockOwnedByCurrentSession(stored.Lock) then return false end
		stored.Lock = nil
		studioMockStore[key] = stored
		return true
	end

	for attempt = 1, DATASTORE_MAX_ATTEMPTS do
		local success, result = pcall(function()
			local dataStore = DataStoreService:GetDataStore(STORE_NAME)
			return dataStore:UpdateAsync(key, function(oldValue)
				if oldValue == nil then return nil end
				local stored = sanitize(oldValue)
				if not isLockOwnedByCurrentSession(stored.Lock) then return nil end
				stored.Lock = nil
				return stored
			end)
		end)

		if success then
			return typeof(result) == "table" and sanitize(result).Lock == nil
		end
		if attempt < DATASTORE_MAX_ATTEMPTS then
			task.wait(2 ^ (attempt - 1))
		end
	end
	return false
end

local function applyAcquiredData(player: Player, data: PlayerData, key: string): boolean
	local success, applied = pcall(applyData, player, data)
	if success and applied == true then return true end

	releaseCurrentLockOnly(key)
	player:SetAttribute("DataLoaded", false)
	player:SetAttribute("DataLoadFailed", true)
	warn("Failed to apply loaded data for " .. player.Name .. ": " .. tostring(applied))
	if player.Parent == Players then
		player:Kick("Não foi possível preparar seus dados com segurança. Tente entrar novamente.")
	end
	return false
end

local function loadPlayer(player: Player)
	player:SetAttribute("DataLoaded", false)
	player:SetAttribute("DataLoadFailed", false)
	local key = "Player_" .. player.UserId

	-- Mock para qualquer sessão do Studio. Ele não sobrevive ao encerramento do servidor.
	if USE_STUDIO_MEMORY_MOCK then
		player:SetAttribute("DataSessionMode", "StudioMock")
		local cached = studioMockStore[key]
		local data = sanitize(cached)
		local now = os.time()
		if cached ~= nil and data.Lock and not isLockOwnedByCurrentSession(data.Lock) and isLockActive(data.Lock, now) then
			warn(string.format("Player %s is locked by session %s in mock store.", player.Name, data.Lock.JobId))
			player:SetAttribute("DataLoadFailed", true)
			player:Kick("Seus dados ainda estão abertos em outra sessão. Aguarde alguns minutos e reconecte.")
			return
		end

		data.Lock = makeCurrentLock(now)
		studioMockStore[key] = data
		applyAcquiredData(player, data, key)
		return
	end

	player:SetAttribute("DataSessionMode", "Persistent")
	local loadedData: PlayerData? = nil
	local lockConflict = false
	local otherJobId = ""

	for attempt = 1, LOCK_ACQUIRE_RETRIES do
		if not player.Parent then return end

		local success, result = pcall(function()
			local dataStore = DataStoreService:GetDataStore(STORE_NAME)
			return dataStore:UpdateAsync(key, function(oldValue)
				-- O Roblox pode executar este callback novamente em caso de conflito.
				-- Por isso, ele apenas transforma e retorna os dados recebidos.
				local now = os.time()
				local candidate = sanitize(oldValue)
				local existingLock = candidate.Lock
				if existingLock and not isLockOwnedByCurrentSession(existingLock) and isLockActive(existingLock, now) then
					return nil
				end

				candidate.Lock = makeCurrentLock(now)
				return candidate
			end)
		end)

		if success then
			if typeof(result) == "table" then
				local committedData = sanitize(result)
				if isLockOwnedByCurrentSession(committedData.Lock) then
					loadedData = committedData
					break
				end
				if committedData.Lock then otherJobId = committedData.Lock.JobId end
			end
			lockConflict = true
			warn(string.format("Player %s (UserId: %d) data lock is held by another session. Retry %d/%d in %ds...", player.Name, player.UserId, attempt, LOCK_ACQUIRE_RETRIES, LOCK_RETRY_DELAY))
			if attempt < LOCK_ACQUIRE_RETRIES then
				task.wait(LOCK_RETRY_DELAY)
			end
		else
			warn(string.format("DataStore UpdateAsync error for %s (attempt %d/%d): %s", player.Name, attempt, LOCK_ACQUIRE_RETRIES, tostring(result)))
			if attempt < LOCK_ACQUIRE_RETRIES then
				task.wait(2 ^ (attempt - 1))
			end
		end
	end

	if not player.Parent then
		if loadedData then releaseCurrentLockOnly(key) end
		return
	end

	if loadedData then
		applyAcquiredData(player, loadedData, key)
	elseif lockConflict then
		warn(string.format("Player %s kicked to prevent session overlap with session %s.", player.Name, if otherJobId ~= "" then otherJobId else "unknown"))
		player:SetAttribute("DataLoadFailed", true)
		player:Kick("Seus dados ainda estão abertos em outro servidor. Aguarde alguns minutos e reconecte.")
	else
		warn("DataStore unavailable while loading data for " .. player.Name)
		if RunService:IsStudio() then
			player:SetAttribute("DataSessionMode", "StudioTemporary")
			applyData(player, newDefaultData())
			player:SetAttribute("DataLoadFailed", true)
		else
			player:SetAttribute("DataLoadFailed", true)
			player:Kick("Não foi possível carregar seus dados com segurança. Tente entrar novamente em alguns minutos.")
		end
	end
end

local function initializePlayer(player: Player)
	task.spawn(loadPlayer, player)
end

local function markConfirmedLockLoss(player: Player)
	player:SetAttribute("DataLoaded", false)
	player:SetAttribute("DataLoadFailed", true)
	if player.Parent == Players then
		task.defer(function()
			if player.Parent == Players then
				player:Kick("Sua sessão de dados foi aberta em outro servidor. Entre novamente para proteger seu progresso.")
			end
		end)
	end
end

local function savePlayer(player: Player, releaseLock: boolean?): boolean
	if player:GetAttribute("DataLoaded") ~= true or player:GetAttribute("DataLoadFailed") == true or saving[player] then return false end
	local data = snapshot(player)
	if not data then return false end
	saving[player] = true
	local key = "Player_" .. player.UserId
	local shouldRelease = releaseLock == true

	-- No Studio, manter apenas durante a vida deste servidor de teste.
	if USE_STUDIO_MEMORY_MOCK then
		local storedData = studioMockStore[key]
		local stored = if storedData ~= nil then sanitize(storedData) else nil
		if not stored or not isLockOwnedByCurrentSession(stored.Lock) then
			saving[player] = nil
			if not shouldRelease then markConfirmedLockLoss(player) end
			return false
		end

		if shouldRelease then
			data.Lock = nil
		else
			data.Lock = makeCurrentLock(os.time())
		end
		studioMockStore[key] = data
		saving[player] = nil
		return true
	end

	local writeConfirmed = false
	local confirmedLockLoss = false
	local lastError: any = nil

	for attempt = 1, DATASTORE_MAX_ATTEMPTS do
		local success, result = pcall(function()
			local dataStore = DataStoreService:GetDataStore(STORE_NAME)
			return dataStore:UpdateAsync(key, function(oldValue)
				if oldValue == nil then return nil end
				local currentStored = sanitize(oldValue)
				-- Um servidor antigo nunca recupera posse durante um save,
				-- mesmo que o lock de outra sessão já esteja expirado.
				if not isLockOwnedByCurrentSession(currentStored.Lock) then return nil end

				local writeData = sanitize(data)
				if shouldRelease then
					writeData.Lock = nil
				else
					writeData.Lock = makeCurrentLock(os.time())
				end
				return writeData
			end)
		end)

		if success then
			if typeof(result) == "table" then
				local committedData = sanitize(result)
				writeConfirmed = if shouldRelease
					then committedData.Lock == nil
					else isLockOwnedByCurrentSession(committedData.Lock)
			end
			if not writeConfirmed then confirmedLockLoss = true end
			break
		else
			lastError = result
			if attempt < DATASTORE_MAX_ATTEMPTS then
				task.wait(2 ^ (attempt - 1))
			end
		end
	end

	saving[player] = nil

	if confirmedLockLoss then
		warn(string.format("Save aborted for %s: this server no longer owns the session lock.", player.Name))
		if not shouldRelease then markConfirmedLockLoss(player) end
		return false
	end

	if not writeConfirmed then
		warn("Failed to save data for " .. player.Name .. ": " .. tostring(lastError))
	end
	return writeConfirmed
end

local function renewLock(player: Player): boolean
	if player:GetAttribute("DataLoaded") ~= true or player:GetAttribute("DataLoadFailed") == true or saving[player] then return false end
	saving[player] = true
	local key = "Player_" .. player.UserId

	if USE_STUDIO_MEMORY_MOCK then
		local storedData = studioMockStore[key]
		local stored = if storedData ~= nil then sanitize(storedData) else nil
		if not stored or not isLockOwnedByCurrentSession(stored.Lock) then
			saving[player] = nil
			markConfirmedLockLoss(player)
			return false
		end
		stored.Lock = makeCurrentLock(os.time())
		studioMockStore[key] = stored
		saving[player] = nil
		return true
	end

	local renewalConfirmed = false
	local confirmedLockLoss = false
	local lastError: any = nil

	for attempt = 1, DATASTORE_MAX_ATTEMPTS do
		local success, result = pcall(function()
			local dataStore = DataStoreService:GetDataStore(STORE_NAME)
			return dataStore:UpdateAsync(key, function(oldValue)
				if oldValue == nil then return nil end
				local stored = sanitize(oldValue)
				if not isLockOwnedByCurrentSession(stored.Lock) then return nil end
				stored.Lock = makeCurrentLock(os.time())
				return stored
			end)
		end)

		if success then
			if typeof(result) == "table" then
				local committedData = sanitize(result)
				renewalConfirmed = isLockOwnedByCurrentSession(committedData.Lock)
			end
			if not renewalConfirmed then confirmedLockLoss = true end
			break
		else
			lastError = result
			if attempt < DATASTORE_MAX_ATTEMPTS then
				task.wait(2 ^ (attempt - 1))
			end
		end
	end

	saving[player] = nil
	if confirmedLockLoss then
		warn(string.format("Lock renewal aborted for %s: this server no longer owns the session lock.", player.Name))
		markConfirmedLockLoss(player)
		return false
	end
	if not renewalConfirmed then
		warn("Failed to renew session lock for " .. player.Name .. ": " .. tostring(lastError))
	end
	return renewalConfirmed
end

local function waitForOperationAndRelease(player: Player, deadline: number): boolean
	while saving[player] and os.clock() < deadline do
		task.wait(0.1)
	end
	if saving[player] or os.clock() >= deadline then return false end
	return savePlayer(player, true)
end

function PlayerDataService.SavePlayer(player: Player, releaseLock: boolean?): boolean
	return savePlayer(player, releaseLock)
end

function PlayerDataService.LoadPlayer(player: Player)
	loadPlayer(player)
end

function PlayerDataService.GetStoredMockData(userId: number): any
	if not RunService:IsStudio() then return nil end
	return studioMockStore["Player_" .. userId]
end

function PlayerDataService.SetStoredMockData(userId: number, data: any): boolean
	if not RunService:IsStudio() then return false end
	studioMockStore["Player_" .. userId] = data
	return true
end

function PlayerDataService.start()
	Players.PlayerAdded:Connect(initializePlayer)
	Players.PlayerRemoving:Connect(function(player)
		waitForOperationAndRelease(player, os.clock() + 10)
	end)
	for _, player in Players:GetPlayers() do
		initializePlayer(player)
	end

	task.spawn(function()
		local elapsed = 0
		while true do
			task.wait(LOCK_HEARTBEAT_INTERVAL)
			elapsed += LOCK_HEARTBEAT_INTERVAL
			local shouldAutosave = elapsed >= AUTOSAVE_INTERVAL
			if shouldAutosave then elapsed = 0 end
			for _, player in Players:GetPlayers() do
				if shouldAutosave then
					task.spawn(savePlayer, player, false)
				else
					task.spawn(renewLock, player)
				end
			end
		end
	end)

	game:BindToClose(function()
		local deadline = os.clock() + SHUTDOWN_SAVE_TIMEOUT
		local remaining = 0
		for _, player in Players:GetPlayers() do
			remaining += 1
			task.spawn(function()
				pcall(waitForOperationAndRelease, player, deadline)
				remaining -= 1
			end)
		end
		while remaining > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return PlayerDataService
