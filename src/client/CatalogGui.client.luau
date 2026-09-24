--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local AuctionCatalog = require(ReplicatedStorage.Shared.AuctionCatalog)

type CatalogOffer = AuctionCatalog.CatalogOffer

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CatalogGui"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 10
screenGui.Parent = playerGui

-- Modal Backdrop
local backdrop = Instance.new("Frame")
backdrop.Name = "Backdrop"
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
backdrop.BackgroundTransparency = 0.5
backdrop.Visible = false
backdrop.Parent = screenGui

-- Main Card Window
local window = Instance.new("Frame")
window.Name = "Window"
window.AnchorPoint = Vector2.new(0.5, 0.5)
window.Position = UDim2.fromScale(0.5, 0.5)
window.Size = UDim2.fromOffset(820, 520)
window.BackgroundColor3 = Color3.fromRGB(20, 24, 30)
window.BorderSizePixel = 0
window.Parent = backdrop

local winCorner = Instance.new("UICorner")
winCorner.CornerRadius = UDim.new(0, 12)
winCorner.Parent = window

local winStroke = Instance.new("UIStroke")
winStroke.Color = Color3.fromRGB(240, 180, 45)
winStroke.Thickness = 2
winStroke.Parent = window

-- Header Frame
local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 56)
header.BackgroundColor3 = Color3.fromRGB(15, 18, 22)
header.BorderSizePixel = 0
header.Parent = window

local headerCorner = Instance.new("UICorner")
headerCorner.CornerRadius = UDim.new(0, 12)
headerCorner.Parent = header

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Size = UDim2.new(0.45, 0, 0.52, 0)
titleLabel.Position = UDim2.fromOffset(18, 5)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "⚖️ CATÁLOGO DE SUCATAS (LEILÃO)"
titleLabel.TextColor3 = Color3.fromRGB(255, 215, 60)
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Font = Enum.Font.GothamBlack
titleLabel.TextSize = 17
titleLabel.Parent = header

local progressLabel = Instance.new("TextLabel")
progressLabel.Name = "TicketProgress"
progressLabel.Size = UDim2.new(0.45, 0, 0.44, 0)
progressLabel.Position = UDim2.fromOffset(18, 30)
progressLabel.BackgroundTransparency = 1
progressLabel.Text = "Progresso do próximo Ticket: 0/12"
progressLabel.TextColor3 = Color3.fromRGB(150, 200, 255)
progressLabel.TextXAlignment = Enum.TextXAlignment.Left
progressLabel.Font = Enum.Font.GothamBold
progressLabel.TextSize = 12
progressLabel.Parent = header

-- Timer Label
local timerLabel = Instance.new("TextLabel")
timerLabel.Name = "Timer"
timerLabel.Size = UDim2.new(0.25, 0, 1, 0)
timerLabel.Position = UDim2.new(0.45, 0, 0, 0)
timerLabel.BackgroundTransparency = 1
timerLabel.Text = "🔄 Novas em: 05:00"
timerLabel.TextColor3 = Color3.fromRGB(140, 200, 255)
timerLabel.Font = Enum.Font.GothamBold
timerLabel.TextSize = 15
timerLabel.Parent = header

-- Ticket Balance Pill
local ticketPill = Instance.new("Frame")
ticketPill.Name = "TicketPill"
ticketPill.Size = UDim2.fromOffset(140, 34)
ticketPill.Position = UDim2.new(1, -195, 0.5, -17)
ticketPill.BackgroundColor3 = Color3.fromRGB(35, 42, 54)
ticketPill.BorderSizePixel = 0
ticketPill.Parent = header

local pillCorner = Instance.new("UICorner")
pillCorner.CornerRadius = UDim.new(0, 17)
pillCorner.Parent = ticketPill

local pillStroke = Instance.new("UIStroke")
pillStroke.Color = Color3.fromRGB(240, 180, 45)
pillStroke.Thickness = 1.5
pillStroke.Parent = ticketPill

local ticketLabel = Instance.new("TextLabel")
ticketLabel.Name = "Tickets"
ticketLabel.Size = UDim2.fromScale(1, 1)
ticketLabel.BackgroundTransparency = 1
ticketLabel.Text = "🎟️ 0 Tickets"
ticketLabel.TextColor3 = Color3.fromRGB(255, 230, 130)
ticketLabel.Font = Enum.Font.GothamBlack
ticketLabel.TextSize = 14
ticketLabel.Parent = ticketPill

-- Close Button
local closeBtn = Instance.new("TextButton")
closeBtn.Name = "CloseBtn"
closeBtn.Size = UDim2.fromOffset(36, 36)
closeBtn.Position = UDim2.new(1, -46, 0.5, -18)
closeBtn.BackgroundColor3 = Color3.fromRGB(180, 45, 40)
closeBtn.BorderSizePixel = 0
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 18
closeBtn.Parent = header

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 18)
closeCorner.Parent = closeBtn

-- Box Selector Bar
local boxBar = Instance.new("Frame")
boxBar.Name = "BoxBar"
boxBar.Size = UDim2.new(1, -36, 0, 48)
boxBar.Position = UDim2.fromOffset(18, 66)
boxBar.BackgroundColor3 = Color3.fromRGB(25, 30, 38)
boxBar.BorderSizePixel = 0
boxBar.Parent = window

local boxBarCorner = Instance.new("UICorner")
boxBarCorner.CornerRadius = UDim.new(0, 8)
boxBarCorner.Parent = boxBar

local boxBarLabel = Instance.new("TextLabel")
boxBarLabel.Size = UDim2.new(0.24, 0, 1, 0)
boxBarLabel.Position = UDim2.fromOffset(12, 0)
boxBarLabel.BackgroundTransparency = 1
boxBarLabel.Text = "📦 Destino da Entrega:"
boxBarLabel.TextColor3 = Color3.fromRGB(190, 200, 215)
boxBarLabel.Font = Enum.Font.GothamBold
boxBarLabel.TextSize = 14
boxBarLabel.TextXAlignment = Enum.TextXAlignment.Left
boxBarLabel.Parent = boxBar

local selectedBoxIndex = 1
local boxButtons: {[number]: TextButton} = {}

local function updateBoxBar()
	local unlocked = player:GetAttribute("UnlockedBoxes")
	local maxUnlocked = if typeof(unlocked) == "number" then math.clamp(unlocked, 1, 3) else 1

	for b = 1, 3 do
		local btn = boxButtons[b]
		if not btn then continue end
		local isUnlocked = b <= maxUnlocked
		local isSelected = b == selectedBoxIndex

		local currentCar = player:GetAttribute(string.format("Box_%d_Current", b)) or "Carro Padrão"
		local pendingCar = player:GetAttribute(string.format("Box_%d_Pending", b))

		if not isUnlocked then
			btn.BackgroundColor3 = Color3.fromRGB(45, 48, 55)
			btn.TextColor3 = Color3.fromRGB(120, 125, 135)
			btn.Text = string.format("🔒 Box %d [Bloqueado]", b)
		elseif isSelected then
			btn.BackgroundColor3 = Color3.fromRGB(45, 145, 85)
			btn.TextColor3 = Color3.new(1, 1, 1)
			if pendingCar then
				btn.Text = string.format("✅ Box %d (Fila: %s)", b, pendingCar)
			else
				btn.Text = string.format("✅ Box %d (%s)", b, currentCar)
			end
		else
			btn.BackgroundColor3 = Color3.fromRGB(35, 42, 54)
			btn.TextColor3 = Color3.fromRGB(200, 210, 225)
			btn.Text = string.format("Box %d (%s)", b, currentCar)
		end
	end
end

for b = 1, 3 do
	local btn = Instance.new("TextButton")
	btn.Name = "BoxBtn_" .. b
	btn.Size = UDim2.new(0.24, -8, 0, 36)
	btn.Position = UDim2.new(0.25 + (b - 1) * 0.25, 4, 0.5, -18)
	btn.BackgroundColor3 = Color3.fromRGB(35, 42, 54)
	btn.BorderSizePixel = 0
	btn.Text = "Box " .. b
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 12
	btn.Parent = boxBar

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 6)
	btnCorner.Parent = btn

	btn.MouseButton1Click:Connect(function()
		local unlocked = player:GetAttribute("UnlockedBoxes")
		local maxUnlocked = if typeof(unlocked) == "number" then math.clamp(unlocked, 1, 3) else 1
		if b <= maxUnlocked then
			selectedBoxIndex = b
			updateBoxBar()
		end
	end)

	boxButtons[b] = btn
end

-- Scroll Frame for Offers
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Name = "OffersScroll"
scrollFrame.Size = UDim2.new(1, -36, 0, 335)
scrollFrame.Position = UDim2.fromOffset(18, 122)
scrollFrame.BackgroundTransparency = 1
scrollFrame.BorderSizePixel = 0
scrollFrame.ScrollBarThickness = 6
scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(240, 180, 45)
scrollFrame.CanvasSize = UDim2.fromOffset(0, 0)
scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.X
scrollFrame.Parent = window

local offersLayout = Instance.new("UIListLayout")
offersLayout.FillDirection = Enum.FillDirection.Horizontal
offersLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
offersLayout.Padding = UDim.new(0, 12)
offersLayout.Parent = scrollFrame

-- Footer Banner / Feedback
local footer = Instance.new("Frame")
footer.Name = "Footer"
footer.Size = UDim2.new(1, -36, 0, 45)
footer.Position = UDim2.new(0, 18, 1, -55)
footer.BackgroundTransparency = 1
footer.Parent = window

local feedbackLabel = Instance.new("TextLabel")
feedbackLabel.Name = "Feedback"
feedbackLabel.Size = UDim2.new(1, 0, 0.5, 0)
feedbackLabel.Position = UDim2.fromOffset(0, 0)
feedbackLabel.BackgroundTransparency = 1
feedbackLabel.Text = "Veículos adquiridos permanecem no Box até serem substituídos."
feedbackLabel.TextColor3 = Color3.fromRGB(150, 190, 230)
feedbackLabel.Font = Enum.Font.Gotham
feedbackLabel.TextSize = 13
feedbackLabel.Parent = footer

local hintLabel = Instance.new("TextLabel")
hintLabel.Name = "Hint"
hintLabel.Size = UDim2.new(1, 0, 0.5, 0)
hintLabel.Position = UDim2.fromOffset(0, 22)
hintLabel.BackgroundTransparency = 1
hintLabel.Text = "Conclua o carro: cada peça vendável presente vale 1 ponto • 12 pontos = 1 Ticket."
hintLabel.TextColor3 = Color3.fromRGB(120, 130, 145)
hintLabel.Font = Enum.Font.Gotham
hintLabel.TextSize = 12
hintLabel.Parent = footer

-- Helpers & Network
local refreshDeadline = os.time() + 300
local updateHudTicketText: ((number, number) -> ())? = nil

local function updateTicketDisplay()
	local leaderstats = player:FindFirstChild("leaderstats")
	local tickets = leaderstats and leaderstats:FindFirstChild("Tickets")
	local count = if tickets and tickets:IsA("IntValue") then tickets.Value else (player:GetAttribute("AuctionTickets") or 0)
	local points = player:GetAttribute("TicketPoints")
	local pointsCount = if typeof(points) == "number" then points else 0

	ticketLabel.Text = string.format("%d %s", count, if count == 1 then "TICKET" else "TICKETS")
	progressLabel.Text = string.format("Progresso do próximo Ticket: %d/12", pointsCount)
	if updateHudTicketText then updateHudTicketText(count, pointsCount) end
end

local function renderOfferCard(offer: CatalogOffer, isPurchased: boolean)
	local leaderstats = player:FindFirstChild("leaderstats")
	local ticketValue = leaderstats and leaderstats:FindFirstChild("Tickets")
	local availableTickets = if ticketValue and ticketValue:IsA("IntValue") then ticketValue.Value else (player:GetAttribute("AuctionTickets") or 0)
	local missingTickets = math.max(0, offer.TicketCost - availableTickets)
	local card = Instance.new("Frame")
	card.Name = "Offer_" .. offer.OfferId
	card.Size = UDim2.fromOffset(180, 315)
	card.BackgroundColor3 = Color3.fromRGB(28, 34, 44)
	card.BorderSizePixel = 0
	card.Parent = scrollFrame

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 10)
	cardCorner.Parent = card

	local cardStroke = Instance.new("UIStroke")
	cardStroke.Color = offer.Conservation.TagColor
	cardStroke.Thickness = 1.5
	cardStroke.Parent = card

	-- Model Name
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, -16, 0, 38)
	nameLabel.Position = UDim2.fromOffset(8, 8)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = offer.DisplayName
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.Font = Enum.Font.GothamBlack
	nameLabel.TextSize = 14
	nameLabel.TextWrapped = true
	nameLabel.Parent = card

	-- Conservation Badge
	local badge = Instance.new("Frame")
	badge.Size = UDim2.new(1, -24, 0, 22)
	badge.Position = UDim2.fromOffset(12, 48)
	badge.BackgroundColor3 = offer.Conservation.TagColor
	badge.BorderSizePixel = 0
	badge.Parent = card

	local badgeCorner = Instance.new("UICorner")
	badgeCorner.CornerRadius = UDim.new(0, 11)
	badgeCorner.Parent = badge

	local badgeLabel = Instance.new("TextLabel")
	badgeLabel.Size = UDim2.fromScale(1, 1)
	badgeLabel.BackgroundTransparency = 1
	badgeLabel.Text = offer.Conservation.Name:upper()
	badgeLabel.TextColor3 = Color3.new(1, 1, 1)
	badgeLabel.Font = Enum.Font.GothamBlack
	badgeLabel.TextSize = 11
	badgeLabel.Parent = badge

	-- Description
	local descLabel = Instance.new("TextLabel")
	descLabel.Size = UDim2.new(1, -16, 0, 48)
	descLabel.Position = UDim2.fromOffset(8, 74)
	descLabel.BackgroundTransparency = 1
	descLabel.Text = offer.Description
	descLabel.TextColor3 = Color3.fromRGB(170, 180, 195)
	descLabel.Font = Enum.Font.Gotham
	descLabel.TextSize = 11
	descLabel.TextWrapped = true
	descLabel.Parent = card

	-- Stats Box
	local statsFrame = Instance.new("Frame")
	statsFrame.Size = UDim2.new(1, -16, 0, 72)
	statsFrame.Position = UDim2.fromOffset(8, 126)
	statsFrame.BackgroundColor3 = Color3.fromRGB(20, 24, 32)
	statsFrame.BorderSizePixel = 0
	statsFrame.Parent = card

	local statsCorner = Instance.new("UICorner")
	statsCorner.CornerRadius = UDim.new(0, 6)
	statsCorner.Parent = statsFrame

	local s1 = Instance.new("TextLabel")
	s1.Size = UDim2.new(1, -8, 0, 20)
	s1.Position = UDim2.fromOffset(4, 4)
	s1.BackgroundTransparency = 1
	local conservationMultiplier = offer.Conservation.Multiplier
	local modelMultiplier = if conservationMultiplier > 0 then offer.ScrapMultiplier / conservationMultiplier else offer.ScrapMultiplier
	s1.Text = string.format("⚡ Final %.1fx (%.1fx × %.1fx)", offer.ScrapMultiplier, modelMultiplier, conservationMultiplier)
	s1.TextColor3 = Color3.fromRGB(255, 215, 60)
	s1.Font = Enum.Font.GothamBold
	s1.TextSize = 12
	s1.TextXAlignment = Enum.TextXAlignment.Left
	s1.Parent = statsFrame

	local s2 = Instance.new("TextLabel")
	s2.Size = UDim2.new(1, -8, 0, 20)
	s2.Position = UDim2.fromOffset(4, 24)
	s2.BackgroundTransparency = 1
	s2.Text = string.format("🔧 Peças: %d instaladas", offer.TotalPartsCount)
	s2.TextColor3 = Color3.fromRGB(140, 210, 255)
	s2.Font = Enum.Font.Gotham
	s2.TextSize = 11
	s2.TextXAlignment = Enum.TextXAlignment.Left
	s2.Parent = statsFrame

	local s3 = Instance.new("TextLabel")
	s3.Size = UDim2.new(1, -8, 0, 20)
	s3.Position = UDim2.fromOffset(4, 44)
	s3.BackgroundTransparency = 1
	s3.Text = string.format("💰 Est.: ~R$ %d", offer.EstimatedScrapValue)
	s3.TextColor3 = Color3.fromRGB(80, 255, 140)
	s3.Font = Enum.Font.GothamBold
	s3.TextSize = 11
	s3.TextXAlignment = Enum.TextXAlignment.Left
	s3.Parent = statsFrame

	-- Ticket Price Label
	local priceLabel = Instance.new("TextLabel")
	priceLabel.Size = UDim2.new(1, -16, 0, 24)
	priceLabel.Position = UDim2.fromOffset(8, 206)
	priceLabel.BackgroundTransparency = 1
	priceLabel.Text = string.format("Custo: %d Tickets", offer.TicketCost)
	priceLabel.TextColor3 = if missingTickets > 0 then Color3.fromRGB(255, 125, 105) else Color3.fromRGB(255, 230, 130)
	priceLabel.Font = Enum.Font.GothamBlack
	priceLabel.TextSize = 14
	priceLabel.Parent = card

	-- Buy Button
	local buyBtn = Instance.new("TextButton")
	buyBtn.Size = UDim2.new(1, -16, 0, 38)
	buyBtn.Position = UDim2.fromOffset(8, 236)
	buyBtn.BorderSizePixel = 0
	buyBtn.Font = Enum.Font.GothamBlack
	buyBtn.TextSize = 14
	buyBtn.Parent = card

	local buyCorner = Instance.new("UICorner")
	buyCorner.CornerRadius = UDim.new(0, 8)
	buyCorner.Parent = buyBtn

	if isPurchased then
		buyBtn.Text = "Adquirido"
		buyBtn.BackgroundColor3 = Color3.fromRGB(55, 60, 70)
		buyBtn.TextColor3 = Color3.fromRGB(160, 165, 175)
		buyBtn.Active = false
	elseif missingTickets > 0 then
		buyBtn.Text = string.format("FALTAM %d TICKETS", missingTickets)
		buyBtn.BackgroundColor3 = Color3.fromRGB(75, 61, 60)
		buyBtn.TextColor3 = Color3.fromRGB(235, 165, 150)
		buyBtn.Active = false
	else
		buyBtn.Text = "Comprar"
		buyBtn.BackgroundColor3 = Color3.fromRGB(40, 150, 80)
		buyBtn.TextColor3 = Color3.new(1, 1, 1)
		buyBtn.Active = true
	end

	buyBtn.MouseButton1Click:Connect(function()
		if isPurchased then return end
		local isLoaded = player:GetAttribute("DataLoaded")
		local loadFailed = player:GetAttribute("DataLoadFailed")
		if isLoaded ~= true or loadFailed == true then
			feedbackLabel.Text = "Aguarde o carregamento dos seus dados antes de comprar."
			feedbackLabel.TextColor3 = Color3.fromRGB(255, 120, 60)
			return
		end

		local buyRemote = ReplicatedStorage:FindFirstChild("BuyAuctionCatalogCar")
		if not buyRemote or not buyRemote:IsA("RemoteFunction") then return end

		buyBtn.Text = "Processando..."
		buyBtn.Active = false

		local callOk, success, message = pcall(function()
			return buyRemote:InvokeServer(selectedBoxIndex, offer.OfferId)
		end)
		if not callOk then
			feedbackLabel.Text = "Não foi possível concluir a compra. Tente novamente."
			feedbackLabel.TextColor3 = Color3.fromRGB(255, 100, 90)
			buyBtn.Active = true
			buyBtn.Text = "Comprar"
			return
		end
		feedbackLabel.Text = message
		feedbackLabel.TextColor3 = if success then Color3.fromRGB(80, 255, 140) else Color3.fromRGB(255, 100, 90)

		if success then
			buyBtn.Text = "Adquirido"
			buyBtn.BackgroundColor3 = Color3.fromRGB(55, 60, 70)
			buyBtn.TextColor3 = Color3.fromRGB(160, 165, 175)
			buyBtn.Active = false
			updateTicketDisplay()
			updateBoxBar()
		else
			buyBtn.Active = true
			buyBtn.Text = "Comprar"
		end
	end)
end

local lastOffers: {CatalogOffer} = {}
local lastPurchasedOffers: {[string]: boolean} = {}

local function refreshUI(offers: {CatalogOffer}, purchasedOffers: {[string]: boolean}?)
	local purchased = purchasedOffers or {}
	lastOffers = offers
	lastPurchasedOffers = purchased
	for _, child in scrollFrame:GetChildren() do
		if child:IsA("Frame") then child:Destroy() end
	end
	for _, offer in offers do
		local isPurchased = purchased[offer.OfferId] == true
		renderOfferCard(offer, isPurchased)
	end
	updateTicketDisplay()
	updateBoxBar()
end

local function fetchCatalog()
	local getRemote = ReplicatedStorage:FindFirstChild("GetAuctionCatalog")
	if getRemote and getRemote:IsA("RemoteFunction") then
		local callOk, data = pcall(function()
			return getRemote:InvokeServer()
		end)
		if callOk and data and data.Offers then
			refreshDeadline = os.time() + (data.TimeRemaining or 300)
			refreshUI(data.Offers, data.PurchasedOffers)
		elseif not callOk then
			feedbackLabel.Text = "Não foi possível carregar o catálogo. Tente novamente."
			feedbackLabel.TextColor3 = Color3.fromRGB(255, 100, 90)
		end
	end
end

local function openCatalog()
	backdrop.Visible = true
	updateBoxBar()
	updateTicketDisplay()
	fetchCatalog()
end

local function closeCatalog()
	backdrop.Visible = false
end

closeBtn.MouseButton1Click:Connect(closeCatalog)

-- HUD Quick Access Button (Left side of screen)
local hudBtn = Instance.new("TextButton")
hudBtn.Name = "OpenCatalogHudBtn"
hudBtn.Size = UDim2.fromOffset(210, 40)
hudBtn.Position = UDim2.new(0, 20, 0, 130)
hudBtn.BackgroundColor3 = Color3.fromRGB(24, 30, 42)
hudBtn.BorderSizePixel = 0
hudBtn.Text = "CATÁLOGO  •  0 TICKETS (0/12)"
hudBtn.TextColor3 = Color3.fromRGB(255, 215, 60)
hudBtn.Font = Enum.Font.GothamBlack
hudBtn.TextSize = 12
hudBtn.Parent = screenGui

updateHudTicketText = function(count: number, points: number)
	hudBtn.Text = string.format("CATÁLOGO  •  %d %s (%d/12)", count, if count == 1 then "TICKET" else "TICKETS", points)
end
updateTicketDisplay()

local hudCorner = Instance.new("UICorner")
hudCorner.CornerRadius = UDim.new(0, 8)
hudCorner.Parent = hudBtn

local hudStroke = Instance.new("UIStroke")
hudStroke.Color = Color3.fromRGB(240, 180, 45)
hudStroke.Thickness = 1.5
hudStroke.Parent = hudBtn

hudBtn.MouseButton1Click:Connect(function()
	if backdrop.Visible then
		closeCatalog()
	else
		openCatalog()
	end
end)

local toggleBindable = Instance.new("BindableFunction")
toggleBindable.Name = "ToggleCatalog"
toggleBindable.OnInvoke = function()
	if backdrop.Visible then
		closeCatalog()
	else
		openCatalog()
	end
	return backdrop.Visible
end
toggleBindable.Parent = screenGui

screenGui:GetAttributeChangedSignal("IsOpen"):Connect(function()
	local open = screenGui:GetAttribute("IsOpen")
	if open == true then
		openCatalog()
	elseif open == false then
		closeCatalog()
	end
end)

-- Click outside window to dismiss
backdrop.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		local pos = input.Position
		local winPos = window.AbsolutePosition
		local winSize = window.AbsoluteSize
		local insideWindow = (pos.X >= winPos.X and pos.X <= winPos.X + winSize.X and pos.Y >= winPos.Y and pos.Y <= winPos.Y + winSize.Y)
		if not insideWindow then
			closeCatalog()
		end
	end
end)

-- Open via Proximity Prompt
ProximityPromptService.PromptTriggered:Connect(function(prompt, triggerPlayer)
	if triggerPlayer == player and prompt.Name == "CatalogPrompt" then
		openCatalog()
	end
end)

-- Live Reactive Updates
local leaderstats = player:WaitForChild("leaderstats", 10)
if leaderstats then
	local tickets = leaderstats:WaitForChild("Tickets", 10)
	if tickets and tickets:IsA("IntValue") then
		tickets.Changed:Connect(function()
			updateTicketDisplay()
			if backdrop.Visible and #lastOffers > 0 then
				refreshUI(lastOffers, lastPurchasedOffers)
			end
		end)
	end
end
player:GetAttributeChangedSignal("AuctionTickets"):Connect(updateTicketDisplay)
player:GetAttributeChangedSignal("TicketPoints"):Connect(updateTicketDisplay)
player:GetAttributeChangedSignal("UnlockedBoxes"):Connect(updateBoxBar)

-- Remote Event for automatic 5-minute rotation
local catalogRefreshedEvent = ReplicatedStorage:WaitForChild("AuctionCatalogRefreshed", 10)
if catalogRefreshedEvent and catalogRefreshedEvent:IsA("RemoteEvent") then
	catalogRefreshedEvent.OnClientEvent:Connect(function(newDeadline: number)
		refreshDeadline = newDeadline or (os.time() + 300)
		if backdrop.Visible then
			fetchCatalog()
		end
	end)
end

-- Timer countdown loop
task.spawn(function()
	while true do
		task.wait(1)
		local remaining = math.max(0, refreshDeadline - os.time())
		local mins = math.floor(remaining / 60)
		local secs = remaining % 60
		timerLabel.Text = string.format("🔄 Novas em: %02d:%02d", mins, secs)
	end
end)
