--!strict

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local EnvironmentService = {}

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

local function setupLighting()
	-- Iluminação Golden Hour / Fim de tarde cinematográfico no ferro-velho
	Lighting.ClockTime = 17.35
	Lighting.GeographicLatitude = 38.5
	Lighting.Brightness = 2.4
	Lighting.Ambient = Color3.fromRGB(75, 70, 68)
	Lighting.OutdoorAmbient = Color3.fromRGB(135, 115, 95)
	Lighting.ShadowSoftness = 0.25
	Lighting.GlobalShadows = true

	-- Limpar efeitos prévios
	for _, child in Lighting:GetChildren() do
		if child:IsA("PostProcessEffect") or child:IsA("Atmosphere") or child:IsA("Sky") then
			child:Destroy()
		end
	end

	-- Névoa volumétrica industrial com tom de poeira e fuligem suspensa
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Name = "ScrapAtmosphere"
	atmosphere.Density = 0.32
	atmosphere.Offset = 0.22
	atmosphere.Haze = 2.2
	atmosphere.Color = Color3.fromRGB(220, 190, 155)
	atmosphere.Decay = Color3.fromRGB(140, 110, 85)
	atmosphere.Glare = 0.3
	atmosphere.Parent = Lighting

	-- Correção de cor com contraste marcante e calor metálico
	local colorCorrection = Instance.new("ColorCorrectionEffect")
	colorCorrection.Name = "IndustrialColorGrade"
	colorCorrection.Brightness = 0.02
	colorCorrection.Contrast = 0.16
	colorCorrection.Saturation = 0.10
	colorCorrection.TintColor = Color3.fromRGB(255, 245, 235)
	colorCorrection.Parent = Lighting

	-- Bloom suave para lâmpadas industriais e reflexos metálicos
	local bloom = Instance.new("BloomEffect")
	bloom.Name = "IndustrialBloom"
	bloom.Intensity = 0.35
	bloom.Size = 22
	bloom.Threshold = 0.88
	bloom.Parent = Lighting

	-- Raios de sol atravessando a névoa do ferro-velho
	local sunRays = Instance.new("SunRaysEffect")
	sunRays.Name = "SunsetRays"
	sunRays.Intensity = 0.12
	sunRays.Spread = 0.75
	sunRays.Parent = Lighting

	-- Céu dourado de fim de tarde
	local sky = Instance.new("Sky")
	sky.Name = "ScrapYardSky"
	sky.CelestialBodiesShown = true
	sky.SunAngularSize = 15
	sky.SkyboxBk = "rbxassetid://600830446"
	sky.SkyboxDn = "rbxassetid://600831635"
	sky.SkyboxFt = "rbxassetid://600832720"
	sky.SkyboxLf = "rbxassetid://600833863"
	sky.SkyboxRt = "rbxassetid://600835177"
	sky.SkyboxUp = "rbxassetid://600836238"
	sky.Parent = Lighting
end

local function buildYardGround(parent: Model)
	-- Terreno principal de terra batida, cascalho e brita (260x260 studs)
	local mainGround = createPart(
		parent,
		"ScrapYardGround",
		Vector3.new(260, 1, 260),
		CFrame.new(0, -0.05, 0),
		Enum.Material.Ground,
		Color3.fromRGB(58, 52, 46),
		true,
		true
	)

	-- Camadas de cascalho e brita espalhadas
	local gravelPatches = {
		Vector3.new(-45, 0.02, 10),
		Vector3.new(45, 0.02, -10),
		Vector3.new(-10, 0.02, -45),
		Vector3.new(10, 0.02, 45),
		Vector3.new(0, 0.02, 0),
	}
	for i, pos in gravelPatches do
		createPart(
			parent,
			"GravelPatch_" .. i,
			Vector3.new(38, 0.1, 38),
			CFrame.new(pos) * CFrame.Angles(0, math.rad(i * 35), 0),
			Enum.Material.Slate,
			Color3.fromRGB(72, 68, 62),
			true,
			false
		)
	end

	-- Estradas de asfalto rachado conectando a Central aos 4 Lotes
	local roadTargets = {
		Vector3.new(-55, 0, -55),
		Vector3.new(55, 0, -55),
		Vector3.new(-55, 0, 55),
		Vector3.new(55, 0, 55),
	}
	for i, target in roadTargets do
		local dir = (target - Vector3.new(0, 0, 0))
		local midPoint = Vector3.new(0, 0.08, 0) + (dir * 0.5)
		local length = dir.Magnitude
		local angle = math.atan2(dir.X, dir.Z)

		local road = createPart(
			parent,
			"AsphaltRoad_" .. i,
			Vector3.new(12, 0.18, length - 24),
			CFrame.new(midPoint) * CFrame.Angles(0, angle, 0),
			Enum.Material.Concrete,
			Color3.fromRGB(42, 44, 46),
			true,
			true
		)

		-- Faixa central tracejada desbotada
		local dash = createPart(
			parent,
			"RoadStripe_" .. i,
			Vector3.new(0.6, 0.22, length - 26),
			CFrame.new(midPoint) * CFrame.Angles(0, angle, 0),
			Enum.Material.SmoothPlastic,
			Color3.fromRGB(180, 160, 80),
			true,
			false
		)
		dash.Transparency = 0.35
	end
end

local function buildOilDrum(parent: Instance, pos: Vector3, color: Color3, rotation: number?)
	local drumModel = Instance.new("Model")
	drumModel.Name = "OilDrum"

	local drum = createPart(
		drumModel,
		"DrumBody",
		Vector3.new(3.6, 2.4, 2.4),
		CFrame.new(pos) * CFrame.Angles(0, math.rad(rotation or 0), 0),
		Enum.Material.CorrodedMetal,
		color,
		true,
		true
	)
	drum.Shape = Enum.PartType.Cylinder
	drum.CFrame = drum.CFrame * CFrame.Angles(0, 0, math.rad(90))

	-- Faixa de aviso central
	local stripe = createPart(
		drumModel,
		"DrumStripe",
		Vector3.new(0.6, 2.45, 2.45),
		drum.CFrame,
		Enum.Material.Metal,
		Color3.fromRGB(220, 170, 30),
		true,
		false
	)
	stripe.Shape = Enum.PartType.Cylinder

	drumModel.Parent = parent
end

local function buildTirePile(parent: Instance, pos: Vector3, count: number)
	local pileModel = Instance.new("Model")
	pileModel.Name = "TirePile"

	for i = 1, count do
		local yOffset = 0.5 + (i - 1) * 0.95
		local jitterX = (math.sin(i * 1.7) * 0.25)
		local jitterZ = (math.cos(i * 2.3) * 0.25)
		local tire = createPart(
			pileModel,
			"Tire_" .. i,
			Vector3.new(1.0, 3.2, 3.2),
			CFrame.new(pos + Vector3.new(jitterX, yOffset, jitterZ)) * CFrame.Angles(0, 0, math.rad(90)),
			Enum.Material.Rubber,
			Color3.fromRGB(24, 24, 26),
			true,
			true
		)
		tire.Shape = Enum.PartType.Cylinder
	end

	pileModel.Parent = parent
end

local function buildShippingContainer(parent: Instance, pos: Vector3, rotationY: number, color: Color3)
	local container = Instance.new("Model")
	container.Name = "ShippingContainer"

	local cf = CFrame.new(pos) * CFrame.Angles(0, math.rad(rotationY), 0)

	-- Caixa principal corrugada
	createPart(
		container,
		"ContainerBody",
		Vector3.new(9.5, 9.0, 22),
		cf * CFrame.new(0, 4.5, 0),
		Enum.Material.CorrodedMetal,
		color,
		true,
		true
	)

	-- Molduras de canto reforçadas
	local frameColor = Color3.fromRGB(35, 38, 42)
	for _, xOffset in { -4.6, 4.6 } do
		for _, zOffset in { -10.8, 10.8 } do
			createPart(
				container,
				"CornerPost",
				Vector3.new(0.6, 9.2, 0.6),
				cf * CFrame.new(xOffset, 4.6, zOffset),
				Enum.Material.DiamondPlate,
				frameColor,
				true,
				true
			)
		end
	end

	-- Portas traseiras de metal
	local door = createPart(
		container,
		"ContainerDoor",
		Vector3.new(8.8, 8.4, 0.3),
		cf * CFrame.new(0, 4.5, 11),
		Enum.Material.Metal,
		Color3.fromRGB(40, 44, 48),
		true,
		true
	)

	-- Tranca de alavanca industrial
	createPart(
		container,
		"DoorLatch",
		Vector3.new(0.3, 6.0, 0.4),
		cf * CFrame.new(0, 4.5, 11.2),
		Enum.Material.Metal,
		Color3.fromRGB(200, 180, 50),
		true,
		false
	)

	container.Parent = parent
end

local function buildScrapCube(parent: Instance, pos: Vector3, rotationY: number, color: Color3)
	-- Bloco de carro prensado/esmagado (sucata compactada)
	local cube = createPart(
		parent,
		"ScrapCube",
		Vector3.new(5.5, 4.0, 5.5),
		CFrame.new(pos) * CFrame.Angles(0, math.rad(rotationY), 0),
		Enum.Material.CorrodedMetal,
		color,
		true,
		true
	)

	-- Faixas de arame de amarração do fardo
	for _, yOff in { -1.2, 1.2 } do
		createPart(
			parent,
			"BindingWire",
			Vector3.new(5.6, 0.2, 5.6),
			cube.CFrame * CFrame.new(0, yOff, 0),
			Enum.Material.DiamondPlate,
			Color3.fromRGB(30, 30, 32),
			true,
			false
		)
	end
end

local function buildIndustrialLampPost(parent: Instance, pos: Vector3, lightColor: Color3)
	local poleModel = Instance.new("Model")
	poleModel.Name = "IndustrialLampPost"

	-- Mastro de aço
	local pole = createPart(
		poleModel,
		"Pole",
		Vector3.new(1.0, 20, 1.0),
		CFrame.new(pos + Vector3.new(0, 10, 0)),
		Enum.Material.DiamondPlate,
		Color3.fromRGB(45, 48, 52),
		true,
		true
	)

	-- Braço curvo superior
	createPart(
		poleModel,
		"Arm",
		Vector3.new(0.8, 0.8, 5.5),
		CFrame.new(pos + Vector3.new(0, 19.5, -2.2)),
		Enum.Material.Metal,
		Color3.fromRGB(45, 48, 52),
		true,
		false
	)

	-- Luminária cônica
	local hood = createPart(
		poleModel,
		"LampHood",
		Vector3.new(2.4, 0.8, 2.4),
		CFrame.new(pos + Vector3.new(0, 19.0, -4.5)),
		Enum.Material.Metal,
		Color3.fromRGB(35, 38, 42),
		true,
		false
	)

	local bulb = createPart(
		poleModel,
		"Bulb",
		Vector3.new(1.4, 0.3, 1.4),
		CFrame.new(pos + Vector3.new(0, 18.6, -4.5)),
		Enum.Material.Neon,
		lightColor,
		true,
		false
	)

	local light = Instance.new("SpotLight")
	light.Name = "PostLight"
	light.Color = lightColor
	light.Brightness = 3.5
	light.Range = 45
	light.Angle = 65
	light.Face = Enum.NormalId.Bottom
	light.Shadows = true
	light.Parent = bulb

	poleModel.Parent = parent
end

local function buildYardPerimeterAndProps(parent: Model)
	local propsFolder = Instance.new("Folder")
	propsFolder.Name = "YardProps"
	propsFolder.Parent = parent

	-- Contêineres de carga enferrujados nos cantos do pátio
	buildShippingContainer(propsFolder, Vector3.new(-92, 0.5, 0), 12, Color3.fromRGB(135, 60, 45))   -- Rust Red
	buildShippingContainer(propsFolder, Vector3.new(92, 0.5, 0), -15, Color3.fromRGB(45, 75, 110))   -- Faded Navy
	buildShippingContainer(propsFolder, Vector3.new(0, 0.5, -92), 92, Color3.fromRGB(65, 80, 55))    -- Army Olive
	buildShippingContainer(propsFolder, Vector3.new(-85, 0.5, -85), 45, Color3.fromRGB(120, 85, 45)) -- Dirty Ochre

	-- Pilhas de fardos de sucata compactada (cubos de carros prensados) formando barreiras
	local scrapColors = {
		Color3.fromRGB(130, 65, 45),
		Color3.fromRGB(50, 70, 90),
		Color3.fromRGB(85, 85, 80),
		Color3.fromRGB(110, 45, 40),
	}
	for i = 1, 16 do
		local angle = (i / 16) * math.pi * 2
		local radius = 112
		local x = math.cos(angle) * radius
		local z = math.sin(angle) * radius
		local color = scrapColors[(i % #scrapColors) + 1]
		buildScrapCube(propsFolder, Vector3.new(x, 2.0, z), i * 22, color)
		if i % 2 == 0 then
			buildScrapCube(propsFolder, Vector3.new(x, 5.8, z), i * 45 + 10, color)
		end
	end

	-- Pilhas de pneus ao longo dos caminhos e pátio
	buildTirePile(propsFolder, Vector3.new(-32, 0, -32), 4)
	buildTirePile(propsFolder, Vector3.new(32, 0, -32), 5)
	buildTirePile(propsFolder, Vector3.new(-32, 0, 32), 3)
	buildTirePile(propsFolder, Vector3.new(32, 0, 32), 5)
	buildTirePile(propsFolder, Vector3.new(-68, 0, 15), 4)
	buildTirePile(propsFolder, Vector3.new(68, 0, -15), 4)

	-- Tambores de combustível e óleo com faixas de perigo
	local drumColors = {
		Color3.fromRGB(140, 50, 40),
		Color3.fromRGB(40, 80, 120),
		Color3.fromRGB(160, 120, 35),
		Color3.fromRGB(45, 50, 55),
	}
	local drumPositions = {
		Vector3.new(-26, 0.5, -16),
		Vector3.new(-28, 0.5, -18),
		Vector3.new(26, 0.5, -16),
		Vector3.new(28, 0.5, -14),
		Vector3.new(-26, 0.5, 20),
		Vector3.new(26, 0.5, 20),
		Vector3.new(0, 0.5, -34),
		Vector3.new(3, 0.5, -35),
	}
	for i, pos in drumPositions do
		buildOilDrum(propsFolder, pos, drumColors[(i % #drumColors) + 1], i * 30)
	end

	-- Postes de iluminação industrial com luz âmbar quente
	local postPositions = {
		Vector3.new(-38, 0, -38),
		Vector3.new(38, 0, -38),
		Vector3.new(-38, 0, 38),
		Vector3.new(38, 0, 38),
	}
	for _, pos in postPositions do
		buildIndustrialLampPost(propsFolder, pos, Color3.fromRGB(255, 215, 140))
	end
end

function EnvironmentService.start()
	setupLighting()

	local oldYard = Workspace:FindFirstChild("ScrapYardEnvironment")
	if oldYard then oldYard:Destroy() end

	local yardModel = Instance.new("Model")
	yardModel.Name = "ScrapYardEnvironment"

	buildYardGround(yardModel)
	buildYardPerimeterAndProps(yardModel)

	yardModel.Parent = Workspace
end

return EnvironmentService
