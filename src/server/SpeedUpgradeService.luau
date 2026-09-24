--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local EconomyService = require(ServerScriptService.Server.EconomyService)
local PlotService = require(ServerScriptService.Server.PlotService)
local SpeedUpgradeConfig = require(ReplicatedStorage.Shared.SpeedUpgradeConfig)

local SpeedUpgradeService = {}

local function applySpeedToCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 5)
	if humanoid and humanoid:IsA("Humanoid") then
		local currentValue = player:GetAttribute("SpeedLevel")
		local currentLevel = if typeof(currentValue) == "number" then currentValue else 1
		local definition = SpeedUpgradeConfig.Get(currentLevel)
		if definition then
			humanoid.WalkSpeed = definition.Speed
		end
	end
end

local function initializePlayer(player: Player)
	if player:GetAttribute("SpeedLevel") == nil then
		player:SetAttribute("SpeedLevel", 1)
	end

	player.CharacterAdded:Connect(function(character)
		task.defer(applySpeedToCharacter, player, character)
	end)
	player:GetAttributeChangedSignal("SpeedLevel"):Connect(function()
		if player.Character then
			applySpeedToCharacter(player, player.Character)
		end
	end)
	if player.Character then
		task.defer(applySpeedToCharacter, player, player.Character)
	end
end

function SpeedUpgradeService.PurchaseNext(player: Player): (boolean, string)
	if player:GetAttribute("DataLoaded") ~= true then
		return false, "Seus dados ainda estão carregando."
	end
	if not PlotService.GetPlot(player) then
		return false, "Você precisa ter um lote para comprar melhorias."
	end

	local currentValue = player:GetAttribute("SpeedLevel")
	local currentLevel = if typeof(currentValue) == "number" then math.clamp(currentValue, 1, SpeedUpgradeConfig.GetMaxLevel()) else 1
	local nextDefinition = SpeedUpgradeConfig.Get(currentLevel + 1)
	if not nextDefinition or not nextDefinition.PurchaseCost then
		return false, "Sua velocidade já está no nível máximo."
	end

	if not EconomyService.TrySpend(player, nextDefinition.PurchaseCost) then
		return false, "Dinheiro insuficiente."
	end

	player:SetAttribute("SpeedLevel", nextDefinition.Level)
	PlotService.SyncUpgradeWorkshop(player)
	if player.Character then
		applySpeedToCharacter(player, player.Character)
	end
	return true, string.format("%s adquirida com sucesso!", nextDefinition.Name)
end

function SpeedUpgradeService.start()
	Players.PlayerAdded:Connect(initializePlayer)
	for _, player in Players:GetPlayers() do
		initializePlayer(player)
	end
end

return SpeedUpgradeService
