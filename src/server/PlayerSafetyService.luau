--!strict

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local PartRemovalService = require(ServerScriptService.Server.PartRemovalService)
local EngineHoistService = require(ServerScriptService.Server.EngineHoistService)

local PlayerSafetyService = {}

local function cleanupPlayer(player: Player)
	PartRemovalService.HandlePlayerLoss(player)
	EngineHoistService.ReleasePlayer(player)
end

local function bindPlayer(player: Player)
	player.CharacterRemoving:Connect(function()
		cleanupPlayer(player)
	end)
end

function PlayerSafetyService.start()
	Players.PlayerAdded:Connect(bindPlayer)
	for _, player in Players:GetPlayers() do bindPlayer(player) end
	Players.PlayerRemoving:Connect(cleanupPlayer)
end

return PlayerSafetyService
