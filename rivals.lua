-- ============================================================================
-- 1. THE FULL UI LIBRARY
-- ============================================================================
local UILibrary = (function()
	local Players           = game:GetService("Players")
	local TweenService      = game:GetService("TweenService")
	local TextService       = game:GetService("TextService")
	local RunService        = game:GetService("RunService")
	local UserInputService  = game:GetService("UserInputService")
	local StatsService      = game:GetService("Stats")

	local UILibrary = { Version = "V1 Made by Qwen67 Israel" }

	local player = Players.LocalPlayer
	local playerGui = player and player:FindFirstChildOfClass("PlayerGui")

	local DefaultTheme = {
		PanelBg    = Color3.fromRGB(5, 5, 6),
		SidebarBg  = Color3.fromRGB(10, 10, 11),
		SubBarBg   = Color3.fromRGB(11, 11, 13),
		SearchBg   = Color3.fromRGB(11, 11, 13),
		InputBg    = Color3.fromRGB(12, 12, 14),
		ActiveBg   = Color3.fromRGB(24, 24, 27),
		HoverBg    = Color3.fromRGB(18, 18, 21),
		TrackOff   = Color3.fromRGB(38, 38, 43),
		KnobOff    = Color3.fromRGB(205, 205, 210),
		Border     = Color3.fromRGB(30, 30, 34),
		Active     = Color3.fromRGB(245, 245, 247),
		Text       = Color3.fromRGB(225, 225, 228),
		TextDim    = Color3.fromRGB(157, 157, 164),
		TextMuted  = Color3.fromRGB(104, 104, 112),
		Gold       = Color3.fromRGB(205, 169, 51),
		Green      = Color3.fromRGB(70, 220, 126),
		Red        = Color3.fromRGB(230, 67, 83),
	}

	UILibrary.Theme = table.clone(DefaultTheme)
	UILibrary.DefaultTheme = DefaultTheme
	local function C(key) return UILibrary.Theme[key] end

	local screenGui, Stage
	local CANVAS_W, CANVAS_H = 720, 740
	local PANEL_X, PANEL_Y, PANEL_W, PANEL_H = 92, 20, 624, 482
	local SIDEBAR_X, SIDEBAR_W, TAB_STEP = 24, 54, 44
	local SUBBAR_H, SUBBAR_HALF_IN = 38, 18
	local COL_L_X, COL_W_L, COL_Y, COL_H = 14, 288, 76, 378
	local DEFAULT_CHARACTER_ASSET = "rbxassetid://911435489"
	local CHARACTER_SIZE = Vector2.new(290, 410)

	local tabs, currentTab, sidebar, sideIndicator, subBar, mainPanel, sectionChip, searchBox, contentL
	local charImage, footerRefs = nil, {}
	local pickerState, thumbCache, uiVisible = { open = false, frame = nil }, {}, true
	local watermarkVisible, toggleKey = true, Enum.KeyCode.RightShift
	local hbConn, dragConns, themeBinds, themeRefreshers = nil, {}, {}, {}

	local function addRefresher(fn) themeRefreshers[#themeRefreshers+1] = fn end
	local function clearRefreshers() table.clear(themeRefreshers) end
	local function bindTheme(obj, prop, key) themeBinds[#themeBinds+1] = { Obj = obj, Prop = prop, Key = key } end

	function UILibrary:ApplyTheme()
		for i = #themeBinds, 1, -1 do
			local b = themeBinds[i]
			if not b.Obj or not b.Obj.Parent then table.remove(themeBinds, i)
			else pcall(function() b.Obj[b.Prop] = C(b.Key) end) end
		end
		for _, fn in ipairs(themeRefreshers) do pcall(fn) end
		if currentTab then
			self:_RefreshTabVisuals()
			self:_RefreshSubTabVisuals(currentTab)
		end
	end

	local function I(class, props)
		local obj = Instance.new(class)
		local parent = props.Parent
		props.Parent = nil
		for k, v in pairs(props) do obj[k] = v end
		obj.Parent = parent
		return obj
	end

	local function tween(obj, time, props, style, dir)
		TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props):Play()
	end

	local function strokeOn(obj, colorOrKey, thickness, transparency)
		local col = colorOrKey; if typeof(colorOrKey) == "string" then col = C(colorOrKey) end
		local st = I("UIStroke", { Parent = obj, Color = col, Thickness = thickness or 1, Transparency = transparency or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, LineJoinMode = Enum.LineJoinMode.Round })
		if typeof(colorOrKey) == "string" then bindTheme(st, "Color", colorOrKey) end
		return st
	end

	local function rectTL(parent, x, y, w, h, colorOrKey, radius, transparency)
		local col = colorOrKey; if typeof(colorOrKey) == "string" then col = C(colorOrKey) end
		local f = I("Frame", { Parent = parent, BackgroundColor3 = col, BackgroundTransparency = transparency or 0, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), BorderSizePixel = 0 })
		if radius then I("UICorner", { Parent = f, CornerRadius = UDim.new(0, radius) }) end
		if typeof(colorOrKey) == "string" then bindTheme(f, "BackgroundColor3", colorOrKey) end
		return f
	end

	local function circFrame(parent, cx, cy, d, colorOrKey, transparency, z)
		local col = colorOrKey; if typeof(colorOrKey) == "string" then col = C(colorOrKey) end
		local f = I("Frame", { Parent = parent, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(cx, cy), Size = UDim2.fromOffset(d, d), BackgroundColor3 = col, BackgroundTransparency = transparency or 0, BorderSizePixel = 0, ZIndex = z })
		I("UICorner", { Parent = f, CornerRadius = UDim.new(1, 0) })
		if typeof(colorOrKey) == "string" then bindTheme(f, "BackgroundColor3", colorOrKey) end
		return f
	end

	local function applyFont(obj, weight)
		local list = weight == "bold" and { Enum.Font.GothamBold, Enum.Font.GothamBlack, Enum.Font.SourceSansBold } or weight == "medium" and { Enum.Font.GothamMedium, Enum.Font.GothamSemibold, Enum.Font.Gotham, Enum.Font.SourceSans } or { Enum.Font.Gotham, Enum.Font.SourceSans, Enum.Font.Arial }
		for _, f in ipairs(list) do if pcall(function() obj.Font = f end) then break end end
	end

	local function txt(parent, x, y, w, h, text, size, colorOrKey, weight, align)
		local col = colorOrKey; if typeof(colorOrKey) == "string" then col = C(colorOrKey) end
		local l = I("TextLabel", { Parent = parent, BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), Text = text, TextSize = size, TextColor3 = col, TextXAlignment = align or Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center })
		applyFont(l, weight); if typeof(colorOrKey) == "string" then bindTheme(l, "TextColor3", colorOrKey) end
		return l
	end

	local function textWidth(text, size, weight)
		local ok, r = pcall(function() return TextService:GetTextSize(text, size, weight == "medium" and Enum.Font.GothamMedium or Enum.Font.Gotham, Vector2.new(1000, 20)) end)
		if ok then return r.X end
		return #text * size * 0.55
	end

	local function tweenIconColor(holder, color, duration)
		for _, d in ipairs(holder:GetDescendants()) do
			if d:IsA("Frame") then tween(d, duration, { BackgroundColor3 = color })
			elseif d:IsA("UIStroke") then tween(d, duration, { Color = color })
			elseif d:IsA("TextLabel") then tween(d, duration, { TextColor3 = color })
			elseif d:IsA("ImageLabel") then tween(d, duration, { ImageColor3 = color }) end
		end
	end

	local function hexOf(c) return string.format("#%02x%02x%02x", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5)) end
	local function rbxThumb(userId, kind, w, h) return "rbxthumb://type=" .. (kind or "AvatarHeadShot") .. "&id=" .. tostring(userId) .. "&w=" .. tostring(w or 100) .. "&h=" .. tostring(h or 100) end

	local ICON_ASSETS = {
		bars = "rbxassetid://7733674319", bell = "rbxassetid://7733911828", cube = "rbxassetid://7733917120", eye = "rbxassetid://7733774602", gamepad = "rbxassetid://7733799901", gear = "rbxassetid://7734053495", globe = "rbxassetid://7733954760", grid = "rbxassetid://7733970390", hamburger = "rbxassetid://7733993211", key = "rbxassetid://7733965118", layers = "rbxassetid://7743868936", medal = "rbxassetid://7733673987", palette = "rbxassetid://7734021595", search = "rbxassetid://7734052925", shield = "rbxassetid://7734056608", sliders = "rbxassetid://7734058803", target = "rbxassetid://7733765307", user = "rbxassetid://7743875962", wave = "rbxassetid://7733655755", wrench = "rbxassetid://7743878358",
	}

	local Icon = {}
	for icon_name, icon_id in pairs(ICON_ASSETS) do
		Icon[icon_name] = function(parent, cx, cy, size, color)
			return I("ImageLabel", { Parent = parent, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(cx, cy), Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1, BorderSizePixel = 0, Image = icon_id, ImageColor3 = color or C("TextDim") })
		end
	end
	UILibrary.Icon = Icon

	local function chevronVector(parent, cx, cy, size, color)
		local holder = I("Frame", { Parent = parent, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(cx, cy), Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1, BorderSizePixel = 0 })
		local w, h = size * 0.52, math.max(2, size * 0.14)
		local function bar(px, py, rw, rh, rot)
			local f = I("Frame", { Parent = holder, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(px, py), Size = UDim2.fromOffset(rw, rh), Rotation = rot, BackgroundColor3 = color, BorderSizePixel = 0 })
			I("UICorner", { Parent = f, CornerRadius = UDim.new(1, 0) })
		end
		bar(size * 0.5 - size * 0.13, size * 0.46, w, h, 45); bar(size * 0.5 + size * 0.13, size * 0.46, w, h, -45)
		return holder
	end

	local function closePicker()
		if pickerState.open and pickerState.frame then
			local f = pickerState.frame; pickerState.open = false; pickerState.frame = nil
			tween(f, 0.14, { Size = UDim2.fromOffset(168, 0), BackgroundTransparency = 1 })
			task.delay(0.16, function() if f then f:Destroy() end end)
		end
	end

	local function closeAllDropdowns()
		if not Stage then return end
		local ok, children = pcall(function() return Stage:GetChildren() end)
		if not ok or not children then return end
		for _, ch in ipairs(children) do if ch.Name == "DropdownList" then pcall(function() ch:Destroy() end) end end
	end

	UILibrary.CloseAllDropdowns = closeAllDropdowns

	local function openPicker(anchorSwatch, current, onPick)
		closePicker()
		local h, s, v = Color3.toHSV(current)
		local ap = anchorSwatch.AbsolutePosition; local sp = Stage.AbsolutePosition
		local px = math.clamp(ap.X - sp.X + 18, 4, CANVAS_W - 172); local py = math.clamp(ap.Y - sp.Y + 12, 4, CANVAS_H - 140)
		local root = I("Frame", { Name = "ColorPicker", Parent = Stage, BackgroundColor3 = C("SubBarBg"), Position = UDim2.fromOffset(px, py), Size = UDim2.fromOffset(168, 0), BorderSizePixel = 0, ZIndex = 200 })
		I("UICorner", { Parent = root, CornerRadius = UDim.new(0, 10) }); strokeOn(root, "Border", 1, 0.55).ZIndex = 201; bindTheme(root, "BackgroundColor3", "SubBarBg")
		pickerState.open = true; pickerState.frame = root
		local SV_W, SV_H = 118, 84
		local sv = I("TextButton", { Parent = root, Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.fromHSV(h, 1, 1), Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(SV_W, SV_H), BorderSizePixel = 0, ZIndex = 201 })
		I("UICorner", { Parent = sv, CornerRadius = UDim.new(0, 8) })
		local gw = I("Frame", { Parent = sv, Size = UDim2.new(1,0,1,0), BackgroundColor3 = Color3.new(1,1,1), BorderSizePixel = 0, ZIndex = 202 })
		I("UIGradient", { Parent = gw, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0,0), NumberSequenceKeypoint.new(1,1) }) }); I("UICorner", { Parent = gw, CornerRadius = UDim.new(0, 8) })
		local gb = I("Frame", { Parent = sv, Size = UDim2.new(1,0,1,0), BackgroundColor3 = Color3.new(0,0,0), BorderSizePixel = 0, ZIndex = 203 })
		I("UIGradient", { Parent = gb, Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0,1), NumberSequenceKeypoint.new(1,0) }) }); I("UICorner", { Parent = gb, CornerRadius = UDim.new(0, 8) })
		local knob = I("Frame", { Parent = sv, BackgroundTransparency = 1, Position = UDim2.fromOffset(s * SV_W - 6, (1 - v) * SV_H - 6), Size = UDim2.fromOffset(12, 12), ZIndex = 204 })
		local ring = circFrame(knob, 6, 6, 10, Color3.new(1,1,1), 1, 205); strokeOn(ring, Color3.new(1,1,1), 2, 0).ZIndex = 206
		local hue = I("TextButton", { Parent = root, Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(1,1,1), Position = UDim2.fromOffset(138, 10), Size = UDim2.fromOffset(12, SV_H), BorderSizePixel = 0, ZIndex = 201 })
		I("UICorner", { Parent = hue, CornerRadius = UDim.new(0, 8) })
		I("UIGradient", { Parent = hue, Rotation = 90, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 1, 1)), ColorSequenceKeypoint.new(0.17, Color3.fromHSV(0.83, 1, 1)), ColorSequenceKeypoint.new(0.33, Color3.fromHSV(0.66, 1, 1)), ColorSequenceKeypoint.new(0.5, Color3.fromHSV(0.5, 1, 1)), ColorSequenceKeypoint.new(0.67, Color3.fromHSV(0.33, 1, 1)), ColorSequenceKeypoint.new(0.83, Color3.fromHSV(0.16, 1, 1)), ColorSequenceKeypoint.new(1, Color3.fromHSV(0, 1, 1)) }) })
		local hueKnob = rectTL(hue, -2, (1 - h) * SV_H - 2, 16, 4, Color3.new(1,1,1), 2, 0); hueKnob.ZIndex = 202
		local preview = circFrame(root, 20, 112, 18, current, 0, 201); strokeOn(preview, "Border", 1, 0.55).ZIndex = 202
		local hexLabel = txt(root, 36, 104, 96, 16, hexOf(current), 11, "TextDim"); hexLabel.ZIndex = 201
		local function apply() local c = Color3.fromHSV(h, s, v); sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1); preview.BackgroundColor3 = c; hexLabel.Text = hexOf(c); anchorSwatch.BackgroundColor3 = c; if onPick then onPick(c) end end
		local dragSV, dragHue = false, false
		sv.InputBegan:Connect(function(inp) if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then dragSV = true end end)
		hue.InputBegan:Connect(function(inp) if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then dragHue = true end end)
		local endedConn, changedConn, beganConn
		endedConn = UserInputService.InputEnded:Connect(function(inp) if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then dragSV, dragHue = false, false end end)
		changedConn = UserInputService.InputChanged:Connect(function(inp)
			if not pickerState.open or pickerState.frame ~= root then return end
			if inp.UserInputType ~= Enum.UserInputType.MouseMovement and inp.UserInputType ~= Enum.UserInputType.Touch then return end
			if dragSV then s = math.clamp((inp.Position.X - sv.AbsolutePosition.X) / sv.AbsoluteSize.X, 0, 1); v = 1 - math.clamp((inp.Position.Y - sv.AbsolutePosition.Y) / sv.AbsoluteSize.Y, 0, 1); knob.Position = UDim2.fromOffset(s * SV_W - 6, (1 - v) * SV_H - 6); apply()
			elseif dragHue then h = 1 - math.clamp((inp.Position.Y - hue.AbsolutePosition.Y) / hue.AbsoluteSize.Y, 0, 1); hueKnob.Position = UDim2.fromOffset(-2, (1 - h) * SV_H - 2); apply() end
		end)
		beganConn = UserInputService.InputBegan:Connect(function(inp)
			if not pickerState.open or pickerState.frame ~= root then return end
			if inp.UserInputType ~= Enum.UserInputType.MouseButton1 and inp.UserInputType ~= Enum.UserInputType.Touch then return end
			local rp, rs = root.AbsolutePosition, root.AbsoluteSize; local p = inp.Position
			local inside = p.X >= rp.X - 4 and p.X <= rp.X + rs.X + 4 and p.Y >= rp.Y - 4 and p.Y <= rp.Y + rs.Y + 4
			local ap2 = anchorSwatch.AbsolutePosition
			local insideSw = p.X >= ap2.X - 12 and p.X <= ap2.X + 12 and p.Y >= ap2.Y - 12 and p.Y <= ap2.Y + 12
			if not inside and not insideSw then if endedConn then endedConn:Disconnect() end; if changedConn then changedConn:Disconnect() end; if beganConn then beganConn:Disconnect() end; closePicker() end
		end)
		task.defer(function() tween(root, 0.18, { Size = UDim2.fromOffset(168, 132) }, Enum.EasingStyle.Back) end)
		return root
	end

	local function panelPos() return mainPanel.Position.X.Offset, mainPanel.Position.Y.Offset end
	local function panelCenterX() local x, _ = panelPos(); return x + PANEL_W/2 end
	local function subbarY() local _, y = panelPos(); return y + PANEL_H - SUBBAR_HALF_IN end
	local function sidebarDX() return SIDEBAR_X - PANEL_X end

	local function buildSidebar()
		sidebar = rectTL(Stage, SIDEBAR_X, PANEL_Y, SIDEBAR_W, 120, "SidebarBg", 12); sidebar.ZIndex = 10; sidebar.Active = true; strokeOn(sidebar, "Border", 1, 0.55).ZIndex = 11
		sideIndicator = I("Frame", { Parent = sidebar, BackgroundColor3 = C("Active"), BorderSizePixel = 0, Position = UDim2.fromOffset(0, 21), Size = UDim2.fromOffset(2, 18), BackgroundTransparency = 1, ZIndex = 13 })
		I("UICorner", { Parent = sideIndicator, CornerRadius = UDim.new(1,0) }); bindTheme(sideIndicator, "BackgroundColor3", "Active")
	end

	local function fitSidebar()
		if not (sidebar and mainPanel) then return end
		local n = math.max(1, #tabs); local h = math.min(PANEL_H, n * TAB_STEP + 18)
		local px, py = panelPos(); sidebar.Size = UDim2.fromOffset(SIDEBAR_W, h); sidebar.Position = UDim2.fromOffset(px + sidebarDX(), py + (PANEL_H - h) / 2)
	end

	function UILibrary:_RefreshTabVisuals()
		if not sidebar then return end
		for _, t in ipairs(tabs) do
			local active = (t == currentTab); tween(t.hl, 0.0, { BackgroundColor3 = C("ActiveBg") }); tween(t.hl, 0.0, { BackgroundTransparency = active and 0.18 or 1 })
			tweenIconColor(t.iconHolder, active and C("Active") or C("TextMuted"), 0.0)
		end
		if currentTab and currentTab.cy then sideIndicator.BackgroundTransparency = 0; sideIndicator.BackgroundColor3 = C("Active"); sideIndicator.Position = UDim2.fromOffset(0, currentTab.cy - 9) end
	end

	function UILibrary:AddTab(cfg)
		cfg = cfg or {}; assert(sidebar, "UILibrary:Build() must be called before AddTab().")
		local index = #tabs + 1; local cy = 10 + (index - 1) * TAB_STEP + TAB_STEP / 2
		local tab = { index = index, name = cfg.Name or ("Tab" .. index), icon = cfg.Icon or "grid", subs = {}, currentSub = nil }
		local hl = rectTL(sidebar, 6, cy - 18, SIDEBAR_W - 12, 36, "ActiveBg", 10, 1); hl.ZIndex = 11
		local iconHolder = I("Frame", { Parent = sidebar, BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(6, cy - 18), Size = UDim2.fromOffset(SIDEBAR_W - 12, 36), ZIndex = 12 })
		if Icon[tab.icon] then Icon[tab.icon](iconHolder, (SIDEBAR_W - 12) / 2, 18, 18, C("TextMuted")).ZIndex = 12 end
		local btn = I("TextButton", { Parent = sidebar, BackgroundTransparency = 1, Text = "", Position = UDim2.fromOffset(6, cy - 18), Size = UDim2.fromOffset(SIDEBAR_W - 12, 36), ZIndex = 14 })
		btn.MouseEnter:Connect(function() if currentTab ~= tab then tween(hl, 0.16, { BackgroundTransparency = 0.65 }) end end)
		btn.MouseLeave:Connect(function() if currentTab ~= tab then tween(hl, 0.20, { BackgroundTransparency = 1 }) end end)
		btn.MouseButton1Click:Connect(function() self:SelectTab(tab) end)
		tab.hl, tab.iconHolder, tab.btn, tab.cy = hl, iconHolder, btn, cy; tabs[index] = tab; fitSidebar()
		if not currentTab then self:SelectTab(tab) end; return tab
	end

	function UILibrary:SelectTab(tab)
		if currentTab == tab then return end; currentTab = tab
		for _, t in ipairs(tabs) do local active = (t == tab); tween(t.hl, 0.2, { BackgroundTransparency = active and 0.18 or 1 }); tweenIconColor(t.iconHolder, active and C("Active") or C("TextMuted"), 0.2) end
		sideIndicator.BackgroundTransparency = 0; sideIndicator.BackgroundColor3 = C("Active")
		tween(sideIndicator, 0.26, { Position = UDim2.fromOffset(0, tab.cy - 9) }, Enum.EasingStyle.Quart)
		self:RebuildSubBars(tab); closePicker(); closeAllDropdowns()
	end

	local COLLAPSED_W, PILL_H = 34, 28
	local function buildSubBar()
		subBar = rectTL(Stage, panelCenterX() - 230, subbarY(), 460, SUBBAR_H, "SubBarBg", 10); subBar.ZIndex = 30; subBar.Active = true; strokeOn(subBar, "Border", 1, 0.55).ZIndex = 31
	end

	local function layoutSubBar(tab)
		if not subBar then return end
		local cursor = 8
		for _, sub in ipairs(tab.subs) do
			local w = (tab.currentSub == sub) and sub.expandedW or COLLAPSED_W
			tween(sub.pill, 0.25, { Position = UDim2.fromOffset(cursor, (SUBBAR_H - PILL_H) / 2), Size = UDim2.fromOffset(w, PILL_H) }, Enum.EasingStyle.Quart)
			cursor = cursor + w + 6
		end
		local total = math.max(260, cursor + 2); local cx = panelCenterX()
		tween(subBar, 0.25, { Size = UDim2.fromOffset(total, SUBBAR_H), Position = UDim2.fromOffset(cx - total / 2, subbarY()) }, Enum.EasingStyle.Quart)
	end

	function UILibrary:_RefreshSubTabVisuals(tab)
		if not tab then return end
		for _, sub in ipairs(tab.subs) do
			local active = (tab.currentSub == sub)
			if sub.pill and sub.label and sub.iconHolder then
				sub.pill.BackgroundColor3 = active and C("ActiveBg") or C("InputBg"); sub.pill.BackgroundTransparency = active and 0 or 0.45
				sub.label.TextColor3 = C("Text"); sub.label.TextTransparency = active and 0 or 1; tweenIconColor(sub.iconHolder, active and C("Active") or C("TextMuted"), 0.0)
			end
		end
	end

	function UILibrary:AddSubTab(tab, cfg)
		cfg = cfg or {}; assert(subBar, "UILibrary:Build() must be called before AddSubTab().")
		local sub = { name = cfg.Name or ("Sub" .. (#tab.subs + 1)), icon = cfg.Icon or "cube", tab = tab, rows = {}, build = cfg.Build }
		tab.subs[#tab.subs + 1] = sub
		if currentTab == tab then self:RebuildSubBars(tab); if not tab.currentSub then self:SelectSubTab(tab, sub) end end
		return sub
	end

	function UILibrary:RebuildSubBars(tab)
		for _, ch in ipairs(subBar:GetChildren()) do if ch:IsA("Frame") or ch:IsA("TextButton") then ch:Destroy() end end
		tab.currentSub = nil
		for i, sub in ipairs(tab.subs) do
			local labelW = textWidth(sub.name, 12, "medium"); sub.expandedW = COLLAPSED_W + labelW + 14
			local pill = I("Frame", { Parent = subBar, LayoutOrder = i, BackgroundColor3 = C("InputBg"), BackgroundTransparency = 0.45, Position = UDim2.fromOffset(8, (SUBBAR_H - PILL_H) / 2), Size = UDim2.fromOffset(COLLAPSED_W, PILL_H), ClipsDescendants = true, BorderSizePixel = 0, ZIndex = 31 })
			I("UICorner", { Parent = pill, CornerRadius = UDim.new(0, 8) })
			local iconHolder = I("Frame", { Parent = pill, BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromOffset(COLLAPSED_W, PILL_H), ZIndex = 32 })
			if Icon[sub.icon] then Icon[sub.icon](iconHolder, COLLAPSED_W / 2, PILL_H / 2, 16, C("TextMuted")).ZIndex = 32 end
			local label = txt(pill, COLLAPSED_W - 2, 0, labelW + 12, PILL_H, sub.name, 12, "Text", "medium"); label.TextTransparency = 1; label.ZIndex = 32
			sub.pill, sub.label, sub.iconHolder = pill, label, iconHolder
			local btn = I("TextButton", { Parent = pill, BackgroundTransparency = 1, Text = "", Size = UDim2.new(1, 0, 1, 0), ZIndex = 33 })
			btn.MouseEnter:Connect(function() if tab.currentSub ~= sub then tween(pill, 0.14, { BackgroundTransparency = 0.15 }) end end)
			btn.MouseLeave:Connect(function() if tab.currentSub ~= sub then tween(pill, 0.18, { BackgroundTransparency = 0.45 }) end end)
			btn.MouseButton1Click:Connect(function() self:SelectSubTab(tab, sub) end)
		end
		if tab.subs[1] then self:SelectSubTab(tab, tab.subs[1]) end
		addRefresher(function() if currentTab == tab then self:_RefreshSubTabVisuals(tab) end end)
	end

	function UILibrary:SelectSubTab(tab, sub)
		if tab.currentSub == sub then return end; local oldSub = tab.currentSub; tab.currentSub = sub; closePicker(); closeAllDropdowns()
		if oldSub and oldSub.pill then tween(oldSub.pill, 0.18, { BackgroundTransparency = 0.45, BackgroundColor3 = C("InputBg") }); tween(oldSub.label, 0.14, { TextTransparency = 1 }); tweenIconColor(oldSub.iconHolder, C("TextMuted"), 0.2) end
		tweenIconColor(sub.iconHolder, C("Active"), 0.2); tween(sub.pill, 0.2, { BackgroundTransparency = 0, BackgroundColor3 = C("ActiveBg") })
		task.delay(0.06, function() if tab.currentSub == sub then tween(sub.label, 0.18, { TextTransparency = 0 }) end end)
		layoutSubBar(tab); sectionChip.Text = sub.name; self:BuildPage(sub)
	end

	local function buildMainPanel()
		mainPanel = rectTL(Stage, PANEL_X, PANEL_Y, PANEL_W, PANEL_H, "PanelBg", 8); mainPanel.ZIndex = 20; mainPanel.Active = true; mainPanel.ClipsDescendants = true; strokeOn(mainPanel, "Border", 1, 0.65).ZIndex = 21
		local keyHint = rectTL(mainPanel, 10, 10, 68, 22, "SearchBg", 7); keyHint.ZIndex = 22; strokeOn(keyHint, "Border", 1, 0.65).ZIndex = 23
		txt(keyHint, 0, 0, 68, 22, "Lucent v2", 12, "TextDim", "medium", Enum.TextXAlignment.Center).ZIndex = 24
		local searchBar = rectTL(mainPanel, 84, 10, 204, 28, "SearchBg", 7); searchBar.ZIndex = 22; strokeOn(searchBar, "Border", 1, 0.75).ZIndex = 23
		Icon.search(searchBar, 16, 14, 13, C("TextMuted")).ZIndex = 24
		searchBox = I("TextBox", { Parent = searchBar, BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(30, 0), Size = UDim2.new(1, -36, 1, 0), PlaceholderText = "search", PlaceholderColor3 = C("TextMuted"), Text = "", TextColor3 = C("Text"), TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 24 })
		applyFont(searchBox, nil); bindTheme(searchBox, "TextColor3", "Text"); bindTheme(searchBox, "PlaceholderColor3", "TextMuted")
		txt(mainPanel, PANEL_W - 260, 8, 210, 15, player and player.Name or "Player", 13, "Text", "medium", Enum.TextXAlignment.Right).ZIndex = 22
		txt(mainPanel, PANEL_W - 260, 24, 210, 11, "FREE", 11, "Gold", "medium", Enum.TextXAlignment.Right).ZIndex = 22
		local avatar = I("ImageLabel", { Parent = mainPanel, Name = "Avatar", BackgroundColor3 = C("InputBg"), BackgroundTransparency = 0, Position = UDim2.fromOffset(PANEL_W - 40, 9), Size = UDim2.fromOffset(28, 28), Image = player and rbxThumb(player.UserId) or "", ZIndex = 22 })
		I("UICorner", { Parent = avatar, CornerRadius = UDim.new(1, 0) }); strokeOn(avatar, "Border", 1, 0.65).ZIndex = 23; bindTheme(avatar, "BackgroundColor3", "InputBg")
		sectionChip = txt(mainPanel, COL_L_X, 44, 320, 22, "", 14, "Text", "medium"); sectionChip.ZIndex = 22
		charImage = I("ImageLabel", { Parent = mainPanel, Name = "CharacterImage", BackgroundTransparency = 1, BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromOffset(PANEL_W - 16, PANEL_H), Size = UDim2.fromOffset(CHARACTER_SIZE.X, CHARACTER_SIZE.Y), Image = DEFAULT_CHARACTER_ASSET, ScaleType = Enum.ScaleType.Fit, ZIndex = 21 })
		local optCard = rectTL(mainPanel, 10, 72, COL_W_L + 10, 304, "PanelBg", 7, 0.82); optCard.ZIndex = 21; strokeOn(optCard, "Border", 1, 0.85).ZIndex = 22
		contentL = I("ScrollingFrame", { Parent = mainPanel, Name = "ContentL", BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(COL_L_X, COL_Y), Size = UDim2.fromOffset(COL_W_L + 8, COL_H), ClipsDescendants = true, ZIndex = 22, ScrollBarThickness = 3, ScrollBarImageColor3 = C("TextMuted"), ScrollBarImageTransparency = 0.4, CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y, ElasticBehavior = Enum.ElasticBehavior.Never })
		bindTheme(contentL, "ScrollBarImageColor3", "TextMuted"); I("UIListLayout", { Parent = contentL, Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder })
		searchBox:GetPropertyChangedSignal("Text"):Connect(function() UILibrary:ApplySearch(searchBox.Text) end)
	end

	local function tryLoadChar(img)
		if not (charImage and charImage.Parent) then return false end
		charImage.Image = img; local t0 = os.clock()
		while not charImage.IsLoaded and os.clock() - t0 < 2.0 do task.wait(0.05) end
		return charImage.IsLoaded
	end

	local function loadCharacterImage()
		task.spawn(function()
			task.wait(0.1); if not (charImage and charImage.Parent) then return end; if charImage:GetAttribute("custom") then return end
			if DEFAULT_CHARACTER_ASSET and DEFAULT_CHARACTER_ASSET ~= "" then
				if tryLoadChar(DEFAULT_CHARACTER_ASSET) then return end
				local raw = tostring(DEFAULT_CHARACTER_ASSET):gsub("%D",""); if raw ~= "" then tryLoadChar("rbxthumb://type=Asset&id=" .. raw .. "&w=512&h=512") end
			end
		end)
	end

	function UILibrary:RefreshVisibility() self:ApplySearch(searchBox and searchBox.Text or "") end
	function UILibrary:ApplySearch(query)
		if not contentL then return end; local q = (query or ""):lower()
		for _, row in ipairs(contentL:GetChildren()) do
			if row:IsA("Frame") and row:GetAttribute("key") then
				local depHidden = row:GetAttribute("depHidden") == true
				if q == "" then row.Visible = not depHidden else row.Visible = (not depHidden) and row:GetAttribute("key"):find(q, 1, true) ~= nil end
			end
		end
	end

	local function newRow(sub, height)
		local row = I("Frame", { Parent = contentL, BackgroundColor3 = C("HoverBg"), BackgroundTransparency = 1, Size = UDim2.fromOffset(COL_W_L, height), LayoutOrder = #sub.rows + 1, ZIndex = 22, BorderSizePixel = 0 })
		I("UICorner", { Parent = row, CornerRadius = UDim.new(0, 7) }); row:SetAttribute("w", COL_W_L); sub.rows[#sub.rows + 1] = row; return row
	end

	function UILibrary:BuildPage(sub)
		clearRefreshers(); for _, ch in ipairs(contentL:GetChildren()) do if ch:IsA("Frame") then ch:Destroy() end end; sub.rows = {}
		if sub.build then local ok, err = pcall(sub.build, sub); if not ok then warn("[UILibrary] Build error '" .. tostring(sub.name) .. "': " .. tostring(err)) end end
		self:ApplySearch(searchBox.Text)
	end

	function UILibrary:AddToggle(sub, cfg)
		cfg = cfg or {}; local row = newRow(sub, 24); local W = row:GetAttribute("w")
		local label = txt(row, 10, 0, W - 96, 24, cfg.Name or "toggle", 12, C("TextDim")); label.ZIndex = 23
		local obj = { Name = cfg.Name, value = cfg.Default == true, Row = row }
		local track = rectTL(row, W - 42, 4, 31, 16, C("TrackOff"), 8, 0); track.ZIndex = 23
		local knob = circFrame(track, 8, 8, 12, C("KnobOff"), 0, 24)
		local function render(on)
			if on then
				tween(knob, 0.16, { Position = UDim2.fromOffset(23, 8), BackgroundColor3 = C("Active") }, Enum.EasingStyle.Quart); tween(track, 0.16, { BackgroundColor3 = C("ActiveBg") }, Enum.EasingStyle.Quart)
				tween(label, 0.16, { TextColor3 = C("Text") }, Enum.EasingStyle.Quart)
			else
				tween(knob, 0.16, { Position = UDim2.fromOffset(8, 8), BackgroundColor3 = C("KnobOff") }, Enum.EasingStyle.Quart); tween(track, 0.16, { BackgroundColor3 = C("TrackOff") }, Enum.EasingStyle.Quart)
				tween(label, 0.16, { TextColor3 = C("TextDim") }, Enum.EasingStyle.Quart)
			end
		end
		local function set(on, silent) obj.value = on and true or false; render(obj.value); if not silent and cfg.Callback then task.spawn(cfg.Callback, obj.value) end end
		obj.Set = set
		local btn = I("TextButton", { Parent = row, BackgroundTransparency = 1, Text = "", Size = UDim2.new(1, 0, 1, 0), ZIndex = 23 })
		btn.MouseButton1Click:Connect(function() set(not obj.value) end)
		set(obj.value, true); return obj
	end

	function UILibrary:AddColorPicker(sub, cfg)
		cfg = cfg or {}; local row = newRow(sub, 24); local W = row:GetAttribute("w")
		local current = cfg.Color or Color3.new(1,1,1)
		txt(row, 10, 0, W - 50, 24, cfg.Name or "color", 12, "TextDim").ZIndex = 23
		local sw = I("TextButton", { Parent = row, Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromOffset(W - 10, 12), Size = UDim2.fromOffset(16, 16), BackgroundColor3 = current, BorderSizePixel = 0, ZIndex = 24 })
		I("UICorner", { Parent = sw, CornerRadius = UDim.new(1, 0) }); strokeOn(sw, "Border", 1, 0.55).ZIndex = 25
		sw.MouseButton1Click:Connect(function() openPicker(sw, sw.BackgroundColor3, function(c) if cfg.Callback then task.spawn(cfg.Callback, c) end end) end)
		return { Set = function(c) sw.BackgroundColor3 = c end, Row = row }
	end

	function UILibrary:AddDropdown(sub, cfg)
		cfg = cfg or {}; local row = newRow(sub, 43); local W = row:GetAttribute("w"); local bw = W - 20
		txt(row, 10, 0, bw, 14, cfg.Name or "dropdown", 10, "TextMuted").ZIndex = 23
		local box = I("TextButton", { Parent = row, Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(10, 16), Size = UDim2.fromOffset(bw, 27), BackgroundColor3 = C("InputBg"), BorderSizePixel = 0, ZIndex = 23 })
		I("UICorner", { Parent = box, CornerRadius = UDim.new(0, 6) }); strokeOn(box, "Border", 1, 0.7).ZIndex = 24
		local value = txt(box, 10, 0, bw - 40, 27, "", 12, "Text"); value.ZIndex = 25
		local chev = chevronVector(box, bw - 16, 14, 12, C("TextDim")); chev.ZIndex = 25
		local obj = { value = cfg.Default or (cfg.Options and cfg.Options[1]), Row = row }; value.Text = tostring(obj.value)
		box.MouseButton1Click:Connect(function()
			local idx = 1; for i, v in ipairs(cfg.Options or {}) do if v == obj.value then idx = i break end end
			obj.value = (cfg.Options or {})[(idx % #(cfg.Options or {1})) + 1]; value.Text = tostring(obj.value)
			if cfg.Callback then task.spawn(cfg.Callback, obj.value) end
		end)
		return obj
	end

	function UILibrary:AddSlider(sub, cfg)
		cfg = cfg or {}; local min, max = cfg.Min or 0, cfg.Max or 100; local row = newRow(sub, 37); local W = row:GetAttribute("w"); local tw = W - 20
		txt(row, 10, 0, 170, 15, cfg.Name or "slider", 12, "TextDim").ZIndex = 23
		local valueL = txt(row, 10, 0, tw, 15, "", 12, "Text", "medium", Enum.TextXAlignment.Right); valueL.ZIndex = 23
		local track = I("TextButton", { Parent = row, Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(10, 22), Size = UDim2.fromOffset(tw, 4), BackgroundColor3 = C("TrackOff"), BorderSizePixel = 0, ZIndex = 23 })
		I("UICorner", { Parent = track, CornerRadius = UDim.new(0, 2) })
		local fill = rectTL(track, 0, 0, 100, 4, C("Active"), 2, 0); fill.ZIndex = 24
		local knobS = circFrame(track, 6, 2, 11, C("Active"), 0, 25)
		local obj = { value = cfg.Default or min, Row = row }
		local function set(v, silent) v = math.clamp(v, min, max); obj.value = v; local fw = math.max(5, tw * (v - min) / (max - min)); tween(fill, 0.10, { Size = UDim2.fromOffset(fw, 4) }); tween(knobS, 0.10, { Position = UDim2.fromOffset(fw, 2) }); valueL.Text = tostring(math.floor(v * 10 + 0.5) / 10) .. (cfg.Suffix or ""); if not silent and cfg.Callback then task.spawn(cfg.Callback, v) end end
		local sliding = false
		track.InputBegan:Connect(function(inp) if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then sliding = true end end)
		UserInputService.InputEnded:Connect(function(inp) if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then sliding = false end end)
		UserInputService.InputChanged:Connect(function(inp) if sliding and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then local t = math.clamp((inp.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1); set(min + (max - min) * t) end end)
		set(obj.value, true); return obj
	end

	function UILibrary:AddButton(sub, cfg)
		cfg = cfg or {}; local row = newRow(sub, 28)
		local box = I("TextButton", { Parent = row, Text = cfg.Name or "button", BackgroundColor3 = C("InputBg"), BorderSizePixel = 0, Size = UDim2.new(1, 0, 1, 0), TextColor3 = C("Text"), TextSize = 12, ZIndex = 23 })
		applyFont(box, "medium"); I("UICorner", { Parent = box, CornerRadius = UDim.new(0, 8) }); strokeOn(box, "Border", 1, 0.7).ZIndex = 24
		box.MouseButton1Click:Connect(function() if cfg.Callback then task.spawn(cfg.Callback) end end)
		return { Row = row }
	end

	function UILibrary:AddLabel(sub, cfg)
		cfg = cfg or {}; local row = newRow(sub, 24); local W = row:GetAttribute("w")
		txt(row, 10, 0, W - 20, 24, cfg.Text or "", 10, "TextMuted").ZIndex = 23; return { Row = row }
	end

	local notifHolder
	function UILibrary:Notify(text, duration)
		if not screenGui then return end; duration = tonumber(duration) or 3
		if not notifHolder or not notifHolder.Parent then notifHolder = I("Frame", { Parent = screenGui, Name = "Notifications", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -16), Size = UDim2.fromOffset(280, 400), ZIndex = 500 }); I("UIListLayout", { Parent = notifHolder, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = Enum.HorizontalAlignment.Right }) end
		local card = I("Frame", { Parent = notifHolder, BackgroundColor3 = C("SubBarBg"), BackgroundTransparency = 1, Size = UDim2.fromOffset(280, 36), BorderSizePixel = 0, ZIndex = 501, LayoutOrder = os.clock() * 1000 })
		I("UICorner", { Parent = card, CornerRadius = UDim.new(0, 8) }); strokeOn(card, "Border", 1, 0.5).ZIndex = 502
		local bar = rectTL(card, 0, 0, 3, 36, "Active", 2, 0); bar.ZIndex = 503
		local l = txt(card, 12, 0, 260, 36, tostring(text), 12, "Text"); l.ZIndex = 503; l.TextWrapped = true; l.TextTransparency = 1
		tween(card, 0.2, { BackgroundTransparency = 0 }); tween(l, 0.2, { TextTransparency = 0 })
		task.delay(duration, function() if card and card.Parent then tween(card, 0.25, { BackgroundTransparency = 1 }); tween(l, 0.25, { TextTransparency = 1 }); task.delay(0.3, function() if card then card:Destroy() end end) end end)
	end

	function UILibrary:ToggleUI()
		uiVisible = not uiVisible
		local targetTrans = uiVisible and 0 or 1
		local tw = TweenService:Create(Stage, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { GroupTransparency = targetTrans })
		if uiVisible then Stage.Visible = true; tw:Play() else tw:Play(); tw.Completed:Connect(function() if not uiVisible then Stage.Visible = false end end) end
	end

	local function buildFooter()
		local footer = rectTL(Stage, (PANEL_X + PANEL_W/2) - 155, CANVAS_H - 34, 310, 24, "SubBarBg", 8); footer.ZIndex = 12; strokeOn(footer, "Border", 1, 0.55).ZIndex = 13
		local med = Icon.medal(footer, 46, 12, 13, C("Gold")); med.ZIndex = 14; txt(footer, 58, 0, 62, 24, "RIVALES", 10, "Text", "medium").ZIndex = 14
		local clock = txt(footer, 260, 0, 48, 24, os.date("%I:%M %p"), 10, "TextDim"); clock.ZIndex = 14
		footerRefs = { footer = footer }
	end

	function UILibrary:Build(opts)
		opts = opts or {}; if not playerGui then player = Players.LocalPlayer; playerGui = player:WaitForChild("PlayerGui") end
		self:Destroy()
		screenGui = I("ScreenGui", { Name = "GameUI_Real", Parent = playerGui, ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 100, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
		Stage = I("CanvasGroup", { Name = "Stage", Parent = screenGui, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.fromOffset(CANVAS_W, CANVAS_H), BackgroundTransparency = 1, GroupTransparency = 0 })
		buildMainPanel(); buildSidebar(); fitSidebar(); buildSubBar(); buildFooter(); loadCharacterImage()
		local scale = opts.Scale or 1
		if scale ~= 1 then local sc = Instance.new("UIScale"); sc.Scale = scale; sc.Parent = Stage end
		local toggleBtn = I("TextButton", { Parent = screenGui, Name = "ToggleUIButton", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -24, 1, -24), Size = UDim2.fromOffset(120, 34), BackgroundColor3 = C("SubBarBg"), BorderSizePixel = 0, Text = "", ZIndex = 1000, AutoButtonColor = false })
		I("UICorner", { Parent = toggleBtn, CornerRadius = UDim.new(0, 8) }); strokeOn(toggleBtn, "Border", 1, 0.4).ZIndex = 1001
		local btnIcon = Icon.hamburger(toggleBtn, 20, 17, 14, C("TextDim")); btnIcon.ZIndex = 1002
		local btnText = txt(toggleBtn, 36, 0, 74, 34, "Toggle UI", 12, "TextDim", "medium"); btnText.ZIndex = 1002
		toggleBtn.MouseButton1Click:Connect(function() UILibrary:ToggleUI() end)
		self:ApplyTheme()
	end

	function UILibrary:Destroy()
		if screenGui then screenGui:Destroy() end
		screenGui, Stage = nil, nil; tabs = {}; currentTab = nil
	end

	return UILibrary
end)()


-- ============================================================================
-- 2. COMBAT LOGIC (From combat.lua)
-- ============================================================================
local players = game:GetService("Players")
local run_service = cloneref(game:GetService("RunService"))
local user_input_service = cloneref(game:GetService("UserInputService"))
local replicated_storage = cloneref(game:GetService("ReplicatedStorage"))
local sound_service = cloneref(game:GetService("SoundService"))
local player_scripts = players.LocalPlayer:WaitForChild("PlayerScripts")
local local_player = players.LocalPlayer
local mechanics_controller = require(player_scripts.Controllers.MechanicsController)

local PREDICT_MAX_LEAD = 0.18
local AIM_OVERSHOOT_DURATION = 0.12
local DEFAULT_ESP_DISTANCE_CAP = 800
local TRIGGER_MISS_OFFSET = 8
local HIT_SOUND_DIR = "daydreamer/rivals/assets"

local los_params = RaycastParams.new(); los_params.FilterType = Enum.RaycastFilterType.Exclude
local los_filter = {nil}
local trigger_ray_params = RaycastParams.new(); trigger_ray_params.FilterType = Enum.RaycastFilterType.Exclude
local trigger_filter = {nil}

local env = (getgenv and getgenv()) or _G
local dreamer = env.dreamer or {}; env.dreamer = dreamer

local function is_katana_deflecting(target_model)
    local target_player = target_model and players:GetPlayerFromCharacter(target_model)
    local users = env.dreamerkatana
    return target_player ~= nil and type(users) == "table" and users[target_player] == true
end

local function is_valid_enemy(target_model)
    local target_player = players:GetPlayerFromCharacter(target_model)
    if not target_player or (target_player.Team ~= nil and target_player.Team == local_player.Team) or (target_player:GetAttribute("TeamID") ~= nil and target_player:GetAttribute("TeamID") == local_player:GetAttribute("TeamID")) then return false end
    local target_humanoid = target_model:FindFirstChildOfClass("Humanoid")
    return target_humanoid and target_humanoid.Health > 0
end

local function has_line_of_sight(part)
    local cam = workspace.CurrentCamera; local character = local_player.Character
    if not cam or not part then return false end
    los_filter[1] = character or workspace; los_params.FilterDescendantsInstances = los_filter
    local result = workspace:Raycast(cam.CFrame.Position, part.Position - cam.CFrame.Position, los_params)
    return not result or result.Instance:IsDescendantOf(part.Parent)
end

local function world_to_screen(world_pos, cam)
    cam = cam or workspace.CurrentCamera
    if not cam or not world_pos then return nil, false end
    local screen_vec, on_screen = cam:WorldToViewportPoint(world_pos)
    return screen_vec, on_screen and screen_vec.Z > 0
end

local function screen_center(cam) cam = cam or workspace.CurrentCamera; return Vector2.new(cam.ViewportSize.X * 0.5, cam.ViewportSize.Y * 0.5) end

local function make_drawing_circle()
    if type(Drawing) ~= "table" then return nil end
    local ok, circle = pcall(function() return Drawing.new("Circle") end)
    if not ok or not circle then return nil end
    circle.Visible = false; circle.Filled = false; circle.NumSides = 96; circle.Thickness = 1.5; circle.Transparency = 1; circle.Color = Color3.fromRGB(255, 255, 255); circle.Radius = 100
    return circle
end

local function remove_drawing(obj) if not obj then return end; pcall(function() obj.Visible = false; obj:Remove() end) end

local function muzzle_pos()
    local view_models = workspace:FindFirstChild("ViewModels"); if not view_models then return nil end
    local first_person = view_models:FindFirstChild("FirstPerson"); if not first_person then return nil end
    for _, model in pairs(first_person:GetChildren()) do
        if model:IsA("Model") and model.Name:find("^" .. local_player.Name) then
            local muzzle = model:FindFirstChild("ItemVisual") and model.ItemVisual:FindFirstChild("Body") and model.ItemVisual.Body:FindFirstChild("BodyPrimary") and model.ItemVisual.Body.BodyPrimary:FindFirstChild("_muzzle")
            if muzzle and muzzle:IsA("Attachment") then return muzzle.WorldPosition end
        end
    end
    return nil
end

local function hit_part_from_name(character, part_name, head_hit_chance)
    if not character then return nil end
    local fc = function(n) return character:FindFirstChild(n) end
    if (part_name == "Closest" or part_name == "Random") and math.random(1, 100) <= math.clamp(tonumber(head_hit_chance) or 0, 0, 100) then return fc("Head") or fc("HumanoidRootPart") end
    if part_name == "Head" then return fc("Head") elseif part_name == "HumanoidRootPart" then return fc("HumanoidRootPart") elseif part_name == "Torso" then return fc("Torso") or fc("UpperTorso") elseif part_name == "UpperTorso" then return fc("UpperTorso") elseif part_name == "LowerTorso" then return fc("LowerTorso") end
    return fc("HumanoidRootPart")
end

local function get_aim_lerp_alpha(smoothness, curve, dt)
    smoothness = math.clamp(tonumber(smoothness) or 2, 0.1, 10); local speed = 6 / smoothness
    if curve == "Instant" or curve == "Snap" then return 1
    elseif curve == "Expo" then return 1 - math.exp(-(4 / smoothness) * dt)
    elseif curve == "EaseIn" then local t = math.clamp(speed * dt, 0, 1); return t * t
    elseif curve == "EaseOut" then local t = math.clamp(speed * dt, 0, 1); return 1 - (1 - t) * (1 - t)
    elseif curve == "Cubic" then local t = math.clamp(speed * dt, 0, 1); return t * t * t end
    return math.clamp(speed * dt, 0, 1)
end

local function sample_delayed_position(history, target_time, fallback_pos)
    local n = #history; if n == 0 then return fallback_pos end
    if target_time <= history[1].t then return history[1].pos end
    if target_time >= history[n].t then return history[n].pos end
    for i = n - 1, 1, -1 do
        local a, b = history[i], history[i + 1]
        if target_time >= a.t and target_time <= b.t then return a.pos:Lerp(b.pos, (target_time - a.t) / (b.t - a.t)) end
    end
    return fallback_pos
end

local silent_ray_params = RaycastParams.new()
local silent_offsets = { Vector3.new(0, 12, 0), Vector3.new(0, 16, 0), Vector3.new(0, 20, 0), Vector3.new(0, 24, 0), Vector3.new(0, 28, 0), Vector3.new(0, 32, 0) }

local function calculate_silent_point(origin, target_pos, target_char)
    silent_ray_params.FilterDescendantsInstances = { local_player.Character or workspace, target_char }
    silent_ray_params.FilterType = Enum.RaycastFilterType.Exclude
    if not workspace:Raycast(origin, target_pos - origin, silent_ray_params) then return origin end
    for _, offset in ipairs(silent_offsets) do
        local scan_pos = origin + offset
        if not workspace:Raycast(scan_pos, target_pos - scan_pos, silent_ray_params) then return scan_pos end
    end
    return nil
end

local function get_silent_target_part(st)
    local cam = workspace.CurrentCamera; if not cam then return nil, nil end
    local center = screen_center(cam); local radius = st.fov or 100; local part_name = st.hit_part or "Head"
    local best_part, best_char, best_dist = nil, nil, math.huge
    for _, plr in ipairs(players:GetPlayers()) do
        if plr ~= local_player and plr.Character and is_valid_enemy(plr.Character) and (st.katana_check ~= true or not is_katana_deflecting(plr.Character)) then
            local part = hit_part_from_name(plr.Character, part_name, st.head_hit_chance)
            if part and part:IsDescendantOf(workspace) and ((not st.visible_check) or has_line_of_sight(part)) then
                local scr, on = world_to_screen(part.Position, cam)
                if on then
                    local dist = (Vector2.new(scr.X, scr.Y) - center).Magnitude
                    if dist <= radius and dist < best_dist then best_dist = dist; best_part = part; best_char = plr.Character end
                end
            end
        end
    end
    return best_part, best_char
end

local function build_silent_raycast_result(from, range, st)
    local target_part, target_char = get_silent_target_part(st)
    if not target_part or not target_char then return end
    local origin = from
    if st.manipulation ~= false then origin = calculate_silent_point(from, target_part.Position, target_char); if not origin then return end end
    local delta = target_part.Position - origin; local dist = delta.Magnitude
    if dist <= 0 then return end
    local hit_pos = target_part.Position
    if type(range) == "number" and dist > range then dist = range; hit_pos = origin + delta.Unit * range end
    return { Position = hit_pos, Distance = dist, Instance = target_part, Material = target_part.Material, Normal = -delta.Unit }
end

local silent_item_denylist = { Flamethrower = true, Grenade = true, Medkit = true, Molotov = true, SmokeGrenade = true, Flashbang = true, Warper = true, Warpstone = true, Grappler = true, Satchel = true }
local function get_equipped_item() local lf = mechanics_controller.LocalFighter; return lf and lf.EquippedItem or nil end
local function get_item_field(item, key) if not item then return nil end; if item[key] ~= nil then return item[key] end; local ok, v = pcall(function() return item:Get(key) end); return ok and v or nil end
local function silent_item_allowed(item)
    local name = tostring(get_item_field(item, "Name") or item.Name or ""); if silent_item_denylist[name] then return false end
    local info = get_item_field(item, "Info"); if type(info) == "table" then local t = tostring(info.ItemType or info.Type or info.Class or ""); if t == "Melee" or t == "Throwable" or t == "Consumable" then return false end end
    return true
end
local function should_silent_raycast(range) local item = get_equipped_item(); if not item or not silent_item_allowed(item) then return false end; if type(range) ~= "number" then return false end; return range >= 50 end

-- Combat State Table
local CombatState = {
    silent_aim = { enabled = false, fov = 100, draw_fov = false, fov_color = Color3.new(1,1,1), hit_chance = 100, katana_check = false, visible_check = false, manipulation = true, hit_part = "Head", head_hit_chance = 0 },
    aim_assist = { enabled = false, fov = 500, draw_fov = false, fov_color = Color3.new(1,1,1), smoothness = 20, reaction_time = 0, target_switch_delay = 0, sticky_target = false, katana_check = false, overshoot_chance = 0, overshoot_pixels = 15, aim_method = "Linear", aim_part = "Head", head_hit_chance = 0, visible_check = false, prediction = false, prediction_strength_x = 50, prediction_strength_y = 50, jitter = false, jitter_strength_x = 0, jitter_strength_y = 0, bind_mode = "always", keybind = nil },
    triggerbot = { enabled = false, reaction_time = 0, miss_chance = 0, katana_check = false, flashbang_check = true, scope_check = true },
    bullet_tracers = { enabled = false, line_type = "Solid", duration = 250, max_distance = 2000, thickness = 2, transparency = 10, local_only = true, lightning_jaggedness = 14, color = Color3.new(1,1,1) },
    hit_sounds = { enabled = false, volume = 70, pitch = 100, hit_file = "", shot_file = "", reload_file = "", equip_file = "" },
    esp = { distance_cap = DEFAULT_ESP_DISTANCE_CAP }
}
UILibrary.state = CombatState

local Combat = {}
Combat.__index = Combat

function Combat.new(ui)
    return setmetatable({
        ui = ui, hit_assets = {}, hit_sounds = {}, fov_circles = {}, fov_draw_conn = nil,
        next_shoot_time = 0, trigger_miss_target = nil, trigger_miss_position = nil,
        trigger_miss_side = 0, trigger_miss_until = 0,
        silent_utility = nil, silent_raycast_hooked = false,
        tracer_entries = {}, tracer_conn = nil, tracer_effect = nil,
        original_tracer_play = nil, tracer_play_wrapper = nil,
        aim_locked_target = nil, aim_smooth_cf = nil, aim_last_cam_cf = nil,
        aim_overshoot_offset = nil, aim_overshoot_until = 0, cam_controller = nil,
        aim_target_history = {}, aim_next_switch_time = 0,
        aim_assist_using_bind = false, aim_assist_conn = nil,
        original_raycast_fn = nil,
        original_sound_originals = nil, original_sound_modules = nil,
        original_toggle_autoshoot_fn = nil,
        aim_step_conn = nil, tracer_update_conn = nil
    }, Combat)
end

function Combat:ensure_hit_sound_dir()
    if type(makefolder) == "function" then pcall(makefolder, "daydreamer"); pcall(makefolder, "daydreamer/rivals"); pcall(makefolder, HIT_SOUND_DIR) end
end

function Combat:list_hit_sound_files()
    local files = {}; if type(listfiles) ~= "function" or type(isfolder) ~= "function" or not isfolder(HIT_SOUND_DIR) then return files end
    local ok, entries = pcall(listfiles, HIT_SOUND_DIR); if ok and type(entries) == "table" then for _, path in ipairs(entries) do local filename = tostring(path):match("([^/\\]+)$"); if filename and filename:lower():match("%.(mp3|ogg|wav)$") then files[#files+1] = filename end end end
    table.sort(files, function(a,b) return a:lower() < b:lower() end); return files
end

function Combat:get_hit_sound_asset(filename)
    if type(filename) ~= "string" or filename == "" then return nil end
    local path = HIT_SOUND_DIR .. "/" .. filename
    if type(isfile) ~= "function" or not isfile(path) then return nil end
    local loader = getcustomasset or env.getcustomasset or getsynasset or env.getsynasset or getcustomassetasync or env.getcustomassetasync
    if type(loader) ~= "function" then return nil end
    local ok, asset = pcall(loader, path); return (ok and type(asset) == "string") and asset or nil
end

function Combat:play_sound_event(event, force)
    local state = self.ui.state.hit_sounds; if not state or (state.enabled ~= true and not force) then return end
    local asset = self:get_hit_sound_asset(state[event .. "_file"]); if not asset then return false end
    local sound = Instance.new("Sound"); sound.SoundId = asset; sound.Volume = math.clamp((tonumber(state.volume) or 70) / 100, 0, 1.5); sound.PlaybackSpeed = math.clamp((tonumber(state.pitch) or 100) / 100, 0.5, 2); sound.Parent = sound_service
    self.hit_sounds[sound] = true; sound.Ended:Connect(function() self.hit_sounds[sound] = nil; sound:Destroy() end); sound:Play()
    return true
end

function Combat:install_sound_hooks()
    local ok, viewmodel = pcall(require, player_scripts.Modules.ClientReplicatedClasses.ClientFighter.ClientItem.ClientViewModel)
    local item_ok, client_item = pcall(require, player_scripts.Modules.ClientReplicatedClasses.ClientFighter.ClientItem)
    if not ok or not item_ok then return false end
    local originals = { hitmarker = viewmodel.PlayHitmarkerSound, create_sound = client_item.CreateSound }
    self.original_sound_originals = originals
    self.original_sound_modules  = { viewmodel = viewmodel, client_item = client_item }
    local runtime = { event = nil, reload_pending_until = 0 }
    viewmodel.PlayHitmarkerSound = function(s, ...) if self:play_sound_event("hit") then return end; runtime.event = "hit"; local r = originals.hitmarker(s, ...); runtime.event = nil; return r end
    client_item.CreateSound = function(s, ...)
        local owner = s.ClientFighter and s.ClientFighter.Player; if owner ~= local_player then return originals.create_sound(s, ...) end
        local evt = runtime.event; if evt == "reload" then runtime.reload_pending_until = 0 elseif not evt and os.clock() < runtime.reload_pending_until then evt = "reload"; runtime.reload_pending_until = 0 end
        evt = evt or "shot"; if self:play_sound_event(evt) then return nil end
        return originals.create_sound(s, ...)
    end
    return true
end

function Combat:start_fov_drawings()
    if not self.fov_draw_conn then
        self.fov_draw_conn = run_service.RenderStepped:Connect(function()
            for name, entry in pairs(self.fov_circles) do
                local st = self.ui.state[name]
                local draw = st and st.enabled == true and st.draw_fov == true
                if draw and not entry.circle then entry.circle = make_drawing_circle() end
                if entry.circle then
                    entry.circle.Visible = draw
                    if draw then entry.circle.Position = screen_center(); entry.circle.Radius = st.fov; entry.circle.Color = st.fov_color end
                end
            end
        end)
    end
end

function Combat:install_triggerbot()
    self.original_toggle_autoshoot_fn = mechanics_controller._ToggleAutoShoot
    mechanics_controller._ToggleAutoShoot = function(p1)
        p1._auto_shoot_hash = p1._auto_shoot_hash + 1; local current_hash = p1._auto_shoot_hash
        if p1._auto_shoot_connection then p1._auto_shoot_connection:Disconnect() end
        local is_shooting = false
        p1._auto_shoot_connection = run_service.RenderStepped:Connect(function()
            if p1._auto_shoot_hash ~= current_hash or not (p1.LocalFighter and p1.LocalFighter.EquippedItem and p1:IsAlive()) then return end
            local st = self.ui.state.triggerbot; if not st or not st.enabled then if is_shooting then is_shooting = false; p1:EquippedItemInput("FinishShooting") end; self.next_shoot_time = 0; return end
            if st.flashbang_check ~= false and local_player.PlayerGui:FindFirstChild("FlashbangGui") then self.next_shoot_time = 0; return end
            local weapon_reach = p1.LocalFighter.EquippedItem:GetAutoShootReach()
            if st.scope_check ~= false and (not weapon_reach or weapon_reach <= 0) then if is_shooting then is_shooting = false; p1:EquippedItemInput("FinishShooting") end; self.next_shoot_time = 0; return end
            if not weapon_reach or weapon_reach <= 0 then weapon_reach = 100 end
            local cam = workspace.CurrentCamera; if not cam then return end
            trigger_filter[1] = local_player.Character or workspace; trigger_ray_params.FilterDescendantsInstances = trigger_filter
            local active_ray = workspace:Raycast(cam.CFrame.Position, cam.CFrame.LookVector * weapon_reach, trigger_ray_params)
            if active_ray and active_ray.Instance then
                local hit_model = active_ray.Instance:FindFirstAncestorOfClass("Model")
                if hit_model and hit_model:HasTag("Entity") and is_valid_enemy(hit_model) and (st.katana_check ~= true or not is_katana_deflecting(hit_model)) then
                    local now = os.clock(); local delay = (st.reaction_time or 0) / 1000
                    if delay > 0 then if self.next_shoot_time == 0 then self.next_shoot_time = now + delay; return elseif now < self.next_shoot_time then return end end
                    self.next_shoot_time = 0
                    if not is_shooting then
                        if math.clamp(tonumber(st.miss_chance) or 0, 0, 100) > 0 and math.random(1, 100) <= st.miss_chance then self.trigger_miss_target = hit_model; self.trigger_miss_position = active_ray.Position; self.trigger_miss_side = math.random(0, 1) == 0 and -1 or 1; self.trigger_miss_until = os.clock() + 0.15 end
                        is_shooting = true; p1:EquippedItemInput("StartShooting")
                        if p1.LocalFighter.EquippedItem.Name ~= "Flamethrower" then task.delay(0.01, function() p1:EquippedItemInput("FinishShooting"); is_shooting = false end) end
                    end
                    return
                end
            end
            self.next_shoot_time = 0; self.trigger_miss_target = nil; self.trigger_miss_until = 0
            if is_shooting then is_shooting = false; p1:EquippedItemInput("FinishShooting") end
        end)
    end
    pcall(function() if mechanics_controller.LocalFighter then mechanics_controller:_ToggleAutoShoot() end end)
end

function Combat:install_silent_raycast()
    if self.silent_raycast_hooked then return end
    local ok, utility = pcall(require, replicated_storage.Modules.Utility)
    if not ok or type(utility) ~= "table" or type(utility.Raycast) ~= "function" then return end
    local original_raycast = utility.Raycast; self.silent_raycast_hooked = true
    self.silent_utility      = utility
    self.original_raycast_fn = original_raycast
    utility.Raycast = function(hook_self, from, to, range, ignore, mode, debug)
        if self.trigger_miss_target and os.clock() <= self.trigger_miss_until then
            local cam = workspace.CurrentCamera; local delta = cam.CFrame.RightVector * (TRIGGER_MISS_OFFSET * self.trigger_miss_side)
            self.trigger_miss_target = nil; self.trigger_miss_until = 0
            return original_raycast(hook_self, from, from + delta.Unit * range, range, ignore, mode, debug)
        end
        local st = self.ui.state.silent_aim
        if st and st.enabled and should_silent_raycast(range) and math.random(1, 100) <= (st.hit_chance or 100) then
            local result = build_silent_raycast_result(from, range, st); if result then return result end
        end
        return original_raycast(hook_self, from, to, range, ignore, mode, debug)
    end
end

function Combat:step_aim_assist(dt)
    dt = dt or (1/240); local st = self.ui.state.aim_assist
    if not st or not st.enabled then self.aim_locked_target = nil; return end
    local cam = workspace.CurrentCamera; if not cam then return end
    local now = os.clock()
    if self.aim_locked_target and (not self.aim_locked_target.Parent or not self.aim_locked_target:IsDescendantOf(workspace)) then self.aim_locked_target = nil end

    if not self.aim_locked_target then
        local best, best_dist = nil, st.fov
        local center = screen_center(cam)
        for _, p in ipairs(players:GetPlayers()) do
            if p ~= local_player and p.Character and is_valid_enemy(p.Character) and (st.katana_check ~= true or not is_katana_deflecting(p.Character)) then
                local part = hit_part_from_name(p.Character, st.aim_part, st.head_hit_chance)
                if part and ((not st.visible_check) or has_line_of_sight(part)) then
                    local scr, on = world_to_screen(part.Position, cam)
                    if on then
                        local dist = (Vector2.new(scr.X, scr.Y) - center).Magnitude
                        if dist <= best_dist then best_dist = dist; best = part end
                    end
                end
            end
        end
        self.aim_locked_target = best; self.aim_smooth_cf = cam.CFrame
    end

    if not self.aim_locked_target then return end

    local my_char = local_player.Character; if not my_char then return end
    if not self.cam_controller then pcall(function() self.cam_controller = require(player_scripts.Controllers.CameraController) end) end
    if not self.cam_controller then return end

    local true_pos = self.aim_locked_target.Position
    local alpha = get_aim_lerp_alpha(st.smoothness / 10, st.aim_method, dt)
    self.aim_smooth_cf = self.aim_smooth_cf:Lerp(CFrame.lookAt(cam.CFrame.Position, true_pos), alpha)
    pcall(function() self.cam_controller:MimicRotation(self.aim_smooth_cf) end)
end

function Combat:add_tracer_segment(start_pos, end_pos, st)
    local entry = { start_pos = start_pos, end_pos = end_pos, created_at = os.clock(), duration = st.duration/1000, line_type = st.line_type, color = st.color, thickness = st.thickness, transparency = st.transparency/100, lines = {} }
    for i=1,(entry.line_type=="Solid" and 1 or 8) do local ok, line = pcall(Drawing.new, "Line"); if ok then line.Thickness=entry.thickness; line.Color=entry.color; entry.lines[i]=line end end
    self.tracer_entries[#self.tracer_entries+1] = entry
end

function Combat:update_tracers()
    local now = os.clock()
    for i=#self.tracer_entries,1,-1 do
        local e = self.tracer_entries[i]; local a = (now-e.created_at)/e.duration
        if a>=1 then for _,l in ipairs(e.lines) do remove_drawing(l) end; table.remove(self.tracer_entries,i)
        else local from,on1 = world_to_screen(e.start_pos); local to,on2 = world_to_screen(e.end_pos); local vis = on1 and on2
            for _,l in ipairs(e.lines) do l.Visible = vis end
            if vis then local s2 = Vector2.new(from.X, from.Y); local e2 = Vector2.new(to.X, to.Y); local delta = e2 - s2
                if e.line_type == "Dashed" then
                    for j,l in ipairs(e.lines) do local fa=(j-1)/#e.lines; local ta=math.min(1,fa+0.55/#e.lines); l.From=s2+delta*fa; l.To=s2+delta*ta; l.Transparency=(1-e.transparency)*(1-a) end
                else e.lines[1].From=s2; e.lines[1].To=e2; e.lines[1].Transparency=(1-e.transparency)*(1-a) end
            end
        end
    end
end

function Combat:install_bullet_tracers()
    local ok, effect = pcall(require, player_scripts.Modules.TracerEffect); if not ok or not effect.Play then return end
    local orig = effect.Play
    self.tracer_effect        = effect
    self.original_tracer_play = orig
    effect.Play = function(s, data, properties, context)
        if self.ui.state.bullet_tracers.enabled and (self.ui.state.bullet_tracers.local_only == false or data.IsLocal == true) and context and context.MuzzlePosition then
            for _, group in pairs(data.RaycastResults or {}) do local res = group.Position and group or group[1]; if res and res.Position then self:add_tracer_segment(context.MuzzlePosition, res.Position, self.ui.state.bullet_tracers) end end
        end
        return orig(s, data, properties, context)
    end
    self.tracer_update_conn = run_service.RenderStepped:Connect(function() self:update_tracers() end)
end

function Combat:Unload()
    if self.fov_draw_conn      then pcall(function() self.fov_draw_conn:Disconnect()      end) self.fov_draw_conn      = nil end
    if self.aim_step_conn      then pcall(function() self.aim_step_conn:Disconnect()      end) self.aim_step_conn      = nil end
    if self.tracer_update_conn then pcall(function() self.tracer_update_conn:Disconnect() end) self.tracer_update_conn = nil end

    for _, entry in pairs(self.fov_circles) do remove_drawing(entry.circle) end
    self.fov_circles = {}
    for _, e in ipairs(self.tracer_entries) do for _, l in ipairs(e.lines) do remove_drawing(l) end end
    self.tracer_entries = {}

    if self.silent_utility and self.original_raycast_fn then
        pcall(function() self.silent_utility.Raycast = self.original_raycast_fn end)
    end
    if self.original_sound_originals and self.original_sound_modules then
        pcall(function()
            self.original_sound_modules.viewmodel.PlayHitmarkerSound  = self.original_sound_originals.hitmarker
            self.original_sound_modules.client_item.CreateSound       = self.original_sound_originals.create_sound
        end)
    end
    if self.original_toggle_autoshoot_fn then
        pcall(function() mechanics_controller._ToggleAutoShoot = self.original_toggle_autoshoot_fn end)
    end
    if self.tracer_effect and self.original_tracer_play then
        pcall(function() self.tracer_effect.Play = self.original_tracer_play end)
    end

    for sound in pairs(self.hit_sounds) do pcall(function() sound:Stop(); sound:Destroy() end) end
    self.hit_sounds = {}

    local st = self.ui.state
    for _, v in pairs(st) do
        if type(v) == "table" and v.enabled ~= nil then v.enabled = false end
    end
end

local combat_instance = Combat.new(UILibrary)
UILibrary.state = CombatState
combat_instance:ensure_hit_sound_dir()
combat_instance:install_sound_hooks()
combat_instance:install_triggerbot()
task.spawn(function() for i=1,120 do combat_instance:install_silent_raycast(); if combat_instance.silent_raycast_hooked then break end task.wait(0.25) end end)
combat_instance:install_bullet_tracers()
combat_instance:start_fov_drawings()
combat_instance.aim_step_conn = run_service.RenderStepped:Connect(function(dt) combat_instance:step_aim_assist(dt) end)


-- ============================================================================
-- 3. RAGEBOT LOGIC (integrated from ragebot.lua - no LPH macros)
-- ============================================================================
local Ragebot = (function()
    local players           = cloneref(game:GetService("Players"))
    local run_svc           = cloneref(game:GetService("RunService"))
    local userinput         = cloneref(game:GetService("UserInputService"))
    local workspace         = cloneref(game:GetService("Workspace"))
    local replicated_storage= cloneref(game:GetService("ReplicatedStorage"))
    local local_player = players.LocalPlayer
    local camera       = workspace.CurrentCamera

    local rb_conns = {}
    local function rbtrack(c) rb_conns[#rb_conns + 1] = c; return c end

    --// modules
    local modules = {}
    local function get_modules()
        if modules.ready then return modules end
        local ps     = local_player:FindFirstChild("PlayerScripts")
        local rs_mod = replicated_storage:FindFirstChild("Modules")
        if rs_mod then
            local function sr(ref) local ok,r = pcall(require, ref); return ok and r or nil end
            modules.enums   = sr(rs_mod:FindFirstChild("EnumLibrary"))
            modules.utility = sr(rs_mod:FindFirstChild("Utility"))
        end
        if ps then
            local ctrls = ps:FindFirstChild("Controllers")
            if ctrls then
                local function sr(ref) local ok,r = pcall(require, ref); return ok and r or nil end
                modules.fighter = sr(ctrls:FindFirstChild("FighterController"))
                modules.camctrl = sr(ctrls:FindFirstChild("CameraController"))
            end
        end
        modules.ready = modules.enums and modules.fighter and modules.utility
        return modules
    end

    --// cfg
    local cfg = {
        master         = false,
        enabled        = false,
        auto           = true,
        autoshoot      = true,
        shoot_attempts = 1,
        hit_part       = "Head",
        weapon_slot    = "primary",
        atk_pos        = "default",
        under_offset   = 4,
        custom_atk     = false,
        custom_height  = 2,
        custom_front   = 0,
        custom_side    = 0,
        custom_vert    = 0,
        custom_radius  = 0,
        predict        = false,
        predict_mul    = 1.2,
        voidspam       = false,
        vs_shoot_ms    = 500,
        vs_hide_ms     = 500,
        status_label   = false,
    }

    local target = { char=nil, player=nil, immune=false, manual=false }

    local orbit = {
        active=false, angle=0, speed=9000,
        serverpos=nil, savedpos=nil, conn=nil,
        height=2, radius=0,
    }

    local state = { csync=false, reloading=false, outofammo=false, reload_at=0 }
    local vspam = { phase=nil, last=0, duration=0, shoot_ready_at=0 }
    local vsnap = { cf=nil, lv=nil, av=nil }
    local oldpos = nil
    local oldpos_char = nil

    local SLOTS          = { primary=1, secondary=2, melee=3 }
    local MELEE_NAMES    = {["Battle Axe"]=true,["Chainsaw"]=true,["Fists"]=true,["Gunblade"]=true,["Katana"]=true,["Knife"]=true,["Scythe"]=true,["Trowel"]=true,["Maul"]=true}
    local INFINITE_WPNS  = {["Energy Rifle"]=true,["Energy Pistols"]=true}

    local function in_lobby() return false end

    local katanausers = {}
    local shared_env = (getgenv and getgenv()) or _G
    shared_env.dreamerkatana = katanausers

    local function detectkatana()
        task.spawn(function()
            local katana, attempts = nil, 0
            while attempts < 10 do
                pcall(function()
                    local m = local_player.PlayerScripts.Modules.Items:FindFirstChild("Katana", true)
                    if m then katana = require(m) end
                end)
                if not katana then
                    for _, m in pairs(local_player.PlayerScripts:GetDescendants()) do
                        if m.Name == "Katana" and m:IsA("ModuleScript") then
                            local ok, res = pcall(require, m)
                            if ok then katana = res; break end
                        end
                    end
                end
                if katana and type(katana) == "table" and katana.StartAiming then break end
                attempts += 1
                task.wait(1)
            end
            if katana and type(katana) == "table" and katana.StartAiming then
                local old = katana.StartAiming
                katana.StartAiming = function(self, force)
                    local fighter = self.ClientFighter
                    local player  = fighter and fighter.Player
                    if player then
                        katanausers[player] = true
                        local dur = (self.Info and self.Info.DeflectDuration) or 0.6
                        task.delay(dur, function() katanausers[player] = nil end)
                    end
                    return old(self, force)
                end
            end
        end)
    end
    detectkatana()

    local sling_active
    local function target_deflecting()
        return target.player and katanausers[target.player] and not sling_active()
    end

    local weapon_cache = { t = 0, name = nil }
    local function parse_weapon_name(model_name)
        local dash = model_name:find("-", 1, true)
        if not dash then return nil end
        local weapon = model_name:sub(dash + 1):match("^%s*(.-)%s*$")
        return weapon ~= "" and weapon or nil
    end
    local function get_weapon(force)
        local now = os.clock()
        if not force and now - weapon_cache.t < 0.05 then return weapon_cache.name end
        local vm = workspace:FindFirstChild("ViewModels")
        local fp = vm and vm:FindFirstChild("FirstPerson")
        if not fp then weapon_cache.t = now; weapon_cache.name = nil; return nil end
        local found = nil
        for _, c in ipairs(fp:GetChildren()) do
            found = parse_weapon_name(c.Name)
            if found then break end
        end
        weapon_cache.t = now; weapon_cache.name = found
        return found
    end
    local function is_sling(w)    return w and false end
    local function is_infinite(w) return w and INFINITE_WPNS[w] == true end
    local function pick_melee()   return (cfg.weapon_slot or "primary") == "melee" end
    local function want_slot()    return SLOTS[cfg.weapon_slot or "primary"] or 1 end
    function sling_active() return false end

    local function hook_fast_melee()
        if _G.daydreamer_ragebot_melee_hooked then return end
        local ok, melee_module = pcall(function()
            return require(local_player.PlayerScripts.Modules.ItemTypes.Melee)
        end)
        if not (ok and type(melee_module) == "table") then return end
        if type(melee_module.StartShooting) ~= "function" then return end
        local orig = melee_module.StartShooting
        melee_module.StartShooting = function(self, p1, p2)
            local old
            if cfg.master and not in_lobby() and pick_melee() and self.Info then
                old = self.Info.AttackCooldown
                self.Info.AttackCooldown = 0
            end
            local r = { orig(self, p1, p2) }
            if old ~= nil and self.Info then self.Info.AttackCooldown = old end
            return table.unpack(r)
        end
        _G.daydreamer_ragebot_melee_hooked = true
    end
    task.spawn(function()
        for _ = 1, 20 do
            hook_fast_melee()
            if _G.daydreamer_ragebot_melee_hooked then break end
            task.wait(1)
        end
    end)

    local function is_teammate(p)
        if not p then return false end
        return local_player:GetAttribute("TeamID") == p:GetAttribute("TeamID")
    end

    local function valid_char(char)
        if not char or not char.Parent then return false end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then return false end
        if not char:FindFirstChild("HumanoidRootPart") then return false end
        local tp = players:GetPlayerFromCharacter(char)
        return tp and not is_teammate(tp)
    end

    local function get_ammo(weapon)
        weapon = weapon or get_weapon()
        local m = get_modules()
        if not m.fighter then return 0,0,pick_melee() end
        if is_infinite(weapon) then return nil,nil,false end
        local lf = m.fighter.LocalFighter
        if not (lf and lf.EquippedItem) then return 0,0,pick_melee() end
        local cur, max_a, is_melee = 0, 0, false
        pcall(function()
            local item = lf.EquippedItem
            local nm = tostring(item:Get("Name") or "")
            cur     = item:Get("CurrentAmmo") or item:Get("Ammo") or 0
            max_a   = item:Get("MaxAmmo")     or item:Get("MaxBullets") or cur
            is_melee = nm:lower():find("melee",1,true) ~= nil or MELEE_NAMES[nm] == true
        end)
        if pick_melee() then is_melee = true end
        return tonumber(cur) or 0, tonumber(max_a) or 0, is_melee
    end

    local function can_shoot(weapon)
        weapon = weapon or get_weapon()
        local char = local_player.Character
        if not char then return false end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then return false end
        if is_infinite(weapon) then return true end
        local cur, _, melee = get_ammo(weapon)
        if cur == nil then return true end
        return cur > 0 or melee
    end

    local function vm_reloading()
        local vm = workspace:FindFirstChild("ViewModels")
        local fp = vm and vm:FindFirstChild("FirstPerson")
        if not fp then return false end
        local found = false
        pcall(function()
            for _, d in ipairs(fp:GetDescendants()) do
                if d:IsA("Animator") then
                    for _, tr in ipairs(d:GetPlayingAnimationTracks()) do
                        local nm = (tr.Name or ""):lower()
                        local an = tr.Animation
                        if an then nm = nm .. " " .. tostring(an.Name):lower() end
                        if nm:find("reload", 1, true) then found = true return end
                    end
                end
            end
        end)
        return found
    end

    local reload_check_t = 0
    local reload_check_value = false
    local function check_reloading(weapon)
        local now = tick()
        if now - reload_check_t < 0.08 then return reload_check_value end
        reload_check_t = now
        local function finish(value) reload_check_value = value == true; return reload_check_value end
        if is_infinite(weapon or get_weapon()) then return finish(false) end
        local m = get_modules()
        local lf = m.fighter and m.fighter.LocalFighter
        if not (lf and lf.EquippedItem) then return finish(false) end
        local res = false
        pcall(function()
            for _, k in ipairs({"Reloading","IsReloading","IsReload"}) do
                local v = lf.EquippedItem:Get(k)
                if v == true or v == 1 then res = true return end
            end
        end)
        if res then return finish(true) end
        if vm_reloading() then return finish(true) end
        return finish(state.reload_at > 0 and (now - state.reload_at) < 1.75)
    end

    local MAX_VOID_UNDER_FLOOR = 0.5
    local function void_hrp()
        local char = local_player.Character
        return char and char:FindFirstChild("HumanoidRootPart")
    end
    local function floor_limited_void_cf(root)
        if not root then return nil end
        local pos = root.Position
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        local char = local_player.Character
        if char then params.FilterDescendantsInstances = { char } end
        local ok, result = pcall(function()
            return workspace:Raycast(pos + Vector3.new(0, 8, 0), Vector3.new(0, -512, 0), params)
        end)
        if not ok or not result then return nil end
        local min_y = result.Position.Y - MAX_VOID_UNDER_FLOOR
        local y = math.max(pos.Y, min_y)
        return CFrame.new(pos.X, y, pos.Z) * CFrame.Angles(math.pi, math.pi, math.pi)
    end
    local function clr_snap()
        if vsnap.cf then
            local hrp = void_hrp()
            if hrp and (not vsnap.char or vsnap.char == local_player.Character) then
                pcall(function() hrp.CFrame = vsnap.cf end)
            end
        end
        vsnap.cf, vsnap.lv, vsnap.av, vsnap.char = nil, nil, nil, nil
    end
    local MAX_REAL_POS = 1e6
    local function snap_void(hrp)
        if not hrp then return end
        if in_lobby() then return end
        if not vsnap.cf then
            local cf = hrp.CFrame
            if cf.Position.Magnitude >= MAX_REAL_POS then return end
            vsnap.cf   = cf
            vsnap.char = local_player.Character
        end
        pcall(function()
            local cf = floor_limited_void_cf(hrp)
            if cf then hrp.CFrame = cf end
        end)
    end

    run_svc:BindToRenderStep("ragebot_vfr_csync", Enum.RenderPriority.First.Value, function()
        if not vsnap.cf then return end
        if vsnap.char and vsnap.char ~= local_player.Character then
            vsnap.cf, vsnap.lv, vsnap.av, vsnap.char = nil, nil, nil, nil
            return
        end
        local hrp = void_hrp()
        if not hrp then return end
        pcall(function() hrp.CFrame = vsnap.cf end)
    end)

    local function on_respawn()
        vsnap.cf, vsnap.lv, vsnap.av, vsnap.char = nil, nil, nil, nil
        oldpos, oldpos_char = nil, nil
        orbit.serverpos, orbit.savedpos = nil, nil
        vspam.phase = nil
    end
    rbtrack(local_player.CharacterAdded:Connect(on_respawn))

    local last_slot_force = 0
    local function lf_items()
        local m = get_modules(); local lf = m.fighter and m.fighter.LocalFighter
        return lf and lf.Items
    end
    local function slot_item(idx)
        local items = lf_items(); if not items then return nil end
        if items[idx] then return items[idx] end
        if items[tostring(idx)] then return items[tostring(idx)] end
        local ordered = {}
        for _, it in pairs(items) do if it then ordered[#ordered+1] = it end end
        table.sort(ordered, function(a,b)
            return (tonumber(a:Get("Slot") or a:Get("Index")) or 99) < (tonumber(b:Get("Slot") or b:Get("Index")) or 99)
        end)
        return ordered[idx]
    end
    local function which_slot(item)
        if not item then return nil end
        local items = lf_items(); local oid = item:Get("ObjectID")
        if items and oid then
            for i = 1,3 do
                local it = items[i] or items[tostring(i)]
                if it and it:Get("ObjectID") == oid then return i end
            end
        end
    end
    local function press_slot(idx)
        pcall(function()
            local vim = game:GetService("VirtualInputManager")
            local kc = ({Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three})[idx]
            if not kc then return end
            vim:SendKeyEvent(true, kc, false, game); task.wait(0.02)
            vim:SendKeyEvent(false, kc, false, game)
        end)
    end
    local function eq_slot()
        if in_lobby() then return end
        if not cfg.enabled then return end
        local m = get_modules(); local lf = m.fighter and m.fighter.LocalFighter
        if not lf then return end
        local want = want_slot()
        local eq = lf.EquippedItem
        if eq and which_slot(eq) == want then return end
        local now = tick(); if now - last_slot_force < 0.06 then return end
        last_slot_force = now
        local item = slot_item(want); local oid = item and item:Get("ObjectID")
        if oid then
            local rm = replicated_storage.Remotes.Replication.Fighter.UseItem
            for _, en in ipairs({"Equip","Switch","Select","EquipItem","ChangeItem"}) do
                pcall(function()
                    local ev = m.enums:ToEnum(en)
                    if ev then rm:FireServer(oid, ev, nil, nil) end
                end)
            end
        end
        pcall(function()
            if lf.EquipItem then lf:EquipItem(want) end
            if lf.SwitchToSlot then lf:SwitchToSlot(want) end
        end)
        press_slot(want)
    end

    local function atk_cfg()
        if pick_melee() and not cfg.custom_atk then
            return {height=0,front=0,side=0,vertical=0,radius=0}
        end
        if cfg.custom_atk then
            return {height=cfg.custom_height or 2,front=cfg.custom_front or 0,
                    side=cfg.custom_side or 0,vertical=cfg.custom_vert or 0,radius=cfg.custom_radius or 0}
        end
        if cfg.atk_pos == "under" then
            return {height=0,front=0,side=0,vertical=-(cfg.under_offset or 4),radius=0}
        end
        local w = get_weapon()
        return {height=(w and w:lower():find("sniper")) and 8 or 2,front=0,side=0,vertical=0,radius=0}
    end
    local function orb_base(root)
        if not root then return Vector3.zero end
        local s = atk_cfg()
        return root.Position + root.CFrame.LookVector*s.front + root.CFrame.RightVector*s.side + Vector3.new(0,s.vertical,0)
    end
    local function refresh_atk() local s=atk_cfg(); orbit.height=s.height; orbit.radius=s.radius or 0 end
    local resolve_hit_part

    local function clear_shot_line(origin, target_part, target_pos)
        if not target_part then return false end
        local dir = target_pos - origin
        if dir.Magnitude < 1e-3 then return true end
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        local ignore = {}
        local char = local_player.Character
        if char then ignore[#ignore + 1] = char end
        params.FilterDescendantsInstances = ignore
        local ok, result = pcall(function() return workspace:Raycast(origin, dir, params) end)
        if not ok then return true end
        if not result then return true end
        local hit = result.Instance
        return hit and target.char and hit:IsDescendantOf(target.char)
    end

    local function clear_attack_pos(troot, hit_part)
        if not troot then return nil end
        local s = atk_cfg()
        local base = troot.Position
            + Vector3.new(0, s.height, 0)
            + troot.CFrame.LookVector * s.front
            + troot.CFrame.RightVector * s.side
        local candidates = {
            base,
            base + Vector3.new(0, 2, 0),
            base + Vector3.new(0, 4, 0),
            troot.Position + Vector3.new(0, math.max(s.height or 0, 4), 0),
            troot.Position + Vector3.new(0, 7, 0),
            troot.Position + troot.CFrame.LookVector * -5 + Vector3.new(0, 3, 0),
            troot.Position + troot.CFrame.RightVector * 5 + Vector3.new(0, 3, 0),
            troot.Position + troot.CFrame.RightVector * -5 + Vector3.new(0, 3, 0),
        }
        local target_pos = hit_part and hit_part.Position or troot.Position
        for _, pos in ipairs(candidates) do
            if clear_shot_line(pos, hit_part or troot, target_pos) then return pos end
        end
        return nil
    end

    local function set_vspam_attack_pos()
        if not target.char then return false end
        local troot = target.char:FindFirstChild("HumanoidRootPart")
        if not troot then return false end
        local hit_part = resolve_hit_part(target.char, cfg.hit_part) or troot
        local surf_pos = clear_attack_pos(troot, hit_part)
        if not surf_pos then return false end
        orbit.serverpos = surf_pos
        local surf_cf = CFrame.new(surf_pos)
        local hrp = void_hrp()
        if hrp then pcall(function() hrp.CFrame = surf_cf end) end
        return true
    end

    local function tick_vspam()
        if not cfg.voidspam then return end
        local now = tick(); local elapsed = now - vspam.last
        if vspam.phase == "shoot" then
            set_vspam_attack_pos()
            if elapsed >= vspam.duration then
                vspam.phase="hide"; vspam.duration=(cfg.vs_hide_ms or 500)/1000; vspam.last=now
            end
        elseif vspam.phase == "hide" then
            if elapsed >= vspam.duration then
                vspam.phase="shoot"; vspam.duration=(cfg.vs_shoot_ms or 500)/1000; vspam.last=now
                clr_snap()
                if set_vspam_attack_pos() then vspam.shoot_ready_at = now + 0.08 end
            end
        else
            vspam.phase="shoot"; vspam.duration=(cfg.vs_shoot_ms or 500)/1000; vspam.last=now
            set_vspam_attack_pos()
            vspam.shoot_ready_at = now + 0.08
        end
    end
    local function tick_ammo(weapon)
        weapon = weapon or get_weapon()
        if is_infinite(weapon) then
            state.outofammo=false; state.reloading=false; state.reload_at=0; return nil,nil,false
        end
        local cur, _, melee = get_ammo(weapon)
        local was_oom = state.outofammo
        state.outofammo = not melee and (tonumber(cur) or 0) <= 0
        local rel = check_reloading(weapon)
        if rel and not state.reloading then state.reload_at = tick()
        elseif not rel then state.reload_at = 0 end
        state.reloading = rel
        if not state.outofammo and was_oom and cfg.voidspam then
            vspam.phase = "shoot"; vspam.last = tick()
        end
        return cur, nil, melee
    end
    local autoshoot

    local function stop_sync()
        if not state.csync then return end
        if orbit.conn then orbit.conn:Disconnect(); orbit.conn=nil end
        state.csync=false; orbit.active=false; clr_snap(); vspam.phase=nil; vspam.shoot_ready_at=0
        local m = get_modules(); local lf = m.fighter and m.fighter.LocalFighter
        if orbit.savedpos and lf and lf.Entity and lf.Entity.RootPart and not _G.dreamerunderground then
            pcall(function() lf.Entity.RootPart.CFrame = orbit.savedpos end)
        end
        orbit.serverpos=nil; orbit.savedpos=nil; oldpos=nil; oldpos_char=nil
    end
    local function start_sync()
        if in_lobby() then return end
        if state.csync then return end
        if target.immune and not sling_active() then return end
        if not target.char or not valid_char(target.char) then return end
        local m = get_modules(); if not m.ready then return end
        orbit.serverpos = nil
        eq_slot(); state.csync=true; orbit.active=true; refresh_atk()
        local lf0 = m.fighter.LocalFighter
        if lf0 and lf0.Entity and lf0.Entity.RootPart and not orbit.savedpos then
            orbit.savedpos = lf0.Entity.RootPart.CFrame
        end
        orbit.conn = run_svc.Heartbeat:Connect(function(dt)
            if not state.csync then return end
            if target.immune and not sling_active() then stop_sync() return end
            if not target.char or not valid_char(target.char) then stop_sync() return end
            local m = get_modules(); local lf = m.fighter and m.fighter.LocalFighter
            if not lf or not lf.Entity or not lf.Entity.RootPart then return end
            local _w = get_weapon(); local sling = is_sling(_w)
            local eq = lf.EquippedItem
            if eq and not pick_melee() then
                local nm = tostring(eq:Get("Name") or ""):lower()
                if nm:find("fist",1,true) or nm:find("utility",1,true) then return end
            end
            eq_slot()
            local myroot = lf.Entity and lf.Entity.RootPart
            if not myroot then return end
            do
                local cf0 = myroot.CFrame
                if cf0.Position.Magnitude < MAX_REAL_POS then
                    oldpos = cf0; oldpos_char = local_player.Character
                end
            end
            if state.reloading and not sling then
                if cfg.voidspam then
                    local hrp = void_hrp(); if hrp then snap_void(hrp) end
                    return
                end
            end
            if not sling and cfg.voidspam then
                tick_vspam()
                if vspam.phase == "hide" then
                    local hrp = void_hrp(); if hrp then snap_void(hrp) end
                    return
                end
            end
            local tchar = target.char
            if not tchar then stop_sync() return end
            local root = tchar:FindFirstChild("HumanoidRootPart")
            if not root then stop_sync() return end
            if target_deflecting() then
                if cfg.voidspam then local hrp = void_hrp(); if hrp then snap_void(hrp) end end
                return
            end
            if state.outofammo and not is_infinite(_w) then
                if cfg.voidspam then
                    local hrp = void_hrp()
                    if hrp then snap_void(hrp)
                    else
                        local cf = floor_limited_void_cf(myroot)
                        if cf then orbit.serverpos = cf.Position; pcall(function() myroot.CFrame = cf end) end
                    end
                    return
                end
            end
            local s = atk_cfg(); orbit.height=s.height; orbit.radius=s.radius or 0
            orbit.angle = orbit.angle + orbit.speed*dt
            orbit.serverpos = orb_base(root) + Vector3.new(
                math.cos(orbit.angle)*orbit.radius, orbit.height, math.sin(orbit.angle)*orbit.radius)
            if cfg.voidspam and not sling then
                local hit_part = resolve_hit_part(target.char, cfg.hit_part) or root
                orbit.serverpos = clear_attack_pos(root, hit_part) or orbit.serverpos
            end
            if not _G.dreamerunderground then
                local cur_cf = myroot.CFrame
                local new_cf = CFrame.new(orbit.serverpos)
                if (cfg.voidspam and vspam.phase == "shoot") or (new_cf.Position - cur_cf.Position).Magnitude < 2000 then
                    myroot.CFrame = new_cf; orbit.savedpos = cur_cf
                end
            end
            if cfg.voidspam and cfg.autoshoot and not target.immune then autoshoot() end
        end)
    end

    local pred_vel=Vector3.new(); local pred_last_pos=nil; local pred_last_t=0
    local function update_vel()
        if not target.char or not cfg.predict then pred_vel=Vector3.new(); pred_last_pos=nil; return end
        local root = target.char:FindFirstChild("HumanoidRootPart"); if not root then return end
        local now=tick(); local dt=now-pred_last_t
        if dt>0 and dt<0.1 and pred_last_pos then
            pred_vel = pred_vel:Lerp((root.Position-pred_last_pos)/dt, 0.6)
        end
        pred_last_pos=root.Position; pred_last_t=now
    end
    local function predict_pos(part, origin)
        if not cfg.predict or not part then return part and part.Position or Vector3.new() end
        local dist = (part.Position-origin).Magnitude
        local ping = 0; pcall(function()
            ping = game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()/1000 end)
        return part.Position + pred_vel*((dist/3000+ping)*cfg.predict_mul)
    end

    resolve_hit_part = function(char, name)
        if not char then return nil end
        local fc = function(n) return char:FindFirstChild(n) end
        if name=="Closest" then
            local myroot = local_player.Character and local_player.Character:FindFirstChild("HumanoidRootPart")
            if not myroot then return fc("Head") end
            local best,bd=nil,math.huge
            for _,p in pairs(char:GetChildren()) do
                if p:IsA("BasePart") then local d=(p.Position-myroot.Position).Magnitude
                    if d<bd then bd=d; best=p end end
            end; return best or fc("Head")
        elseif name=="Random" then
            local t={"Head","HumanoidRootPart","UpperTorso"}; return fc(t[math.random(#t)]) or fc("Head")
        end
        return fc(name) or fc("HumanoidRootPart") or fc("Head")
    end

    autoshoot = function(weapon)
        weapon = weapon or get_weapon()
        if in_lobby() then return end
        if not cfg.enabled or not cfg.autoshoot or not target.char then return end
        if target.immune and not is_sling(weapon) then return end
        if target_deflecting() then return end
        if cfg.voidspam and not sling_active() then
            if vspam.phase=="hide" then return end
            if vspam.phase=="shoot" and tick() < (vspam.shoot_ready_at or 0) then return end
        end
        local melee = pick_melee()
        local m = get_modules(); local lf = m.fighter and m.fighter.LocalFighter
        if not (lf and lf.EquippedItem) then return end
        if not is_infinite(weapon) and not melee then
            if state.reloading or state.outofammo then return end
            if not can_shoot(weapon) then return end
        end
        if not valid_char(target.char) then return end
        local hit_part = resolve_hit_part(target.char, cfg.hit_part); if not hit_part then return end
        local root = local_player.Character and local_player.Character:FindFirstChild("HumanoidRootPart")
        if state.csync and not orbit.serverpos then return end
        local shoot_pos = (state.csync and orbit.serverpos) or (root and root.Position) or Vector3.new()
        local target_pos = predict_pos(hit_part, shoot_pos)
        if cfg.voidspam and not sling_active() and not clear_shot_line(shoot_pos, hit_part, target_pos) then
            return
        end
        if not (m.utility and m.enums) then return end
        local data = {
            [utf8.char(1)] = {
                [utf8.char(0)] = m.utility:EncodeCFrame(CFrame.new(shoot_pos, target_pos)),
                [utf8.char(1)] = m.utility:EncodeCFrame(CFrame.new(shoot_pos, target_pos)),
                [utf8.char(2)] = hit_part,
                [utf8.char(3)] = m.utility:EncodeCFrame(CFrame.new(0.43,0.25,0.42)),
            },
        }
        local oid = lf.EquippedItem:Get("ObjectID"); if not oid then return end
        local attempts = melee and 1 or math.clamp(math.floor(tonumber(cfg.shoot_attempts) or 1), 1, 3)
        for _ = 1, attempts do
            pcall(function()
                replicated_storage.Remotes.Replication.Fighter.UseItem:FireServer(
                    oid, m.enums:ToEnum("StartShooting"), data, nil)
            end)
        end
        if weapon ~= "Flamethrower" and type(lf.Input) == "function" then
            task.delay(0.03, function() pcall(lf.Input, lf, "FinishShooting") end)
        end
    end

    local function nearest()
        if in_lobby() then return nil end
        local cursor = userinput:GetMouseLocation()
        local best, best_d = nil, math.huge
        for _, p in players:GetPlayers() do
            if p ~= local_player and p.Character and valid_char(p.Character) then
                local root = p.Character:FindFirstChild("HumanoidRootPart")
                if root then
                    local wts = _G.dreamerw2s or function(pos) return camera:WorldToViewportPoint(pos) end
                    local sp, on = wts(root.Position, camera)
                    if on and sp then
                        local d = (Vector2.new(sp.X,sp.Y)-cursor).Magnitude
                        if d < best_d then best=p.Character; best_d=d end
                    end
                end
            end
        end
        return best
    end
    local function clear_target()
        cfg.enabled=false; stop_sync()
        target.char=nil; target.player=nil; target.manual=false; target.immune=false
    end
    local function set_target(char)
        if in_lobby() then return end
        if not char then return end
        orbit.serverpos = nil
        cfg.enabled=true; target.char=char
        target.player=players:GetPlayerFromCharacter(char)
        target.immune=false; target.manual=false
        local root = char:FindFirstChild("HumanoidRootPart")
        target.immune = root and root:FindFirstChild("Attachment") ~= nil
        if not target.immune or sling_active() then eq_slot(); start_sync() end
    end
    task.defer(function()
        local m = get_modules(); if not m.camctrl then return end
        local old = m.camctrl.Update
        m.camctrl.Update = function(...)
            local lf = m.fighter and m.fighter.LocalFighter
            if not _G.dreamerunderground and not cfg.voidspam then
                if state.csync and lf and lf.Entity and lf.Entity.RootPart and oldpos
                   and oldpos_char == local_player.Character then
                    lf.Entity.RootPart.CFrame = oldpos
                end
            end
            return old(...)
        end
    end)

    local immune_list = {}
    local next_immune_scan = 0
    rbtrack(run_svc.Heartbeat:Connect(function()
        local now = tick()
        if now < next_immune_scan then return end
        next_immune_scan = now + 0.1
        for _, p in pairs(players:GetPlayers()) do
            if p ~= local_player then
                local char = p.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                local now_immune = root and root:FindFirstChild("Attachment") ~= nil
                if now_immune and not immune_list[p] then
                    immune_list[p] = true
                    if target.player == p then
                        target.immune=true
                        if not sling_active() then vspam.phase=nil; clr_snap(); stop_sync() end
                    end
                elseif not now_immune and immune_list[p] then
                    immune_list[p] = nil
                    if target.player == p then
                        target.immune = false
                        if cfg.enabled and target.char and valid_char(target.char) then start_sync() end
                    end
                end
            end
        end
    end))

    local function update_sling(weapon) return is_sling(weapon or get_weapon()) end
    local fflag_sling_state = nil
    local function update_fflag(weapon, target_ok)
        local want = cfg.enabled and not in_lobby() and target.char
            and target_ok ~= false
            and (target_ok == true or valid_char(target.char))
            and is_sling(weapon or get_weapon())
        if fflag_sling_state == want then return end
        fflag_sling_state = want
        if want then
            pcall(function() setfflag("TargetTimeDelayFacctorTenths","999999") end)
        else
            pcall(function() setfflag("TargetTimeDelayFacctorTenths","1") end)
        end
    end

    rbtrack(run_svc.Heartbeat:Connect(function()
        get_modules()
        if in_lobby() then
            if cfg.enabled or state.csync or target.char then clear_target() end
            cfg.master = false
            update_fflag(nil, false); update_sling(nil)
            return
        end
        local active = cfg.master or cfg.enabled or state.csync
        if not active then update_fflag(nil, false); return end
        local weapon = get_weapon()
        local target_ok = target.char and valid_char(target.char) or false
        local sling = update_sling(weapon)
        update_fflag(weapon, target_ok)
        local cur, _, melee = tick_ammo(weapon)
        if cfg.master and cfg.auto then
            if (cur==nil or cur>0 or melee) and not state.reloading then
                if not cfg.enabled or not target.char or not target_ok then
                    local nt = nearest()
                    if nt then
                        if cfg.enabled then stop_sync() end
                        set_target(nt)
                        target_ok = target.char and valid_char(target.char) or false
                        sling = is_sling(weapon)
                    end
                end
            end
        end
        if cfg.enabled and target.char then
            if not target_ok then clear_target(); return end
            eq_slot()
            if cfg.autoshoot and (not target.immune or sling) then
                if not (state.csync and cfg.voidspam and not sling) then autoshoot(weapon) end
            end
        end
    end))
    rbtrack(run_svc.RenderStepped:Connect(function()
        if in_lobby() then pred_vel=Vector3.new(); pred_last_pos=nil; return end
        if cfg.enabled and target.char and cfg.predict then update_vel() end
    end))

    -- Status GUI (with safe parenting - never blocks load)
    local status_gui, status_lbl
    do
        local function try_parent(gui)
            if type(gethui) == "function" then
                local ok, h = pcall(gethui)
                if ok and h then
                    local pok = pcall(function() gui.Parent = h end)
                    if pok then return true end
                end
            end
            local cg_ok, cg = pcall(function() return game:GetService("CoreGui") end)
            if cg_ok and cg then
                local pok = pcall(function() gui.Parent = cg end)
                if pok then return true end
            end
            local lpl = players.LocalPlayer
            local pg = lpl and lpl:FindFirstChildOfClass("PlayerGui")
            if pg then
                local pok = pcall(function() gui.Parent = pg end)
                if pok then return true end
            end
            return false
        end

        local gui = Instance.new("ScreenGui")
        gui.Name = "rb_status"
        gui.ResetOnSpawn = false
        gui.IgnoreGuiInset = true
        gui.DisplayOrder = 10001
        gui.ZIndexBehavior = Enum.ZIndexBehavior.Global

        if try_parent(gui) then
            local lbl = Instance.new("TextLabel")
            lbl.BackgroundTransparency = 1
            lbl.AnchorPoint = Vector2.new(0.5, 0.5)
            lbl.Position = UDim2.new(0.5, 0, 0.5, 30)
            lbl.Size = UDim2.new(0, 300, 0, 20)
            lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
            lbl.TextSize = 14
            lbl.Font = Enum.Font.Gotham
            lbl.TextStrokeTransparency = 0.5
            lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
            lbl.Visible = false
            lbl.Parent = gui
            status_gui = gui
            status_lbl = lbl
        else
            pcall(function() gui:Destroy() end)
            status_gui, status_lbl = nil, nil
        end
    end

    local next_status_update = 0
    rbtrack(run_svc.RenderStepped:Connect(function()
        if not cfg.status_label or not status_lbl then return end
        local now = tick()
        if now < next_status_update then return end
        next_status_update = now + 0.1
        local text
        if not cfg.master then
            text = in_lobby() and "ragebot: disabled (in lobby)" or " "
        elseif not target.char then
            text = "ragebot: idle"
        elseif target.immune then
            text = "ragebot: target is immune"
        elseif target_deflecting() then
            text = "ragebot: target deflecting with katana"
        elseif state.reloading or state.outofammo then
            text = "ragebot: out of ammo, reloading"
        elseif cfg.voidspam and vspam.phase == "hide" then
            text = "ragebot: voidspamming"
        elseif state.csync then
            text = "ragebot: attacking"
        else
            text = "ragebot: idle"
        end
        status_lbl.Text = text
        status_lbl.Visible = true
    end))

    return {
        cfg = cfg,
        set_master = function(v)
            if v == true and in_lobby() then cfg.master = false; clear_target(); return false end
            cfg.master = v == true
            if v then
                local nt = nearest()
                if nt then target.manual = true; set_target(nt) end
            else
                clear_target()
            end
            return true
        end,
        set_custom_atk = function(v) cfg.custom_atk = v == true; refresh_atk() end,
        set_predict = function(v) cfg.predict = v == true end,
        set_voidspam = function(v)
            cfg.voidspam = v == true
            if not v then vspam.phase = nil; vspam.shoot_ready_at = 0; clr_snap() end
        end,
        set_attempts = function(v) cfg.shoot_attempts = math.clamp(math.floor(tonumber(v) or 1), 1, 3) end,
        set_hit_part = function(v) cfg.hit_part = v or "Head" end,
        set_weapon_slot = function(v) cfg.weapon_slot = v or "primary"; refresh_atk(); eq_slot() end,
        set_atk_mode = function(v) cfg.atk_pos = v or "default"; refresh_atk() end,
        set_under_offset = function(v) cfg.under_offset = tonumber(v) or 4; refresh_atk() end,
        set_custom_height = function(v) cfg.custom_height = tonumber(v) or 2; refresh_atk() end,
        set_custom_front = function(v) cfg.custom_front = tonumber(v) or 0; refresh_atk() end,
        set_custom_side = function(v) cfg.custom_side = tonumber(v) or 0; refresh_atk() end,
        set_custom_vert = function(v) cfg.custom_vert = tonumber(v) or 0; refresh_atk() end,
        set_custom_radius = function(v) cfg.custom_radius = tonumber(v) or 0; refresh_atk() end,
        set_predict_mul = function(v) cfg.predict_mul = (tonumber(v) or 12) / 10 end,
        set_vs_shoot_ms = function(v) cfg.vs_shoot_ms = tonumber(v) or 500 end,
        set_vs_hide_ms = function(v) cfg.vs_hide_ms = tonumber(v) or 500 end,
        set_status_label = function(v)
            cfg.status_label = v == true
            if status_lbl then status_lbl.Visible = v == true end
        end,
        cleanup = function()
            cfg.master = false; cfg.enabled = false
            pcall(stop_sync)
            pcall(function() run_svc:UnbindFromRenderStep("ragebot_vfr_csync") end)
            for _, c in ipairs(rb_conns) do pcall(function() c:Disconnect() end) end
            rb_conns = {}
            pcall(function() if orbit.conn then orbit.conn:Disconnect(); orbit.conn = nil end end)
            pcall(function() if status_gui then status_gui:Destroy() end end)
            pcall(function() setfflag("TargetTimeDelayFacctorTenths", "1") end)
        end,
    }
end)()

shared.daydreamer_rivals_ragebot_cleanup = Ragebot.cleanup


-- ============================================================================
-- 4. DEVICE PROMPT & UI CONSTRUCTION
-- ============================================================================
local function AskForDeviceAndLoad()
    local pGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
    local gui = Instance.new("ScreenGui"); gui.Name = "DeviceSelector"; gui.ResetOnSpawn = false; gui.IgnoreGuiInset = true; gui.DisplayOrder = 999; gui.Parent = pGui

    local bg = Instance.new("Frame"); bg.Size = UDim2.new(0, 320, 0, 210); bg.Position = UDim2.new(0.5, -160, 0.5, -105); bg.BackgroundColor3 = Color3.fromRGB(15, 15, 18); bg.BorderSizePixel = 0; bg.Parent = gui
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 10)
    local stroke = Instance.new("UIStroke", bg); stroke.Color = Color3.fromRGB(40, 40, 45); stroke.Thickness = 1

    local title = Instance.new("TextLabel"); title.Size = UDim2.new(1, 0, 0, 50); title.BackgroundTransparency = 1; title.Text = "What device are you using?"; title.TextColor3 = Color3.fromRGB(230, 230, 235); title.Font = Enum.Font.GothamBold; title.TextSize = 16; title.Parent = bg

    local function makeBtn(text, yPos, scaleValue)
        local btn = Instance.new("TextButton"); btn.Size = UDim2.new(0, 280, 0, 38); btn.Position = UDim2.new(0, 20, 0, yPos); btn.BackgroundColor3 = Color3.fromRGB(30, 30, 36); btn.Text = text; btn.TextColor3 = Color3.fromRGB(200, 200, 205); btn.Font = Enum.Font.GothamMedium; btn.TextSize = 14; btn.Parent = bg
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
        btn.MouseEnter:Connect(function() btn.BackgroundColor3 = Color3.fromRGB(45, 45, 55) end)
        btn.MouseLeave:Connect(function() btn.BackgroundColor3 = Color3.fromRGB(30, 30, 36) end)
        btn.MouseButton1Click:Connect(function()
            gui:Destroy()

            UILibrary:Build({ Scale = scaleValue })

            local CombatTab = UILibrary:AddTab({ Name = "Combat", Icon = "target" })

            -- Silent Aim
            UILibrary:AddSubTab(CombatTab, { Name = "silent aim", Icon = "target", Build = function(sub)
                UILibrary:AddToggle(sub, { Name = "enabled", Default = false, Callback = function(v) CombatState.silent_aim.enabled = v end })
                UILibrary:AddSlider(sub, { Name = "fov", Min = 10, Max = 750, Default = 100, Callback = function(v) CombatState.silent_aim.fov = v end })
                UILibrary:AddToggle(sub, { Name = "draw fov", Default = false, Callback = function(v) CombatState.silent_aim.draw_fov = v end })
                UILibrary:AddColorPicker(sub, { Name = "fov color", Default = Color3.new(1,1,1), Callback = function(c) CombatState.silent_aim.fov_color = c end })
                UILibrary:AddSlider(sub, { Name = "hit chance", Min = 0, Max = 100, Default = 100, Callback = function(v) CombatState.silent_aim.hit_chance = v end })
                UILibrary:AddToggle(sub, { Name = "katana deflect check", Default = false, Callback = function(v) CombatState.silent_aim.katana_check = v end })
                UILibrary:AddToggle(sub, { Name = "visible check", Default = false, Callback = function(v) CombatState.silent_aim.visible_check = v end })
                UILibrary:AddToggle(sub, { Name = "manipulation", Default = true, Callback = function(v) CombatState.silent_aim.manipulation = v end })
                UILibrary:AddDropdown(sub, { Name = "hit part", Options = {"Head", "HumanoidRootPart", "Torso", "UpperTorso", "LowerTorso", "Random", "Closest"}, Default = "Head", Callback = function(v) CombatState.silent_aim.hit_part = v end })
                UILibrary:AddSlider(sub, { Name = "head hit chance", Min = 0, Max = 100, Default = 0, Callback = function(v) CombatState.silent_aim.head_hit_chance = v end })
            end })

            -- Aim Assist
            UILibrary:AddSubTab(CombatTab, { Name = "aim assist", Icon = "target", Build = function(sub)
                UILibrary:AddToggle(sub, { Name = "enabled", Default = false, Callback = function(v) CombatState.aim_assist.enabled = v end })
                UILibrary:AddSlider(sub, { Name = "fov", Min = 10, Max = 1000, Default = 500, Callback = function(v) CombatState.aim_assist.fov = v end })
                UILibrary:AddToggle(sub, { Name = "draw fov", Default = false, Callback = function(v) CombatState.aim_assist.draw_fov = v end })
                UILibrary:AddColorPicker(sub, { Name = "fov color", Default = Color3.new(1,1,1), Callback = function(c) CombatState.aim_assist.fov_color = c end })
                UILibrary:AddSlider(sub, { Name = "smoothness", Min = 1, Max = 100, Default = 20, Callback = function(v) CombatState.aim_assist.smoothness = v end })
                UILibrary:AddDropdown(sub, { Name = "aim method", Options = {"Linear", "Snap", "Expo", "EaseIn", "EaseOut", "EaseInOut", "Cubic"}, Default = "Linear", Callback = function(v) CombatState.aim_assist.aim_method = v end })
                UILibrary:AddDropdown(sub, { Name = "aim part", Options = {"Head", "HumanoidRootPart", "Torso", "UpperTorso", "LowerTorso", "Random", "Closest"}, Default = "Head", Callback = function(v) CombatState.aim_assist.aim_part = v end })
                UILibrary:AddToggle(sub, { Name = "visibility check", Default = false, Callback = function(v) CombatState.aim_assist.visible_check = v end })
                UILibrary:AddToggle(sub, { Name = "sticky target", Default = false, Callback = function(v) CombatState.aim_assist.sticky_target = v end })
                UILibrary:AddToggle(sub, { Name = "katana deflect check", Default = false, Callback = function(v) CombatState.aim_assist.katana_check = v end })
                UILibrary:AddSlider(sub, { Name = "reaction time", Min = 0, Max = 500, Default = 0, Callback = function(v) CombatState.aim_assist.reaction_time = v end })
                UILibrary:AddSlider(sub, { Name = "target switch delay", Min = 0, Max = 500, Default = 0, Callback = function(v) CombatState.aim_assist.target_switch_delay = v end })
                UILibrary:AddSlider(sub, { Name = "overshoot chance", Min = 0, Max = 100, Default = 0, Callback = function(v) CombatState.aim_assist.overshoot_chance = v end })
                UILibrary:AddSlider(sub, { Name = "overshoot distance", Min = 1, Max = 100, Default = 15, Callback = function(v) CombatState.aim_assist.overshoot_pixels = v end })
                UILibrary:AddToggle(sub, { Name = "prediction", Default = false, Callback = function(v) CombatState.aim_assist.prediction = v end })
                UILibrary:AddSlider(sub, { Name = "prediction strength x", Min = 0, Max = 100, Default = 50, Callback = function(v) CombatState.aim_assist.prediction_strength_x = v end })
                UILibrary:AddSlider(sub, { Name = "prediction strength y", Min = 0, Max = 100, Default = 50, Callback = function(v) CombatState.aim_assist.prediction_strength_y = v end })
                UILibrary:AddToggle(sub, { Name = "jitter", Default = false, Callback = function(v) CombatState.aim_assist.jitter = v end })
                UILibrary:AddSlider(sub, { Name = "jitter strength x", Min = 0, Max = 200, Default = 0, Callback = function(v) CombatState.aim_assist.jitter_strength_x = v end })
                UILibrary:AddSlider(sub, { Name = "jitter strength y", Min = 0, Max = 200, Default = 0, Callback = function(v) CombatState.aim_assist.jitter_strength_y = v end })
            end })

            -- Triggerbot
            UILibrary:AddSubTab(CombatTab, { Name = "triggerbot", Icon = "target", Build = function(sub)
                UILibrary:AddToggle(sub, { Name = "enabled", Default = false, Callback = function(v) CombatState.triggerbot.enabled = v end })
                UILibrary:AddSlider(sub, { Name = "reaction time", Min = 0, Max = 500, Default = 0, Callback = function(v) CombatState.triggerbot.reaction_time = v end })
                UILibrary:AddSlider(sub, { Name = "miss chance", Min = 0, Max = 100, Default = 0, Callback = function(v) CombatState.triggerbot.miss_chance = v end })
                UILibrary:AddToggle(sub, { Name = "katana deflect check", Default = false, Callback = function(v) CombatState.triggerbot.katana_check = v end })
                UILibrary:AddToggle(sub, { Name = "flashbang check", Default = true, Callback = function(v) CombatState.triggerbot.flashbang_check = v end })
                UILibrary:AddToggle(sub, { Name = "scope check", Default = true, Callback = function(v) CombatState.triggerbot.scope_check = v end })
            end })

            -- Tracers
            UILibrary:AddSubTab(CombatTab, { Name = "bullet tracers", Icon = "wave", Build = function(sub)
                UILibrary:AddToggle(sub, { Name = "enabled", Default = false, Callback = function(v) CombatState.bullet_tracers.enabled = v end })
                UILibrary:AddDropdown(sub, { Name = "line type", Options = {"Solid", "Dashed", "Lightning"}, Default = "Solid", Callback = function(v) CombatState.bullet_tracers.line_type = v end })
                UILibrary:AddSlider(sub, { Name = "duration", Min = 25, Max = 1500, Default = 250, Callback = function(v) CombatState.bullet_tracers.duration = v end })
                UILibrary:AddSlider(sub, { Name = "max distance", Min = 50, Max = 4000, Default = 2000, Callback = function(v) CombatState.bullet_tracers.max_distance = v end })
                UILibrary:AddSlider(sub, { Name = "thickness", Min = 1, Max = 8, Default = 2, Callback = function(v) CombatState.bullet_tracers.thickness = v end })
                UILibrary:AddSlider(sub, { Name = "transparency", Min = 0, Max = 100, Default = 10, Callback = function(v) CombatState.bullet_tracers.transparency = v end })
                UILibrary:AddToggle(sub, { Name = "local shots only", Default = true, Callback = function(v) CombatState.bullet_tracers.local_only = v end })
                UILibrary:AddSlider(sub, { Name = "lightning jaggedness", Min = 1, Max = 50, Default = 14, Callback = function(v) CombatState.bullet_tracers.lightning_jaggedness = v end })
                UILibrary:AddColorPicker(sub, { Name = "color", Default = Color3.new(1,1,1), Callback = function(c) CombatState.bullet_tracers.color = c end })
            end })

            -- Hit Sounds
            UILibrary:AddSubTab(CombatTab, { Name = "hit sounds", Icon = "bell", Build = function(sub)
                local files = combat_instance:list_hit_sound_files()
                UILibrary:AddToggle(sub, { Name = "enabled", Default = false, Callback = function(v) CombatState.hit_sounds.enabled = v end })
                UILibrary:AddLabel(sub, { Text = "Folder: " .. HIT_SOUND_DIR })
                UILibrary:AddDropdown(sub, { Name = "hit sound file", Options = files, Default = files[1] or "", Callback = function(v) CombatState.hit_sounds.hit_file = v end })
                UILibrary:AddDropdown(sub, { Name = "shot sound file", Options = files, Default = files[1] or "", Callback = function(v) CombatState.hit_sounds.shot_file = v end })
                UILibrary:AddDropdown(sub, { Name = "reload sound file", Options = files, Default = files[1] or "", Callback = function(v) CombatState.hit_sounds.reload_file = v end })
                UILibrary:AddDropdown(sub, { Name = "equip sound file", Options = files, Default = files[1] or "", Callback = function(v) CombatState.hit_sounds.equip_file = v end })
                UILibrary:AddSlider(sub, { Name = "volume", Min = 0, Max = 150, Default = 70, Callback = function(v) CombatState.hit_sounds.volume = v end })
                UILibrary:AddSlider(sub, { Name = "pitch", Min = 50, Max = 200, Default = 100, Callback = function(v) CombatState.hit_sounds.pitch = v end })
                UILibrary:AddButton(sub, { Name = "Refresh Sounds", Callback = function() UILibrary:BuildPage(sub) end })
            end })

            -- Ragebot
            UILibrary:AddSubTab(CombatTab, { Name = "ragebot", Icon = "target", Build = function(sub)
                local customSliders = {}
                local predictMulSlider
                local vsShootSlider, vsHideSlider

                UILibrary:AddToggle(sub, { Name = "ragebot", Default = false, Callback = function(v)
                    Ragebot.set_master(v)
                end })
                UILibrary:AddSlider(sub, { Name = "shoot attempts", Min = 1, Max = 3, Default = 1, Callback = function(v) Ragebot.set_attempts(v) end })
                UILibrary:AddDropdown(sub, { Name = "hit part", Options = {"Head","HumanoidRootPart","Torso","UpperTorso","Closest","Random"}, Default = "Head", Callback = function(v) Ragebot.set_hit_part(v) end })
                UILibrary:AddDropdown(sub, { Name = "weapon", Options = {"primary","secondary","melee"}, Default = "primary", Callback = function(v) Ragebot.set_weapon_slot(v) end })
                UILibrary:AddDropdown(sub, { Name = "attack pos", Options = {"default","under"}, Default = "default", Callback = function(v) Ragebot.set_atk_mode(v) end })
                UILibrary:AddSlider(sub, { Name = "under offset", Min = 1, Max = 25, Default = 4, Callback = function(v) Ragebot.set_under_offset(v) end })

                UILibrary:AddToggle(sub, { Name = "custom position override", Default = false, Callback = function(v)
                    Ragebot.set_custom_atk(v)
                    for _, s in ipairs(customSliders) do if s.Row then s.Row.Visible = v == true end end
                end })
                customSliders[1] = UILibrary:AddSlider(sub, { Name = "orbit height", Min = -25, Max = 30, Default = 2, Callback = function(v) Ragebot.set_custom_height(v) end })
                customSliders[2] = UILibrary:AddSlider(sub, { Name = "front offset", Min = -20, Max = 20, Default = 0, Callback = function(v) Ragebot.set_custom_front(v) end })
                customSliders[3] = UILibrary:AddSlider(sub, { Name = "side offset", Min = -20, Max = 20, Default = 0, Callback = function(v) Ragebot.set_custom_side(v) end })
                customSliders[4] = UILibrary:AddSlider(sub, { Name = "vertical offset (set to 20 against knife users)", Min = -25, Max = 30, Default = 0, Callback = function(v) Ragebot.set_custom_vert(v) end })
                customSliders[5] = UILibrary:AddSlider(sub, { Name = "orbit radius", Min = 0, Max = 25, Default = 0, Callback = function(v) Ragebot.set_custom_radius(v) end })
                for _, s in ipairs(customSliders) do if s.Row then s.Row.Visible = false end end

                UILibrary:AddToggle(sub, { Name = "prediction", Default = false, Callback = function(v)
                    Ragebot.set_predict(v)
                    if predictMulSlider and predictMulSlider.Row then predictMulSlider.Row.Visible = v == true end
                end })
                predictMulSlider = UILibrary:AddSlider(sub, { Name = "predict mult", Min = 1, Max = 30, Default = 12, Callback = function(v) Ragebot.set_predict_mul(v) end })
                if predictMulSlider.Row then predictMulSlider.Row.Visible = false end

                UILibrary:AddToggle(sub, { Name = "voidspam", Default = false, Callback = function(v)
                    Ragebot.set_voidspam(v)
                    if vsShootSlider and vsShootSlider.Row then vsShootSlider.Row.Visible = v == true end
                    if vsHideSlider and vsHideSlider.Row then vsHideSlider.Row.Visible = v == true end
                end })
                vsShootSlider = UILibrary:AddSlider(sub, { Name = "attack time", Min = 0, Max = 1000, Default = 500, Suffix = "ms", Callback = function(v) Ragebot.set_vs_shoot_ms(v) end })
                vsHideSlider = UILibrary:AddSlider(sub, { Name = "hide time", Min = 0, Max = 1000, Default = 500, Suffix = "ms", Callback = function(v) Ragebot.set_vs_hide_ms(v) end })
                if vsShootSlider.Row then vsShootSlider.Row.Visible = false end
                if vsHideSlider.Row then vsHideSlider.Row.Visible = false end

                UILibrary:AddToggle(sub, { Name = "status label", Default = false, Callback = function(v) Ragebot.set_status_label(v) end })
            end })

            -- ==========================================================
            -- SETTINGS TAB
            -- ==========================================================
            local SettingsTab = UILibrary:AddTab({ Name = "Settings", Icon = "gear" })

            UILibrary:AddSubTab(SettingsTab, { Name = "theme", Icon = "palette", Build = function(sub)
                local themeKeys = {
                    "PanelBg", "SidebarBg", "SubBarBg", "SearchBg", "InputBg",
                    "ActiveBg", "HoverBg", "TrackOff", "KnobOff", "Border",
                    "Active", "Text", "TextDim", "TextMuted", "Gold", "Green", "Red"
                }
                for _, key in ipairs(themeKeys) do
                    UILibrary:AddColorPicker(sub, {
                        Name = key,
                        Default = UILibrary.Theme[key],
                        Callback = function(c)
                            UILibrary.Theme[key] = c
                            UILibrary:ApplyTheme()
                        end
                    })
                end
                UILibrary:AddButton(sub, {
                    Name = "Reset theme to default",
                    Callback = function()
                        for k, v in pairs(UILibrary.DefaultTheme) do UILibrary.Theme[k] = v end
                        UILibrary:ApplyTheme()
                        UILibrary:BuildPage(sub)
                    end
                })
            end })

            UILibrary:AddSubTab(SettingsTab, { Name = "unload", Icon = "wrench", Build = function(sub)
                UILibrary:AddLabel(sub, { Text = "Unload removes the UI and restores all" })
                UILibrary:AddLabel(sub, { Text = "hooked game functions to their originals." })

                UILibrary:AddButton(sub, {
                    Name = "Hide UI (toggle)",
                    Callback = function() UILibrary:ToggleUI() end
                })
                UILibrary:AddButton(sub, {
                    Name = "Test notification",
                    Callback = function() UILibrary:Notify("Script is active", 2) end
                })
                UILibrary:AddButton(sub, {
                    Name = "Unload script",
                    Callback = function()
                        pcall(function() Ragebot.cleanup() end)
                        pcall(function() combat_instance:Unload() end)
                        pcall(function() UILibrary:Destroy() end)
                        local pg = game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
                        if pg then
                            for _, g in ipairs(pg:GetChildren()) do
                                if g.Name == "DeviceSelector" then g:Destroy() end
                            end
                        end
                    end
                })
                UILibrary:AddButton(sub, {
                    Name = "Rejoin game",
                    Callback = function()
                        pcall(function() Ragebot.cleanup() end)
                        pcall(function() combat_instance:Unload() end)
                        pcall(function() UILibrary:Destroy() end)
                        pcall(function()
                            game:GetService("TeleportService"):Teleport(game.PlaceId, game:GetService("Players").LocalPlayer)
                        end)
                    end
                })
                UILibrary:AddLabel(sub, { Text = "Tip: use Rejoin if anything glitches." })
            end })

        end)
    end

    makeBtn("PC (100% size)", 60, 1.0)
    makeBtn("Tablet (85% size)", 108, 0.85)
    makeBtn("Phone (65% size)", 156, 0.65)
end

AskForDeviceAndLoad()