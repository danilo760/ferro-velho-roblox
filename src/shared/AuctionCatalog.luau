--!strict

export type AuctionCarModel = {
	Id: string,
	DisplayName: string,
	Description: string,
	BodyColor: Color3,
	AccentColor: Color3,
	StartingBid: number,
	ScrapMultiplier: number,
	PossibleMissingParts: {string},
}

export type AuctionLot = {
	LotId: number,
	ModelConfig: AuctionCarModel,
	InstalledParts: {string},
	EstimatedScrapValue: number,
	StartingBid: number,
}

local VEHICLE_MODELS: {[string]: AuctionCarModel} = {
	Sedan90s = {
		Id = "Sedan90s",
		DisplayName = "Sedan Popular '94",
		Description = "Sedan clássico de ferro-velho, peças padrão fáceis de desmontar.",
		BodyColor = Color3.fromRGB(85, 95, 105),
		AccentColor = Color3.fromRGB(40, 44, 48),
		StartingBid = 120,
		ScrapMultiplier = 1.0,
		PossibleMissingParts = { "HeadlightLeft", "HeadlightRight", "DoorRight", "Battery" },
	},
	RustPickup = {
		Id = "RustPickup",
		DisplayName = "Picape Rust '85",
		Description = "Picape utilitária reforçada. Peças de carroceria pesadas e alto valor de sucata.",
		BodyColor = Color3.fromRGB(150, 75, 45),
		AccentColor = Color3.fromRGB(55, 30, 20),
		StartingBid = 350,
		ScrapMultiplier = 1.6,
		PossibleMissingParts = { "HeadlightLeft", "HeadlightRight", "Hood", "Trunk" },
	},
	MuscleCar72 = {
		Id = "MuscleCar72",
		DisplayName = "Muscle Car '72 V8",
		Description = "Raridade americana. Motor V8 supervalorizado e rodas de alto rendimento.",
		BodyColor = Color3.fromRGB(180, 35, 30),
		AccentColor = Color3.fromRGB(25, 25, 25),
		StartingBid = 850,
		ScrapMultiplier = 2.8,
		PossibleMissingParts = { "HeadlightLeft", "HeadlightRight", "DoorLeft", "DoorRight" },
	},
}

local MODEL_KEYS = { "Sedan90s", "RustPickup", "MuscleCar72" }

local ALL_PARTS = {
	"Chassis", "Engine", "Battery", "Hood", "Trunk",
	"DoorLeft", "DoorRight", "HeadlightLeft", "HeadlightRight",
	"WheelFrontLeft", "WheelFrontRight", "WheelRearLeft", "WheelRearRight",
}

local BASE_VALUES: {[string]: number} = {
	Engine = 450, Battery = 80, Hood = 95, Trunk = 100,
	DoorLeft = 110, DoorRight = 110, HeadlightLeft = 45, HeadlightRight = 45,
	WheelFrontLeft = 60, WheelFrontRight = 60, WheelRearLeft = 60, WheelRearRight = 60,
}

local AuctionCatalog = {}

function AuctionCatalog.GetModel(id: string): AuctionCarModel?
	return VEHICLE_MODELS[id]
end

function AuctionCatalog.GenerateLot(lotId: number): AuctionLot
	local randomKey = MODEL_KEYS[math.random(1, #MODEL_KEYS)]
	local modelConfig = VEHICLE_MODELS[randomKey]

	local installedParts: {string} = {}
	local totalEstimatedValue = 0

	for _, partName in ALL_PARTS do
		local isEssential = (partName == "Chassis" or partName == "Engine")
		local isCandidate = table.find(modelConfig.PossibleMissingParts, partName) ~= nil
		local keepPart = true

		if isCandidate and not isEssential then
			-- 40% de chance de vir ausente no leilão
			keepPart = math.random() > 0.40
		end

		if keepPart then
			table.insert(installedParts, partName)
			local baseVal = BASE_VALUES[partName] or 0
			totalEstimatedValue += math.round(baseVal * modelConfig.ScrapMultiplier)
		end
	end

	return {
		LotId = lotId,
		ModelConfig = modelConfig,
		InstalledParts = installedParts,
		EstimatedScrapValue = totalEstimatedValue,
		StartingBid = modelConfig.StartingBid,
	}
end

return AuctionCatalog
