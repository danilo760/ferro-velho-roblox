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

local function corner(parent: Instance, radius: number)
	local value = Instance.new("UICorner")
	value.CornerRadius = UDim.new(0, radius)
	value.Parent = parent
end

local function stroke(parent: Instance, color: Color3, thickness: number, transparency: number?)
	local value = Instance.new("UIStroke")
	value.Color = color
	value.Thickness = thickness
	value.Transparency = transparency or 0
	value.Parent = parent
	return value
end

local function formatMoney(value: number): string
	local reversed = string.reverse(tostring(math.max(0, math.floor(value))))
	local grouped = string.gsub(reversed, "(%d%d%d)", "%1.")
	local formatted = string.reverse(grouped)
	if string.sub(formatted, 1, 1) == "." then formatted = string.sub(formatted, 2) end
	return "R$ " .. formatted
end

local gui = Instance.new("ScreenGui")
gui.Name = "UpgradesGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 20
gui.Parent = playerGui

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
openButton.Parent = gui
corner(openButton, 10)
stroke(openButton, Color3.fromRGB(246, 196, 55), 2)

local openAccent = Instance.new("Frame")
openAccent.Size = UDim2.new(0, 7, 1, 0)
openAccent.BackgroundColor3 = Color3.fromRGB(246, 196, 55)
openAccent.BorderSizePixel = 0
openAccent.Parent = openButton
corner(openAccent, 10)

local backdrop = Instance.new("Frame")
backdrop.Name = "Backdrop"
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
backdrop.BackgroundTransparency = 0.4
backdrop.BorderSizePixel = 0
backdrop.Active = true
backdrop.Visible = false
backdrop.Parent = gui

local window = Instance.new("Frame")
window.Name = "UpgradeTree"
window.AnchorPoint = Vector2.new(0.5, 0.5)
window.Position = UDim2.fromScale(0.5, 0.5)
window.Size = UDim2.fromScale(0.88, 0.84)
window.BackgroundColor3 = Color3.fromRGB(20, 23, 27)
window.BorderSizePixel = 0
window.Parent = backdrop
corner(window, 14)
stroke(window, Color3.fromRGB(210, 158, 37), 2)

local sizeConstraint = Instance.new("UISizeConstraint")
sizeConstraint.MinSize = Vector2.new(300, 430)
sizeConstraint.MaxSize = Vector2.new(760, 650)
sizeConstraint.Parent = window

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 82)
header.BackgroundColor3 = Color3.fromRGB(30, 34, 39)
header.BorderSizePixel = 0
header.Parent = window
corner(header, 14)

local title = Instance.new("TextLabel")
title.Position = UDim2.fromOffset(18, 8)
title.Size = UDim2.new(1, -72, 0, 32)
title.BackgroundTransparency = 1
title.Text = "ÁRVORE DE MELHORIAS"
title.TextColor3 = Color3.fromRGB(246, 196, 55)
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextScaled = true
title.Font = Enum.Font.GothamBlack
title.Parent = header

local titleLimit = Instance.new("UITextSizeConstraint")
titleLimit.MinTextSize = 15
titleLimit.MaxTextSize = 23
titleLimit.Parent = title

local subtitle = Instance.new("TextLabel")
subtitle.Position = UDim2.fromOffset(18, 43)
subtitle.Size = UDim2.new(1, -210, 0, 28)
subtitle.BackgroundTransparency = 1
subtitle.Text = "Compre o próximo nó para avançar"
subtitle.TextColor3 = Color3.fromRGB(164, 172, 182)
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.TextSize = 13
subtitle.TextWrapped = true
subtitle.Font = Enum.Font.GothamMedium
subtitle.Parent = header

local moneyLabel = Instance.new("TextLabel")
moneyLabel.AnchorPoint = Vector2.new(1, 1)
moneyLabel.Position = UDim2.new(1, -58, 1, -10)
moneyLabel.Size = UDim2.fromOffset(150, 30)
moneyLabel.BackgroundColor3 = Color3.fromRGB(40, 49, 43)
moneyLabel.BorderSizePixel = 0
moneyLabel.Text = "R$ 0"
moneyLabel.TextColor3 = Color3.fromRGB(100, 235, 140)
moneyLabel.TextSize = 14
moneyLabel.Font = Enum.Font.GothamBlack
moneyLabel.Parent = header
corner(moneyLabel, 15)

local closeButton = Instance.new("TextButton")
closeButton.AnchorPoint = Vector2.new(1, 0)
closeButton.Position = UDim2.new(1, -12, 0, 12)
closeButton.Size = UDim2.fromOffset(36, 36)
closeButton.BackgroundColor3 = Color3.fromRGB(164, 53, 46)
closeButton.BorderSizePixel = 0
closeButton.Text = "X"
closeButton.TextColor3 = Color3.new(1, 1, 1)
closeButton.TextSize = 17
closeButton.Font = Enum.Font.GothamBlack
closeButton.Parent = header
corner(closeButton, 18)

local scroll = Instance.new("ScrollingFrame")
scroll.Name = "TreeScroll"
scroll.Position = UDim2.fromOffset(12, 94)
scroll.Size = UDim2.new(1, -24, 1, -108)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.CanvasSize = UDim2.fromOffset(0, 568)
scroll.ScrollBarThickness = 5
scroll.ScrollBarImageColor3 = Color3.fromRGB(210, 158, 37)
scroll.Parent = window

local rootNode = Instance.new("Frame")
rootNode.Name = "RootNode"
rootNode.AnchorPoint = Vector2.new(0.5, 0)
rootNode.Position = UDim2.new(0.5, 0, 0, 2)
rootNode.Size = UDim2.fromOffset(210, 54)
rootNode.BackgroundColor3 = Color3.fromRGB(91, 69, 27)
rootNode.BorderSizePixel = 0
rootNode.Parent = scroll
corner(rootNode, 10)
stroke(rootNode, Color3.fromRGB(246, 196, 55), 2)

local rootText = Instance.new("TextLabel")
rootText.Size = UDim2.fromScale(1, 1)
rootText.BackgroundTransparency = 1
rootText.Text = "SEU FERRO-VELHO"
rootText.TextColor3 = Color3.fromRGB(255, 225, 125)
rootText.TextSize = 16
rootText.Font = Enum.Font.GothamBlack
rootText.Parent = rootNode

local trunk = Instance.new("Frame")
trunk.Position = UDim2.new(0.5, -2, 0, 56)
trunk.Size = UDim2.fromOffset(4, 25)
trunk.BackgroundColor3 = Color3.fromRGB(135, 113, 62)
trunk.BorderSizePixel = 0
trunk.Parent = scroll

local split = Instance.new("Frame")
split.Position = UDim2.new(0.25, 0, 0, 79)
split.Size = UDim2.new(0.5, 0, 0, 4)
split.BackgroundColor3 = Color3.fromRGB(135, 113, 62)
split.BorderSizePixel = 0
split.Parent = scroll

for _, scaleX in { 0.25, 0.75 } do
	local branchLine = Instance.new("Frame")
	branchLine.Position = UDim2.new(scaleX, -2, 0, 80)
	branchLine.Size = UDim2.fromOffset(4, 22)
	branchLine.BackgroundColor3 = Color3.fromRGB(135, 113, 62)
	branchLine.BorderSizePixel = 0
	branchLine.Parent = scroll
end

type NodeReference = {
	Button: TextButton,
	State: TextLabel,
	Outline: UIStroke,
	Connector: Frame?,
	Level: number,
	Category: string,
	Accent: Color3,
}

local allNodes: {NodeReference} = {}
local purchasing = false
local toastSerial = 0

local function createBranch(name: string, category: string, accent: Color3, xScale: number, definitions: {any})
	local branch = Instance.new("Frame")
	branch.Name = name .. "Branch"
	branch.Position = UDim2.new(xScale, 6, 0, 101)
	branch.Size = UDim2.new(0.5, -12, 0, 455)
	branch.BackgroundTransparency = 1
	branch.Parent = scroll

	local branchTitle = Instance.new("TextLabel")
	branchTitle.Size = UDim2.new(1, 0, 0, 34)
	branchTitle.BackgroundColor3 = Color3.fromRGB(31, 36, 42)
	branchTitle.BorderSizePixel = 0
	branchTitle.Text = name
	branchTitle.TextColor3 = accent
	branchTitle.TextSize = 15
	branchTitle.Font = Enum.Font.GothamBlack
	branchTitle.Parent = branch
	corner(branchTitle, 8)
	stroke(branchTitle, accent, 1, 0.3)

	local y = 44
	for index, definition in definitions do
		local connector: Frame? = nil
		if index > 1 then
			connector = Instance.new("Frame")
			connector.Name = "Connector_" .. index
			connector.Position = UDim2.new(0.5, -2, 0, y - 12)
			connector.Size = UDim2.fromOffset(4, 12)
			connector.BackgroundColor3 = Color3.fromRGB(78, 84, 92)
			connector.BorderSizePixel = 0
			connector.Parent = branch
		end

		local node = Instance.new("TextButton")
		node.Name = category .. "Level" .. definition.Level
		node.Position = UDim2.new(0, 5, 0, y)
		node.Size = UDim2.new(1, -10, 0, 68)
		node.BackgroundColor3 = Color3.fromRGB(42, 47, 54)
		node.BorderSizePixel = 0
		node.Text = ""
		node.AutoButtonColor = false
		node.Parent = branch
		corner(node, 9)
		local outline = stroke(node, Color3.fromRGB(78, 84, 92), 1)

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Position = UDim2.fromOffset(8, 5)
		nameLabel.Size = UDim2.new(1, -16, 0, 34)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = string.format("NÍVEL %d  •  %s", definition.Level, definition.Name)
		nameLabel.TextColor3 = Color3.fromRGB(230, 234, 240)
		nameLabel.TextSize = 12
		nameLabel.TextWrapped = true
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.Parent = node

		local effect = if category == "Tool"
			then string.format("%.1fs por peça", definition.RemovalSeconds)
			else string.format("%d studs/s", definition.Speed)
		local effectLabel = Instance.new("TextLabel")
		effectLabel.Position = UDim2.fromOffset(8, 38)
		effectLabel.Size = UDim2.new(1, -16, 0, 23)
		effectLabel.BackgroundTransparency = 1
		effectLabel.Text = effect
		effectLabel.TextColor3 = Color3.fromRGB(164, 174, 186)
		effectLabel.TextSize = 11
		effectLabel.Font = Enum.Font.GothamMedium
		effectLabel.Parent = node

		local state = Instance.new("TextLabel")
		state.AnchorPoint = Vector2.new(1, 1)
		state.Position = UDim2.new(1, -5, 1, -5)
		state.Size = UDim2.fromOffset(92, 20)
		state.BackgroundColor3 = Color3.fromRGB(65, 70, 78)
		state.BorderSizePixel = 0
		state.Text = "BLOQUEADO"
		state.TextColor3 = Color3.fromRGB(190, 195, 202)
		state.TextSize = 9
		state.Font = Enum.Font.GothamBlack
		state.Parent = node
		corner(state, 10)

		local reference: NodeReference = {
			Button = node,
			State = state,
			Outline = outline,
			Connector = connector,
			Level = definition.Level,
			Category = category,
			Accent = accent,
		}
		table.insert(allNodes, reference)
		y += 80
	end
end

local toolDefinitions = {}
local toolIndex = 1
while ToolUpgradeConfig.Get(toolIndex) do
	table.insert(toolDefinitions, ToolUpgradeConfig.Get(toolIndex))
	toolIndex += 1
end

local speedDefinitions = {}
for level = 1, SpeedUpgradeConfig.GetMaxLevel() do
	table.insert(speedDefinitions, SpeedUpgradeConfig.Get(level))
end

createBranch("FERRAMENTAS", "Tool", Color3.fromRGB(87, 157, 255), 0, toolDefinitions)
createBranch("MOBILIDADE", "Speed", Color3.fromRGB(54, 218, 180), 0.5, speedDefinitions)

local toast = Instance.new("TextLabel")
toast.AnchorPoint = Vector2.new(0.5, 1)
toast.Position = UDim2.new(0.5, 0, 1, -14)
toast.Size = UDim2.new(0.82, 0, 0, 44)
toast.BackgroundColor3 = Color3.fromRGB(35, 42, 48)
toast.BackgroundTransparency = 1
toast.BorderSizePixel = 0
toast.TextTransparency = 1
toast.TextColor3 = Color3.new(1, 1, 1)
toast.TextSize = 14
toast.TextWrapped = true
toast.Font = Enum.Font.GothamBold
toast.Visible = false
toast.ZIndex = 20
toast.Parent = window
corner(toast, 10)

local function getMoney(): number
	local leaderstats = player:FindFirstChild("leaderstats")
	local money = leaderstats and leaderstats:FindFirstChild("Dinheiro")
	return if money and money:IsA("IntValue") then money.Value else 0
end

local function currentLevel(category: string): number
	local attributeName = if category == "Tool" then "ToolLevel" else "SpeedLevel"
	local value = player:GetAttribute(attributeName)
	local maximum = if category == "Tool" then #toolDefinitions else #speedDefinitions
	return if typeof(value) == "number" then math.clamp(value, 1, maximum) else 1
end

local function refreshTree()
	moneyLabel.Text = formatMoney(getMoney())
	for _, node in allNodes do
		local activeLevel = currentLevel(node.Category)
		local definitions = if node.Category == "Tool" then toolDefinitions else speedDefinitions
		local definition = definitions[node.Level]
		local isCurrent = node.Level == activeLevel
		local isCompleted = node.Level < activeLevel
		local isNext = node.Level == activeLevel + 1
		if node.Connector then
			node.Connector.BackgroundColor3 = if node.Level <= activeLevel
				then Color3.fromRGB(75, 210, 145)
				elseif isNext then node.Accent
				else Color3.fromRGB(78, 84, 92)
		end

		node.Button.Active = isNext and not purchasing
		if isCurrent then
			node.Button.BackgroundColor3 = Color3.fromRGB(76, 63, 31)
			node.Outline.Color = Color3.fromRGB(246, 196, 55)
			node.Outline.Thickness = 2
			node.State.BackgroundColor3 = Color3.fromRGB(190, 142, 30)
			node.State.TextColor3 = Color3.fromRGB(30, 26, 18)
			node.State.Text = "ATUAL"
		elseif isCompleted then
			node.Button.BackgroundColor3 = Color3.fromRGB(35, 72, 61)
			node.Outline.Color = Color3.fromRGB(75, 210, 145)
			node.Outline.Thickness = 1
			node.State.BackgroundColor3 = Color3.fromRGB(55, 170, 112)
			node.State.TextColor3 = Color3.fromRGB(20, 35, 28)
			node.State.Text = "CONCLUÍDO"
		elseif isNext then
			node.Button.BackgroundColor3 = Color3.fromRGB(40, 53, 64)
			node.Outline.Color = node.Accent
			node.Outline.Thickness = 2
			node.State.BackgroundColor3 = if purchasing then Color3.fromRGB(85, 90, 96) else node.Accent
			node.State.TextColor3 = Color3.fromRGB(20, 24, 28)
			node.State.Text = if purchasing then "AGUARDE" else formatMoney(definition.PurchaseCost or 0)
		else
			node.Button.BackgroundColor3 = Color3.fromRGB(37, 40, 45)
			node.Outline.Color = Color3.fromRGB(68, 73, 80)
			node.Outline.Thickness = 1
			node.State.BackgroundColor3 = Color3.fromRGB(60, 64, 70)
			node.State.TextColor3 = Color3.fromRGB(145, 150, 158)
			node.State.Text = "BLOQUEADO"
		end
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
	refreshTree()
	local callOk, response = pcall(function()
		return purchaseRemote:InvokeServer(category)
	end)
	purchasing = false
	refreshTree()
	if not callOk or typeof(response) ~= "table" then
		showToast("Não foi possível falar com o servidor.", false)
		return
	end
	showToast(tostring(response.Message or "Resposta inválida do servidor."), response.Success == true)
end

for _, node in allNodes do
	node.Button.MouseButton1Click:Connect(function()
		if node.Level == currentLevel(node.Category) + 1 then
			purchase(node.Category)
		end
	end)
end

local function openMenu()
	refreshTree()
	backdrop.Visible = true
	window.Size = UDim2.fromScale(0.82, 0.78)
	TweenService:Create(window, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.fromScale(0.88, 0.84),
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

player:GetAttributeChangedSignal("ToolLevel"):Connect(refreshTree)
player:GetAttributeChangedSignal("SpeedLevel"):Connect(refreshTree)

task.spawn(function()
	local leaderstats = player:WaitForChild("leaderstats", 10)
	local money = leaderstats and leaderstats:WaitForChild("Dinheiro", 10)
	if money and money:IsA("IntValue") then
		money:GetPropertyChangedSignal("Value"):Connect(refreshTree)
	end
	refreshTree()
end)
