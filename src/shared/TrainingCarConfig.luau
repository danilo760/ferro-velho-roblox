--!strict

export type TrainingPart = {
	PartId: string,
	Installed: boolean,
	RequiredPartsRemoved: {string},
}

local TrainingCarConfig = {
	CarId = "TrainingCar01",
	DisplayName = "Sucata Compacta",
	Parts = {
		{ PartId = "Engine", Installed = true, RequiredPartsRemoved = { "Battery" } },
		{ PartId = "Battery", Installed = true, RequiredPartsRemoved = {} },
		{ PartId = "WheelFrontLeft", Installed = true, RequiredPartsRemoved = {} },
		{ PartId = "WheelFrontRight", Installed = true, RequiredPartsRemoved = {} },
		{ PartId = "WheelRearLeft", Installed = true, RequiredPartsRemoved = {} },
		{ PartId = "WheelRearRight", Installed = true, RequiredPartsRemoved = {} },
		{ PartId = "Hood", Installed = true, RequiredPartsRemoved = {} },
		{ PartId = "DoorLeft", Installed = true, RequiredPartsRemoved = {} },
		{ PartId = "DoorRight", Installed = true, RequiredPartsRemoved = {} },
		{ PartId = "Trunk", Installed = true, RequiredPartsRemoved = {} },
		{ PartId = "HeadlightLeft", Installed = true, RequiredPartsRemoved = { "Hood" } },
		{ PartId = "HeadlightRight", Installed = true, RequiredPartsRemoved = { "Hood" } },
	},
}

return TrainingCarConfig
