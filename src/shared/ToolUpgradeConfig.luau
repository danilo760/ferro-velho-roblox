--!strict

export type ToolLevelDefinition = {
	Level: number,
	Name: string,
	RemovalSeconds: number,
	PurchaseCost: number?,
}

local ToolUpgradeConfig = {}

ToolUpgradeConfig.Levels = {
	[1] = {
		Level = 1,
		Name = "Ferramentas básicas",
		RemovalSeconds = 1.5,
		PurchaseCost = nil,
	},
	[2] = {
		Level = 2,
		Name = "Chave catraca",
		RemovalSeconds = 1.2,
		PurchaseCost = 1000,
	},
} :: {[number]: ToolLevelDefinition}

function ToolUpgradeConfig.Get(level: number): ToolLevelDefinition?
	return ToolUpgradeConfig.Levels[level]
end

return ToolUpgradeConfig
