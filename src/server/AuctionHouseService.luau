--!strict

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local AuctionHouseService = {}

local bidTriggerEvent = Instance.new("BindableEvent")
AuctionHouseService.OnQuickBidTriggered = bidTriggerEvent.Event

local houseModel: Model? = nil
local turntablePart: Part? = nil
local displayedCar: Model? = nil
local turntableConnection: RBXScriptConnection? = nil

local titleLabel: TextLabel? = nil
local statusLabel: TextLabel? = nil
local timerLabel: TextLabel? = nil
local bidLabel: TextLabel? = nil
local leaderLabel: TextLabel? = nil
local podiumHammer: Part? = nil

local AUCTION_CENTER = Vector3.new(0, 0.5, 85)

local function createPart(parent: Instance, name: string, size: Vector3, cf: CFrame, material: Enum.Material, color: Color3, anchored: boolean, canCollide: boolean): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cf
	part.Material = material
	part.Color = color
	part.Anchored = anchored
	part.CanCollide = canCollide
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function buildBidPad(parent: Instance, name: string, offset: Vector3, color: Color3, amount: number)
	local pad = createPart(parent, name, Vector3.new(5, 0.6, 5), CFrame.new(AUCTION_CENTER + offset), Enum.Material.Neon, color, true, true)
	pad.Transparency = 0.25

	local bb = Instance.new("BillboardGui")
	bb.Name = "PadGui"
	bb.Size = UDim2.fromOffset(180, 50)
	bb.StudsOffset = Vector3.new(0, 2.5, 0)
	bb.AlwaysOnTop = true
	bb.Parent = pad

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = string.format("+R$ %d", amount)
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.2
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.Parent = bb

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BidPrompt"
	prompt.ActionText = string.format("Cobrir +R$ %d", amount)
	prompt.ObjectText = "Leilão"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = pad

	local debounce: {[Player]: boolean} = {}

	local function handleBid(player: Player)
		if debounce[player] then return end
		debounce[player] = true
		bidTriggerEvent:Fire(player, amount)
		task.delay(0.4, function()
			debounce[player] = nil
		end)
	end

	prompt.Triggered:Connect(handleBid)

	pad.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		local player = character and game:GetService("Players"):GetPlayerFromCharacter(character)
		if player then
			handleBid(player)
		end
	end)
end

function AuctionHouseService.build()
	if houseModel and houseModel.Parent then houseModel:Destroy() end

	local house = Instance.new("Model")
	house.Name = "AuctionHouse"

	-- 1. Passarela conectando a Central ao Leilão
	createPart(house, "Walkway", Vector3.new(12, 0.4, 42), CFrame.new(0, 0.4, 44), Enum.Material.Concrete, Color3.fromRGB(70, 74, 80), true, true)

	-- 2. Piso Principal do Galpão (48x48 studs)
	createPart(house, "Floor", Vector3.new(48, 1, 48), CFrame.new(AUCTION_CENTER), Enum.Material.Concrete, Color3.fromRGB(45, 48, 52), true, true)

	-- Linha amarela de segurança industrial
	local selectionBox = Instance.new("SelectionBox")
	selectionBox.Adornee = house:FindFirstChild("Floor") :: Part
	selectionBox.Color3 = Color3.fromRGB(240, 180, 20)
	selectionBox.LineThickness = 0.08
	selectionBox.Parent = house

	-- 3. Pilares Industriais de Aço
	local pilarPositions = {
		Vector3.new(-22, 10, -22), Vector3.new(22, 10, -22),
		Vector3.new(-22, 10, 22), Vector3.new(22, 10, 22),
	}
	for i, pos in pilarPositions do
		createPart(house, "Pillar_" .. i, Vector3.new(2, 20, 2), CFrame.new(AUCTION_CENTER + pos), Enum.Material.Metal, Color3.fromRGB(60, 65, 70), true, true)
	end

	-- Vigas de Teto Industriais
	createPart(house, "RoofBeam_X1", Vector3.new(46, 1.5, 1.5), CFrame.new(AUCTION_CENTER + Vector3.new(0, 20, -22)), Enum.Material.Metal, Color3.fromRGB(40, 44, 48), true, true)
	createPart(house, "RoofBeam_X2", Vector3.new(46, 1.5, 1.5), CFrame.new(AUCTION_CENTER + Vector3.new(0, 20, 22)), Enum.Material.Metal, Color3.fromRGB(40, 44, 48), true, true)
	createPart(house, "RoofBeam_Z1", Vector3.new(1.5, 1.5, 44), CFrame.new(AUCTION_CENTER + Vector3.new(-22, 20, 0)), Enum.Material.Metal, Color3.fromRGB(40, 44, 48), true, true)
	createPart(house, "RoofBeam_Z2", Vector3.new(1.5, 1.5, 44), CFrame.new(AUCTION_CENTER + Vector3.new(22, 20, 0)), Enum.Material.Metal, Color3.fromRGB(40, 44, 48), true, true)

	-- 4. Plataforma Giratória (Turntable)
	local turntable = createPart(house, "Turntable", Vector3.new(18, 0.8, 18), CFrame.new(AUCTION_CENTER + Vector3.new(0, 0.7, 0)), Enum.Material.DiamondPlate, Color3.fromRGB(30, 32, 35), true, true)
	turntablePart = turntable

	-- Anel neon na borda da plataforma
	local ring = createPart(house, "TurntableRing", Vector3.new(18.6, 0.2, 18.6), CFrame.new(AUCTION_CENTER + Vector3.new(0, 0.5, 0)), Enum.Material.Neon, Color3.fromRGB(255, 185, 45), true, false)

	-- 5. Púlpito do Leiloeiro
	local podiumBase = createPart(house, "PodiumBase", Vector3.new(8, 2, 4), CFrame.new(AUCTION_CENTER + Vector3.new(0, 1.5, 18)), Enum.Material.WoodPlanks, Color3.fromRGB(90, 55, 30), true, true)
	local hammer = createPart(house, "AuctionHammer", Vector3.new(1.2, 0.5, 2.2), CFrame.new(AUCTION_CENTER + Vector3.new(0, 2.8, 18)), Enum.Material.Metal, Color3.fromRGB(220, 180, 50), true, false)
	podiumHammer = hammer

	local auctioneerSign = Instance.new("BillboardGui")
	auctioneerSign.Size = UDim2.fromOffset(200, 45)
	auctioneerSign.StudsOffset = Vector3.new(0, 2.8, 0)
	auctioneerSign.AlwaysOnTop = true
	auctioneerSign.Parent = podiumBase
	local aLabel = Instance.new("TextLabel")
	aLabel.Size = UDim2.fromScale(1, 1)
	aLabel.BackgroundTransparency = 1
	aLabel.Text = "⚖️ MESA DO LEILOEIRO"
	aLabel.TextColor3 = Color3.fromRGB(255, 225, 120)
	aLabel.TextStrokeTransparency = 0.2
	aLabel.TextScaled = true
	aLabel.Font = Enum.Font.GothamBold
	aLabel.Parent = auctioneerSign

	-- 6. Grande Placar Suspenso do Leilão
	local boardFrame = createPart(house, "SignboardFrame", Vector3.new(24, 8, 1.2), CFrame.new(AUCTION_CENTER + Vector3.new(0, 14, 0)), Enum.Material.Metal, Color3.fromRGB(20, 22, 25), true, false)

	local sg = Instance.new("SurfaceGui")
	sg.Name = "AuctionBoardGui"
	sg.Face = Enum.NormalId.Front -- Voltado para o sul (plateia)
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 30
	sg.Parent = boardFrame

	local bgFrame = Instance.new("Frame")
	bgFrame.Size = UDim2.fromScale(1, 1)
	bgFrame.BackgroundColor3 = Color3.fromRGB(15, 18, 22)
	bgFrame.BorderSizePixel = 0
	bgFrame.Parent = sg

	local tLabel = Instance.new("TextLabel")
	tLabel.Size = UDim2.fromScale(1, 0.28)
	tLabel.Position = UDim2.fromScale(0, 0.04)
	tLabel.BackgroundTransparency = 1
	tLabel.Text = "LEILÃO DE SUCATAS"
	tLabel.TextColor3 = Color3.fromRGB(255, 210, 60)
	tLabel.TextScaled = true
	tLabel.Font = Enum.Font.GothamBlack
	tLabel.Parent = bgFrame
	titleLabel = tLabel

	local sLabel = Instance.new("TextLabel")
	sLabel.Size = UDim2.fromScale(1, 0.22)
	sLabel.Position = UDim2.fromScale(0, 0.32)
	sLabel.BackgroundTransparency = 1
	sLabel.Text = "AGUARDANDO PRÓXIMO LOTE..."
	sLabel.TextColor3 = Color3.fromRGB(140, 200, 255)
	sLabel.TextScaled = true
	sLabel.Font = Enum.Font.GothamBold
	sLabel.Parent = bgFrame
	statusLabel = sLabel

	local bLabel = Instance.new("TextLabel")
	bLabel.Size = UDim2.fromScale(0.65, 0.20)
	bLabel.Position = UDim2.fromScale(0.04, 0.56)
	bLabel.BackgroundTransparency = 1
	bLabel.Text = "Lance Atual: R$ 0"
	bLabel.TextColor3 = Color3.fromRGB(80, 255, 130)
	bLabel.TextScaled = true
	bLabel.TextXAlignment = Enum.TextXAlignment.Left
	bLabel.Font = Enum.Font.GothamBold
	bLabel.Parent = bgFrame
	bidLabel = bLabel

	local tmLabel = Instance.new("TextLabel")
	tmLabel.Size = UDim2.fromScale(0.28, 0.20)
	tmLabel.Position = UDim2.fromScale(0.68, 0.56)
	tmLabel.BackgroundTransparency = 1
	tmLabel.Text = "⏱️ 00:00"
	tmLabel.TextColor3 = Color3.fromRGB(255, 120, 100)
	tmLabel.TextScaled = true
	tmLabel.Font = Enum.Font.GothamBlack
	tmLabel.Parent = bgFrame
	timerLabel = tmLabel

	local lLabel = Instance.new("TextLabel")
	lLabel.Size = UDim2.fromScale(0.92, 0.16)
	lLabel.Position = UDim2.fromScale(0.04, 0.78)
	lLabel.BackgroundTransparency = 1
	lLabel.Text = "Líder: Nenhum"
	lLabel.TextColor3 = Color3.fromRGB(210, 220, 230)
	lLabel.TextScaled = true
	lLabel.TextXAlignment = Enum.TextXAlignment.Left
	lLabel.Font = Enum.Font.Gotham
	lLabel.Parent = bgFrame
	leaderLabel = lLabel

	-- 7. Três Podiums de Lance Rápido na Plateia (Z = -14 do centro)
	buildBidPad(house, "BidPad_50", Vector3.new(-7, 0.2, -15), Color3.fromRGB(60, 220, 100), 50)
	buildBidPad(house, "BidPad_100", Vector3.new(0, 0.2, -15), Color3.fromRGB(60, 160, 255), 100)
	buildBidPad(house, "BidPad_250", Vector3.new(7, 0.2, -15), Color3.fromRGB(255, 195, 45), 250)

	house.Parent = Workspace
	houseModel = house

	-- Rotação suave contínua da mesa giratória
	if turntableConnection then turntableConnection:Disconnect() end
	local currentRotation = 0
	turntableConnection = RunService.Heartbeat:Connect(function(dt)
		if turntablePart and turntablePart.Parent then
			currentRotation = (currentRotation + dt * 15) % 360
			turntablePart.CFrame = CFrame.new(AUCTION_CENTER + Vector3.new(0, 0.7, 0)) * CFrame.Angles(0, math.rad(currentRotation), 0)
			if displayedCar and displayedCar.PrimaryPart then
				displayedCar:PivotTo(turntablePart.CFrame * CFrame.new(0, 0.8, 0))
			end
		end
	end)
end

function AuctionHouseService.SetDisplayedCar(car: Model?)
	if displayedCar and displayedCar.Parent then
		displayedCar:Destroy()
	end
	displayedCar = car
	if car and turntablePart then
		car:PivotTo(turntablePart.CFrame * CFrame.new(0, 0.8, 0))
		car.Parent = houseModel or Workspace
	end
end

function AuctionHouseService.GetDisplayedCar(): Model?
	return displayedCar
end

function AuctionHouseService.UpdateBoard(title: string, status: string, timerText: string, bidText: string, leaderText: string, statusColor: Color3?)
	if titleLabel then titleLabel.Text = title end
	if statusLabel then
		statusLabel.Text = status
		if statusColor then statusLabel.TextColor3 = statusColor end
	end
	if timerLabel then timerLabel.Text = timerText end
	if bidLabel then bidLabel.Text = bidText end
	if leaderLabel then leaderLabel.Text = leaderText end
end

function AuctionHouseService.PlayGavelEffect()
	if not podiumHammer then return end
	local startCf = podiumHammer.CFrame
	local strikeCf = startCf * CFrame.Angles(math.rad(-35), 0, 0)
	TweenService:Create(podiumHammer, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		CFrame = strikeCf,
	}):Play()
	task.delay(0.12, function()
		if podiumHammer and podiumHammer.Parent then
			TweenService:Create(podiumHammer, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				CFrame = startCf,
			}):Play()
		end
	end)
end

return AuctionHouseService
