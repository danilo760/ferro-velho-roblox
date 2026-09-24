--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local SpeedUpgradeConfig = require(ReplicatedStorage.Shared.SpeedUpgradeConfig)
local ToolUpgradeConfig = require(ReplicatedStorage.Shared.ToolUpgradeConfig)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local purchaseRemote = ReplicatedStorage:WaitForChild("PurchaseUpgrade", 10)

local function addCorner(parent: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

local function addStroke(parent: Instance, color: Color3, thickness: number, transparency: number?)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Transparency = transparency or 0
	stroke.Parent = parent
end

local function addTextLimit(parent: Instance, minimum: number, maximum: number)
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MinTextSize = minimum
	constraint.MaxTextSize = maximum
	constraint.Parent = parent
end

local function formatMoney(value: number): string
	local reversed = string.reverse(tostring(math.max(0, math.floor(value))))
	local grouped = string.gsub(reversed, "(%d%d%d)", "%1.")
	local formatted = string.reverse(grouped)
	if string.sub(formatted, 1, 1) == "." then
		formatted = string.sub(formatted, 2)
	end
	return "R$ " .. formatted
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "UpgradesGui"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 20
screenGui.Parent = playerGui

local openButton = Instance.new("TextButton")
openButton.Name = "OpenUpgrades"
openButton.AnchorPoint = Vector2.new(1, 0.5)
openButton.Position = UDim2.new(1, -18, 0.52, 0)
openButton.Size = UDim2.fromOffset(158, 54)
openButton.BackgroundColor3 = Color3.fromRGB(31, 35, 39)
openButton.BorderSizePixel = 0
openButton.Text = "MELHORIAS"
openButton.TextColor3 = Color3.fromRGB(246, 196, 55)
openButton.TextSize = 17
openButton.Font = Enum.Font.GothamBlack
openButton.AutoButtonColor = false
openButton.Parent = screenGui
addCorner(openButton, 10)
addStroke(openButton, Color3.fromRGB(246, 196, 55), 2)

local buttonAccent = Instance.new("Frame")
buttonAccent.Name = "Accent"
buttonAccent.Size = UDim2.new(0, 7, 1, 0)
buttonAccent.BackgroundColor3 = Color3.fromRGB(246, 196, 55)
buttonAccent.BorderSizePixel = 0
buttonAccent.Parent = openButton
addCorner(buttonAccent, 10)

local backdrop = Instance.new("Frame")
backdrop.Name = "Backdrop"
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
backdrop.BackgroundTransparency = 0.42
backdrop.BorderSizePixel = 0
backdrop.Visible = false
backdrop.Active = true
backdrop.Parent = screenGui

local window = Instance.new("Frame")
window.Name = "Window"
window.AnchorPoint = Vector2.new(0.5, 0.5)
window.Position = UDim2.fromScale(0.5, 0.5)
window.Size = UDim2.fromScale(0.82, 0.78)
window.BackgroundColor3 = Color3.fromRGB(22, 25, 29)
window.BorderSizePixel = 0
window.Parent = backdrop
addCorner(window, 14)
addStroke(window, Color3.fromRGB(210, 158, 37), 2)

local windowSize = Instance.new("UISizeConstraint")
windowSize.MinSize = Vector2.new(300, 420)
windowSize.MaxSize = Vector2.new(720, 600)
windowSize.Parent = window

local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 92)
header.BackgroundColor3 = Color3.fromRGB(31, 35, 40)
header.BorderSizePixel = 0
header.Parent = window
addCorner(header, 14)

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, -70, 0, 36)
title.Position = UDim2.fromOffset(20, 8)
title.BackgroundTransparency = 1
title.Text = "CENTRAL DE MELHORIAS"
title.TextColor3 = Color3.fromRGB(246, 196, 55)
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextScaled = true
title.Font = Enum.Font.GothamBlack
title.Parent = header
addTextLimit(title, 15, 24)

local subtitle = Instance.new("TextLabel")
subtitle.Name = "Subtitle"
subtitle.Size = UDim2.fromOffset(62, 30)
subtitle.Position = UDim2.fromOffset(20, 50)
subtitle.BackgroundTransparency = 1
subtitle.Text = "SALDO"
subtitle.TextColor3 = Color3.fromRGB(170, 178, 188)
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.TextSize = 13
subtitle.Font = Enum.Font.GothamBold
subtitle.Parent = header

local moneyLabel = Instance.new("TextLabel")
moneyLabel.Name = "Money"
moneyLabel.Position = UDim2.fromOffset(88, 48)
moneyLabel.Size = UDim2.fromOffset(150, 34)
moneyLabel.BackgroundColor3 = Color3.fromRGB(43, 50, 45)
moneyLabel.BorderSizePixel = 0
moneyLabel.Text = "R$ 0"
moneyLabel.TextColor3 = Color3.fromRGB(100, 235, 140)
moneyLabel.TextSize = 15
moneyLabel.Font = Enum.Font.GothamBlack
moneyLabel.Parent = header
addCorner(moneyLabel, 17)

local closeButton = Instance.new("TextButton")
closeButton.Name = "Close"
closeButton.AnchorPoint = Vector2.new(1, 0.5)
closeButton.Position = UDim2.new(1, -12, 0.5, 0)
closeButton.Size = UDim2.fromOffset(36, 36)
closeButton.BackgroundColor3 = Color3.fromRGB(164, 53, 46)
closeButton.BorderSizePixel = 0
closeButton.Text = "X"
closeButton.TextColor3 = Color3.new(1, 1, 1)
closeButton.TextSize = 17
closeButton.Font = Enum.Font.GothamBlack
closeButton.Parent = header
addCorner(closeButton, 18)

local content = Instance.new("ScrollingFrame")
content.Name = "Content"
content.Position = UDim2.fromOffset(16, 108)
content.Size = UDim2.new(1, -32, 1, -124)
content.BackgroundTransparency = 1
content.BorderSizePixel = 0
content.ScrollBarThickness = 5
content.ScrollBarImageColor3 = Color3.fromRGB(210, 158, 37)
content.AutomaticCanvasSize = Enum.AutomaticSize.Y
content.CanvasSize = UDim2.fromOffset(0, 0)
content.Parent = window

local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 12)
list.FillDirection = Enum.FillDirection.Vertical
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Parent = content

type CardReferences = {
	Root: Frame,
	Level: TextLabel,
	Current: TextLabel,
	Next: TextLabel,
	Buy: TextButton,
}

local function createCard(order: number, category: string, accent: Color3): CardReferences
	local card = Instance.new("Frame")
	card.Name = category .. "Card"
	card.LayoutOrder = order
	card.Size = UDim2.new(1, -6, 0, 238)
	card.BackgroundColor3 = Color3.fromRGB(32, 37, 43)
	card.BorderSizePixel = 0
	card.Parent = content
	addCorner(card, 12)
	addStroke(card, accent, 1, 0.35)

	local accentBar = Instance.new("Frame")
	accentBar.Size = UDim2.new(0, 7, 1, 0)
	accentBar.BackgroundColor3 = accent
	accentBar.BorderSizePixel = 0
	accentBar.Parent = card
	addCorner(accentBar, 12)

	local categoryLabel = Instance.new("TextLabel")
	categoryLabel.Size = UDim2.new(1, -44, 0, 34)
	categoryLabel.Position = UDim2.fromOffset(22, 12)
	categoryLabel.BackgroundTransparency = 1
	categoryLabel.Text = category
	categoryLabel.TextColor3 = accent
	categoryLabel.TextXAlignment = Enum.TextXAlignment.Left
	categoryLabel.TextSize = 20
	categoryLabel.Font = Enum.Font.GothamBlack
	categoryLabel.Parent = card

	local levelLabel = Instance.new("TextLabel")
	levelLabel.Position = UDim2.fromOffset(22, 48)
	levelLabel.Size = UDim2.fromOffset(155, 28)
	levelLabel.BackgroundColor3 = Color3.fromRGB(45, 51, 59)
	levelLabel.BorderSizePixel = 0
	levelLabel.TextColor3 = Color3.fromRGB(225, 230, 236)
	levelLabel.TextSize = 13
	levelLabel.Font = Enum.Font.GothamBold
	levelLabel.Parent = card
	addCorner(levelLabel, 14)

	local currentLabel = Instance.new("TextLabel")
	currentLabel.Position = UDim2.fromOffset(22, 82)
	currentLabel.Size = UDim2.new(1, -44, 0, 48)
	currentLabel.BackgroundTransparency = 1
	currentLabel.TextColor3 = Color3.fromRGB(230, 233, 238)
	currentLabel.TextXAlignment = Enum.TextXAlignment.Left
	currentLabel.TextYAlignment = Enum.TextYAlignment.Top
	currentLabel.TextWrapped = true
	currentLabel.TextSize = 15
	currentLabel.Font = Enum.Font.GothamBold
	currentLabel.Parent = card

	local nextLabel = Instance.new("TextLabel")
	nextLabel.Position = UDim2.fromOffset(22, 130)
	nextLabel.Size = UDim2.new(1, -44, 0, 50)
	nextLabel.BackgroundTransparency = 1
	nextLabel.TextColor3 = Color3.fromRGB(170, 180, 192)
	nextLabel.TextXAlignment = Enum.TextXAlignment.Left
	nextLabel.TextYAlignment = Enum.TextYAlignment.Top
	nextLabel.TextWrapped = true
	nextLabel.TextSize = 14
	nextLabel.Font = Enum.Font.GothamMedium
	nextLabel.Parent = card

	local buyButton = Instance.new("TextButton")
	buyButton.Name = "Buy"
	buyButton.AnchorPoint = Vector2.new(0, 1)
	buyButton.Position = UDim2.new(0, 22, 1, -14)
	buyButton.Size = UDim2.new(1, -44, 0, 46)
	buyButton.BackgroundColor3 = accent
	buyButton.BorderSizePixel = 0
	buyButton.TextColor3 = Color3.fromRGB(20, 24, 28)
	buyButton.TextSize = 14
	buyButton.TextWrapped = true
	buyButton.Font = Enum.Font.GothamBlack
	buyButton.AutoButtonColor = true
	buyButton.Parent = card
	addCorner(buyButton, 9)

	return { Root = card, Level = levelLabel, Current = currentLabel, Next = nextLabel, Buy = buyButton }
end

local toolCard = createCard(1, "FERRAMENTAS", Color3.fromRGB(87, 157, 255))
local speedCard = createCard(2, "MOBILIDADE", Color3.fromRGB(54, 218, 180))

local toast = Instance.new("TextLabel")
toast.Name = "Toast"
toast.AnchorPoint = Vector2.new(0.5, 1)
toast.Position = UDim2.new(0.5, 0, 1, -18)
toast.Size = UDim2.new(0.8, 0, 0, 46)
toast.BackgroundColor3 = Color3.fromRGB(35, 42, 48)
toast.BackgroundTransparency = 1
toast.BorderSizePixel = 0
toast.Text = ""
toast.TextColor3 = Color3.new(1, 1, 1)
toast.TextTransparency = 1
toast.TextSize = 15
toast.TextWrapped = true
toast.Font = Enum.Font.GothamBold
toast.Visible = false
toast.ZIndex = 10
toast.Parent = window
addCorner(toast, 10)

local purchasing = false
local toastSerial = 0

local function getMoney(): number
	local leaderstats = player:FindFirstChild("leaderstats")
	local money = leaderstats and leaderstats:FindFirstChild("Dinheiro")
	return if money and money:IsA("IntValue") then money.Value else 0
end

local function setButtonState(button: TextButton, enabled: boolean, accent: Color3)
	button.Active = enabled
	button.AutoButtonColor = enabled
	button.BackgroundColor3 = if enabled then accent else Color3.fromRGB(69, 74, 80)
	button.TextColor3 = if enabled then Color3.fromRGB(20, 24, 28) else Color3.fromRGB(175, 180, 186)
end

local function refresh()
	moneyLabel.Text = formatMoney(getMoney())

	local toolValue = player:GetAttribute("ToolLevel")
	local toolLevel = if typeof(toolValue) == "number" then math.clamp(toolValue, 1, 2) else 1
	local currentTool = ToolUpgradeConfig.Get(toolLevel)
	local nextTool = ToolUpgradeConfig.Get(toolLevel + 1)
	toolCard.Level.Text = string.format("NÍVEL %d / 2", toolLevel)
	toolCard.Current.Text = string.format("Atual: %s  •  %.1fs por peça", currentTool and currentTool.Name or "Ferramentas básicas", currentTool and currentTool.RemovalSeconds or 1.5)
	if nextTool and nextTool.PurchaseCost then
		toolCard.Next.Text = string.format("Próxima: %s\nReduz o tempo para %.1fs por peça", nextTool.Name, nextTool.RemovalSeconds)
		toolCard.Buy.Text = "COMPRAR  " .. formatMoney(nextTool.PurchaseCost)
		setButtonState(toolCard.Buy, not purchasing, Color3.fromRGB(87, 157, 255))
	else
		toolCard.Next.Text = "Todas as melhorias de ferramenta foram adquiridas."
		toolCard.Buy.Text = "NÍVEL MÁXIMO"
		setButtonState(toolCard.Buy, false, Color3.fromRGB(87, 157, 255))
	end

	local speedValue = player:GetAttribute("SpeedLevel")
	local speedLevel = if typeof(speedValue) == "number" then math.clamp(speedValue, 1, SpeedUpgradeConfig.GetMaxLevel()) else 1
	local currentSpeed = SpeedUpgradeConfig.Get(speedLevel)
	local nextSpeed = SpeedUpgradeConfig.Get(speedLevel + 1)
	speedCard.Level.Text = string.format("NÍVEL %d / %d", speedLevel, SpeedUpgradeConfig.GetMaxLevel())
	speedCard.Current.Text = string.format("Atual: %s  •  %d studs/s", currentSpeed and currentSpeed.Name or "Passo Padrão", currentSpeed and currentSpeed.Speed or 16)
	if nextSpeed and nextSpeed.PurchaseCost then
		speedCard.Next.Text = string.format("Próxima: %s\nAumenta sua velocidade para %d studs/s", nextSpeed.Name, nextSpeed.Speed)
		speedCard.Buy.Text = "COMPRAR  " .. formatMoney(nextSpeed.PurchaseCost)
		setButtonState(speedCard.Buy, not purchasing, Color3.fromRGB(54, 218, 180))
	else
		speedCard.Next.Text = "Todas as melhorias de mobilidade foram adquiridas."
		speedCard.Buy.Text = "NÍVEL MÁXIMO"
		setButtonState(speedCard.Buy, false, Color3.fromRGB(54, 218, 180))
	end
end

local function showToast(message: string, success: boolean)
	toastSerial += 1
	local serial = toastSerial
	toast.Visible = true
	toast.Text = message
	toast.TextColor3 = if success then Color3.fromRGB(105, 245, 150) else Color3.fromRGB(255, 125, 110)
	toast.BackgroundTransparency = 0.08
	toast.TextTransparency = 0
	task.delay(2.2, function()
		if serial ~= toastSerial then return end
		local tween = TweenService:Create(toast, TweenInfo.new(0.25), { BackgroundTransparency = 1, TextTransparency = 1 })
		tween:Play()
		tween.Completed:Wait()
		if serial == toastSerial then toast.Visible = false end
	end)
end

local function purchase(category: string)
	if purchasing then return end
	if not purchaseRemote or not purchaseRemote:IsA("RemoteFunction") then
		showToast("Servidor de melhorias indisponível.", false)
		return
	end
	purchasing = true
	refresh()
	local callOk, response = pcall(function()
		return purchaseRemote:InvokeServer(category)
	end)
	purchasing = false
	refresh()
	if not callOk or typeof(response) ~= "table" then
		showToast("Não foi possível falar com o servidor.", false)
		return
	end
	showToast(tostring(response.Message or "Resposta inválida do servidor."), response.Success == true)
end

local function openMenu()
	refresh()
	backdrop.Visible = true
	window.Size = UDim2.fromScale(0.76, 0.72)
	TweenService:Create(window, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.fromScale(0.82, 0.78),
	}):Play()
end

local function closeMenu()
	backdrop.Visible = false
end

openButton.MouseEnter:Connect(function()
	TweenService:Create(openButton, TweenInfo.new(0.12), { BackgroundColor3 = Color3.fromRGB(43, 48, 54) }):Play()
end)
openButton.MouseLeave:Connect(function()
	TweenService:Create(openButton, TweenInfo.new(0.12), { BackgroundColor3 = Color3.fromRGB(31, 35, 39) }):Play()
end)
openButton.MouseButton1Click:Connect(openMenu)
closeButton.MouseButton1Click:Connect(closeMenu)
toolCard.Buy.MouseButton1Click:Connect(function() purchase("Tool") end)
speedCard.Buy.MouseButton1Click:Connect(function() purchase("Speed") end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not backdrop.Visible then return end
	if input.KeyCode == Enum.KeyCode.Escape then
		closeMenu()
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		local point = input.Position
		local position = window.AbsolutePosition
		local size = window.AbsoluteSize
		if point.X < position.X or point.X > position.X + size.X or point.Y < position.Y or point.Y > position.Y + size.Y then
			closeMenu()
		end
	end
end)

player:GetAttributeChangedSignal("ToolLevel"):Connect(refresh)
player:GetAttributeChangedSignal("SpeedLevel"):Connect(refresh)

task.spawn(function()
	local leaderstats = player:WaitForChild("leaderstats", 10)
	local money = leaderstats and leaderstats:WaitForChild("Dinheiro", 10)
	if money and money:IsA("IntValue") then
		money:GetPropertyChangedSignal("Value"):Connect(refresh)
	end
	refresh()
end)
