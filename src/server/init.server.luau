--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local TrainingCarBuilder = require(ServerScriptService.Server.TrainingCarBuilder)
local PartRemovalService = require(ServerScriptService.Server.PartRemovalService)
local EngineHoistService = require(ServerScriptService.Server.EngineHoistService)
local EconomyService = require(ServerScriptService.Server.EconomyService)

local existingCar = Workspace:FindFirstChild("TrainingCar01")
if existingCar then existingCar:Destroy() end

local car = TrainingCarBuilder.create()
car.Parent = Workspace

PartRemovalService.setupCar(car)
EngineHoistService.start(car)
EconomyService.start()
