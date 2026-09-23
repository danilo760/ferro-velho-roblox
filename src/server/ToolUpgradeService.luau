--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local EconomyService = require(ServerScriptService.Server.EconomyService)
local PlotService = require(ServerScriptService.Server.PlotService)
local ToolUpgradeConfig = require(ReplicatedStorage.Shared.ToolUpgradeConfig)

local ToolUpgradeService = {}
local TARGET_LEVEL = 2
local buttonsByPlayer: {[Player]: Part} = {}
local playerConnections: {[Player]: {RBXScriptConnection}} = {}

local function removeButton(player: Player)
	local button = buttonsByPlayer[player]
	if button and button.Parent then button:Destroy() end
	buttonsByPlayer[player] = nil
end

local function createButton(player: Player, plot: Model)
	removeButton(player)
	if player:GetAttribute("DataLoaded") ~= true then return end
	local currentLevel = player:GetAttribute("ToolLevel")
	if typeof(currentLevel) == "number" and currentLevel >= TARGET_LEVEL then return end

	local definition = ToolUpgradeConfig.Get(TARGET_LEVEL)
	assert(definition and definition.PurchaseCost, "Tool level 2 configuration is missing")
	local origin = plot:FindFirstChild("Origin")
	assert(origin and origin:IsA("BasePart"), "Plot origin is missing")

	local button = Instance.new("Part")
	button.Name = "ToolUpgradeButton_" .. player.UserId
	button:SetAttribute("OwnerUserId", player.UserId)
	button:SetAttribute("UpgradeId", "ToolLevel2")
	button.Size = Vector3.new(7, 1, 7)
	button.CFrame = origin.CFrame * CFrame.new(14, 0, 14)
	button.Anchored = true
	button.CanCollide = true
	button.Material = Enum.Material.DiamondPlate
	button.Color = Color3.fromRGB(65, 150, 255)
	button.Parent = plot

	local signBoard = Instance.new("Part")
	signBoard.Name = "UpgradeSign"
	signBoard.Size = Vector3.new(8, 4, 0.5)
	signBoard.CFrame = button.CFrame * CFrame.new(0, 3.2, -3.2)
	signBoard.Anchored = true
	signBoard.CanCollide = false
	signBoard.Material = Enum.Material.DiamondPlate
	signBoard.Color = Color3.fromRGB(30, 35, 42)
	signBoard.Parent = button

	for _, x in { -3.4, 3.4 } do
		local post = Instance.new("Part")
		post.Name = "SignPost"
		post.Size = Vector3.new(0.35, 2.7, 0.35)
		post.CFrame = button.CFrame * CFrame.new(x, 1.35, -3.2)
		post.Anchored = true
		post.CanCollide = false
		post.Material = Enum.Material.Metal
		post.Color = Color3.fromRGB(38, 42, 46)
		post.Parent = button
	end

	local gui = Instance.new("SurfaceGui")
	gui.Name = "UpgradeGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.Parent = signBoard

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = definition.Name .. "\nR$ " .. tostring(definition.PurchaseCost) .. "\n1,5s > 1,2s"
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.2
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = gui

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BuyToolUpgrade"
	prompt.ActionText = "Comprar"
	prompt.ObjectText = definition.Name .. " - R$ " .. tostring(definition.PurchaseCost)
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = button

	local buying = false
	prompt.Triggered:Connect(function(triggeringPlayer)
		if buying or triggeringPlayer ~= player then return end
		if plot:GetAttribute("OwnerUserId") ~= player.UserId then return end
		local level = player:GetAttribute("ToolLevel")
		if typeof(level) ~= "number" or level ~= TARGET_LEVEL - 1 then return end
		buying = true
		if EconomyService.TrySpend(player, definition.PurchaseCost :: number) then
			player:SetAttribute("ToolLevel", TARGET_LEVEL)
			removeButton(player)
			return
		end
		prompt.ObjectText = "Dinheiro insuficiente"
		task.delay(1.5, function()
			if prompt.Parent then
				prompt.ObjectText = definition.Name .. " - R$ " .. tostring(definition.PurchaseCost)
				buying = false
			end
		end)
	end)

	buttonsByPlayer[player] = button
end

local function syncButton(player: Player)
	local plot = PlotService.GetPlot(player)
	if plot then
		createButton(player, plot)
	else
		removeButton(player)
	end
end

local function initializePlayer(player: Player)
	if player:GetAttribute("ToolLevel") == nil then
		player:SetAttribute("ToolLevel", 1)
	end
	if playerConnections[player] then return end
	playerConnections[player] = {
		player:GetAttributeChangedSignal("DataLoaded"):Connect(function()
			syncButton(player)
		end),
		player:GetAttributeChangedSignal("ToolLevel"):Connect(function()
			syncButton(player)
		end),
	}
end

local function cleanupPlayer(player: Player)
	removeButton(player)
	local connections = playerConnections[player]
	if connections then
		for _, connection in connections do connection:Disconnect() end
	end
	playerConnections[player] = nil
end

function ToolUpgradeService.start()
	Players.PlayerAdded:Connect(initializePlayer)
	Players.PlayerRemoving:Connect(cleanupPlayer)
	for _, player in Players:GetPlayers() do initializePlayer(player) end

	PlotService.PlotAssigned:Connect(createButton)
	PlotService.PlotReleased:Connect(function(player)
		removeButton(player)
	end)

	for _, player in Players:GetPlayers() do
		local plot = PlotService.GetPlot(player)
		if plot then createButton(player, plot) end
	end
end

return ToolUpgradeService
