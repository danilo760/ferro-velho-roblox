--!strict

export type ConservationStateId = number

export type ConservationDef = {
	Id: ConservationStateId,
	Name: string,
	Multiplier: number,
	TicketCost: number,
	MinPartsRatio: number,
	MaxPartsRatio: number,
	TagColor: Color3,
}

export type AuctionCarModel = {
	Id: string,
	DisplayName: string,
	Description: string,
	BaseBodyColor: Color3,
	BaseAccentColor: Color3,
	BaseMultiplier: number,
}

export type CatalogOffer = {
	OfferId: string,
	ModelId: string,
	DisplayName: string,
	Description: string,
	Conservation: ConservationDef,
	TicketCost: number,
	ScrapMultiplier: number,
	InstalledParts: {string},
	TotalPartsCount: number,
	EstimatedScrapValue: number,
	BodyColor: Color3,
	AccentColor: Color3,
}

local CONSERVATION_STATES: {[ConservationStateId]: ConservationDef} = {
	[1] = {
		Id = 1,
		Name = "Sucateado",
		Multiplier = 0.8,
		TicketCost = 1,
		MinPartsRatio = 0.40,
		MaxPartsRatio = 0.50,
		TagColor = Color3.fromRGB(180, 110, 50),
	},
	[2] = {
		Id = 2,
		Name = "Danificado",
		Multiplier = 1.0,
		TicketCost = 2,
		MinPartsRatio = 0.60,
		MaxPartsRatio = 0.70,
		TagColor = Color3.fromRGB(215, 160, 45),
	},
	[3] = {
		Id = 3,
		Name = "Usado",
		Multiplier = 1.4,
		TicketCost = 3,
		MinPartsRatio = 0.80,
		MaxPartsRatio = 0.90,
		TagColor = Color3.fromRGB(60, 150, 220),
	},
	[4] = {
		Id = 4,
		Name = "Preservado",
		Multiplier = 2.0,
		TicketCost = 5,
		MinPartsRatio = 1.00,
		MaxPartsRatio = 1.00,
		TagColor = Color3.fromRGB(65, 195, 105),
	},
	[5] = {
		Id = 5,
		Name = "Excelente",
		Multiplier = 3.0,
		TicketCost = 8,
		MinPartsRatio = 1.00,
		MaxPartsRatio = 1.00,
		TagColor = Color3.fromRGB(180, 80, 235),
	},
}

local VEHICLE_MODELS: {[string]: AuctionCarModel} = {
	Sedan90s = {
		Id = "Sedan90s",
		DisplayName = "Sedan Popular '94",
		Description = "Sedan clássico de ferro-velho, peças padrão fáceis de desmontar.",
		BaseBodyColor = Color3.fromRGB(85, 95, 105),
		BaseAccentColor = Color3.fromRGB(40, 44, 48),
		BaseMultiplier = 1.0,
	},
	RustPickup = {
		Id = "RustPickup",
		DisplayName = "Picape Rust '85",
		Description = "Picape utilitária reforçada com alto rendimento de sucata.",
		BaseBodyColor = Color3.fromRGB(150, 75, 45),
		BaseAccentColor = Color3.fromRGB(55, 30, 20),
		BaseMultiplier = 1.2,
	},
	MuscleCar72 = {
		Id = "MuscleCar72",
		DisplayName = "Muscle Car '72 V8",
		Description = "Raridade americana com motor potente e lataria valorizada.",
		BaseBodyColor = Color3.fromRGB(180, 35, 30),
		BaseAccentColor = Color3.fromRGB(25, 25, 25),
		BaseMultiplier = 1.5,
	},
	CompactHatch = {
		Id = "CompactHatch",
		DisplayName = "Hatch Compacto '98",
		Description = "Carro urbano ágil e leve, desmontagem rápida.",
		BaseBodyColor = Color3.fromRGB(45, 110, 160),
		BaseAccentColor = Color3.fromRGB(35, 40, 45),
		BaseMultiplier = 1.1,
	},
	VintageCoupe = {
		Id = "VintageCoupe",
		DisplayName = "Cupê Clássico '68",
		Description = "Cupê elegante dos anos 60 com peças vintage super procuradas.",
		BaseBodyColor = Color3.fromRGB(140, 35, 60),
		BaseAccentColor = Color3.fromRGB(30, 30, 35),
		BaseMultiplier = 1.4,
	},
}

local MODEL_KEYS = { "Sedan90s", "RustPickup", "MuscleCar72", "CompactHatch", "VintageCoupe" }

local REMOVABLE_PARTS = {
	"Hood", "Trunk", "DoorLeft", "DoorRight",
	"HeadlightLeft", "HeadlightRight",
	"WheelFrontLeft", "WheelFrontRight", "WheelRearLeft", "WheelRearRight",
	"Battery",
}

local BASE_VALUES: {[string]: number} = {
	Engine = 450,
	Battery = 80,
	Hood = 95,
	Trunk = 100,
	DoorLeft = 110,
	DoorRight = 110,
	HeadlightLeft = 45,
	HeadlightRight = 45,
	WheelFrontLeft = 60,
	WheelFrontRight = 60,
	WheelRearLeft = 60,
	WheelRearRight = 60,
}

local COLOR_PALETTES = {
	Color3.fromRGB(85, 95, 105),
	Color3.fromRGB(150, 75, 45),
	Color3.fromRGB(180, 35, 30),
	Color3.fromRGB(45, 110, 160),
	Color3.fromRGB(50, 130, 80),
	Color3.fromRGB(130, 115, 65),
	Color3.fromRGB(115, 60, 140),
	Color3.fromRGB(60, 65, 75),
}

local PRISTINE_COLORS = {
	Color3.fromRGB(235, 195, 50), -- Dourado
	Color3.fromRGB(225, 230, 240), -- Pérola / Prata
	Color3.fromRGB(200, 30, 40),  -- Vermelho metálico
	Color3.fromRGB(35, 145, 230), -- Azul elétrico
}

local AuctionCatalog = {}

function AuctionCatalog.GetConservation(tier: ConservationStateId): ConservationDef
	return CONSERVATION_STATES[tier] or CONSERVATION_STATES[1]
end

function AuctionCatalog.GetModel(id: string): AuctionCarModel?
	return VEHICLE_MODELS[id]
end

function AuctionCatalog.GenerateOffer(offerId: string, forcedTier: ConservationStateId?): CatalogOffer
	local modelKey = MODEL_KEYS[math.random(1, #MODEL_KEYS)]
	local model = VEHICLE_MODELS[modelKey]

	local tier: ConservationStateId
	if forcedTier then
		tier = forcedTier
	else
		-- Distribuição ponderada: 1: 30%, 2: 30%, 3: 20%, 4: 12%, 5: 8%
		local roll = math.random(1, 100)
		if roll <= 30 then
			tier = 1
		elseif roll <= 60 then
			tier = 2
		elseif roll <= 80 then
			tier = 3
		elseif roll <= 92 then
			tier = 4
		else
			tier = 5
		end
	end

	local conservation = CONSERVATION_STATES[tier]
	local finalMultiplier = math.round((model.BaseMultiplier * conservation.Multiplier) * 10) / 10

	-- Engine e Chassis são essenciais e sempre estão presentes
	local installedParts: {string} = { "Chassis", "Engine" }
	local partsPool = table.clone(REMOVABLE_PARTS)

	-- Embaralhar pool de peças
	for i = #partsPool, 2, -1 do
		local j = math.random(1, i)
		partsPool[i], partsPool[j] = partsPool[j], partsPool[i]
	end

	local totalRemovable = #REMOVABLE_PARTS
	local minParts = math.clamp(math.floor(totalRemovable * conservation.MinPartsRatio), 1, totalRemovable)
	local maxParts = math.clamp(math.ceil(totalRemovable * conservation.MaxPartsRatio), minParts, totalRemovable)
	local partsToPick = math.random(minParts, maxParts)

	for i = 1, partsToPick do
		table.insert(installedParts, partsPool[i])
	end

	-- Calcular valor estimado de sucata
	local totalEstValue = 0
	for _, partName in installedParts do
		local baseVal = BASE_VALUES[partName] or 0
		totalEstValue += math.round(baseVal * finalMultiplier)
	end

	local bodyColor: Color3
	local accentColor: Color3 = model.BaseAccentColor

	if tier == 5 then
		bodyColor = PRISTINE_COLORS[math.random(1, #PRISTINE_COLORS)]
		accentColor = Color3.fromRGB(20, 20, 25)
	else
		bodyColor = COLOR_PALETTES[math.random(1, #COLOR_PALETTES)]
	end

	-- Contagem de peças removíveis instaladas + Engine = total de peças vendíveis
	local vendibleCount = 0
	for _, part in installedParts do
		if BASE_VALUES[part] ~= nil then
			vendibleCount += 1
		end
	end

	return {
		OfferId = offerId,
		ModelId = model.Id,
		DisplayName = model.DisplayName,
		Description = model.Description,
		Conservation = conservation,
		TicketCost = conservation.TicketCost,
		ScrapMultiplier = finalMultiplier,
		InstalledParts = installedParts,
		TotalPartsCount = vendibleCount,
		EstimatedScrapValue = totalEstValue,
		BodyColor = bodyColor,
		AccentColor = accentColor,
	}
end

function AuctionCatalog.GenerateCatalog(): {CatalogOffer}
	local offers: {CatalogOffer} = {}
	-- Gerar 5 ofertas garantindo variedade
	local guaranteedTiers: {ConservationStateId} = { 1, 2, 3, 4, 5 }
	-- Embaralhar a ordem dos tiers na exibição
	for i = #guaranteedTiers, 2, -1 do
		local j = math.random(1, i)
		guaranteedTiers[i], guaranteedTiers[j] = guaranteedTiers[j], guaranteedTiers[i]
	end

	for i = 1, 5 do
		local offerId = string.format("OFFER_%d_%d", os.time(), i)
		table.insert(offers, AuctionCatalog.GenerateOffer(offerId, guaranteedTiers[i]))
	end

	return offers
end

return AuctionCatalog
