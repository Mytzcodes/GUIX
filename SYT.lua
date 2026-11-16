--!nocheck
--[[
    SYT.lua — Unified R&8_DV Frontend + Full Backend Logic (Single Script)
    Template GUI: https://raw.githubusercontent.com/Mytzcodes/R-8/refs/heads/main/Sample%20Gui/SampleGui.lua
    Framework   : https://raw.githubusercontent.com/Mytzcodes/R-8/refs/heads/main/r%268_dv.lua

    Fitur Lengkap Terintegrasi (SYT):
      - Overview         : Telemetry dunia & posisi real-time, daftar player world, Kontrol Sesi & Theme & FPS Boost
      - Teleport & Map   : Manual TP validasi, Walk-Path Safe, Step TP, Gap TP, Peta World 2D Interaktif
      - Misc             : Fly (Anti-BasePath & High Altitude), Seems, Fast Roulette, No Clip, God Mode, Auto Follow, Auto Collect
      - PNB              : Visual Backpack Selector, 5x5 Tile Pad, Unified Speed Ratio (1x-10x), 1-Hit (Equip .dig Gear), Phase Verify
      - Auto Pabrik      : Visual Backpack/Seed Pair, Map Tile & Connected Line (-----) Selector, BreakPos 1-3 Tile Head Pad
      - Dirt Farm (DF)   : Auto Break & Ubah ke Dirt (Skip Door/Bedrock/Locks), Pola Kelipatan 2, Rotation World Otomatis
      - Visualisasi      : Custom In-Game Name, Roles Lengkap + Effects, Title, Lock
      - Spam & ULTIMAX   : Input Spam, Color Prefix / Cycle, Whisper All, ULTIMAX Anti-Kick & Anti-Ban Firewall + [GETC SKIPER]
]]

-- 1. LOAD R&8_DV IMGUI FRAMEWORK (INSTANT BOOT + CLEAN MULTI-ROOT MANAGEMENT)
local cachedR8Source = nil
local cachedR8Loader = nil

local function getAllGuiRoots()
    local roots, seen = {}, {}
    local function pushRoot(inst)
        if typeof(inst) == "Instance" and not seen[inst] then
            seen[inst] = true
            table.insert(roots, inst)
        end
    end
    if type(gethui) == "function" then
        local okH, h = pcall(gethui)
        if okH then pushRoot(h) end
    end
    local okCg, cg = pcall(game.GetService, game, "CoreGui")
    if okCg then pushRoot(cg) end
    local okPl, plrs = pcall(game.GetService, game, "Players")
    local lp = okPl and plrs and plrs.LocalPlayer
    if lp then
        pushRoot(lp:FindFirstChildOfClass("PlayerGui"))
    end
    return roots
end

local function cleanupSYTGuiContainers(keepScreenGui)
    local env = (type(getgenv) == "function" and select(2, pcall(getgenv))) or _G
    if type(env) == "table" then
        if env.__SYT_BOOT_LOADER then
            pcall(function() env.__SYT_BOOT_LOADER:Destroy() end)
            env.__SYT_BOOT_LOADER = nil
        end
        if env.__SYT_ACTIVE_UI then
            local prevSg = env.__SYT_ACTIVE_UI.ScreenGui
            if not keepScreenGui or prevSg ~= keepScreenGui then
                pcall(function() env.__SYT_ACTIVE_UI:Destroy() end)
                env.__SYT_ACTIVE_UI = nil
            end
        end
        if env.__R8_DV_ACTIVE_UI then
            local prevR8 = env.__R8_DV_ACTIVE_UI.ScreenGui
            if not keepScreenGui or prevR8 ~= keepScreenGui then
                pcall(function() env.__R8_DV_ACTIVE_UI:Destroy() end)
                env.__R8_DV_ACTIVE_UI = nil
            end
        end
    end
    for _, root in ipairs(getAllGuiRoots()) do
        pcall(function()
            for _, child in ipairs(root:GetChildren()) do
                if child:IsA("ScreenGui") and child ~= keepScreenGui then
                    local nm = child.Name or ""
                    if nm == "SYT_BootLoader" or string.sub(nm, 1, 13) == "R8_DV_Engine_" then
                        pcall(function() child:Destroy() end)
                    end
                end
            end
        end)
    end
end

local function patchR8FrameworkSource(raw)
    if type(raw) ~= "string" or raw == "" then return raw end
    local patched = raw
    -- V2: Ubah Dropdown ListHolder menjadi ScrollingFrame agar panjang dropdown ter-scroll rapi
    patched = string.gsub(
        patched,
        'local ListHolder = Instance%.new%("Frame"%)%s*\n(%s*)ListHolder%.Size = UDim2%.new%(1, 0, 0, 0%)',
        'local ListHolder = Instance.new("ScrollingFrame")\n%1ListHolder.Size = UDim2.new(1, 0, 0, 0)\n%1ListHolder.CanvasSize = UDim2.new(0, 0, 0, 0)\n%1ListHolder.AutomaticCanvasSize = Enum.AutomaticSize.Y\n%1ListHolder.ScrollBarThickness = 4\n%1ListHolder.ScrollBarImageColor3 = Color3.fromRGB(130, 145, 170)\n%1ListHolder.ScrollingEnabled = true'
    )
    patched = string.gsub(
        patched,
        'local targetHeight = %(#options %* 38%) %+ %(math%.max%(#options %- 1, 0%) %* 6%) %+ 16',
        'local function calcDropTargetHeight(cnt)\n                local fullHeight = (cnt * 38) + (math.max(cnt - 1, 0) * 6) + 16\n                return math.min(fullHeight, 172)\n            end\n            local targetHeight = calcDropTargetHeight(#options)'
    )
    patched = string.gsub(
        patched,
        '(%s*)for i, opt in ipairs%(options%) do',
        '%1local function RebuildDropdownOpts(newList)\n%1    options = (type(newList) == "table" and #newList > 0) and newList or {"Default"}\n%1    targetHeight = calcDropTargetHeight(#options)\n%1    for _, entry in ipairs(OptionRows) do\n%1        if entry.Btn and entry.Btn.Parent then entry.Btn:Destroy() end\n%1    end\n%1    OptionRows = {}\n%1    for i, opt in ipairs(options) do'
    )
    patched = string.gsub(
        patched,
        '(%s*)RegisterThemeUpdater%(ListHolder, function%(%) RefreshOptionsVisual%(%) end%)',
        '%1end\n%1RebuildDropdownOpts(options)\n%1Self._DropRefresh = Self._DropRefresh or {}\n%1Self._DropRefresh[flag] = function(newList)\n%1    RebuildDropdownOpts(newList)\n%1    RefreshOptionsVisual()\n%1    if isOpen then SmoothTween(ListHolder, 0.14, {Size = UDim2.new(1, 0, 0, targetHeight)}) end\n%1end\n%1RegisterThemeUpdater(ListHolder, function() RefreshOptionsVisual() end)'
    )
    -- System: ekspos ScreenGui & MainWindow pada Self tanpa delay StartHidden kecuali diminta eksplisit
    patched = string.gsub(
        patched,
        'ScreenGui%.Parent = SafeParent',
        'Self.ScreenGui = ScreenGui\n    Self.SafeGuiParent = SafeParent\n    if config.StartHidden == true then ScreenGui.Enabled = false end\n    ScreenGui.Parent = SafeParent'
    )
    patched = string.gsub(
        patched,
        'MainWindow%.Parent = ScreenGui',
        'Self.MainWindow = MainWindow\n    MainWindow.Parent = ScreenGui'
    )
    -- V4 Layout Fix: Sidebar ringkas agar seluruh 8 fitur muncul langsung tanpa terpotong di PC maupun Mobile
    patched = string.gsub(
        patched,
        'LogoHolder%.Size = UDim2%.new%(1, 0, 0, 138%)',
        'LogoHolder.Size = UDim2.new(1, 0, 0, 78)'
    )
    patched = string.gsub(
        patched,
        'BrandLogo%.Size = UDim2%.fromOffset%(58, 58%)%s*\n(%s*)BrandLogo%.Position = UDim2%.new%(0%.5, 0, 0, 36%)',
        'BrandLogo.Size = UDim2.fromOffset(32, 32)\n%1BrandLogo.Position = UDim2.new(0.5, 0, 0, 16)'
    )
    patched = string.gsub(
        patched,
        'fallbackCrest%.Position = UDim2%.new%(0%.5, 0, 0, 36%)',
        'fallbackCrest.Position = UDim2.new(0.5, 0, 0, 16)'
    )
    patched = string.gsub(
        patched,
        'BrandMainTitle%.Size = UDim2%.new%(1, %-20, 0, 28%)%s*\n(%s*)BrandMainTitle%.Position = UDim2%.new%(0, 10, 0, 72%)%s*\n(%s*)BrandMainTitle%.BackgroundTransparency = 1%s*\n(%s*)BrandMainTitle%.Font = Enum%.Font%.GothamBlack%s*\n(%s*)BrandMainTitle%.TextSize = 22',
        'BrandMainTitle.Size = UDim2.new(1, -20, 0, 20)\n%1BrandMainTitle.Position = UDim2.new(0, 10, 0, 35)\n%2BrandMainTitle.BackgroundTransparency = 1\n%3BrandMainTitle.Font = Enum.Font.GothamBlack\n%4BrandMainTitle.TextSize = 16'
    )
    patched = string.gsub(
        patched,
        'BrandSubLbl%.Size = UDim2%.new%(1, %-20, 0, 18%)%s*\n(%s*)BrandSubLbl%.Position = UDim2%.new%(0, 10, 0, 102%)%s*\n(%s*)BrandSubLbl%.BackgroundTransparency = 1%s*\n(%s*)BrandSubLbl%.Font = Enum%.Font%.GothamBold%s*\n(%s*)BrandSubLbl%.TextSize = 13',
        'BrandSubLbl.Size = UDim2.new(1, -20, 0, 14)\n%1BrandSubLbl.Position = UDim2.new(0, 10, 0, 56)\n%2BrandSubLbl.BackgroundTransparency = 1\n%3BrandSubLbl.Font = Enum.Font.GothamBold\n%4BrandSubLbl.TextSize = 10'
    )
    patched = string.gsub(
        patched,
        'NavDivider%.Position = UDim2%.new%(0, 12, 0, 130%)',
        'NavDivider.Position = UDim2.new(0, 12, 0, 74)'
    )
    patched = string.gsub(
        patched,
        'local NavScroll = Instance%.new%("ScrollingFrame"%)%s*\n%s*NavScroll%.Position = UDim2%.new%(0, 12, 0, 138%)%s*\n%s*NavScroll%.Size = UDim2%.new%(1, %-24, 1, %-216%)%s*\n%s*NavScroll%.BackgroundTransparency = 1%s*\n%s*NavScroll%.BorderSizePixel = 0%s*\n%s*NavScroll%.ScrollBarThickness = 2%s*\n%s*NavScroll%.AutomaticCanvasSize = Enum%.AutomaticSize%.Y%s*\n%s*NavScroll%.CanvasSize = UDim2%.new%(0, 0, 0, 0%)%s*\n%s*NavScroll%.Parent = LeftSidebar%s*\n%s*BindTheme%(NavScroll, "ScrollBarImageColor3", "Accent"%)%s*\n%s*local NavPad = Instance%.new%("UIPadding"%)%s*\n%s*NavPad%.PaddingTop = UDim%.new%(0, 4%)%s*\n%s*NavPad%.PaddingLeft = UDim%.new%(0, 2%)%s*\n%s*NavPad%.PaddingRight = UDim%.new%(0, 4%)%s*\n%s*NavPad%.PaddingBottom = UDim%.new%(0, 12%)%s*\n%s*NavPad%.Parent = NavScroll%s*\n%s*local NavLayout = Instance%.new%("UIListLayout"%)%s*\n%s*NavLayout%.Padding = UDim%.new%(0, 8%)%s*\n%s*NavLayout%.SortOrder = Enum%.SortOrder%.LayoutOrder%s*\n%s*NavLayout%.Parent = NavScroll',
        'local NavScroll = Instance.new("ScrollingFrame")\n    NavScroll.Position = UDim2.new(0, 12, 0, 79)\n    NavScroll.Size = UDim2.new(1, -24, 1, -153)\n    NavScroll.BackgroundTransparency = 1\n    NavScroll.BorderSizePixel = 0\n    NavScroll.ClipsDescendants = true\n    NavScroll.ScrollingEnabled = true\n    NavScroll.ScrollingDirection = Enum.ScrollingDirection.Y\n    NavScroll.ScrollBarThickness = 4\n    NavScroll.AutomaticCanvasSize = Enum.AutomaticSize.None\n    NavScroll.CanvasSize = UDim2.new(0, 0, 0, 320)\n    NavScroll.Parent = LeftSidebar\n    BindTheme(NavScroll, "ScrollBarImageColor3", "Accent")\n    local NavPad = Instance.new("UIPadding")\n    NavPad.PaddingTop = UDim.new(0, 2)\n    NavPad.PaddingLeft = UDim.new(0, 2)\n    NavPad.PaddingRight = UDim.new(0, 4)\n    NavPad.PaddingBottom = UDim.new(0, 6)\n    NavPad.Parent = NavScroll\n    local NavLayout = Instance.new("UIListLayout")\n    NavLayout.Padding = UDim.new(0, 3)\n    NavLayout.SortOrder = Enum.SortOrder.LayoutOrder\n    NavLayout.Parent = NavScroll\n    local function SyncNavCanvas()\n        local sc = (WindowScale and WindowScale.Scale > 0.1) and WindowScale.Scale or 1\n        local estH = 10\n        local cnt = 0\n        for _, ch in ipairs(NavScroll:GetChildren()) do\n            if ch:IsA("GuiObject") then\n                estH = estH + ch.Size.Y.Offset\n                cnt = cnt + 1\n            end\n        end\n        if cnt > 1 then estH = estH + (cnt - 1) * 3 end\n        local absH = math.ceil(NavLayout.AbsoluteContentSize.Y / sc) + 12\n        NavScroll.CanvasSize = UDim2.fromOffset(0, math.max(estH, absH))\n    end\n    Self.LeftSidebar = LeftSidebar\n    Self.NavScroll = NavScroll\n    Self.SyncNavCanvas = SyncNavCanvas\n    TrackConn(NavLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(SyncNavCanvas))\n    TrackConn(NavScroll.ChildAdded:Connect(function() task.defer(SyncNavCanvas) end))\n    TrackConn(WindowScale:GetPropertyChangedSignal("Scale"):Connect(function() task.defer(SyncNavCanvas) end))'
    )
    patched = string.gsub(
        patched,
        'local function CreateScrollPage%(parent%)%s*\n%s*local Page = Instance%.new%("ScrollingFrame"%)%s*\n%s*Page%.Size = UDim2%.fromScale%(1, 1%)%s*\n%s*Page%.BackgroundTransparency = 1%s*\n%s*Page%.BorderSizePixel = 0%s*\n%s*Page%.ScrollBarThickness = 3%s*\n%s*Page%.AutomaticCanvasSize = Enum%.AutomaticSize%.Y%s*\n%s*Page%.CanvasSize = UDim2%.new%(0, 0, 0, 0%)%s*\n%s*Page%.Visible = false%s*\n%s*Page%.Parent = parent%s*\n%s*BindTheme%(Page, "ScrollBarImageColor3", "Accent"%)%s*\n%s*local Pad = Instance%.new%("UIPadding"%)%s*\n%s*Pad%.PaddingTop = UDim%.new%(0, 16%)%s*\n%s*Pad%.PaddingBottom = UDim%.new%(0, 26%)%s*\n%s*Pad%.PaddingLeft = UDim%.new%(0, 16%)%s*\n%s*Pad%.PaddingRight = UDim%.new%(0, 20%)%s*\n%s*Pad%.Parent = Page%s*\n%s*local Layout = Instance%.new%("UIListLayout"%)%s*\n%s*Layout%.Padding = UDim%.new%(0, 14%)%s*\n%s*Layout%.SortOrder = Enum%.SortOrder%.LayoutOrder%s*\n%s*Layout%.Parent = Page%s*\n%s*return Page',
        'local function CreateScrollPage(parent)\n        local Page = Instance.new("ScrollingFrame")\n        Page.Size = UDim2.fromScale(1, 1)\n        Page.BackgroundTransparency = 1\n        Page.BorderSizePixel = 0\n        Page.ClipsDescendants = true\n        Page.ScrollingEnabled = true\n        Page.ScrollingDirection = Enum.ScrollingDirection.Y\n        Page.ScrollBarThickness = 4\n        Page.AutomaticCanvasSize = Enum.AutomaticSize.None\n        Page.CanvasSize = UDim2.new(0, 0, 0, 0)\n        Page.Visible = false\n        Page.Parent = parent\n        BindTheme(Page, "ScrollBarImageColor3", "Accent")\n        local Pad = Instance.new("UIPadding")\n        Pad.PaddingTop = UDim.new(0, 16)\n        Pad.PaddingBottom = UDim.new(0, 26)\n        Pad.PaddingLeft = UDim.new(0, 16)\n        Pad.PaddingRight = UDim.new(0, 20)\n        Pad.Parent = Page\n        local Layout = Instance.new("UIListLayout")\n        Layout.Padding = UDim.new(0, 14)\n        Layout.SortOrder = Enum.SortOrder.LayoutOrder\n        Layout.Parent = Page\n        local function SyncPageCanvas()\n            local sc = (WindowScale and WindowScale.Scale > 0.1) and WindowScale.Scale or 1\n            local absH = math.ceil(Layout.AbsoluteContentSize.Y / sc)\n            Page.CanvasSize = UDim2.fromOffset(0, math.max(0, absH + 46))\n        end\n        TrackConn(Layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(SyncPageCanvas))\n        TrackConn(Page.ChildAdded:Connect(function() task.defer(SyncPageCanvas) end))\n        TrackConn(Page:GetPropertyChangedSignal("Visible"):Connect(function()\n            if Page.Visible then task.defer(SyncPageCanvas) end\n        end))\n        TrackConn(WindowScale:GetPropertyChangedSignal("Scale"):Connect(function() task.defer(SyncPageCanvas) end))\n        return Page'
    )
    patched = string.gsub(
        patched,
        'function Self:Category%(catLabel%)%s*\n(%s*)local Lbl = Instance%.new%("TextLabel"%)%s*\n(%s*)Lbl%.Size = UDim2%.new%(1, %-12, 0, 28%)%s*\n(%s*)Lbl%.BackgroundTransparency = 1%s*\n(%s*)Lbl%.Font = Enum%.Font%.GothamBlack%s*\n(%s*)Lbl%.TextSize = 13',
        'function Self:Category(catLabel)\n%1local Lbl = Instance.new("TextLabel")\n%2Lbl.Size = UDim2.new(1, -12, 0, 18)\n%3Lbl.BackgroundTransparency = 1\n%4Lbl.Font = Enum.Font.GothamBlack\n%5Lbl.TextSize = 11'
    )
    patched = string.gsub(
        patched,
        'local NavBtn = Instance%.new%("TextButton"%)%s*\n(%s*)NavBtn%.Size = UDim2%.new%(1, 0, 0, 48%)',
        'local NavBtn = Instance.new("TextButton")\n%1NavBtn.Size = UDim2.new(1, 0, 0, 26)'
    )
    patched = string.gsub(
        patched,
        'NameLbl%.Font = Enum%.Font%.GothamBold%s*\n(%s*)NameLbl%.Text = name%s*\n(%s*)NameLbl%.TextSize = 17',
        'NameLbl.Font = Enum.Font.GothamBold\n%1NameLbl.Text = name\n%2NameLbl.TextSize = 13'
    )
    patched = string.gsub(
        patched,
        'table%.insert%(Self%.Features, FeatureObj%)',
        'table.insert(Self.Features, FeatureObj)\n        if type(Self.SyncNavCanvas) == "function" then Self.SyncNavCanvas() end'
    )
    patched = string.gsub(
        patched,
        'SyncRightPanelVisibility%(%)%s*\n(%s*)end%s*\n(%s*)return FeatureObj',
        'SyncRightPanelVisibility()\n%1    if type(Self.SyncNavCanvas) == "function" then task.defer(Self.SyncNavCanvas) end\n%1end\n%2return FeatureObj'
    )
    local extIcons = [==[
    elseif key == "system" or key == "security" then
        Outline(sizePx * 0.64, sizePx * 0.72, 0.5, 0.5, 5, 1.8)
        Bar(sizePx * 0.30, 2, 0.5, 0.46, 0, 1)
        Bar(2, sizePx * 0.34, 0.5, 0.50, 0, 1)
    elseif key == "spaming" or key == "spam" then
        Outline(sizePx * 0.72, sizePx * 0.54, 0.5, 0.45, 5, 1.8)
        Bar(sizePx * 0.36, 2, 0.5, 0.39, 0, 1)
        Bar(sizePx * 0.24, 2, 0.44, 0.52, 0, 1)
        Bar(sizePx * 0.18, 2, 0.33, 0.76, -35, 1)
    elseif key == "pnb" or key == "pickaxe" then
        Outline(sizePx * 0.40, sizePx * 0.40, 0.64, 0.66, 2, 1.7)
        Bar(sizePx * 0.52, 2.1, 0.40, 0.48, -45, 1)
        Bar(sizePx * 0.34, 2.4, 0.29, 0.29, 45, 1)
    elseif key == "pabrik" or key == "factory" then
        Outline(sizePx * 0.72, sizePx * 0.44, 0.5, 0.64, 2, 1.7)
        Bar(sizePx * 0.16, sizePx * 0.28, 0.28, 0.32, 0, 1)
        Bar(sizePx * 0.14, sizePx * 0.20, 0.50, 0.36, 0, 1)
        Bar(sizePx * 0.14, 2, 0.70, 0.32, 0, 1)
        Bar(sizePx * 0.36, 2, 0.5, 0.64, 0, 1)
    elseif key == "dirtfarm" or key == "farm" or key == "df" then
        Bar(2.2, sizePx * 0.72, 0.20, 0.50, 0, 1)
        Bar(2.2, sizePx * 0.72, 0.80, 0.50, 0, 1)
        Bar(sizePx * 0.42, 2.2, 0.50, 0.26, 0, 1)
        Bar(sizePx * 0.42, 2.2, 0.50, 0.50, 0, 1)
        Bar(sizePx * 0.42, 2.2, 0.50, 0.74, 0, 1)
    elseif key == "clearworld" or key == "clear" or key == "eraser" or key == "cw" then
        Bar(sizePx * 0.52, 2.2, 0.58, 0.38, -45, 1)
        Bar(sizePx * 0.40, sizePx * 0.18, 0.33, 0.64, 45, 2)
        Bar(sizePx * 0.20, 1.8, 0.26, 0.26, 0, 1)
        Bar(1.8, sizePx * 0.20, 0.26, 0.26, 0, 1)
    elseif key == "moveblock" or key == "move" or key == "transfer" then
        Bar(sizePx * 0.46, 2.1, 0.46, 0.33, 0, 1)
        Bar(sizePx * 0.18, 2.1, 0.68, 0.28, 45, 1)
        Bar(sizePx * 0.18, 2.1, 0.68, 0.38, -45, 1)
        Bar(sizePx * 0.46, 2.1, 0.54, 0.67, 0, 1)
        Bar(sizePx * 0.18, 2.1, 0.32, 0.62, -45, 1)
        Bar(sizePx * 0.18, 2.1, 0.32, 0.72, 45, 1)
    elseif key == "discordhooks" or key == "webhook" or key == "discord" or key == "bell" then
        Outline(sizePx * 0.26, sizePx * 0.26, 0.50, 0.25, sizePx, 1.7)
        Outline(sizePx * 0.26, sizePx * 0.26, 0.27, 0.71, sizePx, 1.7)
        Outline(sizePx * 0.26, sizePx * 0.26, 0.73, 0.71, sizePx, 1.7)
        Bar(sizePx * 0.34, 2, 0.38, 0.48, -60, 1)
        Bar(sizePx * 0.34, 2, 0.62, 0.48, 60, 1)
        Bar(sizePx * 0.32, 2, 0.50, 0.71, 0, 1)
    elseif key == "proxy" or key == "terminal" or key == "command" then
        Outline(sizePx * 0.78, sizePx * 0.64, 0.5, 0.5, 3, 1.7)
        Bar(sizePx * 0.22, 2, 0.34, 0.43, 38, 1)
        Bar(sizePx * 0.22, 2, 0.34, 0.57, -38, 1)
        Bar(sizePx * 0.22, 2, 0.64, 0.62, 0, 1)
    elseif key == "active" or key == "queue" or key == "list" then
        Bar(3, 3, 0.24, 0.30, 0, 99)
        Bar(sizePx * 0.44, 2, 0.58, 0.30, 0, 1)
        Bar(3, 3, 0.24, 0.50, 0, 99)
        Bar(sizePx * 0.44, 2, 0.58, 0.50, 0, 1)
        Bar(3, 3, 0.24, 0.70, 0, 99)
        Bar(sizePx * 0.44, 2, 0.58, 0.70, 0, 1)
    else
        Outline(sizePx * 0.56, sizePx * 0.56, 0.5, 0.5, 4, 1.8)]==]
    patched = string.gsub(
        patched,
        '    else%s*\n%s*Outline%(sizePx %* 0%.56, sizePx %* 0%.56, 0%.5, 0%.5, 4, 1%.8%)',
        function() return extIcons end,
        1
    )
    patched = string.gsub(
        patched,
        'local vecTabIcon, recolor = DrawVectorIcon%(NavBtn, logo or name, 20, nil, nil%)%s*\n(%s*)vecTabIcon%.Position = UDim2%.new%(0, 14, 0%.5, %-10%)',
        'local vecTabIcon, recolor = DrawVectorIcon(NavBtn, logo or name, 16, nil, nil)\n%1vecTabIcon.Position = UDim2.new(0, 12, 0.5, -8)'
    )
    patched = string.gsub(
        patched,
        'NameLbl%.Position = UDim2%.new%(0, 44, 0, 0%)%s*\n(%s*)NameLbl%.Size = UDim2%.new%(1, %-52, 1, 0%)',
        'NameLbl.Position = UDim2.new(0, 36, 0, 0)\n%1NameLbl.Size = UDim2.new(1, -44, 1, 0)'
    )
    patched = string.gsub(
        patched,
        'if BadgeTxt and BadgeTxt%.Parent and clickToken == myToken and defaultBadgeText ~= "" then',
        'if BadgeTxt and BadgeTxt.Parent and clickToken == myToken and defaultBadgeText ~= "" and BadgeTxt.Text == "CLICKED" then'
    )
    return patched
end

local function loadR8Framework(forceReload)
    local env = (type(getgenv) == "function" and select(2, pcall(getgenv))) or _G
    if type(env) == "table" then
        env.__SYT_R8_LOADER_V1 = nil
        env.__SYT_R8_SOURCE_V1 = nil
        env.__SYT_R8_LOADER_V2 = nil
        env.__SYT_R8_SOURCE_V2 = nil
        env.__SYT_R8_LOADER_V3 = nil
        env.__SYT_R8_SOURCE_V3 = nil
        env.__SYT_R8_LOADER_V4 = nil
        env.__SYT_R8_SOURCE_V4 = nil
        env.__SYT_R8_LOADER_V5 = nil
        env.__SYT_R8_SOURCE_V5 = nil
    end
    if not forceReload and type(cachedR8Loader) == "function" then
        return cachedR8Loader()
    end
    if not forceReload and type(env) == "table" then
        if type(env.__SYT_R8_LOADER_V6) == "function" then
            cachedR8Loader = env.__SYT_R8_LOADER_V6
            if type(env.__SYT_R8_SOURCE_V6) == "string" then
                cachedR8Source = env.__SYT_R8_SOURCE_V6
            end
            return cachedR8Loader()
        end
        if type(env.__SYT_R8_SOURCE_V6) == "string" and #env.__SYT_R8_SOURCE_V6 > 128 then
            cachedR8Source = env.__SYT_R8_SOURCE_V6
        end
    end
    if not cachedR8Source or #cachedR8Source < 128 or forceReload then
        local urls = {
            "https://raw.githubusercontent.com/Mytzcodes/R-8/refs/heads/main/r%268_dv.lua",
            "https://raw.githubusercontent.com/Mytzcodes/R-8/refs/heads/main/r&8_dv.lua",
        }
        local okFetch, rawScript, fetchErr
        for _, url in ipairs(urls) do
            okFetch, rawScript = pcall(function() return game:HttpGet(url, true) end)
            if okFetch and type(rawScript) == "string" and #rawScript > 128 and string.sub(rawScript, 1, 4) ~= "404:" then
                break
            end
            fetchErr = rawScript
        end
        assert(okFetch and type(rawScript) == "string" and #rawScript > 128, "[SYT] Gagal mengunduh r&8_dv.lua: " .. tostring(fetchErr or "timeout/kosong"))
        cachedR8Source = patchR8FrameworkSource(rawScript)
        if type(env) == "table" then
            env.__SYT_R8_SOURCE_V6 = cachedR8Source
        end
    end
    local loader, loadErr = loadstring(cachedR8Source)
    assert(type(loader) == "function", "[SYT] Compile error r&8_dv: " .. tostring(loadErr))
    cachedR8Loader = loader
    if type(env) == "table" then
        env.__SYT_R8_LOADER_V6 = loader
    end
    return cachedR8Loader()
end

local UI, ThemeChoices
local function feature(...)
    local args = { ... }
    local okCtor, ctor = xpcall(UI.feature, debug.traceback, table.unpack(args))
    local tabName = args[2] or args[1] or "Tab"
    if not okCtor or type(ctor) ~= "function" then
        warn(string.format("[SYT UI Tab Ctor Error] %s: %s", tostring(tabName), tostring(ctor)))
        return function() return nil end
    end
    local function safeWrapPage(sideLabel, fn)
        if type(fn) ~= "function" then return nil end
        return function(pageApi)
            local ok, err = xpcall(fn, debug.traceback, pageApi)
            if not ok then
                warn(string.format("[SYT UI Tab Error] %s (%s): %s", tostring(tabName), tostring(sideLabel), tostring(err)))
                if pageApi and type(pageApi.Card) == "function" then
                    pcall(function()
                        local errCard = pageApi:Card("Tab Recovery: " .. tostring(tabName), nil, "Shield", {
                            Subtitle = tostring(err)
                        })
                        errCard:Input("Detail Error", "TabErr_" .. tostring(tabName) .. "_" .. tostring(sideLabel), "-", tostring(err))
                    end)
                end
            end
        end
    end
    return function(def)
        if type(def) == "table" then
            local wrapped = {}
            for k, v in pairs(def) do wrapped[k] = v end
            if type(def.center) == "function" then
                wrapped.center = safeWrapPage("center", def.center)
            end
            if type(def.right) == "function" then
                wrapped.right = safeWrapPage("right", def.right)
            end
            local okCall, res = xpcall(ctor, debug.traceback, wrapped)
            if not okCall then
                warn(string.format("[SYT UI Tab Build Error] %s: %s", tostring(tabName), tostring(res)))
                return nil
            end
            return res
        end
        local okCall, res = xpcall(ctor, debug.traceback, def)
        return okCall and res or nil
    end
end
local function center(fn) return fn end
local function right(fn) return fn end

local function initSYTWindow(themeOverride, scaleOverride, startHidden)
    cleanupSYTGuiContainers(nil)
    local env = (type(getgenv) == "function" and select(2, pcall(getgenv))) or _G
    local ImGui = loadR8Framework(false)
    UI = ImGui({
        Title         = "SYT SUITE - IMGUI",
        BrandTitle    = "SYT",
        BrandSubtitle = "GROWBLOX SUITE",
        Theme         = themeOverride or "Minimalist Monochrome",
        CheckboxStyle = "Modern",
        LetterSpacing = 1,
        AutoLoading   = false,
        StartHidden   = startHidden == true,
    }).Call(3)
    if type(env) == "table" then env.__SYT_ACTIVE_UI = UI end
    if scaleOverride and UI.SetScale then
        pcall(function() UI:SetScale(scaleOverride) end)
    end
    ThemeChoices = UI.GetThemes and UI:GetThemes() or {
        "Minimalist Monochrome",
        "Blue Night Sky",
        "Violet Amethyst",
        "Orange Sand",
        "Midnight Monokai",
    }
    return UI
end

-- Pencarian cepat tabel gt via RenderStepped upvalue (< 1ms, tanpa freeze getgc)
local function fastHasWorldGT()
    if type(getconnections) ~= "function" then return false end
    local okR, rs = pcall(game.GetService, game, "RunService")
    if not okR or not rs then return false end
    local okConns, conns = pcall(getconnections, rs.RenderStepped)
    if not okConns or type(conns) ~= "table" then return false end
    local g1 = (debug and debug.getupvalue) or getupvalue
    local g2 = (debug and debug.getupvalues) or getupvalues
    for _, c in ipairs(conns) do
        local fn = type(c) == "table" and (c.Function or c["function"]) or nil
        if type(fn) == "function" then
            local cand = nil
            if type(g2) == "function" then
                local ok, ups = pcall(g2, fn)
                if ok and type(ups) == "table" then cand = ups[1] end
            elseif type(g1) == "function" then
                local ok, _, val = pcall(g1, fn, 1)
                if ok then cand = val end
            end
            if type(cand) == "table" and type(rawget(cand, "fg")) == "table" and type(rawget(cand, "goTo")) == "function" then
                return true
            end
        end
    end
    return false
end

-- Gate kesiapan ringan & non-blocking: langsung lolos jika Player & Shared tersedia (< 1ms)
local function ensureSharedModulesReady(maxSec)
    local t0 = os.clock()
    maxSec = maxSec or 2.5
    if not game:IsLoaded() then
        pcall(function() game.Loaded:Wait() end)
    end
    local plrs = game:GetService("Players")
    local lp = plrs.LocalPlayer
    while not lp and (os.clock() - t0) < maxSec do
        task.wait(0.05)
        lp = plrs.LocalPlayer
    end
    if lp and not lp:FindFirstChildOfClass("PlayerGui") then
        lp:WaitForChild("PlayerGui", math.max(0.2, maxSec - (os.clock() - t0)))
    end
    local rs = game:GetService("ReplicatedStorage")
    if rs and not rs:FindFirstChild("Shared") then
        rs:WaitForChild("Shared", math.max(0.2, maxSec - (os.clock() - t0)))
    end
    local pg = lp and lp:FindFirstChildOfClass("PlayerGui")
    return (pg ~= nil) and (pg:FindFirstChild("GameGui") ~= nil)
end

local function safeInitSYTWindow(theme, scale, startHidden)
    local lastErr
    for attempt = 1, 2 do
        local ok, res = pcall(initSYTWindow, theme, scale, startHidden)
        if ok and UI then return true, nil end
        lastErr = res
        cachedR8Loader = nil
        cachedR8Source = nil
        local env = (type(getgenv) == "function" and select(2, pcall(getgenv))) or _G
        if type(env) == "table" then
            env.__SYT_R8_LOADER_V3 = nil
            env.__SYT_R8_SOURCE_V3 = nil
        env.__SYT_R8_LOADER_V4 = nil
        env.__SYT_R8_SOURCE_V4 = nil
        env.__SYT_R8_LOADER_V5 = nil
        env.__SYT_R8_SOURCE_V5 = nil
            env.__SYT_R8_LOADER_V6 = nil
            env.__SYT_R8_SOURCE_V6 = nil
        end
        task.wait(0.1)
    end
    warn("[SYT] Gagal init window: " .. tostring(lastErr))
    return false, tostring(lastErr or "Init window gagal")
end

-- 2. SERVICES, EXECUTOR HELPERS & SHARED TABLES
local Players           = game:GetService("Players")
local CoreGui           = (function() local ok, c = pcall(game.GetService, game, "CoreGui"); return ok and c or nil end)()
local GuiService        = game:GetService("GuiService")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local TextChatService   = game:GetService("TextChatService")
local StarterGui        = game:GetService("StarterGui")
local HttpService       = game:GetService("HttpService")
local Lighting          = game:GetService("Lighting")
local TweenService      = game:GetService("TweenService")

local LP = Players.LocalPlayer

local function getEnv()
    if type(getgenv) == "function" then
        local ok, g = pcall(getgenv)
        if ok and type(g) == "table" then return g end
    end
    return _G
end

local MY_SCRIPT_TOKEN = ((getEnv().__SYT_SCRIPT_TOKEN or 0) + 1)
getEnv().__SYT_SCRIPT_TOKEN = MY_SCRIPT_TOKEN
do
    local env = getEnv()
    pcall(function() game:GetService("RunService"):UnbindFromRenderStep("SYT_FlyStep") end)
    if type(env.__SYT_STOP_ALL) == "function" then pcall(env.__SYT_STOP_ALL, "Rerun SYT") end
    pcall(function() game:GetService("RunService"):UnbindFromRenderStep("SYT_NoClipStep") end)
    pcall(function() game:GetService("RunService"):UnbindFromRenderStep("SYT_SlowFallStep") end)
    pcall(function() game:GetService("RunService"):UnbindFromRenderStep("SYT_ModZoomStep") end)
    env.__SYT_WATCHDOG_TOKEN = (env.__SYT_WATCHDOG_TOKEN or 0) + 1
    env.__SYT_RERUN_TOKEN = (env.__SYT_RERUN_TOKEN or 0) + 1
    env.__SYT_DISABLE_WATCHDOG = true
    env.__SYT_ENV_DATA = env.__SYT_ENV_DATA or {}
    env.__SYT_P2P_PEERS = env.__SYT_P2P_PEERS or {}
    if type(env.__SYT_P2P_CONNS) == "table" then
        for _, pc in ipairs(env.__SYT_P2P_CONNS) do pcall(function() pc:Disconnect() end) end
    end
    env.__SYT_P2P_CONNS = {}
    for _, k in ipairs({ "__SYT_WATCHER_CONN", "__SYT_WATCHDOG_CONN", "__SYT_NOCLIP_CONN", "__SYT_FLY_CONN", "__SYT_ROULETTE_CONN", "__SYT_AUTOCOLL_CONN", "__SYT_GOD_CONN", "__SYT_P2P_CONN" }) do
        if env[k] then
            pcall(function() env[k]:Disconnect() end)
            env[k] = nil
        end
    end
    if env.__SYT_ACTIVE_UI then
        pcall(function() env.__SYT_ACTIVE_UI:Destroy() end)
        env.__SYT_ACTIVE_UI = nil
    end
    for _, root in ipairs(getAllGuiRoots()) do
        pcall(function()
            for _, ch in ipairs(root:GetChildren()) do
                if ch:IsA("ScreenGui") and string.sub(ch.Name or "", 1, 15) == "SYT_GameDialog_" then
                    pcall(function() ch:Destroy() end)
                end
            end
        end)
    end
    if type(env.__SYT_LAST_EXEC_AT) == "number" then
        while (os.clock() - env.__SYT_LAST_EXEC_AT) < 2.0 do
            if env.__SYT_SCRIPT_TOKEN ~= MY_SCRIPT_TOKEN then return end
            task.wait(0.05)
        end
    end
    env.__SYT_LAST_EXEC_AT = os.clock()
end

local function getSafeHui()
    if type(gethui) == "function" then
        local ok, h = pcall(gethui)
        if ok and typeof(h) == "Instance" then return h end
    end
    return nil
end

getAllGuiRoots = function()
    local roots, seen = {}, {}
    local function add(r)
        if typeof(r) == "Instance" and not seen[r] then
            seen[r] = true
            roots[#roots + 1] = r
        end
    end
    add(UI and UI.ScreenGui)
    add(getSafeHui())
    add(CoreGui)
    local curLp = Players.LocalPlayer or LP
    add(curLp and curLp:FindFirstChildOfClass("PlayerGui"))
    return roots
end

local function safeGetGC(includeTables)
    if type(getgc) == "function" then
        local ok, res = pcall(getgc, includeTables == true)
        if ok and type(res) == "table" then return res end
    end
    return {}
end

local _debug = debug or {}
local function uv(fn, idx)
    if type(fn) ~= "function" or type(idx) ~= "number" then return nil end
    local g2 = (_debug and _debug.getupvalues) or getupvalues
    if type(g2) == "function" then
        local ok, ups = pcall(g2, fn)
        if ok and type(ups) == "table" and ups[idx] ~= nil then
            return ups[idx]
        end
    end
    local g1 = (_debug and _debug.getupvalue) or getupvalue
    if type(g1) == "function" then
        local function pick(ok, ...)
            if not ok then return nil end
            local n = select("#", ...)
            if n >= 2 then
                return select(2, ...)
            elseif n == 1 then
                return (...)
            end
            return nil
        end
        return pick(pcall(g1, fn, idx))
    end
    return nil
end

local function guvs(fn)
    if type(fn) ~= "function" then return nil end
    local g = (_debug and _debug.getupvalues) or getupvalues
    if type(g) == "function" then
        local ok, res = pcall(g, fn)
        if ok and type(res) == "table" then return res end
    end
    return nil
end

local function suv(fn, idx, val)
    if type(fn) ~= "function" or type(idx) ~= "number" then return false end
    local s = (_debug and _debug.setupvalue) or setupvalue
    if type(s) == "function" then
        return (pcall(s, fn, idx, val))
    end
    return false
end

local function fnSource(fn)
    local f = (_debug and _debug.getinfo) or getinfo
    if type(f) == "function" and type(fn) == "function" then
        local ok, info = pcall(f, fn, "S")
        if ok and type(info) == "table" then
            return tostring(info.source or info.short_src or "")
        end
    end
    return ""
end

local function clamp(n, lo, hi)
    if n < lo then return lo end
    if n > hi then return hi end
    return n
end

local function toInt(v, fallback)
    local n = tonumber(v)
    return n and math.floor(n) or fallback
end

local function tileKey(x, y)
    return tostring(math.floor(x)) .. "," .. tostring(math.floor(y))
end

local function cleanWorldName(name)
    return string.upper((tostring(name or "")):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function stripColorTags(s)
    return (tostring(s or "")):gsub("`.", "")
end

local function serverNow()
    local ok, t = pcall(function() return workspace:GetServerTimeNow() end)
    return (ok and type(t) == "number") and t or os.clock()
end

local MAX_STACK = 200
local COLOR_CODES = { "`1", "`2", "`3", "`4", "`5", "`6", "`7", "`8", "`9", "`b", "`c", "`d", "`e", "`p", "`#", "`@" }

-- 3. GAME DISCOVERY + IN-GAME ACCOUNT & ITEM ICON ENGINE
local H = {
    initialized      = false,
    Net              = nil,
    ItemDB           = nil,
    Roles            = nil,
    Assets           = nil,
    ItemIcon         = nil,
    Autotile         = nil,
    BitmapText       = nil,
    gt               = nil,
    inv              = nil,
    others           = nil,
    stateObj         = nil,
    trees            = nil,
    mirroredTrees    = {},
    wheelSpins       = nil,
    particles        = nil,
    backdropObj      = nil,
    weathersObj      = nil,
    renderFn         = nil,
    pxIdx            = nil,
    pyIdx            = nil,
    vxIdx            = nil,
    vyIdx            = nil,
    prevXIdx         = nil,
    prevYIdx         = nil,
    renderPosPairs   = {},
    statePosPairs    = {},
    deadIdx          = nil,
    hpIdx            = nil,
    lastHurtAtIdx    = nil,
    touchHurtIdx     = nil,
    dieIdx           = nil,
    respawnIdx       = nil,
    goPxIdx          = nil,
    goPyIdx          = nil,
    goPrevXIdx       = nil,
    goPrevYIdx       = nil,
    goVxIdx          = nil,
    goVyIdx          = nil,
    goAckXIdx        = nil,
    goAckYIdx        = nil,
    skillsObj        = nil,
    origHandPower    = nil,
    origSkills       = nil,
    skillsHookedFor  = nil,
    nameTagObj       = nil,
    wornTbl          = nil,
    playerSpriteObj  = nil,
    origAreas        = nil,
    areasBypassedFor = nil,
    origDropOk       = nil,
    dropOkHookedFor  = nil,
    origDrawWeather  = nil,
    weatherHookedFor = nil,
    weatherLockedId  = nil,
    weatherLockedOpts = nil,
    lastWorldTag     = "",
    lastTileAt       = 0,
    lastDropAt       = 0,
    origMoveSend     = nil,
    origDiedSend     = nil,
    origTakeDrop     = nil,
    origOnHurt       = nil,
    origOnDie        = nil,
    origTouchHurt    = nil,
    origDieFn        = nil,
    origRespawnFn    = nil,
    origGtRespawn    = nil,
    origTBHurt       = nil,
    origTBDie        = nil,
    touchHurtRef     = nil,
    dieFnRef         = nil,
    origSwirlFn      = nil,
    origYolkFn       = nil,
    origTouchBlocks  = nil,
    takeSeq          = 0,
    takingUids       = {},
    autoMove         = nil,
    moveConn         = nil,
    moveHooked       = false,
    takeDropHooked   = false,
    wheelHooked      = false,
    seemsHooked      = false,
    netGodHooked     = false,
    chatWarnHooked   = false,
    serverTileEchoSeen = false,
    recentSelfEdits  = {},
    lastPlaceRejectedAt = 0,
    nextPlaceAllowedAt = 0,
    adaptivePlaceGap = 0.168,
    lastGcScanAt     = 0,
    lastDigWearTryAt = 0,
    flyLastValidPos  = nil,
    flyAirAnchor     = nil,
    antiBackAnchor   = nil,
    lastSentMove     = nil,
    stopMoveUntil    = 0,
    lastPunchAt      = 0,
    lastActAt        = 0,
    blockedMoveToCount = 0,
    lastBlockedMoveToAt = 0,
    lastActionBlockedAt = 0,
    lastActionBlockedReason = "",
    goToGuardedFor   = nil,
    antiBackGuardHooked = false,
    antiBackWrappedConns = {},
    allowNextMoveToUntil = 0,
    firewallHooked   = false,
    firewallHookedFor = nil,
    origNetSendMap   = {},
    origNetCallFn    = nil,
    fwBucket         = {},
    fwTileLastAt     = {},
    fwBlockedCount   = 0,
    fwLastBlockReason = "",
    fwLastBlockAt    = 0,
    fwMoveLastSentAt = 0,
    fwLastPlaceSentAt = 0,
    fwLastDropSentAt = 0,
    chatBackoffUntil = 0,
    lastMcGcScanAt   = 0,
    mcCandidates     = {},
    _mcWrapped       = {},
    watcherConn      = nil,
    flyConn          = nil,
    godConn          = nil,
    fpsConn          = nil,
    collectConn      = nil,
    rouletteGui      = nil,
    onNotify         = nil,
}

local UIHooks = {
    refreshMap     = nil,
    refreshBP      = nil,
    refreshPad5x5  = nil,
    refreshPadPab  = nil,
    updateButtons  = nil,
    sidebarNameLbl = nil,
    sidebarSubLbl  = nil,
}

local FALLBACK_ATLAS = {
    tiles1        = "rbxassetid://82799209779866",
    tiles2        = "rbxassetid://89455019317905",
    tiles3        = "rbxassetid://106357113402286",
    tiles4        = "rbxassetid://133411503344534",
    tiles7        = "rbxassetid://118371595643743",
    tiles8        = "rbxassetid://120565708911892",
    tiles10       = "rbxassetid://108050932892062",
    tiles12       = "rbxassetid://85572011411757",
    tiles16       = "rbxassetid://107464853942311",
    handitem5Icon = "rbxassetid://88972987813614",
    back          = "rbxassetid://108325908969366",
    gtBack        = "rbxassetid://98376529032674",
    gtBack2       = "rbxassetid://113745426721038",
    gtBack3       = "rbxassetid://118968851482188",
}

local FALLBACK_FX = {
    seed       = "rbxassetid://108732646662201",
    particles  = "rbxassetid://137922727001498",
    particles2 = "rbxassetid://93187360380810",
    pickup     = "rbxassetid://98554358199183",
}

local function safeRequireShared(name)
    local sh = ReplicatedStorage:FindFirstChild("Shared")
    local mod = sh and sh:FindFirstChild(name)
    if mod then
        local ok, res = pcall(require, mod)
        if ok and type(res) == "table" then return res end
    end
    return nil
end

local function isValidGT(t)
    return type(t) == "table"
        and type(rawget(t, "fg")) == "table"
        and type(rawget(t, "bg")) == "table"
        and type(rawget(t, "w")) == "number"
        and type(rawget(t, "h")) == "number"
        and type(rawget(t, "name")) == "string"
        and type(rawget(t, "goTo")) == "function"
        and type(rawget(t, "dropList")) == "function"
end

local function isValidNet(t)
    if type(t) ~= "table" then return false end
    local tile = rawget(t, "tile")
    local move = rawget(t, "move")
    return type(tile) == "table" and type(rawget(tile, "send")) == "function"
        and type(move) == "table" and type(rawget(move, "send")) == "function"
        and type(rawget(t, "worldTag")) == "function"
end

local function isValidItemDB(t)
    if type(t) ~= "table" then return false end
    local d2 = rawget(t, 2)
    return type(d2) == "table" and rawget(d2, "name") == "Dirt"
end

local function isValidInv(t)
    if type(t) ~= "table" then return false end
    if type(rawget(t, "slots")) ~= "table" or type(rawget(t, "capacity")) ~= "number" then
        return false
    end
    local ok, hasMethods = pcall(function()
        return type(t.count) == "function" and type(t.add) == "function"
    end)
    return ok and hasMethods
end

local function isValidStateObj(t)
    return type(t) == "table"
        and type(rawget(t, "state")) == "function"
        and type(rawget(t, "RAY")) == "table"
        and type(rawget(t, "onDie")) == "function"
end

local function isValidOthers(t)
    return type(t) == "table"
        and type(rawget(t, "list")) == "function"
        and type(rawget(t, "where")) == "function"
        and type(rawget(t, "update")) == "function"
end

local function isTreeMapCandidate(tbl)
    if type(tbl) ~= "table" or tbl == H.gt or tbl == H.ItemDB or tbl == H.Net or tbl == H.inv then
        return false
    end
    for k, v in pairs(tbl) do
        if type(k) == "number" and type(v) == "table" and type(v.id) == "number" and type(v.p) == "number" then
            return true
        end
        return false
    end
    return false
end

local function isWheelMapCandidate(tbl)
    if type(tbl) ~= "table" or tbl == H.gt or tbl == H.ItemDB or tbl == H.Net then
        return false
    end
    for k, v in pairs(tbl) do
        if type(k) == "number" and type(v) == "table" and type(v.ends) == "number" and v.n ~= nil then
            return true
        end
        return false
    end
    return false
end

local function inspectUpvalues(gt)
    if not gt then return end
    local refX, refY = nil, nil
    if H.stateObj and type(H.stateObj.state) == "function" then
        local okSt, st = pcall(H.stateObj.state)
        if okSt and type(st) == "table" and type(st.x) == "number" and type(st.y) == "number" then
            refX, refY = st.x, st.y
        end
    elseif type(gt.state) == "function" then
        local okSt, st = pcall(gt.state)
        if okSt and type(st) == "table" and type(st.x) == "number" and type(st.y) == "number" then
            refX, refY = st.x, st.y
        end
    end

    H.statePosPairs = {}
    local stFn = H.stateObj and type(H.stateObj.state) == "function" and H.stateObj.state or nil
    if stFn and uv(stFn, 1) == gt and type(uv(stFn, 3)) == "number" and type(uv(stFn, 4)) == "number" then
        H.statePosPairs = { x = 3, y = 4, vx = (type(uv(stFn, 5)) == "number") and 5 or nil, vy = (type(uv(stFn, 6)) == "number") and 6 or nil }
    end

    local goTo = rawget(gt, "goTo")
    if type(goTo) == "function" then
        H.goPxIdx, H.goPyIdx, H.goPrevXIdx, H.goPrevYIdx, H.goVxIdx, H.goVyIdx, H.goAckXIdx, H.goAckYIdx = nil, nil, nil, nil, nil, nil, nil, nil
        for idx = 1, 14 do
            local v1, v2, v3 = uv(goTo, idx), uv(goTo, idx + 1), uv(goTo, idx + 2)
            if type(v1) == "number" and type(v2) == "number" and v3 == gt then
                H.goPxIdx, H.goPyIdx = idx, idx + 1
                if type(uv(goTo, idx + 4)) == "number" and type(uv(goTo, idx + 5)) == "number" then
                    H.goPrevXIdx, H.goPrevYIdx = idx + 4, idx + 5
                end
                if type(uv(goTo, idx + 6)) == "number" and type(uv(goTo, idx + 7)) == "number" then
                    H.goVxIdx, H.goVyIdx = idx + 6, idx + 7
                end
                if type(uv(goTo, idx + 8)) == "number" and type(uv(goTo, idx + 9)) == "number" then
                    H.goAckXIdx, H.goAckYIdx = idx + 8, idx + 9
                end
                break
            end
        end
    end

    if (not refX or not refY) and H.goPxIdx and H.goPyIdx and type(goTo) == "function" then
        refX, refY = uv(goTo, H.goPxIdx), uv(goTo, H.goPyIdx)
    end

    local function iterFnUpvalues(fn, maxFallback)
        local ups = guvs(fn)
        if type(ups) == "table" then
            return pairs(ups)
        end
        local limit = maxFallback or 360
        local idx = 0
        return function()
            while idx < limit do
                idx += 1
                local val = uv(fn, idx)
                if val ~= nil then
                    return idx, val
                end
            end
            return nil
        end
    end

    local getconns = getconnections
    if type(getconns) == "function" and not H.renderFn then
        local okConns, conns = pcall(getconns, RunService.RenderStepped)
        if okConns and type(conns) == "table" then
            for _, c in ipairs(conns) do
                local fn = type(c) == "table" and (c.Function or c["function"]) or nil
                if type(fn) == "function" and uv(fn, 1) == gt then
                    local hasScale, has64, hasSkills = false, false, false
                    for _, val in iterFnUpvalues(fn, 360) do
                        if typeof(val) == "Instance" and val:IsA("UIScale") then
                            hasScale = true
                        elseif val == 64 then
                            has64 = true
                        elseif type(val) == "table" and type(rawget(val, "handPower")) == "function" and type(rawget(val, "punchRange")) == "function" and type(rawget(val, "buildRange")) == "function" then
                            hasSkills = true
                        end
                    end
                    if hasScale and (has64 or hasSkills) then
                        H.renderFn = fn
                        break
                    end
                end
            end
        end
    end

    if H.renderFn then
        H.mcCandidates = {}
        for _, val in iterFnUpvalues(H.renderFn, 360) do
            if type(val) == "table" then
                if not H.particles and type(rawget(val, "swirl")) == "function" and type(rawget(val, "yolk")) == "function" then
                    H.particles = val
                elseif not H.backdropObj and type(rawget(val, "setWorld")) == "function" then
                    H.backdropObj = val
                elseif not H.skillsObj and type(rawget(val, "handPower")) == "function" and type(rawget(val, "punchRange")) == "function" and type(rawget(val, "buildRange")) == "function" then
                    H.skillsObj = val
                elseif type(rawget(val, "dir")) == "function" and type(rawget(val, "jumping")) == "function" and type(rawget(val, "busy")) == "function" then
                    if not H.mobileControls then
                        H.mobileControls = val
                    end
                    H.mcCandidates[#H.mcCandidates + 1] = val
                elseif not H.nameTagObj and type(rawget(val, "tagKey")) == "function" and type(rawget(val, "redraw")) == "function" then
                    H.nameTagObj = val
                end
            end
        end
    end

    if H.skillsObj then
        local sk = H.skillsObj
        local origIsWorn = (H.skillsHookedFor == sk and H.origSkills and H.origSkills.isWorn) or rawget(sk, "isWorn")
        if type(origIsWorn) == "function" then
            local w = uv(origIsWorn, 1)
            if type(w) == "table" then H.wornTbl = w end
        end
        local origApplyWorn = (H.skillsHookedFor == sk and H.origSkills and H.origSkills.applyWorn) or rawget(sk, "applyWorn")
        if type(origApplyWorn) == "function" then
            if type(H.wornTbl) ~= "table" then
                local w = uv(origApplyWorn, 1)
                if type(w) == "table" then H.wornTbl = w end
            end
            local ps = uv(origApplyWorn, 2)
            if type(ps) == "table" and (type(rawget(ps, "rigs")) == "table" or typeof(rawget(ps, "SKIN")) == "Color3" or type(rawget(ps, "applyFeet")) == "function") then
                H.playerSpriteObj = ps
            end
        end
    end

    if H.renderFn and refX and refY then
        local fallbackIdx = nil
        H.pxIdx, H.pyIdx, H.prevXIdx, H.prevYIdx, H.vxIdx, H.vyIdx = nil, nil, nil, nil, nil, nil
        H.renderPosPairs = {}
        for idx = 1, 90 do
            local vx, vy = uv(H.renderFn, idx), uv(H.renderFn, idx + 1)
            if type(vx) == "number" and type(vy) == "number"
                and math.abs(vx - refX) < 0.05 and math.abs(vy - refY) < 0.05 then
                H.renderPosPairs[#H.renderPosPairs + 1] = { x = idx, y = idx + 1 }
                if not fallbackIdx then fallbackIdx = idx end
                if not H.pxIdx and type(uv(H.renderFn, idx + 2)) == "boolean" and type(uv(H.renderFn, idx - 1)) == "number" then
                    H.pxIdx, H.pyIdx = idx, idx + 1
                end
            end
        end
        if not H.pxIdx and fallbackIdx then
            H.pxIdx, H.pyIdx = fallbackIdx, fallbackIdx + 1
        end
        if type(rawget(gt, "touchBlocks")) == "function" then
            H.touchHurtRef = H.touchHurtRef or uv(gt.touchBlocks, 1)
            H.dieFnRef     = H.dieFnRef     or uv(gt.touchBlocks, 2)
        end
        if type(rawget(gt, "respawn")) == "function" then
            H.dieFnRef = H.dieFnRef or uv(gt.respawn, 2)
        end

        local getc = (_debug and (_debug.getconstants or _debug.getconsts)) or getconstants
        for uIdx = 1, 120 do
            local val = uv(H.renderFn, uIdx)
            if type(val) == "function" then
                if H.touchHurtRef and val == H.touchHurtRef and not H.touchHurtIdx then
                    H.touchHurtIdx = uIdx
                    H.origTouchHurt = H.origTouchHurt or val
                elseif H.dieFnRef and val == H.dieFnRef and not H.dieIdx then
                    H.dieIdx = uIdx
                    H.origDieFn = H.origDieFn or val
                end
                if type(getc) == "function" then
                    local okC, consts = pcall(getc, val)
                    if okC and type(consts) == "table" then
                        local hasHurts, hasDeadly, hasDieConst, hasRespawnConst = false, false, false, false
                        for _, c in pairs(consts) do
                            if c == "hurts" then hasHurts = true end
                            if c == "deadly" then hasDeadly = true end
                            if c == "male_scream" or c == "ouch" or c == "deadSince" or c == "glitchSoul" or c == "burn" or c == "Burn" then
                                hasDieConst = true
                            end
                            if c == "died" or c == "respawnedAt" then
                                hasRespawnConst = true
                            end
                        end
                        if hasHurts and hasDeadly and not H.touchHurtIdx then
                            H.touchHurtIdx = uIdx
                            H.origTouchHurt = H.origTouchHurt or val
                        elseif hasDieConst and not hasHurts and not H.dieIdx then
                            H.dieIdx = uIdx
                            H.origDieFn = H.origDieFn or val
                        elseif hasRespawnConst and not hasHurts and not hasDieConst and not H.respawnIdx then
                            H.respawnIdx = uIdx
                            H.origRespawnFn = H.origRespawnFn or val
                        end
                    end
                end
            end
        end

        if H.touchHurtIdx and H.dieIdx then
            local lo = math.min(H.touchHurtIdx, H.dieIdx)
            local hi = math.max(H.touchHurtIdx, H.dieIdx)
            for hIdx = lo + 1, hi - 1 do
                local v = uv(H.renderFn, hIdx)
                if type(v) == "number" and v >= 0 and v <= 5 then
                    H.hpIdx = hIdx
                elseif type(v) == "number" and v < 0 then
                    H.lastHurtAtIdx = hIdx
                end
            end
        end
        if H.respawnIdx and type(uv(H.renderFn, H.respawnIdx - 1)) == "boolean" then
            H.deadIdx = H.respawnIdx - 1
        end

        if H.pxIdx then
            local idx = H.pxIdx
            -- Temukan velocity (vx, vy) berdasarkan kesesuaian dengan state() jika tersedia, aman tanpa tebak blindly
            local refVx, refVy = nil, nil
            if H.stateObj and type(H.stateObj.state) == "function" then
                local okSt, st = pcall(H.stateObj.state)
                if okSt and type(st) == "table" then
                    refVx, refVy = st.vx, st.vy
                end
            end
            if type(refVx) == "number" and type(refVy) == "number" then
                for k = math.max(1, idx - 8), math.min(90, idx + 8) do
                    if k ~= idx and k ~= idx + 1 then
                        local a, b = uv(H.renderFn, k), uv(H.renderFn, k + 1)
                        if type(a) == "number" and type(b) == "number" and math.abs(a - refVx) < 0.05 and math.abs(b - refVy) < 0.05 then
                            H.vxIdx, H.vyIdx = k, k + 1
                            break
                        end
                    end
                end
            end
            if not H.deadIdx then
                for dIdx = idx + 2, idx + 16 do
                    local v = uv(H.renderFn, dIdx)
                    if type(v) == "boolean" and dIdx ~= idx + 2 then
                        H.deadIdx = dIdx
                        break
                    end
                end
            end
            if not H.hpIdx then
                for hIdx = math.max(1, idx - 6), idx + 14 do
                    local v = uv(H.renderFn, hIdx)
                    if type(v) == "number" and hIdx ~= idx and hIdx ~= idx + 1 and hIdx ~= H.vxIdx and hIdx ~= H.vyIdx then
                        if v >= 1 and v <= 5 and math.floor(v) == v and not H.hpIdx then
                            H.hpIdx = hIdx
                        end
                    end
                end
            end
        end
    end
end

local Core = {}
local SYT_Logic = { VERSION = "2.1.0", _Hooks = H, Core = Core }

function Core.AllowMoveToWindow(sec)
    H.allowNextMoveToUntil = math.max(H.allowNextMoveToUntil or 0, os.clock() + (tonumber(sec) or 0.8))
end

function Core.IsAntiBackActive()
    local gs = SYT_Logic.GetcSkipper and SYT_Logic.GetcSkipper.State
    local ms = SYT_Logic.Misc and SYT_Logic.Misc.State
    if gs and gs.enabled == false and not (ms and (ms.fly or ms.godMode)) then
        return false
    end
    return (gs and (gs.antiBack ~= false or gs.noValidateBack == true))
        or (ms and (ms.fly and ms.flyAntiBasePath ~= false or ms.godMode))
        or false
end

function Core.GetStopOrNoSendMode()
    local gs = SYT_Logic.GetcSkipper and SYT_Logic.GetcSkipper.State
    if not gs or gs.enabled == false then return "off" end
    local m = string.lower(tostring(gs.stopOrNoSend or "nosend"))
    if m == "stop" or m == "nosend" or m == "off" then return m end
    return "nosend"
end

function Core.IsNearDoorTile(tx, ty)
    local gt = H.gt
    if not gt or not gt.w or not gt.h or type(tx) ~= "number" or type(ty) ~= "number" then return false end
    for dy = -1, 1 do
        for dx = -1, 1 do
            local ax, ay = tx + dx, ty + dy
            if ax >= 0 and ax < gt.w and ay >= 0 and ay < gt.h then
                local id = Core.GetFG(ax, ay)
                if id and id ~= 0 then
                    local info = Core.GetItemInfo(id)
                    if info and (info.door or info.entrance) then
                        return true
                    end
                end
            end
        end
    end
    return false
end

function Core.GetRealServerRange(kind)
    if kind == "collect" or kind == "take" then
        return 4.6
    end
    local sk = H.skillsObj
    local src = (sk and H.skillsHookedFor == sk and H.origSkills) and H.origSkills or sk
    local r = 2.5
    if src then
        if kind == "build" or kind == "place" then
            if type(src.buildRange) == "function" then
                local ok, v = pcall(src.buildRange)
                if ok and type(v) == "number" and v >= 2.0 then r = v end
            end
        elseif kind == "punch" or kind == "break" then
            if type(src.punchRange) == "function" then
                local ok, v = pcall(src.punchRange)
                if ok and type(v) == "number" and v >= 2.0 then r = v end
            elseif type(src.buildRange) == "function" then
                local ok, v = pcall(src.buildRange)
                if ok and type(v) == "number" and v >= 2.0 then r = v end
            end
        end
    end
    return math.max(2.35, r - 0.05)
end

function Core.GetActionRange(kind)
    if kind == "collect" or kind == "take" then
        return 4.6
    end
    local sk = H.skillsObj
    local gs = SYT_Logic.GetcSkipper and SYT_Logic.GetcSkipper.State
    local shieldOn = not (gs and gs.antiKickShield == false)
    local allowSpoof = (not shieldOn) and gs and gs.spoofServerReach == true
    local src = (sk and H.skillsHookedFor == sk and H.origSkills and not allowSpoof) and H.origSkills or sk
    local r = 2.5
    if src then
        if kind == "build" or kind == "place" then
            if type(src.buildRange) == "function" then
                local ok, v = pcall(src.buildRange)
                if ok and type(v) == "number" and v >= 2.0 then r = v end
            end
        elseif kind == "punch" or kind == "break" then
            if type(src.punchRange) == "function" then
                local ok, v = pcall(src.punchRange)
                if ok and type(v) == "number" and v >= 2.0 then r = v end
            elseif type(src.buildRange) == "function" then
                local ok, v = pcall(src.buildRange)
                if ok and type(v) == "number" and v >= 2.0 then r = v end
            end
        end
    end
    return math.max(2.35, r - 0.05)
end

function Core.IsInActionReach(tx, ty, kind, posOverride)
    if type(tx) ~= "number" or type(ty) ~= "number" then return false end
    local pos = posOverride or Core.ReadPos()
    local range = Core.GetActionRange(kind)
    local dx = math.abs((tx + 0.5) - pos.x)
    local dy = math.abs((ty + 0.5) - (pos.y - 0.475))
    return dx <= range and dy <= range
end

function Core.CanPlaceBodyOk(tx, ty, info, posOverride)
    local gt = H.gt
    if not gt or tx < 0 or tx >= gt.w or ty < 0 or ty >= gt.h then return false, "out_of_bounds" end
    if info and info.kind == "consumable" then return true, "consumable" end
    if not Core.CanEditTile(tx, ty) then return false, "no_edit" end
    if type(gt.builderOk) == "function" then
        local okB, resB = pcall(gt.builderOk, tx, ty, true)
        if okB and resB == false then return false, "builder_locked" end
    end
    if info and (info.solid or info.combiner) and not info.background and info.kind ~= "seed" then
        local pos = posOverride or Core.ReadPos()
        if (tx + 1 > pos.x - 0.3) and (tx < pos.x + 0.3) and (ty + 1 > pos.y - 0.95) and (ty < pos.y) then
            return false, "inside_player"
        end
    end
    return true, "ok"
end

function Core.ShouldBlockMoveTo(gx, gy)
    if os.clock() <= (H.allowNextMoveToUntil or 0) then
        return false
    end
    local ms = SYT_Logic.Misc and SYT_Logic.Misc.State
    local gs = SYT_Logic.GetcSkipper and SYT_Logic.GetcSkipper.State
    local antiBack = Core.IsAntiBackActive()
    local flyOn = ms and ms.fly == true and ms.flyAntiBasePath ~= false
    local godOn = ms and ms.godMode == true
    local skipperOn = gs and gs.enabled == true and (gs.noValidateBack == true or gs.antiBack ~= false)
    if not (antiBack or flyOn or godOn or skipperOn) then
        return false
    end
    local cur = Core.ReadPos()
    if type(gx) == "number" and type(gy) == "number" then
        local gt = H.gt
        local sp = gt and gt.spawn
        local nearSpawnTarget = sp and (math.abs(gx - sp.X) + math.abs(gy - sp.Y)) <= 2.4
        local playerFarFromSpawn = sp and (math.abs(cur.x - sp.X) + math.abs(cur.y - sp.Y)) > 3.2
        if not nearSpawnTarget and Core.IsNearDoorTile(cur.tx, cur.ty) and not flyOn then
            return false
        end
        local jumpDist = math.abs(gx - cur.x) + math.abs(gy - cur.y)
        if (nearSpawnTarget and playerFarFromSpawn) or jumpDist > 1.8 or flyOn or godOn then
            H.blockedMoveToCount = (H.blockedMoveToCount or 0) + 1
            H.lastBlockedMoveToAt = os.clock()
            if not flyOn and Core.GetStopOrNoSendMode() == "stop" then
                H.stopMoveUntil = math.max(H.stopMoveUntil or 0, os.clock() + 0.35)
                H.autoMove = nil
            end
            return true
        end
        return false
    end
    if flyOn or godOn or skipperOn then
        H.blockedMoveToCount = (H.blockedMoveToCount or 0) + 1
        H.lastBlockedMoveToAt = os.clock()
        return true
    end
    return false
end

function Core.InstallAntiBackGuard()
    local gt, net = H.gt, H.Net
    local dmgEvents = { ForceDie = true, Died = true, Knocked = true, Burned = true, Impulse = true, Hurt = true }
    local function wrapGuardFn(evKey, origFn)
        if type(origFn) ~= "function" then return origFn end
        if H.antiBackWrappedConns[origFn] then return origFn end
        local isMove = (evKey == "MoveTo")
        local isDmg = dmgEvents[evKey] == true
        local wrapper = function(a1, a2, ...)
            local ms = SYT_Logic.Misc and SYT_Logic.Misc.State
            if isMove then
                local mx = tonumber(a1) or (type(a1) == "table" and tonumber(a1.x or a1.X or a1[1]))
                local my = tonumber(a2) or (type(a1) == "table" and tonumber(a1.y or a1.Y or a1[2]))
                if Core.ShouldBlockMoveTo(mx, my) then
                    return nil
                end
            end
            if isDmg and ms and (ms.godMode == true or (Core.IsAntiBackActive() and (evKey == "Knocked" or evKey == "Impulse"))) then
                return nil
            end
            return origFn(a1, a2, ...)
        end
        H.antiBackWrappedConns[origFn] = wrapper
        H.antiBackWrappedConns[wrapper] = wrapper
        return wrapper
    end

    -- Layer 1: Guard gt.goTo & gt.on agar server MoveTo / listener world baru tidak menarik posisi ke BasePath/Spawn
    if gt and H.goToGuardedFor ~= gt then
        H.goToGuardedFor = gt
        if type(rawget(gt, "goTo")) == "function" then
            local origGoTo = gt.goTo
            H.origGtGoTo = origGoTo
            gt.goTo = function(gx, gy, ...)
                if Core.ShouldBlockMoveTo(tonumber(gx), tonumber(gy)) then
                    local cur = Core.ReadPos()
                    Core.SetLocalCoords(cur.x, cur.y, 0, 0)
                    H.antiBackAnchor = { x = cur.x, y = cur.y, t = os.clock() }
                    return nil
                end
                if type(gx) == "number" and type(gy) == "number" then
                    H.lastSentMove = { x = gx, y = gy, vx = 0, vy = 0, flags = 2, t = os.clock() }
                    H.antiBackAnchor = { x = gx, y = gy, t = os.clock() }
                end
                return origGoTo(gx, gy, ...)
            end
        end
        if type(rawget(gt, "on")) == "function" then
            local origGtOn = gt.on
            H.origGtOn = origGtOn
            gt.on = function(evName, cb, ...)
                if type(cb) == "function" and (evName == "MoveTo" or dmgEvents[evName]) then
                    cb = wrapGuardFn(evName, cb)
                end
                return origGtOn(evName, cb, ...)
            end
        end
    end

    local function hookRemoteEventConn(evKey, re)
        if not re or not re:IsA("RemoteEvent") or type(getconnections) ~= "function" then return end
        local okC, conns = pcall(getconnections, re.OnClientEvent)
        if okC and type(conns) == "table" then
            for _, c in ipairs(conns) do
                local fn = type(c) == "table" and (c.Function or c["function"]) or nil
                if type(fn) == "function" and not H.antiBackWrappedConns[fn] then
                    local wrapped = wrapGuardFn(evKey, fn)
                    if type(c.Disable) == "function" then
                        local okDis = pcall(function() c:Disable() end)
                        if okDis then
                            re.OnClientEvent:Connect(wrapped)
                        end
                    end
                end
            end
        end
    end

    -- Layer 2: Guard WorldRemotes OnClientEvent via getconnections + hook ChildAdded jika rejoin world
    local targetEvSet = { MoveTo = true, ForceDie = true, Died = true, Knocked = true, Burned = true, Impulse = true, Hurt = true }
    local wr = ReplicatedStorage:FindFirstChild("WorldRemotes")
    if wr then
        for evKey, _ in pairs(targetEvSet) do
            hookRemoteEventConn(evKey, wr:FindFirstChild(evKey))
        end
        if H.wrChildHookedFor ~= wr then
            H.wrChildHookedFor = wr
            wr.ChildAdded:Connect(function(ch)
                if targetEvSet[ch.Name] then
                    task.defer(function()
                        hookRemoteEventConn(ch.Name, ch)
                    end)
                end
            end)
        end
    end

    -- Layer 3: Guard ByteNet getListeners() + listen() + net.on() + upvalue tables pada H.Net
    if type(net) == "table" then
        if type(rawget(net, "on")) == "function" and H.netOnGuardedFor ~= net then
            local origNetOn = net.on
            H.netOnGuardedFor = net
            H.origNetOn = origNetOn
            net.on = function(evName, cb, ...)
                if type(cb) == "function" and (evName == "MoveTo" or dmgEvents[evName]) then
                    cb = wrapGuardFn(evName, cb)
                end
                return origNetOn(evName, cb, ...)
            end
        end
        local netMap = {
            moveTo = "MoveTo", moveto = "MoveTo",
            forceDie = "ForceDie", forcedie = "ForceDie",
            knocked = "Knocked", burned = "Burned", impulse = "Impulse", hurt = "Hurt", died = "Died",
        }
        H.wrappedPktListen = H.wrappedPktListen or {}
        for pktName, evKey in pairs(netMap) do
            local pktObj = rawget(net, pktName)
            if type(pktObj) == "table" then
                if type(pktObj.getListeners) == "function" then
                    local okL, listeners = pcall(pktObj.getListeners)
                    if okL and type(listeners) == "table" then
                        for idx, lfn in ipairs(listeners) do
                            if type(lfn) == "function" and not H.antiBackWrappedConns[lfn] then
                                listeners[idx] = wrapGuardFn(evKey, lfn)
                            end
                        end
                    end
                end
                if type(pktObj.listen) == "function" then
                    local uvs = guvs(pktObj.listen)
                    if type(uvs) == "table" then
                        for _, uval in pairs(uvs) do
                            if type(uval) == "table" and #uval > 0 then
                                for idx, lfn in ipairs(uval) do
                                    if type(lfn) == "function" and not H.antiBackWrappedConns[lfn] then
                                        uval[idx] = wrapGuardFn(evKey, lfn)
                                    end
                                end
                            end
                        end
                    end
                    if not H.wrappedPktListen[pktObj] then
                        local origListen = pktObj.listen
                        H.wrappedPktListen[pktObj] = true
                        pktObj.listen = function(cb, ...)
                            if type(cb) == "function" then
                                cb = wrapGuardFn(evKey, cb)
                            end
                            return origListen(cb, ...)
                        end
                    end
                end
            end
        end
    end

    H.antiBackGuardHooked = true
    if type(SYT_Logic._origInstallNetGuard) == "function" then
        pcall(SYT_Logic._origInstallNetGuard)
    end
    return true
end

function Core.SanitizeOutboundMove(pkt, fromBot, forceBypass)
    if type(pkt) ~= "table" then return nil, "bad_pkt" end
    local px = tonumber(pkt.x)
    local py = tonumber(pkt.y)
    if not px or not py or px ~= px or py ~= py or math.abs(px) > 1e5 or math.abs(py) > 1e5 then
        return nil, "invalid_coords"
    end
    local gt = H.gt
    if gt and gt.w and gt.h then
        if px < -0.5 or px > (gt.w + 0.5) or py < -2.0 or py > (gt.h + 1.5) then
            return nil, "out_of_world_bounds"
        end
    end

    local now = os.clock()
    local vx = tonumber(pkt.vx) or 0
    local vy = tonumber(pkt.vy) or 0
    local flags = toInt(pkt.flags, 2)
    local ts = clamp(math.floor(tonumber(pkt.t) or ((now * 1000) % 65535)), 0, 65535)
    local miscRef = SYT_Logic.Misc
    local ms = miscRef and miscRef.State
    local stopNoSend = Core.GetStopOrNoSendMode()
    local antiBack = Core.IsAntiBackActive()

    if ms and ms.noClip and not forceBypass then
        return nil, "noclip_visual_only"
    end

    if not fromBot and not forceBypass and H.autoMove then
        local am = H.autoMove
        return { x = am.x, y = am.y, vx = am.vx or 0, vy = am.vy or 0, flags = am.flags or 2, t = ts }
    end

    -- Bila mode Stop aktif karena rollback baru saja terdeteksi (di luar Fly aktif), tahan paket liar hingga aman kembali
    local flyActive = (ms and ms.fly == true)
    if not flyActive and stopNoSend == "stop" and now < (H.stopMoveUntil or 0) and not forceBypass then
        H.lastActionBlockedAt = now
        H.lastActionBlockedReason = "stop_move_guard"
        return nil, "stop_move_guard"
    end

    -- Ketika SteppedAnchor Fly memegang kontrol terbang, tahan broadcast Others.lua yang mengirim vy/ungrounded liar
    if flyActive and ms.flyMethod ~= "GhostHybrid" and not fromBot and not forceBypass then
        return nil, "fly_anchor_owns_move"
    end

    if flyActive and ms.flyAntiBasePath ~= false and not forceBypass then
        vx = clamp(vx, -18.0, 18.0)
        vy = clamp(vy, -22.0, 24.0)
        local facingBit = (math.floor(flags) % 2 == 1) and 1 or 0
        local groundedBit = (ms.flyMethod ~= "GhostHybrid") and ((math.floor(flags) % 4 >= 2) and 2 or 0) or ((math.abs(vy) < 0.08) and 2 or ((math.floor(flags) % 4 >= 2) and 2 or 0))
        flags = facingBit + groundedBit
    end

    -- Validasi step delta terhadap paket Move terakhir agar tidak memicu server BasePath rollback atau Speed Kick
    local gs = SYT_Logic.GetcSkipper and SYT_Logic.GetcSkipper.State
    local shieldOn = not (gs and gs.antiKickShield == false)
    local prev = H.lastSentMove
    if (antiBack or shieldOn) and not forceBypass and prev and (now - (prev.t or 0)) < 3.0 then
        local dx = px - prev.x
        local dy = py - prev.y
        local absDx, absDy = math.abs(dx), math.abs(dy)
        if not flyActive and not fromBot and (absDx > 6.5 or absDy > 6.5) then
            if stopNoSend == "stop" then
                H.stopMoveUntil = now + 0.30
            end
            H.lastActionBlockedAt = now
            H.lastActionBlockedReason = "no_send_huge_delta"
            return nil, "no_send_huge_delta"
        end
        local dt = clamp(now - (prev.t or now), 0.016, 0.25)
        local capH, capV
        if flyActive then
            capH = shieldOn and 1.35 or 1.45
            capV = shieldOn and 1.45 or 1.55
        elseif shieldOn then
            local safeRate = clamp(tonumber(gs and gs.safeWalkSpeedCap) or 10.4, 7.2, 13.5)
            capH = clamp(dt * safeRate + 0.30, 0.34, 2.35)
            capV = clamp(dt * 24.5 + 0.45, 0.45, 3.35)
        else
            capH = 3.55
            capV = 3.35
        end
        if absDx > capH or absDy > capV then
            local cdx = clamp(dx, -capH, capH)
            local cdy = clamp(dy, -capV, capV)
            px = prev.x + cdx
            py = prev.y + cdy
            if flyActive then
                local dtPrev = math.max(0.055, now - (prev.t or now))
                vx = clamp(cdx / dtPrev, -18.0, 18.0)
                vy = clamp(cdy / dtPrev, -22.0, 24.0)
            else
                vx = clamp(vx, -10.5, 10.5)
                vy = clamp(vy, -24.0, 24.0)
                local facingBit = (math.floor(flags) % 2 == 1) and 1 or 0
                flags = facingBit + 2
            end
        end
    end

    if shieldOn and not flyActive and not forceBypass then
        vx = clamp(vx, -12.0, 12.0)
        vy = clamp(vy, -26.0, 26.0)
    end

    if shieldOn and not flyActive and not fromBot and not forceBypass and prev and (now - (H.fwMoveLastSentAt or 0)) < 0.026 then
        local sameGrounded = (math.floor(flags) % 4 >= 2) == (math.floor(prev.flags or 2) % 4 >= 2)
        if sameGrounded and math.abs(px - prev.x) < 0.14 and math.abs(py - prev.y) < 0.14 then
            return nil, "move_rate_coalesce"
        end
    end

    local cleanPkt = { x = px, y = py, vx = vx, vy = vy, flags = flags, t = ts }
    H.fwMoveLastSentAt = now
    H.lastSentMove = { x = px, y = py, vx = vx, vy = vy, flags = flags, t = now }
    H.antiBackAnchor = { x = px, y = py, t = now }
    if ms and ms.fly then
        H.flyLastValidPos = { x = px, y = py, vx = vx, vy = vy, t = now }
    end
    return cleanPkt, "ok"
end

function Core.EnsureMoveHook()
    local net = H.Net
    if not net or not net.move or type(net.move.send) ~= "function" then return end
    if not H.moveHooked or H.moveHookedFor ~= net then
        H.origMoveSend = H.origMoveSend or net.move.send
        H.moveHooked = true
        H.moveHookedFor = net
        net.move.send = function(pkt)
            local cleanPkt = Core.SanitizeOutboundMove(pkt, false, false)
            if not cleanPkt then return nil end
            return H.origMoveSend(cleanPkt)
        end
    end
end

function Core.ClearVisualCrack(tx, ty)
    local gt = H.gt
    if not gt or not gt.w or type(tx) ~= "number" or type(ty) ~= "number" then return end
    local rh = rawget(gt, "remoteHit")
    if type(rh) ~= "function" then return end
    local cMap = uv(rh, 5)
    local cPool = uv(rh, 6)
    if type(cMap) ~= "table" then return end
    local cIdx = ty * gt.w + tx
    local entry = cMap[cIdx]
    if type(entry) == "table" then
        local img = entry.l
        if typeof(img) == "Instance" then
            pcall(function() img.Visible = false end)
            if type(cPool) == "table" then
                table.insert(cPool, img)
            end
        end
        cMap[cIdx] = nil
    end
end

function Core.EnsureTileHook()
    local gt = H.gt
    if not gt or type(gt.tileChanged) ~= "function" or H.tileHookedFor == gt then return end
    H.tileHookedFor = gt
    H.tileAck = H.tileAck or {}
    H.recentSelfEdits = H.recentSelfEdits or {}
    local orig = gt.tileChanged
    H.origTileChanged = orig
    gt.tileChanged = function(layerName, x, y, id, flip)
        if not H.mirroring and type(x) == "number" and type(y) == "number" and gt.w then
            local key = tostring(layerName) .. ":" .. (y * gt.w + x)
            local nowT = os.clock()
            H.tileAck[key] = { id = id, t = nowT }
            local selfAt = H.recentSelfEdits and H.recentSelfEdits[key]
            if selfAt and (nowT - selfAt) <= 1.25 then
                H.serverTileEchoSeen = true
            end
        end
        if id == 0 and type(x) == "number" and type(y) == "number" then
            pcall(Core.ClearVisualCrack, x, y)
        end
        return orig(layerName, x, y, id, flip)
    end
end

function Core.MarkSelfTileEdit(layer, tx, ty)
    local gt = H.gt
    if not gt or not gt.w or type(tx) ~= "number" or type(ty) ~= "number" then return end
    H.recentSelfEdits = H.recentSelfEdits or {}
    local layerName = (layer == 2) and "bg" or "fg"
    H.recentSelfEdits[layerName .. ":" .. (ty * gt.w + tx)] = os.clock()
end

function Core.NotifyServerMessage(text)
    if type(text) ~= "string" then return end
    local low = string.lower(text)
    local now = os.clock()
    local gs = SYT_Logic.GetcSkipper and SYT_Logic.GetcSkipper.State
    local adapt = not (gs and gs.ultimaxAdaptiveBackoff == false)
    if string.find(low, "placing too fast", 1, true) or (string.find(low, "too fast", 1, true) and not string.find(low, "chatting", 1, true)) then
        H.lastPlaceRejectedAt = now
        H.adaptivePlaceGap = clamp((H.adaptivePlaceGap or 0.168) + (adapt and 0.045 or 0.032), 0.165, 0.48)
        H.nextPlaceAllowedAt = math.max(H.nextPlaceAllowedAt or 0, now + (adapt and 0.65 or 0.34))
        H.ultimaxLastAlert = "place_too_fast"
    end
    if string.find(low, "chatting too fast", 1, true) or string.find(low, "flood", 1, true) or string.find(low, "wait a moment", 1, true) or string.find(low, "too many", 1, true) then
        H.chatBackoffUntil = math.max(H.chatBackoffUntil or 0, now + (adapt and 4.2 or 3.4))
        H.ultimaxLastAlert = "chat_or_flood_limit"
    end
    if string.find(low, "have banned", 1, true) or string.find(low, "modnotice", 1, true) or string.find(low, "warning from", 1, true) then
        H.ultimaxNoticeCount = (H.ultimaxNoticeCount or 0) + 1
        H.ultimaxLastNotice = string.sub(text, 1, 64)
    end
end

function Core.NotifyModNotice(kind, detail)
    local kLow = string.lower(tostring(kind or ""))
    H.ultimaxNoticeCount = (H.ultimaxNoticeCount or 0) + 1
    H.ultimaxLastNotice = tostring(kind or "-") .. (detail and detail ~= "" and (": " .. tostring(detail)) or "")
    H.ultimaxLastNoticeAt = os.clock()
    local gs = SYT_Logic.GetcSkipper and SYT_Logic.GetcSkipper.State
    local severe = (kLow == "warn" or kLow == "mute" or kLow == "freeze" or kLow == "kick" or kLow == "banned" or kLow == "nuke" or kLow == "hell")
    if severe and gs and gs.ultimaxEnabled ~= false and gs.ultimaxAdaptiveBackoff ~= false then
        H.nextPlaceAllowedAt = math.max(H.nextPlaceAllowedAt or 0, os.clock() + 3.0)
        H.chatBackoffUntil = math.max(H.chatBackoffUntil or 0, os.clock() + 5.0)
        task.defer(function()
            if type(SYT_Logic.StopAllAutomation) == "function" then
                pcall(SYT_Logic.StopAllAutomation, "ULTIMAX Auto-Pause: ModNotice (" .. tostring(kind) .. ")")
            end
        end)
    end
end

function Core.InstallUltimaxNamecallGuard()
    local gEnv = getEnv()
    local gs = SYT_Logic.GetcSkipper and SYT_Logic.GetcSkipper.State
    gEnv.__SYT_ULTIMAX_CALLBACK = function(selfObj, methodName, reasonArg)
        if methodName == "SendAsync" and type(reasonArg) == "string" and string.sub(reasonArg, 1, 1) == "/" then
            local okCh, isTc = pcall(function() return typeof(selfObj) == "Instance" and selfObj:IsA("TextChannel") end)
            if okCh and isTc then
                local fn = gEnv.__SYT_PROXY_CMD_HANDLER
                local lpObj = LP or Players.LocalPlayer
                if type(fn) == "function" then
                    local okCmd, handled = pcall(fn, reasonArg, lpObj and lpObj.Name or "")
                    if okCmd and handled then
                        return true
                    end
                end
            end
        end
        local curLogic = gEnv.SYT_Logic or SYT_Logic
        local s = curLogic and curLogic.GetcSkipper and curLogic.GetcSkipper.State
        if s and (s.antiKickShield == false or s.ultimaxEnabled == false or s.ultimaxNamecallGuard == false) then
            return false
        end
        local localPlr = LP or Players.LocalPlayer
        if selfObj == localPlr and (methodName == "Kick" or methodName == "kick") then
            H.ultimaxKickBlocked = (H.ultimaxKickBlocked or 0) + 1
            H.ultimaxLastKickReason = tostring(reasonArg or "LocalPlayer:Kick")
            return true
        end
        return false
    end

    if gs and (gs.ultimaxEnabled == false or gs.ultimaxNamecallGuard == false) then
        return false
    end
    if gEnv.__SYT_ULTIMAX_NAMECALL_HOOKED then
        H.ultimaxNamecallHooked = true
        return true
    end

    local hooked = false
    local getMethod = (type(getnamecallmethod) == "function" and getnamecallmethod) or nil
    local wrapClos = (type(newcclosure) == "function" and newcclosure) or function(fn) return fn end

    if type(hookfunction) == "function" and not gEnv.__SYT_ULTIMAX_KICKFN_HOOKED then
        pcall(function()
            local localPlr = LP or Players.LocalPlayer
            if localPlr and type(localPlr.Kick) == "function" then
                local origKickFn
                origKickFn = hookfunction(localPlr.Kick, wrapClos(function(selfObj, reasonArg, ...)
                    local cb = gEnv.__SYT_ULTIMAX_CALLBACK
                    if type(cb) == "function" and cb(selfObj, "Kick", reasonArg) then
                        return nil
                    end
                    return origKickFn(selfObj, reasonArg, ...)
                end))
                gEnv.__SYT_ULTIMAX_KICKFN_HOOKED = true
            end
        end)
    end

    if type(hookmetamethod) == "function" and getMethod then
        local okHook = pcall(function()
            local origNamecall
            origNamecall = hookmetamethod(game, "__namecall", wrapClos(function(selfObj, ...)
                local m = getMethod()
                local cb = gEnv.__SYT_ULTIMAX_CALLBACK
                if type(cb) == "function" and cb(selfObj, m, (select(1, ...))) then
                    return nil
                end
                return origNamecall(selfObj, ...)
            end))
            gEnv.__SYT_ORIG_ULTIMAX_NAMECALL = origNamecall
            hooked = true
        end)
        if okHook and hooked then
            gEnv.__SYT_ULTIMAX_NAMECALL_HOOKED = true
            H.ultimaxNamecallHooked = true
            return true
        end
    end

    if not hooked and type(getrawmetatable) == "function" and getMethod then
        pcall(function()
            local mt = getrawmetatable(game)
            if type(mt) ~= "table" or type(mt.__namecall) ~= "function" then return end
            local unlock = (type(setreadonly) == "function" and function(val) setreadonly(mt, val) end)
                or (type(make_writeable) == "function" and function(val) if not val then make_writeable(mt) end end)
            if unlock then pcall(unlock, false) end
            local origNamecall = mt.__namecall
            mt.__namecall = wrapClos(function(selfObj, ...)
                local m = getMethod()
                local cb = gEnv.__SYT_ULTIMAX_CALLBACK
                if type(cb) == "function" and cb(selfObj, m, (select(1, ...))) then
                    return nil
                end
                return origNamecall(selfObj, ...)
            end)
            if unlock then pcall(unlock, true) end
            gEnv.__SYT_ORIG_ULTIMAX_NAMECALL = origNamecall
            hooked = true
        end)
    end

    if hooked then
        gEnv.__SYT_ULTIMAX_NAMECALL_HOOKED = true
        H.ultimaxNamecallHooked = true
    end
    return hooked
end

function Core.EnsureOutboundFirewall()
    local net = H.Net
    if not net then return false end
    if H.firewallHooked and H.firewallHookedFor == net then
        return true
    end
    H.firewallHookedFor = net
    local gEnv = getEnv()
    local fwStore = rawget(gEnv, "__SYT_FW_ORIG_STORE")
    if type(fwStore) ~= "table" then
        fwStore = {}
        gEnv.__SYT_FW_ORIG_STORE = fwStore
    end
    local netOrig = fwStore[net]
    if type(netOrig) ~= "table" then
        netOrig = {}
        fwStore[net] = netOrig
    end
    local function resolveOrigFn(key, curFn)
        if type(netOrig[key]) == "function" then
            return netOrig[key]
        end
        if type(curFn) == "function" then
            netOrig[key] = curFn
        end
        return curFn
    end

    H.origNetSendMap = {}
    H.origNetCallFn = nil
    H.fwBucket = H.fwBucket or {}
    H.fwTileLastAt = H.fwTileLastAt or {}

    local function blockPacket(reason)
        H.fwBlockedCount = (H.fwBlockedCount or 0) + 1
        H.fwLastBlockReason = tostring(reason or "blocked")
        H.fwLastBlockAt = os.clock()
        return nil
    end

    local function allowWindow(chan, maxCount, winSec)
        local now = os.clock()
        local q = H.fwBucket[chan]
        if not q then q = {}; H.fwBucket[chan] = q end
        local cut = now - winSec
        local writeIdx = 1
        for i = 1, #q do
            if q[i] >= cut then
                q[writeIdx] = q[i]
                writeIdx += 1
            end
        end
        for i = writeIdx, #q do q[i] = nil end
        if #q >= maxCount then
            return false
        end
        q[#q + 1] = now
        return true
    end

    local function shieldActive()
        local gs = SYT_Logic.GetcSkipper and SYT_Logic.GetcSkipper.State
        return not (gs and gs.antiKickShield == false)
    end

    local function ultimaxActive()
        local gs = SYT_Logic.GetcSkipper and SYT_Logic.GetcSkipper.State
        return shieldActive() and not (gs and gs.ultimaxEnabled == false)
    end

    local function realIsStaff()
        if not LP then return false end
        local vs = SYT_Logic.Visual and SYT_Logic.Visual.State
        local rawTag = (vs and vs.origSaved) and vs.origTag or LP:GetAttribute("Tag")
        local tl = string.lower(tostring(rawTag or ""))
        if tl == "developer" or tl == "moderator" or tl == "admin" or tl == "mod" or tl == "dev" then
            return true
        end
        if H.Roles and type(H.Roles.isStaff) == "function" then
            local origTag = vs and vs.origSaved and vs.origTag or nil
            if not (vs and vs.role ~= "none" and not origTag) then
                local ok, res = pcall(H.Roles.isStaff, LP.UserId)
                if ok and res == true and not (vs and vs.origSaved and vs.origTag == nil) then return true end
            end
        end
        return false
    end

    local function withinRealReach(tx, ty, kind, tol)
        local pos = Core.ReadPos()
        local r = Core.GetRealServerRange(kind) + (tol or 0.68)
        local dx = math.abs((tx + 0.5) - pos.x)
        local dy = math.abs((ty + 0.5) - (pos.y - 0.475))
        return dx <= r and dy <= r
    end

    local function guardRateSend(pktName, maxCnt, winSec, validatorFn)
        local ch = rawget(net, pktName)
        if type(ch) == "table" and type(ch.send) == "function" then
            local origFn = resolveOrigFn(pktName, ch.send)
            H.origNetSendMap[pktName] = origFn
            ch.send = function(pkt)
                if ultimaxActive() then
                    if type(validatorFn) == "function" then
                        local okV, reason = validatorFn(pkt)
                        if okV == false then
                            return blockPacket(reason or (pktName .. "_invalid"))
                        end
                    end
                    if not allowWindow("pkt_" .. pktName, maxCnt, winSec) then
                        return blockPacket(pktName .. "_burst")
                    end
                end
                return origFn(pkt)
            end
        end
    end

    if net.tile and type(net.tile.send) == "function" then
        local origTile = resolveOrigFn("tile", net.tile.send)
        H.origNetSendMap.tile = origTile
        net.tile.send = function(pkt)
            if shieldActive() and type(pkt) == "table" then
                local gt = H.gt
                local tx, ty = toInt(pkt.x), toInt(pkt.y)
                local lyr = toInt(pkt.layer, 1)
                local id = toInt(pkt.id, 0)
                if not tx or not ty or (gt and (tx < 0 or tx >= gt.w or ty < 0 or ty >= gt.h)) then
                    return blockPacket("tile_oob")
                end
                if type(Core.CanRealEditTile) == "function" and not Core.CanRealEditTile(tx, ty) then
                    return blockPacket("tile_locked_area")
                end
                local curId = Core.GetLayerTile(tx, ty, lyr)
                if curId ~= 0 and Core.IsProtectedTile(curId) then
                    return blockPacket("tile_protected")
                end
                local kind = (id == 0) and "break" or "place"
                if not withinRealReach(tx, ty, kind, 0.72) then
                    return blockPacket("tile_out_of_real_range")
                end
                local now = os.clock()
                if id ~= 0 then
                    local rejAt = H.lastPlaceRejectedAt or 0
                    local rejCooldown = ultimaxActive() and 0.55 or 0.28
                    if (rejAt > 0 and (now - rejAt) < rejCooldown) or now < (H.nextPlaceAllowedAt or 0) or (now - (H.fwLastPlaceSentAt or 0)) < 0.145 then
                        return blockPacket("place_flood")
                    end
                    if not allowWindow("place", 6, 0.92) then
                        return blockPacket("place_burst")
                    end
                    H.fwLastPlaceSentAt = now
                else
                    local tk = tostring(lyr) .. ":" .. tostring(tx) .. "," .. tostring(ty)
                    if (now - (H.fwTileLastAt[tk] or 0)) < 0.055 then
                        return blockPacket("break_same_tile_flood")
                    end
                    if not allowWindow("break_tile", 10, 0.28) then
                        return blockPacket("break_tile_burst")
                    end
                    H.fwTileLastAt[tk] = now
                end
            end
            return origTile(pkt)
        end
    end

    if net.punch and type(net.punch.send) == "function" then
        local origPunch = resolveOrigFn("punch", net.punch.send)
        H.origNetSendMap.punch = origPunch
        net.punch.send = function(pkt)
            if shieldActive() and type(pkt) == "table" then
                local tx = tonumber(pkt.tx or pkt.x)
                local ty = tonumber(pkt.ty or pkt.y)
                if tx and ty then
                    local itx, ity = math.floor(tx), math.floor(ty)
                    if not withinRealReach(itx, ity, "punch", 0.75) then
                        return blockPacket("punch_out_of_range")
                    end
                    if type(Core.CanRealEditTile) == "function" and not Core.CanRealEditTile(itx, ity) then
                        return blockPacket("punch_locked_area")
                    end
                end
                if not allowWindow("punch", 10, 0.30) then
                    return blockPacket("punch_burst")
                end
            end
            return origPunch(pkt)
        end
    end

    if net.act and type(net.act.send) == "function" then
        local origAct = resolveOrigFn("act", net.act.send)
        H.origNetSendMap.act = origAct
        net.act.send = function(pkt)
            if shieldActive() and type(pkt) == "table" then
                local px, py = tonumber(pkt.x), tonumber(pkt.y)
                if px and py then
                    local tx, ty = math.floor(px), math.floor(py)
                    local kind = (pkt.kind == 2 or pkt.kind == 3) and "place" or "punch"
                    if not withinRealReach(tx, ty, kind, 1.15) then
                        return blockPacket("act_out_of_range")
                    end
                end
                if not allowWindow("act", 26, 0.28) then
                    return blockPacket("act_burst")
                end
            end
            return origAct(pkt)
        end
    end

    if net.harvest and type(net.harvest.send) == "function" then
        local origHarv = resolveOrigFn("harvest", net.harvest.send)
        H.origNetSendMap.harvest = origHarv
        net.harvest.send = function(pkt)
            if shieldActive() and type(pkt) == "table" then
                local tx, ty = toInt(pkt.x), toInt(pkt.y)
                if not tx or not ty then return blockPacket("harvest_bad") end
                if not withinRealReach(tx, ty, "punch", 0.75) then
                    return blockPacket("harvest_out_of_range")
                end
                if type(Core.CanRealEditTile) == "function" and not Core.CanRealEditTile(tx, ty) then
                    return blockPacket("harvest_locked")
                end
                if not allowWindow("harvest", 8, 0.30) then
                    return blockPacket("harvest_burst")
                end
            end
            return origHarv(pkt)
        end
    end

    if net.splice and type(net.splice.send) == "function" then
        local origSpl = resolveOrigFn("splice", net.splice.send)
        H.origNetSendMap.splice = origSpl
        net.splice.send = function(pkt)
            if shieldActive() and type(pkt) == "table" then
                local tx, ty = toInt(pkt.x or pkt.tx), toInt(pkt.y or pkt.ty)
                if tx and ty then
                    if not withinRealReach(tx, ty, "place", 0.75) then
                        return blockPacket("splice_out_of_range")
                    end
                    if type(Core.CanRealEditTile) == "function" and not Core.CanRealEditTile(tx, ty) then
                        return blockPacket("splice_locked")
                    end
                end
                if not allowWindow("splice", 5, 0.75) then
                    return blockPacket("splice_burst")
                end
            end
            return origSpl(pkt)
        end
    end

    if net.drop and type(net.drop.send) == "function" then
        local origDrop = resolveOrigFn("drop", net.drop.send)
        H.origNetSendMap.drop = origDrop
        net.drop.send = function(pkt)
            if shieldActive() then
                local now = os.clock()
                if (now - (H.fwLastDropSentAt or 0)) < 1.08 then
                    return blockPacket("drop_cooldown")
                end
                H.fwLastDropSentAt = now
            end
            return origDrop(pkt)
        end
    end

    if net.take and type(net.take.send) == "function" then
        local origTake = resolveOrigFn("take", net.take.send)
        H.origNetSendMap.take = origTake
        net.take.send = function(pkt)
            if shieldActive() and not allowWindow("take", 16, 0.35) then
                return blockPacket("take_burst")
            end
            return origTake(pkt)
        end
    end

    if net.wear and type(net.wear.send) == "function" then
        local origWear = resolveOrigFn("wear", net.wear.send)
        H.origNetSendMap.wear = origWear
        net.wear.send = function(pkt)
            if shieldActive() and not allowWindow("wear", 3, 0.80) then
                return blockPacket("wear_burst")
            end
            local curLogic = getEnv().SYT_Logic or SYT_Logic
            local vs = curLogic and curLogic.Visual and curLogic.Visual.State
            if vs and type(pkt) == "table" and type(vs.fakeWorn) == "table" and next(vs.fakeWorn) ~= nil then
                local cleanPkt = {}
                for sl, id in pairs(pkt) do
                    if type(id) == "number" and id > 0 then
                        local isSpoofSlot = (vs.fakeWorn[sl] ~= nil)
                        if (not isSpoofSlot) and Core.CountItem(id) > 0 then
                            cleanPkt[sl] = id
                        elseif type(vs.origWorn) == "table" and type(vs.origWorn[sl]) == "number" and vs.origWorn[sl] > 0 and Core.CountItem(vs.origWorn[sl]) > 0 then
                            cleanPkt[sl] = vs.origWorn[sl]
                        end
                    end
                end
                for sl, origId in pairs(vs.origWorn or {}) do
                    if vs.fakeWorn[sl] == 0 and type(origId) == "number" and origId > 0 and Core.CountItem(origId) > 0 then
                        cleanPkt[sl] = origId
                    end
                end
                return origWear(cleanPkt)
            end
            return origWear(pkt)
        end
    end

    -- ULTIMAX Packet Firewall untuk seluruh packet interaksi/ekonomi/world di Net.lua
    guardRateSend("toggle", 5, 0.60, function(pkt)
        if type(pkt) == "table" and pkt.x and pkt.y then
            local tx, ty = toInt(pkt.x), toInt(pkt.y)
            if tx and ty and not withinRealReach(tx, ty, "place", 1.25) then
                return false, "toggle_out_of_range"
            end
        end
        return true
    end)
    guardRateSend("spin", 1, 0.85)
    guardRateSend("doorPass", 2, 1.00)
    guardRateSend("recycle", 4, 0.80)
    guardRateSend("cycle", 5, 0.65)
    guardRateSend("convert", 3, 0.90)
    guardRateSend("feed", 5, 0.70)
    guardRateSend("spray", 5, 0.70)
    guardRateSend("useOn", 4, 0.90)
    guardRateSend("openPack", 4, 0.80)
    guardRateSend("buy", 4, 0.80)
    guardRateSend("display", 4, 0.80)
    guardRateSend("vend", 4, 0.80)
    guardRateSend("hubBuy", 3, 0.90)
    guardRateSend("donation", 3, 0.90)
    guardRateSend("trade", 6, 0.70)
    guardRateSend("list", 3, 1.20)

    if net.ask and type(net.ask.send) == "function" then
        local origAskSend = resolveOrigFn("ask", net.ask.send)
        H.origNetSendMap.ask = origAskSend
        net.ask.send = function(pkt)
            if ultimaxActive() and type(pkt) == "table" then
                local fnId = toInt(pkt.fn, 0)
                local askName = (type(net.ASK) == "table" and fnId > 0) and tostring(net.ASK[fnId] or "") or ""
                if askName == "ModCommand" then
                    if not realIsStaff() and type(pkt.s) == "string" and not string.find(pkt.s, '"msg"', 1, true) then
                        return blockPacket("ask_nonstaff_modcommand")
                    end
                    if not allowWindow("ask_modcommand", 1, 2.35) then
                        return blockPacket("ask_modcommand_flood")
                    end
                elseif askName == "ReportPlayer" and not allowWindow("ask_report", 1, 5.0) then
                    return blockPacket("ask_report_flood")
                elseif askName == "WorldCommand" and not allowWindow("ask_worldcmd", 2, 1.2) then
                    return blockPacket("ask_worldcmd_flood")
                elseif askName == "SaveSettings" and not allowWindow("ask_saveset", 2, 1.5) then
                    return blockPacket("ask_saveset_flood")
                elseif askName == "Broadcast" and not allowWindow("ask_bc", 1, 2.0) then
                    return blockPacket("ask_bc_flood")
                end
            end
            return origAskSend(pkt)
        end
    end

    if type(net.call) == "function" then
        local origCall = resolveOrigFn("__call__", net.call)
        H.origNetCallFn = origCall
        net.call = function(remoteName, ...)
            local rName = tostring(remoteName)
            if shieldActive() and rName == "ModCommand" then
                local subCmd = tostring((select(1, ...)) or "")
                if subCmd ~= "msg" and not realIsStaff() then
                    return blockPacket("nonstaff_modcommand")
                end
                if not allowWindow("modcommand_msg", 1, 2.35) then
                    return blockPacket("modcommand_flood")
                end
            elseif ultimaxActive() then
                if rName == "WorldCommand" and not allowWindow("call_worldcmd", 2, 1.2) then
                    return blockPacket("worldcmd_flood")
                elseif rName == "ReportPlayer" and not allowWindow("call_report", 1, 5.0) then
                    return blockPacket("report_flood")
                elseif rName == "SaveSettings" and not allowWindow("call_saveset", 2, 1.5) then
                    return blockPacket("saveset_flood")
                elseif rName == "Broadcast" and not allowWindow("call_bc", 1, 2.0) then
                    return blockPacket("broadcast_flood")
                end
            end
            if rName == "GetProfile" then
                local targetUid = select(1, ...)
                local ret = { origCall(remoteName, ...) }
                if type(gEnv.__SYT_OVERLAY_PROFILE_FN) == "function" then
                    pcall(gEnv.__SYT_OVERLAY_PROFILE_FN, targetUid, ret)
                end
                return table.unpack(ret)
            end
            return origCall(remoteName, ...)
        end
    end

    gEnv.__SYT_MODNOTICE_CB = function(kind, detail)
        Core.NotifyModNotice(kind, detail)
    end
    if type(net.on) == "function" and not netOrig.__modNoticeHooked then
        netOrig.__modNoticeHooked = true
        pcall(net.on, "ModNotice", function(kind, detail)
            local cb = gEnv.__SYT_MODNOTICE_CB
            if type(cb) == "function" then cb(kind, detail) end
        end)
    end

    pcall(Core.InstallUltimaxNamecallGuard)
    H.firewallHooked = true
    return true
end

function Core.EnsureChatWarnHook()
    if H.chatWarnHooked then return end
    local hookedAny = false
    if H.stateObj then
        for _, mName in ipairs({ "onSay", "say", "console" }) do
            local origFn = rawget(H.stateObj, mName)
            if type(origFn) == "function" then
                H.stateObj[mName] = function(msg, ...)
                    Core.NotifyServerMessage(msg)
                    return origFn(msg, ...)
                end
                hookedAny = true
            end
        end
    end
    local pg = LP and LP:FindFirstChildOfClass("PlayerGui")
    local gg = pg and pg:FindFirstChild("GameGui")
    local chatMod = gg and gg:FindFirstChild("ChatUI")
    if chatMod and chatMod:IsA("ModuleScript") then
        local okReq, chatTbl = pcall(require, chatMod)
        if okReq and type(chatTbl) == "table" and type(chatTbl.add) == "function" and not H.origChatAdd then
            local origAdd = chatTbl.add
            H.origChatAdd = origAdd
            chatTbl.add = function(msg, cat, ...)
                Core.NotifyServerMessage(msg)
                return origAdd(msg, cat, ...)
            end
            hookedAny = true
        end
    end
    if hookedAny then H.chatWarnHooked = true end
end

function Core.PlayVisualPunch(tx, ty, showVisual)
    if showVisual == false then return end
    local gt = H.gt
    if gt and type(rawget(gt, "remoteHit")) == "function" then
        pcall(gt.remoteHit, tx, ty, false)
    end
end

function Core.DiscoverWheelSpins(allowGcFallback)
    if type(H.wheelSpins) == "table" then return H.wheelSpins end
    local gt, db, net = H.gt, H.ItemDB, H.Net
    local function isPlainWheelTbl(t)
        return type(t) == "table" and t ~= gt and t ~= db and t ~= net and t ~= H.inv and t ~= H.trees
            and type(rawget(t, "play")) ~= "function" and type(rawget(t, "playAt")) ~= "function"
            and type(rawget(t, "worldTag")) ~= "function" and type(rawget(t, "fg")) ~= "table"
    end
    local function checkGameWheelFn(fn)
        if type(fn) ~= "function" then return nil end
        local u1, u2, u3 = uv(fn, 1), uv(fn, 2), uv(fn, 3)
        if u1 == db and u3 == gt and isPlainWheelTbl(u2) then return u2 end -- updateSpins
        if u2 == gt and u3 == db and isPlainWheelTbl(u1) then return u1 end -- spin
        if u1 == gt and u2 == db and isPlainWheelTbl(u3) then return u3 end -- WheelSpun listener
        return nil
    end
    if net and net.wheelSpun and type(net.wheelSpun.getListeners) == "function" then
        local okL, ls = pcall(net.wheelSpun.getListeners)
        if okL and type(ls) == "table" then
            for _, lfn in ipairs(ls) do
                local hit = checkGameWheelFn(lfn)
                if hit then H.wheelSpins = hit; return hit end
                local uvs = guvs(lfn)
                if type(uvs) == "table" then
                    for _, sub in pairs(uvs) do
                        local subHit = checkGameWheelFn(sub)
                        if subHit then H.wheelSpins = subHit; return subHit end
                    end
                end
            end
        end
    end
    if allowGcFallback and gt and db then
        local gcFns = safeGetGC(false)
        for i, fn in ipairs(gcFns) do
            if type(fn) == "function" then
                local src = fnSource(fn)
                if src == "" or string.find(src, "Game", 1, true) then
                    local hit = checkGameWheelFn(fn)
                    if hit then H.wheelSpins = hit; return hit end
                end
            end
            if i % 3500 == 0 then task.wait() end
        end
    end
    return H.wheelSpins
end

-- Auto-equip item dengan atribut .dig > 0 (misal Pickaxe/Drill) di Backpack saat 1-Hit aktif
function Core.EnsureBestDigEquipped()
    local sk = H.skillsObj
    local db = H.ItemDB
    if not sk or not db or type(sk.handDig) ~= "function" or type(sk.onWear) ~= "function" then
        return false, 0
    end
    local origHandDig = (H.skillsHookedFor == sk and H.origSkills and H.origSkills.handDig) or rawget(sk, "handDig")
    local curDig = (type(origHandDig) == "function") and (tonumber(select(2, pcall(origHandDig))) or 0) or 0
    if curDig > 0 then
        return true, curDig
    end
    local nowT = os.clock()
    if (nowT - (H.lastDigWearTryAt or 0)) < 1.5 then
        return false, curDig
    end
    local bestId, bestDig = nil, 0
    for _, slot in ipairs(Core.GetBackpackSlots()) do
        if (slot.n or 0) > 0 then
            local info = db[slot.id]
            local d = info and (tonumber(info.dig) or 0) or 0
            if d > bestDig then
                bestDig = d
                bestId = slot.id
            end
        end
    end
    if bestId and bestDig > 0 then
        local alreadyWorn = (type(sk.isWorn) == "function") and (select(2, pcall(sk.isWorn, bestId)) == true)
        if not alreadyWorn then
            H.lastDigWearTryAt = nowT
            pcall(sk.onWear, bestId)
        end
        local afterDig = tonumber(select(2, pcall(sk.handDig))) or bestDig
        return afterDig > 0, afterDig
    end
    return false, curDig
end

function Core.InstallGetgcBypassHooks()
    local sk = H.skillsObj
    if sk and H.skillsHookedFor ~= sk then
        local orig = {
            handPower  = rawget(sk, "handPower"),
            punchRange = rawget(sk, "punchRange"),
            buildRange = rawget(sk, "buildRange"),
            handDig    = rawget(sk, "handDig"),
            wornSpeed  = rawget(sk, "wornSpeed"),
            slowFall   = rawget(sk, "slowFall"),
            fireproof  = rawget(sk, "fireproof"),
            blocked    = rawget(sk, "blocked"),
            isWorn     = rawget(sk, "isWorn"),
            applyWorn  = rawget(sk, "applyWorn"),
        }
        H.origSkills = orig
        H.origHandPower = orig.handPower or H.origHandPower
        H.skillsHookedFor = sk

        if type(orig.isWorn) == "function" then
            local w = uv(orig.isWorn, 1)
            if type(w) == "table" then H.wornTbl = w end
        end
        if type(orig.applyWorn) == "function" then
            if type(H.wornTbl) ~= "table" then
                local w = uv(orig.applyWorn, 1)
                if type(w) == "table" then H.wornTbl = w end
            end
            local ps = uv(orig.applyWorn, 2)
            if type(ps) == "table" and (type(rawget(ps, "rigs")) == "table" or typeof(rawget(ps, "SKIN")) == "Color3" or type(rawget(ps, "applyFeet")) == "function") then
                H.playerSpriteObj = ps
            end
        end

        if type(orig.handPower) == "function" then
            sk.handPower = function(...)
                local gs = SYT_Logic.GetcSkipper and SYT_Logic.GetcSkipper.State
                local on = ((H.oneHitForceUntil or 0) > os.clock())
                    or (SYT_Logic.PNB and SYT_Logic.PNB.State and SYT_Logic.PNB.State.oneHit)
                    or (SYT_Logic.Pabrik and SYT_Logic.Pabrik.State and SYT_Logic.Pabrik.State.oneHit)
                    or (SYT_Logic.DirtFarm and SYT_Logic.DirtFarm.State and SYT_Logic.DirtFarm.State.oneHit)
                    or (gs and gs.enabled and gs.bypassHandPower)
                if on then return 99 end
                return orig.handPower(...)
            end
        end
        if type(orig.punchRange) == "function" then
            sk.punchRange = function(...)
                local okO, origV = pcall(orig.punchRange, ...)
                local base = okO and tonumber(origV) or 2.5
                local gs = SYT_Logic.GetcSkipper and SYT_Logic.GetcSkipper.State
                if gs and gs.enabled and gs.bypassClientRange then
                    return math.max(base, tonumber(gs.maxRangeTiles) or 12)
                end
                if okO then return origV end
                return base
            end
        end
        if type(orig.buildRange) == "function" then
            sk.buildRange = function(...)
                local okO, origV = pcall(orig.buildRange, ...)
                local base = okO and tonumber(origV) or 2.5
                local gs = SYT_Logic.GetcSkipper and SYT_Logic.GetcSkipper.State
                if gs and gs.enabled and gs.bypassClientRange then
                    return math.max(base, tonumber(gs.maxRangeTiles) or 12)
                end
                if okO then return origV end
                return base
            end
        end
        if type(orig.wornSpeed) == "function" then
            sk.wornSpeed = function(...)
                local okO, origV = pcall(orig.wornSpeed, ...)
                local base = okO and tonumber(origV) or 1
                local gs = SYT_Logic.GetcSkipper and SYT_Logic.GetcSkipper.State
                if gs and gs.enabled and gs.bypassWalkSpeed then
                    local reqScale = tonumber(gs.walkSpeedScale) or 1.45
                    if gs.antiKickShield ~= false then
                        reqScale = math.min(reqScale, 1.38)
                    end
                    return math.max(base, reqScale)
                end
                if (H.dfSpeedForceUntil or 0) > os.clock() then
                    return math.max(base, 1.32)
                end
                if okO then return origV end
                return base
            end
        end
        if type(orig.handDig) == "function" then
            sk.handDig = function(...)
                local okO, origV = pcall(orig.handDig, ...)
                local gs = SYT_Logic.GetcSkipper and SYT_Logic.GetcSkipper.State
                if gs and gs.enabled and gs.bypassHandPower then
                    if type(origV) == "boolean" then return true end
                    if type(origV) == "number" then return math.max(origV, 99) end
                end
                if okO then return origV end
                return false
            end
        end
        if type(orig.airJumps) == "function" then
            sk.airJumps = function(...)
                if H._stripWingDoubleJump then return 0 end
                return orig.airJumps(...)
            end
        end
        if type(orig.slowFall) == "function" then
            sk.slowFall = function(...)
                local gs = SYT_Logic.GetcSkipper and SYT_Logic.GetcSkipper.State
                if gs and gs.enabled and gs.bypassPhysics then return true end
                return orig.slowFall(...)
            end
        end
        if type(orig.fireproof) == "function" then
            sk.fireproof = function(...)
                local gs = SYT_Logic.GetcSkipper and SYT_Logic.GetcSkipper.State
                if gs and gs.enabled and gs.bypassPhysics then return true end
                return orig.fireproof(...)
            end
        end
        if type(orig.blocked) == "function" then
            sk.blocked = function(...)
                local gs = SYT_Logic.GetcSkipper and SYT_Logic.GetcSkipper.State
                if gs and gs.enabled and gs.bypassUiBlock then return false end
                return orig.blocked(...)
            end
        end
    end

    local gt = H.gt
    if gt then
        local areas = rawget(gt, "areas")
        if type(areas) == "table" and H.areasBypassedFor ~= areas then
            H.origAreas = {
                tbl       = areas,
                canEdit   = rawget(areas, "canEdit"),
                mayBuild  = rawget(areas, "mayBuild"),
                hasAccess = rawget(areas, "hasAccess"),
            }
            H.areasBypassedFor = areas
            if type(H.origAreas.canEdit) == "function" then
                areas.canEdit = function(...)
                    local gs = SYT_Logic.GetcSkipper and SYT_Logic.GetcSkipper.State
                    if gs and gs.enabled and gs.bypassClientLocks then return true end
                    return H.origAreas.canEdit(...)
                end
            end
            if type(H.origAreas.mayBuild) == "function" then
                areas.mayBuild = function(...)
                    local gs = SYT_Logic.GetcSkipper and SYT_Logic.GetcSkipper.State
                    if gs and gs.enabled and gs.bypassClientLocks then return true end
                    return H.origAreas.mayBuild(...)
                end
            end
            if type(H.origAreas.hasAccess) == "function" then
                areas.hasAccess = function(...)
                    local gs = SYT_Logic.GetcSkipper and SYT_Logic.GetcSkipper.State
                    if gs and gs.enabled and gs.bypassClientLocks then return true end
                    return H.origAreas.hasAccess(...)
                end
            end
        end

        if type(rawget(gt, "dropOk")) == "function" and H.dropOkHookedFor ~= gt then
            H.origDropOk = rawget(gt, "dropOk")
            H.dropOkHookedFor = gt
            gt.dropOk = function(...)
                local gs = SYT_Logic.GetcSkipper and SYT_Logic.GetcSkipper.State
                if gs and gs.enabled and (gs.bypassUiBlock or gs.bypassClientLocks) then
                    return true
                end
                return H.origDropOk(...)
            end
        end
    end
    return H.skillsHookedFor ~= nil
end

function Core.SyncOneHitHook(forceSec)
    if type(forceSec) == "number" and forceSec > 0 then
        H.oneHitForceUntil = math.max(H.oneHitForceUntil or 0, os.clock() + forceSec)
    end
    return Core.InstallGetgcBypassHooks()
end

function SYT_Logic.Init(forceRefresh)
    local nowT = os.clock()
    H.lastInitTryAt = nowT
    local curWName = (H.gt and type(rawget(H.gt, "name")) == "string") and rawget(H.gt, "name") or ""
    local worldChanged = (curWName ~= "" and curWName ~= H.lastWorldTag)
    if worldChanged then
        forceRefresh = true
        H.lastWorldTag = curWName
        H.inv = nil
        H.renderFn = nil
        H.renderPosPairs = {}
        H.pxIdx = nil
        H.skillsObj = nil
        H.origSkills = nil
        H.skillsHookedFor = nil
        H.nameTagObj = nil
        H.wornTbl = nil
        H.playerSpriteObj = nil
        H.origAreas = nil
        H.areasBypassedFor = nil
        H.origDropOk = nil
        H.dropOkHookedFor = nil
        H.origDrawWeather = nil
        H.weatherHookedFor = nil
        H.tileAck = {}
        H.recentSelfEdits = {}
        H.lastPlaceRejectedAt = 0
        H.nextPlaceAllowedAt = 0
        H.lastSentMove = nil
        H.antiBackAnchor = nil
        H.flyLastValidPos = nil
        H.goToGuardedFor = nil
        H.stopMoveUntil = 0
        Core.AllowMoveToWindow(2.0)
    end
    if H.initialized and not forceRefresh and isValidGT(H.gt) and H.Net and H.ItemDB and H.inv then
        Core.EnsureMoveHook()
        Core.EnsureManualInputHook()
        Core.EnsureTileHook()
        Core.EnsureChatWarnHook()
        Core.InstallGetgcBypassHooks()
        if not H.wheelSpins then Core.DiscoverWheelSpins(false) end
        if type(Core.EnsureWheelHook) == "function" then Core.EnsureWheelHook() end
        pcall(Core.InstallAntiBackGuard)
        if type(SYT_Logic.InstallNetGuard) == "function" then pcall(SYT_Logic.InstallNetGuard) end
        return true
    end

    H.Net        = H.Net        or safeRequireShared("Net")
    H.ItemDB     = H.ItemDB     or safeRequireShared("ItemDB")
    H.Roles      = H.Roles      or safeRequireShared("Roles")
    H.Assets     = H.Assets     or safeRequireShared("Assets")
    H.ItemIcon   = H.ItemIcon   or safeRequireShared("ItemIcon")
    H.Autotile   = H.Autotile   or safeRequireShared("Autotile")
    H.BitmapText = H.BitmapText or safeRequireShared("BitmapText")

    -- Fast path (<1ms): ambil H.gt & H.inv langsung dari koneksi RenderStepped tanpa freeze getgc
    if (not H.gt or not isValidGT(H.gt)) and type(getconnections) == "function" then
        local okConns, conns = pcall(getconnections, RunService.RenderStepped)
        if okConns and type(conns) == "table" then
            for _, c in ipairs(conns) do
                local fn = type(c) == "table" and (c.Function or c["function"]) or nil
                local u1 = fn and uv(fn, 1) or nil
                if isValidGT(u1) then
                    H.gt = u1
                    if not H.renderFn then
                        for idx = 1, 130 do
                            local val = uv(fn, idx)
                            if val == nil and idx > 110 then break end
                            if typeof(val) == "Instance" and val:IsA("UIScale") then
                                H.renderFn = fn
                                break
                            end
                        end
                    end
                    break
                end
            end
        end
    end

    if H.gt and type(rawget(H.gt, "backpackNow")) == "function" then
        local maybeInv = uv(H.gt.backpackNow, 1)
        if isValidInv(maybeInv) then
            H.inv = maybeInv
        end
        H.lastWorldTag = rawget(H.gt, "name") or H.lastWorldTag
    end

    local needTableScan = (not isValidGT(H.gt) or not H.Net or not H.ItemDB or not H.inv or not H.stateObj or not H.others or not H.skillsObj or not H.nameTagObj)
    if needTableScan and (nowT - (H.lastGcScanAt or 0) >= 4.0 or not isValidGT(H.gt)) then
        H.lastGcScanAt = nowT
        for _, v in ipairs(safeGetGC(true)) do
            if type(v) == "table" then
                if not H.gt and isValidGT(v) then
                    H.gt = v
                elseif not H.Net and isValidNet(v) then
                    H.Net = v
                elseif not H.ItemDB and isValidItemDB(v) then
                    H.ItemDB = v
                elseif (not H.inv or forceRefresh) and isValidInv(v) then
                    H.inv = v
                elseif not H.stateObj and isValidStateObj(v) then
                    H.stateObj = v
                elseif not H.others and isValidOthers(v) then
                    H.others = v
                elseif not H.trees and isTreeMapCandidate(v) then
                    H.trees = v
                elseif not H.wheelSpins and isWheelMapCandidate(v) then
                    H.wheelSpins = v
                elseif not H.particles and type(rawget(v, "swirl")) == "function" and type(rawget(v, "yolk")) == "function" then
                    H.particles = v
                elseif not H.backdropObj and type(rawget(v, "setWorld")) == "function" and type(rawget(v, "draw")) == "function" then
                    H.backdropObj = v
                elseif not H.skillsObj and type(rawget(v, "handPower")) == "function" and type(rawget(v, "punchRange")) == "function" and type(rawget(v, "buildRange")) == "function" then
                    H.skillsObj = v
                elseif not H.nameTagObj and type(rawget(v, "tagKey")) == "function" and type(rawget(v, "redraw")) == "function" then
                    H.nameTagObj = v
                end
            end
        end
    end

    if H.gt and type(rawget(H.gt, "backpackNow")) == "function" then
        local maybeInv = uv(H.gt.backpackNow, 1)
        if isValidInv(maybeInv) then
            H.inv = maybeInv
        end
        H.lastWorldTag = rawget(H.gt, "name") or H.lastWorldTag
    end

    if H.gt and not H.origTakeDrop and type(H.gt.takeDrop) == "function" then
        H.origTakeDrop = H.gt.takeDrop
    end
    if H.Net and H.Net.move and not H.origMoveSend and type(H.Net.move.send) == "function" then
        H.origMoveSend = H.Net.move.send
    end
    if H.Net and H.Net.died and not H.origDiedSend and type(H.Net.died.send) == "function" then
        H.origDiedSend = H.Net.died.send
    end

    if H.gt and (not H.renderFn or not H.skillsObj or not H.nameTagObj or not H.mobileControls or forceRefresh) then
        if worldChanged then
            H.mobileControls = nil
            H.mcCandidates = {}
        end
        pcall(inspectUpvalues, H.gt)
    end

    Core.EnsureMoveHook()
    Core.EnsureManualInputHook()
    Core.EnsureTileHook()
    Core.EnsureOutboundFirewall()
    pcall(Core.InstallUltimaxNamecallGuard)
    Core.EnsureChatWarnHook()
    Core.InstallGetgcBypassHooks()
    Core.DiscoverWheelSpins(false)
    if type(Core.EnsureWheelHook) == "function" then Core.EnsureWheelHook() end
    pcall(Core.InstallAntiBackGuard)
    if type(SYT_Logic.InstallNetGuard) == "function" then pcall(SYT_Logic.InstallNetGuard) end
    H.initialized = isValidGT(H.gt) and H.Net ~= nil and H.ItemDB ~= nil
    if worldChanged and H.initialized and SYT_Logic.Visual and type(SYT_Logic.Visual.OnWorldChanged) == "function" then
        pcall(SYT_Logic.Visual.OnWorldChanged)
    end
    return H.initialized
end

-- Pure Manual Input Hook (Game.lua MobileControls upvalue + MobileControls.current .dir() / .jumping())
function Core.EnsureManualInputHook()
    if not H._mcModRef then
        pcall(function()
            local pgui = LP and LP:FindFirstChild("PlayerGui")
            local ggui = pgui and pgui:FindFirstChild("GameGui")
            local mod = ggui and ggui:FindFirstChild("MobileControls")
            if mod then
                H._mcModRef = require(mod)
            end
        end)
    end

    H._mcWrapped = H._mcWrapped or setmetatable({}, { __mode = "k" })
    local list = {}
    local seen = {}
    local function pushCand(t)
        if type(t) == "table" and not seen[t]
            and type(rawget(t, "dir")) == "function"
            and type(rawget(t, "jumping")) == "function"
        then
            seen[t] = true
            list[#list + 1] = t
        end
    end

    pushCand(H.mobileControls)
    if type(H.mcCandidates) == "table" then
        for _, cand in ipairs(H.mcCandidates) do
            pushCand(cand)
        end
    end
    if type(H._mcModRef) == "table" then
        pushCand(H._mcModRef.current)
    end

    if #list == 0 and H.gt and (os.clock() - (H.lastMcGcScanAt or 0)) > 1.5 and type(getgc) == "function" then
        H.lastMcGcScanAt = os.clock()
        local okGc, objs = pcall(getgc, true)
        if okGc and type(objs) == "table" then
            for _, obj in ipairs(objs) do
                if type(obj) == "table"
                    and type(rawget(obj, "dir")) == "function"
                    and type(rawget(obj, "jumping")) == "function"
                    and type(rawget(obj, "busy")) == "function"
                    and type(rawget(obj, "punching")) == "function"
                then
                    pushCand(obj)
                end
            end
        end
    end

    local anyHooked = false
    for _, mc in ipairs(list) do
        if not H.mobileControls then H.mobileControls = mc end
        if not H._mcWrapped[mc] then
            local origDir = mc.dir
            local origJump = mc.jumping
            H._mcWrapped[mc] = { dir = origDir, jump = origJump }
            H._mcOrigDir = origDir
            H._mcOrigJump = origJump
            H._mcHookedObj = mc
            mc.dir = function(...)
                local ok, base = pcall(origDir, ...)
                local mi = H.manualInput
                if mi and mi.active then
                    if mi.expiresAt and os.clock() > mi.expiresAt then
                        mi.active = false
                        mi.dir = 0
                        mi.jump = false
                        return ok and base or 0
                    end
                    return mi.dir or 0
                end
                return ok and base or 0
            end
            mc.jumping = function(...)
                local ok, base = pcall(origJump, ...)
                local mi = H.manualInput
                if mi and mi.active then
                    if mi.expiresAt and os.clock() > mi.expiresAt then
                        mi.active = false
                        mi.dir = 0
                        mi.jump = false
                        return ok and base or false
                    end
                    return mi.jump == true
                end
                return ok and base or false
            end
        end
        anyHooked = true
    end
    return anyHooked
end

function Core.SetManualInput(dir, jump)
    if not H.mobileControls or (type(H._mcModRef) == "table" and type(H._mcModRef.current) == "table" and (not H._mcWrapped or not H._mcWrapped[H._mcModRef.current])) then
        if not H.mobileControls and H.gt then
            pcall(inspectUpvalues, H.gt)
        end
        Core.EnsureManualInputHook()
    end
    H.manualInput = H.manualInput or {}
    local mi = H.manualInput
    if not mi.active then
        pcall(function()
            local tb = UserInputService and UserInputService:GetFocusedTextBox()
            if tb then tb:ReleaseFocus() end
        end)
    end
    local d = tonumber(dir) or 0
    if d > 0 then d = 1 elseif d < 0 then d = -1 else d = 0 end
    mi.dir = d
    mi.jump = jump == true
    mi.active = true
    mi.expiresAt = os.clock() + 2.5
    return true
end

function Core.ClearManualInput()
    if H.manualInput then
        H.manualInput.active = false
        H.manualInput.dir = 0
        H.manualInput.jump = false
        H.manualInput.expiresAt = 0
    end
end

-- In-Game Growblox Account helpers (BUKAN username Roblox)
function Core.GetInGameName(plr, stripColors)
    plr = plr or LP
    if not plr then return "-" end
    local raw = plr:GetAttribute("Nick") or plr:GetAttribute("GameName")
    if (not raw or raw == "") and H.Roles and type(H.Roles.nameOf) == "function" then
        local ok, rn = pcall(H.Roles.nameOf, plr)
        if ok and type(rn) == "string" and rn ~= "" then raw = rn end
    end
    if (not raw or raw == "") and H.others and type(H.others.list) == "function" then
        local ok, lst = pcall(H.others.list)
        if ok and type(lst) == "table" then
            for _, row in ipairs(lst) do
                if type(row) == "table" and row[1] == plr.UserId and row[2] then
                    raw = tostring(row[2])
                    break
                end
            end
        end
    end
    raw = tostring(raw or plr.DisplayName or plr.Name)
    return stripColors and stripColorTags(raw) or raw
end

function Core.IsPlayerStaff(plr)
    if not plr then return false end
    local uid = type(plr) == "number" and plr or plr.UserId
    if H.Roles and type(H.Roles.isStaff) == "function" then
        local ok, res = pcall(H.Roles.isStaff, uid)
        if ok and res then return true end
    end
    local sr = ReplicatedStorage:FindFirstChild("StaffRoles")
    if sr and sr:GetAttribute("u" .. tostring(uid)) then return true end
    return false
end

function Core.GetInWorldPlayers(includeSelf)
    local curWorld = cleanWorldName(H.gt and H.gt.name or "")
    local byUid = {}
    local res = {}

    if H.others and type(H.others.list) == "function" then
        local ok, lst = pcall(H.others.list)
        if ok and type(lst) == "table" then
            for _, entry in ipairs(lst) do
                if type(entry) == "table" and entry[1] then
                    local uid = entry[1]
                    local plr = Players:GetPlayerByUserId(uid)
                    local wx, wy = nil, nil
                    if type(H.others.where) == "function" then
                        local okW, px, py = pcall(H.others.where, uid)
                        if okW then wx, wy = px, py end
                    end
                    local item = {
                        userId   = uid,
                        gameName = plr and Core.GetInGameName(plr, true) or stripColorTags(entry[2]),
                        player   = plr,
                        x        = wx,
                        y        = wy,
                        tx       = wx and math.floor(wx) or nil,
                        ty       = wy and math.floor(wy - 0.01) or nil,
                        isStaff  = Core.IsPlayerStaff(uid),
                        isSelf   = (LP and uid == LP.UserId) or false,
                    }
                    byUid[uid] = item
                    if includeSelf or not item.isSelf then
                        res[#res + 1] = item
                    end
                end
            end
        end
    end

    for _, plr in ipairs(Players:GetPlayers()) do
        if not byUid[plr.UserId] then
            local pw = cleanWorldName(plr:GetAttribute("World") or curWorld)
            if curWorld == "" or pw == curWorld or plr == LP then
                local item = {
                    userId   = plr.UserId,
                    gameName = Core.GetInGameName(plr, true),
                    player   = plr,
                    isStaff  = Core.IsPlayerStaff(plr.UserId),
                    isSelf   = plr == LP,
                }
                if includeSelf or not item.isSelf then
                    res[#res + 1] = item
                end
            end
        end
    end
    return res
end

function Core.AttachItemSprite(parent, itemId, sizePx)
    if not parent or not itemId then return false end
    sizePx = sizePx or 30
    local zBase = math.max((parent.ZIndex or 2) + 4, 8)
    local info = Core.GetItemInfo(itemId)

    -- Prioritas 1: ItemIcon bawaan game jika tidak menghasilkan frame kosong
    if H.ItemIcon and type(H.ItemIcon.new) == "function" and type(H.ItemIcon.set) == "function" then
        local ok, ic = pcall(H.ItemIcon.new, parent, UDim2.fromOffset(sizePx, sizePx), zBase)
        if ok and ic and ic.frame then
            ic.frame.AnchorPoint = Vector2.new(0.5, 0.5)
            ic.frame.Position = UDim2.fromScale(0.5, 0.5)
            ic.frame.ZIndex = zBase
            local okSet = pcall(H.ItemIcon.set, ic, itemId)
            if okSet then
                local hasImg = false
                for _, d in ipairs(ic.frame:GetDescendants()) do
                    if d:IsA("ImageLabel") then
                        d.ZIndex = math.max(d.ZIndex, zBase + 1)
                        if d.Visible and d.Image ~= "" then hasImg = true end
                    end
                end
                if hasImg then return true end
            end
            pcall(function() ic.frame:Destroy() end)
        end
    end

    -- Prioritas 2: Seed texture (FX.seed 2-layer base+over) / Atlas lookup dengan FALLBACK_ATLAS lengkap
    if info then
        local atlasTbl = (H.Assets and H.Assets.Atlas) or FALLBACK_ATLAS
        local fxTbl    = (H.Assets and H.Assets.FX) or FALLBACK_FX
        if info.seed or info.kind == "seed" then
            local seedImg = (fxTbl and fxTbl.seed) or FALLBACK_FX.seed
            local sd = type(info.seed) == "table" and info.seed or {}
            local sPx = math.floor(sizePx * 0.65)
            local img = Instance.new("ImageLabel")
            img.Size = UDim2.fromOffset(sPx, sPx)
            img.AnchorPoint = Vector2.new(0.5, 0.5)
            img.Position = UDim2.fromScale(0.5, 0.5)
            img.BackgroundTransparency = 1
            img.ResampleMode = Enum.ResamplerMode.Pixelated
            img.Image = seedImg
            img.ImageRectSize = Vector2.new(16, 16)
            img.ImageRectOffset = Vector2.new((sd.base or 0) * 16, 0)
            img.ImageColor3 = sd.color or info.tint or Color3.fromRGB(165, 225, 130)
            img.ZIndex = zBase + 1
            img.Parent = parent
            if sd.over ~= nil then
                local ov = Instance.new("ImageLabel")
                ov.Size = UDim2.fromOffset(sPx, sPx)
                ov.AnchorPoint = Vector2.new(0.5, 0.5)
                ov.Position = UDim2.fromScale(0.5, 0.5)
                ov.BackgroundTransparency = 1
                ov.ResampleMode = Enum.ResamplerMode.Pixelated
                ov.Image = seedImg
                ov.ImageRectSize = Vector2.new(16, 16)
                ov.ImageRectOffset = Vector2.new(sd.over * 16, 16)
                ov.ImageColor3 = sd.overColor or Color3.new(1, 1, 1)
                ov.ZIndex = zBase + 2
                ov.Parent = parent
            end
            return true
        end

        local atlasKey = info.iconAtlas or info.atlas
        local atlasImg = atlasKey and ((atlasTbl and atlasTbl[atlasKey]) or FALLBACK_ATLAS[atlasKey])
        if atlasImg and atlasImg ~= "" then
            local img = Instance.new("ImageLabel")
            img.Size = UDim2.fromOffset(sizePx, sizePx)
            img.AnchorPoint = Vector2.new(0.5, 0.5)
            img.Position = UDim2.fromScale(0.5, 0.5)
            img.BackgroundTransparency = 1
            img.ResampleMode = Enum.ResamplerMode.Pixelated
            img.Image = atlasImg
            img.ImageRectSize = Vector2.new(32, 32)
            local cx = info.iconTx or info.tx or 0
            local cy = info.iconTy or info.ty or 0
            if not info.iconAtlas and H.Autotile and type(H.Autotile.aloneCell) == "function" then
                local okC, ax, ay = pcall(H.Autotile.aloneCell, info)
                if okC and ax and ay then cx, cy = ax, ay end
            elseif not info.iconAtlas and info.spread and (info.spread == 2 or info.spread == 3 or info.spread == 5 or info.spread == 7 or info.spread == 8 or info.spread == 10) then
                cx, cy = (info.tx or 0), (info.ty or 0)
            end
            img.ImageRectOffset = Vector2.new(cx * 32, cy * 32)
            img.ImageColor3 = info.tint or Color3.new(1, 1, 1)
            img.ZIndex = zBase + 1
            img.Parent = parent
            if type(info.overCell) == "table" and info.overCell[1] and info.overCell[2] then
                local ov = Instance.new("ImageLabel")
                ov.Size = UDim2.fromOffset(sizePx, sizePx)
                ov.AnchorPoint = Vector2.new(0.5, 0.5)
                ov.Position = UDim2.fromScale(0.5, 0.5)
                ov.BackgroundTransparency = 1
                ov.ResampleMode = Enum.ResamplerMode.Pixelated
                ov.Image = atlasImg
                ov.ImageRectSize = Vector2.new(32, 32)
                ov.ImageRectOffset = Vector2.new(info.overCell[1] * 32, info.overCell[2] * 32)
                ov.ImageColor3 = Color3.new(1, 1, 1)
                ov.ZIndex = zBase + 2
                ov.Parent = parent
            end
            return true
        end
    end

    -- Prioritas 3: Pixel badge fallback agar cell backpack tidak pernah blank
    local badge = Instance.new("Frame")
    badge.Size = UDim2.fromOffset(sizePx - 4, sizePx - 4)
    badge.AnchorPoint = Vector2.new(0.5, 0.5)
    badge.Position = UDim2.fromScale(0.5, 0.5)
    badge.BackgroundColor3 = (info and info.tint) or Color3.fromRGB(72, 118, 175)
    badge.BorderSizePixel = 0
    badge.ZIndex = zBase + 1
    badge.Parent = parent
    Instance.new("UICorner", badge).CornerRadius = UDim.new(0, 5)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.fromScale(1, 1)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 10
    lbl.TextColor3 = Color3.new(1, 1, 1)
    lbl.Text = string.upper(string.sub((info and info.name) or tostring(itemId), 1, 3))
    lbl.ZIndex = zBase + 2
    lbl.Parent = badge
    return true
end

function Core.GetLiveInventory()
    if H.gt and type(rawget(H.gt, "backpackNow")) == "function" then
        local maybeInv = uv(H.gt.backpackNow, 1)
        if isValidInv(maybeInv) then
            H.inv = maybeInv
        end
    end
    if not isValidInv(H.inv) and (os.clock() - (H.lastInvGcAt or 0)) >= 3.0 then
        H.lastInvGcAt = os.clock()
        for _, v in ipairs(safeGetGC(true)) do
            if isValidInv(v) then
                H.inv = v
                break
            end
        end
    end
    return H.inv
end

function Core.GetBackpackSlots()
    Core.EnsureInit()
    local function collectFrom(tbl)
        local list = {}
        if type(tbl) ~= "table" then return list end
        for idx, sl in pairs(tbl) do
            if type(sl) == "table" then
                local id = tonumber(sl.id or sl[1])
                local n  = tonumber(sl.n or sl[2] or sl.count or 0) or 0
                if id and id > 0 and n > 0 then
                    list[#list + 1] = { slot = tonumber(idx) or (#list + 1), id = id, n = n }
                end
            end
        end
        table.sort(list, function(a, b) return a.slot < b.slot end)
        return list
    end

    local inv = Core.GetLiveInventory()
    local out = inv and collectFrom(inv.slots) or {}
    if #out == 0 and H.gt and type(rawget(H.gt, "backpackNow")) == "function" then
        local ok, bn = pcall(H.gt.backpackNow)
        if ok and type(bn) == "table" then
            out = collectFrom(bn)
        end
    end
    return out
end

function Core.ClearStuckDropVisuals(uid, remCount)
    Core.EnsureInit()
    local gt = H.gt
    if gt and type(gt.dropList) == "function" then
        local okD, drops = pcall(gt.dropList)
        if okD and type(drops) == "table" then
            for i = #drops, 1, -1 do
                local d = drops[i]
                if type(d) == "table" and (uid == nil or d.uid == uid) then
                    local isRemPartial = (uid ~= nil and d.uid == uid and type(remCount) == "number" and remCount > 0)
                    if isRemPartial then
                        d.n = remCount
                        if type(gt.dropTaken) == "function" then pcall(gt.dropTaken, d.uid, remCount) end
                    else
                        local shouldClean = (uid ~= nil and d.uid == uid) or ((d.n or 0) <= 0) or (d.frame and not d.frame.Parent)
                        if shouldClean then
                            d.n = 0
                            d.flown = true
                            pcall(function()
                                if d.frame and d.frame.Destroy then d.frame:Destroy() end
                            end)
                            if drops[i] == d then
                                table.remove(drops, i)
                            end
                            if uid ~= nil and type(gt.dropTaken) == "function" then
                                pcall(gt.dropTaken, d.uid, 0)
                            end
                        end
                    end
                end
            end
        end
    end
    -- Bersihkan clone gem / item drop yang tersangkut secara visual di GameGui
    if not (uid ~= nil and type(remCount) == "number" and remCount > 0) then
        local pg = LP and LP:FindFirstChildOfClass("PlayerGui")
        local gg = pg and pg:FindFirstChild("GameGui")
        if gg then
            for _, obj in ipairs(gg:GetDescendants()) do
                if (obj:IsA("ImageLabel") or obj:IsA("Frame")) and obj.Visible then
                    local nm = string.lower(obj.Name)
                    if nm == "dropclone" or nm == "pickupclone" or nm == "gemclone" or string.find(nm, "stuckdrop", 1, true) then
                        pcall(function() obj:Destroy() end)
                    end
                end
            end
        end
    end
end

-- Core World / Pos / Inventory / Tree helpers
function Core.EnsureInit()
    local curName = (H.gt and type(rawget(H.gt, "name")) == "string") and rawget(H.gt, "name") or ""
    local worldChanged = (curName ~= "" and curName ~= H.lastWorldTag)
    if worldChanged or ((not H.initialized or not isValidGT(H.gt)) and (os.clock() - (H.lastInitTryAt or 0)) >= 2.5) then
        SYT_Logic.Init(true)
    end
    return H.gt ~= nil and H.Net ~= nil
end

function Core.ReadPos()
    Core.EnsureInit()
    local x, y, vx, vy, grounded, dead = nil, nil, 0, 0, false, false
    if H.stateObj and type(H.stateObj.state) == "function" then
        local ok, st = pcall(H.stateObj.state)
        if ok and type(st) == "table" and type(st.x) == "number" then
            x, y, vx, vy = st.x, st.y, st.vx or 0, st.vy or 0
            grounded, dead = st.grounded == true, st.dead == true
        end
    elseif H.gt and type(H.gt.state) == "function" then
        local ok, st = pcall(H.gt.state)
        if ok and type(st) == "table" and type(st.x) == "number" then
            x, y, vx, vy = st.x, st.y, st.vx or 0, st.vy or 0
            grounded, dead = st.grounded == true, st.dead == true
        end
    end
    if (not x or not y) and H.renderFn and H.pxIdx and H.pyIdx then
        x = uv(H.renderFn, H.pxIdx)
        y = uv(H.renderFn, H.pyIdx)
    end
    if (not x or not y) and H.gt and type(H.gt.goTo) == "function" then
        if not H.goPxIdx then pcall(inspectUpvalues, H.gt) end
        if H.goPxIdx and H.goPyIdx then
            x = uv(H.gt.goTo, H.goPxIdx)
            y = uv(H.gt.goTo, H.goPyIdx)
        end
    end
    x, y = x or 0, y or 1
    local tx, ty = math.floor(x), math.floor(y - 0.01)
    if H.gt and H.gt.w and H.gt.h then
        tx = clamp(tx, 0, H.gt.w - 1)
        ty = clamp(ty, 0, H.gt.h - 1)
    end
    return { x = x, y = y, tx = tx, ty = ty, sx = tx + 1, sy = ty + 1, vx = vx, vy = vy, grounded = grounded, dead = dead }
end

function Core.SetLocalCoords(px, py, vx, vy)
    Core.EnsureInit()
    local gt = H.gt
    if not gt then return false end
    vx, vy = vx or 0, vy or 0

    -- 1. Sinkronkan upvalue gt.goTo (ref shared dgn RenderStepped: pos, prevAntiWarp, vel, ack)
    if type(gt.goTo) == "function" then
        if not H.goPxIdx then pcall(inspectUpvalues, gt) end
        if H.goPxIdx and H.goPyIdx then
            suv(gt.goTo, H.goPxIdx, px)
            suv(gt.goTo, H.goPyIdx, py)
            if H.goPrevXIdx and H.goPrevYIdx then
                suv(gt.goTo, H.goPrevXIdx, px)
                suv(gt.goTo, H.goPrevYIdx, py)
            end
            if H.goAckXIdx and H.goAckYIdx then
                suv(gt.goTo, H.goAckXIdx, px)
                suv(gt.goTo, H.goAckYIdx, py)
            end
            if H.goVxIdx and H.goVyIdx then
                suv(gt.goTo, H.goVxIdx, vx)
                suv(gt.goTo, H.goVyIdx, vy)
            end
        end
    end

    -- 2. Sinkronkan stateObj.state() agar Others.lua sendState membaca posisi exact
    if H.stateObj and type(H.stateObj.state) == "function" and H.statePosPairs and H.statePosPairs.x then
        suv(H.stateObj.state, H.statePosPairs.x, px)
        suv(H.stateObj.state, H.statePosPairs.y, py)
        if H.statePosPairs.vx then suv(H.stateObj.state, H.statePosPairs.vx, vx) end
        if H.statePosPairs.vy then suv(H.stateObj.state, H.statePosPairs.vy, vy) end
    end

    -- 3. Sinkronkan seluruh pasangan posisi terverifikasi di RenderStepped (tanpa blind offset)
    if H.renderFn then
        if H.renderPosPairs and #H.renderPosPairs > 0 then
            for _, p in ipairs(H.renderPosPairs) do
                suv(H.renderFn, p.x, px)
                suv(H.renderFn, p.y, py)
            end
        elseif H.pxIdx and H.pyIdx then
            suv(H.renderFn, H.pxIdx, px)
            suv(H.renderFn, H.pyIdx, py)
        end
        if H.vxIdx and H.vyIdx then
            suv(H.renderFn, H.vxIdx, vx)
            suv(H.renderFn, H.vyIdx, vy)
        end
    end

    gt.stuckAt, gt.portalGo = nil, nil
    return true
end

function Core.GetItemInfo(id)
    if not H.ItemDB then SYT_Logic.Init() end
    return (H.ItemDB and id and id ~= 0) and H.ItemDB[id] or nil
end

function Core.GetItemName(id)
    local info = Core.GetItemInfo(id)
    return info and info.name or ("Item#" .. tostring(id))
end

function Core.FindItemByName(query)
    Core.EnsureInit()
    if not H.ItemDB or type(query) ~= "string" or query == "" then return nil end
    local q = string.lower((query):match("^%s*(.-)%s*$"))
    for id, info in pairs(H.ItemDB) do
        if type(id) == "number" and type(info) == "table" and info.name and string.lower(info.name) == q then
            return { id = id, info = info }
        end
    end
    for id, info in pairs(H.ItemDB) do
        if type(id) == "number" and type(info) == "table" and info.name and string.find(string.lower(info.name), q, 1, true) then
            return { id = id, info = info }
        end
    end
    return nil
end

function Core.ReadGems()
    if SYT_Logic.Visual and SYT_Logic.Visual.State and SYT_Logic.Visual.State.fakeGemsActive and type(SYT_Logic.Visual.State.origGems) == "number" then
        return SYT_Logic.Visual.State.origGems
    end
    local sk = H.skillsObj
    local addFn = sk and rawget(sk, "addGems")
    if type(addFn) == "function" then
        local ok, g = pcall(uv, addFn, 1)
        if ok and type(g) == "number" then return math.max(0, math.floor(g)) end
    end
    if H.gt and type(rawget(H.gt, "gems")) == "number" then
        return math.max(0, math.floor(H.gt.gems))
    end
    return 0
end

function Core.CountItem(id)
    if not id then return 0 end
    local inv = Core.GetLiveInventory()
    if inv and type(inv.count) == "function" then
        local ok, c = pcall(function() return inv:count(id) end)
        if ok and type(c) == "number" and c > 0 then return c end
    end
    local total = 0
    for _, sl in ipairs(Core.GetBackpackSlots()) do
        if sl.id == id then total += (sl.n or 0) end
    end
    return total
end

function Core.GetItemRoom(id)
    if not id then return 0 end
    local inv = Core.GetLiveInventory()
    if inv and type(inv.room) == "function" then
        local ok, r = pcall(function() return inv:room(id) end)
        if ok and type(r) == "number" then return r end
    end
    return math.max(0, MAX_STACK - Core.CountItem(id))
end

function Core.GetFG(tx, ty)
    local gt = H.gt
    if not gt or not gt.fg or not gt.fg[ty] then return 0 end
    return gt.fg[ty][tx] or 0
end

function Core.GetBG(tx, ty)
    local gt = H.gt
    if not gt or not gt.bg or not gt.bg[ty] then return 0 end
    return gt.bg[ty][tx] or 0
end

function Core.GetLayerTile(tx, ty, layer)
    return (layer == 2) and Core.GetBG(tx, ty) or Core.GetFG(tx, ty)
end

function Core.MirrorLocalTile(layer, tx, ty, id, flip)
    local gt = H.gt
    if not gt then return end
    local layerName = (layer == 2) and "bg" or "fg"
    if type(gt.tileChanged) == "function" then
        H.mirroring = true
        pcall(gt.tileChanged, layerName, tx, ty, id, flip == true)
        H.mirroring = false
    else
        if layer == 2 then
            if gt.bg and gt.bg[ty] then gt.bg[ty][tx] = id end
        else
            if gt.fg and gt.fg[ty] then gt.fg[ty][tx] = id end
        end
        if type(gt.placedAt) == "table" and type(gt.placedAt[layerName]) == "table" and gt.w then
            gt.placedAt[layerName][ty * gt.w + tx] = (id ~= 0) and os.clock() or nil
        end
    end
    if gt.w then
        if id > 0 then
            local info = Core.GetItemInfo(id)
            if info and info.kind == "seed" then
                H.mirroredTrees[ty * gt.w + tx] = { id = id, p = serverNow() }
            end
        else
            H.mirroredTrees[ty * gt.w + tx] = nil
            if H.trees then H.trees[ty * gt.w + tx] = nil end
        end
    end
end

function Core.IsSolid(tx, ty)
    local gt = H.gt
    if not gt then return true end
    if tx < 0 or tx >= gt.w or ty >= gt.h then return true end
    if ty < 0 then return false end
    local id = Core.GetFG(tx, ty)
    if id == 0 then return false end
    local info = Core.GetItemInfo(id)
    if not info or info.door or info.entrance then return false end
    return info.solid == true
end

function Core.CanRealEditTile(tx, ty)
    local gt = H.gt
    if not gt or tx < 0 or tx >= gt.w or ty < 0 or ty >= gt.h then return false end
    if H.origAreas and H.origAreas.tbl == gt.areas then
        if type(H.origAreas.canEdit) == "function" then
            local ok, can = pcall(H.origAreas.canEdit, tx, ty)
            if ok then return can == true end
        elseif type(H.origAreas.mayBuild) == "function" then
            local ok, can = pcall(H.origAreas.mayBuild, gt.lock, tx, ty)
            if ok then return can == true end
        end
    end
    if gt.areas then
        if type(gt.areas.canEdit) == "function" then
            local ok, can = pcall(gt.areas.canEdit, tx, ty)
            if ok then return can == true end
        elseif type(gt.areas.mayBuild) == "function" then
            local ok, can = pcall(gt.areas.mayBuild, gt.lock, tx, ty)
            if ok then return can == true end
        end
    end
    return true
end

function Core.CanEditTile(tx, ty)
    local gs = SYT_Logic.GetcSkipper and SYT_Logic.GetcSkipper.State
    if not (gs and gs.antiKickShield == false) then
        return Core.CanRealEditTile(tx, ty)
    end
    local gt = H.gt
    if not gt or tx < 0 or tx >= gt.w or ty < 0 or ty >= gt.h then return false end
    if gt.areas then
        if type(gt.areas.canEdit) == "function" then
            local ok, can = pcall(gt.areas.canEdit, tx, ty)
            if ok then return can == true end
        elseif type(gt.areas.mayBuild) == "function" then
            local ok, can = pcall(gt.areas.mayBuild, gt.lock, tx, ty)
            if ok then return can == true end
        end
    end
    return true
end

function Core.IsProtectedTile(id)
    if not id or id == 0 then return false end
    local info = Core.GetItemInfo(id)
    if not info then return true end
    local ln = string.lower(info.name or "")
    if ln == "blank" or string.find(ln, "bedrock", 1, true) or string.find(ln, "door", 1, true) then return true end
    return (info.lock or info.area or info.vend or info.display or info.displayOne or info.worldKey or info.entrance or info.vip or info.combiner) == true
end

function Core.ValidateTile(tx, ty)
    local gt = H.gt
    if not gt or (gt.name or "") == "" or not gt.w or not gt.h then
        return false, "Belum masuk world / gt belum ditemukan"
    end
    if type(tx) ~= "number" or type(ty) ~= "number" then
        return false, "Koordinat harus berupa angka"
    end
    tx, ty = math.floor(tx), math.floor(ty)
    if tx < 0 or tx >= gt.w or ty < 0 or ty >= gt.h then
        return false, string.format("Di luar batas world (X: 0..%d, Y: 0..%d)", gt.w - 1, gt.h - 1)
    end
    if Core.IsSolid(tx, ty) then
        return false, string.format("Tile (%d, %d) SOLID / terhalang", tx, ty)
    end
    return true, string.format("VALID Tile (%d, %d) | Stats (%d, %d)", tx, ty, tx + 1, ty + 1), tx, ty
end

function Core.IsPlantable(tx, ty)
    local gt = H.gt
    if not gt or tx < 0 or tx >= gt.w or ty < 0 or ty >= gt.h - 1 then return false end
    if Core.GetFG(tx, ty) ~= 0 then return false end
    local belowId = Core.GetFG(tx, ty + 1)
    if belowId == 0 then return false end
    local below = Core.GetItemInfo(belowId)
    if not below or not (below.solid == true or below.platform == true) then return false end
    return Core.CanEditTile(tx, ty)
end

function Core.GetTreeAt(tx, ty)
    local gt = H.gt
    if not gt then return nil end
    local idx = ty * gt.w + tx
    if H.trees and H.trees[idx] then return H.trees[idx] end
    return H.mirroredTrees[idx]
end

function Core.IsTreeRipe(tx, ty)
    local fgId = Core.GetFG(tx, ty)
    if fgId == 0 then return false end
    local info = Core.GetItemInfo(fgId)
    if not info or info.kind ~= "seed" then return false end
    local tr = Core.GetTreeAt(tx, ty)
    if not tr or type(tr.p) ~= "number" then return false end
    return serverNow() >= (tr.p + (info.grow or 0))
end

function Core.GetTreeRemainingSec(tx, ty)
    local fgId = Core.GetFG(tx, ty)
    local info = Core.GetItemInfo(fgId)
    local tr   = Core.GetTreeAt(tx, ty)
    if not info or info.kind ~= "seed" or not tr or type(tr.p) ~= "number" then return nil end
    return math.max(0, (tr.p + (info.grow or 0)) - serverNow())
end

function Core.ResolveBlockAndSeedPair(idOrName)
    Core.EnsureInit()
    if not H.ItemDB then return nil end
    local targetId = tonumber(idOrName)
    if not targetId and type(idOrName) == "string" and idOrName ~= "" then
        local q = string.lower(idOrName)
        for id, info in pairs(H.ItemDB) do
            if type(id) == "number" and type(info) == "table" and info.name and string.lower(info.name) == q then
                targetId = id
                break
            end
        end
        if not targetId then
            for id, info in pairs(H.ItemDB) do
                if type(id) == "number" and type(info) == "table" and info.name and string.find(string.lower(info.name), q, 1, true) then
                    targetId = id
                    break
                end
            end
        end
    end
    if not targetId or not H.ItemDB[targetId] then return nil end
    local info = H.ItemDB[targetId]
    local blockId, seedId = nil, nil
    if info.kind == "seed" then
        seedId = targetId
        if H.ItemDB[targetId - 1] and H.ItemDB[targetId - 1].kind ~= "seed" then blockId = targetId - 1 end
    else
        blockId = targetId
        if H.ItemDB[targetId + 1] and H.ItemDB[targetId + 1].kind == "seed" then seedId = targetId + 1 end
    end
    return {
        blockId   = blockId,
        seedId    = seedId,
        blockName = blockId and Core.GetItemName(blockId) or "",
        seedName  = seedId and Core.GetItemName(seedId) or "",
    }
end

local function emitNotify(title, text, payload)
    if type(H.onNotify) == "function" then pcall(H.onNotify, title, text, payload) end
    if H.gt and type(H.gt.floatText) == "function" then
        local pos = Core.ReadPos()
        pcall(H.gt.floatText, pos.x, pos.y - 1.2, text, Color3.fromRGB(255, 225, 95))
    end
    pcall(function()
        StarterGui:SetCore("SendNotification", { Title = tostring(title or "SYT"), Text = tostring(text or ""), Duration = 3 })
    end)
end

-- 4. [GETC SKIPER] RATE LIMITER, RANGE GUARD & ITEM-UPDATE SKIPPER
local GetcSkipper = {
    State = {
        enabled                = true,
        ultimaxEnabled         = true,
        ultimaxNamecallGuard   = true,
        ultimaxAdaptiveBackoff = true,
        antiKickShield         = true,
        skipUpdateItems        = false,
        longRangeNoDelay       = true,
        noValidateBack         = true,
        antiBack               = true,
        stopOrNoSend           = "nosend",
        safeStepCap            = 3,
        safeWalkSpeedCap       = 10.4,
        maxRangeTiles          = 12,
        bypassClientRange      = true,
        bypassWalkSpeed        = false,
        bypassHandPower        = false,
        bypassPhysics          = false,
        bypassClientLocks      = false,
        bypassUiBlock          = false,
        spoofServerReach       = false,
        walkSpeedScale         = 1.45,
        jitterMin              = 0.05,
        jitterMax              = 0.35,
        minIntervals           = { tile = 0.045, move = 0.030, act = 0.040, take = 0.025, drop = 1.080, chat = 2.250 },
        lastSent               = {},
        jitterCount            = 0,
        origInvNotify          = nil,
    }
}
SYT_Logic.GetcSkipper = GetcSkipper

function GetcSkipper.SyncBypassHooks()
    Core.EnsureInit()
    Core.EnsureMoveHook()
    Core.EnsureOutboundFirewall()
    pcall(Core.InstallUltimaxNamecallGuard)
    return Core.InstallGetgcBypassHooks()
end

function GetcSkipper.SetBypassOption(key, val)
    GetcSkipper.State[key] = val
    Core.EnsureInit()
    Core.EnsureMoveHook()
    Core.EnsureOutboundFirewall()
    pcall(Core.InstallUltimaxNamecallGuard)
    Core.InstallGetgcBypassHooks()
    return GetcSkipper.State[key]
end

function GetcSkipper.GetUltimaxStatusText()
    local S = GetcSkipper.State
    return string.format(
        "ULTIMAX=%s | FW=%d | KickBlk=%d | Notice=%d | Last=%s",
        (S.ultimaxEnabled ~= false and S.antiKickShield ~= false) and "ON" or "OFF",
        H.fwBlockedCount or 0,
        H.ultimaxKickBlocked or 0,
        H.ultimaxNoticeCount or 0,
        (H.ultimaxLastNotice and H.ultimaxLastNotice ~= "" and H.ultimaxLastNotice)
            or (H.fwLastBlockReason and H.fwLastBlockReason ~= "" and H.fwLastBlockReason)
            or "-"
    )
end

function GetcSkipper.EnableUltimaxAllSafe()
    local S = GetcSkipper.State
    S.enabled = true
    S.ultimaxEnabled = true
    S.ultimaxNamecallGuard = true
    S.ultimaxAdaptiveBackoff = true
    S.antiKickShield = true
    S.antiBack = true
    S.noValidateBack = true
    S.stopOrNoSend = "nosend"
    S.safeStepCap = clamp(toInt(S.safeStepCap, 3), 1, 3)
    Core.EnsureInit(true)
    Core.EnsureMoveHook()
    Core.EnsureOutboundFirewall()
    local ncOk = pcall(Core.InstallUltimaxNamecallGuard)
    local gcOk = Core.InstallGetgcBypassHooks()
    pcall(Core.InstallAntiBackGuard)
    if type(SYT_Logic.InstallNetGuard) == "function" then
        pcall(SYT_Logic.InstallNetGuard)
    end
    if UI then
        UI:SetValue("UltimaxMaster", true)
        UI:SetValue("GuardAntiKickShield", true)
        UI:SetValue("UltimaxNamecallGuard", true)
        UI:SetValue("UltimaxAdaptiveBackoff", true)
        UI:SetValue("GuardEnabled", true)
        UI:SetValue("GuardAntiBack", true)
        UI:SetValue("GuardNoValidateBack", true)
        UI:SetValue("UltimaxStatusDisplay", GetcSkipper.GetUltimaxStatusText())
    end
    return gcOk, ncOk
end

function GetcSkipper.SetAntiBack(on)
    GetcSkipper.State.antiBack = on == true
    if GetcSkipper.State.antiBack and type(Core.InstallAntiBackGuard) == "function" then
        pcall(Core.InstallAntiBackGuard)
    end
    return GetcSkipper.State.antiBack
end

function GetcSkipper.SetStopOrNoSend(mode)
    local m = string.lower(tostring(mode or "nosend"))
    if string.find(m, "stop", 1, true) then
        m = "stop"
    elseif string.find(m, "off", 1, true) then
        m = "off"
    else
        m = "nosend"
    end
    GetcSkipper.State.stopOrNoSend = m
    return m
end

function GetcSkipper.SetSkipUpdateItems(on)
    local S = GetcSkipper.State
    S.skipUpdateItems = on == true
    Core.EnsureInit()
    local inv = Core.GetLiveInventory()
    if not inv then return false end
    local cbKey = (type(inv.onChange) == "function" and "onChange")
        or (type(inv.changed) == "function" and "changed")
        or (type(inv.notify) == "function" and "notify")
    if not cbKey then return true end
    if S.skipUpdateItems then
        S.origInvNotify = S.origInvNotify or inv[cbKey]
        inv[cbKey] = function(...)
            if S.skipUpdateItems then return end
            return S.origInvNotify(...)
        end
    elseif S.origInvNotify then
        inv[cbKey] = S.origInvNotify
    end
    return true
end

function GetcSkipper.SetNoValidateBack(on)
    GetcSkipper.State.noValidateBack = on == true
    if GetcSkipper.State.noValidateBack and type(SYT_Logic.InstallNetGuard) == "function" then
        pcall(SYT_Logic.InstallNetGuard)
    end
    return GetcSkipper.State.noValidateBack
end

function GetcSkipper.RandomizedWait(baseDelay, packetKind, shouldContinueFn)
    local S = GetcSkipper.State
    local req = math.max(0, tonumber(baseDelay) or 0)
    local kind = tostring(packetKind or "tile")
    -- Range Jauh Non-Delay: hilangkan jeda artifisial/jitter untuk paket cepat (kecuali chat/drop server cooldown)
    if S.enabled and S.longRangeNoDelay and kind ~= "chat" and kind ~= "drop" then
        if req > 0 then
            if type(shouldContinueFn) == "function" then
                local deadline = os.clock() + req
                while os.clock() < deadline do
                    if not shouldContinueFn() then return 0 end
                    task.wait(math.min(0.025, math.max(0.004, deadline - os.clock())))
                end
            else
                task.wait(req)
            end
        end
        S.lastSent[kind] = os.clock()
        return req
    end
    local waitTime = req
    local shieldChatOrDrop = (S.antiKickShield ~= false and (kind == "chat" or kind == "drop"))
    if S.enabled or shieldChatOrDrop then
        local minInt = S.minIntervals[kind] or 0.04
        if kind == "chat" and S.antiKickShield ~= false then
            minInt = math.max(minInt, 2.25)
        elseif kind == "drop" and S.antiKickShield ~= false then
            minInt = math.max(minInt, 1.08)
        end
        local now     = os.clock()
        local elapsed = now - (S.lastSent[kind] or 0)
        if req < minInt or elapsed < minInt then
            S.jitterCount += 1
            local j = S.jitterMin + math.random() * math.max(0, S.jitterMax - S.jitterMin)
            waitTime = math.max(req, minInt - elapsed) * (1 + j)
        elseif waitTime > 0 then
            waitTime = waitTime * (1 + math.random() * 0.08)
        end
    end
    if waitTime > 0 then
        if type(shouldContinueFn) == "function" then
            local deadline = os.clock() + waitTime
            while os.clock() < deadline do
                if not shouldContinueFn() then return 0 end
                task.wait(math.min(0.05, math.max(0.01, deadline - os.clock())))
            end
        else
            task.wait(waitTime)
        end
    end
    if packetKind then S.lastSent[kind] = os.clock() end
    return waitTime
end

function GetcSkipper.InRange(tx, ty, maxRange)
    local pos = Core.ReadPos()
    local d = math.max(math.abs(math.floor(tx) - pos.tx), math.abs(math.floor(ty) - pos.ty))
    local effRange = tonumber(maxRange) or GetcSkipper.State.maxRangeTiles or 12
    return d <= effRange, d
end

local stepTeleportImpl
function GetcSkipper.EnsureRange(tx, ty, maxRange, stepDelay, shouldContinueFn)
    local S = GetcSkipper.State
    if GetcSkipper.InRange(tx, ty, maxRange) then return true end
    if S.enabled and S.noValidateBack and type(SYT_Logic.InstallNetGuard) == "function" then
        pcall(SYT_Logic.InstallNetGuard)
    end
    if type(stepTeleportImpl) == "function" then
        local hop = (S.enabled and S.longRangeNoDelay) and clamp(toInt(S.maxRangeTiles, 12), 4, 16) or math.min(4, S.maxRangeTiles)
        local delayArg = (S.enabled and S.longRangeNoDelay) and 0 or (stepDelay or 0.04)
        return stepTeleportImpl(tx, ty, hop, delayArg, shouldContinueFn)
    end
    return false
end

-- 5. REUSABLE RAW PACKETS (PUNCH, HIT DAMAGE, WALK/TP, PLACE, CHAT, COLLECT)
local Packets = {}
SYT_Logic.Packets    = Packets
SYT_Logic.RawPackets = Packets

local function moveTs()
    return math.floor((os.clock() * 1000) % 65535)
end

local function computeMoveFlags(px, py, vx, vy, prevFacing)
    local facing = prevFacing or 1
    if math.abs(vx or 0) > 0.05 then
        facing = (vx > 0) and 1 or -1
    end
    local grounded = (math.abs(vy or 0) < 0.35) and Core.IsSolid(math.floor(px), math.floor(py + 0.02))
    return (facing > 0 and 1 or 0) + (grounded and 2 or 0), facing
end

function Packets.SendRawMove(px, py, vx, vy, flags, opts)
    Core.EnsureInit()
    Core.EnsureMoveHook()
    if type(Core.InstallAntiBackGuard) == "function" and Core.IsAntiBackActive() then
        pcall(Core.InstallAntiBackGuard)
    end
    local sendFn = H.origMoveSend or (H.Net and H.Net.move and H.Net.move.send)
    if type(sendFn) ~= "function" then return false, "send_nil" end
    local fl = flags
    if fl == nil then
        fl = computeMoveFlags(px, py, vx or 0, vy or 0, 1)
    else
        fl = toInt(fl, 2)
    end
    local ts = (type(opts) == "table" and tonumber(opts.t)) or moveTs()
    local rawPkt = { x = px, y = py, vx = vx or 0, vy = vy or 0, flags = fl, t = ts }
    local cleanPkt, reason = Core.SanitizeOutboundMove(rawPkt, true, type(opts) == "table" and opts.forceBypass == true)
    if not cleanPkt then
        return false, reason or "no_send"
    end
    return pcall(sendFn, cleanPkt)
end

function Packets.FindTilePath(sx, sy, gx, gy, allowHazard)
    local gt = H.gt
    if not gt then return nil end
    local w, h = gt.w, gt.h
    sx, sy = clamp(math.floor(sx), 0, w - 1), clamp(math.floor(sy), 0, h - 1)
    gx, gy = clamp(math.floor(gx), 0, w - 1), clamp(math.floor(gy), 0, h - 1)
    if sx == gx and sy == gy then return { { x = gx, y = gy } } end

    local function runBfs(ignoreDanger)
        local startIdx, goalIdx = sy * w + sx, gy * w + gx
        local cameFrom = { [startIdx] = -1 }
        local queue, head = { startIdx }, 1
        local dirs = { { 1, 0 }, { -1, 0 }, { 0, -1 }, { 0, 1 } }
        while head <= #queue do
            local cur = queue[head]
            head += 1
            if cur == goalIdx then
                local rev, c = {}, goalIdx
                while c ~= -1 do
                    rev[#rev + 1] = { x = c % w, y = math.floor(c / w) }
                    c = cameFrom[c]
                end
                local path = {}
                for i = #rev, 1, -1 do path[#path + 1] = rev[i] end
                return path
            end
            local cx, cy = cur % w, math.floor(cur / w)
            for _, d in ipairs(dirs) do
                local nx, ny = cx + d[1], cy + d[2]
                if nx >= 0 and nx < w and ny >= 0 and ny < h then
                    local nIdx = ny * w + nx
                    if cameFrom[nIdx] == nil and (nIdx == goalIdx or not Core.IsSolid(nx, ny)) then
                        local miscRef = SYT_Logic.Misc
                        local okHazard = ignoreDanger or (nIdx == goalIdx) or (miscRef and miscRef.State and miscRef.State.godMode)
                        if not okHazard then
                            local fi = Core.GetItemInfo(Core.GetFG(nx, ny))
                            okHazard = not (fi and (fi.deadly or fi.hurts))
                        end
                        if okHazard then
                            cameFrom[nIdx] = cur
                            queue[#queue + 1] = nIdx
                        end
                    end
                end
            end
        end
        return nil
    end

    local safePath = runBfs(allowHazard == true)
    if safePath or allowHazard == true then
        return safePath
    end
    return runBfs(true)
end

-- Kompresi segmen lurus (horizontal/vertikal) agar Walk cepat & kontinu tanpa berhenti tiap 1 tile
local function compressWalkPath(path)
    if type(path) ~= "table" or #path <= 2 then return path end
    local out = { path[1] }
    local prevDx = path[2].x - path[1].x
    local prevDy = path[2].y - path[1].y
    for i = 3, #path do
        local dx = path[i].x - path[i - 1].x
        local dy = path[i].y - path[i - 1].y
        if dx ~= prevDx or dy ~= prevDy then
            out[#out + 1] = path[i - 1]
            prevDx, prevDy = dx, dy
        end
    end
    out[#out + 1] = path[#path]
    return out
end

-- Helper pergerakan kontinu sub-tile sinkron penuh dengan Game.lua & Server Growblox (Anti-Back + Stop/No-Send)
local function executeServerSyncedPath(tx, ty, speedH, speedV, shouldContinueFn, moveOpts)
    Core.EnsureInit()
    Core.EnsureMoveHook()
    moveOpts = moveOpts or {}
    local gs = GetcSkipper.State
    local antiBack = Core.IsAntiBackActive() or (moveOpts.noValidateBack == true)
    local stopMode = Core.GetStopOrNoSendMode()
    local noDelay = (moveOpts.noDelay == true) or (moveOpts.noDelay ~= false and gs.enabled and gs.longRangeNoDelay == true)
    local fastWalk = (moveOpts.fastWalk == true) or ((not noDelay) and ((tonumber(speedH) or 0) > 7.4))
    local noSnap = (moveOpts.noSnap == true) or (not noDelay)
    local noValidateBack = (moveOpts.noValidateBack == true) or (moveOpts.noValidateBack ~= false and gs.enabled and gs.noValidateBack == true) or antiBack
    if noValidateBack then
        pcall(Core.InstallAntiBackGuard)
        if type(SYT_Logic.InstallNetGuard) == "function" then
            pcall(SYT_Logic.InstallNetGuard)
        end
    end
    local gt = H.gt
    if not gt then return false, "gt nil" end
    if stopMode == "stop" and os.clock() < (H.stopMoveUntil or 0) then
        return false, "stopped_cooldown"
    end
    tx = clamp(math.floor(tx), 0, gt.w - 1)
    ty = clamp(math.floor(ty), 0, gt.h - 1)

    local sH = noDelay and clamp(tonumber(speedH) or 13.5, 6.0, 22.0)
        or (fastWalk and clamp(tonumber(speedH) or 12.0, 4.8, 16.0) or clamp(tonumber(speedH) or 6.9, 4.5, 7.4))
    local sV = noDelay and clamp(tonumber(speedV) or 16.0, 8.0, 24.0)
        or (fastWalk and clamp(tonumber(speedV) or 15.0, 6.0, 20.0) or clamp(tonumber(speedV) or 11.5, 5.5, 14.0))
    local maxAttempts = noValidateBack and 1 or 2
    local facing = 1
    -- Cadence Net.move mendekati sendState Others.lua (0.050s-0.067s) agar delta per paket tetap sub-tile
    local tickSec = noDelay and 0.048 or (fastWalk and 0.050 or 0.067)

    for attempt = 1, maxAttempts do
        local startT = os.clock()
        local blockedBefore = H.blockedMoveToCount or 0
        local cur = Core.ReadPos()
        if cur.tx == tx and cur.ty == ty and not moveOpts.customPath then
            return true, string.format("Walk-Path OK -> (%d, %d)", tx, ty)
        end
        local rawPath = (attempt == 1 and type(moveOpts.customPath) == "table" and #moveOpts.customPath >= 1)
            and moveOpts.customPath
            or Packets.FindTilePath(cur.tx, cur.ty, tx, ty)
        if not rawPath or #rawPath == 0 then
            return false, "Jalur tertutup blok (No-Send Guard)"
        end
        local path = {}
        for idxP, nd in ipairs(rawPath) do path[idxP] = { x = nd.x, y = nd.y } end
        if #path > 1 and Core.IsSolid(path[#path].x, path[#path].y) then
            table.remove(path, #path)
            if #path == 0 then
                return false, "Target solid tanpa celah terdekat"
            end
        end
        if #path <= 1 then
            local dst = path[1] or { x = tx, y = ty }
            if cur.tx == dst.x and cur.ty == dst.y then
                return true, string.format("Walk-Path OK -> (%d, %d)", dst.x, dst.y)
            end
            return false, "Target solid tanpa celah terdekat"
        end

        H.moveConn = H.moveConn and (pcall(function() H.moveConn:Disconnect() end) and nil) or nil
        local curPx, curPy = cur.x, cur.y
        if math.abs(curPx - (path[1].x + 0.5)) > 1.2 or math.abs(curPy - (path[1].y + 1)) > 1.2 then
            curPx, curPy = path[1].x + 0.5, path[1].y + 1
        end

        -- Selaraskan ke tengah tile awal sebelum meluncur di segmen lurus agar hitbox tidak menyerempet tembok
        local compressed = compressWalkPath(path)
        if (math.abs(curPx - (path[1].x + 0.5)) > 0.16 or math.abs(curPy - (path[1].y + 1)) > 0.16) then
            local alignPath = { { x = path[1].x, y = path[1].y }, { x = path[1].x, y = path[1].y } }
            for k = 2, #compressed do alignPath[#alignPath + 1] = compressed[k] end
            path = alignPath
        else
            path = compressed
        end

        local initFl, initFc = computeMoveFlags(curPx, curPy, 0, 0, facing)
        facing = initFc
        H.autoMove = { x = curPx, y = curPy, vx = 0, vy = 0, flags = antiBack and ((facing > 0 and 1 or 0) + 2) or initFl }
        H.moveConn = RunService.RenderStepped:Connect(function()
            local am = H.autoMove
            if am then
                if am.fromX and am.t1 and am.t1 > am.t0 then
                    local alpha = clamp((os.clock() - am.t0) / (am.t1 - am.t0), 0, 1)
                    am.x = am.fromX + (am.toX - am.fromX) * alpha
                    am.y = am.fromY + (am.toY - am.fromY) * alpha
                end
                Core.SetLocalCoords(am.x, am.y, am.vx, am.vy)
            end
        end)

        local aborted, cancelled, stopReason = false, false, nil
        for i = 2, #path do
            if type(shouldContinueFn) == "function" and not shouldContinueFn() then
                cancelled = true
                break
            end
            if stopMode == "stop" and ((H.blockedMoveToCount or 0) > blockedBefore or (H.lastBlockedMoveToAt or 0) >= startT) then
                aborted = true
                stopReason = "stopped_anti_back"
                break
            end
            local n = path[i]
            local destX, destY = n.x + 0.5, n.y + 1
            local segDx, segDy = destX - curPx, destY - curPy
            local dist = math.sqrt(segDx * segDx + segDy * segDy)
            if dist >= 0.02 then
                local isHoriz = math.abs(segDx) >= math.abs(segDy)
                local speed = isHoriz and sH or sV
                -- Batasi step per paket <= 0.85 tile saat Fast Walk agar server selalu menerimanya sebagai Walk legal
                local maxSub = noDelay and math.min(3.2, math.max(0.85, speed * tickSec))
                    or (fastWalk and math.min(0.85, math.max(0.45, speed * tickSec)) or math.max(0.25, speed * tickSec))
                local subSteps = math.max(1, math.ceil(dist / maxSub))
                local stepDt = math.max(tickSec, (dist / subSteps) / speed)
                local totalSegSec = math.max(0.04, subSteps * stepDt)
                local segVx = noDelay and 0 or clamp(segDx / totalSegSec, -18.0, 18.0)
                local segVy = noDelay and 0 or clamp(segDy / totalSegSec, -22.0, 22.0)

                local prevX, prevY = curPx, curPy
                for s = 1, subSteps do
                    if type(shouldContinueFn) == "function" and not shouldContinueFn() then
                        cancelled = true
                        break
                    end
                    local tFrac = s / subSteps
                    local nx = curPx + segDx * tFrac
                    local ny = curPy + segDy * tFrac
                    local fl, fc = computeMoveFlags(nx, ny, segVx, segVy, facing)
                    if antiBack or noValidateBack then
                        if segDx > 0.02 then fc = 1 elseif segDx < -0.02 then fc = -1 end
                        fl = (fc > 0 and 1 or 0) + 2
                    end
                    facing = fc
                    local nowStep = os.clock()
                    H.autoMove = {
                        fromX = prevX, fromY = prevY, toX = nx, toY = ny,
                        x = prevX, y = prevY, vx = segVx, vy = segVy, flags = fl,
                        t0 = nowStep, t1 = nowStep + stepDt,
                    }
                    Core.SetLocalCoords(nx, ny, segVx, segVy)
                    local okSent, sendMsg = Packets.SendRawMove(nx, ny, segVx, segVy, fl)
                    if not okSent and (stopMode == "stop" or stopMode == "nosend") and sendMsg ~= "fly_anchor_owns_move" then
                        aborted = true
                        stopReason = tostring(sendMsg or "no_send_abort")
                        break
                    end
                    prevX, prevY = nx, ny
                    task.wait(stepDt)
                    if stopMode == "stop" and ((H.blockedMoveToCount or 0) > blockedBefore or (H.lastBlockedMoveToAt or 0) >= startT) then
                        aborted = true
                        stopReason = "stopped_anti_back"
                        break
                    end
                    if type(gt.state) == "function" or (H.stateObj and type(H.stateObj.state) == "function") then
                        local chk = Core.ReadPos()
                        if (math.abs(chk.x - nx) + math.abs(chk.y - ny)) > 3.6 then
                            if stopMode == "stop" then
                                Core.SetLocalCoords(curPx, curPy, 0, 0)
                                Packets.SendRawMove(curPx, curPy, 0, 0, (facing > 0 and 1 or 0) + 2)
                                aborted = true
                                stopReason = "stopped_desync_hold"
                                break
                            elseif noValidateBack then
                                Core.SetLocalCoords(nx, ny, segVx, segVy)
                                Packets.SendRawMove(nx, ny, segVx, segVy, fl)
                            else
                                aborted = true
                                break
                            end
                        end
                    end
                end
                if aborted or cancelled then break end
                curPx, curPy = destX, destY
            end
        end

        if H.moveConn then
            pcall(function() H.moveConn:Disconnect() end)
            H.moveConn = nil
        end

        if cancelled then
            H.autoMove = nil
            return false, "cancelled"
        end

        if not aborted then
            local finNode = path[#path]
            local fx, fy = finNode.x + 0.5, finNode.y + 1
            local fFlags = (antiBack or noValidateBack) and ((facing > 0 and 1 or 0) + 2) or computeMoveFlags(fx, fy, 0, 0, facing)
            H.autoMove = { x = fx, y = fy, vx = 0, vy = 0, flags = fFlags }
            Core.SetLocalCoords(fx, fy, 0, 0)
            if noSnap then
                -- Walk normal memakai timestamp non-snap (bukan t=65535) agar tidak terdeteksi TP
                Packets.SendRawMove(fx, fy, 0, 0, fFlags)
            else
                Packets.SendRawMove(fx, fy, 0, 0, fFlags, { t = 65535 })
                if not noDelay then task.wait(0.055) end
                Packets.SendRawMove(fx, fy, 0, 0, fFlags, { t = 65535 })
            end
            H.autoMove = nil
            local fin = Core.ReadPos()
            if noValidateBack or (math.abs(fin.tx - finNode.x) + math.abs(fin.ty - finNode.y)) <= 2 then
                return true, string.format("%s -> (%d, %d)", fastWalk and "Fast Walk OK" or (noDelay and "Anti-Back Sync OK" or "Server Walk OK"), finNode.x, finNode.y)
            end
            aborted = true
        else
            H.autoMove = nil
        end

        if stopReason then
            return false, stopReason
        end

        if aborted and attempt < maxAttempts then
            sH, sV = 6.9, 10.5
            fastWalk = false
            task.wait(0.14)
        end
    end

    H.autoMove = nil
    local f = Core.ReadPos()
    local reached = (math.abs(f.tx - tx) + math.abs(f.ty - ty)) <= 3
    return reached, reached
        and string.format("Sampai (%d, %d)", f.tx, f.ty)
        or string.format("Tertahan aman di (%d, %d) - Anti-Back / Stop Guard", f.tx, f.ty)
end

-- Metode Rekomendasi Jarak Jauh: Walk-Path cepat & mulus tanpa sentinel TP 65535
function Packets.WalkPathTo(tx, ty, speedTilesPerSec, shouldContinueFn, moveOpts)
    local req = tonumber(speedTilesPerSec) or 6.9
    local mOpts = type(moveOpts) == "table" and moveOpts or {}
    local opts = {
        noDelay = mOpts.noDelay == true,
        fastWalk = (mOpts.fastWalk ~= nil) and (mOpts.fastWalk == true) or (req > 7.4),
        noSnap = (mOpts.noSnap == nil) and true or (mOpts.noSnap == true),
        noValidateBack = mOpts.noValidateBack,
        customPath = mOpts.customPath,
    }
    return executeServerSyncedPath(tx, ty, clamp(req, 4.8, 16.0), math.max(12.0, clamp(req * 1.25, 11.5, 20.0)), shouldContinueFn, opts)
end

function Packets.StepTeleport(tx, ty, stepSize, stepDelay, shouldContinueFn)
    Core.EnsureInit()
    Core.EnsureMoveHook()
    local gt = H.gt
    if not gt then return false, "gt nil" end
    tx = clamp(math.floor(tx), 0, gt.w - 1)
    ty = clamp(math.floor(ty), 0, gt.h - 1)

    local gs = GetcSkipper.State
    local antiBack = Core.IsAntiBackActive()
    local stopMode = Core.GetStopOrNoSendMode()
    local noDelay = gs.enabled and gs.longRangeNoDelay == true
    local noValidateBack = antiBack or (gs.enabled and gs.noValidateBack == true)
    if noValidateBack then
        pcall(Core.InstallAntiBackGuard)
        if type(SYT_Logic.InstallNetGuard) == "function" then
            pcall(SYT_Logic.InstallNetGuard)
        end
    end
    if stopMode == "stop" and os.clock() < (H.stopMoveUntil or 0) then
        return false, "stopped_cooldown"
    end

    local cur = Core.ReadPos()
    if cur.tx == tx and cur.ty == ty then return true, "at_target" end

    local path = Packets.FindTilePath(cur.tx, cur.ty, tx, ty)
    if not path or #path <= 1 then
        return false, "Jalur tertutup blok (No-Send Guard)"
    end
    if Core.IsSolid(path[#path].x, path[#path].y) then
        table.remove(path, #path)
        if #path == 0 then return false, "Target solid tanpa celah" end
    end

    local totalDist = #path - 1
    if totalDist <= 1 and not Core.IsSolid(path[#path].x, path[#path].y) then
        local fin = path[#path]
        local fx, fy = fin.x + 0.5, fin.y + 1
        local fFl = noValidateBack and ((fx >= cur.x and 1 or 0) + 2) or computeMoveFlags(fx, fy, (fx - cur.x) * 7, (fy - cur.y) * 7, (fx >= cur.x) and 1 or -1)
        Core.SetLocalCoords(fx, fy, 0, 0)
        Packets.SendRawMove(fx, fy, 0, 0, fFl, { t = 65535 })
        if not noDelay then task.wait(tonumber(stepDelay) or 0.055) end
        return true, string.format("Step TP (1 node) -> (%d, %d)", fin.x, fin.y)
    end

    -- Stepped Anti-Back Logic: hop <= 3 node path (<= 3.45 Euclidean tile agar selalu diterima server tanpa BasePath rollback)
    local reqHop = toInt(stepSize, toInt(gs.safeStepCap, 3))
    local hopCap = antiBack and clamp(reqHop, 1, clamp(toInt(gs.safeStepCap, 3), 1, 3)) or clamp(reqHop, 1, 6)
    local delaySec = math.max(noDelay and 0.048 or 0.062, tonumber(stepDelay) or (noDelay and 0.048 or 0.068))
    local facing = (tx >= cur.tx) and 1 or -1
    local blockedBefore = H.blockedMoveToCount or 0
    local startT = os.clock()
    H.moveConn = H.moveConn and (pcall(function() H.moveConn:Disconnect() end) and nil) or nil

    local idx = 1
    while idx < #path do
        if type(shouldContinueFn) == "function" and not shouldContinueFn() then
            H.autoMove = nil
            return false, "cancelled"
        end
        if stopMode == "stop" and ((H.blockedMoveToCount or 0) > blockedBefore or (H.lastBlockedMoveToAt or 0) >= startT) then
            H.autoMove = nil
            Core.SetLocalCoords(cur.x, cur.y, 0, 0)
            Packets.SendRawMove(cur.x, cur.y, 0, 0, (facing > 0 and 1 or 0) + 2, { t = 65535 })
            return false, "stopped_anti_back"
        end

        local nextIdx = math.min(#path, idx + hopCap)
        while nextIdx > (idx + 1) do
            local cand = path[nextIdx]
            local cdx = (cand.x + 0.5) - cur.x
            local cdy = (cand.y + 1) - cur.y
            if math.sqrt(cdx * cdx + cdy * cdy) <= (antiBack and 3.45 or 5.5) then
                break
            end
            nextIdx -= 1
        end

        idx = nextIdx
        local node = path[idx]
        local nx, ny = node.x + 0.5, node.y + 1
        if nx > cur.x + 0.05 then facing = 1 elseif nx < cur.x - 0.05 then facing = -1 end
        local fl = noValidateBack and ((facing > 0 and 1 or 0) + 2) or computeMoveFlags(nx, ny, 0, 0, facing)
        H.autoMove = { x = nx, y = ny, vx = 0, vy = 0, flags = fl }
        Core.SetLocalCoords(nx, ny, 0, 0)
        local okSent, sendMsg = Packets.SendRawMove(nx, ny, 0, 0, fl)
        if not okSent and (stopMode == "stop" or stopMode == "nosend") and sendMsg ~= "fly_anchor_owns_move" then
            H.autoMove = nil
            return false, tostring(sendMsg or "no_send_abort")
        end
        cur = { x = nx, y = ny, tx = node.x, ty = node.y }
        if idx < #path then
            task.wait(delaySec)
        end
    end

    H.autoMove = nil
    local finNode = path[#path]
    local fx, fy = finNode.x + 0.5, finNode.y + 1
    local finFl = (facing > 0 and 1 or 0) + 2
    Core.SetLocalCoords(fx, fy, 0, 0)
    Packets.SendRawMove(fx, fy, 0, 0, finFl, { t = 65535 })
    return true, string.format("Step Anti-Back OK -> (%d, %d)", finNode.x, finNode.y)
end
stepTeleportImpl = Packets.StepTeleport

function Packets.WalkTeleport(arg1, ty, mode, stepSize, stepDelay)
    Core.EnsureInit()
    Core.EnsureMoveHook()
    local gt = H.gt
    if not gt then return false, "gt nil" end
    local opts = type(arg1) == "table" and arg1 or { tx = arg1, ty = ty, mode = mode, stepSize = stepSize, stepDelay = stepDelay }
    local m = string.lower(tostring(opts.mode or "step"))
    if m == "raw" then
        return Packets.SendRawMove(opts.x or opts.tx or 0, opts.y or opts.ty or 0, opts.vx or 0, opts.vy or 0, opts.flags, opts)
    end
    local tx, py = toInt(opts.tx), toInt(opts.ty)
    if not tx or not py then return false, "invalid coords (no send)" end
    local okVal, msg, cx, cy = Core.ValidateTile(tx, py)
    if not okVal and m ~= "force" then return false, msg .. " (No-Send)" end
    cx, cy = cx or clamp(tx, 0, gt.w - 1), cy or clamp(py, 0, gt.h - 1)
    if m == "walk" or m == "walkpath" or m == "safe" then
        return Packets.WalkPathTo(cx, cy, opts.speed or 6.9, opts.shouldContinueFn)
    elseif m == "direct" or m == "force" then
        local cur = Core.ReadPos()
        local distCheb = math.max(math.abs((cx + 0.5) - cur.x), math.abs((cy + 1) - cur.y))
        if m == "direct" and distCheb > 3.4 then
            return Packets.StepTeleport(cx, cy, opts.stepSize or 3, opts.stepDelay or 0.052, opts.shouldContinueFn)
        end
        pcall(Core.InstallAntiBackGuard)
        if m == "force" then
            Core.AllowMoveToWindow(0.8)
        end
        local px, wy = cx + 0.5, cy + 1
        local facing = (px >= cur.x) and 1 or -1
        local fl = (Core.IsAntiBackActive() or GetcSkipper.State.noValidateBack) and ((facing > 0 and 1 or 0) + 2) or computeMoveFlags(px, wy, 0, 0, facing)
        Core.SetLocalCoords(px, wy, 0, 0)
        local okS, rsn = Packets.SendRawMove(px, wy, 0, 0, fl, { t = 65535, forceBypass = (m == "force") })
        if not okS then return false, tostring(rsn or "no_send") end
        return true, string.format("Direct TP -> Tile (%d, %d) | Stats (%d, %d)", cx, cy, cx + 1, cy + 1)
    end
    local dfltStep = clamp(toInt(GetcSkipper.State.safeStepCap, 3), 1, 3)
    local dfltDelay = (GetcSkipper.State.enabled and GetcSkipper.State.longRangeNoDelay) and 0.048 or 0.065
    return Packets.StepTeleport(cx, cy, opts.stepSize or dfltStep, opts.stepDelay or dfltDelay, opts.shouldContinueFn)
end

function Packets.FindStandCandidates(tx, ty, maxRange)
    local cur = Core.ReadPos()
    local r = toInt(maxRange, 4) or 4
    local gt = H.gt
    local w, h = (gt and gt.w) or 100, (gt and gt.h) or 60
    local cands = {}
    for dy = -r, r do
        for dx = -r, r do
            local ax, ay = tx + dx, ty + dy
            if ax >= 0 and ax < w and ay >= 0 and ay < h and not Core.IsSolid(ax, ay) then
                local distP = math.abs(ax - cur.tx) + math.abs(ay - cur.ty)
                local cheb = math.max(math.abs(dx), math.abs(dy))
                cands[#cands + 1] = { x = ax, y = ay, score = distP * 10 + cheb }
            end
        end
    end
    table.sort(cands, function(a, b) return a.score < b.score end)
    local out = {}
    local limit = math.min(#cands, 12)
    for idx = 1, limit do
        local c = cands[idx]
        local p = Packets.FindTilePath(cur.tx, cur.ty, c.x, c.y)
        if p and #p >= 1 then
            out[#out + 1] = { x = c.x, y = c.y, path = p, len = #p }
        end
    end
    table.sort(out, function(a, b) return a.len < b.len end)
    return out
end

-- Navigasi Walk Murni (khusus Dirt Farm & Fast Walk: anti-teleport, berjalan cepat mengikuti path valid)
function Packets.MoveWalkNear(tx, ty, maxRange, shouldContinueFn, walkSpeed, actionKind)
    local r = toInt(maxRange, 2) or 2
    local cur = Core.ReadPos()
    if actionKind then
        if Core.IsInActionReach(tx, ty, actionKind, cur) then return true, "in_reach" end
    elseif r == 0 then
        if cur.tx == tx and cur.ty == ty then return true, "at_target" end
    elseif math.max(math.abs(cur.tx - tx), math.abs(cur.ty - ty)) <= r then
        return true, "in_range"
    end
    local spd = clamp(tonumber(walkSpeed) or 11.5, 4.8, 16.0)
    local walkOpts = { fastWalk = spd > 7.4, noSnap = true }
    if r == 0 and not Core.IsSolid(tx, ty) then
        local okW, msgW = Packets.WalkPathTo(tx, ty, spd, shouldContinueFn, walkOpts)
        if okW then return true, msgW end
    end
    local cands = Packets.FindStandCandidates(tx, ty, r)
    if #cands == 0 then
        return false, "unreachable"
    end
    local maxTries = math.min(#cands, 4)
    local lastMsg = "walk_failed"
    for i = 1, maxTries do
        if type(shouldContinueFn) == "function" and not shouldContinueFn() then
            return false, "cancelled"
        end
        local c = cands[i]
        if (not actionKind) or Core.IsInActionReach(tx, ty, actionKind, { x = c.x + 0.5, y = c.y + 1 }) then
            walkOpts.customPath = c.path
            local okW, msgW = Packets.WalkPathTo(c.x, c.y, spd, shouldContinueFn, walkOpts)
            local chk = Core.ReadPos()
            if (actionKind and Core.IsInActionReach(tx, ty, actionKind, chk))
                or (not actionKind and (okW or math.max(math.abs(chk.tx - tx), math.abs(chk.ty - ty)) <= r)) then
                return true, msgW or "walk_ok"
            end
            lastMsg = msgW or lastMsg
        end
    end
    return false, lastMsg
end

-- Navigasi Hybrid TP x Walk (khusus Auto Pabrik: TP jarak jauh <= 3 tile/hop lalu Walk masuk ke titik target)
function Packets.MoveHybrid(tx, ty, maxRange, shouldContinueFn, opts)
    opts = opts or {}
    local r = toInt(maxRange, 4) or 4
    local cur = Core.ReadPos()
    if r == 0 then
        if cur.tx == tx and cur.ty == ty then return true, "at_target" end
    elseif math.max(math.abs(cur.tx - tx), math.abs(cur.ty - ty)) <= r then
        return true, "in_range"
    end

    local gx, gy, path
    if r == 0 and not Core.IsSolid(tx, ty) then
        gx, gy = tx, ty
        path = Packets.FindTilePath(cur.tx, cur.ty, gx, gy)
    else
        local cands = Packets.FindStandCandidates(tx, ty, r)
        if cands[1] then
            gx, gy, path = cands[1].x, cands[1].y, cands[1].path
        end
    end
    if not gx or not path or #path == 0 then
        return false, "unreachable"
    end

    local distNodes = #path - 1
    if distNodes <= 6 then
        local okW, msgW = Packets.WalkPathTo(gx, gy, 7.1, shouldContinueFn)
        local chk = Core.ReadPos()
        if okW or (r > 0 and math.max(math.abs(chk.tx - tx), math.abs(chk.ty - ty)) <= r) or (r == 0 and chk.tx == gx and chk.ty == gy) then
            return true, msgW
        end
        return Packets.StepTeleport(gx, gy, clamp(toInt(opts.stepSize, 3), 1, 3), math.max(0.048, tonumber(opts.stepDelay) or 0.052), shouldContinueFn)
    end

    -- Fase 1 (TP): lompat aman <= 3 tile per step hingga ~3 tile sebelum tujuan
    local tpIdx = math.max(2, #path - 3)
    local tpNode = path[tpIdx]
    local okTp, msgTp = Packets.StepTeleport(tpNode.x, tpNode.y, clamp(toInt(opts.stepSize, 3), 1, 3), math.max(0.048, tonumber(opts.stepDelay) or 0.050), shouldContinueFn)
    if type(shouldContinueFn) == "function" and not shouldContinueFn() then
        return false, "cancelled"
    end
    if not okTp and msgTp == "stopped_anti_back" then
        return false, msgTp
    end

    -- Fase 2 (Walk): selesaikan pendekatan akhir dengan Walk fisik agar tidak rubberband/nyangkut
    local chk = Core.ReadPos()
    if (r == 0 and chk.tx == gx and chk.ty == gy) or (r > 0 and math.max(math.abs(chk.tx - tx), math.abs(chk.ty - ty)) <= r) then
        return true, "tp_walk_ok"
    end
    local okW, msgW = Packets.WalkPathTo(gx, gy, 7.1, shouldContinueFn)
    chk = Core.ReadPos()
    if okW or (r > 0 and math.max(math.abs(chk.tx - tx), math.abs(chk.ty - ty)) <= r) or (r == 0 and chk.tx == gx and chk.ty == gy) then
        return true, msgW or "tp_walk_ok"
    end
    return Packets.StepTeleport(gx, gy, 2, 0.055, shouldContinueFn)
end

-- Navigasi Reach Server-Exact sebelum Punch / Break / Place / Collect (Stop / No-Send jika di luar jangkauan)
function Packets.EnsureActionReach(tx, ty, kind, shouldContinueFn, opts)
    opts = opts or {}
    if Core.IsInActionReach(tx, ty, kind) then
        return true, "in_reach"
    end
    local reach = Core.GetActionRange(kind)
    local searchR = math.max(1, math.floor(reach - 0.1))
    local cands = Packets.FindStandCandidates(tx, ty, searchR)
    local gx, gy
    for _, c in ipairs(cands) do
        local cx, cy = c.x + 0.5, c.y + 1
        local dx = math.abs((tx + 0.5) - cx)
        local dy = math.abs((ty + 0.5) - (cy - 0.475))
        if dx <= reach and dy <= reach then
            gx, gy = c.x, c.y
            break
        end
    end
    if not gx and cands[1] then
        gx, gy = cands[1].x, cands[1].y
    end
    if not gx then
        H.lastActionBlockedAt = os.clock()
        H.lastActionBlockedReason = "unreachable_no_send"
        return false, "unreachable_no_send"
    end

    if opts.preferWalk == true then
        local wspd = tonumber(opts.walkSpeed) or 11.0
        Packets.WalkPathTo(gx, gy, wspd, shouldContinueFn, { fastWalk = wspd > 7.4, noSnap = true })
    elseif opts.preferHybrid == true then
        Packets.MoveHybrid(gx, gy, 0, shouldContinueFn, opts)
    else
        Packets.StepTeleport(gx, gy, 3, math.max(0.048, tonumber(opts.stepDelay) or 0.050), shouldContinueFn)
    end

    if Core.IsInActionReach(tx, ty, kind) then
        return true, "moved_in_reach"
    end
    H.lastActionBlockedAt = os.clock()
    H.lastActionBlockedReason = "out_of_range_no_send"
    return false, "out_of_range_no_send"
end

local function waitPacketInterval(delaySec, rawTiming, packetKind, shouldContinueFn)
    local d = tonumber(delaySec) or 0
    if d <= 0 then return true end
    if rawTiming then
        local dl = os.clock() + d
        while os.clock() < dl do
            if type(shouldContinueFn) == "function" and not shouldContinueFn() then return false end
            task.wait(math.min(0.02, math.max(0.004, dl - os.clock())))
        end
        return true
    end
    GetcSkipper.RandomizedWait(d, packetKind or "act", shouldContinueFn)
    return (type(shouldContinueFn) ~= "function") or shouldContinueFn()
end

local function countDropsInRadius(tx, ty, pad)
    local gt = H.gt
    if not gt or type(gt.dropList) ~= "function" then return 0 end
    local ok, drops = pcall(gt.dropList)
    if not ok or type(drops) ~= "table" then return 0 end
    local p = tonumber(pad) or 1.6
    local cnt = 0
    for _, d in ipairs(drops) do
        if type(d) == "table" and (d.n or 0) > 0 and d.x and d.y then
            if math.abs(d.x - (tx + 0.5)) <= p and math.abs((d.y - 0.5) - ty) <= p then
                cnt += 1
            end
        end
    end
    return cnt
end

local function computeEffectiveHits(info, curId, isRetry)
    local base = (info and info.kind == "seed") and 20 or math.max(1, toInt(info and info.hits, 3))
    if info and info.kind ~= "seed" and H.skillsObj and type(H.skillsObj.handDig) == "function" then
        local okD, digVal = pcall(H.skillsObj.handDig)
        if okD and (tonumber(digVal) or 0) > 0 then
            base = math.max(1, math.ceil(base * 6 / 8 - 1e-6))
        end
    end
    return base
end

local function waitTilePlaceCooldown(layer, tx, ty, shouldContinueFn)
    local gt = H.gt
    if not gt or type(gt.placedAt) ~= "table" or not gt.w then return true end
    local layerName = (layer == 2) and "bg" or "fg"
    local pm = gt.placedAt[layerName]
    if type(pm) ~= "table" then return true end
    local tAt = pm[ty * gt.w + tx]
    if type(tAt) == "number" then
        local elapsed = os.clock() - tAt
        -- Game.lua L3744: server menolak punch dalam < 0.30s sejak block di-place
        if elapsed < 0.31 then
            return waitPacketInterval(0.31 - elapsed, true, "tile", shouldContinueFn)
        end
    end
    return true
end

function Packets.PunchBreak(arg1, ty, layer, flip, showHand)
    Core.EnsureInit()
    local gt, net = H.gt, H.Net
    if not gt or not net or not net.tile or not net.tile.send then return false, "net nil" end
    local opts = type(arg1) == "table" and arg1 or { tx = arg1, ty = ty, layer = layer, flip = flip, showHand = showHand }
    local tx, py = toInt(opts.tx), toInt(opts.ty)
    if not tx or not py or tx < 0 or tx >= gt.w or py < 0 or py >= gt.h then return false, "out_of_bounds" end
    local targetLayer = toInt(opts.layer, 1)
    local curId = Core.GetLayerTile(tx, py, targetLayer)
    if curId == 0 and not opts.force then return true, "empty" end
    if not opts.ignoreProtected and Core.IsProtectedTile(curId) then return false, "protected_no_send" end
    if not Core.CanEditTile(tx, py) and not opts.ignoreProtected then return false, "no_edit_no_send" end

    -- Validasi Jangkauan Punch (Game.lua punchRange): Stop / No-Send jika gagal menjangkau
    if opts.autoRange ~= false then
        local okR, msgR = Packets.EnsureActionReach(tx, py, "punch", opts.shouldContinue, opts)
        if not okR then return false, msgR end
    elseif not Core.IsInActionReach(tx, py, "punch") and Core.GetStopOrNoSendMode() ~= "off" then
        H.lastActionBlockedAt = os.clock()
        H.lastActionBlockedReason = "punch_out_of_range_no_send"
        return false, "out_of_range_no_send"
    end

    if not opts.skipPlaceCooldown then
        if not waitTilePlaceCooldown(targetLayer, tx, py, opts.shouldContinue) then
            return false, "cancelled"
        end
    end
    if opts.respectCooldown then
        local actWait = math.max(tonumber(gt.actAt) or 0, (H.lastPunchAt or 0) + 0.16) - os.clock()
        if actWait > 0.005 then
            if not waitPacketInterval(math.min(actWait, 0.25), true, "act", opts.shouldContinue) then
                return false, "cancelled"
            end
        end
    end

    local info = Core.GetItemInfo(curId)
    if opts.showHand ~= false and net.act and net.act.send then
        pcall(net.act.send, { kind = 1, x = tx + 0.5, y = py + 0.5 })
        pcall(net.act.send, { kind = 6, x = tx + 0.5, y = py + 0.5 })
    end
    H.lastPunchAt = os.clock()
    if opts.playPunchVisual then
        Core.PlayVisualPunch(tx, py, opts.showVisual ~= false)
    end
    Core.MarkSelfTileEdit(targetLayer, tx, py)
    if opts.harvestIfTree ~= false and info and info.kind == "seed" and info.provider and net.harvest and net.harvest.send then
        local okH = pcall(net.harvest.send, { x = tx, y = py })
        if okH and opts.noLocalMirror ~= true then Core.MirrorLocalTile(1, tx, py, 0) end
        return okH, okH and "harvest_sent" or "harvest_failed"
    end
    local ok = pcall(net.tile.send, { layer = targetLayer, x = tx, y = py, id = 0, flip = opts.flip == true })
    if ok then
        H.lastTileAt = os.clock()
        gt.actAt = math.max(tonumber(gt.actAt) or 0, os.clock() + 0.16)
        if opts.noLocalMirror ~= true then
            Core.MirrorLocalTile(targetLayer, tx, py, 0)
        end
    end
    return ok, ok and "break_sent" or "send_failed"
end

function Packets.HitDamage(arg1, ty, oneHit, customHits, hitDelay, layer, showHand)
    Core.EnsureInit()
    local gt, net = H.gt, H.Net
    if not gt or not net then return false, "net_nil" end
    local opts = type(arg1) == "table" and arg1 or { tx = arg1, ty = ty, oneHit = oneHit, customHits = customHits, hitDelay = hitDelay, layer = layer, showHand = showHand }
    local tx, py = toInt(opts.tx), toInt(opts.ty)
    if not tx or not py or tx < 0 or tx >= gt.w or py < 0 or py >= gt.h then return false, "out_of_bounds" end
    local targetLayer = toInt(opts.layer, 1)
    local curId = Core.GetLayerTile(tx, py, targetLayer)
    if curId == 0 then return true, "empty" end
    if Core.IsProtectedTile(curId) or not Core.CanEditTile(tx, py) then return false, "protected_no_send" end

    if opts.autoRange ~= false then
        local okR, msgR = Packets.EnsureActionReach(tx, py, "break", opts.shouldContinue, opts)
        if not okR then return false, msgR end
    elseif not Core.IsInActionReach(tx, py, "break") and Core.GetStopOrNoSendMode() ~= "off" then
        H.lastActionBlockedAt = os.clock()
        H.lastActionBlockedReason = "break_out_of_range_no_send"
        return false, "out_of_range_no_send"
    end

    if opts.oneHit == true then
        Core.SyncOneHitHook(60)
        Core.EnsureBestDigEquipped()
    end

    local cont = opts.shouldContinue
    if not opts.skipPlaceCooldown then
        if not waitTilePlaceCooldown(targetLayer, tx, py, cont) then return false, "cancelled" end
    end

    local info = Core.GetItemInfo(curId)
    local effHits = computeEffectiveHits(info, curId)
    local key = ((targetLayer == 2) and "bg" or "fg") .. ":" .. (py * (gt.w or 100) + tx)
    local minPunchGap = (opts.oneHit == true) and 0.08 or 0.192
    local delay = tonumber(opts.hitDelay)
    if delay == nil then delay = 0.194 end
    delay = clamp(delay, minPunchGap, 0.45)

    -- Mode 1-Hit terverifikasi: uji 1 pukulan nyata dulu; jika server tidak 1-hit, langsung sambung sisa hit tanpa ghost-break
    if opts.oneHit == true and not opts.forceMultiHit and not toInt(opts.customHits, nil) then
        local preDrops = countDropsInRadius(tx, py, 1.8)
        local sentAt = os.clock()
        Packets.PunchBreak({
            tx = tx, ty = py, layer = targetLayer,
            showHand = opts.showHand ~= false,
            playPunchVisual = true, showVisual = opts.showVisual ~= false,
            autoRange = false, skipPlaceCooldown = true,
            noLocalMirror = true, shouldContinue = cont,
        })
        local probeDl = os.clock() + 0.145
        while os.clock() < probeDl do
            if type(cont) == "function" and not cont() then return false, "cancelled" end
            if Core.GetLayerTile(tx, py, targetLayer) == 0 then return true, "broken" end
            local ack = H.tileAck and H.tileAck[key]
            if ack and ack.t >= (sentAt - 0.02) and ack.id == 0 then
                Core.MirrorLocalTile(targetLayer, tx, py, 0)
                return true, "server_1hit"
            end
            if countDropsInRadius(tx, py, 1.8) > preDrops then
                Core.MirrorLocalTile(targetLayer, tx, py, 0)
                return true, "drop_1hit"
            end
            if ack and ack.t >= (sentAt - 0.02) and ack.id ~= 0 then
                break
            end
            task.wait(0.02)
        end
        if Core.GetLayerTile(tx, py, targetLayer) == 0 then return true, "broken" end
        effHits = math.max(1, effHits - 1)
    end

    local totalHits = toInt(opts.customHits, nil) or effHits
    local showVis = (opts.showVisual ~= false)

    -- Hit awal (totalHits - 1) mengirim act.send kind 1+6 agar damage terdaftar penuh di server sebelum tile.send(0)
    for _ = 1, math.max(0, totalHits - 1) do
        if type(cont) == "function" and not cont() then return false, "cancelled" end
        if Core.GetLayerTile(tx, py, targetLayer) == 0 then return true, "broken" end
        if not Core.IsInActionReach(tx, py, "break") and Core.GetStopOrNoSendMode() ~= "off" then
            return false, "moved_out_of_range_no_send"
        end
        if net.act and net.act.send then
            pcall(net.act.send, { kind = 1, x = tx + 0.5, y = py + 0.5 })
            pcall(net.act.send, { kind = 6, x = tx + 0.5, y = py + 0.5 })
        end
        H.lastPunchAt = os.clock()
        Core.PlayVisualPunch(tx, py, showVis)
        if delay > 0 then
            if not waitPacketInterval(delay, opts.rawTiming, "act", cont) then return false, "cancelled" end
        end
        if Core.GetLayerTile(tx, py, targetLayer) == 0 then return true, "broken" end
    end

    local maxExtra = math.max(4, effHits + 5)
    for extraPass = 0, maxExtra do
        if type(cont) == "function" and not cont() then return false, "cancelled" end
        if Core.GetLayerTile(tx, py, targetLayer) == 0 then return true, "broken" end
        if not Core.IsInActionReach(tx, py, "break") and Core.GetStopOrNoSendMode() ~= "off" then
            return false, "moved_out_of_range_no_send"
        end
        if opts.oneHit ~= true then
            local cdLeft = math.max(tonumber(gt.actAt) or 0, (H.lastPunchAt or 0) + 0.192) - os.clock()
            if cdLeft > 0.004 then
                if not waitPacketInterval(math.min(cdLeft, 0.25), true, "act", cont) then return false, "cancelled" end
            end
        end
        local sentAt = os.clock()
        Packets.PunchBreak({
            tx = tx, ty = py, layer = targetLayer,
            showHand = opts.showHand ~= false,
            playPunchVisual = (extraPass > 0), showVisual = showVis,
            autoRange = false,
            skipPlaceCooldown = true,
            noLocalMirror = (opts.noLocalMirror == true),
            shouldContinue = cont,
        })
        if opts.verifyBreak == false then
            return (opts.noLocalMirror ~= true) or (Core.GetLayerTile(tx, py, targetLayer) == 0), "sent"
        end
        local waitEnd = os.clock() + (tonumber(opts.verifyTimeout) or 0.24)
        local reverted = false
        while os.clock() < waitEnd do
            if type(cont) == "function" and not cont() then return false, "cancelled" end
            local ack = H.tileAck and H.tileAck[key]
            if ack and ack.t >= (sentAt - 0.02) and ack.id ~= 0 then
                reverted = true
                break
            end
            if Core.GetLayerTile(tx, py, targetLayer) ~= 0 and opts.noLocalMirror ~= true then
                reverted = true
                break
            end
            if Core.GetLayerTile(tx, py, targetLayer) == 0 and (not H.serverTileEchoSeen or (ack and ack.t >= (sentAt - 0.02) and ack.id == 0)) then
                pcall(Core.ClearVisualCrack, tx, py)
                return true, "verified_broken"
            end
            task.wait(0.015)
        end
        if not reverted and Core.GetLayerTile(tx, py, targetLayer) == 0 then
            pcall(Core.ClearVisualCrack, tx, py)
            return true, "verified_broken"
        end
        local retryDelay = math.max(delay, 0.194)
        if not waitPacketInterval(retryDelay, true, "act", cont) then return false, "cancelled" end
    end
    local okEnd = Core.GetLayerTile(tx, py, targetLayer) == 0
    if okEnd then pcall(Core.ClearVisualCrack, tx, py) end
    return okEnd, okEnd and "broken" or "verify_failed"
end

-- Break Paralel tervalidasi jangkauan (batch radius <= 2 agar seluruh tile masuk dalam punchRange 2.5+)
function Packets.BreakBlocksParallel(targets, opts)
    Core.EnsureInit()
    local gt = H.gt
    if not gt or type(targets) ~= "table" or #targets == 0 then return 0 end
    opts = opts or {}
    local defaultLayer = toInt(opts.layer, 1)
    local maxThreads = clamp(toInt(opts.threads or opts.maxThreads, 3), 1, 3)
    local shouldCont = opts.shouldContinue or opts.shouldContinueFn

    local queue = {}
    for _, t in ipairs(targets) do
        local tx, ty = toInt(t.tx or t.x), toInt(t.ty or t.y)
        local lyr = toInt(t.layer, defaultLayer)
        if tx and ty and tx >= 0 and tx < gt.w and ty >= 0 and ty < gt.h then
            local curId = Core.GetLayerTile(tx, ty, lyr)
            if curId ~= 0 and not Core.IsProtectedTile(curId) and Core.CanEditTile(tx, ty) then
                queue[#queue + 1] = { tx = tx, ty = ty, layer = lyr }
            end
        end
    end
    if #queue == 0 then return 0 end
    if opts.oneHit == true then
        Core.SyncOneHitHook(60)
        Core.EnsureBestDigEquipped()
    end

    local brokeTotal = 0
    local i = 1
    while i <= #queue do
        if type(shouldCont) == "function" and not shouldCont() then break end
        local anchor = queue[i]
        local batch = { anchor }
        while #batch < maxThreads and (i + #batch) <= #queue do
            local cand = queue[i + #batch]
            if math.max(math.abs(cand.tx - anchor.tx), math.abs(cand.ty - anchor.ty)) <= 2 then
                batch[#batch + 1] = cand
            else
                break
            end
        end
        i += #batch

        if opts.autoRange ~= false then
            local cx, cy = 0, 0
            for _, b in ipairs(batch) do cx += b.tx; cy += b.ty end
            cx, cy = math.floor(cx / #batch + 0.5), math.floor(cy / #batch + 0.5)
            Packets.EnsureActionReach(cx, cy, "break", shouldCont, opts)
        end

        for pass = 1, 2 do
            if type(shouldCont) == "function" and not shouldCont() then break end
            local remBatch = {}
            for _, b in ipairs(batch) do
                if Core.GetLayerTile(b.tx, b.ty, b.layer) ~= 0 then
                    remBatch[#remBatch + 1] = b
                end
            end
            if #remBatch == 0 then break end
            local pending = #remBatch
            for k, b in ipairs(remBatch) do
                task.spawn(function()
                    if k > 1 then task.wait((k - 1) * 0.022) end
                    Packets.HitDamage({
                        tx = b.tx, ty = b.ty, layer = b.layer,
                        oneHit = opts.oneHit == true and pass == 1,
                        forceMultiHit = (pass > 1),
                        customHits = opts.customHits,
                        hitDelay = opts.hitDelay,
                        showHand = opts.showHand,
                        showVisual = opts.showVisual ~= false,
                        noLocalMirror = (opts.noLocalMirror == true),
                        verifyBreak = opts.verifyBreak,
                        autoRange = (opts.autoRange ~= false),
                        preferWalk = opts.preferWalk,
                        preferHybrid = opts.preferHybrid,
                        shouldContinue = shouldCont,
                    })
                    pending -= 1
                end)
            end
            local dl = os.clock() + 4.5
            while pending > 0 and os.clock() < dl do
                if type(shouldCont) == "function" and not shouldCont() then break end
                task.wait(0.015)
            end
        end
        for _, b in ipairs(batch) do
            if Core.GetLayerTile(b.tx, b.ty, b.layer) == 0 then
                brokeTotal += 1
            end
        end
        if i <= #queue then
            GetcSkipper.RandomizedWait(opts.chunkDelay or 0.025, "tile", shouldCont)
        end
    end
    return brokeTotal
end

-- ═══ VERIFIED PIPELINE (Place -> Break -> Collect) + Worker Pool ═══
local function runPool(items, threads, fn, shouldCont)
    local n = #items
    if n == 0 then return end
    local nextIdx, active = 1, 0
    local workers = math.max(1, math.min(threads or 3, n))
    for _ = 1, workers do
        active += 1
        task.spawn(function()
            while true do
                if type(shouldCont) == "function" and not shouldCont() then break end
                local i = nextIdx
                if i > n then break end
                nextIdx += 1
                pcall(fn, items[i], i)
            end
            active -= 1
        end)
    end
    local dl = os.clock() + 30
    while active > 0 and os.clock() < dl do
        task.wait(0.01)
    end
end
Packets.RunPool = runPool

-- Sinkronisasi slot Place strict >= 0.165s (mengikuti Game.lua L1893 actAt 0.16s agar zero "placing too fast")
local function reservePlaceSlot(minGap, shouldContinueFn)
    local now = os.clock()
    local gap = clamp(tonumber(minGap) or H.adaptivePlaceGap or 0.168, 0.164, 0.36)
    if H.lastPlaceRejectedAt and (now - H.lastPlaceRejectedAt) > 2.0 and (H.adaptivePlaceGap or 0.168) > 0.168 then
        H.adaptivePlaceGap = math.max(0.168, (H.adaptivePlaceGap or 0.168) - 0.004)
    end
    local gtActAt = (H.gt and tonumber(H.gt.actAt)) or 0
    local rejectUntil = ((H.lastPlaceRejectedAt or 0) > 0) and (H.lastPlaceRejectedAt + 0.32) or 0
    local slotAt = math.max(now, H.nextPlaceAllowedAt or 0, rejectUntil, gtActAt)
    H.nextPlaceAllowedAt = slotAt + gap
    while os.clock() < slotAt do
        if type(shouldContinueFn) == "function" and not shouldContinueFn() then return false end
        task.wait(math.min(0.03, math.max(0.005, slotAt - os.clock())))
    end
    return (type(shouldContinueFn) ~= "function") or shouldContinueFn()
end

function Packets.VerifyTile(tx, ty, layer, expectId, opts)
    opts = opts or {}
    local gt = H.gt
    if not gt then return false, "gt_nil" end
    local timeout = tonumber(opts.timeout) or 0.25
    local stableNeed = tonumber(opts.stable) or 0.055
    local sentAt = opts.sentAt or os.clock()
    local strict = (opts.requireServerAck == true) or (opts.noLocalMirror == true)
    local key = ((layer == 2) and "bg" or "fg") .. ":" .. (ty * gt.w + tx)
    local t0, stableSince = os.clock(), nil
    while (os.clock() - t0) < timeout do
        if type(opts.shouldContinue) == "function" and not opts.shouldContinue() then return false, "cancelled" end
        local ack = H.tileAck and H.tileAck[key]
        if ack and ack.t >= (sentAt - 0.02) and ack.id ~= expectId then
            -- Server mengirim nilai berbeda (gagal 1-hit atau revert); hentikan tunggu agar bisa retry cepat
            return false, "server_mismatch"
        end
        if opts.checkPlaceReject and (H.lastPlaceRejectedAt or 0) >= (sentAt - 0.02) and (H.lastPlaceRejectedAt or 0) <= (sentAt + 0.35) then
            if not (ack and ack.id == expectId and ack.t >= (sentAt - 0.02)) then
                return false, "placing_too_fast"
            end
        end
        if Core.GetLayerTile(tx, ty, layer) == expectId then
            if ack and ack.id == expectId and ack.t >= (sentAt - 0.02) then
                return true, "server_ack"
            end
            if not strict then
                stableSince = stableSince or os.clock()
                if (os.clock() - stableSince) >= stableNeed then
                    return true, "visual_stable"
                end
            end
        else
            stableSince = nil
        end
        task.wait(0.015)
    end
    local ack = H.tileAck and H.tileAck[key]
    if Core.GetLayerTile(tx, ty, layer) == expectId then
        if not strict or (ack and ack.id == expectId and ack.t >= (sentAt - 0.02)) then
            return true, ack and "server_ack" or "visual_match"
        end
    end
    return false, H.serverTileEchoSeen and "no_server_ack" or "timeout"
end

-- STEP 1: place + pacing anti too-fast + verifikasi visual == server (sinkron langsung tanpa stuck place)
function Packets.PlaceVerified(tx, ty, id, layer, opts)
    opts = opts or {}
    local cont = opts.shouldContinue
    local pd = tonumber(opts.delay) or 0
    local strict = (opts.noLocalMirror == true) -- mirror visual seperti Game.lua lalu revert hanya jika server tolak
    for _ = 1, (opts.retries or 2) + 1 do
        if type(cont) == "function" and not cont() then return false, "cancelled" end
        local cur = Core.GetLayerTile(tx, ty, layer)
        if cur == id then return true, "matched" end
        if cur ~= 0 then return false, "occupied" end
        if Core.CountItem(id) <= 0 then return false, "no_item" end
        local sentAt = os.clock()
        local ok, msgP = Packets.Place({
            tx = tx, ty = ty, itemId = id, layer = layer,
            showHand = opts.showHand,
            autoRange = opts.autoRange == true,
            preferHybrid = opts.preferHybrid == true,
            noLocalMirror = strict,
            placeGap = opts.placeGap,
            bypassPlaceThrottle = opts.bypassPlaceThrottle,
            shouldContinue = cont,
        })
        if ok then
            if pd > 0 then
                if not waitPacketInterval(pd, true, "tile", cont) then return false, "cancelled" end
            end
            local vOk, vReason = Packets.VerifyTile(tx, ty, layer, id, {
                sentAt = sentAt, stable = opts.stable or 0.05,
                timeout = opts.verifyTimeout or 0.16,
                noLocalMirror = strict,
                requireServerAck = strict and H.serverTileEchoSeen,
                checkPlaceReject = true,
                shouldContinue = cont,
            })
            if vOk then return true, vReason end
            if vReason == "placing_too_fast" or vReason == "server_mismatch" then
                if Core.GetLayerTile(tx, ty, layer) == id and not strict then
                    Core.MirrorLocalTile(layer, tx, ty, 0, false)
                end
                local inv = Core.GetLiveInventory()
                if inv and type(inv.add) == "function" and Core.GetLayerTile(tx, ty, layer) ~= id then
                    pcall(function() inv:add(id, 1) end)
                end
                if vReason == "placing_too_fast" then
                    waitPacketInterval(0.24, true, "tile", cont)
                end
            else
                -- Fallback bila server mode tidak pernah mengirim echo tileChanged & tidak revert
                if not strict and Core.GetLayerTile(tx, ty, layer) == id then
                    return true, "visual_ok"
                end
                if strict and not H.serverTileEchoSeen then
                    local gt = H.gt
                    local key = ((layer == 2) and "bg" or "fg") .. ":" .. (ty * (gt and gt.w or 100) + tx)
                    local ack = H.tileAck and H.tileAck[key]
                    if not (ack and ack.t >= (sentAt - 0.02) and ack.id ~= id) then
                        Core.MirrorLocalTile(layer, tx, ty, id, false)
                        return true, "no_echo_mirror"
                    end
                end
            end
        elseif msgP == "matched" then
            return true, "matched"
        end
        task.wait(0.03)
    end
    return Core.GetLayerTile(tx, ty, layer) == id, "verify_failed"
end

-- STEP 2: break multi-thread + terus punch sampai blok benar-benar hancur + sync visual client
function Packets.BreakVerified(targets, opts)
    opts = opts or {}
    local gt = H.gt
    if not gt then return 0, #targets end
    local layerDef = toInt(opts.layer, 1)
    local list = {}
    for _, t in ipairs(targets) do
        local lyr = toInt(t.layer, layerDef)
        local tx, ty = toInt(t.tx or t.x), toInt(t.ty or t.y)
        if tx and ty and Core.GetLayerTile(tx, ty, lyr) ~= 0 then
            local cid = Core.GetLayerTile(tx, ty, lyr)
            if not Core.IsProtectedTile(cid) and Core.CanEditTile(tx, ty) then
                list[#list + 1] = { tx = tx, ty = ty, layer = lyr }
            end
        end
    end
    if #list == 0 then return 0, 0 end
    if opts.oneHit == true then
        Core.SyncOneHitHook(60)
        Core.EnsureBestDigEquipped()
    end
    if opts.autoRange ~= false then
        local cx, cy = 0, 0
        for _, b in ipairs(list) do cx += b.tx; cy += b.ty end
        Packets.EnsureActionReach(math.floor(cx / #list + 0.5), math.floor(cy / #list + 0.5), "break", opts.shouldContinue, opts)
    end
    local threads = clamp(toInt(opts.threads, #list), 1, 9)
    local okCount = 0
    runPool(list, threads, function(b, workerIdx)
        if workerIdx > 1 then task.wait(math.min(0.08, (workerIdx - 1) * 0.018)) end
        for attempt = 1, 5 do
            if type(opts.shouldContinue) == "function" and not opts.shouldContinue() then return end
            if Core.GetLayerTile(b.tx, b.ty, b.layer) == 0 then
                okCount += 1
                return
            end
            local okHit, hitReason = Packets.HitDamage({
                tx = b.tx, ty = b.ty, layer = b.layer,
                oneHit = opts.oneHit == true and attempt == 1,
                forceMultiHit = (attempt >= 2),
                hitDelay = (attempt >= 2) and math.max(0.15, tonumber(opts.hitDelay) or 0.165) or opts.hitDelay,
                showHand = (opts.showHand ~= false),
                showVisual = opts.showVisual ~= false,
                autoRange = (opts.autoRange ~= false),
                preferWalk = opts.preferWalk,
                preferHybrid = opts.preferHybrid,
                noLocalMirror = (opts.noLocalMirror == true),
                verifyTimeout = opts.verifyTimeout or 0.125,
                rawTiming = true,
                skipPlaceCooldown = (attempt == 1),
                shouldContinue = opts.shouldContinue,
            })
            if okHit or Core.GetLayerTile(b.tx, b.ty, b.layer) == 0 then
                okCount += 1
                return
            end
            if hitReason == "out_of_range_no_send" or hitReason == "unreachable_no_send" then
                return
            end
            task.wait(0.025)
        end
    end, opts.shouldContinue)
    return okCount, #list - okCount
end

-- STEP 3: verifikasi drop (seed/block/gems) di tile terpilih benar-benar sudah ter-collect
function Packets.CollectVerified(tiles, opts)
    opts = opts or {}
    local gt = H.gt
    if not gt or type(gt.dropList) ~= "function" or #tiles == 0 then return true end
    local minX, maxX, minY, maxY = 1e9, -1e9, 1e9, -1e9
    for _, t in ipairs(tiles) do
        local tx, ty = t.tx or t.x, t.ty or t.y
        minX, maxX = math.min(minX, tx), math.max(maxX, tx)
        minY, maxY = math.min(minY, ty), math.max(maxY, ty)
    end
    local pad = tonumber(opts.pad) or 2.5
    local function pending()
        local ok, drops = pcall(gt.dropList)
        local out = {}
        if ok and type(drops) == "table" then
            for _, d in ipairs(drops) do
                if type(d) == "table" and (d.n or 0) > 0 and d.x and d.y
                    and d.x >= minX - pad and d.x <= maxX + 1 + pad
                    and (d.y - 0.5) >= minY - pad and (d.y - 0.5) <= maxY + 1 + pad
                    and (d.id == 112 or Core.GetItemRoom(d.id) > 0) then
                    out[#out + 1] = d
                end
            end
        end
        return out
    end
    local cont = opts.shouldContinue
    if opts.expectDrops then
        local t0 = os.clock()
        local waitLim = tonumber(opts.waitDrop) or 0.14
        while (os.clock() - t0) < waitLim and #pending() == 0 do
            if type(cont) == "function" and not cont() then return false end
            task.wait(0.015)
        end
    end
    for attempt = 1, 4 do
        if type(cont) == "function" and not cont() then return false end
        local pend = pending()
        if #pend == 0 then return true end
        if attempt >= 2 then
            H.takingUids = H.takingUids or {}
            for _, d in ipairs(pend) do
                d.taking = false
                if d.uid then H.takingUids[d.uid] = nil end
            end
        end
        Packets.Collect({
            radius = 4.6,
            stepMoveIfFar = attempt >= 3,
            preferWalk = opts.preferWalk,
            preferHybrid = opts.preferHybrid,
            collectDelay = opts.collectDelay or 0,
            shouldContinue = cont,
        })
        local t0 = os.clock()
        while (os.clock() - t0) < 0.20 and #pending() > 0 do
            if type(cont) == "function" and not cont() then return false end
            task.wait(0.015)
        end
    end
    return #pending() == 0
end

function Packets.Place(arg1, ty, itemId, layer, flip, showHand)
    Core.EnsureInit()
    Core.EnsureChatWarnHook()
    local gt, net = H.gt, H.Net
    if not gt or not net or not net.tile or not net.tile.send then return false, "net nil" end
    local opts = type(arg1) == "table" and arg1 or { tx = arg1, ty = ty, itemId = itemId, layer = layer, flip = flip, showHand = showHand }
    local tx, py, id = toInt(opts.tx), toInt(opts.ty), toInt(opts.itemId or opts.id)
    if not tx or not py or not id or id <= 0 or tx < 0 or tx >= gt.w or py < 0 or py >= gt.h then return false, "invalid" end
    if Core.CountItem(id) <= 0 and not opts.ignoreCount then return false, "no_item" end

    local info = Core.GetItemInfo(id)
    local targetLayer = toInt(opts.layer, (info and info.background) and 2 or 1)
    local preId = Core.GetLayerTile(tx, py, targetLayer)
    if preId == id and not opts.force then return true, "matched" end
    if preId ~= 0 and not opts.force then return false, "occupied" end

    -- Validasi Jangkauan Build (Game.lua buildRange) + Anti Solid-Overlap Badan Player (Game.lua canPlace L3430)
    if opts.autoRange ~= false then
        local okR, msgR = Packets.EnsureActionReach(tx, py, "build", opts.shouldContinue, opts)
        if not okR then return false, msgR end
    elseif not Core.IsInActionReach(tx, py, "build") and Core.GetStopOrNoSendMode() ~= "off" then
        H.lastActionBlockedAt = os.clock()
        H.lastActionBlockedReason = "place_out_of_range_no_send"
        return false, "out_of_range_no_send"
    end

    local okBody, bodyReason = Core.CanPlaceBodyOk(tx, py, info)
    if not okBody and not opts.ignoreBodyOverlap then
        H.lastActionBlockedAt = os.clock()
        H.lastActionBlockedReason = bodyReason .. "_no_send"
        return false, bodyReason .. "_no_send"
    end

    if opts.bypassPlaceThrottle ~= true then
        if not reservePlaceSlot(opts.placeGap, opts.shouldContinue) then
            return false, "cancelled"
        end
        local postId = Core.GetLayerTile(tx, py, targetLayer)
        if postId == id and not opts.force then return true, "matched" end
        if postId ~= 0 and not opts.force then return false, "occupied" end
        if Core.CountItem(id) <= 0 and not opts.ignoreCount then return false, "no_item" end
        if not Core.IsInActionReach(tx, py, "build") and Core.GetStopOrNoSendMode() ~= "off" then
            return false, "out_of_range_no_send"
        end
        local okB2, bRsn2 = Core.CanPlaceBodyOk(tx, py, info)
        if not okB2 and not opts.ignoreBodyOverlap then
            return false, bRsn2 .. "_no_send"
        end
    end

    if opts.showHand ~= false and net.act and net.act.send then
        pcall(net.act.send, { kind = (info and info.kind == "seed") and 3 or 2, x = tx + 0.5, y = py + 0.5 })
    end
    Core.MarkSelfTileEdit(targetLayer, tx, py)
    local ok = pcall(net.tile.send, { layer = targetLayer, x = tx, y = py, id = id, flip = opts.flip == true })
    if ok then
        local nowT = os.clock()
        H.lastTileAt = nowT
        gt.actAt = math.max(tonumber(gt.actAt) or 0, nowT + 0.16)
        if opts.noLocalMirror ~= true then
            Core.MirrorLocalTile(targetLayer, tx, py, id, opts.flip == true)
        end
        if H.inv and type(H.inv.remove) == "function" then pcall(function() H.inv:remove(id, 1) end) end
    end
    return ok, ok and "placed" or "failed"
end

function Packets.SendChat(arg1, prefixColor, isWhisper, whisperTarget)
    Core.EnsureInit()
    Core.EnsureOutboundFirewall()
    local opts = type(arg1) == "table" and arg1 or { message = arg1, prefixColor = prefixColor, isWhisper = isWhisper, whisperTarget = whisperTarget }
    local rawMsg = tostring(opts.message or opts.text or "")
    local prefix = tostring(opts.prefixColor or opts.color or "")
    if rawMsg == "" then return false, "empty" end
    local fullMsg = prefix ~= "" and (prefix .. rawMsg) or rawMsg
    local maxLen  = clamp(toInt(opts.maxLength, 120), 1, 120)
    if #fullMsg > maxLen then fullMsg = string.sub(fullMsg, 1, maxLen) end

    local gs = SYT_Logic.GetcSkipper and SYT_Logic.GetcSkipper.State
    local shieldOn = not (gs and gs.antiKickShield == false)
    if shieldOn and (H.chatBackoffUntil or 0) > os.clock() then
        local remWait = H.chatBackoffUntil - os.clock()
        if remWait > 0 and remWait < 6.0 then
            task.wait(remWait)
        end
    end
    if opts.bypassRateLimit ~= true or shieldOn then
        GetcSkipper.RandomizedWait(shieldOn and 0.25 or 0, "chat", opts.shouldContinue)
    end

    if opts.isWhisper and opts.whisperTarget and H.Net and type(H.Net.call) == "function" then
        return pcall(H.Net.call, "ModCommand", "msg", tostring(opts.whisperTarget) .. " " .. fullMsg)
    end
    local wn = cleanWorldName(H.gt and H.gt.name or "")
    local wc = TextChatService:FindFirstChild("WorldChannels")
    local ch = (wc and wn ~= "" and wc:FindFirstChild(wn)) or TextChatService:FindFirstChild("RBXGeneral")
    if not ch then
        local tc = TextChatService:FindFirstChild("TextChannels")
        if tc then ch = (wn ~= "" and tc:FindFirstChild(wn)) or tc:FindFirstChild("RBXGeneral") end
    end
    if not ch or type(ch.SendAsync) ~= "function" then return false, "no_channel" end
    return pcall(function() return ch:SendAsync(fullMsg) end)
end

function Packets.Collect(arg1, filterId, stepMoveIfFar, collectDelay)
    Core.EnsureInit()
    local gt = H.gt
    if not gt or type(gt.dropList) ~= "function" then return { totalTaken = 0, gemsTaken = 0, itemsTaken = 0 } end
    local opts = type(arg1) == "table" and arg1 or { radius = arg1, filterId = filterId, stepMoveIfFar = stepMoveIfFar, collectDelay = collectDelay }
    local pickupMax = 4.6
    local radius = math.min(pickupMax, tonumber(opts.radius) or pickupMax)
    local targetId, stepFar = opts.filterId, opts.stepMoveIfFar == true
    local delay = tonumber(opts.collectDelay) or 0.03
    local shouldContinueFn = opts.shouldContinue or opts.shouldContinueFn
    local okD, drops = pcall(gt.dropList)
    if not okD or type(drops) ~= "table" then return { totalTaken = 0, gemsTaken = 0, itemsTaken = 0 } end

    local now = os.clock()
    H.takingUids = H.takingUids or {}
    for uid, exp in pairs(H.takingUids) do
        if exp <= now then H.takingUids[uid] = nil end
    end

    local function distToDrop(d, cp)
        local distBody = math.max(math.abs(d.x - cp.x), math.abs(d.y - (cp.y - 0.5)))
        local distTile = math.max(math.abs(d.x - (cp.tx + 0.5)), math.abs(d.y - (cp.ty + 0.5)))
        return math.min(distBody, distTile)
    end

    local pos = Core.ReadPos()
    local list = {}
    for i = 1, #drops do
        local d = drops[i]
        if type(d) == "table" and d.uid and d.x and d.y and (d.n or 0) > 0 and (d.readyAt or 0) <= now then
            if not d.taking and (not H.takingUids[d.uid] or H.takingUids[d.uid] <= now) then
                if not targetId or d.id == targetId then
                    local dist = distToDrop(d, pos)
                    if (dist <= radius or stepFar) and (d.id == 112 or Core.GetItemRoom(d.id) > 0) then
                        list[#list + 1] = { drop = d, dist = dist }
                    end
                end
            end
        end
    end
    if #list == 0 then return { totalTaken = 0, gemsTaken = 0, itemsTaken = 0 } end
    table.sort(list, function(a, b) return a.dist < b.dist end)

    local sum = { totalTaken = 0, gemsTaken = 0, itemsTaken = 0 }

    local function collectBatchInRange()
        local cp = Core.ReadPos()
        local batch = {}
        local tNow = os.clock()
        for _, item in ipairs(list) do
            local d = item.drop
            if (d.n or 0) > 0 and not d.taking and (not H.takingUids[d.uid] or H.takingUids[d.uid] <= tNow) then
                -- Anti No-Send: hanya kirim takeDrop bila benar-benar masuk dalam jangkauan pickup server <= 4.6 tile
                if distToDrop(d, cp) <= pickupMax then
                    local want = math.min(d.n, (d.id == 112) and d.n or Core.GetItemRoom(d.id))
                    if want > 0 then
                        d.taking = true
                        H.takingUids[d.uid] = tNow + 1.5
                        batch[#batch + 1] = { drop = d, want = want }
                    end
                end
            end
        end
        if #batch == 0 then return 0 end

        -- Eksekusi seluruh drop dalam radius secara paralel bersamaan (mirror Game.lua task.spawn)
        local pending = #batch
        for _, entry in ipairs(batch) do
            local d, want = entry.drop, entry.want
            local preN = d.n or want
            task.spawn(function()
                local got = 0
                if type(gt.takeDrop) == "function" then
                    local okT, res = pcall(gt.takeDrop, d.uid, want)
                    if okT and type(res) == "number" then got = res end
                elseif H.Net and H.Net.take and H.Net.take.send then
                    H.takeSeq += 1
                    if pcall(H.Net.take.send, { seq = H.takeSeq, uid = d.uid, want = want }) then got = want end
                end
                if got > 0 then
                    sum.totalTaken += got
                    local rem = math.max(0, preN - got)
                    d.n = rem
                    d.flown = (rem <= 0)
                    if d.frame and rem <= 0 then
                        pcall(function() d.frame.Visible = false end)
                    end
                    Core.ClearStuckDropVisuals(d.uid, rem)
                    if d.id == 112 then
                        sum.gemsTaken += got
                    else
                        sum.itemsTaken += got
                        local inv = Core.GetLiveInventory()
                        if inv and type(inv.add) == "function" then pcall(function() inv:add(d.id, got) end) end
                    end
                end
                d.taking = false
                H.takingUids[d.uid] = nil
                pending -= 1
            end)
        end

        local deadline = os.clock() + 0.45
        while pending > 0 and os.clock() < deadline do
            if type(shouldContinueFn) == "function" and not shouldContinueFn() then break end
            task.wait(0.02)
        end
        return #batch
    end

    collectBatchInRange()

    if stepFar then
        for _ = 1, 16 do
            if type(shouldContinueFn) == "function" and not shouldContinueFn() then break end
            local cp = Core.ReadPos()
            local nextDrop, bestDist = nil, math.huge
            for _, item in ipairs(list) do
                local d = item.drop
                if (d.n or 0) > 0 and not d.taking and (d.id == 112 or Core.GetItemRoom(d.id) > 0) then
                    local dist = distToDrop(d, cp)
                    if dist < bestDist then
                        bestDist = dist
                        nextDrop = d
                    end
                end
            end
            if not nextDrop then break end
            if bestDist > pickupMax then
                local dx, dy = math.floor(nextDrop.x), math.floor(nextDrop.y)
                local movedOk = false
                if opts.preferWalk == true then
                    movedOk = Packets.MoveWalkNear(dx, dy, 2, shouldContinueFn, tonumber(opts.walkSpeed) or 12.0)
                elseif opts.preferHybrid == true then
                    movedOk = Packets.MoveHybrid(dx, dy, 2, shouldContinueFn, { stepSize = 3, stepDelay = math.max(0.048, delay) })
                else
                    movedOk = Packets.StepTeleport(dx, dy, 3, math.max(0.048, delay), shouldContinueFn)
                end
                if not movedOk and distToDrop(nextDrop, Core.ReadPos()) > pickupMax then
                    break
                end
            end
            local fired = collectBatchInRange()
            if fired == 0 then break end
        end
    end

    if sum.totalTaken > 0 and delay > 0 then
        GetcSkipper.RandomizedWait(delay, "take", shouldContinueFn)
    end
    return sum
end

-- 6. V1 [MISC], V2 [PNB], V3 [AUTO PABRIK], V4 [VISUAL], V5 [SPAM]
local stopAllAutomationImpl
local buildSYTMenuFn

local Misc = {
    State = {
        fly = false, flySpeed = 14, flyMethod = "SteppedAnchor", flyAntiBasePath = true, flyMaxCeilingY = 0.25,
        seems = false, seemsPaused = false, seemsReason = "",
        fastRoulette = false, lastWheelSpin = nil, rouletteHistory = {},
        noClip = false, noClipAnchor = nil,
        godMode = false,
        autoFollow = false, followTarget = "", followToken = 0, followThread = nil, followStatus = "Idle",
        collectState = false, autoCleanDrops = true, comboGems = 0, lastGemAt = 0, sessionGems = 0,
        autoCollect = false, autoCollectRadius = 5, autoCollectStep = false, autoCollectDelay = 0.04,
        autoCollectToken = 0, autoCollectThread = nil,
        fpsBoost = false,
    }
}
SYT_Logic.Misc = Misc

-- Metode Fly Baru (SteppedAnchor): visual tetap halus & terlihat player lain via sync <= 3.4 tile/0.082s + grounded flags (anti BasePath rollback)
local function unbindFlyRenderStep()
    pcall(RunService.UnbindFromRenderStep, RunService, "SYT_FlyStep")
end

function Core.StartSteppedAnchorFly()
    local gt = H.gt
    if not gt then return false end
    unbindFlyRenderStep()
    pcall(Core.InstallAntiBackGuard)
    if type(SYT_Logic.InstallNetGuard) == "function" then
        pcall(SYT_Logic.InstallNetGuard)
    end

    local p0 = Core.ReadPos()
    local visX, visY = p0.x, p0.y
    local syncX, syncY = p0.x, p0.y
    local lastSyncAt = os.clock()
    local lastGuardAt = lastSyncAt
    local lastTouchScanAt = 0
    local facing = 1

    local touchBtns = { left = {}, right = {}, up = {}, down = {} }
    local function scanTouchBtns()
        touchBtns = { left = {}, right = {}, up = {}, down = {} }
        pcall(function()
            local pg = LP and LP:FindFirstChildOfClass("PlayerGui")
            local gg = pg and pg:FindFirstChild("GameGui")
            if gg then
                for _, d in ipairs(gg:GetDescendants()) do
                    if d:IsA("GuiButton") and d.Visible then
                        local nm = string.lower(d.Name)
                        if string.find(nm, "left", 1, true) then table.insert(touchBtns.left, d)
                        elseif string.find(nm, "right", 1, true) then table.insert(touchBtns.right, d)
                        elseif string.find(nm, "jump", 1, true) or string.find(nm, "up", 1, true) then table.insert(touchBtns.up, d)
                        elseif string.find(nm, "down", 1, true) or string.find(nm, "crouch", 1, true) then table.insert(touchBtns.down, d) end
                    end
                end
            end
        end)
    end
    scanTouchBtns()

    local function anyTouchDown(list)
        for _, b in ipairs(list) do
            if b.Parent and b.Visible and b.GuiState == Enum.GuiState.Press then
                return true
            end
        end
        return false
    end

    gt.ghost = true
    gt.stuckAt = nil
    H.lastSentMove = { x = syncX, y = syncY, vx = 0, vy = 0, flags = 3, t = lastSyncAt }
    H.antiBackAnchor = { x = visX, y = visY, t = lastSyncAt }
    Packets.SendRawMove(syncX, syncY, 0, 0, (facing > 0 and 1 or 0) + 2)

    local alive = true
    RunService:BindToRenderStep("SYT_FlyStep", Enum.RenderPriority.Last.Value + 20, function(dt)
        if not alive or getEnv().__SYT_SCRIPT_TOKEN ~= MY_SCRIPT_TOKEN or not Misc.State.fly or Misc.State.flyMethod == "GhostHybrid" or H.gt ~= gt then
            alive = false
            unbindFlyRenderStep()
            if H.flyConn then H.flyConn = nil end
            return
        end

        gt.ghost = true
        gt.stuckAt = nil
        local now = os.clock()
        if (now - lastGuardAt) >= 1.5 then
            lastGuardAt = now
            pcall(Core.InstallAntiBackGuard)
        end
        if (#touchBtns.left + #touchBtns.right + #touchBtns.up) == 0 and (now - lastTouchScanAt) >= 1.5 then
            lastTouchScanAt = now
            scanTouchBtns()
        end

        local frameDt = clamp(tonumber(dt) or 0.016, 0.004, 0.08)
        local speed = clamp(tonumber(Misc.State.flySpeed) or 14, 6, 45)
        local ceilY = clamp(tonumber(Misc.State.flyMaxCeilingY) or 0.25, 0.15, 0.95)
        local maxY = math.max(1.0, (gt.h or 60) - 0.5)
        local maxX = math.max(1.0, (gt.w or 100) - 0.5)

        local mvX, mvY = 0, 0
        if not UserInputService:GetFocusedTextBox() then
            if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left) or anyTouchDown(touchBtns.left) then mvX -= 1 end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) or anyTouchDown(touchBtns.right) then mvX += 1 end
            if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up) or UserInputService:IsKeyDown(Enum.KeyCode.Space) or anyTouchDown(touchBtns.up) then mvY -= 1 end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down) or UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or anyTouchDown(touchBtns.down) then mvY += 1 end
        end

        -- Mobile / Virtual Joystick Fallback: tangkap input kecil dari engine Game.lua, tolak snap/teleport > 1.25 tile
        if mvX == 0 and mvY == 0 and not H.autoMove then
            local raw = Core.ReadPos()
            local engDx, engDy = raw.x - visX, raw.y - visY
            local engDist = math.abs(engDx) + math.abs(engDy)
            if engDist > 0.002 and engDist <= 1.25 then
                mvX, mvY = engDx, engDy
            end
        end

        if mvX ~= 0 then facing = (mvX > 0) and 1 or -1 end
        local mag = math.sqrt(mvX * mvX + mvY * mvY)
        if mag > 0 then
            mvX, mvY = mvX / mag, mvY / mag
        end

        -- Anti-Rollback Fly: visual posisi bebas bergerak di segala ketinggian & jarak (> 6 tile aman tanpa ditarik mundur)
        if not H.autoMove then
            visX = clamp(visX + mvX * speed * frameDt, 0.5, maxX)
            visY = clamp(visY + mvY * speed * frameDt, ceilY, maxY)
        else
            visX, visY = H.autoMove.x, H.autoMove.y
        end

        Core.SetLocalCoords(visX, visY, 0, 0)
        H.flyLastValidPos = { x = visX, y = visY, vx = 0, vy = 0, t = now }
        H.antiBackAnchor = { x = visX, y = visY, t = now }

        -- Sync server smooth sesuai ritme 15Hz Growblox (~0.067s) dengan step <= 1.05 H / 1.22 V & vx/vy konsisten
        local dH = visX - syncX
        local dV = visY - syncY
        local absDH, absDV = math.abs(dH), math.abs(dV)
        local elapsed = now - lastSyncAt
        local needStep = (absDH >= 0.03 or absDV >= 0.03) and elapsed >= 0.067
        local needKeepAlive = elapsed >= 0.75
        if needStep or needKeepAlive then
            local stepDx = clamp(dH, -1.05, 1.05)
            local stepDy = clamp(dV, -1.22, 1.22)
            syncX = syncX + stepDx
            syncY = syncY + stepDy
            local safeDt = math.max(0.055, elapsed)
            local svx = (absDH >= 0.03) and clamp(stepDx / safeDt, -16.0, 16.0) or 0
            local svy = (absDV >= 0.03) and clamp(stepDy / safeDt, -20.0, 22.0) or 0
            local onGround = Core.IsSolid(math.floor(syncX), math.floor(syncY + 0.05))
            local groundedBit = (onGround or math.abs(svy) < 1.2) and 2 or 0
            local fl = (facing > 0 and 1 or 0) + groundedBit
            Packets.SendRawMove(syncX, syncY, svx, svy, fl)
            lastSyncAt = now
        end
    end)

    H.flyConn = {
        Disconnect = function()
            alive = false
            unbindFlyRenderStep()
        end
    }
    getEnv().__SYT_FLY_CONN = H.flyConn
    return true
end

local function snapOutOfSolidAtCurrentPos(gt)
    if not gt then return false end
    local p = Core.ReadPos()
    if not (Core.IsSolid(p.tx, p.ty) or Core.IsSolid(p.tx, math.floor(p.y - 1.01))) then
        return false
    end
    local best, bd = nil, 1e9
    for dy = -6, 6 do
        for dx = -6, 6 do
            local ax, ay = p.tx + dx, p.ty + dy
            if ax >= 0 and ax < gt.w and ay >= 1 and ay < gt.h
                and not Core.IsSolid(ax, ay) and not Core.IsSolid(ax, ay - 1) then
                local d = dx * dx + dy * dy
                if d < bd then bd, best = d, { x = ax, y = ay } end
            end
        end
    end
    if best then
        local nx, ny = best.x + 0.5, best.y + 1
        Core.SetLocalCoords(nx, ny, 0, 0)
        Packets.SendRawMove(nx, ny, 0, 0, 2, { t = 65535 })
        return true
    end
    return false
end

function Misc.SetFly(enabled, speed)
    Core.EnsureInit()
    Core.EnsureMoveHook()
    Misc.State.fly = enabled == true
    if type(speed) == "number" then Misc.State.flySpeed = clamp(speed, 6, 45) end
    unbindFlyRenderStep()
    if H.flyConn then H.flyConn:Disconnect(); H.flyConn = nil end
    local gt = H.gt
    if not gt then return false end

    if not Misc.State.fly then
        H.flyLastValidPos = nil
        gt.ghost = (Misc.State.noClip == true)
        -- Jika berhenti terbang persis di dalam blok solid, geser halus ke tile kosong terdekat agar anti-stuck game tidak me-respawn ke spawn/base
        snapOutOfSolidAtCurrentPos(gt)
        return false
    end

    -- Pasang Anti-Back Guard & NetGuard agar server Net.moveTo / goTo tidak menarik balik ke BasePath/Spawn saat Fly
    pcall(Core.InstallAntiBackGuard)
    if type(SYT_Logic.InstallNetGuard) == "function" then
        pcall(SYT_Logic.InstallNetGuard)
    end
    local p0 = Core.ReadPos()
    H.flyLastValidPos = { x = p0.x, y = p0.y, vx = 0, vy = 0, t = os.clock() }
    Core.SetLocalCoords(p0.x, p0.y, 0, 0) -- Sinkronkan goPrev/goAck ke posisi mulai terbang

    if Misc.State.flyMethod ~= "GhostHybrid" then
        return Core.StartSteppedAnchorFly()
    end

    -- Mode GhostHybrid (opsional): mode 'ghost' engine Growblox ditambah proteksi EnsureMoveHook & Anti-Back Guard
    gt.ghost = true
    gt.stuckAt = nil
    H.flyConn = RunService.Heartbeat:Connect(function(dt)
        if getEnv().__SYT_SCRIPT_TOKEN ~= MY_SCRIPT_TOKEN then
            if H.flyConn then H.flyConn:Disconnect(); H.flyConn = nil end
            return
        end
        if not Misc.State.fly then return end
        local g = H.gt
        if not g or g.name == "" then return end
        if g.ghost ~= true then g.ghost = true end
        g.stuckAt = nil

        local safeDt = math.min(dt or 0.016, 0.05)
        local ceilY = clamp(tonumber(Misc.State.flyMaxCeilingY) or 0.25, 0.15, 0.95)
        local cur = Core.ReadPos()
        local last = H.flyLastValidPos

        -- Cegah snapback tiba-tiba ke BasePath / Spawn oleh anti-warp internal client
        if Misc.State.flyAntiBasePath ~= false and last and (os.clock() - (last.t or 0)) < 2.0 then
            local jumpDist = math.abs(cur.x - last.x) + math.abs(cur.y - last.y)
            local sp = g.spawn
            local pulledToSpawn = sp and sp.X and sp.Y and (math.abs(cur.x - sp.X) + math.abs(cur.y - sp.Y) <= 2.4) and (math.abs(last.x - sp.X) + math.abs(last.y - sp.Y) > 3.2)
            if (jumpDist > 5.8 or pulledToSpawn) and not H.autoMove then
                Core.SetLocalCoords(last.x, last.y, 0, 0)
                Packets.SendRawMove(last.x, last.y, 0, 0, 2)
                return
            end
        end

        local targetSpd = clamp(tonumber(Misc.State.flySpeed) or 12, 6, 45)
        if H.stateObj and type(H.stateObj.state) == "function" then
            local okSt, st = pcall(H.stateObj.state)
            if okSt and type(st) == "table" and st.active then
                local vx, vy = tonumber(st.vx) or 0, tonumber(st.vy) or 0
                local cx, cy = tonumber(st.x) or cur.x, tonumber(st.y) or cur.y
                local upPressed = false
                pcall(function()
                    upPressed = UserInputService:IsKeyDown(Enum.KeyCode.W)
                        or UserInputService:IsKeyDown(Enum.KeyCode.Up)
                        or UserInputService:IsKeyDown(Enum.KeyCode.Space)
                end)

                local nx, ny = cx, cy
                local effVx, effVy = vx, vy
                -- Dorong naik melewati batas y=0.95 bawaan Game.lua saat menahan tombol naik
                if upPressed and ny <= 1.25 then
                    ny = clamp(ny - (targetSpd * 0.72 * safeDt), ceilY, g.h or 60)
                    effVy = -math.max(math.abs(vy), targetSpd * 0.7)
                end

                if (math.abs(vx) > 0.1 or math.abs(vy) > 0.1) and math.abs(targetSpd - 10.8) > 1.2 then
                    local mag = math.sqrt(vx * vx + vy * vy)
                    local extra = targetSpd - 10.8
                    local step = math.clamp(extra * safeDt, -0.65, 0.65)
                    nx = clamp(nx + (vx / mag) * step, 0.3, (g.w or 100) - 0.3)
                    ny = clamp(ny + (vy / mag) * step, ceilY, g.h or 60)
                    effVx = vx * (targetSpd / 10.8)
                    effVy = vy * (targetSpd / 10.8)
                end

                if nx ~= cx or ny ~= cy then
                    Core.SetLocalCoords(nx, ny, effVx, effVy)
                    cur.x, cur.y = nx, ny
                elseif Misc.State.flyAntiBasePath ~= false then
                    -- Jaga goPrev & goAck selalu terikat ke posisi terbaru agar tidak mundur ke BasePath
                    Core.SetLocalCoords(cur.x, cur.y, vx, vy)
                end
            end
        end
        H.flyLastValidPos = { x = cur.x, y = cur.y, t = os.clock() }
    end)
    getEnv().__SYT_FLY_CONN = H.flyConn
    return true
end

local fpsSavedGuis, fpsSavedFx, fpsSavedShadows = {}, {}, nil
local function isBgOrFxGui(obj)
    if not obj or not obj:IsA("GuiObject") then return false end
    local nm = string.lower(obj.Name)
    if nm == "backdrop" or nm == "weathers" or nm == "weather" or nm == "weatherfx"
        or nm == "worldfx" or nm == "particles" or nm == "sky" or nm == "clouds"
        or nm == "hills" or nm == "mountains" or nm == "parallax" or nm == "sun" or nm == "moon" or nm == "stars" then
        return true
    end
    local anc = obj.Parent
    while anc do
        local an = string.lower(anc.Name)
        if an == "backdrop" or an == "weathers" or an == "weatherfx" or an == "worldfx" or an == "particles" then
            return true
        end
        if an == "gamegui" or anc:IsA("ScreenGui") then break end
        anc = anc.Parent
    end
    return false
end

function Misc.SetFpsBoost(enabled)
    Core.EnsureInit()
    local on = enabled == true
    Misc.State.fpsBoost = on

    if H.fpsConn then H.fpsConn:Disconnect(); H.fpsConn = nil end

    if on then
        local pg = LP and LP:FindFirstChildOfClass("PlayerGui")
        local gg = pg and pg:FindFirstChild("GameGui")
        if gg then
            for _, d in ipairs(gg:GetDescendants()) do
                if isBgOrFxGui(d) then
                    if fpsSavedGuis[d] == nil then fpsSavedGuis[d] = d.Visible end
                    d.Visible = false
                end
            end
            H.fpsConn = gg.DescendantAdded:Connect(function(d)
                if Misc.State.fpsBoost and isBgOrFxGui(d) then
                    if fpsSavedGuis[d] == nil then fpsSavedGuis[d] = d.Visible end
                    d.Visible = false
                end
            end)
        end
        if H.particles then
            for _, k in ipairs({ "swirl", "ghost", "dust", "sparkle", "burst", "smoke" }) do
                if type(H.particles[k]) == "function" then
                    H["origFps_" .. k] = H["origFps_" .. k] or H.particles[k]
                    H.particles[k] = function(...)
                        if Misc.State.fpsBoost then return end
                        return H["origFps_" .. k](...)
                    end
                end
            end
        end
        fpsSavedShadows = Lighting.GlobalShadows
        pcall(function() Lighting.GlobalShadows = false end)
        for _, inst in ipairs(workspace:GetDescendants()) do
            if inst:IsA("ParticleEmitter") or inst:IsA("Trail") or inst:IsA("Beam") or inst:IsA("Smoke") or inst:IsA("Fire") or inst:IsA("Sparkles") then
                if fpsSavedFx[inst] == nil then fpsSavedFx[inst] = inst.Enabled end
                inst.Enabled = false
            end
        end
        emitNotify("FPS Boost", "Background & World FX disembunyikan (ON)")
    else
        for obj, vis in pairs(fpsSavedGuis) do
            if obj and obj.Parent then pcall(function() obj.Visible = vis end) end
        end
        table.clear(fpsSavedGuis)
        if H.particles then
            for _, k in ipairs({ "swirl", "ghost", "dust", "sparkle", "burst", "smoke" }) do
                if H["origFps_" .. k] then H.particles[k] = H["origFps_" .. k] end
            end
        end
        if fpsSavedShadows ~= nil then
            pcall(function() Lighting.GlobalShadows = fpsSavedShadows end)
            fpsSavedShadows = nil
        end
        for inst, en in pairs(fpsSavedFx) do
            if inst and inst.Parent then pcall(function() inst.Enabled = en end) end
        end
        table.clear(fpsSavedFx)
    end
    return Misc.State.fpsBoost
end

local function evaluateSeems()
    if not Misc.State.seems then
        Misc.State.seemsPaused = false
        Misc.State.seemsReason = ""
        return false
    end
    local plrs = Core.GetInWorldPlayers(true)
    local staffName, count = nil, #plrs
    for _, p in ipairs(plrs) do
        if not p.isSelf and p.isStaff then
            staffName = p.gameName
            break
        end
    end
    if staffName or count > 1 then
        local reason = staffName and ("Staff: " .. staffName) or string.format("Player > 1 (%d)", count)
        local was = Misc.State.seemsPaused
        Misc.State.seemsPaused = true
        Misc.State.seemsReason = reason
        if type(stopAllAutomationImpl) == "function" then stopAllAutomationImpl("SEEMS: " .. reason) end
        if not was then emitNotify("SEEMS Aktif", reason) end
        return true
    end
    Misc.State.seemsPaused = false
    Misc.State.seemsReason = ""
    return false
end

function Misc.SetSeems(enabled)
    Core.EnsureInit()
    Misc.State.seems = enabled == true
    if not H.seemsHooked then
        H.seemsHooked = true
        Players.PlayerAdded:Connect(function() if Misc.State.seems then task.delay(0.15, evaluateSeems) end end)
        Players.PlayerRemoving:Connect(function() if Misc.State.seems then task.delay(0.1, evaluateSeems) end end)
        if H.Net and H.Net.entered and type(H.Net.entered.listen) == "function" then
            H.Net.entered.listen(function() if Misc.State.seems then evaluateSeems() end end)
        end
    end
    evaluateSeems()
    return Misc.State.seems
end

local ROULETTE_RED = {
    [1]=true, [3]=true, [5]=true, [7]=true, [9]=true, [12]=true,
    [14]=true, [16]=true, [18]=true, [19]=true, [21]=true, [23]=true,
    [25]=true, [27]=true, [30]=true, [32]=true, [34]=true, [36]=true,
}

local function sanitizeRouletteNumber(raw)
    if raw == nil then return nil end
    local s = stripColorTags(tostring(raw)):gsub("^%s+", ""):gsub("%s+$", "")
    if s == "" or string.sub(s, 1, 1) == "-" then return nil end
    -- Tolak anomali angka > 2 digit (mis. 100..9999)
    if string.match(s, "%d%d%d+") then return nil end
    local digits = string.match(s, "^(%d%d?)$") or string.match(s, "(%d%d?)")
    if not digits then return nil end
    local num = tonumber(digits)
    if num and num >= 0 and num <= 36 then
        return math.floor(num)
    end
    return nil
end

local rouletteHideToken = 0
local function showRoulettePopup(rollerName, num, tx, ty)
    if type(num) ~= "number" or num < 0 or num > 36 then return end
    table.insert(Misc.State.rouletteHistory, 1, num)
    while #Misc.State.rouletteHistory > 6 do table.remove(Misc.State.rouletteHistory) end

    local parentGui = getSafeHui() or CoreGui or (LP and LP:FindFirstChildOfClass("PlayerGui"))
    if not parentGui then return end
    if H.rouletteGui and H.rouletteGui.Parent then
        H.rouletteGui:Destroy()
    end

    local sg = Instance.new("ScreenGui")
    sg.Name = "SYT_RoulettePopupGui"
    sg.IgnoreGuiInset = true
    sg.ResetOnSpawn = false
    sg.DisplayOrder = 1000001
    sg.Parent = parentGui
    H.rouletteGui = sg

    local card = Instance.new("Frame")
    card.Size = UDim2.fromOffset(308, 122)
    card.AnchorPoint = Vector2.new(0.5, 0)
    card.Position = UDim2.new(0.5, 0, 0, 14)
    card.BackgroundColor3 = Color3.fromRGB(12, 16, 24)
    card.BorderSizePixel = 0
    card.Parent = sg
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 12)
    local stroke = Instance.new("UIStroke", card)
    stroke.Thickness = 1.6

    local isGreen = (num == 0)
    local isRed   = ROULETTE_RED[num] == true
    local badgeCol = isGreen and Color3.fromRGB(16, 185, 129) or (isRed and Color3.fromRGB(220, 38, 38) or Color3.fromRGB(30, 41, 59))
    stroke.Color = isGreen and Color3.fromRGB(52, 211, 153) or (isRed and Color3.fromRGB(248, 113, 113) or Color3.fromRGB(100, 116, 139))

    local header = Instance.new("TextLabel")
    header.Size = UDim2.new(1, -40, 0, 20)
    header.Position = UDim2.fromOffset(12, 7)
    header.BackgroundTransparency = 1
    header.Font = Enum.Font.GothamBold
    header.TextSize = 10
    header.TextXAlignment = Enum.TextXAlignment.Left
    header.TextColor3 = Color3.fromRGB(148, 163, 184)
    header.Text = "SYT FAST ROULETTE • 0-36 VERIFIED"
    header.Parent = card

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.fromOffset(22, 22)
    closeBtn.Position = UDim2.new(1, -28, 0, 6)
    closeBtn.BackgroundColor3 = Color3.fromRGB(24, 31, 44)
    closeBtn.BorderSizePixel = 0
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 11
    closeBtn.TextColor3 = Color3.fromRGB(226, 232, 240)
    closeBtn.Text = "X"
    closeBtn.Parent = card
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)
    closeBtn.MouseButton1Click:Connect(function()
        if sg and sg.Parent then sg:Destroy() end
    end)

    local circle = Instance.new("Frame")
    circle.Size = UDim2.fromOffset(58, 58)
    circle.Position = UDim2.fromOffset(12, 32)
    circle.BackgroundColor3 = badgeCol
    circle.BorderSizePixel = 0
    circle.Parent = card
    Instance.new("UICorner", circle).CornerRadius = UDim.new(1, 0)
    local cStroke = Instance.new("UIStroke", circle)
    cStroke.Color = Color3.new(1, 1, 1)
    cStroke.Transparency = 0.65

    local numLbl = Instance.new("TextLabel")
    numLbl.Size = UDim2.fromScale(1, 1)
    numLbl.BackgroundTransparency = 1
    numLbl.Font = Enum.Font.GothamBlack
    numLbl.TextSize = 26
    numLbl.TextColor3 = Color3.new(1, 1, 1)
    numLbl.Text = tostring(num)
    numLbl.Parent = circle

    local colorWord = isGreen and "GREEN ZERO" or (isRed and "RED" or "BLACK")
    local parity    = (num == 0) and "ZERO" or ((num % 2 == 0) and "EVEN" or "ODD")
    local halfBand  = (num == 0) and "0" or ((num <= 18) and "1-18" or "19-36")

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, -88, 0, 22)
    titleLbl.Position = UDim2.fromOffset(80, 32)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Font = Enum.Font.GothamBold
    titleLbl.TextSize = 14
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.TextColor3 = Color3.fromRGB(248, 250, 252)
    titleLbl.Text = string.format("%s | %s (%s)", colorWord, parity, halfBand)
    titleLbl.Parent = card

    local metaLbl = Instance.new("TextLabel")
    metaLbl.Size = UDim2.new(1, -88, 0, 18)
    metaLbl.Position = UDim2.fromOffset(80, 54)
    metaLbl.BackgroundTransparency = 1
    metaLbl.Font = Enum.Font.Code
    metaLbl.TextSize = 11
    metaLbl.TextXAlignment = Enum.TextXAlignment.Left
    metaLbl.TextTruncate = Enum.TextTruncate.AtEnd
    metaLbl.TextColor3 = Color3.fromRGB(148, 163, 184)
    metaLbl.Text = string.format("Roller: %s @ (%d, %d)", tostring(rollerName ~= "" and rollerName or "Player"), toInt(tx, 0), toInt(ty, 0))
    metaLbl.Parent = card

    local histBar = Instance.new("Frame")
    histBar.Size = UDim2.new(1, -88, 0, 20)
    histBar.Position = UDim2.fromOffset(80, 76)
    histBar.BackgroundTransparency = 1
    histBar.Parent = card
    local hl = Instance.new("UIListLayout", histBar)
    hl.FillDirection = Enum.FillDirection.Horizontal
    hl.Padding = UDim.new(0, 4)

    for _, hNum in ipairs(Misc.State.rouletteHistory) do
        local chip = Instance.new("TextLabel")
        chip.Size = UDim2.fromOffset(26, 20)
        chip.BackgroundColor3 = (hNum == 0) and Color3.fromRGB(16, 185, 129) or (ROULETTE_RED[hNum] and Color3.fromRGB(220, 38, 38) or Color3.fromRGB(30, 41, 59))
        chip.Font = Enum.Font.GothamBold
        chip.TextSize = 10
        chip.TextColor3 = Color3.new(1, 1, 1)
        chip.Text = tostring(hNum)
        chip.Parent = histBar
        Instance.new("UICorner", chip).CornerRadius = UDim.new(0, 5)
    end

    card.Position = UDim2.new(0.5, 0, 0, -40)
    pcall(function()
        TweenService:Create(card, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Position = UDim2.new(0.5, 0, 0, 14)
        }):Play()
    end)

    rouletteHideToken += 1
    local myTok = rouletteHideToken
    task.delay(6.5, function()
        if rouletteHideToken == myTok and sg and sg.Parent then
            sg:Destroy()
        end
    end)
end

local lastWheelKey, lastWheelAt = nil, 0
local function handleWheelSpin(px, py, n, name, userId)
    if not Misc.State.fastRoulette then return end
    local validNum = sanitizeRouletteNumber(n)
    local key = tostring(px) .. ":" .. tostring(py) .. ":" .. tostring(n) .. ":" .. tostring(userId)
    local now = os.clock()
    if key == lastWheelKey and (now - lastWheelAt) < 1.0 then return end
    lastWheelKey, lastWheelAt = key, now

    Misc.State.lastWheelSpin = { x = px, y = py, n = n, name = name, userId = userId }
    local spins = H.wheelSpins or Core.DiscoverWheelSpins()
    local gt = H.gt
    if type(spins) == "table" and gt and gt.w then
        local idx = toInt(py, 0) * gt.w + toInt(px, 0)
        if type(spins[idx]) == "table" then
            spins[idx].ends = now - 0.05
        end
    end
    for _, dly in ipairs({ 0, 0.02, 0.07 }) do
        task.delay(dly, function()
            local sp = H.wheelSpins or Core.DiscoverWheelSpins()
            local g = H.gt
            if type(sp) == "table" and g and g.w then
                local idx = toInt(py, 0) * g.w + toInt(px, 0)
                if type(sp[idx]) == "table" then
                    sp[idx].ends = os.clock() - 0.05
                end
            end
        end)
    end

    local roller = stripColorTags(tostring(name or ""))
    if validNum ~= nil then
        local msg = string.format("%s -> %d (%d, %d)", roller, validNum, toInt(px, 0), toInt(py, 0))
        task.defer(function()
            if UI then pcall(function() UI:SetValue("RouletteResultDisplay", msg) end) end
            pcall(showRoulettePopup, roller, validNum, toInt(px, 0), toInt(py, 0))
            emitNotify("Fast Roulette [0-36]", msg)
        end)
    else
        task.defer(function()
            if UI then pcall(function() UI:SetValue("RouletteResultDisplay", string.format("Anomali >2 digit diblokir (%s)", tostring(n))) end) end
        end)
    end
end

function Core.SkipWheelAnimations()
    if not Misc.State.fastRoulette then return end
    local spins = H.wheelSpins or Core.DiscoverWheelSpins()
    if type(spins) ~= "table" then return end
    local now = os.clock()
    for _, entry in pairs(spins) do
        if type(entry) == "table" and entry.n ~= nil then
            if (entry.ends or 0) > now then
                entry.ends = now - 0.05
            end
            handleWheelSpin(entry.x, entry.y, entry.n, entry.name, entry.userId)
        end
    end
end

function Core.EnsureWheelHook()
    if H.wheelSpins == nil then Core.DiscoverWheelSpins() end
    -- Jalur 1: ByteNet packet wheelSpun (jalur utama Net.on("WheelSpun") di Game.lua)
    if not H.wheelByteNetHooked and H.Net and H.Net.wheelSpun and type(H.Net.wheelSpun.listen) == "function" then
        local okL = pcall(function()
            H.Net.wheelSpun.listen(function(pkt)
                if type(pkt) ~= "table" then return end
                if pkt.w ~= nil and H.Net and type(H.Net.worldTag) == "function" and H.gt and H.gt.name ~= "" then
                    if pkt.w ~= H.Net.worldTag(H.gt.name) then return end
                end
                handleWheelSpin(pkt.x, pkt.y, pkt.n, pkt.name, pkt.userId)
            end)
        end)
        if okL then H.wheelByteNetHooked = true end
    end
    -- Jalur 2: Opsional RemoteEvent WorldRemotes.WheelSpun jika tersedia di world
    if not H.wheelRemoteHooked then
        local wr = ReplicatedStorage:FindFirstChild("WorldRemotes")
        local rem = wr and wr:FindFirstChild("WheelSpun")
        if rem and rem:IsA("RemoteEvent") then
            H.wheelRemoteHooked = true
            rem.OnClientEvent:Connect(function(a, b, c, d, e)
                if type(a) == "table" then
                    handleWheelSpin(a.x, a.y, a.n, a.name, a.userId)
                else
                    handleWheelSpin(a, b, c, d, e)
                end
            end)
        end
    end
end

function Misc.SetFastRoulette(enabled)
    Core.EnsureInit()
    Misc.State.fastRoulette = enabled == true
    if H.rouletteSkipConn then H.rouletteSkipConn:Disconnect(); H.rouletteSkipConn = nil end
    if Misc.State.fastRoulette then
        Core.DiscoverWheelSpins(true)
        Core.EnsureWheelHook()
        Core.SkipWheelAnimations()
        H.rouletteSkipConn = RunService.Heartbeat:Connect(function()
            if getEnv().__SYT_SCRIPT_TOKEN ~= MY_SCRIPT_TOKEN then
                if H.rouletteSkipConn then H.rouletteSkipConn:Disconnect(); H.rouletteSkipConn = nil end
                return
            end
            if not Misc.State.fastRoulette then return end
            if not H.wheelByteNetHooked then Core.EnsureWheelHook() end
            Core.SkipWheelAnimations()
        end)
        getEnv().__SYT_ROULETTE_CONN = H.rouletteSkipConn
    end
    return Misc.State.fastRoulette
end

function Misc.SetNoClip(enabled)
    Core.EnsureInit()
    Core.EnsureMoveHook()
    local gt = H.gt
    if not gt then return false end
    local on = enabled == true
    if on == Misc.State.noClip then return on end
    Misc.State.noClip = on
    if on then
        local pos = Core.ReadPos()
        Misc.State.noClipAnchor = { x = pos.x, y = pos.y, tx = pos.tx, ty = pos.ty }
        gt.ghost = true
        gt.stuckAt = nil
        if type(SYT_Logic.InstallNetGuard) == "function" then pcall(SYT_Logic.InstallNetGuard) end
    else
        Misc.State.noClipAnchor = nil
        gt.ghost = (Misc.State.fly == true)
        if not snapOutOfSolidAtCurrentPos(gt) then
            local pos = Core.ReadPos()
            Core.SetLocalCoords(pos.x, pos.y, 0, 0)
            Packets.SendRawMove(pos.x, pos.y, 0, 0, computeMoveFlags(pos.x, pos.y, 0, 0, 1))
        end
    end
    return Misc.State.noClip
end

local function hookIncomingNetGuard()
    H.netGodHooked = true
    H.antiBackWrappedConns = H.antiBackWrappedConns or {}
    local targetEvents = {
        knocked = true, impulse = true, forcedie = true, burned = true, useonplayerfx = true, hurt = true,
    }
    -- Hook tabel handler internal Net DAN gt.on (ForceDie / Burned / Knocked / Impulse / MoveTo rollback BasePath)
    local probeFns = {}
    if H.Net then
        if type(H.Net.on) == "function" then probeFns[#probeFns + 1] = H.Net.on end
        for _, ch in pairs(H.Net) do
            if type(ch) == "table" and type(rawget(ch, "listen")) == "function" then
                probeFns[#probeFns + 1] = rawget(ch, "listen")
            end
        end
    end
    if H.gt and type(rawget(H.gt, "on")) == "function" then
        probeFns[#probeFns + 1] = rawget(H.gt, "on")
    end

    local function shouldDropMoveTo(arg1, arg2)
        if os.clock() < (H.allowNextMoveToUntil or 0) then return false end
        local x, y = arg1, arg2
        if type(arg1) == "table" then
            x = arg1.x or arg1.X or arg1[1]
            y = arg1.y or arg1.Y or arg1[2]
        end
        local godOn = Misc.State.godMode == true
        local flyGuard = Misc.State.fly == true and Misc.State.flyAntiBasePath ~= false
        local skipperGuard = GetcSkipper.State.enabled == true and GetcSkipper.State.noValidateBack == true
        if not (godOn or flyGuard or skipperGuard) then return false end
        if x == nil or y == nil then return true end
        local p = Core.ReadPos()
        local distPull = math.abs(x - p.x) + math.abs(y - p.y)
        local sp = H.gt and H.gt.spawn
        local toSpawn = sp and sp.X and sp.Y and (math.abs(x - sp.X) <= 2.2 and math.abs(y - sp.Y) <= 2.2) and ((math.abs(p.x - sp.X) + math.abs(p.y - sp.Y)) > 3)
        -- Saat Fly Anti-BasePath aktif, tolak semua MoveTo rollback tanpa mengirim paket balikan yang mengganggu SteppedAnchor
        if flyGuard then
            H.blockedMoveToCount = (H.blockedMoveToCount or 0) + 1
            H.lastBlockedMoveToAt = os.clock()
            return true
        end
        if skipperGuard and (H.autoMove ~= nil or toSpawn or (os.clock() - (H.lastTileAt or 0)) < 1.8) and distPull > 2.0 then
            Packets.SendRawMove(p.x, p.y, 0, 0, 2)
            return true
        end
        if godOn and toSpawn then
            return true
        end
        return false
    end

    local function wrapNetHandler(isDmgEv, isMoveEv, origFn)
        if type(origFn) ~= "function" or H.antiBackWrappedConns[origFn] then return origFn end
        local w = function(...)
            if isDmgEv and Misc.State.godMode then return end
            if isMoveEv and shouldDropMoveTo(...) then return end
            return origFn(...)
        end
        H.antiBackWrappedConns[origFn] = w
        H.antiBackWrappedConns[w] = w
        return w
    end

    for _, fn in ipairs(probeFns) do
        local uvs = guvs(fn)
        if type(uvs) == "table" then
            for _, u in pairs(uvs) do
                if type(u) == "table" then
                    for k, handler in pairs(u) do
                        local kl = string.lower(tostring(k))
                        local isDmgEv = targetEvents[kl]
                        local isMoveEv = (kl == "moveto")
                        if isDmgEv or isMoveEv then
                            if type(handler) == "function" then
                                u[k] = wrapNetHandler(isDmgEv, isMoveEv, handler)
                            elseif type(handler) == "table" then
                                for i, cb in pairs(handler) do
                                    if type(cb) == "function" then
                                        handler[i] = wrapNetHandler(isDmgEv, isMoveEv, cb)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end
SYT_Logic.InstallNetGuard = hookIncomingNetGuard

function Misc.SetGodMode(enabled)
    Core.EnsureInit()
    local net, gt = H.Net, H.gt
    Misc.State.godMode = enabled == true
    if H.godConn then H.godConn:Disconnect(); H.godConn = nil end

    if net and net.died then
        H.origDiedSend = H.origDiedSend or net.died.send
        net.died.send = Misc.State.godMode and (function() return nil end) or H.origDiedSend
    end
    if net and net.hurt and type(net.hurt.send) == "function" then
        H.origHurtSend = H.origHurtSend or net.hurt.send
        net.hurt.send = Misc.State.godMode and (function() return nil end) or H.origHurtSend
    end

    if H.stateObj then
        if type(H.stateObj.onHurt) == "function" then
            H.origOnHurt = H.origOnHurt or H.stateObj.onHurt
            H.stateObj.onHurt = Misc.State.godMode and (function() end) or H.origOnHurt
        end
        if type(H.stateObj.onDie) == "function" then
            H.origOnDie = H.origOnDie or H.stateObj.onDie
            H.stateObj.onDie = Misc.State.godMode and (function() end) or H.origOnDie
        end
    end

    if gt then
        pcall(inspectUpvalues, gt)
        if type(rawget(gt, "respawn")) == "function" then
            H.origGtRespawn = H.origGtRespawn or gt.respawn
            gt.respawn = Misc.State.godMode and (function() return nil end) or H.origGtRespawn
        end
        if type(rawget(gt, "touchBlocks")) == "function" then
            H.origTBHurt = H.origTBHurt or uv(gt.touchBlocks, 1)
            H.origTBDie  = H.origTBDie  or uv(gt.touchBlocks, 2)
            if Misc.State.godMode then
                suv(gt.touchBlocks, 1, function() return false, false end)
                suv(gt.touchBlocks, 2, function() return nil end)
            else
                if H.origTBHurt then suv(gt.touchBlocks, 1, H.origTBHurt) end
                if H.origTBDie then suv(gt.touchBlocks, 2, H.origTBDie) end
            end
        end
    end

    -- Pasang proteksi 3-Layer Anti-Back & Hazard Guard (goTo + WorldRemotes + ByteNet listeners)
    pcall(Core.InstallAntiBackGuard)
    pcall(hookIncomingNetGuard)

    -- Hook touchingHurt, die & respawn di RenderStepped: HP tidak berkurang, tidak mati, tidak respawn
    if H.renderFn then
        if H.touchHurtIdx and H.origTouchHurt then
            suv(H.renderFn, H.touchHurtIdx, Misc.State.godMode and (function() return false, false end) or H.origTouchHurt)
        end
        if H.dieIdx and H.origDieFn then
            suv(H.renderFn, H.dieIdx, Misc.State.godMode and (function() return nil end) or H.origDieFn)
        end
        if H.respawnIdx and H.origRespawnFn then
            suv(H.renderFn, H.respawnIdx, Misc.State.godMode and (function() return nil end) or H.origRespawnFn)
        end
    end

    -- Blokir partikel serangan / burn swirl / yolk di sekitar player saat God Mode aktif
    if H.particles then
        if type(H.particles.swirl) == "function" then
            H.origSwirlFn = H.origSwirlFn or H.particles.swirl
            H.particles.swirl = function(self, px, py, ...)
                if Misc.State.godMode then
                    local p = Core.ReadPos()
                    if not px or not py or (math.abs(px - p.x) <= 2.8 and math.abs(py - p.y) <= 2.8) then
                        return
                    end
                end
                return H.origSwirlFn(self, px, py, ...)
            end
        end
        if type(H.particles.yolk) == "function" then
            H.origYolkFn = H.origYolkFn or H.particles.yolk
            H.particles.yolk = function(self, px, py, ...)
                if Misc.State.godMode then
                    local p = Core.ReadPos()
                    if not px or not py or (math.abs(px - p.x) <= 2.8 and math.abs(py - p.y) <= 2.8) then
                        return
                    end
                end
                return H.origYolkFn(self, px, py, ...)
            end
        end
    end

    if Misc.State.godMode then
        H.godConn = RunService.RenderStepped:Connect(function()
            if not Misc.State.godMode then return end
            if H.renderFn then
                if H.deadIdx then suv(H.renderFn, H.deadIdx, false) end
                if H.hpIdx then suv(H.renderFn, H.hpIdx, 5) end
                if H.lastHurtAtIdx then suv(H.renderFn, H.lastHurtAtIdx, os.clock() + 5) end
            end
            if gt then
                if gt.deadSince then gt.deadSince = nil end
                if gt.dying then gt.dying = nil end
                if gt.hurtAt then gt.hurtAt = nil end
                if gt.stuckAt then gt.stuckAt = nil end
                if not Misc.State.fly and not Misc.State.noClip and not H.touchHurtIdx then
                    local p = Core.ReadPos()
                    local f1, f2 = Core.GetItemInfo(Core.GetFG(p.tx, p.ty)), Core.GetItemInfo(Core.GetFG(p.tx, p.ty + 1))
                    gt.ghost = ((f1 and (f1.deadly or f1.hurts)) or (f2 and (f2.deadly or f2.hurts))) == true
                end
            end
        end)
    elseif gt and not Misc.State.fly and not Misc.State.noClip then
        gt.ghost = false
    end
    return Misc.State.godMode
end

if type(SYT_Logic.InstallNetGuard) == "function" and SYT_Logic.InstallNetGuard ~= Core.InstallAntiBackGuard then
    SYT_Logic._origInstallNetGuard = SYT_Logic.InstallNetGuard
end
SYT_Logic.InstallNetGuard = Core.InstallAntiBackGuard

-- Auto Follow Player (Scrollable Dropdown via Walk)
local function extractFollowName(raw)
    local s = (tostring(raw or "")):match("^%s*(.-)%s*$")
    if s == "" or s == "Tidak ada player lain" then return "" end
    local bare = string.match(s, "^([^%(%[]+)")
    return (bare or s):match("^%s*(.-)%s*$")
end

function Misc.GetFollowCandidates()
    Core.EnsureInit()
    local out = {}
    for _, op in ipairs(Core.GetInWorldPlayers(false)) do
        local label = op.gameName
        if op.isStaff then label = label .. " [MOD]" end
        out[#out + 1] = label
    end
    table.sort(out)
    if #out == 0 then out[1] = "Tidak ada player lain" end
    return out
end

function Misc.SetFollowTarget(nameOrLabel)
    local nm = extractFollowName(nameOrLabel)
    Misc.State.followTarget = nm
    return nm
end

function Misc.SetAutoFollow(enabled, targetName)
    Core.EnsureInit()
    if type(targetName) == "string" and targetName ~= "" then
        Misc.SetFollowTarget(targetName)
    end
    Misc.State.autoFollow = enabled == true
    Misc.State.followToken += 1
    local tok = Misc.State.followToken

    if not Misc.State.autoFollow then
        Misc.State.followStatus = "Idle"
        if UI then UI:SetValue("FollowStatusDisplay", "Idle") end
        return false
    end

    if Misc.State.followTarget == "" then
        local cands = Misc.GetFollowCandidates()
        Misc.SetFollowTarget(cands[1])
    end

    Misc.State.followThread = task.spawn(function()
        local function alive() return Misc.State.autoFollow and Misc.State.followToken == tok end
        while alive() do
            if evaluateSeems() then break end
            local gt = H.gt
            if not gt or (gt.name or "") == "" then
                Misc.State.followStatus = "Belum masuk world..."
                if UI then UI:SetValue("FollowStatusDisplay", Misc.State.followStatus) end
                task.wait(0.35)
            elseif Misc.State.followTarget == "" then
                Misc.State.followStatus = "Pilih target player dulu"
                if UI then UI:SetValue("FollowStatusDisplay", Misc.State.followStatus) end
                task.wait(0.4)
            else
                local found = nil
                local want = string.lower(Misc.State.followTarget)
                for _, op in ipairs(Core.GetInWorldPlayers(false)) do
                    local gn = string.lower(op.gameName or "")
                    local rn = string.lower(op.rbxName or "")
                    if gn == want or rn == want or string.find(gn, want, 1, true) then
                        found = op
                        break
                    end
                end
                if not found or not found.tx or not found.ty then
                    Misc.State.followStatus = "Mencari " .. Misc.State.followTarget .. " di world..."
                    if UI then UI:SetValue("FollowStatusDisplay", Misc.State.followStatus) end
                    task.wait(0.35)
                else
                    local cur = Core.ReadPos()
                    local dist = math.abs(found.tx - cur.tx) + math.abs(found.ty - cur.ty)
                    if dist <= 1 then
                        Misc.State.followStatus = string.format("Dekat %s (%d,%d)", found.gameName, found.tx, found.ty)
                        if UI then UI:SetValue("FollowStatusDisplay", Misc.State.followStatus) end
                        task.wait(0.18)
                    else
                        local goalX, goalY = found.tx, found.ty
                        local candidates = {
                            { x = found.tx - 1, y = found.ty },
                            { x = found.tx + 1, y = found.ty },
                            { x = found.tx,     y = found.ty },
                        }
                        for _, cTile in ipairs(candidates) do
                            if cTile.x >= 0 and cTile.x < gt.w and cTile.y >= 0 and cTile.y < gt.h and not Core.IsSolid(cTile.x, cTile.y) then
                                goalX, goalY = cTile.x, cTile.y
                                break
                            end
                        end
                        local path = Packets.FindTilePath(cur.tx, cur.ty, goalX, goalY)
                        if path and #path > 1 then
                            Misc.State.followStatus = string.format("Walk ke %s (jarak %d)", found.gameName, dist)
                            if UI then UI:SetValue("FollowStatusDisplay", Misc.State.followStatus) end
                            local maxHops = math.min(#path, 5)
                            local speed = 13.5
                            local prevX, prevY = cur.tx, cur.ty
                            for i = 2, maxHops do
                                if not alive() or evaluateSeems() then break end
                                local nd = path[i]
                                local vx, vy = (nd.x - prevX) * speed, (nd.y - prevY) * speed
                                local px, py = nd.x + 0.5, nd.y + 1
                                Core.SetLocalCoords(px, py, vx, vy)
                                Packets.SendRawMove(px, py, vx, vy, 2)
                                prevX, prevY = nd.x, nd.y
                                task.wait(0.075)
                            end
                        else
                            Misc.State.followStatus = string.format("Jalur ke %s terhalang (%d,%d)", found.gameName, found.tx, found.ty)
                            if UI then UI:SetValue("FollowStatusDisplay", Misc.State.followStatus) end
                            task.wait(0.3)
                        end
                    end
                end
            end
        end
    end)
    return true
end

function Misc.SetCollectState(enabled)
    Core.EnsureInit()
    Misc.State.collectState = enabled == true
    local gt = H.gt
    if gt and type(gt.takeDrop) == "function" and not H.takeDropHooked then
        H.takeDropHooked = true
        H.origTakeDrop = H.origTakeDrop or gt.takeDrop
        gt.takeDrop = function(uid, want)
            local matchedId, matchedN = nil, 0
            if type(gt.dropList) == "function" then
                local ok, drops = pcall(gt.dropList)
                if ok and type(drops) == "table" then
                    for _, d in ipairs(drops) do
                        if type(d) == "table" and d.uid == uid then
                            matchedId = d.id
                            matchedN = d.n or 0
                            break
                        end
                    end
                end
            end
            local got = H.origTakeDrop(uid, want)
            if type(got) == "number" and got > 0 then
                if Misc.State.autoCleanDrops or Misc.State.collectState then
                    local rem = math.max(0, matchedN - got)
                    Core.ClearStuckDropVisuals(uid, rem)
                end
                if Misc.State.collectState and matchedId == 112 then
                    local now = os.clock()
                    Misc.State.comboGems = ((now - Misc.State.lastGemAt) <= 2.5) and (Misc.State.comboGems + got) or got
                    Misc.State.lastGemAt = now
                    Misc.State.sessionGems += got
                    local txt = string.format("Get %d Gems (Session: %d)", Misc.State.comboGems, Misc.State.sessionGems)
                    UI:SetValue("CollectGemsDisplay", txt)
                    emitNotify("Collect State", txt)
                end
            end
            return got
        end
    end
    return Misc.State.collectState
end

function Misc.SetAutoCollect(enabled, radius, stepEnabled)
    Core.EnsureInit()
    local S = Misc.State
    if type(radius) == "number" then
        S.autoCollectRadius = clamp(toInt(radius, 5), 1, 6)
    end
    if stepEnabled ~= nil then
        S.autoCollectStep = stepEnabled == true
    end
    local wantOn = enabled == true
    S.autoCollect = wantOn

    if S.autoCollectThread then
        pcall(task.cancel, S.autoCollectThread)
        S.autoCollectThread = nil
    end
    S.autoCollectToken += 1
    if not wantOn then return false end

    local tok = S.autoCollectToken
    S.autoCollectThread = task.spawn(function()
        while S.autoCollect and S.autoCollectToken == tok do
            if not Misc.State.seemsPaused and not Misc.State.noClip and H.gt and H.gt.name ~= "" then
                local pnbRun = SYT_Logic.PNB and SYT_Logic.PNB.State.running
                local pabRun = SYT_Logic.Pabrik and SYT_Logic.Pabrik.State.running
                local stepAllowed = S.autoCollectStep and not pnbRun and not pabRun
                Packets.Collect({
                    radius = S.autoCollectRadius,
                    stepMoveIfFar = stepAllowed,
                    collectDelay = 0,
                    shouldContinue = function()
                        return S.autoCollect and S.autoCollectToken == tok
                    end,
                })
                if S.autoCleanDrops then
                    Core.ClearStuckDropVisuals()
                end
            end
            task.wait(0.08)
        end
    end)
    return true
end

-- V2 [PNB]
local PNB = {
    State = {
        running = false, sessionToken = 0, thread = nil,
        status = "Idle", phase = "Idle", verifySummary = "-", cycles = 0,
        selectedBlockId = nil, grid5x5 = { ["0,-1"] = true },
        oneHit = false, showHand = true, speed = 2,
        breakThreads = 5, autoCollect = true, lockCenterPos = false, centerPos = nil,
    }
}
SYT_Logic.PNB = PNB

local function setPNBStatus(msg, phaseText, verifyText)
    PNB.State.status = msg
    if phaseText ~= nil then PNB.State.phase = phaseText end
    if verifyText ~= nil then PNB.State.verifySummary = verifyText end
    if UI then
        UI:SetValue("PnbStatusDisplay", msg)
        if phaseText ~= nil then UI:SetValue("PnbPhaseDisplay", tostring(phaseText)) end
        if verifyText ~= nil then UI:SetValue("PnbVerifyDisplay", tostring(verifyText)) end
    end
    if UIHooks.updateButtons then UIHooks.updateButtons() end
end

local function pnbTimingsForSpeed(speedRatio)
    local spd = clamp(tonumber(speedRatio) or 2, 1, 10)
    local actGap = clamp(0.22 / spd, 0.015, 0.22)
    local verifyWait = clamp(0.32 / (0.65 + spd * 0.35), 0.09, 0.32)
    local cycleWait = clamp(0.06 / spd, 0.005, 0.06)
    return spd, actGap, verifyWait, cycleWait
end

local function inspectPnbTargets(targets, bid, layer)
    local foreign, placed, empty = {}, {}, {}
    local minX, maxX, minY, maxY = 1e9, -1e9, 1e9, -1e9
    for _, t in ipairs(targets) do
        minX, maxX = math.min(minX, t.tx), math.max(maxX, t.tx)
        minY, maxY = math.min(minY, t.ty), math.max(maxY, t.ty)
        local curId = Core.GetLayerTile(t.tx, t.ty, layer)
        if curId == 0 then
            empty[#empty + 1] = t
        elseif curId == bid then
            placed[#placed + 1] = t
        else
            foreign[#foreign + 1] = { tx = t.tx, ty = t.ty, layer = layer, id = curId }
        end
    end
    local seedDrops, blockDrops, gemDrops, totalDrops = 0, 0, 0, 0
    local gt = H.gt
    if gt and type(gt.dropList) == "function" and #targets > 0 then
        local ok, drops = pcall(gt.dropList)
        if ok and type(drops) == "table" then
            local pad = 2.2
            for _, d in ipairs(drops) do
                if type(d) == "table" and (d.n or 0) > 0 and d.x and d.y
                    and d.x >= minX - pad and d.x <= maxX + 1 + pad
                    and (d.y - 0.5) >= minY - pad and (d.y - 0.5) <= maxY + 1 + pad
                    and (d.id == 112 or Core.GetItemRoom(d.id) > 0) then
                    totalDrops += 1
                    if d.id == 112 then
                        gemDrops += 1
                    else
                        local di = Core.GetItemInfo(d.id)
                        if di and di.kind == "seed" then
                            seedDrops += 1
                        else
                            blockDrops += 1
                        end
                    end
                end
            end
        end
    end
    return {
        foreign = foreign,
        placed = placed,
        empty = empty,
        totalDrops = totalDrops,
        seedDrops = seedDrops,
        blockDrops = blockDrops,
        gemDrops = gemDrops,
    }
end

function PNB.GetBackpackBlocks(includeSeeds)
    Core.EnsureInit()
    local byId = {}
    for _, slot in ipairs(Core.GetBackpackSlots()) do
        local info = Core.GetItemInfo(slot.id)
        local isSeed = (info and (info.kind == "seed" or info.seed ~= nil)) or false
        local kind = isSeed and "seed" or ((info and info.kind) or "block")
        local isWearOrTool = (slot.id == 18 or slot.id == 32 or slot.id == 112 or kind == "cloth" or kind == "tool" or (info and (info.cloth or info.tool)))
        if not isWearOrTool then
            if includeSeeds or not isSeed then
                if byId[slot.id] then
                    byId[slot.id].count += (slot.n or 0)
                else
                    byId[slot.id] = {
                        id = slot.id,
                        name = (info and info.name) or Core.GetItemName(slot.id),
                        count = slot.n or 0,
                        kind = kind,
                        layer = (info and info.background) and 2 or 1,
                        hits = (info and info.hits) or 3,
                    }
                end
            end
        end
    end
    local list = {}
    for _, entry in pairs(byId) do list[#list + 1] = entry end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

function PNB.ToggleTile5x5(dx, dy)
    dx, dy = toInt(dx), toInt(dy)
    if not dx or not dy or dx < -2 or dx > 2 or dy < -2 or dy > 2 then return false end
    if dx == 0 and dy == 0 then return false end
    local k = tileKey(dx, dy)
    local nextV = not (PNB.State.grid5x5[k] == true)
    PNB.State.grid5x5[k] = nextV or nil
    if UIHooks.refreshPad5x5 then UIHooks.refreshPad5x5() end
    return nextV
end

function PNB.GetActiveOffsets()
    local res = {}
    for dy = -2, 2 do
        for dx = -2, 2 do
            if PNB.State.grid5x5[tileKey(dx, dy)] then
                res[#res + 1] = { dx = dx, dy = dy }
            end
        end
    end
    return res
end

function PNB.Stop()
    PNB.State.running = false
    PNB.State.sessionToken += 1
    if PNB.State.thread then
        pcall(task.cancel, PNB.State.thread)
        PNB.State.thread = nil
    end
    setPNBStatus("Stopped", "Idle", "Cycle: " .. tostring(PNB.State.cycles or 0))
    return false
end

function PNB.Start()
    Core.EnsureInit()
    local S = PNB.State
    if S.running then return true end
    if not S.selectedBlockId then setPNBStatus("Pilih block dari Backpack dulu", "Waiting Block", "-"); return false end
    if #PNB.GetActiveOffsets() == 0 then setPNBStatus("Pilih minimal 1 tile di Pad 5x5", "Waiting Pad", "-"); return false end

    S.running = true
    S.cycles = 0
    S.sessionToken += 1
    local token = S.sessionToken
    local pos0 = Core.ReadPos()
    S.centerPos = { tx = pos0.tx, ty = pos0.ty }
    local function alive() return S.running and S.sessionToken == token end
    setPNBStatus("Running...", "Inspecting Tiles", "-")

    S.thread = task.spawn(function()
        while alive() do
            if evaluateSeems() then break end
            local gt = H.gt
            if not gt or gt.name == "" then setPNBStatus("Keluar dari world", "Idle", "-"); break end

            local bid   = S.selectedBlockId
            local info  = Core.GetItemInfo(bid)
            local layer = (info and info.background) and 2 or 1
            local centerP = (S.lockCenterPos and S.centerPos) or Core.ReadPos()
            local cx, cy  = centerP.tx, centerP.ty

            local targets = {}
            for _, off in ipairs(PNB.GetActiveOffsets()) do
                local tx, ty = cx + off.dx, cy + off.dy
                if tx >= 0 and tx < gt.w and ty >= 0 and ty < gt.h and Core.CanEditTile(tx, ty) then
                    if not (info and info.solid and layer == 1 and tx == cx and ty == cy) then
                        targets[#targets + 1] = { tx = tx, ty = ty, layer = layer }
                    end
                end
            end
            if #targets == 0 then
                setPNBStatus("Tidak ada tile valid di Pad 5x5", "Idle", "-")
                break
            end

            local spd, actGap, verifyWait, cycleWait = pnbTimingsForSpeed(S.speed)
            local placeGap = math.max(H.adaptivePlaceGap or 0.155, clamp(0.28 / spd, 0.145, 0.28))
            local nThreads = clamp(toInt(S.breakThreads, 5), 1, 9)
            if S.oneHit then
                Core.EnsureBestDigEquipped()
            end

            local breakOpts = {
                layer = layer, threads = nThreads, oneHit = S.oneHit,
                noLocalMirror = false, hitDelay = math.max(0.08, actGap), verifyTimeout = verifyWait,
                stable = clamp(0.05 / math.max(1, spd * 0.4), 0.015, 0.05),
                showHand = S.showHand, showVisual = true, shouldContinue = alive,
            }
            local function runCollectPhase(expectDrops)
                if not (alive() and S.autoCollect) then return true end
                local snapBefore = inspectPnbTargets(targets, bid, layer)
                setPNBStatus(
                    string.format("Fase 3: Collect (Seed:%d Blk:%d Gem:%d) [%.0fx]", snapBefore.seedDrops, snapBefore.blockDrops, snapBefore.gemDrops, spd),
                    "Fase 3: Collect",
                    string.format("Drops tersisa: %d (S:%d B:%d G:%d)", snapBefore.totalDrops, snapBefore.seedDrops, snapBefore.blockDrops, snapBefore.gemDrops)
                )
                local colOk = Packets.CollectVerified(targets, {
                    expectDrops = expectDrops, waitDrop = clamp(0.16 / spd, 0.03, 0.16),
                    collectDelay = 0, shouldContinue = alive,
                })
                local snapAfter = inspectPnbTargets(targets, bid, layer)
                setPNBStatus(
                    colOk and "Collect Verified OK" or "Collect retry (masih ada drop)",
                    "Fase 3: Collect",
                    string.format("Drops -> %d -> %d", snapBefore.totalDrops, snapAfter.totalDrops)
                )
                return colOk and snapAfter.totalDrops == 0
            end

            -- INSPEKSI AWAL: Deteksi kondisi nyata tile terpilih (foreign, placed block, empty, atau dropped seeds/blocks/gems)
            local snap = inspectPnbTargets(targets, bid, layer)

            -- PRE-PHASE: Bersihkan blok/seed asing (non-target) di tile terpilih & verifikasi server
            if #snap.foreign > 0 then
                setPNBStatus(
                    string.format("Clear %d tile asing/seed (%d thread)...", #snap.foreign, math.min(nThreads, #snap.foreign)),
                    "Pre-Clean Tile",
                    string.format("Asing: %d/%d", #snap.foreign, #targets)
                )
                for _ = 1, 3 do
                    if not alive() then break end
                    local _, failed = Packets.BreakVerified(snap.foreign, breakOpts)
                    if failed == 0 then break end
                end
                runCollectPhase(true)
                snap = inspectPnbTargets(targets, bid, layer)
            end

            local itemCount = Core.CountItem(bid)
            local placedAny, brokeAny = false, false

            -- FASE 1: PLACE — isi seluruh tile terpilih & verifikasi visual == server sebelum lanjut Break
            if #snap.empty > 0 and itemCount > 0 then
                for round = 1, 3 do
                    if not alive() then break end
                    local curSnap = inspectPnbTargets(targets, bid, layer)
                    local needPlace = curSnap.empty
                    if #needPlace == 0 or Core.CountItem(bid) <= 0 then break end
                    setPNBStatus(
                        string.format("Fase 1: Place %d/%d (%dx Speed)", #needPlace, #targets, spd),
                        "Fase 1: Place",
                        string.format("Placed: %d/%d (Round %d)", #curSnap.placed, #targets, round)
                    )
                    Packets.EnsureActionReach(needPlace[1].tx, needPlace[1].ty, "build", alive)
                    if S.showHand ~= false and H.Net and H.Net.act and H.Net.act.send then
                        pcall(H.Net.act.send, { kind = (info and info.kind == "seed") and 3 or 2, x = needPlace[1].tx + 0.5, y = needPlace[1].ty + 0.5 })
                    end
                    Packets.RunPool(needPlace, math.min(nThreads, #needPlace), function(t)
                        local ok = Packets.PlaceVerified(t.tx, t.ty, bid, layer, {
                            showHand = false, delay = 0, noLocalMirror = false,
                            autoRange = false,
                            placeGap = math.max(0.168, tonumber(placeGap) or 0.168),
                            verifyTimeout = clamp(0.24 / (0.6 + spd * 0.4), 0.12, 0.24),
                            shouldContinue = alive,
                        })
                        if ok then placedAny = true end
                    end, alive)
                end
                snap = inspectPnbTargets(targets, bid, layer)
            end

            -- GATE FASE 1 -> FASE 2: pastikan visual & server tile sudah cocok
            local readyToBreak = (#snap.placed == #targets) or (#snap.placed > 0 and Core.CountItem(bid) <= 0)
            if not readyToBreak and #snap.empty > 0 and Core.CountItem(bid) > 0 then
                setPNBStatus(
                    string.format("Place Verify %d/%d belum cocok server, ulangi...", #snap.placed, #targets),
                    "Fase 1: Verify Ulang",
                    string.format("Visual=Server: %d/%d", #snap.placed, #targets)
                )
                task.wait(cycleWait)
            elseif #snap.placed > 0 then
                -- FASE 2: BREAK — hancurkan semua blok 1..N dan pastikan SEMUA terkonfirmasi pecah dari server
                local breakVerified = false
                for round = 1, 5 do
                    if not alive() then break end
                    local curSnap = inspectPnbTargets(targets, bid, layer)
                    local toBreak = curSnap.placed
                    if #toBreak == 0 then
                        breakVerified = true
                        break
                    end
                    brokeAny = true
                    setPNBStatus(
                        string.format("Fase 2: Break %d/%d (%dT | %s | %.0fx)", #toBreak, #targets, math.min(nThreads, #toBreak), S.oneHit and "1-Hit" or "Hit", spd),
                        "Fase 2: Break",
                        string.format("Broken: %d/%d | Sisa: %d", #targets - #toBreak, #targets, #toBreak)
                    )
                    Packets.BreakVerified(toBreak, breakOpts)
                    local afterSnap = inspectPnbTargets(targets, bid, layer)
                    if #afterSnap.placed == 0 then
                        breakVerified = true
                        break
                    end
                    setPNBStatus(
                        string.format("Verify Break: sisa %d/%d di server, pukul ulang...", #afterSnap.placed, #targets),
                        "Fase 2: Verify Break",
                        string.format("Server Broken: %d/%d", #targets - #afterSnap.placed, #targets)
                    )
                end

                -- GATE FASE 2 -> FASE 3: hanya lanjut collect jika seluruh tile target sudah benar-benar kosong di server
                if breakVerified then
                    local colDone = runCollectPhase(true)
                    if colDone then
                        S.cycles = (S.cycles or 0) + 1
                        setPNBStatus(
                            string.format("Siklus #%d Verified (%.0fx)", S.cycles, spd),
                            "Verified OK",
                            string.format("Tiles %d/%d OK | Cycle #%d", #targets, #targets, S.cycles)
                        )
                    else
                        setPNBStatus("Fase 3: Drop masih tersisa di tile target", "Fase 3: Retry Collect", "Drops belum bersih")
                    end
                end
            elseif snap.totalDrops > 0 then
                -- Tidak ada block terpasang namun masih ada seed/block/gems drop di tile target -> bersihkan Fase 3 dulu
                runCollectPhase(false)
            elseif Core.CountItem(bid) <= 0 and #snap.placed == 0 then
                setPNBStatus("Selesai: Block habis di backpack", "Selesai", string.format("Cycle selesai: %d", S.cycles or 0))
                break
            end

            if not alive() then break end
            task.wait(cycleWait)
        end
        if S.sessionToken == token then
            S.running = false
            S.thread = nil
            if S.phase ~= "Selesai" and S.phase ~= "Idle" then
                S.phase = "Stopped"
            end
            if UI then UI:SetValue("PnbPhaseDisplay", S.phase) end
            if UIHooks.refreshBP then UIHooks.refreshBP() end
            if UIHooks.updateButtons then UIHooks.updateButtons() end
        end
    end)
    return true
end

function PNB.Toggle()
    if PNB.State.running then
        return PNB.Stop()
    else
        return PNB.Start()
    end
end

-- V3 [AUTO PABRIK]
local Pabrik = {
    State = {
        running = false, sessionToken = 0, thread = nil, status = "Idle",
        selectedTiles = {}, selectedLines = {},
        blockId = nil, seedId = nil, itemName = "",
        breakPos = nil, breakTileCount = 1,
        oneHit = false, showHand = true, placeDelay = 0.14, breakDelay = 0.18, collectDelay = 0.05,
    }
}
SYT_Logic.Pabrik = Pabrik

local function countSelectedPabrikTiles()
    local n = 0
    for _ in pairs(Pabrik.State.selectedTiles) do n += 1 end
    return n
end

-- V5 #2: Kelompokkan tile terpilih yang saling tersambung horizontal menjadi 1 line (-----)
function Pabrik.GetConnectedLines()
    local rows = {}
    for _, pt in pairs(Pabrik.State.selectedTiles) do
        local y = pt.y
        rows[y] = rows[y] or {}
        rows[y][#rows[y] + 1] = pt.x
    end
    local lines = {}
    local ys = {}
    for y in pairs(rows) do ys[#ys + 1] = y end
    table.sort(ys)
    for _, y in ipairs(ys) do
        local xs = rows[y]
        table.sort(xs)
        local xStart, xPrev = xs[1], xs[1]
        for i = 2, #xs do
            if xs[i] <= xPrev + 1 then
                xPrev = xs[i]
            else
                lines[#lines + 1] = { y = y, x1 = xStart, x2 = xPrev, len = (xPrev - xStart + 1) }
                xStart, xPrev = xs[i], xs[i]
            end
        end
        lines[#lines + 1] = { y = y, x1 = xStart, x2 = xPrev, len = (xPrev - xStart + 1) }
    end
    return lines
end

local function setPabrikStatus(msg)
    Pabrik.State.status = msg
    local lineCnt = #Pabrik.GetConnectedLines()
    if UI then UI:SetValue("PabrikStatusDisplay", string.format("%s | Tiles: %d | Lines: %d", msg, countSelectedPabrikTiles(), lineCnt)) end
    if UIHooks.updateButtons then UIHooks.updateButtons() end
end

function Pabrik.ToggleTile(tx, ty)
    Core.EnsureInit()
    local gt = H.gt
    tx, ty = toInt(tx), toInt(ty)
    if not tx or not ty or (gt and (tx < 0 or tx >= gt.w or ty < 0 or ty >= gt.h)) then return false end
    local k = tileKey(tx, ty)
    if Pabrik.State.selectedTiles[k] then
        Pabrik.State.selectedTiles[k] = nil
    else
        Pabrik.State.selectedTiles[k] = { x = tx, y = ty }
    end
    setPabrikStatus(Pabrik.State.running and Pabrik.State.status or "Selection updated")
    if UIHooks.refreshMap then UIHooks.refreshMap(true) end
    return Pabrik.State.selectedTiles[k] ~= nil
end

function Pabrik.ToggleLine(ty, refTx)
    Core.EnsureInit()
    local gt = H.gt
    ty = toInt(ty)
    if not gt or not ty or ty < 0 or ty >= gt.h - 1 then return false end
    refTx = toInt(refTx)

    -- Jika klik tepat pada segmen garis terpilih (-----), unselect seluruh segmen tersambung itu sebagai 1 line
    if refTx and Pabrik.State.selectedTiles[tileKey(refTx, ty)] then
        local lx, rx = refTx, refTx
        while lx > 0 and Pabrik.State.selectedTiles[tileKey(lx - 1, ty)] do lx -= 1 end
        while rx < gt.w - 1 and Pabrik.State.selectedTiles[tileKey(rx + 1, ty)] do rx += 1 end
        for x = lx, rx do Pabrik.State.selectedTiles[tileKey(x, ty)] = nil end
        local anyLeft = false
        for x = 0, gt.w - 1 do
            if Pabrik.State.selectedTiles[tileKey(x, ty)] then anyLeft = true; break end
        end
        if not anyLeft then Pabrik.State.selectedLines[ty] = nil end
        setPabrikStatus(string.format("Hapus 1 Line Y=%d (%d..%d)", ty, lx, rx))
        if UIHooks.refreshMap then UIHooks.refreshMap(true) end
        return false
    end

    if not refTx and Pabrik.State.selectedLines[ty] then
        Pabrik.State.selectedLines[ty] = nil
        for x = 0, gt.w - 1 do Pabrik.State.selectedTiles[tileKey(x, ty)] = nil end
        setPabrikStatus("Hapus Line Y=" .. tostring(ty))
        if UIHooks.refreshMap then UIHooks.refreshMap(true) end
        return false
    end

    local function isEligible(x)
        local bInfo = Core.GetItemInfo(Core.GetFG(x, ty + 1))
        if not (bInfo and (bInfo.solid or bInfo.platform) and Core.CanEditTile(x, ty)) then return false end
        local cId = Core.GetFG(x, ty)
        local cInfo = Core.GetItemInfo(cId)
        return cId == 0 or (cInfo and cInfo.kind == "seed")
    end

    -- Kumpulkan segmen horizontal yang saling terhubung (-----)
    local runs, curRun = {}, nil
    for x = 0, gt.w - 1 do
        if isEligible(x) then
            if not curRun then
                curRun = { x1 = x, x2 = x }
                runs[#runs + 1] = curRun
            else
                curRun.x2 = x
            end
        else
            curRun = nil
        end
    end

    if #runs == 0 then
        setPabrikStatus("Tidak ada platform valid di Y=" .. tostring(ty))
        return false
    end

    local targetRun = nil
    if refTx then
        local bestDist = math.huge
        for _, r in ipairs(runs) do
            if refTx >= r.x1 and refTx <= r.x2 then
                targetRun = r
                break
            end
            local d = math.min(math.abs(refTx - r.x1), math.abs(refTx - r.x2))
            if d < bestDist then
                bestDist = d
                targetRun = r
            end
        end
    end

    if targetRun then
        local alreadySelected = true
        for x = targetRun.x1, targetRun.x2 do
            if not Pabrik.State.selectedTiles[tileKey(x, ty)] then alreadySelected = false; break end
        end
        for x = targetRun.x1, targetRun.x2 do
            Pabrik.State.selectedTiles[tileKey(x, ty)] = (not alreadySelected) and { x = x, y = ty } or nil
        end
        Pabrik.State.selectedLines[ty] = (not alreadySelected) or nil
        setPabrikStatus(string.format("%s 1 Line Y=%d (%d..%d)", alreadySelected and "Off" or "Pilih", ty, targetRun.x1, targetRun.x2))
        if UIHooks.refreshMap then UIHooks.refreshMap(true) end
        return not alreadySelected
    end

    local added = 0
    for _, r in ipairs(runs) do
        for x = r.x1, r.x2 do
            Pabrik.State.selectedTiles[tileKey(x, ty)] = { x = x, y = ty }
            added += 1
        end
    end
    if added > 0 then Pabrik.State.selectedLines[ty] = true end
    setPabrikStatus("Pilih Line Y=" .. tostring(ty))
    if UIHooks.refreshMap then UIHooks.refreshMap(true) end
    return added > 0
end

function Pabrik.SetItem(idOrName)
    local pair = Core.ResolveBlockAndSeedPair(idOrName)
    if not pair then return nil end
    Pabrik.State.blockId  = pair.blockId
    Pabrik.State.seedId   = pair.seedId
    Pabrik.State.itemName = pair.blockName ~= "" and pair.blockName or pair.seedName
    if UI then UI:SetValue("PabrikPairDisplay", string.format("%s | Block:%s Seed:%s", Pabrik.State.itemName, tostring(pair.blockId), tostring(pair.seedId))) end
    if UIHooks.refreshPadPab then UIHooks.refreshPadPab() end
    return pair
end

function Pabrik.SetBreakPos(tx, ty)
    if tx == nil or ty == nil then
        local p = Core.ReadPos()
        tx, ty = p.tx, p.ty
    end
    Pabrik.State.breakPos = { x = math.floor(tx), y = math.floor(ty) }
    if UI then UI:SetValue("PabrikBreakPosDisplay", string.format("BreakPos (%d, %d) [%d tile]", Pabrik.State.breakPos.x, Pabrik.State.breakPos.y, Pabrik.State.breakTileCount)) end
    if UIHooks.refreshPadPab then UIHooks.refreshPadPab() end
    if UIHooks.refreshMap then UIHooks.refreshMap(true) end
    return Pabrik.State.breakPos
end

function Pabrik.SetBreakCount(c)
    Pabrik.State.breakTileCount = clamp(toInt(c, 1), 1, 3)
    if Pabrik.State.breakPos and UI then
        UI:SetValue("PabrikBreakPosDisplay", string.format("BreakPos (%d, %d) [%d tile]", Pabrik.State.breakPos.x, Pabrik.State.breakPos.y, Pabrik.State.breakTileCount))
    end
    if UIHooks.refreshPadPab then UIHooks.refreshPadPab() end
    return Pabrik.State.breakTileCount
end

function Pabrik.GetSortedTiles()
    local list = {}
    for _, t in pairs(Pabrik.State.selectedTiles) do list[#list + 1] = { x = t.x, y = t.y } end
    table.sort(list, function(a, b)
        if a.y ~= b.y then return a.y < b.y end
        return (a.y % 2 == 0) and (a.x < b.x) or (a.x > b.x)
    end)
    return list
end

local function computePabrikBreakOffsets(c)
    if c <= 1 then return { { dx = 0, dy = -1 } }
    elseif c == 2 then return { { dx = 0, dy = -1 }, { dx = 1, dy = -1 } }
    else return { { dx = -1, dy = -1 }, { dx = 0, dy = -1 }, { dx = 1, dy = -1 } } end
end

function Pabrik.Stop()
    Pabrik.State.running = false
    Pabrik.State.sessionToken += 1
    if Pabrik.State.thread then
        pcall(task.cancel, Pabrik.State.thread)
        Pabrik.State.thread = nil
    end
    setPabrikStatus("Stopped")
    return false
end

function Pabrik.Start()
    Core.EnsureInit()
    local S = Pabrik.State
    if S.running then return true end
    if not S.blockId or not S.seedId then setPabrikStatus("Set Item/Seed pabrik dulu"); return false end
    if #Pabrik.GetSortedTiles() == 0 then setPabrikStatus("Pilih minimal 1 tile/line pabrik"); return false end
    if not S.breakPos then Pabrik.SetBreakPos() end

    S.running = true
    S.sessionToken += 1
    local token = S.sessionToken
    local function alive() return S.running and S.sessionToken == token end
    setPabrikStatus("Running...")

    S.thread = task.spawn(function()
        local bInfo = Core.GetItemInfo(S.blockId)
        local layer = (bInfo and bInfo.background) and 2 or 1
        while alive() do
            if evaluateSeems() then break end
            local gt = H.gt
            if not gt or gt.name == "" then break end

            if Core.CountItem(S.blockId) > 0 and Core.CountItem(S.seedId) < 200 then
                setPabrikStatus(string.format("TP x Walk -> BreakPos (%d)", Core.CountItem(S.blockId)))
                Packets.MoveHybrid(S.breakPos.x, S.breakPos.y, 0, alive)
                local offs = computePabrikBreakOffsets(S.breakTileCount)
                local pabPlaceGap = math.max(H.adaptivePlaceGap or 0.155, tonumber(S.placeDelay) or 0.14)
                while alive() and Core.CountItem(S.blockId) > 0 and Core.CountItem(S.seedId) < 200 do
                    if evaluateSeems() then break end
                    -- 1. Bersihkan dulu blok non-target sekaligus & punch sampai hancur penuh
                    local clearBatch, placeTargets = {}, {}
                    for _, off in ipairs(offs) do
                        local tx, ty = S.breakPos.x + off.dx, S.breakPos.y + off.dy
                        if tx >= 0 and tx < gt.w and ty >= 0 and ty < gt.h and Core.CanEditTile(tx, ty) then
                            local curId = Core.GetLayerTile(tx, ty, layer)
                            if curId ~= 0 and curId ~= S.blockId then
                                clearBatch[#clearBatch + 1] = { tx = tx, ty = ty, layer = layer }
                            end
                            placeTargets[#placeTargets + 1] = { tx = tx, ty = ty }
                        end
                    end
                    if #clearBatch > 0 then
                        Packets.BreakVerified(clearBatch, {
                            threads = 3, layer = layer, oneHit = S.oneHit,
                            hitDelay = math.max(0.12, tonumber(S.breakDelay) or 0.16),
                            showHand = S.showHand, showVisual = true,
                            noLocalMirror = false, autoRange = true, preferHybrid = true, shouldContinue = alive,
                        })
                    end
                    -- 2. Place block target ke 1-3 tile dengan verify visual==server & anti too-fast
                    for _, pt in ipairs(placeTargets) do
                        if not alive() or Core.CountItem(S.blockId) <= 0 then break end
                        if Core.GetLayerTile(pt.tx, pt.ty, layer) == 0 then
                            Packets.PlaceVerified(pt.tx, pt.ty, S.blockId, layer, {
                                showHand = S.showHand, delay = 0, noLocalMirror = false,
                                autoRange = true, preferHybrid = true,
                                retries = 2, placeGap = pabPlaceGap, shouldContinue = alive,
                            })
                        end
                    end
                    -- 3. Break seluruh tile terpasang bersamaan (terus punch sampai benar-benar hancur)
                    for _ = 1, 5 do
                        if not alive() then break end
                        local breakBatch = {}
                        for _, pt in ipairs(placeTargets) do
                            if Core.GetLayerTile(pt.tx, pt.ty, layer) ~= 0 then
                                breakBatch[#breakBatch + 1] = { tx = pt.tx, ty = pt.ty, layer = layer }
                            end
                        end
                        if #breakBatch == 0 then break end
                        Packets.BreakVerified(breakBatch, {
                            threads = 3, layer = layer, oneHit = S.oneHit,
                            hitDelay = math.max(0.12, tonumber(S.breakDelay) or 0.16),
                            showHand = S.showHand, showVisual = true,
                            noLocalMirror = false, autoRange = true, preferHybrid = true, shouldContinue = alive,
                        })
                    end
                    if alive() then
                        Packets.Collect({ radius = 5, stepMoveIfFar = true, preferHybrid = true, collectDelay = S.collectDelay, shouldContinue = alive })
                        GetcSkipper.RandomizedWait(S.collectDelay, "take", alive)
                    end
                end
            elseif Core.CountItem(S.seedId) > 0 then
                Packets.Collect({ radius = 5, stepMoveIfFar = false, preferHybrid = true, collectDelay = S.collectDelay, shouldContinue = alive })
                local seedPlaceGap = math.max(H.adaptivePlaceGap or 0.155, tonumber(S.placeDelay) or 0.14)
                local realPlaceDist = math.max(1, math.floor(Core.GetActionRange("place") - 0.35))
                for _, t in ipairs(Pabrik.GetSortedTiles()) do
                    if not alive() or evaluateSeems() then break end
                    if (Core.CountItem(S.blockId) > 0 and Core.CountItem(S.seedId) < 200) or Core.CountItem(S.seedId) <= 0 then break end
                    if Core.IsPlantable(t.x, t.y) then
                        setPabrikStatus(string.format("TP x Walk -> Plant (%d, %d)", t.x, t.y))
                        local okM = Core.IsInActionReach(t.x, t.y, "place") or Packets.MoveHybrid(t.x, t.y, realPlaceDist, alive)
                        if okM and alive() then
                            Packets.PlaceVerified(t.x, t.y, S.seedId, 1, {
                                showHand = S.showHand, delay = 0, noLocalMirror = false,
                                autoRange = true, preferHybrid = true,
                                retries = 2, placeGap = seedPlaceGap, shouldContinue = alive,
                            })
                        end
                    end
                end
            end

            if not alive() or evaluateSeems() then break end
            if Core.CountItem(S.blockId) > 0 then continue end

            local planted, ready, minRem = {}, {}, nil
            for _, t in ipairs(Pabrik.GetSortedTiles()) do
                if Core.GetFG(t.x, t.y) == S.seedId then
                    planted[#planted + 1] = t
                    if Core.IsTreeRipe(t.x, t.y) then
                        ready[#ready + 1] = t
                    else
                        local r = Core.GetTreeRemainingSec(t.x, t.y)
                        if r and (not minRem or r < minRem) then minRem = r end
                    end
                end
            end

            if #planted == 0 then
                if Core.CountItem(S.blockId) == 0 and Core.CountItem(S.seedId) == 0 then
                    Packets.Collect({ radius = 5, stepMoveIfFar = true, preferHybrid = true, collectDelay = S.collectDelay, shouldContinue = alive })
                    setPabrikStatus("Menunggu seed/block (habis)")
                    GetcSkipper.RandomizedWait(0.45, nil, alive)
                else
                    GetcSkipper.RandomizedWait(0.20, nil, alive)
                end
            elseif #ready < #planted then
                setPabrikStatus(string.format("Grow %d/%d (~%.1fs)", #ready, #planted, minRem or 0))
                GetcSkipper.RandomizedWait(0.35, nil, alive)
            else
                setPabrikStatus(string.format("TP x Walk -> Harvest %d trees", #ready))
                local realPunchDist = math.max(1, math.floor(Core.GetActionRange("punch") - 0.35))
                for _, t in ipairs(ready) do
                    if not alive() or evaluateSeems() then break end
                    local okM = Core.IsInActionReach(t.x, t.y, "break") or Packets.MoveHybrid(t.x, t.y, realPunchDist, alive)
                    if okM and alive() then
                        Packets.HitDamage({
                            tx = t.x, ty = t.y, layer = 1,
                            oneHit = S.oneHit, hitDelay = math.max(0.12, tonumber(S.breakDelay) or 0.16),
                            showHand = S.showHand, showVisual = true,
                            noLocalMirror = false, autoRange = true, preferHybrid = true, shouldContinue = alive,
                        })
                        if alive() and Core.GetFG(t.x, t.y) == 0 then
                            Packets.Collect({ radius = 5, stepMoveIfFar = false, preferHybrid = true, collectDelay = S.collectDelay, shouldContinue = alive })
                        end
                    end
                end
                if alive() then
                    Packets.Collect({ radius = 5, stepMoveIfFar = true, preferHybrid = true, collectDelay = S.collectDelay, shouldContinue = alive })
                    GetcSkipper.RandomizedWait(S.collectDelay, "take", alive)
                end
            end
        end
        if S.sessionToken == token then
            S.running = false
            S.thread = nil
            if UIHooks.refreshBP then UIHooks.refreshBP() end
            if UIHooks.updateButtons then UIHooks.updateButtons() end
        end
    end)
    return true
end

function Pabrik.Toggle()
    if Pabrik.State.running then
        return Pabrik.Stop()
    else
        return Pabrik.Start()
    end
end

-- [DIRT FARM] Pure Manual Walk + Jump + Break FG & Cave BG DF + Collect Lava/Drop Sebelum Replace Dirt + Rotation World FIFO
local DirtFarm = {
    State = {
        running = false, sessionToken = 0, thread = nil, status = "Idle",
        breakDelay = 0.14, placeDelay = 0.12, collectDelay = 0.04,
        oneHit = false, showHand = true, autoCollect = true, centerGap = false,
        rotationText = "", rotationWorlds = {}, worldIdx = 1,
        switchingWorld = false,
    }
}
SYT_Logic.DirtFarm = DirtFarm

local function setDfStatus(msg)
    DirtFarm.State.status = msg
    if UI then UI:SetValue("DfStatusDisplay", msg) end
    if UIHooks.updateButtons then UIHooks.updateButtons() end
end

function DirtFarm._syncEnvQueue(worlds)
    local ed = getEnv().__SYT_ENV_DATA or {}
    getEnv().__SYT_ENV_DATA = ed
    local copy = {}
    for i, w in ipairs(worlds or DirtFarm.State.rotationWorlds or {}) do copy[i] = w end
    ed.dfQueue = copy
    return copy
end

function DirtFarm.SetRotationWorlds(rawText)
    DirtFarm.State.rotationText = tostring(rawText or "")
    local list = {}
    for w in string.gmatch(DirtFarm.State.rotationText, "[^,%s;\n\r]+") do
        local up = string.upper((w:gsub("^%s*(.-)%s*$", "%1")))
        if up ~= "" then
            list[#list + 1] = up
        end
    end
    DirtFarm.State.rotationWorlds = list
    DirtFarm.State.worldIdx = 1
    DirtFarm._syncEnvQueue(list)
    if UI then UI:SetValue("DfRotInput", table.concat(list, ", ")) end
    return list
end

local function resolveDirtId()
    local gt = H.gt
    local w, h = gt and gt.w or 100, gt and gt.h or 60
    local found = Core.FindItemByName("dirt")
    if found and found.id then return found.id end
    local counts = {}
    for y = math.floor(h * 0.45), h - 2 do
        for x = 2, w - 3 do
            local id = Core.GetFG(x, y)
            if id and id > 0 and id ~= 8 and id ~= 6 and not Core.IsProtectedTile(id) then
                local info = Core.GetItemInfo(id)
                if info and info.solid and not info.door and not info.lock and not info.deadly and not info.hurts then
                    counts[id] = (counts[id] or 0) + 1
                end
            end
        end
    end
    local bestId, bestN = 2, -1
    for id, cnt in pairs(counts) do
        if cnt > bestN then
            bestId, bestN = id, cnt
        end
    end
    return bestId
end

local function resolveDirtSeedId(dirtId)
    dirtId = dirtId or 2
    if type(H.ItemDB) == "table" then
        for id, info in pairs(H.ItemDB) do
            if type(id) == "number" and type(info) == "table" and info.kind == "seed" then
                if info.seed == dirtId or string.lower(info.name or "") == "dirt seed" then
                    return id
                end
            end
        end
    end
    return dirtId + 1
end

local function buildDfBlueprint(gt)
    local w, h = gt.w or 100, gt.h or 60
    local doorX = gt.spawn and math.floor(gt.spawn.X) or math.floor(w / 2)
    local doorY = gt.spawn and math.floor(gt.spawn.Y) or math.max(2, math.floor(h * 0.4))
    local foundDoor = false
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local id = Core.GetFG(x, y)
            if id == 6 then
                doorX, doorY, foundDoor = x, y, true
                break
            elseif id > 0 and not foundDoor then
                local info = Core.GetItemInfo(id)
                if info and (info.door or info.entrance) then
                    doorX, doorY = x, y
                end
            end
        end
        if foundDoor then break end
    end

    local bedrockTopY = h - 1
    for y = h - 1, math.max(doorY + 4, 0), -1 do
        local bCount = 0
        for x = 0, w - 1 do
            local id = Core.GetFG(x, y)
            local info = (id > 0) and Core.GetItemInfo(id) or nil
            if id == 8 or (info and string.find(string.lower(info.name or ""), "bedrock", 1, true)) then
                bCount += 1
            end
        end
        if bCount >= math.floor(w * 0.65) then
            bedrockTopY = y
        elseif y < h - 1 then
            break
        end
    end

    local maxWorkY = clamp(bedrockTopY - 1, doorY + 2, h - 2)
    local groundY = clamp(doorY + 1, 2, maxWorkY - 1)
    local topY = 2
    local midX = math.floor(w / 2)
    local dirtId = resolveDirtId()

    local function desiredAt(x, y)
        if x < 0 or x >= w or y < topY or y > maxWorkY then return nil end
        local curId = Core.GetFG(x, y)
        if curId == 6 or curId == 8 or Core.IsProtectedTile(curId) or not Core.CanEditTile(x, y) then
            return nil
        end
        -- README.MD: hanya 2 tile ujung kiri & 2 tile ujung kanan dibolongi lurus (tanpa bolong tengah)
        if x <= 1 or x >= w - 2 then return 0 end
        if y == doorY or y == maxWorkY then return 0 end
        if y >= groundY then
            return ((y - groundY) % 2 == 0) and dirtId or 0
        else
            return ((groundY - y) % 2 == 0) and dirtId or 0
        end
    end

    -- README.MD: bersihkan Cave BG hanya pada tile lorong DF & 2 kolom ujung (air), bukan di belakang platform Dirt
    local function wantBgZeroAt(x, y)
        if x < 0 or x >= w or y < topY or y > maxWorkY then return false end
        if desiredAt(x, y) ~= 0 then return false end
        local curBg = Core.GetBG(x, y)
        if curBg == 0 or Core.IsProtectedTile(curBg) or not Core.CanEditTile(x, y) then
            return false
        end
        return true
    end

    return {
        w = w, h = h, topY = topY, doorX = doorX, doorY = doorY,
        groundY = groundY, maxWorkY = maxWorkY, midX = midX, dirtId = dirtId,
        desiredAt = desiredAt, wantBgZeroAt = wantBgZeroAt,
    }
end

do
    local function dfIsHazard(info)
        local godMode = SYT_Logic.Misc and SYT_Logic.Misc.State and SYT_Logic.Misc.State.godMode == true
        return info and (info.deadly == true or info.hurts == true) and not godMode
    end

    local function dfIsBlocking(tx, ty)
        local gt = H.gt
        if not gt or tx < 0 or tx >= gt.w or ty >= gt.h then return true end
        if ty < 0 then return false end
        if Core.IsSolid(tx, ty) then return true end
        local id = Core.GetFG(tx, ty)
        if id == 0 then return false end
        return dfIsHazard(Core.GetItemInfo(id)) == true
    end

    local function dfIsStandable(tx, ty)
        local gt = H.gt
        if not gt or tx < 0 or tx >= gt.w or ty >= gt.h then return true end
        if ty < 0 then return false end
        if Core.IsSolid(tx, ty) then return true end
        local id = Core.GetFG(tx, ty)
        if id == 0 then return false end
        local info = Core.GetItemInfo(id)
        return info and info.platform == true and not info.background
    end

    local function dfIsBreakableBlocking(tx, ty)
        local gt = H.gt
        if not gt or tx < 0 or tx >= gt.w or ty < 0 or ty >= gt.h then return false, false end
        local id = Core.GetFG(tx, ty)
        if id == 0 then return false, false end
        local info = Core.GetItemInfo(id)
        if not Core.IsSolid(tx, ty) and not dfIsHazard(info) then
            return false, false, info
        end
        local breakable = (not Core.IsProtectedTile(id)) and Core.CanEditTile(tx, ty)
        return true, breakable, info
    end

    local function dfSafeReachDist(tx, ty, posOverride, kind)
        local pos = posOverride or Core.ReadPos()
        local maxR = math.min(2.15, Core.GetActionRange(kind or "break") - 0.12)
        local dx = math.abs((tx + 0.5) - pos.x)
        local dy = math.abs((ty + 0.5) - (pos.y - 0.475))
        return dx <= maxR and dy <= maxR
    end

    local function dfCanActFromStand(tx, ty, actionKind, itemInfo, standPos)
        if actionKind == "stand" then
            return math.abs(standPos.x - (tx + 0.5)) <= 0.48 and math.abs(standPos.y - (ty + 1)) <= 0.25
        end
        if not Core.IsInActionReach(tx, ty, actionKind, standPos) then return false end
        if actionKind == "build" and itemInfo then
            return Core.CanPlaceBodyOk(tx, ty, itemInfo, standPos)
        end
        return true
    end

    local function dfQuickCollectNear(aliveFn, filterId, waitRecentDrops)
        local S = DirtFarm.State
        if not S.autoCollect and not filterId then return 0 end
        local gt = H.gt
        if not gt or type(gt.dropList) ~= "function" then return 0 end

        local total = 0
        local checks = waitRecentDrops and 2 or 1
        for c = 1, checks do
            if type(aliveFn) == "function" and not aliveFn() then break end
            local okD, drops = pcall(gt.dropList)
            if not okD or type(drops) ~= "table" or #drops == 0 then break end
            local pos = Core.ReadPos()
            local now = os.clock()
            local hasReadyNear = false
            local hasSoonNear = false
            for i = 1, #drops do
                local d = drops[i]
                if type(d) == "table" and d.uid and d.x and d.y and (d.n or 0) > 0 then
                    if not filterId or d.id == filterId then
                        local distBody = math.max(math.abs(d.x - pos.x), math.abs(d.y - (pos.y - 0.5)))
                        if distBody <= 4.55 and (d.id == 112 or Core.GetItemRoom(d.id) > 0) then
                            if (d.readyAt or 0) <= now then
                                hasReadyNear = true
                                break
                            elseif (d.readyAt or 0) <= now + 0.22 then
                                hasSoonNear = true
                            end
                        end
                    end
                end
            end
            if hasReadyNear then
                local res = Packets.Collect({
                    radius = 4.55, filterId = filterId, stepMoveIfFar = false,
                    collectDelay = tonumber(S.collectDelay) or 0.04,
                    shouldContinue = aliveFn,
                })
                total += (res and res.totalTaken or 0)
            elseif hasSoonNear and waitRecentDrops and c < checks then
                task.wait(0.08)
            else
                break
            end
        end
        return total
    end

    local function dfSettleGrounded(aliveFn, maxWait)
        Core.ClearManualInput()
        local deadline = os.clock() + (maxWait or 0.45)
        while os.clock() < deadline do
            if type(aliveFn) == "function" and not aliveFn() then return false end
            local p = Core.ReadPos()
            if p.grounded and math.abs(p.vx or 0) < 0.35 then return true end
            task.wait(0.016)
        end
        return false
    end

    local function dfSettleStillForPunch(aliveFn)
        Core.ClearManualInput()
        local dl = os.clock() + 0.18
        while os.clock() < dl do
            if type(aliveFn) == "function" and not aliveFn() then return false end
            local p = Core.ReadPos()
            if math.abs(p.vx or 0) <= 0.15 and math.abs(p.vy or 0) <= 0.15 then return true end
            task.wait(0.016)
        end
        return true
    end

    -- Break FG (layer=1) terlebih dahulu lalu Cave BG (layer=2) dengan hit asli server (>= 0.192s), anti-kick & verifikasi 0 + bersih crack
    local function dfBreakBatchLayers(coords, aliveFn)
        local S = DirtFarm.State
        local gt = H.gt
        if not gt or type(coords) ~= "table" or #coords == 0 then return true end

        local dfHitGap = math.max(0.194, tonumber(S.breakDelay) or 0.194)
        local items = {}
        local seen = {}
        for _, c in ipairs(coords) do
            local tx = toInt(c.tx or c.x or c[1])
            local ty = toInt(c.ty or c.y or c[2])
            if tx and ty and tx >= 0 and tx < gt.w and ty >= 0 and ty < gt.h then
                local k = ty * 1000 + tx
                local wantFg = (c.wantFg ~= false)
                local wantBg = (c.wantBg == true)
                if not seen[k] then
                    local entry = { tx = tx, ty = ty, wantFg = wantFg, wantBg = wantBg }
                    items[#items + 1] = entry
                    seen[k] = entry
                else
                    if wantFg then seen[k].wantFg = true end
                    if wantBg then seen[k].wantBg = true end
                end
            end
        end
        if #items == 0 then return true end

        dfSettleStillForPunch(aliveFn)

        local function coolIfBlocked()
            if H.fwLastBlockAt and (os.clock() - H.fwLastBlockAt) < 0.40 then
                task.wait(0.32)
            end
        end

        -- Stage 1: Break FG (layer 1) sampai benar-benar 0 di server
        for _ = 1, 5 do
            if type(aliveFn) == "function" and not aliveFn() then return false end
            coolIfBlocked()
            local pos = Core.ReadPos()
            local fgTargets = {}
            for _, it in ipairs(items) do
                if it.wantFg then
                    local cid = Core.GetFG(it.tx, it.ty)
                    if cid ~= 0 and not Core.IsProtectedTile(cid) and Core.CanEditTile(it.tx, it.ty) and dfSafeReachDist(it.tx, it.ty, pos, "break") then
                        fgTargets[#fgTargets + 1] = { tx = it.tx, ty = it.ty, layer = 1 }
                    end
                end
            end
            if #fgTargets == 0 then break end
            H.dfSpeedForceUntil = os.clock() + 1.0
            for _, t in ipairs(fgTargets) do
                if type(aliveFn) == "function" and not aliveFn() then return false end
                Packets.BreakVerified({ t }, {
                    threads = 1, layer = 1, oneHit = false, customHits = nil,
                    hitDelay = dfHitGap, verifyTimeout = 0.28, showHand = S.showHand,
                    showVisual = true, noLocalMirror = true, autoRange = false,
                    shouldContinue = aliveFn,
                })
                if Core.GetFG(t.tx, t.ty) == 0 then pcall(Core.ClearVisualCrack, t.tx, t.ty) end
                task.wait(0.025)
            end
        end

        -- Stage 2: Break Cave BG (layer 2) pada semua target yang sudah bebas FG
        for _ = 1, 5 do
            if type(aliveFn) == "function" and not aliveFn() then return false end
            coolIfBlocked()
            local pos = Core.ReadPos()
            local bgTargets = {}
            for _, it in ipairs(items) do
                if it.wantBg and Core.GetFG(it.tx, it.ty) == 0 then
                    local cbg = Core.GetBG(it.tx, it.ty)
                    if cbg ~= 0 and not Core.IsProtectedTile(cbg) and Core.CanEditTile(it.tx, it.ty) and dfSafeReachDist(it.tx, it.ty, pos, "break") then
                        bgTargets[#bgTargets + 1] = { tx = it.tx, ty = it.ty, layer = 2 }
                    end
                end
            end
            if #bgTargets == 0 then break end
            H.dfSpeedForceUntil = os.clock() + 1.0
            for _, t in ipairs(bgTargets) do
                if type(aliveFn) == "function" and not aliveFn() then return false end
                Packets.BreakVerified({ t }, {
                    threads = 1, layer = 2, oneHit = false, customHits = nil,
                    hitDelay = dfHitGap, verifyTimeout = 0.28, showHand = S.showHand,
                    showVisual = true, noLocalMirror = true, autoRange = false,
                    shouldContinue = aliveFn,
                })
                if Core.GetBG(t.tx, t.ty) == 0 then pcall(Core.ClearVisualCrack, t.tx, t.ty) end
                task.wait(0.025)
            end
        end

        for _, it in ipairs(items) do
            if it.wantFg then
                local fid = Core.GetFG(it.tx, it.ty)
                if fid ~= 0 and not Core.IsProtectedTile(fid) and Core.CanEditTile(it.tx, it.ty) then
                    return false
                end
            end
            if it.wantBg and Core.GetFG(it.tx, it.ty) == 0 then
                local bid = Core.GetBG(it.tx, it.ty)
                if bid ~= 0 and not Core.IsProtectedTile(bid) and Core.CanEditTile(it.tx, it.ty) then
                    return false
                end
            end
            pcall(Core.ClearVisualCrack, it.tx, it.ty)
        end
        return true
    end

    local function dfStepWalkToX(goalX, expectedFloorY, maxTime, aliveFn, stopIfFn, keepMovingOnPass, bp)
        local t0 = os.clock()
        local deadline = t0 + (maxTime or 3.5)
        local lastX = Core.ReadPos().x
        local lastProgT = t0
        local stallBreaks = 0
        while os.clock() < deadline do
            if type(aliveFn) == "function" and not aliveFn() then
                Core.ClearManualInput()
                return false, "cancelled"
            end
            H.dfSpeedForceUntil = os.clock() + 0.8
            local p = Core.ReadPos()
            if expectedFloorY and math.abs(p.y - expectedFloorY) > 0.78 and not p.grounded then
                Core.ClearManualInput()
                return false, "fell"
            end
            if type(stopIfFn) == "function" then
                local st, reason = stopIfFn(p)
                if st then
                    if not keepMovingOnPass then
                        Core.ClearManualInput()
                    end
                    return true, reason or "stopped"
                end
            end
            local dx = goalX - p.x
            if math.abs(dx) <= 0.14 then
                Core.ClearManualInput()
                return true, "reached"
            end
            local dir = (dx > 0) and 1 or -1
            local w = H.gt and H.gt.w or 100
            local checkTx = clamp(math.floor(p.x + dir * 0.62), 0, w - 1)
            local checkTy = expectedFloorY and (expectedFloorY - 1) or math.floor(p.y - 0.01)
            local blkNow, brkNow = dfIsBreakableBlocking(checkTx, checkTy)
            if blkNow and brkNow and ((not bp) or bp.desiredAt(checkTx, checkTy) == 0) and checkTx ~= p.tx then
                Core.ClearManualInput()
                dfBreakBatchLayers({ { tx = checkTx, ty = checkTy, wantFg = true, wantBg = false } }, aliveFn)
                lastProgT = os.clock()
                deadline = deadline + 0.70
            elseif math.abs(p.x - lastX) > 0.04 then
                lastX = p.x
                lastProgT = os.clock()
            elseif (os.clock() - lastProgT) > 0.36 then
                local frontTx = clamp(math.floor(p.x + dir * 0.72), 0, w - 1)
                local blk, brk = dfIsBreakableBlocking(frontTx, checkTy)
                local allowedByBp = (not bp) or (bp.desiredAt(frontTx, checkTy) == 0)
                if blk and brk and allowedByBp and stallBreaks < 4 then
                    stallBreaks += 1
                    Core.ClearManualInput()
                    dfBreakBatchLayers({ { tx = frontTx, ty = checkTy, wantFg = true, wantBg = false } }, aliveFn)
                    lastProgT = os.clock()
                    deadline = deadline + 0.75
                elseif (os.clock() - lastProgT) > 0.65 then
                    Core.ClearManualInput()
                    return false, "stalled"
                end
            end
            Core.SetManualInput(dir, false)
            task.wait(0.012)
        end
        Core.ClearManualInput()
        return false, "timeout"
    end

    local function dfManualJumpTo(destTileX, destFloorY, aliveFn)
        local targetCenterX = destTileX + 0.5
        local p0 = Core.ReadPos()
        local startY = p0.y
        local dyNeeded = startY - destFloorY
        local t0 = os.clock()
        local deadline = t0 + 1.65
        local jumped = false
        local releasedJump = false

        while os.clock() < deadline do
            if type(aliveFn) == "function" and not aliveFn() then
                Core.ClearManualInput()
                return false, "cancelled"
            end
            H.dfSpeedForceUntil = os.clock() + 0.8
            local p = Core.ReadPos()
            local now = os.clock()
            local elapsed = now - t0
            if not p.grounded or p.vy < -1.0 then
                jumped = true
            end

            if jumped and p.grounded and elapsed > 0.14 then
                if math.abs(p.y - destFloorY) <= 0.22 and math.abs(p.x - targetCenterX) <= 0.60 then
                    Core.ClearManualInput()
                    if math.abs(p.x - targetCenterX) > 0.15 then
                        dfStepWalkToX(targetCenterX, destFloorY, 0.55, aliveFn)
                    end
                    return true, "landed"
                elseif math.abs(p.y - destFloorY) > 0.25 and p.y > destFloorY + 0.25 then
                    Core.ClearManualInput()
                    return false, "missed_floor"
                end
            end

            local dx = targetCenterX - p.x
            local dir = 0
            if dyNeeded >= 0.5 and elapsed < 0.09 and p.y > destFloorY + 0.25 and math.abs(dx) <= 1.25 then
                dir = 0
            elseif math.abs(dx) > 0.10 then
                dir = (dx > 0) and 1 or -1
            end

            local wantJump = false
            if not releasedJump then
                if dyNeeded >= 1.5 then
                    if elapsed < 0.20 and p.y > destFloorY - 0.35 and (p.vy <= 0 or not jumped) then
                        wantJump = true
                    elseif elapsed >= 0.08 then
                        releasedJump = true
                    end
                elseif dyNeeded >= 0.5 then
                    if elapsed < 0.13 and p.y > destFloorY - 0.30 and (p.vy <= 0 or not jumped) then
                        wantJump = true
                    elseif elapsed >= 0.06 then
                        releasedJump = true
                    end
                else
                    if elapsed < 0.12 and p.y > startY - 0.75 and (p.vy <= 0 or not jumped) then
                        wantJump = true
                    elseif elapsed >= 0.06 then
                        releasedJump = true
                    end
                end
            end

            Core.SetManualInput(dir, wantJump)
            task.wait(0.016)
        end
        Core.ClearManualInput()
        local pf = Core.ReadPos()
        local okF = math.abs(pf.y - destFloorY) <= 0.25 and math.abs(pf.x - targetCenterX) <= 0.65
        return okF, okF and "landed_late" or "jump_timeout"
    end

    local function dfDropIntoCol(targetColX, destFloorY, aliveFn, maxWait)
        local targetCenterX = targetColX + 0.5
        local t0 = os.clock()
        local deadline = t0 + (maxWait or 2.8)
        while os.clock() < deadline do
            if type(aliveFn) == "function" and not aliveFn() then
                Core.ClearManualInput()
                return false, "cancelled"
            end
            H.dfSpeedForceUntil = os.clock() + 0.8
            local p = Core.ReadPos()
            if p.grounded and math.abs(p.y - destFloorY) <= 0.22 and math.abs(p.x - targetCenterX) <= 0.65 then
                Core.ClearManualInput()
                if math.abs(p.x - targetCenterX) > 0.15 then
                    dfStepWalkToX(targetCenterX, destFloorY, 0.50, aliveFn)
                end
                return true, "landed"
            end
            if p.grounded and p.y > destFloorY + 0.35 then
                Core.ClearManualInput()
                return false, "overshot_drop"
            end
            local dx = targetCenterX - p.x
            local dir = (math.abs(dx) > 0.12) and ((dx > 0) and 1 or -1) or 0
            Core.SetManualInput(dir, false)
            task.wait(0.016)
        end
        Core.ClearManualInput()
        return false, "drop_timeout"
    end

    local function dfPlaceDirtSafe(tx, ty, dirtId, aliveFn)
        Core.ClearManualInput()
        local curId = Core.GetFG(tx, ty)
        if curId == dirtId then return true, "already" end
        if curId ~= 0 then
            if Core.IsProtectedTile(curId) or not Core.CanEditTile(tx, ty) then
                return false, "protected"
            end
            if not dfBreakBatchLayers({ { tx = tx, ty = ty, wantFg = true, wantBg = false } }, aliveFn) then
                return false, "break_failed"
            end
            dfQuickCollectNear(aliveFn, nil, true)
        end
        if Core.CountItem(dirtId) <= 0 then
            dfQuickCollectNear(aliveFn, dirtId, true)
        end
        if Core.CountItem(dirtId) <= 0 then
            return false, "no_dirt"
        end
        local dirtInfo = Core.GetItemInfo(dirtId)
        local pos = Core.ReadPos()
        local okBody, reasonBody = Core.CanPlaceBodyOk(tx, ty, dirtInfo, pos)
        if not okBody and reasonBody == "inside_player" then
            local awayDir = (pos.x <= tx + 0.5) and -1 or 1
            local safeX = (awayDir < 0) and (tx - 0.45) or (tx + 1.45)
            local pFloor = math.floor(pos.y + 0.5)
            if dfIsStandable(math.floor(safeX), pFloor) then
                dfStepWalkToX(safeX, pFloor, 0.65, aliveFn)
                pos = Core.ReadPos()
                okBody, reasonBody = Core.CanPlaceBodyOk(tx, ty, dirtInfo, pos)
            end
        end
        if not okBody then
            return false, reasonBody or "body_blocked"
        end
        if not Core.IsInActionReach(tx, ty, "build", pos) then
            return false, "out_of_reach"
        end
        local S = DirtFarm.State
        local okP, msgP = Packets.PlaceVerified(tx, ty, dirtId, 1, {
            showHand = S.showHand, delay = 0, noLocalMirror = false,
            retries = 3, placeGap = math.max(H.adaptivePlaceGap or 0.172, tonumber(S.placeDelay) or 0.172),
            shouldContinue = aliveFn,
        })
        if okP or Core.GetFG(tx, ty) == dirtId then
            return true, msgP or "placed"
        end
        return false, msgP or "place_failed"
    end

    -- README.MD L174: Bila lantai mengandung lava/batu/non-dirt, break dulu & collect dropnya sebelum replace Dirt
    local function dfFixFloorSafe(tx, floorY, dirtId, aliveFn)
        local curId = Core.GetFG(tx, floorY)
        if curId == dirtId then return true, "already" end
        if Core.IsProtectedTile(curId) or not Core.CanEditTile(tx, floorY) then
            return false, "protected"
        end
        if curId ~= 0 then
            local info = Core.GetItemInfo(curId)
            local isHaz = dfIsHazard(info)
            if not isHaz and Core.CountItem(dirtId) <= 0 then
                dfQuickCollectNear(aliveFn, dirtId, true)
                if Core.CountItem(dirtId) <= 0 and dfIsStandable(tx, floorY) then
                    return false, "no_dirt"
                end
            end
            if not dfBreakBatchLayers({ { tx = tx, ty = floorY, wantFg = true, wantBg = false } }, aliveFn) then
                return false, "floor_break_failed"
            end
            dfQuickCollectNear(aliveFn, nil, true)
        end
        return dfPlaceDirtSafe(tx, floorY, dirtId, aliveFn)
    end

    local function dfCleanAirTilesInReach(bp, coords, aliveFn)
        local allOk = true
        for round = 1, 3 do
            if type(aliveFn) == "function" and not aliveFn() then return false end
            local pos = Core.ReadPos()
            local batch = {}
            for _, c in ipairs(coords) do
                local cx, cy = c[1], c[2]
                if cx and cy and cx >= 0 and cy >= 0 and H.gt and cx < H.gt.w and cy < H.gt.h then
                    if bp.desiredAt(cx, cy) == 0 and dfSafeReachDist(cx, cy, pos, "break") then
                        local fg = Core.GetFG(cx, cy)
                        local needFg = (fg ~= 0 and not Core.IsProtectedTile(fg) and Core.CanEditTile(cx, cy))
                        local needBg = bp.wantBgZeroAt(cx, cy)
                        if needFg or needBg then
                            batch[#batch + 1] = { tx = cx, ty = cy, wantFg = needFg, wantBg = true }
                        end
                    end
                end
            end
            if #batch == 0 then
                dfQuickCollectNear(aliveFn)
                return true
            end
            allOk = dfBreakBatchLayers(batch, aliveFn)
            dfQuickCollectNear(aliveFn)
            if allOk then return true end
            task.wait(0.06)
        end
        return allOk
    end

    local function dfEnsureTemporaryStep(tx, ty, dirtId, aliveFn)
        local cid = Core.GetFG(tx, ty)
        if dfIsStandable(tx, ty) and not dfIsHazard(cid > 0 and Core.GetItemInfo(cid) or nil) then
            return true
        end
        return dfFixFloorSafe(tx, ty, dirtId, aliveFn)
    end

    -- Bersihkan 2 kolom ujung shaft sekitar baris tertentu; jika sOut (x=0 / w-1) masih kotor & di luar reach, masuk 1 langkah ke sIn dulu
    local function dfCleanEdgeShaftAround(bp, sIn, sOut, ys, aliveFn)
        local coords = {}
        for _, y in ipairs(ys) do
            if y >= bp.topY and y <= bp.maxWorkY then
                coords[#coords + 1] = { sIn, y }
                coords[#coords + 1] = { sOut, y }
            end
        end
        local ok = dfCleanAirTilesInReach(bp, coords, aliveFn)
        local needStepIntoShaft = false
        for _, y in ipairs(ys) do
            if y >= bp.topY and y <= bp.maxWorkY and bp.desiredAt(sOut, y) == 0 then
                local fg = Core.GetFG(sOut, y)
                if (fg ~= 0 and not Core.IsProtectedTile(fg) and Core.CanEditTile(sOut, y)) or bp.wantBgZeroAt(sOut, y) then
                    needStepIntoShaft = true
                    break
                end
            end
        end
        if needStepIntoShaft then
            local pos = Core.ReadPos()
            local standY = math.floor(pos.y + 0.5)
            local returnX = (sIn < bp.midX) and 2 or (bp.w - 3)
            if dfIsStandable(sIn, standY) or (Core.CountItem(bp.dirtId) > 0 and dfFixFloorSafe(sIn, standY, bp.dirtId, aliveFn)) then
                if dfStepWalkToX(sIn + 0.5, standY, 0.9, aliveFn, nil, false, bp) then
                    dfCleanAirTilesInReach(bp, coords, aliveFn)
                    if dfIsStandable(returnX, standY) then
                        dfStepWalkToX(returnX + 0.5, standY, 0.9, aliveFn, nil, false, bp)
                        if bp.desiredAt(sIn, standY) == 0 then
                            dfCleanAirTilesInReach(bp, { { sIn, standY } }, aliveFn)
                        end
                    end
                end
            end
        end
        return ok
    end

    -- Naik / Panjat murni lewat 2 kolom ujung (kiri {0,1} atau kanan {w-2,w-1}) dengan bersihkan pijakan & Cave BG di belakang
    local function dfClimbShaftToFloorY(bp, colA, colB, targetFloorY, dirtId, aliveFn, preferExitX)
        local dirtInfo = Core.GetItemInfo(dirtId)
        for _ = 1, 120 do
            if type(aliveFn) == "function" and not aliveFn() then
                Core.ClearManualInput()
                return false, "cancelled"
            end
            dfSettleGrounded(aliveFn, 0.35)
            local pos = Core.ReadPos()
            local curFloorY = math.floor(pos.y + 0.5)
            if curFloorY <= targetFloorY then
                Core.ClearManualInput()
                return true, "climbed"
            end

            local standCol = pos.tx
            if standCol ~= colA and standCol ~= colB then
                local enterCol = (math.abs(colA - pos.tx) <= math.abs(colB - pos.tx)) and colA or colB
                if math.abs(enterCol - pos.tx) > 1 then
                    Core.ClearManualInput()
                    return false, "not_adjacent_to_shaft"
                end
                dfCleanAirTilesInReach(bp, { { enterCol, curFloorY - 1 }, { enterCol, curFloorY - 2 } }, aliveFn)
                local okStep, errStep = dfEnsureTemporaryStep(enterCol, curFloorY, dirtId, aliveFn)
                if not okStep then return false, errStep or "no_dirt_entry" end
                dfStepWalkToX(enterCol + 0.5, curFloorY, 0.9, aliveFn)
                pos = Core.ReadPos()
                standCol = pos.tx
                curFloorY = math.floor(pos.y + 0.5)
            end

            local otherCol = (standCol == colA) and colB or colA
            local nextFloorY = curFloorY - 1
            local nextFootY = nextFloorY - 1

            local clearReq = {
                { standCol, nextFootY },
                { standCol, nextFootY - 1 },
                { otherCol, nextFootY },
                { otherCol, nextFootY - 1 },
            }
            if nextFloorY == targetFloorY and preferExitX then
                clearReq[#clearReq + 1] = { preferExitX, targetFloorY - 1 }
            end
            dfCleanAirTilesInReach(bp, clearReq, aliveFn)

            local cidStep = Core.GetFG(otherCol, nextFloorY)
            if cidStep == 0 or not dfIsStandable(otherCol, nextFloorY) or dfIsHazard(cidStep > 0 and Core.GetItemInfo(cidStep) or nil) then
                if not dfCanActFromStand(otherCol, nextFloorY, "build", dirtInfo, pos) then
                    dfStepWalkToX(standCol + 0.5, curFloorY, 0.5, aliveFn)
                end
                local okP, errP = dfFixFloorSafe(otherCol, nextFloorY, dirtId, aliveFn)
                if not okP then
                    Core.ClearManualInput()
                    return false, errP or "no_dirt_climb"
                end
            end

            local okJ = dfManualJumpTo(otherCol, nextFloorY, aliveFn)
            if not okJ then
                dfCleanAirTilesInReach(bp, clearReq, aliveFn)
                okJ = dfManualJumpTo(otherCol, nextFloorY, aliveFn)
            end
            if not okJ then
                Core.ClearManualInput()
                return false, "climb_jump_failed"
            end

            -- Segera hancurkan pijakan sementara & Cave BG di standCol setelah naik 1 tile
            dfCleanAirTilesInReach(bp, {
                { standCol, curFloorY },
                { standCol, curFloorY + 1 },
                { standCol, curFloorY - 1 },
            }, aliveFn)
        end
        Core.ClearManualInput()
        return false, "climb_limit"
    end

    -- Turun tepat 2 baris (atau hingga targetFloorY) lewat 2 kolom ujung + sapu Cave BG di kedua kolom ujung
    local function dfTransitionToLowerRow(bp, shaftInner, shaftOuter, edgeX, fromCorY, nextCorY, dirtId, aliveFn)
        local fromFloorY = fromCorY + 1
        local nextFloorY = nextCorY + 1
        dfSettleGrounded(aliveFn, 0.4)

        dfCleanAirTilesInReach(bp, {
            { shaftInner, fromCorY }, { shaftOuter, fromCorY },
            { shaftInner, fromFloorY }, { shaftOuter, fromFloorY },
        }, aliveFn)

        -- Kasus terakhir tepat di Bedrock: turun bertahap 1x1 antar shaftInner<->shaftOuter sampai bedrockTopY
        if nextFloorY > bp.maxWorkY then
            dfCleanAirTilesInReach(bp, {
                { shaftInner, fromFloorY + 1 }, { shaftOuter, fromFloorY + 1 },
                { edgeX, fromFloorY + 1 },
            }, aliveFn)
            local okIn = dfStepWalkToX(shaftInner + 0.5, nil, 1.4, aliveFn)
            if not okIn then
                dfDropIntoCol(shaftInner, math.min(nextFloorY, fromFloorY + 2), aliveFn, 1.6)
            end
            for _ = 1, 8 do
                if type(aliveFn) == "function" and not aliveFn() then return false, "cancelled" end
                dfSettleGrounded(aliveFn, 0.3)
                local p = Core.ReadPos()
                local cY = math.floor(p.y + 0.5)
                if cY >= nextFloorY then break end
                local curCol = (math.abs(p.x - (shaftInner + 0.5)) <= math.abs(p.x - (shaftOuter + 0.5))) and shaftInner or shaftOuter
                local altCol = (curCol == shaftInner) and shaftOuter or shaftInner
                dfCleanAirTilesInReach(bp, {
                    { altCol, cY - 1 }, { altCol, cY }, { altCol, cY + 1 },
                    { curCol, cY - 1 },
                }, aliveFn)
                local okD = dfDropIntoCol(altCol, math.min(nextFloorY, cY + 1), aliveFn, 1.4)
                if not okD then
                    dfDropIntoCol(altCol, nextFloorY, aliveFn, 1.4)
                end
            end
            dfSettleGrounded(aliveFn, 0.35)
            local pf = Core.ReadPos()
            local landFloor = math.floor(pf.y + 0.5)
            dfCleanAirTilesInReach(bp, {
                { edgeX, nextCorY }, { edgeX, nextCorY - 1 },
                { shaftInner, nextCorY }, { shaftOuter, nextCorY },
                { shaftInner, nextCorY - 1 }, { shaftOuter, nextCorY - 1 },
            }, aliveFn)
            if not dfStepWalkToX(edgeX + 0.5, landFloor, 1.4, aliveFn) then
                return false, "bedrock_exit_failed"
            end
            dfCleanEdgeShaftAround(bp, shaftInner, shaftOuter, { fromCorY, fromFloorY, nextCorY - 1, nextCorY }, aliveFn)
            return true, "entered_bedrock"
        end

        -- Kasus normal turun tepat 2 baris (fromCorY -> fromCorY + 2) via 1-tile landing step di shaft
        local midY = fromFloorY + 1
        local okStep1, errS1 = dfEnsureTemporaryStep(shaftInner, midY, dirtId, aliveFn)
        if not okStep1 then return false, errS1 or "drop_step1_failed" end

        local okD1 = dfDropIntoCol(shaftInner, midY, aliveFn, 1.8)
        if not okD1 then return false, "drop_step1_miss" end

        dfCleanAirTilesInReach(bp, { { shaftOuter, midY }, { edgeX, midY } }, aliveFn)
        local okStep2, errS2 = dfEnsureTemporaryStep(shaftOuter, nextFloorY, dirtId, aliveFn)
        if not okStep2 then return false, errS2 or "drop_step2_failed" end

        local okD2 = dfDropIntoCol(shaftOuter, nextFloorY, aliveFn, 1.8)
        if not okD2 then return false, "drop_step2_miss" end

        dfCleanAirTilesInReach(bp, { { shaftInner, midY }, { edgeX, midY } }, aliveFn)
        if bp.desiredAt(edgeX, nextFloorY) == dirtId and Core.GetFG(edgeX, nextFloorY) ~= dirtId then
            local okE, errE = dfFixFloorSafe(edgeX, nextFloorY, dirtId, aliveFn)
            if not okE and not dfIsStandable(edgeX, nextFloorY) then
                return false, errE or "edge_floor_failed"
            end
        end
        local okIn, errIn = dfEnsureTemporaryStep(shaftInner, nextFloorY, dirtId, aliveFn)
        if not okIn then return false, errIn or "drop_bridge_failed" end

        if not dfStepWalkToX(edgeX + 0.5, nextFloorY, 1.4, aliveFn) then
            return false, "enter_row_failed"
        end

        -- Sapu tuntas FG & Cave BG pada 2 kolom ujung shaft setelah aman berdiri di edgeX
        dfCleanEdgeShaftAround(bp, shaftInner, shaftOuter, { fromCorY, fromFloorY, nextCorY, nextFloorY }, aliveFn)
        return true, "entered"
    end

    local function dfRowNeedsLowerFix(bp, corY, xFrom, xTo, alsoClearAbove)
        local dir = (xTo >= xFrom) and 1 or -1
        local floorY = corY + 1
        local dirtId = bp.dirtId
        for tx = xFrom, xTo, dir do
            if bp.desiredAt(tx, corY) == 0 and (Core.GetFG(tx, corY) ~= 0 or bp.wantBgZeroAt(tx, corY)) then
                return tx
            end
            if alsoClearAbove and corY - 1 >= bp.topY and bp.desiredAt(tx, corY - 1) == 0 then
                if Core.GetFG(tx, corY - 1) ~= 0 or bp.wantBgZeroAt(tx, corY - 1) then
                    return tx
                end
            end
            if floorY <= bp.maxWorkY and bp.desiredAt(tx, floorY) == dirtId and Core.GetFG(tx, floorY) ~= dirtId then
                return tx
            end
        end
        return nil
    end

    -- Sapu 1 lorong bawah penuh secara monotonik satu arah (tidak membalik arah di tengah jalan)
    local function dfWalkCorridorLower(bp, corY, xFrom, xTo, alsoClearAbove, aliveFn, cleanEndFloorShaft, skipAudit)
        local dir = (xTo >= xFrom) and 1 or -1
        local floorY = corY + 1
        local dirtId = bp.dirtId
        local dirtInfo = Core.GetItemInfo(dirtId)

        local function tileNeedsWork(tx)
            if bp.desiredAt(tx, corY) == 0 then
                local cfg = Core.GetFG(tx, corY)
                if (cfg ~= 0 and not Core.IsProtectedTile(cfg) and Core.CanEditTile(tx, corY)) or bp.wantBgZeroAt(tx, corY) then
                    return true
                end
            end
            if alsoClearAbove and corY - 1 >= bp.topY and bp.desiredAt(tx, corY - 1) == 0 then
                local afg = Core.GetFG(tx, corY - 1)
                if (afg ~= 0 and not Core.IsProtectedTile(afg) and Core.CanEditTile(tx, corY - 1)) or bp.wantBgZeroAt(tx, corY - 1) then
                    return true
                end
            end
            if floorY <= bp.maxWorkY and bp.desiredAt(tx, floorY) == dirtId then
                local ffg = Core.GetFG(tx, floorY)
                if ffg ~= dirtId and not Core.IsProtectedTile(ffg) and Core.CanEditTile(tx, floorY) then
                    return true
                end
            end
            return false
        end

        local maxPasses = skipAudit and 1 or 2
        for pass = 1, maxPasses do
            local pFrom = (pass == 1) and xFrom or xTo
            local pTo = (pass == 1) and xTo or xFrom
            if pass == 2 then
                local missedX = dfRowNeedsLowerFix(bp, corY, xFrom, xTo, alsoClearAbove)
                if not missedX then break end
                -- Jalan lurus sepanjang baris yang sama ke missedX lalu kembali ke xTo agar posisi ujung tetap akurat
                pFrom = xTo
                pTo = missedX
            end

            local pDir = (pTo >= pFrom) and 1 or -1
            for tx = pFrom, pTo, pDir do
                if type(aliveFn) == "function" and not aliveFn() then
                    Core.ClearManualInput()
                    return false, "cancelled"
                end
                H.dfSpeedForceUntil = os.clock() + 1.0

                local needCor = (bp.desiredAt(tx, corY) == 0)
                    and ((Core.GetFG(tx, corY) ~= 0 and not Core.IsProtectedTile(Core.GetFG(tx, corY)) and Core.CanEditTile(tx, corY)) or bp.wantBgZeroAt(tx, corY))
                local needAbove = alsoClearAbove and corY - 1 >= bp.topY and (bp.desiredAt(tx, corY - 1) == 0)
                    and ((Core.GetFG(tx, corY - 1) ~= 0 and not Core.IsProtectedTile(Core.GetFG(tx, corY - 1)) and Core.CanEditTile(tx, corY - 1)) or bp.wantBgZeroAt(tx, corY - 1))
                local needFloor = (floorY <= bp.maxWorkY) and (bp.desiredAt(tx, floorY) == dirtId)
                    and (Core.GetFG(tx, floorY) ~= dirtId) and not Core.IsProtectedTile(Core.GetFG(tx, floorY)) and Core.CanEditTile(tx, floorY)

                if needCor or needAbove or needFloor then
                    local curPos = Core.ReadPos()
                    if math.abs(curPos.y - floorY) > 0.55 then
                        Core.ClearManualInput()
                        return false, "off_floor"
                    end
                    local needWalkCloser = not dfSafeReachDist(tx, corY, curPos, "break")
                        or (needAbove and not dfSafeReachDist(tx, corY - 1, curPos, "break"))
                        or (needFloor and not dfSafeReachDist(tx, floorY, curPos, "build"))
                    if needWalkCloser then
                        local standReqX = tx - pDir
                        if not dfStepWalkToX(standReqX + 0.5, floorY, 1.35, aliveFn, nil, false, bp) then
                            Core.ClearManualInput()
                            return false, "approach_row_failed"
                        end
                    end

                    -- 1) Bersihkan batch kolom dalam reach (tx + lookahead 1-2 tile depan) & verifikasi 100% clear di server sebelum maju
                    for cleanTry = 1, 3 do
                        local clearList = {}
                        local minB, maxB = math.min(pFrom, pTo), math.max(pFrom, pTo)
                        local posNow = Core.ReadPos()
                        for stepAhead = 0, 1 do
                            local lx = tx + (stepAhead * pDir)
                            if lx < minB or lx > maxB then break end
                            if stepAhead == 0 or dfSafeReachDist(lx, corY, posNow, "break") then
                                if bp.desiredAt(lx, corY) == 0 then
                                    local lfg = Core.GetFG(lx, corY)
                                    if (lfg ~= 0 and not Core.IsProtectedTile(lfg) and Core.CanEditTile(lx, corY)) or bp.wantBgZeroAt(lx, corY) then
                                        clearList[#clearList + 1] = { lx, corY }
                                    elseif stepAhead > 0 and lfg ~= 0 then
                                        break
                                    end
                                end
                                if alsoClearAbove and corY - 1 >= bp.topY and bp.desiredAt(lx, corY - 1) == 0 then
                                    local afg = Core.GetFG(lx, corY - 1)
                                    if (afg ~= 0 and not Core.IsProtectedTile(afg) and Core.CanEditTile(lx, corY - 1)) or bp.wantBgZeroAt(lx, corY - 1) then
                                        clearList[#clearList + 1] = { lx, corY - 1 }
                                    end
                                end
                            end
                        end
                        if #clearList == 0 then break end
                        local okC = dfCleanAirTilesInReach(bp, clearList, aliveFn)
                        local txStillFg = (bp.desiredAt(tx, corY) == 0 and Core.GetFG(tx, corY) ~= 0 and not Core.IsProtectedTile(Core.GetFG(tx, corY)) and Core.CanEditTile(tx, corY))
                        local stillBg = (bp.desiredAt(tx, corY) == 0 and bp.wantBgZeroAt(tx, corY))
                            or (alsoClearAbove and corY - 1 >= bp.topY and bp.desiredAt(tx, corY - 1) == 0 and bp.wantBgZeroAt(tx, corY - 1))
                        if okC and (not txStillFg) and (not stillBg) then break end
                        task.wait(0.04)
                    end

                    -- Jika lorong tx masih terblokir solid yang tidak bisa di-break (mis. Lock), coba lompati ke tx + pDir bila atas terbuka
                    if dfIsBlocking(tx, corY) then
                        local jumpTo = tx + pDir
                        if jumpTo >= 2 and jumpTo <= bp.w - 3 and not dfIsBlocking(tx, corY - 1) and not dfIsBlocking(jumpTo, corY - 1) and dfIsStandable(jumpTo, floorY) then
                            dfManualJumpTo(jumpTo, floorY, aliveFn)
                        end
                    end

                    -- 2) Lantai bawah Lava/Batu/Kosong -> Hancurkan dulu & collect dropnya SEBELUM place Dirt (batch lookahead lantai jangkauan!)
                    local floorMaxAhead = (tx ~= pTo and floorY <= bp.maxWorkY) and 1 or 0
                    for fAhead = 0, floorMaxAhead do
                        local fx = tx + (fAhead * pDir)
                        local inBounds = (pDir > 0 and fx <= pTo) or (pDir < 0 and fx >= pTo)
                        if inBounds and bp.desiredAt(fx, floorY) == dirtId and Core.GetFG(fx, floorY) ~= dirtId
                            and not Core.IsProtectedTile(Core.GetFG(fx, floorY)) and Core.CanEditTile(fx, floorY) then
                            if fAhead == 0 or (dfSafeReachDist(fx, floorY, Core.ReadPos(), "build") and Core.GetFG(fx, corY) == 0) then
                                local okF, errF = dfFixFloorSafe(fx, floorY, dirtId, aliveFn)
                                if fAhead == 0 and not okF and errF == "no_dirt" and (Core.GetFG(fx, floorY) == 0 or not dfIsStandable(fx, floorY)) then
                                    Core.ClearManualInput()
                                    return false, "no_dirt"
                                end
                            end
                        end
                    end
                end

                local atLeftEdge = (tx == 2)
                local atRightEdge = (tx == bp.w - 3)
                if atLeftEdge or atRightEdge or tx == pTo then
                    if not dfStepWalkToX(tx + 0.5, floorY, 1.35, aliveFn, nil, false, bp) then
                        Core.ClearManualInput()
                        return false, "edge_walk_failed"
                    end
                    local sCols = atLeftEdge and { 0, 1 } or (atRightEdge and { bp.w - 2, bp.w - 1 } or {})
                    if #sCols > 0 then
                        local allowFloorShaftClean = cleanEndFloorShaft or (tx ~= xTo) or (floorY > bp.maxWorkY)
                        local edgeYs = { corY }
                        if alsoClearAbove and corY - 1 >= bp.topY then edgeYs[#edgeYs + 1] = corY - 1 end
                        if allowFloorShaftClean then edgeYs[#edgeYs + 1] = floorY end
                        dfCleanEdgeShaftAround(bp, atLeftEdge and 1 or (bp.w - 2), atLeftEdge and 0 or (bp.w - 1), edgeYs, aliveFn)
                    end
                else
                    local curStillBlocked = (bp.desiredAt(tx, corY) == 0 and Core.GetFG(tx, corY) ~= 0 and not Core.IsProtectedTile(Core.GetFG(tx, corY)) and Core.CanEditTile(tx, corY))
                    if curStillBlocked then
                        dfBreakBatchLayers({ { tx = tx, ty = corY, wantFg = true, wantBg = true } }, aliveFn)
                    end
                    local nextX = tx + pDir
                    local nextTileAirClear = (nextX >= 2 and nextX <= bp.w - 3) and (Core.GetFG(nextX, corY) == 0)
                    local nxClean = nextTileAirClear and not tileNeedsWork(nextX)
                    local okWalk = dfStepWalkToX(tx + 0.5, floorY, 1.15, aliveFn, nxClean and function(p)
                        return (pDir > 0 and p.x >= tx + 0.35) or (pDir < 0 and p.x <= tx + 0.65), "passed"
                    end or nil, nxClean, bp)
                    if not okWalk then
                        Core.ClearManualInput()
                        return false, "walk_stalled"
                    end
                    if (math.abs(tx - pFrom) % 3 == 0) or Core.CountItem(dirtId) < 25 then
                        dfQuickCollectNear(aliveFn)
                    end
                end
            end

            if pass == 2 then
                -- Kembali mulus ke xTo agar posisi akhir selalu tepat di ujung tujuan
                if math.abs(Core.ReadPos().x - (xTo + 0.5)) > 0.6 then
                    local retDir = (xTo >= Core.ReadPos().tx) and 1 or -1
                    for rx = Core.ReadPos().tx, xTo, retDir do
                        if not aliveFn() then return false, "cancelled" end
                        dfStepWalkToX(rx + 0.5, floorY, 1.0, aliveFn, (rx ~= xTo) and function(p)
                            return (retDir > 0 and p.x >= rx + 0.35) or (retDir < 0 and p.x <= rx + 0.65), "passed"
                        end or nil, rx ~= xTo, bp)
                    end
                end
                Core.ClearManualInput()
            end
        end

        Core.ClearManualInput()
        return true, "row_done"
    end

    local function dfWalkUpperShelf(bp, standFloorY, placeFloorY, xFrom, xTo, aliveFn)
        local dir = (xTo >= xFrom) and 1 or -1
        local dirtId = bp.dirtId
        local standCorY = standFloorY - 1
        local ceilCorY = placeFloorY - 1

        for pass = 1, 2 do
            local pFrom = (pass == 1) and xFrom or xTo
            local pTo = (pass == 1) and xTo or xFrom
            if pass == 2 then
                local missedX = nil
                local scanStep = (xTo >= xFrom) and 1 or -1
                for cx = xFrom, xTo, scanStep do
                    if (bp.desiredAt(cx, placeFloorY) == dirtId and Core.GetFG(cx, placeFloorY) ~= dirtId and not Core.IsProtectedTile(Core.GetFG(cx, placeFloorY)) and Core.CanEditTile(cx, placeFloorY))
                        or (bp.desiredAt(cx, standCorY) == 0 and ((Core.GetFG(cx, standCorY) ~= 0 and not Core.IsProtectedTile(Core.GetFG(cx, standCorY)) and Core.CanEditTile(cx, standCorY)) or bp.wantBgZeroAt(cx, standCorY)))
                        or (ceilCorY >= bp.topY and bp.desiredAt(cx, ceilCorY) == 0 and ((Core.GetFG(cx, ceilCorY) ~= 0 and not Core.IsProtectedTile(Core.GetFG(cx, ceilCorY)) and Core.CanEditTile(cx, ceilCorY)) or bp.wantBgZeroAt(cx, ceilCorY)))
                    then
                        missedX = cx
                        break
                    end
                end
                if not missedX then break end
                pFrom = xTo
                pTo = missedX
            end

            local pDir = (pTo >= pFrom) and 1 or -1
            for tx = pFrom, pTo, pDir do
                if type(aliveFn) == "function" and not aliveFn() then
                    Core.ClearManualInput()
                    return false, "cancelled"
                end
                H.dfSpeedForceUntil = os.clock() + 1.0

                local standPrevX = tx - pDir
                if (bp.desiredAt(tx, standCorY) == 0 and ((Core.GetFG(tx, standCorY) ~= 0 and not Core.IsProtectedTile(Core.GetFG(tx, standCorY)) and Core.CanEditTile(tx, standCorY)) or bp.wantBgZeroAt(tx, standCorY))) then
                    if dfIsStandable(standPrevX, standFloorY) and math.abs(Core.ReadPos().x - (standPrevX + 0.5)) > 1.25 then
                        dfStepWalkToX(standPrevX + 0.5, standFloorY, 1.0, aliveFn, nil, false, bp)
                    end
                    dfCleanAirTilesInReach(bp, { { tx, standCorY } }, aliveFn)
                end

                if bp.desiredAt(tx, standFloorY) == dirtId and Core.GetFG(tx, standFloorY) ~= dirtId then
                    if dfIsStandable(standPrevX, standFloorY) and math.abs(Core.ReadPos().x - (standPrevX + 0.5)) > 1.25 then
                        dfStepWalkToX(standPrevX + 0.5, standFloorY, 1.0, aliveFn, nil, false, bp)
                    end
                    local okFloor, errF = dfFixFloorSafe(tx, standFloorY, dirtId, aliveFn)
                    if not okFloor and not dfIsStandable(tx, standFloorY) then
                        Core.ClearManualInput()
                        return false, errF or "no_dirt"
                    end
                end

                if not dfStepWalkToX(tx + 0.5, standFloorY, 1.15, aliveFn, nil, false, bp) then
                    Core.ClearManualInput()
                    return false, "upper_walk_failed"
                end

                local upperAir = {}
                if ceilCorY >= bp.topY and bp.desiredAt(tx, ceilCorY) == 0 then
                    upperAir[#upperAir + 1] = { tx, ceilCorY }
                end
                if placeFloorY >= bp.topY and bp.desiredAt(tx, placeFloorY) == 0 then
                    upperAir[#upperAir + 1] = { tx, placeFloorY }
                end
                if #upperAir > 0 then
                    dfCleanAirTilesInReach(bp, upperAir, aliveFn)
                end
                if tx == 2 or tx == bp.w - 3 then
                    local sInU = (tx == 2) and 1 or (bp.w - 2)
                    local sOutU = (tx == 2) and 0 or (bp.w - 1)
                    local ysU = { standCorY }
                    if placeFloorY >= bp.topY then ysU[#ysU + 1] = placeFloorY end
                    if ceilCorY >= bp.topY then ysU[#ysU + 1] = ceilCorY end
                    dfCleanEdgeShaftAround(bp, sInU, sOutU, ysU, aliveFn)
                end

                if placeFloorY >= bp.topY and bp.desiredAt(tx, placeFloorY) == dirtId and Core.GetFG(tx, placeFloorY) ~= dirtId then
                    if Core.CountItem(dirtId) <= 0 then dfQuickCollectNear(aliveFn, dirtId, true) end
                    local okP, errP = dfFixFloorSafe(tx, placeFloorY, dirtId, aliveFn)
                    if not okP and errP == "no_dirt" then
                        Core.ClearManualInput()
                        return false, "no_dirt"
                    end
                end
                if (math.abs(tx - pFrom) % 3 == 0) then
                    dfQuickCollectNear(aliveFn)
                end
            end

            if pass == 2 and math.abs(Core.ReadPos().x - (xTo + 0.5)) > 0.6 then
                dfStepWalkToX(xTo + 0.5, standFloorY, 3.0, aliveFn, nil, false, bp)
            end
        end

        Core.ClearManualInput()
        return true, "upper_row_done"
    end

    DirtFarm._impl = {
        dfQuickCollectNear = dfQuickCollectNear,
        dfSettleGrounded = dfSettleGrounded,
        dfStepWalkToX = dfStepWalkToX,
        dfCleanAirTilesInReach = dfCleanAirTilesInReach,
        dfCleanEdgeShaftAround = dfCleanEdgeShaftAround,
        dfClimbShaftToFloorY = dfClimbShaftToFloorY,
        dfTransitionToLowerRow = dfTransitionToLowerRow,
        dfWalkCorridorLower = dfWalkCorridorLower,
        dfWalkUpperShelf = dfWalkUpperShelf,
    }
end

function DirtFarm.Start()
    Core.EnsureInit()
    Core.EnsureManualInputHook()
    Core.SyncOneHitHook()
    pcall(function()
        local tb = UserInputService and UserInputService:GetFocusedTextBox()
        if tb then tb:ReleaseFocus() end
    end)
    local gt = H.gt
    if not gt or gt.name == "" then
        setDfStatus("Belum masuk world!")
        return false
    end
    if DirtFarm.State.running then return true end
    DirtFarm.State.running = true
    DirtFarm.State.switchingWorld = false
    DirtFarm.State.sessionToken += 1
    H.dfSpeedForceUntil = os.clock() + 1.5
    local tok = DirtFarm.State.sessionToken
    local function alive() return DirtFarm.State.running and DirtFarm.State.sessionToken == tok end
    if UIHooks.updateButtons then UIHooks.updateButtons() end

    DirtFarm.State.thread = task.spawn(function()
        local impl = DirtFarm._impl
        local lastWorldTracked = ""
        local noDirtRetries = 0
        local lowerSweptForWorld, upperSweptForWorld = false, false

        local function rowHasLowerWork(bp, corY, alsoAbove)
            local flY = corY + 1
            for x = 0, bp.w - 1 do
                local wc = bp.desiredAt(x, corY)
                if wc ~= nil and (Core.GetFG(x, corY) ~= wc or (wc == 0 and bp.wantBgZeroAt(x, corY))) then
                    return true
                end
                if flY <= bp.maxWorkY then
                    local wf = bp.desiredAt(x, flY)
                    if wf ~= nil and (Core.GetFG(x, flY) ~= wf or (wf == 0 and bp.wantBgZeroAt(x, flY))) then
                        return true
                    end
                end
                if alsoAbove and corY - 1 >= bp.topY then
                    local wa = bp.desiredAt(x, corY - 1)
                    if wa ~= nil and (Core.GetFG(x, corY - 1) ~= wa or (wa == 0 and bp.wantBgZeroAt(x, corY - 1))) then
                        return true
                    end
                end
            end
            return false
        end

        local function rowHasUpperWork(bp, pY)
            local standY = pY + 2
            local standCorY = standY - 1
            local ceilCorY = pY - 1
            for x = 0, bp.w - 1 do
                local wp = bp.desiredAt(x, pY)
                if wp ~= nil and (Core.GetFG(x, pY) ~= wp or (wp == 0 and bp.wantBgZeroAt(x, pY))) then
                    return true
                end
                local ws = bp.desiredAt(x, standCorY)
                if ws ~= nil and (Core.GetFG(x, standCorY) ~= ws or (ws == 0 and bp.wantBgZeroAt(x, standCorY))) then
                    return true
                end
                if ceilCorY >= bp.topY then
                    local wc = bp.desiredAt(x, ceilCorY)
                    if wc ~= nil and (Core.GetFG(x, ceilCorY) ~= wc or (wc == 0 and bp.wantBgZeroAt(x, ceilCorY))) then
                        return true
                    end
                end
            end
            return false
        end

        local function isWorldDfComplete(bp)
            for y = bp.topY, bp.maxWorkY do
                for x = 0, bp.w - 1 do
                    local want = bp.desiredAt(x, y)
                    if want ~= nil then
                        if Core.GetFG(x, y) ~= want then return false end
                        if want == 0 and bp.wantBgZeroAt(x, y) then return false end
                    end
                end
            end
            return true
        end

        local function moveVerticallyViaEdgeShaft(bp, targetFloorY, dirtId)
            local pos = Core.ReadPos()
            local curFloorY = math.floor(pos.y + 0.5)
            local atLeft = (pos.tx < bp.midX)
            local edgeX = atLeft and 2 or (bp.w - 3)
            local sIn = atLeft and 1 or (bp.w - 2)
            local sOut = atLeft and 0 or (bp.w - 1)

            if math.abs(pos.x - (edgeX + 0.5)) > 1.2 then
                local curCor = curFloorY - 1
                impl.dfWalkCorridorLower(bp, curCor, pos.tx, edgeX, false, alive, false)
            end

            if not alive() then return false end
            pos = Core.ReadPos()
            curFloorY = math.floor(pos.y + 0.5)
            if curFloorY < targetFloorY then
                while curFloorY < targetFloorY and alive() do
                    local curCor = curFloorY - 1
                    local stepCor = math.min(targetFloorY - 1, curCor + 2)
                    local okT = impl.dfTransitionToLowerRow(bp, sIn, sOut, edgeX, curCor, stepCor, dirtId, alive)
                    if not okT then return false end
                    curFloorY = math.floor(Core.ReadPos().y + 0.5)
                end
            elseif curFloorY > targetFloorY then
                local okC = impl.dfClimbShaftToFloorY(bp, sIn, sOut, targetFloorY, dirtId, alive, edgeX)
                if not okC then return false end
            end
            impl.dfCleanEdgeShaftAround(bp, sIn, sOut, { targetFloorY - 2, targetFloorY - 1, targetFloorY, targetFloorY + 1 }, alive)
            return math.abs(Core.ReadPos().y - targetFloorY) <= 0.65
        end

        local function dfFarmDirtIfLow(bp, dirtId)
            local seedId = resolveDirtSeedId(dirtId)
            local groundCor = bp.groundY - 1
            if groundCor < bp.topY or groundCor > bp.maxWorkY then return false end
            if not moveVerticallyViaEdgeShaft(bp, bp.groundY, dirtId) then
                return false
            end

            local curP = Core.ReadPos()
            local startX = (curP.tx < bp.midX) and 2 or (bp.w - 3)
            local endX = (startX == 2) and (bp.w - 3) or 2
            local dir = (endX >= startX) and 1 or -1

            -- 1. Collect drop Dirt & harvest tree matang di groundCor
            setDfStatus("[DF] Kumpulkan Dirt / Harvest Tree...")
            for tx = startX, endX, dir do
                if not alive() then return false end
                local fg = Core.GetFG(tx, groundCor)
                if fg == seedId and Core.IsTreeRipe(tx, groundCor) then
                    if math.abs(Core.ReadPos().x - (tx + 0.5)) > 1.8 then
                        impl.dfStepWalkToX(tx + 0.5, bp.groundY, 1.4, alive, nil, false, bp)
                    end
                    impl.dfCleanAirTilesInReach(bp, { { tx, groundCor } }, alive)
                elseif math.abs(tx - startX) % 4 == 0 then
                    if dfIsStandable(tx, bp.groundY) then
                        impl.dfStepWalkToX(tx + 0.5, bp.groundY, 1.2, alive, nil, false, bp)
                    end
                    impl.dfQuickCollectNear(alive, dirtId, true)
                end
                if Core.CountItem(dirtId) >= 60 then
                    impl.dfQuickCollectNear(alive, dirtId, true)
                    return true
                end
            end
            impl.dfQuickCollectNear(alive, dirtId, true)
            if Core.CountItem(dirtId) >= 20 then return true end

            -- 2. Tanam Dirt Seed secukupnya di groundCor (di luar safety moat door) jika punya seed
            local haveSeed = Core.CountItem(seedId)
            if haveSeed <= 0 then return Core.CountItem(dirtId) > 0 end
            local planted = {}
            local maxPlant = math.min(28, haveSeed)
            setDfStatus(string.format("[DF] Tanam %d Dirt Seed untuk bahan Dirt...", maxPlant))
            for tx = endX, startX, -dir do
                if not alive() or #planted >= maxPlant or Core.CountItem(seedId) <= 0 then break end
                if math.abs(tx - bp.doorX) > 3 and Core.GetFG(tx, groundCor) == 0 and Core.IsPlantable(tx, groundCor) then
                    if math.abs(Core.ReadPos().x - (tx + 0.5)) > 1.8 and dfIsStandable(tx, bp.groundY) then
                        impl.dfStepWalkToX(tx + 0.5, bp.groundY, 1.2, alive, nil, false, bp)
                    end
                    if Core.IsInActionReach(tx, groundCor, "build") then
                        local okPl = Packets.PlaceVerified(tx, groundCor, seedId, 1, {
                            showHand = DirtFarm.State.showHand, delay = 0, noLocalMirror = false,
                            retries = 2, placeGap = 0.175, shouldContinue = alive,
                        })
                        if okPl or Core.GetFG(tx, groundCor) == seedId then
                            planted[#planted + 1] = { x = tx, y = groundCor }
                        end
                    end
                end
            end
            if #planted == 0 then return Core.CountItem(dirtId) > 0 end

            -- 3. Tunggu pohon matang lalu harvest + collect semua Dirt
            local waitDl = os.clock() + 40
            while alive() and os.clock() < waitDl do
                local ripeAny, stillAny = false, false
                for _, pt in ipairs(planted) do
                    if Core.GetFG(pt.x, pt.y) == seedId then
                        stillAny = true
                        if Core.IsTreeRipe(pt.x, pt.y) then ripeAny = true end
                    end
                end
                if not stillAny or ripeAny then break end
                local rem = Core.GetTreeRemainingSec(planted[1].x, planted[1].y)
                setDfStatus(string.format("[DF] Tunggu Dirt Tree (%ds)...", math.ceil(tonumber(rem) or 1)))
                task.wait(0.8)
            end
            for _, pt in ipairs(planted) do
                if not alive() then return false end
                if Core.GetFG(pt.x, pt.y) == seedId then
                    local waitEach = os.clock() + 25
                    while alive() and os.clock() < waitEach and not Core.IsTreeRipe(pt.x, pt.y) and Core.GetFG(pt.x, pt.y) == seedId do
                        task.wait(0.4)
                    end
                    if dfIsStandable(pt.x, bp.groundY) then
                        impl.dfStepWalkToX(pt.x + 0.5, bp.groundY, 1.4, alive, nil, false, bp)
                    end
                    if Core.GetFG(pt.x, pt.y) == seedId then
                        Packets.BreakVerified({ { tx = pt.x, ty = pt.y, layer = 1 } }, {
                            threads = 1, layer = 1, oneHit = false, customHits = nil,
                            hitDelay = 0.194, verifyTimeout = 0.28, showHand = DirtFarm.State.showHand,
                            showVisual = true, noLocalMirror = true, autoRange = false, shouldContinue = alive,
                        })
                    end
                    impl.dfQuickCollectNear(alive, dirtId, true)
                end
            end
            return Core.CountItem(dirtId) > 0
        end

        while alive() do
            if evaluateSeems() then break end
            Core.EnsureInit()
            Core.EnsureManualInputHook()
            H.dfSpeedForceUntil = os.clock() + 1.5
            gt = H.gt
            if not gt or gt.name == "" then
                Core.ClearManualInput()
                setDfStatus("Menunggu world...")
                task.wait(0.5)
            else
                local curW = cleanWorldName(gt.name)
                if curW ~= lastWorldTracked then
                    lastWorldTracked = curW
                    noDirtRetries = 0
                    lowerSweptForWorld, upperSweptForWorld = false, false
                end

                local rotQ = DirtFarm.State.rotationWorlds or {}
                local readyToFarm = true
                if #rotQ > 0 then
                    local inQueue = false
                    for _, wn in ipairs(rotQ) do
                        if wn == curW then inQueue = true; break end
                    end
                    if not inQueue then
                        local firstW = rotQ[1]
                        if firstW and firstW ~= "" and firstW ~= curW then
                            readyToFarm = false
                            local ed = getEnv().__SYT_ENV_DATA or {}
                            getEnv().__SYT_ENV_DATA = ed
                            ed.rotSession = {
                                mode = "DirtFarm",
                                targetWorld = firstW,
                                worlds = DirtFarm._syncEnvQueue(rotQ),
                                active = true,
                                updatedAt = os.clock(),
                            }
                            DirtFarm.State.switchingWorld = true
                            setDfStatus("[DF] Masuk antrian world: " .. firstW)
                            local okWarp = Packets.EnterWorldDoor(firstW, alive)
                            DirtFarm.State.switchingWorld = false
                            if not alive() then break end
                            if not okWarp then
                                setDfStatus("[DF] Gagal masuk " .. firstW .. ", tunggu...")
                                task.wait(1.6)
                            else
                                lowerSweptForWorld, upperSweptForWorld = false, false
                            end
                        end
                    else
                        local ed = getEnv().__SYT_ENV_DATA or {}
                        getEnv().__SYT_ENV_DATA = ed
                        ed.rotSession = {
                            mode = "DirtFarm",
                            targetWorld = curW,
                            worlds = DirtFarm._syncEnvQueue(rotQ),
                            active = true,
                            updatedAt = os.clock(),
                        }
                    end
                end

                if readyToFarm then
                local bp = buildDfBlueprint(gt)
                local dirtId = bp.dirtId

                -- Stage 1A: Zigzag optimal kiri<->kanan (mulai bersih ke kiri dulu bila di tengah/kanan agar tidak lari kosong ke pojok kanan, lalu zigzag rapat turun kebawah)
                if not lowerSweptForWorld then
                    local lowerCors = {}
                    local cy = bp.doorY
                    while cy <= bp.maxWorkY do
                        if cy == bp.maxWorkY - 1 and bp.desiredAt(2, bp.maxWorkY) == 0 then
                            lowerCors[#lowerCors + 1] = { corY = bp.maxWorkY, above = true }
                            break
                        else
                            lowerCors[#lowerCors + 1] = { corY = cy, above = false }
                            if cy == bp.maxWorkY then break end
                            cy += 2
                        end
                    end

                    -- Sweep baris awal optimal: bila di tengah/agak kanan, sapu kiri dulu (pos0.tx->2) baru lurus kanan (2->w-3) supaya zero jalan mundur/lambat 1-1!
                    local pos0 = Core.ReadPos()
                    local firstCurFloor = math.floor(pos0.y + 0.5)
                    if firstCurFloor >= 2 and firstCurFloor <= bp.maxWorkY + 1 then
                        if pos0.tx > 8 and pos0.tx < bp.w - 10 then
                            setDfStatus(string.format("[DF] Sapu Cepat Kiri (%d->2)...", pos0.tx))
                            impl.dfWalkCorridorLower(bp, firstCurFloor - 1, pos0.tx, 2, false, alive, false, true)
                        elseif pos0.tx > 2 and pos0.tx <= 8 then
                            setDfStatus("[DF] Masuk ujung kiri x=2...")
                            impl.dfWalkCorridorLower(bp, firstCurFloor - 1, pos0.tx, 2, false, alive, false, true)
                        elseif pos0.tx < bp.w - 3 and pos0.tx >= bp.w - 10 then
                            setDfStatus(string.format("[DF] Masuk ujung kanan x=%d...", bp.w - 3))
                            impl.dfWalkCorridorLower(bp, firstCurFloor - 1, pos0.tx, bp.w - 3, false, alive, false, true)
                        end
                    end

                    local sweptAllLower = true
                    for i = 1, #lowerCors do
                        if not alive() or evaluateSeems() then sweptAllLower = false; break end
                        local rowInfo = lowerCors[i]
                        local rCorY = rowInfo.corY
                        local targetFloorY = rCorY + 1
                        if rowHasLowerWork(bp, rCorY, rowInfo.above) then
                            local curP = Core.ReadPos()
                            if math.abs(curP.y - targetFloorY) > 0.55 then
                                setDfStatus(string.format("[DF] Turun ujung ke y=%d...", rCorY))
                                if not moveVerticallyViaEdgeShaft(bp, targetFloorY, dirtId) then
                                    sweptAllLower = false
                                    break
                                end
                            end

                            curP = Core.ReadPos()
                            local atLeft = (curP.tx < bp.midX)
                            local xStart = atLeft and 2 or (bp.w - 3)
                            local xEnd = atLeft and (bp.w - 3) or 2
                            if math.abs(curP.x - (xStart + 0.5)) > 1.2 then
                                if not impl.dfWalkCorridorLower(bp, rCorY, curP.tx, xStart, rowInfo.above, alive, false) then
                                    sweptAllLower = false
                                    break
                                end
                            end

                            local hasMoreRowsBelow = (i < #lowerCors)
                            setDfStatus(string.format("[DF] Zigzag Bawah y=%d (%d->%d)", rCorY, xStart, xEnd))
                            local okRow, errRow = impl.dfWalkCorridorLower(bp, rCorY, xStart, xEnd, rowInfo.above, alive, not hasMoreRowsBelow)
                            if not okRow then
                                if errRow == "no_dirt" then
                                    noDirtRetries += 1
                                    if dfFarmDirtIfLow(bp, dirtId) then
                                        noDirtRetries = 0
                                    end
                                end
                                sweptAllLower = false
                                break
                            end
                            noDirtRetries = 0
                        end
                    end

                    Core.ClearManualInput()
                    if sweptAllLower then
                        -- Cek apakah masih ada sisa di baris bawah mana pun sebelum lanjut ke atas
                        local anyLowerLeft = false
                        for _, rowInfo in ipairs(lowerCors) do
                            if rowHasLowerWork(bp, rowInfo.corY, rowInfo.above) then
                                anyLowerLeft = true
                                break
                            end
                        end
                        if not anyLowerLeft then
                            lowerSweptForWorld = true
                        end
                    end
                end

                -- Stage 1B: Zigzag Bagian Atas (groundY - 2 -> topY, bottom-to-top) lewat 2 kolom ujung (kiri/kanan)
                if alive() and lowerSweptForWorld and not upperSweptForWorld then
                    local upperPlaceRows = {}
                    local uy = bp.groundY - 2
                    while uy >= bp.topY do
                        upperPlaceRows[#upperPlaceRows + 1] = uy
                        uy -= 2
                    end

                    local sweptAllUpper = true
                    if #upperPlaceRows > 0 then
                        for i = 1, #upperPlaceRows do
                            if not alive() or evaluateSeems() then sweptAllUpper = false; break end
                            local pY = upperPlaceRows[i]
                            local standY = pY + 2
                            if rowHasUpperWork(bp, pY) then
                                if Core.CountItem(dirtId) <= 0 then
                                    impl.dfQuickCollectNear(alive, dirtId, true)
                                end
                                if Core.CountItem(dirtId) <= 0 then
                                    noDirtRetries += 1
                                    setDfStatus(string.format("Dirt kurang! Farm Dirt Tree (%d/3)...", noDirtRetries))
                                    if dfFarmDirtIfLow(bp, dirtId) then
                                        noDirtRetries = 0
                                    else
                                        task.wait(0.45)
                                    end
                                    sweptAllUpper = false
                                    break
                                end

                                setDfStatus(string.format("[DF] Naik Shaft ke Rak Atas y=%d...", standY))
                                if not moveVerticallyViaEdgeShaft(bp, standY, dirtId) then
                                    sweptAllUpper = false
                                    break
                                end

                                local curP = Core.ReadPos()
                                local atLeft = (curP.tx < bp.midX)
                                local xStart = atLeft and 2 or (bp.w - 3)
                                local xEnd = atLeft and (bp.w - 3) or 2
                                setDfStatus(string.format("[DF] Build Atas y=%d (%d->%d)", pY, xStart, xEnd))
                                local okUp, errUp = impl.dfWalkUpperShelf(bp, standY, pY, xStart, xEnd, alive)
                                if not okUp then
                                    if errUp == "no_dirt" then noDirtRetries += 1 end
                                    sweptAllUpper = false
                                    break
                                end
                                noDirtRetries = 0
                            end
                        end
                    end
                    Core.ClearManualInput()
                    if sweptAllUpper then
                        local anyUpperLeft = false
                        for _, pY in ipairs(upperPlaceRows) do
                            if rowHasUpperWork(bp, pY) then anyUpperLeft = true; break end
                        end
                        if not anyUpperLeft then
                            upperSweptForWorld = true
                        end
                    end
                end

                if not alive() then break end

                if isWorldDfComplete(bp) then
                    Core.ClearManualInput()
                    if DirtFarm.State.autoCollect then
                        impl.dfQuickCollectNear(alive, nil, true)
                    end
                    local rot = DirtFarm.State.rotationWorlds or {}
                    for ri = #rot, 1, -1 do
                        if rot[ri] == curW then table.remove(rot, ri) end
                    end
                    DirtFarm.State.rotationText = table.concat(rot, ", ")
                    local savedRot = DirtFarm._syncEnvQueue(rot)
                    if UIHooks.refreshDfList then UIHooks.refreshDfList() end

                    local nextWorld = nil
                    for _, wn in ipairs(rot) do
                        if wn ~= curW then nextWorld = wn; break end
                    end

                    local ed = getEnv().__SYT_ENV_DATA or {}
                    getEnv().__SYT_ENV_DATA = ed
                    if nextWorld and nextWorld ~= "" then
                        ed.rotSession = {
                            mode = "DirtFarm",
                            targetWorld = nextWorld,
                            worlds = savedRot,
                            active = true,
                            updatedAt = os.clock(),
                        }
                        setDfStatus(string.format("[%s] BERSIH -> Pindah ke %s", curW, nextWorld))
                        emitNotify("SYT Dirt Farm", string.format("DF %s selesai! Pindah ke %s...", curW, nextWorld))
                        DirtFarm.State.switchingWorld = true
                        local okNext = Packets.EnterWorldDoor(nextWorld, alive)
                        DirtFarm.State.switchingWorld = false
                        lowerSweptForWorld, upperSweptForWorld = false, false
                        if not okNext and alive() then
                            task.wait(1.6)
                        end
                    else
                        ed.rotSession = nil
                        setDfStatus(string.format("Selesai! World %s Dirt Farm Selesai", curW))
                        emitNotify("SYT Dirt Farm", "Dirt Farm selesai di world " .. curW)
                        DirtFarm.State.running = false
                        break
                    end
                else
                    if noDirtRetries >= 3 then
                        local ed = getEnv().__SYT_ENV_DATA
                        if type(ed) == "table" then ed.rotSession = nil end
                        setDfStatus("Dirt habis! Siapkan Dirt di inventory.")
                        DirtFarm.State.running = false
                        break
                    end
                    -- Reset sweep flag supaya siklus berikutnya membereskan baris tersisa lewat koridor & shaft ujung (tanpa A* hancurkan lantai)
                    lowerSweptForWorld = false
                    upperSweptForWorld = false
                    task.wait(0.25)
                end
                end
            end
            task.wait(0.05)
        end

        H.dfSpeedForceUntil = 0
        Core.ClearManualInput()
        DirtFarm.State.switchingWorld = false
        if DirtFarm.State.sessionToken == tok then
            DirtFarm.State.running = false
            DirtFarm.State.thread = nil
            if DirtFarm.State.status == "Idle" or string.find(DirtFarm.State.status, "[", 1, true) then
                setDfStatus("Stopped")
            end
        end
        if UIHooks.updateButtons then UIHooks.updateButtons() end
    end)
    return true
end

function DirtFarm.Stop(keepSaved)
    DirtFarm.State.running = false
    DirtFarm.State.switchingWorld = false
    H.dfSpeedForceUntil = 0
    DirtFarm.State.sessionToken += 1
    Core.ClearManualInput()
    if DirtFarm.State.thread then
        pcall(task.cancel, DirtFarm.State.thread)
        DirtFarm.State.thread = nil
    end
    if not keepSaved then
        local ed = getEnv().__SYT_ENV_DATA
        if type(ed) == "table" and ed.rotSession and ed.rotSession.mode == "DirtFarm" then
            ed.rotSession = nil
        end
    end
    setDfStatus("Stopped")
end

function DirtFarm.Toggle()
    if DirtFarm.State.running then
        DirtFarm.Stop()
        return false
    end
    return DirtFarm.Start()
end

-- V4 [SPOOFER & VISUALISASI]
local VISUAL_ROLES = { "none", "developer", "moderator", "admin", "owner", "vip", "royal", "legend", "sponsor", "supporter", "dr" }
local VISUAL_EFFECTS = { "None", "Rainbow Wave", "Sponsor Sparkle", "Supporter Wave", "Legend Gold", "Royal Pulse", "Creator Tag", "Color Prefix" }
local VISUAL_TITLES = { "none", "legend", "dr", "cc", "sponsor", "supporter", "royal" }

local ROLE_BADGES = {}

local Visual = {
    Presets = {
        roles         = VISUAL_ROLES,
        effects       = VISUAL_EFFECTS,
        titles        = VISUAL_TITLES,
        guildRanks    = { "None (Real)", "2: (GE) Member", "3: (GC) Officer", "4: (GL) Leader", "Custom Text Prefix" },
        countries     = { "Real (Unchanged)", "id", "us", "my", "sg", "ph", "jp", "kr", "gb", "de", "br", "00" },
        boosterColors = {
            ["Default (Real)"] = false,
            ["Magenta Glow"]   = Color3.fromRGB(244, 127, 255),
            ["Gold Emperor"]   = Color3.fromRGB(255, 215, 70),
            ["Cyan Neon"]      = Color3.fromRGB(80, 235, 255),
            ["Crimson Red"]    = Color3.fromRGB(255, 75, 95),
            ["Emerald"]        = Color3.fromRGB(70, 240, 145),
            ["Pure White"]     = Color3.fromRGB(255, 255, 255),
        },
        boosterColorNames = { "Default (Real)", "Magenta Glow", "Gold Emperor", "Cyan Neon", "Crimson Red", "Emerald", "Pure White" },
        wearSlots = { "back", "hand", "hat", "hair", "shirt", "pants", "feet", "face", "neck", "chest", "ances", "mask", "ring", "pet" },
        outfitPresets = {
            "Real (Server Outfit)",
            "Legend Gold Mix",
            "Dev Glitch / Void",
            "Dragon & Wings Mix",
            "Farming / Pickaxe Look",
            "Clear All Clothes (Naked)",
        },
        skinNames = {
            "Real (Server Skin)", "Default Fair", "Pale Ivory", "Warm Tan", "Deep Bronze",
            "Zombie Green", "Frost Cyan", "Crimson Devil", "Shadow Black", "Golden Idol",
            "Void Purple", "Ghost (See-Through)",
        },
        skins = {
            ["Default Fair"]  = Color3.fromRGB(255, 214, 178),
            ["Pale Ivory"]    = Color3.fromRGB(255, 236, 220),
            ["Warm Tan"]      = Color3.fromRGB(224, 172, 105),
            ["Deep Bronze"]   = Color3.fromRGB(141, 85, 36),
            ["Zombie Green"]  = Color3.fromRGB(120, 210, 120),
            ["Frost Cyan"]    = Color3.fromRGB(130, 230, 255),
            ["Crimson Devil"] = Color3.fromRGB(220, 70, 70),
            ["Shadow Black"]  = Color3.fromRGB(45, 45, 55),
            ["Golden Idol"]   = Color3.fromRGB(255, 210, 80),
            ["Void Purple"]   = Color3.fromRGB(155, 90, 235),
        },
        weatherNames = {
            "Real (Server Weather)",
            "Rainin' Gems (13690)",
            "Heatwave (3694)",
            "Apocalypse (4242)",
            "Night (8896)",
            "Spooky (984)",
            "Snowy (1210)",
            "Meteor Shower (8836)",
            "Stargazing (7644)",
            "Digital Rain (6280)",
            "Black Hole (13640)",
            "Holiday Haven (14032)",
            "Emerald City (15240)",
            "Atlantis (14598)",
            "Paradise City (16406)",
            "Realm of Spirits (13070)",
            "Bedawang Nala (16282)",
        },
        weatherIds = {
            ["Real (Server Weather)"]    = 0,
            ["Rainin' Gems (13690)"]     = 13690,
            ["Heatwave (3694)"]          = 3694,
            ["Apocalypse (4242)"]        = 4242,
            ["Night (8896)"]             = 8896,
            ["Spooky (984)"]             = 984,
            ["Snowy (1210)"]             = 1210,
            ["Meteor Shower (8836)"]     = 8836,
            ["Stargazing (7644)"]        = 7644,
            ["Digital Rain (6280)"]      = 6280,
            ["Black Hole (13640)"]       = 13640,
            ["Holiday Haven (14032)"]    = 14032,
            ["Emerald City (15240)"]     = 15240,
            ["Atlantis (14598)"]         = 14598,
            ["Paradise City (16406)"]    = 16406,
            ["Realm of Spirits (13070)"] = 13070,
            ["Bedawang Nala (16282)"]    = 16282,
        },
    },
    State = {
        customName = "", role = "none", effect = "None", colorCode = "", customTitle = "none",
        guildTag = "", guildMode = "None (Real)", country = "Real (Unchanged)",
        booster = false, boosterColor = "Default (Real)",
        spoofDr = false, spoofLegend = false, spoofStillTag = false, spoofLevel = 0,
        tilesName = false, hideName = false, lockNames = false,
        -- Outfit / Skin / Weather / Gems spoof state
        outfitPreset = "Real (Server Outfit)", selectedSlot = "back", wearSearch = "", customSlotId = "",
        fakeWorn = {}, skinPreset = "Real (Server Skin)", ghostSkin = false,
        weatherName = "Real (Server Weather)", weatherId = 0, _appliedWeatherId = nil,
        fakeGemsActive = false, fakeGemsValue = 0, origGems = nil,
        -- Snapshots
        lastWorldName = "", lastPosKey = "", origSaved = false,
        origNick = nil, origGameName = nil, origTag = nil, origOwnTitle = nil, origWornTitle = nil,
        origDrTitle = nil, origHasLegend = nil, origHideLegend = nil, origHideDr = nil, origStillTag = nil,
        origRoleAttr = nil, origTitleAttr = nil, origGuildRank = nil, origBooster = nil,
        origBoosterColor = nil, origCountry = nil, origLevel = nil, origPlayerLevel = nil,
        origWorn = nil, origWornSavedFor = nil,
        origSkin = nil, origSkinSavedFor = nil,
        origSkinT = nil, origSkinTSavedFor = nil,
    }
}
SYT_Logic.Visual = Visual
SYT_Logic.Spoofer = Visual

local function findNameTag()
    local pg = LP and LP:FindFirstChildOfClass("PlayerGui")
    local gg = pg and pg:FindFirstChild("GameGui")
    if not gg then return nil end
    for _, obj in ipairs(gg:GetDescendants()) do
        if obj.Name == "NameTag" and obj:IsA("GuiObject") then return obj end
    end
    return nil
end

local function refreshNameTagObj()
    if type(H.nameTagObj) == "table" then
        H.nameTagObj.shownKey = nil
        if type(H.nameTagObj.redraw) == "function" then
            pcall(H.nameTagObj.redraw)
        end
    end
    local tag = findNameTag()
    if tag then tag.Visible = not Visual.State.hideName end
end

local function ensureVisualRefs()
    Core.EnsureInit()
    if H.gt and (not H.skillsObj or not H.nameTagObj or not H.wornTbl or not H.playerSpriteObj) then
        pcall(inspectUpvalues, H.gt)
    end
    Core.InstallGetgcBypassHooks()
end

local function saveOrigVisual()
    local S = Visual.State
    if S.origSaved or not LP then return end
    S.origSaved        = true
    S.origNick         = LP:GetAttribute("Nick")
    S.origGameName     = LP:GetAttribute("GameName")
    S.origTag          = LP:GetAttribute("Tag")
    S.origOwnTitle     = LP:GetAttribute("OwnTitle")
    S.origWornTitle    = LP:GetAttribute("WornTitle")
    S.origDrTitle      = LP:GetAttribute("DrTitle")
    S.origHasLegend    = LP:GetAttribute("HasLegend")
    S.origHideLegend   = LP:GetAttribute("HideLegendUntil")
    S.origHideDr       = LP:GetAttribute("HideDrUntil")
    S.origStillTag     = LP:GetAttribute("StillTag")
    S.origGuildRank    = LP:GetAttribute("GuildRank")
    S.origBooster      = LP:GetAttribute("DiscordBooster")
    S.origBoosterColor = LP:GetAttribute("DiscordColor")
    S.origCountry      = LP:GetAttribute("Country")
    S.origLevel        = LP:GetAttribute("Level")
    S.origPlayerLevel  = LP:GetAttribute("PlayerLevel")
    local k = "u" .. tostring(LP.UserId)
    local sr, tl = ReplicatedStorage:FindFirstChild("StaffRoles"), ReplicatedStorage:FindFirstChild("TitleList")
    S.origRoleAttr  = sr and sr:GetAttribute(k) or nil
    S.origTitleAttr = tl and tl:GetAttribute(k) or nil
end

local function wrapVisualEffect(text, effectName, colorPrefix)
    local spanMap = {
        ["Rainbow Wave"] = "rainbow",
        ["Sponsor Sparkle"] = "sponsor",
        ["Supporter Wave"] = "supporter",
        ["Patron Aura"] = "patron",
        ["Benefactor Neon"] = "benefactor",
        ["Super Sponsor"] = "supersponsor",
        ["Legend Gold"] = "legend",
        ["Royal Pulse"] = "royal",
        ["Creator Tag"] = "cc",
    }
    local sp = spanMap[tostring(effectName or "")]
    if sp then
        return "`{" .. sp .. "}" .. text .. "`}"
    elseif effectName == "Color Prefix" and colorPrefix ~= "" then
        return colorPrefix .. text .. "``"
    end
    return (colorPrefix ~= "") and (colorPrefix .. text .. "``") or text
end

function Visual.HasActiveSpoof()
    local S = Visual.State
    if S.lockNames or S.tilesName or S.hideName or S.customName ~= "" or S.role ~= "none"
        or S.effect ~= "None" or S.colorCode ~= "" or S.customTitle ~= "none"
        or S.guildMode ~= "None (Real)" or S.country ~= "Real (Unchanged)"
        or S.booster or (S.boosterColor and S.boosterColor ~= "Default (Real)")
        or S.spoofDr or S.spoofLegend or S.spoofStillTag or (tonumber(S.spoofLevel) or 0) > 0
        or S.skinPreset ~= "Real (Server Skin)" or S.ghostSkin or (tonumber(S.weatherId) or 0) > 0
        or S.fakeGemsActive then
        return true
    end
    for _, _ in pairs(S.fakeWorn) do
        return true
    end
    return false
end

function Visual.FindWearableByKeywords(slotName, keywords, fallbackId)
    ensureVisualRefs()
    local db = H.ItemDB
    if type(db) == "table" then
        for _, kw in ipairs(keywords) do
            local kwLow = string.lower(kw)
            for id, info in pairs(db) do
                if type(id) == "number" and type(info) == "table" and info.slot == slotName and type(info.name) == "string" then
                    if string.find(string.lower(info.name), kwLow, 1, true) then
                        return id
                    end
                end
            end
        end
    end
    return fallbackId
end

function Visual.GetWearableOptionsForSlot(slotName, searchFilter)
    ensureVisualRefs()
    local out = { "Default (Keep Real)", "Kosong / Remove (0)" }
    local db = H.ItemDB
    if type(db) ~= "table" then return out end
    local filt = string.lower(tostring(searchFilter or ""))
    local matches = {}
    for id, info in pairs(db) do
        if type(id) == "number" and type(info) == "table" and info.slot == slotName and type(info.name) == "string" then
            if filt == "" or string.find(string.lower(info.name), filt, 1, true) or string.find(tostring(id), filt, 1, true) then
                matches[#matches + 1] = { id = id, name = info.name }
            end
        end
    end
    table.sort(matches, function(a, b) return a.id < b.id end)
    for i = 1, math.min(#matches, 80) do
        out[#out + 1] = string.format("%d - %s", matches[i].id, matches[i].name)
    end
    return out
end

function Visual.SetOutfitPreset(presetName)
    local S = Visual.State
    S.outfitPreset = tostring(presetName or "Real (Server Outfit)")
    S.fakeWorn = {}
    if S.outfitPreset == "Real (Server Outfit)" then
        return Visual.ApplyOutfit()
    elseif S.outfitPreset == "Clear All Clothes (Naked)" then
        for _, sl in ipairs(Visual.Presets.wearSlots) do S.fakeWorn[sl] = 0 end
    elseif S.outfitPreset == "Legend Gold Mix" then
        S.fakeWorn.back  = Visual.FindWearableByKeywords("back",  { "immortal da vinci", "legendary", "golden angel", "da vinci", "wing" }, 16262)
        S.fakeWorn.hand  = Visual.FindWearableByKeywords("hand",  { "rayman", "legend", "dragon", "scythe", "katana" }, 900)
        S.fakeWorn.hat   = Visual.FindWearableByKeywords("hat",   { "crown", "legend", "zeus" }, nil)
        S.fakeWorn.feet  = Visual.FindWearableByKeywords("feet",  { "air robinson", "boots", "speed" }, nil)
    elseif S.outfitPreset == "Dev Glitch / Void" then
        S.fakeWorn.hat   = Visual.FindWearableByKeywords("hat",   { "void", "glitch" }, 20007)
        S.fakeWorn.neck  = Visual.FindWearableByKeywords("neck",  { "kuyang", "void", "scarf" }, 20006)
        S.fakeWorn.back  = Visual.FindWearableByKeywords("back",  { "glitch", "void", "nightmare", "wing" }, 8286)
        S.fakeWorn.hand  = Visual.FindWearableByKeywords("hand",  { "glitch", "katana", "scythe", "ice_dragon" }, 1378)
    elseif S.outfitPreset == "Dragon & Wings Mix" then
        S.fakeWorn.back  = Visual.FindWearableByKeywords("back",  { "da vinci", "angel wings", "wings" }, 8286)
        S.fakeWorn.hand  = Visual.FindWearableByKeywords("hand",  { "dragon", "hand" }, 900)
    elseif S.outfitPreset == "Farming / Pickaxe Look" then
        S.fakeWorn.hand  = Visual.FindWearableByKeywords("hand",  { "pickaxe", "drill", "pick" }, nil)
        S.fakeWorn.hat   = Visual.FindWearableByKeywords("hat",   { "straw", "farmer", "crown" }, nil)
    end
    return Visual.ApplyOutfit()
end

function Visual.ApplySlotItem(slotName, choiceStr)
    local S = Visual.State
    local sl = tostring(slotName or S.selectedSlot or "back")
    local txt = tostring(choiceStr or "")
    if txt == "" or txt == "Default (Keep Real)" then
        S.fakeWorn[sl] = nil
    elseif txt == "Kosong / Remove (0)" or tonumber(txt) == 0 then
        S.fakeWorn[sl] = 0
    else
        local parsedId = tonumber(string.match(txt, "^(%d+)"))
        if parsedId and parsedId > 0 then
            S.fakeWorn[sl] = parsedId
        else
            return false, "invalid_id"
        end
    end
    return Visual.ApplyOutfit()
end

function Visual.ApplyOutfit()
    ensureVisualRefs()
    local S = Visual.State
    local wt = H.wornTbl
    if type(wt) == "table" then
        if S.origWornSavedFor ~= wt then
            S.origWornSavedFor = wt
            S.origWorn = {}
            for _, sl in ipairs(Visual.Presets.wearSlots) do
                S.origWorn[sl] = rawget(wt, sl)
            end
        end
        for _, sl in ipairs(Visual.Presets.wearSlots) do
            local spoofVal = S.fakeWorn[sl]
            if spoofVal ~= nil then
                wt[sl] = (spoofVal > 0) and spoofVal or nil
            elseif S.origWorn then
                wt[sl] = S.origWorn[sl]
            end
        end
    end

    local ps = H.playerSpriteObj
    if type(ps) == "table" then
        if S.origSkinSavedFor ~= ps then
            S.origSkinSavedFor = ps
            S.origSkin = rawget(ps, "SKIN")
        end
        local col = Visual.Presets.skins[S.skinPreset]
        if S.skinPreset == "Real (Server Skin)" or S.skinPreset == "Ghost (See-Through)" then
            if typeof(S.origSkin) == "Color3" then
                ps.SKIN = S.origSkin
                if type(rawget(ps, "setSkin")) == "function" then pcall(ps.setSkin, ps, S.origSkin) end
            end
        elseif typeof(col) == "Color3" then
            ps.SKIN = col
            if type(rawget(ps, "setSkin")) == "function" then pcall(ps.setSkin, ps, col) end
        end
    end

    local gt = H.gt
    if gt then
        if S.origSkinTSavedFor ~= gt then
            S.origSkinTSavedFor = gt
            S.origSkinT = rawget(gt, "skinT")
        end
        if S.ghostSkin == true or S.skinPreset == "Ghost (See-Through)" then
            gt.skinT = 0.2
        else
            gt.skinT = S.origSkinT
        end
    end

    if H.skillsObj and type(H.skillsObj.applyWorn) == "function" then
        pcall(H.skillsObj.applyWorn)
    end
    if type(ps) == "table" and type(rawget(ps, "applyFeet")) == "function" then
        pcall(ps.applyFeet, ps)
    end
    refreshNameTagObj()
    return type(wt) == "table" or type(ps) == "table"
end

function Visual.EnsureWeatherHook()
    local gt = H.gt
    if not gt or type(rawget(gt, "drawWeather")) ~= "function" then return false end
    if H.weatherHookedFor == gt then return true end
    H.origDrawWeather = rawget(gt, "drawWeather")
    H.weatherHookedFor = gt
    gt.drawWeather = function(...)
        local S = Visual.State
        local wid = tonumber(S.weatherId) or 0
        if wid > 0 then
            local fx = rawget(gt, "weatherFx")
            if type(fx) == "table" and type(fx.set) == "function" then
                if S._appliedWeatherId ~= wid then
                    S._appliedWeatherId = wid
                    pcall(fx.set, fx, wid)
                end
                return
            end
        end
        S._appliedWeatherId = nil
        return H.origDrawWeather(...)
    end
    return true
end

function Visual.ApplyWeather(weatherNameOrId)
    ensureVisualRefs()
    local S = Visual.State
    local gt = H.gt
    local wid = tonumber(weatherNameOrId)
    if wid then
        S.weatherId = math.max(0, math.floor(wid))
    elseif type(weatherNameOrId) == "string" then
        S.weatherName = weatherNameOrId
        S.weatherId = Visual.Presets.weatherIds[weatherNameOrId] or 0
    end
    S._appliedWeatherId = nil
    Visual.EnsureWeatherHook()
    if gt then
        local fx = rawget(gt, "weatherFx")
        if S.weatherId > 0 and type(fx) == "table" and type(fx.set) == "function" then
            S._appliedWeatherId = S.weatherId
            pcall(fx.set, fx, S.weatherId)
        elseif S.weatherId <= 0 and type(H.origDrawWeather) == "function" then
            pcall(H.origDrawWeather)
        end
    end
    return S.weatherId
end

function Visual.ApplyGems(fakeAmount)
    ensureVisualRefs()
    local sk = H.skillsObj
    local addFn = sk and rawget(sk, "addGems")
    if type(addFn) ~= "function" then return false, "addGems_nil" end
    local S = Visual.State
    if not S.fakeGemsActive then
        local cur = uv(addFn, 1)
        if type(cur) == "number" then S.origGems = cur end
    end
    local val = math.max(0, math.floor(tonumber(fakeAmount) or 0))
    S.fakeGemsActive = true
    S.fakeGemsValue = val
    suv(addFn, 1, val)
    pcall(addFn, 0)
    return true, val
end

function Visual.RestoreGems()
    local S = Visual.State
    if not S.fakeGemsActive then return true end
    local sk = H.skillsObj
    local addFn = sk and rawget(sk, "addGems")
    if type(addFn) == "function" and type(S.origGems) == "number" then
        suv(addFn, 1, S.origGems)
        pcall(addFn, 0)
    end
    S.fakeGemsActive = false
    S.origGems = nil
    return true
end

function Visual.EnableStealthAntiKick()
    GetcSkipper.EnableUltimaxAllSafe()
    return true
end

function Visual.Apply()
    ensureVisualRefs()
    saveOrigVisual()
    local S = Visual.State
    if not LP then return false end
    local base = (S.customName ~= "" and S.customName) or (S.origGameName and tostring(S.origGameName)) or Core.GetInGameName(LP, true)
    local pos  = Core.ReadPos()
    local rLow = string.lower(tostring(S.role or "none"))
    local body = base .. (S.tilesName and string.format(" [%d,%d]", pos.tx, pos.ty) or "")
    if S.guildMode == "Custom Text Prefix" and S.guildTag ~= "" then
        body = "[" .. S.guildTag .. "] " .. body
    end

    -- Gabungkan effect + role badge (dengan efek BitmapText game asli)
    local styledBody = wrapVisualEffect(body, S.effect or "None", S.colorCode or "")
    local roleBadge  = ROLE_BADGES[rLow] or ""
    local finalNick  = (roleBadge ~= "" and rLow ~= "developer" and rLow ~= "moderator") and (roleBadge .. styledBody) or styledBody
    if rLow == "dr" and not string.find(string.lower(body), "^dr%.") then
        finalNick = wrapVisualEffect("Dr." .. body, S.effect or "None", (S.colorCode ~= "") and S.colorCode or "`2")
    end

    -- Trigger attribute redraw di Roles.lua / NameUI / Game.lua
    LP:SetAttribute("Nick", finalNick)

    local k = "u" .. tostring(LP.UserId)
    local sr = ReplicatedStorage:FindFirstChild("StaffRoles")
    local tagVal = (rLow == "developer" or rLow == "moderator") and rLow or S.origTag
    LP:SetAttribute("Tag", tagVal)
    if sr then
        local srVal = (rLow == "developer" or rLow == "moderator" or rLow == "vip") and rLow or S.origRoleAttr
        sr:SetAttribute(k, srVal)
    end

    local tl = ReplicatedStorage:FindFirstChild("TitleList")
    local chosenTitle = S.customTitle
    if (not chosenTitle or chosenTitle == "" or chosenTitle == "none") and (rLow == "royal" or rLow == "legend" or rLow == "sponsor" or rLow == "supporter" or rLow == "dr") then
        chosenTitle = rLow
    end
    if chosenTitle and chosenTitle ~= "" and chosenTitle ~= "none" then
        LP:SetAttribute("OwnTitle", chosenTitle)
        LP:SetAttribute("WornTitle", chosenTitle)
        if tl then tl:SetAttribute(k, chosenTitle) end
    else
        LP:SetAttribute("OwnTitle", S.origOwnTitle)
        LP:SetAttribute("WornTitle", S.origWornTitle)
        if tl then tl:SetAttribute(k, S.origTitleAttr) end
    end

    -- DrTitle & HasLegend harus boolean true agar render Dr. & Legend Wings/Badge aktif di Roles.lua
    if S.spoofDr or chosenTitle == "dr" or rLow == "dr" then
        LP:SetAttribute("DrTitle", true)
        LP:SetAttribute("HideDrUntil", 0)
    else
        LP:SetAttribute("DrTitle", S.origDrTitle)
        LP:SetAttribute("HideDrUntil", S.origHideDr)
    end
    if S.spoofLegend or chosenTitle == "legend" or rLow == "legend" then
        LP:SetAttribute("HasLegend", true)
        LP:SetAttribute("HideLegendUntil", 0)
    else
        LP:SetAttribute("HasLegend", S.origHasLegend)
        LP:SetAttribute("HideLegendUntil", S.origHideLegend)
    end
    LP:SetAttribute("StillTag", S.spoofStillTag and true or S.origStillTag)

    if S.guildMode == "2: (GE) Member" then
        LP:SetAttribute("GuildRank", 2)
    elseif S.guildMode == "3: (GC) Officer" then
        LP:SetAttribute("GuildRank", 3)
    elseif S.guildMode == "4: (GL) Leader" then
        LP:SetAttribute("GuildRank", 4)
    else
        LP:SetAttribute("GuildRank", S.origGuildRank)
    end

    if S.country and S.country ~= "Real (Unchanged)" then
        LP:SetAttribute("Country", S.country)
    else
        LP:SetAttribute("Country", S.origCountry)
    end

    local bCol = Visual.Presets.boosterColors[S.boosterColor]
    LP:SetAttribute("DiscordBooster", S.booster == true or S.origBooster)
    if typeof(bCol) == "Color3" then
        LP:SetAttribute("DiscordColor", bCol)
    else
        LP:SetAttribute("DiscordColor", S.origBoosterColor)
    end

    local lvl = toInt(S.spoofLevel, 0)
    if lvl > 0 then
        LP:SetAttribute("Level", lvl)
        LP:SetAttribute("PlayerLevel", lvl)
    else
        LP:SetAttribute("Level", S.origLevel)
        LP:SetAttribute("PlayerLevel", S.origPlayerLevel)
    end

    Visual.ApplyOutfit()
    if (tonumber(S.weatherId) or 0) > 0 or H.weatherHookedFor == H.gt then
        Visual.ApplyWeather(S.weatherId)
    end
    refreshNameTagObj()
    S.lastPosKey = tileKey(pos.tx, pos.ty)
    return true
end

function Visual.OnWorldChanged()
    ensureVisualRefs()
    if Visual.HasActiveSpoof() then
        Visual.Apply()
        if Visual.State.fakeGemsActive then
            Visual.ApplyGems(Visual.State.fakeGemsValue)
        end
    end
end

function Visual.Restore()
    ensureVisualRefs()
    saveOrigVisual()
    local S = Visual.State
    S.customName, S.role, S.effect, S.colorCode, S.customTitle = "", "none", "None", "", "none"
    S.guildTag, S.guildMode, S.country = "", "None (Real)", "Real (Unchanged)"
    S.booster, S.boosterColor = false, "Default (Real)"
    S.spoofDr, S.spoofLegend, S.spoofStillTag, S.spoofLevel = false, false, false, 0
    S.tilesName, S.hideName = false, false
    S.outfitPreset, S.fakeWorn, S.skinPreset, S.ghostSkin = "Real (Server Outfit)", {}, "Real (Server Skin)", false
    S.weatherName, S.weatherId, S._appliedWeatherId = "Real (Server Weather)", 0, nil

    if LP then
        LP:SetAttribute("Nick", S.origNick)
        LP:SetAttribute("GameName", S.origGameName)
        LP:SetAttribute("Tag", S.origTag)
        LP:SetAttribute("OwnTitle", S.origOwnTitle)
        LP:SetAttribute("WornTitle", S.origWornTitle)
        LP:SetAttribute("DrTitle", S.origDrTitle)
        LP:SetAttribute("HasLegend", S.origHasLegend)
        LP:SetAttribute("HideLegendUntil", S.origHideLegend)
        LP:SetAttribute("HideDrUntil", S.origHideDr)
        LP:SetAttribute("StillTag", S.origStillTag)
        LP:SetAttribute("GuildRank", S.origGuildRank)
        LP:SetAttribute("DiscordBooster", S.origBooster)
        LP:SetAttribute("DiscordColor", S.origBoosterColor)
        LP:SetAttribute("Country", S.origCountry)
        LP:SetAttribute("Level", S.origLevel)
        LP:SetAttribute("PlayerLevel", S.origPlayerLevel)
        local k = "u" .. tostring(LP.UserId)
        local sr, tl = ReplicatedStorage:FindFirstChild("StaffRoles"), ReplicatedStorage:FindFirstChild("TitleList")
        if sr then sr:SetAttribute(k, S.origRoleAttr) end
        if tl then tl:SetAttribute(k, S.origTitleAttr) end
    end

    if type(H.wornTbl) == "table" and S.origWorn then
        for _, sl in ipairs(Visual.Presets.wearSlots) do
            H.wornTbl[sl] = S.origWorn[sl]
        end
    end
    if type(H.playerSpriteObj) == "table" and typeof(S.origSkin) == "Color3" then
        H.playerSpriteObj.SKIN = S.origSkin
        if type(rawget(H.playerSpriteObj, "setSkin")) == "function" then
            pcall(H.playerSpriteObj.setSkin, H.playerSpriteObj, S.origSkin)
        end
    end
    if H.gt and S.origSkinTSavedFor == H.gt then
        H.gt.skinT = S.origSkinT
    end
    if H.skillsObj and type(H.skillsObj.applyWorn) == "function" then pcall(H.skillsObj.applyWorn) end
    if type(H.playerSpriteObj) == "table" and type(rawget(H.playerSpriteObj, "applyFeet")) == "function" then
        pcall(H.playerSpriteObj.applyFeet, H.playerSpriteObj)
    end

    if type(H.origDrawWeather) == "function" and H.weatherHookedFor == H.gt then
        pcall(H.origDrawWeather)
    end
    Visual.RestoreGems()
    refreshNameTagObj()
    return true
end

-- V5 [SET SPAMING]
local Spam = {
    State = {
        running = false, sessionToken = 0, thread = nil, status = "Idle",
        text = "", maxLength = 120, prefixColor = "", autoCycleColor = false, colorIndex = 1,
        delay = 3.0, experimentalWhisperAll = false,
    }
}
SYT_Logic.Spam = Spam

local function setSpamStatus(msg)
    Spam.State.status = msg
    if UI then UI:SetValue("SpamStatusDisplay", msg) end
    if UIHooks.updateButtons then UIHooks.updateButtons() end
end

function Spam.FormatNextMessage()
    local S = Spam.State
    local prefix = S.prefixColor
    if S.autoCycleColor then
        prefix = COLOR_CODES[S.colorIndex] or "`2"
        S.colorIndex = (S.colorIndex % #COLOR_CODES) + 1
    end
    local msg = (prefix ~= "" and (prefix .. S.text)) or S.text
    return (#msg > S.maxLength) and string.sub(msg, 1, S.maxLength) or msg
end

function Spam.Stop()
    Spam.State.running = false
    Spam.State.sessionToken += 1
    if Spam.State.thread then
        pcall(task.cancel, Spam.State.thread)
        Spam.State.thread = nil
    end
    setSpamStatus("Stopped")
    return false
end

function Spam.Start()
    Core.EnsureInit()
    local S = Spam.State
    if S.running then return true end
    if S.text == "" then setSpamStatus("Isi pesan spam terlebih dahulu"); return false end
    S.running = true
    S.sessionToken += 1
    local token = S.sessionToken
    local function alive() return S.running and S.sessionToken == token end
    setSpamStatus("Spamming...")

    S.thread = task.spawn(function()
        Core.EnsureOutboundFirewall()
        while alive() do
            if evaluateSeems() or not H.gt or H.gt.name == "" then break end
            local shieldOn = not (GetcSkipper.State.antiKickShield == false)
            local effDelay = shieldOn and math.max(2.35, tonumber(S.delay) or 3.0) or math.max(1.65, tonumber(S.delay) or 3.0)
            if S.experimentalWhisperAll then
                local players = Core.GetInWorldPlayers(false)
                if #players == 0 then
                    setSpamStatus("Menunggu player di world...")
                    task.wait(1.0)
                else
                    for _, p in ipairs(players) do
                        if not alive() or evaluateSeems() then break end
                        setSpamStatus("Whisper -> " .. p.gameName)
                        local okSend, okCall, callRes = pcall(function()
                            return Packets.SendChat({
                                message = Spam.FormatNextMessage(),
                                maxLength = S.maxLength,
                                isWhisper = true,
                                whisperTarget = p.gameName,
                                bypassRateLimit = not shieldOn,
                                shouldContinue = alive,
                            })
                        end)
                        if shieldOn and okSend and okCall == nil and (H.fwLastBlockReason == "modcommand_flood" or H.fwLastBlockReason == "nonstaff_modcommand") then
                            setSpamStatus("Whisper Guarded (" .. tostring(H.fwLastBlockReason) .. ")")
                        end
                        GetcSkipper.RandomizedWait(effDelay, "chat", alive)
                    end
                end
            else
                Packets.SendChat({
                    message = Spam.FormatNextMessage(),
                    maxLength = S.maxLength,
                    bypassRateLimit = not shieldOn,
                    shouldContinue = alive,
                })
                GetcSkipper.RandomizedWait(effDelay, "chat", alive)
            end
        end
        if S.sessionToken == token then
            S.running = false
            S.thread = nil
            setSpamStatus("Stopped")
        end
    end)
    return true
end

function Spam.Toggle()
    if Spam.State.running then
        return Spam.Stop()
    else
        return Spam.Start()
    end
end

-- Random Valid Gap Teleport State
local tpState = {
    selectedX = nil, selectedY = nil,
    patrolOn = false, patrolToken = 0, patrolThread = nil, patrolDelay = 0.25,
    mapClickMode = "TP", -- "TP" | "PABRIK_TILE" | "PABRIK_LINE" | "BREAK_POS"
}

local function stopRandomTp()
    tpState.patrolOn = false
    tpState.patrolToken += 1
    if tpState.patrolThread then
        pcall(task.cancel, tpState.patrolThread)
        tpState.patrolThread = nil
    end
    if UIHooks.updateButtons then UIHooks.updateButtons() end
end

local function pickReachableGapTile()
    local gt = H.gt
    if not gt or not gt.w or not gt.h then return nil end
    local w, h = gt.w, gt.h
    local pos = Core.ReadPos()
    local sx, sy = clamp(pos.tx, 0, w - 1), clamp(pos.ty, 0, h - 1)
    if Core.IsSolid(sx, sy) and gt.spawn then
        sx, sy = clamp(math.floor(gt.spawn.X), 0, w - 1), clamp(math.floor(gt.spawn.Y), 0, h - 1)
    end
    local vis, queue, head, reachable = { [sy * w + sx] = true }, { sy * w + sx }, 1, {}
    local dirs = { { 1, 0 }, { -1, 0 }, { 0, -1 }, { 0, 1 } }
    while head <= #queue and #reachable < 450 do
        local cur = queue[head]
        head += 1
        local cx, cy = cur % w, math.floor(cur / w)
        if not Core.IsSolid(cx, cy) and (cx ~= pos.tx or cy ~= pos.ty) then
            reachable[#reachable + 1] = { x = cx, y = cy }
        end
        for _, d in ipairs(dirs) do
            local nx, ny = cx + d[1], cy + d[2]
            if nx >= 0 and nx < w and ny >= 0 and ny < h then
                local nIdx = ny * w + nx
                if not vis[nIdx] and not Core.IsSolid(nx, ny) then
                    vis[nIdx] = true
                    queue[#queue + 1] = nIdx
                end
            end
        end
    end
    if #reachable > 0 then return reachable[math.random(1, #reachable)] end
    local fallback = {}
    for y = 1, h - 2 do
        for x = 1, w - 2 do
            if not Core.IsSolid(x, y) then fallback[#fallback + 1] = { x = x, y = y } end
        end
    end
    return (#fallback > 0) and fallback[math.random(1, #fallback)] or nil
end

local function toggleRandomTp()
    if tpState.patrolOn then
        stopRandomTp()
        if UI then UI:SetValue("ValidStatusDisplay", "Random Gap Teleport dihentikan.") end
        return false
    end
    Core.EnsureInit()
    local gt = H.gt
    if not gt or gt.name == "" then
        if UI then UI:SetValue("ValidStatusDisplay", "Belum masuk world.") end
        return false
    end
    tpState.patrolOn = true
    tpState.patrolToken += 1
    local tok = tpState.patrolToken
    local function alive() return tpState.patrolOn and tpState.patrolToken == tok end
    if UIHooks.updateButtons then UIHooks.updateButtons() end
    if UI then UI:SetValue("ValidStatusDisplay", "Random Gap TP AKTIF...") end

    tpState.patrolThread = task.spawn(function()
        while alive() do
            if evaluateSeems() then break end
            local pick = pickReachableGapTile()
            if pick then
                tpState.selectedX, tpState.selectedY = pick.x, pick.y
                if UI then
                    UI:SetValue("TpManualX", tostring(pick.x))
                    UI:SetValue("TpManualY", tostring(pick.y))
                end
                local ok, msg = Packets.WalkTeleport({ tx = pick.x, ty = pick.y, mode = "step", stepSize = 4, stepDelay = tpState.patrolDelay })
                if UI then UI:SetValue("ValidStatusDisplay", (ok and "[GAP-TP] " or "[ERR] ") .. tostring(msg)) end
                if UIHooks.refreshMap then UIHooks.refreshMap(true) end
            end
            GetcSkipper.RandomizedWait(math.max(0.08, tpState.patrolDelay), nil, alive)
        end
        if tpState.patrolToken == tok then
            tpState.patrolOn = false
            tpState.patrolThread = nil
            if UIHooks.updateButtons then UIHooks.updateButtons() end
        end
    end)
    return true
end

local STORE_OFFERS = {
    { key = "small_seed_pack", name = "Small Seed Pack", price = 100 },
    { key = "house_entrance", name = "House Entrance", price = 100 },
    { key = "basic_clothes", name = "Basic Clothing Pack", price = 100 },
    { key = "small_lock", name = "Small Lock", price = 50 },
    { key = "big_lock", name = "Big Lock", price = 200 },
    { key = "splicing_kit", name = "Basic Splicing Kit", price = 200 },
    { key = "grow_spray", name = "Grow Spray Fertilizer", price = 200 },
    { key = "builder_pack", name = "Builder's Pack", price = 300 },
    { key = "display_box", name = "Display Box", price = 300 },
    { key = "huge_lock", name = "Huge Lock", price = 500 },
    { key = "rare_clothes", name = "Rare Clothing Pack", price = 500 },
    { key = "backpack", name = "Backpack Upgrade", price = 500 },
    { key = "deluxe_spray", name = "Deluxe Grow Spray", price = 900 },
    { key = "small_seed_packs", name = "Small Seed Pack Collection", price = 1000 },
    { key = "rare_seed_pack", name = "Rare Seed Pack", price = 1000 },
    { key = "parkour_pack", name = "Parkour Pack", price = 1000 },
    { key = "megaphone", name = "Megaphone", price = 1000 },
    { key = "world_lock", name = "World Lock", price = 2000 },
    { key = "signal_jammer", name = "Signal Jammer", price = 2000 },
    { key = "shop_pack", name = "Shopkeeper's Pack", price = 3000 },
    { key = "security_camera", name = "Security Camera", price = 4000 },
    { key = "composer_pack", name = "Composer's Pack", price = 5000 },
    { key = "mad_science_kit", name = "Mad Science Kit", price = 5000 },
    { key = "surgery_pack", name = "Surgery Starter Pack", price = 5000 },
    { key = "builder_machine", name = "Block Machine", price = 5000 },
    { key = "city_pack", name = "City Pack", price = 8000 },
    { key = "vending", name = "Vending Machine", price = 8000 },
    { key = "door_mover", name = "Door Mover", price = 8000 },
    { key = "wl_pack", name = "World Lock Pack", price = 20000 },
    { key = "punch_jammer", name = "Punch Jammer", price = 25000 },
    { key = "mini_mod", name = "Mini Mod", price = 40000 },
    { key = "builders_lock", name = "Builder's Lock", price = 50000 },
    { key = "growscan", name = "GrowScan 9000", price = 50000 },
    { key = "rayman_fist", name = "Rayman's Fist", price = 100000 },
}

local function findStoreOfferByDisplay(txt)
    local s = tostring(txt or "")
    local key = s:match("^([a-z0-9_]+)%s*|") or s
    for _, o in ipairs(STORE_OFFERS) do
        if o.key == key or o.name == s then return o end
    end
    return nil
end

local function sanitizeWorldSpec(raw, allowDoor)
    local s = tostring(raw or ""):gsub("%s+", ""):upper()
    if allowDoor then
        local w, d = s:match("^([A-Z0-9]+):?([A-Z0-9]*)$")
        w = (w or s:gsub("[^A-Z0-9]", "")):sub(1, 8)
        d = (d or ""):sub(1, 8)
        return w, d
    end
    return (s:gsub("[^A-Z0-9]", "")):sub(1, 8), ""
end

local function pickOpenSideDirection(tx, ty, preferSide)
    local gt = H.gt
    if not gt then return (preferSide == "left") and -1 or 1 end
    local rightOk = (tx + 1 < gt.w) and not Core.IsSolid(tx + 1, ty)
    local leftOk = (tx - 1 >= 0) and not Core.IsSolid(tx - 1, ty)
    if preferSide == "left" and leftOk then return -1 end
    if preferSide == "right" and rightOk then return 1 end
    if rightOk then return 1 end
    if leftOk then return -1 end
    return 1
end

function Packets.Drop(itemId, count, opts)
    Core.EnsureInit()
    Core.EnsureOutboundFirewall()
    local gt, net = H.gt, H.Net
    if not gt or not net or not net.drop or type(net.drop.send) ~= "function" then return false, "net_drop_nil" end
    itemId = toInt(itemId)
    count = clamp(toInt(count, 1), 1, 200)
    if not itemId or itemId <= 0 or Core.CountItem(itemId) <= 0 then return false, "no_item" end
    count = math.min(count, Core.CountItem(itemId))
    opts = opts or {}
    local pos = Core.ReadPos()
    local dir = pickOpenSideDirection(pos.tx, pos.ty, opts.preferSide)
    local dropX = clamp(pos.tx + (dir > 0 and 1.2 or -0.2), 0.3, (gt.w or 100) - 0.3)
    local dropY = pos.ty + 0.5
    local facingBit = (dir > 0) and 1 or 0
    Packets.SendRawMove(pos.x, pos.y, 0, 0, facingBit + 2)
    task.wait(0.06)
    -- Hormati jeda drop 1.08s dari firewall agar tidak terblokir server
    local waitLeft = (H.fwLastDropSentAt or 0) + 1.12 - os.clock()
    if waitLeft > 0 then task.wait(waitLeft) end
    local ok = pcall(net.drop.send, { id = itemId, n = count, x = dropX, y = dropY })
    if ok and H.inv and type(H.inv.remove) == "function" then
        pcall(function() H.inv:remove(itemId, count) end)
    end
    return ok, ok and "dropped" or "drop_failed"
end

function Packets.EnterWorldDoor(spec, aliveFn)
    Core.EnsureInit()
    local gt = H.gt
    if not gt or type(gt.enter) ~= "function" then return false, "enter_nil" end
    local wName, doorId = sanitizeWorldSpec(spec, true)
    if wName == "" then return false, "empty_world" end
    while H._warpInFlight do
        if type(aliveFn) == "function" and not aliveFn() then return false, "cancelled" end
        task.wait(0.15)
    end
    H._warpInFlight = true
    local function finishWarp(ok, rsn)
        H._warpInFlight = false
        return ok, rsn
    end
    if cleanWorldName(gt.name) ~= wName then
        local sinceLast = os.clock() - (H._lastWarpAt or 0)
        if sinceLast < 2.4 then
            local waitRem = 2.4 - sinceLast
            local wEnd = os.clock() + waitRem
            while os.clock() < wEnd do
                if type(aliveFn) == "function" and not aliveFn() then return finishWarp(false, "cancelled") end
                if H.gt and cleanWorldName(H.gt.name) == wName then break end
                task.wait(0.10)
            end
        end
        if H.gt and cleanWorldName(H.gt.name) ~= wName then
            H._lastWarpAt = os.clock()
            H._lastWarpTarget = wName
            H.intentionalSwitchUntil = os.clock() + 15.0
            pcall(gt.enter, wName)
            local dl = os.clock() + 12
            while os.clock() < dl do
                if type(aliveFn) == "function" and not aliveFn() then return finishWarp(false, "cancelled") end
                if H.gt and cleanWorldName(H.gt.name) == wName then break end
                task.wait(0.25)
            end
            task.wait(0.85)
            pcall(SYT_Logic.Init, true)
            if H.gt and cleanWorldName(H.gt.name) == wName and Visual and Visual.State then
                Visual.State.lastWorldName = wName
            end
            H.intentionalSwitchUntil = os.clock() + 3.5
        end
    end
    if cleanWorldName(H.gt and H.gt.name or "") ~= wName then
        return finishWarp(false, "enter_timeout")
    end
    if doorId ~= "" and H.Net and type(H.Net.call) == "function" then
        gt = H.gt
        for y = 0, (gt.h or 60) - 1 do
            for x = 0, (gt.w or 100) - 1 do
                local id = Core.GetFG(x, y)
                if id > 0 and id ~= 6 then
                    local info = Core.GetItemInfo(id)
                    if info and (info.door or info.entrance) then
                        local okD = pcall(H.Net.call, "DoorPass", x, y, doorId)
                        if okD then task.wait(0.5); break end
                    end
                end
            end
        end
        pcall(H.Net.call, "UseDoor", doorId)
        task.wait(0.45)
    end
    return finishWarp(true, wName)
end

function Packets.BuyStoreOffer(offerKey)
    Core.EnsureInit()
    if not H.Net or type(H.Net.call) ~= "function" then return false, "net_call_nil" end
    local ok, okRes, data = pcall(H.Net.call, "BuyItem", offerKey)
    if not ok then return false, tostring(okRes) end
    return okRes == true, data
end

-- Forward declarations
local SystemModule, AutoLeveling, ClearWorld, MoveBlock, DiscordHook, ProxyCommands

local function isAnyMainTaskRunning(exceptName)
    local active = {
        PNB = PNB and PNB.State and PNB.State.running,
        Pabrik = Pabrik and Pabrik.State and Pabrik.State.running,
        DirtFarm = DirtFarm and DirtFarm.State and DirtFarm.State.running,
        ClearWorld = ClearWorld and ClearWorld.State and ClearWorld.State.running,
        MoveBlock = MoveBlock and MoveBlock.State and MoveBlock.State.running,
        AutoLeveling = AutoLeveling and AutoLeveling.State and AutoLeveling.State.running,
    }
    for k, on in pairs(active) do
        if k ~= exceptName and on == true then return true, k end
    end
    return false, nil
end

local function guardExclusiveStart(modName)
    local busy, holder = isAnyMainTaskRunning(modName)
    if busy then
        emitNotify("SYT", "SORRY YOUR TASK IS DO RIGHT NOW (" .. tostring(holder) .. ")")
        return false
    end
    return true
end

local function resolveConsoleUi()
    if H._chatUiObj and type(H._chatUiObj.add) == "function" then return H._chatUiObj end
    for _, v in ipairs(safeGetGC(true)) do
        if type(v) == "table" and type(rawget(v, "add")) == "function" and type(rawget(v, "setGems")) == "function" and type(rawget(v, "prefill")) == "function" then
            H._chatUiObj = v
            return v
        end
    end
    return nil
end

local function proxyConsole(msg, kind, allowSpans)
    local txt = tostring(msg or "")
    local chatUi = resolveConsoleUi()
    if chatUi then
        local ok = pcall(chatUi.add, txt, kind or "system", allowSpans == true)
        if ok then return true end
    end
    if H.gt and type(H.gt.floatText) == "function" then
        local pos = Core.ReadPos()
        pcall(H.gt.floatText, pos.x, pos.y - 1.3, stripColorTags(txt), Color3.fromRGB(130, 230, 255))
    end
    return true
end

local function buildStorageFileSupported()
    return type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
end

local function safeReadStorage(fname)
    if buildStorageFileSupported() then
        local okE, ex = pcall(isfile, fname)
        if okE and ex then
            local okR, dat = pcall(readfile, fname)
            if okR and type(dat) == "string" then return dat end
        end
    end
    local env = getEnv()
    return env and env["__SYT_STORE_" .. fname] or nil
end

local function safeWriteStorage(fname, val)
    local env = getEnv()
    if env then env["__SYT_STORE_" .. fname] = val end
    if buildStorageFileSupported() then
        pcall(writefile, fname, tostring(val))
    end
end

-- Helper Shared Zigzag Clear + Lava-First Safety
local function resolveActiveDropWorldSafe()
    local cw = ClearWorld and ClearWorld.State
    return (cw and cw.noCollect == true)
end

local function clearSingleTileWithLavaCheck(tx, ty, layers, hitGap, showHand, noCollect, aliveFn)
    local gt = H.gt
    if not gt or tx < 0 or tx >= gt.w or ty < 0 or ty >= gt.h then return false end
    local safeHitGap = math.max(0.162, tonumber(hitGap) or 0.165)

    local function coolAntiKick()
        if H.fwLastBlockAt and (os.clock() - H.fwLastBlockAt) < 0.45 then
            task.wait(0.35)
        end
    end

    local function walkToBreakRange(bx, by)
        if Core.IsInActionReach(bx, by, "break") then return true end
        local okW = Packets.MoveWalkNear(bx, by, 2, aliveFn, 7.1, "break")
        if okW and Core.IsInActionReach(bx, by, "break") then return true end
        local cands = Packets.FindStandCandidates(bx, by, 2)
        if cands and cands[1] then
            Packets.WalkPathTo(cands[1].x, cands[1].y, 6.9, aliveFn, { fastWalk = false, noSnap = true, customPath = cands[1].path })
        end
        return Core.IsInActionReach(bx, by, "break")
    end

    -- Cek 1 tile di bawah (ty + 1): jika mengandung lava/deadly dan bisa dihancurkan, hancurkan dulu dari samping aman (walkSpeed <= 7.1, NO TP!)
    if ty + 1 < gt.h then
        local belowId = Core.GetFG(tx, ty + 1)
        if belowId ~= 0 and not Core.IsProtectedTile(belowId) and Core.CanEditTile(tx, ty + 1) then
            local bInfo = Core.GetItemInfo(belowId)
            if bInfo and (bInfo.hurts == true or bInfo.deadly == true) then
                if not Core.IsInActionReach(tx, ty + 1, "break") then
                    local pos = Core.ReadPos()
                    local safeSideX = (pos.tx <= tx) and math.max(0, tx - 1) or math.min(gt.w - 1, tx + 1)
                    if not Core.IsSolid(safeSideX, ty) then
                        Packets.WalkPathTo(safeSideX, ty, 7.0, aliveFn, { fastWalk = false, noSnap = true })
                    else
                        walkToBreakRange(tx, ty + 1)
                    end
                end
                if Core.IsInActionReach(tx, ty + 1, "break") then
                    coolAntiKick()
                    Packets.BreakVerified({ { tx = tx, ty = ty + 1, layer = 1 } }, {
                        threads = 1, layer = 1, oneHit = false, customHits = nil,
                        hitDelay = safeHitGap, verifyTimeout = 0.24, showHand = showHand,
                        showVisual = true, noLocalMirror = true, autoRange = true,
                        preferWalk = true, walkSpeed = 7.1, shouldContinue = aliveFn
                    })
                    if not noCollect then
                        Packets.Collect({ radius = 4, stepMoveIfFar = false, preferWalk = true, collectDelay = 0.02, shouldContinue = aliveFn })
                    end
                end
            end
        end
    end

    for _, lyr in ipairs(layers) do
        if type(aliveFn) == "function" and not aliveFn() then return false end
        local tid = Core.GetLayerTile(tx, ty, lyr)
        if tid ~= 0 and not Core.IsProtectedTile(tid) and Core.CanEditTile(tx, ty) then
            if walkToBreakRange(tx, ty) and (type(aliveFn) ~= "function" or aliveFn()) then
                for _ = 1, 2 do
                    if Core.GetLayerTile(tx, ty, lyr) == 0 or (type(aliveFn) == "function" and not aliveFn()) then break end
                    coolAntiKick()
                    Packets.BreakVerified({ { tx = tx, ty = ty, layer = lyr } }, {
                        threads = 1, layer = lyr, oneHit = false, customHits = nil,
                        hitDelay = safeHitGap, verifyTimeout = 0.24, showHand = showHand,
                        showVisual = true, noLocalMirror = true, autoRange = true,
                        preferWalk = true, walkSpeed = 7.1, shouldContinue = aliveFn
                    })
                    task.wait(0.02)
                end
                if not noCollect then
                    Packets.Collect({ radius = 4.2, stepMoveIfFar = false, preferWalk = true, collectDelay = 0.02, shouldContinue = aliveFn })
                end
            end
        end
    end
    return true
end

-- ClearWorld: FIFO World List, Zigzag FG + BG (kecuali Door/Lock/Bedrock), Lava Pre-Break
ClearWorld = {
    State = {
        running = false, sessionToken = 0, thread = nil, status = "Idle",
        worldInput = "", worldList = {}, worldIdx = 1,
        switchingWorld = false, halfWorldMode = false, noCollect = false,
        progress = 0,
    }
}
SYT_Logic.ClearWorld = ClearWorld

local function setCwStatus(msg)
    ClearWorld.State.status = msg
    if UI then UI:SetValue("CwStatusDisplay", msg) end
    if UIHooks.updateButtons then UIHooks.updateButtons() end
end

function ClearWorld._syncEnvQueue(worlds)
    local ed = getEnv().__SYT_ENV_DATA or {}
    getEnv().__SYT_ENV_DATA = ed
    local copy = {}
    for i, w in ipairs(worlds or ClearWorld.State.worldList or {}) do copy[i] = w end
    ed.cwQueue = copy
    return copy
end

function ClearWorld.AddWorld(raw)
    local w = sanitizeWorldSpec(raw, false)
    if w == "" then return false, ClearWorld.State.worldList end
    for _, existing in ipairs(ClearWorld.State.worldList) do
        if existing == w then return false, ClearWorld.State.worldList end
    end
    table.insert(ClearWorld.State.worldList, w)
    ClearWorld._syncEnvQueue(ClearWorld.State.worldList)
    if UIHooks.refreshCwList then UIHooks.refreshCwList() end
    return true, ClearWorld.State.worldList
end

function ClearWorld.RemoveWorldAt(idx)
    if idx >= 1 and idx <= #ClearWorld.State.worldList then
        table.remove(ClearWorld.State.worldList, idx)
        ClearWorld._syncEnvQueue(ClearWorld.State.worldList)
        if UIHooks.refreshCwList then UIHooks.refreshCwList() end
    end
end

function ClearWorld.Stop(keepSaved)
    Core.ClearManualInput()
    ClearWorld.State.running = false
    ClearWorld.State.switchingWorld = false
    ClearWorld.State.sessionToken += 1
    if ClearWorld.State.thread then
        pcall(task.cancel, ClearWorld.State.thread)
        ClearWorld.State.thread = nil
    end
    if not keepSaved then
        local ed = getEnv().__SYT_ENV_DATA
        if type(ed) == "table" and ed.rotSession and ed.rotSession.mode == "ClearWorld" then
            ed.rotSession = nil
        end
    end
    setCwStatus("Stopped")
    return false
end

function ClearWorld.Start(opts)
    opts = opts or {}
    if not opts.fromAutoLevel and not guardExclusiveStart("ClearWorld") then return false end
    Core.EnsureInit()
    Core.EnsureManualInputHook()
    local S = ClearWorld.State
    if S.running then return true end
    S.halfWorldMode = opts.halfWorld == true
    S.noCollect = opts.noCollect == true
    S.running = true
    S.sessionToken += 1
    S.progress = 0
    local tok = S.sessionToken
    local function alive() return S.running and S.sessionToken == tok end
    if UIHooks.updateButtons then UIHooks.updateButtons() end

    S.thread = task.spawn(function()
        while alive() do
            Core.EnsureInit()
            local gt = H.gt
            if not gt or gt.name == "" then
                setCwStatus("Menunggu world...")
                task.wait(0.4)
            else
                local curW = cleanWorldName(gt.name)
                local readyCw = true
                if not opts.fromAutoLevel and #S.worldList > 0 then
                    local inQueue = false
                    for _, w in ipairs(S.worldList) do
                        if w == curW then inQueue = true; break end
                    end
                    if not inQueue then
                        local firstW = S.worldList[1]
                        if firstW and firstW ~= "" and firstW ~= curW then
                            readyCw = false
                            local ed = getEnv().__SYT_ENV_DATA or {}
                            getEnv().__SYT_ENV_DATA = ed
                            ed.rotSession = {
                                mode = "ClearWorld",
                                targetWorld = firstW,
                                worlds = ClearWorld._syncEnvQueue(S.worldList),
                                halfWorld = S.halfWorldMode,
                                noCollect = S.noCollect,
                                active = true,
                                updatedAt = os.clock(),
                            }
                            S.switchingWorld = true
                            setCwStatus("Masuk antrian world: " .. firstW)
                            local okWarp = Packets.EnterWorldDoor(firstW, alive)
                            S.switchingWorld = false
                            if not alive() then break end
                            if not okWarp then
                                setCwStatus("Gagal masuk " .. firstW .. ", tunggu...")
                                task.wait(1.6)
                            end
                        end
                    else
                        local ed = getEnv().__SYT_ENV_DATA or {}
                        getEnv().__SYT_ENV_DATA = ed
                        ed.rotSession = {
                            mode = "ClearWorld",
                            targetWorld = curW,
                            worlds = ClearWorld._syncEnvQueue(S.worldList),
                            halfWorld = S.halfWorldMode,
                            noCollect = S.noCollect,
                            active = true,
                            updatedAt = os.clock(),
                        }
                    end
                elseif not opts.fromAutoLevel then
                    local ed = getEnv().__SYT_ENV_DATA or {}
                    getEnv().__SYT_ENV_DATA = ed
                    ed.rotSession = {
                        mode = "ClearWorld",
                        targetWorld = curW,
                        worlds = {},
                        halfWorld = S.halfWorldMode,
                        noCollect = S.noCollect,
                        active = true,
                        updatedAt = os.clock(),
                    }
                end

                if readyCw then
                local w, h = gt.w or 100, gt.h or 60
                local maxY = h - 1
                -- Cari batas atas bedrock terbawah
                for y = h - 1, 0, -1 do
                    local bedCnt = 0
                    for x = 0, w - 1 do
                        local fid = Core.GetFG(x, y)
                        if fid == 8 then bedCnt += 1 end
                    end
                    if bedCnt >= math.floor(w * 0.6) then
                        maxY = math.max(2, y - 1)
                    else
                        break
                    end
                end
                if S.halfWorldMode then
                    maxY = math.max(3, math.floor(maxY * 0.5))
                end

                -- Cari sisi kiri atau kanan paling dekat dari posisi player
                local p0 = Core.ReadPos()
                local dirRev = (p0.tx > math.floor(w * 0.5))

                -- Hitung total tile target untuk Progress 0-100%
                local targets = {}
                for y = 0, maxY do
                    local xs = dirRev and (w - 1) or 0
                    local xe = dirRev and 0 or (w - 1)
                    local stepX = dirRev and -1 or 1
                    for x = xs, xe, stepX do
                        local fgId = Core.GetFG(x, y)
                        local bgId = Core.GetBG(x, y)
                        local needFg = (fgId ~= 0 and not Core.IsProtectedTile(fgId) and Core.CanEditTile(x, y))
                        local needBg = (bgId ~= 0 and not Core.IsProtectedTile(bgId) and Core.CanEditTile(x, y))
                        if needFg or needBg then
                            targets[#targets + 1] = { x = x, y = y, needFg = needFg, needBg = needBg }
                        end
                    end
                    dirRev = not dirRev
                end

                local totalT = #targets
                if totalT == 0 then
                    S.progress = 100
                    if opts.fromAutoLevel then
                        setCwStatus("Setengah world bersih!")
                        S.running = false
                        break
                    end
                    -- Pop FIFO list jika world saat ini sudah selesai
                    local nextW = nil
                    if #S.worldList > 0 then
                        for i = #S.worldList, 1, -1 do
                            if S.worldList[i] == curW then table.remove(S.worldList, i) end
                        end
                        if UIHooks.refreshCwList then UIHooks.refreshCwList() end
                        nextW = S.worldList[1]
                    end
                    local savedQ = ClearWorld._syncEnvQueue(S.worldList)
                    local ed = getEnv().__SYT_ENV_DATA or {}
                    getEnv().__SYT_ENV_DATA = ed
                    if nextW and nextW ~= curW then
                        ed.rotSession = {
                            mode = "ClearWorld",
                            targetWorld = nextW,
                            worlds = savedQ,
                            halfWorld = S.halfWorldMode,
                            noCollect = S.noCollect,
                            active = true,
                            updatedAt = os.clock(),
                        }
                        S.switchingWorld = true
                        setCwStatus("World bersih -> Next: " .. nextW)
                        local okNext = Packets.EnterWorldDoor(nextW, alive)
                        S.switchingWorld = false
                        if not okNext and alive() then
                            task.wait(1.6)
                        end
                    else
                        ed.rotSession = nil
                        setCwStatus("Clear World Selesai: " .. curW)
                        emitNotify("Clear World", "World " .. curW .. " selesai dibersihkan!")
                        S.running = false
                        break
                    end
                else
                    for idx, t in ipairs(targets) do
                        if not alive() then break end
                        if not opts.fromAutoLevel and SystemModule.State.enabled then
                            -- Biarkan System security menangani jika ada orang masuk
                        elseif opts.fromAutoLevel and #Core.GetInWorldPlayers(false) > 0 then
                            setCwStatus("Player lain terdeteksi saat AutoLevel -> Ganti world")
                            break
                        end
                        S.progress = math.floor((idx / totalT) * 100)
                        setCwStatus(string.format("[%s] Clear %d/%d (%d%%) @(%d,%d)", curW, idx, totalT, S.progress, t.x, t.y))
                        clearSingleTileWithLavaCheck(t.x, t.y, { 1, 2 }, 0.194, true, S.noCollect, alive)
                        task.wait(0.02)
                    end
                end
                end
            end
            task.wait(0.05)
        end
        Core.ClearManualInput()
        ClearWorld.State.switchingWorld = false
        if ClearWorld.State.sessionToken == tok then
            ClearWorld.State.running = false
            ClearWorld.State.thread = nil
            if UIHooks.updateButtons then UIHooks.updateButtons() end
        end
    end)
    return true
end

function ClearWorld.Toggle()
    if ClearWorld.State.running then return ClearWorld.Stop() end
    return ClearWorld.Start()
end

-- MoveBlock: Set Take, Set Drop, ambil item dari take, walk ke drop, Packets.Drop, delay 2 detik
MoveBlock = {
    State = { takePos = nil, dropPos = nil, running = false, sessionToken = 0, thread = nil, status = "Idle", itemId = nil, progress = 0 }
}
SYT_Logic.MoveBlock = MoveBlock

function MoveBlock.SetTake()
    local pos = Core.ReadPos()
    MoveBlock.State.takePos = { x = pos.tx, y = pos.ty }
    MoveBlock.State.status = string.format("Take=(%d,%d)", pos.tx, pos.ty)
    if UI then
        UI:SetValue("MoveTakeDisplay", string.format("(%d, %d)", pos.sx, pos.sy))
        UI:SetValue("MoveBlockStatus", MoveBlock.State.status)
    end
end

function MoveBlock.SetDrop()
    local pos = Core.ReadPos()
    MoveBlock.State.dropPos = { x = pos.tx, y = pos.ty }
    MoveBlock.State.status = string.format("Drop=(%d,%d)", pos.tx, pos.ty)
    if UI then
        UI:SetValue("MoveDropDisplay", string.format("(%d, %d)", pos.sx, pos.sy))
        UI:SetValue("MoveBlockStatus", MoveBlock.State.status)
    end
end

function MoveBlock.Stop()
    MoveBlock.State.running = false
    MoveBlock.State.sessionToken += 1
    if MoveBlock.State.thread then
        pcall(task.cancel, MoveBlock.State.thread)
        MoveBlock.State.thread = nil
    end
    MoveBlock.State.status = "Stopped"
    if UI then UI:SetValue("MoveBlockStatus", MoveBlock.State.status) end
    if UIHooks.updateButtons then UIHooks.updateButtons() end
end

function MoveBlock.Start()
    if MoveBlock.State.running then return true end
    if not guardExclusiveStart("MoveBlock") then return false end
    if not MoveBlock.State.takePos or not MoveBlock.State.dropPos then
        emitNotify("Move Block", "Set Take dan Drop position dulu!")
        return false
    end
    Core.EnsureInit()
    MoveBlock.State.running = true
    MoveBlock.State.sessionToken += 1
    local tok = MoveBlock.State.sessionToken
    local function alive() return MoveBlock.State.running and MoveBlock.State.sessionToken == tok end
    if UIHooks.updateButtons then UIHooks.updateButtons() end

    MoveBlock.State.thread = task.spawn(function()
        while alive() do
            local tp = MoveBlock.State.takePos
            local dp = MoveBlock.State.dropPos
            -- 1. Cek apakah sudah ada item non-gems di backpack atau deteksi dari drop di posisi Take
            local beforeCounts = {}
            for _, sl in ipairs(Core.GetBackpackSlots()) do
                if sl.id ~= 18 and sl.id ~= 32 and sl.id ~= 112 then
                    beforeCounts[sl.id] = (beforeCounts[sl.id] or 0) + (sl.n or 0)
                end
            end

            MoveBlock.State.status = string.format("Walk -> Take (%d,%d)", tp.x, tp.y)
            if UI then UI:SetValue("MoveBlockStatus", MoveBlock.State.status) end
            Packets.WalkTeleport({ tx = tp.x, ty = tp.y, mode = "walk" })
            task.wait(0.15)
            if not alive() then break end

            Packets.Collect({ radius = 2.0, stepMoveIfFar = false, preferWalk = true, collectDelay = 0.05, shouldContinue = alive })
            task.wait(0.15)

            -- Otomatis tentukan block/item ID yang bertambah di BP setelah collect
            local targetId, targetCount = MoveBlock.State.itemId, 0
            for _, sl in ipairs(Core.GetBackpackSlots()) do
                if sl.id ~= 18 and sl.id ~= 32 and sl.id ~= 112 then
                    local diff = (sl.n or 0) - (beforeCounts[sl.id] or 0)
                    if diff > 0 then
                        targetId = sl.id
                        MoveBlock.State.itemId = targetId
                        break
                    end
                end
            end
            if not targetId then
                -- Fallback: ambil block/seed pertama yang ada jumlah > 0 di BP
                for _, sl in ipairs(Core.GetBackpackSlots()) do
                    if sl.id ~= 18 and sl.id ~= 32 and sl.id ~= 112 and (sl.n or 0) > 0 then
                        targetId = sl.id
                        break
                    end
                end
            end
            if targetId then targetCount = Core.CountItem(targetId) end

            if targetId and targetCount > 0 then
                MoveBlock.State.status = string.format("Walk -> Drop %s x%d (%d,%d)", Core.GetItemName(targetId), targetCount, dp.x, dp.y)
                if UI then UI:SetValue("MoveBlockStatus", MoveBlock.State.status) end
                Packets.WalkTeleport({ tx = dp.x, ty = dp.y, mode = "walk" })
                task.wait(0.15)
                if not alive() then break end
                Packets.Drop(targetId, targetCount)
            else
                MoveBlock.State.status = "Menunggu drop di Take..."
                if UI then UI:SetValue("MoveBlockStatus", MoveBlock.State.status) end
            end

            -- Delay 2 detik sesuai spesifikasi README
            local dl = os.clock() + 2.0
            while os.clock() < dl and alive() do task.wait(0.05) end
        end
        if MoveBlock.State.sessionToken == tok then
            MoveBlock.State.running = false
            MoveBlock.State.thread = nil
            if UIHooks.updateButtons then UIHooks.updateButtons() end
        end
    end)
    return true
end

function MoveBlock.Toggle()
    if MoveBlock.State.running then return MoveBlock.Stop() end
    return MoveBlock.Start()
end

-- System & Security + Auto Leveling (Target L10 via Half-World ClearWorld & 7-8 Random Letter Worlds)
SystemModule = {
    State = {
        enabled = true,      -- ON / OFF security (Default ON + FREEZE)
        mode = "FREEZE",     -- "FREEZE" | "LEAVE"
        discordLog = false,  -- Sync join log to DiscordHook
        frozenByJoin = false,
        joinLogs = {},       -- Scrollable join entries
        knownPlayers = {},
        safeCount = 0,
    }
}
SYT_Logic.System = SystemModule

function SystemModule._pushJoinLog(name, isStaff, actionTag)
    local stamp = os.date("%H:%M:%S")
    local roleTag = isStaff and "[MOD]" or "[PLAYER]"
    local line = string.format("[%s] %s %s -> %s", stamp, roleTag, tostring(name or "-"), tostring(actionTag or "JOIN"))
    table.insert(SystemModule.State.joinLogs, 1, { text = line, isStaff = isStaff == true, name = tostring(name or "-") })
    while #SystemModule.State.joinLogs > 80 do
        table.remove(SystemModule.State.joinLogs)
    end
    if SystemModule.State.discordLog and DiscordHook and DiscordHook.State.url ~= "" then
        task.spawn(function() pcall(DiscordHook.Send, line) end)
    end
    if UIHooks.refreshSysLog then pcall(UIHooks.refreshSysLog) end
end

function SystemModule.CheckWorldEntrants()
    if not H.gt or (H.gt.name or "") == "" then return end
    local plrs = Core.GetInWorldPlayers(false)
    local curWorld = cleanWorldName(H.gt.name)
    local currentSet = {}
    for _, p in ipairs(plrs) do
        local k = curWorld .. ":" .. tostring(p.userId)
        currentSet[k] = true
        if not SystemModule.State.knownPlayers[k] then
            SystemModule.State.knownPlayers[k] = true
            local actionDesc = SystemModule.State.enabled and SystemModule.State.mode or "LOG ONLY"
            SystemModule._pushJoinLog(p.gameName, p.isStaff, actionDesc)
            if p.isStaff then
                emitNotify("MOD JOINED!", p.gameName .. " bergabung ke world!")
            end
            if SystemModule.State.enabled and not (AutoLeveling and AutoLeveling.State and AutoLeveling.State.running) then
                SystemModule.State.safeCount = (SystemModule.State.safeCount or 0) + 1
                if SystemModule.State.mode == "LEAVE" then
                    stopAllAutomationImpl("SYSTEM LEAVE: " .. p.gameName)
                    if H.Net and type(H.Net.call) == "function" then
                        pcall(H.Net.call, "LeaveWorld")
                    elseif H.gt and type(H.gt.enter) == "function" then
                        pcall(H.gt.enter, "EXIT")
                    end
                else
                    SystemModule.State.frozenByJoin = true
                    stopAllAutomationImpl("SYSTEM FREEZE: " .. p.gameName)
                    Core.ClearManualInput()
                end
            end
        end
    end
    for k in pairs(SystemModule.State.knownPlayers) do
        if k:sub(1, #curWorld + 1) == (curWorld .. ":") and not currentSet[k] then
            SystemModule.State.knownPlayers[k] = nil
        end
    end
end

function SystemModule._random78World()
    local len = math.random(7, 8)
    local chars = {}
    for i = 1, len do
        chars[i] = string.char(math.random(65, 90))
    end
    return table.concat(chars)
end

AutoLeveling = {
    State = {
        running = false, sessionToken = 0, thread = nil, status = "Idle",
        targetLevel = 10, switchingWorld = false,
        targetWorld = "", completedWorlds = {}
    }
}
SYT_Logic.AutoLeveling = AutoLeveling

function AutoLeveling.GetLevel()
    if LP then
        local lvAttr = LP:GetAttribute("PlayerLevel") or LP:GetAttribute("Level")
        if type(lvAttr) == "number" then return lvAttr end
    end
    if H.gt and type(rawget(H.gt, "level")) == "number" then return rawget(H.gt, "level") end
    return 0
end

function AutoLeveling.Stop(keepSaved)
    AutoLeveling.State.running = false
    AutoLeveling.State.switchingWorld = false
    AutoLeveling.State.sessionToken += 1
    if AutoLeveling.State.thread then
        pcall(task.cancel, AutoLeveling.State.thread)
        AutoLeveling.State.thread = nil
    end
    if not keepSaved then
        AutoLeveling.State.targetWorld = ""
        safeWriteStorage("syt_autolvl.dat", "")
        local ed = getEnv().__SYT_ENV_DATA
        if type(ed) == "table" and ed.rotSession and ed.rotSession.mode == "AutoLeveling" then
            ed.rotSession = nil
        end
    end
    ClearWorld.Stop(true)
    AutoLeveling.State.status = "Stopped"
    if UI then
        pcall(UI.SetValue, UI, "AutoLvlStatus", AutoLeveling.State.status)
        if not keepSaved then pcall(UI.SetValue, UI, "SysAutoLevelToggle", false, true) end
    end
    if UIHooks.updateButtons then UIHooks.updateButtons() end
end

function AutoLeveling.Start()
    if AutoLeveling.State.running then return true end
    if not guardExclusiveStart("AutoLeveling") then return false end
    Core.EnsureInit()
    local S = AutoLeveling.State
    S.running = true
    S.sessionToken += 1
    local tok = S.sessionToken
    local function alive() return S.running and S.sessionToken == tok end

    -- Registrasikan rerun via queue_on_teleport sekali jika terjadi server teleport saat AutoLevel
    if not H._qotAutoLvlRegistered then
        H._qotAutoLvlRegistered = true
        local qot = (type(queue_on_teleport) == "function" and queue_on_teleport)
            or (type(syn) == "table" and type(syn.queue_on_teleport) == "function" and syn.queue_on_teleport)
            or nil
        if qot then
            pcall(qot, 'task.delay(2, function() loadstring(game:HttpGet("https://raw.githubusercontent.com/Mytzcodes/GUIX/refs/heads/main/SYT.lua", true))() end)')
        end
    end

    local initWorld = cleanWorldName(H.gt and H.gt.name or "")
    S.targetWorld = initWorld ~= "" and initWorld or (S.targetWorld or "")
    safeWriteStorage("syt_autolvl.dat", "ON|" .. tostring(S.targetWorld or ""))
    do
        local ed = getEnv().__SYT_ENV_DATA or {}
        getEnv().__SYT_ENV_DATA = ed
        ed.rotSession = {
            mode = "AutoLeveling",
            targetWorld = S.targetWorld,
            completedWorlds = S.completedWorlds,
            active = true,
            updatedAt = os.clock(),
        }
    end
    if UIHooks.updateButtons then UIHooks.updateButtons() end

    S.thread = task.spawn(function()
        while alive() do
            Core.EnsureInit()
            local lv = AutoLeveling.GetLevel()
            if lv >= S.targetLevel then
                S.status = string.format("Target L%d Tercapai!", lv)
                safeWriteStorage("syt_autolvl.dat", "")
                local ed = getEnv().__SYT_ENV_DATA
                if type(ed) == "table" and ed.rotSession and ed.rotSession.mode == "AutoLeveling" then ed.rotSession = nil end
                if UI then
                    pcall(UI.SetValue, UI, "AutoLvlStatus", S.status)
                    pcall(UI.SetValue, UI, "SysAutoLevelToggle", false, true)
                end
                emitNotify("Auto Leveling", S.status)
                break
            end

            local curW = cleanWorldName(H.gt and H.gt.name or "")
            local others = Core.GetInWorldPlayers(false)
            -- Jika world kosong atau sudah pernah diselesaikan atau ada player lain, cari random world baru
            if #others > 0 or curW == "" or S.completedWorlds[curW] then
                local rw = SystemModule._random78World()
                S.targetWorld = rw
                safeWriteStorage("syt_autolvl.dat", "ON|" .. rw)
                local ed = getEnv().__SYT_ENV_DATA or {}
                getEnv().__SYT_ENV_DATA = ed
                ed.rotSession = { mode = "AutoLeveling", targetWorld = rw, completedWorlds = S.completedWorlds, active = true, updatedAt = os.clock() }
                S.switchingWorld = true
                H.intentionalSwitchUntil = os.clock() + 15.0
                S.status = string.format("Lv%d/10 | Warp -> %s", lv, rw)
                if UI then UI:SetValue("AutoLvlStatus", S.status) end
                local okRw = Packets.EnterWorldDoor(rw, alive)
                S.switchingWorld = false
                H.intentionalSwitchUntil = os.clock() + 3.5
                if not okRw and alive() then task.wait(1.6) end
            else
                -- Lanjut langsung di world saat ini tanpa mengulang pencarian random world
                S.targetWorld = curW
                safeWriteStorage("syt_autolvl.dat", "ON|" .. curW)
                local ed = getEnv().__SYT_ENV_DATA or {}
                getEnv().__SYT_ENV_DATA = ed
                ed.rotSession = { mode = "AutoLeveling", targetWorld = curW, completedWorlds = S.completedWorlds, active = true, updatedAt = os.clock() }
                S.status = string.format("Lv%d/10 | Half Clear %s", lv, curW)
                if UI then UI:SetValue("AutoLvlStatus", S.status) end
                ClearWorld.Start({ fromAutoLevel = true, halfWorld = true, noCollect = true })
                while ClearWorld.State.running and alive() do
                    if AutoLeveling.GetLevel() >= S.targetLevel then
                        ClearWorld.Stop(true)
                        break
                    end
                    if #Core.GetInWorldPlayers(false) > 0 then
                        S.completedWorlds[curW] = true
                        ClearWorld.Stop(true)
                        break
                    end
                    S.status = string.format("Lv%d/10 | %s (%d%%)", AutoLeveling.GetLevel(), cleanWorldName(H.gt and H.gt.name or curW), ClearWorld.State.progress or 0)
                    if UI then UI:SetValue("AutoLvlStatus", S.status) end
                    task.wait(0.4)
                end
                if alive() and AutoLeveling.GetLevel() < S.targetLevel then
                    S.completedWorlds[curW] = true
                    local rw = SystemModule._random78World()
                    S.targetWorld = rw
                    safeWriteStorage("syt_autolvl.dat", "ON|" .. rw)
                    ed.rotSession = { mode = "AutoLeveling", targetWorld = rw, completedWorlds = S.completedWorlds, active = true, updatedAt = os.clock() }
                    S.switchingWorld = true
                    H.intentionalSwitchUntil = os.clock() + 15.0
                    S.status = string.format("Lv%d/10 | Next Random -> %s", AutoLeveling.GetLevel(), rw)
                    if UI then UI:SetValue("AutoLvlStatus", S.status) end
                    local okRw2 = Packets.EnterWorldDoor(rw, alive)
                    S.switchingWorld = false
                    H.intentionalSwitchUntil = os.clock() + 3.5
                    if not okRw2 and alive() then task.wait(1.6) end
                end
            end
            task.wait(0.25)
        end
        if S.sessionToken == tok then
            S.running = false
            S.switchingWorld = false
            ClearWorld.Stop(true)
            S.thread = nil
            if UIHooks.updateButtons then UIHooks.updateButtons() end
        end
    end)
    return true
end

function AutoLeveling.Toggle()
    if AutoLeveling.State.running then return AutoLeveling.Stop() end
    return AutoLeveling.Start()
end

-- Override Misc Engine Features to match exact README.MD specifications:
-- 1. Ghost/NoClip (pure visual movement only - no server move - returns to start position on OFF)
function Misc.SetNoClip(enabled)
    Core.EnsureInit()
    Core.EnsureMoveHook()
    pcall(RunService.UnbindFromRenderStep, RunService, "SYT_NoClipStep")
    if H.noClipConn then
        pcall(function() H.noClipConn:Disconnect() end)
        H.noClipConn = nil
    end

    local gt = H.gt
    if not gt then
        Misc.State.noClip = false
        return false
    end

    local on = enabled == true
    if on then
        if Misc.State.fly then
            Misc.SetFly(false)
        end
        local pos = Core.ReadPos()
        local anchor = { x = pos.x, y = pos.y, tx = pos.tx, ty = pos.ty, sx = pos.sx, sy = pos.sy }
        Misc.State.noClipAnchor = anchor
        Misc.State.noClip = true
        -- Kunci posisi server pada posisi awal sebelum NoClip & aktifkan visual ghost
        Core.SetLocalCoords(anchor.x, anchor.y, 0, 0)
        gt.ghost = true
        gt.stuckAt = nil
        gt.portalGo = nil
        if type(SYT_Logic.InstallNetGuard) == "function" then pcall(SYT_Logic.InstallNetGuard) end
        if UI then
            pcall(UI.SetValue, UI, "MiscNoClipStatus", string.format("VISUAL ON | Anchor (%d,%d)", anchor.sx, anchor.sy))
        end

        local visX, visY = anchor.x, anchor.y
        local lastHudAt = 0
        local touchBtns = { left = {}, right = {}, up = {}, down = {} }
        local function scanTouchBtns()
            touchBtns = { left = {}, right = {}, up = {}, down = {} }
            pcall(function()
                local pg = LP and LP:FindFirstChildOfClass("PlayerGui")
                local gg = pg and pg:FindFirstChild("GameGui")
                if gg then
                    for _, d in ipairs(gg:GetDescendants()) do
                        if d:IsA("GuiButton") and d.Visible then
                            local nm = string.lower(d.Name)
                            if string.find(nm, "left", 1, true) then table.insert(touchBtns.left, d)
                            elseif string.find(nm, "right", 1, true) then table.insert(touchBtns.right, d)
                            elseif string.find(nm, "jump", 1, true) or string.find(nm, "up", 1, true) then table.insert(touchBtns.up, d)
                            elseif string.find(nm, "down", 1, true) or string.find(nm, "crouch", 1, true) then table.insert(touchBtns.down, d) end
                        end
                    end
                end
            end)
        end
        local function anyTouchDown(list)
            for _, b in ipairs(list) do
                if b.Parent and b.Visible and b.GuiState == Enum.GuiState.Press then return true end
            end
            return false
        end
        scanTouchBtns()

        local alive = true
        RunService:BindToRenderStep("SYT_NoClipStep", Enum.RenderPriority.Last.Value + 18, function(dt)
            if not alive or getEnv().__SYT_SCRIPT_TOKEN ~= MY_SCRIPT_TOKEN or not Misc.State.noClip or H.gt ~= gt then
                alive = false
                pcall(RunService.UnbindFromRenderStep, RunService, "SYT_NoClipStep")
                return
            end
            gt.ghost = true
            gt.stuckAt = nil
            gt.portalGo = nil

            local frameDt = clamp(tonumber(dt) or 0.016, 0.004, 0.06)
            local speed = 13.5
            local mvX, mvY = 0, 0
            if not UserInputService:GetFocusedTextBox() then
                if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left) or anyTouchDown(touchBtns.left) then mvX -= 1 end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) or anyTouchDown(touchBtns.right) then mvX += 1 end
                if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up) or UserInputService:IsKeyDown(Enum.KeyCode.Space) or anyTouchDown(touchBtns.up) then mvY -= 1 end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down) or UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or anyTouchDown(touchBtns.down) then mvY += 1 end
            end

            if mvX ~= 0 or mvY ~= 0 then
                local mag = math.sqrt(mvX * mvX + mvY * mvY)
                if mag > 0 then mvX, mvY = mvX / mag, mvY / mag end
                visX = clamp(visX + mvX * speed * frameDt, 0.5, math.max(1, (gt.w or 100) - 0.5))
                visY = clamp(visY + mvY * speed * frameDt, 0.25, math.max(1, (gt.h or 60) - 0.5))
            end

            Core.SetLocalCoords(visX, visY, 0, 0)
            local now = os.clock()
            if UI and (now - lastHudAt) >= 0.30 then
                lastHudAt = now
                pcall(UI.SetValue, UI, "MiscNoClipStatus", string.format("VISUAL (%d,%d) | Anchor (%d,%d)", math.floor(visX) + 1, math.floor(visY) + 1, anchor.sx, anchor.sy))
            end
        end)
        H.noClipConn = {
            Disconnect = function()
                alive = false
                pcall(RunService.UnbindFromRenderStep, RunService, "SYT_NoClipStep")
            end
        }
        getEnv().__SYT_NOCLIP_CONN = H.noClipConn
    else
        local anchor = Misc.State.noClipAnchor
        Misc.State.noClip = false
        Misc.State.noClipAnchor = nil
        gt.ghost = (Misc.State.fly == true)
        gt.stuckAt = nil
        gt.portalGo = nil
        if anchor then
            local function restoreAnchor()
                if H.gt == gt and not Misc.State.noClip then
                    gt.stuckAt = nil
                    gt.portalGo = nil
                    Core.SetLocalCoords(anchor.x, anchor.y, 0, 0)
                end
            end
            restoreAnchor()
            Packets.SendRawMove(anchor.x, anchor.y, 0, 0, 2, { forceBypass = true })
            task.defer(restoreAnchor)
            task.delay(0.05, restoreAnchor)
            if UI then
                pcall(UI.SetValue, UI, "MiscNoClipStatus", string.format("OFF | Returned (%d,%d)", anchor.sx, anchor.sy))
            end
        elseif UI then
            pcall(UI.SetValue, UI, "MiscNoClipStatus", "Idle")
        end
    end
    return Misc.State.noClip
end

-- 2. Bounded Fly (max +5 up, max +-4 left/right from start, visual barrier indicators, fall on OFF)
do
local flyBarriers = {}
local function clearFlyBarriers()
    for _, b in ipairs(flyBarriers) do pcall(function() b:Destroy() end) end
    table.clear(flyBarriers)
end

local function showFlyBarrierFeedback(reasonTxt)
    local now = os.clock()
    if (H._lastFlyWallAt or 0) + 0.6 < now then
        H._lastFlyWallAt = now
        local pos = Core.ReadPos()
        if H.gt and type(H.gt.floatText) == "function" then
            pcall(H.gt.floatText, pos.x, pos.y - 1.4, reasonTxt, Color3.fromRGB(248, 113, 113))
        end
    end
end

function Misc.SetFly(enabled)
    Core.EnsureInit()
    Core.EnsureMoveHook()
    unbindFlyRenderStep()
    clearFlyBarriers()
    if H.flyConn then H.flyConn:Disconnect(); H.flyConn = nil end
    Misc.State.fly = enabled == true
    local gt = H.gt
    if not gt then return false end

    if not Misc.State.fly then
        gt.ghost = (Misc.State.noClip == true)
        -- Jatuh dari posisi saat ini (tidak kembali ke origin)
        local p = Core.ReadPos()
        Core.SetLocalCoords(p.x, p.y, 0, 0.2)
        Packets.SendRawMove(p.x, p.y, 0, 0, 0)
        return false
    end

    pcall(Core.InstallAntiBackGuard)
    if type(SYT_Logic.InstallNetGuard) == "function" then pcall(SYT_Logic.InstallNetGuard) end
    local p0 = Core.ReadPos()
    local visX, visY = p0.x, p0.y
    local syncX, syncY = p0.x, p0.y
    local minX = math.max(0.5, p0.x - 4.0)
    local maxX = math.min(math.max(1, (gt.w or 100) - 0.5), p0.x + 4.0)
    local minY = math.max(0.35, p0.y - 5.0)
    local maxY = math.min(math.max(1, (gt.h or 60) - 0.5), p0.y + 0.5)
    local lastSyncAt, facing = os.clock(), 1

    -- Buat penanda batas visual blok pada HUD (atas -5, kiri -4, kanan +4)
    local parentHud = getSafeHui() or CoreGui or (LP and LP:FindFirstChildOfClass("PlayerGui"))
    if parentHud then
        local bgui = Instance.new("ScreenGui")
        bgui.Name = "SYT_FlyBarrierHud"
        bgui.IgnoreGuiInset = true
        bgui.ResetOnSpawn = false
        bgui.Parent = parentHud
        flyBarriers[#flyBarriers + 1] = bgui
        local pill = Instance.new("TextLabel", bgui)
        pill.Size = UDim2.fromOffset(250, 24)
        pill.AnchorPoint = Vector2.new(0.5, 0)
        pill.Position = UDim2.new(0.5, 0, 0, 8)
        pill.BackgroundColor3 = Color3.fromRGB(15, 23, 42)
        pill.BackgroundTransparency = 0.2
        pill.Font = Enum.Font.Code
        pill.TextSize = 11
        pill.TextColor3 = Color3.fromRGB(250, 204, 21)
        pill.Text = "FLY BARRIER | X:-4..+4 | UP:+5"
        Instance.new("UICorner", pill).CornerRadius = UDim.new(0, 6)
        flyBarriers[#flyBarriers + 1] = pill
    end

    gt.ghost = true
    gt.stuckAt = nil
    H.lastSentMove = { x = syncX, y = syncY, vx = 0, vy = 0, flags = 3, t = lastSyncAt }
    Packets.SendRawMove(syncX, syncY, 0, 0, 3)

    local alive = true
    RunService:BindToRenderStep("SYT_FlyStep", Enum.RenderPriority.Last.Value + 20, function(dt)
        if not alive or getEnv().__SYT_SCRIPT_TOKEN ~= MY_SCRIPT_TOKEN or not Misc.State.fly or H.gt ~= gt then
            alive = false
            unbindFlyRenderStep()
            clearFlyBarriers()
            return
        end
        gt.ghost = true
        gt.stuckAt = nil
        local frameDt = clamp(tonumber(dt) or 0.016, 0.004, 0.06)
        local speed = 10.5
        local mvX, mvY = 0, 0
        if not UserInputService:GetFocusedTextBox() then
            if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left) then mvX -= 1 end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then mvX += 1 end
            if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up) or UserInputService:IsKeyDown(Enum.KeyCode.Space) then mvY -= 1 end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down) then mvY += 1 end
        end
        if mvX ~= 0 then facing = (mvX > 0) and 1 or -1 end
        local mag = math.sqrt(mvX * mvX + mvY * mvY)
        if mag > 0 then mvX, mvY = mvX / mag, mvY / mag end

        local nextX = visX + mvX * speed * frameDt
        local nextY = visY + mvY * speed * frameDt
        if nextX < minX then nextX = minX; showFlyBarrierFeedback("[BARRIER] Batas Kiri (-4)") end
        if nextX > maxX then nextX = maxX; showFlyBarrierFeedback("[BARRIER] Batas Kanan (+4)") end
        if nextY < minY then nextY = minY; showFlyBarrierFeedback("[BARRIER] Batas Atas (+5)") end
        if nextY > maxY then nextY = maxY end
        visX, visY = nextX, nextY
        Core.SetLocalCoords(visX, visY, 0, 0)

        local now = os.clock()
        local elapsed = now - lastSyncAt
        if elapsed >= 0.068 then
            local stepDx = clamp(visX - syncX, -1.0, 1.0)
            local stepDy = clamp(visY - syncY, -1.1, 1.1)
            syncX, syncY = syncX + stepDx, syncY + stepDy
            Packets.SendRawMove(syncX, syncY, 0, 0, (facing > 0 and 1 or 0) + 2)
            lastSyncAt = now
        end
    end)
    H.flyConn = { Disconnect = function() alive = false; unbindFlyRenderStep(); clearFlyBarriers() end }
    return true
end

-- 3. Zoom 2.5x Out (anti-overshoot render boundary + auto tile pool rebuild)
Misc.State.zoom25x = false
local function unbindModZoomStep()
    pcall(RunService.UnbindFromRenderStep, RunService, "SYT_ModZoomStep")
end

local function resolveZoomParts(gt)
    local worldScale = nil
    if H.renderFn then
        for idx = 1, 160 do
            local val = uv(H.renderFn, idx)
            if val == nil and idx > 110 then break end
            if typeof(val) == "Instance" and val:IsA("UIScale") then
                worldScale = val
                break
            end
        end
    end
    if not worldScale and LP then
        local pg = LP:FindFirstChildOfClass("PlayerGui")
        local gg = pg and pg:FindFirstChild("GameGui")
        if gg then
            for _, d in ipairs(gg:GetDescendants()) do
                if d:IsA("UIScale") and d.Parent and d.Parent.Name == "Camera" then
                    worldScale = d
                    break
                end
            end
        end
    end
    local viewport = (worldScale and worldScale.Parent and worldScale.Parent.Parent and worldScale.Parent.Parent:IsA("GuiObject")) and worldScale.Parent.Parent or nil
    local vw, vh = 1280, 720
    if viewport and viewport.AbsoluteSize.X > 32 and viewport.AbsoluteSize.Y > 32 then
        vw, vh = viewport.AbsoluteSize.X, viewport.AbsoluteSize.Y
    else
        local cam = workspace.CurrentCamera
        if cam and cam.ViewportSize.X > 32 and cam.ViewportSize.Y > 32 then
            vw, vh = cam.ViewportSize.X, cam.ViewportSize.Y
        end
    end
    return worldScale, viewport, vw, vh
end

local function computeSafeModZoomMin(gt, baseMin)
    local _, _, vw, vh = resolveZoomParts(gt)
    local w = (gt and tonumber(rawget(gt, "w")) and gt.w > 1) and gt.w or 100
    local h = (gt and tonumber(rawget(gt, "h")) and gt.h > 1) and gt.h or 60
    -- Jaga agar layar saat zoom out tidak melebihi batas render world (w x h)
    local minPx = math.max(1, math.ceil(math.max(vw / math.max(1, w - 1), vh / math.max(1, h - 1))))
    local worldFitMin = minPx / 64
    local raw25x = baseMin / 2.5
    return clamp(math.max(raw25x, worldFitMin), 0.24, baseMin)
end

local function rebuildWorldTilePool(gt, viewport)
    if type(getconnections) ~= "function" or not gt or not viewport then return end
    local okC, conns = pcall(getconnections, viewport:GetPropertyChangedSignal("AbsoluteSize"))
    if okC and type(conns) == "table" then
        for _, c in ipairs(conns) do
            local fn = type(c) == "table" and (c.Function or c["function"]) or nil
            if type(fn) == "function" then
                local hasGt = false
                for idx = 1, 32 do
                    if uv(fn, idx) == gt then hasGt = true; break end
                end
                if hasGt then pcall(fn) end
            end
        end
    end
end

local function clampZoomInputUpvalues(gt, minAllowed, maxAllowed)
    if type(getconnections) ~= "function" or not gt then return end
    local minZ = clamp(tonumber(minAllowed) or 0.24, 0.24, 1.6)
    local maxZ = clamp(tonumber(maxAllowed) or 1.6, minZ, 2.0)
    for _, sig in ipairs({ UserInputService.InputChanged, UserInputService.TouchPinch }) do
        local okC, conns = pcall(getconnections, sig)
        if okC and type(conns) == "table" then
            for _, c in ipairs(conns) do
                local fn = type(c) == "table" and (c.Function or c["function"]) or nil
                if type(fn) == "function" then
                    local gtIdx = nil
                    local numSlots = {}
                    for idx = 1, 8 do
                        local val = uv(fn, idx)
                        if val == gt then
                            gtIdx = idx
                        elseif type(val) == "number" and val >= 0.05 and val <= 2.5 then
                            numSlots[#numSlots + 1] = { idx = idx, val = val }
                        end
                    end
                    if gtIdx then
                        for _, ns in ipairs(numSlots) do
                            if ns.val < minZ then
                                suv(fn, ns.idx, minZ)
                            elseif ns.val > maxZ then
                                suv(fn, ns.idx, maxZ)
                            end
                        end
                    end
                end
            end
        end
    end
end

function Misc.SetZoom25x(enabled)
    Core.EnsureInit()
    local on = enabled == true
    Misc.State.zoom25x = on
    local gt = H.gt
    if on then
        if Misc.State._origCamMaxZoom == nil and LP then
            pcall(function() Misc.State._origCamMaxZoom = LP.CameraMaxZoomDistance end)
        end
        if gt and Misc.State._hadOrigGtZoomMin == nil then
            local rawMin = rawget(gt, "zoomMin")
            Misc.State._hadOrigGtZoomMin = (type(rawMin) == "number")
            Misc.State._origGtZoomMin = (type(rawMin) == "number") and rawMin or 0.6
        end
        local baseMin = clamp(tonumber(Misc.State._origGtZoomMin) or 0.6, 0.35, 1.0)
        local safeMin = computeSafeModZoomMin(gt, baseMin)
        Misc.State._lastSafeZoomMin = safeMin

        if gt then
            gt.zoomMin = safeMin
        end
        if LP then
            pcall(function() LP:SetAttribute("ModZoom", true) end)
            pcall(function()
                if Misc.State._origCamMaxZoom then
                    LP.CameraMaxZoomDistance = math.min(400, Misc.State._origCamMaxZoom * 2.5)
                end
            end)
        end
        if gt then
            gt.zoomMin = safeMin
            local _, viewport = resolveZoomParts(gt)
            rebuildWorldTilePool(gt, viewport)
            clampZoomInputUpvalues(gt, safeMin, 1.6)
        end

        unbindModZoomStep()
        local lastPoolZoomMin = safeMin
        pcall(RunService.BindToRenderStep, RunService, "SYT_ModZoomStep", Enum.RenderPriority.First.Value + 5, function()
            if not Misc.State.zoom25x or getEnv().__SYT_SCRIPT_TOKEN ~= MY_SCRIPT_TOKEN then
                unbindModZoomStep()
                return
            end
            local g = H.gt
            if not g then return end
            local bMin = clamp(tonumber(Misc.State._origGtZoomMin) or 0.6, 0.35, 1.0)
            local curSafe = computeSafeModZoomMin(g, bMin)
            Misc.State._lastSafeZoomMin = curSafe
            if rawget(g, "zoomMin") ~= curSafe then
                g.zoomMin = curSafe
                if math.abs(curSafe - lastPoolZoomMin) > 0.008 then
                    lastPoolZoomMin = curSafe
                    local _, vp = resolveZoomParts(g)
                    rebuildWorldTilePool(g, vp)
                end
            end
            clampZoomInputUpvalues(g, curSafe, 1.6)
        end)

        task.defer(function()
            if not Misc.State.zoom25x or getEnv().__SYT_SCRIPT_TOKEN ~= MY_SCRIPT_TOKEN then return end
            local g = H.gt
            if not g then return end
            local bMin = clamp(tonumber(Misc.State._origGtZoomMin) or 0.6, 0.35, 1.0)
            local sMin = computeSafeModZoomMin(g, bMin)
            g.zoomMin = sMin
            local _, vp = resolveZoomParts(g)
            rebuildWorldTilePool(g, vp)
            clampZoomInputUpvalues(g, sMin, 1.6)
        end)
    else
        unbindModZoomStep()
        local baseMin = clamp(tonumber(Misc.State._origGtZoomMin) or 0.6, 0.35, 1.0)
        if LP then
            pcall(function() LP:SetAttribute("ModZoom", nil) end)
            pcall(function()
                if Misc.State._origCamMaxZoom then
                    LP.CameraMaxZoomDistance = Misc.State._origCamMaxZoom
                end
            end)
        end
        if gt then
            gt.zoomMin = Misc.State._hadOrigGtZoomMin and Misc.State._origGtZoomMin or nil
            if type(rawget(gt, "zoom")) == "number" and gt.zoom < baseMin then
                gt.zoom = baseMin
            end
            local _, viewport = resolveZoomParts(gt)
            rebuildWorldTilePool(gt, viewport)
            clampZoomInputUpvalues(gt, baseMin, 1.6)
        end
    end
    return on
end

-- 4. Skip Update Item
Misc.State.skipUpdateItem = false
function Misc.SetSkipUpdateItem(enabled)
    local on = enabled == true
    Misc.State.skipUpdateItem = on
    GetcSkipper.SetSkipUpdateItems(on)
    if H._skipUpdConn then H._skipUpdConn:Disconnect(); H._skipUpdConn = nil end
    if on then
        local function hideLoadingBanners()
            local pg = LP and LP:FindFirstChildOfClass("PlayerGui")
            if not pg then return end
            for _, obj in ipairs(pg:GetDescendants()) do
                if obj:IsA("TextLabel") and obj.Visible then
                    local txt = string.lower(obj.Text or "")
                    if string.find(txt, "updating", 1, true) or string.find(txt, "entering", 1, true) then
                        local f = obj:FindFirstAncestorOfClass("Frame")
                        if f and f.Name ~= "Console" then f.Visible = false end
                    end
                end
            end
        end
        hideLoadingBanners()
        local pg = LP and LP:FindFirstChildOfClass("PlayerGui")
        if pg then
            H._skipUpdConn = pg.DescendantAdded:Connect(function(obj)
                if Misc.State.skipUpdateItem and obj:IsA("TextLabel") then
                    task.defer(hideLoadingBanners)
                end
            end)
        end
    end
    return on
end

-- 5. Slow Fall (2x lebih lambat dari jatuh normal)
Misc.State.slowFall = false
function Misc.SetSlowFall(enabled)
    local on = enabled == true
    Misc.State.slowFall = on
    pcall(RunService.UnbindFromRenderStep, RunService, "SYT_SlowFallStep")
    if on then
        local lastY, lastVelSet = nil, 0
        RunService:BindToRenderStep("SYT_SlowFallStep", Enum.RenderPriority.Last.Value + 10, function(dt)
            if not Misc.State.slowFall or getEnv().__SYT_SCRIPT_TOKEN ~= MY_SCRIPT_TOKEN then
                pcall(RunService.UnbindFromRenderStep, RunService, "SYT_SlowFallStep")
                return
            end
            local gt = H.gt
            if not gt or (gt.name or "") == "" or Misc.State.fly or Misc.State.noClip then
                lastY = nil
                return
            end
            local p = Core.ReadPos()
            if not p.grounded and p.vy > 0.45 then
                -- Kurangi kenaikan jatuh sebesar 50% (2x lebih lambat)
                if lastY and p.y > lastY then
                    local dy = p.y - lastY
                    local slowY = lastY + dy * 0.5
                    Core.SetLocalCoords(p.x, slowY, p.vx, p.vy * 0.5)
                    p.y = slowY
                end
                if os.clock() - lastVelSet > 0.08 then
                    lastVelSet = os.clock()
                    Core.SetLocalCoords(p.x, p.y, p.vx, math.min(p.vy, 6.5))
                end
            end
            lastY = p.y
        end)
    end
    return on
end
end

-- Enhance Spam per README.MD: Random `0..`9 per-word rainbow OR single prefix, REQUIRED empty check, send first then delay
do
Spam.State.maxLength = 85
Spam.State.rainbowOn = false
Spam.State.prefixOn = false
Spam.State.delay = 5.0

local function randColorCode()
    return "`" .. tostring(math.random(0, 9))
end

function Spam.FormatNextMessage()
    local S = Spam.State
    local raw = tostring(S.text or ""):sub(1, 85)
    if S.rainbowOn then
        local words = {}
        for w in raw:gmatch("%S+") do
            words[#words + 1] = randColorCode() .. " " .. w
        end
        return table.concat(words, " "):sub(1, 85)
    elseif S.prefixOn then
        return (randColorCode() .. " " .. raw):sub(1, 85)
    end
    return raw
end

function Spam.Start()
    Core.EnsureInit()
    local S = Spam.State
    if S.running then return true end
    local curInput = UI and UI:GetValue("SpamTextInput")
    if type(curInput) == "string" and curInput ~= "REQUIRED" then
        S.text = curInput:sub(1, 85)
    end
    if not S.text or S.text == "" or S.text == "REQUIRED" then
        S.text = ""
        if UI then UI:SetValue("SpamTextInput", "REQUIRED") end
        setSpamStatus("REQUIRED: Isi pesan spam dulu!")
        emitNotify("Spam", "Text wajib diisi (REQUIRED)")
        return false
    end
    S.running = true
    S.sessionToken += 1
    local token = S.sessionToken
    local function alive() return S.running and S.sessionToken == token end
    setSpamStatus("Spamming...")

    S.thread = task.spawn(function()
        Core.EnsureOutboundFirewall()
        while alive() do
            if not H.gt or H.gt.name == "" then break end
            local msg = Spam.FormatNextMessage()
            Packets.SendChat({ message = msg, maxLength = 85, shouldContinue = alive })
            local d = clamp(tonumber(S.delay) or 5.0, 3.0, 7.0)
            local dl = os.clock() + d
            while os.clock() < dl and alive() do task.wait(0.05) end
        end
        if S.sessionToken == token then
            S.running = false
            S.thread = nil
            setSpamStatus("Stopped")
        end
    end)
    return true
end
end

-- Enhance PNB with README.MD Storage Block, Safe, Auto Buy (5x gems, 2s delay)
PNB.State.storageBlock = ""
PNB.State.storageSafe = ""
PNB.State.autoBuyKey = "OFF"
PNB.State.speedPct = 60
PNB.State.switchingWorld = false
PNB.State.progress = 0

H._origPnbStop = PNB.Stop
function PNB.Stop()
    PNB.State.running = false
    PNB.State.switchingWorld = false
    PNB.State.sessionToken += 1
    if PNB.State.thread then
        pcall(task.cancel, PNB.State.thread)
        PNB.State.thread = nil
    end
    Core.ClearManualInput()
    setPNBStatus("Stopped", "Idle", "Cycle: " .. tostring(PNB.State.cycles or 0))
    if UIHooks.updateButtons then
        pcall(UIHooks.updateButtons)
        task.delay(0.62, function() if UIHooks.updateButtons then pcall(UIHooks.updateButtons) end end)
    end
    return false
end

H._origPnbStart = PNB.Start
function PNB.Start()
    if PNB.State.running then return true end
    if not guardExclusiveStart("PNB") then return false end
    Core.EnsureInit()
    local S = PNB.State
    if not S.selectedBlockId then
        setPNBStatus("Pilih block di Block Selector!", "Waiting Block", "-")
        emitNotify("PNB", "Pilih block dulu di Block Selector!")
        if UIHooks.updateButtons then pcall(UIHooks.updateButtons) end
        return false
    end
    if #PNB.GetActiveOffsets() == 0 then
        setPNBStatus("Pilih minimal 1 tile pada Pad 5x5", "Waiting Pad", "-")
        emitNotify("PNB", "Pilih minimal 1 tile di Pad 5x5!")
        if UIHooks.updateButtons then pcall(UIHooks.updateButtons) end
        return false
    end
    if Core.CountItem(S.selectedBlockId) <= 0 and S.storageBlock == "" then
        setPNBStatus("Block habis & World Storage Block kosong", "No Block", "-")
        emitNotify("PNB", "Block habis di Backpack & Storage kosong!")
        if UIHooks.updateButtons then pcall(UIHooks.updateButtons) end
        return false
    end

    -- Speed 0-100% -> PNB.State.speed (1..10)
    local pct = clamp(tonumber(S.speedPct) or 60, 0, 100)
    S.speed = clamp(math.floor(1 + (pct / 100) * 9 + 0.5), 1, 10)
    S.oneHit = false

    S.running = true
    S.cycles = 0
    S.progress = 0
    S.sessionToken += 1
    local token = S.sessionToken
    local pos0 = Core.ReadPos()
    S.centerPos = { tx = pos0.tx, ty = pos0.ty }
    local pnbWorld = cleanWorldName(H.gt and H.gt.name or "")
    local function alive() return S.running and S.sessionToken == token end
    setPNBStatus("Running...", "Inspecting", "-")
    if UIHooks.updateButtons then
        pcall(UIHooks.updateButtons)
        task.delay(0.62, function() if UIHooks.updateButtons then pcall(UIHooks.updateButtons) end end)
    end

    local function warpToStorageAndBack(spec, taskKind, extraPayload)
        if not spec or spec == "" then return false end
        local originPos = S.centerPos
        S.switchingWorld = true
        setPNBStatus("Storage: Masuk " .. spec, "Storage", taskKind)
        local okW = Packets.EnterWorldDoor(spec, alive)
        if okW and alive() then
            if taskKind == "fetch" then
                local gt = H.gt
                if gt and type(gt.dropList) == "function" then
                    local okD, drops = pcall(gt.dropList)
                    if okD and type(drops) == "table" then
                        for _, d in ipairs(drops) do
                            if not alive() or Core.GetItemRoom(S.selectedBlockId) <= 0 then break end
                            if type(d) == "table" and d.id == S.selectedBlockId and (d.n or 0) > 0 then
                                Packets.WalkTeleport({ tx = math.floor(d.x), ty = math.floor(d.y), mode = "walk" })
                                Packets.Collect({ radius = 3, filterId = S.selectedBlockId, stepMoveIfFar = true, preferWalk = true, collectDelay = 0.05, shouldContinue = alive })
                            end
                        end
                    end
                end
            elseif taskKind == "safe" and type(extraPayload) == "table" then
                for _, item in ipairs(extraPayload) do
                    if not alive() then break end
                    if Core.CountItem(item.id) >= item.amount then
                        Packets.Drop(item.id, item.amount)
                        SystemModule.State.safeCount = (SystemModule.State.safeCount or 0) + item.amount
                    end
                end
            end
        end
        if alive() and pnbWorld ~= "" then
            Packets.EnterWorldDoor(pnbWorld, alive)
            if alive() and originPos then
                Packets.WalkTeleport({ tx = originPos.tx, ty = originPos.ty, mode = "step", stepSize = 3 })
            end
        end
        S.switchingWorld = false
        return true
    end

    local function runAutoBuyCheck()
        local offer = findStoreOfferByDisplay(S.autoBuyKey)
        if not offer then return end
        local gems = Core.ReadGems()
        -- Minimal kelipatan 5 dari harga item sebelum memicu Auto Buy
        if gems < (offer.price * 5) then return end
        setPNBStatus(string.format("AutoBuy %s (Gems: %d >= 5x %d)", offer.name, gems, offer.price), "AutoBuy", offer.key)
        local boughtItems = {}
        while alive() do
            local curGems = Core.ReadGems()
            if curGems < offer.price then break end
            task.wait(2.0) -- Delay 2s sebelum buy
            if not alive() then break end
            local okB, resB = Packets.BuyStoreOffer(offer.key)
            task.wait(2.0) -- Delay 2s sesudah buy agar tidak crash
            if not okB then break end
            if type(resB) == "table" and type(resB.items) == "table" then
                for _, pair in ipairs(resB.items) do
                    if type(pair) == "table" and pair[1] then
                        boughtItems[pair[1]] = true
                    end
                end
            end
        end
        if alive() and S.storageSafe ~= "" then
            local payload = {}
            for id in pairs(boughtItems) do
                local c = Core.CountItem(id)
                if c > 0 then payload[#payload + 1] = { id = id, amount = c } end
            end
            if #payload > 0 then warpToStorageAndBack(S.storageSafe, "safe", payload) end
        end
    end

    local function checkSafeMultiples()
        if S.storageSafe == "" then return end
        local payload = {}
        -- Kelipatan 10 untuk Locks (WL=242, Small=202, Big=204, Huge=206) dan 200 untuk seed/SSP box
        for _, lockId in ipairs({ 242, 202, 204, 206, 4994 }) do
            local cnt = Core.CountItem(lockId)
            if cnt >= 10 then
                payload[#payload + 1] = { id = lockId, amount = math.floor(cnt / 10) * 10 }
            end
        end
        for _, sl in ipairs(Core.GetBackpackSlots()) do
            if sl.id ~= S.selectedBlockId and sl.id ~= 18 and sl.id ~= 32 and sl.id ~= 112 and (sl.n or 0) >= 200 then
                local info = Core.GetItemInfo(sl.id)
                if info and (info.kind == "seed" or string.find(string.lower(info.name or ""), "pack", 1, true)) then
                    payload[#payload + 1] = { id = sl.id, amount = 200 }
                end
            end
        end
        if #payload > 0 then
            warpToStorageAndBack(S.storageSafe, "safe", payload)
        end
    end

    S.thread = task.spawn(function()
        local function coolIfFwBlocked()
            if H.fwLastBlockAt and (os.clock() - H.fwLastBlockAt) < 0.45 then
                task.wait(0.35)
            end
        end

        local function returnToPnbCenter()
            local cp = S.centerPos
            if not cp then return true end
            local nowP = Core.ReadPos()
            if math.abs(nowP.tx - cp.tx) > 0 or math.abs(nowP.ty - cp.ty) > 0 then
                Packets.WalkPathTo(cp.tx, cp.ty, 7.1, alive, { fastWalk = false, noSnap = true })
            end
            return true
        end

        while alive() do
            if not H.gt or H.gt.name == "" then setPNBStatus("Keluar world", "Idle", "-"); break end
            if SystemModule.State.enabled and SystemModule.State.frozenByJoin then break end
            runAutoBuyCheck()
            checkSafeMultiples()

            local bid = S.selectedBlockId
            local startCnt = Core.CountItem(bid)
            if startCnt <= 0 then
                if S.storageBlock ~= "" then
                    warpToStorageAndBack(S.storageBlock, "fetch")
                    if Core.CountItem(bid) <= 0 then
                        setPNBStatus("Block habis di BP & Storage", "Selesai", "-")
                        break
                    end
                else
                    setPNBStatus("Block habis di Backpack", "Selesai", "-")
                    break
                end
            end

            returnToPnbCenter()
            if not alive() then break end

            local info = Core.GetItemInfo(bid)
            local layer = (info and info.background) and 2 or 1
            local cp = S.centerPos or Core.ReadPos()
            local centerStand = { x = cp.tx + 0.5, y = cp.ty + 1 }
            local targets = {}
            for _, off in ipairs(PNB.GetActiveOffsets()) do
                local tx, ty = cp.tx + off.dx, cp.ty + off.dy
                if tx >= 0 and tx < H.gt.w and ty >= 0 and ty < H.gt.h and Core.CanEditTile(tx, ty) then
                    if not (info and info.solid and layer == 1 and tx == cp.tx and ty == cp.ty) then
                        if Core.IsInActionReach(tx, ty, "break", centerStand) then
                            targets[#targets + 1] = { tx = tx, ty = ty, layer = layer }
                        end
                    end
                end
            end
            if #targets == 0 then setPNBStatus("Pilih tile dalam jangkauan", "Idle", "-"); break end

            local placeGap = math.max(H.adaptivePlaceGap or 0.174, clamp(0.34 - (pct / 100) * 0.165, 0.174, 0.34))
            local hitDelay = math.max(0.192, clamp(0.28 - (pct / 100) * 0.088, 0.192, 0.28))
            local nThreads = (pct >= 70 and #targets >= 2) and 2 or 1
            local cycleWait = clamp(0.08 - (pct / 100) * 0.05, 0.025, 0.08)

            local breakOpts = {
                layer = layer, threads = nThreads,
                oneHit = (S.oneHit == true), customHits = nil,
                hitDelay = hitDelay, verifyTimeout = 0.26,
                stable = 0.04, noLocalMirror = true,
                autoRange = false, preferWalk = true, walkSpeed = 7.1,
                showHand = S.showHand, showVisual = true, shouldContinue = alive,
            }

            local snap = inspectPnbTargets(targets, bid, layer)
            if #snap.foreign > 0 then
                setPNBStatus(string.format("Pre-Clean %d tile asing...", #snap.foreign), "Clean", "-")
                for _ = 1, 3 do
                    if not alive() then break end
                    coolIfFwBlocked()
                    local _, failedF = Packets.BreakVerified(snap.foreign, {
                        layer = layer, threads = 1, oneHit = false, customHits = nil,
                        hitDelay = hitDelay, verifyTimeout = 0.26, noLocalMirror = true,
                        autoRange = true, preferWalk = true, walkSpeed = 7.1,
                        showHand = S.showHand, showVisual = true, shouldContinue = alive,
                    })
                    if failedF == 0 then break end
                end
                snap = inspectPnbTargets(targets, bid, layer)
            end

            if #snap.empty > 0 and Core.CountItem(bid) > 0 then
                setPNBStatus(string.format("Fase 1: Place (%d%%)", pct), "Place", "-")
                returnToPnbCenter()
                for round = 1, 2 do
                    if not alive() then break end
                    local curSnap = inspectPnbTargets(targets, bid, layer)
                    if #curSnap.empty == 0 or Core.CountItem(bid) <= 0 then break end
                    for _, t in ipairs(curSnap.empty) do
                        if not alive() or Core.CountItem(bid) <= 0 then break end
                        coolIfFwBlocked()
                        Packets.PlaceVerified(t.tx, t.ty, bid, layer, {
                            showHand = S.showHand, delay = 0, noLocalMirror = false,
                            autoRange = false, preferWalk = true, walkSpeed = 7.1,
                            placeGap = placeGap, verifyTimeout = 0.24, shouldContinue = alive,
                        })
                    end
                end
                snap = inspectPnbTargets(targets, bid, layer)
            end

            if #snap.placed > 0 then
                setPNBStatus(string.format("Fase 2: Break (%d%%)", pct), "Break", "-")
                returnToPnbCenter()
                for _ = 1, 5 do
                    if not alive() then break end
                    local curS = inspectPnbTargets(targets, bid, layer)
                    if #curS.placed == 0 then break end
                    coolIfFwBlocked()
                    Packets.BreakVerified(curS.placed, breakOpts)
                end
                if S.autoCollect ~= false then
                    setPNBStatus(string.format("Fase 3: Collect (%d%%)", pct), "Collect", "-")
                    Packets.CollectVerified(targets, {
                        expectDrops = true, waitDrop = 0.14,
                        preferWalk = true, collectDelay = 0.02, shouldContinue = alive,
                    })
                    returnToPnbCenter()
                end
                S.cycles += 1
                S.progress = clamp(100 - math.floor((Core.CountItem(bid) / math.max(1, startCnt)) * 100), 1, 100)
                setPNBStatus(string.format("Cycle #%d | Sisa BP: %d", S.cycles, Core.CountItem(bid)), "OK", "Done")
            elseif snap.totalDrops > 0 and S.autoCollect ~= false then
                Packets.CollectVerified(targets, {
                    expectDrops = false, waitDrop = 0.10,
                    preferWalk = true, collectDelay = 0.02, shouldContinue = alive,
                })
                returnToPnbCenter()
            end
            task.wait(cycleWait)
        end
        if S.sessionToken == token then
            S.running = false
            S.thread = nil
            Core.ClearManualInput()
            if UIHooks.refreshBP then UIHooks.refreshBP() end
            if UIHooks.updateButtons then UIHooks.updateButtons() end
        end
    end)
    return true
end

function PNB.Toggle()
    if PNB.State.running then
        return PNB.Stop()
    end
    return PNB.Start()
end

-- Enhance Pabrik with Speed 0-100%, strict README flow, and progress tracking
Pabrik.State.speedPct = 60
Pabrik.State.progress = 0

H._origPabrikStart = Pabrik.Start
function Pabrik.Start()
    if Pabrik.State.running then return true end
    if not guardExclusiveStart("Pabrik") then return false end
    Core.EnsureInit()
    local S = Pabrik.State
    if not S.blockId or not S.seedId then setPabrikStatus("Pilih Block / Seed dulu"); return false end
    if #Pabrik.GetSortedTiles() == 0 then setPabrikStatus("Pilih tile Dirt dulu di Dirt Selector"); return false end
    if not S.breakPos then Pabrik.SetBreakPos() end
    local pct = clamp(tonumber(S.speedPct) or 60, 0, 100)
    local factor = 0.35 + (pct / 100) * 1.15
    S.placeDelay = clamp(0.18 / factor, 0.12, 0.30)
    S.breakDelay = clamp(0.18 / factor, 0.08, 0.25)
    S.collectDelay = clamp(0.06 / factor, 0.02, 0.12)
    return H._origPabrikStart()
end

-- Wrap DirtFarm.Start with Mutual Exclusion Check + FIFO Pop
H._origDfStart = DirtFarm.Start
function DirtFarm.Start()
    if DirtFarm.State.running then return true end
    if not guardExclusiveStart("DirtFarm") then return false end
    return H._origDfStart()
end

-- Discord Hook: Clean Running Status Embed + OS Storage MessageID (Only User Configured Webhook)
DiscordHook = {
    State = {
        url = "",
        delay = 120, -- 1-5 menit
        enabled = false,
        messageId = nil,
        startTime = nil,
        thread = nil,
        lastActionNote = "",
    }
}
SYT_Logic.DiscordHook = DiscordHook

function DiscordHook._jsonEscape(s)
    return tostring(s or ""):gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "")
end

function DiscordHook.GetSafeRequest()
    if type(syn) == "table" and type(syn.request) == "function" then return syn.request end
    if type(http_request) == "function" then return http_request end
    if type(request) == "function" then return request end
    return nil
end

function DiscordHook._activeFarmProgress()
    if PNB.State.running then return "PNB", tostring(PNB.State.progress or 0) .. "%" end
    if Pabrik.State.running then return "PABRIK", tostring(Pabrik.State.progress or 0) .. "%" end
    if DirtFarm.State.running then return "DIRT FARM", tostring(DirtFarm.State.status or "Running") end
    if ClearWorld.State.running then return "CLEAR WORLD", tostring(ClearWorld.State.progress or 0) .. "%" end
    if MoveBlock.State.running then return "MOVE BLOCK", tostring(MoveBlock.State.status or "Running") end
    if AutoLeveling.State.running then return "AUTO LEVELING", "Lv" .. tostring(AutoLeveling.GetLevel()) .. "/10" end
    return "IDLE", "0%"
end

function DiscordHook.Send(noteLine)
    local reqFn = DiscordHook.GetSafeRequest()
    if not reqFn or DiscordHook.State.url == "" then return false end
    if noteLine then DiscordHook.State.lastActionNote = tostring(noteLine) end

    local gt = H.gt
    local worldName = (gt and gt.name ~= "" and gt.name) or "-"
    local playerName = Core.GetInGameName(LP, true)
    local stName, progStr = DiscordHook._activeFarmProgress()
    local uptime = DiscordHook.State.startTime and math.floor(os.clock() - DiscordHook.State.startTime) or 0
    local uptimeStr = string.format("%02dh %02dm %02ds", math.floor(uptime / 3600), math.floor((uptime % 3600) / 60), uptime % 60)
    local safeTotal = tostring(SystemModule.State.safeCount or 0)
    if DiscordHook.State.lastActionNote ~= "" then
        safeTotal = safeTotal .. " | " .. DiscordHook.State.lastActionNote
    end

    local authorIcon = "https://media.discordapp.net/attachments/1571862046969176137/1571872000744620164/9b3d0135-5ab8-4239-8589-7ca6a12e246b.webp?ex=6afc4f60&is=6afafde0&hm=83fe3e652dfa9a704e7928a1ea692ebc432994e6259785fa8f3a8ef3d177c8b6&format=webp&width=768&height=768"
    local bannerImg = "https://media.discordapp.net/attachments/1571862046969176137/1571872352936140860/Gemini_Generated_Image_kqlim5kqlim5kqli.jpg?ex=6afc4fb4&is=6afafe34&hm=959ae0c770f6998ed2116041a9ff3af55278c2d0808a541d5276539c6bcb2cec&format=webp&width=1536&height=651"

    local bodyStr = string.format(
        '{"content":null,"embeds":[{"color":5765375,"fields":[' ..
        '{"name":"[  <a:king:1238156871282724895>  ]  -  NAME","value":"<a:angry:1515044838008160258> [  %s ]","inline":true},' ..
        '{"name":"[  <a:world:1113108638094069880>  ] -  WORLD","value":"<a:angry:1515044838008160258> [ %s ]"},' ..
        '{"name":"[  <a:damn:1462853718713045225>  ] -  STATE","value":"<a:angry:1515044838008160258> [ %s ]"},' ..
        '{"name":"[  <a:time:1345668076854841374>  ] -  UP TIME","value":"<a:angry:1515044838008160258> [ %s ]"},' ..
        '{"name":"[  <a:PROG:1430165994885746821>  ] -  PROGRESS","value":"<a:angry:1515044838008160258> [ %s ]"},' ..
        '{"name":"[  <a:SAFE:1280719300495282246>  ] -  SAFE TOTAL","value":"<a:angry:1515044838008160258> [ %s ]"}' ..
        '],"author":{"name":"%s","icon_url":"%s"},"footer":{"text":"Script created By DryCursed Community"},"image":{"url":"%s"}}],"attachments":[]}',
        DiscordHook._jsonEscape(playerName),
        DiscordHook._jsonEscape(worldName),
        DiscordHook._jsonEscape(stName),
        DiscordHook._jsonEscape(uptimeStr),
        DiscordHook._jsonEscape(progStr),
        DiscordHook._jsonEscape(safeTotal),
        DiscordHook._jsonEscape(playerName),
        authorIcon,
        bannerImg
    )

    local mid = DiscordHook.State.messageId or safeReadStorage("syt_dhook_mid.txt")
    local isPatch = type(mid) == "string" and mid:match("^%d+$") ~= nil
    local method = isPatch and "PATCH" or "POST"
    local reqUrl = isPatch and (DiscordHook.State.url .. "/messages/" .. mid) or (DiscordHook.State.url .. "?wait=true")

    local ok2, resp = pcall(reqFn, {
        Url = reqUrl,
        Method = method,
        Headers = { ["Content-Type"] = "application/json" },
        Body = bodyStr
    })
    if ok2 and type(resp) == "table" then
        if resp.StatusCode == 404 and isPatch then
            DiscordHook.State.messageId = nil
            safeWriteStorage("syt_dhook_mid.txt", "")
            return DiscordHook.Send(noteLine)
        elseif resp.StatusCode and resp.StatusCode >= 200 and resp.StatusCode < 300 then
            if method == "POST" and type(resp.Body) == "string" then
                local newId = resp.Body:match('"id"%s*:%s*"(%d+)"')
                if newId then
                    DiscordHook.State.messageId = newId
                    safeWriteStorage("syt_dhook_mid.txt", newId)
                    if UI then pcall(UI.SetValue, UI, "DhMessageIdDisplay", newId) end
                end
            end
            return true
        end
    end
    return false
end

function DiscordHook.Stop()
    DiscordHook.State.enabled = false
    if DiscordHook.State.thread then
        pcall(task.cancel, DiscordHook.State.thread)
        DiscordHook.State.thread = nil
    end
end

function DiscordHook.Start()
    local curUrl = UI and UI:GetValue("SysDiscordUrlInput")
    if type(curUrl) == "string" and curUrl ~= "" then
        DiscordHook.State.url = curUrl:sub(1, 300)
    end
    if DiscordHook.State.url == "" then
        DiscordHook.State.enabled = false
        if UI then pcall(UI.SetValue, UI, "DhEnabledToggle", false, true) end
        emitNotify("Discord Hook", "Masukkan link Discord Webhook terlebih dahulu!")
        return false
    end
    if DiscordHook.State.enabled then return true end
    DiscordHook.State.enabled = true
    DiscordHook.State.startTime = DiscordHook.State.startTime or os.clock()
    DiscordHook.State.messageId = DiscordHook.State.messageId or safeReadStorage("syt_dhook_mid.txt")
    if DiscordHook.State.messageId and UI then
        pcall(UI.SetValue, UI, "DhMessageIdDisplay", DiscordHook.State.messageId)
    end

    DiscordHook.State.thread = task.spawn(function()
        while DiscordHook.State.enabled do
            pcall(DiscordHook.Send)
            local waitSec = clamp(tonumber(DiscordHook.State.delay) or 120, 60, 300)
            local dl = os.clock() + waitSec
            while os.clock() < dl and DiscordHook.State.enabled do task.wait(0.25) end
        end
    end)
    return true
end

function DiscordHook.Toggle()
    if DiscordHook.State.enabled then return DiscordHook.Stop() end
    return DiscordHook.Start()
end

-- Enhance Visual (Roles Lengkap + Animasi BitmapText Asli + Env State + Shared Local/Peer Visual Applicator)
;(function()
    local ROLE_CAT = {
        { key = "none",         label = "No Role (Asli)",          kind = "Default",       prefix = "",        suffix = "",           span = nil,            color = Color3.fromRGB(255, 255, 255), code = "`w" },
        { key = "supporter",    label = "Supporter",               kind = "Donor Wave",    prefix = "",        suffix = "",           span = "supporter",    color = Color3.fromRGB(110, 252, 130), code = "`2" },
        { key = "patron",       label = "Patron",                  kind = "Donor Aura",    prefix = "",        suffix = "",           span = "patron",       color = Color3.fromRGB(255, 238, 125), code = "`9" },
        { key = "benefactor",   label = "Benefactor",              kind = "Donor Neon",    prefix = "",        suffix = "",           span = "benefactor",   color = Color3.fromRGB(80, 225, 255),  code = "`c" },
        { key = "sponsor",      label = "Sponsor",                 kind = "Sparkle",       prefix = "",        suffix = "",           span = "sponsor",      color = Color3.fromRGB(175, 205, 255), code = "`3" },
        { key = "supersponsor", label = "Super Sponsor (Mighty.)", kind = "Wrench + Gold", prefix = "Mighty. ",suffix = "",           span = "supersponsor", color = Color3.fromRGB(255, 214, 110), code = "`9" },
        { key = "legend",       label = "Legendary (of Legend)",   kind = "Wings + Gold",  prefix = "",        suffix = " of Legend", span = "legend",       color = Color3.fromRGB(255, 200, 60),  code = "`d" },
        { key = "royal",        label = "Royal",                   kind = "Royal Pulse",   prefix = "",        suffix = "",           span = "royal",        color = Color3.fromRGB(255, 165, 110), code = "`8" },
        { key = "dr",           label = "Doctor (Dr.)",            kind = "Red Title",     prefix = "Dr. ",    suffix = "",           span = nil,            color = Color3.fromRGB(255, 55, 45),   code = "`4" },
        { key = "cc",           label = "Content Creator (CC)",    kind = "Creator Badge", prefix = "",        suffix = "",           span = "cc",           color = Color3.fromRGB(220, 155, 255), code = "`5" },
        { key = "vip",          label = "VIP",                     kind = "VIP Lime",      prefix = "",        suffix = "",           span = nil,            color = Color3.fromRGB(181, 255, 151), code = "`^" },
        { key = "owner",        label = "Owner (Rainbow)",         kind = "Rainbow Wave",  prefix = "",        suffix = "",           span = "rainbow",      color = Color3.fromRGB(255, 145, 235), code = "`{" },
        { key = "admin",        label = "World Admin",             kind = "Admin Green",   prefix = "",        suffix = "",           span = nil,            color = Color3.fromRGB(125, 196, 124), code = "`v" },
        { key = "moderator",    label = "Moderator (@MOD)",        kind = "Staff @ Purple",prefix = "@",       suffix = "",           span = nil,            color = Color3.fromRGB(255, 143, 243), code = "`#" },
        { key = "developer",    label = "Developer (@DEV)",        kind = "Staff @ Gold",  prefix = "@",       suffix = "",           span = nil,            color = Color3.fromRGB(255, 193, 94),  code = "`d" },
    }
    Visual.RoleCatalog = ROLE_CAT
    Visual.Presets.roles = {}
    for _, rc in ipairs(ROLE_CAT) do
        Visual.Presets.roles[#Visual.Presets.roles + 1] = rc.key
    end
    Visual.Presets.effects = {
        "None", "Rainbow Wave", "Sponsor Sparkle", "Supporter Wave", "Patron Aura",
        "Benefactor Neon", "Super Sponsor", "Legend Gold", "Royal Pulse", "Creator Tag", "Color Prefix"
    }

    local EFFECT_TO_SPAN = {
        ["Rainbow Wave"]    = "rainbow",
        ["Sponsor Sparkle"] = "sponsor",
        ["Supporter Wave"]  = "supporter",
        ["Patron Aura"]     = "patron",
        ["Benefactor Neon"] = "benefactor",
        ["Super Sponsor"]   = "supersponsor",
        ["Legend Gold"]     = "legend",
        ["Royal Pulse"]     = "royal",
        ["Creator Tag"]     = "cc",
    }

    local TITLE_ROLE_KEYS = {
        supporter = true, patron = true, benefactor = true,
        sponsor = true, supersponsor = true, legend = true,
        royal = true, dr = true, cc = true,
    }

    function Visual.FindRoleEntry(roleKey)
        local rk = string.lower(tostring(roleKey or "none"))
        for idx, rc in ipairs(ROLE_CAT) do
            if rc.key == rk then return rc, idx end
        end
        return ROLE_CAT[1], 1
    end

    function Visual.GetEffectIndex(effectName)
        local ef = tostring(effectName or "None")
        for idx, nm in ipairs(Visual.Presets.effects) do
            if nm == ef then return idx end
        end
        return 1
    end

    local function composeAffixedName(baseName, roleKey, opts)
        opts = opts or {}
        local clean = stripColorTags(tostring(baseName or ""))
        if clean == "" then clean = Core.GetInGameName(LP, true) end
        if clean == "" then clean = "Player" end
        local rc = Visual.FindRoleEntry(roleKey)
        local pre = rc.prefix or ""
        local suf = rc.suffix or ""
        local low = string.lower(clean)
        if pre == "Dr. " and (string.find(low, "^dr%.") or string.find(low, "^dr ")) then pre = "" end
        if pre == "Mighty. " and string.find(low, "^mighty%.") then pre = "" end
        if pre == "@" and string.sub(clean, 1, 1) == "@" then pre = "" end
        if opts.spoofDr and pre == "" and not string.find(low, "^dr%.") and not string.find(low, "^dr ") and rc.key ~= "developer" and rc.key ~= "moderator" then
            pre = "Dr. "
        end
        if suf == " of Legend" and string.find(low, " of legend$") then suf = "" end
        if opts.spoofLegend and suf == "" and not string.find(low, " of legend$") then
            suf = " of Legend"
        end
        return pre .. clean .. suf
    end

    function Visual.FormatPreviewText(baseName, roleKey, opts)
        return composeAffixedName(baseName, roleKey, opts)
    end

    function Visual.FormatSbMarkup(baseName, roleKey, effectName, colorCode, opts)
        local full = composeAffixedName(baseName, roleKey, opts)
        local rc = Visual.FindRoleEntry(roleKey)
        local sp = EFFECT_TO_SPAN[tostring(effectName or "")]
        if not sp then sp = rc.span end
        if sp and sp ~= "" then
            return "`{" .. sp .. "}" .. full .. "`}"
        end
        if type(colorCode) == "string" and colorCode ~= "" then
            return colorCode .. full .. "``"
        end
        return (rc.code or "`w") .. full .. "``"
    end

    function Visual.SaveToEnv()
        local S = Visual.State
        local env = getEnv()
        env.__SYT_ENV_DATA = env.__SYT_ENV_DATA or {}
        local copyWorn = {}
        local serWorn = {}
        for sl, id in pairs(S.fakeWorn or {}) do
            if type(id) == "number" then
                copyWorn[sl] = id
                serWorn[#serWorn + 1] = tostring(sl) .. "=" .. tostring(id)
            end
        end
        env.__SYT_ENV_DATA.visual = {
            customName = tostring(S.customName or ""),
            role = tostring(S.role or "none"),
            effect = tostring(S.effect or "None"),
            colorCode = tostring(S.colorCode or ""),
            customTitle = tostring(S.customTitle or "none"),
            skinPreset = tostring(S.skinPreset or "Real (Server Skin)"),
            ghostSkin = S.ghostSkin == true,
            spoofDr = S.spoofDr == true,
            spoofLegend = S.spoofLegend == true,
            spoofStillTag = S.spoofStillTag == true,
            spoofLevel = tonumber(S.spoofLevel) or 0,
            guildMode = tostring(S.guildMode or "None (Real)"),
            guildTag = tostring(S.guildTag or ""),
            country = tostring(S.country or "Real (Unchanged)"),
            booster = S.booster == true,
            boosterColor = tostring(S.boosterColor or "Default (Real)"),
            tilesName = S.tilesName == true,
            hideName = S.hideName == true,
            lockNames = S.lockNames == true,
            fakeWorn = copyWorn,
        }
        local raw = table.concat({
            tostring(S.customName or ""):gsub("[|\n\r]", ""),
            tostring(S.role or "none"),
            tostring(S.effect or "None"),
            tostring(S.customTitle or "none"),
            table.concat(serWorn, ";"),
            tostring(S.colorCode or ""):gsub("[|\n\r]", ""),
            tostring(S.skinPreset or "Real (Server Skin)"):gsub("[|\n\r]", ""),
            (S.ghostSkin and "1" or "0") .. (S.spoofDr and "1" or "0") .. (S.spoofLegend and "1" or "0") .. (S.spoofStillTag and "1" or "0") .. (S.hideName and "1" or "0") .. (S.tilesName and "1" or "0") .. (S.booster and "1" or "0"),
            tostring(S.guildMode or "None (Real)"):gsub("[|\n\r]", ""),
            tostring(S.guildTag or ""):gsub("[|\n\r]", ""),
            tostring(S.country or "Real (Unchanged)"):gsub("[|\n\r]", ""),
            tostring(S.boosterColor or "Default (Real)"):gsub("[|\n\r]", ""),
            tostring(tonumber(S.spoofLevel) or 0),
        }, "|")
        safeWriteStorage("syt_visual_state.dat", raw)
    end

    function Visual.LoadFromEnv()
        local env = getEnv()
        local S = Visual.State
        local ev = env and env.__SYT_ENV_DATA and env.__SYT_ENV_DATA.visual
        if type(ev) == "table" then
            S.customName = ev.customName or S.customName
            S.role = ev.role or S.role
            S.effect = ev.effect or S.effect
            S.colorCode = ev.colorCode or S.colorCode
            S.customTitle = ev.customTitle or S.customTitle
            S.skinPreset = ev.skinPreset or S.skinPreset
            S.ghostSkin = ev.ghostSkin == true
            S.spoofDr = ev.spoofDr == true
            S.spoofLegend = ev.spoofLegend == true
            S.spoofStillTag = ev.spoofStillTag == true
            S.spoofLevel = tonumber(ev.spoofLevel) or S.spoofLevel or 0
            S.guildMode = ev.guildMode or S.guildMode
            S.guildTag = ev.guildTag or S.guildTag
            S.country = ev.country or S.country
            S.booster = ev.booster == true
            S.boosterColor = ev.boosterColor or S.boosterColor
            S.tilesName = ev.tilesName == true
            S.hideName = ev.hideName == true
            S.lockNames = ev.lockNames == true
            S.fakeWorn = {}
            for sl, id in pairs(ev.fakeWorn or {}) do S.fakeWorn[sl] = id end
            return true
        end
        local raw = safeReadStorage("syt_visual_state.dat")
        if type(raw) == "string" and raw ~= "" then
            local f = {}
            for seg in (raw .. "|"):gmatch("([^|]*)|") do f[#f + 1] = seg end
            if f[1] and f[1] ~= "" then S.customName = f[1]; S.lockNames = true end
            if f[2] and f[2] ~= "" then S.role = f[2] end
            if f[3] and f[3] ~= "" then S.effect = f[3] end
            if f[4] and f[4] ~= "" then S.customTitle = f[4] end
            if f[5] and f[5] ~= "" then
                S.fakeWorn = {}
                for pair in f[5]:gmatch("[^;]+") do
                    local sl, id = pair:match("([^=]+)=(%d+)")
                    if sl and id then S.fakeWorn[sl] = tonumber(id) end
                end
            end
            if f[6] then S.colorCode = f[6] end
            if f[7] and f[7] ~= "" then S.skinPreset = f[7] end
            if f[8] and #f[8] >= 7 then
                S.ghostSkin = f[8]:sub(1, 1) == "1"
                S.spoofDr = f[8]:sub(2, 2) == "1"
                S.spoofLegend = f[8]:sub(3, 3) == "1"
                S.spoofStillTag = f[8]:sub(4, 4) == "1"
                S.hideName = f[8]:sub(5, 5) == "1"
                S.tilesName = f[8]:sub(6, 6) == "1"
                S.booster = f[8]:sub(7, 7) == "1"
            end
            if f[9] and f[9] ~= "" then S.guildMode = f[9] end
            if f[10] then S.guildTag = f[10] end
            if f[11] and f[11] ~= "" then S.country = f[11] end
            if f[12] and f[12] ~= "" then S.boosterColor = f[12] end
            if f[13] then S.spoofLevel = tonumber(f[13]) or 0 end
            return true
        end
        return false
    end

    function Visual.SnapshotPlayerAttrs(plr)
        if not plr then return {} end
        local uid = plr.UserId
        local k = "u" .. tostring(uid)
        local sr = ReplicatedStorage:FindFirstChild("StaffRoles")
        local tl = ReplicatedStorage:FindFirstChild("TitleList")
        return {
            Nick = plr:GetAttribute("Nick"),
            GameName = plr:GetAttribute("GameName"),
            Tag = plr:GetAttribute("Tag"),
            OwnTitle = plr:GetAttribute("OwnTitle"),
            WornTitle = plr:GetAttribute("WornTitle"),
            DrTitle = plr:GetAttribute("DrTitle"),
            HasLegend = plr:GetAttribute("HasLegend"),
            HideLegendUntil = plr:GetAttribute("HideLegendUntil"),
            HideDrUntil = plr:GetAttribute("HideDrUntil"),
            StillTag = plr:GetAttribute("StillTag"),
            GuildRank = plr:GetAttribute("GuildRank"),
            Country = plr:GetAttribute("Country"),
            DiscordBooster = plr:GetAttribute("DiscordBooster"),
            DiscordColor = plr:GetAttribute("DiscordColor"),
            Level = plr:GetAttribute("Level"),
            PlayerLevel = plr:GetAttribute("PlayerLevel"),
            StaffRole = sr and sr:GetAttribute(k) or nil,
            TitleList = tl and tl:GetAttribute(k) or nil,
        }
    end

    -- Terapkan identitas Visual & Role secara seragam untuk LocalPlayer maupun peer P2P di Others
    function Visual.ApplyIdentityToPlayer(plr, st, origAttrs)
        if not plr then return end
        origAttrs = origAttrs or {}
        st = st or {}
        local uid = plr.UserId
        local k = "u" .. tostring(uid)
        local sr = ReplicatedStorage:FindFirstChild("StaffRoles")
        local tl = ReplicatedStorage:FindFirstChild("TitleList")
        local rLow = string.lower(tostring(st.role or "none"))
        local rc = Visual.FindRoleEntry(rLow)
        local base = stripColorTags(tostring(st.customName or ""))
        if base == "" then
            base = (origAttrs.GameName and origAttrs.GameName ~= "" and tostring(origAttrs.GameName)) or plr.Name
        end

        local sp = EFFECT_TO_SPAN[tostring(st.effect or "")]
        local explicitTitle = tostring(st.customTitle or "none")
        local chosenTitle = explicitTitle
        if chosenTitle == "" or chosenTitle == "none" then
            if TITLE_ROLE_KEYS[rLow] then
                chosenTitle = rLow
            elseif sp then
                chosenTitle = sp
            end
        end
        local effTitle = (sp and chosenTitle ~= "none" and chosenTitle ~= "") and sp or ((chosenTitle ~= "none" and chosenTitle ~= "") and chosenTitle or nil)
        if rLow == "owner" and not sp and not TITLE_ROLE_KEYS[explicitTitle] then
            effTitle = "rainbow"
        end
        if sp and TITLE_ROLE_KEYS[rLow] and rLow ~= "dr" and rLow ~= "legend" then
            effTitle = sp
        elseif sp and explicitTitle == "none" then
            effTitle = sp
        end

        local drActive = (st.spoofDr == true) or (chosenTitle == "dr") or (rLow == "dr")
        local legendActive = (st.spoofLegend == true) or (chosenTitle == "legend") or (rLow == "legend")

        local body = base
        if st.tilesName and LP and plr == LP then
            local pos = Core.ReadPos()
            body = body .. string.format(" [%d,%d]", pos.tx, pos.ty)
        end
        if st.guildMode == "Custom Text Prefix" and type(st.guildTag) == "string" and st.guildTag ~= "" then
            body = "[" .. stripColorTags(st.guildTag) .. "] " .. body
        end
        local lowBody = string.lower(body)
        if rLow == "supersponsor" and not string.find(lowBody, "^mighty%.") then
            body = "Mighty. " .. body
            lowBody = string.lower(body)
        end
        if drActive and effTitle ~= "dr" and not string.find(lowBody, "^dr%.") and not string.find(lowBody, "^dr ") then
            body = "Dr. " .. body
        end

        local nickVal = body
        if sp then
            nickVal = "`{" .. sp .. "}" .. body .. "`}"
        elseif type(st.colorCode) == "string" and st.colorCode ~= "" then
            nickVal = st.colorCode .. body .. "``"
        elseif rLow == "owner" then
            nickVal = "`{rainbow}" .. body .. "`}"
        elseif rLow == "vip" then
            nickVal = "`^" .. body .. "``"
        elseif rLow == "admin" then
            nickVal = "`v" .. body .. "``"
        elseif rc.span then
            nickVal = "`{" .. rc.span .. "}" .. body .. "`}"
        elseif rLow == "dr" then
            nickVal = "`4" .. body .. "``"
        end

        -- 1. Set atribut sekunder/title/server table terlebih dahulu (sebelum AttributeChanged drawName)
        if sr then
            local srVal = (rLow == "developer" or rLow == "moderator" or rLow == "vip") and rLow or origAttrs.StaffRole
            sr:SetAttribute(k, srVal)
        end
        if tl then
            tl:SetAttribute(k, (effTitle and effTitle ~= "") and effTitle or origAttrs.TitleList)
        end
        if effTitle and effTitle ~= "" then
            plr:SetAttribute("WornTitle", effTitle)
        else
            plr:SetAttribute("WornTitle", origAttrs.WornTitle)
        end
        if drActive then
            plr:SetAttribute("DrTitle", true)
            plr:SetAttribute("HideDrUntil", 0)
        else
            plr:SetAttribute("DrTitle", origAttrs.DrTitle)
            plr:SetAttribute("HideDrUntil", origAttrs.HideDrUntil)
        end
        if legendActive then
            plr:SetAttribute("HasLegend", true)
            plr:SetAttribute("HideLegendUntil", 0)
        else
            plr:SetAttribute("HasLegend", origAttrs.HasLegend)
            plr:SetAttribute("HideLegendUntil", origAttrs.HideLegendUntil)
        end
        plr:SetAttribute("StillTag", (st.spoofStillTag == true) and true or origAttrs.StillTag)

        local bCol = Visual.Presets.boosterColors and Visual.Presets.boosterColors[st.boosterColor]
        if typeof(bCol) == "Color3" then
            plr:SetAttribute("DiscordColor", bCol)
        elseif rLow == "owner" then
            plr:SetAttribute("DiscordColor", Color3.fromRGB(255, 145, 235))
        elseif rLow == "vip" then
            plr:SetAttribute("DiscordColor", Color3.fromRGB(181, 255, 151))
        elseif rLow == "admin" then
            plr:SetAttribute("DiscordColor", Color3.fromRGB(125, 196, 124))
        else
            plr:SetAttribute("DiscordColor", origAttrs.DiscordColor)
        end

        local lvl = tonumber(st.spoofLevel) or 0
        if lvl > 0 then
            plr:SetAttribute("Level", math.floor(lvl))
            plr:SetAttribute("PlayerLevel", math.floor(lvl))
        else
            plr:SetAttribute("Level", origAttrs.Level)
            plr:SetAttribute("PlayerLevel", origAttrs.PlayerLevel)
        end

        -- 2. Set atribut yang diawasi AttributeChanged (Others.lua) di akhir agar drawName membaca state terbaru lengkap
        if st.guildMode == "2: (GE) Member" then
            plr:SetAttribute("GuildRank", 2)
        elseif st.guildMode == "3: (GC) Officer" then
            plr:SetAttribute("GuildRank", 3)
        elseif st.guildMode == "4: (GL) Leader" then
            plr:SetAttribute("GuildRank", 4)
        else
            plr:SetAttribute("GuildRank", origAttrs.GuildRank)
        end
        if st.country and st.country ~= "Real (Unchanged)" and st.country ~= "" then
            plr:SetAttribute("Country", st.country)
        else
            plr:SetAttribute("Country", origAttrs.Country)
        end
        plr:SetAttribute("DiscordBooster", (st.booster == true) or origAttrs.DiscordBooster)
        plr:SetAttribute("GameName", base)
        if effTitle and effTitle ~= "" and (TITLE_ROLE_KEYS[rLow] or TITLE_ROLE_KEYS[explicitTitle]) then
            plr:SetAttribute("OwnTitle", effTitle)
        else
            plr:SetAttribute("OwnTitle", origAttrs.OwnTitle)
        end
        plr:SetAttribute("Nick", nickVal)
        local tagVal = (rLow == "developer" or rLow == "moderator") and rLow or origAttrs.Tag
        plr:SetAttribute("Tag", tagVal)
    end

    local _origVisualApply = Visual.Apply
    local _origVisualOutfit = Visual.ApplyOutfit
    local _origVisualRestore = Visual.Restore

    function Visual.ReapplyOutfitLocally()
        ensureVisualRefs()
        local S = Visual.State
        local wt = H.wornTbl
        if type(wt) ~= "table" then return false end
        local slots = (Visual.Presets and Visual.Presets.wearSlots) or { "back", "hand", "hat", "hair", "shirt", "pants", "feet", "face", "neck", "chest", "ances", "mask", "ring", "pet" }
        if S.origWornSavedFor ~= wt then
            S.origWornSavedFor = wt
            S.origWorn = {}
            for _, sl in ipairs(slots) do
                S.origWorn[sl] = rawget(wt, sl)
            end
        end
        for _, sl in ipairs(slots) do
            local spoofVal = S.fakeWorn[sl]
            if spoofVal ~= nil then
                wt[sl] = (spoofVal > 0) and spoofVal or nil
            elseif S.origWorn then
                wt[sl] = S.origWorn[sl]
            end
        end
        local ps = H.playerSpriteObj
        if type(ps) == "table" then
            if S.origSkinSavedFor ~= ps then
                S.origSkinSavedFor = ps
                S.origSkin = rawget(ps, "SKIN")
            end
            local col = Visual.Presets.skins[S.skinPreset]
            if typeof(col) == "Color3" then
                ps.SKIN = col
                if type(rawget(ps, "setSkin")) == "function" then pcall(ps.setSkin, ps, col) end
            end
        end
        if H.skillsObj and type(H.skillsObj.applyWorn) == "function" then
            pcall(H.skillsObj.applyWorn)
            if type(ps) == "table" and type(ps.allRigs) == "table" then
                local clk = os.clock()
                for _, rig in ipairs(ps.allRigs) do
                    if type(rig) == "table" and rig.portrait then
                        pcall(H.skillsObj.applyWorn, rig, clk)
                    end
                end
            end
        end
        if type(ps) == "table" and type(rawget(ps, "applyFeet")) == "function" then
            pcall(ps.applyFeet, ps)
        end
        refreshNameTagObj()
        return true
    end

    function Visual.EnsureOutfitPersistenceHooks()
        if H.inv and H.inv.changed and typeof(H.inv.changed.Event) == "RBXScriptSignal" and H._invOutfitHookedFor ~= H.inv then
            H._invOutfitHookedFor = H.inv
            local boundInv = H.inv
            boundInv.changed.Event:Connect(function()
                local vs = Visual and Visual.State
                if vs and type(vs.fakeWorn) == "table" and next(vs.fakeWorn) ~= nil then
                    task.defer(function()
                        if Visual and Visual.ReapplyOutfitLocally then
                            pcall(Visual.ReapplyOutfitLocally)
                        end
                    end)
                end
            end)
        end
        if H.skillsObj and type(rawget(H.skillsObj, "refresh")) == "function" and H._skRefreshHookedFor ~= H.skillsObj then
            local sk = H.skillsObj
            local origRefresh = rawget(sk, "refresh")
            H._skRefreshHookedFor = sk
            sk.refresh = function(...)
                local res = origRefresh(...)
                local vs = Visual and Visual.State
                if vs and type(vs.fakeWorn) == "table" and next(vs.fakeWorn) ~= nil then
                    task.defer(function()
                        if Visual and Visual.ReapplyOutfitLocally then
                            pcall(Visual.ReapplyOutfitLocally)
                        end
                    end)
                end
                return res
            end
        end
    end

    function Visual.ApplyOutfit()
        local okR = _origVisualOutfit()
        Visual.EnsureOutfitPersistenceHooks()
        local ps = H.playerSpriteObj
        if type(ps) == "table" and type(ps.allRigs) == "table" and H.skillsObj and type(H.skillsObj.applyWorn) == "function" then
            local clk = os.clock()
            for _, rig in ipairs(ps.allRigs) do
                if type(rig) == "table" and rig.portrait then
                    pcall(H.skillsObj.applyWorn, rig, clk)
                end
            end
        end
        pcall(Visual.SaveToEnv)
        if not Visual.State._batchP2P and ProxyCommands and ProxyCommands.P2P and ProxyCommands.P2P.BroadcastState then
            task.spawn(ProxyCommands.P2P.BroadcastState, false)
        end
        return okR
    end

    function Visual.Apply()
        local S = Visual.State
        S._batchP2P = true
        if _origVisualApply then _origVisualApply() end
        S._batchP2P = false
        Visual.EnsureOutfitPersistenceHooks()
        if LP then
            Visual.ApplyIdentityToPlayer(LP, S, {
                Nick = S.origNick, GameName = S.origGameName, Tag = S.origTag,
                OwnTitle = S.origOwnTitle, WornTitle = S.origWornTitle,
                DrTitle = S.origDrTitle, HasLegend = S.origHasLegend,
                HideLegendUntil = S.origHideLegend, HideDrUntil = S.origHideDr,
                StillTag = S.origStillTag, GuildRank = S.origGuildRank,
                Country = S.origCountry, DiscordBooster = S.origBooster,
                DiscordColor = S.origBoosterColor, Level = S.origLevel,
                PlayerLevel = S.origPlayerLevel, StaffRole = S.origRoleAttr, TitleList = S.origTitleAttr,
            })
        end
        if type(H.nameTagObj) == "table" then
            H.nameTagObj.shownKey = nil
            if type(H.nameTagObj.redraw) == "function" then pcall(H.nameTagObj.redraw) end
        end
        pcall(Visual.SaveToEnv)
        if ProxyCommands and ProxyCommands.P2P and ProxyCommands.P2P.BroadcastState then
            task.spawn(ProxyCommands.P2P.BroadcastState, false)
        end
        return true
    end

    function Visual.Restore()
        local r = _origVisualRestore and _origVisualRestore() or true
        H._stripWingDoubleJump = false
        pcall(Visual.SaveToEnv)
        if ProxyCommands and ProxyCommands.P2P and ProxyCommands.P2P.BroadcastState then
            task.spawn(ProxyCommands.P2P.BroadcastState, true)
        end
        return r
    end
end)()

-- Proxy System (/p2p, /reme, /clothes, Host BJ /set b /lock t /set tax /cal /info, /get, /cn, /list, /sbv)
ProxyCommands = {
    State = {
        p2pEnabled = true,
        p2pLive = false,
        remeEnabled = false,
        lastRealWheelByUser = {},
        bj = { b1 = nil, b2 = nil, t1 = nil, t2 = nil, tax = 0, running = false },
        activeDialogs = {},
    }
}
SYT_Logic.Proxy = ProxyCommands

local function closeProxyDialog(name)
    local prev = ProxyCommands.State.activeDialogs[name]
    if prev then
        pcall(function() prev:Destroy() end)
        ProxyCommands.State.activeDialogs[name] = nil
    end
    local targetNm = "SYT_GameDialog_" .. tostring(name)
    for _, root in ipairs(getAllGuiRoots()) do
        if typeof(root) == "Instance" then
            pcall(function()
                for _, ch in ipairs(root:GetChildren()) do
                    if ch:IsA("ScreenGui") and ch.Name == targetNm then ch:Destroy() end
                end
            end)
        end
    end
end

local function makeNativeGameDialog(name, titleText, wPx, hPx)
    closeProxyDialog(name)
    local pg = LP and LP:FindFirstChildOfClass("PlayerGui")
    local sg = Instance.new("ScreenGui")
    sg.Name = "SYT_GameDialog_" .. name
    sg.ResetOnSpawn = false
    sg.Enabled = true
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.DisplayOrder = 10050
    sg.IgnoreGuiInset = true

    local candidates = {}
    local hui = getSafeHui()
    if hui then candidates[#candidates + 1] = hui end
    if CoreGui then candidates[#candidates + 1] = CoreGui end
    if pg then candidates[#candidates + 1] = pg end
    for _, r in ipairs(getAllGuiRoots()) do
        if typeof(r) == "Instance" then candidates[#candidates + 1] = r end
    end
    local mounted = false
    for _, rootParent in ipairs(candidates) do
        local okP = pcall(function() sg.Parent = rootParent end)
        if okP and sg.Parent then mounted = true; break end
    end
    if not mounted then
        warn("[SYT Dialog] Gagal mount dialog " .. tostring(name))
    end

    local box = Instance.new("Frame", sg)
    box.Size = UDim2.fromOffset(wPx, hPx)
    box.AnchorPoint = Vector2.new(0.5, 0.5)
    box.Position = UDim2.fromScale(0.5, 0.5)
    box.Active = true
    box.Visible = true
    box.BackgroundColor3 = Color3.fromRGB(30, 100, 120)
    box.BorderSizePixel = 0
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 8)
    local stOuter = Instance.new("UIStroke", box)
    stOuter.Color = Color3.fromRGB(135, 184, 204)
    stOuter.Thickness = 3

    local uiScale = Instance.new("UIScale", box)
    uiScale.Name = "SYT_ProxyDialogScale"
    pcall(function()
        local cam = workspace.CurrentCamera
        local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
        uiScale.Scale = clamp(math.min((vp.X - 20) / wPx, (vp.Y - 20) / hPx), 0.42, 1.0)
    end)

    local inner = Instance.new("Frame", box)
    inner.Position = UDim2.fromOffset(6, 6)
    inner.Size = UDim2.new(1, -12, 1, -12)
    inner.BackgroundColor3 = Color3.fromRGB(16, 46, 58)
    inner.BorderSizePixel = 0
    Instance.new("UICorner", inner).CornerRadius = UDim.new(0, 6)
    local stInner = Instance.new("UIStroke", inner)
    stInner.Color = Color3.fromRGB(4, 8, 10)
    stInner.Thickness = 1.5

    local hdr = Instance.new("TextLabel", inner)
    hdr.Size = UDim2.new(1, -80, 0, 32)
    hdr.Position = UDim2.fromOffset(12, 6)
    hdr.BackgroundTransparency = 1
    hdr.Font = Enum.Font.GothamBold
    hdr.TextSize = 16
    hdr.TextXAlignment = Enum.TextXAlignment.Left
    hdr.TextColor3 = Color3.fromRGB(255, 230, 180)
    hdr.Text = titleText

    local closeBtn = Instance.new("TextButton", inner)
    closeBtn.Size = UDim2.fromOffset(64, 26)
    closeBtn.Position = UDim2.new(1, -72, 0, 8)
    closeBtn.BackgroundColor3 = Color3.fromRGB(196, 40, 40)
    closeBtn.BorderSizePixel = 0
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 12
    closeBtn.TextColor3 = Color3.new(1, 1, 1)
    closeBtn.Text = "CLOSE"
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 5)
    closeBtn.MouseButton1Click:Connect(function()
        closeProxyDialog(name)
    end)

    ProxyCommands.State.activeDialogs[name] = sg
    return sg, inner
end

-- Overhead Tag Popup (muncul di atas kepala player / NameTag, TIDAK menimpa layar kita jika player tidak terlihat)
local function showOverheadTagPopup(userId, tagText, borderColor)
    local pg = LP and LP:FindFirstChildOfClass("PlayerGui")
    local gg = pg and pg:FindFirstChild("GameGui")
    if not gg then return end

    local anchorFrame = nil
    if LP and userId == LP.UserId then
        anchorFrame = findNameTag()
    elseif H.others and type(H.others.tagOf) == "function" then
        local ok, nt = pcall(H.others.tagOf, userId)
        if ok and typeof(nt) == "Instance" then anchorFrame = nt end
    end
    if not anchorFrame or not anchorFrame.Parent then return end

    local old = anchorFrame:FindFirstChild("SYT_RemeOverhead")
    if old then old:Destroy() end

    local pill = Instance.new("Frame", anchorFrame)
    pill.Name = "SYT_RemeOverhead"
    pill.AutomaticSize = Enum.AutomaticSize.X
    pill.Size = UDim2.fromOffset(120, 22)
    pill.AnchorPoint = Vector2.new(0.5, 1)
    pill.Position = UDim2.new(0.5, 0, 0, -6)
    pill.BackgroundColor3 = Color3.fromRGB(20, 42, 54)
    pill.ZIndex = (anchorFrame.ZIndex or 10) + 10
    Instance.new("UICorner", pill).CornerRadius = UDim.new(0, 5)
    local st = Instance.new("UIStroke", pill)
    st.Color = borderColor or Color3.fromRGB(80, 255, 140)
    st.Thickness = 1.6

    local lbl = Instance.new("TextLabel", pill)
    lbl.AutomaticSize = Enum.AutomaticSize.X
    lbl.Size = UDim2.fromScale(0, 1)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 11
    lbl.TextColor3 = Color3.new(1, 1, 1)
    lbl.Text = "  " .. tagText .. "  "
    lbl.ZIndex = pill.ZIndex + 1

    task.delay(4.5, function()
        if pill and pill.Parent then pcall(function() pill:Destroy() end) end
    end)
end

-- Zero-Server P2P Client Visual Sync + /sbv Virtual Super Broadcast (via Metadata-First RBXGeneral + Nibble Fallback + Rate Governor)
;(function()
    local P2P_PREFIX = "xwkp "
    local P2P_META_TAG = "SYT2|"
    local P2P_CONS = "bcdfghjkmnpqrtvw"
    local REV_CONS = {}
    for i = 1, #P2P_CONS do REV_CONS[P2P_CONS:sub(i, i)] = i - 1 end

    local SLOTS_ORDER = {
        "hat", "hair", "face", "shirt", "pants", "feet",
        "back", "hand", "neck", "chest", "ances", "mask", "ring", "pet"
    }
    local SLOT_TO_IDX = {}
    for idx, sl in ipairs(SLOTS_ORDER) do SLOT_TO_IDX[sl] = idx end

    local P2P = {
        Peers = {},
        seenWire = {},
        queue = {},
        sending = false,
        nextSendAt = 0,
        blockedUntil = 0,
        sentTimes = {},
        lastSbvAt = 0,
        lastHelloAt = 0,
        lastStateSentAt = 0,
        lastSentSig = "",
        pendingBroadcast = false,
        pendingBroadcastToken = 0,
        replyTimers = {},
        sfxSound = nil,
        metaBroken = false,
        lastMetaSentAt = 0,
        lastMetaSentPayload = "",
    }
    ProxyCommands.P2P = P2P

    local function shallowCopyTbl(t)
        if type(t) ~= "table" then return nil end
        local o = {}
        for k, v in pairs(t) do o[k] = v end
        return o
    end

    local function strToHex(s)
        s = tostring(s or "")
        return (s:gsub(".", function(c)
            return string.format("%02x", string.byte(c))
        end))
    end

    local function hexToStr(h)
        if type(h) ~= "string" or (#h % 2) ~= 0 then return "" end
        local ok, res = pcall(function()
            return (h:gsub("%x%x", function(pair)
                return string.char(tonumber(pair, 16) or 32)
            end))
        end)
        return ok and res or ""
    end

    local function cleanPipeVal(s)
        return tostring(s or ""):gsub("[|\r\n]", "")
    end

    local function computeChecksum(bytes)
        local c = 0x5A
        for i = 1, #bytes do
            c = (c * 33 + bytes[i] + i) % 256
        end
        return c
    end

    local function pushVarint(bytes, n)
        n = math.max(0, math.floor(tonumber(n) or 0))
        repeat
            local b = n % 128
            n = math.floor(n / 128)
            if n > 0 then b = b + 128 end
            bytes[#bytes + 1] = b
        until n == 0
    end

    local function readVarint(bytes, pos)
        local val, mul, shift = 0, 1, 0
        while pos <= #bytes and shift < 4 do
            local b = bytes[pos]
            pos = pos + 1
            if b >= 128 then
                val = val + (b - 128) * mul
                mul = mul * 128
                shift = shift + 1
            else
                val = val + b * mul
                return val, pos
            end
        end
        return val, pos
    end

    local function pushStr(bytes, s, maxBytes)
        s = tostring(s or "")
        if #s > maxBytes then s = s:sub(1, maxBytes) end
        bytes[#bytes + 1] = #s
        for i = 1, #s do
            bytes[#bytes + 1] = string.byte(s, i)
        end
    end

    local function readStr(bytes, pos)
        if pos > #bytes then return "", pos end
        local len = bytes[pos]
        pos = pos + 1
        local ch = {}
        for _ = 1, len do
            if pos > #bytes then break end
            ch[#ch + 1] = string.char(bytes[pos])
            pos = pos + 1
        end
        return table.concat(ch), pos
    end

    local function encodeBytesToWire(bytes)
        bytes[#bytes + 1] = computeChecksum(bytes)
        local nibs = {}
        for i = 1, #bytes do
            local b = bytes[i]
            local hi = math.floor(b / 16) + 1
            local lo = (b % 16) + 1
            nibs[#nibs + 1] = P2P_CONS:sub(hi, hi) .. P2P_CONS:sub(lo, lo)
        end
        local flat = table.concat(nibs)
        local groups = {}
        for i = 1, #flat, 8 do
            groups[#groups + 1] = flat:sub(i, math.min(i + 7, #flat))
        end
        return P2P_PREFIX .. table.concat(groups, " ")
    end

    local function decodeWireToBytes(txt)
        if type(txt) ~= "string" or txt:sub(1, #P2P_PREFIX) ~= P2P_PREFIX then return nil end
        local body = txt:sub(#P2P_PREFIX + 1):gsub("%s+", "")
        if #body < 8 or (#body % 2) ~= 0 or #body > 192 then return nil end
        local bytes = {}
        for i = 1, #body, 2 do
            local a = REV_CONS[body:sub(i, i)]
            local b = REV_CONS[body:sub(i + 1, i + 1)]
            if a == nil or b == nil then return nil end
            bytes[#bytes + 1] = a * 16 + b
        end
        local expected = bytes[#bytes]
        bytes[#bytes] = nil
        if computeChecksum(bytes) ~= expected then return nil end
        return bytes
    end

    local function buildPeerSig(st)
        local wKeys = {}
        for sl, id in pairs(st.worn or {}) do
            wKeys[#wKeys + 1] = tostring(sl) .. "=" .. tostring(id)
        end
        table.sort(wKeys)
        return table.concat({
            st.reset and "R1" or "R0",
            tostring(st.role or "none"),
            tostring(st.effect or "None"),
            tostring(st.colorCode or ""),
            tostring(st.customTitle or "none"),
            tostring(st.customName or ""),
            tostring(st.skinPreset or "Real (Server Skin)"),
            st.ghostSkin and "G1" or "G0",
            st.spoofDr and "D1" or "D0",
            st.spoofLegend and "L1" or "L0",
            st.spoofStillTag and "S1" or "S0",
            st.hideName and "H1" or "H0",
            tostring(st.guildMode or "None (Real)"),
            tostring(st.guildTag or ""),
            tostring(st.country or "Real (Unchanged)"),
            st.booster and "B1" or "B0",
            tostring(st.boosterColor or "Default (Real)"),
            tostring(tonumber(st.spoofLevel) or 0),
            table.concat(wKeys, ",")
        }, "|")
    end

    function ProxyCommands.SaveEnv()
        local env = getEnv()
        env.__SYT_ENV_DATA = env.__SYT_ENV_DATA or {}
        local bj = ProxyCommands.State.bj or {}
        env.__SYT_ENV_DATA.proxy = {
            p2pEnabled = ProxyCommands.State.p2pEnabled ~= false,
            remeEnabled = ProxyCommands.State.remeEnabled == true,
            bj = {
                b1 = bj.b1 and { x = bj.b1.x, y = bj.b1.y } or nil,
                b2 = bj.b2 and { x = bj.b2.x, y = bj.b2.y } or nil,
                t1 = bj.t1 and { x = bj.t1.x, y = bj.t1.y } or nil,
                t2 = bj.t2 and { x = bj.t2.x, y = bj.t2.y } or nil,
                tax = tonumber(bj.tax) or 0,
            }
        }
    end

    function ProxyCommands.LoadEnv()
        local env = getEnv()
        local pr = env and env.__SYT_ENV_DATA and env.__SYT_ENV_DATA.proxy
        if type(pr) == "table" then
            ProxyCommands.State.p2pEnabled = (pr.p2pEnabled ~= false)
            ProxyCommands.State.remeEnabled = (pr.remeEnabled == true)
            if type(pr.bj) == "table" then
                local bj = ProxyCommands.State.bj
                bj.b1 = pr.bj.b1 and { x = pr.bj.b1.x, y = pr.bj.b1.y } or bj.b1
                bj.b2 = pr.bj.b2 and { x = pr.bj.b2.x, y = pr.bj.b2.y } or bj.b2
                bj.t1 = pr.bj.t1 and { x = pr.bj.t1.x, y = pr.bj.t1.y } or bj.t1
                bj.t2 = pr.bj.t2 and { x = pr.bj.t2.x, y = pr.bj.t2.y } or bj.t2
                if type(pr.bj.tax) == "number" then bj.tax = pr.bj.tax end
            end
        end
    end

    function P2P.SaveToEnv()
        local env = getEnv()
        env.__SYT_P2P_PEERS = env.__SYT_P2P_PEERS or {}
        for uid, peer in pairs(P2P.Peers) do
            env.__SYT_P2P_PEERS[uid] = {
                uid = peer.uid,
                reset = peer.reset == true,
                role = peer.role,
                effect = peer.effect,
                colorCode = peer.colorCode,
                customTitle = peer.customTitle,
                customName = peer.customName,
                skinPreset = peer.skinPreset,
                ghostSkin = peer.ghostSkin == true,
                spoofDr = peer.spoofDr == true,
                spoofLegend = peer.spoofLegend == true,
                spoofStillTag = peer.spoofStillTag == true,
                hideName = peer.hideName == true,
                guildMode = peer.guildMode,
                guildTag = peer.guildTag,
                country = peer.country,
                booster = peer.booster == true,
                boosterColor = peer.boosterColor,
                spoofLevel = peer.spoofLevel or 0,
                worn = shallowCopyTbl(peer.worn) or {},
                sig = peer.sig,
                updatedAt = peer.updatedAt,
                origAttrs = shallowCopyTbl(peer.origAttrs),
            }
        end
    end

    function P2P.LoadFromEnv()
        local env = getEnv()
        local saved = env and env.__SYT_P2P_PEERS
        if type(saved) ~= "table" then return end
        for uid, peer in pairs(saved) do
            if type(peer) == "table" and tonumber(uid) then
                local obj = {
                    uid = tonumber(uid),
                    reset = peer.reset == true,
                    role = peer.role or "none",
                    effect = peer.effect or "None",
                    colorCode = peer.colorCode or "",
                    customTitle = peer.customTitle or "none",
                    customName = peer.customName or "",
                    skinPreset = peer.skinPreset or "Real (Server Skin)",
                    ghostSkin = peer.ghostSkin == true,
                    spoofDr = peer.spoofDr == true,
                    spoofLegend = peer.spoofLegend == true,
                    spoofStillTag = peer.spoofStillTag == true,
                    hideName = peer.hideName == true,
                    guildMode = peer.guildMode or "None (Real)",
                    guildTag = peer.guildTag or "",
                    country = peer.country or "Real (Unchanged)",
                    booster = peer.booster == true,
                    boosterColor = peer.boosterColor or "Default (Real)",
                    spoofLevel = tonumber(peer.spoofLevel) or 0,
                    worn = shallowCopyTbl(peer.worn) or {},
                    updatedAt = peer.updatedAt or os.clock(),
                    origAttrs = shallowCopyTbl(peer.origAttrs),
                }
                obj.sig = buildPeerSig(obj)
                P2P.Peers[tonumber(uid)] = obj
            end
        end
    end

    local function getP2PChannel()
        local ok, TCS = pcall(game.GetService, game, "TextChatService")
        if not ok or not TCS then return nil end
        local tcsFolder = TCS:FindFirstChild("TextChannels")
        if tcsFolder then
            local gen = tcsFolder:FindFirstChild("RBXGeneral")
            if gen and gen:IsA("TextChannel") then return gen end
            for _, ch in ipairs(tcsFolder:GetChildren()) do
                if ch:IsA("TextChannel") then return ch end
            end
        end
        return nil
    end

    local function getOthersEntryMap()
        if not H.others then return nil end
        if H._othersCacheFor == H.others and type(H._othersEntryMap) == "table" then
            return H._othersEntryMap
        end
        local candidateFns = { H.others.tagOf, H.others.where, H.others.list }
        for _, fn in ipairs(candidateFns) do
            if type(fn) == "function" then
                for upIdx = 1, 5 do
                    local okU, t = pcall(uv, fn, upIdx)
                    if okU and type(t) == "table" then
                        for _, val in pairs(t) do
                            if type(val) == "table" and (val.userId ~= nil or val.slots ~= nil or val.lookVer ~= nil) then
                                H._othersCacheFor = H.others
                                H._othersEntryMap = t
                                return t
                            end
                        end
                    end
                end
            end
        end
        return nil
    end

    local function paintPeerRigs(entry, skinCol, isSee)
        if type(entry) ~= "table" or type(entry.rigs) ~= "table" then return end
        local useCol = typeof(skinCol) == "Color3" and skinCol or nil
        local mouthCol = useCol and Color3.new(useCol.R * 0.38, useCol.G * 0.35, useCol.B * 0.3) or nil
        local skinT = isSee and 0.2 or 0
        for _, rig in pairs(entry.rigs) do
            if type(rig) == "table" then
                rig.feetKey = nil
                rig.heldKey = nil
                rig.wornVer = nil
                if not rig.shade then
                    if useCol then
                        for _, part in ipairs({
                            rig.body, rig.head, rig.eyelids, rig.blink,
                            rig.armBack and rig.armBack.Sprite or nil,
                            rig.armFront and rig.armFront.Sprite or nil,
                            rig.forearm, rig.fist
                        }) do
                            if typeof(part) == "Instance" and part:IsA("ImageLabel") then
                                part.ImageColor3 = useCol
                                if not entry.ghostShown then
                                    part.ImageTransparency = skinT
                                end
                            end
                        end
                        if typeof(rig.face) == "Instance" and rig.face:IsA("ImageLabel") and mouthCol then
                            rig.face.ImageColor3 = mouthCol
                        end
                    end
                end
            end
        end
    end

    local function applyPeerToWorld(uid, peer)
        if not peer or not LP or uid == LP.UserId then return end
        local active = (ProxyCommands.State.p2pEnabled ~= false) and not peer.reset
        local wantSig = active and peer.sig or "ORIG"

        local plr = Players:GetPlayerByUserId(uid)
        if plr then
            if not peer.origAttrs then
                peer.origAttrs = Visual.SnapshotPlayerAttrs(plr)
            end
            if active then
                if plr:GetAttribute("SYT_PeerSig") ~= wantSig then
                    Visual.ApplyIdentityToPlayer(plr, peer, peer.origAttrs)
                    plr:SetAttribute("SYT_PeerSig", wantSig)
                end
            else
                if plr:GetAttribute("SYT_PeerSig") ~= nil then
                    Visual.ApplyIdentityToPlayer(plr, { role = "none", customName = "", effect = "None" }, peer.origAttrs)
                    plr:SetAttribute("SYT_PeerSig", nil)
                end
            end
        end

        local entryMap = getOthersEntryMap()
        if type(entryMap) == "table" then
            local matched = {}
            for _, entry in pairs(entryMap) do
                if type(entry) == "table" and tonumber(entry.userId) == uid then
                    matched[#matched + 1] = entry
                end
            end
            if #matched == 0 and type(entryMap[uid]) == "table" then
                matched[1] = entryMap[uid]
            end
            for _, entry in ipairs(matched) do
                if entry.slots ~= nil or entry.worn ~= nil then
                    if entry._sytLastSlots ~= entry.slots then
                        entry._sytOrigSlots = shallowCopyTbl(entry.slots) or {}
                        entry._sytOrigWorn = shallowCopyTbl(entry.worn) or {}
                        entry._sytOrigPet = entry.pet
                        entry._sytOrigWings = entry.wings
                        entry._sytOrigWingIt = entry.wingIt
                        entry._sytOrigSkin = entry.skin
                        entry._sytOrigSee = entry.see
                        if entry._sytOrigName == nil then entry._sytOrigName = entry.name end
                        entry._sytAppliedSig = nil
                    end
                    if entry._sytAppliedSig ~= wantSig then
                        if active then
                            local newSlots = shallowCopyTbl(entry._sytOrigSlots) or {}
                            for sl, id in pairs(peer.worn or {}) do
                                if type(id) == "number" and id > 0 then
                                    newSlots[sl] = id
                                elseif id == 0 then
                                    newSlots[sl] = nil
                                end
                            end
                            local newWorn = {}
                            local newPet, newWings, newWingIt = nil, false, nil
                            for _, id in pairs(newSlots) do
                                if type(id) == "number" and id > 0 then
                                    newWorn[id] = true
                                    local info = H.ItemDB and H.ItemDB[id]
                                    if type(info) == "table" then
                                        if info.pet then newPet = info.pet end
                                        if info.wingSheet then
                                            newWings = info.wingSheet
                                            newWingIt = info
                                        end
                                    end
                                end
                            end
                            entry.slots = newSlots
                            entry.worn = newWorn
                            entry.pet = newPet
                            entry.wings = newWings
                            entry.wingIt = newWingIt

                            local skinCol = entry._sytOrigSkin
                            local spName = tostring(peer.skinPreset or "Real (Server Skin)")
                            if spName ~= "Real (Server Skin)" and spName ~= "Ghost (See-Through)" then
                                local c3 = Visual.Presets.skins and Visual.Presets.skins[spName]
                                if typeof(c3) == "Color3" then skinCol = c3 end
                            end
                            local seeFlag = (peer.ghostSkin == true or spName == "Ghost (See-Through)") and true or (entry._sytOrigSee == true)
                            entry.skin = skinCol
                            entry.see = seeFlag
                            paintPeerRigs(entry, skinCol, seeFlag)

                            if (peer.customName or "") ~= "" or (peer.role or "none") ~= "none" or peer.spoofDr or peer.spoofLegend then
                                local baseShow = (peer.customName ~= "" and peer.customName) or entry._sytOrigName or (plr and (plr:GetAttribute("GameName") or plr.Name)) or "Player"
                                if type(entry.name) == "string" or entry._sytOrigName ~= nil then
                                    entry.name = Visual.FormatPreviewText(baseShow, peer.role, {
                                        spoofDr = peer.spoofDr == true,
                                        spoofLegend = peer.spoofLegend == true,
                                    })
                                end
                            end
                        else
                            entry.slots = shallowCopyTbl(entry._sytOrigSlots) or {}
                            entry.worn = shallowCopyTbl(entry._sytOrigWorn) or {}
                            entry.pet = entry._sytOrigPet
                            entry.wings = entry._sytOrigWings
                            entry.wingIt = entry._sytOrigWingIt
                            entry.skin = entry._sytOrigSkin
                            entry.see = entry._sytOrigSee
                            paintPeerRigs(entry, entry._sytOrigSkin, entry._sytOrigSee == true)
                            if entry._sytOrigName ~= nil then entry.name = entry._sytOrigName end
                        end
                        entry._sytLastSlots = entry.slots
                        entry._sytAppliedSig = wantSig
                        entry.shownKey = nil
                        entry.lookVer = (tonumber(entry.lookVer) or 0) + 1
                        if typeof(entry.tag) == "Instance" and entry.tag:IsA("GuiObject") then
                            entry.tag.Visible = not (active and peer.hideName == true)
                        end
                        if type(entry.redraw) == "function" then pcall(entry.redraw) end
                    end
                elseif entry._sytAppliedSig ~= wantSig then
                    entry._sytAppliedSig = wantSig
                    entry.shownKey = nil
                    if typeof(entry.tag) == "Instance" and entry.tag:IsA("GuiObject") then
                        entry.tag.Visible = not (active and peer.hideName == true)
                    end
                    if type(entry.redraw) == "function" then pcall(entry.redraw) end
                end
            end
        end
    end

    function P2P.SyncVisiblePeers()
        for uid, peer in pairs(P2P.Peers) do
            if tonumber(uid) and uid ~= (LP and LP.UserId) then
                pcall(applyPeerToWorld, uid, peer)
            end
        end
    end

    function P2P.GetPeerCount()
        local n = 0
        for uid, _ in pairs(P2P.Peers) do
            if uid ~= (LP and LP.UserId) then n = n + 1 end
        end
        return n
    end

    function P2P.OverlayProfile(targetUid, ret)
        if type(ret) ~= "table" then return end
        local prof = (type(ret[1]) == "table" and ret[1]) or (type(ret[2]) == "table" and ret[2])
        if type(prof) ~= "table" then return end

        local src, isLocal = nil, false
        local numUid = tonumber(targetUid)
        if LP and (targetUid == nil or numUid == LP.UserId or targetUid == LP.Name) then
            src = Visual.State
            isLocal = true
        elseif numUid and P2P.Peers[numUid] then
            src = P2P.Peers[numUid]
        elseif type(targetUid) == "string" and targetUid ~= "" then
            for uid, peer in pairs(P2P.Peers) do
                local plr = Players:GetPlayerByUserId(uid)
                if plr and (plr.Name == targetUid or peer.customName == targetUid) then
                    src = peer
                    break
                end
            end
        end
        if not src then return end
        if not isLocal and (src.reset or ProxyCommands.State.p2pEnabled == false) then return end

        local wornSrc = isLocal and src.fakeWorn or src.worn
        if type(wornSrc) == "table" and next(wornSrc) ~= nil then
            if type(prof.slots) == "table" then
                for sl, id in pairs(wornSrc) do
                    if type(id) == "number" and id > 0 then
                        prof.slots[sl] = id
                    elseif id == 0 then
                        prof.slots[sl] = nil
                    end
                end
            end
            if type(prof.worn) == "table" then
                if prof.worn[1] ~= nil or #prof.worn > 0 then
                    local slotMap = {}
                    for _, wid in ipairs(prof.worn) do
                        local info = H.ItemDB and H.ItemDB[wid]
                        local sl = (info and info.slot) or ("u" .. tostring(wid))
                        slotMap[sl] = wid
                    end
                    for sl, id in pairs(wornSrc) do
                        slotMap[sl] = (type(id) == "number" and id > 0) and id or nil
                    end
                    local arr = {}
                    for _, wid in pairs(slotMap) do
                        if type(wid) == "number" and wid > 0 then arr[#arr + 1] = wid end
                    end
                    prof.worn = arr
                else
                    for sl, id in pairs(wornSrc) do
                        if type(id) == "number" and id > 0 then
                            prof.worn[id] = true
                        elseif id == 0 and type(prof.slots) == "table" and prof.slots[sl] then
                            prof.worn[prof.slots[sl]] = nil
                        end
                    end
                end
            end
        end
        local spNm = tostring(src.skinPreset or "Real (Server Skin)")
        if spNm ~= "Real (Server Skin)" and type(prof.skin) == "string" then
            prof.skin = spNm
        end
        if ((src.customName or "") ~= "" or (src.role or "none") ~= "none" or src.spoofDr or src.spoofLegend) and type(prof.name) == "string" then
            local nmBase = (src.customName ~= "" and src.customName) or prof.name
            prof.name = Visual.FormatPreviewText(nmBase, src.role, {
                spoofDr = src.spoofDr == true,
                spoofLegend = src.spoofLegend == true,
            })
        end
        local rLow = string.lower(tostring(src.role or "none"))
        if rLow ~= "none" then
            if prof.title ~= nil then prof.title = rLow end
            if prof.wornTitle ~= nil then prof.wornTitle = rLow end
        end
        if src.spoofLegend or rLow == "legend" then
            if prof.hasLegend ~= nil then prof.hasLegend = true end
        end
        if src.spoofDr or rLow == "dr" then
            if prof.dr ~= nil then prof.dr = true end
        end
    end

    local function playSbvSound()
        pcall(function()
            local ss = game:GetService("SoundService")
            if not P2P.sfxSound or not P2P.sfxSound.Parent then
                local s = Instance.new("Sound")
                s.Name = "SYT_SBV_SFX"
                s.SoundId = "rbxassetid://85047722302784"
                s.Volume = 0.65
                s.Parent = ss
                P2P.sfxSound = s
            end
            P2P.sfxSound:Play()
        end)
    end

    local function displaySbvLine(rawName, customName, roleKey, effName, colorCode, worldName, msgText, opts)
        local cleanBase = stripColorTags(tostring(customName or ""))
        if cleanBase == "" then cleanBase = stripColorTags(tostring(rawName or "Player")) end
        local senderMarkup = Visual.FormatSbMarkup(cleanBase, roleKey, effName, colorCode, opts)
        local wClean = string.upper(stripColorTags(tostring(worldName or "WORLD")))
        if wClean == "" then wClean = "WORLD" end
        local safeMsg = tostring(msgText or ""):gsub("[\r\n]", " ")
        local sbLine = string.format("`5** from (%s`5) in [`$%s`5] ** :`` `$%s``", senderMarkup, wClean, safeMsg)
        playSbvSound()
        proxyConsole(sbLine, nil, true)
    end

    local function enqueueWire(kindTag, metaStr, fallbackWire, stateSig)
        if #Players:GetPlayers() <= 1 then return end
        if kindTag == "SET" or kindTag == "HELLO" then
            local now = os.clock()
            if stateSig and stateSig == P2P.lastSentSig and (now - (P2P.lastStateSentAt or 0)) < 35.0 and kindTag == "SET" then
                return
            end
            for i = #P2P.queue, 1, -1 do
                if P2P.queue[i].kind == "SET" or P2P.queue[i].kind == "HELLO" then
                    table.remove(P2P.queue, i)
                end
            end
        else
            if #P2P.queue >= 3 then table.remove(P2P.queue, 1) end
        end

        local item = { kind = kindTag, meta = metaStr, fallback = fallbackWire, sig = stateSig }
        if kindTag == "SBV" then
            table.insert(P2P.queue, 1, item)
        else
            P2P.queue[#P2P.queue + 1] = item
        end

        if P2P.sending then return end
        P2P.sending = true
        task.spawn(function()
            while #P2P.queue > 0 do
                if getEnv().__SYT_SCRIPT_TOKEN ~= MY_SCRIPT_TOKEN then break end
                if #Players:GetPlayers() <= 1 then
                    table.clear(P2P.queue)
                    break
                end
                local now = os.clock()
                for i = #P2P.sentTimes, 1, -1 do
                    if (now - P2P.sentTimes[i]) > 14.0 then
                        table.remove(P2P.sentTimes, i)
                    end
                end
                local waitUntil = math.max(P2P.nextSendAt or 0, P2P.blockedUntil or 0)
                if #P2P.sentTimes >= 3 then
                    waitUntil = math.max(waitUntil, P2P.sentTimes[1] + 14.2)
                end
                if now < waitUntil then
                    task.wait(math.min(0.4, waitUntil - now))
                else
                    local ch = getP2PChannel()
                    local ts = ch and LP and ch:FindFirstChild(tostring(LP.UserId))
                    if ch and (not ts or ts:GetAttribute("CanSend") ~= false) then
                        local pkt = table.remove(P2P.queue, 1)
                        local minGap = (pkt.kind == "SBV") and 2.8 or 4.0
                        P2P.nextSendAt = os.clock() + minGap
                        P2P.sentTimes[#P2P.sentTimes + 1] = os.clock()
                        if pkt.sig then
                            P2P.lastSentSig = pkt.sig
                            P2P.lastStateSentAt = os.clock()
                        end
                        local sendOk, sendRes
                        if not P2P.metaBroken and type(pkt.meta) == "string" and pkt.meta ~= "" then
                            P2P.lastMetaSentAt = os.clock()
                            P2P.lastMetaSentPayload = pkt.meta
                            sendOk, sendRes = pcall(function() return ch:SendAsync("xwkp", pkt.meta) end)
                        elseif type(pkt.fallback) == "string" and #pkt.fallback <= 200 then
                            sendOk, sendRes = pcall(function() return ch:SendAsync(pkt.fallback) end)
                        end
                        if sendOk and typeof(sendRes) == "Instance" and sendRes.Status == Enum.TextChatMessageStatus.Floodchecked then
                            P2P.blockedUntil = os.clock() + 12.0
                            for i = #P2P.queue, 1, -1 do
                                if P2P.queue[i].kind ~= "SBV" then table.remove(P2P.queue, i) end
                            end
                        end
                    else
                        task.wait(0.5)
                    end
                end
            end
            P2P.sending = false
        end)
    end

    local function buildStatePayloads(isHello, isReset)
        local S = Visual.State
        local _, roleIdx = Visual.FindRoleEntry(isReset and "none" or S.role)
        local effIdx = Visual.GetEffectIndex(isReset and "None" or S.effect)
        local roleKey = isReset and "none" or tostring(S.role or "none")
        local effName = isReset and "None" or tostring(S.effect or "None")
        local customName = isReset and "" or tostring(S.customName or "")
        local colorCode = isReset and "" or tostring(S.colorCode or "")
        local customTitle = isReset and "none" or tostring(S.customTitle or "none")
        local skinPreset = isReset and "Real (Server Skin)" or tostring(S.skinPreset or "Real (Server Skin)")
        local guildMode = isReset and "None (Real)" or tostring(S.guildMode or "None (Real)")
        local guildTag = isReset and "" or tostring(S.guildTag or "")
        local country = isReset and "Real (Unchanged)" or tostring(S.country or "Real (Unchanged)")
        local boosterColor = isReset and "Default (Real)" or tostring(S.boosterColor or "Default (Real)")
        local spoofLevel = isReset and 0 or (tonumber(S.spoofLevel) or 0)

        local flags = (isReset and 1 or 0)
            + (isHello and 2 or 0)
            + ((not isReset and S.ghostSkin) and 4 or 0)
            + ((not isReset and S.spoofDr) and 8 or 0)
            + ((not isReset and S.spoofLegend) and 16 or 0)
            + ((not isReset and S.spoofStillTag) and 32 or 0)
            + ((not isReset and S.booster) and 64 or 0)
            + ((not isReset and S.hideName) and 128 or 0)

        local wornPairs = {}
        local wornList = {}
        if not isReset then
            for sl, id in pairs(S.fakeWorn or {}) do
                local sIdx = SLOT_TO_IDX[tostring(sl)]
                if sIdx and type(id) == "number" and id >= 0 then
                    local iid = math.floor(id)
                    wornList[#wornList + 1] = { sIdx = sIdx, id = iid }
                end
            end
            table.sort(wornList, function(a, b) return a.sIdx < b.sIdx end)
            for _, item in ipairs(wornList) do
                wornPairs[#wornPairs + 1] = tostring(item.sIdx) .. "=" .. tostring(item.id)
            end
        end

        local metaStr = table.concat({
            "SYT2",
            isHello and "H" or "S",
            tostring(flags),
            cleanPipeVal(roleKey),
            cleanPipeVal(effName),
            cleanPipeVal(colorCode),
            cleanPipeVal(customTitle),
            cleanPipeVal(skinPreset),
            cleanPipeVal(guildMode),
            cleanPipeVal(country),
            cleanPipeVal(boosterColor),
            tostring(math.floor(spoofLevel)),
            strToHex(customName:sub(1, 28)),
            strToHex(guildTag:sub(1, 16)),
            table.concat(wornPairs, ",")
        }, "|")

        local bytes = { isHello and 0x12 or 0x11, flags, roleIdx, effIdx }
        pushStr(bytes, customName, 20)
        local countPos = #bytes + 1
        bytes[countPos] = 0
        local added = 0
        for _, item in ipairs(wornList) do
            local temp = {}
            pushVarint(temp, item.id)
            if (#bytes + 1 + #temp + 1) > 84 then break end
            bytes[#bytes + 1] = item.sIdx
            for _, tb in ipairs(temp) do bytes[#bytes + 1] = tb end
            added = added + 1
        end
        bytes[countPos] = added
        local fallbackWire = encodeBytesToWire(bytes)
        local sig = buildPeerSig({
            reset = isReset == true, role = roleKey, effect = effName, colorCode = colorCode,
            customTitle = customTitle, customName = customName, skinPreset = skinPreset,
            ghostSkin = (not isReset and S.ghostSkin) == true,
            spoofDr = (not isReset and S.spoofDr) == true,
            spoofLegend = (not isReset and S.spoofLegend) == true,
            spoofStillTag = (not isReset and S.spoofStillTag) == true,
            hideName = (not isReset and S.hideName) == true,
            guildMode = guildMode, guildTag = guildTag, country = country,
            booster = (not isReset and S.booster) == true, boosterColor = boosterColor,
            spoofLevel = spoofLevel, worn = isReset and {} or (S.fakeWorn or {}),
        })
        return metaStr, fallbackWire, sig
    end

    function P2P.BroadcastState(isReset)
        if ProxyCommands.State.p2pEnabled == false then return end
        P2P.pendingBroadcastToken = (P2P.pendingBroadcastToken or 0) + 1
        local myTok = P2P.pendingBroadcastToken
        P2P.pendingBroadcast = true
        task.delay(isReset and 0.08 or 0.75, function()
            if myTok ~= P2P.pendingBroadcastToken then return end
            P2P.pendingBroadcast = false
            if getEnv().__SYT_SCRIPT_TOKEN ~= MY_SCRIPT_TOKEN then return end
            if ProxyCommands.State.p2pEnabled == false then return end
            local metaStr, fallbackWire, sig = buildStatePayloads(false, isReset == true)
            enqueueWire("SET", metaStr, fallbackWire, sig)
        end)
    end

    function P2P.SendHello()
        if ProxyCommands.State.p2pEnabled == false then return end
        local now = os.clock()
        if (now - (P2P.lastHelloAt or 0)) < 5.0 then return end
        P2P.lastHelloAt = now
        local metaStr, fallbackWire, sig = buildStatePayloads(true, false)
        enqueueWire("HELLO", metaStr, fallbackWire, sig)
    end

    function P2P.SendSbv(msgText)
        local cleanMsg = tostring(msgText or ""):match("^%s*(.-)%s*$")
        if cleanMsg == "" then
            proxyConsole("`o[SBV] Format: /sbv <pesan>``")
            return false
        end
        cleanMsg = cleanMsg:sub(1, 120)
        local now = os.clock()
        if (now - (P2P.lastSbvAt or 0)) < 2.8 then
            proxyConsole("`o[SBV] Tunggu ~3 detik sebelum kirim /sbv lagi (anti-spam).``")
            return false
        end
        P2P.lastSbvAt = now

        local S = Visual.State
        local _, roleIdx = Visual.FindRoleEntry(S.role)
        local effIdx = Visual.GetEffectIndex(S.effect)
        local curWorld = (H.gt and cleanWorldName(H.gt.name)) or "START"
        local opts = { spoofDr = S.spoofDr == true, spoofLegend = S.spoofLegend == true }

        displaySbvLine(Core.GetInGameName(LP, true), S.customName, S.role, S.effect, S.colorCode, curWorld, cleanMsg, opts)

        local flags = (S.spoofDr and 8 or 0) + (S.spoofLegend and 16 or 0)
        local metaStr = table.concat({
            "SYT2", "B", tostring(flags),
            cleanPipeVal(S.role or "none"),
            cleanPipeVal(S.effect or "None"),
            cleanPipeVal(S.colorCode or ""),
            cleanPipeVal(S.customTitle or "none"),
            strToHex((S.customName or ""):sub(1, 24)),
            strToHex(curWorld:sub(1, 18)),
            strToHex(cleanMsg)
        }, "|")

        local bytes = { 0x13, roleIdx, effIdx }
        pushStr(bytes, S.customName or "", 20)
        pushStr(bytes, curWorld, 16)
        local rem = math.max(12, 84 - #bytes - 1)
        pushStr(bytes, cleanMsg, rem)
        enqueueWire("SBV", metaStr, encodeBytesToWire(bytes), nil)
        return true
    end

    local function applyDecodedPeerState(senderUid, peerObj, wantReply)
        peerObj.sig = buildPeerSig(peerObj)
        P2P.Peers[senderUid] = peerObj
        pcall(P2P.SaveToEnv)
        pcall(applyPeerToWorld, senderUid, peerObj)

        if wantReply and ProxyCommands.State.p2pEnabled ~= false and not P2P.replyTimers[senderUid] then
            local now = os.clock()
            if (now - (P2P.lastStateSentAt or 0)) < 7.0 then return end
            P2P.replyTimers[senderUid] = true
            local stagger = 1.4 + ((LP and (LP.UserId % 5) or 0) * 0.45)
            task.delay(stagger, function()
                P2P.replyTimers[senderUid] = nil
                if getEnv().__SYT_SCRIPT_TOKEN ~= MY_SCRIPT_TOKEN then return end
                if ProxyCommands.State.p2pEnabled ~= false then
                    local metaStr, fallbackWire, sig = buildStatePayloads(false, false)
                    enqueueWire("SET", metaStr, fallbackWire, sig)
                end
            end)
        end
    end

    function P2P.HandleIncomingPacket(wireTxt, metaTxt, senderUid, msgId)
        local isMeta = type(metaTxt) == "string" and metaTxt:sub(1, #P2P_META_TAG) == P2P_META_TAG
        local isWire = type(wireTxt) == "string" and wireTxt:sub(1, #P2P_PREFIX) == P2P_PREFIX
        if not isMeta and not isWire then return false end

        senderUid = tonumber(senderUid)
        if LP and senderUid == LP.UserId then
            if wireTxt == "xwkp" or isWire then
                if isMeta and metaTxt == P2P.lastMetaSentPayload then
                    P2P.metaBroken = false
                elseif not isMeta and (os.clock() - (P2P.lastMetaSentAt or 0)) < 3.0 and (metaTxt == nil or metaTxt == "") then
                    P2P.metaBroken = true
                end
            end
            return true
        end
        if not senderUid then return true end

        local now = os.clock()
        local dedupeKey = tostring(msgId or "") ~= "" and ("ID:" .. tostring(msgId)) or (tostring(senderUid) .. "|" .. (isMeta and metaTxt or wireTxt))
        if P2P.seenWire[dedupeKey] and (now - P2P.seenWire[dedupeKey]) < 4.0 then
            return true
        end
        P2P.seenWire[dedupeKey] = now
        for k, t0 in pairs(P2P.seenWire) do
            if (now - t0) > 12.0 then P2P.seenWire[k] = nil end
        end

        if isMeta then
            local f = {}
            for seg in (metaTxt .. "|"):gmatch("([^|]*)|") do f[#f + 1] = seg end
            local kind = f[2]
            if kind == "S" or kind == "H" then
                local flags = tonumber(f[3]) or 0
                local isReset = (flags % 2) == 1
                local wantReply = (math.floor(flags / 2) % 2) == 1
                local ghostSkin = (math.floor(flags / 4) % 2) == 1
                local spoofDr = (math.floor(flags / 8) % 2) == 1
                local spoofLegend = (math.floor(flags / 16) % 2) == 1
                local spoofStillTag = (math.floor(flags / 32) % 2) == 1
                local booster = (math.floor(flags / 64) % 2) == 1
                local hideName = (math.floor(flags / 128) % 2) == 1
                local roleKey = f[4] ~= "" and f[4] or "none"
                local effName = f[5] ~= "" and f[5] or "None"
                local colorCode = f[6] or ""
                local customTitle = f[7] ~= "" and f[7] or "none"
                local skinPreset = f[8] ~= "" and f[8] or "Real (Server Skin)"
                local guildMode = f[9] ~= "" and f[9] or "None (Real)"
                local country = f[10] ~= "" and f[10] or "Real (Unchanged)"
                local boosterColor = f[11] ~= "" and f[11] or "Default (Real)"
                local spoofLevel = tonumber(f[12]) or 0
                local cName = hexToStr(f[13] or "")
                local gTag = hexToStr(f[14] or "")
                local wornMap = {}
                for pair in tostring(f[15] or ""):gmatch("[^,]+") do
                    local sIdxStr, idStr = pair:match("^(%d+)=(%d+)$")
                    local sl = SLOTS_ORDER[tonumber(sIdxStr) or 0]
                    if sl and idStr then wornMap[sl] = tonumber(idStr) end
                end
                applyDecodedPeerState(senderUid, {
                    uid = senderUid,
                    reset = isReset,
                    role = roleKey,
                    effect = effName,
                    colorCode = colorCode,
                    customTitle = customTitle,
                    customName = cName,
                    skinPreset = skinPreset,
                    ghostSkin = ghostSkin,
                    spoofDr = spoofDr,
                    spoofLegend = spoofLegend,
                    spoofStillTag = spoofStillTag,
                    hideName = hideName,
                    guildMode = guildMode,
                    guildTag = gTag,
                    country = country,
                    booster = booster,
                    boosterColor = boosterColor,
                    spoofLevel = spoofLevel,
                    worn = wornMap,
                    updatedAt = now,
                    origAttrs = P2P.Peers[senderUid] and P2P.Peers[senderUid].origAttrs or nil,
                }, kind == "H" or wantReply)
                return true
            elseif kind == "B" then
                local flags = tonumber(f[3]) or 0
                local spoofDr = (math.floor(flags / 8) % 2) == 1
                local spoofLegend = (math.floor(flags / 16) % 2) == 1
                local roleKey = f[4] ~= "" and f[4] or "none"
                local effName = f[5] ~= "" and f[5] or "None"
                local colorCode = f[6] or ""
                local cName = hexToStr(f[8] or "")
                local wName = hexToStr(f[9] or "")
                local sbMsg = hexToStr(f[10] or "")
                local plr = Players:GetPlayerByUserId(senderUid)
                local rawNm = (plr and (plr:GetAttribute("GameName") or plr.Name)) or "Player"
                if P2P.Peers[senderUid] and P2P.Peers[senderUid].origAttrs and P2P.Peers[senderUid].origAttrs.GameName then
                    rawNm = P2P.Peers[senderUid].origAttrs.GameName
                end
                displaySbvLine(rawNm, cName, roleKey, effName, colorCode, wName, sbMsg, { spoofDr = spoofDr, spoofLegend = spoofLegend })
                return true
            end
        end

        local bytes = decodeWireToBytes(wireTxt)
        if not bytes then return true end
        local ptype = bytes[1]

        if ptype == 0x11 or ptype == 0x12 then
            local flags = bytes[2] or 0
            local roleIdx = bytes[3] or 1
            local effIdx = bytes[4] or 1
            local isReset = (flags % 2) == 1
            local wantReply = (math.floor(flags / 2) % 2) == 1
            local ghostSkin = (math.floor(flags / 4) % 2) == 1
            local spoofDr = (math.floor(flags / 8) % 2) == 1
            local spoofLegend = (math.floor(flags / 16) % 2) == 1
            local spoofStillTag = (math.floor(flags / 32) % 2) == 1
            local booster = (math.floor(flags / 64) % 2) == 1
            local hideName = (math.floor(flags / 128) % 2) == 1
            local cName, pos = readStr(bytes, 5)
            local slotCnt = bytes[pos] or 0
            pos = pos + 1
            local wornMap = {}
            for _ = 1, slotCnt do
                if pos > #bytes then break end
                local sIdx = bytes[pos]
                pos = pos + 1
                local itemId
                itemId, pos = readVarint(bytes, pos)
                local sl = SLOTS_ORDER[sIdx]
                if sl then wornMap[sl] = itemId end
            end

            local rc = Visual.RoleCatalog[roleIdx] or Visual.RoleCatalog[1]
            local eff = Visual.Presets.effects[effIdx] or "None"
            applyDecodedPeerState(senderUid, {
                uid = senderUid,
                reset = isReset,
                role = rc.key,
                effect = eff,
                customName = cName,
                ghostSkin = ghostSkin,
                spoofDr = spoofDr,
                spoofLegend = spoofLegend,
                spoofStillTag = spoofStillTag,
                booster = booster,
                hideName = hideName,
                worn = wornMap,
                updatedAt = now,
                origAttrs = P2P.Peers[senderUid] and P2P.Peers[senderUid].origAttrs or nil,
            }, ptype == 0x12 or wantReply)
            return true
        elseif ptype == 0x13 then
            local roleIdx = bytes[2] or 1
            local effIdx = bytes[3] or 1
            local cName, pos = readStr(bytes, 4)
            local wName, sbMsg
            wName, pos = readStr(bytes, pos)
            sbMsg, pos = readStr(bytes, pos)
            local rc = Visual.RoleCatalog[roleIdx] or Visual.RoleCatalog[1]
            local eff = Visual.Presets.effects[effIdx] or "None"
            local plr = Players:GetPlayerByUserId(senderUid)
            local rawNm = (plr and (plr:GetAttribute("GameName") or plr.Name)) or "Player"
            if P2P.Peers[senderUid] and P2P.Peers[senderUid].origAttrs and P2P.Peers[senderUid].origAttrs.GameName then
                rawNm = P2P.Peers[senderUid].origAttrs.GameName
            end
            displaySbvLine(rawNm, cName, rc.key, eff, nil, wName, sbMsg)
            return true
        end
        return false
    end

    function P2P.HandleIncomingWire(wireTxt, senderUid)
        return P2P.HandleIncomingPacket(wireTxt, nil, senderUid, nil)
    end

    getEnv().__SYT_OVERLAY_PROFILE_FN = P2P.OverlayProfile
    getEnv().__SYT_P2P_ON_INCOMING_FN = function(msg)
        if not msg then return nil end
        local txt = type(msg.Text) == "string" and msg.Text or ""
        local meta = type(msg.Metadata) == "string" and msg.Metadata or ""
        local isP2P = (meta:sub(1, #P2P_META_TAG) == P2P_META_TAG) or (txt:sub(1, 4) == "xwkp")
        if isP2P then
            local uid = msg.TextSource and msg.TextSource.UserId
            pcall(P2P.HandleIncomingPacket, txt, meta, uid, msg.MessageId)
            local props = Instance.new("TextChatMessageProperties")
            props.Text = ""
            props.PrefixText = ""
            return props
        end
        return nil
    end
end)()

-- Dialog 1: /CLOTHES (3-Column Character Edit + Explicit SET buttons + P2P Auto-Sync)
function ProxyCommands.OpenClothesDialog()
    Core.EnsureInit()
    Visual.EnsureOutfitPersistenceHooks()
    local sg, inner = makeNativeGameDialog("Clothes", "Character Edit - Wardrobe (/clothes)", 710, 430)
    local selectedCat = "all"
    local searchQ = ""

    local leftCol = Instance.new("ScrollingFrame", inner)
    leftCol.Position = UDim2.fromOffset(10, 44)
    leftCol.Size = UDim2.fromOffset(115, 364)
    leftCol.BackgroundColor3 = Color3.fromRGB(20, 66, 84)
    leftCol.BorderSizePixel = 0
    leftCol.ScrollBarThickness = 4
    leftCol.AutomaticCanvasSize = Enum.AutomaticSize.Y
    leftCol.CanvasSize = UDim2.new()
    Instance.new("UICorner", leftCol).CornerRadius = UDim.new(0, 6)
    local lLayout = Instance.new("UIListLayout", leftCol)
    lLayout.Padding = UDim.new(0, 4)

    local midCol = Instance.new("Frame", inner)
    midCol.Position = UDim2.fromOffset(132, 44)
    midCol.Size = UDim2.fromOffset(204, 364)
    midCol.BackgroundColor3 = Color3.fromRGB(20, 66, 84)
    midCol.BorderSizePixel = 0
    Instance.new("UICorner", midCol).CornerRadius = UDim.new(0, 6)

    local avatarBox = Instance.new("Frame", midCol)
    avatarBox.Size = UDim2.fromOffset(168, 162)
    avatarBox.Position = UDim2.new(0.5, -84, 0, 8)
    avatarBox.BackgroundColor3 = Color3.fromRGB(12, 34, 46)
    avatarBox.ClipsDescendants = true
    Instance.new("UICorner", avatarBox).CornerRadius = UDim.new(0, 6)

    local charStage = Instance.new("Frame", avatarBox)
    charStage.Name = "ClothesCharStage"
    charStage.Size = UDim2.new(1, -8, 1, -36)
    charStage.Position = UDim2.fromOffset(4, 2)
    charStage.BackgroundTransparency = 1

    local portraitHost = Instance.new("Frame", charStage)
    portraitHost.Name = "Portrait"
    portraitHost.Size = UDim2.fromOffset(32, 32)
    portraitHost.AnchorPoint = Vector2.new(0.5, 0.5)
    portraitHost.Position = UDim2.new(0.5, 0, 0.58, 0)
    portraitHost.BackgroundTransparency = 1
    portraitHost.ZIndex = 3
    local rigScale = Instance.new("UIScale", portraitHost)
    rigScale.Scale = 2.55

    local ps = H.playerSpriteObj
    local activeRig = nil
    if type(ps) == "table" and type(ps.buildRig) == "function" and type(ps.allRigs) == "table" then
        local okRig, built = pcall(ps.buildRig, false, portraitHost)
        if okRig and type(built) == "table" then
            built.portrait = true
            built.flip = false
            built.sign = 0
            table.insert(ps.allRigs, built)
            activeRig = built
            if type(ps.applyFeet) == "function" then pcall(ps.applyFeet, ps) end
            if typeof(ps.SKIN) == "Color3" and type(ps.setSkin) == "function" then pcall(ps.setSkin, ps, ps.SKIN) end
            if H.skillsObj and type(H.skillsObj.applyWorn) == "function" then
                pcall(H.skillsObj.applyWorn, built, os.clock())
            end
        end
    end

    local function cleanupPortraitRig()
        if activeRig and type(ps) == "table" and type(ps.allRigs) == "table" then
            for ri = #ps.allRigs, 1, -1 do
                if ps.allRigs[ri] == activeRig then
                    table.remove(ps.allRigs, ri)
                end
            end
            activeRig = nil
        end
    end
    if sg and typeof(sg) == "Instance" then
        sg.Destroying:Connect(cleanupPortraitRig)
    end
    avatarBox.Destroying:Connect(cleanupPortraitRig)

    local slotInfoLbl = Instance.new("TextLabel", avatarBox)
    slotInfoLbl.Size = UDim2.new(1, -8, 0, 14)
    slotInfoLbl.Position = UDim2.new(0, 4, 1, -36)
    slotInfoLbl.BackgroundTransparency = 1
    slotInfoLbl.Font = Enum.Font.Code
    slotInfoLbl.TextSize = 9
    slotInfoLbl.TextTruncate = Enum.TextTruncate.AtEnd
    slotInfoLbl.TextColor3 = Color3.fromRGB(148, 226, 255)

    local pNameLbl = Instance.new("TextLabel", avatarBox)
    pNameLbl.Size = UDim2.new(1, -8, 0, 18)
    pNameLbl.Position = UDim2.new(0, 4, 1, -20)
    pNameLbl.BackgroundTransparency = 1
    pNameLbl.Font = Enum.Font.GothamBold
    pNameLbl.TextSize = 11
    pNameLbl.TextColor3 = Color3.fromRGB(255, 230, 180)
    pNameLbl.Text = Visual.FormatPreviewText(Visual.State.customName or "", Visual.State.role or "none", {
        spoofDr = Visual.State.spoofDr == true,
        spoofLegend = Visual.State.spoofLegend == true,
    })

    local function rebuildMidPreview()
        pNameLbl.Text = Visual.FormatPreviewText(Visual.State.customName or "", Visual.State.role or "none", {
            spoofDr = Visual.State.spoofDr == true,
            spoofLegend = Visual.State.spoofLegend == true,
        })
        local rc = Visual.FindRoleEntry(Visual.State.role or "none")
        pNameLbl.TextColor3 = rc.color or Color3.fromRGB(255, 230, 180)
        local wt = H.wornTbl or {}
        local activeCount, parts = 0, {}
        for _, sl in ipairs({ "hat", "hair", "face", "shirt", "back", "hand", "pants", "feet", "chest", "ances", "neck", "pet" }) do
            local id = Visual.State.fakeWorn[sl]
            if id == nil then id = wt[sl] end
            if type(id) == "number" and id > 0 then
                activeCount += 1
                if #parts < 3 then parts[#parts + 1] = sl:sub(1, 3):upper() .. "#" .. tostring(id) end
            end
        end
        slotInfoLbl.Text = (activeCount > 0) and string.format("Set (%d): %s", activeCount, table.concat(parts, " ")) or "Set: Polos / Kosong (0)"
        if activeRig then
            local pObj = H.playerSpriteObj
            if H.skillsObj and type(H.skillsObj.applyWorn) == "function" then
                pcall(H.skillsObj.applyWorn, activeRig, os.clock())
            end
            if type(pObj) == "table" and type(pObj.applyFeet) == "function" then pcall(pObj.applyFeet, pObj) end
            if type(pObj) == "table" and typeof(pObj.SKIN) == "Color3" and type(pObj.setSkin) == "function" then
                pcall(pObj.setSkin, pObj, pObj.SKIN)
            end
        end
    end

    local setNowBtn = Instance.new("TextButton", midCol)
    setNowBtn.Size = UDim2.new(1, -16, 0, 28)
    setNowBtn.Position = UDim2.fromOffset(8, 178)
    setNowBtn.BackgroundColor3 = Color3.fromRGB(64, 186, 84)
    setNowBtn.Font = Enum.Font.GothamBold
    setNowBtn.TextSize = 11
    setNowBtn.TextColor3 = Color3.new(1, 1, 1)
    setNowBtn.Text = "SET OUTFIT + SYNC P2P"
    Instance.new("UICorner", setNowBtn).CornerRadius = UDim.new(0, 5)

    local saveBtn = Instance.new("TextButton", midCol)
    saveBtn.Size = UDim2.new(0.5, -10, 0, 26)
    saveBtn.Position = UDim2.fromOffset(8, 212)
    saveBtn.BackgroundColor3 = Color3.fromRGB(39, 125, 159)
    saveBtn.Font = Enum.Font.GothamBold
    saveBtn.TextSize = 11
    saveBtn.TextColor3 = Color3.new(1, 1, 1)
    saveBtn.Text = "SAVE SET"
    Instance.new("UICorner", saveBtn).CornerRadius = UDim.new(0, 5)

    local loadBtn = Instance.new("TextButton", midCol)
    loadBtn.Size = UDim2.new(0.5, -10, 0, 26)
    loadBtn.Position = UDim2.new(0.5, 2, 0, 212)
    loadBtn.BackgroundColor3 = Color3.fromRGB(140, 180, 192)
    loadBtn.Font = Enum.Font.GothamBold
    loadBtn.TextSize = 11
    loadBtn.TextColor3 = Color3.fromRGB(10, 20, 28)
    loadBtn.Text = "LOAD SET"
    Instance.new("UICorner", loadBtn).CornerRadius = UDim.new(0, 5)

    local clearBtn = Instance.new("TextButton", midCol)
    clearBtn.Size = UDim2.new(0.5, -10, 0, 26)
    clearBtn.Position = UDim2.fromOffset(8, 244)
    clearBtn.BackgroundColor3 = Color3.fromRGB(180, 70, 70)
    clearBtn.Font = Enum.Font.GothamBold
    clearBtn.TextSize = 10
    clearBtn.TextColor3 = Color3.new(1, 1, 1)
    clearBtn.Text = "RESET REAL"
    Instance.new("UICorner", clearBtn).CornerRadius = UDim.new(0, 5)

    local nakedBtn = Instance.new("TextButton", midCol)
    nakedBtn.Size = UDim2.new(0.5, -10, 0, 26)
    nakedBtn.Position = UDim2.new(0.5, 2, 0, 244)
    nakedBtn.BackgroundColor3 = Color3.fromRGB(145, 92, 48)
    nakedBtn.Font = Enum.Font.GothamBold
    nakedBtn.TextSize = 10
    nakedBtn.TextColor3 = Color3.new(1, 1, 1)
    nakedBtn.Text = "NAKED (0)"
    Instance.new("UICorner", nakedBtn).CornerRadius = UDim.new(0, 5)

    local wingsNote = Instance.new("TextLabel", midCol)
    wingsNote.Size = UDim2.new(1, -16, 0, 82)
    wingsNote.Position = UDim2.fromOffset(8, 276)
    wingsNote.BackgroundTransparency = 1
    wingsNote.Font = Enum.Font.Gotham
    wingsNote.TextSize = 10
    wingsNote.TextWrapped = true
    wingsNote.TextColor3 = Color3.fromRGB(200, 225, 235)
    wingsNote.Text = "Klik SET pada baju untuk pakai & kirim lengkap ke sesama pengguna SYT (P2P). Klik UNSET untuk kembalikan slot asli atau NAKED untuk lepas semua."

    local rightCol = Instance.new("Frame", inner)
    rightCol.Position = UDim2.fromOffset(344, 44)
    rightCol.Size = UDim2.fromOffset(344, 364)
    rightCol.BackgroundColor3 = Color3.fromRGB(20, 66, 84)
    rightCol.BorderSizePixel = 0
    Instance.new("UICorner", rightCol).CornerRadius = UDim.new(0, 6)

    local searchBox = Instance.new("TextBox", rightCol)
    searchBox.Size = UDim2.new(1, -16, 0, 28)
    searchBox.Position = UDim2.fromOffset(8, 8)
    searchBox.BackgroundColor3 = Color3.fromRGB(12, 34, 46)
    searchBox.Font = Enum.Font.Gotham
    searchBox.TextSize = 12
    searchBox.TextColor3 = Color3.new(1, 1, 1)
    searchBox.PlaceholderText = "Search clothes name or ID..."
    searchBox.Text = ""
    searchBox.ClearTextOnFocus = false
    Instance.new("UICorner", searchBox).CornerRadius = UDim.new(0, 5)

    local itemScroll = Instance.new("ScrollingFrame", rightCol)
    itemScroll.Position = UDim2.fromOffset(8, 42)
    itemScroll.Size = UDim2.new(1, -16, 1, -50)
    itemScroll.BackgroundColor3 = Color3.fromRGB(14, 38, 48)
    itemScroll.BorderSizePixel = 0
    itemScroll.ScrollBarThickness = 5
    itemScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    itemScroll.CanvasSize = UDim2.new()
    local rLayout = Instance.new("UIListLayout", itemScroll)
    rLayout.Padding = UDim.new(0, 4)

    local function catMatchesSlot(catKey, itemSlot)
        if catKey == "all" then return true end
        if catKey == "neck" then
            return itemSlot == "neck" or itemSlot == "chest" or itemSlot == "ances"
        elseif catKey == "pet" then
            return itemSlot == "pet" or itemSlot == "mask" or itemSlot == "ring"
        end
        return itemSlot == catKey
    end

    local rebuildItems
    rebuildItems = function()
        for _, ch in ipairs(itemScroll:GetChildren()) do
            if not ch:IsA("UIListLayout") then ch:Destroy() end
        end
        local db = H.ItemDB
        if type(db) ~= "table" then
            local waitLbl = Instance.new("TextLabel", itemScroll)
            waitLbl.Size = UDim2.new(1, -8, 0, 42)
            waitLbl.BackgroundTransparency = 1
            waitLbl.Font = Enum.Font.GothamBold
            waitLbl.TextSize = 12
            waitLbl.TextColor3 = Color3.fromRGB(255, 220, 140)
            waitLbl.Text = "ItemDB belum dimuat (masuk world dulu)..."
            return
        end
        local q = string.lower(searchQ or "")
        local list = {}
        for id, info in pairs(db) do
            if type(id) == "number" and type(info) == "table" and type(info.name) == "string" and not info.seed and info.kind ~= "seed" then
                local isWearable = (info.kind == "cloth") or (type(info.slot) == "string" and info.slot ~= "")
                if isWearable and catMatchesSlot(selectedCat, info.slot) then
                    if q == "" or string.find(string.lower(info.name), q, 1, true) or string.find(tostring(id), q, 1, true) then
                        list[#list + 1] = { id = id, info = info }
                    end
                end
            end
        end
        table.sort(list, function(a, b) return a.id < b.id end)
        for i = 1, math.min(#list, 120) do
            local entry = list[i]
            local sl = entry.info.slot or "back"
            local isWornNow = (Visual.State.fakeWorn[sl] == entry.id)

            local row = Instance.new("Frame", itemScroll)
            row.Size = UDim2.new(1, -8, 0, 38)
            row.BackgroundColor3 = isWornNow and Color3.fromRGB(24, 72, 54) or Color3.fromRGB(28, 52, 58)
            row.BorderSizePixel = 0
            Instance.new("UICorner", row).CornerRadius = UDim.new(0, 5)

            local iconF = Instance.new("Frame", row)
            iconF.Size = UDim2.fromOffset(30, 30)
            iconF.Position = UDim2.fromOffset(4, 4)
            iconF.BackgroundTransparency = 1
            Core.AttachItemSprite(iconF, entry.id, 28)

            local fxHint = ""
            if entry.info.speed then fxHint = " [Spd]" end
            if entry.info.punchRange then fxHint = fxHint .. " [Rng]" end
            local txtLbl = Instance.new("TextLabel", row)
            txtLbl.Size = UDim2.new(1, -98, 1, 0)
            txtLbl.Position = UDim2.fromOffset(38, 0)
            txtLbl.BackgroundTransparency = 1
            txtLbl.Font = Enum.Font.GothamBold
            txtLbl.TextSize = 11
            txtLbl.TextTruncate = Enum.TextTruncate.AtEnd
            txtLbl.TextXAlignment = Enum.TextXAlignment.Left
            txtLbl.TextColor3 = Color3.new(1, 1, 1)
            txtLbl.Text = string.format("[%s] %s (#%d)%s", tostring(sl):upper(), entry.info.name, entry.id, fxHint)

            local setBtn = Instance.new("TextButton", row)
            setBtn.Size = UDim2.fromOffset(50, 26)
            setBtn.Position = UDim2.new(1, -56, 0.5, -13)
            setBtn.BackgroundColor3 = isWornNow and Color3.fromRGB(64, 186, 84) or Color3.fromRGB(39, 125, 159)
            setBtn.BorderSizePixel = 0
            setBtn.Font = Enum.Font.GothamBold
            setBtn.TextSize = 11
            setBtn.TextColor3 = Color3.new(1, 1, 1)
            setBtn.Text = isWornNow and "UNSET" or "SET"
            Instance.new("UICorner", setBtn).CornerRadius = UDim.new(0, 4)

            setBtn.MouseButton1Click:Connect(function()
                if Visual.State.fakeWorn[sl] == entry.id then
                    Visual.State.fakeWorn[sl] = nil
                else
                    Visual.State.fakeWorn[sl] = entry.id
                    H._stripWingDoubleJump = true
                end
                Visual.ApplyOutfit()
                rebuildMidPreview()
                rebuildItems()
            end)
        end
    end

    setNowBtn.MouseButton1Click:Connect(function()
        H._stripWingDoubleJump = (next(Visual.State.fakeWorn) ~= nil)
        Visual.ApplyOutfit()
        rebuildMidPreview()
        proxyConsole("`2[Clothes] Outfit aktif diterapkan & disinkronkan via P2P!``")
    end)

    saveBtn.MouseButton1Click:Connect(function()
        local pairsList = {}
        for sl, id in pairs(Visual.State.fakeWorn) do
            pairsList[#pairsList + 1] = tostring(sl) .. "=" .. tostring(id)
        end
        safeWriteStorage("syt_clothes_preset.txt", table.concat(pairsList, ";"))
        proxyConsole("`2[Clothes] Preset outfit disimpan!``")
    end)

    loadBtn.MouseButton1Click:Connect(function()
        local raw = safeReadStorage("syt_clothes_preset.txt")
        if raw and raw ~= "" then
            Visual.State.fakeWorn = {}
            for pair in raw:gmatch("[^;]+") do
                local sl, id = pair:match("([^=]+)=(%d+)")
                if sl and id then Visual.State.fakeWorn[sl] = tonumber(id) end
            end
            H._stripWingDoubleJump = (next(Visual.State.fakeWorn) ~= nil)
            Visual.ApplyOutfit()
            rebuildMidPreview()
            rebuildItems()
            proxyConsole("`2[Clothes] Preset outfit dimuat & disinkronkan P2P!``")
        else
            proxyConsole("`o[Clothes] Belum ada preset tersimpan.``")
        end
    end)

    clearBtn.MouseButton1Click:Connect(function()
        Visual.State.fakeWorn = {}
        H._stripWingDoubleJump = false
        Visual.ApplyOutfit()
        rebuildMidPreview()
        rebuildItems()
        proxyConsole("`2[Clothes] Outfit dikembalikan ke asli (+ Sync P2P).``")
    end)

    nakedBtn.MouseButton1Click:Connect(function()
        Visual.State.fakeWorn = {}
        for _, sl in ipairs(Visual.Presets.wearSlots or {}) do
            Visual.State.fakeWorn[sl] = 0
        end
        H._stripWingDoubleJump = true
        Visual.ApplyOutfit()
        rebuildMidPreview()
        rebuildItems()
        proxyConsole("`2[Clothes] Semua slot dikosongkan (Naked 0) + Sync P2P!``")
    end)

    local cats = {
        { key = "all", label = "ALL" }, { key = "hat", label = "HAT / KEPALA" },
        { key = "hair", label = "HAIR" }, { key = "face", label = "FACE" },
        { key = "shirt", label = "SHIRT / BADAN" }, { key = "pants", label = "PANTS" },
        { key = "feet", label = "FEET / KAKI" }, { key = "back", label = "BACK / WINGS" },
        { key = "hand", label = "HAND" }, { key = "neck", label = "NECK / CHEST" },
        { key = "pet", label = "PET / MASK" },
    }
    for _, c in ipairs(cats) do
        local cb = Instance.new("TextButton", leftCol)
        cb.Size = UDim2.new(1, -8, 0, 28)
        cb.BackgroundColor3 = Color3.fromRGB(39, 125, 159)
        cb.Font = Enum.Font.GothamBold
        cb.TextSize = 10
        cb.TextColor3 = Color3.new(1, 1, 1)
        cb.Text = c.label
        Instance.new("UICorner", cb).CornerRadius = UDim.new(0, 4)
        cb.MouseButton1Click:Connect(function()
            selectedCat = c.key
            rebuildItems()
        end)
    end

    searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        searchQ = searchBox.Text
        rebuildItems()
    end)

    rebuildMidPreview()
    rebuildItems()
end

-- Dialog 2: /CN (Roles List lengkap dengan Nama Role, Jenis Role, Preview Nama pakai Role, dan tombol SET per item)
function ProxyCommands.OpenCnDialog()
    Core.EnsureInit()
    local _, inner = makeNativeGameDialog("SetRoleName", "Custom Name & Role (/cn)", 580, 430)

    local nameLbl = Instance.new("TextLabel", inner)
    nameLbl.Position = UDim2.fromOffset(12, 44)
    nameLbl.Size = UDim2.new(0.55, -14, 0, 18)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Font = Enum.Font.GothamBold
    nameLbl.TextSize = 11
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left
    nameLbl.TextColor3 = Color3.new(1, 1, 1)
    nameLbl.Text = "Custom Name (kosong = nama asli):"

    local effLbl = Instance.new("TextLabel", inner)
    effLbl.Position = UDim2.new(0.55, 6, 0, 44)
    effLbl.Size = UDim2.new(0.45, -18, 0, 18)
    effLbl.BackgroundTransparency = 1
    effLbl.Font = Enum.Font.GothamBold
    effLbl.TextSize = 11
    effLbl.TextXAlignment = Enum.TextXAlignment.Left
    effLbl.TextColor3 = Color3.new(1, 1, 1)
    effLbl.Text = "Animasi / Effect Nama:"

    local nameInput = Instance.new("TextBox", inner)
    nameInput.Position = UDim2.fromOffset(12, 64)
    nameInput.Size = UDim2.new(0.55, -14, 0, 30)
    nameInput.BackgroundColor3 = Color3.fromRGB(12, 34, 46)
    nameInput.Font = Enum.Font.GothamBold
    nameInput.TextSize = 13
    nameInput.TextColor3 = Color3.new(1, 1, 1)
    nameInput.PlaceholderText = "Ketik nama (contoh: REDY)"
    nameInput.Text = Visual.State.customName or ""
    nameInput.ClearTextOnFocus = false
    Instance.new("UICorner", nameInput).CornerRadius = UDim.new(0, 5)

    local chosenRole = Visual.State.role or "none"
    local effIdx = Visual.GetEffectIndex(Visual.State.effect)

    local effBtn = Instance.new("TextButton", inner)
    effBtn.Position = UDim2.new(0.55, 6, 0, 64)
    effBtn.Size = UDim2.new(0.45, -18, 0, 30)
    effBtn.BackgroundColor3 = Color3.fromRGB(39, 125, 159)
    effBtn.Font = Enum.Font.GothamBold
    effBtn.TextSize = 11
    effBtn.TextColor3 = Color3.new(1, 1, 1)
    effBtn.Text = "FX: " .. tostring(Visual.Presets.effects[effIdx] or "None")
    Instance.new("UICorner", effBtn).CornerRadius = UDim.new(0, 5)

    local previewBox = Instance.new("Frame", inner)
    previewBox.Position = UDim2.fromOffset(12, 100)
    previewBox.Size = UDim2.new(1, -24, 0, 34)
    previewBox.BackgroundColor3 = Color3.fromRGB(12, 34, 46)
    Instance.new("UICorner", previewBox).CornerRadius = UDim.new(0, 5)

    local previewLbl = Instance.new("TextLabel", previewBox)
    previewLbl.Size = UDim2.new(1, -16, 1, 0)
    previewLbl.Position = UDim2.fromOffset(8, 0)
    previewLbl.BackgroundTransparency = 1
    previewLbl.Font = Enum.Font.GothamBold
    previewLbl.TextSize = 12
    previewLbl.TextXAlignment = Enum.TextXAlignment.Left
    previewLbl.TextColor3 = Color3.fromRGB(255, 230, 140)

    local roleScroll = Instance.new("ScrollingFrame", inner)
    roleScroll.Position = UDim2.fromOffset(12, 140)
    roleScroll.Size = UDim2.new(1, -24, 1, -190)
    roleScroll.BackgroundColor3 = Color3.fromRGB(14, 38, 48)
    roleScroll.BorderSizePixel = 0
    roleScroll.ScrollBarThickness = 5
    roleScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    roleScroll.CanvasSize = UDim2.new()
    local rLay = Instance.new("UIListLayout", roleScroll)
    rLay.Padding = UDim.new(0, 4)

    local rowRefs = {}

    local function syncRoleVisuals()
        local curRaw = (nameInput.Text or ""):match("^%s*(.-)%s*$")
        local selRc = Visual.FindRoleEntry(chosenRole)
        local curFx = Visual.Presets.effects[effIdx] or "None"
        local curPreview = Visual.FormatPreviewText(curRaw, chosenRole)
        previewLbl.TextColor3 = selRc.color or Color3.new(1, 1, 1)
        previewLbl.Text = string.format("Preview Aktif: %s   |   Role: %s (%s)   |   FX: %s",
            curPreview, selRc.label, selRc.kind, curFx)

        for _, ref in ipairs(rowRefs) do
            local rc = ref.rc
            local isSel = (rc.key == chosenRole)
            ref.row.BackgroundColor3 = isSel and Color3.fromRGB(24, 72, 54) or Color3.fromRGB(20, 52, 66)
            ref.preview.Text = Visual.FormatPreviewText(curRaw, rc.key)
            ref.btn.BackgroundColor3 = isSel and Color3.fromRGB(64, 186, 84) or Color3.fromRGB(39, 125, 159)
            ref.btn.Text = isSel and "SET ✓" or "SET"
        end
    end

    local function applyCnState(roleKey)
        chosenRole = roleKey or chosenRole
        local rc = Visual.FindRoleEntry(chosenRole)
        Visual.State.customName = (nameInput.Text or ""):match("^%s*(.-)%s*$")
        Visual.State.role = rc.key
        Visual.State.customTitle = (rc.key ~= "none") and rc.key or "none"
        Visual.State.spoofDr = (rc.key == "dr")
        Visual.State.spoofLegend = (rc.key == "legend")
        Visual.State.effect = Visual.Presets.effects[effIdx] or "None"
        Visual.State.lockNames = (Visual.State.customName ~= "" or rc.key ~= "none" or Visual.State.effect ~= "None")
        Visual.Apply()
        syncRoleVisuals()
        local shown = Visual.FormatPreviewText(Visual.State.customName, rc.key, {
            spoofDr = Visual.State.spoofDr == true,
            spoofLegend = Visual.State.spoofLegend == true,
        })
        proxyConsole(string.format("`2[CN] SET '%s' | Role: %s (%s) | Synced P2P!``", shown, rc.label, rc.kind))
    end

    for _, rc in ipairs(Visual.RoleCatalog) do
        local row = Instance.new("Frame", roleScroll)
        row.Size = UDim2.new(1, -10, 0, 42)
        row.BorderSizePixel = 0
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 5)

        local roleLbl = Instance.new("TextLabel", row)
        roleLbl.Position = UDim2.fromOffset(8, 3)
        roleLbl.Size = UDim2.new(0.45, -8, 0, 18)
        roleLbl.BackgroundTransparency = 1
        roleLbl.Font = Enum.Font.GothamBold
        roleLbl.TextSize = 12
        roleLbl.TextXAlignment = Enum.TextXAlignment.Left
        roleLbl.TextColor3 = rc.color or Color3.new(1, 1, 1)
        roleLbl.Text = rc.label

        local kindLbl = Instance.new("TextLabel", row)
        kindLbl.Position = UDim2.fromOffset(8, 21)
        kindLbl.Size = UDim2.new(0.45, -8, 0, 16)
        kindLbl.BackgroundTransparency = 1
        kindLbl.Font = Enum.Font.Gotham
        kindLbl.TextSize = 10
        kindLbl.TextXAlignment = Enum.TextXAlignment.Left
        kindLbl.TextColor3 = Color3.fromRGB(180, 210, 224)
        kindLbl.Text = "Jenis: " .. rc.kind .. (rc.span and (" | Anim: " .. rc.span) or "")

        local pvLbl = Instance.new("TextLabel", row)
        pvLbl.Position = UDim2.new(0.46, 0, 0, 4)
        pvLbl.Size = UDim2.new(0.36, -6, 1, -8)
        pvLbl.BackgroundTransparency = 1
        pvLbl.Font = Enum.Font.GothamBold
        pvLbl.TextSize = 12
        pvLbl.TextTruncate = Enum.TextTruncate.AtEnd
        pvLbl.TextXAlignment = Enum.TextXAlignment.Right
        pvLbl.TextColor3 = rc.color or Color3.new(1, 1, 1)

        local setBtn = Instance.new("TextButton", row)
        setBtn.Position = UDim2.new(1, -68, 0.5, -14)
        setBtn.Size = UDim2.fromOffset(60, 28)
        setBtn.BorderSizePixel = 0
        setBtn.Font = Enum.Font.GothamBold
        setBtn.TextSize = 11
        setBtn.TextColor3 = Color3.new(1, 1, 1)
        Instance.new("UICorner", setBtn).CornerRadius = UDim.new(0, 4)

        rowRefs[#rowRefs + 1] = { rc = rc, row = row, preview = pvLbl, btn = setBtn }
        setBtn.MouseButton1Click:Connect(function()
            applyCnState(rc.key)
        end)
    end

    effBtn.MouseButton1Click:Connect(function()
        effIdx = (effIdx % #Visual.Presets.effects) + 1
        effBtn.Text = "FX: " .. tostring(Visual.Presets.effects[effIdx] or "None")
        syncRoleVisuals()
    end)

    nameInput:GetPropertyChangedSignal("Text"):Connect(syncRoleVisuals)

    local applyBtn = Instance.new("TextButton", inner)
    applyBtn.Position = UDim2.new(0, 12, 1, -42)
    applyBtn.Size = UDim2.new(0.5, -16, 0, 32)
    applyBtn.BackgroundColor3 = Color3.fromRGB(64, 186, 84)
    applyBtn.Font = Enum.Font.GothamBold
    applyBtn.TextSize = 13
    applyBtn.TextColor3 = Color3.new(1, 1, 1)
    applyBtn.Text = "SET NAME & ROLE"
    Instance.new("UICorner", applyBtn).CornerRadius = UDim.new(0, 6)
    applyBtn.MouseButton1Click:Connect(function()
        applyCnState(chosenRole)
    end)

    local resetBtn = Instance.new("TextButton", inner)
    resetBtn.Position = UDim2.new(0.5, 4, 1, -42)
    resetBtn.Size = UDim2.new(0.5, -16, 0, 32)
    resetBtn.BackgroundColor3 = Color3.fromRGB(140, 180, 192)
    resetBtn.Font = Enum.Font.GothamBold
    resetBtn.TextSize = 13
    resetBtn.TextColor3 = Color3.fromRGB(10, 20, 28)
    resetBtn.Text = "RESTORE REAL"
    Instance.new("UICorner", resetBtn).CornerRadius = UDim.new(0, 6)
    resetBtn.MouseButton1Click:Connect(function()
        Visual.Restore()
        nameInput.Text = ""
        chosenRole = "none"
        effIdx = 1
        effBtn.Text = "FX: None"
        syncRoleVisuals()
        proxyConsole("`2[CN] Nama & Role dipulihkan ke asli (+ Sync P2P).``")
    end)

    syncRoleVisuals()
end

-- Dialog 3: /LIST (Changelog & Full Command List)
function ProxyCommands.OpenListDialog()
    local _, inner = makeNativeGameDialog("List", "SYT Proxy Commands & Changelog (/list)", 480, 380)
    local sc = Instance.new("ScrollingFrame", inner)
    sc.Position = UDim2.fromOffset(10, 44)
    sc.Size = UDim2.new(1, -20, 1, -54)
    sc.BackgroundColor3 = Color3.fromRGB(14, 38, 48)
    sc.ScrollBarThickness = 5
    sc.AutomaticCanvasSize = Enum.AutomaticSize.Y
    sc.CanvasSize = UDim2.new()
    local lbl = Instance.new("TextLabel", sc)
    lbl.Size = UDim2.new(1, -16, 0, 0)
    lbl.Position = UDim2.fromOffset(8, 6)
    lbl.AutomaticSize = Enum.AutomaticSize.Y
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.Code
    lbl.TextSize = 12
    lbl.TextWrapped = true
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextYAlignment = Enum.TextYAlignment.Top
    lbl.TextColor3 = Color3.new(1, 1, 1)
    lbl.Text = table.concat({
        "[ + ] SYSTEM: Anti-Kick Freeze/Leave default ON, Player/Mod Join Log & Auto Leveling L10 (Auto Rerun)",
        "[ + ] MISC: Visual Ghost/NoClip, Bounded Fly (+5 Up, +-4 X), Zoom 2.5x, Skip Update, Slow Fall 2x",
        "[ + ] SPAM: Random Rainbow Word / Prefix Color (3-7s)",
        "[ + ] PNB: 5x5 Pad, Backpack Card Grid, World Storage Block/Safe, Auto Buy 5x Gems",
        "[ + ] PABRIK: Rendered Plantable Dirt Selector + Harvest & Break Loop",
        "[ + ] DIRT FARM & CLEAR WORLD: FIFO Queue + Lava Safe Zigzag",
        "[ + ] MOVE BLOCK: Set Take/Drop + Walk & Drop loop",
        "[ + ] PROXY P2P: Zero-Server Sync Outfit + Name/Role + Virtual SB (/sbv)",
        "[ + ] DISCORD HOOK: POST -> PATCH Embed + Saved Message ID",
        "",
        "-- COMMAND ---",
        "/p2p off | /p2p on : Toggle P2P client visual sync",
        "/sbv <pesan>       : Kirim Super Broadcast Visual ke sesama SYT user (format + animasi nama)",
        "/reme              : Toggle Fast Roulette ([REAL]/[FAKE] di atas kepala)",
        "/clothes           : Buka Dialog Character Edit Outfit (+ tombol SET + Sync P2P)",
        "/cn                : Buka Dialog Roles List lengkap (Nama, Jenis, Preview & SET)",
        "/set b 1 /set b 2  : Set posisi Break Player 1 & Player 2 (Host BJ)",
        "/lock t 1 /lock t 2: Set posisi Drop Lock Player 1 & Player 2 (Host BJ)",
        "/set tax <0-100>   : Atur pajak Host BJ (%)",
        "/info              : Cek koordinat B1, B2, T1, T2 & TAX",
        "/cal               : Hitung gems B1 & B2 (+2s), ambil lock & drop pemenang",
        "/get               : Tampilkan IP asli di Console",
        "/list              : Buka dialog Commands & Changelog ini",
    }, "\n")
end

-- Host BJ /cal Execution
function ProxyCommands.RunHostBjCalculate()
    local bj = ProxyCommands.State.bj
    if bj.running then proxyConsole("`4[BJ] Kalkulasi sedang berjalan!``"); return end
    if not bj.b1 or not bj.b2 or not bj.t1 or not bj.t2 then
        proxyConsole("`4[BJ] Set semua posisi dulu (/set b 1, /set b 2, /lock t 1, /lock t 2)!``")
        return
    end
    bj.running = true
    task.spawn(function()
        local function alive() return bj.running end
        local function countGemsAroundB(pos)
            Packets.WalkTeleport({ tx = pos.x, ty = pos.y, mode = "walk" })
            task.wait(0.25)
            local before = Core.ReadGems()
            -- Radius kecil (1.15) agar akurat dan tidak terambil ke kotak lawan
            Packets.Collect({ radius = 1.15, filterId = 112, stepMoveIfFar = false, preferWalk = true, collectDelay = 0.05, shouldContinue = alive })
            task.wait(0.30)
            return math.max(0, Core.ReadGems() - before)
        end

        local g1 = countGemsAroundB(bj.b1)
        Packets.SendChat({ message = string.format("[ + %d ]", g1), maxLength = 85 })
        task.wait(2.0)

        local g2 = countGemsAroundB(bj.b2)
        Packets.SendChat({ message = string.format("[ + %d ]", g2), maxLength = 85 })
        task.wait(0.8)

        -- Cek gems paling besar, lalu kumpulkan Lock dari T1 dan T2
        local winPos = (g1 >= g2) and bj.t1 or bj.t2
        local winnerLabel = (g1 >= g2) and "P1" or "P2"
        local beforeWL = Core.CountItem(242)
        local beforeDL = Core.CountItem(1796)
        Packets.WalkTeleport({ tx = bj.t1.x, ty = bj.t1.y, mode = "walk" })
        Packets.Collect({ radius = 1.4, stepMoveIfFar = false, preferWalk = true, collectDelay = 0.05, shouldContinue = alive })
        task.wait(0.3)
        Packets.WalkTeleport({ tx = bj.t2.x, ty = bj.t2.y, mode = "walk" })
        Packets.Collect({ radius = 1.4, stepMoveIfFar = false, preferWalk = true, collectDelay = 0.05, shouldContinue = alive })
        task.wait(0.3)

        local totalWL = math.max(0, (Core.CountItem(242) - beforeWL)) + math.max(0, (Core.CountItem(1796) - beforeDL)) * 100
        local payoutWL = math.floor(totalWL * (100 - clamp(bj.tax or 0, 0, 100)) / 100)
        Packets.WalkTeleport({ tx = winPos.x, ty = winPos.y, mode = "walk" })
        task.wait(0.25)
        if payoutWL >= 100 and Core.CountItem(1796) > 0 then
            local dls = math.min(Core.CountItem(1796), math.floor(payoutWL / 100))
            if dls > 0 then Packets.Drop(1796, dls); payoutWL = payoutWL - dls * 100 end
        end
        if payoutWL > 0 and Core.CountItem(242) > 0 then
            Packets.Drop(242, math.min(Core.CountItem(242), payoutWL))
        end
        proxyConsole(string.format("`2[BJ] %s WIN (%d vs %d) | Total:%d WL | Tax:%d%% | Drop:%d WL``", winnerLabel, g1, g2, totalWL, bj.tax or 0, math.floor(totalWL * (100 - (bj.tax or 0)) / 100)))
        bj.running = false
    end)
end

local function handleProxyCommand(rawText, senderName)
    local lp = LP or Players.LocalPlayer
    local myName = lp and lp.DisplayName or ""
    local myAccount = lp and lp.Name or ""
    if senderName and senderName ~= "" and senderName ~= myName and senderName ~= myAccount then
        -- Deteksi [FAKE] Roulette jika player lain mengetik hasil roulette di chat
        if ProxyCommands.State.remeEnabled then
            local numHit = rawText:match("spun the wheel and got[^%d]*(%d+)") or rawText:match("GET NUMBER%s+(%d+)")
            if numHit then
                local n = tonumber(numHit)
                if n and n >= 0 and n <= 36 then
                    local uid = nil
                    for _, p in ipairs(Core.GetInWorldPlayers(true)) do
                        if p.gameName == senderName then uid = p.userId; break end
                    end
                    local recentReal = uid and ProxyCommands.State.lastRealWheelByUser[uid]
                    if uid and (not recentReal or (os.clock() - recentReal) > 2.0) then
                        showOverheadTagPopup(uid, string.format("[ FAKE ] %s GET NUMBER %d", senderName, n), Color3.fromRGB(239, 68, 68))
                    end
                end
            end
        end
        return false
    end

    if rawText:sub(1, 1) ~= "/" then return false end
    local parts = {}
    for w in rawText:gmatch("%S+") do parts[#parts + 1] = w end
    local cmd = parts[1] and parts[1]:sub(2):lower() or ""
    local a1 = parts[2] and parts[2]:lower() or ""
    local a2 = parts[3] and parts[3]:lower() or ""

    if cmd == "p2p" then
        if a1 == "off" then
            ProxyCommands.State.p2pEnabled = false
            ProxyCommands.State.p2pLive = false
            pcall(ProxyCommands.SaveEnv)
            if ProxyCommands.P2P and ProxyCommands.P2P.SyncVisiblePeers then pcall(ProxyCommands.P2P.SyncVisiblePeers) end
            proxyConsole("`4[Proxy P2P] OFF``")
        else
            ProxyCommands.State.p2pEnabled = true
            ProxyCommands.State.p2pLive = (#Core.GetInWorldPlayers(false) > 0) or (ProxyCommands.P2P and ProxyCommands.P2P.GetPeerCount() > 0)
            pcall(ProxyCommands.SaveEnv)
            if ProxyCommands.P2P then
                pcall(ProxyCommands.P2P.SyncVisiblePeers)
                pcall(ProxyCommands.P2P.SendHello)
            end
            proxyConsole("`2[Proxy P2P] ON (Sync Visual Aktif)``")
        end
        return true
    elseif cmd == "sbv" then
        local msgText = (rawText:sub(5) or ""):match("^%s*(.-)%s*$")
        if ProxyCommands.P2P and ProxyCommands.P2P.SendSbv then
            ProxyCommands.P2P.SendSbv(msgText)
        end
        return true
    elseif cmd == "reme" then
        ProxyCommands.State.remeEnabled = not ProxyCommands.State.remeEnabled
        Misc.SetFastRoulette(ProxyCommands.State.remeEnabled)
        pcall(ProxyCommands.SaveEnv)
        proxyConsole(ProxyCommands.State.remeEnabled and "`2[Proxy /reme] ON (Fast Roulette)``" or "`4[Proxy /reme] OFF``")
        return true
    elseif cmd == "clothes" then
        task.spawn(function()
            local okD, errD = xpcall(ProxyCommands.OpenClothesDialog, debug.traceback)
            if not okD then proxyConsole("`4[Proxy /clothes] " .. tostring(errD) .. "``") end
        end)
        return true
    elseif cmd == "set" and a1 == "b" and (a2 == "1" or a2 == "2") then
        local pos = Core.ReadPos()
        ProxyCommands.State.bj["b" .. a2] = { x = pos.tx, y = pos.ty }
        pcall(ProxyCommands.SaveEnv)
        proxyConsole(string.format("`2[Host BJ] B%s set -> (%d, %d)``", a2, pos.tx, pos.ty))
        return true
    elseif cmd == "lock" and a1 == "t" and (a2 == "1" or a2 == "2") then
        local pos = Core.ReadPos()
        ProxyCommands.State.bj["t" .. a2] = { x = pos.tx, y = pos.ty }
        pcall(ProxyCommands.SaveEnv)
        proxyConsole(string.format("`2[Host BJ] T%s set -> (%d, %d)``", a2, pos.tx, pos.ty))
        return true
    elseif cmd == "set" and a1 == "tax" then
        local txPct = clamp(tonumber(a2) or 0, 0, 100)
        ProxyCommands.State.bj.tax = math.floor(txPct)
        pcall(ProxyCommands.SaveEnv)
        proxyConsole(string.format("`2[Host BJ] TAX set -> %d%%``", ProxyCommands.State.bj.tax))
        return true
    elseif cmd == "info" then
        local bj = ProxyCommands.State.bj
        local fmt = function(p) return p and string.format("(%d,%d)", p.x, p.y) or "UNSET" end
        proxyConsole(string.format("`9[Host BJ Info] B1:%s | B2:%s | T1:%s | T2:%s | TAX:%d%%``", fmt(bj.b1), fmt(bj.b2), fmt(bj.t1), fmt(bj.t2), bj.tax or 0))
        return true
    elseif cmd == "cal" then
        ProxyCommands.RunHostBjCalculate()
        return true
    elseif cmd == "get" then
        local ip = H._cachedIp
        if not ip or ip == "" then
            local ok, res = pcall(function() return game:HttpGet("https://api.ipify.org", true) end)
            ip = (ok and type(res) == "string" and #res < 64) and (res):match("^%s*(.-)%s*$") or "Unavailable"
            H._cachedIp = ip
        end
        proxyConsole(string.format("`2 YOUR'E IP IS %s ``", ip))
        return true
    elseif cmd == "cn" then
        task.spawn(function()
            local okD, errD = xpcall(ProxyCommands.OpenCnDialog, debug.traceback)
            if not okD then proxyConsole("`4[Proxy /cn] " .. tostring(errD) .. "``") end
        end)
        return true
    elseif cmd == "list" then
        task.spawn(function()
            local okD, errD = xpcall(ProxyCommands.OpenListDialog, debug.traceback)
            if not okD then proxyConsole("`4[Proxy /list] " .. tostring(errD) .. "``") end
        end)
        return true
    end
    return false
end

function ProxyCommands.Install()
    local env = getEnv()
    env.__SYT_PROXY_CMD_HANDLER = handleProxyCommand
    env.__SYT_P2P_CONNS = env.__SYT_P2P_CONNS or {}
    local p2pConns = env.__SYT_P2P_CONNS

    if H._proxyWheelConn then pcall(function() H._proxyWheelConn:Disconnect() end) end
    -- Hook ByteNet wheelSpun untuk menampilkan [ REAL ] popup di atas kepala roller saat /reme ON
    if H.Net and H.Net.wheelSpun and type(H.Net.wheelSpun.listen) == "function" and not H._proxyWheelHooked then
        H._proxyWheelHooked = true
        pcall(function()
            H.Net.wheelSpun.listen(function(pkt)
                if type(pkt) ~= "table" or not ProxyCommands.State.remeEnabled then return end
                local n = tonumber(pkt.n)
                local uid = pkt.userId
                local nm = stripColorTags(tostring(pkt.name or "Player"))
                if uid then ProxyCommands.State.lastRealWheelByUser[uid] = os.clock() end
                if n and n >= 0 and n <= 36 then
                    showOverheadTagPopup(uid or (LP and LP.UserId), string.format("[ REAL ] %s GET NUMBER %d", nm, n), Color3.fromRGB(34, 197, 94))
                end
            end)
        end)
    end

    -- Hook Net.entered & Net.look agar visual P2P peer tetap terpasang setelah server refresh look (0-frame defer + 0.18s followup)
    if H.Net and not H._p2pNetHooked then
        H._p2pNetHooked = true
        local function schedulePeerResync()
            local function runSync()
                if env.__SYT_SCRIPT_TOKEN ~= MY_SCRIPT_TOKEN then return end
                if ProxyCommands.P2P and ProxyCommands.P2P.SyncVisiblePeers then
                    pcall(ProxyCommands.P2P.SyncVisiblePeers)
                end
            end
            task.defer(runSync)
            task.delay(0.18, runSync)
        end
        if H.Net.entered and type(H.Net.entered.listen) == "function" then
            pcall(H.Net.entered.listen, schedulePeerResync)
        end
        if H.Net.look and type(H.Net.look.listen) == "function" then
            pcall(H.Net.look.listen, schedulePeerResync)
        end
    end

    -- Utama: Hook ChatUI.onCommand langsung (selalu re-check bila Game.lua menulis ulang onCommand)
    local chatTbl = resolveConsoleUi()
    if chatTbl and type(rawget(chatTbl, "add")) == "function" and type(rawget(chatTbl, "prefill")) == "function" then
        local curOnCmd = rawget(chatTbl, "onCommand")
        if curOnCmd ~= H._sytOnCmdWrapper then
            local origOnCmd = (type(curOnCmd) == "function") and curOnCmd or nil
            H._sytOnCmdWrapper = function(txt, ...)
                if type(txt) == "string" and txt:sub(1, 1) == "/" then
                    local okCmd, handled = pcall(handleProxyCommand, txt, LP and LP.Name or "")
                    if okCmd and handled then
                        return true
                    end
                end
                if type(origOnCmd) == "function" then
                    return origOnCmd(txt, ...)
                end
                return false
            end
            chatTbl.onCommand = H._sytOnCmdWrapper
            H.chatOnCmdHookedTbl = chatTbl
        end
    end

    -- P2P Transport + Slash Command Backup via TextChatService
    if H._proxyTcsToken ~= MY_SCRIPT_TOKEN then
        H._proxyTcsToken = MY_SCRIPT_TOKEN
        local ok, TCS = pcall(game.GetService, game, "TextChatService")
        if ok and TCS then
            if not env.__SYT_TCS_INCOMING_WRAPPED then
                env.__SYT_TCS_INCOMING_WRAPPED = true
                pcall(function()
                    local prevCb = TCS.OnIncomingMessage
                    TCS.OnIncomingMessage = function(msg)
                        local fn = env.__SYT_P2P_ON_INCOMING_FN
                        if type(fn) == "function" then
                            local okP, res = pcall(fn, msg)
                            if okP and res ~= nil then return res end
                        end
                        if type(prevCb) == "function" then return prevCb(msg) end
                        return nil
                    end
                end)
            end

            -- Global SendAsync hook (dipasang sekali pada method TextChannel.SendAsync untuk blokir /sbv & /cmd ke chat publik)
            if not env.__SYT_TCS_SENDASYNC_HOOKED and type(hookfunction) == "function" then
                pcall(function()
                    local sampleCh = TCS:FindFirstChildWhichIsA("TextChannel", true)
                    if sampleCh and type(sampleCh.SendAsync) == "function" then
                        env.__SYT_TCS_SENDASYNC_HOOKED = true
                        local origSend = sampleCh.SendAsync
                        env.__SYT_TCS_SENDASYNC_ORIG = hookfunction(origSend, function(selfCh, msgText, metaText, ...)
                            if typeof(selfCh) == "Instance" and selfCh:IsA("TextChannel") and type(msgText) == "string" and msgText:sub(1, 1) == "/" then
                                local hFn = env.__SYT_PROXY_CMD_HANDLER
                                if type(hFn) == "function" then
                                    local okH, handled = pcall(hFn, msgText, LP and LP.Name or "")
                                    if okH and handled then
                                        return { Status = Enum.TextChatMessageStatus.Success, Text = "" }
                                    end
                                end
                            end
                            return env.__SYT_TCS_SENDASYNC_ORIG(selfCh, msgText, metaText, ...)
                        end)
                    end
                end)
            end

            -- Satu listener MessageReceived terpusat (menghindari duplikasi double-handle)
            pcall(function()
                local mConn = TCS.MessageReceived:Connect(function(msg)
                    if not msg then return end
                    local txt = type(msg.Text) == "string" and msg.Text or ""
                    local meta = type(msg.Metadata) == "string" and msg.Metadata or ""
                    local uid = msg.TextSource and msg.TextSource.UserId
                    if (meta:sub(1, 5) == "SYT2|" or txt:sub(1, 4) == "xwkp") and ProxyCommands.P2P and ProxyCommands.P2P.HandleIncomingPacket then
                        pcall(ProxyCommands.P2P.HandleIncomingPacket, txt, meta, uid, msg.MessageId)
                        return
                    end
                    if txt:sub(1, 1) ~= "/" then
                        local src = msg.TextSource and msg.TextSource.Name or ""
                        handleProxyCommand(txt, src)
                    end
                end)
                p2pConns[#p2pConns + 1] = mConn
            end)
        end
    end
end

stopAllAutomationImpl = function(reason)
    local keepSession = (reason == "Rerun SYT")
    if PNB then PNB.Stop() end
    if Pabrik then Pabrik.Stop() end
    if DirtFarm then DirtFarm.Stop(keepSession) end
    if ClearWorld then ClearWorld.Stop(keepSession) end
    if MoveBlock then MoveBlock.Stop() end
    if AutoLeveling then AutoLeveling.Stop(keepSession) end
    if Spam then Spam.Stop() end
    stopRandomTp()
    if not keepSession then
        local ed = getEnv().__SYT_ENV_DATA
        if type(ed) == "table" then ed.rotSession = nil end
    end
    if reason and reason ~= "" and UI then
        setPNBStatus(reason)
        setPabrikStatus(reason)
        setDfStatus(reason)
        setCwStatus(reason)
        setSpamStatus(reason)
        pcall(UI.SetValue, UI, "MoveBlockStatus", reason)
        pcall(UI.SetValue, UI, "AutoLvlStatus", reason)
    end
    if UIHooks.updateButtons then UIHooks.updateButtons() end
end
SYT_Logic.StopAllAutomation = stopAllAutomationImpl

function UIHooks.getActiveMenuGui()
    if UI and UI.ScreenGui and UI.ScreenGui.Parent then return UI.ScreenGui end
    local gEnv = getEnv()
    local activeUi = gEnv and gEnv.__R8_DV_ACTIVE_UI
    local sg = activeUi and activeUi.ScreenGui
    if sg and sg.Parent then return sg end
    for _, root in ipairs(getAllGuiRoots()) do
        if typeof(root) == "Instance" then
            if root:IsA("ScreenGui") and root.Parent and string.find(root.Name, "^R8_DV_Engine_") then
                return root
            end
            local okCh, children = pcall(root.GetChildren, root)
            if okCh and type(children) == "table" then
                for _, ch in ipairs(children) do
                    if ch:IsA("ScreenGui") and ch.Parent and string.find(ch.Name, "^R8_DV_Engine_") then
                        return ch
                    end
                end
            end
        end
    end
    return nil
end

function UIHooks.menuIsReady()
    local sg = UIHooks.getActiveMenuGui()
    if not sg or not sg.Parent then return false end
    if UI and UI.MainWindow and not UI.MainWindow.Parent then return false end
    if not UI or type(UI.Features) ~= "table" or #UI.Features < 10 then return false end
    local okCnt, cnt = pcall(function() return #sg:GetDescendants() end)
    return okCnt and cnt > 20
end

function UIHooks.allCanvasesReady()
    return UIHooks.menuIsReady() and UIHooks.refreshBP ~= nil and UIHooks.refreshPad5x5 ~= nil
end

function UIHooks.enforceSingleActiveFeatureTab()
    if not UI then return end
    if type(UI.SelectFeature) == "function" then pcall(UI.SelectFeature, UI, 1) end
    if type(UI.Features) == "table" then
        for idx, feat in ipairs(UI.Features) do
            if type(feat) == "table" then
                local isFirst = (idx == 1)
                if feat.CenterPage and typeof(feat.CenterPage) == "Instance" then feat.CenterPage.Visible = isFirst end
                if feat.RightPage and typeof(feat.RightPage) == "Instance" then feat.RightPage.Visible = isFirst end
            end
        end
    end
    if type(UI.SyncRightPanelVisibility) == "function" then pcall(UI.SyncRightPanelVisibility, UI) end
    if type(UI.SyncNavCanvas) == "function" then pcall(UI.SyncNavCanvas) end
end

-- Left Scrollable Sidebar = 10 Fitur README (+), Masing-masing hanya menggunakan 2 Tab Panel (Center & Right)
buildSYTMenuFn = function()
    UIHooks.refreshBP      = nil
    UIHooks.refreshPabBP   = nil
    UIHooks.refreshPad5x5  = nil
    UIHooks.refreshMap     = nil
    UIHooks.refreshDfList  = nil
    UIHooks.refreshCwList  = nil
    UIHooks.refreshSysLog  = nil
    UIHooks.sidebarNameLbl = nil
    UIHooks.sidebarSubLbl  = nil

    local autoBuyOptions = { "OFF" }
    for _, o in ipairs(STORE_OFFERS) do
        autoBuyOptions[#autoBuyOptions + 1] = string.format("%s | %s (%d)", o.key, o.name, o.price)
    end

    if UI.Category then UI:Category("Core") end

    -- 1. + SYSTEM
    feature("System", "System")({
        center = center(function(c)
            c:Header("System Security", "Anti-Ban/Kick & Auto Leveling L10", "SYS")
            local SysCard = c:Card("System Config", nil, "Shield", {
                Subtitle = "Default ON + Freeze saat player/mod join"
            })
            SysCard:Toggle("System ON / OFF", "SysMasterToggle", SystemModule.State.enabled, function(v)
                SystemModule.State.enabled = v == true
                if not v then SystemModule.State.frozenByJoin = false end
            end)
            SysCard:Toggle("Leave (OFF) / Freeze (ON)", "SysLeaveFreezeSwitch", SystemModule.State.mode == "FREEZE", function(v)
                SystemModule.State.mode = v and "FREEZE" or "LEAVE"
            end)
            SysCard:Toggle("Log Discord", "SysLogDiscordToggle", SystemModule.State.discordLog, function(v)
                SystemModule.State.discordLog = v == true
            end)
            SysCard:Toggle("Auto Leveling (L10)", "SysAutoLevelToggle", AutoLeveling.State.running, function(v)
                if v then AutoLeveling.Start() else AutoLeveling.Stop() end
            end)
            SysCard:Input("Leveling Status", "AutoLvlStatus", "Idle", AutoLeveling.State.status or "Idle")
        end),
        right = right(function(r)
            local LogCard = r:Card("Join & Mod Log", "Logs", "Shield", {
                Subtitle = "Scrollable player & mod join list"
            })
            LogCard:Input("Player & Mod Join Log", "__SYS_LOG_ANCHOR__", "__SYS_LOG_ANCHOR_KEY__", "__SYS_LOG_ANCHOR_KEY__")
            LogCard:Button("Minimize ke Shortcut", "MINIMIZE", "Minimize", function()
                if UI and type(UI.MinimizeToIcon) == "function" then
                    pcall(UI.MinimizeToIcon, UI)
                end
            end)
            LogCard:Button("Tutup Menu", "CLOSE", "Close", function()
                UIHooks.userDestroy = true
                if Misc and Misc.State and Misc.State.noClip then pcall(Misc.SetNoClip, false) end
                if Misc and Misc.State and Misc.State.zoom25x then pcall(Misc.SetZoom25x, false) end
                stopAllAutomationImpl("Menu ditutup permanen")
                cleanupSYTGuiContainers(nil)
            end)
        end)
    })

    -- 2. + MISC
    feature("Misc", "Misc")({
        center = center(function(c)
            c:Header("Misc Tools", "5 Tools pendukung visual & pergerakan", "MSC")
            local MiscCard = c:Card("Misc Toggle", nil, "Sliders", {
                Subtitle = "Visual NoClip, Bounded Fly, Zoom, Skip Update, Slow Fall"
            })
            MiscCard:Toggle("Ghost / No Clip", "MiscNoClipToggle", Misc.State.noClip, function(on)
                Misc.SetNoClip(on)
            end)
            MiscCard:Toggle("Fly (+5 Up, +-4 X)", "MiscFlyToggle", Misc.State.fly, function(on)
                Misc.SetFly(on)
            end)
            MiscCard:Toggle("Zoom (2.5x Out)", "MiscZoomToggle", Misc.State.zoom25x, function(on)
                Misc.SetZoom25x(on)
            end)
            MiscCard:Toggle("Skip Update Item", "MiscSkipUpdateToggle", Misc.State.skipUpdateItem, function(on)
                Misc.SetSkipUpdateItem(on)
            end)
            MiscCard:Toggle("Slow Fall (2x)", "MiscSlowFallToggle", Misc.State.slowFall, function(on)
                Misc.SetSlowFall(on)
            end)
        end),
        right = right(function(r)
            local MiscInfo = r:Card("Misc Status", "State", "Sliders", {
                Subtitle = "NoClip tidak menggerakkan server (balik ke posisi awal saat OFF)"
            })
            MiscInfo:Input("NoClip Status", "MiscNoClipStatus", "Idle", "Idle")
        end)
    })

    -- 3. + SPAMING
    feature("Spaming", "Spaming")({
        center = center(function(c)
            c:Header("Spaming", "Auto chat spam max 85 char", "SPM")
            local SpamCard = c:Card("Spam Config", nil, "Bolt", {
                Subtitle = "Rainbow / Prefix saling eksklusif (`0..`9)"
            })
            SpamCard:Input("Text (Max 85)", "SpamTextInput", "Ketik pesan...", Spam.State.text, function(txt)
                Spam.State.text = tostring(txt or ""):sub(1, 85)
            end)
            SpamCard:Toggle("Rainbow Colour", "SpamRainbowToggle", Spam.State.rainbowOn, function(v)
                Spam.State.rainbowOn = v == true
                if v and Spam.State.prefixOn then
                    Spam.State.prefixOn = false
                    pcall(UI.SetValue, UI, "SpamPrefixToggle", false, true)
                end
            end)
            SpamCard:Toggle("Prefix Color", "SpamPrefixToggle", Spam.State.prefixOn, function(v)
                Spam.State.prefixOn = v == true
                if v and Spam.State.rainbowOn then
                    Spam.State.rainbowOn = false
                    pcall(UI.SetValue, UI, "SpamRainbowToggle", false, true)
                end
            end)
            SpamCard:Input("Delay Radio (3 - 7s)", "__SPAM_RADIO_ANCHOR__", "__SPAM_RADIO_ANCHOR_KEY__", "__SPAM_RADIO_ANCHOR_KEY__")
        end),
        right = right(function(r)
            local SpamCtrl = r:Card("Spam Control", "Chat", "Bolt", {})
            SpamCtrl:Button("[SPAM] Start / Stop", "TOGGLE", "Bolt", function() Spam.Toggle() end)
            SpamCtrl:Input("Status Spam", "SpamStatusDisplay", "Idle", Spam.State.status or "Idle")
        end)
    })

    if UI.Category then UI:Category("Farm") end

    -- 4. + PNB
    feature("PNB", "PNB")({
        center = center(function(c)
            c:Header("PNB", "Pad 5x5 (Anda di tengah) & Backpack Block Grid", "PNB")
            local PnbPadCard = c:Card("Tile & Block Selector", nil, "Combat", {
                Subtitle = "Hanya Block yang muncul (Seed dikecualikan)"
            })
            PnbPadCard:Input("Tile Selector 5x5", "__PAD_5X5_ANCHOR__", "__PAD_5X5_ANCHOR_KEY__", "__PAD_5X5_ANCHOR_KEY__")
            PnbPadCard:Input("Block Selector", "__BP_ITEM_ANCHOR__", "__BP_ITEM_ANCHOR_KEY__", "__BP_ITEM_ANCHOR_KEY__")
            PnbPadCard:Button("Refresh Backpack", "REFRESH", "Visuals", function()
                Core.EnsureInit()
                if UIHooks.refreshBP then UIHooks.refreshBP() end
            end)
        end),
        right = right(function(r)
            local PnbCtrl = r:Card("PNB Control", "Run", "Bolt", {})
            PnbCtrl:Button("[PNB] Start / Stop", "TOGGLE", "Bolt", function() PNB.Toggle() end)
            PnbCtrl:Input("Block Dipilih", "PnbSelectedDisplay", "None", PNB.State.selectedBlockId and tostring(PNB.State.selectedBlockId) or "None")
            PnbCtrl:Input("Status PNB", "PnbStatusDisplay", "Idle", PNB.State.status or "Idle")

            local PnbCfg = r:Card("Storage & Buy", "PNB", "Combat", {})
            PnbCfg:Input("Storage Block (WORLD:ID)", "PnbStorageBlockInput", "Maks 8 char...", PNB.State.storageBlock, function(txt)
                PNB.State.storageBlock = tostring(txt or ""):gsub("%s+", ""):upper():sub(1, 17)
            end)
            PnbCfg:Input("Storage Safe (WORLD:ID)", "PnbStorageSafeInput", "Maks 8 char...", PNB.State.storageSafe, function(txt)
                PNB.State.storageSafe = tostring(txt or ""):gsub("%s+", ""):upper():sub(1, 17)
            end)
            PnbCfg:Slider("Speed (0 - 100%)", "PnbSpeedPct", 0, 100, PNB.State.speedPct or 60, "%", function(v)
                PNB.State.speedPct = clamp(tonumber(v) or 60, 0, 100)
            end, 5)
            PnbCfg:Dropdown("Auto Buy (Min 5x Gems)", "PnbAutoBuySelect", autoBuyOptions, "OFF", function(v)
                PNB.State.autoBuyKey = v or "OFF"
            end)
        end)
    })

    -- 5. + PABRIK
    feature("Pabrik", "Pabrik")({
        center = center(function(c)
            c:Header("Pabrik", "Dirt Selector & Block/Seed Pair", "PAB")
            local PabCard = c:Card("Grid Selector", nil, "AutoFarm", {
                Subtitle = "Pilih tile tanam plantable & item pair"
            })
            PabCard:Input("Dirt Selector", "__WORLD_MAP_ANCHOR__", "__WORLD_MAP_ANCHOR_KEY__", "__WORLD_MAP_ANCHOR_KEY__")
            PabCard:Input("Block / Seed Card", "__PAB_BP_ANCHOR__", "__PAB_BP_ANCHOR_KEY__", "__PAB_BP_ANCHOR_KEY__")
        end),
        right = right(function(r)
            local PabCfg = r:Card("Pabrik Config", "Setup", "AutoFarm", {})
            PabCfg:Input("Block / Seed Pair", "PabrikItemInput", "Nama / ID...", tostring(Pabrik.State.itemName or ""), function(txt)
                if txt and txt ~= "" then Pabrik.SetItem(txt) end
            end)
            PabCfg:Slider("Speed (0 - 100%)", "PabrikSpeedPct", 0, 100, Pabrik.State.speedPct or 60, "%", function(v)
                Pabrik.State.speedPct = clamp(tonumber(v) or 60, 0, 100)
            end, 5)
            PabCfg:Button("Set Break Pos", "SET BREAK", "Teleports", function()
                Pabrik.SetBreakPos()
            end)
            PabCfg:Input("Break Pos", "PabrikBreakPosDisplay", "Unset", "-")
            PabCfg:Input("Pair Aktif", "PabrikPairDisplay", "Unset", "-")

            local PabCtrl = r:Card("Pabrik Control", "Run", "Bolt", {})
            PabCtrl:Button("[PABRIK] Start / Stop", "TOGGLE", "Bolt", function() Pabrik.Toggle() end)
            PabCtrl:Input("Status Pabrik", "PabrikStatusDisplay", "Idle", "Idle")
        end)
    })

    -- 6. + DIRT FARM
    feature("DirtFarm", "Dirt Farm")({
        center = center(function(c)
            c:Header("Dirt Farm", "Antrian FIFO world format 2-kolom", "DF")
            local DfListCard = c:Card("World Queue (FIFO)", nil, "Active", {
                Subtitle = "Max 8 karakter huruf/angka per world"
            })
            DfListCard:Input("World Name", "DfWorldInput", "WORLD (Max 8)", "", function(txt)
                local clean = sanitizeWorldSpec(txt, false)
                DirtFarm.State.rotationInput = clean
            end)
            DfListCard:Button("Add World to List", "ADD WORLD", "Teleports", function()
                local raw = UI:GetValue("DfWorldInput") or ""
                local clean = sanitizeWorldSpec(raw, false)
                if clean == "" then return end
                local list = DirtFarm.State.rotationWorlds or {}
                local exists = false
                for _, w in ipairs(list) do if w == clean then exists = true; break end end
                if not exists then
                    list[#list + 1] = clean
                    DirtFarm.State.rotationWorlds = list
                    DirtFarm.State.rotationText = table.concat(list, ", ")
                    if DirtFarm._syncEnvQueue then DirtFarm._syncEnvQueue(list) end
                    UI:SetValue("DfWorldInput", "")
                    if UIHooks.refreshDfList then UIHooks.refreshDfList() end
                end
            end)
            DfListCard:Input("World List Queue", "__DF_LIST_ANCHOR__", "__DF_LIST_ANCHOR_KEY__", "__DF_LIST_ANCHOR_KEY__")
        end),
        right = right(function(r)
            local DfCtrl = r:Card("Dirt Farm Control", "DF", "Bolt", {})
            DfCtrl:Button("[DF] Start / Stop", "TOGGLE", "Bolt", function() DirtFarm.Toggle() end)
            DfCtrl:Input("Status DF", "DfStatusDisplay", "Idle", DirtFarm.State.status or "Idle")
        end)
    })

    -- 7. + CLEAR WORLD
    feature("ClearWorld", "Clear World")({
        center = center(function(c)
            c:Header("Clear World", "Break FG & BG kecuali Door, Lock, Bedrock", "CW")
            local CwListCard = c:Card("World Queue (FIFO)", nil, "Active", {
                Subtitle = "Pre-break lava 1 tile di bawah + zigzag"
            })
            CwListCard:Input("World Name", "CwWorldInput", "WORLD (Max 8)", "", function(txt)
                ClearWorld.State.worldInput = sanitizeWorldSpec(txt, false)
            end)
            CwListCard:Button("Add World to List", "ADD WORLD", "Teleports", function()
                local ok = ClearWorld.AddWorld(UI:GetValue("CwWorldInput") or "")
                if ok then UI:SetValue("CwWorldInput", "") end
            end)
            CwListCard:Input("World List Queue", "__CW_LIST_ANCHOR__", "__CW_LIST_ANCHOR_KEY__", "__CW_LIST_ANCHOR_KEY__")
        end),
        right = right(function(r)
            local CwCtrl = r:Card("Clear World Control", "CW", "Bolt", {})
            CwCtrl:Button("[CW] Start / Stop", "TOGGLE", "Bolt", function() ClearWorld.Toggle() end)
            CwCtrl:Input("Status Clear World", "CwStatusDisplay", "Idle", ClearWorld.State.status or "Idle")
        end)
    })

    -- 8. + MOVE BLOCK
    feature("MoveBlock", "Move Block")({
        center = center(function(c)
            c:Header("Move Block", "Pindah drop item Take -> Drop (Delay 2s)", "MV")
            local MbPosCard = c:Card("Position Setup", nil, "Teleports", {})
            MbPosCard:Button("Set Take", "SET TAKE", "Teleports", function() MoveBlock.SetTake() end)
            MbPosCard:Input("Take Pos", "MoveTakeDisplay", "Unset", MoveBlock.State.takePos and string.format("(%d, %d)", MoveBlock.State.takePos.x + 1, MoveBlock.State.takePos.y + 1) or "Unset")
            MbPosCard:Button("Set Drop", "SET DROP", "Teleports", function() MoveBlock.SetDrop() end)
            MbPosCard:Input("Drop Pos", "MoveDropDisplay", "Unset", MoveBlock.State.dropPos and string.format("(%d, %d)", MoveBlock.State.dropPos.x + 1, MoveBlock.State.dropPos.y + 1) or "Unset")
        end),
        right = right(function(r)
            local MbCtrl = r:Card("Move Control", "Move", "Bolt", {})
            MbCtrl:Button("[MOVE] Start / Stop", "TOGGLE", "Bolt", function() MoveBlock.Toggle() end)
            MbCtrl:Input("Status Move Block", "MoveBlockStatus", "Idle", MoveBlock.State.status or "Idle")
        end)
    })

    if UI.Category then UI:Category("Network") end

    -- 9. + DISCORD HOOK'S
    feature("DiscordHooks", "Discord Hook's")({
        center = center(function(c)
            c:Header("Discord Hook's", "POST lalu PATCH by Message ID", "DH")
            local DhCard = c:Card("Webhook Config", nil, "Shield", {
                Subtitle = "Simpan Message ID di OS Storage & anti-spam"
            })
            DhCard:Input("Webhook Link (Max 300)", "SysDiscordUrlInput", "https://discord.com/api/webhooks/...", DiscordHook.State.url, function(txt)
                DiscordHook.State.url = tostring(txt or ""):sub(1, 300)
            end)
            DhCard:Input("Delay Radio (1 - 5m)", "__DH_RADIO_ANCHOR__", "__DH_RADIO_ANCHOR_KEY__", "__DH_RADIO_ANCHOR_KEY__")
            DhCard:Toggle("ON / OFF Discord Hook", "DhEnabledToggle", DiscordHook.State.enabled, function(v)
                if v then DiscordHook.Start() else DiscordHook.Stop() end
            end)
        end),
        right = right(function(r)
            local DhInfo = r:Card("Hook Status", "ID", "Shield", {})
            DhInfo:Input("Saved Message ID", "DhMessageIdDisplay", "-", DiscordHook.State.messageId or "-")
        end)
    })

    -- 10. + PROXY
    feature("Proxy", "Proxy")({
        center = center(function(c)
            c:Header("Proxy System", "P2P Client Visual Sync + Virtual SB (/sbv)", "PRX")
            local ProxyCard = c:Card("Visual Dialogs & /sbv", nil, "Player", {
                Subtitle = "Gunakan /command di chat atau tombol SET / Kirim /sbv"
            })
            ProxyCard:Button("Wardrobe (/clothes)", "CLOTHES", "Visuals", function()
                task.spawn(function() xpcall(ProxyCommands.OpenClothesDialog, debug.traceback) end)
            end)
            ProxyCard:Button("Role & Name (/cn)", "CN", "Player", function()
                task.spawn(function() xpcall(ProxyCommands.OpenCnDialog, debug.traceback) end)
            end)
            ProxyCard:Button("Proxy List (/list)", "LIST", "Shield", function()
                task.spawn(function() xpcall(ProxyCommands.OpenListDialog, debug.traceback) end)
            end)
            ProxyCard:Input("Virtual SB (/sbv)", "ProxySbvInput", "Ketik pesan /sbv ...", "", function(txt)
                ProxyCommands.State.sbvDraft = tostring(txt or "")
            end)
            ProxyCard:Button("Kirim Virtual SB (/sbv)", "SEND SBV", "Bolt", function()
                local msg = UI and UI:GetValue("ProxySbvInput") or ProxyCommands.State.sbvDraft or ""
                if ProxyCommands.P2P and ProxyCommands.P2P.SendSbv then
                    if ProxyCommands.P2P.SendSbv(msg) and UI then
                        pcall(UI.SetValue, UI, "ProxySbvInput", "")
                    end
                end
            end)
            ProxyCard:Button("Hitung BJ (/cal)", "CAL BJ", "Bolt", function()
                ProxyCommands.RunHostBjCalculate()
            end)
        end),
        right = right(function(r)
            local ProxyInfo = r:Card("Proxy Status", "Cmd", "Player", {
                Subtitle = "/sbv <msg>, /cn, /clothes, /p2p off|on, /reme, /list, /set b, /lock t, /cal, /get"
            })
            ProxyInfo:Input("Status P2P", "ProxyP2pStatus", "ON", "STANDBY")
            ProxyInfo:Input("Host BJ Setup", "ProxyBjStatus", "UNSET", "B1/B2/T1/T2")
        end)
    })

    if type(UIHooks.buildMountedCanvasesFn) == "function" then UIHooks.buildMountedCanvasesFn() end
    if UI and type(UI.SyncNavCanvas) == "function" then pcall(UI.SyncNavCanvas) end
end

UIHooks.buttonMap = {}

function UIHooks.scanResponsiveButtons()
    local buttonMap = UIHooks.buttonMap
    local specs = {
        { prefix = "[PNB]",    getState = function() return PNB.State.running,          "STOP", "START", "[PNB] AKTIF (Klik STOP)",    "[PNB] Start / Stop" end },
        { prefix = "[PABRIK]", getState = function() return Pabrik.State.running,       "STOP", "START", "[PABRIK] AKTIF (Klik STOP)", "[PABRIK] Start / Stop" end },
        { prefix = "[DF]",     getState = function() return DirtFarm.State.running,     "STOP", "START", "[DF] AKTIF (Klik STOP)",     "[DF] Start / Stop" end },
        { prefix = "[CW]",     getState = function() return ClearWorld.State.running,   "STOP", "START", "[CW] AKTIF (Klik STOP)",     "[CW] Start / Stop" end },
        { prefix = "[MOVE]",   getState = function() return MoveBlock.State.running,    "STOP", "START", "[MOVE] AKTIF (Klik STOP)",   "[MOVE] Start / Stop" end },
        { prefix = "[SPAM]",   getState = function() return Spam.State.running,         "STOP", "START", "[SPAM] AKTIF (Klik STOP)",   "[SPAM] Start / Stop" end },
    }
    local scanRoots = {}
    local ownSg = UIHooks.getActiveMenuGui()
    if ownSg then scanRoots[1] = ownSg else scanRoots = getAllGuiRoots() end
    for _, root in ipairs(scanRoots) do
        if typeof(root) == "Instance" then
            local okD, desc = pcall(root.GetDescendants, root)
            if okD and type(desc) == "table" then
                for _, d in ipairs(desc) do
                    if d:IsA("TextLabel") then
                        local okT, dTxt = pcall(function() return d.Text end)
                        if okT and type(dTxt) == "string" then
                            for _, sp in ipairs(specs) do
                                if not buttonMap[sp.prefix] and string.sub(dTxt, 1, #sp.prefix) == sp.prefix then
                                    local btn = d:FindFirstAncestorOfClass("TextButton")
                                    if btn then
                                        local badgeTxt, badgePill = nil, nil
                                        for _, ch in ipairs(btn:GetDescendants()) do
                                            if ch:IsA("TextLabel") and ch ~= d and (ch.Text == "TOGGLE" or ch.Text == "START" or ch.Text == "STOP" or ch.Text == "CLICKED") then
                                                badgeTxt = ch; badgePill = ch.Parent; break
                                            end
                                        end
                                        buttonMap[sp.prefix] = { lbl = d, badgeTxt = badgeTxt, badgePill = badgePill, getState = sp.getState }
                                        btn.MouseButton1Click:Connect(function()
                                            task.delay(0.05, function() if UIHooks.updateButtons then UIHooks.updateButtons() end end)
                                            task.delay(0.20, function() if UIHooks.updateButtons then UIHooks.updateButtons() end end)
                                            task.delay(0.62, function() if UIHooks.updateButtons then UIHooks.updateButtons() end end)
                                        end)
                                    end
                                end
                            end
                            if not UIHooks.sidebarSubLbl and dTxt == "Active Session" then
                                UIHooks.sidebarSubLbl = d
                                local cardParent = d.Parent
                                if cardParent then
                                    for _, sib in ipairs(cardParent:GetDescendants()) do
                                        if sib:IsA("TextLabel") and sib ~= d and (sib.Text == (LP and LP.DisplayName) or sib.Text == (LP and LP.Name) or sib.Text == "Operator") then
                                            UIHooks.sidebarNameLbl = sib; break
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

UIHooks.updateButtons = function()
    for _, item in pairs(UIHooks.buttonMap) do
        if item.lbl and item.lbl.Parent then
            local active, onBadge, offBadge, onLbl, offLbl = item.getState()
            item.lbl.Text = active and onLbl or offLbl
            if item.badgeTxt and item.badgeTxt.Parent then item.badgeTxt.Text = active and onBadge or offBadge end
            if item.badgePill and item.badgePill.Parent and item.badgePill:IsA("Frame") then
                item.badgePill.BackgroundColor3 = active and Color3.fromRGB(220, 38, 38) or Color3.fromRGB(16, 185, 129)
                item.badgePill.BackgroundTransparency = 0
            end
        end
    end
end

UIHooks.buildMountedCanvasesFn = function()
    table.clear(UIHooks.buttonMap)

    local function findAllTextBoxesWithKey(key)
        local found = {}
        local function scanRoot(root)
            if typeof(root) ~= "Instance" then return end
            local okD, desc = pcall(root.GetDescendants, root)
            if not okD or type(desc) ~= "table" then return end
            for _, d in ipairs(desc) do
                if d:IsA("TextBox") then
                    local okT, txt = pcall(function() return d.Text end)
                    if okT and txt == key then found[#found + 1] = d end
                end
            end
        end
        local ownSg = UIHooks.getActiveMenuGui()
        if ownSg then scanRoot(ownSg); if #found > 0 then return found end end
        for _, root in ipairs(getAllGuiRoots()) do
            if root ~= ownSg then scanRoot(root); if #found > 0 then return found end end
        end
        return found
    end

    local function mountEmbeddedCanvas(anchorKey, heightPx, buildFn)
        local function tryMountNow()
            local hits = findAllTextBoxesWithKey(anchorKey)
            if #hits == 0 then return false end
            local anchorBox = hits[1]
            if not anchorBox or not anchorBox.Parent then return false end
            local rowContainer = anchorBox.Parent
            for _, ch in ipairs(rowContainer:GetChildren()) do
                if not ch:IsA("UICorner") and not ch:IsA("UIStroke") then ch:Destroy() end
            end
            rowContainer.Size = UDim2.new(1, 0, 0, heightPx)
            rowContainer.BackgroundColor3 = Color3.fromRGB(11, 14, 20)
            rowContainer.ClipsDescendants = true
            local okB, bErr = xpcall(buildFn, debug.traceback, rowContainer)
            if not okB then warn("[SYT Canvas Error " .. tostring(anchorKey) .. "]: " .. tostring(bErr)) end
            return true
        end
        if tryMountNow() then return end
        task.spawn(function()
            for _ = 1, 80 do
                if getEnv().__SYT_SCRIPT_TOKEN ~= MY_SCRIPT_TOKEN then return end
                if tryMountNow() then return end
                task.wait(0.05)
            end
        end)
    end

    -- 1. PNB 5x5 TILE SELECTOR PAD (__PAD_5X5_ANCHOR_KEY__)
    mountEmbeddedCanvas("__PAD_5X5_ANCHOR_KEY__", 210, function(rowContainer)
        local padFrame = Instance.new("Frame", rowContainer)
        padFrame.Size = UDim2.new(1, -12, 1, -12)
        padFrame.Position = UDim2.fromOffset(6, 6)
        padFrame.BackgroundTransparency = 1
        local cellMap = {}
        local function refresh5x5()
            local pos = Core.ReadPos()
            local myGameName = Core.GetInGameName(LP, true)
            for dy = -2, 2 do
                for dx = -2, 2 do
                    local cell = cellMap[tileKey(dx, dy)]
                    if cell then
                        if dx == 0 and dy == 0 then
                            cell.BackgroundColor3 = Color3.fromRGB(161, 98, 7)
                            cell.TextColor3 = Color3.fromRGB(254, 240, 138)
                            cell.Text = string.format("%s\n(%d,%d)", string.sub(myGameName, 1, 6), pos.tx, pos.ty)
                        else
                            local on = PNB.State.grid5x5[tileKey(dx, dy)] == true
                            cell.BackgroundColor3 = on and Color3.fromRGB(14, 116, 144) or Color3.fromRGB(23, 29, 41)
                            cell.TextColor3 = on and Color3.new(1, 1, 1) or Color3.fromRGB(148, 163, 184)
                            cell.Text = string.format("%+d,%+d", dx, dy)
                        end
                    end
                end
            end
        end
        for r = 0, 4 do
            local dy = r - 2
            for c = 0, 4 do
                local dx = c - 2
                local btn = Instance.new("TextButton", padFrame)
                btn.Size = UDim2.new(0.2, -4, 0.2, -4)
                btn.Position = UDim2.new(c * 0.2, 2, r * 0.2, 2)
                btn.BorderSizePixel = 0
                btn.Font = Enum.Font.Code
                btn.TextSize = 10
                btn.TextWrapped = true
                Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)
                if dx ~= 0 or dy ~= 0 then
                    btn.MouseButton1Click:Connect(function() PNB.ToggleTile5x5(dx, dy) end)
                end
                cellMap[tileKey(dx, dy)] = btn
            end
        end
        UIHooks.refreshPad5x5 = refresh5x5
        refresh5x5()
    end)

    -- 2. BACKPACK CARD GRID (3-column Flex Grid: __BP_ITEM_ANCHOR_KEY__)
    mountEmbeddedCanvas("__BP_ITEM_ANCHOR_KEY__", 220, function(rowContainer)
        local scroller = rowContainer:FindFirstAncestorOfClass("ScrollingFrame")
        local topBar = Instance.new("Frame", rowContainer)
        topBar.Size = UDim2.new(1, -12, 0, 22)
        topBar.Position = UDim2.fromOffset(6, 4)
        topBar.BackgroundTransparency = 1
        local infoLbl = Instance.new("TextLabel", topBar)
        infoLbl.Size = UDim2.fromScale(1, 1)
        infoLbl.BackgroundTransparency = 1
        infoLbl.Font = Enum.Font.Code
        infoLbl.TextSize = 10
        infoLbl.TextXAlignment = Enum.TextXAlignment.Left
        infoLbl.TextColor3 = Color3.fromRGB(148, 163, 184)
        infoLbl.Text = "Block Selector (Tap pilih / tap lagi batal)"

        local scroll = Instance.new("ScrollingFrame", rowContainer)
        scroll.Size = UDim2.new(1, -12, 1, -32)
        scroll.Position = UDim2.fromOffset(6, 28)
        scroll.BackgroundColor3 = Color3.fromRGB(8, 10, 15)
        scroll.BorderSizePixel = 0
        scroll.ScrollBarThickness = 4
        scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
        scroll.CanvasSize = UDim2.new()
        local grid = Instance.new("UIGridLayout", scroll)
        grid.CellSize = UDim2.new(0.32, 0, 0, 74)
        grid.CellPadding = UDim2.fromOffset(4, 5)

        local function rebuildBP()
            for _, ch in ipairs(scroll:GetChildren()) do
                if ch:IsA("TextButton") then ch:Destroy() end
            end
            -- Hanya block (seed tidak masuk per README PNB spec)
            local items = PNB.GetBackpackBlocks(false)
            for _, it in ipairs(items) do
                local isSel = (PNB.State.selectedBlockId == it.id)
                local cell = Instance.new("TextButton", scroll)
                cell.Text = ""
                cell.AutoButtonColor = false
                cell.BackgroundColor3 = isSel and Color3.fromRGB(22, 48, 68) or Color3.fromRGB(19, 24, 34)
                cell.BorderSizePixel = 0
                Instance.new("UICorner", cell).CornerRadius = UDim.new(0, 6)
                local st = Instance.new("UIStroke", cell)
                st.Color = isSel and Color3.fromRGB(56, 189, 248) or Color3.fromRGB(48, 58, 76)
                st.Thickness = isSel and 1.8 or 1

                local iconHolder = Instance.new("Frame", cell)
                iconHolder.Size = UDim2.fromOffset(32, 32)
                iconHolder.AnchorPoint = Vector2.new(0.5, 0)
                iconHolder.Position = UDim2.new(0.5, 0, 0, 5)
                iconHolder.BackgroundTransparency = 1
                Core.AttachItemSprite(iconHolder, it.id, 30)

                local cntLbl = Instance.new("TextLabel", cell)
                cntLbl.Size = UDim2.fromOffset(32, 14)
                cntLbl.Position = UDim2.new(1, -34, 0, 2)
                cntLbl.BackgroundTransparency = 1
                cntLbl.Font = Enum.Font.Code
                cntLbl.TextSize = 9
                cntLbl.TextXAlignment = Enum.TextXAlignment.Right
                cntLbl.TextColor3 = Color3.fromRGB(250, 204, 21)
                cntLbl.Text = "x" .. tostring(it.count)

                local nameLbl = Instance.new("TextLabel", cell)
                nameLbl.Size = UDim2.new(1, -6, 0, 24)
                nameLbl.Position = UDim2.new(0, 3, 1, -26)
                nameLbl.BackgroundTransparency = 1
                nameLbl.Font = Enum.Font.Gotham
                nameLbl.TextSize = 9
                nameLbl.TextWrapped = true
                nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
                nameLbl.TextColor3 = Color3.fromRGB(226, 232, 240)
                nameLbl.Text = string.format("%s [%d]", it.name, it.id)

                cell.MouseButton1Click:Connect(function()
                    if PNB.State.selectedBlockId == it.id then
                        PNB.State.selectedBlockId = nil
                        UI:SetValue("PnbSelectedDisplay", "None")
                    else
                        PNB.State.selectedBlockId = it.id
                        UI:SetValue("PnbSelectedDisplay", string.format("%s (ID:%d | x%d)", it.name, it.id, it.count))
                        Pabrik.SetItem(it.id)
                        UI:SetValue("PabrikItemInput", tostring(it.id))
                        if UIHooks.refreshPabBP then pcall(UIHooks.refreshPabBP) end
                    end
                    rebuildBP()
                end)
            end
            infoLbl.Text = string.format("Blocks di Backpack: %d (Hanya Block, Seed exclude)", #items)
        end
        UIHooks.refreshBP = rebuildBP
        if scroller then
            scroller:GetPropertyChangedSignal("Visible"):Connect(function() if scroller.Visible then rebuildBP() end end)
        end
        task.delay(0.3, rebuildBP)
    end)

    -- 2B. PABRIK BLOCK / SEED CARD GRID (__PAB_BP_ANCHOR_KEY__)
    mountEmbeddedCanvas("__PAB_BP_ANCHOR_KEY__", 185, function(rowContainer)
        local scroller = rowContainer:FindFirstAncestorOfClass("ScrollingFrame")
        local scroll = Instance.new("ScrollingFrame", rowContainer)
        scroll.Size = UDim2.new(1, -12, 1, -12)
        scroll.Position = UDim2.fromOffset(6, 6)
        scroll.BackgroundColor3 = Color3.fromRGB(8, 10, 15)
        scroll.BorderSizePixel = 0
        scroll.ScrollBarThickness = 4
        scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
        scroll.CanvasSize = UDim2.new()
        local grid = Instance.new("UIGridLayout", scroll)
        grid.CellSize = UDim2.new(0.32, 0, 0, 72)
        grid.CellPadding = UDim2.fromOffset(4, 5)

        local function rebuildPabBP()
            for _, ch in ipairs(scroll:GetChildren()) do
                if ch:IsA("TextButton") then ch:Destroy() end
            end
            local items = PNB.GetBackpackBlocks(true)
            for _, it in ipairs(items) do
                local isSel = (Pabrik.State.blockId == it.id) or (Pabrik.State.seedId == it.id)
                local cell = Instance.new("TextButton", scroll)
                cell.Text = ""
                cell.AutoButtonColor = false
                cell.BackgroundColor3 = isSel and Color3.fromRGB(46, 28, 72) or Color3.fromRGB(19, 24, 34)
                cell.BorderSizePixel = 0
                Instance.new("UICorner", cell).CornerRadius = UDim.new(0, 6)
                local st = Instance.new("UIStroke", cell)
                st.Color = isSel and Color3.fromRGB(168, 85, 247) or Color3.fromRGB(48, 58, 76)
                st.Thickness = isSel and 1.8 or 1

                local iconHolder = Instance.new("Frame", cell)
                iconHolder.Size = UDim2.fromOffset(30, 30)
                iconHolder.AnchorPoint = Vector2.new(0.5, 0)
                iconHolder.Position = UDim2.new(0.5, 0, 0, 4)
                iconHolder.BackgroundTransparency = 1
                Core.AttachItemSprite(iconHolder, it.id, 28)

                local cntLbl = Instance.new("TextLabel", cell)
                cntLbl.Size = UDim2.fromOffset(32, 14)
                cntLbl.Position = UDim2.new(1, -34, 0, 2)
                cntLbl.BackgroundTransparency = 1
                cntLbl.Font = Enum.Font.Code
                cntLbl.TextSize = 9
                cntLbl.TextXAlignment = Enum.TextXAlignment.Right
                cntLbl.TextColor3 = Color3.fromRGB(250, 204, 21)
                cntLbl.Text = "x" .. tostring(it.count)

                local nameLbl = Instance.new("TextLabel", cell)
                nameLbl.Size = UDim2.new(1, -6, 0, 24)
                nameLbl.Position = UDim2.new(0, 3, 1, -26)
                nameLbl.BackgroundTransparency = 1
                nameLbl.Font = Enum.Font.Gotham
                nameLbl.TextSize = 9
                nameLbl.TextWrapped = true
                nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
                nameLbl.TextColor3 = Color3.fromRGB(226, 232, 240)
                nameLbl.Text = string.format("%s [%d]", it.name, it.id)

                cell.MouseButton1Click:Connect(function()
                    if isSel then
                        Pabrik.State.blockId, Pabrik.State.seedId, Pabrik.State.itemName = nil, nil, ""
                        UI:SetValue("PabrikPairDisplay", "Unset")
                    else
                        Pabrik.SetItem(it.id)
                        UI:SetValue("PabrikItemInput", tostring(it.id))
                    end
                    rebuildPabBP()
                end)
            end
        end
        UIHooks.refreshPabBP = rebuildPabBP
        if scroller then
            scroller:GetPropertyChangedSignal("Visible"):Connect(function() if scroller.Visible then rebuildPabBP() end end)
        end
        task.delay(0.35, rebuildPabBP)
    end)

    -- 3. PABRIK RENDERED PLANTABLE DIRT SELECTOR (__WORLD_MAP_ANCHOR_KEY__)
    mountEmbeddedCanvas("__WORLD_MAP_ANCHOR_KEY__", 220, function(rowContainer)
        local hudLbl = Instance.new("TextLabel", rowContainer)
        hudLbl.Size = UDim2.new(1, -12, 0, 18)
        hudLbl.Position = UDim2.fromOffset(6, 4)
        hudLbl.BackgroundTransparency = 1
        hudLbl.Font = Enum.Font.Code
        hudLbl.TextSize = 10
        hudLbl.TextXAlignment = Enum.TextXAlignment.Left
        hudLbl.TextColor3 = Color3.fromRGB(167, 243, 208)
        hudLbl.Text = "Ketuk tile kosong di atas Dirt/Solid untuk Plantable Tile"

        local mapView = Instance.new("Frame", rowContainer)
        mapView.Size = UDim2.new(1, -12, 1, -28)
        mapView.Position = UDim2.fromOffset(6, 24)
        mapView.BackgroundColor3 = Color3.fromRGB(18, 34, 58)
        mapView.ClipsDescendants = true

        local hitBtn = Instance.new("TextButton", mapView)
        hitBtn.Size = UDim2.fromScale(1, 1)
        hitBtn.BackgroundTransparency = 1
        hitBtn.Text = ""
        hitBtn.ZIndex = 15

        local pool = {}
        local lastDraw = 0
        local function getBox(i, col)
            local f = pool[i]
            if not f then
                f = Instance.new("Frame", mapView)
                f.BorderSizePixel = 0
                pool[i] = f
            end
            f.Visible = true
            f.BackgroundColor3 = col
            return f
        end

        local function renderDirtSelector(force)
            if not rowContainer.Parent then return end
            local now = os.clock()
            if not force and (now - lastDraw) < 0.35 then return end
            lastDraw = now
            Core.EnsureInit()
            local gt = H.gt
            if not gt or not gt.fg then return end
            local w, h = gt.w or 100, gt.h or 60
            local used = 0
            for y = 0, h - 1 do
                local x = 0
                while x < w do
                    local id = Core.GetFG(x, y)
                    local isSelected = Pabrik.State.selectedTiles[tileKey(x, y)] ~= nil
                    local plantable = Core.IsPlantable(x, y)
                    if isSelected or plantable or id ~= 0 then
                        local col
                        if isSelected then
                            col = Color3.fromRGB(168, 85, 247)
                        elseif plantable then
                            col = Color3.fromRGB(52, 211, 153)
                        else
                            local info = Core.GetItemInfo(id)
                            if id == 8 then col = Color3.fromRGB(48, 54, 66)
                            elseif info and info.lock then col = Color3.fromRGB(250, 204, 21)
                            elseif info and info.kind == "seed" then col = Color3.fromRGB(34, 197, 94)
                            else col = Color3.fromRGB(110, 80, 52) end
                        end
                        used += 1
                        local f = getBox(used, col)
                        f.Position = UDim2.fromScale(x / w, y / h)
                        f.Size = UDim2.fromScale(1 / w, 1 / h)
                        f.ZIndex = isSelected and 6 or (plantable and 4 or 2)
                    end
                    x += 1
                end
            end
            for i = used + 1, #pool do pool[i].Visible = false end
        end
        UIHooks.refreshMap = renderDirtSelector

        hitBtn.InputEnded:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
                local gt = H.gt
                if not gt then return end
                local ap, as = mapView.AbsolutePosition, mapView.AbsoluteSize
                if as.X <= 1 or as.Y <= 1 then return end
                local rx = clamp((inp.Position.X - ap.X) / as.X, 0, 0.999)
                local ry = clamp((inp.Position.Y - ap.Y) / as.Y, 0, 0.999)
                local tx = math.floor(rx * gt.w)
                local ty = math.floor(ry * gt.h)
                if Core.IsPlantable(tx, ty) or Pabrik.State.selectedTiles[tileKey(tx, ty)] then
                    Pabrik.ToggleTile(tx, ty)
                    renderDirtSelector(true)
                end
            end
        end)
        task.delay(0.4, function() renderDirtSelector(true) end)
    end)

    -- 4 & 5. FIFO WORLD QUEUE LISTS (DF: __DF_LIST_ANCHOR_KEY__ | CW: __CW_LIST_ANCHOR_KEY__)
    local function mountWorldQueueList(anchorKey, getListFn, removeFn, hookName)
        mountEmbeddedCanvas(anchorKey, 96, function(rowContainer)
            local scroll = Instance.new("ScrollingFrame", rowContainer)
            scroll.Size = UDim2.new(1, -8, 1, -8)
            scroll.Position = UDim2.fromOffset(4, 4)
            scroll.BackgroundColor3 = Color3.fromRGB(15, 20, 30)
            scroll.BorderSizePixel = 0
            scroll.ScrollBarThickness = 4
            scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
            scroll.CanvasSize = UDim2.new()
            Instance.new("UIListLayout", scroll).Padding = UDim.new(0, 3)

            local function refresh()
                for _, ch in ipairs(scroll:GetChildren()) do
                    if ch:IsA("Frame") then ch:Destroy() end
                end
                local list = getListFn() or {}
                for i, wName in ipairs(list) do
                    local row = Instance.new("Frame", scroll)
                    row.Size = UDim2.new(1, -6, 0, 22)
                    row.BackgroundColor3 = Color3.fromRGB(26, 34, 48)
                    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 4)
                    local lbl = Instance.new("TextLabel", row)
                    lbl.Size = UDim2.new(1, -30, 1, 0)
                    lbl.Position = UDim2.fromOffset(6, 0)
                    lbl.BackgroundTransparency = 1
                    lbl.Font = Enum.Font.Code
                    lbl.TextSize = 11
                    lbl.TextXAlignment = Enum.TextXAlignment.Left
                    lbl.TextColor3 = Color3.new(1, 1, 1)
                    lbl.Text = string.format("%d. %s", i, tostring(wName))
                    local del = Instance.new("TextButton", row)
                    del.Size = UDim2.fromOffset(22, 18)
                    del.Position = UDim2.new(1, -24, 0, 2)
                    del.BackgroundColor3 = Color3.fromRGB(185, 28, 28)
                    del.Font = Enum.Font.GothamBold
                    del.TextSize = 10
                    del.TextColor3 = Color3.new(1, 1, 1)
                    del.Text = "X"
                    Instance.new("UICorner", del).CornerRadius = UDim.new(0, 3)
                    del.MouseButton1Click:Connect(function() removeFn(i) end)
                end
            end
            UIHooks[hookName] = refresh
            refresh()
        end)
    end

    mountWorldQueueList("__DF_LIST_ANCHOR_KEY__",
        function() return DirtFarm.State.rotationWorlds end,
        function(i)
            table.remove(DirtFarm.State.rotationWorlds, i)
            DirtFarm.State.rotationText = table.concat(DirtFarm.State.rotationWorlds, ", ")
            if DirtFarm._syncEnvQueue then DirtFarm._syncEnvQueue(DirtFarm.State.rotationWorlds) end
            if UIHooks.refreshDfList then UIHooks.refreshDfList() end
        end,
        "refreshDfList"
    )
    mountWorldQueueList("__CW_LIST_ANCHOR_KEY__",
        function() return ClearWorld.State.worldList end,
        function(i) ClearWorld.RemoveWorldAt(i) end,
        "refreshCwList"
    )

    -- 6. SCROLLABLE SYSTEM JOIN & MOD LOG (__SYS_LOG_ANCHOR_KEY__)
    mountEmbeddedCanvas("__SYS_LOG_ANCHOR_KEY__", 120, function(rowContainer)
        local scroll = Instance.new("ScrollingFrame", rowContainer)
        scroll.Size = UDim2.new(1, -8, 1, -8)
        scroll.Position = UDim2.fromOffset(4, 4)
        scroll.BackgroundColor3 = Color3.fromRGB(12, 16, 24)
        scroll.BorderSizePixel = 0
        scroll.ScrollBarThickness = 4
        scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
        scroll.CanvasSize = UDim2.new()
        Instance.new("UIListLayout", scroll).Padding = UDim.new(0, 3)

        local function refreshSysLog()
            for _, ch in ipairs(scroll:GetChildren()) do
                if ch:IsA("TextLabel") then ch:Destroy() end
            end
            for _, item in ipairs(SystemModule.State.joinLogs) do
                local lbl = Instance.new("TextLabel", scroll)
                lbl.Size = UDim2.new(1, -6, 0, 18)
                lbl.BackgroundTransparency = 1
                lbl.Font = Enum.Font.Code
                lbl.TextSize = 10
                lbl.TextXAlignment = Enum.TextXAlignment.Left
                lbl.TextColor3 = item.isStaff and Color3.fromRGB(248, 113, 113) or Color3.fromRGB(148, 163, 184)
                lbl.Text = item.text
            end
        end
        UIHooks.refreshSysLog = refreshSysLog
        refreshSysLog()
    end)

    -- 7 & 8. RADIO GROUPS (SPAM 3-7s | DISCORD HOOK 1-5m)
    local function mountRadioGroup(anchorKey, values, labels, getCurrent, onPick)
        mountEmbeddedCanvas(anchorKey, 34, function(rowContainer)
            local btns = {}
            local function syncVis()
                local cur = getCurrent()
                for val, b in pairs(btns) do
                    local on = (val == cur)
                    b.BackgroundColor3 = on and Color3.fromRGB(56, 189, 248) or Color3.fromRGB(31, 35, 44)
                    b.TextColor3 = on and Color3.new(0, 0, 0) or Color3.new(1, 1, 1)
                end
            end
            local n = #values
            for i, val in ipairs(values) do
                local b = Instance.new("TextButton", rowContainer)
                b.Size = UDim2.new(1 / n, -4, 1, -6)
                b.Position = UDim2.new((i - 1) / n, 2, 0, 3)
                b.BorderSizePixel = 0
                b.Font = Enum.Font.GothamBold
                b.TextSize = 10
                b.Text = labels[i]
                Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
                btns[val] = b
                b.MouseButton1Click:Connect(function()
                    onPick(val)
                    syncVis()
                end)
            end
            syncVis()
        end)
    end

    mountRadioGroup("__SPAM_RADIO_ANCHOR_KEY__", { 3, 4, 5, 6, 7 }, { "3s", "4s", "5s", "6s", "7s" },
        function() return math.floor(Spam.State.delay or 5) end,
        function(v) Spam.State.delay = v end
    )
    mountRadioGroup("__DH_RADIO_ANCHOR_KEY__", { 60, 120, 180, 240, 300 }, { "1m", "2m", "3m", "4m", "5m" },
        function() return math.floor(DiscordHook.State.delay or 120) end,
        function(v) DiscordHook.State.delay = v end
    )

    task.defer(function()
        if getEnv().__SYT_SCRIPT_TOKEN ~= MY_SCRIPT_TOKEN then return end
        pcall(SYT_Logic.Init, false)
        pcall(UIHooks.scanResponsiveButtons)
        pcall(UIHooks.updateButtons)
        if UIHooks.refreshBP then pcall(UIHooks.refreshBP) end
        if UIHooks.refreshPabBP then pcall(UIHooks.refreshPabBP) end
        if UIHooks.refreshMap then pcall(UIHooks.refreshMap, true) end
    end)
end

-- Boot UI & Runtime Watcher wrapped in do-block to free root-chunk locals
;(function()
getEnv().__SYT_STOP_ALL = stopAllAutomationImpl
cleanupSYTGuiContainers(nil)
ensureSharedModulesReady(2.0)
LP = LP or Players.LocalPlayer
pcall(SYT_Logic.Init, false)
pcall(Visual.LoadFromEnv)
pcall(ProxyCommands.LoadEnv)
if ProxyCommands.P2P and ProxyCommands.P2P.LoadFromEnv then pcall(ProxyCommands.P2P.LoadFromEnv) end
pcall(Core.InstallUltimaxNamecallGuard)
pcall(ProxyCommands.Install)

do
    local okInit, initErr = safeInitSYTWindow(UIHooks.theme or "Minimalist Monochrome", UIHooks.scale or 1.0, false)
    if not okInit then
        warn("[SYT] Gagal init UI: " .. tostring(initErr))
    else
        local okB, buildErr = xpcall(buildSYTMenuFn, debug.traceback)
        if not okB then
            warn("[SYT] Build UI Error: " .. tostring(buildErr))
            emitNotify("SYT Menu Error", tostring(buildErr))
        end
        UIHooks.enforceSingleActiveFeatureTab()
        local envData = getEnv().__SYT_ENV_DATA or {}
        getEnv().__SYT_ENV_DATA = envData
        if envData.uiMinimized == nil then envData.uiMinimized = true end

        if UI and not UI._sytMinHooked then
            UI._sytMinHooked = true
            local origMin = rawget(UI, "MinimizeToIcon")
            local origRest = rawget(UI, "RestoreFromIcon")
            if type(origMin) == "function" then
                UI.MinimizeToIcon = function(self, ...)
                    local ed = getEnv().__SYT_ENV_DATA
                    if type(ed) == "table" then ed.uiMinimized = true end
                    return origMin(self, ...)
                end
            end
            if type(origRest) == "function" then
                UI.RestoreFromIcon = function(self, ...)
                    local ed = getEnv().__SYT_ENV_DATA
                    if type(ed) == "table" then ed.uiMinimized = false end
                    local r = origRest(self, ...)
                    task.defer(function()
                        if getEnv().__SYT_SCRIPT_TOKEN ~= MY_SCRIPT_TOKEN then return end
                        pcall(UIHooks.scanResponsiveButtons)
                        pcall(UIHooks.updateButtons)
                        if UIHooks.refreshBP then pcall(UIHooks.refreshBP) end
                        if UIHooks.refreshPabBP then pcall(UIHooks.refreshPabBP) end
                        if UIHooks.refreshPad5x5 then pcall(UIHooks.refreshPad5x5) end
                        if UIHooks.refreshMap then pcall(UIHooks.refreshMap, true) end
                    end)
                    return r
                end
            end
        end

        local sg = UIHooks.getActiveMenuGui()
        if sg and sg.Parent then
            sg.Enabled = true
            local sq = sg:FindFirstChild("R8DV_FloatingSquircle", true)
            if sq and sq:IsA("GuiObject") then
                sq.Size = UDim2.fromOffset(48, 48)
                local hasTxt = false
                for _, ch in ipairs(sq:GetDescendants()) do
                    if ch:IsA("TextLabel") then ch.Text = "SYT"; hasTxt = true end
                end
                if not hasTxt then
                    local tl = Instance.new("TextLabel", sq)
                    tl.Size = UDim2.fromScale(1, 1)
                    tl.BackgroundTransparency = 1
                    tl.Font = Enum.Font.GothamBold
                    tl.TextSize = 12
                    tl.TextColor3 = Color3.new(1, 1, 1)
                    tl.Text = "SYT"
                end
            end
            task.defer(function()
                if UI and type(UI.SyncNavCanvas) == "function" then pcall(UI.SyncNavCanvas) end
                if envData.uiMinimized and UI and type(UI.MinimizeToIcon) == "function" then
                    task.delay(0.15, function()
                        if getEnv().__SYT_SCRIPT_TOKEN ~= MY_SCRIPT_TOKEN then return end
                        pcall(UI.MinimizeToIcon, UI)
                    end)
                end
            end)
            pcall(UIHooks.scanResponsiveButtons)
            pcall(UIHooks.updateButtons)
            if UIHooks.refreshBP then pcall(UIHooks.refreshBP) end
            if UIHooks.refreshPabBP then pcall(UIHooks.refreshPabBP) end
            if UIHooks.refreshPad5x5 then pcall(UIHooks.refreshPad5x5) end
            if UIHooks.refreshMap then pcall(UIHooks.refreshMap, true) end
        else
            warn("[SYT] ScreenGui menu belum terpasang: " .. tostring(UIHooks.menuIsReady()))
        end
    end
end

-- Sync Visual Env Spoof + Broadcast Hello ke sesama user SYT saat execute
task.spawn(function()
    local dl = os.clock() + 8
    while os.clock() < dl do
        if getEnv().__SYT_SCRIPT_TOKEN ~= MY_SCRIPT_TOKEN then return end
        pcall(SYT_Logic.Init, false)
        if H.gt and (H.gt.name or "") ~= "" then break end
        task.wait(0.35)
    end
    if getEnv().__SYT_SCRIPT_TOKEN ~= MY_SCRIPT_TOKEN then return end
    Visual.EnsureOutfitPersistenceHooks()
    if Visual.HasActiveSpoof() or (Visual.State.customName or "") ~= "" or (Visual.State.role or "none") ~= "none" or next(Visual.State.fakeWorn or {}) ~= nil then
        H._stripWingDoubleJump = (next(Visual.State.fakeWorn or {}) ~= nil)
        pcall(Visual.Apply)
    end
    if ProxyCommands.P2P then
        if ProxyCommands.P2P.SyncVisiblePeers then pcall(ProxyCommands.P2P.SyncVisiblePeers) end
        if ProxyCommands.P2P.SendHello then pcall(ProxyCommands.P2P.SendHello) end
    end
end)

-- Auto-Resume dari Local Memory env (__SYT_ENV_DATA.rotSession + queue DF/CW) & AutoLeveling (level < 10) tanpa spam warp
task.spawn(function()
    local ed = getEnv().__SYT_ENV_DATA
    if type(ed) == "table" then
        if type(ed.dfQueue) == "table" and #ed.dfQueue > 0 then
            local q = {}
            for i, w in ipairs(ed.dfQueue) do q[i] = w end
            DirtFarm.State.rotationWorlds = q
            DirtFarm.State.rotationText = table.concat(q, ", ")
            if UIHooks.refreshDfList then pcall(UIHooks.refreshDfList) end
        end
        if type(ed.cwQueue) == "table" and #ed.cwQueue > 0 then
            local q = {}
            for i, w in ipairs(ed.cwQueue) do q[i] = w end
            ClearWorld.State.worldList = q
            if UIHooks.refreshCwList then pcall(UIHooks.refreshCwList) end
        end
    end

    local rot = type(ed) == "table" and ed.rotSession or nil
    local savedAutoLvl = safeReadStorage("syt_autolvl.dat")
    local hasRot = (type(rot) == "table" and rot.active == true and (type(rot.updatedAt) ~= "number" or (os.clock() - rot.updatedAt) <= 300))
    local hasAutoFile = (not hasRot) and (type(savedAutoLvl) == "string" and string.sub(savedAutoLvl, 1, 3) == "ON|")
    if not hasRot and not hasAutoFile then return end

    local dl = os.clock() + 12
    while os.clock() < dl do
        if getEnv().__SYT_SCRIPT_TOKEN ~= MY_SCRIPT_TOKEN then return end
        pcall(SYT_Logic.Init, false)
        if H.gt and (H.gt.name or "") ~= "" then break end
        task.wait(0.35)
    end
    if getEnv().__SYT_SCRIPT_TOKEN ~= MY_SCRIPT_TOKEN then return end
    if not H.gt or (H.gt.name or "") == "" then return end

    if hasRot then
        if rot.mode == "DirtFarm" then
            if type(rot.worlds) == "table" and #rot.worlds > 0 then
                local q = {}
                for i, w in ipairs(rot.worlds) do q[i] = w end
                DirtFarm.State.rotationWorlds = q
                DirtFarm.State.rotationText = table.concat(q, ", ")
                if UIHooks.refreshDfList then pcall(UIHooks.refreshDfList) end
            end
            DirtFarm.Start()
            return
        elseif rot.mode == "ClearWorld" then
            if type(rot.worlds) == "table" and #rot.worlds > 0 then
                local q = {}
                for i, w in ipairs(rot.worlds) do q[i] = w end
                ClearWorld.State.worldList = q
                if UIHooks.refreshCwList then pcall(UIHooks.refreshCwList) end
            end
            ClearWorld.Start({ halfWorld = rot.halfWorld == true, noCollect = rot.noCollect == true })
            return
        elseif rot.mode == "AutoLeveling" then
            if AutoLeveling.GetLevel() < AutoLeveling.State.targetLevel then
                if type(rot.targetWorld) == "string" and rot.targetWorld ~= "" then
                    AutoLeveling.State.targetWorld = rot.targetWorld
                end
                if type(rot.completedWorlds) == "table" then
                    AutoLeveling.State.completedWorlds = rot.completedWorlds
                end
                if UI then pcall(UI.SetValue, UI, "SysAutoLevelToggle", true, true) end
                AutoLeveling.Start()
                return
            else
                ed.rotSession = nil
                safeWriteStorage("syt_autolvl.dat", "")
                return
            end
        end
    end

    if hasAutoFile then
        if AutoLeveling.GetLevel() < AutoLeveling.State.targetLevel then
            local savedW = string.sub(savedAutoLvl, 4)
            if savedW ~= "" then AutoLeveling.State.targetWorld = savedW end
            if UI then pcall(UI.SetValue, UI, "SysAutoLevelToggle", true, true) end
            AutoLeveling.Start()
        else
            safeWriteStorage("syt_autolvl.dat", "")
        end
    end
end)

-- Runtime Watcher: Live Sync, World Change, Player/Mod Detection, Outfit Anti-Drop Self-Heal & Low-Heat Mode
local function computeInvHash()
    local slots = Core.GetBackpackSlots()
    if #slots == 0 then return "" end
    local sum, cnt = 0, 0
    for i, s in ipairs(slots) do
        cnt += 1
        sum += ((s.id or 0) * 13 + (s.n or 0)) * (i % 7 + 1)
    end
    return tostring(cnt) .. ":" .. tostring(sum)
end

local lastFastTick, lastSlowTick, lastInvHash = 0, 0, ""
if H.watcherConn then H.watcherConn:Disconnect() end
H.watcherConn = RunService.Heartbeat:Connect(function()
    if getEnv().__SYT_SCRIPT_TOKEN ~= MY_SCRIPT_TOKEN then
        if H.watcherConn then H.watcherConn:Disconnect(); H.watcherConn = nil end
        return
    end
    local now = os.clock()
    if (now - lastFastTick) < 0.25 then return end
    lastFastTick = now
    if Misc.State.fastRoulette then Core.SkipWheelAnimations() end
    if not H.chatOnCmdHookedTbl or rawget(H.chatOnCmdHookedTbl, "onCommand") ~= H._sytOnCmdWrapper then
        pcall(ProxyCommands.Install)
    end
    if Visual and Visual.State and type(Visual.State.fakeWorn) == "table" and next(Visual.State.fakeWorn) ~= nil and type(H.wornTbl) == "table" then
        Visual.EnsureOutfitPersistenceHooks()
        local drifted = false
        for sl, fv in pairs(Visual.State.fakeWorn) do
            if (fv > 0 and H.wornTbl[sl] ~= fv) or (fv == 0 and H.wornTbl[sl] ~= nil) then
                drifted = true
                break
            end
        end
        if drifted and Visual.ReapplyOutfitLocally then
            pcall(Visual.ReapplyOutfitLocally)
        end
    end

    local uiVisible = (UI and not UI.IsMinimized and UI.MainWindow and UI.MainWindow.Parent and UI.MainWindow.Visible) == true
    local gt = H.gt
    local curWorld = gt and cleanWorldName(gt.name) or ""
    local intentionalWorldSwitch = DirtFarm.State.switchingWorld
        or PNB.State.switchingWorld
        or ClearWorld.State.switchingWorld
        or AutoLeveling.State.switchingWorld
        or (now < (H.intentionalSwitchUntil or 0))

    if curWorld ~= Visual.State.lastWorldName then
        local prev = Visual.State.lastWorldName
        Visual.State.lastWorldName = curWorld
        if prev ~= "" and not intentionalWorldSwitch then
            if Misc and Misc.State and Misc.State.noClip then
                Misc.State.noClip = false
                Misc.State.noClipAnchor = nil
                pcall(RunService.UnbindFromRenderStep, RunService, "SYT_NoClipStep")
                if UI then pcall(UI.SetValue, UI, "MiscNoClipToggle", false, true) end
            end
            stopAllAutomationImpl("Pindah world -> Otomasi OFF")
        end
        if curWorld ~= "" then
            task.delay(0.15, function()
                if getEnv().__SYT_SCRIPT_TOKEN ~= MY_SCRIPT_TOKEN then return end
                pcall(SYT_Logic.Init, true)
                pcall(Core.InstallAntiBackGuard)
                pcall(hookIncomingNetGuard)
                pcall(ProxyCommands.Install)
                if Visual.State.lockNames or Visual.HasActiveSpoof() or (Visual.State.customName or "") ~= "" or (Visual.State.role or "none") ~= "none" then
                    pcall(Visual.OnWorldChanged)
                end
                if ProxyCommands.P2P then
                    if ProxyCommands.P2P.SyncVisiblePeers then pcall(ProxyCommands.P2P.SyncVisiblePeers) end
                    if ProxyCommands.P2P.SendHello then pcall(ProxyCommands.P2P.SendHello) end
                end
                if Misc.State.zoom25x then pcall(Misc.SetZoom25x, true) end
                if UI and not UI.IsMinimized and UI.MainWindow and UI.MainWindow.Visible then
                    if UIHooks.refreshBP then pcall(UIHooks.refreshBP) end
                    if UIHooks.refreshPabBP then pcall(UIHooks.refreshPabBP) end
                    if UIHooks.refreshMap then pcall(UIHooks.refreshMap, true) end
                    if UIHooks.refreshPad5x5 then pcall(UIHooks.refreshPad5x5) end
                end
            end)
        end
    end

    if gt and (gt.name or "") ~= "" then
        local peerCnt = (ProxyCommands.P2P and ProxyCommands.P2P.GetPeerCount) and ProxyCommands.P2P.GetPeerCount() or 0
        ProxyCommands.State.p2pLive = (ProxyCommands.State.p2pEnabled and (#Core.GetInWorldPlayers(false) > 0 or peerCnt > 0)) == true
        pcall(SystemModule.CheckWorldEntrants)
        if uiVisible then
            local pos = Core.ReadPos()
            if UIHooks.sidebarNameLbl and UIHooks.sidebarNameLbl.Parent then
                UIHooks.sidebarNameLbl.Text = Core.GetInGameName(LP, true)
            end
            if UIHooks.sidebarSubLbl and UIHooks.sidebarSubLbl.Parent then
                UIHooks.sidebarSubLbl.Text = string.format("%s (%d,%d)", tostring(gt.name), pos.sx, pos.sy)
            end
        end
    else
        ProxyCommands.State.p2pLive = false
    end

    if (now - lastSlowTick) >= 1.2 then
        lastSlowTick = now
        if not H.gt or not H.ItemDB or not H.Net or not H.inv then pcall(SYT_Logic.Init) end
        pcall(ProxyCommands.Install)
        if ProxyCommands.State.p2pEnabled and ProxyCommands.P2P and ProxyCommands.P2P.SyncVisiblePeers then
            pcall(ProxyCommands.P2P.SyncVisiblePeers)
        end
        if uiVisible then
            local bMap = UIHooks.buttonMap
            if not bMap["[PNB]"] or not bMap["[PABRIK]"] or not bMap["[DF]"] or not bMap["[CW]"] or not bMap["[MOVE]"] or not bMap["[SPAM]"] then
                pcall(UIHooks.scanResponsiveButtons)
                pcall(UIHooks.updateButtons)
            end
            local invHash = computeInvHash()
            if invHash ~= lastInvHash then
                lastInvHash = invHash
                if UIHooks.refreshBP then UIHooks.refreshBP() end
                if UIHooks.refreshPabBP then UIHooks.refreshPabBP() end
            end
            if UIHooks.refreshMap then UIHooks.refreshMap(false) end
            if UI then
                local pCnt = (ProxyCommands.P2P and ProxyCommands.P2P.GetPeerCount) and ProxyCommands.P2P.GetPeerCount() or 0
                local p2pTxt = not ProxyCommands.State.p2pEnabled and "OFF (/p2p off)"
                    or (pCnt > 0 and string.format("ON (%d Peer Sync)", pCnt)
                    or (ProxyCommands.State.p2pLive and "ON (Multi-Player)" or "STANDBY (Alone)"))
                pcall(UI.SetValue, UI, "ProxyP2pStatus", p2pTxt)
                local bj = ProxyCommands.State.bj
                local bjTxt = string.format("B1:%s B2:%s T1:%s T2:%s | TAX:%d%%",
                    bj.b1 and (bj.b1.x .. "," .. bj.b1.y) or "-",
                    bj.b2 and (bj.b2.x .. "," .. bj.b2.y) or "-",
                    bj.t1 and (bj.t1.x .. "," .. bj.t1.y) or "-",
                    bj.t2 and (bj.t2.x .. "," .. bj.t2.y) or "-",
                    bj.tax or 0)
                pcall(UI.SetValue, UI, "ProxyBjStatus", bjTxt)
            end
        end
    end
end)
getEnv().__SYT_WATCHER_CONN = H.watcherConn
end)()
getEnv().SYT_Logic = SYT_Logic
return SYT_Logic
