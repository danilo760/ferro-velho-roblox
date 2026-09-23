--!strict

local Workspace = game:GetService("Workspace")

local RecyclingCenterService = {}

local DOCK_CFRAMES: {[number]: CFrame} = {
	[1] = CFrame.lookAt(Vector3.new(-12, 1.5, -12), Vector3.new(0, 1.5, 0)),
	[2] = CFrame.lookAt(Vector3.new(12, 1.5, -12), Vector3.new(0, 1.5, 0)),
	[3] = CFrame.lookAt(Vector3.new(-12, 1.5, 12), Vector3.new(0, 1.5, 0)),
	[4] = CFrame.lookAt(Vector3.new(12, 1.5, 12), Vector3.new(0, 1.5, 0)),
}

local function createPart(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.CanCollide = true
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function createCenterSign(parent: Instance)
	local pillar = createPart(
		parent,
		"CenterPillar",
		Vector3.new(2, 10, 2),
		CFrame.new(0, 6, 0),
		Color3.fromRGB(45, 48, 52),
		Enum.Material.Metal
	)

	local gui = Instance.new("BillboardGui")
	gui.Name = "CenterSign"
	gui.Size = UDim2.fromOffset(520, 110)
	gui.StudsOffset = Vector3.new(0, 6.5, 0)
	gui.AlwaysOnTop = true
	gui.Parent = pillar

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(24, 26, 29)
	label.BackgroundTransparency = 0.15
	label.BorderSizePixel = 0
	label.Text = "CENTRAL DE RECICLAGEM"
	label.TextColor3 = Color3.fromRGB(255, 210, 70)
	label.TextStrokeTransparency = 0.2
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.Parent = gui
end

function RecyclingCenterService.GetDockCFrame(plot: Model): CFrame
	local plotId = plot:GetAttribute("PlotId")
	assert(typeof(plotId) == "number", "PlotId is missing")
	local dockCFrame = DOCK_CFRAMES[plotId]
	assert(dockCFrame, "Recycling dock is missing for plot " .. tostring(plotId))
	return dockCFrame
end

function RecyclingCenterService.start()
	local oldCenter = Workspace:FindFirstChild("RecyclingCenter")
	if oldCenter then oldCenter:Destroy() end

	local model = Instance.new("Model")
	model.Name = "RecyclingCenter"
	model.Parent = Workspace

	local floor = createPart(
		model,
		"CenterFloor",
		Vector3.new(40, 1, 40),
		CFrame.new(0, 0.5, 0),
		Color3.fromRGB(58, 62, 67),
		Enum.Material.Concrete
	)
	model.PrimaryPart = floor

	createCenterSign(model)

	for plotId, dockCFrame in DOCK_CFRAMES do
		local marker = createPart(
			model,
			"DockMarker" .. plotId,
			Vector3.new(11, 0.15, 11),
			dockCFrame * CFrame.new(0, -0.575, 0),
			Color3.fromRGB(235, 175, 45),
			Enum.Material.Metal
		)
		marker.CanCollide = false
	end
end

return RecyclingCenterService
