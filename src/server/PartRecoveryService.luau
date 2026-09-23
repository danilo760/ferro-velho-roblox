--!strict

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local PartRemovalService = require(ServerScriptService.Server.PartRemovalService)
local PartRecoveryService = {}

local RECOVERY_HEIGHT = -25
local CHECK_INTERVAL = 0.5

function PartRecoveryService.start(car: Model, plotGroundY: number, recoveryOrigin: CFrame)
	task.spawn(function()
		while car.Parent do
			local recoveryIndex = 0
			for _, descendant in car:GetDescendants() do
				if descendant:IsA("BasePart")
					and descendant.Name ~= "Engine"
					and descendant:GetAttribute("PartId") ~= nil
					and descendant.Position.Y < RECOVERY_HEIGHT then
					recoveryIndex += 1
					local carrierId = descendant:GetAttribute("CarrierUserId")
					if typeof(carrierId) == "number" and carrierId > 0 then
						local player = Players:GetPlayerByUserId(carrierId)
						if player then PartRemovalService.ClearCarriedPart(player) end
					end

					local carryWeld = descendant:FindFirstChild("CarryWeld")
					if carryWeld then carryWeld:Destroy() end
					local row = math.floor((recoveryIndex - 1) / 6)
					local column = (recoveryIndex - 1) % 6
					local side = if row == 0 then -1 else 1
					local recoveryTarget = recoveryOrigin * CFrame.new(side * 7, 0, -6 + column * 2.5)
					descendant.Anchored = true
					descendant.CanCollide = true
					descendant.Massless = false
					descendant.CFrame = CFrame.new(
						recoveryTarget.Position.X,
						plotGroundY + descendant.Size.Y / 2 + 0.1,
						recoveryTarget.Position.Z
					) * recoveryOrigin.Rotation
					descendant:SetAttribute("PartState", "Removed")
					descendant:SetAttribute("CarrierUserId", 0)

					local prompt = descendant:FindFirstChildWhichIsA("ProximityPrompt", true)
					if prompt then
						prompt.ActionText = "Pegar"
						prompt.HoldDuration = 0.25
						prompt.Enabled = true
					end
				end
			end
			task.wait(CHECK_INTERVAL)
		end
	end)
end

return PartRecoveryService
