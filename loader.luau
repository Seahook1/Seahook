--!strict
-- KiclaHook V2 | Rivals
-- CheatMenu.luau
-- Runtime: Roblox Luau (typed, strict mode)
-- Mobile: Touch drag, touch sliders, FloatingToggleButton, isMobile detection

local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local GuiService       = game:GetService("GuiService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

-- ─────────────────────────────────────────────
-- Mobile detection
-- ─────────────────────────────────────────────

local isMobile: boolean = UserInputService.TouchEnabled
	and not UserInputService.KeyboardEnabled

-- ─────────────────────────────────────────────
-- Types
-- ─────────────────────────────────────────────

type Tab         = "Combat" | "Visuals" | "Misc" | "Settings"
type CombatSubTab = "Legitbot" | "Silent Aim" | "Triggerbot" | "Rage"

type LegitbotState = {
	Enabled:        boolean,
	EnableMode:     string,
	Speed:          number,   -- 1–5
	SpeedInAttack:  number,   -- stored ×10  (15 = 1.5)
	SpeedScaleFOV:  number,   -- 0–100
	MaxLockOnTime:  number,   -- 0–10
	ReactionTimeMs: number,   -- 0–500
	TeamCheck:      boolean,
	VisibleCheck:   boolean,
	TargetHitparts: string,
	MaxFOV:         number,   -- 0–600
	DrawFOV:        boolean,
	DynamicFOV:     boolean,
}

type MenuState = {
	Visible:      boolean,
	ActiveTab:    Tab,
	ActiveSubTab: CombatSubTab,
	Legitbot:     LegitbotState,
	IsDragging:   boolean,
}

-- ─────────────────────────────────────────────
-- Default state
-- ─────────────────────────────────────────────

local State: MenuState = {
	Visible      = true,
	ActiveTab    = "Combat",
	ActiveSubTab = "Legitbot",
	Legitbot = {
		Enabled        = false,
		EnableMode     = "Always: None",
		Speed          = 1,
		SpeedInAttack  = 15,
		SpeedScaleFOV  = 70,
		MaxLockOnTime  = 3,
		ReactionTimeMs = 100,
		TeamCheck      = true,
		VisibleCheck   = false,
		TargetHitparts = "Head, Body",
		MaxFOV         = 120,
		DrawFOV        = false,
		DynamicFOV     = false,
	},
	IsDragging = false,
}

-- ─────────────────────────────────────────────
-- Colour palette
-- ─────────────────────────────────────────────

local C = {
	BG             = Color3.fromRGB(30,  34,  40),
	TitleBar       = Color3.fromRGB(22,  25,  30),
	TabBar         = Color3.fromRGB(26,  29,  35),
	SubTabBar      = Color3.fromRGB(28,  31,  37),
	TabActive      = Color3.fromRGB(38,  82, 156),
	TabHover       = Color3.fromRGB(40,  44,  52),
	Divider        = Color3.fromRGB(50,  54,  62),
	TextPrimary    = Color3.fromRGB(220, 220, 220),
	TextMuted      = Color3.fromRGB(140, 140, 148),
	TextLabel      = Color3.fromRGB(180, 184, 192),
	SliderFill     = Color3.fromRGB(38,  82, 156),
	SliderTrack    = Color3.fromRGB(50,  54,  62),
	CheckOn        = Color3.fromRGB(38,  82, 156),
	CheckOff       = Color3.fromRGB(50,  54,  62),
	DropdownBG     = Color3.fromRGB(36,  40,  48),
	DropdownBorder = Color3.fromRGB(60,  64,  72),
	ToggleBtn      = Color3.fromRGB(38,  82, 156),
	White          = Color3.fromRGB(255, 255, 255),
}

-- ─────────────────────────────────────────────
-- Dimensions  (mobile scales up)
-- ─────────────────────────────────────────────

local SCALE = if isMobile then 1.35 else 1.0

local function s(n: number): number
	return math.round(n * SCALE)
end

local DIM = {
	WindowW    = s(520),
	WindowH    = s(370),
	TitleH     = s(28),
	TabH       = s(30),
	SubTabH    = s(26),
	PanelL     = s(260),
	FontSize   = s(13),
	FontSizeSm = s(11),
	-- touch tap target minimum (44 px recommended by Apple/Google HIG)
	TapTarget  = if isMobile then 44 else 18,
	SliderH    = if isMobile then 8  else 4,
	ThumbR     = if isMobile then 10 else 0,  -- thumb radius on mobile slider
	CheckSize  = if isMobile then 20 else 12,
	RowH       = if isMobile then 44 else 32,
	CheckRowH  = if isMobile then 44 else 18,
}

DIM.ContentH = DIM.WindowH - DIM.TitleH - DIM.TabH - DIM.SubTabH

-- ─────────────────────────────────────────────
-- GUI root
-- ─────────────────────────────────────────────

local ScreenGui              = Instance.new("ScreenGui")
ScreenGui.Name               = "KiclaHookV2"
ScreenGui.ResetOnSpawn       = false
ScreenGui.IgnoreGuiInset     = true
ScreenGui.ZIndexBehavior     = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent             = PlayerGui

-- ─────────────────────────────────────────────
-- Utility helpers
-- ─────────────────────────────────────────────

local function new(class: string, props: {[string]: any}, parent: Instance?): Instance
	local inst = Instance.new(class)
	for k, v in props do
		(inst :: any)[k] = v
	end
	if parent then inst.Parent = parent end
	return inst
end

local function label(
	text:   string,
	size:   number,
	color:  Color3,
	parent: Instance,
	pos:    UDim2,
	anchor: Vector2?
): TextLabel
	return new("TextLabel", {
		Text                   = text,
		TextSize               = size,
		TextColor3             = color,
		BackgroundTransparency = 1,
		Font                   = Enum.Font.Gotham,
		Position               = pos,
		AnchorPoint            = anchor or Vector2.zero,
		Size                   = UDim2.new(1, 0, 0, size + 4),
		TextXAlignment         = Enum.TextXAlignment.Left,
	}, parent) :: TextLabel
end

local function sectionLabel(text: string, parent: Instance, yOffset: number)
	label(text, DIM.FontSizeSm, C.TextMuted, parent, UDim2.fromOffset(8, yOffset))
end

-- ─────────────────────────────────────────────
-- Unified input: fires callback on Mouse1 OR Touch
-- ─────────────────────────────────────────────

local function onTap(btn: GuiButton, cb: () -> ())
	-- MouseButton1Click works for both mouse and touch in Roblox
	btn.MouseButton1Click:Connect(cb)
end

-- ─────────────────────────────────────────────
-- Window frame
-- ─────────────────────────────────────────────

-- centre on screen; on mobile the window fills more of the display
local vpSize   = workspace.CurrentCamera.ViewportSize
local startX   = math.round((vpSize.X - DIM.WindowW) / 2)
local startY   = math.round((vpSize.Y - DIM.WindowH) / 2)

local Window: Frame = new("Frame", {
	Name             = "Window",
	Size             = UDim2.fromOffset(DIM.WindowW, DIM.WindowH),
	Position         = UDim2.fromOffset(startX, startY),
	BackgroundColor3 = C.BG,
	BorderSizePixel  = 0,
	ClipsDescendants = true,
}, ScreenGui) :: Frame

new("UIStroke", { Color = C.Divider, Thickness = 1 }, Window)

-- ─────────────────────────────────────────────
-- Title bar + drag (Mouse AND Touch)
-- ─────────────────────────────────────────────

local TitleBar: Frame = new("Frame", {
	Name             = "TitleBar",
	Size             = UDim2.new(1, 0, 0, DIM.TitleH),
	Position         = UDim2.fromOffset(0, 0),
	BackgroundColor3 = C.TitleBar,
	BorderSizePixel  = 0,
}, Window) :: Frame

label("KiclaHook V2  |  Rivals", DIM.FontSize, C.TextPrimary, TitleBar,
	UDim2.fromOffset(8, 5))

-- drag state
local dragStart:  Vector2? = nil
local dragOrigin: Vector2? = nil

local function beginDrag(pos: Vector3)
	State.IsDragging = true
	dragStart  = Vector2.new(pos.X, pos.Y)
	dragOrigin = Vector2.new(Window.Position.X.Offset, Window.Position.Y.Offset)
end

local function endDrag()
	State.IsDragging = false
end

local function moveDrag(pos: Vector3)
	if not State.IsDragging or not dragStart or not dragOrigin then return end
	local delta = Vector2.new(pos.X, pos.Y) - dragStart
	-- clamp to viewport so the window can't be flung off screen
	local vp  = workspace.CurrentCamera.ViewportSize
	local newX = math.clamp(dragOrigin.X + delta.X, 0, vp.X - DIM.WindowW)
	local newY = math.clamp(dragOrigin.Y + delta.Y, 0, vp.Y - DIM.WindowH)
	Window.Position = UDim2.fromOffset(newX, newY)
end

TitleBar.InputBegan:Connect(function(input: InputObject)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		beginDrag(input.Position)
	end
end)

TitleBar.InputEnded:Connect(function(input: InputObject)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		endDrag()
	end
end)

UserInputService.InputChanged:Connect(function(input: InputObject)
	if not State.IsDragging then return end
	if input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch then
		moveDrag(input.Position)
	end
end)

-- ─────────────────────────────────────────────
-- Primary tab bar
-- ─────────────────────────────────────────────

local PrimaryTabs: {Tab} = {"Combat", "Visuals", "Misc", "Settings"}

local TabBarFrame: Frame = new("Frame", {
	Size             = UDim2.new(1, 0, 0, DIM.TabH),
	Position         = UDim2.fromOffset(0, DIM.TitleH),
	BackgroundColor3 = C.TabBar,
	BorderSizePixel  = 0,
}, Window) :: Frame

new("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	SortOrder     = Enum.SortOrder.LayoutOrder,
}, TabBarFrame)

local tabButtons: {[Tab]: TextButton} = {}

local function updateTabVisuals()
	for tab, btn in tabButtons do
		btn.BackgroundColor3 = if tab == State.ActiveTab then C.TabActive else C.TabBar
		btn.TextColor3       = if tab == State.ActiveTab then C.White     else C.TextMuted
	end
end

for i, tabName in PrimaryTabs do
	local btn = new("TextButton", {
		Text             = tabName,
		TextSize         = DIM.FontSize,
		Font             = Enum.Font.Gotham,
		TextColor3       = C.TextMuted,
		BackgroundColor3 = C.TabBar,
		BorderSizePixel  = 0,
		Size             = UDim2.new(0.25, 0, 1, 0),
		LayoutOrder      = i,
		AutoButtonColor  = false,
	}, TabBarFrame) :: TextButton

	tabButtons[tabName] = btn
	onTap(btn, function()
		State.ActiveTab = tabName
		updateTabVisuals()
	end)
end

updateTabVisuals()

-- ─────────────────────────────────────────────
-- Sub-tab bar
-- ─────────────────────────────────────────────

local SubTabs: {CombatSubTab} = {"Legitbot", "Silent Aim", "Triggerbot", "Rage"}

local SubTabBarFrame: Frame = new("Frame", {
	Size             = UDim2.new(1, 0, 0, DIM.SubTabH),
	Position         = UDim2.fromOffset(0, DIM.TitleH + DIM.TabH),
	BackgroundColor3 = C.SubTabBar,
	BorderSizePixel  = 0,
}, Window) :: Frame

new("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	SortOrder     = Enum.SortOrder.LayoutOrder,
}, SubTabBarFrame)

local subTabButtons: {[CombatSubTab]: TextButton} = {}

local function updateSubTabVisuals()
	for tab, btn in subTabButtons do
		btn.TextColor3 = if tab == State.ActiveSubTab then C.TextPrimary else C.TextMuted
		local ul = btn:FindFirstChild("Underline") :: Frame?
		if ul then
			ul.BackgroundTransparency =
				if tab == State.ActiveSubTab then 0 else 1
		end
	end
end

for i, tabName in SubTabs do
	local btn = new("TextButton", {
		Text             = tabName,
		TextSize         = DIM.FontSizeSm,
		Font             = Enum.Font.Gotham,
		TextColor3       = C.TextMuted,
		BackgroundColor3 = C.SubTabBar,
		BorderSizePixel  = 0,
		Size             = UDim2.new(0.25, 0, 1, 0),
		LayoutOrder      = i,
		AutoButtonColor  = false,
	}, SubTabBarFrame) :: TextButton

	new("Frame", {
		Name                   = "Underline",
		Size                   = UDim2.new(1, 0, 0, 2),
		Position               = UDim2.new(0, 0, 1, -2),
		BackgroundColor3       = C.TabActive,
		BackgroundTransparency = 1,
		BorderSizePixel        = 0,
	}, btn)

	subTabButtons[tabName] = btn
	onTap(btn, function()
		State.ActiveSubTab = tabName
		updateSubTabVisuals()
	end)
end

updateSubTabVisuals()

-- ─────────────────────────────────────────────
-- Content area
-- ─────────────────────────────────────────────

local ContentY = DIM.TitleH + DIM.TabH + DIM.SubTabH

local ContentArea: Frame = new("Frame", {
	Size             = UDim2.new(1, 0, 0, DIM.ContentH),
	Position         = UDim2.fromOffset(0, ContentY),
	BackgroundColor3 = C.BG,
	BorderSizePixel  = 0,
	ClipsDescendants = true,
}, Window) :: Frame

-- vertical divider
new("Frame", {
	Size             = UDim2.new(0, 1, 1, 0),
	Position         = UDim2.fromOffset(DIM.PanelL, 0),
	BackgroundColor3 = C.Divider,
	BorderSizePixel  = 0,
}, ContentArea)

-- ─────────────────────────────────────────────
-- Widget: slider row
-- Supports mouse drag AND touch drag on the track.
-- On mobile the track is taller, thumb is visible.
-- ─────────────────────────────────────────────

local function sliderRow(
	labelText:  string,
	valueNum:   number,
	maxNum:     number,
	displayFmt: (v: number) -> string,
	parent:     Instance,
	yOffset:    number,
	onChanged:  (v: number) -> ()
): (Frame, TextLabel)

	local row: Frame = new("Frame", {
		Size                   = UDim2.new(1, 0, 0, DIM.RowH),
		Position               = UDim2.fromOffset(0, yOffset),
		BackgroundTransparency = 1,
		BorderSizePixel        = 0,
	}, parent) :: Frame

	label(labelText, DIM.FontSizeSm, C.TextLabel, row, UDim2.fromOffset(8, 2))

	local valLbl: TextLabel = new("TextLabel", {
		Text                   = displayFmt(valueNum),
		TextSize               = DIM.FontSizeSm,
		TextColor3             = C.TextPrimary,
		BackgroundTransparency = 1,
		Font                   = Enum.Font.Gotham,
		Position               = UDim2.new(1, -8, 0, 2),
		AnchorPoint            = Vector2.new(1, 0),
		Size                   = UDim2.new(0.45, 0, 0, 16),
		TextXAlignment         = Enum.TextXAlignment.Right,
	}, row) :: TextLabel

	-- track
	local trackY = if isMobile then 22 else 20
	local track: Frame = new("Frame", {
		Size             = UDim2.new(1, -16, 0, DIM.SliderH),
		Position         = UDim2.fromOffset(8, trackY),
		BackgroundColor3 = C.SliderTrack,
		BorderSizePixel  = 0,
	}, row) :: Frame
	new("UICorner", { CornerRadius = UDim.new(0, DIM.SliderH) }, track)

	local pct  = math.clamp(valueNum / maxNum, 0, 1)
	local fill: Frame = new("Frame", {
		Size             = UDim2.new(pct, 0, 1, 0),
		BackgroundColor3 = C.SliderFill,
		BorderSizePixel  = 0,
	}, track) :: Frame
	new("UICorner", { CornerRadius = UDim.new(0, DIM.SliderH) }, fill)

	-- thumb (mobile only — visible drag handle)
	local thumb: Frame? = nil
	if isMobile then
		thumb = new("Frame", {
			Name             = "Thumb",
			Size             = UDim2.fromOffset(DIM.ThumbR * 2, DIM.ThumbR * 2),
			AnchorPoint      = Vector2.new(0.5, 0.5),
			Position         = UDim2.new(pct, 0, 0.5, 0),
			BackgroundColor3 = C.White,
			BorderSizePixel  = 0,
			ZIndex           = 3,
		}, track) :: Frame
		new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, thumb)
	end

	-- drag hitbox — tall enough for fingers
	local hitH = if isMobile then 44 else 14
	local drag: TextButton = new("TextButton", {
		Text                   = "",
		Size                   = UDim2.new(1, 0, 0, hitH),
		Position               = UDim2.new(0, 0, 0.5, -hitH / 2),
		BackgroundTransparency = 1,
		BorderSizePixel        = 0,
		ZIndex                 = 5,
	}, track) :: TextButton

	local dragging = false

	local function applyPos(screenX: number)
		local abs  = track.AbsolutePosition
		local size = track.AbsoluteSize
		local rel  = math.clamp((screenX - abs.X) / size.X, 0, 1)
		local val  = math.round(rel * maxNum)
		fill.Size  = UDim2.new(rel, 0, 1, 0)
		if thumb then
			thumb.Position = UDim2.new(rel, 0, 0.5, 0)
		end
		valLbl.Text = displayFmt(val)
		onChanged(val)
	end

	drag.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			applyPos(input.Position.X)
		end
	end)

	UserInputService.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	UserInputService.InputChanged:Connect(function(input: InputObject)
		if not dragging then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch then
			applyPos(input.Position.X)
		end
	end)

	return row, valLbl
end

-- ─────────────────────────────────────────────
-- Widget: checkbox row
-- Mobile: larger box + full-row tap target
-- ─────────────────────────────────────────────

local function checkRow(
	labelText: string,
	checked:   boolean,
	parent:    Instance,
	yOffset:   number,
	onToggle:  (v: boolean) -> ()
): Frame

	local row: Frame = new("Frame", {
		Size                   = UDim2.new(1, 0, 0, DIM.CheckRowH),
		Position               = UDim2.fromOffset(0, yOffset),
		BackgroundTransparency = 1,
		BorderSizePixel        = 0,
	}, parent) :: Frame

	local checkY = math.round((DIM.CheckRowH - DIM.CheckSize) / 2)
	local box: Frame = new("Frame", {
		Size             = UDim2.fromOffset(DIM.CheckSize, DIM.CheckSize),
		Position         = UDim2.fromOffset(8, checkY),
		BackgroundColor3 = if checked then C.CheckOn else C.CheckOff,
		BorderSizePixel  = 0,
	}, row) :: Frame
	new("UICorner", { CornerRadius = UDim.new(0, 3) }, box)

	label(labelText, DIM.FontSizeSm, C.TextLabel, row,
		UDim2.fromOffset(8 + DIM.CheckSize + 8, checkY - 1))

	local state = checked
	local btn: TextButton = new("TextButton", {
		Text                   = "",
		Size                   = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel        = 0,
		ZIndex                 = 4,
	}, row) :: TextButton

	onTap(btn, function()
		state = not state
		box.BackgroundColor3 = if state then C.CheckOn else C.CheckOff
		onToggle(state)
	end)

	return row
end

-- ─────────────────────────────────────────────
-- Widget: dropdown row
-- ─────────────────────────────────────────────

local function dropdownRow(
	valueText: string,
	options:   {string},
	parent:    Instance,
	yOffset:   number,
	onSelect:  (v: string) -> ()
): Frame

	local DROP_H = if isMobile then 32 else 22

	local row: Frame = new("Frame", {
		Size             = UDim2.new(1, -16, 0, DROP_H),
		Position         = UDim2.fromOffset(8, yOffset),
		BackgroundColor3 = C.DropdownBG,
		BorderSizePixel  = 1,
		BorderColor3     = C.DropdownBorder,
	}, parent) :: Frame
	new("UICorner", { CornerRadius = UDim.new(0, 3) }, row)

	local valLbl: TextLabel = new("TextLabel", {
		Text                   = valueText,
		TextSize               = DIM.FontSizeSm,
		TextColor3             = C.TextPrimary,
		BackgroundTransparency = 1,
		Font                   = Enum.Font.Gotham,
		Position               = UDim2.fromOffset(6, 0),
		Size                   = UDim2.new(1, -22, 1, 0),
		TextXAlignment         = Enum.TextXAlignment.Left,
	}, row) :: TextLabel

	new("TextLabel", {
		Text                   = "▾",
		TextSize               = 12,
		TextColor3             = C.TextMuted,
		BackgroundTransparency = 1,
		Font                   = Enum.Font.Gotham,
		Position               = UDim2.new(1, -16, 0, 0),
		Size                   = UDim2.fromOffset(14, DROP_H),
		TextXAlignment         = Enum.TextXAlignment.Center,
	}, row)

	new("TextLabel", {
		Text                   = "+",
		TextSize               = 12,
		TextColor3             = C.TextMuted,
		BackgroundTransparency = 1,
		Font                   = Enum.Font.Gotham,
		Position               = UDim2.new(1, -4, 0.5, -6),
		Size                   = UDim2.fromOffset(10, 12),
		TextXAlignment         = Enum.TextXAlignment.Right,
	}, row)

	local open   = false
	local listFr: Frame? = nil

	local btn: TextButton = new("TextButton", {
		Text                   = "",
		Size                   = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel        = 0,
		ZIndex                 = 6,
	}, row) :: TextButton

	onTap(btn, function()
		open = not open
		if listFr then
			listFr:Destroy()
			listFr = nil
		end
		if open then
			local itemH = if isMobile then 36 else 20
			local list: Frame = new("Frame", {
				Size             = UDim2.new(1, 0, 0, #options * itemH),
				Position         = UDim2.new(0, 0, 1, 2),
				BackgroundColor3 = C.DropdownBG,
				BorderSizePixel  = 1,
				BorderColor3     = C.DropdownBorder,
				ZIndex           = 10,
				ClipsDescendants = true,
			}, row) :: Frame
			new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, list)
			listFr = list

			for idx, opt in options do
				local item: TextButton = new("TextButton", {
					Text             = opt,
					TextSize         = DIM.FontSizeSm,
					Font             = Enum.Font.Gotham,
					TextColor3       = C.TextPrimary,
					BackgroundColor3 = C.DropdownBG,
					BorderSizePixel  = 0,
					Size             = UDim2.new(1, 0, 0, itemH),
					LayoutOrder      = idx,
					TextXAlignment   = Enum.TextXAlignment.Left,
					AutoButtonColor  = false,
				}, list) :: TextButton

				new("UIPadding", { PaddingLeft = UDim.new(0, 6) }, item)

				onTap(item, function()
					valLbl.Text = opt
					onSelect(opt)
					open = false
					list:Destroy()
					listFr = nil
				end)
			end
		end
	end)

	return row
end

-- ─────────────────────────────────────────────
-- Left panel: Main Settings
-- ─────────────────────────────────────────────

local LeftPanel: Frame = new("Frame", {
	Name                   = "LeftPanel",
	Size                   = UDim2.fromOffset(DIM.PanelL, DIM.ContentH),
	Position               = UDim2.fromOffset(0, 0),
	BackgroundTransparency = 1,
	BorderSizePixel        = 0,
	ClipsDescendants       = true,
}, ContentArea) :: Frame

sectionLabel("Main Settings", LeftPanel, 6)

-- Enabled row
local enabledRow: Frame = new("Frame", {
	Size                   = UDim2.new(1, 0, 0, DIM.CheckRowH),
	Position               = UDim2.fromOffset(0, 20),
	BackgroundTransparency = 1,
}, LeftPanel) :: Frame

local checkY0 = math.round((DIM.CheckRowH - DIM.CheckSize) / 2)
local enableBox: Frame = new("Frame", {
	Size             = UDim2.fromOffset(DIM.CheckSize, DIM.CheckSize),
	Position         = UDim2.fromOffset(8, checkY0),
	BackgroundColor3 = if State.Legitbot.Enabled then C.CheckOn else C.CheckOff,
	BorderSizePixel  = 0,
}, enabledRow) :: Frame
new("UICorner", { CornerRadius = UDim.new(0, 3) }, enableBox)

label("Enabled", DIM.FontSizeSm, C.TextLabel, enabledRow,
	UDim2.fromOffset(8 + DIM.CheckSize + 8, checkY0 - 1))

new("TextLabel", {
	Text                   = State.Legitbot.EnableMode,
	TextSize               = DIM.FontSizeSm,
	TextColor3             = C.TextMuted,
	BackgroundTransparency = 1,
	Font                   = Enum.Font.Gotham,
	Position               = UDim2.new(1, -8, 0, checkY0 - 1),
	AnchorPoint            = Vector2.new(1, 0),
	Size                   = UDim2.new(0.5, 0, 0, 16),
	TextXAlignment         = Enum.TextXAlignment.Right,
}, enabledRow)

local enableBtn: TextButton = new("TextButton", {
	Text                   = "",
	Size                   = UDim2.new(1, 0, 1, 0),
	BackgroundTransparency = 1,
	BorderSizePixel        = 0,
	ZIndex                 = 4,
}, enabledRow) :: TextButton

onTap(enableBtn, function()
	State.Legitbot.Enabled = not State.Legitbot.Enabled
	enableBox.BackgroundColor3 = if State.Legitbot.Enabled then C.CheckOn else C.CheckOff
end)

-- row y cursor advances by RowH or CheckRowH
local lY = 20 + DIM.CheckRowH + 2

sliderRow("Speed", State.Legitbot.Speed, 5,
	function(v) return tostring(v).."/5" end,
	LeftPanel, lY, function(v) State.Legitbot.Speed = v end)
lY += DIM.RowH + 2

sliderRow("Speed (in attack)", State.Legitbot.SpeedInAttack, 50,
	function(v) return string.format("%.1f", v/10).."/5" end,
	LeftPanel, lY, function(v) State.Legitbot.SpeedInAttack = v end)
lY += DIM.RowH + 2

sliderRow("Speed scale - FOV", State.Legitbot.SpeedScaleFOV, 100,
	function(v) return tostring(v).."/100" end,
	LeftPanel, lY, function(v) State.Legitbot.SpeedScaleFOV = v end)
lY += DIM.RowH + 2

sliderRow("Maximum lock-on time", State.Legitbot.MaxLockOnTime, 10,
	function(v) return tostring(v).."/10" end,
	LeftPanel, lY, function(v) State.Legitbot.MaxLockOnTime = v end)
lY += DIM.RowH + 2

sliderRow("Reaction time (ms)", State.Legitbot.ReactionTimeMs, 500,
	function(v) return tostring(v).."/500" end,
	LeftPanel, lY, function(v) State.Legitbot.ReactionTimeMs = v end)
lY += DIM.RowH + 2

checkRow("Team Check",    State.Legitbot.TeamCheck,    LeftPanel, lY,
	function(v) State.Legitbot.TeamCheck = v end)
lY += DIM.CheckRowH + 2

checkRow("Visible Check", State.Legitbot.VisibleCheck, LeftPanel, lY,
	function(v) State.Legitbot.VisibleCheck = v end)
lY += DIM.CheckRowH + 2

sectionLabel("Targeting Hitparts", LeftPanel, lY)
lY += 16

dropdownRow(State.Legitbot.TargetHitparts,
	{"Head, Body", "Head", "Body"},
	LeftPanel, lY,
	function(v) State.Legitbot.TargetHitparts = v end)

-- ─────────────────────────────────────────────
-- Right panel: FOV Settings
-- ─────────────────────────────────────────────

local RightPanel: Frame = new("Frame", {
	Name                   = "RightPanel",
	Size                   = UDim2.fromOffset(DIM.WindowW - DIM.PanelL - 1, DIM.ContentH),
	Position               = UDim2.fromOffset(DIM.PanelL + 1, 0),
	BackgroundTransparency = 1,
	BorderSizePixel        = 0,
	ClipsDescendants       = true,
}, ContentArea) :: Frame

sectionLabel("FOV Settings", RightPanel, 6)

local rY = 20
sliderRow("Maximum FOV", State.Legitbot.MaxFOV, 600,
	function(v) return tostring(v).."/600" end,
	RightPanel, rY, function(v) State.Legitbot.MaxFOV = v end)
rY += DIM.RowH + 2

checkRow("Draw FOV",    State.Legitbot.DrawFOV,    RightPanel, rY,
	function(v) State.Legitbot.DrawFOV = v end)
rY += DIM.CheckRowH + 2

checkRow("Dynamic FOV", State.Legitbot.DynamicFOV, RightPanel, rY,
	function(v) State.Legitbot.DynamicFOV = v end)

-- ─────────────────────────────────────────────
-- Toggle visibility
-- Desktop  → INSERT key
-- Mobile   → floating ☰ button (bottom-right, above thumb zone)
-- ─────────────────────────────────────────────

-- keyboard (desktop)
UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.Insert then
		State.Visible  = not State.Visible
		Window.Visible = State.Visible
	end
end)

-- floating toggle button (mobile)
if isMobile then
	local TOGGLE_SIZE = 48

	local toggleBtn: TextButton = new("TextButton", {
		Text             = "☰",
		TextSize         = 22,
		Font             = Enum.Font.Gotham,
		TextColor3       = C.White,
		BackgroundColor3 = C.ToggleBtn,
		BorderSizePixel  = 0,
		Size             = UDim2.fromOffset(TOGGLE_SIZE, TOGGLE_SIZE),
		-- bottom-right, 16 px from edge, 80 px above bottom (above on-screen keyboard / thumb zone)
		Position         = UDim2.new(1, -(TOGGLE_SIZE + 16), 1, -(TOGGLE_SIZE + 80)),
		ZIndex           = 20,
	}, ScreenGui) :: TextButton
	new("UICorner", { CornerRadius = UDim.new(0, 12) }, toggleBtn)

	onTap(toggleBtn, function()
		State.Visible  = not State.Visible
		Window.Visible = State.Visible
		toggleBtn.TextColor3 = if State.Visible then C.White else C.TextMuted
	end)

	-- drag the toggle button itself so the player can reposition it
	local togDragging  = false
	local togDragStart: Vector2? = nil
	local togOrigin:    Vector2? = nil

	toggleBtn.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.Touch then
			togDragging  = true
			togDragStart = Vector2.new(input.Position.X, input.Position.Y)
			togOrigin    = Vector2.new(
				toggleBtn.Position.X.Offset,
				toggleBtn.Position.Y.Offset
			)
		end
	end)

	toggleBtn.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.Touch then
			togDragging = false
		end
	end)

	UserInputService.InputChanged:Connect(function(input: InputObject)
		if not togDragging or not togDragStart or not togOrigin then return end
		if input.UserInputType == Enum.UserInputType.Touch then
			local vp    = workspace.CurrentCamera.ViewportSize
			local delta = Vector2.new(input.Position.X, input.Position.Y) - togDragStart
			local newX  = math.clamp(togOrigin.X + delta.X, 0, vp.X - TOGGLE_SIZE)
			local newY  = math.clamp(togOrigin.Y + delta.Y, 0, vp.Y - TOGGLE_SIZE)
			toggleBtn.Position = UDim2.fromOffset(newX, newY)
		end
	end)
end

-- ─────────────────────────────────────────────
-- Public API
-- ─────────────────────────────────────────────

local CheatMenu = {}

function CheatMenu.GetState(): MenuState
	return State
end

function CheatMenu.IsLegitbotEnabled(): boolean
	return State.Legitbot.Enabled
end

function CheatMenu.GetLegitbotConfig(): LegitbotState
	return State.Legitbot
end

function CheatMenu.SetVisible(visible: boolean)
	State.Visible  = visible
	Window.Visible = visible
end

function CheatMenu.IsMobile(): boolean
	return isMobile
end

return CheatMenu
