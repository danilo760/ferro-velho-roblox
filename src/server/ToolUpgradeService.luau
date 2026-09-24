--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local EconomyService = require(ServerScriptService.Server.EconomyService)
local PlotService = require(ServerScriptService.Server.PlotService)
local ToolUpgradeConfig = require(ReplicatedStorage.Shared.ToolUpgradeConfig)

local ToolUpgradeService = {}

local function initializePlayer(player: Player)
	if player:GetAttribute("ToolLevel") == nil then
		player:SetAttribute("ToolLevel", 1)
	end
end

function ToolUpgradeService.PurchaseNext(player: Player): (boolean, string)
	if player:GetAttribute("DataLoaded") ~= true then
		return false, "Seus dados ainda estão carregando."
	end
	if not PlotService.GetPlot(player) then
		return false, "Você precisa ter um lote para comprar melhorias."
	end

	local currentValue = player:GetAttribute("ToolLevel")
	local currentLevel = if typeof(currentValue) == "number" then math.clamp(currentValue, 1, 2) else 1
	local nextDefinition = ToolUpgradeConfig.Get(currentLevel + 1)
	if not nextDefinition or not nextDefinition.PurchaseCost then
		return false, "Sua ferramenta já está no nível máximo."
	end

	if not EconomyService.TrySpend(player, nextDefinition.PurchaseCost) then
		return false, "Dinheiro insuficiente."
	end

	player:SetAttribute("ToolLevel", nextDefinition.Level)
	PlotService.SyncUpgradeWorkshop(player)
	return true, string.format("%s adquirida com sucesso!", nextDefinition.Name)
end

function ToolUpgradeService.start()
	Players.PlayerAdded:Connect(initializePlayer)
	for _, player in Players:GetPlayers() do
		initializePlayer(player)
	end
end

return ToolUpgradeService
