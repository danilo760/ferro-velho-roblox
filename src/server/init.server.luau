--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local EconomyService = require(ServerScriptService.Server.EconomyService)
local PlayerSafetyService = require(ServerScriptService.Server.PlayerSafetyService)
local CarLifecycleService = require(ServerScriptService.Server.CarLifecycleService)

EconomyService.start()
PlayerSafetyService.start()
CarLifecycleService.start()
