-- Huy Hub Doors v4 (один файл)
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("RunService")
local Http = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lp = Players.LocalPlayer

-- ===== Списки имён (при необходимости правьте) =====
local ANTI_NAMES = {
	Rush = { "RushMoving" },
	Ambush = { "AmbushMoving" },
	A90 = { "A90", "A-90" },
	Screech = { "Screech" },
	Alma = { "Alma" },
	Scream = { "Scream", "Krik" },
	Stems = { "Stems", "Stem" },
	Eyes = { "Eyes" },
	Halt = { "Halt" },
	Snare = { "Snare" },
}
local FIGURE_NAMES = { FigureRagdoll = true, Figure = true, FigureSetup = true }

local ITEM_NAMES = {
	KeyObtain = true, LiveHintBook = true, LiveBreakerPolePickup = true, Lighter = true,
	Flashlight = true, Lockpicks = true, Vitamins = true, Bandage = true, Crucifix = true,
	Battery = true, Candle = true, SkeletonKey = true, GoldPile = true,
}
local function isStardust(n) return n:lower():find("stardust", 1, true) ~= nil end
local function isItemName(n) return ITEM_NAMES[n] or isStardust(n) end

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

local THREATS = { RushMoving = true, AmbushMoving = true }
local HIDE_REACH = 10
local SPEED_CAP = 24 -- выше этого значения сервер откатывает

local COLORS = {
	Color3.fromRGB(0, 255, 0), Color3.fromRGB(255, 0, 0), Color3.fromRGB(0, 170, 255),
	Color3.fromRGB(255, 255, 0), Color3.fromRGB(255, 0, 255), Color3.fromRGB(255, 255, 255),
}

local DEFAULT = {
	espDoors = true, espEntities = true, espItems = false, espStardust = true, espHide = false,
	colDoors = 1, colEntities = 2, colItems = 4, colStardust = 5, colHide = 3,
	speedOn = false, speed = 20,
	fullbright = false,
	infJump = false, jumpPower = 50,
	dash = true, dashPower = 24,
	noclip = false,
	autoLoot = false, lootRange = 14,
	autoHide = false, hideTrigger = 150,
	antiRush = false, antiAmbush = false,
	antiA90 = false, antiScreech = false, antiAlma = false, antiScream = false, antiStems = false,
	antiEyes = false, antiHalt = false, antiSnare = false,
	autoFigure = false, antiCustom = false, customName = "",
	ntfOn = true,
}
for _, e in ipairs(ENTITIES) do DEFAULT["ntf_" .. e.key] = true end

local cfg = {}
for k, v in pairs(DEFAULT) do cfg[k] = v end

-- ===== Конфиги с именами =====
local INDEX = "DoorsMenu_index.json"
local function cleanName(s)
	s = tostring(s or "")
	s = s:gsub("[^%w_%- \128-\255]", "")
	s = s:gsub("^%s+", ""):gsub("%s+$", "")
	local cut = utf8.offset(s, 25)
	if cut then s = s:sub(1, cut - 1) end
	return s
end
local function fileOf(n) return "DoorsMenu_" .. n .. ".json" end
local function readIndex()
	if not (isfile and readfile) or not isfile(INDEX) then return {} end
	local ok, d = pcall(function() return Http:JSONDecode(readfile(INDEX)) end)
	return (ok and type(d) == "table") and d or {}
end
local function writeIndex(t)
	pcall(function() writefile(INDEX, Http:JSONEncode(t)) end)
end
local function saveNamed(name)
	if not writefile then return false, "executor has no writefile" end
	name = cleanName(name)
	if name == "" then return false, "enter a name first" end
	local ok = pcall(function() writefile(fileOf(name), Http:JSONEncode(cfg)) end)
	if not ok then return false, "save failed" end
	local idx = readIndex()
	if not table.find(idx, name) then
		table.insert(idx, name)
		writeIndex(idx)
	end
	return true, name
end
local function loadNamed(name)
	if not (isfile and readfile) or not name or not isfile(fileOf(name)) then return false end
	local ok, data = pcall(function() return Http:JSONDecode(readfile(fileOf(name))) end)
	if not ok or type(data) ~= "table" then return false end
	for k, v in pairs(data) do
		if DEFAULT[k] ~= nil and type(v) == type(DEFAULT[k]) then cfg[k] = v end
	end
	return true
end
local function deleteNamed(name)
	if not name then return false end
	pcall(function() if delfile and isfile(fileOf(name)) then delfile(fileOf(name)) end end)
	local idx = readIndex()
	local i = table.find(idx, name)
	if i then
		table.remove(idx, i)
		writeIndex(idx)
	end
	return true
end

-- ===== Общие помощники =====
local function hum() return lp.Character and lp.Character:FindFirstChildOfClass("Humanoid") end
local function root() return lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") end

local function promptPos(p)
	local par = p.Parent
	if not par then return nil end
	if par:IsA("Attachment") then return par.WorldPosition end
	if par:IsA("PVInstance") then return par:GetPivot().Position end
	return nil
end

local function getModules()
	local ui = lp:FindFirstChild("PlayerGui")
	local m = ui and ui:FindFirstChild("MainUI") and ui.MainUI:FindFirstChild("Initiator")
	m = m and m:FindFirstChild("Main_Game")
	m = m and m:FindFirstChild("RemoteListener")
	return m and m:FindFirstChild("Modules")
end

-- ===== ESP =====
local reg = {}
local function addESP(obj, cat)
	if not obj or not obj.Parent or obj:FindFirstChild("_ESP") then return end
	local ok, h = pcall(function()
		local hl = Instance.new("Highlight")
		hl.Name = "_ESP"
		hl.FillTransparency = 0.5
		hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		hl.Adornee = obj
		hl.Parent = obj
		return hl
	end)
	if ok then table.insert(reg, { h = h, cat = cat }) end
end
local function refreshESP()
	local map = {
		doors = { cfg.espDoors, cfg.colDoors },
		ent = { cfg.espEntities, cfg.colEntities },
		items = { cfg.espItems, cfg.colItems },
		stardust = { cfg.espStardust, cfg.colStardust },
		hide = { cfg.espHide, cfg.colHide },
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

-- CurrentRooms может появиться не сразу, поэтому всё, что от него зависит, подключается отложенно
local roomsHooks = {}
local function onRooms(fn) table.insert(roomsHooks, fn) end

local function espDoor(d)
	if d.Name == "Door" and d:IsA("BasePart") and d.Parent and d.Parent.Name == "Door" then
		addESP(d, "doors")
	end
end

-- ===== Подсказки: автосбор, подсветка предметов/пыли/шкафов =====
local lootCache, lastFire, hidePrompts = {}, {}, {}

local function lootAncestor(p)
	local a = p.Parent
	for _ = 1, 6 do
		if not a then return nil end
		if isItemName(a.Name) then return a end
		a = a.Parent
	end
	return nil
end

local function trackPrompt(d)
	if not d:IsA("ProximityPrompt") then return end
	local anc = lootAncestor(d)
	if anc then
		lootCache[d] = true
		addESP(anc, isStardust(anc.Name) and "stardust" or "items")
	end
	if d.Name == "HidePrompt" then
		hidePrompts[d] = true
		local par = d.Parent
		local m = (par and par:IsA("Model")) and par or d:FindFirstAncestorOfClass("Model")
		if m then addESP(m, "hide") end
	end
	refreshESP()
end

onRooms(function(rooms)
	rooms.DescendantAdded:Connect(function(d) task.defer(espDoor, d) end)
	rooms.DescendantAdded:Connect(function(d) task.defer(trackPrompt, d) end)
	for _, d in ipairs(rooms:GetDescendants()) do
		espDoor(d)
		trackPrompt(d)
	end
	refreshESP()
end)

local function fireFast(p)
	pcall(function() p.HoldDuration = 0 end)
	pcall(function() p.RequiresLineOfSight = false end)
	pcall(fireproximityprompt, p)
end

task.spawn(function()
	while task.wait(0.15) do
		if cfg.autoLoot and fireproximityprompt then
			local r = root()
			if r then
				for p in pairs(lootCache) do
					if not p.Parent then
						lootCache[p] = nil
						lastFire[p] = nil
					elseif p.Enabled and tick() - (lastFire[p] or 0) > 0.6 then
						local pos = promptPos(p)
						if pos and (pos - r.Position).Magnitude <= cfg.lootRange then
							lastFire[p] = tick()
							fireFast(p)
						end
					end
				end
			end
		end
	end
end)

-- ===== Авто-шкаф (Rush / Ambush) =====
local hiddenByUs, hidePrompt, hideTime, lastThreat = false, nil, 0, 0

local function threatInfo()
	local exists, nearest = false, math.huge
	local r = root()
	for _, o in ipairs(workspace:GetChildren()) do
		if THREATS[o.Name] then
			exists = true
			if r then
				local ok, pos = pcall(function() return o:GetPivot().Position end)
				if ok then nearest = math.min(nearest, (pos - r.Position).Magnitude) end
			end
		end
	end
	return exists, nearest
end

local function nearestHide(maxd)
	local r = root()
	if not r then return nil end
	local best, bd = nil, maxd
	for p in pairs(hidePrompts) do
		if not p.Parent then
			hidePrompts[p] = nil
		else
			local pos = promptPos(p)
			if pos then
				local d = (pos - r.Position).Magnitude
				if d < bd then best, bd = p, d end
			end
		end
	end
	return best, bd
end

task.spawn(function()
	while task.wait(0.1) do
		if cfg.autoHide and fireproximityprompt and root() and lp.Character then
			local exists, dist = threatInfo()
			if exists then lastThreat = tick() end
			local attr = lp.Character:GetAttribute("Hiding")
			if attr == false and hiddenByUs and tick() - hideTime > 1.5 then hiddenByUs = false end
			local isHidden = (attr == true) or hiddenByUs
			if exists and dist <= cfg.hideTrigger and not isHidden then
				local p, d = nearestHide(45)
				if p then
					if d <= HIDE_REACH then
						fireFast(p)
						hidePrompt, hiddenByUs, hideTime = p, true, tick()
						task.wait(0.5)
					else
						local pos, h = promptPos(p), hum()
						if pos and h then h:MoveTo(pos) end -- подбегаем к шкафу
					end
				end
			elseif not exists and hiddenByUs and tick() - lastThreat > 2 then
				if hidePrompt and hidePrompt.Parent then fireFast(hidePrompt) end
				hiddenByUs = false
				task.wait(0.5)
			end
		end
	end
end)

-- ===== Анти-сущности =====
local function matches(name, list)
	for _, n in ipairs(list) do
		if name == n then return true end
	end
	return false
end
local antiKeys = {
	antiRush = "Rush", antiAmbush = "Ambush", antiA90 = "A90", antiScreech = "Screech",
	antiAlma = "Alma", antiScream = "Scream", antiStems = "Stems",
	antiEyes = "Eyes", antiHalt = "Halt", antiSnare = "Snare",
}

local function antiInstant(inst)
	for flag, key in pairs(antiKeys) do
		if cfg[flag] and matches(inst.Name, ANTI_NAMES[key]) then
			if key == "Screech" then
				pcall(function() ReplicatedStorage.RemotesFolder.Screech:FireServer(true) end)
			end
			task.wait()
			pcall(function() inst:Destroy() end)
			return
		end
	end
	if cfg.autoFigure and FIGURE_NAMES[inst.Name] then
		task.wait()
		pcall(function() inst:Destroy() end)
	elseif cfg.antiCustom and cfg.customName ~= "" and inst.Name == cfg.customName then
		task.wait()
		pcall(function() inst:Destroy() end)
	end
end
workspace.ChildAdded:Connect(antiInstant)
onRooms(function(rooms) rooms.DescendantAdded:Connect(antiInstant) end)

local function deleteFigure()
	local rooms = workspace:FindFirstChild("CurrentRooms")
	local n = 0
	if rooms then
		for _, d in ipairs(rooms:GetDescendants()) do
			if FIGURE_NAMES[d.Name] and d.Parent then
				pcall(function() d:Destroy() end)
				n = n + 1
			end
		end
	end
	return n
end

task.spawn(function()
	while task.wait(0.5) do
		pcall(function()
			local mods = getModules()
			for flag, key in pairs(antiKeys) do
				if cfg[flag] and mods then
					for _, m in ipairs(mods:GetChildren()) do
						if matches(m.Name, ANTI_NAMES[key]) then m:Destroy() end
					end
				end
			end
		end)
	end
end)

-- ===== Скорость, свет, прыжок, рывок, ноклип =====
local origBoost
local function setSpeed(v)
	v = math.min(v, SPEED_CAP)
	local c, h = lp.Character, hum()
	if not (c and h) then return end
	if c:GetAttribute("SpeedBoost") ~= nil then
		if origBoost == nil then origBoost = c:GetAttribute("SpeedBoost") end
		c:SetAttribute("SpeedBoost", math.max(0, v - 16))
	else
		h.WalkSpeed = v
	end
end
local function resetSpeed()
	local c, h = lp.Character, hum()
	if c and origBoost ~= nil and c:GetAttribute("SpeedBoost") ~= nil then
		c:SetAttribute("SpeedBoost", origBoost)
	end
	origBoost = nil
	if h then h.WalkSpeed = 16 end
end
lp.CharacterAdded:Connect(function() origBoost = nil end)

local dashing = false
RS.Heartbeat:Connect(function()
	local h = hum()
	if h then
		if cfg.speedOn and not dashing then setSpeed(cfg.speed) end
		if cfg.infJump then
			h.UseJumpPower = true
			h.JumpPower = cfg.jumpPower
		end
	end
	if cfg.fullbright then
		Lighting.Brightness = 2
		Lighting.ClockTime = 14
		Lighting.FogEnd = 1e5
		Lighting.GlobalShadows = false
	end
end)

UIS.JumpRequest:Connect(function()
	if not cfg.infJump then return end
	local h, r = hum(), root()
	if h and r then
		pcall(function() h:ChangeState(Enum.HumanoidStateType.Jumping) end)
		local v = r.AssemblyLinearVelocity
		r.AssemblyLinearVelocity = Vector3.new(v.X, cfg.jumpPower, v.Z)
	end
end)

local function doDash()
	local r = root()
	if not cfg.dash or dashing or not r then return end
	dashing = true
	local look = r.CFrame.LookVector
	local dir = Vector3.new(look.X, 0, look.Z)
	local t = tick()
	while tick() - t < 0.5 do
		local h = hum()
		if not (h and root()) then break end
		setSpeed(cfg.dashPower)
		h:Move(dir, false)
		RS.Heartbeat:Wait()
	end
	dashing = false
	if cfg.speedOn then setSpeed(cfg.speed) else resetSpeed() end
end

-- Ноклип: отключаем столкновения у всех частей персонажа (включая Collision-части игры) каждый кадр
local ncOrig = {}
RS.Stepped:Connect(function()
	local c = lp.Character
	if not c then return end
	if cfg.noclip then
		for _, part in ipairs(c:GetDescendants()) do
			if part:IsA("BasePart") and part.CanCollide then
				ncOrig[part] = true
				part.CanCollide = false
			end
		end
	elseif next(ncOrig) then
		for part in pairs(ncOrig) do
			if part.Parent then part.CanCollide = true end
		end
		ncOrig = {}
	end
end)

-- ===== Диагностика =====
local function dumpInfo()
	local out = {}
	local function add(s) table.insert(out, s) end
	local c, h = lp.Character, hum()
	add("== Character attributes")
	if c then for k, v in pairs(c:GetAttributes()) do add(k .. "=" .. tostring(v)) end end
	add("== Humanoid")
	if h then
		add("WalkSpeed=" .. h.WalkSpeed .. " JumpPower=" .. h.JumpPower .. " UseJumpPower=" .. tostring(h.UseJumpPower))
		for k, v in pairs(h:GetAttributes()) do add(k .. "=" .. tostring(v)) end
	end
	add("== Character parts (CanCollide)")
	if c then
		local n = 0
		for _, p in ipairs(c:GetDescendants()) do
			if p:IsA("BasePart") and n < 40 then
				n = n + 1
				add(p.Name .. " cc=" .. tostring(p.CanCollide))
			end
		end
	end
	add("== workspace children")
	local seen = {}
	for _, o in ipairs(workspace:GetChildren()) do
		if not seen[o.Name] then
			seen[o.Name] = true
			add(o.Name .. " (" .. o.ClassName .. ")")
		end
	end
	add("== client Modules")
	local mods = getModules()
	if mods then for _, m in ipairs(mods:GetChildren()) do add(m.Name) end else add("not found") end
	add("== RemotesFolder")
	local rf = ReplicatedStorage:FindFirstChild("RemotesFolder")
	if rf then for _, m in ipairs(rf:GetChildren()) do add(m.Name .. " (" .. m.ClassName .. ")") end else add("not found") end
	add("== prompts within 20 studs")
	local r, rm = root(), workspace:FindFirstChild("CurrentRooms")
	if r and rm then
		local n = 0
		for _, d in ipairs(rm:GetDescendants()) do
			if d:IsA("ProximityPrompt") and n < 25 then
				local pos = promptPos(d)
				if pos and (pos - r.Position).Magnitude <= 20 then
					n = n + 1
					add(d.Name .. " | parent=" .. (d.Parent and d.Parent.Name or "?") .. " | enabled=" .. tostring(d.Enabled) .. " | " .. d:GetFullName():sub(-70))
				end
			end
		end
	end
	add("== counts: loot prompts / hide prompts / highlights")
	local lc, hc = 0, 0
	for _ in pairs(lootCache) do lc = lc + 1 end
	for _ in pairs(hidePrompts) do hc = hc + 1 end
	add(lc .. " / " .. hc .. " / " .. #reg)
	return table.concat(out, "\n")
end

-- ===== Интерфейс =====
local parentGui = (gethui and gethui()) or game:GetService("CoreGui")
local gui = Instance.new("ScreenGui")
gui.Name = "DoorsMenu"
gui.ResetOnSpawn = false
gui.Parent = parentGui

local ACC = Color3.fromRGB(124, 92, 255)
local BG = Color3.fromRGB(16, 16, 22)
local ROW = Color3.fromRGB(28, 28, 38)
local OFFC = Color3.fromRGB(70, 70, 86)
local TXT = Color3.fromRGB(235, 235, 245)
local SUB = Color3.fromRGB(150, 150, 170)
local WHITE = Color3.new(1, 1, 1)

local function mk(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	if parent then o.Parent = parent end
	return o
end
local function corner(o, r) return mk("UICorner", { CornerRadius = UDim.new(0, r or 8) }, o) end

-- Уведомления справа сверху
local ntfHolder = mk("Frame", {
	Size = UDim2.fromOffset(230, 300), Position = UDim2.new(1, -240, 0, 10), BackgroundTransparency = 1,
}, gui)
mk("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Right }, ntfHolder)

local function notify(text, color)
	color = color or Color3.fromRGB(255, 90, 90)
	local f = mk("Frame", { Size = UDim2.fromOffset(222, 34), BackgroundColor3 = BG, BackgroundTransparency = 0.05 }, ntfHolder)
	corner(f, 8)
	local st = mk("UIStroke", { Color = color, Thickness = 1.5 }, f)
	local l = mk("TextLabel", {
		Size = UDim2.new(1, -12, 1, 0), Position = UDim2.fromOffset(8, 0), BackgroundTransparency = 1,
		Text = text, TextColor3 = TXT, Font = Enum.Font.GothamBold, TextSize = 13, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, f)
	task.delay(4, function()
		local info = TweenInfo.new(0.4)
		TweenService:Create(f, info, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(l, info, { TextTransparency = 1 }):Play()
		TweenService:Create(st, info, { Transparency = 1 }):Play()
		task.wait(0.45)
		f:Destroy()
	end)
end

-- Перетаскивание (палец отличает тап от движения)
local function makeDraggable(handle, target, onTap)
	local dragging, moved, startObj, startPos, startTarget = false, false, nil, nil, nil
	handle.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging, moved, startObj, startPos, startTarget = true, false, i, i.Position, target.Position
		end
	end)
	UIS.InputChanged:Connect(function(i)
		if not dragging then return end
		if i.UserInputType == Enum.UserInputType.Touch and i ~= startObj then return end
		if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseMovement then
			local d = i.Position - startPos
			if d.Magnitude > 8 then moved = true end
			if moved then
				target.Position = UDim2.new(startTarget.X.Scale, startTarget.X.Offset + d.X, startTarget.Y.Scale, startTarget.Y.Offset + d.Y)
			end
		end
	end)
	UIS.InputEnded:Connect(function(i)
		if not dragging then return end
		if i.UserInputType == Enum.UserInputType.Touch and i ~= startObj then return end
		if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
			if not moved and onTap then onTap() end
		end
	end)
end

-- Кнопка открытия меню (перемещается пальцем)
local openBtn = mk("TextButton", {
	Size = UDim2.fromOffset(48, 48), Position = UDim2.new(0, 10, 0.5, -24), BackgroundColor3 = ACC,
	Text = "H", TextColor3 = WHITE, Font = Enum.Font.GothamBlack, TextSize = 22, AutoButtonColor = false,
}, gui)
corner(openBtn, 24)
mk("UIStroke", { Color = WHITE, Transparency = 0.6, Thickness = 1.5 }, openBtn)
mk("UIGradient", {
	Color = ColorSequence.new(Color3.fromRGB(150, 110, 255), Color3.fromRGB(90, 60, 220)), Rotation = 45,
}, openBtn)

-- Панель
local panel = mk("Frame", {
	Size = UDim2.fromOffset(320, 330), Position = UDim2.new(0, 68, 0.5, -165), BackgroundColor3 = BG, Visible = false,
}, gui)
corner(panel, 14)
mk("UIStroke", { Color = ACC, Thickness = 1.5, Transparency = 0.3 }, panel)

local header = mk("Frame", { Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1 }, panel)
mk("TextLabel", {
	Size = UDim2.new(1, -50, 1, 0), Position = UDim2.fromOffset(14, 0), BackgroundTransparency = 1,
	Text = "Huy Hub Doors", TextColor3 = TXT, Font = Enum.Font.GothamBlack, TextSize = 16,
	TextXAlignment = Enum.TextXAlignment.Left,
}, header)
mk("Frame", { Size = UDim2.new(1, -28, 0, 2), Position = UDim2.new(0, 14, 1, -2), BackgroundColor3 = ACC, BorderSizePixel = 0 }, header)
local closeBtn = mk("TextButton", {
	Size = UDim2.fromOffset(30, 26), Position = UDim2.new(1, -38, 0, 5), BackgroundColor3 = ROW,
	Text = "✕", TextColor3 = SUB, Font = Enum.Font.GothamBold, TextSize = 13,
}, header)
corner(closeBtn, 8)
closeBtn.Activated:Connect(function() panel.Visible = false end)

makeDraggable(openBtn, openBtn, function() panel.Visible = not panel.Visible end)
makeDraggable(header, panel, nil)

-- Вкладки и страницы
local TABS = { "ESP", "Move", "Auto", "Anti", "Alerts", "Config" }
local pages, tabBtns = {}, {}
local function selectTab(n)
	for name, pg in pairs(pages) do pg.Visible = (name == n) end
	for name, b in pairs(tabBtns) do
		b.BackgroundColor3 = (name == n) and ACC or ROW
		b.TextColor3 = (name == n) and WHITE or SUB
	end
end

for i, name in ipairs(TABS) do
	local b = mk("TextButton", {
		Size = UDim2.new(1 / #TABS, -4, 0, 26), Position = UDim2.new((i - 1) / #TABS, 2, 0, 42),
		BackgroundColor3 = ROW, TextColor3 = SUB, Font = Enum.Font.GothamBold, TextSize = 11, Text = name,
	}, panel)
	corner(b, 8)
	b.Activated:Connect(function() selectTab(name) end)
	tabBtns[name] = b

	local pg = mk("ScrollingFrame", {
		Position = UDim2.fromOffset(8, 76), Size = UDim2.new(1, -16, 1, -84), BackgroundTransparency = 1,
		ScrollBarThickness = 3, ScrollBarImageColor3 = ACC, AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(), Visible = false, BorderSizePixel = 0,
	}, panel)
	mk("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, pg)
	pages[name] = pg
end

local orders = {}
local function ord(p)
	orders[p] = (orders[p] or 0) + 1
	return orders[p]
end
local refreshers = {}

local function section(p, text)
	return mk("TextLabel", {
		Size = UDim2.new(1, -4, 0, 18), BackgroundTransparency = 1, Text = string.upper(text), TextColor3 = ACC,
		Font = Enum.Font.GothamBold, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = ord(p),
	}, p)
end

local function buttonRow(p, text, cb)
	local b = mk("TextButton", {
		Size = UDim2.new(1, -4, 0, 34), BackgroundColor3 = ACC, Text = text, TextColor3 = WHITE,
		Font = Enum.Font.GothamBold, TextSize = 13, LayoutOrder = ord(p),
	}, p)
	corner(b, 8)
	b.Activated:Connect(cb)
	return b
end

local function toggleRow(p, text, key, colKey, onChange)
	local f = mk("Frame", { Size = UDim2.new(1, -4, 0, 36), BackgroundColor3 = ROW, LayoutOrder = ord(p) }, p)
	corner(f, 8)
	mk("TextLabel", {
		Size = UDim2.new(1, colKey and -104 or -64, 1, 0), Position = UDim2.fromOffset(10, 0), BackgroundTransparency = 1,
		Text = text, TextColor3 = TXT, Font = Enum.Font.Gotham, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, f)
	local sw = mk("Frame", { Size = UDim2.fromOffset(38, 20), Position = UDim2.new(1, -46, 0.5, -10), BackgroundColor3 = OFFC }, f)
	corner(sw, 10)
	local knob = mk("Frame", { Size = UDim2.fromOffset(16, 16), Position = UDim2.new(0, 2, 0.5, -8), BackgroundColor3 = WHITE }, sw)
	corner(knob, 8)
	local hit = mk("TextButton", {
		Size = colKey and UDim2.new(0, 60, 1, 0) or UDim2.new(1, 0, 1, 0),
		Position = colKey and UDim2.new(1, -60, 0, 0) or UDim2.new(0, 0, 0, 0),
		BackgroundTransparency = 1, Text = "",
	}, f)
	local function upd()
		local on = cfg[key]
		local info = TweenInfo.new(0.15)
		TweenService:Create(sw, info, { BackgroundColor3 = on and ACC or OFFC }):Play()
		TweenService:Create(knob, info, { Position = on and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8) }):Play()
	end
	hit.Activated:Connect(function()
		cfg[key] = not cfg[key]
		upd()
		if onChange then onChange() end
	end)
	if colKey then
		local sc = mk("TextButton", {
			Size = UDim2.fromOffset(22, 22), Position = UDim2.new(1, -84, 0.5, -11),
			BackgroundColor3 = COLORS[cfg[colKey]], Text = "",
		}, f)
		corner(sc, 6)
		local function updc() sc.BackgroundColor3 = COLORS[cfg[colKey]] end
		sc.Activated:Connect(function()
			cfg[colKey] = cfg[colKey] % #COLORS + 1
			updc()
			refreshESP()
		end)
		table.insert(refreshers, updc)
	end
	upd()
	table.insert(refreshers, upd)
end

local function sliderRow(p, text, key, min, max)
	local f = mk("Frame", { Size = UDim2.new(1, -4, 0, 48), BackgroundColor3 = ROW, LayoutOrder = ord(p) }, p)
	corner(f, 8)
	mk("TextLabel", {
		Size = UDim2.new(1, -70, 0, 22), Position = UDim2.fromOffset(10, 3), BackgroundTransparency = 1, Text = text,
		TextColor3 = TXT, Font = Enum.Font.Gotham, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
	}, f)
	local val = mk("TextLabel", {
		Size = UDim2.fromOffset(50, 22), Position = UDim2.new(1, -60, 0, 3), BackgroundTransparency = 1,
		TextColor3 = ACC, Font = Enum.Font.GothamBold, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Right,
	}, f)
	local bar = mk("Frame", { Size = UDim2.new(1, -24, 0, 6), Position = UDim2.new(0, 12, 0, 34), BackgroundColor3 = OFFC }, f)
	corner(bar, 3)
	local fill = mk("Frame", { BackgroundColor3 = ACC, Size = UDim2.new(0, 0, 1, 0) }, bar)
	corner(fill, 3)
	local knob = mk("Frame", {
		Size = UDim2.fromOffset(14, 14), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
		BackgroundColor3 = WHITE,
	}, bar)
	corner(knob, 7)
	local function upd()
		local a = (cfg[key] - min) / (max - min)
		fill.Size = UDim2.new(a, 0, 1, 0)
		knob.Position = UDim2.new(a, 0, 0.5, 0)
		val.Text = tostring(math.floor(cfg[key]))
	end
	upd()
	table.insert(refreshers, upd)
	local sliding = false
	local function set(x)
		local a = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
		cfg[key] = math.floor(min + (max - min) * a + 0.5)
		upd()
	end
	f.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
			sliding = true
			p.ScrollingEnabled = false
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
			p.ScrollingEnabled = true
		end
	end)
end

local function textBox(p, placeholder)
	local box = mk("TextBox", {
		Size = UDim2.new(1, -4, 0, 36), BackgroundColor3 = ROW, TextColor3 = TXT, PlaceholderText = placeholder,
		PlaceholderColor3 = SUB, Text = "", ClearTextOnFocus = false, Font = Enum.Font.Gotham, TextSize = 14,
		LayoutOrder = ord(p),
	}, p)
	corner(box, 8)
	return box
end

local function refreshAll()
	for _, f in ipairs(refreshers) do f() end
	refreshESP()
end

-- ----- ESP -----
do
	local p = pages.ESP
	section(p, "Highlights (tap square = color)")
	toggleRow(p, "Doors", "espDoors", "colDoors", refreshESP)
	toggleRow(p, "Entities", "espEntities", "colEntities", refreshESP)
	toggleRow(p, "Items", "espItems", "colItems", refreshESP)
	toggleRow(p, "Stardust", "espStardust", "colStardust", refreshESP)
	toggleRow(p, "Hiding spots", "espHide", "colHide", refreshESP)
	section(p, "World")
	toggleRow(p, "Fullbright", "fullbright")
end

-- ----- Move -----
do
	local p = pages.Move
	section(p, "Speed (max 24)")
	toggleRow(p, "Speed boost", "speedOn", nil, function()
		if not cfg.speedOn then resetSpeed() end
	end)
	sliderRow(p, "Walk speed", "speed", 16, SPEED_CAP)
	section(p, "Jump")
	toggleRow(p, "Infinite jump", "infJump")
	sliderRow(p, "Jump power", "jumpPower", 30, 100)
	section(p, "Dash")
	toggleRow(p, "Dash button", "dash")
	sliderRow(p, "Dash power", "dashPower", 16, SPEED_CAP)
	section(p, "Collision")
	toggleRow(p, "Noclip", "noclip")
end

-- ----- Auto -----
do
	local p = pages.Auto
	section(p, "Auto pickup")
	toggleRow(p, "Auto pickup", "autoLoot")
	sliderRow(p, "Pickup range", "lootRange", 6, 25)
	section(p, "Auto hide (Rush / Ambush)")
	toggleRow(p, "Auto hide in closet", "autoHide")
	sliderRow(p, "Hide trigger distance", "hideTrigger", 60, 300)
	section(p, "Diagnostics")
	buttonRow(p, "Copy debug info", function()
		if setclipboard then
			setclipboard(dumpInfo())
			notify("Debug info copied", Color3.fromRGB(80, 220, 120))
		else
			notify("setclipboard not supported", Color3.fromRGB(255, 200, 80))
		end
	end)
end

-- ----- Anti -----
do
	local p = pages.Anti
	section(p, "Remove / neutralize entities")
	toggleRow(p, "Anti Rush", "antiRush")
	toggleRow(p, "Anti Ambush", "antiAmbush")
	toggleRow(p, "Anti Screech", "antiScreech")
	toggleRow(p, "Anti Eyes", "antiEyes")
	toggleRow(p, "Anti Halt", "antiHalt")
	toggleRow(p, "Anti Snare", "antiSnare")
	toggleRow(p, "Anti A-90", "antiA90")
	toggleRow(p, "Anti Alma", "antiAlma")
	toggleRow(p, "Anti Scream", "antiScream")
	toggleRow(p, "Anti Stems", "antiStems")
	section(p, "Figure")
	buttonRow(p, "Delete Figure now", function()
		local n = deleteFigure()
		notify(n > 0 and ("Deleted " .. n .. " Figure part(s)") or "Figure not found", Color3.fromRGB(255, 200, 80))
	end)
	toggleRow(p, "Auto delete Figure", "autoFigure")
	section(p, "Custom (model name to delete)")
	local box = textBox(p, "Exact name...")
	box.Text = cfg.customName
	box.FocusLost:Connect(function() cfg.customName = box.Text end)
	table.insert(refreshers, function() box.Text = cfg.customName end)
	toggleRow(p, "Delete custom name", "antiCustom")
end

-- ----- Alerts -----
do
	local p = pages.Alerts
	section(p, "Entity notifications")
	toggleRow(p, "Notifications", "ntfOn")
	for _, e in ipairs(ENTITIES) do
		toggleRow(p, e.label, "ntf_" .. e.key)
	end
end

-- ----- Config -----
do
	local p = pages.Config
	local selected = nil
	local statusLbl
	section(p, "Save current settings")
	local box = textBox(p, "Config name...")
	local function setStatus(s) if statusLbl then statusLbl.Text = s end end
	local rebuild
	buttonRow(p, "Save with this name", function()
		local ok, res = saveNamed(box.Text)
		if ok then
			selected = res
			setStatus("Saved: " .. res)
			rebuild()
		else
			setStatus(res)
		end
	end)
	buttonRow(p, "Load selected", function()
		if not selected then setStatus("Select a config first") return end
		if loadNamed(selected) then
			refreshAll()
			setStatus("Loaded: " .. selected)
		else
			setStatus("Could not load")
		end
	end)
	buttonRow(p, "Delete selected", function()
		if not selected then setStatus("Select a config first") return end
		deleteNamed(selected)
		setStatus("Deleted: " .. selected)
		selected = nil
		rebuild()
	end)
	statusLbl = mk("TextLabel", {
		Size = UDim2.new(1, -4, 0, 18), BackgroundTransparency = 1, Text = "Status: -", TextColor3 = SUB,
		Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = ord(p),
	}, p)
	section(p, "Saved configs (tap to select)")
	local items = {}
	rebuild = function()
		for _, b in ipairs(items) do b:Destroy() end
		items = {}
		for i, name in ipairs(readIndex()) do
			local b = mk("TextButton", {
				Size = UDim2.new(1, -4, 0, 34), BackgroundColor3 = (name == selected) and ACC or ROW, TextColor3 = TXT,
				Font = Enum.Font.Gotham, TextSize = 14, Text = name, LayoutOrder = 1000 + i,
			}, p)
			corner(b, 8)
			b.Activated:Connect(function()
				selected = name
				box.Text = name
				rebuild()
			end)
			table.insert(items, b)
		end
	end
	rebuild()
end

selectTab("ESP")

-- Экранная кнопка рывка (перемещается пальцем, срабатывает по тапу)
local dashBtn = mk("TextButton", {
	Size = UDim2.fromOffset(64, 64), Position = UDim2.new(1, -90, 1, -260), BackgroundColor3 = ACC,
	BackgroundTransparency = 0.15, Text = "DASH", TextColor3 = WHITE, Font = Enum.Font.GothamBlack, TextSize = 14,
	AutoButtonColor = false,
}, gui)
corner(dashBtn, 32)
mk("UIStroke", { Color = WHITE, Transparency = 0.6, Thickness = 1.5 }, dashBtn)
makeDraggable(dashBtn, dashBtn, doDash)
RS.Heartbeat:Connect(function() dashBtn.Visible = cfg.dash end)

UIS.InputBegan:Connect(function(i, gp)
	if not gp and i.KeyCode == Enum.KeyCode.C then doDash() end
end)

-- ===== Уведомления о появлении сущностей =====
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
onRooms(function(rooms) rooms.DescendantAdded:Connect(onSpawn) end)

workspace.ChildAdded:Connect(function(c)
	if THREATS[c.Name] then
		task.wait()
		addESP(c, "ent")
		refreshESP()
	end
end)

-- Запуск отложенных хуков, когда CurrentRooms появится (меню при этом уже готово)
task.spawn(function()
	local rooms = workspace:WaitForChild("CurrentRooms")
	for _, fn in ipairs(roomsHooks) do
		local ok, err = pcall(fn, rooms)
		if not ok then warn("[Huy Hub Doors] hook error: " .. tostring(err)) end
	end
end)

refreshESP()
print("[Huy Hub Doors] loaded")
notify("Huy Hub Doors loaded", Color3.fromRGB(80, 220, 120))
