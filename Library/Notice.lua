local cloneref = (cloneref or clonereference or function(instance)
	return instance
end)

local TweenService = cloneref(game:GetService("TweenService"))
local CoreGui = cloneref(game:GetService("CoreGui"))
local Players = cloneref(game:GetService("Players"))

local protectgui = protectgui or (syn and syn.protect_gui) or function() end
local gethui = gethui or function()
	return CoreGui
end

local GUI_NAME = "Tailor"
local CONTAINER_NAME = "NotifyContainer"
local MAX_VISIBLE = 5
local DEFAULT_LENGTH = 3
local SLIDE_OFFSET = 50
local CARD_WIDTH = 270

local THEME = {
	BackgroundTop = Color3.fromRGB(32, 32, 40),
	BackgroundBottom = Color3.fromRGB(20, 20, 26),
	Stroke = Color3.fromRGB(70, 70, 88),
	Title = Color3.fromRGB(255, 255, 255),
	Text = Color3.fromRGB(190, 192, 205),
	Track = Color3.fromRGB(45, 45, 56),
	Neutral = Color3.fromRGB(52, 52, 64),
}

local ACCENTS = {
	info = Color3.fromRGB(80, 160, 255),
	success = Color3.fromRGB(80, 210, 130),
	warning = Color3.fromRGB(255, 190, 70),
	error = Color3.fromRGB(245, 90, 90),
}

local BG_VISIBLE = 0.1
local STROKE_VISIBLE = 0.35

local TWEEN_SLIDE_IN = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local TWEEN_FADE_IN = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TWEEN_SLIDE_OUT = TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
local TWEEN_FADE_OUT = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local TWEEN_COLLAPSE = TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut)

local function create(className, props, parent)
	local inst = Instance.new(className)
	for key, value in pairs(props) do
		inst[key] = value
	end
	inst.Parent = parent
	return inst
end

local function play(inst, info, props)
	local tween = TweenService:Create(inst, info, props)
	tween:Play()
	return tween
end

local function mountGui(gui)
	pcall(protectgui, gui)
	local ok = pcall(function()
		gui.Parent = gethui()
	end)
	if not (ok and gui.Parent) then
		local player = Players.LocalPlayer or Players.PlayerAdded:Wait()
		gui.Parent = player:WaitForChild("PlayerGui", 10)
	end
end

local function getContainer()
	local root = gethui()
	local gui = root:FindFirstChild(GUI_NAME)

	if not gui then
		gui = create("ScreenGui", {
			Name = GUI_NAME,
			ResetOnSpawn = false,
			DisplayOrder = 998,
			IgnoreGuiInset = true,
		})
		mountGui(gui)
	end

	local existing = gui:FindFirstChild(CONTAINER_NAME)
	if existing then
		return existing
	end

	local container = create("Frame", {
		Name = CONTAINER_NAME,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -20, 1, -20),
		Size = UDim2.new(0, CARD_WIDTH, 1, -40),
		ClipsDescendants = false,
	}, gui)

	create("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		Padding = UDim.new(0, 0),
	}, container)

	return container
end

local container = getContainer()
local active = {}
local orderCounter = 0

local function makeButton(parent, config, defaultText, color, widthScale, onClick)
	local btn = create("TextButton", {
		Size = UDim2.new(widthScale, widthScale < 1 and -4 or 0, 1, 0),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		AutoButtonColor = true,
		Font = Enum.Font.GothamBold,
		Text = config.Text or defaultText,
		TextColor3 = THEME.Title,
		TextSize = 12,
	}, parent)

	create("UICorner", { CornerRadius = UDim.new(0, 6) }, btn)

	btn.MouseButton1Click:Connect(function()
		if config.Callback then
			task.spawn(function()
				local ok, err = pcall(config.Callback)
				if not ok then
					warn("[Tailor Notify] 回调执行异常: " .. tostring(err))
				end
			end)
		end
		onClick()
	end)
end

local function notify(config)
	local cfg = config or {}

	local accentColor = ACCENTS[cfg.Type or "info"] or ACCENTS.info
	local hasButtons = cfg.Accept ~= nil or cfg.Dismiss ~= nil
	local autoClose = (not hasButtons) or cfg.Length ~= nil
	local length = math.max(cfg.Length or DEFAULT_LENGTH, 0.5)

	local title = cfg.Title or "提醒"
	local description = cfg.Description or ""
	local hasDesc = (description ~= "")

	while #active >= MAX_VISIBLE do
		local oldest = table.remove(active, 1)
		if oldest then
			oldest()
		end
	end

	orderCounter += 1

	local textLen = #description
	local estLines = hasDesc and (textLen > 60 and 3 or (textLen > 28 and 2 or 1)) or 0
	local cardHeight = 36 + (estLines * 16) + (hasButtons and 36 or 0) + (autoClose and 8 or 0)
	cardHeight = math.clamp(cardHeight, 56, 140)

	local wrapper = create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, cardHeight + 10),
		LayoutOrder = orderCounter,
	}, container)

	local card = create("Frame", {
		Size = UDim2.new(1, 0, 0, cardHeight),
		Position = UDim2.new(1, SLIDE_OFFSET, 0, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, wrapper)
	create("UICorner", { CornerRadius = UDim.new(0, 9) }, card)
	create("UIGradient", {
		Color = ColorSequence.new(THEME.BackgroundTop, THEME.BackgroundBottom),
		Rotation = 90,
	}, card)

	local stroke = create("UIStroke", {
		Color = THEME.Stroke:Lerp(accentColor, 0.3),
		Thickness = 1.2,
		Transparency = 1,
	}, card)

	local accent = create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 8, 0.5, 0),
		Size = UDim2.new(0, 3, 0, math.max(cardHeight - 20, 16)),
		BackgroundColor3 = accentColor,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, card)
	create("UICorner", { CornerRadius = UDim.new(1, 0) }, accent)

	local content = create("CanvasGroup", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		GroupTransparency = 1,
		ZIndex = 2,
	}, card)
	create("UIPadding", {
		PaddingTop = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 10),
		PaddingLeft = UDim.new(0, 20),
		PaddingRight = UDim.new(0, 14),
	}, content)
	create("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 4),
	}, content)

	create("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 16),
		Font = Enum.Font.GothamBold,
		Text = title,
		TextColor3 = THEME.Title,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 1,
	}, content)

	if hasDesc then
		create("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, estLines * 16),
			Font = Enum.Font.GothamMedium,
			Text = description,
			TextColor3 = THEME.Text,
			TextSize = 11,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			LayoutOrder = 2,
		}, content)
	end

	local closed = false
	local progressTween = nil
	local closeFn

	local function close()
		if closed then return end
		closed = true

		local index = table.find(active, closeFn)
		if index then
			table.remove(active, index)
		end

		if progressTween then
			progressTween:Cancel()
			progressTween:Destroy()
			progressTween = nil
		end

		play(card, TWEEN_SLIDE_OUT, { Position = UDim2.new(1, SLIDE_OFFSET, 0, 0) })
		play(card, TWEEN_FADE_OUT, { BackgroundTransparency = 1 })
		play(stroke, TWEEN_FADE_OUT, { Transparency = 1 })
		play(accent, TWEEN_FADE_OUT, { BackgroundTransparency = 1 })
		play(content, TWEEN_FADE_OUT, { GroupTransparency = 1 })

		task.delay(0.2, function()
			if not wrapper.Parent then return end
			local collapse = play(wrapper, TWEEN_COLLAPSE, { Size = UDim2.new(1, 0, 0, 0) })
			collapse.Completed:Connect(function()
				wrapper:Destroy()
			end)
		end)

		task.delay(1.0, function()
			if wrapper.Parent then
				wrapper:Destroy()
			end
		end)
	end
	closeFn = close
	table.insert(active, close)

	if autoClose then
		local track = create("Frame", {
			BackgroundColor3 = THEME.Track,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 2),
			LayoutOrder = 3,
		}, content)
		create("UICorner", { CornerRadius = UDim.new(1, 0) }, track)

		local fill = create("Frame", {
			BackgroundColor3 = accentColor,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 1, 0),
		}, track)
		create("UICorner", { CornerRadius = UDim.new(1, 0) }, fill)

		progressTween = TweenService:Create(fill, TweenInfo.new(length, Enum.EasingStyle.Linear), {
			Size = UDim2.new(0, 0, 1, 0),
		})
	end

	if hasButtons then
		local row = create("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 24),
			LayoutOrder = 4,
		}, content)
		create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}, row)

		local width = (cfg.Accept ~= nil and cfg.Dismiss ~= nil) and 0.5 or 1

		if cfg.Accept then
			makeButton(row, cfg.Accept, "确认", accentColor:Lerp(Color3.fromRGB(0, 0, 0), 0.25), width, close)
		end
		if cfg.Dismiss then
			makeButton(row, cfg.Dismiss, "关闭", THEME.Neutral, width, close)
		end
	end

	play(card, TWEEN_SLIDE_IN, { Position = UDim2.new(0, 0, 0, 0) })
	play(card, TWEEN_FADE_IN, { BackgroundTransparency = BG_VISIBLE })
	play(stroke, TWEEN_FADE_IN, { Transparency = STROKE_VISIBLE })
	play(accent, TWEEN_FADE_IN, { BackgroundTransparency = 0 })
	play(content, TWEEN_FADE_IN, { GroupTransparency = 0 })

	if progressTween then
		progressTween:Play()
	end
	if autoClose then
		task.delay(length, close)
	end

	return { Close = close }
end

return notify
