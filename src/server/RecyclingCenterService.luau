--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local PlotService = require(ServerScriptService.Server.PlotService)

local RecyclingCenterService = {}

export type DockData = {
	Index: number,
	Model: Model,
	Direction: Vector3,
	CFrame: CFrame,
	PartsDropZone: Part,
	EngineBayZone: Part,
	OwnerUserId: number,
	SignLabel: TextLabel,
	StatusLabel: TextLabel,
}

local docks: {[number]: DockData} = {}
local centralModel: Model? = nil
local leaderboardLabels: {TextLabel} = {}
local podiumLabels: {[number]: TextLabel} = {}

local DOCK_OFFSETS = {
	[1] = Vector3.new(-22, 0.5, -22), -- Voltado para o Lote 1 (-55, -55)
	[2] = Vector3.new(22, 0.5, -22),  -- Voltado para o Lote 2 (55, -55)
	[3] = Vector3.new(-22, 0.5, 22),  -- Voltado para o Lote 3 (-55, 55)
	[4] = Vector3.new(22, 0.5, 22),   -- Voltado para o Lote 4 (55, 55)
}

local DOCK_TARGETS = {
	[1] = Vector3.new(-55, 0.5, -55),
	[2] = Vector3.new(55, 0.5, -55),
	[3] = Vector3.new(-55, 0.5, 55),
	[4] = Vector3.new(55, 0.5, 55),
}

local function createPart(parent: Instance, name: string, size: Vector3, cf: CFrame, material: Enum.Material, color: Color3, anchored: boolean, canCollide: boolean): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cf
	part.Material = material
	part.Color = color
	part.Anchored = anchored
	part.CanCollide = canCollide
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function buildCentralHub(parent: Model)
	local mainFloor = createPart(parent, "CenterFloor", Vector3.new(38, 1, 38), CFrame.new(0, 0.5, 0), Enum.Material.Concrete, Color3.fromRGB(60, 64, 68), true, true)

	local floorBorder = Instance.new("SelectionBox")
	floorBorder.Name = "CenterBorder"
	floorBorder.Adornee = mainFloor
	floorBorder.Color3 = Color3.fromRGB(240, 180, 40)
	floorBorder.LineThickness = 0.12
	floorBorder.SurfaceTransparency = 1
	floorBorder.Parent = mainFloor

	local pillarPositions = {
		Vector3.new(-8, 9, -8),
		Vector3.new(8, 9, -8),
		Vector3.new(-8, 9, 8),
		Vector3.new(8, 9, 8),
	}
	for i, pos in pillarPositions do
		createPart(parent, "Pillar" .. i, Vector3.new(1.8, 16, 1.8), CFrame.new(pos), Enum.Material.DiamondPlate, Color3.fromRGB(90, 95, 100), true, true)
	end

	createPart(parent, "IndustrialRoof", Vector3.new(22, 1.2, 22), CFrame.new(0, 17.5, 0), Enum.Material.Metal, Color3.fromRGB(45, 50, 55), true, true)
	createPart(parent, "RoofCap", Vector3.new(16, 1.5, 16), CFrame.new(0, 18.8, 0), Enum.Material.Metal, Color3.fromRGB(180, 50, 45), true, true)

	local signBoard = createPart(parent, "MainSignTower", Vector3.new(14, 3.5, 14), CFrame.new(0, 14.5, 0), Enum.Material.SmoothPlastic, Color3.fromRGB(25, 28, 32), true, true)
	for _, face in {Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right} do
		local gui = Instance.new("SurfaceGui")
		gui.Name = "SignGui_" .. face.Name
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 50
		gui.Parent = signBoard

		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = "CENTRAL DE RECICLAGEM"
		label.TextColor3 = Color3.fromRGB(80, 255, 130)
		label.TextStrokeColor3 = Color3.fromRGB(15, 60, 25)
		label.TextStrokeTransparency = 0.1
		label.TextScaled = true
		label.Font = Enum.Font.GothamBlack
		label.Parent = gui
	end

	local lightFixture = createPart(parent, "CenterLightFixture", Vector3.new(3, 0.5, 3), CFrame.new(0, 16.5, 0), Enum.Material.Neon, Color3.fromRGB(255, 240, 200), true, false)
	local pointLight = Instance.new("PointLight")
	pointLight.Color = Color3.fromRGB(255, 235, 190)
	pointLight.Brightness = 2.5
	pointLight.Range = 45
	pointLight.Shadows = true
	pointLight.Parent = lightFixture

	----------------------------------------------------------------------
	-- PLACAR DO SERVIDOR (LEADERBOARD)
	----------------------------------------------------------------------
	local boardPart = createPart(parent, "LeaderboardBoard", Vector3.new(12, 7, 0.8), CFrame.new(0, 5.5, -9), Enum.Material.Metal, Color3.fromRGB(30, 32, 36), true, true)
	local boardGui = Instance.new("SurfaceGui")
	boardGui.Name = "BoardGui"
	boardGui.Face = Enum.NormalId.Back
	boardGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	boardGui.PixelsPerStud = 50
	boardGui.Parent = boardPart

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0.22, 0)
	title.Position = UDim2.new(0, 0, 0, 0)
	title.BackgroundColor3 = Color3.fromRGB(45, 130, 75)
	title.Text = "🏆 PLACAR DO FERRO-VELHO 🏆"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextScaled = true
	title.Font = Enum.Font.GothamBlack
	title.Parent = boardGui

	local listFrame = Instance.new("Frame")
	listFrame.Size = UDim2.new(1, -20, 0.74, 0)
	listFrame.Position = UDim2.new(0, 10, 0.24, 0)
	listFrame.BackgroundTransparency = 1
	listFrame.Parent = boardGui

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.Parent = listFrame

	for rank = 1, 4 do
		local row = Instance.new("TextLabel")
		row.Name = "Rank" .. rank
		row.Size = UDim2.new(1, 0, 0.22, 0)
		row.BackgroundColor3 = if rank % 2 == 0 then Color3.fromRGB(40, 44, 50) else Color3.fromRGB(50, 55, 62)
		row.Text = string.format("%d. Vazio - R$ 0  |  0 Carros", rank)
		row.TextColor3 = Color3.fromRGB(230, 235, 240)
		row.TextScaled = true
		row.Font = Enum.Font.GothamMedium
		row.Parent = listFrame
		table.insert(leaderboardLabels, row)
	end

	----------------------------------------------------------------------
	-- HALL DA FAMA (PÓDIO TRIPLO)
	----------------------------------------------------------------------
	local podiumBaseCf = CFrame.new(0, 0.5, 7)
	local podiumConfigs = {
		{ Rank = 1, Height = 2.4, Color = Color3.fromRGB(235, 185, 45), Offset = Vector3.new(0, 0, 0), Name = "1º LUGAR" },
		{ Rank = 2, Height = 1.6, Color = Color3.fromRGB(195, 205, 215), Offset = Vector3.new(-3.2, 0, 0), Name = "2º LUGAR" },
		{ Rank = 3, Height = 1.0, Color = Color3.fromRGB(180, 115, 60), Offset = Vector3.new(3.2, 0, 0), Name = "3º LUGAR" },
	}

	for _, cfg in podiumConfigs do
		local stepPart = createPart(
			parent,
			"Podium_" .. cfg.Rank,
			Vector3.new(2.8, cfg.Height, 2.8),
			podiumBaseCf * CFrame.new(cfg.Offset.X, cfg.Height / 2, cfg.Offset.Z),
			Enum.Material.Metal,
			cfg.Color,
			true,
			true
		)

		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 50
		gui.Parent = stepPart

		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = cfg.Name .. "\n---"
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.TextStrokeTransparency = 0.3
		label.TextScaled = true
		label.Font = Enum.Font.GothamBold
		label.Parent = gui

		podiumLabels[cfg.Rank] = label
	end

	----------------------------------------------------------------------
	-- ÁREA VISUAL DO REI DO FERRO-VELHO
	----------------------------------------------------------------------
	local kingBase = createPart(parent, "KingPlatform", Vector3.new(7, 1.2, 7), CFrame.new(0, 1.1, 0), Enum.Material.DiamondPlate, Color3.fromRGB(45, 42, 38), true, true)
	local kingBorder = Instance.new("SelectionBox")
	kingBorder.Adornee = kingBase
	kingBorder.Color3 = Color3.fromRGB(255, 215, 0)
	kingBorder.LineThickness = 0.15
	kingBorder.Parent = kingBase

	createPart(parent, "ThroneBack", Vector3.new(3.5, 4, 0.8), CFrame.new(0, 3.5, -1.8), Enum.Material.Metal, Color3.fromRGB(140, 50, 45), true, true)
	createPart(parent, "ThroneSeat", Vector3.new(3.5, 1.2, 2.8), CFrame.new(0, 2.1, -0.6), Enum.Material.Concrete, Color3.fromRGB(80, 85, 90), true, true)

	local crown = Instance.new("Part")
	crown.Name = "FloatingCrown"
	crown.Size = Vector3.new(2.2, 1.4, 2.2)
	crown.CFrame = CFrame.new(0, 6.2, -0.6)
	crown.Material = Enum.Material.Neon
	crown.Color = Color3.fromRGB(255, 215, 30)
	crown.Anchored = true
	crown.CanCollide = false
	crown.Parent = parent

	local crownHighlight = Instance.new("Highlight")
	crownHighlight.Adornee = crown
	crownHighlight.FillColor = Color3.fromRGB(255, 225, 50)
	crownHighlight.OutlineColor = Color3.fromRGB(255, 255, 200)
	crownHighlight.FillTransparency = 0.3
	crownHighlight.Parent = crown

	local crownBillboard = Instance.new("BillboardGui")
	crownBillboard.Size = UDim2.fromOffset(260, 45)
	crownBillboard.StudsOffset = Vector3.new(0, 1.8, 0)
	crownBillboard.AlwaysOnTop = true
	crownBillboard.Parent = crown

	local crownText = Instance.new("TextLabel")
	crownText.Size = UDim2.fromScale(1, 1)
	crownText.BackgroundTransparency = 1
	crownText.Text = "👑 REI DO FERRO-VELHO 👑"
	crownText.TextColor3 = Color3.fromRGB(255, 220, 70)
	crownText.TextStrokeColor3 = Color3.fromRGB(70, 45, 0)
	crownText.TextStrokeTransparency = 0.1
	crownText.TextScaled = true
	crownText.Font = Enum.Font.GothamBlack
	crownText.Parent = crownBillboard

	task.spawn(function()
		local angle = 0
		while crown.Parent do
			angle += 1.5
			crown.CFrame = CFrame.new(0, 6.2 + math.sin(os.clock() * 2) * 0.25, -0.6) * CFrame.Angles(0, math.rad(angle), 0)
			RunService.Heartbeat:Wait()
		end
	end)
end

local function buildDock(index: number, parent: Model): DockData
	local dockModel = Instance.new("Model")
	dockModel.Name = "Dock_" .. index
	dockModel:SetAttribute("DockId", index)
	dockModel:SetAttribute("OwnerUserId", 0)
	dockModel.Parent = parent

	local pos = DOCK_OFFSETS[index]
	local target = DOCK_TARGETS[index]
	local lookDirection = (target - pos).Unit
	local dockCf = CFrame.lookAt(pos, pos + lookDirection)

	local dockPad = createPart(dockModel, "DockPad", Vector3.new(16, 1, 14), dockCf, Enum.Material.Concrete, Color3.fromRGB(55, 58, 62), true, true)
	dockModel.PrimaryPart = dockPad

	local border = Instance.new("SelectionBox")
	border.Adornee = dockPad
	border.Color3 = Color3.fromRGB(80, 200, 120)
	border.LineThickness = 0.08
	border.Parent = dockPad

	local rampLength = 5
	local rampCf = dockCf * CFrame.new(0, 0, -8.5)
	local ramp = Instance.new("WedgePart")
	ramp.Name = "EntryRamp"
	ramp.Size = Vector3.new(16, 1, rampLength)
	ramp.CFrame = rampCf * CFrame.Angles(0, math.pi, 0)
	ramp.Material = Enum.Material.Concrete
	ramp.Color = Color3.fromRGB(70, 75, 80)
	ramp.Anchored = true
	ramp.CanCollide = true
	ramp.Parent = dockModel

	----------------------------------------------------------------------
	-- ÁREA 1: ESTEIRA / DESCARTAR PEÇAS NORMAIS
	----------------------------------------------------------------------
	local dropCf = dockCf * CFrame.new(-4.2, 0.45, 0)
	local partsDrop = createPart(dockModel, "PartsDropZone", Vector3.new(6, 0.6, 10), dropCf, Enum.Material.Neon, Color3.fromRGB(45, 195, 95), true, true)
	partsDrop:SetAttribute("OwnerUserId", 0)
	partsDrop:SetAttribute("DockId", index)
	partsDrop:SetAttribute("ZoneType", "NormalParts")

	local partsBillboard = Instance.new("BillboardGui")
	partsBillboard.Size = UDim2.fromOffset(200, 50)
	partsBillboard.StudsOffset = Vector3.new(0, 3, 0)
	partsBillboard.AlwaysOnTop = true
	partsBillboard.Parent = partsDrop

	local partsLabel = Instance.new("TextLabel")
	partsLabel.Size = UDim2.fromScale(1, 1)
	partsLabel.BackgroundTransparency = 1
	partsLabel.Text = "ENTREGA DE PEÇAS"
	partsLabel.TextColor3 = Color3.fromRGB(240, 255, 240)
	partsLabel.TextStrokeColor3 = Color3.fromRGB(15, 60, 25)
	partsLabel.TextStrokeTransparency = 0.2
	partsLabel.TextScaled = true
	partsLabel.Font = Enum.Font.GothamBold
	partsLabel.Parent = partsBillboard

	----------------------------------------------------------------------
	-- ÁREA 2: BAIA DO GUINCHO / MOTOR
	----------------------------------------------------------------------
	local engineCf = dockCf * CFrame.new(4.2, 0.45, 0)
	local engineBay = createPart(dockModel, "EngineBayZone", Vector3.new(6.5, 0.6, 10), engineCf, Enum.Material.DiamondPlate, Color3.fromRGB(225, 150, 40), true, true)
	engineBay:SetAttribute("OwnerUserId", 0)
	engineBay:SetAttribute("DockId", index)
	engineBay:SetAttribute("ZoneType", "EngineBay")

	local bayBillboard = Instance.new("BillboardGui")
	bayBillboard.Size = UDim2.fromOffset(220, 50)
	bayBillboard.StudsOffset = Vector3.new(0, 3, 0)
	bayBillboard.AlwaysOnTop = true
	bayBillboard.Parent = engineBay

	local bayLabel = Instance.new("TextLabel")
	bayLabel.Size = UDim2.fromScale(1, 1)
	bayLabel.BackgroundTransparency = 1
	bayLabel.Text = "BAIA DE GUINCHO / MOTOR"
	bayLabel.TextColor3 = Color3.fromRGB(255, 235, 150)
	bayLabel.TextStrokeColor3 = Color3.fromRGB(80, 45, 0)
	bayLabel.TextStrokeTransparency = 0.2
	bayLabel.TextScaled = true
	bayLabel.Font = Enum.Font.GothamBold
	bayLabel.Parent = bayBillboard

	----------------------------------------------------------------------
	-- PORTAL / PLACA DA DOCA
	----------------------------------------------------------------------
	local signPost = createPart(dockModel, "SignArch", Vector3.new(15, 3.5, 0.6), dockCf * CFrame.new(0, 5.5, -6), Enum.Material.Metal, Color3.fromRGB(35, 38, 42), true, true)
	local signGui = Instance.new("SurfaceGui")
	signGui.Face = Enum.NormalId.Front
	signGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	signGui.PixelsPerStud = 50
	signGui.Parent = signPost

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, 0, 0.5, 0)
	titleLabel.Position = UDim2.new(0, 0, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = string.format("DOCA %d - RECICLAGEM", index)
	titleLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
	titleLabel.TextStrokeTransparency = 0.2
	titleLabel.TextScaled = true
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.Parent = signGui

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Size = UDim2.new(1, 0, 0.5, 0)
	statusLabel.Position = UDim2.new(0, 0, 0.5, 0)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = "DOCA LIVRE"
	statusLabel.TextColor3 = Color3.fromRGB(180, 190, 200)
	statusLabel.TextScaled = true
	statusLabel.Font = Enum.Font.GothamMedium
	statusLabel.Parent = signGui

	return {
		Index = index,
		Model = dockModel,
		Direction = lookDirection,
		CFrame = dockCf,
		PartsDropZone = partsDrop,
		EngineBayZone = engineBay,
		OwnerUserId = 0,
		SignLabel = titleLabel,
		StatusLabel = statusLabel,
	}
end

function RecyclingCenterService.AssignDock(plotId: number, player: Player)
	local dock = docks[plotId]
	if not dock then return end
	dock.OwnerUserId = player.UserId
	dock.Model:SetAttribute("OwnerUserId", player.UserId)
	dock.PartsDropZone:SetAttribute("OwnerUserId", player.UserId)
	dock.EngineBayZone:SetAttribute("OwnerUserId", player.UserId)
	dock.StatusLabel.Text = "FERRO-VELHO DE " .. player.DisplayName:upper()
	dock.StatusLabel.TextColor3 = Color3.fromRGB(80, 255, 130)
end

function RecyclingCenterService.ReleaseDock(plotId: number)
	local dock = docks[plotId]
	if not dock then return end
	dock.OwnerUserId = 0
	dock.Model:SetAttribute("OwnerUserId", 0)
	dock.PartsDropZone:SetAttribute("OwnerUserId", 0)
	dock.EngineBayZone:SetAttribute("OwnerUserId", 0)
	dock.StatusLabel.Text = "DOCA LIVRE"
	dock.StatusLabel.TextColor3 = Color3.fromRGB(180, 190, 200)
end

function RecyclingCenterService.GetDock(plotId: number): DockData?
	return docks[plotId]
end

function RecyclingCenterService.GetDockForPlayer(player: Player): DockData?
	local plotId = player:GetAttribute("PlotId")
	if typeof(plotId) == "number" then
		return docks[plotId]
	end
	return nil
end

function RecyclingCenterService.GetAllDocks(): {[number]: DockData}
	return docks
end

local function updateLeaderboardAndPodium()
	local playerStats: {{ Player: Player, Money: number, Cars: number }} = {}
	for _, player in Players:GetPlayers() do
		local leaderstats = player:FindFirstChild("leaderstats")
		local money = leaderstats and leaderstats:FindFirstChild("Dinheiro")
		local cars = leaderstats and leaderstats:FindFirstChild("Carros Desmontados")
		local moneyVal = if money and money:IsA("IntValue") then money.Value else 0
		local carsVal = if cars and cars:IsA("IntValue") then cars.Value else 0
		table.insert(playerStats, { Player = player, Money = moneyVal, Cars = carsVal })
	end

	table.sort(playerStats, function(a, b)
		if a.Money ~= b.Money then
			return a.Money > b.Money
		end
		return a.Cars > b.Cars
	end)

	for rank = 1, 4 do
		local label = leaderboardLabels[rank]
		if label then
			local entry = playerStats[rank]
			if entry then
				label.Text = string.format("%d. %s  -  R$ %s  |  %d Carros", rank, entry.Player.DisplayName, tostring(entry.Money), entry.Cars)
			else
				label.Text = string.format("%d. Vazio  -  R$ 0  |  0 Carros", rank)
			end
		end
	end

	for rank = 1, 3 do
		local label = podiumLabels[rank]
		if label then
			local entry = playerStats[rank]
			local titleText = if rank == 1 then "1º LUGAR" elseif rank == 2 then "2º LUGAR" else "3º LUGAR"
			if entry then
				label.Text = string.format("%s\n%s\nR$ %d", titleText, entry.Player.DisplayName, entry.Money)
			else
				label.Text = string.format("%s\n---", titleText)
			end
		end
	end
end

function RecyclingCenterService.PulseDropZone(zone: Part)
	local originalColor = zone.Color
	local highlightColor = Color3.fromRGB(255, 255, 140)
	zone.Color = highlightColor
	zone.Transparency = 0
	local tween = TweenService:Create(zone, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Color = originalColor,
		Transparency = 0.2,
	})
	tween:Play()
end

function RecyclingCenterService.start()
	local existing = Workspace:FindFirstChild("RecyclingCenter")
	if existing then existing:Destroy() end

	local folder = Instance.new("Model")
	folder.Name = "RecyclingCenter"
	folder.Parent = Workspace
	centralModel = folder

	buildCentralHub(folder)

	for i = 1, 4 do
		docks[i] = buildDock(i, folder)
	end

	PlotService.PlotAssigned:Connect(function(player: Player, plot: Model)
		local plotId = plot:GetAttribute("PlotId")
		if typeof(plotId) == "number" then
			RecyclingCenterService.AssignDock(plotId, player)
		end
	end)

	PlotService.PlotReleased:Connect(function(player: Player, plot: Model)
		local plotId = plot:GetAttribute("PlotId")
		if typeof(plotId) == "number" then
			RecyclingCenterService.ReleaseDock(plotId)
		end
	end)

	for _, player in Players:GetPlayers() do
		local plot = PlotService.GetPlot(player)
		if plot then
			local plotId = plot:GetAttribute("PlotId")
			if typeof(plotId) == "number" then
				RecyclingCenterService.AssignDock(plotId, player)
			end
		end
	end

	task.spawn(function()
		while true do
			updateLeaderboardAndPodium()
			task.wait(2)
		end
	end)
end

return RecyclingCenterService
