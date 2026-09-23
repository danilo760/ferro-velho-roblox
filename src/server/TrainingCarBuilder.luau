--!strict

local TrainingCarBuilder = {}

local function createPart(parent: Model, name: string, size: Vector3, position: Vector3, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Anchored = true
	part.Material = Enum.Material.Metal
	part.Color = color
	part.Parent = parent
	return part
end

function TrainingCarBuilder.create(): Model
	local car = Instance.new("Model")
	car.Name = "TrainingCar01"

	local bodyColor = Color3.fromRGB(68, 72, 76)
	local glassColor = Color3.fromRGB(25, 35, 42)
	local tireColor = Color3.fromRGB(20, 20, 20)
	local lightColor = Color3.fromRGB(255, 220, 120)

	createPart(car, "Chassis", Vector3.new(8, 0.6, 15), Vector3.new(0, 2.1, 0), bodyColor)
	createPart(car, "Hood", Vector3.new(7.4, 0.4, 3.2), Vector3.new(0, 2.8, -5.1), bodyColor)
	createPart(car, "DoorLeft", Vector3.new(0.35, 2.2, 4.2), Vector3.new(-4.05, 3.2, 0), bodyColor)
	createPart(car, "DoorRight", Vector3.new(0.35, 2.2, 4.2), Vector3.new(4.05, 3.2, 0), bodyColor)
	createPart(car, "Trunk", Vector3.new(7.4, 0.4, 2.8), Vector3.new(0, 2.8, 5.2), bodyColor)
	createPart(car, "Windshield", Vector3.new(6.4, 1.8, 0.25), Vector3.new(0, 4.1, -2.4), glassColor)
	createPart(car, "RearWindow", Vector3.new(6.4, 1.8, 0.25), Vector3.new(0, 4.1, 2.4), glassColor)

	local wheelPositions = {
		FrontLeft = Vector3.new(-4.2, 1.7, -4.2),
		FrontRight = Vector3.new(4.2, 1.7, -4.2),
		RearLeft = Vector3.new(-4.2, 1.7, 4.2),
		RearRight = Vector3.new(4.2, 1.7, 4.2),
	}
	for wheelName, position in pairs(wheelPositions) do
		local wheel = createPart(car, "Wheel" .. wheelName, Vector3.new(1.1, 2.4, 2.4), position, tireColor)
		wheel.Shape = Enum.PartType.Cylinder
		wheel.Orientation = Vector3.new(0, 0, 90)
	end

	createPart(car, "Engine", Vector3.new(5.5, 1.3, 2.4), Vector3.new(0, 3.2, -4.6), Color3.fromRGB(45, 45, 45))
	createPart(car, "Battery", Vector3.new(1.3, 0.8, 0.9), Vector3.new(2.1, 4.0, -4.6), Color3.fromRGB(35, 35, 40))
	createPart(car, "HeadlightLeft", Vector3.new(1.3, 0.5, 0.25), Vector3.new(-2.2, 3.2, -6.7), lightColor)
	createPart(car, "HeadlightRight", Vector3.new(1.3, 0.5, 0.25), Vector3.new(2.2, 3.2, -6.7), lightColor)

	return car
end

return TrainingCarBuilder
