--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local RecyclingCenterService = require(ServerScriptService.Server.RecyclingCenterService)
local EconomyService = require(ServerScriptService.Server.EconomyService)
local PlayerDataService = require(ServerScriptService.Server.PlayerDataService)
local PlayerSafetyService = require(ServerScriptService.Server.PlayerSafetyService)
local PlotService = require(ServerScriptService.Server.PlotService)
local CarLifecycleService = require(ServerScriptService.Server.CarLifecycleService)
local ToolUpgradeService = require(ServerScriptService.Server.ToolUpgradeService)
local SpeedUpgradeService = require(ServerScriptService.Server.SpeedUpgradeService)

RecyclingCenterService.start()
EconomyService.start()
PlayerDataService.start()
PlayerSafetyService.start()
ToolUpgradeService.start()
SpeedUpgradeService.start()
PlotService.start()
CarLifecycleService.start()
