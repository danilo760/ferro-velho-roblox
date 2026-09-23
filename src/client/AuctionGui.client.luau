--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local AUCTION_CENTER = Vector3.new(0, 0.5, 85)
local ACTIVATION_DISTANCE = 55

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AuctionGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local frame = Instance.new("Frame")
frame.Name = "AuctionCard"
frame.AnchorPoint = Vector2.new(1, 0)
frame.Position = UDim2.new(1, -20, 0, 80)
frame.Size = UDim2.fromOffset(280, 200)
frame.BackgroundColor3 = Color3.fromRGB(20, 24, 30)
frame.BorderSizePixel = 0
frame.Visible = false
frame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = frame

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(240, 180, 40)
stroke.Thickness = 2
stroke.Parent = frame

-- Título
local headerLabel = Instance.new("TextLabel")
headerLabel.Size = UDim2.new(1, -20, 0, 26)
headerLabel.Position = UDim2.fromOffset(10, 8)
headerLabel.BackgroundTransparency = 1
headerLabel.Text = "⚖️ LEILÃO DE SUCATAS"
headerLabel.TextColor3 = Color3.fromRGB(255, 215, 60)
headerLabel.TextScaled = true
headerLabel.Font = Enum.Font.GothamBlack
headerLabel.Parent = frame

-- Nome do Carro
local carLabel = Instance.new("TextLabel")
carLabel.Size = UDim2.new(1, -20, 0, 20)
carLabel.Position = UDim2.fromOffset(10, 36)
carLabel.BackgroundTransparency = 1
carLabel.Text = "Aguardando lote..."
carLabel.TextColor3 = Color3.fromRGB(220, 225, 235)
carLabel.TextScaled = true
carLabel.Font = Enum.Font.GothamBold
carLabel.Parent = frame

-- Status e Timer
local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -20, 0, 18)
statusLabel.Position = UDim2.fromOffset(10, 58)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Status: --"
statusLabel.TextColor3 = Color3.fromRGB(130, 200, 255)
statusLabel.TextScaled = true
statusLabel.Font = Enum.Font.Gotham
statusLabel.Parent = frame

-- Maior Lance
local bidLabel = Instance.new("TextLabel")
bidLabel.Size = UDim2.new(1, -20, 0, 24)
bidLabel.Position = UDim2.fromOffset(10, 80)
bidLabel.BackgroundTransparency = 1
bidLabel.Text = "Lance: R$ 0"
bidLabel.TextColor3 = Color3.fromRGB(80, 255, 130)
bidLabel.TextScaled = true
bidLabel.Font = Enum.Font.GothamBlack
bidLabel.Parent = frame

-- Líder
local leaderLabel = Instance.new("TextLabel")
leaderLabel.Size = UDim2.new(1, -20, 0, 16)
leaderLabel.Position = UDim2.fromOffset(10, 106)
leaderLabel.BackgroundTransparency = 1
leaderLabel.Text = "Líder: Nenhum"
leaderLabel.TextColor3 = Color3.fromRGB(180, 190, 200)
leaderLabel.TextScaled = true
leaderLabel.Font = Enum.Font.Gotham
leaderLabel.Parent = frame

-- Feedback de erro / mensagem rápida
local feedbackLabel = Instance.new("TextLabel")
feedbackLabel.Size = UDim2.new(1, -20, 0, 16)
feedbackLabel.Position = UDim2.fromOffset(10, 124)
feedbackLabel.BackgroundTransparency = 1
feedbackLabel.Text = ""
feedbackLabel.TextColor3 = Color3.fromRGB(255, 100, 90)
feedbackLabel.TextScaled = true
feedbackLabel.Font = Enum.Font.GothamBold
feedbackLabel.Parent = frame

-- Container de Botões
local btnContainer = Instance.new("Frame")
btnContainer.Size = UDim2.new(1, -20, 0, 42)
btnContainer.Position = UDim2.fromOffset(10, 146)
btnContainer.BackgroundTransparency = 1
btnContainer.Parent = frame

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.Padding = UDim.new(0, 8)
layout.Parent = btnContainer

local function createBidButton(amount: number, color: Color3)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0.31, -4, 1, 0)
	btn.BackgroundColor3 = color
	btn.BorderSizePixel = 0
	btn.Text = string.format("+R$ %d", amount)
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.TextScaled = true
	btn.Font = Enum.Font.GothamBlack
	btn.Parent = btnContainer

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 6)
	btnCorner.Parent = btn

	btn.MouseButton1Click:Connect(function()
		local remote = ReplicatedStorage:FindFirstChild("PlaceAuctionBid")
		if remote and remote:IsA("RemoteFunction") then
			local success, message = remote:InvokeServer(amount)
			if not success then
				feedbackLabel.Text = message or "Lance rejeitado"
				task.delay(2.5, function()
					if feedbackLabel.Text == message then feedbackLabel.Text = "" end
				end)
			else
				feedbackLabel.Text = "✅ " .. (message or "Lance aceito!")
				feedbackLabel.TextColor3 = Color3.fromRGB(80, 255, 120)
				task.delay(2, function()
					feedbackLabel.Text = ""
					feedbackLabel.TextColor3 = Color3.fromRGB(255, 100, 90)
				end)
			end
		end
	end)
end

createBidButton(50, Color3.fromRGB(45, 160, 85))
createBidButton(100, Color3.fromRGB(40, 120, 205))
createBidButton(250, Color3.fromRGB(210, 145, 30))

-- Loop de proximidade e atualização
RunService.Heartbeat:Connect(function()
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		frame.Visible = false
		return
	end

	local dist = (root.Position - AUCTION_CENTER).Magnitude
	local inRange = dist <= ACTIVATION_DISTANCE

	if inRange ~= frame.Visible then
		frame.Visible = inRange
	end

	if inRange then
		local house = Workspace:FindFirstChild("AuctionHouse")
		if house then
			local state = house:GetAttribute("AuctionState") or "Waiting"
			local vehicleName = house:GetAttribute("VehicleName") or ""
			local lotId = house:GetAttribute("LotId") or 0
			local currentBid = house:GetAttribute("CurrentBid") or 0
			local timer = house:GetAttribute("TimeRemaining") or 0
			local leader = house:GetAttribute("LeaderName") or "Nenhum"

			if vehicleName ~= "" then
				carLabel.Text = string.format("Lote #%d: %s", lotId, vehicleName)
			else
				carLabel.Text = "Preparando próximo lote..."
			end

			if state == "Waiting" then
				statusLabel.Text = string.format("Próximo lote em: %02ds", timer)
				statusLabel.TextColor3 = Color3.fromRGB(150, 190, 230)
			elseif state == "Inspection" then
				statusLabel.Text = string.format("Inspeção na mesa: %02ds", timer)
				statusLabel.TextColor3 = Color3.fromRGB(255, 215, 60)
			elseif state == "Bidding" then
				statusLabel.Text = string.format("LANCES ABERTOS: ⏱️ %02ds", timer)
				statusLabel.TextColor3 = if timer <= 5 then Color3.fromRGB(255, 80, 70) else Color3.fromRGB(80, 255, 120)
			elseif state == "Sold" then
				statusLabel.Text = "🔨 VENDIDO!"
				statusLabel.TextColor3 = Color3.fromRGB(80, 255, 120)
			else
				statusLabel.Text = "Lote não arrematado"
				statusLabel.TextColor3 = Color3.fromRGB(180, 180, 190)
			end

			bidLabel.Text = string.format("Lance: R$ %d", currentBid)
			leaderLabel.Text = string.format("Líder: %s", leader)
		end
	end
end)
