--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local PlotService = {}
local plotAssignedEvent = Instance.new("BindableEvent")
local plotReleasedEvent = Instance.new("BindableEvent")
local boxUnlockedEvent = Instance.new("BindableEvent")

PlotService.PlotAssigned = plotAssignedEvent.Event
PlotService.PlotReleased = plotReleasedEvent.Event
PlotService.BoxUnlocked = boxUnlockedEvent.Event

local PLOT_SIZE = Vector3.new(48, 1, 48)
local PLOT_POSITIONS = {
	Vector3.new(-55, 0.5, -55),
	Vector3.new(55, 0.5, -55),
	Vector3.new(-55, 0.5, 55),
	Vector3.new(55, 0.5, 55),
}

local BOX_X_OFFSETS = { -15, 0, 15 }
local BOX_REQUISITES = {
	[1] = "INICIAL",
	[2] = "REBIRTH 5 (R$ 500.000)",
	[3] = "REBIRTH 10 (R$ 25.000.000)",
}

local plots: {Model} = {}
local playerPlots: {[Player]: Model} = {}

local function setPlotLabel(plot: Model, text: string)
	local sign = plot:FindFirstChild("OwnerSign")
	local gui = sign and sign:FindFirstChild("OwnerGui")
	local label = gui and gui:FindFirstChild("OwnerLabel")
	if label and label:IsA("TextLabel") then label.Text = text end
end

local function setBarrierUnlocked(barrier: BasePart, isUnlocked: boolean)
	barrier.CanCollide = not isUnlocked
	barrier.Transparency = if isUnlocked then 1 else 0.2

	for _, child in barrier:GetDescendants() do
		if child:IsA("BasePart") then
			child.CanCollide = not isUnlocked
			child.Transparency = if isUnlocked then 1 else 0
		elseif child:IsA("SurfaceGui") or child:IsA("BillboardGui") then
			child.Enabled = not isUnlocked
		end
	end
end

local function createBox(plot: Model, boxIndex: number, position: Vector3): Model
	local boxModel = Instance.new("Model")
	boxModel.Name = "Box_" .. boxIndex
	boxModel:SetAttribute("BoxIndex", boxIndex)
	boxModel:SetAttribute("IsUnlocked", boxIndex == 1)

	local xOffset = BOX_X_OFFSETS[boxIndex]
	local boxPos = position + Vector3.new(xOffset, 0.1, -4)

	-- Piso demarcado do Box (Concreto industrial escurecido)
	local pad = Instance.new("Part")
	pad.Name = "BoxPad"
	pad.Size = Vector3.new(13.5, 0.2, 22)
	pad.Position = boxPos
	pad.Anchored = true
	pad.Material = Enum.Material.Concrete
	pad.Color = Color3.fromRGB(48, 50, 54)
	pad.TopSurface = Enum.SurfaceType.Smooth
	pad.BottomSurface = Enum.SurfaceType.Smooth
	pad.Parent = boxModel

	-- Faixa zebrada (Hazard Stripes) amarela e preta na entrada do Box
	local frontHazard = Instance.new("Part")
	frontHazard.Name = "FrontHazardStripe"
	frontHazard.Size = Vector3.new(13.5, 0.22, 1.2)
	frontHazard.Position = boxPos + Vector3.new(0, 0.02, 10.4)
	frontHazard.Anchored = true
	frontHazard.Material = Enum.Material.DiamondPlate
	frontHazard.Color = if boxIndex == 1 then Color3.fromRGB(220, 180, 40) else Color3.fromRGB(180, 50, 45)
	frontHazard.Parent = boxModel

	-- Mancha de óleo sob o cofre do motor
	local oilSpill = Instance.new("Part")
	oilSpill.Name = "OilSpill"
	oilSpill.Size = Vector3.new(4.5, 0.04, 3.8)
	oilSpill.Position = boxPos + Vector3.new(0, 0.12, -4.5)
	oilSpill.Anchored = true
	oilSpill.CanCollide = false
	oilSpill.Material = Enum.Material.SmoothPlastic
	oilSpill.Color = Color3.fromRGB(18, 18, 20)
	oilSpill.Transparency = 0.2
	oilSpill.Parent = boxModel

	-- Ponto de origem do carro para esse Box
	local origin = Instance.new("Part")
	origin.Name = "BoxOrigin"
	origin.Size = Vector3.new(1, 1, 1)
	origin.Position = boxPos + Vector3.new(0, 0.5, 0)
	origin.Anchored = true
	origin.CanCollide = false
	origin.Transparency = 1
	origin.Parent = boxModel

	-- Ponto de origem do guincho para esse Box
	local hoistOrigin = Instance.new("Part")
	hoistOrigin.Name = "BoxHoistOrigin"
	hoistOrigin.Size = Vector3.new(1, 1, 1)
	hoistOrigin.Position = boxPos + Vector3.new(-4.5, 0.5, -9)
	hoistOrigin.Anchored = true
	hoistOrigin.CanCollide = false
	hoistOrigin.Transparency = 1
	hoistOrigin.Parent = boxModel

	-- Colunas industriais de aço nas laterais da baia
	for _, xSide in { -6.2, 6.2 } do
		local col = Instance.new("Part")
		col.Name = "BayColumn"
		col.Size = Vector3.new(0.8, 9.0, 0.8)
		col.Position = boxPos + Vector3.new(xSide, 4.5, 10.6)
		col.Anchored = true
		col.Material = Enum.Material.DiamondPlate
		col.Color = Color3.fromRGB(42, 45, 50)
		col.Parent = boxModel
	end

	-- Arco / Viga de identificação do Box
	local arch = Instance.new("Part")
	arch.Name = "BoxArch"
	arch.Size = Vector3.new(13.2, 1.8, 0.8)
	arch.Position = boxPos + Vector3.new(0, 8.1, 10.6)
	arch.Anchored = true
	arch.Material = Enum.Material.DiamondPlate
	arch.Color = Color3.fromRGB(35, 38, 42)
	arch.Parent = boxModel

	-- Luminária industrial pendurada com iluminação quente de oficina
	local lampHood = Instance.new("Part")
	lampHood.Name = "ShopLamp"
	lampHood.Size = Vector3.new(2.2, 0.6, 2.2)
	lampHood.Position = boxPos + Vector3.new(0, 7.0, 0)
	lampHood.Anchored = true
	lampHood.Material = Enum.Material.Metal
	lampHood.Color = Color3.fromRGB(38, 42, 46)
	lampHood.Parent = boxModel

	local lampBulb = Instance.new("Part")
	lampBulb.Name = "ShopLampBulb"
	lampBulb.Size = Vector3.new(1.2, 0.2, 1.2)
	lampBulb.Position = boxPos + Vector3.new(0, 6.7, 0)
	lampBulb.Anchored = true
	lampBulb.Material = Enum.Material.Neon
	lampBulb.Color = Color3.fromRGB(255, 230, 160)
	lampBulb.Parent = boxModel

	local shopLight = Instance.new("PointLight")
	shopLight.Name = "ShopLight"
	shopLight.Color = Color3.fromRGB(255, 225, 150)
	shopLight.Brightness = 2.2
	shopLight.Range = 26
	shopLight.Shadows = true
	shopLight.Parent = lampBulb

	local gui = Instance.new("SurfaceGui")
	gui.Name = "BoxGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.Parent = arch

	local label = Instance.new("TextLabel")
	label.Name = "BoxLabel"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = if boxIndex == 1 then "BOX 1  [ATIVO]" else string.format("BOX %d  [BLOQUEADO]", boxIndex)
	label.TextColor3 = if boxIndex == 1 then Color3.fromRGB(240, 200, 60) else Color3.fromRGB(240, 80, 70)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.Parent = gui

	-- Barreira para Boxes Bloqueados (2 e 3): Portão industrial pantográfico com corrente e cadeado
	if boxIndex > 1 then
		local barrier = Instance.new("Part")
		barrier.Name = "BoxBarrier"
		barrier.Size = Vector3.new(13.0, 6.8, 0.4)
		barrier.Position = boxPos + Vector3.new(0, 3.6, 10.6)
		barrier.Anchored = true
		barrier.CanCollide = true
		barrier.Material = Enum.Material.DiamondPlate
		barrier.Color = Color3.fromRGB(58, 62, 68)
		barrier.Transparency = 0.2
		barrier.Parent = boxModel

		-- Faixa central de aviso
		local warningBar = Instance.new("Part")
		warningBar.Name = "WarningBar"
		warningBar.Size = Vector3.new(13.1, 0.8, 0.5)
		warningBar.Position = boxPos + Vector3.new(0, 3.6, 10.6)
		warningBar.Anchored = true
		warningBar.Material = Enum.Material.Metal
		warningBar.Color = Color3.fromRGB(210, 160, 30)
		warningBar.Parent = barrier

		-- Cadeado e corrente
		local padlock = Instance.new("Part")
		padlock.Name = "Padlock"
		padlock.Size = Vector3.new(1.0, 1.2, 0.6)
		padlock.Position = boxPos + Vector3.new(0, 3.6, 10.9)
		padlock.Anchored = true
		padlock.Material = Enum.Material.Metal
		padlock.Color = Color3.fromRGB(190, 150, 45)
		padlock.Parent = barrier

		local barrierBb = Instance.new("SurfaceGui")
		barrierBb.Name = "BarrierInfo"
		barrierBb.Face = Enum.NormalId.Front
		barrierBb.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		barrierBb.PixelsPerStud = 55
		barrierBb.Parent = warningBar

		local infoLabel = Instance.new("TextLabel")
		infoLabel.Size = UDim2.fromScale(1, 1)
		infoLabel.BackgroundTransparency = 1
		infoLabel.Text = string.format("BOX %d BLOQUEADO  •  %s", boxIndex, BOX_REQUISITES[boxIndex])
		infoLabel.TextColor3 = Color3.fromRGB(255, 220, 110)
		infoLabel.TextStrokeColor3 = Color3.fromRGB(40, 15, 10)
		infoLabel.TextStrokeTransparency = 0.1
		infoLabel.TextScaled = true
		infoLabel.Font = Enum.Font.GothamBold
		infoLabel.Parent = barrierBb
	end

	boxModel.Parent = plot
	return boxModel
end

local function createStationDisplay(parent: Instance, name: string, cf: CFrame, accentColor: Color3, title: string): TextLabel
	local board = Instance.new("Part")
	board.Name = name
	board.Size = Vector3.new(7.2, 3.8, 0.35)
	board.CFrame = cf
	board.Anchored = true
	board.CanCollide = false
	board.Material = Enum.Material.DiamondPlate
	board.Color = Color3.fromRGB(27, 30, 34)
	board.Parent = parent

	local accent = Instance.new("Part")
	accent.Name = "Accent"
	accent.Size = Vector3.new(7.4, 0.35, 0.42)
	accent.CFrame = cf * CFrame.new(0, 2.05, 0)
	accent.Anchored = true
	accent.CanCollide = false
	accent.Material = Enum.Material.Neon
	accent.Color = accentColor
	accent.Parent = board

	local gui = Instance.new("SurfaceGui")
	gui.Name = "StationGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 55
	gui.LightInfluence = 0.2
	gui.Parent = board

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "TitleLabel"
	titleLabel.Size = UDim2.new(1, -12, 0.32, 0)
	titleLabel.Position = UDim2.fromOffset(6, 4)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = title
	titleLabel.TextColor3 = accentColor
	titleLabel.TextScaled = true
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.Parent = gui

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "StatusLabel"
	statusLabel.Size = UDim2.new(1, -12, 0.63, -6)
	statusLabel.Position = UDim2.new(0, 6, 0.34, 2)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = "AGUARDANDO DONO"
	statusLabel.TextColor3 = Color3.fromRGB(225, 230, 235)
	statusLabel.TextStrokeTransparency = 0.65
	statusLabel.TextScaled = true
	statusLabel.TextWrapped = true
	statusLabel.Font = Enum.Font.GothamBold
	statusLabel.Parent = gui

	return statusLabel
end

local function createUpgradeWorkshop(plot: Model, position: Vector3)
	local workshop = Instance.new("Model")
	workshop.Name = "UpgradeWorkshop"
	workshop.Parent = plot

	local center = position + Vector3.new(14.5, 0, 16.2)
	local steel = Color3.fromRGB(40, 44, 48)
	local wall = Color3.fromRGB(61, 66, 70)
	local yellow = Color3.fromRGB(235, 184, 42)

	local floor = Instance.new("Part")
	floor.Name = "UpgradeFloor"
	floor.Size = Vector3.new(18, 0.35, 13.5)
	floor.Position = center + Vector3.new(0, 1.02, 0)
	floor.Anchored = true
	floor.Material = Enum.Material.DiamondPlate
	floor.Color = Color3.fromRGB(48, 52, 55)
	floor.Parent = workshop

	local backWall = Instance.new("Part")
	backWall.Name = "UpgradeBackWall"
	backWall.Size = Vector3.new(18, 7, 0.6)
	backWall.Position = center + Vector3.new(0, 4.5, 6.45)
	backWall.Anchored = true
	backWall.Material = Enum.Material.CorrodedMetal
	backWall.Color = wall
	backWall.Parent = workshop

	local sideWall = Instance.new("Part")
	sideWall.Name = "UpgradeSideWall"
	sideWall.Size = Vector3.new(0.6, 7, 13.5)
	sideWall.Position = center + Vector3.new(8.7, 4.5, 0)
	sideWall.Anchored = true
	sideWall.Material = Enum.Material.CorrodedMetal
	sideWall.Color = wall
	sideWall.Parent = workshop

	local roof = Instance.new("Part")
	roof.Name = "UpgradeRoof"
	roof.Size = Vector3.new(18.8, 0.8, 14.3)
	roof.Position = center + Vector3.new(0, 8.1, 0)
	roof.Anchored = true
	roof.Material = Enum.Material.Metal
	roof.Color = steel
	roof.Parent = workshop

	for _, xOffset in { -8.4, 8.4 } do
		local post = Instance.new("Part")
		post.Name = "UpgradeFrontPost"
		post.Size = Vector3.new(0.7, 7.2, 0.7)
		post.Position = center + Vector3.new(xOffset, 4.5, -6.35)
		post.Anchored = true
		post.Material = Enum.Material.DiamondPlate
		post.Color = steel
		post.Parent = workshop
	end

	local header = Instance.new("Part")
	header.Name = "UpgradeHeader"
	header.Size = Vector3.new(18, 2.3, 0.55)
	header.Position = center + Vector3.new(0, 6.75, -6.4)
	header.Anchored = true
	header.CanCollide = false
	header.Material = Enum.Material.DiamondPlate
	header.Color = Color3.fromRGB(29, 32, 35)
	header.Parent = workshop

	local headerGui = Instance.new("SurfaceGui")
	headerGui.Face = Enum.NormalId.Front
	headerGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	headerGui.PixelsPerStud = 55
	headerGui.Parent = header

	local headerLabel = Instance.new("TextLabel")
	headerLabel.Size = UDim2.fromScale(1, 1)
	headerLabel.BackgroundTransparency = 1
	headerLabel.Text = "CENTRO DE MELHORIAS"
	headerLabel.TextColor3 = yellow
	headerLabel.TextStrokeTransparency = 0.25
	headerLabel.TextScaled = true
	headerLabel.Font = Enum.Font.GothamBlack
	headerLabel.Parent = headerGui

	local divider = Instance.new("Part")
	divider.Name = "StationDivider"
	divider.Size = Vector3.new(0.35, 6.4, 12.4)
	divider.Position = center + Vector3.new(0, 4.2, 0.3)
	divider.Anchored = true
	divider.CanCollide = false
	divider.Material = Enum.Material.Metal
	divider.Color = Color3.fromRGB(34, 37, 40)
	divider.Parent = workshop

	local toolDisplayCf = CFrame.new(position + Vector3.new(10.2, 4.5, 22.15))
	local speedDisplayCf = CFrame.new(position + Vector3.new(18.5, 4.5, 22.15))
	createStationDisplay(workshop, "ToolStationDisplay", toolDisplayCf, Color3.fromRGB(80, 155, 255), "FERRAMENTAS")
	createStationDisplay(workshop, "SpeedStationDisplay", speedDisplayCf, Color3.fromRGB(35, 220, 190), "MOBILIDADE")

	-- Ferramenta física na parede: cabo, cabeça e soquete da chave catraca.
	local ratchetHandle = Instance.new("Part")
	ratchetHandle.Name = "RatchetDisplayHandle"
	ratchetHandle.Size = Vector3.new(0.38, 3.2, 0.38)
	ratchetHandle.CFrame = CFrame.new(position + Vector3.new(10.2, 5.5, 21.72)) * CFrame.Angles(0, 0, math.rad(-35))
	ratchetHandle.Anchored = true
	ratchetHandle.CanCollide = false
	ratchetHandle.Material = Enum.Material.Metal
	ratchetHandle.Color = Color3.fromRGB(175, 182, 190)
	ratchetHandle.Parent = workshop

	local ratchetHead = Instance.new("Part")
	ratchetHead.Name = "RatchetDisplayHead"
	ratchetHead.Size = Vector3.new(0.5, 1.1, 1.1)
	ratchetHead.CFrame = CFrame.new(position + Vector3.new(9.3, 6.75, 21.72)) * CFrame.Angles(0, math.rad(90), 0)
	ratchetHead.Shape = Enum.PartType.Cylinder
	ratchetHead.Anchored = true
	ratchetHead.CanCollide = false
	ratchetHead.Material = Enum.Material.Metal
	ratchetHead.Color = Color3.fromRGB(205, 210, 215)
	ratchetHead.Parent = workshop

	local toolInstalledLight = Instance.new("Part")
	toolInstalledLight.Name = "ToolInstalledLight"
	toolInstalledLight.Size = Vector3.new(1.1, 0.35, 0.35)
	toolInstalledLight.Position = position + Vector3.new(10.2, 2.35, 21.7)
	toolInstalledLight.Anchored = true
	toolInstalledLight.CanCollide = false
	toolInstalledLight.Material = Enum.Material.Metal
	toolInstalledLight.Color = Color3.fromRGB(55, 60, 64)
	toolInstalledLight.Parent = workshop

	-- Roda na parede para representar a categoria de mobilidade.
	local speedWheel = Instance.new("Part")
	speedWheel.Name = "MobilityWheelDisplay"
	speedWheel.Size = Vector3.new(0.7, 2.8, 2.8)
	speedWheel.CFrame = CFrame.new(position + Vector3.new(18.5, 5.9, 21.72)) * CFrame.Angles(0, math.rad(90), 0)
	speedWheel.Shape = Enum.PartType.Cylinder
	speedWheel.Anchored = true
	speedWheel.CanCollide = false
	speedWheel.Material = Enum.Material.Rubber
	speedWheel.Color = Color3.fromRGB(24, 25, 27)
	speedWheel.Parent = workshop

	local speedHub = Instance.new("Part")
	speedHub.Name = "MobilityWheelHub"
	speedHub.Size = Vector3.new(0.75, 1.15, 1.15)
	speedHub.CFrame = speedWheel.CFrame
	speedHub.Shape = Enum.PartType.Cylinder
	speedHub.Anchored = true
	speedHub.CanCollide = false
	speedHub.Material = Enum.Material.Metal
	speedHub.Color = Color3.fromRGB(45, 165, 145)
	speedHub.Parent = workshop

	for level = 1, 5 do
		local indicator = Instance.new("Part")
		indicator.Name = "SpeedIndicator_" .. level
		indicator.Size = Vector3.new(0.9, 0.35, 0.35)
		indicator.Position = position + Vector3.new(15.7 + level * 0.95, 2.35, 21.7)
		indicator.Anchored = true
		indicator.CanCollide = false
		indicator.Material = Enum.Material.Metal
		indicator.Color = Color3.fromRGB(55, 60, 64)
		indicator.Parent = workshop
	end

	for stationIndex, stationX in { 10.2, 18.5 } do
		local anchor = Instance.new("Part")
		anchor.Name = if stationIndex == 1 then "ToolUpgradeAnchor" else "SpeedUpgradeAnchor"
		anchor.Size = Vector3.new(1, 1, 1)
		anchor.Position = position + Vector3.new(stationX, 1.4, 15.3)
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.Transparency = 1
		anchor.Parent = workshop

		local lamp = Instance.new("Part")
		lamp.Name = "StationLamp"
		lamp.Size = Vector3.new(2.2, 0.35, 1.4)
		lamp.Position = position + Vector3.new(stationX, 7.45, 15.3)
		lamp.Anchored = true
		lamp.CanCollide = false
		lamp.Material = Enum.Material.Neon
		lamp.Color = if stationIndex == 1 then Color3.fromRGB(80, 155, 255) else Color3.fromRGB(35, 220, 190)
		lamp.Parent = workshop

		local light = Instance.new("PointLight")
		light.Color = lamp.Color
		light.Brightness = 1.5
		light.Range = 12
		light.Parent = lamp
	end

	local stripe = Instance.new("Part")
	stripe.Name = "UpgradeHazardStripe"
	stripe.Size = Vector3.new(18, 0.12, 0.8)
	stripe.Position = center + Vector3.new(0, 1.22, -6.25)
	stripe.Anchored = true
	stripe.CanCollide = false
	stripe.Material = Enum.Material.SmoothPlastic
	stripe.Color = yellow
	stripe.Parent = workshop
end

local function setWorkshopStatus(plot: Model, toolLevel: number, speedLevel: number, isOwned: boolean)
	local workshop = plot:FindFirstChild("UpgradeWorkshop")
	if not workshop then return end

	local toolDisplay = workshop:FindFirstChild("ToolStationDisplay")
	local toolGui = toolDisplay and toolDisplay:FindFirstChild("StationGui")
	local toolStatus = toolGui and toolGui:FindFirstChild("StatusLabel")
	if toolStatus and toolStatus:IsA("TextLabel") then
		if not isOwned then
			toolStatus.Text = "AGUARDANDO DONO"
		elseif toolLevel >= 2 then
			toolStatus.Text = "NIVEL 2\nCHAVE CATRACA\nINSTALADA"
		else
			toolStatus.Text = "NIVEL 1\nFERRAMENTAS BASICAS\nMELHORIA DISPONIVEL"
		end
	end
	local toolInstalledLight = workshop:FindFirstChild("ToolInstalledLight")
	if toolInstalledLight and toolInstalledLight:IsA("BasePart") then
		local installed = isOwned and toolLevel >= 2
		toolInstalledLight.Material = if installed then Enum.Material.Neon else Enum.Material.Metal
		toolInstalledLight.Color = if installed then Color3.fromRGB(80, 155, 255) else Color3.fromRGB(55, 60, 64)
	end

	local speedDisplay = workshop:FindFirstChild("SpeedStationDisplay")
	local speedGui = speedDisplay and speedDisplay:FindFirstChild("StationGui")
	local speedStatus = speedGui and speedGui:FindFirstChild("StatusLabel")
	if speedStatus and speedStatus:IsA("TextLabel") then
		if not isOwned then
			speedStatus.Text = "AGUARDANDO DONO"
		else
			local speed = 14 + math.clamp(speedLevel, 1, 5) * 2
			speedStatus.Text = string.format("NIVEL %d / 5\n%d STUDS/S\n%s", speedLevel, speed, if speedLevel >= 5 then "MAXIMO" else "MELHORIA DISPONIVEL")
		end
	end

	for level = 1, 5 do
		local indicator = workshop:FindFirstChild("SpeedIndicator_" .. level)
		if indicator and indicator:IsA("BasePart") then
			indicator.Material = if isOwned and level <= speedLevel then Enum.Material.Neon else Enum.Material.Metal
			indicator.Color = if isOwned and level <= speedLevel then Color3.fromRGB(35, 220, 190) else Color3.fromRGB(55, 60, 64)
		end
	end
end

local function createPlot(index: number, position: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "Plot" .. index
	model:SetAttribute("PlotId", index)
	model:SetAttribute("OwnerUserId", 0)

	local pad = Instance.new("Part")
	pad.Name = "Pad"
	pad.Size = PLOT_SIZE
	pad.Position = position
	pad.Anchored = true
	pad.Material = Enum.Material.Concrete
	pad.Color = Color3.fromRGB(68, 72, 76)
	pad.TopSurface = Enum.SurfaceType.Smooth
	pad.BottomSurface = Enum.SurfaceType.Smooth
	pad.Parent = model
	model.PrimaryPart = pad

	createUpgradeWorkshop(model, position)

	-- Mureta de contenção industrial nas laterais do lote
	for _, sideX in { -PLOT_SIZE.X / 2 + 0.4, PLOT_SIZE.X / 2 - 0.4 } do
		local curb = Instance.new("Part")
		curb.Name = "SideCurb"
		curb.Size = Vector3.new(0.8, 0.7, PLOT_SIZE.Z)
		curb.Position = position + Vector3.new(sideX, 0.35, 0)
		curb.Anchored = true
		curb.Material = Enum.Material.Concrete
		curb.Color = Color3.fromRGB(48, 52, 56)
		curb.Parent = model
	end

	-- Parede de oficina ao fundo com chapa de aço corrugado
	local backWall = Instance.new("Part")
	backWall.Name = "WorkshopWall"
	backWall.Size = Vector3.new(PLOT_SIZE.X - 1.6, 9.5, 0.8)
	backWall.Position = position + Vector3.new(0, 4.75, -PLOT_SIZE.Z / 2 + 0.6)
	backWall.Anchored = true
	backWall.Material = Enum.Material.CorrodedMetal
	backWall.Color = Color3.fromRGB(58, 62, 66)
	backWall.Parent = model

	-- Galpão aberto: teto e paredes laterais criam um volume real sem fechar a entrada dos boxes.
	local workshopRoof = Instance.new("Part")
	workshopRoof.Name = "WorkshopRoof"
	workshopRoof.Size = Vector3.new(PLOT_SIZE.X - 1.6, 1, 32)
	workshopRoof.Position = position + Vector3.new(0, 11, -7.3)
	workshopRoof.Anchored = true
	workshopRoof.Material = Enum.Material.Metal
	workshopRoof.Color = Color3.fromRGB(43, 47, 51)
	workshopRoof.Parent = model

	for _, sideX in { -PLOT_SIZE.X / 2 + 0.8, PLOT_SIZE.X / 2 - 0.8 } do
		local sideWall = Instance.new("Part")
		sideWall.Name = "WorkshopSideWall"
		sideWall.Size = Vector3.new(1, 10, 32)
		sideWall.Position = position + Vector3.new(sideX, 5, -7.3)
		sideWall.Anchored = true
		sideWall.Material = Enum.Material.CorrodedMetal
		sideWall.Color = Color3.fromRGB(54, 59, 63)
		sideWall.Parent = model
	end

	for _, zOffset in { -20, -10, 0, 8 } do
		local roofBeam = Instance.new("Part")
		roofBeam.Name = "RoofBeam"
		roofBeam.Size = Vector3.new(PLOT_SIZE.X - 2, 0.55, 0.7)
		roofBeam.Position = position + Vector3.new(0, 10.35, zOffset)
		roofBeam.Anchored = true
		roofBeam.Material = Enum.Material.DiamondPlate
		roofBeam.Color = Color3.fromRGB(29, 32, 35)
		roofBeam.Parent = model
	end

	local workshopSign = Instance.new("Part")
	workshopSign.Name = "WorkshopSign"
	workshopSign.Size = Vector3.new(25, 3.4, 0.45)
	workshopSign.Position = position + Vector3.new(0, 8, -PLOT_SIZE.Z / 2 + 0.1)
	workshopSign.Anchored = true
	workshopSign.CanCollide = false
	workshopSign.Material = Enum.Material.DiamondPlate
	workshopSign.Color = Color3.fromRGB(27, 30, 33)
	workshopSign.Parent = model

	local workshopGui = Instance.new("SurfaceGui")
	workshopGui.Face = Enum.NormalId.Front
	workshopGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	workshopGui.PixelsPerStud = 50
	workshopGui.Parent = workshopSign

	local workshopLabel = Instance.new("TextLabel")
	workshopLabel.Size = UDim2.fromScale(1, 1)
	workshopLabel.BackgroundTransparency = 1
	workshopLabel.Text = "OFICINA DE DESMONTAGEM"
	workshopLabel.TextColor3 = Color3.fromRGB(242, 194, 55)
	workshopLabel.TextStrokeTransparency = 0.25
	workshopLabel.TextScaled = true
	workshopLabel.Font = Enum.Font.GothamBlack
	workshopLabel.Parent = workshopGui

	-- Bancada pesada de trabalho de madeira e metal
	local bench = Instance.new("Part")
	bench.Name = "Workbench"
	bench.Size = Vector3.new(12, 2.6, 2.8)
	bench.Position = position + Vector3.new(0, 1.3, -PLOT_SIZE.Z / 2 + 2.5)
	bench.Anchored = true
	bench.Material = Enum.Material.WoodPlanks
	bench.Color = Color3.fromRGB(95, 70, 50)
	bench.Parent = model

	-- Morsa de bancada (Bench Vise)
	local vise = Instance.new("Part")
	vise.Name = "BenchVise"
	vise.Size = Vector3.new(1.2, 1.0, 1.4)
	vise.Position = bench.Position + Vector3.new(4.5, 1.8, 0)
	vise.Anchored = true
	vise.Material = Enum.Material.Metal
	vise.Color = Color3.fromRGB(45, 75, 120)
	vise.Parent = model

	-- Armário móvel de ferramentas vermelho (Rollaway Tool Cabinet)
	local toolCabinet = Instance.new("Part")
	toolCabinet.Name = "ToolCabinet"
	toolCabinet.Size = Vector3.new(3.8, 4.2, 2.4)
	toolCabinet.Position = position + Vector3.new(-16, 2.1, -PLOT_SIZE.Z / 2 + 2.5)
	toolCabinet.Anchored = true
	toolCabinet.Material = Enum.Material.Metal
	toolCabinet.Color = Color3.fromRGB(180, 45, 40)
	toolCabinet.Parent = model

	local origin = Instance.new("Part")
	origin.Name = "Origin"
	origin.Size = Vector3.new(1, 1, 1)
	origin.Position = position + Vector3.new(0, 1, 0)
	origin.Anchored = true
	origin.CanCollide = false
	origin.Transparency = 1
	origin.Parent = model

	local spawnPoint = Instance.new("Part")
	spawnPoint.Name = "PlayerSpawn"
	spawnPoint.Size = Vector3.new(4, 0.25, 4)
	spawnPoint.Position = position + Vector3.new(0, 1.15, 18)
	spawnPoint.Anchored = true
	spawnPoint.CanCollide = false
	spawnPoint.Transparency = 1
	spawnPoint.Parent = model

	local sign = Instance.new("Part")
	sign.Name = "OwnerSign"
	sign.Size = Vector3.new(8, 3.5, 0.5)
	sign.Position = position + Vector3.new(0, 2.8, 23)
	sign.Anchored = true
	sign.Material = Enum.Material.DiamondPlate
	sign.Color = Color3.fromRGB(38, 42, 46)
	sign.Parent = model

	for _, x in { -3.5, 3.5 } do
		local signPost = Instance.new("Part")
		signPost.Name = "OwnerSignPost"
		signPost.Size = Vector3.new(0.45, 3.2, 0.45)
		signPost.Position = position + Vector3.new(x, 1.6, 23)
		signPost.Anchored = true
		signPost.Material = Enum.Material.Metal
		signPost.Color = Color3.fromRGB(32, 35, 38)
		signPost.Parent = model
	end

	local gui = Instance.new("SurfaceGui")
	gui.Name = "OwnerGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 45
	gui.Parent = sign

	local label = Instance.new("TextLabel")
	label.Name = "OwnerLabel"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "LOTE LIVRE"
	label.TextColor3 = Color3.fromRGB(255, 215, 90)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = gui

	-- Criar os 3 Boxes no lote
	local boxesFolder = Instance.new("Folder")
	boxesFolder.Name = "Boxes"
	boxesFolder.Parent = model
	for b = 1, 3 do
		createBox(boxesFolder, b, position)
	end

	-- Terminal de Leilão físico no lote (Estilo quiosque industrial blindado)
	local terminalModel = Instance.new("Model")
	terminalModel.Name = "AuctionTerminal"

	local deskPos = position + Vector3.new(-16, 1.4, 17)

	local desk = Instance.new("Part")
	desk.Name = "TerminalDesk"
	desk.Size = Vector3.new(4, 2.8, 2.5)
	desk.Position = deskPos
	desk.Anchored = true
	desk.Material = Enum.Material.DiamondPlate
	desk.Color = Color3.fromRGB(42, 46, 50)
	desk.Parent = terminalModel

	local monitor = Instance.new("Part")
	monitor.Name = "TerminalMonitor"
	monitor.Size = Vector3.new(2.8, 2.0, 0.4)
	monitor.Position = deskPos + Vector3.new(0, 2.4, 0)
	monitor.Anchored = true
	monitor.Material = Enum.Material.Metal
	monitor.Color = Color3.fromRGB(28, 30, 34)
	monitor.Parent = terminalModel

	local screen = Instance.new("Part")
	screen.Name = "TerminalScreen"
	screen.Size = Vector3.new(2.5, 1.7, 0.08)
	screen.Position = deskPos + Vector3.new(0, 2.4, 0.22)
	screen.Anchored = true
	screen.Material = Enum.Material.SmoothPlastic
	screen.Color = Color3.fromRGB(15, 22, 20)
	screen.Parent = terminalModel

	local tScreenGui = Instance.new("SurfaceGui")
	tScreenGui.Name = "ScreenGui"
	tScreenGui.Face = Enum.NormalId.Front
	tScreenGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	tScreenGui.PixelsPerStud = 50
	tScreenGui.Parent = screen

	local screenFrame = Instance.new("Frame")
	screenFrame.Size = UDim2.fromScale(1, 1)
	screenFrame.BackgroundColor3 = Color3.fromRGB(12, 18, 16)
	screenFrame.Parent = tScreenGui

	local screenTitle = Instance.new("TextLabel")
	screenTitle.Size = UDim2.new(1, -10, 0.45, 0)
	screenTitle.Position = UDim2.fromOffset(5, 5)
	screenTitle.BackgroundTransparency = 1
	screenTitle.Text = "⚖️ LEILÃO DE SUCATAS"
	screenTitle.TextColor3 = Color3.fromRGB(240, 195, 50)
	screenTitle.TextScaled = true
	screenTitle.Font = Enum.Font.GothamBlack
	screenTitle.Parent = screenFrame

	local screenSub = Instance.new("TextLabel")
	screenSub.Size = UDim2.new(1, -10, 0.45, 0)
	screenSub.Position = UDim2.new(0, 5, 0.5, 0)
	screenSub.BackgroundTransparency = 1
	screenSub.Text = "5 OFERTAS / 5 MIN\nPressione [E]"
	screenSub.TextColor3 = Color3.fromRGB(100, 210, 140)
	screenSub.TextScaled = true
	screenSub.Font = Enum.Font.GothamBold
	screenSub.Parent = screenFrame

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CatalogPrompt"
	prompt.ActionText = "Abrir Catálogo de Sucatas"
	prompt.ObjectText = "Terminal de Leilão"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = desk

	terminalModel.Parent = model

	model.Parent = Workspace
	return model
end

function PlotService.SyncBoxes(player: Player)
	local plot = playerPlots[player]
	if not plot then return end
	local boxesFolder = plot:FindFirstChild("Boxes")
	if not boxesFolder then return end

	local unlockedBoxes = player:GetAttribute("UnlockedBoxes")
	local unlockedCount = if typeof(unlockedBoxes) == "number" then math.clamp(unlockedBoxes, 1, 3) else 1

	for b = 1, 3 do
		local boxModel = boxesFolder:FindFirstChild("Box_" .. b)
		if boxModel and boxModel:IsA("Model") then
			local isUnlocked = b <= unlockedCount
			boxModel:SetAttribute("IsUnlocked", isUnlocked)

			local frontHazard = boxModel:FindFirstChild("FrontHazardStripe")
			if frontHazard and frontHazard:IsA("BasePart") then
				frontHazard.Color = if isUnlocked then Color3.fromRGB(220, 180, 40) else Color3.fromRGB(180, 50, 45)
			end

			local arch = boxModel:FindFirstChild("BoxArch")
			local gui = arch and arch:FindFirstChild("BoxGui")
			local label = gui and gui:FindFirstChild("BoxLabel")
			if label and label:IsA("TextLabel") then
				label.Text = if isUnlocked then string.format("BOX %d  [ATIVO]", b) else string.format("BOX %d  [BLOQUEADO]", b)
				label.TextColor3 = if isUnlocked then Color3.fromRGB(240, 200, 60) else Color3.fromRGB(240, 80, 70)
			end

			local barrier = boxModel:FindFirstChild("BoxBarrier")
			if barrier and barrier:IsA("BasePart") then
				setBarrierUnlocked(barrier, isUnlocked)
			end
		end
	end
end

function PlotService.SyncUpgradeWorkshop(player: Player)
	local plot = playerPlots[player]
	if not plot then return end
	local toolValue = player:GetAttribute("ToolLevel")
	local speedValue = player:GetAttribute("SpeedLevel")
	local toolLevel = if typeof(toolValue) == "number" then math.clamp(toolValue, 1, 2) else 1
	local speedLevel = if typeof(speedValue) == "number" then math.clamp(speedValue, 1, 5) else 1
	setWorkshopStatus(plot, toolLevel, speedLevel, true)
end

function PlotService.GetUpgradeAnchor(player: Player, anchorName: string): CFrame?
	local plot = PlotService.GetPlot(player)
	local workshop = plot and plot:FindFirstChild("UpgradeWorkshop")
	local anchor = workshop and workshop:FindFirstChild(anchorName)
	return if anchor and anchor:IsA("BasePart") then anchor.CFrame else nil
end

function PlotService.UnlockBox(player: Player, boxIndex: number): boolean
	if boxIndex < 1 or boxIndex > 3 then return false end
	local current = player:GetAttribute("UnlockedBoxes")
	local currentNum = if typeof(current) == "number" then current else 1
	if boxIndex <= currentNum then return true end

	player:SetAttribute("UnlockedBoxes", boxIndex)
	PlotService.SyncBoxes(player)
	boxUnlockedEvent:Fire(player, boxIndex)
	return true
end

function PlotService.GetBoxOrigin(player: Player, boxIndex: number): CFrame?
	local plot = PlotService.GetPlot(player)
	local boxes = plot and plot:FindFirstChild("Boxes")
	local box = boxes and boxes:FindFirstChild("Box_" .. boxIndex)
	local origin = box and box:FindFirstChild("BoxOrigin")
	return if origin and origin:IsA("BasePart") then origin.CFrame else nil
end

function PlotService.GetBoxHoistOrigin(player: Player, boxIndex: number): CFrame?
	local plot = PlotService.GetPlot(player)
	local boxes = plot and plot:FindFirstChild("Boxes")
	local box = boxes and boxes:FindFirstChild("Box_" .. boxIndex)
	local hoistOrigin = box and box:FindFirstChild("BoxHoistOrigin")
	return if hoistOrigin and hoistOrigin:IsA("BasePart") then hoistOrigin.CFrame else nil
end

local function teleportToPlot(player: Player, character: Model)
	local plot = playerPlots[player]
	if not plot then return end
	local spawnPoint = plot:FindFirstChild("PlayerSpawn")
	if spawnPoint and spawnPoint:IsA("BasePart") then
		character:PivotTo(spawnPoint.CFrame * CFrame.new(0, 3, 0))
	end
end

local function assignPlot(player: Player)
	if playerPlots[player] then return end
	for _, plot in plots do
		if plot:GetAttribute("OwnerUserId") == 0 then
			plot:SetAttribute("OwnerUserId", player.UserId)
			playerPlots[player] = plot
			player:SetAttribute("PlotId", plot:GetAttribute("PlotId"))
			setPlotLabel(plot, "FERRO-VELHO DE " .. player.DisplayName)

			if player:GetAttribute("UnlockedBoxes") == nil then
				player:SetAttribute("UnlockedBoxes", 1)
			end

			PlotService.SyncBoxes(player)
			PlotService.SyncUpgradeWorkshop(player)

			player:GetAttributeChangedSignal("UnlockedBoxes"):Connect(function()
				PlotService.SyncBoxes(player)
			end)
			player:GetAttributeChangedSignal("ToolLevel"):Connect(function()
				PlotService.SyncUpgradeWorkshop(player)
			end)
			player:GetAttributeChangedSignal("SpeedLevel"):Connect(function()
				PlotService.SyncUpgradeWorkshop(player)
			end)

			player.CharacterAdded:Connect(function(character)
				task.defer(teleportToPlot, player, character)
			end)
			if player.Character then task.defer(teleportToPlot, player, player.Character) end
			plotAssignedEvent:Fire(player, plot)
			return
		end
	end
	warn("No free tycoon plot for " .. player.Name)
end

local function releasePlot(player: Player)
	local plot = playerPlots[player]
	if not plot then return end
	plotReleasedEvent:Fire(player, plot)
	plot:SetAttribute("OwnerUserId", 0)
	setPlotLabel(plot, "LOTE LIVRE")
	setWorkshopStatus(plot, 1, 1, false)
	playerPlots[player] = nil
	player:SetAttribute("PlotId", nil)

	-- Resetar boxes do lote
	local boxesFolder = plot:FindFirstChild("Boxes")
	if boxesFolder then
		for b = 1, 3 do
			local boxModel = boxesFolder:FindFirstChild("Box_" .. b)
			if boxModel and boxModel:IsA("Model") then
				local isUnlocked = b == 1
				boxModel:SetAttribute("IsUnlocked", isUnlocked)
				local frontHazard = boxModel:FindFirstChild("FrontHazardStripe")
				if frontHazard and frontHazard:IsA("BasePart") then
					frontHazard.Color = if isUnlocked then Color3.fromRGB(220, 180, 40) else Color3.fromRGB(180, 50, 45)
				end
				local arch = boxModel:FindFirstChild("BoxArch")
				local gui = arch and arch:FindFirstChild("BoxGui")
				local label = gui and gui:FindFirstChild("BoxLabel")
				if label and label:IsA("TextLabel") then
					label.Text = if isUnlocked then "BOX 1  [ATIVO]" else string.format("BOX %d  [BLOQUEADO]", b)
					label.TextColor3 = if isUnlocked then Color3.fromRGB(240, 200, 60) else Color3.fromRGB(240, 80, 70)
				end
				local barrier = boxModel:FindFirstChild("BoxBarrier")
				if barrier and barrier:IsA("BasePart") then
					setBarrierUnlocked(barrier, isUnlocked)
				end
			end
		end
	end
end

function PlotService.GetPlot(player: Player): Model?
	local plot = playerPlots[player]
	if plot and plot.Parent then return plot end

	-- Fallback resiliente por OwnerUserId na pasta TycoonPlots
	local folder = Workspace:FindFirstChild("TycoonPlots")
	if folder then
		for _, p in folder:GetChildren() do
			if p:IsA("Model") and p:GetAttribute("OwnerUserId") == player.UserId then
				playerPlots[player] = p
				return p
			end
		end
	end
	return nil
end

function PlotService.GetPlotOrigin(player: Player): CFrame?
	local plot = PlotService.GetPlot(player)
	local origin = plot and plot:FindFirstChild("Origin")
	return if origin and origin:IsA("BasePart") then origin.CFrame else nil
end

function PlotService.start()
	local oldPlots = Workspace:FindFirstChild("TycoonPlots")
	if oldPlots then oldPlots:Destroy() end
	local folder = Instance.new("Folder")
	folder.Name = "TycoonPlots"
	folder.Parent = Workspace
	for index, position in PLOT_POSITIONS do
		local plot = createPlot(index, position)
		plot.Parent = folder
		table.insert(plots, plot)
	end
	Players.PlayerAdded:Connect(assignPlot)
	Players.PlayerRemoving:Connect(releasePlot)
	for _, player in Players:GetPlayers() do assignPlot(player) end
end

return PlotService
