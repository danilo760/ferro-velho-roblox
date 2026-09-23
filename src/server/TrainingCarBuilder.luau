--!strict

local TrainingCarBuilder = {}

local CAR_ORIGIN = Vector3.new(0, 0, -28)

local function createPart(
	parent: Model,
	name: string,
	size: Vector3,
	localPosition: Vector3,
	color: Color3,
	material: Enum.Material?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = CAR_ORIGIN + localPosition
	part.Anchored = true
	part.CanCollide = true
	part.Material = material or Enum.Material.Metal
	part.Color = color
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

function TrainingCarBuilder.create(): Model
	local car = Instance.new("Model")
	car.Name = "TrainingCar01"

	local bodyColor = Color3.fromRGB(74, 82, 88)
	local darkMetal = Color3.fromRGB(38, 42, 45)
	local glassColor = Color3.fromRGB(32, 52, 62)
	local tireColor = Color3.fromRGB(18, 18, 18)
	local rimColor = Color3.fromRGB(115, 120, 125)
	local lightColor = Color3.fromRGB(255, 221, 125)

	createPart(car, "Chassis", Vector3.new(7.6, 0.65, 13.5), Vector3.new(0, 2.25, 0), darkMetal, Enum.Material.Metal)
	createPart(car, "BodyFront", Vector3.new(7.4, 1.25, 3.4), Vector3.new(0, 2.95, -4.65), bodyColor, Enum.Material.Metal)
	createPart(car, "BodyRear", Vector3.new(7.4, 1.25, 3.2), Vector3.new(0, 2.95, 4.65), bodyColor, Enum.Material.Metal)
	createPart(car, "Roof", Vector3.new(6.7, 0.35, 4.9), Vector3.new(0, 5.25, 0.2), bodyColor, Enum.Material.Metal)

	createPart(car, "Hood", Vector3.new(7.0, 0.3, 3.1), Vector3.new(0, 3.65, -4.65), bodyColor, Enum.Material.Metal)
	createPart(car, "DoorLeft", Vector3.new(0.3, 2.45, 4.15), Vector3.new(-3.72, 3.85, 0), bodyColor, Enum.Material.Metal)
	createPart(car, "DoorRight", Vector3.new(0.3, 2.45, 4.15), Vector3.new(3.72, 3.85, 0), bodyColor, Enum.Material.Metal)
	createPart(car, "Trunk", Vector3.new(7.0, 0.3, 2.7), Vector3.new(0, 3.65, 4.85), bodyColor, Enum.Material.Metal)

	local windshield = createPart(car, "Windshield", Vector3.new(6.3, 1.8, 0.2), Vector3.new(0, 4.35, -2.25), glassColor, Enum.Material.Glass)
	windshield.Transparency = 0.25
	windshield.Orientation = Vector3.new(-18, 0, 0)

	local rearWindow = createPart(car, "RearWindow", Vector3.new(6.3, 1.8, 0.2), Vector3.new(0, 4.35, 2.65), glassColor, Enum.Material.Glass)
	rearWindow.Transparency = 0.25
	rearWindow.Orientation = Vector3.new(18, 0, 0)

	local wheelPositions = {
		WheelFrontLeft = Vector3.new(-3.9, 1.75, -4.25),
		WheelFrontRight = Vector3.new(3.9, 1.75, -4.25),
		WheelRearLeft = Vector3.new(-3.9, 1.75, 4.15),
		WheelRearRight = Vector3.new(3.9, 1.75, 4.15),
	}

	for wheelName, position in pairs(wheelPositions) do
		local wheel = createPart(car, wheelName, Vector3.new(1.15, 2.8, 2.8), position, tireColor, Enum.Material.Rubber)
		wheel.Shape = Enum.PartType.Cylinder

		local side = if position.X < 0 then -1 else 1
		local rimPosition = position + Vector3.new(0.59 * side, 0, 0)
		local rim = createPart(car, wheelName .. "Rim", Vector3.new(0.12, 1.55, 1.55), rimPosition, rimColor, Enum.Material.Metal)
		rim.Shape = Enum.PartType.Cylinder
		rim.CanCollide = false
	end

	createPart(car, "Engine", Vector3.new(5.2, 1.15, 2.35), Vector3.new(0, 3.75, -4.55), Color3.fromRGB(42, 45, 48), Enum.Material.Metal)
	createPart(car, "Battery", Vector3.new(1.25, 0.8, 0.95), Vector3.new(2.25, 4.45, -4.55), Color3.fromRGB(30, 32, 36), Enum.Material.SmoothPlastic)
	createPart(car, "HeadlightLeft", Vector3.new(1.45, 0.55, 0.25), Vector3.new(-2.25, 3.15, -6.38), lightColor, Enum.Material.Glass)
	createPart(car, "HeadlightRight", Vector3.new(1.45, 0.55, 0.25), Vector3.new(2.25, 3.15, -6.38), lightColor, Enum.Material.Glass)

	return car
end

return TrainingCarBuilder
