--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local AuctionCatalog = require(ReplicatedStorage.Shared.AuctionCatalog)

type CatalogOffer = AuctionCatalog.CatalogOffer

export type BoxSummary = {
	BoxIndex: number,
	CurrentCarName: string,
	CycleValue: number,
	TotalParts: number,
	ScrapMultiplier: number,
	IsTrainingCar: boolean,
	HasPending: boolean,
	PendingCarName: string?,
}

-- Estados compartilhados do catálogo declarados previamente no escopo local
local lastOffers: {CatalogOffer} = {}
local lastPurchasedOffers: {[string]: boolean} = {}
local lastBoxes: {[number]: BoxSummary} = {}
local selectedBoxIndex: number = 1

local pendingOffer: CatalogOffer? = nil
local pendingBoxIndex: number? = nil
local pendingBuyBtn: TextButton? = nil
local isConfirmingPurchase: boolean = false

local updateBoxBar: () -> ()
local refreshUI: (({CatalogOffer}, {[string]: boolean}?, {[number]: BoxSummary}?) -> ())? = nil
local fetchCatalog: () -> ()
local updateTicketDisplay: () -> ()
local clearPendingModalState: () -> ()
local hideConfirmModal: () -> ()
local showConfirmModal: (offer: CatalogOffer, boxIndex: number, buyBtn: TextButton?) -> ()
local selectBox: (boxIndex: number) -> boolean

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

local boxButtons: {[number]: TextButton} = {}

updateBoxBar = function()
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

-- Função local única e centralizada para selecionar Box com validação rigorosa
selectBox = function(boxIndex: number): boolean
	if typeof(boxIndex) ~= "number" or boxIndex % 1 ~= 0 or boxIndex < 1 or boxIndex > 3 then
		return false
	end
	local unlocked = player:GetAttribute("UnlockedBoxes")
	local maxUnlocked = if typeof(unlocked) == "number" then math.clamp(unlocked, 1, 3) else 1
	if boxIndex > maxUnlocked then
		return false
	end

	selectedBoxIndex = boxIndex
	updateBoxBar()
	if refreshUI and lastOffers and #lastOffers > 0 then
		refreshUI(lastOffers, lastPurchasedOffers, lastBoxes)
	end
	return true
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
		selectBox(b)
	end)

	boxButtons[b] = btn
end

-- Scroll Frame for Offers
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Name = "OffersScroll"
scrollFrame.Size = UDim2.new(1, -36, 0, 315)
scrollFrame.Position = UDim2.fromOffset(18, 122)
scrollFrame.BackgroundTransparency = 1
scrollFrame.BorderSizePixel = 0
scrollFrame.ScrollBarThickness = 6
scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(240, 180, 45)
scrollFrame.CanvasSize = UDim2.fromOffset(0, 0)
scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.X
scrollFrame.ZIndex = 1
scrollFrame.Parent = window

local offersLayout = Instance.new("UIListLayout")
offersLayout.FillDirection = Enum.FillDirection.Horizontal
offersLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
offersLayout.Padding = UDim.new(0, 12)
offersLayout.Parent = scrollFrame

-- Camada de bloqueio cobrindo toda a janela atrás do modal (impede cliques nos cards)
local modalOverlay = Instance.new("TextButton")
modalOverlay.Name = "ModalOverlay"
modalOverlay.Size = UDim2.fromScale(1, 1)
modalOverlay.Position = UDim2.fromScale(0, 0)
modalOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
modalOverlay.BackgroundTransparency = 0.55
modalOverlay.BorderSizePixel = 0
modalOverlay.ZIndex = 40
modalOverlay.Visible = false
modalOverlay.Active = true
modalOverlay.AutoButtonColor = false
modalOverlay.Text = ""
modalOverlay.Parent = window

-- Confirmation Modal for Worse Purchases (Responsivo com limite máximo de 480px)
local confirmModal = Instance.new("Frame")
confirmModal.Name = "ConfirmWorseModal"
confirmModal.Size = UDim2.new(0.85, 0, 0, 220)
confirmModal.AnchorPoint = Vector2.new(0.5, 0.5)
confirmModal.Position = UDim2.fromScale(0.5, 0.5)
confirmModal.BackgroundColor3 = Color3.fromRGB(18, 22, 28)
confirmModal.BorderSizePixel = 0
confirmModal.ZIndex = 50
confirmModal.Visible = false
confirmModal.Parent = window

local confirmConstraint = Instance.new("UISizeConstraint")
confirmConstraint.MaxSize = Vector2.new(480, 260)
confirmConstraint.MinSize = Vector2.new(280, 180)
confirmConstraint.Parent = confirmModal

local confirmCorner = Instance.new("UICorner")
confirmCorner.CornerRadius = UDim.new(0, 12)
confirmCorner.Parent = confirmModal

local confirmStroke = Instance.new("UIStroke")
confirmStroke.Color = Color3.fromRGB(240, 140, 45)
confirmStroke.Thickness = 2
confirmStroke.Parent = confirmModal

local confirmTitle = Instance.new("TextLabel")
confirmTitle.Name = "Title"
confirmTitle.Size = UDim2.new(1, -24, 0, 28)
confirmTitle.Position = UDim2.fromOffset(12, 10)
confirmTitle.BackgroundTransparency = 1
confirmTitle.Text = "⚠️ ATENÇÃO: RENDIMENTO MENOR"
confirmTitle.TextColor3 = Color3.fromRGB(255, 160, 50)
confirmTitle.Font = Enum.Font.GothamBlack
confirmTitle.TextSize = 15
confirmTitle.ZIndex = 51
confirmTitle.Parent = confirmModal

local confirmMsg = Instance.new("TextLabel")
confirmMsg.Name = "Message"
confirmMsg.Size = UDim2.new(1, -24, 0, 110)
confirmMsg.Position = UDim2.fromOffset(12, 38)
confirmMsg.BackgroundTransparency = 1
confirmMsg.Text = ""
confirmMsg.TextColor3 = Color3.fromRGB(230, 235, 245)
confirmMsg.Font = Enum.Font.Gotham
confirmMsg.TextSize = 12
confirmMsg.TextWrapped = true
confirmMsg.ZIndex = 51
confirmMsg.Parent = confirmModal

local btnRow = Instance.new("Frame")
btnRow.Name = "ButtonRow"
btnRow.Size = UDim2.new(1, -24, 0, 42)
btnRow.Position = UDim2.new(0, 12, 1, -52)
btnRow.BackgroundTransparency = 1
btnRow.ZIndex = 51
btnRow.Parent = confirmModal

local cancelBtn = Instance.new("TextButton")
cancelBtn.Name = "CancelBtn"
cancelBtn.Size = UDim2.new(0.48, -4, 1, 0)
cancelBtn.Position = UDim2.new(0, 0, 0, 0)
cancelBtn.BackgroundColor3 = Color3.fromRGB(55, 60, 72)
cancelBtn.BorderSizePixel = 0
cancelBtn.Text = "Cancelar"
cancelBtn.TextColor3 = Color3.new(1, 1, 1)
cancelBtn.Font = Enum.Font.GothamBold
cancelBtn.TextSize = 13
cancelBtn.ZIndex = 52
cancelBtn.Parent = btnRow

local cancelCorner = Instance.new("UICorner")
cancelCorner.CornerRadius = UDim.new(0, 8)
cancelCorner.Parent = cancelBtn

local proceedBtn = Instance.new("TextButton")
proceedBtn.Name = "ProceedBtn"
proceedBtn.Size = UDim2.new(0.48, -4, 1, 0)
proceedBtn.Position = UDim2.new(0.52, 4, 0, 0)
proceedBtn.BackgroundColor3 = Color3.fromRGB(200, 55, 50)
proceedBtn.BorderSizePixel = 0
proceedBtn.Text = "Comprar mesmo assim"
proceedBtn.TextColor3 = Color3.new(1, 1, 1)
proceedBtn.Font = Enum.Font.GothamBlack
proceedBtn.TextSize = 12
proceedBtn.ZIndex = 52
proceedBtn.Parent = btnRow

local proceedCorner = Instance.new("UICorner")
proceedCorner.CornerRadius = UDim.new(0, 8)
proceedCorner.Parent = proceedBtn

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

local function getSelectedBoxSummary(): BoxSummary
	if lastBoxes and lastBoxes[selectedBoxIndex] then
		return lastBoxes[selectedBoxIndex]
	end
	return {
		BoxIndex = selectedBoxIndex,
		CurrentCarName = player:GetAttribute(string.format("Box_%d_Current", selectedBoxIndex)) or "Carro de Treinamento",
		CycleValue = 1500,
		TotalParts = 12,
		ScrapMultiplier = 1.0,
		IsTrainingCar = true,
		HasPending = player:GetAttribute(string.format("Box_%d_Pending", selectedBoxIndex)) ~= nil,
		PendingCarName = player:GetAttribute(string.format("Box_%d_Pending", selectedBoxIndex)),
	}
end

updateTicketDisplay = function()
	local leaderstats = player:FindFirstChild("leaderstats")
	local tickets = leaderstats and leaderstats:FindFirstChild("Tickets")
	local count = if tickets and tickets:IsA("IntValue") then tickets.Value else (player:GetAttribute("AuctionTickets") or 0)
	local points = player:GetAttribute("TicketPoints")
	local pointsCount = if typeof(points) == "number" then points else 0

	ticketLabel.Text = string.format("%d %s", count, if count == 1 then "TICKET" else "TICKETS")
	progressLabel.Text = string.format("Progresso do próximo Ticket: %d/12", pointsCount)
	if updateHudTicketText then updateHudTicketText(count, pointsCount) end
end

clearPendingModalState = function()
	pendingOffer = nil
	pendingBoxIndex = nil
	pendingBuyBtn = nil
end

hideConfirmModal = function()
	confirmModal.Visible = false
	modalOverlay.Visible = false
	clearPendingModalState()
end

showConfirmModal = function(offer: CatalogOffer, boxIndex: number, buyBtn: TextButton?)
	pendingOffer = offer
	pendingBoxIndex = boxIndex
	pendingBuyBtn = buyBtn
	local boxSum = getSelectedBoxSummary()
	local diffVal = boxSum.CycleValue - offer.EstimatedScrapValue
	confirmMsg.Text = string.format("Este veículo rende aproximadamente R$ %d a menos por ciclo que seu carro atual (%s, ~R$ %d).\n\nEle substituirá o veículo permanente do Box %d.\n\nDeseja continuar com a compra?", diffVal, boxSum.CurrentCarName, boxSum.CycleValue, boxIndex)
	modalOverlay.Visible = true
	confirmModal.Visible = true
end

local function updateBtnSafe(btn: TextButton?, text: string, bg: Color3?, fg: Color3?, active: boolean)
	if btn and btn.Parent ~= nil then
		btn.Text = text
		if bg then btn.BackgroundColor3 = bg end
		if fg then btn.TextColor3 = fg end
		btn.Active = active
	end
end

local function executePurchase(boxIndex: number, offerId: string, buyBtn: TextButton?)
	local isLoaded = player:GetAttribute("DataLoaded")
	local loadFailed = player:GetAttribute("DataLoadFailed")
	if isLoaded ~= true or loadFailed == true then
		feedbackLabel.Text = "Aguarde o carregamento dos seus dados antes de comprar."
		feedbackLabel.TextColor3 = Color3.fromRGB(255, 120, 60)
		return
	end

	local buyRemote = ReplicatedStorage:FindFirstChild("BuyAuctionCatalogCar")
	if not buyRemote or not buyRemote:IsA("RemoteFunction") then return end

	updateBtnSafe(buyBtn, "Processando...", nil, nil, false)

	local callOk, success, message = pcall(function()
		return buyRemote:InvokeServer(boxIndex, offerId)
	end)
	if not callOk then
		feedbackLabel.Text = "Não foi possível concluir a compra. Tente novamente."
		feedbackLabel.TextColor3 = Color3.fromRGB(255, 100, 90)
		updateBtnSafe(buyBtn, "Comprar", Color3.fromRGB(40, 150, 80), Color3.new(1, 1, 1), true)
		return
	end
	feedbackLabel.Text = message
	feedbackLabel.TextColor3 = if success then Color3.fromRGB(80, 255, 140) else Color3.fromRGB(255, 100, 90)

	if success then
		updateBtnSafe(buyBtn, "Adquirido", Color3.fromRGB(55, 60, 70), Color3.fromRGB(160, 165, 175), false)
		updateTicketDisplay()
		updateBoxBar()
		fetchCatalog()
	else
		updateBtnSafe(buyBtn, "Comprar", Color3.fromRGB(40, 150, 80), Color3.new(1, 1, 1), true)
	end
end

cancelBtn.MouseButton1Click:Connect(hideConfirmModal)

proceedBtn.MouseButton1Click:Connect(function()
	if isConfirmingPurchase then return end
	isConfirmingPurchase = true
	local offer = pendingOffer
	local bIndex = pendingBoxIndex
	local btn = pendingBuyBtn
	hideConfirmModal()
	if offer and bIndex then
		executePurchase(bIndex, offer.OfferId, btn)
	end
	isConfirmingPurchase = false
end)

local function renderOfferCard(offer: CatalogOffer, isPurchased: boolean)
	local leaderstats = player:FindFirstChild("leaderstats")
	local ticketValue = leaderstats and leaderstats:FindFirstChild("Tickets")
	local availableTickets = if ticketValue and ticketValue:IsA("IntValue") then ticketValue.Value else (player:GetAttribute("AuctionTickets") or 0)
	local missingTickets = math.max(0, offer.TicketCost - availableTickets)
	local currentBox = getSelectedBoxSummary()

	local card = Instance.new("Frame")
	card.Name = "Offer_" .. offer.OfferId
	card.Size = UDim2.fromOffset(190, 290)
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
	nameLabel.Size = UDim2.new(1, -16, 0, 32)
	nameLabel.Position = UDim2.fromOffset(8, 6)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = offer.DisplayName
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.Font = Enum.Font.GothamBlack
	nameLabel.TextSize = 13
	nameLabel.TextWrapped = true
	nameLabel.Parent = card

	-- Conservation Badge
	local badge = Instance.new("Frame")
	badge.Size = UDim2.new(1, -20, 0, 18)
	badge.Position = UDim2.fromOffset(10, 40)
	badge.BackgroundColor3 = offer.Conservation.TagColor
	badge.BorderSizePixel = 0
	badge.Parent = card

	local badgeCorner = Instance.new("UICorner")
	badgeCorner.CornerRadius = UDim.new(0, 9)
	badgeCorner.Parent = badge

	local badgeLabel = Instance.new("TextLabel")
	badgeLabel.Size = UDim2.fromScale(1, 1)
	badgeLabel.BackgroundTransparency = 1
	badgeLabel.Text = offer.Conservation.Name:upper()
	badgeLabel.TextColor3 = Color3.new(1, 1, 1)
	badgeLabel.Font = Enum.Font.GothamBlack
	badgeLabel.TextSize = 10
	badgeLabel.Parent = badge

	-- Description
	local descLabel = Instance.new("TextLabel")
	descLabel.Size = UDim2.new(1, -16, 0, 30)
	descLabel.Position = UDim2.fromOffset(8, 60)
	descLabel.BackgroundTransparency = 1
	descLabel.Text = offer.Description
	descLabel.TextColor3 = Color3.fromRGB(170, 180, 195)
	descLabel.Font = Enum.Font.Gotham
	descLabel.TextSize = 10
	descLabel.TextWrapped = true
	descLabel.Parent = card

	-- Stats Box (Height 76)
	local statsFrame = Instance.new("Frame")
	statsFrame.Size = UDim2.new(1, -16, 0, 76)
	statsFrame.Position = UDim2.fromOffset(8, 92)
	statsFrame.BackgroundColor3 = Color3.fromRGB(20, 24, 32)
	statsFrame.BorderSizePixel = 0
	statsFrame.Parent = card

	local statsCorner = Instance.new("UICorner")
	statsCorner.CornerRadius = UDim.new(0, 6)
	statsCorner.Parent = statsFrame

	local multLabel = Instance.new("TextLabel")
	multLabel.Size = UDim2.new(1, -8, 0, 17)
	multLabel.Position = UDim2.fromOffset(6, 2)
	multLabel.BackgroundTransparency = 1
	multLabel.Text = string.format("⚡ Final %.1fx (%.1fx × %.1fx)", offer.ScrapMultiplier, (AuctionCatalog.GetModel(offer.ModelId) and AuctionCatalog.GetModel(offer.ModelId).BaseMultiplier or 1), offer.Conservation.Multiplier)
	multLabel.TextColor3 = Color3.fromRGB(255, 215, 60)
	multLabel.Font = Enum.Font.GothamBold
	multLabel.TextSize = 10
	multLabel.TextXAlignment = Enum.TextXAlignment.Left
	multLabel.Parent = statsFrame

	local partsLabel = Instance.new("TextLabel")
	partsLabel.Size = UDim2.new(1, -8, 0, 17)
	partsLabel.Position = UDim2.fromOffset(6, 20)
	partsLabel.BackgroundTransparency = 1
	partsLabel.Text = string.format("🔧 Peças: %d • Atual: %d", offer.TotalPartsCount, currentBox.TotalParts)
	partsLabel.TextColor3 = Color3.fromRGB(180, 210, 240)
	partsLabel.Font = Enum.Font.Gotham
	partsLabel.TextSize = 10
	partsLabel.TextXAlignment = Enum.TextXAlignment.Left
	partsLabel.Parent = statsFrame

	local valLabel = Instance.new("TextLabel")
	valLabel.Size = UDim2.new(1, -8, 0, 17)
	valLabel.Position = UDim2.fromOffset(6, 38)
	valLabel.BackgroundTransparency = 1
	valLabel.Text = string.format("💰 Ciclo: ~R$ %d", offer.EstimatedScrapValue)
	valLabel.TextColor3 = Color3.fromRGB(120, 230, 130)
	valLabel.Font = Enum.Font.GothamBold
	valLabel.TextSize = 10
	valLabel.TextXAlignment = Enum.TextXAlignment.Left
	valLabel.Parent = statsFrame

	local pointsLabel = Instance.new("TextLabel")
	pointsLabel.Size = UDim2.new(1, -8, 0, 17)
	pointsLabel.Position = UDim2.fromOffset(6, 56)
	pointsLabel.BackgroundTransparency = 1
	pointsLabel.Text = string.format("🎟️ +%d TicketPoints ao concluir", offer.TotalPartsCount)
	pointsLabel.TextColor3 = Color3.fromRGB(240, 190, 80)
	pointsLabel.Font = Enum.Font.GothamBold
	pointsLabel.TextSize = 10
	pointsLabel.TextXAlignment = Enum.TextXAlignment.Left
	pointsLabel.Parent = statsFrame

	-- Comparison Banner Frame (Height 32)
	local compFrame = Instance.new("Frame")
	compFrame.Size = UDim2.new(1, -16, 0, 32)
	compFrame.Position = UDim2.fromOffset(8, 172)
	compFrame.BorderSizePixel = 0
	compFrame.Parent = card

	local compCorner = Instance.new("UICorner")
	compCorner.CornerRadius = UDim.new(0, 6)
	compCorner.Parent = compFrame

	local compStroke = Instance.new("UIStroke")
	compStroke.Thickness = 1
	compStroke.Parent = compFrame

	local compLabel = Instance.new("TextLabel")
	compLabel.Size = UDim2.new(1, -4, 1, 0)
	compLabel.Position = UDim2.fromOffset(2, 0)
	compLabel.BackgroundTransparency = 1
	compLabel.Font = Enum.Font.GothamBlack
	compLabel.TextSize = 10
	compLabel.TextWrapped = true
	compLabel.Parent = compFrame

	local diff = offer.EstimatedScrapValue - currentBox.CycleValue
	if diff > 0 then
		compLabel.Text = string.format("⬆ MELHORIA: +R$ %d por ciclo", diff)
		compLabel.TextColor3 = Color3.fromRGB(80, 255, 140)
		compFrame.BackgroundColor3 = Color3.fromRGB(15, 38, 25)
		compStroke.Color = Color3.fromRGB(45, 150, 80)
	elseif diff == 0 then
		compLabel.Text = "= MESMO VALOR por ciclo"
		compLabel.TextColor3 = Color3.fromRGB(240, 220, 100)
		compFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 22)
		compStroke.Color = Color3.fromRGB(160, 140, 45)
	else
		compLabel.Text = string.format("⬇ RENDE R$ %d A MENOS por ciclo", math.abs(diff))
		compLabel.TextColor3 = Color3.fromRGB(255, 110, 100)
		compFrame.BackgroundColor3 = Color3.fromRGB(42, 22, 22)
		compStroke.Color = Color3.fromRGB(180, 55, 55)
	end

	-- Ticket Price Label
	local priceLabel = Instance.new("TextLabel")
	priceLabel.Size = UDim2.new(1, -16, 0, 22)
	priceLabel.Position = UDim2.fromOffset(8, 208)
	priceLabel.BackgroundTransparency = 1
	priceLabel.Text = string.format("Custo: %d Tickets", offer.TicketCost)
	priceLabel.TextColor3 = if missingTickets > 0 then Color3.fromRGB(255, 125, 105) else Color3.fromRGB(255, 230, 130)
	priceLabel.Font = Enum.Font.GothamBlack
	priceLabel.TextSize = 13
	priceLabel.Parent = card

	-- Buy Button
	local buyBtn = Instance.new("TextButton")
	buyBtn.Size = UDim2.new(1, -16, 0, 36)
	buyBtn.Position = UDim2.fromOffset(8, 234)
	buyBtn.BorderSizePixel = 0
	buyBtn.Font = Enum.Font.GothamBlack
	buyBtn.TextSize = 13
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
		if missingTickets > 0 then return end
		local isLoaded = player:GetAttribute("DataLoaded")
		local loadFailed = player:GetAttribute("DataLoadFailed")
		if isLoaded ~= true or loadFailed == true then
			feedbackLabel.Text = "Aguarde o carregamento dos seus dados antes de comprar."
			feedbackLabel.TextColor3 = Color3.fromRGB(255, 120, 60)
			return
		end

		local boxSum = getSelectedBoxSummary()
		if offer.EstimatedScrapValue < boxSum.CycleValue then
			showConfirmModal(offer, selectedBoxIndex, buyBtn)
		else
			executePurchase(selectedBoxIndex, offer.OfferId, buyBtn)
		end
	end)
end

refreshUI = function(offers: {CatalogOffer}, purchasedOffers: {[string]: boolean}?, boxes: {[number]: BoxSummary}?)
	hideConfirmModal()
	local purchased = purchasedOffers or {}
	lastOffers = offers
	lastPurchasedOffers = purchased
	if boxes then
		lastBoxes = boxes
	end
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

fetchCatalog = function()
	hideConfirmModal()
	local getRemote = ReplicatedStorage:FindFirstChild("GetAuctionCatalog")
	if getRemote and getRemote:IsA("RemoteFunction") then
		local callOk, data = pcall(function()
			return getRemote:InvokeServer()
		end)
		if callOk and data and data.Offers then
			refreshDeadline = os.time() + (data.TimeRemaining or 300)
			local boxMap: {[number]: BoxSummary} = {}
			if data.Boxes then
				for _, b in data.Boxes do
					boxMap[b.BoxIndex] = b
				end
			end
			refreshUI(data.Offers, data.PurchasedOffers, boxMap)
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
	hideConfirmModal()
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
		hideConfirmModal()
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

if RunService:IsStudio() then
	local testBridge = Instance.new("BindableFunction")
	testBridge.Name = "CatalogClientTestingBridge"
	testBridge.OnInvoke = function(action: string, args: any)
		if action == "TriggerBuyOffer" then
			local offerId = args.OfferId
			for _, offer in ipairs(lastOffers) do
				if offer.OfferId == offerId then
					local boxSum = getSelectedBoxSummary()
					if offer.EstimatedScrapValue < boxSum.CycleValue then
						showConfirmModal(offer, selectedBoxIndex, nil)
						return { Triggered = "Modal", ModalVisible = confirmModal.Visible, Message = confirmMsg.Text }
					else
						executePurchase(selectedBoxIndex, offer.OfferId, nil)
						return { Triggered = "DirectPurchase" }
					end
				end
			end
			return { Error = "Offer not found" }
		elseif action == "ClickModalCancel" then
			local wasOpen = confirmModal.Visible
			hideConfirmModal()
			return { Cancelled = wasOpen, ModalVisible = confirmModal.Visible }
		elseif action == "ClickModalProceed" then
			if isConfirmingPurchase then return { Proceeded = false, Reason = "Debounce" } end
			isConfirmingPurchase = true
			local offer = pendingOffer
			local bIndex = pendingBoxIndex
			hideConfirmModal()
			if offer and bIndex then
				executePurchase(bIndex, offer.OfferId, nil)
				isConfirmingPurchase = false
				return { Proceeded = true, OfferId = offer.OfferId, ModalVisible = confirmModal.Visible }
			end
			isConfirmingPurchase = false
			return { Proceeded = false }
		elseif action == "SelectBox" then
			local ok = selectBox(args.BoxIndex)
			return { Success = ok, SelectedBoxIndex = selectedBoxIndex }
		elseif action == "GetModalState" then
			return {
				Visible = confirmModal.Visible,
				OverlayVisible = modalOverlay.Visible,
				OverlayActive = modalOverlay.Active,
				Title = confirmTitle.Text,
				Message = confirmMsg.Text,
				PendingOfferId = pendingOffer and pendingOffer.OfferId,
			}
		elseif action == "GetSelectedBoxSummary" then
			return getSelectedBoxSummary()
		elseif action == "GetCardComparison" then
			local offerId = args.OfferId
			local card = scrollFrame:FindFirstChild("Offer_" .. offerId)
			if card then
				for _, desc in ipairs(card:GetDescendants()) do
					if desc:IsA("TextLabel") and (desc.Text:find("MELHORIA") or desc.Text:find("RENDE") or desc.Text:find("MESMO VALOR")) then
						return desc.Text
					end
				end
			end
			return nil
		elseif action == "GetBoxBarState" then
			local result = {}
			for b = 1, 3 do
				local btn = boxButtons[b]
				table.insert(result, {
					Box = b,
					Text = btn and btn.Text or "NIL",
					BgColor = btn and btn.BackgroundColor3 or Color3.new(),
				})
			end
			return result
		end
		return nil
	end
	testBridge.Parent = screenGui
end
