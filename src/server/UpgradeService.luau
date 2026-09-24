--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local SpeedUpgradeService = require(ServerScriptService.Server.SpeedUpgradeService)
local ToolUpgradeService = require(ServerScriptService.Server.ToolUpgradeService)

local UpgradeService = {}
local purchaseBusy: {[Player]: boolean} = {}

local function ensurePurchaseRemote(): RemoteFunction
	local existing = ReplicatedStorage:FindFirstChild("PurchaseUpgrade")
	if existing and existing:IsA("RemoteFunction") then
		return existing
	end
	if existing then existing:Destroy() end
	local remote = Instance.new("RemoteFunction")
	remote.Name = "PurchaseUpgrade"
	remote.Parent = ReplicatedStorage
	return remote
end

function UpgradeService.start()
	local purchaseRemote = ensurePurchaseRemote()
	purchaseRemote.OnServerInvoke = function(player: Player, category: any)
		if typeof(category) ~= "string" then
			return { Success = false, Message = "Categoria de melhoria inválida." }
		end
		if purchaseBusy[player] then
			return { Success = false, Message = "A compra anterior ainda está sendo processada." }
		end

		purchaseBusy[player] = true
		local callOk, purchaseOk, message = pcall(function(): (boolean, string)
			if category == "Tool" then
				return ToolUpgradeService.PurchaseNext(player)
			elseif category == "Speed" then
				return SpeedUpgradeService.PurchaseNext(player)
			end
			return false, "Categoria de melhoria inválida."
		end)
		purchaseBusy[player] = nil

		if not callOk then
			warn(string.format("Upgrade purchase failed for %s: %s", player.Name, tostring(purchaseOk)))
			return { Success = false, Message = "Não foi possível concluir a compra." }
		end
		return { Success = purchaseOk, Message = message }
	end

	Players.PlayerRemoving:Connect(function(player)
		purchaseBusy[player] = nil
	end)
end

return UpgradeService
