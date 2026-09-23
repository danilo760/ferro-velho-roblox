--!strict

export type PartDefinition = {
	Id: string,
	DisplayName: string,
	Category: string,
	SellValue: number,
	Weight: number,
	RemovalSeconds: number,
	RequiredTool: string,
}

local REMOVAL_SECONDS = 1.5

local PartsCatalog: {[string]: PartDefinition} = {
	Engine = { Id = "Engine", DisplayName = "Motor", Category = "Powertrain", SellValue = 450, Weight = 180, RemovalSeconds = REMOVAL_SECONDS, RequiredTool = "EngineHoist" },
	Battery = { Id = "Battery", DisplayName = "Bateria", Category = "Electrical", SellValue = 80, Weight = 18, RemovalSeconds = REMOVAL_SECONDS, RequiredTool = "BasicTools" },
	WheelFrontLeft = { Id = "WheelFrontLeft", DisplayName = "Roda dianteira esquerda", Category = "Wheel", SellValue = 60, Weight = 14, RemovalSeconds = REMOVAL_SECONDS, RequiredTool = "BasicTools" },
	WheelFrontRight = { Id = "WheelFrontRight", DisplayName = "Roda dianteira direita", Category = "Wheel", SellValue = 60, Weight = 14, RemovalSeconds = REMOVAL_SECONDS, RequiredTool = "BasicTools" },
	WheelRearLeft = { Id = "WheelRearLeft", DisplayName = "Roda traseira esquerda", Category = "Wheel", SellValue = 60, Weight = 14, RemovalSeconds = REMOVAL_SECONDS, RequiredTool = "BasicTools" },
	WheelRearRight = { Id = "WheelRearRight", DisplayName = "Roda traseira direita", Category = "Wheel", SellValue = 60, Weight = 14, RemovalSeconds = REMOVAL_SECONDS, RequiredTool = "BasicTools" },
	Hood = { Id = "Hood", DisplayName = "Capô", Category = "Body", SellValue = 95, Weight = 22, RemovalSeconds = REMOVAL_SECONDS, RequiredTool = "BasicTools" },
	DoorLeft = { Id = "DoorLeft", DisplayName = "Porta esquerda", Category = "Body", SellValue = 110, Weight = 35, RemovalSeconds = REMOVAL_SECONDS, RequiredTool = "BasicTools" },
	DoorRight = { Id = "DoorRight", DisplayName = "Porta direita", Category = "Body", SellValue = 110, Weight = 35, RemovalSeconds = REMOVAL_SECONDS, RequiredTool = "BasicTools" },
	Trunk = { Id = "Trunk", DisplayName = "Porta-malas", Category = "Body", SellValue = 100, Weight = 30, RemovalSeconds = REMOVAL_SECONDS, RequiredTool = "BasicTools" },
	HeadlightLeft = { Id = "HeadlightLeft", DisplayName = "Farol esquerdo", Category = "Electrical", SellValue = 45, Weight = 4, RemovalSeconds = REMOVAL_SECONDS, RequiredTool = "BasicTools" },
	HeadlightRight = { Id = "HeadlightRight", DisplayName = "Farol direito", Category = "Electrical", SellValue = 45, Weight = 4, RemovalSeconds = REMOVAL_SECONDS, RequiredTool = "BasicTools" },
}

return PartsCatalog
