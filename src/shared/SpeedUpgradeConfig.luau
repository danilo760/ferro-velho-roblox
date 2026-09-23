--!strict

export type SpeedLevelDefinition = {
	Level: number,
	Name: string,
	Speed: number,
	PurchaseCost: number?,
}

local SpeedUpgradeConfig = {}

SpeedUpgradeConfig.Levels = {
	[1] = {
		Level = 1,
		Name = "Passo Padrão",
		Speed = 16,
		PurchaseCost = nil,
	},
	[2] = {
		Level = 2,
		Name = "Tênis Reforçado",
		Speed = 18,
		PurchaseCost = 500,
	},
	[3] = {
		Level = 3,
		Name = "Passada Ágil",
		Speed = 20,
		PurchaseCost = 1500,
	},
	[4] = {
		Level = 4,
		Name = "Corrida Atlética",
		Speed = 22,
		PurchaseCost = 4000,
	},
	[5] = {
		Level = 5,
		Name = "Velocidade Máxima",
		Speed = 24,
		PurchaseCost = 10000,
	},
} :: {[number]: SpeedLevelDefinition}

function SpeedUpgradeConfig.Get(level: number): SpeedLevelDefinition?
	return SpeedUpgradeConfig.Levels[level]
end

function SpeedUpgradeConfig.GetMaxLevel(): number
	return #SpeedUpgradeConfig.Levels
end

return SpeedUpgradeConfig
