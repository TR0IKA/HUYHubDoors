-- Doors | мобильное меню: ESP, скорость, прыжок, рывок, анти-сущности, конфиги
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("RunService")
local Http = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local lp = Players.LocalPlayer

-- Имена, которые отключает "Anti". Добавляйте свои (имя модуля или модели).
local ANTI_NAMES = {
	A90 = { "A90", "A-90" },
	Screech = { "Screech" },
	Alma = { "Alma" },
	Scream = { "Scream", "Krik" },
	Stems = { "Stems", "Stem" },
}

local ITEM_NAMES = {
	KeyObtain = true, LiveHintBook = true, LiveBreakerPolePickup = true, Lighter = true,
	Flashlight = true, Lockpicks = true, Vitamins = true, Bandage = true, Crucifix = true,
	Battery = true, Candle = true, SkeletonKey = true,
}

local COLORS = {
	Color3.fromRGB(0, 255, 0), Color3.fromRGB(255, 0, 0), Color3.fromRGB(0, 170, 255),
	Color3.fromRGB(255, 255, 0), Color3.fromRGB(255, 0, 255), Color3.fromRGB(255, 255, 255),
}

local DEFAULT = {
	espDoors = true, espEntities = true, espItems = false,
	colDoors = 1, colEntities = 2, colItems = 4,
	speedOn = false, speed = 22,
	fullbright = false, infJump = false, dash = true,
	antiA90 = false, antiScreech = false, antiAlma = false, antiScream = false, antiStems = false,
}
-- Сущности для уведомлений. names = точные имена моделей в workspace.
-- Имена Alma / Scream / Stems / A90 — предположительные, при необходимости поправьте.
local ENTITIES = {
	{ key = "Rush", label = "Rush", names = { "RushMoving" } },
	{ key = "Ambush", label = "Ambush", names = { "AmbushMoving" } },
	{ key = "Seek", label = "Seek", names = { "SeekMovingNewClone", "SeekMoving" } },
	{ key = "Eyes", label = "Eyes", names = { "Eyes" } },
	{ key = "Screech", label = "Screech", names = { "Screech" } },
	{ key = "A90", label = "A-90", names = { "A90", "A-90" } },
	{ key = "Alma", label = "Alma", names = { "Alma" } },
	{ key = "Scream", label = "Scream", names = { "Scream", "Krik" } },
	{ key = "Stems", label = "Stems", names = { "Stems", "Stem" } },
}
DEFAULT.ntfOn = true
for _, e in ipairs(ENTITIES) do DEFAULT["ntf_" .. e.key] = true end

local cfg = {}
for k, v in pairs(DEFAULT) do cfg[k] = v end

-- ===== Конфиги =====
local slot = 1
local function path(n) return "DoorsCfg_" .. n .. ".json" end
local function saveCfg()
	if not writefile then return false end
	return pcall(function() writefile(path(slot), Http:JSONEncode(cfg)) end)
end
local function loadCfg()
	if not (isfile and readfile) or not isfile(path(slot)) then return false end
	local ok, data = pcall(function() return Http:JSONDecode(readfile(path(slot))) end)
	if not ok or type(data) ~= "table" then return false end
	for k, v in pairs(data) do
		if DEFAULT[k] ~= nil and type(v) == type(DEFAULT[k]) then cfg[k] = v end
	end
	return true
end

-- ===== ESP =====
local reg = {}
local function addESP(obj, cat)
	if not obj or obj:FindFirstChild("_ESP") then return end
	local h = Instance.new("Highlight")
	h.Name = "_ESP"
	h.FillTransparency = 0.5
	h.Adornee = obj
	h.Parent = obj
	table.insert(reg, { h = h, cat = cat })
end
local function refreshESP()
	local map = {
		doors = { cfg.espDoors, cfg.colDoors },
		ent = { cfg.espEntities, cfg.colEntities },
		items = { cfg.espItems, cfg.colItems },
	}
	for i = #reg, 1, -1 do
		local r = reg[i]
		if not r.h.Parent then
			table.remove(reg, i)
		else
			local m = map[r.cat]
			r.h.Enabled = m[1]
			r.h.FillColor = COLORS[m[2]]
			r.h.OutlineColor = COLORS[m[2]]
		end
	end
end

local function scanRoom(room)
	task.wait(0.3)
	local door = room:FindFirstChild("Door")
	if door and door:FindFirstChild("Door") then addESP(door.Door, "doors") end
	for _, d in ipairs(room:GetDescendants()) do
		if ITEM_NAMES[d.Name] and d:IsA("Model") then addESP(d, "items") end
	end
	refreshESP()
end

local rooms = workspace:WaitForChild("CurrentRooms")
rooms.ChildAdded:Connect(scanRoom)
for _, r in ipairs(rooms:GetChildren()) do task.spawn(scanRoom, r) end

local ENT_MOVING = { RushMoving = true, AmbushMoving = true }
workspace.ChildAdded:Connect(function(c)
	if ENT_MOVING[c.Name] then
		task.wait()
		addESP(c, "ent")
		refreshESP()
	end
end)

-- ===== Anti-сущности =====
local function matches(name, list)
	for _, n in ipairs(list) do
		if name == n then return true end
	end
	return false
end
local antiKeys = {
	antiA90 = "A90", antiScreech = "Screech", antiAlma = "Alma",
	antiScream = "Scream", antiStems = "Stems",
}
local function antiStep()
	local ui = lp:FindFirstChild("PlayerGui")
	local mods = ui and ui:FindFirstChild("MainUI") and ui.MainUI:FindFirstChild("Initiator")
	mods = mods and mods:FindFirstChild("Main_Game")
	mods = mods and mods:FindFirstChild("RemoteListener")
	mods = mods and mods:FindFirstChild("Modules")
	for flag, key in pairs(antiKeys) do
		if cfg[flag] then
			if mods then
				for _, m in ipairs(mods:GetChildren()) do
					if matches(m.Name, ANTI_NAMES[key]) then m:Destroy() end
				end
			end
			for _, o in ipairs(workspace:GetChildren()) do
				if o:IsA("Model") and matches(o.Name, ANTI_NAMES[key]) then o:Destroy() end
			end
		end
	end
end
task.spawn(function()
	while task.wait(0.5) do pcall(antiStep) end
end)

-- ===== Скорость, свет, прыжок =====
local function hum() return lp.Character and lp.Character:FindFirstChildOfClass("Humanoid") end
local function root() return lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") end

RS.Heartbeat:Connect(function()
	local h = hum()
	if h and cfg.speedOn then h.WalkSpeed = cfg.speed end
	if cfg.fullbright then
		Lighting.Brightness = 2
		Lighting.ClockTime = 14
		Lighting.FogEnd = 1e5
		Lighting.GlobalShadows = false
	end
end)

UIS.JumpRequest:Connect(function() -- работает и на телефоне (кнопка прыжка)
	local h = hum()
	if cfg.infJump and h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
end)

local dashing = false
local function doDash()
	local r = root()
	if not cfg.dash or dashing or not r then return end
	dashing = true
	local look = r.CFrame.LookVector
	local t = tick()
	while tick() - t < 0.25 do
		r.AssemblyLinearVelocity = Vector3.new(look.X * 70, r.AssemblyLinearVelocity.Y, look.Z * 70)
		RS.Heartbeat:Wait()
	end
	dashing = false
end

-- ===== Интерфейс (сенсорный) =====
local parent = (gethui and gethui()) or game:GetService("CoreGui")
local gui = Instance.new("ScreenGui")
gui.Name = "DoorsMenu"
gui.ResetOnSpawn = false
gui.Parent = parent

local function corner(o, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 8)
	c.Parent = o
end

local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.fromOffset(46, 46)
toggleBtn.Position = UDim2.new(0, 10, 0.5, -23)
toggleBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
toggleBtn.Text = "☰"
toggleBtn.TextColor3 = Color3.new(1, 1, 1)
toggleBtn.TextSize = 24
toggleBtn.Parent = gui
corner(toggleBtn, 23)

local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(250, 300)
panel.Position = UDim2.new(0, 64, 0.5, -150)
panel.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
panel.Visible = false
panel.Parent = gui
corner(panel, 10)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 30)
title.BackgroundTransparency = 1
title.Text = "Doors Menu (drag)"
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.Parent = panel

local list = Instance.new("ScrollingFrame")
list.Position = UDim2.fromOffset(6, 32)
list.Size = UDim2.new(1, -12, 1, -38)
list.BackgroundTransparency = 1
list.ScrollBarThickness = 4
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.CanvasSize = UDim2.new()
list.Parent = panel
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 5)
layout.Parent = list

toggleBtn.Activated:Connect(function() panel.Visible = not panel.Visible end)

-- перетаскивание панели за заголовок
do
	local drag, start, orig
	title.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
			drag, start, orig = true, i.Position, panel.Position
		end
	end)
	UIS.InputChanged:Connect(function(i)
		if drag and (i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseMovement) then
			local d = i.Position - start
			panel.Position = UDim2.new(orig.X.Scale, orig.X.Offset + d.X, orig.Y.Scale, orig.Y.Offset + d.Y)
		end
	end)
	UIS.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
			drag = false
		end
	end)
end

local refreshers = {}
local function button(text, cb)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, -4, 0, 36) -- крупные кнопки под палец
	b.BackgroundColor3 = Color3.fromRGB(45, 45, 58)
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.Gotham
	b.TextSize = 14
	b.Text = text
	b.Parent = list
	corner(b)
	b.Activated:Connect(cb)
	return b
end

local function toggle(label, key, onChange)
	local b
	local function upd()
		b.Text = label .. ": " .. (cfg[key] and "ON" or "OFF")
		b.BackgroundColor3 = cfg[key] and Color3.fromRGB(40, 120, 70) or Color3.fromRGB(45, 45, 58)
	end
	b = button("", function()
		cfg[key] = not cfg[key]
		upd()
		if onChange then onChange() end
	end)
	upd()
	table.insert(refreshers, upd)
end

local function colorPicker(label, key)
	local b
	local function upd()
		b.Text = label .. " color"
		b.BackgroundColor3 = COLORS[cfg[key]]
		b.TextColor3 = Color3.new(0, 0, 0)
	end
	b = button("", function()
		cfg[key] = cfg[key] % #COLORS + 1
		upd()
		refreshESP()
	end)
	upd()
	table.insert(refreshers, upd)
end

local function slider(label, key, min, max)
	local f = Instance.new("Frame")
	f.Size = UDim2.new(1, -4, 0, 44)
	f.BackgroundColor3 = Color3.fromRGB(45, 45, 58)
	f.Parent = list
	corner(f)
	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(1, 0, 0, 20)
	t.BackgroundTransparency = 1
	t.TextColor3 = Color3.new(1, 1, 1)
	t.Font = Enum.Font.Gotham
	t.TextSize = 13
	t.Parent = f
	local bar = Instance.new("Frame")
	bar.Position = UDim2.new(0, 10, 0, 28)
	bar.Size = UDim2.new(1, -20, 0, 8)
	bar.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
	bar.Parent = f
	corner(bar, 4)
	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
	fill.Parent = bar
	corner(fill, 4)
	local function upd()
		local a = (cfg[key] - min) / (max - min)
		fill.Size = UDim2.new(a, 0, 1, 0)
		t.Text = label .. ": " .. math.floor(cfg[key])
	end
	upd()
	table.insert(refreshers, upd)
	local sliding = false
	local function set(x)
		local a = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
		cfg[key] = math.floor(min + (max - min) * a)
		upd()
	end
	f.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
			sliding = true
			set(i.Position.X)
		end
	end)
	UIS.InputChanged:Connect(function(i)
		if sliding and (i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseMovement) then
			set(i.Position.X)
		end
	end)
	UIS.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
			sliding = false
		end
	end)
end

local function refreshAll()
	for _, f in ipairs(refreshers) do f() end
	refreshESP()
end

-- Пункты меню
toggle("Door ESP", "espDoors", refreshESP)
colorPicker("Door", "colDoors")
toggle("Entity ESP", "espEntities", refreshESP)
colorPicker("Entity", "colEntities")
toggle("Item ESP", "espItems", refreshESP)
colorPicker("Item", "colItems")
toggle("Speed", "speedOn", function()
	if not cfg.speedOn and hum() then hum().WalkSpeed = 16 end
end)
slider("Walk speed", "speed", 16, 60)
toggle("Fullbright", "fullbright")
toggle("Infinite jump", "infJump")
toggle("Dash button", "dash", function() end)
toggle("Anti A-90", "antiA90")
toggle("Anti Screech", "antiScreech")
toggle("Anti Alma", "antiAlma")
toggle("Anti Scream", "antiScream")
toggle("Anti Stems", "antiStems")

-- Уведомления о сущностях
toggle("Notifications", "ntfOn")
for _, e in ipairs(ENTITIES) do
	toggle("Notify: " .. e.label, "ntf_" .. e.key)
end

-- Конфиги
local slotBtn
slotBtn = button("Config slot: 1", function()
	slot = slot % 3 + 1
	slotBtn.Text = "Config slot: " .. slot
end)
local statusBtn
button("Save config", function()
	statusBtn.Text = saveCfg() and "Saved" or "Save failed (no writefile)"
end)
button("Load config", function()
	if loadCfg() then
		refreshAll()
		statusBtn.Text = "Loaded"
	else
		statusBtn.Text = "No config in this slot"
	end
end)
statusBtn = button("Status: -", function() end)

-- Экранная кнопка рывка (вместо клавиши) — можно перетаскивать
local dashBtn = Instance.new("TextButton")
dashBtn.Size = UDim2.fromOffset(64, 64)
dashBtn.Position = UDim2.new(1, -90, 1, -190)
dashBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
dashBtn.BackgroundTransparency = 0.2
dashBtn.Text = "DASH"
dashBtn.TextColor3 = Color3.new(1, 1, 1)
dashBtn.Font = Enum.Font.GothamBold
dashBtn.TextSize = 14
dashBtn.Parent = gui
corner(dashBtn, 32)
dashBtn.Activated:Connect(doDash)
RS.Heartbeat:Connect(function() dashBtn.Visible = cfg.dash end)

-- Клавиша для ПК
UIS.InputBegan:Connect(function(i, gp)
	if not gp and i.KeyCode == Enum.KeyCode.C then doDash() end
end)

-- ===== Уведомления справа сверху =====
local TweenService = game:GetService("TweenService")
local ntfHolder = Instance.new("Frame")
ntfHolder.Size = UDim2.fromOffset(220, 300)
ntfHolder.Position = UDim2.new(1, -230, 0, 10)
ntfHolder.BackgroundTransparency = 1
ntfHolder.Parent = gui
local ntfLayout = Instance.new("UIListLayout")
ntfLayout.Padding = UDim.new(0, 5)
ntfLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
ntfLayout.Parent = ntfHolder

local function notify(text)
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromOffset(210, 32)
	l.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
	l.BackgroundTransparency = 0.1
	l.TextColor3 = Color3.fromRGB(255, 80, 80)
	l.Font = Enum.Font.GothamBold
	l.TextSize = 14
	l.Text = text
	l.Parent = ntfHolder
	corner(l)
	task.delay(4, function()
		local info = TweenInfo.new(0.4)
		TweenService:Create(l, info, { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
		task.wait(0.45)
		l:Destroy()
	end)
end

local nameToEntity = {}
for _, e in ipairs(ENTITIES) do
	for _, n in ipairs(e.names) do nameToEntity[n] = e end
end
local lastSeen = {}

local function onSpawn(inst)
	local e = nameToEntity[inst.Name]
	if not e or not cfg.ntfOn or not cfg["ntf_" .. e.key] then return end
	if lastSeen[e.key] and tick() - lastSeen[e.key] < 3 then return end
	lastSeen[e.key] = tick()
	notify("⚠ " .. e.label .. " spawned!")
end

workspace.ChildAdded:Connect(onSpawn)
rooms.DescendantAdded:Connect(onSpawn)

refreshESP()
