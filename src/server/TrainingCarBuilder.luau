--!strict

local TrainingCarBuilder = {}
local DEFAULT_CAR_ORIGIN = Vector3.new(0, 0, -28)

local function createPart(parent: Model, carCFrame: CFrame, name: string, size: Vector3, localCFrame: CFrame, color: Color3, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = carCFrame * localCFrame
	part.Anchored = true
	part.CanCollide = true
	part.Material = material or Enum.Material.Metal
	part.Color = color
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

export type CustomCarOptions = {
	ModelId: string?,
	BodyColor: Color3?,
	AccentColor: Color3?,
	InstalledParts: {string}?,
	ScrapMultiplier: number?,
	ConservationName: string?,
}

function TrainingCarBuilder.create(originCFrame: CFrame?, carName: string?, options: CustomCarOptions?): Model
	local car = Instance.new("Model")
	car.Name = carName or "TrainingCar01"
	local carCFrame = originCFrame or CFrame.new(DEFAULT_CAR_ORIGIN)

	local modelId = (options and options.ModelId) or "Sedan90s"
	local conservation = (options and options.ConservationName) or "Usado"

	-- Seleção de materiais com base no estado de conservação
	local bodyMaterial = Enum.Material.Metal
	local darkMetalMaterial = Enum.Material.DiamondPlate
	if conservation == "Sucateado" or conservation == "Danificado" then
		bodyMaterial = Enum.Material.CorrodedMetal
		darkMetalMaterial = Enum.Material.CorrodedMetal
	elseif conservation == "Preservado" or conservation == "Excelente" then
		bodyMaterial = Enum.Material.Metal
		darkMetalMaterial = Enum.Material.Metal
	end

	local bodyColor = (options and options.BodyColor) or Color3.fromRGB(74, 82, 88)
	local darkMetal = (options and options.AccentColor) or Color3.fromRGB(38, 42, 45)
	local glassColor = Color3.fromRGB(32, 52, 62)
	local tireColor = Color3.fromRGB(22, 22, 24)
	local rimColor = Color3.fromRGB(130, 135, 140)
	local lightColor = Color3.fromRGB(255, 230, 140)

	local scrapMultiplier = (options and options.ScrapMultiplier) or 1
	car:SetAttribute("ScrapMultiplier", scrapMultiplier)
	car:SetAttribute("ModelId", modelId)

	local partsFilter: {[string]: boolean}? = nil
	if options and options.InstalledParts then
		partsFilter = {}
		for _, name in options.InstalledParts do
			partsFilter[name] = true
		end
	end

	local function shouldBuild(partName: string): boolean
		if not partsFilter then return true end
		return partsFilter[partName] == true
	end

	-- =========================================================================
	-- 1. MODELO: PICAPE RUST '85 (RustPickup) - Cabine dianteira + Caçamba aberta
	-- =========================================================================
	if modelId == "RustPickup" then
		local chassis = createPart(car, carCFrame, "Chassis", Vector3.new(8.0, 0.75, 14.8), CFrame.new(0, 2.35, 0), darkMetal, darkMetalMaterial)
		car.PrimaryPart = chassis

		-- Cabine e Caçamba
		createPart(car, carCFrame, "BodyFront", Vector3.new(7.8, 1.45, 3.6), CFrame.new(0, 3.15, -4.8), bodyColor, bodyMaterial)
		createPart(car, carCFrame, "BodyRear", Vector3.new(7.8, 1.45, 4.8), CFrame.new(0, 3.15, 4.4), bodyColor, bodyMaterial)
		createPart(car, carCFrame, "Roof", Vector3.new(7.0, 0.35, 4.2), CFrame.new(0, 5.85, -1.0), bodyColor, bodyMaterial)

		-- Paredes laterais da caçamba aberta
		createPart(car, carCFrame, "BedSideLeft", Vector3.new(0.4, 1.6, 6.2), CFrame.new(-3.7, 4.15, 4.2), bodyColor, bodyMaterial)
		createPart(car, carCFrame, "BedSideRight", Vector3.new(0.4, 1.6, 6.2), CFrame.new(3.7, 4.15, 4.2), bodyColor, bodyMaterial)
		createPart(car, carCFrame, "BedFloor", Vector3.new(7.0, 0.25, 6.0), CFrame.new(0, 2.9, 4.2), darkMetal, Enum.Material.DiamondPlate)

		-- Para-choque dianteiro tubular de aço reforçado
		createPart(car, carCFrame, "BumperFront", Vector3.new(8.4, 0.8, 0.6), CFrame.new(0, 2.6, -6.8), darkMetal, Enum.Material.DiamondPlate)

		if shouldBuild("Hood") then
			createPart(car, carCFrame, "Hood", Vector3.new(7.4, 0.35, 3.3), CFrame.new(0, 3.95, -4.8), bodyColor, bodyMaterial)
		end
		if shouldBuild("DoorLeft") then
			createPart(car, carCFrame, "DoorLeft", Vector3.new(0.35, 2.85, 3.8), CFrame.new(-3.85, 4.3, -1.0), bodyColor, bodyMaterial)
		end
		if shouldBuild("DoorRight") then
			createPart(car, carCFrame, "DoorRight", Vector3.new(0.35, 2.85, 3.8), CFrame.new(3.85, 4.3, -1.0), bodyColor, bodyMaterial)
		end
		if shouldBuild("Trunk") then
			-- Tampa da Caçamba (Tailgate)
			createPart(car, carCFrame, "Trunk", Vector3.new(7.4, 1.6, 0.4), CFrame.new(0, 4.15, 7.3), bodyColor, bodyMaterial)
		end

		local windshield = createPart(car, carCFrame, "Windshield", Vector3.new(6.8, 2.0, 0.2), CFrame.new(0, 4.85, -2.9) * CFrame.Angles(math.rad(-14), 0, 0), glassColor, Enum.Material.Glass)
		windshield.Transparency = 0.25
		local rearWindow = createPart(car, carCFrame, "RearWindow", Vector3.new(6.8, 1.6, 0.2), CFrame.new(0, 4.95, 0.95), glassColor, Enum.Material.Glass)
		rearWindow.Transparency = 0.25

		local wheelPositions = {
			WheelFrontLeft = Vector3.new(-4.1, 1.95, -4.5),
			WheelFrontRight = Vector3.new(4.1, 1.95, -4.5),
			WheelRearLeft = Vector3.new(-4.1, 1.95, 4.5),
			WheelRearRight = Vector3.new(4.1, 1.95, 4.5),
		}
		for wheelName, position in wheelPositions do
			if shouldBuild(wheelName) then
				local wheel = createPart(car, carCFrame, wheelName, Vector3.new(1.3, 3.2, 3.2), CFrame.new(position), tireColor, Enum.Material.Rubber)
				wheel.Shape = Enum.PartType.Cylinder
				local side = if position.X < 0 then -1 else 1
				local rim = createPart(car, carCFrame, wheelName .. "Rim", Vector3.new(0.15, 1.8, 1.8), CFrame.new(position + Vector3.new(0.66 * side, 0, 0)), rimColor, Enum.Material.Metal)
				rim.Shape = Enum.PartType.Cylinder
				rim.CanCollide = false
				rim.Massless = true
				rim.Anchored = false
				local rimWeld = Instance.new("WeldConstraint")
				rimWeld.Name = "RimWeld"
				rimWeld.Part0 = wheel
				rimWeld.Part1 = rim
				rimWeld.Parent = rim
			end
		end

		createPart(car, carCFrame, "Engine", Vector3.new(5.4, 1.35, 2.6), CFrame.new(0, 3.95, -4.7), Color3.fromRGB(48, 52, 56), Enum.Material.Metal)
		if shouldBuild("Battery") then
			createPart(car, carCFrame, "Battery", Vector3.new(1.35, 0.85, 1.05), CFrame.new(2.4, 4.75, -4.7), Color3.fromRGB(28, 30, 34), Enum.Material.SmoothPlastic)
		end
		if shouldBuild("HeadlightLeft") then
			createPart(car, carCFrame, "HeadlightLeft", Vector3.new(1.6, 0.65, 0.25), CFrame.new(-2.5, 3.35, -6.65), lightColor, Enum.Material.Glass)
		end
		if shouldBuild("HeadlightRight") then
			createPart(car, carCFrame, "HeadlightRight", Vector3.new(1.6, 0.65, 0.25), CFrame.new(2.5, 3.35, -6.65), lightColor, Enum.Material.Glass)
		end

	-- =========================================================================
	-- 2. MODELO: MUSCLE CAR '72 V8 (MuscleCar72) - Capô longo, scoop, fastback
	-- =========================================================================
	elseif modelId == "MuscleCar72" then
		local chassis = createPart(car, carCFrame, "Chassis", Vector3.new(7.8, 0.60, 14.4), CFrame.new(0, 2.15, 0), darkMetal, darkMetalMaterial)
		car.PrimaryPart = chassis

		createPart(car, carCFrame, "BodyFront", Vector3.new(7.6, 1.15, 4.4), CFrame.new(0, 2.85, -4.8), bodyColor, bodyMaterial)
		createPart(car, carCFrame, "BodyRear", Vector3.new(7.6, 1.15, 3.8), CFrame.new(0, 2.85, 4.8), bodyColor, bodyMaterial)
		createPart(car, carCFrame, "Roof", Vector3.new(6.6, 0.30, 4.6), CFrame.new(0, 4.95, 0.4), bodyColor, bodyMaterial)

		-- Aerofólio traseiro estilo ducktail
		createPart(car, carCFrame, "RearSpoiler", Vector3.new(7.2, 0.25, 0.8), CFrame.new(0, 3.75, 6.7), darkMetal, Enum.Material.Metal)

		-- Escapamento duplo lateral de aço
		createPart(car, carCFrame, "ExhaustLeft", Vector3.new(0.3, 0.3, 5.0), CFrame.new(-3.95, 2.05, 1.5), darkMetal, Enum.Material.Metal)
		createPart(car, carCFrame, "ExhaustRight", Vector3.new(0.3, 0.3, 5.0), CFrame.new(3.95, 2.05, 1.5), darkMetal, Enum.Material.Metal)

		if shouldBuild("Hood") then
			local hoodPart = createPart(car, carCFrame, "Hood", Vector3.new(7.2, 0.30, 4.1), CFrame.new(0, 3.5, -4.8), bodyColor, bodyMaterial)
			-- Air Scoop no capô (tomada de ar esportiva)
			local scoop = createPart(car, carCFrame, "HoodScoop", Vector3.new(2.4, 0.45, 2.2), CFrame.new(0, 3.85, -4.5), darkMetal, Enum.Material.Metal)
			scoop.CanCollide = false
			scoop.Massless = true
			scoop.Anchored = false
			local scoopWeld = Instance.new("WeldConstraint")
			scoopWeld.Name = "ScoopWeld"
			scoopWeld.Part0 = hoodPart
			scoopWeld.Part1 = scoop
			scoopWeld.Parent = scoop
		end
		if shouldBuild("DoorLeft") then
			createPart(car, carCFrame, "DoorLeft", Vector3.new(0.30, 2.30, 4.2), CFrame.new(-3.75, 3.65, 0.2), bodyColor, bodyMaterial)
		end
		if shouldBuild("DoorRight") then
			createPart(car, carCFrame, "DoorRight", Vector3.new(0.30, 2.30, 4.2), CFrame.new(3.75, 3.65, 0.2), bodyColor, bodyMaterial)
		end
		if shouldBuild("Trunk") then
			createPart(car, carCFrame, "Trunk", Vector3.new(7.2, 0.30, 2.8), CFrame.new(0, 3.5, 5.2), bodyColor, bodyMaterial)
		end

		local windshield = createPart(car, carCFrame, "Windshield", Vector3.new(6.4, 1.75, 0.2), CFrame.new(0, 4.25, -2.0) * CFrame.Angles(math.rad(-22), 0, 0), glassColor, Enum.Material.Glass)
		windshield.Transparency = 0.25
		local rearWindow = createPart(car, carCFrame, "RearWindow", Vector3.new(6.4, 1.85, 0.2), CFrame.new(0, 4.15, 2.9) * CFrame.Angles(math.rad(24), 0, 0), glassColor, Enum.Material.Glass)
		rearWindow.Transparency = 0.25

		-- Rodas: Traseiras mais grossas e largas (estilo drag/muscle)
		local wheels = {
			{ Name = "WheelFrontLeft", Pos = Vector3.new(-4.0, 1.65, -4.6), Thick = 1.15, Diam = 2.7 },
			{ Name = "WheelFrontRight", Pos = Vector3.new(4.0, 1.65, -4.6), Thick = 1.15, Diam = 2.7 },
			{ Name = "WheelRearLeft", Pos = Vector3.new(-4.1, 1.75, 4.5), Thick = 1.45, Diam = 3.0 },
			{ Name = "WheelRearRight", Pos = Vector3.new(4.1, 1.75, 4.5), Thick = 1.45, Diam = 3.0 },
		}
		for _, w in wheels do
			if shouldBuild(w.Name) then
				local wheel = createPart(car, carCFrame, w.Name, Vector3.new(w.Thick, w.Diam, w.Diam), CFrame.new(w.Pos), tireColor, Enum.Material.Rubber)
				wheel.Shape = Enum.PartType.Cylinder
				local side = if w.Pos.X < 0 then -1 else 1
				local rim = createPart(car, carCFrame, w.Name .. "Rim", Vector3.new(0.12, w.Diam * 0.58, w.Diam * 0.58), CFrame.new(w.Pos + Vector3.new((w.Thick * 0.5 + 0.05) * side, 0, 0)), rimColor, Enum.Material.Metal)
				rim.Shape = Enum.PartType.Cylinder
				rim.CanCollide = false
				rim.Massless = true
				rim.Anchored = false
				local rimWeld = Instance.new("WeldConstraint")
				rimWeld.Name = "RimWeld"
				rimWeld.Part0 = wheel
				rimWeld.Part1 = rim
				rimWeld.Parent = rim
			end
		end

		createPart(car, carCFrame, "Engine", Vector3.new(5.4, 1.25, 2.6), CFrame.new(0, 3.6, -4.6), Color3.fromRGB(50, 52, 56), Enum.Material.Metal)
		if shouldBuild("Battery") then
			createPart(car, carCFrame, "Battery", Vector3.new(1.25, 0.80, 0.95), CFrame.new(2.3, 4.35, -4.6), Color3.fromRGB(30, 32, 36), Enum.Material.SmoothPlastic)
		end
		if shouldBuild("HeadlightLeft") then
			createPart(car, carCFrame, "HeadlightLeft", Vector3.new(1.4, 0.55, 0.25), CFrame.new(-2.3, 3.05, -6.85), lightColor, Enum.Material.Glass)
		end
		if shouldBuild("HeadlightRight") then
			createPart(car, carCFrame, "HeadlightRight", Vector3.new(1.4, 0.55, 0.25), CFrame.new(2.3, 3.05, -6.85), lightColor, Enum.Material.Glass)
		end

	-- =========================================================================
	-- 3. MODELO: HATCH COMPACTO '98 (CompactHatch) - 2 Volumes, traseira reta
	-- =========================================================================
	elseif modelId == "CompactHatch" then
		local chassis = createPart(car, carCFrame, "Chassis", Vector3.new(7.2, 0.65, 11.8), CFrame.new(0, 2.25, 0), darkMetal, darkMetalMaterial)
		car.PrimaryPart = chassis

		createPart(car, carCFrame, "BodyFront", Vector3.new(7.0, 1.30, 2.8), CFrame.new(0, 3.05, -4.2), bodyColor, bodyMaterial)
		createPart(car, carCFrame, "BodyRear", Vector3.new(7.0, 1.30, 2.8), CFrame.new(0, 3.05, 3.8), bodyColor, bodyMaterial)
		createPart(car, carCFrame, "Roof", Vector3.new(6.4, 0.35, 5.6), CFrame.new(0, 5.45, 0.2), bodyColor, bodyMaterial)

		-- Para-choques plásticos escuros característicos de compactos dos anos 90
		createPart(car, carCFrame, "BumperFront", Vector3.new(7.4, 0.8, 0.5), CFrame.new(0, 2.5, -5.7), darkMetal, Enum.Material.SmoothPlastic)
		createPart(car, carCFrame, "BumperRear", Vector3.new(7.4, 0.8, 0.5), CFrame.new(0, 2.5, 5.5), darkMetal, Enum.Material.SmoothPlastic)

		if shouldBuild("Hood") then
			createPart(car, carCFrame, "Hood", Vector3.new(6.6, 0.30, 2.6), CFrame.new(0, 3.75, -4.2), bodyColor, bodyMaterial)
		end
		if shouldBuild("DoorLeft") then
			createPart(car, carCFrame, "DoorLeft", Vector3.new(0.30, 2.50, 4.4), CFrame.new(-3.55, 3.95, 0.1), bodyColor, bodyMaterial)
		end
		if shouldBuild("DoorRight") then
			createPart(car, carCFrame, "DoorRight", Vector3.new(0.30, 2.50, 4.4), CFrame.new(3.55, 3.95, 0.1), bodyColor, bodyMaterial)
		end
		if shouldBuild("Trunk") then
			-- Porta-malas vertical estilo hatchback
			createPart(car, carCFrame, "Trunk", Vector3.new(6.6, 2.2, 0.35), CFrame.new(0, 4.25, 5.1), bodyColor, bodyMaterial)
		end

		local windshield = createPart(car, carCFrame, "Windshield", Vector3.new(6.2, 1.85, 0.2), CFrame.new(0, 4.45, -2.3) * CFrame.Angles(math.rad(-16), 0, 0), glassColor, Enum.Material.Glass)
		windshield.Transparency = 0.25
		local rearWindow = createPart(car, carCFrame, "RearWindow", Vector3.new(6.2, 1.60, 0.2), CFrame.new(0, 4.55, 4.8) * CFrame.Angles(math.rad(12), 0, 0), glassColor, Enum.Material.Glass)
		rearWindow.Transparency = 0.25

		local wheelPositions = {
			WheelFrontLeft = Vector3.new(-3.7, 1.75, -3.8),
			WheelFrontRight = Vector3.new(3.7, 1.75, -3.8),
			WheelRearLeft = Vector3.new(-3.7, 1.75, 3.8),
			WheelRearRight = Vector3.new(3.7, 1.75, 3.8),
		}
		for wheelName, position in wheelPositions do
			if shouldBuild(wheelName) then
				local wheel = createPart(car, carCFrame, wheelName, Vector3.new(1.10, 2.7, 2.7), CFrame.new(position), tireColor, Enum.Material.Rubber)
				wheel.Shape = Enum.PartType.Cylinder
				local side = if position.X < 0 then -1 else 1
				local rim = createPart(car, carCFrame, wheelName .. "Rim", Vector3.new(0.12, 1.5, 1.5), CFrame.new(position + Vector3.new(0.56 * side, 0, 0)), rimColor, Enum.Material.Metal)
				rim.Shape = Enum.PartType.Cylinder
				rim.CanCollide = false
				rim.Massless = true
				rim.Anchored = false
				local rimWeld = Instance.new("WeldConstraint")
				rimWeld.Name = "RimWeld"
				rimWeld.Part0 = wheel
				rimWeld.Part1 = rim
				rimWeld.Parent = rim
			end
		end

		createPart(car, carCFrame, "Engine", Vector3.new(4.8, 1.10, 2.2), CFrame.new(0, 3.75, -4.1), Color3.fromRGB(42, 45, 48), Enum.Material.Metal)
		if shouldBuild("Battery") then
			createPart(car, carCFrame, "Battery", Vector3.new(1.20, 0.75, 0.90), CFrame.new(2.1, 4.4, -4.1), Color3.fromRGB(30, 32, 36), Enum.Material.SmoothPlastic)
		end
		if shouldBuild("HeadlightLeft") then
			createPart(car, carCFrame, "HeadlightLeft", Vector3.new(1.35, 0.50, 0.25), CFrame.new(-2.1, 3.15, -5.55), lightColor, Enum.Material.Glass)
		end
		if shouldBuild("HeadlightRight") then
			createPart(car, carCFrame, "HeadlightRight", Vector3.new(1.35, 0.50, 0.25), CFrame.new(2.1, 3.15, -5.55), lightColor, Enum.Material.Glass)
		end

	-- =========================================================================
	-- 4. MODELO: CUPÊ CLÁSSICO '68 (VintageCoupe) - Linhas fluidas anos 60
	-- =========================================================================
	elseif modelId == "VintageCoupe" then
		local chassis = createPart(car, carCFrame, "Chassis", Vector3.new(7.6, 0.65, 13.8), CFrame.new(0, 2.20, 0), darkMetal, darkMetalMaterial)
		car.PrimaryPart = chassis

		createPart(car, carCFrame, "BodyFront", Vector3.new(7.4, 1.20, 3.8), CFrame.new(0, 2.90, -4.6), bodyColor, bodyMaterial)
		createPart(car, carCFrame, "BodyRear", Vector3.new(7.4, 1.20, 3.4), CFrame.new(0, 2.90, 4.8), bodyColor, bodyMaterial)
		createPart(car, carCFrame, "Roof", Vector3.new(6.4, 0.35, 4.8), CFrame.new(0, 5.10, 0.3), bodyColor, bodyMaterial)

		-- Para-choques cromados clássicos
		createPart(car, carCFrame, "ChromeBumperFront", Vector3.new(7.8, 0.65, 0.4), CFrame.new(0, 2.45, -6.6), rimColor, Enum.Material.Metal)
		createPart(car, carCFrame, "ChromeBumperRear", Vector3.new(7.8, 0.65, 0.4), CFrame.new(0, 2.45, 6.6), rimColor, Enum.Material.Metal)

		if shouldBuild("Hood") then
			createPart(car, carCFrame, "Hood", Vector3.new(7.0, 0.30, 3.4), CFrame.new(0, 3.60, -4.6), bodyColor, bodyMaterial)
		end
		if shouldBuild("DoorLeft") then
			createPart(car, carCFrame, "DoorLeft", Vector3.new(0.30, 2.40, 4.2), CFrame.new(-3.72, 3.75, 0.1), bodyColor, bodyMaterial)
		end
		if shouldBuild("DoorRight") then
			createPart(car, carCFrame, "DoorRight", Vector3.new(0.30, 2.40, 4.2), CFrame.new(3.72, 3.75, 0.1), bodyColor, bodyMaterial)
		end
		if shouldBuild("Trunk") then
			createPart(car, carCFrame, "Trunk", Vector3.new(7.0, 0.30, 2.8), CFrame.new(0, 3.60, 5.0), bodyColor, bodyMaterial)
		end

		local windshield = createPart(car, carCFrame, "Windshield", Vector3.new(6.2, 1.80, 0.2), CFrame.new(0, 4.30, -2.2) * CFrame.Angles(math.rad(-20), 0, 0), glassColor, Enum.Material.Glass)
		windshield.Transparency = 0.25
		local rearWindow = createPart(car, carCFrame, "RearWindow", Vector3.new(6.2, 1.80, 0.2), CFrame.new(0, 4.25, 2.7) * CFrame.Angles(math.rad(22), 0, 0), glassColor, Enum.Material.Glass)
		rearWindow.Transparency = 0.25

		local wheelPositions = {
			WheelFrontLeft = Vector3.new(-3.9, 1.75, -4.3),
			WheelFrontRight = Vector3.new(3.9, 1.75, -4.3),
			WheelRearLeft = Vector3.new(-3.9, 1.75, 4.3),
			WheelRearRight = Vector3.new(3.9, 1.75, 4.3),
		}
		for wheelName, position in wheelPositions do
			if shouldBuild(wheelName) then
				local wheel = createPart(car, carCFrame, wheelName, Vector3.new(1.15, 2.8, 2.8), CFrame.new(position), tireColor, Enum.Material.Rubber)
				wheel.Shape = Enum.PartType.Cylinder
				local side = if position.X < 0 then -1 else 1
				local rim = createPart(car, carCFrame, wheelName .. "Rim", Vector3.new(0.14, 1.6, 1.6), CFrame.new(position + Vector3.new(0.60 * side, 0, 0)), rimColor, Enum.Material.Metal)
				rim.Shape = Enum.PartType.Cylinder
				rim.CanCollide = false
				rim.Massless = true
				rim.Anchored = false
				local rimWeld = Instance.new("WeldConstraint")
				rimWeld.Name = "RimWeld"
				rimWeld.Part0 = wheel
				rimWeld.Part1 = rim
				rimWeld.Parent = rim
			end
		end

		createPart(car, carCFrame, "Engine", Vector3.new(5.2, 1.15, 2.4), CFrame.new(0, 3.70, -4.5), Color3.fromRGB(45, 48, 52), Enum.Material.Metal)
		if shouldBuild("Battery") then
			createPart(car, carCFrame, "Battery", Vector3.new(1.25, 0.80, 0.95), CFrame.new(2.25, 4.40, -4.5), Color3.fromRGB(30, 32, 36), Enum.Material.SmoothPlastic)
		end
		-- Faróis redondos clássicos dos anos 60
		if shouldBuild("HeadlightLeft") then
			local hl = createPart(car, carCFrame, "HeadlightLeft", Vector3.new(0.3, 1.0, 1.0), CFrame.new(-2.3, 3.10, -6.55) * CFrame.Angles(0, 0, math.rad(90)), lightColor, Enum.Material.Glass)
			hl.Shape = Enum.PartType.Cylinder
		end
		if shouldBuild("HeadlightRight") then
			local hr = createPart(car, carCFrame, "HeadlightRight", Vector3.new(0.3, 1.0, 1.0), CFrame.new(2.3, 3.10, -6.55) * CFrame.Angles(0, 0, math.rad(90)), lightColor, Enum.Material.Glass)
			hr.Shape = Enum.PartType.Cylinder
		end

	-- =========================================================================
	-- 5. MODELO PADRÃO / SEDAN POPULAR '94 (Sedan90s / TrainingCar) - 3 Volumes
	-- =========================================================================
	else
		local chassis = createPart(car, carCFrame, "Chassis", Vector3.new(7.6, 0.65, 13.5), CFrame.new(0, 2.25, 0), darkMetal, darkMetalMaterial)
		car.PrimaryPart = chassis

		createPart(car, carCFrame, "BodyFront", Vector3.new(7.4, 1.25, 3.4), CFrame.new(0, 2.95, -4.65), bodyColor, bodyMaterial)
		createPart(car, carCFrame, "BodyRear", Vector3.new(7.4, 1.25, 3.2), CFrame.new(0, 2.95, 4.65), bodyColor, bodyMaterial)
		createPart(car, carCFrame, "Roof", Vector3.new(6.7, 0.35, 4.9), CFrame.new(0, 5.25, 0.2), bodyColor, bodyMaterial)

		if shouldBuild("Hood") then
			createPart(car, carCFrame, "Hood", Vector3.new(7.0, 0.30, 3.1), CFrame.new(0, 3.65, -4.65), bodyColor, bodyMaterial)
		end
		if shouldBuild("DoorLeft") then
			createPart(car, carCFrame, "DoorLeft", Vector3.new(0.30, 2.45, 4.15), CFrame.new(-3.72, 3.85, 0), bodyColor, bodyMaterial)
		end
		if shouldBuild("DoorRight") then
			createPart(car, carCFrame, "DoorRight", Vector3.new(0.30, 2.45, 4.15), CFrame.new(3.72, 3.85, 0), bodyColor, bodyMaterial)
		end
		if shouldBuild("Trunk") then
			createPart(car, carCFrame, "Trunk", Vector3.new(7.0, 0.30, 2.7), CFrame.new(0, 3.65, 4.85), bodyColor, bodyMaterial)
		end

		local windshield = createPart(car, carCFrame, "Windshield", Vector3.new(6.3, 1.80, 0.2), CFrame.new(0, 4.35, -2.25) * CFrame.Angles(math.rad(-18), 0, 0), glassColor, Enum.Material.Glass)
		windshield.Transparency = 0.25
		local rearWindow = createPart(car, carCFrame, "RearWindow", Vector3.new(6.3, 1.80, 0.2), CFrame.new(0, 4.35, 2.65) * CFrame.Angles(math.rad(18), 0, 0), glassColor, Enum.Material.Glass)
		rearWindow.Transparency = 0.25

		local wheelPositions = {
			WheelFrontLeft = Vector3.new(-3.9, 1.75, -4.25),
			WheelFrontRight = Vector3.new(3.9, 1.75, -4.25),
			WheelRearLeft = Vector3.new(-3.9, 1.75, 4.15),
			WheelRearRight = Vector3.new(3.9, 1.75, 4.15),
		}
		for wheelName, position in wheelPositions do
			if shouldBuild(wheelName) then
				local wheel = createPart(car, carCFrame, wheelName, Vector3.new(1.15, 2.8, 2.8), CFrame.new(position), tireColor, Enum.Material.Rubber)
				wheel.Shape = Enum.PartType.Cylinder
				local side = if position.X < 0 then -1 else 1
				local rim = createPart(car, carCFrame, wheelName .. "Rim", Vector3.new(0.12, 1.55, 1.55), CFrame.new(position + Vector3.new(0.59 * side, 0, 0)), rimColor, Enum.Material.Metal)
				rim.Shape = Enum.PartType.Cylinder
				rim.CanCollide = false
				rim.Massless = true
				rim.Anchored = false
				local rimWeld = Instance.new("WeldConstraint")
				rimWeld.Name = "RimWeld"
				rimWeld.Part0 = wheel
				rimWeld.Part1 = rim
				rimWeld.Parent = rim
			end
		end

		createPart(car, carCFrame, "Engine", Vector3.new(5.2, 1.15, 2.35), CFrame.new(0, 3.75, -4.55), Color3.fromRGB(42, 45, 48), Enum.Material.Metal)
		if shouldBuild("Battery") then
			createPart(car, carCFrame, "Battery", Vector3.new(1.25, 0.80, 0.95), CFrame.new(2.25, 4.45, -4.55), Color3.fromRGB(30, 32, 36), Enum.Material.SmoothPlastic)
		end
		if shouldBuild("HeadlightLeft") then
			createPart(car, carCFrame, "HeadlightLeft", Vector3.new(1.45, 0.55, 0.25), CFrame.new(-2.25, 3.15, -6.38), lightColor, Enum.Material.Glass)
		end
		if shouldBuild("HeadlightRight") then
			createPart(car, carCFrame, "HeadlightRight", Vector3.new(1.45, 0.55, 0.25), CFrame.new(2.25, 3.15, -6.38), lightColor, Enum.Material.Glass)
		end
	end

	return car
end

return TrainingCarBuilder
