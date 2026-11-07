local Players = game:GetService('Players')
local Workspace = game:GetService('Workspace')
local Lighting = game:GetService('Lighting')
local RunService = game:GetService('RunService')
local VirtualUser = game:GetService('VirtualUser')
local S
local teardown = {}

if typeof(STATE) == 'table' then
    S = STATE
else
    S = {
        _alive = true,
        alive = function()
            return S._alive
        end,
        onCleanup = function(fn)
            teardown[#teardown + 1] = fn
        end,
        connect = function(signal, fn)
            local conn = signal:Connect(fn)

            teardown[#teardown + 1] = function()
                conn:Disconnect()
            end

            return conn
        end,
    }
end

local LocalPlayer = Players.LocalPlayer

while not LocalPlayer do
    task.wait(0.05)

    LocalPlayer = Players.LocalPlayer
end

local G = (typeof(getgenv) == 'function' and getgenv()) or _G
local SCRIPT_VERSION = '2.7'

G.KILLALL_UI = {
    version = SCRIPT_VERSION,
    loaded = true,
    history = {},
}

local Config = {
    IncludeSelf = false,
    BanishAfterSeconds = 2,
    BarDrainSeconds = 0.5,
    AfkSeconds = 600,
    CollapsedHeight = 172,
    ExpandedHeight = 404,
}
local zeroedHumanoids = {}
local banished = {}
local healthBars = {}
local LastResult = {killed = 0}
local casualtyFolder = Instance.new('Folder')

casualtyFolder.Name = 'Casualties'
casualtyFolder.Parent = Lighting

local function findHumanoid(character)
    return character:FindFirstChildOfClass('Humanoid')
end

S.connect(RunService.Heartbeat, function()
    for humanoid in pairs(zeroedHumanoids)do
        if humanoid.Parent == nil then
            zeroedHumanoids[humanoid] = nil
        else
            humanoid.Health = 0
        end
    end
end)

local BAR_SHELL = Color3.fromRGB(10, 10, 10)
local BAR_GREEN = Color3.fromRGB(52, 208, 62)
local BAR_RED = Color3.fromRGB(214, 48, 49)
local BAR_DEAD_SHELL = Color3.fromRGB(58, 14, 16)

local function lerpColor(a, b, t)
    return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
end
local function findNameTag(character)
    local head = character:FindFirstChild('Head')
    local tag = head and head:FindFirstChild('NameTag')

    if tag then
        return tag
    end

    return character:FindFirstChild('NameTag', true)
end
local function displayName(player)
    local character = player.Character
    local tag = character and findNameTag(character)
    local label = tag and tag:FindFirstChild('NameLabel', true)

    if label and label.Text ~= '' then
        return label.Text
    end

    return player.Name
end
local function ensureBar(character)
    local existing = healthBars[character]

    if existing and existing.Parent then
        return existing
    end

    local tag = findNameTag(character)

    if not tag then
        return nil
    end

    local shell = Instance.new('Frame')

    shell.Name = 'HealthBar'
    shell.Size = UDim2.new(1, -10, 0, 8)
    shell.Position = UDim2.new(0, 5, 1, -3)
    shell.BackgroundColor3 = BAR_SHELL
    shell.BorderSizePixel = 0

    local shellCorner = Instance.new('UICorner')

    shellCorner.CornerRadius = UDim.new(0, 4)
    shellCorner.Parent = shell

    local fill = Instance.new('Frame')

    fill.Name = 'Fill'
    fill.ZIndex = 2
    fill.Size = UDim2.new(1, -2, 1, -2)
    fill.Position = UDim2.new(0, 1, 0, 1)
    fill.BackgroundColor3 = BAR_GREEN
    fill.BorderSizePixel = 0

    local fillCorner = Instance.new('UICorner')

    fillCorner.CornerRadius = UDim.new(0, 3)
    fillCorner.Parent = fill

    local leftCap = Instance.new('Frame')

    leftCap.Name = 'LeftCap'
    leftCap.ZIndex = 3
    leftCap.Size = UDim2.new(0, 2, 1, -2)
    leftCap.Position = UDim2.new(0, 2, 0, 1)
    leftCap.BackgroundColor3 = BAR_SHELL
    leftCap.BorderSizePixel = 0

    local rightCap = Instance.new('Frame')

    rightCap.Name = 'RightCap'
    rightCap.ZIndex = 3
    rightCap.Size = UDim2.new(0, 2, 1, -2)
    rightCap.Position = UDim2.new(1, -4, 0, 1)
    rightCap.BackgroundColor3 = BAR_SHELL
    rightCap.BorderSizePixel = 0
    fill.Parent = shell
    leftCap.Parent = shell
    rightCap.Parent = shell
    shell.Parent = tag
    healthBars[character] = shell

    return shell
end
local function drainBar(character)
    local shell = ensureBar(character)

    if not shell then
        return
    end

    local fill = shell:FindFirstChild('Fill')
    local steps = 12

    task.spawn(function()
        for i = 1, steps do
            if not shell.Parent then
                return
            end

            local t = i / steps

            fill.Size = UDim2.new(1 - t, -2, 1, -2)
            fill.BackgroundColor3 = lerpColor(BAR_GREEN, BAR_RED, t)

            task.wait(Config.BarDrainSeconds / steps)
        end

        fill.Size = UDim2.new(0, 0, 1, -2)
        shell.BackgroundColor3 = BAR_DEAD_SHELL
    end)
end
local function stopVictimEffects(character)
    local humanoid = findHumanoid(character)

    if humanoid then
        zeroedHumanoids[humanoid] = nil
    end
end
local function banish(character)
    if character.Parent == casualtyFolder then
        return
    end

    stopVictimEffects(character)

    banished[#banished + 1] = {
        character = character,
        parent = character.Parent or Workspace,
    }
    character.Parent = casualtyFolder
end
local function killCharacter(character)
    local humanoid = findHumanoid(character)

    if not humanoid then
        return false
    end

    zeroedHumanoids[humanoid] = true

    drainBar(character)
    task.spawn(function()
        task.wait(Config.BanishAfterSeconds)
        banish(character)
    end)

    return true
end
local function killAll()
    local killed = 0

    for _, player in ipairs(Players:GetPlayers())do
        if player ~= LocalPlayer or Config.IncludeSelf then
            local character = player.Character

            if character and killCharacter(character) then
                killed += 1
            end
        end
    end

    LastResult.killed = killed
    G.KILLALL_UI.history[#G.KILLALL_UI.history + 1] = LastResult

    return killed
end
local function restoreAll()
    table.clear(zeroedHumanoids)

    for _, entry in ipairs(banished)do
        pcall(function()
            entry.character.Parent = entry.parent
        end)
    end

    table.clear(banished)

    for character in pairs(healthBars)do
        local bar = healthBars[character]

        if bar then
            bar:Destroy()
        end

        healthBars[character] = nil
    end

    table.clear(healthBars)
end

local afkEnabled = true
local afkPings = 0
local afkErrors = {}
local afkShape = nil
local shieldHits = 0
local clickShield
local afkShapes = {
    {
        name = 'vector2',
        run = function()
            local at = Vector2.new(1, 1)

            VirtualUser:Button1Down(at)
            VirtualUser:Button1Up(at)
        end,
    },
    {
        name = 'noarg',
        run = function()
            VirtualUser:Button1Down()
            VirtualUser:Button1Up()
        end,
    },
    {
        name = 'number',
        run = function()
            VirtualUser:Button1Down(0)
            VirtualUser:Button1Up(0)
        end,
    },
}

local function noteAfkError(msg)
    if #afkErrors < 24 then
        afkErrors[#afkErrors + 1] = msg
    end
end
local function afkPing()
    if not afkEnabled then
        return false
    end

    afkPings += 1

    if not clickShield then
        noteAfkError('no click shield, ping skipped')

        return false
    end

    local before = shieldHits

    clickShield.Visible = true

    local worked

    if afkShape then
        worked = pcall(afkShape.run)
    else
        for _, shape in ipairs(afkShapes)do
            local ok, err = pcall(shape.run)

            if ok then
                afkShape = shape
                worked = true

                break
            end

            noteAfkError(shape.name .. ': ' .. tostring(err))
        end
    end
    if not worked then
        noteAfkError('all Button1Down shapes rejected')
    end

    task.delay(0.12, function()
        if clickShield and clickShield.Parent then
            clickShield.Visible = false
        end
    end)

    return worked, shieldHits > before
end
local function startAfkKeeper()
    S.connect(LocalPlayer.Idled, afkPing)
    task.spawn(function()
        while S.alive() do
            task.wait(Config.AfkSeconds)

            if S.alive() then
                afkPing()
            end
        end
    end)
end

local gui = Instance.new('ScreenGui')

gui.Name = 'KillAllUi'
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 200
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = LocalPlayer:WaitForChild('PlayerGui')
clickShield = Instance.new('TextButton')
clickShield.Name = 'ClickShield'
clickShield.Size = UDim2.fromScale(1, 1)
clickShield.Position = UDim2.new()
clickShield.ZIndex = 100
clickShield.BackgroundColor3 = Color3.new(0, 0, 0)
clickShield.BackgroundTransparency = 1
clickShield.Text = ''
clickShield.TextTransparency = 1
clickShield.AutoButtonColor = false
clickShield.Visible = false
clickShield.Parent = gui

S.connect(clickShield.MouseButton1Down, function()
    shieldHits += 1
end)

local function corner(parent, radius)
    local uicorner = Instance.new('UICorner')

    uicorner.CornerRadius = UDim.new(0, radius)
    uicorner.Parent = parent

    return uicorner
end

local card = Instance.new('Frame')

card.Size = UDim2.new(0, 300, 0, Config.CollapsedHeight)
card.Position = UDim2.new(0, 24, 0, 100)
card.BackgroundColor3 = Color3.fromRGB(16, 18, 22)
card.BorderSizePixel = 0
card.Active = true
card.Draggable = true

corner(card, 12)

card.Parent = gui

local cardStroke = Instance.new('UIStroke')

cardStroke.Color = Color3.fromRGB(58, 64, 76)
cardStroke.Thickness = 1
cardStroke.Transparency = 0.35
cardStroke.Parent = card

local accent = Instance.new('Frame')

accent.Size = UDim2.new(0, 3, 0, 26)
accent.Position = UDim2.new(0, 14, 0, 14)
accent.BackgroundColor3 = Color3.fromRGB(226, 74, 90)
accent.BorderSizePixel = 0

corner(accent, 2)

accent.Parent = card

local title = Instance.new('TextLabel')

title.Size = UDim2.new(1, -42, 0, 26)
title.Position = UDim2.new(0, 28, 0, 14)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Color3.fromRGB(240, 242, 246)
title.Text = 'Kill all'
title.Parent = card

local button = Instance.new('TextButton')

button.Size = UDim2.new(1, -28, 0, 38)
button.Position = UDim2.new(0, 14, 0, 46)
button.BackgroundColor3 = Color3.fromRGB(226, 74, 90)
button.AutoButtonColor = false
button.Text = ''
button.BorderSizePixel = 0

corner(button, 9)

button.Parent = card

local buttonLabel = Instance.new('TextLabel')

buttonLabel.Size = UDim2.new(1, 0, 1, 0)
buttonLabel.BackgroundTransparency = 1
buttonLabel.Font = Enum.Font.GothamBold
buttonLabel.TextSize = 14
buttonLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
buttonLabel.Text = 'Kill all'
buttonLabel.Parent = button

local buttonStroke = Instance.new('UIStroke')

buttonStroke.Color = Color3.fromRGB(255, 255, 255)
buttonStroke.Transparency = 0.88
buttonStroke.Thickness = 1
buttonStroke.Parent = button

local status = Instance.new('TextLabel')

status.Size = UDim2.new(1, -28, 0, 18)
status.Position = UDim2.new(0, 14, 0, 88)
status.BackgroundTransparency = 1
status.Font = Enum.Font.Code
status.TextSize = 11
status.TextTruncate = Enum.TextTruncate.AtEnd
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextColor3 = Color3.fromRGB(108, 116, 130)
status.Text = 'ready'
status.Parent = card

local panel = Instance.new('Frame')

panel.Name = 'RosterPanel'
panel.Size = UDim2.new(1, -28, 0, 232)
panel.Position = UDim2.new(0, 14, 0, 146)
panel.BackgroundTransparency = 1
panel.BorderSizePixel = 0
panel.Visible = false
panel.ClipsDescendants = true
panel.Parent = card

local searchBox = Instance.new('TextBox')

searchBox.Name = 'Search'
searchBox.Size = UDim2.new(1, -6, 0, 28)
searchBox.Position = UDim2.new(0, 3, 0, 0)
searchBox.BackgroundColor3 = Color3.fromRGB(25, 28, 34)
searchBox.BorderSizePixel = 0
searchBox.Font = Enum.Font.Gotham
searchBox.TextSize = 13
searchBox.TextColor3 = Color3.fromRGB(224, 228, 235)
searchBox.PlaceholderText = 'Search name or username'
searchBox.PlaceholderColor3 = Color3.fromRGB(96, 104, 118)
searchBox.ClearTextOnFocus = false
searchBox.Text = ''

corner(searchBox, 6)

searchBox.Parent = panel

local listFrame = Instance.new('ScrollingFrame')

listFrame.Name = 'PlayerList'
listFrame.Size = UDim2.new(1, -6, 0, 198)
listFrame.Position = UDim2.new(0, 3, 0, 33)
listFrame.BackgroundTransparency = 1
listFrame.BorderSizePixel = 0
listFrame.ScrollBarThickness = 4
listFrame.ScrollBarImageColor3 = Color3.fromRGB(90, 98, 112)
listFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
listFrame.CanvasSize = UDim2.new()
listFrame.Parent = panel

local listLayout = Instance.new('UIListLayout')

listLayout.Padding = UDim.new(0, 3)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = listFrame

local listPadding = Instance.new('UIPadding')

listPadding.PaddingBottom = UDim.new(0, 2)
listPadding.Parent = listFrame

local function killOne(player)
    local character = player.Character

    if not character then
        return false
    end

    local done = killCharacter(character)

    if done then
        status.Text = 'down: ' .. player.Name
    end

    return done
end

local rowLabels = {}

local function makeRow(player, order, label)
    local row = Instance.new('Frame')

    row.Name = 'row'
    row.Size = UDim2.new(1, -6, 0, 24)
    row.BackgroundColor3 = Color3.fromRGB(25, 28, 34)
    row.BorderSizePixel = 0
    row.LayoutOrder = order

    corner(row, 6)

    row.Parent = listFrame

    local nameLabel = Instance.new('TextLabel')

    nameLabel.Size = UDim2.new(1, -54, 1, 0)
    nameLabel.Position = UDim2.new(0, 8, 0, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Font = Enum.Font.Gotham
    nameLabel.TextSize = 12
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    nameLabel.TextColor3 = Color3.fromRGB(214, 219, 227)
    nameLabel.Text = label
    nameLabel.Parent = row
    rowLabels[player] = nameLabel

    if player ~= LocalPlayer then
        local kill = Instance.new('TextButton')

        kill.Size = UDim2.new(0, 44, 0, 16)
        kill.Position = UDim2.new(1, -48, 0.5, -8)
        kill.BackgroundColor3 = Color3.fromRGB(226, 74, 90)
        kill.Text = 'kill'
        kill.Font = Enum.Font.GothamBold
        kill.TextSize = 11
        kill.TextColor3 = Color3.fromRGB(255, 255, 255)
        kill.BorderSizePixel = 0

        corner(kill, 5)

        kill.Parent = row

        S.connect(kill.Activated, function()
            killOne(player)
        end)
    end

    return row
end

local toggleHeader
local expanded = false
local shownCount = 0

local function rebuildList()
    for _, child in ipairs(listFrame:GetChildren())do
        if child:IsA('Frame') then
            child:Destroy()
        end
    end

    table.clear(rowLabels)

    local query = searchBox.Text:lower()
    local present = Players:GetPlayers()
    local sortKeys = {}
    local labels = {}

    for _, player in ipairs(present)do
        local label = displayName(player) .. ' [' .. player.Name .. ']'

        labels[player] = label
        sortKeys[player] = label:lower()
    end

    table.sort(present, function(a, b)
        return sortKeys[a] < sortKeys[b]
    end)

    shownCount = 0

    for _, player in ipairs(present)do
        local label = labels[player]

        if query == '' or sortKeys[player]:find(query, 1, true) then
            shownCount += 1

            makeRow(player, shownCount, label)
        end
    end

    toggleHeader.Text = string.format('PLAYERS  %d/%d  %s', shownCount, #present, expanded and 'v' or '>')
end

toggleHeader = Instance.new('TextButton')
toggleHeader.Name = 'RosterToggle'
toggleHeader.Size = UDim2.new(1, -28, 0, 28)
toggleHeader.Position = UDim2.new(0, 14, 0, 112)
toggleHeader.BackgroundColor3 = Color3.fromRGB(25, 28, 34)
toggleHeader.BorderSizePixel = 0
toggleHeader.Font = Enum.Font.GothamBold
toggleHeader.TextSize = 12
toggleHeader.TextColor3 = Color3.fromRGB(146, 154, 168)
toggleHeader.TextXAlignment = Enum.TextXAlignment.Left
toggleHeader.Text = 'PLAYERS  0/0  >'

corner(toggleHeader, 6)

toggleHeader.Parent = card

local function setExpanded(state)
    expanded = state
    panel.Visible = state
    card.Size = UDim2.new(0, 300, 0, state and Config.ExpandedHeight or Config.CollapsedHeight)

    rebuildList()
end

S.connect(toggleHeader.Activated, function()
    setExpanded(not expanded)
end)
S.connect(searchBox:GetPropertyChangedSignal('Text'), rebuildList)
S.connect(Players.PlayerAdded, function()
    task.defer(rebuildList)
end)
S.connect(Players.PlayerRemoving, function()
    task.defer(rebuildList)
end)
S.connect(LocalPlayer.CharacterAdded, function()
    task.defer(rebuildList)
end)

local refreshAccum = 0
local lastCount = -1

S.connect(RunService.Heartbeat, function(dt)
    refreshAccum += dt

    if refreshAccum < 2 then
        return
    end

    refreshAccum = 0

    local count = #Players:GetPlayers()

    if count ~= lastCount then
        lastCount = count

        rebuildList()

        return
    end

    for player, label in pairs(rowLabels)do
        if label.Parent and player.Parent then
            local want = displayName(player) .. ' [' .. player.Name .. ']'

            if label.Text ~= want then
                label.Text = want
            end
        end
    end
end)

local credit = Instance.new('TextLabel')

credit.Size = UDim2.new(1, -28, 0, 16)
credit.Position = UDim2.new(0, 14, 1, -20)
credit.BackgroundTransparency = 1
credit.Font = Enum.Font.Gotham
credit.TextSize = 10
credit.TextColor3 = Color3.fromRGB(92, 99, 112)
credit.Text = 'Made by u/Both-Ad6752 for u/ShortPresentation679'
credit.Parent = card

local buttonBase = Color3.fromRGB(226, 74, 90)
local buttonHover = Color3.fromRGB(240, 96, 110)

S.connect(button.MouseEnter, function()
    button.BackgroundColor3 = buttonHover
    buttonStroke.Transparency = 0.72
end)
S.connect(button.MouseLeave, function()
    button.BackgroundColor3 = buttonBase
    buttonStroke.Transparency = 0.88
end)

local busy = false

S.connect(button.Activated, function()
    if busy then
        return
    end

    busy = true
    status.Text = 'working'

    task.spawn(function()
        local ok, count = pcall(killAll)

        busy = false

        if ok then
            status.Text = string.format('%d down', count or 0)
        else
            status.Text = 'error'
        end
    end)
end)
rebuildList()
task.spawn(function()
    local tries = 0

    while#Players:GetPlayers() < 2 and tries < 60 and S.alive() do
        task.wait(0.5)

        tries += 1
    end

    rebuildList()
end)
startAfkKeeper()

G.KILLALL_UI.run = killAll
G.KILLALL_UI.killOne = killOne
G.KILLALL_UI.rebuild = rebuildList
G.KILLALL_UI.setExpanded = setExpanded
G.KILLALL_UI.restore = restoreAll
G.KILLALL_UI.preview = function(drain)
    local n = 0

    for _, player in ipairs(Players:GetPlayers())do
        if player ~= LocalPlayer or Config.IncludeSelf then
            local character = player.Character

            if character and ensureBar(character) then
                if drain then
                    drainBar(character)
                end

                n += 1
            end
        end
    end

    return n
end
G.KILLALL_UI.pingAfk = afkPing
G.KILLALL_UI.setAfk = function(enabled)
    afkEnabled = enabled

    return afkEnabled
end
G.KILLALL_UI.status = function()
    local errors = {}

    for _, e in ipairs(afkErrors)do
        errors[#errors + 1] = e
    end

    local zeroed = 0

    for _ in pairs(zeroedHumanoids)do
        zeroed += 1
    end

    return {
        version = SCRIPT_VERSION,
        killed = LastResult.killed,
        zeroed = zeroed,
        banished = #banished,
        shown = shownCount,
        expanded = expanded,
        query = searchBox.Text,
        afkEnabled = afkEnabled,
        afkPings = afkPings,
        afkShape = afkShape and afkShape.name or 'unresolved',
        shieldHits = shieldHits,
        afkErrors = table.concat(errors, ' | '),
    }
end

local function runTeardown()
    S._alive = false

    restoreAll()

    for _, fn in ipairs(teardown)do
        pcall(fn)
    end

    table.clear(teardown)
    casualtyFolder:Destroy()
    gui:Destroy()
end

S.onCleanup(runTeardown)

G.KILLALL_UI.teardown = runTeardown
