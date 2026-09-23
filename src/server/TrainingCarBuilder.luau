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
	BodyColor: Color3?,
	AccentColor: Color3?,
	InstalledParts: {string}?,
	ScrapMultiplier: number?,
}

function TrainingCarBuilder.create(originCFrame: CFrame?, carName: string?, options: CustomCarOptions?): Model
	local car = Instance.new("Model")
	car.Name = carName or "TrainingCar01"
	local carCFrame = originCFrame or CFrame.new(DEFAULT_CAR_ORIGIN)

	local bodyColor = (options and options.BodyColor) or Color3.fromRGB(74, 82, 88)
	local darkMetal = (options and options.AccentColor) or Color3.fromRGB(38, 42, 45)
	local glassColor = Color3.fromRGB(32, 52, 62)
	local tireColor = Color3.fromRGB(18, 18, 18)
	local rimColor = Color3.fromRGB(115, 120, 125)
	local lightColor = Color3.fromRGB(255, 221, 125)

	local scrapMultiplier = (options and options.ScrapMultiplier) or 1
	car:SetAttribute("ScrapMultiplier", scrapMultiplier)

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

	local chassis = createPart(car, carCFrame, "Chassis", Vector3.new(7.6, 0.65, 13.5), CFrame.new(0, 2.25, 0), darkMetal, Enum.Material.Metal)
	car.PrimaryPart = chassis
	createPart(car, carCFrame, "BodyFront", Vector3.new(7.4, 1.25, 3.4), CFrame.new(0, 2.95, -4.65), bodyColor, Enum.Material.Metal)
	createPart(car, carCFrame, "BodyRear", Vector3.new(7.4, 1.25, 3.2), CFrame.new(0, 2.95, 4.65), bodyColor, Enum.Material.Metal)
	createPart(car, carCFrame, "Roof", Vector3.new(6.7, 0.35, 4.9), CFrame.new(0, 5.25, 0.2), bodyColor, Enum.Material.Metal)

	if shouldBuild("Hood") then
		createPart(car, carCFrame, "Hood", Vector3.new(7.0, 0.3, 3.1), CFrame.new(0, 3.65, -4.65), bodyColor, Enum.Material.Metal)
	end
	if shouldBuild("DoorLeft") then
		createPart(car, carCFrame, "DoorLeft", Vector3.new(0.3, 2.45, 4.15), CFrame.new(-3.72, 3.85, 0), bodyColor, Enum.Material.Metal)
	end
	if shouldBuild("DoorRight") then
		createPart(car, carCFrame, "DoorRight", Vector3.new(0.3, 2.45, 4.15), CFrame.new(3.72, 3.85, 0), bodyColor, Enum.Material.Metal)
	end
	if shouldBuild("Trunk") then
		createPart(car, carCFrame, "Trunk", Vector3.new(7.0, 0.3, 2.7), CFrame.new(0, 3.65, 4.85), bodyColor, Enum.Material.Metal)
	end

	local windshield = createPart(car, carCFrame, "Windshield", Vector3.new(6.3, 1.8, 0.2), CFrame.new(0, 4.35, -2.25) * CFrame.Angles(math.rad(-18), 0, 0), glassColor, Enum.Material.Glass)
	windshield.Transparency = 0.25
	local rearWindow = createPart(car, carCFrame, "RearWindow", Vector3.new(6.3, 1.8, 0.2), CFrame.new(0, 4.35, 2.65) * CFrame.Angles(math.rad(18), 0, 0), glassColor, Enum.Material.Glass)
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
		createPart(car, carCFrame, "Battery", Vector3.new(1.25, 0.8, 0.95), CFrame.new(2.25, 4.45, -4.55), Color3.fromRGB(30, 32, 36), Enum.Material.SmoothPlastic)
	end
	if shouldBuild("HeadlightLeft") then
		createPart(car, carCFrame, "HeadlightLeft", Vector3.new(1.45, 0.55, 0.25), CFrame.new(-2.25, 3.15, -6.38), lightColor, Enum.Material.Glass)
	end
	if shouldBuild("HeadlightRight") then
		createPart(car, carCFrame, "HeadlightRight", Vector3.new(1.45, 0.55, 0.25), CFrame.new(2.25, 3.15, -6.38), lightColor, Enum.Material.Glass)
	end
	return car
end

return TrainingCarBuilder
