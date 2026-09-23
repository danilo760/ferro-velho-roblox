--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local PlotService = {}

local PLOT_SIZE = Vector3.new(48, 1, 48)
local PLOT_POSITIONS = {
	Vector3.new(-55, 0.5, -55),
	Vector3.new(55, 0.5, -55),
	Vector3.new(-55, 0.5, 55),
	Vector3.new(55, 0.5, 55),
}

local plots: {Model} = {}
local playerPlots: {[Player]: Model} = {}

local function setPlotLabel(plot: Model, text: string)
	local sign = plot:FindFirstChild("OwnerSign")
	local gui = sign and sign:FindFirstChild("OwnerGui")
	local label = gui and gui:FindFirstChild("OwnerLabel")
	if label and label:IsA("TextLabel") then label.Text = text end
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

	model.Parent = Workspace
	return model
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
			player.CharacterAdded:Connect(function(character)
				task.defer(teleportToPlot, player, character)
			end)
			if player.Character then task.defer(teleportToPlot, player, player.Character) end
			return
		end
	end
	warn("No free tycoon plot for " .. player.Name)
end

local function releasePlot(player: Player)
	local plot = playerPlots[player]
	if not plot then return end
	plot:SetAttribute("OwnerUserId", 0)
	setPlotLabel(plot, "LOTE LIVRE")
	playerPlots[player] = nil
	player:SetAttribute("PlotId", nil)
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
