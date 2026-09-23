--!strict

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local gui = Instance.new("ScreenGui")
gui.Name = "InteractionFeedback"
gui.ResetOnSpawn = false
gui.Parent = playerGui

local saleSound = Instance.new("Sound")
saleSound.Name = "SaleSound"
saleSound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
saleSound.Volume = 0.55
saleSound.Parent = gui

local activeHighlight: Highlight? = nil
local rightShoulder: Motor6D? = nil
local leftShoulder: Motor6D? = nil

local function showMoneyGain(amount: number)
	if amount <= 0 then return end
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.58)
	label.Size = UDim2.fromOffset(260, 70)
	label.BackgroundTransparency = 1
	label.Text = "+R$ " .. amount
	label.TextColor3 = Color3.fromRGB(80, 255, 125)
	label.TextStrokeColor3 = Color3.fromRGB(10, 45, 20)
	label.TextStrokeTransparency = 0.2
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.Parent = gui
	pcall(function() saleSound:Play() end)
	TweenService:Create(label, TweenInfo.new(0.75, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.fromScale(0.5, 0.46),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	task.delay(0.8, function() label:Destroy() end)
end

local function watchMoney()
	local leaderstats = player:WaitForChild("leaderstats")
	local money = leaderstats:WaitForChild("Dinheiro") :: IntValue
	local previous = money.Value
	money:GetPropertyChangedSignal("Value"):Connect(function()
		local difference = money.Value - previous
		previous = money.Value
		showMoneyGain(difference)
	end)
end

local function clearHighlight()
	if activeHighlight then
		activeHighlight:Destroy()
		activeHighlight = nil
	end
end

local function getAdornee(prompt: ProximityPrompt): Instance?
	local current: Instance? = prompt.Parent
	if current and current:IsA("Attachment") then
		current = current.Parent
	end
	if current and (current:IsA("BasePart") or current:IsA("Model")) then
		return current
	end
	return nil
end

ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt)
	clearHighlight()
	local target = getAdornee(prompt)
	if not target then return end
	local highlight = Instance.new("Highlight")
	highlight.Name = "InteractionHighlight"
	highlight.Adornee = target
	highlight.FillColor = Color3.fromRGB(255, 184, 55)
	highlight.OutlineColor = Color3.fromRGB(255, 245, 210)
	highlight.FillTransparency = 0.65
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = target
	activeHighlight = highlight
end)

ProximityPromptService.PromptButtonHoldEnded:Connect(clearHighlight)
ProximityPromptService.PromptHidden:Connect(clearHighlight)

local function bindCharacter(character: Model)
	rightShoulder = character:FindFirstChild("RightShoulder", true) :: Motor6D?
	leftShoulder = character:FindFirstChild("LeftShoulder", true) :: Motor6D?
end

player.CharacterAdded:Connect(bindCharacter)
if player.Character then bindCharacter(player.Character) end

RunService:BindToRenderStep("CarryPose", Enum.RenderPriority.Character.Value + 1, function(deltaTime)
	local carriedPartId = player:GetAttribute("CarriedPartId")
	local targetRight = CFrame.identity
	local targetLeft = CFrame.identity
	if carriedPartId ~= nil then
		local angle = if carriedPartId == "Engine" then -78 else -58
		targetRight = CFrame.Angles(math.rad(angle), 0, math.rad(12))
		targetLeft = CFrame.Angles(math.rad(angle), 0, math.rad(-12))
	end
	local alpha = math.clamp(deltaTime * 10, 0, 1)
	if rightShoulder then rightShoulder.Transform = rightShoulder.Transform:Lerp(targetRight, alpha) end
	if leftShoulder then leftShoulder.Transform = leftShoulder.Transform:Lerp(targetLeft, alpha) end
end)

local function showCarCompleted()
	local banner = Instance.new("TextLabel")
	banner.AnchorPoint = Vector2.new(0.5, 0.5)
	banner.Position = UDim2.fromScale(0.5, 0.24)
	banner.Size = UDim2.fromOffset(520, 90)
	banner.BackgroundColor3 = Color3.fromRGB(20, 28, 24)
	banner.BackgroundTransparency = 0.12
	banner.Text = "CARRO CONCLUÍDO  •  BÔNUS R$ " .. tostring(player:GetAttribute("LastCarBonus") or 0)
	banner.TextColor3 = Color3.fromRGB(255, 225, 95)
	banner.TextStrokeTransparency = 0.45
	banner.TextScaled = true
	banner.Font = Enum.Font.GothamBlack
	banner.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = banner

	banner.Size = UDim2.fromOffset(360, 60)
	TweenService:Create(banner, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(520, 90),
	}):Play()
	task.wait(1.8)
	local exitTween = TweenService:Create(banner, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = UDim2.fromScale(0.5, 0.16),
		TextTransparency = 1,
		BackgroundTransparency = 1,
	})
	exitTween:Play()
	exitTween.Completed:Wait()
	banner:Destroy()
end

player:GetAttributeChangedSignal("CarCompletionSerial"):Connect(function()
	task.spawn(showCarCompleted)
end)

task.spawn(watchMoney)
