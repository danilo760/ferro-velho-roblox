--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local EconomyService = require(ServerScriptService.Server.EconomyService)
local PlotService = require(ServerScriptService.Server.PlotService)
local SpeedUpgradeConfig = require(ReplicatedStorage.Shared.SpeedUpgradeConfig)

local SpeedUpgradeService = {}
local buttonsByPlayer: {[Player]: Part} = {}
local playerConnections: {[Player]: {RBXScriptConnection}} = {}

local function applySpeedToCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 5)
	if humanoid and humanoid:IsA("Humanoid") then
		local currentLevel = player:GetAttribute("SpeedLevel")
		local levelNumber = if typeof(currentLevel) == "number" then currentLevel else 1
		local definition = SpeedUpgradeConfig.Get(levelNumber)
		if definition then
			humanoid.WalkSpeed = definition.Speed
		end
	end
end

local function removeButton(player: Player)
	local button = buttonsByPlayer[player]
	if button and button.Parent then button:Destroy() end
	buttonsByPlayer[player] = nil
end

local function createButton(player: Player, plot: Model)
	removeButton(player)
	if player:GetAttribute("DataLoaded") ~= true then return end
	local currentLevel = player:GetAttribute("SpeedLevel")
	local levelNumber = if typeof(currentLevel) == "number" then currentLevel else 1
	local maxLevel = SpeedUpgradeConfig.GetMaxLevel()

	if levelNumber >= maxLevel then return end

	local nextLevel = levelNumber + 1
	local nextDefinition = SpeedUpgradeConfig.Get(nextLevel)
	local currentDefinition = SpeedUpgradeConfig.Get(levelNumber)
	if not nextDefinition or not nextDefinition.PurchaseCost or not currentDefinition then return end

	local origin = plot:FindFirstChild("Origin")
	assert(origin and origin:IsA("BasePart"), "Plot origin is missing")

	local button = Instance.new("Part")
	button.Name = "SpeedUpgradeButton_" .. player.UserId
	button:SetAttribute("OwnerUserId", player.UserId)
	button:SetAttribute("UpgradeId", "SpeedLevel_" .. nextLevel)
	button.Size = Vector3.new(7, 1, 7)
	button.CFrame = origin.CFrame * CFrame.new(-14, 0, 14)
	button.Anchored = true
	button.CanCollide = true
	button.Material = Enum.Material.DiamondPlate
	button.Color = Color3.fromRGB(0, 205, 255)
	button.Parent = plot

	local signBoard = Instance.new("Part")
	signBoard.Name = "UpgradeSign"
	signBoard.Size = Vector3.new(8, 4.2, 0.5)
	signBoard.CFrame = button.CFrame * CFrame.new(0, 3.3, -3.2)
	signBoard.Anchored = true
	signBoard.CanCollide = false
	signBoard.Material = Enum.Material.DiamondPlate
	signBoard.Color = Color3.fromRGB(27, 39, 45)
	signBoard.Parent = button

	for _, x in { -3.4, 3.4 } do
		local post = Instance.new("Part")
		post.Name = "SignPost"
		post.Size = Vector3.new(0.35, 2.8, 0.35)
		post.CFrame = button.CFrame * CFrame.new(x, 1.4, -3.2)
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
	label.Text = string.format("VELOCIDADE NÍVEL %d\n%s (R$ %d)\n%d > %d studs/s",
		nextLevel, nextDefinition.Name, nextDefinition.PurchaseCost, currentDefinition.Speed, nextDefinition.Speed)
	label.TextColor3 = Color3.fromRGB(240, 255, 255)
	label.TextStrokeColor3 = Color3.fromRGB(0, 60, 100)
	label.TextStrokeTransparency = 0.2
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = gui

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BuySpeedUpgrade"
	prompt.ActionText = "Comprar"
	prompt.ObjectText = string.format("Velocidade Nv.%d - R$ %d", nextLevel, nextDefinition.PurchaseCost)
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = button

	local buying = false
	local function handleBuy(triggeringPlayer: Player): boolean
		if buying or triggeringPlayer ~= player then return false end
		if plot:GetAttribute("OwnerUserId") ~= player.UserId then return false end
		local activeLevel = player:GetAttribute("SpeedLevel")
		local lvl = if typeof(activeLevel) == "number" then activeLevel else 1
		if lvl ~= nextLevel - 1 then return false end
		buying = true
		if EconomyService.TrySpend(player, nextDefinition.PurchaseCost :: number) then
			player:SetAttribute("SpeedLevel", nextLevel)
			if player.Character then
				applySpeedToCharacter(player, player.Character)
			end
			removeButton(player)
			createButton(player, plot)
			buying = false
			return true
		end
		prompt.ObjectText = "Dinheiro insuficiente"
		task.delay(1.5, function()
			if prompt.Parent then
				prompt.ObjectText = string.format("Velocidade Nv.%d - R$ %d", nextLevel, nextDefinition.PurchaseCost)
				buying = false
			end
		end)
		return false
	end

	prompt.Triggered:Connect(function(triggeringPlayer)
		handleBuy(triggeringPlayer)
	end)

	local testTrigger = Instance.new("BindableFunction")
	testTrigger.Name = "TestTrigger"
	testTrigger.OnInvoke = function(p: Player)
		return handleBuy(p)
	end
	testTrigger.Parent = prompt

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
	if player:GetAttribute("SpeedLevel") == nil then
		player:SetAttribute("SpeedLevel", 1)
	end

	player.CharacterAdded:Connect(function(character)
		task.defer(applySpeedToCharacter, player, character)
	end)
	if player.Character then
		task.defer(applySpeedToCharacter, player, player.Character)
	end

	if playerConnections[player] then return end
	playerConnections[player] = {
		player:GetAttributeChangedSignal("DataLoaded"):Connect(function()
			syncButton(player)
		end),
		player:GetAttributeChangedSignal("SpeedLevel"):Connect(function()
			syncButton(player)
			if player.Character then
				applySpeedToCharacter(player, player.Character)
			end
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

function SpeedUpgradeService.start()
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

return SpeedUpgradeService
