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

local function createBox(plot: Model, boxIndex: number, position: Vector3): Model
	local boxModel = Instance.new("Model")
	boxModel.Name = "Box_" .. boxIndex
	boxModel:SetAttribute("BoxIndex", boxIndex)
	boxModel:SetAttribute("IsUnlocked", boxIndex == 1)

	local xOffset = BOX_X_OFFSETS[boxIndex]
	local boxPos = position + Vector3.new(xOffset, 0.1, -4)

	-- Piso demarcado do Box
	local pad = Instance.new("Part")
	pad.Name = "BoxPad"
	pad.Size = Vector3.new(13.5, 0.2, 22)
	pad.Position = boxPos
	pad.Anchored = true
	pad.Material = Enum.Material.Concrete
	pad.Color = Color3.fromRGB(56, 60, 64)
	pad.TopSurface = Enum.SurfaceType.Smooth
	pad.BottomSurface = Enum.SurfaceType.Smooth
	pad.Parent = boxModel

	local border = Instance.new("SelectionBox")
	border.Name = "BoxBorder"
	border.Adornee = pad
	border.Color3 = if boxIndex == 1 then Color3.fromRGB(80, 220, 120) else Color3.fromRGB(230, 80, 70)
	border.LineThickness = 0.06
	border.Parent = pad

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

	-- Arco / Placa de identificação do Box
	local arch = Instance.new("Part")
	arch.Name = "BoxArch"
	arch.Size = Vector3.new(11, 2.2, 0.5)
	arch.Position = boxPos + Vector3.new(0, 7.2, 11)
	arch.Anchored = true
	arch.Material = Enum.Material.Metal
	arch.Color = Color3.fromRGB(35, 38, 42)
	arch.Parent = boxModel

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
	label.TextColor3 = if boxIndex == 1 then Color3.fromRGB(100, 255, 140) else Color3.fromRGB(255, 100, 90)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.Parent = gui

	-- Barreira para Boxes Bloqueados (2 e 3)
	if boxIndex > 1 then
		local barrier = Instance.new("Part")
		barrier.Name = "BoxBarrier"
		barrier.Size = Vector3.new(13.5, 6.5, 0.5)
		barrier.Position = boxPos + Vector3.new(0, 3.4, 11)
		barrier.Anchored = true
		barrier.CanCollide = true
		barrier.Material = Enum.Material.Neon
		barrier.Color = Color3.fromRGB(230, 50, 45)
		barrier.Transparency = 0.55
		barrier.Parent = boxModel

		local barrierBb = Instance.new("BillboardGui")
		barrierBb.Name = "BarrierInfo"
		barrierBb.Size = UDim2.fromOffset(260, 50)
		barrierBb.StudsOffset = Vector3.new(0, 1.8, 0)
		barrierBb.AlwaysOnTop = true
		barrierBb.Parent = barrier

		local infoLabel = Instance.new("TextLabel")
		infoLabel.Size = UDim2.fromScale(1, 1)
		infoLabel.BackgroundTransparency = 1
		infoLabel.Text = string.format("🔒 BOX %d BLOQUEADO\nRequer: %s", boxIndex, BOX_REQUISITES[boxIndex])
		infoLabel.TextColor3 = Color3.fromRGB(255, 230, 130)
		infoLabel.TextStrokeColor3 = Color3.fromRGB(60, 10, 10)
		infoLabel.TextStrokeTransparency = 0.1
		infoLabel.TextScaled = true
		infoLabel.Font = Enum.Font.GothamBold
		infoLabel.Parent = barrierBb
	end

	boxModel.Parent = plot
	return boxModel
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
	pad.Color = Color3.fromRGB(72, 76, 80)
	pad.TopSurface = Enum.SurfaceType.Smooth
	pad.BottomSurface = Enum.SurfaceType.Smooth
	pad.Parent = model
	model.PrimaryPart = pad

	local border = Instance.new("SelectionBox")
	border.Name = "PlotBorder"
	border.Adornee = pad
	border.Color3 = Color3.fromRGB(240, 174, 55)
	border.LineThickness = 0.08
	border.SurfaceTransparency = 1
	border.Parent = pad

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
	sign.Size = Vector3.new(8, 4, 0.5)
	sign.Position = position + Vector3.new(0, 3, 23)
	sign.Anchored = true
	sign.Color = Color3.fromRGB(35, 38, 42)
	sign.Parent = model

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
	label.TextColor3 = Color3.fromRGB(255, 220, 115)
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

			local border = boxModel:FindFirstChild("BoxPad") and boxModel.BoxPad:FindFirstChild("BoxBorder")
			if border and border:IsA("SelectionBox") then
				border.Color3 = if isUnlocked then Color3.fromRGB(80, 220, 120) else Color3.fromRGB(230, 80, 70)
			end

			local arch = boxModel:FindFirstChild("BoxArch")
			local gui = arch and arch:FindFirstChild("BoxGui")
			local label = gui and gui:FindFirstChild("BoxLabel")
			if label and label:IsA("TextLabel") then
				label.Text = if isUnlocked then string.format("BOX %d  [ATIVO]", b) else string.format("BOX %d  [BLOQUEADO]", b)
				label.TextColor3 = if isUnlocked then Color3.fromRGB(100, 255, 140) else Color3.fromRGB(255, 100, 90)
			end

			local barrier = boxModel:FindFirstChild("BoxBarrier")
			if barrier and barrier:IsA("BasePart") then
				barrier.CanCollide = not isUnlocked
				barrier.Transparency = if isUnlocked then 1 else 0.55
				local bb = barrier:FindFirstChild("BarrierInfo")
				if bb and bb:IsA("BillboardGui") then
					bb.Enabled = not isUnlocked
				end
			end
		end
	end
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
	local plot = playerPlots[player]
	local boxes = plot and plot:FindFirstChild("Boxes")
	local box = boxes and boxes:FindFirstChild("Box_" .. boxIndex)
	local origin = box and box:FindFirstChild("BoxOrigin")
	return if origin and origin:IsA("BasePart") then origin.CFrame else nil
end

function PlotService.GetBoxHoistOrigin(player: Player, boxIndex: number): CFrame?
	local plot = playerPlots[player]
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

			player:GetAttributeChangedSignal("UnlockedBoxes"):Connect(function()
				PlotService.SyncBoxes(player)
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
	playerPlots[player] = nil
	player:SetAttribute("PlotId", nil)

	-- Resetar boxes do lote
	local boxesFolder = plot:FindFirstChild("Boxes")
	if boxesFolder then
		for b = 1, 3 do
			local boxModel = boxesFolder:FindFirstChild("Box_" .. b)
			if boxModel and boxModel:IsA("Model") then
				local isUnlocked = b == 1
				local arch = boxModel:FindFirstChild("BoxArch")
				local gui = arch and arch:FindFirstChild("BoxGui")
				local label = gui and gui:FindFirstChild("BoxLabel")
				if label and label:IsA("TextLabel") then
					label.Text = if isUnlocked then "BOX 1  [ATIVO]" else string.format("BOX %d  [BLOQUEADO]", b)
					label.TextColor3 = if isUnlocked then Color3.fromRGB(100, 255, 140) else Color3.fromRGB(255, 100, 90)
				end
				local barrier = boxModel:FindFirstChild("BoxBarrier")
				if barrier and barrier:IsA("BasePart") then
					barrier.CanCollide = not isUnlocked
					barrier.Transparency = if isUnlocked then 1 else 0.55
					local bb = barrier:FindFirstChild("BarrierInfo")
					if bb and bb:IsA("BillboardGui") then bb.Enabled = not isUnlocked end
				end
			end
		end
	end
end

function PlotService.GetPlot(player: Player): Model?
	return playerPlots[player]
end

function PlotService.GetPlotOrigin(player: Player): CFrame?
	local plot = playerPlots[player]
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
