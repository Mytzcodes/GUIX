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

-- ═══════════════════════════════════════════════════════════════════════════
-- 1. LOAD R&8_DV IMGUI FRAMEWORK (INSTANT BOOT + CLEAN MULTI-ROOT MANAGEMENT)
-- ═══════════════════════════════════════════════════════════════════════════
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
    end
    if not forceReload and type(cachedR8Loader) == "function" then
        return cachedR8Loader()
    end
    if not forceReload and type(env) == "table" then
        if type(env.__SYT_R8_LOADER_V4) == "function" then
            cachedR8Loader = env.__SYT_R8_LOADER_V4
            if type(env.__SYT_R8_SOURCE_V4) == "string" then
                cachedR8Source = env.__SYT_R8_SOURCE_V4
            end
            return cachedR8Loader()
        end
        if type(env.__SYT_R8_SOURCE_V4) == "string" and #env.__SYT_R8_SOURCE_V4 > 128 then
            cachedR8Source = env.__SYT_R8_SOURCE_V4
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
            env.__SYT_R8_SOURCE_V4 = cachedR8Source
        end
    end
    local loader, loadErr = loadstring(cachedR8Source)
    assert(type(loader) == "function", "[SYT] Compile error r&8_dv: " .. tostring(loadErr))
    cachedR8Loader = loader
    if type(env) == "table" then
        env.__SYT_R8_LOADER_V4 = loader
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
        end
        task.wait(0.1)
    end
    warn("[SYT] Gagal init window: " .. tostring(lastErr))
    return false, tostring(lastErr or "Init window gagal")
end

-- ═══════════════════════════════════════════════════════════════════════════
-- 2. SERVICES, EXECUTOR HELPERS & SHARED TABLES
-- ═══════════════════════════════════════════════════════════════════════════
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
    for _, k in ipairs({ "__SYT_WATCHER_CONN", "__SYT_FLY_CONN", "__SYT_ROULETTE_CONN" }) do
        if env[k] then
            pcall(function() env[k]:Disconnect() end)
            env[k] = nil
        end
    end
    if env.__SYT_ACTIVE_UI then
        pcall(function() env.__SYT_ACTIVE_UI:Destroy() end)
        env.__SYT_ACTIVE_UI = nil
    end
end

local function getSafeHui()
    if type(gethui) == "function" then
        local ok, h = pcall(gethui)
        if ok and typeof(h) == "Instance" then return h end
    end
    return nil
end

local function getAllGuiRoots()
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

-- ═══════════════════════════════════════════════════════════════════════════
-- 3. GAME DISCOVERY + IN-GAME ACCOUNT & ITEM ICON ENGINE
-- ═══════════════════════════════════════════════════════════════════════════
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

    if ms and ms.noClip and ms.noClipAnchor and not fromBot and not forceBypass then
        local a = ms.noClipAnchor
        return { x = a.x, y = a.y, vx = 0, vy = 0, flags = 2, t = ts }
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

-- ═══════════════════════════════════════════════════════════════════════════
-- 4. [GETC SKIPER] RATE LIMITER, RANGE GUARD & ITEM-UPDATE SKIPPER
-- ═══════════════════════════════════════════════════════════════════════════
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

-- ═══════════════════════════════════════════════════════════════════════════
-- 5. REUSABLE RAW PACKETS (PUNCH, HIT DAMAGE, WALK/TP, PLACE, CHAT, COLLECT)
-- ═══════════════════════════════════════════════════════════════════════════
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
    local delay = tonumber(opts.hitDelay)
    if delay == nil then delay = 0.165 end
    delay = clamp(delay, 0.08, 0.45)

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
        local waitEnd = os.clock() + (tonumber(opts.verifyTimeout) or 0.115)
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
            task.wait(0.02)
        end
        if not reverted and Core.GetLayerTile(tx, py, targetLayer) == 0 then
            return true, "verified_broken"
        end
        -- Blok belum hancur penuh di server: terus punch lagi sampai hancur
        local retryDelay = math.max(delay, 0.145)
        if not waitPacketInterval(retryDelay, true, "act", cont) then return false, "cancelled" end
    end
    local okEnd = Core.GetLayerTile(tx, py, targetLayer) == 0
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

-- ═══════════════════════════════════════════════════════════════════════════
-- 6. V1 [MISC], V2 [PNB], V3 [AUTO PABRIK], V4 [VISUAL], V5 [SPAM]
-- ═══════════════════════════════════════════════════════════════════════════
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
    local function trimStr(x) return (tostring(x or "")):match("^%s*(.-)%s*$") end
    local s = trimStr(raw)
    if s == "" or s == "Tidak ada player lain" then return "" end
    local bare = string.match(s, "^([^%(%[]+)")
    return trimStr(bare or s)
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

            if Core.CountItem(S.blockId) > 0 then
                setPabrikStatus(string.format("TP x Walk -> BreakPos (%d)", Core.CountItem(S.blockId)))
                Packets.MoveHybrid(S.breakPos.x, S.breakPos.y, 0, alive)
                local offs = computePabrikBreakOffsets(S.breakTileCount)
                local pabPlaceGap = math.max(H.adaptivePlaceGap or 0.155, tonumber(S.placeDelay) or 0.14)
                while alive() and Core.CountItem(S.blockId) > 0 do
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
                    if Core.CountItem(S.blockId) > 0 or Core.CountItem(S.seedId) <= 0 then break end
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

-- [DIRT FARM] Pure Manual Walk + Jump + Break & Replace Non-Dirt -> Format Dirt Farm + Rotation World (No Fly / No TP)
local DirtFarm = {
    State = {
        running = false, sessionToken = 0, thread = nil, status = "Idle",
        breakDelay = 0.14, placeDelay = 0.12, collectDelay = 0.04,
        oneHit = false, showHand = true, autoCollect = true, centerGap = true,
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

local function parseDfRotationList(rawText)
    local out = {}
    local seen = {}
    for token in string.gmatch(tostring(rawText or ""), "([^,\n;|]+)") do
        local w = string.upper((token):match("^%s*(.-)%s*$"))
        if w ~= "" and not seen[w] then
            seen[w] = true
            out[#out + 1] = w
        end
    end
    return out
end

function DirtFarm.SetRotationWorlds(rawText)
    DirtFarm.State.rotationText = tostring(rawText or "")
    DirtFarm.State.rotationWorlds = parseDfRotationList(DirtFarm.State.rotationText)
    return DirtFarm.State.rotationWorlds
end

local function resolveDirtId()
    local info2 = Core.GetItemInfo(2)
    if info2 and string.find(string.lower(info2.name or ""), "dirt") then return 2 end
    local found = Core.FindItemByName("dirt")
    return (found and found.id) or 2
end

local function buildDfBlueprint(gt)
    local w, h = gt.w or 100, gt.h or 60
    local doorX, doorY = gt.spawn and math.floor(gt.spawn.X) or math.floor(w / 2), gt.spawn and math.floor(gt.spawn.Y) or 23
    local foundDoor = false
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local id = Core.GetFG(x, y)
            if id == 6 then
                doorX, doorY, foundDoor = x, y, true
                break
            elseif id > 0 then
                local info = Core.GetItemInfo(id)
                if info and (info.door or info.entrance) then
                    doorX, doorY, foundDoor = x, y, true
                    break
                end
            end
        end
        if foundDoor then break end
    end

    local bedrockTopY = h - 6
    for y = h - 1, math.max(doorY + 4, 0), -1 do
        local bCount = 0
        for x = 0, w - 1 do
            local id = Core.GetFG(x, y)
            local info = id > 0 and Core.GetItemInfo(id) or nil
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
        if y < topY or y > maxWorkY then return nil end
        local curId = Core.GetFG(x, y)
        if curId == 6 or curId == 8 or Core.IsProtectedTile(curId) or not Core.CanEditTile(x, y) then
            return nil
        end
        -- 2 blok ujung kiri & kanan selalu dibolongi lurus (air)
        if x <= 1 or x >= w - 2 then return 0 end
        -- Bolong tengah (2 kolom) agar mudah naik turun saat atas & bawah selesai
        if DirtFarm.State.centerGap and (x == midX - 1 or x == midX) then return 0 end
        -- Baris tepat di White Door & paling bawah tepat di atas bedrock tetap terbuka lurus
        if y == doorY or y == maxWorkY then return 0 end

        if y >= groundY then
            -- Bagian Bawah: kelipatan 2 baris dari groundY = Dirt, selang-seling 1 baris Air lurus
            return ((y - groundY) % 2 == 0) and dirtId or 0
        else
            -- Bagian Atas (y < doorY): kelipatan 2 ke atas = Place Dirt, selang-seling Air
            return ((groundY - y) % 2 == 0) and dirtId or 0
        end
    end

    return {
        w = w, h = h, topY = topY, doorX = doorX, doorY = doorY,
        groundY = groundY, maxWorkY = maxWorkY, midX = midX, dirtId = dirtId,
        desiredAt = desiredAt,
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

    local function dfQuickCollectNear(aliveFn, filterId)
        local S = DirtFarm.State
        if not S.autoCollect and not filterId then return 0 end
        local gt = H.gt
        if not gt or type(gt.dropList) ~= "function" then return 0 end
        local okD, drops = pcall(gt.dropList)
        if not okD or type(drops) ~= "table" or #drops == 0 then return 0 end
        local pos = Core.ReadPos()
        local now = os.clock()
        local hasReadyNear = false
        for i = 1, #drops do
            local d = drops[i]
            if type(d) == "table" and d.uid and d.x and d.y and (d.n or 0) > 0 and (d.readyAt or 0) <= now then
                if not filterId or d.id == filterId then
                    local distBody = math.max(math.abs(d.x - pos.x), math.abs(d.y - (pos.y - 0.5)))
                    if distBody <= 4.55 and (d.id == 112 or Core.GetItemRoom(d.id) > 0) then
                        hasReadyNear = true
                        break
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
            return res and res.totalTaken or 0
        end
        return 0
    end

    local function dfBreakList(obsList, aliveFn)
        if not obsList or #obsList == 0 then return true end
        Core.ClearManualInput()
        local S = DirtFarm.State
        local dfHitGap = math.max(0.08, tonumber(S.breakDelay) or 0.14)
        local posNow = Core.ReadPos()
        local valid = {}
        for _, bt in ipairs(obsList) do
            local tx, ty = bt.tx or bt.x, bt.ty or bt.y
            local cid = Core.GetFG(tx, ty)
            if cid ~= 0 and not Core.IsProtectedTile(cid) and Core.CanEditTile(tx, ty) and Core.IsInActionReach(tx, ty, "break", posNow) then
                valid[#valid + 1] = { tx = tx, ty = ty, layer = 1 }
            end
        end
        if #valid == 0 then
            for _, bt in ipairs(obsList) do
                local tx, ty = bt.tx or bt.x, bt.ty or bt.y
                if Core.GetFG(tx, ty) ~= 0 then return false end
            end
            return true
        end

        Packets.BreakBlocksParallel(valid, {
            threads = 3, layer = 1, oneHit = S.oneHit,
            hitDelay = dfHitGap, showHand = S.showHand,
            showVisual = true, noLocalMirror = false,
            verifyBreak = true, autoRange = false, shouldContinue = aliveFn,
        })
        for _ = 1, 3 do
            if type(aliveFn) == "function" and not aliveFn() then break end
            local rem = {}
            for _, bt in ipairs(valid) do
                local cid = Core.GetFG(bt.tx, bt.ty)
                if cid ~= 0 and not Core.IsProtectedTile(cid) then
                    rem[#rem + 1] = bt
                end
            end
            if #rem == 0 then break end
            Packets.BreakVerified(rem, {
                threads = 3, layer = 1, oneHit = false,
                hitDelay = math.max(0.10, dfHitGap), showHand = S.showHand,
                showVisual = true, noLocalMirror = true,
                autoRange = false, shouldContinue = aliveFn,
            })
        end
        for _, bt in ipairs(valid) do
            if Core.GetFG(bt.tx, bt.ty) ~= 0 then
                return false
            end
        end
        return true
    end

    local function dfSettleGrounded(aliveFn, maxWait)
        Core.ClearManualInput()
        local deadline = os.clock() + (maxWait or 0.45)
        while os.clock() < deadline do
            if type(aliveFn) == "function" and not aliveFn() then return false end
            local p = Core.ReadPos()
            if p.grounded or math.abs(p.vy) < 0.05 then return true end
            task.wait(0.016)
        end
        return false
    end

    local function dfStepWalkToX(goalX, expectedFloorY, maxTime, aliveFn, stopIfFn, keepMovingOnPass)
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
            if math.abs(p.x - lastX) > 0.04 then
                lastX = p.x
                lastProgT = os.clock()
            elseif (os.clock() - lastProgT) > 0.42 then
                local w = H.gt and H.gt.w or 100
                local frontTx = clamp(math.floor(p.x + dir * 0.72), 0, w - 1)
                local frontTy = expectedFloorY and (expectedFloorY - 1) or math.floor(p.y - 0.01)
                local blk, brk = dfIsBreakableBlocking(frontTx, frontTy)
                if blk and brk and stallBreaks < 4 and type(dfBreakList) == "function" then
                    stallBreaks += 1
                    Core.ClearManualInput()
                    local toBrk = { { tx = frontTx, ty = frontTy, layer = 1 } }
                    local blkTop, brkTop = dfIsBreakableBlocking(frontTx, frontTy - 1)
                    if blkTop and brkTop and expectedFloorY == nil then
                        toBrk[#toBrk + 1] = { tx = frontTx, ty = frontTy - 1, layer = 1 }
                    end
                    dfBreakList(toBrk, aliveFn)
                    lastProgT = os.clock()
                    deadline = deadline + 0.55
                elseif (os.clock() - lastProgT) > 0.58 then
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
            local p = Core.ReadPos()
            local now = os.clock()
            local elapsed = now - t0
            if not p.grounded or p.vy < -1.0 then
                jumped = true
            end

            if jumped and p.grounded and elapsed > 0.14 then
                if math.abs(p.y - destFloorY) <= 0.20 and math.abs(p.x - targetCenterX) <= 0.58 then
                    Core.ClearManualInput()
                    if math.abs(p.x - targetCenterX) > 0.15 then
                        dfStepWalkToX(targetCenterX, destFloorY, 0.45, aliveFn)
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
                    if elapsed < 0.12 and p.y > destFloorY - 0.30 and (p.vy <= 0 or not jumped) then
                        wantJump = true
                    elseif elapsed >= 0.05 then
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
            local p = Core.ReadPos()
            if p.grounded and math.abs(p.y - destFloorY) <= 0.20 and math.abs(p.x - targetCenterX) <= 0.65 then
                Core.ClearManualInput()
                if math.abs(p.x - targetCenterX) > 0.15 then
                    dfStepWalkToX(targetCenterX, destFloorY, 0.45, aliveFn)
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
            if not dfBreakList({ { tx = tx, ty = ty, layer = 1 } }, aliveFn) then
                return false, "break_failed"
            end
        end
        if Core.CountItem(dirtId) <= 0 then
            dfQuickCollectNear(aliveFn, dirtId)
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
                dfStepWalkToX(safeX, pFloor, 0.6, aliveFn)
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
            retries = 2, placeGap = math.max(H.adaptivePlaceGap or 0.155, tonumber(S.placeDelay) or 0.12),
            shouldContinue = aliveFn,
        })
        return okP, msgP
    end

    local function dfCleanTilesInReach(coords, aliveFn)
        local pos = Core.ReadPos()
        local list = {}
        for _, c in ipairs(coords) do
            local cx, cy = c[1], c[2]
            if cx >= 0 and cy >= 0 and H.gt and cx < H.gt.w and cy < H.gt.h then
                local cid = Core.GetFG(cx, cy)
                if cid ~= 0 and not Core.IsProtectedTile(cid) and Core.CanEditTile(cx, cy) and Core.IsInActionReach(cx, cy, "break", pos) then
                    list[#list + 1] = { tx = cx, ty = cy, layer = 1 }
                end
            end
        end
        if #list == 0 then return true end
        local allOk = true
        local idx = 1
        while idx <= #list do
            if type(aliveFn) == "function" and not aliveFn() then return false end
            local batch = {}
            for k = idx, math.min(#list, idx + 2) do
                batch[#batch + 1] = list[k]
            end
            if not dfBreakList(batch, aliveFn) then
                allOk = false
            end
            idx += 3
        end
        return allOk
    end

    local function dfEnsureTemporaryStep(tx, ty, dirtId, aliveFn)
        local cid = Core.GetFG(tx, ty)
        if dfIsStandable(tx, ty) and not dfIsHazard(cid > 0 and Core.GetItemInfo(cid) or nil) then
            return true
        end
        local okP, errP = dfPlaceDirtSafe(tx, ty, dirtId, aliveFn)
        return okP, errP
    end

    local function dfClimbShaftToFloorY(bp, colA, colB, targetFloorY, dirtId, aliveFn, preferExitX)
        local S = DirtFarm.State
        local dirtInfo = Core.GetItemInfo(dirtId)
        for _ = 1, 80 do
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
                dfCleanTilesInReach({ { enterCol, curFloorY - 1 }, { enterCol, curFloorY - 2 } }, aliveFn)
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
            dfCleanTilesInReach(clearReq, aliveFn)

            local stepFloor = nextFloorY
            local cidStep = Core.GetFG(otherCol, stepFloor)
            if cidStep == 0 or not dfIsStandable(otherCol, stepFloor) or dfIsHazard(cidStep > 0 and Core.GetItemInfo(cidStep) or nil) then
                if not dfCanActFromStand(otherCol, stepFloor, "build", dirtInfo, pos) then
                    dfStepWalkToX(standCol + 0.5, curFloorY, 0.5, aliveFn)
                end
                local okP, errP = dfPlaceDirtSafe(otherCol, stepFloor, dirtId, aliveFn)
                if not okP then
                    Core.ClearManualInput()
                    return false, errP or "no_dirt_climb"
                end
            end

            local okJ = dfManualJumpTo(otherCol, stepFloor, aliveFn)
            if not okJ then
                Core.ClearManualInput()
                return false, "climb_jump_failed"
            end

            -- Hancurkan blok pijakan sementara di belakang hanya jika termasuk kolom shaft (desiredAt == 0)
            local cleanup = {}
            if bp.desiredAt(standCol, curFloorY) == 0 and Core.GetFG(standCol, curFloorY) ~= 0 then
                cleanup[#cleanup + 1] = { standCol, curFloorY }
            end
            if bp.desiredAt(standCol, curFloorY + 1) == 0 and Core.GetFG(standCol, curFloorY + 1) ~= 0 then
                cleanup[#cleanup + 1] = { standCol, curFloorY + 1 }
            end
            if #cleanup > 0 then
                dfCleanTilesInReach(cleanup, aliveFn)
                dfQuickCollectNear(aliveFn, dirtId)
            end
        end
        Core.ClearManualInput()
        return false, "climb_limit"
    end

    local function dfTransitionToLowerRow(bp, shaftInner, shaftOuter, edgeX, fromCorY, nextCorY, dirtId, aliveFn)
        local fromFloorY = fromCorY + 1
        local nextFloorY = nextCorY + 1
        local clearPre = {
            { shaftInner, fromCorY }, { shaftOuter, fromCorY },
            { shaftInner, fromCorY + 1 }, { shaftOuter, fromCorY + 1 },
            { shaftOuter, nextCorY }, { edgeX, nextCorY },
        }
        if nextFloorY > bp.maxWorkY then
            clearPre[#clearPre + 1] = { shaftInner, nextCorY }
        end
        dfCleanTilesInReach(clearPre, aliveFn)

        -- Kasus Bedrock langsung: jatuh langsung ke Bedrock tanpa perlu step lantai sementara
        if nextFloorY > bp.maxWorkY then
            local okD = dfDropIntoCol(shaftInner, nextFloorY, aliveFn, 2.2)
            if not okD then return false, "bedrock_drop_failed" end
            return dfStepWalkToX(edgeX + 0.5, nextFloorY, 1.0, aliveFn)
        end

        -- Buat landing step sementara 1 tile di bawah agar tidak nyangkut atap koridor 1-tile
        local okStep1, errS1 = dfEnsureTemporaryStep(shaftInner, nextCorY, dirtId, aliveFn)
        if not okStep1 then return false, errS1 or "drop_step1_failed" end

        local okD1 = dfDropIntoCol(shaftInner, nextCorY, aliveFn, 1.8)
        if not okD1 then return false, "drop_step1_miss" end

        dfCleanTilesInReach({ { shaftOuter, nextCorY }, { edgeX, nextCorY } }, aliveFn)
        local okStep2, errS2 = dfEnsureTemporaryStep(shaftOuter, nextFloorY, dirtId, aliveFn)
        if not okStep2 then return false, errS2 or "drop_step2_failed" end

        local okD2 = dfDropIntoCol(shaftOuter, nextFloorY, aliveFn, 1.8)
        if not okD2 then return false, "drop_step2_miss" end

        dfCleanTilesInReach({ { shaftInner, nextCorY }, { edgeX, nextCorY } }, aliveFn)
        if bp.desiredAt(edgeX, nextFloorY) == dirtId and Core.GetFG(edgeX, nextFloorY) ~= dirtId then
            local okE, errE = dfPlaceDirtSafe(edgeX, nextFloorY, dirtId, aliveFn)
            if not okE and not dfIsStandable(edgeX, nextFloorY) then
                return false, errE or "edge_floor_failed"
            end
        end
        local okIn, errIn = dfEnsureTemporaryStep(shaftInner, nextFloorY, dirtId, aliveFn)
        if not okIn then return false, errIn or "drop_bridge_failed" end

        local okWalk = dfStepWalkToX(edgeX + 0.5, nextFloorY, 1.4, aliveFn)
        if not okWalk then return false, "enter_row_failed" end

        local cleanShaft = {}
        if bp.desiredAt(shaftInner, nextFloorY) == 0 then cleanShaft[#cleanShaft + 1] = { shaftInner, nextFloorY } end
        if bp.desiredAt(shaftOuter, nextFloorY) == 0 then cleanShaft[#cleanShaft + 1] = { shaftOuter, nextFloorY } end
        if #cleanShaft > 0 then
            dfCleanTilesInReach(cleanShaft, aliveFn)
            dfQuickCollectNear(aliveFn, dirtId)
        end
        return true, "entered"
    end

    local function dfFindManualPath(sx, sy, targetX, targetY, actionKind, itemInfo)
        local gt = H.gt
        if not gt then return nil end
        local w, h = gt.w or 100, gt.h or 60
        sx, sy = clamp(math.floor(sx), 0, w - 1), clamp(math.floor(sy), 0, h - 1)
        targetX, targetY = clamp(math.floor(targetX), 0, w - 1), clamp(math.floor(targetY), 0, h - 1)

        if not dfIsBlocking(sx, sy) and dfIsStandable(sx, sy + 1) and dfCanActFromStand(targetX, targetY, actionKind, itemInfo, { x = sx + 0.5, y = sy + 1 }) then
            return {}
        end

        local heapKeys, heapF, heapSz = {}, {}, 0
        local function heapPush(k, f)
            heapSz += 1
            local i = heapSz
            while i > 1 do
                local p = math.floor(i / 2)
                if heapF[p] <= f then break end
                heapKeys[i], heapF[i] = heapKeys[p], heapF[p]
                i = p
            end
            heapKeys[i], heapF[i] = k, f
        end
        local function heapPop()
            local topK = heapKeys[1]
            local lastK, lastF = heapKeys[heapSz], heapF[heapSz]
            heapKeys[heapSz], heapF[heapSz] = nil, nil
            heapSz -= 1
            if heapSz >= 1 then
                local i = 1
                while true do
                    local l, r = i * 2, i * 2 + 1
                    if l > heapSz then break end
                    local c = (r <= heapSz and heapF[r] < heapF[l]) and r or l
                    if heapF[c] >= lastF then break end
                    heapKeys[i], heapF[i] = heapKeys[c], heapF[c]
                    i = c
                end
                heapKeys[i], heapF[i] = lastK, lastF
            end
            return topK
        end

        local function clearCost(cx, cy, brkList)
            local blk, brk, info = dfIsBreakableBlocking(cx, cy)
            if not blk then return true, 0 end
            if not brk then return false, 9999 end
            if brkList then brkList[#brkList + 1] = { cx, cy } end
            return true, 2.2 + math.max(1, toInt(info and info.hits, 3)) * 0.4
        end

        local startKey = sy * w + sx
        local gScore, cameFrom, edgeUsed, closed = { [startKey] = 0 }, { [startKey] = -1 }, {}, {}
        local function heuristic(x, y)
            return math.max(0, math.abs(x - targetX) - 2) + math.max(0, math.abs(y - targetY) - 2) * 1.35
        end
        heapPush(startKey, heuristic(sx, sy))

        local function tryPush(fromKey, nx, ny, cost, kind, dir, brkList)
            if nx < 0 or nx >= w or ny < 0 or ny >= h then return end
            local nk = ny * w + nx
            if closed[nk] then return end
            local ng = (gScore[fromKey] or 0) + cost
            if not gScore[nk] or ng < gScore[nk] then
                gScore[nk] = ng
                cameFrom[nk] = fromKey
                edgeUsed[nk] = { kind = kind, x = nx, y = ny, dir = dir, breakTiles = brkList }
                heapPush(nk, ng + heuristic(nx, ny))
            end
        end

        local expansions = 0
        while heapSz > 0 and expansions < 6500 do
            local curK = heapPop()
            if not closed[curK] then
                closed[curK] = true
                expansions += 1
                local cx, cy = curK % w, math.floor(curK / w)
                if curK ~= startKey then
                    local standPos = { x = cx + 0.5, y = cy + 1 }
                    if dfCanActFromStand(targetX, targetY, actionKind, itemInfo, standPos) then
                        local underTarget = (actionKind == "break" and cx == targetX and cy + 1 == targetY)
                        if not underTarget or heapSz == 0 or gScore[curK] > 30 then
                            local rev, ptr = {}, curK
                            while ptr and ptr ~= -1 do
                                local ed = edgeUsed[ptr]
                                if ed then rev[#rev + 1] = ed end
                                ptr = cameFrom[ptr]
                            end
                            local path = {}
                            for i = #rev, 1, -1 do path[#path + 1] = rev[i] end
                            return path
                        end
                    end
                end

                for _, dir in ipairs({ -1, 1 }) do
                    local nx = cx + dir
                    if nx >= 0 and nx < w then
                        -- 1. Walk horizontal datar
                        if dfIsStandable(nx, cy + 1) then
                            local brk = {}
                            local okC, cCost = clearCost(nx, cy, brk)
                            if okC then
                                tryPush(curK, nx, cy, 1.0 + cCost, "walk", dir, brk)
                            end
                        end

                        -- 2. Jump Up 1..2 tile
                        for jh = 1, 2 do
                            local ny = cy - jh
                            if ny >= 1 then
                                local brk = {}
                                local okAll = dfIsStandable(nx, ny + 1)
                                local totalC = 2.4 + jh * 0.7
                                if okAll then
                                    for hy = cy - 1, ny - 1, -1 do
                                        local okH, cH = clearCost(cx, hy, brk)
                                        if not okH then okAll = false; break end
                                        totalC += cH
                                    end
                                end
                                if okAll then
                                    for ly = ny, ny - 1, -1 do
                                        local okL, cL = clearCost(nx, ly, brk)
                                        if not okL then okAll = false; break end
                                        totalC += cL
                                    end
                                end
                                if okAll then
                                    tryPush(curK, nx, ny, totalC, "jump_up", dir, brk)
                                end
                            end
                        end

                        -- 3. Drop ke bawah melalui kolom air
                        if not dfIsStandable(nx, cy + 1) then
                            local brk = {}
                            local okEntry, eCost = clearCost(nx, cy, brk)
                            if okEntry then
                                local fy = cy + 1
                                while fy < h and not dfIsStandable(nx, fy) do
                                    local blkD, brkD = dfIsBreakableBlocking(nx, fy)
                                    if blkD and not brkD then fy = h + 1; break end
                                    if blkD and brkD then brk[#brk + 1] = { nx, fy }; eCost += 2.6 end
                                    fy += 1
                                end
                                if fy < h then
                                    local landY = fy - 1
                                    tryPush(curK, nx, landY, 1.4 + (landY - cy) * 0.35 + eCost, "drop", dir, brk)
                                end
                            end
                        end

                        -- 4. Jump horizontal melewati celah 1..2 tile
                        for span = 2, 3 do
                            local lx = cx + dir * span
                            if lx >= 0 and lx < w and dfIsStandable(lx, cy + 1) and not dfIsStandable(nx, cy + 1) then
                                local brk = {}
                                local okGap, gapC = true, 2.5 + span * 0.4
                                local okHead0, ch0 = clearCost(cx, cy - 1, brk)
                                if not okHead0 then okGap = false end
                                gapC += ch0
                                if okGap then
                                    for s = 1, span do
                                        local gx = cx + dir * s
                                        local ok1, c1 = clearCost(gx, cy, brk)
                                        local ok2, c2 = clearCost(gx, cy - 1, brk)
                                        if not ok1 or not ok2 then okGap = false; break end
                                        gapC += c1 + c2
                                    end
                                end
                                if okGap then
                                    tryPush(curK, lx, cy, gapC, "jump_gap", dir, brk)
                                end
                            end
                        end
                    end
                end
            end
        end
        return nil
    end

    local function dfExecutePath(path, tx, ty, actionKind, itemInfo, aliveFn)
        local i = 1
        while i <= #path do
            if type(aliveFn) == "function" and not aliveFn() then
                Core.ClearManualInput()
                return false
            end
            if dfCanActFromStand(tx, ty, actionKind, itemInfo, Core.ReadPos()) then
                Core.ClearManualInput()
                return true
            end
            local ed = path[i]
            if ed.breakTiles and #ed.breakTiles > 0 then
                local needBrk = {}
                for _, bt in ipairs(ed.breakTiles) do
                    if dfIsBlocking(bt[1], bt[2]) then
                        needBrk[#needBrk + 1] = bt
                    end
                end
                if #needBrk > 0 then
                    if not dfCleanTilesInReach(needBrk, aliveFn) then
                        Core.ClearManualInput()
                        return false
                    end
                    for _, bt in ipairs(needBrk) do
                        if dfIsBlocking(bt[1], bt[2]) then
                            Core.ClearManualInput()
                            return false
                        end
                    end
                end
            end

            if ed.kind == "walk" then
                local endIdx = i
                local expectedY = ed.y + 1
                while endIdx + 1 <= #path do
                    local nxt = path[endIdx + 1]
                    if nxt.kind == "walk" and nxt.dir == ed.dir and nxt.y == ed.y and (not nxt.breakTiles or #nxt.breakTiles == 0) then
                        endIdx += 1
                    else
                        break
                    end
                end
                local endNode = path[endIdx]
                local okW = dfStepWalkToX(endNode.x + 0.5, expectedY, 1.2 + (endIdx - i + 1) * 0.25, aliveFn, function(p)
                    return dfCanActFromStand(tx, ty, actionKind, itemInfo, p), "in_reach"
                end)
                if not okW then return false end
                i = endIdx + 1
            elseif ed.kind == "jump_up" or ed.kind == "jump_gap" then
                local okJ = dfManualJumpTo(ed.x, ed.y + 1, aliveFn)
                if not okJ then return false end
                i += 1
            elseif ed.kind == "drop" then
                local okD = dfDropIntoCol(ed.x, ed.y + 1, aliveFn, 2.8)
                if not okD then return false end
                i += 1
            else
                i += 1
            end
        end
        Core.ClearManualInput()
        return dfCanActFromStand(tx, ty, actionKind, itemInfo, Core.ReadPos())
    end

    local function dfMoveManualNear(tx, ty, aliveFn, actionKind, itemInfo)
        local kind = actionKind or "break"
        dfSettleGrounded(aliveFn, 0.35)
        local cur = Core.ReadPos()
        if dfCanActFromStand(tx, ty, kind, itemInfo, cur) then
            return true, "in_reach"
        end

        local dirtId = resolveDirtId()
        for attempt = 1, 3 do
            if type(aliveFn) == "function" and not aliveFn() then
                Core.ClearManualInput()
                return false, "cancelled"
            end
            cur = Core.ReadPos()
            if dfCanActFromStand(tx, ty, kind, itemInfo, cur) then
                return true, "in_reach"
            end

            local floorY = math.floor(cur.y + 0.5)
            local path = dfFindManualPath(cur.tx, floorY - 1, tx, ty, kind, itemInfo)
            if path then
                if dfExecutePath(path, tx, ty, kind, itemInfo, aliveFn) then
                    return true, "manual_reached"
                end
            elseif attempt == 1 and ty < cur.ty - 1 and Core.CountItem(dirtId) >= 2 and H.gt then
                -- Jika target lebih tinggi dan terputus jurang/shaft, naik melalui shaft terdekat menggunakan pijakan Dirt manual
                local w = H.gt.w or 100
                local midX = math.floor(w / 2)
                local shafts = {
                    { 0, 1, 2 },
                    { w - 2, w - 1, w - 3 },
                }
                if DirtFarm.State.centerGap then
                    shafts[#shafts + 1] = { midX - 1, midX, (tx >= midX) and (midX + 1) or (midX - 2) }
                end
                table.sort(shafts, function(a, b)
                    return math.abs(a[1] - cur.tx) < math.abs(b[1] - cur.tx)
                end)
                local climbedAny = false
                for _, sh in ipairs(shafts) do
                    local cA, cB, exitX = sh[1], sh[2], sh[3]
                    local basePath = dfFindManualPath(cur.tx, floorY - 1, exitX, cur.ty, "break", nil)
                    if basePath and dfExecutePath(basePath, exitX, cur.ty, "break", nil, aliveFn) then
                        local destFloorY = clamp(ty + 1, 2, (H.gt.h or 60) - 2)
                        if dfClimbShaftToFloorY(buildDfBlueprint(H.gt), cA, cB, destFloorY, dirtId, aliveFn, exitX) then
                            climbedAny = true
                            break
                        end
                    end
                end
                if not climbedAny then break end
            else
                break
            end
        end

        Core.ClearManualInput()
        local fin = Core.ReadPos()
        local finOk = dfCanActFromStand(tx, ty, kind, itemInfo, fin)
        return finOk, finOk and "manual_reached" or "unreachable"
    end

    local function dfWalkCorridorLower(bp, corY, xFrom, xTo, alsoClearAbove, aliveFn, markFailFn)
        local dir = (xTo >= xFrom) and 1 or -1
        local floorY = corY + 1
        local dirtId = bp.dirtId
        local dirtInfo = Core.GetItemInfo(dirtId)

        for tx = xFrom, xTo, dir do
            if type(aliveFn) == "function" and not aliveFn() then
                Core.ClearManualInput()
                return false, "cancelled"
            end

            -- Tangani Center Gap: jembatani datar dengan Dirt sementara atau lompat jika atas terbuka, lalu hancurkan di belakang
            if DirtFarm.State.centerGap and (tx == bp.midX - 1 or tx == bp.midX) and floorY <= bp.maxWorkY then
                local g1 = (dir > 0) and (bp.midX - 1) or bp.midX
                local g2 = (dir > 0) and bp.midX or (bp.midX - 1)
                if tx == g1 then
                    local afterGap = g2 + dir
                    local prepBreak = { { g1, corY }, { g2, corY } }
                    if alsoClearAbove and corY - 1 >= bp.topY and bp.desiredAt(g1, corY - 1) == 0 then
                        prepBreak[#prepBreak + 1] = { g1, corY - 1 }
                        prepBreak[#prepBreak + 1] = { g2, corY - 1 }
                    end
                    dfCleanTilesInReach(prepBreak, aliveFn)

                    local g1Solid = dfIsStandable(g1, floorY) and not dfIsHazard(Core.GetFG(g1, floorY) > 0 and Core.GetItemInfo(Core.GetFG(g1, floorY)) or nil)
                    local g2Solid = dfIsStandable(g2, floorY) and not dfIsHazard(Core.GetFG(g2, floorY) > 0 and Core.GetItemInfo(Core.GetFG(g2, floorY)) or nil)
                    local bridged = false
                    if g1Solid and g2Solid then
                        bridged = true
                    elseif Core.CountItem(dirtId) >= 2 then
                        if not g1Solid then g1Solid = dfEnsureTemporaryStep(g1, floorY, dirtId, aliveFn) end
                        if not g2Solid then g2Solid = dfEnsureTemporaryStep(g2, floorY, dirtId, aliveFn) end
                        bridged = g1Solid and g2Solid
                    elseif not dfIsBlocking(tx - dir, corY - 1) and not dfIsBlocking(g1, corY - 1) and not dfIsBlocking(g2, corY - 1) and dfIsStandable(afterGap, floorY) then
                        dfCleanTilesInReach({ { afterGap, corY } }, aliveFn)
                        if dfManualJumpTo(afterGap, floorY, aliveFn) then
                            bridged = true
                        end
                    end

                    if not bridged then
                        Core.ClearManualInput()
                        return false, "no_dirt_bridge"
                    end
                    if math.abs(Core.ReadPos().tx - afterGap) > 0 then
                        if not dfStepWalkToX(g2 + 0.5, floorY, 1.2, aliveFn) then
                            Core.ClearManualInput()
                            return false, "gap_walk_failed"
                        end
                        if bp.desiredAt(afterGap, floorY) == dirtId and Core.GetFG(afterGap, floorY) ~= dirtId then
                            if not dfPlaceDirtSafe(afterGap, floorY, dirtId, aliveFn) and not dfIsStandable(afterGap, floorY) then
                                Core.ClearManualInput()
                                return false, "after_gap_no_floor"
                            end
                        end
                        dfCleanTilesInReach({ { afterGap, corY } }, aliveFn)
                        if not dfStepWalkToX(afterGap + 0.5, floorY, 0.9, aliveFn) then
                            Core.ClearManualInput()
                            return false, "gap_exit_failed"
                        end
                    end
                    -- Bersihkan jembatan tengah dari sisi seberang (g1 & g2 masih <= 2.0 tile di belakang)
                    dfCleanTilesInReach({ { g1, floorY }, { g2, floorY } }, aliveFn)
                    dfQuickCollectNear(aliveFn)
                end
            else
                -- Pastikan tile koridor, atap ekstra (bedrock), & lantai ke depan sesuai blueprint sebelum melangkah ke tx
                local wantCor = bp.desiredAt(tx, corY)
                local curCor = Core.GetFG(tx, corY)
                local needCorBreak = (wantCor == 0 and curCor ~= 0 and not Core.IsProtectedTile(curCor))
                local needAboveBreak = alsoClearAbove and corY - 1 >= bp.topY and bp.desiredAt(tx, corY - 1) == 0 and Core.GetFG(tx, corY - 1) ~= 0 and not Core.IsProtectedTile(Core.GetFG(tx, corY - 1))
                local wantFloor = (floorY <= bp.maxWorkY) and bp.desiredAt(tx, floorY) or nil
                local curFloor = Core.GetFG(tx, floorY)
                local needFloorFix = (wantFloor == dirtId and curFloor ~= dirtId and not Core.IsProtectedTile(curFloor) and Core.CanEditTile(tx, floorY))

                if needCorBreak or needAboveBreak or needFloorFix then
                    local standReqX = tx - dir
                    local curPos = Core.ReadPos()
                    local needActionKind = (needCorBreak or needAboveBreak) and "break" or "build"
                    local reqInReach = true
                    if needCorBreak and not Core.IsInActionReach(tx, corY, "break", curPos) then reqInReach = false end
                    if needAboveBreak and not Core.IsInActionReach(tx, corY - 1, "break", curPos) then reqInReach = false end
                    if needFloorFix and not dfCanActFromStand(tx, floorY, "build", dirtInfo, curPos) then reqInReach = false end

                    if math.abs(curPos.y - floorY) > 0.48 or math.abs(curPos.x - (tx + 0.5)) > 2.4 or not reqInReach then
                        if math.abs(curPos.y - floorY) <= 0.45 and math.abs(curPos.x - (standReqX + 0.5)) <= 2.3 and dfIsStandable(standReqX, floorY) then
                            local okMove = dfStepWalkToX(standReqX + 0.5, floorY, 1.25, aliveFn)
                            if not okMove then
                                if not dfMoveManualNear(tx, corY, aliveFn, needActionKind, (needActionKind == "build") and dirtInfo or nil) then
                                    Core.ClearManualInput()
                                    return false, "approach_failed"
                                end
                            end
                        else
                            if not dfMoveManualNear(tx, corY, aliveFn, needActionKind, (needActionKind == "build") and dirtInfo or nil) then
                                Core.ClearManualInput()
                                return false, "approach_failed"
                            end
                        end
                    end

                    -- Batch break koridor 1..3 tile ke depan sekaligus dalam jangkauan agar cepat & mulus
                    local brkBatch = {}
                    if needCorBreak then brkBatch[#brkBatch + 1] = { tx, corY } end
                    if needAboveBreak then brkBatch[#brkBatch + 1] = { tx, corY - 1 } end
                    for look = 1, 2 do
                        local txAhead = tx + dir * look
                        if txAhead >= 2 and txAhead <= bp.w - 3 and not (DirtFarm.State.centerGap and (txAhead == bp.midX - 1 or txAhead == bp.midX)) then
                            if bp.desiredAt(txAhead, corY) == 0 and Core.GetFG(txAhead, corY) ~= 0 and not Core.IsProtectedTile(Core.GetFG(txAhead, corY)) then
                                brkBatch[#brkBatch + 1] = { txAhead, corY }
                            end
                            if alsoClearAbove and corY - 1 >= bp.topY and bp.desiredAt(txAhead, corY - 1) == 0 and Core.GetFG(txAhead, corY - 1) ~= 0 and not Core.IsProtectedTile(Core.GetFG(txAhead, corY - 1)) then
                                brkBatch[#brkBatch + 1] = { txAhead, corY - 1 }
                            end
                        end
                    end
                    if #brkBatch > 0 then
                        dfCleanTilesInReach(brkBatch, aliveFn)
                    end

                    if needCorBreak and dfIsBlocking(tx, corY) then
                        if Core.IsProtectedTile(Core.GetFG(tx, corY)) or not Core.CanEditTile(tx, corY) then
                            if markFailFn then markFailFn(tx, corY) end
                        else
                            dfCleanTilesInReach({ { tx, corY } }, aliveFn)
                            if dfIsBlocking(tx, corY) then
                                if markFailFn then markFailFn(tx, corY) end
                                Core.ClearManualInput()
                                return false, "corridor_blocked"
                            end
                        end
                    end

                    if needFloorFix then
                        local floorSolidNow = dfIsStandable(tx, floorY)
                        if Core.CountItem(dirtId) <= 0 then
                            dfQuickCollectNear(aliveFn, dirtId)
                        end
                        if Core.CountItem(dirtId) > 0 then
                            local okP, errP = dfPlaceDirtSafe(tx, floorY, dirtId, aliveFn)
                            if not okP and markFailFn then markFailFn(tx, floorY) end
                        elseif not floorSolidNow then
                            Core.ClearManualInput()
                            return false, "no_dirt"
                        end
                    end
                end

                -- Pastikan lantai tx benar-benar dapat dipijak sebelum berjalan masuk
                local atLeftEdge = (tx == 2)
                local atRightEdge = (tx == bp.w - 3)
                if atLeftEdge or atRightEdge or tx == xTo then
                    local okStep = dfStepWalkToX(tx + 0.5, floorY, 1.25, aliveFn)
                    if not okStep then
                        Core.ClearManualInput()
                        return false, "edge_walk_failed"
                    end
                    local sCols = atLeftEdge and { 0, 1 } or (atRightEdge and { bp.w - 2, bp.w - 1 } or {})
                    if #sCols > 0 then
                        local scList = {}
                        for _, sc in ipairs(sCols) do
                            if bp.desiredAt(sc, corY) == 0 and Core.GetFG(sc, corY) ~= 0 then scList[#scList + 1] = { sc, corY } end
                            if alsoClearAbove and bp.desiredAt(sc, corY - 1) == 0 and Core.GetFG(sc, corY - 1) ~= 0 then scList[#scList + 1] = { sc, corY - 1 } end
                            -- Jangan hancurkan lantai shaft ujung ini jika masih perlu turun di kolom ujung ini
                            local isDropTurnHere = (tx == xTo and floorY <= bp.maxWorkY)
                            if not isDropTurnHere and bp.desiredAt(sc, floorY) == 0 and Core.GetFG(sc, floorY) ~= 0 then
                                scList[#scList + 1] = { sc, floorY }
                            end
                        end
                        dfCleanTilesInReach(scList, aliveFn)
                        dfQuickCollectNear(aliveFn)
                    end
                else
                    -- Terus berjalan mulus melewati tile bersih tanpa berhenti setiap 1 tile
                    local okWalkTile = dfStepWalkToX(tx + 0.5, floorY, 1.0, aliveFn, function(p)
                        return (dir > 0 and p.x >= tx + 0.35) or (dir < 0 and p.x <= tx + 0.65), "passed"
                    end, true)
                    if not okWalkTile then
                        Core.ClearManualInput()
                        return false, "walk_stalled"
                    end
                    if (math.abs(tx - xFrom) % 4 == 0) or Core.CountItem(dirtId) < 15 then
                        dfQuickCollectNear(aliveFn)
                    end
                end
            end
        end

        Core.ClearManualInput()
        return true, "row_done"
    end

    local function dfWalkUpperShelf(bp, standFloorY, placeFloorY, xFrom, xTo, aliveFn, markFailFn)
        local dir = (xTo >= xFrom) and 1 or -1
        local dirtId = bp.dirtId
        local standCorY = standFloorY - 1
        local ceilCorY = placeFloorY - 1

        for tx = xFrom, xTo, dir do
            if type(aliveFn) == "function" and not aliveFn() then
                Core.ClearManualInput()
                return false, "cancelled"
            end

            if DirtFarm.State.centerGap and (tx == bp.midX - 1 or tx == bp.midX) then
                local g1 = (dir > 0) and (bp.midX - 1) or bp.midX
                local g2 = (dir > 0) and bp.midX or (bp.midX - 1)
                if tx == g1 then
                    local afterGap = g2 + dir
                    local prep = { { g1, standCorY }, { g2, standCorY } }
                    if placeFloorY >= bp.topY and bp.desiredAt(g1, placeFloorY) == 0 then
                        prep[#prep + 1] = { g1, placeFloorY }; prep[#prep + 1] = { g2, placeFloorY }
                    end
                    if ceilCorY >= bp.topY and bp.desiredAt(g1, ceilCorY) == 0 then
                        prep[#prep + 1] = { g1, ceilCorY }; prep[#prep + 1] = { g2, ceilCorY }
                    end
                    dfCleanTilesInReach(prep, aliveFn)

                    if not dfIsStandable(g1, standFloorY) and Core.CountItem(dirtId) > 0 then
                        dfEnsureTemporaryStep(g1, standFloorY, dirtId, aliveFn)
                    end
                    if not dfIsStandable(g2, standFloorY) and Core.CountItem(dirtId) > 0 then
                        dfEnsureTemporaryStep(g2, standFloorY, dirtId, aliveFn)
                    end
                    if not (dfIsStandable(g1, standFloorY) and dfIsStandable(g2, standFloorY)) then
                        Core.ClearManualInput()
                        return false, "no_dirt"
                    end
                    dfStepWalkToX(g2 + 0.5, standFloorY, 1.2, aliveFn)
                    dfCleanTilesInReach({ { afterGap, standCorY } }, aliveFn)
                    if bp.desiredAt(afterGap, standFloorY) == dirtId and Core.GetFG(afterGap, standFloorY) ~= dirtId then
                        dfEnsureTemporaryStep(afterGap, standFloorY, dirtId, aliveFn)
                    end
                    if not dfStepWalkToX(afterGap + 0.5, standFloorY, 0.9, aliveFn) then
                        Core.ClearManualInput()
                        return false, "upper_gap_exit_failed"
                    end
                    dfCleanTilesInReach({ { g1, standFloorY }, { g2, standFloorY } }, aliveFn)
                    dfQuickCollectNear(aliveFn)
                end
            else
                -- Bersihkan koridor di depan & atap (ceilCorY), lalu Place Dirt tepat di atas kepala (placeFloorY)
                local curCor = Core.GetFG(tx, standCorY)
                local standPrevX = tx - dir
                if bp.desiredAt(tx, standCorY) == 0 and curCor ~= 0 and not Core.IsProtectedTile(curCor) then
                    if dfIsStandable(standPrevX, standFloorY) then
                        dfStepWalkToX(standPrevX + 0.5, standFloorY, 0.9, aliveFn)
                    end
                    dfCleanTilesInReach({ { tx, standCorY } }, aliveFn)
                end
                if bp.desiredAt(tx, standFloorY) == dirtId and Core.GetFG(tx, standFloorY) ~= dirtId then
                    if dfIsStandable(standPrevX, standFloorY) then
                        dfStepWalkToX(standPrevX + 0.5, standFloorY, 0.9, aliveFn)
                    end
                    local okFloor, errF = dfPlaceDirtSafe(tx, standFloorY, dirtId, aliveFn)
                    if not okFloor and not dfIsStandable(tx, standFloorY) then
                        Core.ClearManualInput()
                        return false, errF or "no_dirt"
                    end
                end

                local okStep = dfStepWalkToX(tx + 0.5, standFloorY, 0.9, aliveFn)
                if not okStep then
                    Core.ClearManualInput()
                    return false, "upper_walk_failed"
                end

                local upperClean = {}
                if ceilCorY >= bp.topY and bp.desiredAt(tx, ceilCorY) == 0 and Core.GetFG(tx, ceilCorY) ~= 0 then
                    upperClean[#upperClean + 1] = { tx, ceilCorY }
                end
                local wantPlace = (placeFloorY >= bp.topY) and bp.desiredAt(tx, placeFloorY) or nil
                if wantPlace == 0 and Core.GetFG(tx, placeFloorY) ~= 0 then
                    upperClean[#upperClean + 1] = { tx, placeFloorY }
                end
                if tx == 2 or tx == bp.w - 3 then
                    local sCols = (tx == 2) and { 0, 1 } or { bp.w - 2, bp.w - 1 }
                    for _, sc in ipairs(sCols) do
                        if bp.desiredAt(sc, standCorY) == 0 and Core.GetFG(sc, standCorY) ~= 0 then upperClean[#upperClean + 1] = { sc, standCorY } end
                        if placeFloorY >= bp.topY and bp.desiredAt(sc, placeFloorY) == 0 and Core.GetFG(sc, placeFloorY) ~= 0 then upperClean[#upperClean + 1] = { sc, placeFloorY } end
                        if ceilCorY >= bp.topY and bp.desiredAt(sc, ceilCorY) == 0 and Core.GetFG(sc, ceilCorY) ~= 0 then upperClean[#upperClean + 1] = { sc, ceilCorY } end
                    end
                end
                if #upperClean > 0 then
                    dfCleanTilesInReach(upperClean, aliveFn)
                end

                if wantPlace == dirtId and Core.GetFG(tx, placeFloorY) ~= dirtId then
                    if Core.CountItem(dirtId) <= 0 then dfQuickCollectNear(aliveFn, dirtId) end
                    local okP, errP = dfPlaceDirtSafe(tx, placeFloorY, dirtId, aliveFn)
                    if not okP then
                        if errP == "no_dirt" then
                            Core.ClearManualInput()
                            return false, "no_dirt"
                        elseif markFailFn then
                            markFailFn(tx, placeFloorY)
                        end
                    end
                end
                dfQuickCollectNear(aliveFn)
            end
        end

        Core.ClearManualInput()
        return true, "upper_row_done"
    end

    local function dfFindReadyDirtDrop(dirtId)
        local gt = H.gt
        if not gt or type(gt.dropList) ~= "function" then return nil end
        local okD, drops = pcall(gt.dropList)
        if not okD or type(drops) ~= "table" then return nil end
        local pos = Core.ReadPos()
        local now = os.clock()
        local best, bestDist = nil, math.huge
        for i = 1, #drops do
            local d = drops[i]
            if type(d) == "table" and d.uid and d.id == dirtId and (d.n or 0) > 0 and (d.readyAt or 0) <= now then
                local dist = math.abs(d.x - pos.x) + math.abs(d.y - pos.y) * 1.4
                if dist < bestDist then
                    bestDist = dist
                    best = d
                end
            end
        end
        return best
    end

    local function dfBreakBatch(tasksBatch, aliveFn)
        if #tasksBatch == 0 then return 0 end
        local first = tasksBatch[1]
        local okM = dfMoveManualNear(first.x, first.y, aliveFn, "break")
        if not okM then return -1 end

        local pendingList = {}
        for _, t in ipairs(tasksBatch) do
            local cid = Core.GetFG(t.x, t.y)
            if cid ~= 0 and not Core.IsProtectedTile(cid) and Core.CanEditTile(t.x, t.y) then
                pendingList[#pendingList + 1] = { tx = t.x, ty = t.y, layer = 1 }
            end
        end
        if #pendingList == 0 then return 0 end

        local cur = Core.ReadPos()
        local execList, outReachList = {}, {}
        for _, bt in ipairs(pendingList) do
            if Core.IsInActionReach(bt.tx, bt.ty, "break", cur) and #execList < 3 then
                execList[#execList + 1] = bt
            else
                outReachList[#outReachList + 1] = bt
            end
        end
        if #execList == 0 then execList[1] = pendingList[1] end

        dfBreakList(execList, aliveFn)
        if #outReachList > 0 and (type(aliveFn) ~= "function" or aliveFn()) then
            local nxt = outReachList[1]
            if dfMoveManualNear(nxt.tx, nxt.ty, aliveFn, "break") then
                local pos2 = Core.ReadPos()
                local followList = {}
                for _, bt in ipairs(outReachList) do
                    if Core.GetFG(bt.tx, bt.ty) ~= 0 and Core.IsInActionReach(bt.tx, bt.ty, "break", pos2) then
                        followList[#followList + 1] = bt
                    end
                end
                if #followList > 0 then dfBreakList(followList, aliveFn) end
            end
        end

        local brokenCount = 0
        for _, bt in ipairs(pendingList) do
            if Core.GetFG(bt.tx, bt.ty) == 0 then brokenCount += 1 end
        end
        dfQuickCollectNear(aliveFn)
        return brokenCount
    end

    local function dfPlaceDirt(tx, ty, dirtId, aliveFn)
        if Core.CountItem(dirtId) <= 0 then
            dfQuickCollectNear(aliveFn, dirtId)
        end
        if Core.CountItem(dirtId) <= 0 and DirtFarm.State.autoCollect then
            local drop = dfFindReadyDirtDrop(dirtId)
            if drop then
                local dtx = clamp(math.floor(drop.x), 0, (H.gt and H.gt.w or 100) - 1)
                local dty = clamp(math.floor(drop.y - 0.01), 0, (H.gt and H.gt.h or 60) - 1)
                dfMoveManualNear(dtx, dty, aliveFn, "collect")
                dfQuickCollectNear(aliveFn, dirtId)
            end
        end
        if Core.CountItem(dirtId) <= 0 then
            return false, "no_dirt"
        end
        local dirtInfo = Core.GetItemInfo(dirtId)
        local okM = dfMoveManualNear(tx, ty, aliveFn, "build", dirtInfo)
        if not okM then return false, "unreachable" end
        return dfPlaceDirtSafe(tx, ty, dirtId, aliveFn)
    end

    DirtFarm._impl = {
        dfQuickCollectNear = dfQuickCollectNear,
        dfMoveManualNear = dfMoveManualNear,
        dfClimbShaftToFloorY = dfClimbShaftToFloorY,
        dfTransitionToLowerRow = dfTransitionToLowerRow,
        dfWalkCorridorLower = dfWalkCorridorLower,
        dfWalkUpperShelf = dfWalkUpperShelf,
        dfFindReadyDirtDrop = dfFindReadyDirtDrop,
        dfBreakBatch = dfBreakBatch,
        dfPlaceDirt = dfPlaceDirt,
        dfStepWalkToX = dfStepWalkToX,
        dfCleanTilesInReach = dfCleanTilesInReach,
        dfEnsureTemporaryStep = dfEnsureTemporaryStep,
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
    local tok = DirtFarm.State.sessionToken
    local function alive() return DirtFarm.State.running and DirtFarm.State.sessionToken == tok end
    if UIHooks.updateButtons then UIHooks.updateButtons() end

    DirtFarm.State.thread = task.spawn(function()
        local impl = DirtFarm._impl
        local skippedKeys, failCounts = {}, {}
        local lastWorldTracked = ""
        local noDirtRetries = 0
        local lowerSweptForWorld, upperSweptForWorld = false, false

        local function tileKey(x, y) return y * 1000 + x end
        local function markFail(x, y)
            local k = tileKey(x, y)
            failCounts[k] = (failCounts[k] or 0) + 1
            if failCounts[k] >= 3 then skippedKeys[k] = true end
        end

        while alive() do
            if evaluateSeems() then break end
            Core.EnsureInit()
            Core.EnsureManualInputHook()
            gt = H.gt
            if not gt or gt.name == "" then
                Core.ClearManualInput()
                setDfStatus("Menunggu world...")
                task.wait(0.5)
            else
                local curW = cleanWorldName(gt.name)
                if curW ~= lastWorldTracked then
                    lastWorldTracked = curW
                    skippedKeys, failCounts = {}, {}
                    noDirtRetries = 0
                    lowerSweptForWorld, upperSweptForWorld = false, false
                end

                local bp = buildDfBlueprint(gt)
                local dirtId = bp.dirtId

                local function rowHasLowerWork(corY, alsoAbove)
                    local flY = corY + 1
                    for x = 0, bp.w - 1 do
                        local wc = bp.desiredAt(x, corY)
                        if wc ~= nil and Core.GetFG(x, corY) ~= wc and not skippedKeys[tileKey(x, corY)] then
                            if wc == 0 or wc == dirtId then return true end
                        end
                        if flY <= bp.maxWorkY then
                            local wf = bp.desiredAt(x, flY)
                            if wf ~= nil and Core.GetFG(x, flY) ~= wf and not skippedKeys[tileKey(x, flY)] then
                                return true
                            end
                        end
                        if alsoAbove and corY - 1 >= bp.topY then
                            local wa = bp.desiredAt(x, corY - 1)
                            if wa ~= nil and Core.GetFG(x, corY - 1) ~= wa and not skippedKeys[tileKey(x, corY - 1)] then
                                return true
                            end
                        end
                    end
                    return false
                end

                -- Stage 1A: Sweep Bagian Bawah (doorY -> maxWorkY) secara manual murni dari atas ke bawah
                if not lowerSweptForWorld then
                    local lowerCors = {}
                    local cy = bp.doorY
                    while cy <= bp.maxWorkY do
                        if cy == bp.maxWorkY - 1 and bp.desiredAt(math.max(2, bp.doorX), bp.maxWorkY) == 0 then
                            lowerCors[#lowerCors + 1] = { corY = bp.maxWorkY, above = true }
                            break
                        else
                            lowerCors[#lowerCors + 1] = { corY = cy, above = false }
                            if cy == bp.maxWorkY then break end
                            cy += 2
                        end
                    end

                    local sweepRev = false
                    local sweptAllLower = true
                    for i = 1, #lowerCors do
                        if not alive() or evaluateSeems() then sweptAllLower = false; break end
                        local rowInfo = lowerCors[i]
                        local rCorY = rowInfo.corY
                        if rowHasLowerWork(rCorY, rowInfo.above) then
                            local curP = Core.ReadPos()
                            local xStart = sweepRev and (bp.w - 3) or 2
                            local xEnd = sweepRev and 2 or (bp.w - 3)
                            if math.abs(curP.tx - xEnd) < math.abs(curP.tx - xStart) then
                                xStart, xEnd = xEnd, xStart
                                sweepRev = not sweepRev
                            end
                            local okReach = (math.floor(curP.y + 0.5) == (rCorY + 1) and math.abs(curP.tx - xStart) <= 1)
                            if not okReach then
                                setDfStatus(string.format("[Manual Walk] Menuju Baris Bawah y=%d (%d)...", rCorY, xStart))
                                okReach = impl.dfMoveManualNear(xStart, rCorY, alive, "stand")
                                if not okReach then
                                    xStart, xEnd = xEnd, xStart
                                    sweepRev = not sweepRev
                                    okReach = impl.dfMoveManualNear(xStart, rCorY, alive, "stand")
                                end
                            end

                            local okRow = false
                            if okReach then
                                setDfStatus(string.format("[Manual Walk] Garap Lorong Bawah y=%d (%d->%d)", rCorY, xStart, xEnd))
                                okRow = impl.dfWalkCorridorLower(bp, rCorY, xStart, xEnd, rowInfo.above, alive, markFail)
                            else
                                local pNow = Core.ReadPos()
                                if math.floor(pNow.y + 0.5) == (rCorY + 1) and pNow.tx >= 2 and pNow.tx <= bp.w - 3 then
                                    setDfStatus(string.format("[Manual Walk] Garap Tengah->Pinggir y=%d (%d->%d)", rCorY, pNow.tx, xEnd))
                                    local okPart = impl.dfWalkCorridorLower(bp, rCorY, pNow.tx, xEnd, rowInfo.above, alive, markFail)
                                    if okPart and alive() then
                                        okRow = impl.dfWalkCorridorLower(bp, rCorY, xEnd, xStart, rowInfo.above, alive, markFail)
                                        xStart, xEnd = xEnd, xStart
                                        sweepRev = not sweepRev
                                    end
                                end
                            end

                            if not okRow then
                                sweptAllLower = false
                            elseif alive() and i < #lowerCors and lowerCors[i + 1].corY == rCorY + 2 and rowHasLowerWork(lowerCors[i + 1].corY, lowerCors[i + 1].above) then
                                local endPos = Core.ReadPos()
                                local atLeft = (endPos.tx <= 3)
                                local sIn = atLeft and 1 or (bp.w - 2)
                                local sOut = atLeft and 0 or (bp.w - 1)
                                local edgeX = atLeft and 2 or (bp.w - 3)
                                impl.dfTransitionToLowerRow(bp, sIn, sOut, edgeX, rCorY, rCorY + 2, dirtId, alive)
                            end
                            sweepRev = not sweepRev
                        end
                    end
                    Core.ClearManualInput()
                    if sweptAllLower then
                        lowerSweptForWorld = true
                    end
                end

                -- Stage 1B: Sweep Bagian Atas (doorY - 1 -> topY) bottom-to-top dengan pijakan Dirt & panjat shaft 1-tile
                if alive() and not upperSweptForWorld then
                    local upperPlaceRows = {}
                    local uy = bp.groundY - 2
                    while uy >= bp.topY do
                        upperPlaceRows[#upperPlaceRows + 1] = uy
                        uy -= 2
                    end
                    local sweptAllUpper = true
                    if #upperPlaceRows > 0 and Core.CountItem(dirtId) > 0 then
                        for i = 1, #upperPlaceRows do
                            if not alive() or evaluateSeems() then sweptAllUpper = false; break end
                            local pY = upperPlaceRows[i]
                            local standY = pY + 2
                            local hasUpperNeed = false
                            for x = 0, bp.w - 1 do
                                local wp = bp.desiredAt(x, pY)
                                if wp ~= nil and Core.GetFG(x, pY) ~= wp and not skippedKeys[tileKey(x, pY)] then hasUpperNeed = true; break end
                                local ws = bp.desiredAt(x, standY - 1)
                                if ws ~= nil and Core.GetFG(x, standY - 1) ~= ws and not skippedKeys[tileKey(x, standY - 1)] then hasUpperNeed = true; break end
                                if pY - 1 >= bp.topY then
                                    local wc = bp.desiredAt(x, pY - 1)
                                    if wc ~= nil and Core.GetFG(x, pY - 1) ~= wc and not skippedKeys[tileKey(x, pY - 1)] then hasUpperNeed = true; break end
                                end
                            end
                            if hasUpperNeed then
                                local curP = Core.ReadPos()
                                local startLeft = (math.abs(curP.tx - 2) <= math.abs(curP.tx - (bp.w - 3)))
                                local xStart = startLeft and 2 or (bp.w - 3)
                                local xEnd = startLeft and (bp.w - 3) or 2
                                local okAt = (math.floor(curP.y + 0.5) == standY and math.abs(curP.tx - xStart) <= 1)
                                if not okAt then
                                    setDfStatus(string.format("[Manual Walk] Menuju Rak Atas y=%d (%d)...", standY, xStart))
                                    okAt = impl.dfMoveManualNear(xStart, standY - 1, alive, "stand")
                                    if not okAt then
                                        xStart, xEnd = xEnd, xStart
                                        okAt = impl.dfMoveManualNear(xStart, standY - 1, alive, "stand")
                                    end
                                end
                                if not okAt then
                                    sweptAllUpper = false
                                    break
                                end
                                setDfStatus(string.format("[Manual Walk] Build Baris Atas y=%d", pY))
                                local okUp, errUp = impl.dfWalkUpperShelf(bp, standY, pY, xStart, xEnd, alive, markFail)
                                if not okUp then
                                    sweptAllUpper = false
                                    if errUp == "no_dirt" then break end
                                end
                                -- Jika masih ada baris di atasnya, panjat 2 tile ke pY lewat shaft di ujung xEnd
                                if okUp and i < #upperPlaceRows and alive() then
                                    local atLeft = (xEnd == 2)
                                    local cIn = atLeft and 1 or (bp.w - 2)
                                    local cOut = atLeft and 0 or (bp.w - 1)
                                    impl.dfCleanTilesInReach({ { xEnd, pY - 1 }, { cIn, standY - 1 }, { cOut, standY - 1 } }, alive)
                                    local okCl = impl.dfClimbShaftToFloorY(bp, cIn, cOut, pY, dirtId, alive, xEnd)
                                    if okCl then
                                        impl.dfStepWalkToX(xEnd + 0.5, pY, 0.9, alive)
                                        impl.dfCleanTilesInReach({ { cIn, pY }, { cOut, pY }, { cIn, standY - 1 } }, alive)
                                        impl.dfQuickCollectNear(alive, dirtId)
                                    end
                                end
                            end
                        end
                    end
                    Core.ClearManualInput()
                    if sweptAllUpper then
                        upperSweptForWorld = true
                    end
                end

                if not alive() then break end

                -- Stage 2: Scan ulang sisa tile & selesaikan satu per satu dengan Pure Manual Walk + Jump + Shaft Climb
                local digShaftTasks, digRowTasks, fillLowerTasks, upperTasks = {}, {}, {}, {}
                local function isShaftX(x)
                    return x <= 1 or x >= bp.w - 2 or (DirtFarm.State.centerGap and (x == bp.midX - 1 or x == bp.midX))
                end

                for y = bp.doorY, bp.maxWorkY do
                    local rev = ((y - bp.doorY) % 2 == 1)
                    local xStart, xEnd, xStep = rev and (bp.w - 1) or 0, rev and 0 or (bp.w - 1), rev and -1 or 1
                    for x = xStart, xEnd, xStep do
                        if not skippedKeys[tileKey(x, y)] then
                            local want = bp.desiredAt(x, y)
                            if want ~= nil then
                                local curId = Core.GetFG(x, y)
                                if want == 0 and curId ~= 0 then
                                    if isShaftX(x) then
                                        digShaftTasks[#digShaftTasks + 1] = { x = x, y = y, op = "break" }
                                    else
                                        digRowTasks[#digRowTasks + 1] = { x = x, y = y, op = "break" }
                                    end
                                elseif want == dirtId and curId ~= dirtId then
                                    fillLowerTasks[#fillLowerTasks + 1] = { x = x, y = y, op = (curId ~= 0) and "replace" or "place" }
                                end
                            end
                        end
                    end
                end

                for y = bp.doorY - 1, bp.topY, -1 do
                    local rev = ((bp.doorY - y) % 2 == 0)
                    local xStart, xEnd, xStep = rev and (bp.w - 1) or 0, rev and 0 or (bp.w - 1), rev and -1 or 1
                    for x = xStart, xEnd, xStep do
                        if not skippedKeys[tileKey(x, y)] then
                            local want = bp.desiredAt(x, y)
                            if want ~= nil then
                                local curId = Core.GetFG(x, y)
                                if want == 0 and curId ~= 0 then
                                    if isShaftX(x) then
                                        digShaftTasks[#digShaftTasks + 1] = { x = x, y = y, op = "break" }
                                    else
                                        digRowTasks[#digRowTasks + 1] = { x = x, y = y, op = "break" }
                                    end
                                elseif want == dirtId and curId ~= dirtId then
                                    upperTasks[#upperTasks + 1] = { x = x, y = y, op = (curId ~= 0) and "replace" or "place" }
                                end
                            end
                        end
                    end
                end

                local totalTodo = #digShaftTasks + #digRowTasks + #fillLowerTasks + #upperTasks
                if totalTodo == 0 then
                    Core.ClearManualInput()
                    local rot = DirtFarm.State.rotationWorlds
                    local nextWorld = nil
                    if #rot > 0 then
                        for idx, wn in ipairs(rot) do
                            if wn == curW and rot[idx + 1] then
                                nextWorld = rot[idx + 1]
                                break
                            end
                        end
                        if not nextWorld then
                            for _, wn in ipairs(rot) do
                                if wn ~= curW then nextWorld = wn; break end
                            end
                        end
                    end

                    if nextWorld and nextWorld ~= curW and type(gt.enter) == "function" then
                        setDfStatus(string.format("[%s] SELESAI -> Rotation ke %s", curW, nextWorld))
                        emitNotify("SYT Dirt Farm", string.format("DF %s selesai! Pindah ke %s...", curW, nextWorld))
                        if DirtFarm.State.autoCollect then
                            impl.dfQuickCollectNear(alive)
                        end
                        Core.ClearManualInput()
                        DirtFarm.State.switchingWorld = true
                        pcall(gt.enter, nextWorld)
                        local deadline = os.clock() + 12
                        while alive() and os.clock() < deadline do
                            local nowW = H.gt and cleanWorldName(H.gt.name) or ""
                            if nowW == nextWorld then break end
                            task.wait(0.25)
                        end
                        task.wait(1.0)
                        pcall(SYT_Logic.Init, true)
                        DirtFarm.State.switchingWorld = false
                    else
                        setDfStatus(string.format("Selesai! World %s Dirt Farm Selesai", curW))
                        emitNotify("SYT Dirt Farm", "Dirt Farm selesai di world " .. curW)
                        DirtFarm.State.running = false
                        break
                    end
                else
                    local activeQueue, phaseLabel
                    if #digRowTasks > 0 then
                        activeQueue, phaseLabel = digRowTasks, "Manual Stray: Gali Lorong"
                    elseif #digShaftTasks > 0 then
                        activeQueue, phaseLabel = digShaftTasks, "Manual Stray: Rapikan Shaft"
                    elseif #fillLowerTasks > 0 then
                        activeQueue, phaseLabel = fillLowerTasks, "Manual Stray: Isi Dirt Bawah"
                    else
                        activeQueue, phaseLabel = upperTasks, "Manual Stray: Place Dirt Atas"
                    end

                    local didAnyAction = false
                    local idx = 1
                    while idx <= #activeQueue and alive() do
                        if evaluateSeems() then break end
                        local taskItem = activeQueue[idx]
                        setDfStatus(string.format("%s (%d/%d | Sisa:%d) (%d,%d)", phaseLabel, idx, #activeQueue, totalTodo - idx + 1, taskItem.x, taskItem.y))
                        local curId = Core.GetFG(taskItem.x, taskItem.y)

                        if taskItem.op == "break" then
                            if curId ~= 0 and not Core.IsProtectedTile(curId) then
                                local batch = { taskItem }
                                local look = 1
                                while #batch < 3 and (idx + look) <= #activeQueue do
                                    local nx = activeQueue[idx + look]
                                    if nx.op == "break" and math.max(math.abs(nx.x - taskItem.x), math.abs(nx.y - taskItem.y)) <= 2 then
                                        batch[#batch + 1] = nx
                                        look += 1
                                    else
                                        break
                                    end
                                end
                                local resB = impl.dfBreakBatch(batch, alive)
                                if resB > 0 then
                                    didAnyAction = true
                                    noDirtRetries = 0
                                    for _, bt in ipairs(batch) do
                                        if Core.GetFG(bt.x, bt.y) ~= 0 then markFail(bt.x, bt.y) end
                                    end
                                else
                                    markFail(taskItem.x, taskItem.y)
                                end
                                idx += #batch
                            else
                                idx += 1
                            end
                        elseif taskItem.op == "replace" then
                            if curId ~= 0 and curId ~= dirtId and not Core.IsProtectedTile(curId) then
                                local resB = impl.dfBreakBatch({ taskItem }, alive)
                                if resB > 0 then didAnyAction = true else markFail(taskItem.x, taskItem.y) end
                            end
                            if Core.GetFG(taskItem.x, taskItem.y) == 0 then
                                local okP, errP = impl.dfPlaceDirt(taskItem.x, taskItem.y, dirtId, alive)
                                if okP then
                                    didAnyAction = true
                                    noDirtRetries = 0
                                elseif errP == "no_dirt" then
                                    noDirtRetries += 1
                                    setDfStatus(string.format("Dirt habis! Collect drops (%d/3)...", noDirtRetries))
                                    task.wait(0.5)
                                    if noDirtRetries >= 3 then break end
                                else
                                    markFail(taskItem.x, taskItem.y)
                                end
                            end
                            idx += 1
                        else -- "place"
                            if Core.GetFG(taskItem.x, taskItem.y) == 0 then
                                local okP, errP = impl.dfPlaceDirt(taskItem.x, taskItem.y, dirtId, alive)
                                if okP then
                                    didAnyAction = true
                                    noDirtRetries = 0
                                elseif errP == "no_dirt" then
                                    noDirtRetries += 1
                                    setDfStatus(string.format("Dirt habis! Collect drops (%d/3)...", noDirtRetries))
                                    task.wait(0.5)
                                    if noDirtRetries >= 3 then break end
                                else
                                    markFail(taskItem.x, taskItem.y)
                                end
                            end
                            idx += 1
                        end
                    end

                    if not didAnyAction and alive() then
                        task.wait(0.35)
                    end
                end
            end
            task.wait(0.05)
        end

        Core.ClearManualInput()
        DirtFarm.State.switchingWorld = false
        if DirtFarm.State.sessionToken == tok then
            DirtFarm.State.running = false
            DirtFarm.State.thread = nil
            if DirtFarm.State.status == "Idle" or string.find(DirtFarm.State.status, "Manual", 1, true) then
                setDfStatus("Stopped")
            elseif UIHooks.updateButtons then
                UIHooks.updateButtons()
            end
        end
    end)
    return true
end

function DirtFarm.Stop()
    Core.ClearManualInput()
    DirtFarm.State.running = false
    DirtFarm.State.switchingWorld = false
    DirtFarm.State.sessionToken += 1
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

local ROLE_BADGES = {
    developer = "`4[DEV] `w",
    moderator = "`#[MOD] `w",
    admin     = "`6[ADMIN] `w",
    owner     = "{rainbow}[OWNER]} `w",
    vip       = "`^[VIP] `w",
    royal     = "{royal}[ROYAL]} ",
    legend    = "{legend}[LEGEND]} ",
    sponsor   = "{sponsor}[SPONSOR]} ",
    supporter = "{supporter}[SUPPORTER]} ",
    dr        = "`2Dr.",
}

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
        wearSlots = { "back", "hand", "hat", "hair", "shirt", "pants", "feet", "face", "neck" },
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
    if effectName == "Rainbow Wave" then return "{rainbow}" .. text .. "}"
    elseif effectName == "Sponsor Sparkle" then return "{sponsor}" .. text .. "}"
    elseif effectName == "Supporter Wave" then return "{supporter}" .. text .. "}"
    elseif effectName == "Legend Gold" then return "{legend}" .. text .. "}"
    elseif effectName == "Royal Pulse" then return "{royal}" .. text .. "}"
    elseif effectName == "Creator Tag" then return "{cc}" .. text .. "}"
    elseif effectName == "Color Prefix" and colorPrefix ~= "" then return colorPrefix .. text
    end
    return (colorPrefix ~= "") and (colorPrefix .. text) or text
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


-- MoveBlock: Ambil item dari posisi take, bawa ke posisi drop, ulangi
local MoveBlock = {
    State = { takePos = nil, dropPos = nil, running = false, thread = nil, status = "Idle", itemId = nil }
}

function MoveBlock.SetTake()
    local pos = Core.ReadPos()
    MoveBlock.State.takePos = { x = pos.tx, y = pos.ty }
    MoveBlock.State.status = string.format("TakePos=(%d,%d)", pos.tx, pos.ty)
    if UI then UI:SetValue("MoveBlockStatus", MoveBlock.State.status) end
end

function MoveBlock.SetDrop()
    local pos = Core.ReadPos()
    MoveBlock.State.dropPos = { x = pos.tx, y = pos.ty }
    MoveBlock.State.status = string.format("TakePos set | DropPos=(%d,%d)", pos.tx, pos.ty)
    if UI then UI:SetValue("MoveBlockStatus", MoveBlock.State.status) end
end

function MoveBlock.Stop()
    MoveBlock.State.running = false
    MoveBlock.State.thread = nil
    MoveBlock.State.status = "Stopped"
    if UI then UI:SetValue("MoveBlockStatus", MoveBlock.State.status) end
end

function MoveBlock.Start()
    if MoveBlock.State.running then return end
    if not MoveBlock.State.takePos or not MoveBlock.State.dropPos then
        emitNotify("MoveBlock", "Set posisi Take & Drop dulu!")
        return
    end
    MoveBlock.State.running = true
    MoveBlock.State.thread = task.spawn(function()
        local tok = MoveBlock.State.thread
        while MoveBlock.State.running and MoveBlock.State.thread == tok do
            local tp = MoveBlock.State.takePos
            local dp = MoveBlock.State.dropPos
            MoveBlock.State.status = "Jalan ke Take..."
            if UI then UI:SetValue("MoveBlockStatus", MoveBlock.State.status) end
            Packets.WalkTeleport({ tx = tp.x, ty = tp.y, mode = "step", stepSize = 3, stepDelay = 0.08 })
            task.wait(0.3)
            -- Collect di area take
            Packets.Collect({ radius = 2, stepMoveIfFar = false, collectDelay = 0 })
            MoveBlock.State.status = "Jalan ke Drop..."
            if UI then UI:SetValue("MoveBlockStatus", MoveBlock.State.status) end
            Packets.WalkTeleport({ tx = dp.x, ty = dp.y, mode = "step", stepSize = 3, stepDelay = 0.08 })
            task.wait(0.3)
            -- Drop / place di area drop (kiri bawah)
            local placeOk = pcall(Packets.Place, { tx = dp.x, ty = dp.y + 1, id = MoveBlock.State.itemId or PNB.State.selectedBlockId or 0 })
            if not placeOk then
                -- coba collect jika tidak ada item untuk di-place
                Packets.Collect({ radius = 1, stepMoveIfFar = false, collectDelay = 0 })
            end
            GetcSkipper.RandomizedWait(2.0)
        end
        MoveBlock.Stop()
    end)
end

function MoveBlock.Toggle()
    if MoveBlock.State.running then MoveBlock.Stop() else MoveBlock.Start() end
end

-- AutoLeveling: Bersihkan setengah world sambil leveling ke L10
local AutoLeveling = {
    State = { running = false, thread = nil, status = "Idle", targetLevel = 10 }
}

function AutoLeveling.GetLevel()
    -- Baca level dari stateObj / gt
    local gt = H.gt
    if gt and type(gt.level) == "number" then return gt.level end
    local ok, stObj = pcall(function()
        local so = Core.GetStateObj()
        return so and (so.level or so.Level or so.xp or so.lv) or nil
    end)
    return (ok and tonumber(stObj)) or 0
end

function AutoLeveling.Stop()
    AutoLeveling.State.running = false
    AutoLeveling.State.thread = nil
    AutoLeveling.State.status = "Stopped"
    DirtFarm.Stop()
    if UI then UI:SetValue("AutoLvlStatus", AutoLeveling.State.status) end
end

function AutoLeveling.Start()
    if AutoLeveling.State.running then return end
    AutoLeveling.State.running = true
    AutoLeveling.State.thread = task.spawn(function()
        while AutoLeveling.State.running do
            local lv = AutoLeveling.GetLevel()
            if lv >= AutoLeveling.State.targetLevel then
                AutoLeveling.State.status = string.format("Level %d tercapai!", lv)
                if UI then UI:SetValue("AutoLvlStatus", AutoLeveling.State.status) end
                AutoLeveling.Stop()
                return
            end
            AutoLeveling.State.status = string.format("Level %d/%d | Farm...", lv, AutoLeveling.State.targetLevel)
            if UI then UI:SetValue("AutoLvlStatus", AutoLeveling.State.status) end
            -- Cek apakah mod/staff ada di world -> warp jika ada
            local players = Core.GetInWorldPlayers(true)
            local modHere = false
            for _, p in ipairs(players) do
                if p.isStaff then modHere = true; break end
            end
            if modHere then
                AutoLeveling.State.status = "MOD terdeteksi! Pindah world..."
                if UI then UI:SetValue("AutoLvlStatus", AutoLeveling.State.status) end
                -- Pindah ke world di rotation list DF jika ada
                local gt = H.gt
                local rotList = DirtFarm.State.rotationList or {}
                if #rotList > 0 and gt and type(gt.enter) == "function" then
                    local curW = cleanWorldName(gt.name)
                    local nxt = rotList[1]
                    for i, w in ipairs(rotList) do
                        if w == curW and rotList[i+1] then nxt = rotList[i+1]; break end
                    end
                    pcall(gt.enter, nxt)
                end
                task.wait(3)
            else
                -- Farm setengah world (jalankan DirtFarm dengan batas tile)
                DirtFarm.State.halfWorldMode = true
                DirtFarm.Start()
                -- Tunggu hingga DF selesai atau stop
                local waitCount = 0
                while DirtFarm.State.running and AutoLeveling.State.running do
                    task.wait(1)
                    waitCount = waitCount + 1
                    if waitCount > 600 then break end -- max 10 menit per world
                end
                DirtFarm.State.halfWorldMode = false
            end
            task.wait(0.5)
        end
    end)
end

function AutoLeveling.Toggle()
    if AutoLeveling.State.running then AutoLeveling.Stop() else AutoLeveling.Start() end
end

-- DiscordHook: Post/Patch status farm ke Discord webhook (opt-in)
local DiscordHook = {
    State = {
        url = "",
        delay = 120, -- detik, 1-5 menit
        enabled = false,
        messageId = nil,
        startTime = nil,
        thread = nil,
    }
}
local _DHOOK_MID_KEY = "__SYT_DHOOK_MID"

function DiscordHook.GetSafeRequest()
    if type(syn) == "table" and type(syn.request) == "function" then return syn.request end
    if type(http_request) == "function" then return http_request end
    if type(request) == "function" then return request end
    return nil
end

function DiscordHook.BuildEmbed()
    local gt = H.gt
    local worldName = (gt and gt.name ~= "" and gt.name) or "-"
    local lp = LP or Players.LocalPlayer
    local playerName = lp and lp.DisplayName or "-"
    local uptime = DiscordHook.State.startTime and math.floor(os.clock() - DiscordHook.State.startTime) or 0
    local uptimeStr = string.format("%dm %ds", math.floor(uptime/60), uptime % 60)

    -- Status dari modul aktif
    local farmStatus = "Idle"
    local prog = ""
    if PNB.State.running then
        farmStatus = "PNB"
        prog = PNB.State.status or "-"
    elseif Pabrik.State.running then
        farmStatus = "Pabrik"
        prog = Pabrik.State.status or "-"
    elseif DirtFarm.State.running then
        farmStatus = "DirtFarm"
        prog = DirtFarm.State.status or "-"
    elseif AutoLeveling.State.running then
        farmStatus = "AutoLeveling"
        prog = AutoLeveling.State.status or "-"
    elseif MoveBlock.State.running then
        farmStatus = "MoveBlock"
        prog = MoveBlock.State.status or "-"
    end

    return {
        embeds = {{
            title = "SYT Farm Status",
            color = 0x00bfff,
            fields = {
                { name = "Player", value = playerName, inline = true },
                { name = "World", value = worldName, inline = true },
                { name = "Mode", value = farmStatus, inline = true },
                { name = "Uptime", value = uptimeStr, inline = true },
                { name = "Progress", value = prog ~= "" and prog or "-", inline = false },
            },
            footer = { text = "SYT DRY CURSED | " .. os.date("%H:%M:%S") },
        }}
    }
end

function DiscordHook.Send()
    local reqFn = DiscordHook.GetSafeRequest()
    if not reqFn or DiscordHook.State.url == "" then return end

    local body = DiscordHook.BuildEmbed()
    local ok, bodyStr = pcall(function()
        -- Manual JSON encode (simple)
        local fields = {}
        for _, f in ipairs(body.embeds[1].fields) do
            table.insert(fields, string.format('{"name":"%s","value":"%s","inline":%s}',
                f.name, tostring(f.value):gsub('"', '\\"'), f.inline and "true" or "false"))
        end
        return string.format(
            '{"embeds":[{"title":"%s","color":%d,"fields":[%s],"footer":{"text":"%s"}}]}',
            body.embeds[1].title,
            body.embeds[1].color,
            table.concat(fields, ","),
            body.embeds[1].footer.text:gsub('"', '\\"')
        )
    end)
    if not ok then return end

    local mid = DiscordHook.State.messageId
    local method = mid and "PATCH" or "POST"
    local url = mid and (DiscordHook.State.url .. "/messages/" .. mid) or DiscordHook.State.url

    local ok2, resp = pcall(reqFn, {
        Url = url .. "?wait=true",
        Method = method,
        Headers = { ["Content-Type"] = "application/json" },
        Body = bodyStr
    })
    if ok2 and type(resp) == "table" and resp.StatusCode and resp.StatusCode >= 200 and resp.StatusCode < 300 then
        -- Simpan message ID dari respons POST pertama
        if method == "POST" and type(resp.Body) == "string" then
            local id = resp.Body:match('"id"%s*:%s*"(%d+)"')
            if id then
                DiscordHook.State.messageId = id
                local env = getEnv()
                if env then env[_DHOOK_MID_KEY] = id end
            end
        end
    end
end

function DiscordHook.Stop()
    DiscordHook.State.enabled = false
    DiscordHook.State.thread = nil
end

function DiscordHook.Start()
    if DiscordHook.State.enabled then return end
    if DiscordHook.State.url == "" then
        emitNotify("DiscordHook", "Masukkan Webhook URL dulu!")
        return
    end
    DiscordHook.State.enabled = true
    DiscordHook.State.startTime = os.clock()
    -- Restore saved message ID
    local env = getEnv()
    if env and env[_DHOOK_MID_KEY] then
        DiscordHook.State.messageId = env[_DHOOK_MID_KEY]
    end
    DiscordHook.State.thread = task.spawn(function()
        while DiscordHook.State.enabled do
            pcall(DiscordHook.Send)
            task.wait(math.max(60, DiscordHook.State.delay))
        end
    end)
end

function DiscordHook.Toggle()
    if DiscordHook.State.enabled then DiscordHook.Stop() else DiscordHook.Start() end
end

-- ProxyCommands: Hook chat masuk untuk parsing /command dari owner
local ProxyCommands = {}
local _proxyHookConn = nil

local function proxyReply(msg)
    -- Kirim reply via Net.chat jika tersedia, else floatText
    pcall(function()
        if H.Net and type(H.Net.chat) == "table" and type(H.Net.chat.FireServer) == "function" then
            H.Net.chat:FireServer(tostring(msg))
        elseif H.gt and type(H.gt.floatText) == "function" then
            H.gt.floatText(tostring(msg))
        else
            Packets.SendChat(tostring(msg))
        end
    end)
end

local function handleProxyCommand(cmd, args, senderName)
    local lp = LP or Players.LocalPlayer
    local myName = lp and lp.DisplayName or ""
    -- Hanya respon ke owner (diri sendiri atau nama cocok)
    if senderName and senderName ~= "" and senderName ~= myName then return end

    if cmd == "reme" then
        -- Fast roulette (spin wheel)
        Misc.SetFastRoulette(true)
        task.delay(2, function() Misc.SetFastRoulette(false) end)
        proxyReply("[SYT] Fast Roulette ON 2s")

    elseif cmd == "clothes" then
        -- Toggle visual outfit editor notification
        proxyReply("[SYT] /clothes: Gunakan GUI Visual tab untuk edit outfit")

    elseif cmd == "set" and args[1] == "b" then
        -- /set b 1 atau /set b 2 -> set block PNB ke slot 1 atau 2
        local slot = tonumber(args[2]) or 1
        proxyReply("[SYT] /set b" .. tostring(slot) .. " -> Block slot diatur via GUI PNB")

    elseif cmd == "lock" and args[1] == "t" then
        local t = args[2] or "1"
        proxyReply("[SYT] /lock t" .. t .. " -> Lock tile via Visual tab")

    elseif cmd == "cal" then
        -- Info kalkulasi gems/jam
        local gems = H.gt and type(H.gt.gems) == "number" and H.gt.gems or 0
        proxyReply(string.format("[SYT] Gems saat ini: %d", gems))

    elseif cmd == "set" and args[1] == "tax" then
        proxyReply("[SYT] /set tax -> Atur via GUI System tab")

    elseif cmd == "info" then
        -- Host BJ info
        local players = Core.GetInWorldPlayers(true)
        local hosts = {}
        for _, p in ipairs(players) do
            if p.isStaff or (p.role and string.lower(p.role):find("host")) then
                table.insert(hosts, p.gameName)
            end
        end
        proxyReply("[SYT] Host/BJ: " .. (#hosts > 0 and table.concat(hosts, ", ") or "Tidak ada"))

    elseif cmd == "get" then
        -- IP info (hanya tampil di UI, tidak dikirim ke orang lain)
        proxyReply("[SYT] /get -> IP hanya ditampilkan di GUI lokal")

    elseif cmd == "cn" then
        -- Role/name info
        proxyReply("[SYT] /cn -> Custom name via Visual tab")

    elseif cmd == "news" then
        proxyReply("[SYT] DRY CURSED " .. (getEnv().__SYT_VERSION or "v1.0") .. " | 2-Tab Farm+Tools")
    end
end

function ProxyCommands.Install()
    if _proxyHookConn then pcall(function() _proxyHookConn:Disconnect() end) end
    _proxyHookConn = nil
    -- Hook TextChatService jika tersedia
    local ok, TCS = pcall(game.GetService, game, "TextChatService")
    if ok and TCS then
        local okCh, ch = pcall(function()
            return TCS:FindFirstChildOfClass("TextChannel") or TCS.RootChannel
        end)
        if okCh and ch then
            _proxyHookConn = ch.MessageReceived:Connect(function(msg)
                local text = msg and msg.Text or ""
                local sender = msg and msg.TextSource and msg.TextSource.Name or ""
                if text:sub(1,1) == "/" then
                    local parts = {}
                    for p in text:gmatch("%S+") do table.insert(parts, p) end
                    local cmd = parts[1] and parts[1]:sub(2):lower() or ""
                    local args = {}
                    for i = 2, #parts do args[#args+1] = parts[i] end
                    handleProxyCommand(cmd, args, sender)
                end
            end)
        end
    end
    -- Fallback: hook via H.Net.chat jika TCS tidak ada
    if not _proxyHookConn and H.Net and H.Net.chat and type(H.Net.chat.OnClientEvent) == "table" then
        local ev = H.Net.chat.OnClientEvent
        if ev then
            _proxyHookConn = ev:Connect(function(data)
                local text = type(data) == "table" and (data.msg or data.text or "") or tostring(data)
                local sender = type(data) == "table" and (data.name or data.gameName or "") or ""
                if text:sub(1,1) == "/" then
                    local parts = {}
                    for p in text:gmatch("%S+") do table.insert(parts, p) end
                    local cmd = parts[1] and parts[1]:sub(2):lower() or ""
                    local args = {}
                    for i = 2, #parts do args[#args+1] = parts[i] end
                    handleProxyCommand(cmd, args, sender)
                end
            end)
        end
    end
end


stopAllAutomationImpl = function(reason)
    PNB.Stop()
    Pabrik.Stop()
    DirtFarm.Stop()
    Spam.Stop()
    stopRandomTp()
    -- DRY CURSED: tambahan modul baru
    if MoveBlock and MoveBlock.State.running then MoveBlock.Stop() end
    if AutoLeveling and AutoLeveling.State.running then AutoLeveling.Stop() end
    if Misc.State.autoFollow then Misc.SetAutoFollow(false) end
    if Misc.State.autoCollect then Misc.SetAutoCollect(false) end
    if Misc.State.fly then Misc.SetFly(false) end
    if Misc.State.noClip then Misc.SetNoClip(false) end
    if reason and reason ~= "" and UI then
        UI:SetValue("ValidStatusDisplay", reason)
        setPNBStatus(reason)
        setPabrikStatus(reason)
        setDfStatus(reason)
        setSpamStatus(reason)
        if UI:SetValue then pcall(UI.SetValue, UI, "MoveBlockStatus", reason) end
        if UI:SetValue then pcall(UI.SetValue, UI, "AutoLvlStatus", reason) end
    end
    if UIHooks.updateButtons then UIHooks.updateButtons() end
end
SYT_Logic.StopAllAutomation = stopAllAutomationImpl

local function getActiveMenuGui()
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

local function menuIsReady()
    local sg = getActiveMenuGui()
    if not sg or not sg.Parent then return false end
    if UI and UI.MainWindow and not UI.MainWindow.Parent then return false end
    -- DRY CURSED: 2 tab (Farm + Tools), threshold diturunkan sesuai
    if not UI or type(UI.Features) ~= "table" or #UI.Features < 2 then return false end
    local okCnt, cnt = pcall(function() return #sg:GetDescendants() end)
    return okCnt and cnt > 20
end

local function allCanvasesReady()
    return menuIsReady()
        and UIHooks.refreshBP ~= nil
        and UIHooks.refreshPad5x5 ~= nil
        and UIHooks.refreshPadPab ~= nil
end

local function enforceSingleActiveFeatureTab()
    if not UI then return end
    if type(UI.SelectFeature) == "function" then
        pcall(UI.SelectFeature, UI, 1)
    end
    if type(UI.Features) == "table" then
        for idx, feat in ipairs(UI.Features) do
            if type(feat) == "table" then
                local isFirst = (idx == 1)
                if feat.CenterPage and typeof(feat.CenterPage) == "Instance" then
                    feat.CenterPage.Visible = isFirst
                end
                if feat.RightPage and typeof(feat.RightPage) == "Instance" then
                    feat.RightPage.Visible = isFirst
                end
            end
        end
    end
    if type(UI.SyncRightPanelVisibility) == "function" then
        pcall(UI.SyncRightPanelVisibility, UI)
    end
    if type(UI.SyncNavCanvas) == "function" then
        pcall(UI.SyncNavCanvas)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- 7. SYT GUI LAYOUT (TERSTRUKTUR: CENTER = KONTROL & CANVAS | RIGHT = AKSI & STATUS)
-- ═══════════════════════════════════════════════════════════════════════════
local buildMountedCanvasesFn

buildSYTMenuFn = function()
    UIHooks.refreshBP      = nil
    UIHooks.refreshPad5x5  = nil
    UIHooks.refreshPadPab  = nil
    UIHooks.sidebarNameLbl = nil
    UIHooks.sidebarSubLbl  = nil

    local okAcc, accName = pcall(Core.GetInGameName, LP, true)
    accName = (okAcc and type(accName) == "string" and accName ~= "") and accName or (LP and LP.DisplayName) or "-"

    -- ═══ TAB 1: FARM ═══
    if UI.Category then UI:Category("Farm") end

    feature("Farm", "Farm")({
        center = center(function(c)
            c:Header("SYT DRY CURSED — Farm Suite", "PNB, Pabrik, Dirt Farm, Clear World, Move Block & System", "SYT")

            -- == SYSTEM ==
            local SysCard = c:Card("System & Kontrol Sesi", nil, "Shield", {
                Subtitle = "Discord Log, Leave/Freeze toggle, Auto Leveling"
            })
            SysCard:Input("Akun Game & World", "LiveInGameAccount", "Menunggu world...", accName)
            SysCard:Toggle("Discord Log (Kirim ke Webhook)", "SysDiscordLogToggle", false, function(v)
                if v then
                    DiscordHook.State.url = UI:GetValue("SysDiscordUrlInput") or ""
                    DiscordHook.Start()
                else
                    DiscordHook.Stop()
                end
            end)
            SysCard:Toggle("Mode: Leave (OFF) / Freeze (ON)", "SysLeaveFreezeToggle", true, function(v)
                -- true = Freeze mode, false = Leave mode
                H._sysLeaveMode = not v
            end)
            SysCard:Button("STOP SEMUA OTOMASI", "STOP ALL", "Shield", function()
                stopAllAutomationImpl("Dihentikan manual oleh user")
            end)

            -- == AUTO LEVELING ==
            local LvlCard = c:Card("Auto Leveling (Target L10)", nil, "Bolt", {
                Subtitle = "Bersihkan setengah world sambil leveling, warp jika ada MOD"
            })
            LvlCard:Input("Status Auto Leveling", "AutoLvlStatus", "Idle", AutoLeveling.State.status)
            LvlCard:Button("[AUTO LVL] Start / Stop", "TOGGLE", "Bolt", function()
                local busy = PNB.State.running or Pabrik.State.running or DirtFarm.State.running or MoveBlock.State.running
                if busy and not AutoLeveling.State.running then
                    emitNotify("SYT", "Sorry, your task is do right now")
                    return
                end
                AutoLeveling.Toggle()
            end)

            -- == PNB ==
            local BpCard = c:Card("PNB — Backpack Item Selector", nil, "Visuals", {
                Subtitle = "Pilih block dari Backpack, tentukan tile 5x5 & atur speed"
            })
            BpCard:Input("Embedded Backpack Items", "__BP_ITEM_ANCHOR__", "__BP_ITEM_ANCHOR_KEY__", "__BP_ITEM_ANCHOR_KEY__")
            BpCard:Button("Refresh Backpack", "REFRESH BP", "Visuals", function()
                Core.EnsureInit()
                if UIHooks.refreshBP then UIHooks.refreshBP() end
            end)

            local PadCard = c:Card("PNB — Pad Tile 5x5", nil, "Teleports", {
                Subtitle = "Pilih tile target Place → Break → Collect"
            })
            PadCard:Input("Embedded 5x5 Pad", "__PAD_5X5_ANCHOR__", "__PAD_5X5_ANCHOR_KEY__", "__PAD_5X5_ANCHOR_KEY__")

            local PnbOptCard = c:Card("PNB — Speed & Opsi", nil, "Sliders", {
                Subtitle = "Kecepatan 0-100% (map ke speed ratio 1x-10x)"
            })
            PnbOptCard:Slider("PNB Speed (%)", "PnbSpeedPct", 0, 100, math.floor((PNB.State.speed or 2) / 10 * 100), "%", function(v)
                PNB.State.speed = math.max(1, math.floor(clamp(tonumber(v) or 20, 0, 100) / 10))
            end, 5)
            PnbOptCard:Toggle("1-Hit Break", "PnbOneHit", PNB.State.oneHit, function(v) PNB.State.oneHit = v == true end)
            PnbOptCard:Toggle("Auto Collect Drops", "PnbAutoCollect", PNB.State.autoCollect, function(v) PNB.State.autoCollect = v == true end)

            -- == PABRIK ==
            local PabCard = c:Card("Pabrik — Item & Pad", nil, "Bolt", {
                Subtitle = "Pasang tile plant+harvest, pilih block/seed pair"
            })
            PabCard:Input("Nama / ID Block atau Seed", "PabrikItemInput", "Contoh: Dirt atau 2", tostring(Pabrik.State.itemName or ""), function(txt)
                if txt and txt ~= "" then Pabrik.SetItem(txt) end
            end)
            PabCard:Button("Set Item dari Input", "SET ITEM", "Shield", function()
                local pair = Pabrik.SetItem(UI:GetValue("PabrikItemInput"))
                if not pair then UI:SetValue("PabrikPairDisplay", "Item tidak ditemukan") end
            end)
            PabCard:Input("Embedded Pabrik Head Pad", "__PAD_PABRIK_ANCHOR__", "__PAD_PABRIK_ANCHOR_KEY__", "__PAD_PABRIK_ANCHOR_KEY__")
            PabCard:Slider("Break Tile Count (1-3)", "PabrikBreakCount", 1, 3, Pabrik.State.breakTileCount, " tile", function(v)
                Pabrik.SetBreakCount(v)
            end, 1)

            -- == DIRT FARM ==
            local DfCard = c:Card("Dirt Farm — Rotation World", nil, "Teleports", {
                Subtitle = "FIFO queue worlds, zigzag 2-wide, skip door/bedrock/lock"
            })
            DfCard:Input("Daftar World (pisah koma)", "DfRotationInput", "WORLD1, WORLD2", DirtFarm.State.rotationText or "", function(txt)
                DirtFarm.SetRotationWorlds(txt)
            end)
            DfCard:Button("Add World Saat Ini", "ADD", "Teleports", function()
                Core.EnsureInit()
                local curW = H.gt and cleanWorldName(H.gt.name) or ""
                if curW == "" then return end
                local list = DirtFarm.SetRotationWorlds(UI:GetValue("DfRotationInput") or DirtFarm.State.rotationText)
                local exists = false
                for _, w in ipairs(list) do if w == curW then exists = true; break end end
                if not exists then
                    list[#list + 1] = curW
                    local joined = table.concat(list, ", ")
                    DirtFarm.SetRotationWorlds(joined)
                    UI:SetValue("DfRotationInput", joined)
                    setDfStatus("Ditambahkan: " .. curW)
                end
            end)

            -- == MOVE BLOCK ==
            local MbCard = c:Card("Move Block", nil, "Teleports", {
                Subtitle = "Walk ke take, ambil item, walk ke drop, delay 2s, ulangi"
            })
            MbCard:Input("Status Move Block", "MoveBlockStatus", "Idle", MoveBlock.State.status)
        end),

        right = right(function(r)
            -- PNB Controls
            local PnbCtrl = r:Card("PNB Kontrol", "Run", "Bolt", {
                Subtitle = "Start/Stop PNB & lihat fase"
            })
            PnbCtrl:Button("[PNB] Start / Stop", "TOGGLE", "Bolt", function()
                local busy = Pabrik.State.running or DirtFarm.State.running or MoveBlock.State.running or AutoLeveling.State.running
                if busy and not PNB.State.running then
                    emitNotify("SYT", "Sorry, your task is do right now")
                    return
                end
                PNB.Toggle()
            end)
            PnbCtrl:Input("Block Terpilih", "PnbSelectedDisplay", "Belum dipilih", PNB.State.selectedBlockId and string.format("ID:%d", PNB.State.selectedBlockId) or "Belum dipilih")
            PnbCtrl:Input("Fase PNB", "PnbPhaseDisplay", "Idle", PNB.State.phase or "Idle")
            PnbCtrl:Input("Status PNB", "PnbStatusDisplay", "Idle", PNB.State.status or "Idle")

            -- Pabrik Controls
            local PabCtrl = r:Card("Pabrik Kontrol", "Run", "Bolt", {
                Subtitle = "Start/Stop Pabrik & pantau pair"
            })
            PabCtrl:Button("[PABRIK] Start / Stop", "TOGGLE", "Bolt", function()
                local busy = PNB.State.running or DirtFarm.State.running or MoveBlock.State.running or AutoLeveling.State.running
                if busy and not Pabrik.State.running then
                    emitNotify("SYT", "Sorry, your task is do right now")
                    return
                end
                Pabrik.Toggle()
            end)
            PabCtrl:Input("Status Pabrik", "PabrikStatusDisplay", "Idle", "Idle")
            PabCtrl:Input("Pair Block & Seed", "PabrikPairDisplay", "Belum diatur", "-")
            PabCtrl:Button("Set BreakPos Sekarang", "SET POS", "Teleports", function()
                Pabrik.SetBreakPos()
                UI:SetValue("PabrikBreakPosDisplay", Pabrik.State.breakPos and string.format("(%d,%d)", Pabrik.State.breakPos.x, Pabrik.State.breakPos.y) or "-")
            end)
            PabCtrl:Input("BreakPos", "PabrikBreakPosDisplay", "Belum diset", "-")

            -- Dirt Farm Controls
            local DfCtrl = r:Card("Dirt Farm Kontrol", "Run", "Bolt", {
                Subtitle = "Start/Stop DF"
            })
            DfCtrl:Button("[DF] Start / Stop", "TOGGLE", "Bolt", function()
                local busy = PNB.State.running or Pabrik.State.running or MoveBlock.State.running or AutoLeveling.State.running
                if busy and not DirtFarm.State.running then
                    emitNotify("SYT", "Sorry, your task is do right now")
                    return
                end
                DirtFarm.Toggle()
            end)
            DfCtrl:Input("Status Dirt Farm", "DfStatusDisplay", "Idle", DirtFarm.State.status or "Idle")

            -- Move Block Controls
            local MbCtrl = r:Card("Move Block Kontrol", "Move", "Bolt", {
                Subtitle = "Set posisi ambil & taruh, lalu start"
            })
            MbCtrl:Button("Set Take Pos (Posisi Sekarang)", "SET TAKE", "Teleports", function()
                MoveBlock.SetTake()
            end)
            MbCtrl:Button("Set Drop Pos (Posisi Sekarang)", "SET DROP", "Teleports", function()
                MoveBlock.SetDrop()
            end)
            MbCtrl:Button("[MOVE] Start / Stop", "TOGGLE", "Bolt", function()
                local busy = PNB.State.running or Pabrik.State.running or DirtFarm.State.running or AutoLeveling.State.running
                if busy and not MoveBlock.State.running then
                    emitNotify("SYT", "Sorry, your task is do right now")
                    return
                end
                MoveBlock.Toggle()
            end)

            -- Close
            local CloseCard = r:Card("Tutup Menu", nil, "Shield", {})
            CloseCard:Button("Tutup Menu Permanen", "CLOSE", "Shield", function()
                UIHooks.userDestroy = true
                if type(stopAllAutomationImpl) == "function" then
                    stopAllAutomationImpl("Menu ditutup permanen oleh user")
                end
                cleanupSYTGuiContainers(nil)
            end)
        end)
    })

    -- ═══ TAB 2: TOOLS ═══
    if UI.Category then UI:Category("Tools") end

    feature("Tools", "Tools")({
        center = center(function(c)
            c:Header("SYT Tools — Misc, Spam, Discord, Proxy", "Ghost/Fly/Zoom, Spam Chat, Discord Hook & Proxy Commands", "V2")

            -- == MISC ==
            local MiscMove = c:Card("Misc: Pergerakan & Visual", nil, "Teleports", {
                Subtitle = "Ghost/NoClip, Fly (max +5 atas, ±4 horizontal), Zoom 2.5x, Slow Fall"
            })
            MiscMove:Toggle("Fly Mode (WASD / Space / Touch)", "MiscFlyToggle", Misc.State.fly, function(on)
                Misc.SetFly(on)
            end)
            MiscMove:Slider("Kecepatan Fly", "MiscFlySpeed", 6, 45, Misc.State.flySpeed, " t/s", function(v)
                Misc.State.flySpeed = clamp(tonumber(v) or 14, 6, 45)
            end)
            MiscMove:Toggle("No Clip (Visual Ghost Only)", "MiscNoClipToggle", Misc.State.noClip, function(on)
                Misc.SetNoClip(on)
            end)
            MiscMove:Toggle("Zoom 2.5x (Max Zoom Out)", "MiscZoomToggle", false, function(on)
                pcall(function()
                    local Camera = workspace.CurrentCamera
                    if Camera then
                        if on then
                            Camera.FieldOfView = math.min(120, Camera.FieldOfView * 2.5)
                        else
                            Camera.FieldOfView = 70
                        end
                    end
                end)
            end)
            MiscMove:Toggle("Slow Fall (2x lebih lambat)", "MiscSlowFallToggle", false, function(on)
                pcall(function()
                    local char = LP and LP.Character
                    local hrp = char and char:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        local bg = hrp:FindFirstChild("SYT_SlowFall") or Instance.new("BodyVelocity")
                        if on then
                            bg.Name = "SYT_SlowFall"
                            bg.Velocity = Vector3.new(0, 0, 0)
                            bg.P = 500
                            bg.MaxForce = Vector3.new(0, 500, 0)
                            bg.Parent = hrp
                        else
                            local bf = hrp:FindFirstChild("SYT_SlowFall")
                            if bf then bf:Destroy() end
                        end
                    end
                end)
            end)
            MiscMove:Toggle("Skip Update Item (Freeze Inv)", "MiscSkipUpdateToggle", false, function(on)
                pcall(function()
                    GetcSkipper.SetBypassOption("bypassUiBlock", on)
                end)
            end)

            local MiscSys = c:Card("Misc: Safety & Roulette", nil, "Shield", {
                Subtitle = "God Mode, Fast Roulette, FPS Boost"
            })
            MiscSys:Toggle("SEEMS (Auto Stop jika bahaya)", "MiscSeemsToggle", Misc.State.seems, function(on)
                Misc.SetSeems(on)
            end)
            MiscSys:Toggle("God Mode (No HP Loss)", "MiscGodToggle", Misc.State.godMode, function(on)
                Misc.SetGodMode(on)
            end)
            MiscSys:Toggle("Fast Roulette (0-36 instan)", "MiscRouletteToggle", Misc.State.fastRoulette, function(on)
                Misc.SetFastRoulette(on)
            end)
            MiscSys:Toggle("FPS Boost (Hide BG/FX)", "MiscFpsBoost", Misc.State.fpsBoost, function(on)
                Misc.SetFpsBoost(on)
            end)

            -- == SPAM ==
            local SpamCard = c:Card("Spam Chat (Max 85 Karakter)", nil, "Bolt", {
                Subtitle = "Rainbow color ATAU prefix color (saling eksklusif)"
            })
            SpamCard:Input("Pesan Spam (max 85 char)", "SpamTextInput", "Ketik pesan di sini...", Spam.State.text, function(txt)
                Spam.State.text = tostring(txt or ""):sub(1, 85)
            end)
            SpamCard:Toggle("Rainbow Color (`1..`9 auto-cycle)", "SpamAutoColor", Spam.State.autoCycleColor, function(v)
                Spam.State.autoCycleColor = v
                if v then
                    -- Matikan prefix manual jika rainbow aktif
                    Spam.State.prefixColor = ""
                    if UI then UI:SetValue("SpamPrefixSelect", "None") end
                end
            end)
            SpamCard:Dropdown("Prefix Color (non-rainbow)", "SpamPrefixSelect",
                { "None", "`1", "`2", "`3", "`4", "`5", "`6", "`7", "`8", "`9" },
                (Spam.State.prefixColor ~= "" and Spam.State.prefixColor) or "None",
                function(v)
                    Spam.State.prefixColor = (v == "None") and "" or v
                    if v ~= "None" then
                        -- Matikan rainbow jika pilih prefix manual
                        Spam.State.autoCycleColor = false
                        if UI then UI:SetValue("SpamAutoColor", false) end
                    end
                end
            )
            SpamCard:Slider("Delay Kirim (3-7 detik)", "SpamDelaySec", 3.0, 7.0, clamp(Spam.State.delay, 3, 7), " s", function(v)
                Spam.State.delay = clamp(tonumber(v) or 5, 3, 7)
            end, 0.5)

            -- == DISCORD HOOK ==
            local DhCard = c:Card("Discord Hook (Farm Status)", nil, "Shield", {
                Subtitle = "POST pertama, lalu PATCH message ID agar tidak spam"
            })
            DhCard:Input("Webhook URL (max 300 char)", "SysDiscordUrlInput", "https://discord.com/api/webhooks/...", DiscordHook.State.url, function(txt)
                DiscordHook.State.url = tostring(txt or ""):sub(1, 300)
            end)
            DhCard:Slider("Interval Kirim (menit)", "DhDelayMin", 1, 5, math.floor(DiscordHook.State.delay / 60), " min", function(v)
                DiscordHook.State.delay = math.max(60, (tonumber(v) or 2) * 60)
            end, 1)
        end),

        right = right(function(r)
            -- Misc Controls
            local MiscCtrl = r:Card("Misc Status", "V1", "Shield", {})
            MiscCtrl:Input("Roulette Terakhir", "RouletteResultDisplay", "-", "-")
            MiscCtrl:Input("Status Follow", "FollowStatusDisplay", "Idle", Misc.State.followStatus or "Idle")
            MiscCtrl:Toggle("Auto Collect Sekitar", "MiscAutoCollectToggle", Misc.State.autoCollect, function(on)
                Misc.SetAutoCollect(on, Misc.State.autoCollectRadius, Misc.State.autoCollectStep)
            end)
            MiscCtrl:Button("Collect Drops Sekarang", "COLLECT", "Bolt", function()
                local res = Packets.Collect({ radius = 4, stepMoveIfFar = true, collectDelay = 0 })
                UI:SetValue("FollowStatusDisplay", string.format("Diambil: %d items", res.itemsTaken))
            end)

            -- ULTIMAX Status
            local UltCard = r:Card("ULTIMAX Protection", "Guard", "Shield", {
                Subtitle = "Anti-kick, firewall paket, anti-back"
            })
            UltCard:Input("Status ULTIMAX", "UltimaxStatusDisplay", "Ready", GetcSkipper.GetUltimaxStatusText())
            UltCard:Toggle("ULTIMAX Master ON", "UltimaxMaster", GetcSkipper.State.ultimaxEnabled ~= false, function(v)
                GetcSkipper.SetBypassOption("ultimaxEnabled", v == true)
            end)
            UltCard:Toggle("Anti-Kick Shield", "GuardAntiKickShield", GetcSkipper.State.antiKickShield ~= false, function(v)
                GetcSkipper.SetBypassOption("antiKickShield", v == true)
            end)
            UltCard:Button("Aktifkan ULTIMAX ALL SAFE", "ULTIMAX", "Shield", function()
                local gOk, ncOk = GetcSkipper.EnableUltimaxAllSafe()
                emitNotify("ULTIMAX", string.format("ALL SAFE | NC=%s GC=%s", tostring(ncOk), tostring(gOk)))
            end)

            -- Spam Controls
            local SpamCtrl = r:Card("Spam Kontrol", "Chat", "Bolt", {
                Subtitle = "Start/Stop spam chat"
            })
            SpamCtrl:Button("[SPAM] Start / Stop", "TOGGLE", "Bolt", function()
                if not Spam.State.running then
                    Spam.State.text = tostring(UI:GetValue("SpamTextInput") or ""):sub(1, 85)
                end
                Spam.Toggle()
            end)
            SpamCtrl:Input("Status Spam", "SpamStatusDisplay", "Idle", Spam.State.status or "Idle")

            -- Discord Hook Controls
            local DhCtrl = r:Card("Discord Hook Kontrol", "Discord", "Shield", {
                Subtitle = "Toggle on/off hook"
            })
            DhCtrl:Toggle("Discord Hook ON/OFF", "DhEnabledToggle", DiscordHook.State.enabled, function(v)
                DiscordHook.State.url = UI:GetValue("SysDiscordUrlInput") or ""
                if v then DiscordHook.Start() else DiscordHook.Stop() end
            end)
            DhCtrl:Input("Message ID Tersimpan", "DhMessageIdDisplay", "-", DiscordHook.State.messageId or "-")

            -- Proxy Commands Info
            local ProxyCard = r:Card("Proxy Commands (/cmd)", "Proxy", "Player", {
                Subtitle = "Ketik di chat game: /reme /clothes /cal /info /get /cn /news"
            })
            ProxyCard:Input("Commands Tersedia", "ProxyCmdList", "-", "/reme /cal /info /get /cn /news /clothes")
            ProxyCard:Button("Re-Install Hook Command", "HOOK", "Shield", function()
                pcall(ProxyCommands.Install)
                emitNotify("Proxy", "Chat command hook dipasang ulang")
            end)
        end)
    })

    if type(buildMountedCanvasesFn) == "function" then
        buildMountedCanvasesFn()
    end
    if UI and type(UI.SyncNavCanvas) == "function" then
        pcall(UI.SyncNavCanvas)
    end
end


-- ═══════════════════════════════════════════════════════════════════════════
-- 8. EMBEDDED CANVAS MOUNTING + SIDEBAR IN-GAME ACCOUNT SYNC
-- ═══════════════════════════════════════════════════════════════════════════
local buttonMap = {}

local function findAllTextBoxesWithKey(key)
    local found = {}
    local function scanRoot(root)
        if typeof(root) ~= "Instance" then return end
        local okD, desc = pcall(root.GetDescendants, root)
        if not okD or type(desc) ~= "table" then return end
        for _, d in ipairs(desc) do
            if d:IsA("TextBox") then
                local okT, txt = pcall(function() return d.Text end)
                if okT and txt == key then
                    found[#found + 1] = d
                end
            end
        end
    end
    local ownSg = getActiveMenuGui()
    if ownSg then
        scanRoot(ownSg)
        if #found > 0 then return found end
    end
    for _, root in ipairs(getAllGuiRoots()) do
        if root ~= ownSg then
            scanRoot(root)
            if #found > 0 then return found end
        end
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
            if not ch:IsA("UICorner") and not ch:IsA("UIStroke") then
                ch:Destroy()
            end
        end
        rowContainer.Size = UDim2.new(1, 0, 0, heightPx)
        rowContainer.BackgroundColor3 = Color3.fromRGB(11, 14, 20)
        rowContainer.ClipsDescendants = true
        local okB, bErr = xpcall(buildFn, debug.traceback, rowContainer)
        if not okB then
            warn("[SYT Canvas Error " .. tostring(anchorKey) .. "]: " .. tostring(bErr))
        end
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

-- Responsive Button Binder: sinkronkan teks & warna tombol Start/Stop otomatis
local function scanResponsiveButtons()
    local specs = {
        { prefix = "[PNB]",    getState = function() return PNB.State.running,      "STOP PNB",    "START PNB",    "[PNB] AKTIF (Klik untuk STOP)",    "[PNB] Start / Stop Engine" end },
        { prefix = "[PABRIK]", getState = function() return Pabrik.State.running,   "STOP PABRIK", "START PABRIK", "[PABRIK] AKTIF (Klik untuk STOP)", "[PABRIK] Start / Stop Auto" end },
        { prefix = "[DF]",     getState = function() return DirtFarm.State.running, "STOP DF",     "START DF",     "[DF] AKTIF (Klik untuk STOP)",     "[DF] Start / Stop Dirt Farm" end },
        { prefix = "[SPAM]",   getState = function() return Spam.State.running,     "STOP SPAM",   "START SPAM",   "[SPAM] AKTIF (Klik untuk STOP)",   "[SPAM] Start / Stop Chat" end },
        { prefix = "[GAP TP]", getState = function() return tpState.patrolOn,       "STOP TP",     "START TP",     "[GAP TP] AKTIF (Klik untuk STOP)", "[GAP TP] Start / Stop Random Teleport" end },
    }
    local scanRoots = {}
    local ownSg = getActiveMenuGui()
    if ownSg then
        scanRoots[1] = ownSg
    else
        scanRoots = getAllGuiRoots()
    end
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
                                            if ch:IsA("TextLabel") and ch ~= d and ch.Text == "TOGGLE" then
                                                badgeTxt = ch
                                                badgePill = ch.Parent
                                                break
                                            end
                                        end
                                        buttonMap[sp.prefix] = { lbl = d, badgeTxt = badgeTxt, badgePill = badgePill, getState = sp.getState }
                                        btn.MouseButton1Click:Connect(function()
                                            task.delay(0.15, function()
                                                if UIHooks.updateButtons then UIHooks.updateButtons() end
                                            end)
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
                                            UIHooks.sidebarNameLbl = sib
                                            break
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
    for _, item in pairs(buttonMap) do
        if item.lbl and item.lbl.Parent then
            local active, onBadge, offBadge, onLbl, offLbl = item.getState()
            item.lbl.Text = active and onLbl or offLbl
            if item.badgeTxt and item.badgeTxt.Parent then
                item.badgeTxt.Text = active and onBadge or offBadge
            end
            if item.badgePill and item.badgePill.Parent and item.badgePill:IsA("Frame") then
                item.badgePill.BackgroundColor3 = active and Color3.fromRGB(220, 38, 38) or Color3.fromRGB(16, 185, 129)
                item.badgePill.BackgroundTransparency = 0
            end
        end
    end
end

buildMountedCanvasesFn = function()
    table.clear(buttonMap)

    -- A. MOUNT 1: EMBEDDED 2D WORLD MAP RENDERER (__WORLD_MAP_ANCHOR_KEY__)
    mountEmbeddedCanvas("__WORLD_MAP_ANCHOR_KEY__", 285, function(rowContainer)
        local scroller = rowContainer:FindFirstAncestorOfClass("ScrollingFrame")

        local topBar = Instance.new("Frame")
        topBar.Size = UDim2.new(1, -12, 0, 22)
        topBar.Position = UDim2.fromOffset(6, 5)
        topBar.BackgroundTransparency = 1
        topBar.Parent = rowContainer

        local modes = {
            { id = "TP",          label = "Mode: TP" },
            { id = "PABRIK_TILE", label = "Pabrik Tile" },
            { id = "PABRIK_LINE", label = "Pabrik Line" },
            { id = "BREAK_POS",   label = "Break Pos" },
        }
        local modeBtns = {}
        local function refreshModeBtns()
            for id, b in pairs(modeBtns) do
                local on = (tpState.mapClickMode == id)
                b.BackgroundColor3 = on and Color3.fromRGB(56, 189, 248) or Color3.fromRGB(31, 35, 44)
                b.TextColor3 = on and Color3.new(0, 0, 0) or Color3.fromRGB(226, 232, 240)
            end
        end
        for i, m in ipairs(modes) do
            local b = Instance.new("TextButton")
            b.Size = UDim2.new(0.24, -3, 1, 0)
            b.Position = UDim2.new((i - 1) * 0.25, 0, 0, 0)
            b.BorderSizePixel = 0
            b.Font = Enum.Font.GothamBold
            b.TextSize = 10
            b.Text = m.label
            b.Parent = topBar
            Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
            b.MouseButton1Click:Connect(function()
                tpState.mapClickMode = m.id
                refreshModeBtns()
            end)
            modeBtns[m.id] = b
        end
        refreshModeBtns()

        local mapView = Instance.new("Frame")
        mapView.Size = UDim2.new(1, -12, 1, -62)
        mapView.Position = UDim2.fromOffset(6, 31)
        mapView.BackgroundColor3 = Color3.fromRGB(24, 52, 92)
        mapView.BorderSizePixel = 0
        mapView.ClipsDescendants = true
        mapView.Active = true
        mapView.Parent = rowContainer

        local mapCanvas = Instance.new("Frame")
        mapCanvas.BackgroundColor3 = Color3.new(1, 1, 1)
        mapCanvas.BorderSizePixel = 0
        mapCanvas.ZIndex = (mapView.ZIndex or 1) + 1
        mapCanvas.Parent = mapView
        Instance.new("UIStroke", mapCanvas).Color = Color3.fromRGB(70, 86, 114)

        -- Lapisan Sky + Underground halus (BackgroundColor3 putih agar UIGradient tampil murni tanpa gelap)
        local skyGrad = Instance.new("UIGradient", mapCanvas)
        skyGrad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(64, 148, 214)),
            ColorSequenceKeypoint.new(0.45, Color3.fromRGB(118, 190, 236)),
            ColorSequenceKeypoint.new(0.46, Color3.fromRGB(54, 40, 32)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 23, 20)),
        })
        skyGrad.Rotation = 90

        -- Penanda top-layer permanen: Crosshair & Beacon Player ("YOU"), Tile Terpilih & BreakPos
        local mZ = (mapCanvas.ZIndex or 2)
        local crossH = Instance.new("Frame")
        crossH.Size = UDim2.new(1, 0, 0, 1)
        crossH.AnchorPoint = Vector2.new(0, 0.5)
        crossH.BackgroundColor3 = Color3.fromRGB(250, 204, 21)
        crossH.BackgroundTransparency = 0.55
        crossH.BorderSizePixel = 0
        crossH.ZIndex = mZ + 20
        crossH.Parent = mapCanvas

        local crossV = Instance.new("Frame")
        crossV.Size = UDim2.new(0, 1, 1, 0)
        crossV.AnchorPoint = Vector2.new(0.5, 0)
        crossV.BackgroundColor3 = Color3.fromRGB(250, 204, 21)
        crossV.BackgroundTransparency = 0.55
        crossV.BorderSizePixel = 0
        crossV.ZIndex = mZ + 20
        crossV.Parent = mapCanvas

        local selBox = Instance.new("Frame")
        selBox.BackgroundColor3 = Color3.fromRGB(56, 189, 248)
        selBox.BackgroundTransparency = 0.55
        selBox.BorderSizePixel = 0
        selBox.Visible = false
        selBox.ZIndex = mZ + 21
        selBox.Parent = mapCanvas
        local selStroke = Instance.new("UIStroke", selBox)
        selStroke.Color = Color3.new(1, 1, 1)
        selStroke.Thickness = 1.6

        local breakBox = Instance.new("Frame")
        breakBox.BackgroundColor3 = Color3.fromRGB(249, 115, 22)
        breakBox.BackgroundTransparency = 0.45
        breakBox.BorderSizePixel = 0
        breakBox.Visible = false
        breakBox.ZIndex = mZ + 21
        breakBox.Parent = mapCanvas
        local breakStroke = Instance.new("UIStroke", breakBox)
        breakStroke.Color = Color3.fromRGB(255, 237, 213)
        breakStroke.Thickness = 1.4

        local playerDot = Instance.new("Frame")
        playerDot.AnchorPoint = Vector2.new(0.5, 0.5)
        playerDot.Size = UDim2.fromOffset(10, 10)
        playerDot.BackgroundColor3 = Color3.fromRGB(250, 204, 21)
        playerDot.BorderSizePixel = 0
        playerDot.ZIndex = mZ + 24
        playerDot.Parent = mapCanvas
        Instance.new("UICorner", playerDot).CornerRadius = UDim.new(1, 0)
        local playerStroke = Instance.new("UIStroke", playerDot)
        playerStroke.Color = Color3.new(1, 1, 1)
        playerStroke.Thickness = 1.8

        local youTag = Instance.new("TextLabel")
        youTag.Size = UDim2.fromOffset(28, 12)
        youTag.AnchorPoint = Vector2.new(0.5, 1)
        youTag.BackgroundColor3 = Color3.fromRGB(15, 23, 42)
        youTag.BackgroundTransparency = 0.12
        youTag.BorderSizePixel = 0
        youTag.Font = Enum.Font.Code
        youTag.TextSize = 9
        youTag.TextColor3 = Color3.fromRGB(250, 204, 21)
        youTag.Text = "YOU"
        youTag.ZIndex = mZ + 25
        youTag.Parent = mapCanvas
        Instance.new("UICorner", youTag).CornerRadius = UDim.new(0, 3)

        local mapHitOverlay = Instance.new("TextButton")
        mapHitOverlay.Size = UDim2.fromScale(1, 1)
        mapHitOverlay.BackgroundTransparency = 1
        mapHitOverlay.BorderSizePixel = 0
        mapHitOverlay.Text = ""
        mapHitOverlay.AutoButtonColor = false
        mapHitOverlay.ZIndex = mZ + 28
        mapHitOverlay.Parent = mapCanvas

        local worldHud = Instance.new("TextLabel")
        worldHud.Size = UDim2.new(0, 230, 0, 18)
        worldHud.Position = UDim2.fromOffset(6, 4)
        worldHud.BackgroundColor3 = Color3.fromRGB(10, 14, 22)
        worldHud.BackgroundTransparency = 0.25
        worldHud.BorderSizePixel = 0
        worldHud.Font = Enum.Font.Code
        worldHud.TextSize = 10
        worldHud.TextColor3 = Color3.fromRGB(248, 250, 252)
        worldHud.Text = " WORLD: - | POS: (-, -) "
        worldHud.ZIndex = mZ + 32
        worldHud.Parent = mapView
        Instance.new("UICorner", worldHud).CornerRadius = UDim.new(0, 4)

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, -12, 0, 24)
    bar.Position = UDim2.new(0, 6, 1, -27)
    bar.BackgroundTransparency = 1
    bar.Parent = rowContainer

    local infoLbl = Instance.new("TextLabel")
    infoLbl.Size = UDim2.new(1, -160, 1, 0)
    infoLbl.BackgroundTransparency = 1
    infoLbl.Font = Enum.Font.Code
    infoLbl.TextSize = 10
    infoLbl.TextColor3 = Color3.fromRGB(203, 213, 225)
    infoLbl.TextXAlignment = Enum.TextXAlignment.Left
    infoLbl.TextTruncate = Enum.TextTruncate.AtEnd
    infoLbl.Text = "Ketuk tile pada peta sesuai mode..."
    infoLbl.Parent = bar

    local function makeBtn(txt, xo, w)
        local b = Instance.new("TextButton")
        b.Size = UDim2.fromOffset(w or 26, 22)
        b.Position = UDim2.new(1, xo, 0, 1)
        b.BackgroundColor3 = Color3.fromRGB(31, 35, 44)
        b.Font = Enum.Font.GothamBold
        b.TextSize = 11
        b.TextColor3 = Color3.fromRGB(240, 244, 250)
        b.Text = txt
        b.BorderSizePixel = 0
        b.Parent = bar
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
        return b
    end
    local fitBtn     = makeBtn("FIT", -154, 32)
    local zoomInBtn  = makeBtn("+",   -118, 26)
    local zoomOutBtn = makeBtn("-",    -88, 26)
    local tpBtn      = makeBtn("TP",   -58, 54)
    tpBtn.BackgroundColor3 = Color3.fromRGB(34, 197, 94)
    tpBtn.TextColor3 = Color3.new(0, 0, 0)

    local mapTilePx, mapPanX, mapPanY = 3.2, 6, 6
    local didFit, fittedW, fittedH, lastDraw, userPanned = false, nil, nil, 0, false
    local mapPool = {}

    local function getScale()
        local h = rowContainer.AbsoluteSize.Y
        return (h > 10) and clamp(h / 285, 0.25, 4) or 1
    end

    local function updatePlayerOverlay(selfPos, w, h)
        selfPos = selfPos or Core.ReadPos()
        w = w or ((H.gt and H.gt.w) or 100)
        h = h or ((H.gt and H.gt.h) or 60)
        local fx = (selfPos.tx + 0.5) / w
        local fy = (selfPos.ty + 0.5) / h
        local dsz = clamp(mapTilePx + 4, 9, 14)
        crossH.Position = UDim2.fromScale(0, fy)
        crossV.Position = UDim2.fromScale(fx, 0)
        playerDot.Size = UDim2.fromOffset(dsz, dsz)
        playerDot.Position = UDim2.fromScale(fx, fy)
        if selfPos.ty < 4 then
            youTag.AnchorPoint = Vector2.new(0.5, 0)
            youTag.Position = UDim2.new(fx, 0, fy, dsz * 0.5 + 3)
        else
            youTag.AnchorPoint = Vector2.new(0.5, 1)
            youTag.Position = UDim2.new(fx, 0, fy, -(dsz * 0.5 + 3))
        end
    end

    local function updateTransform()
        local w, h = (H.gt and H.gt.w) or 100, (H.gt and H.gt.h) or 60
        local s = getScale()
        local vw, vh = math.max(100, mapView.AbsoluteSize.X / s), math.max(80, mapView.AbsoluteSize.Y / s)
        local cw, ch = w * mapTilePx, h * mapTilePx
        mapPanX = (cw <= vw) and math.floor((vw - cw) * 0.5) or clamp(mapPanX, vw - cw - 8, 8)
        mapPanY = (ch <= vh) and math.floor((vh - ch) * 0.5) or clamp(mapPanY, vh - ch - 8, 8)
        mapCanvas.Size = UDim2.fromOffset(cw, ch)
        mapCanvas.Position = UDim2.fromOffset(mapPanX, mapPanY)
        updatePlayerOverlay(nil, w, h)
    end

    local function fitMap()
        local w, h = (H.gt and H.gt.w) or 100, (H.gt and H.gt.h) or 60
        local s = getScale()
        local vw, vh = math.max(120, mapView.AbsoluteSize.X / s), math.max(80, mapView.AbsoluteSize.Y / s)
        mapTilePx = clamp(math.min((vw - 10) / w, (vh - 10) / h), 2, 18)
        mapPanX = math.floor((vw - w * mapTilePx) * 0.5)
        mapPanY = math.floor((vh - h * mapTilePx) * 0.5)
        didFit, fittedW, fittedH, userPanned = true, w, h, false
        updateTransform()
    end

    local function applyZoom(newPx)
        local w, h = (H.gt and H.gt.w) or 100, (H.gt and H.gt.h) or 60
        local s = getScale()
        local vw, vh = math.max(100, mapView.AbsoluteSize.X / s), math.max(80, mapView.AbsoluteSize.Y / s)
        local oldPx = mapTilePx
        local clamped = clamp(newPx, 2, 18)
        if math.abs(clamped - oldPx) < 0.01 then return end
        local cx, cy
        if not userPanned or (w * oldPx <= vw + 4 and h * oldPx <= vh + 4) then
            -- Zoom otomatis mengunci posisi player agar posisi & HUD bar tetap presisi tanpa bergeser
            local sp = Core.ReadPos()
            cx, cy = sp.tx + 0.5, sp.ty + 0.5
        else
            cx, cy = (vw * 0.5 - mapPanX) / oldPx, (vh * 0.5 - mapPanY) / oldPx
        end
        mapTilePx = clamped
        mapPanX = vw * 0.5 - cx * clamped
        mapPanY = vh * 0.5 - cy * clamped
        updateTransform()
    end

    local function getBox(idx, z, col, trans, round)
        local f = mapPool[idx]
        if not f then
            f = Instance.new("Frame")
            f.BorderSizePixel = 0
            f.Parent = mapCanvas
            Instance.new("UICorner", f)
            mapPool[idx] = f
        end
        f.Visible = true
        f.ZIndex = (mapCanvas.ZIndex or 1) + z
        f.BackgroundColor3 = col
        f.BackgroundTransparency = trans or 0
        local uc = f:FindFirstChildOfClass("UICorner")
        if uc then uc.CornerRadius = UDim.new(round and 1 or 0, 0) end
        return f
    end

    local function classifyMapColor(id, info)
        if id == 8 then return Color3.fromRGB(48, 54, 66), "bed" end
        if info then
            if info.hurts then return Color3.fromRGB(239, 68, 34), "lava" end
            if info.deadly then return Color3.fromRGB(220, 38, 38), "dead" end
            if info.swim then return Color3.fromRGB(56, 165, 240), "water" end
            if info.lock or info.worldKey or info.area then return Color3.fromRGB(250, 204, 21), "lock" end
            if info.door or info.entrance or id == 6 then return Color3.fromRGB(56, 189, 248), "door" end
            local ln = string.lower(info.name or "")
            if string.find(ln, "grass", 1, true) or string.find(ln, "leaf", 1, true) then
                return Color3.fromRGB(76, 175, 80), "grass"
            elseif string.find(ln, "lava", 1, true) or string.find(ln, "magma", 1, true) then
                return Color3.fromRGB(239, 68, 34), "lava"
            elseif string.find(ln, "rock", 1, true) or string.find(ln, "stone", 1, true) or string.find(ln, "marble", 1, true) or string.find(ln, "obsidian", 1, true) then
                return Color3.fromRGB(130, 140, 155), "rock"
            elseif string.find(ln, "sand", 1, true) or string.find(ln, "desert", 1, true) then
                return Color3.fromRGB(224, 198, 128), "sand"
            elseif info.platform or string.find(ln, "wood", 1, true) or string.find(ln, "plank", 1, true) then
                return Color3.fromRGB(168, 114, 62), "wood"
            elseif id == 2 or string.find(ln, "dirt", 1, true) or string.find(ln, "mud", 1, true) then
                return Color3.fromRGB(122, 82, 48), "dirt"
            elseif info.tint and info.tint ~= Color3.new(1, 1, 1) and info.tint ~= Color3.new(0, 0, 0) then
                return info.tint, "id_" .. tostring(id)
            end
        end
        return Color3.fromRGB(115, 130, 155), "sol"
    end

    local function renderMap(force)
        if not rowContainer or not rowContainer.Parent or not mapView.Visible then return end
        if mapView.AbsoluteSize.X <= 10 or mapView.AbsoluteSize.Y <= 10 then return end
        local now = os.clock()
        if not force and (now - lastDraw) < 0.25 then return end
        lastDraw = now

        Core.EnsureInit()
        local gt = H.gt
        local selfPos = Core.ReadPos()
        worldHud.Text = string.format(" %s | POS (%d, %d) ", (gt and gt.name ~= "" and gt.name) or "-", selfPos.sx, selfPos.sy)

        local w, h = (gt and gt.w) or 100, (gt and gt.h) or 60
        if not didFit or fittedW ~= w or fittedH ~= h then fitMap() else updateTransform() end
        if not gt or not gt.fg then return end

        local px, used = mapTilePx, 0
        -- Gunakan koordinat normalized UDim2.fromScale agar semua objek 100% terkunci pada grid saat di-zoom!
        -- 1. Background cave walls
        if type(gt.bg) == "table" then
            for y = 0, h - 1 do
                local fgRow, bgRow = gt.fg[y], gt.bg[y]
                if bgRow then
                    local x = 0
                    while x < w do
                        if (bgRow[x] or 0) ~= 0 and (not fgRow or (fgRow[x] or 0) == 0) then
                            local sx = x
                            while x < w and (bgRow[x] or 0) ~= 0 and (not fgRow or (fgRow[x] or 0) == 0) do x += 1 end
                            used += 1
                            local f = getBox(used, 1, Color3.fromRGB(68, 52, 42), 0.15, false)
                            f.AnchorPoint = Vector2.zero
                            f.Position = UDim2.fromScale(sx / w, y / h)
                            f.Size = UDim2.fromScale((x - sx) / w, 1 / h)
                        else
                            x += 1
                        end
                    end
                end
            end
        end

        -- 2. Terrain, Lava, Water, Locks, Seeds, Doors
        for y = 0, h - 1 do
            local row = gt.fg[y]
            if row then
                local x = 0
                while x < w do
                    local id = row[x] or 0
                    local info = Core.GetItemInfo(id)
                    if id ~= 0 and ((info and (info.solid or info.platform or info.hurts or info.deadly or info.swim)) or not info) then
                        local col, keyTag = classifyMapColor(id, info)
                        local sx = x
                        while x < w do
                            local nid = row[x] or 0
                            local ninfo = Core.GetItemInfo(nid)
                            local isTile = (nid ~= 0) and ((ninfo and (ninfo.solid or ninfo.platform or ninfo.hurts or ninfo.deadly or ninfo.swim)) or not ninfo)
                            if not isTile then break end
                            local _, nk = classifyMapColor(nid, ninfo)
                            if nk ~= keyTag then break end
                            x += 1
                        end
                        used += 1
                        local f = getBox(used, 2, col, 0, false)
                        f.AnchorPoint = Vector2.zero
                        f.Position = UDim2.fromScale(sx / w, y / h)
                        f.Size = UDim2.fromScale((x - sx) / w, 1 / h)
                    else
                        if info and (info.kind == "seed" or info.door or info.entrance or info.lock or id == 6) then
                            used += 1
                            local col
                            if info.kind == "seed" then
                                col = Core.IsTreeRipe(x, y) and Color3.fromRGB(250, 204, 21) or Color3.fromRGB(34, 197, 94)
                            else
                                col = select(1, classifyMapColor(id, info))
                            end
                            local f = getBox(used, 3, col, 0, false)
                            f.AnchorPoint = Vector2.zero
                            f.Position = UDim2.fromScale(x / w, y / h)
                            f.Size = UDim2.fromScale(1 / w, 1 / h)
                        end
                        x += 1
                    end
                end
            end
        end

        -- 3. Drops (Cyan = Gems, Amber = Items)
        if type(gt.dropList) == "function" then
            local okD, drops = pcall(gt.dropList)
            if okD and type(drops) == "table" then
                for _, d in ipairs(drops) do
                    if type(d) == "table" and d.x and d.y and (d.n or 0) > 0 then
                        used += 1
                        local f = getBox(used, 3, (d.id == 112) and Color3.fromRGB(103, 232, 249) or Color3.fromRGB(251, 191, 36), 0, true)
                        f.AnchorPoint = Vector2.new(0.5, 0.5)
                        f.Position = UDim2.fromScale(d.x / w, (d.y - 0.5) / h)
                        local ds = clamp(px * 0.65, 4, 9)
                        f.Size = UDim2.fromOffset(ds, ds)
                    end
                end
            end
        end

        -- 4. Auto Pabrik connected horizontal lines (-----) (Purple) & breakPos (Orange)
        for _, seg in ipairs(Pabrik.GetConnectedLines()) do
            used += 1
            local f = getBox(used, 4, Color3.fromRGB(168, 85, 247), 0.12, false)
            f.AnchorPoint = Vector2.zero
            local hRatio = (seg.len > 1) and 0.72 or 1
            local yOff = (seg.len > 1) and 0.14 or 0
            f.Position = UDim2.fromScale(seg.x1 / w, (seg.y + yOff) / h)
            f.Size = UDim2.fromScale(seg.len / w, hRatio / h)
        end
        if Pabrik.State.breakPos then
            breakBox.Visible = true
            breakBox.Position = UDim2.fromScale(Pabrik.State.breakPos.x / w, Pabrik.State.breakPos.y / h)
            breakBox.Size = UDim2.fromScale(1 / w, 1 / h)
        else
            breakBox.Visible = false
        end

        -- 5. Selected TP tile (Cyan/Red)
        if tpState.selectedX and tpState.selectedY then
            local ok = Core.ValidateTile(tpState.selectedX, tpState.selectedY)
            local col = ok and Color3.fromRGB(56, 189, 248) or Color3.fromRGB(239, 68, 68)
            selBox.Visible = true
            selBox.BackgroundColor3 = col
            selBox.AnchorPoint = Vector2.new(0.5, 0.5)
            selBox.Position = UDim2.fromScale((tpState.selectedX + 0.5) / w, (tpState.selectedY + 0.5) / h)
            local minFracW = math.max(1 / w, 7 / math.max(w * px, 1))
            local minFracH = math.max(1 / h, 7 / math.max(h * px, 1))
            selBox.Size = UDim2.fromScale(minFracW, minFracH)
        else
            selBox.Visible = false
        end

        -- 6. Other in-world players (Red dot) + Self (Crosshair + Bright Yellow Pin "YOU")
        for _, op in ipairs(Core.GetInWorldPlayers(false)) do
            if op.tx and op.ty then
                used += 1
                local f = getBox(used, 6, Color3.fromRGB(244, 63, 94), 0, true)
                f.AnchorPoint = Vector2.new(0.5, 0.5)
                f.Position = UDim2.fromScale((op.tx + 0.5) / w, (op.ty + 0.5) / h)
                local dsz = clamp(px + 2, 6, 12)
                f.Size = UDim2.fromOffset(dsz, dsz)
            end
        end

        updatePlayerOverlay(selfPos, w, h)

        for i = used + 1, #mapPool do mapPool[i].Visible = false end
    end
    UIHooks.refreshMap = renderMap
    mapView:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        didFit = false
        renderMap(true)
    end)
    local function onTabShow()
        if (not scroller or scroller.Visible) and rowContainer.Visible then
            fitMap()
            renderMap(true)
        end
    end
    rowContainer:GetPropertyChangedSignal("Visible"):Connect(onTabShow)
    if scroller then scroller:GetPropertyChangedSignal("Visible"):Connect(onTabShow) end

    -- Kalibrasi otomatis koordinat pointer (Mouse / Touch / Android Cutout / gethui) dari tombol kecil UI
    local calib = { Mouse = {}, Touch = {} }
    local function learnCalibFromBtn(btn, inp)
        if not inp or not btn then return end
        local okIn, tl = pcall(function() return GuiService:GetGuiInset() end)
        if not okIn or not tl then return end
        local key = (inp.UserInputType == Enum.UserInputType.Touch) and "Touch" or "Mouse"
        local bp, bs = btn.AbsolutePosition, btn.AbsoluteSize
        local px, py = inp.Position.X, inp.Position.Y
        if tl.Y > bs.Y + 4 then
            local rawIn = (py >= bp.Y - 3 and py <= bp.Y + bs.Y + 3)
            local insIn = (py + tl.Y >= bp.Y - 3 and py + tl.Y <= bp.Y + bs.Y + 3)
            if rawIn and not insIn then calib[key].dy = 0
            elseif insIn and not rawIn then calib[key].dy = tl.Y end
        end
        if tl.X > bs.X + 4 then
            local rawIn = (px >= bp.X - 3 and px <= bp.X + bs.X + 3)
            local insIn = (px + tl.X >= bp.X - 3 and px + tl.X <= bp.X + bs.X + 3)
            if rawIn and not insIn then calib[key].dx = 0
            elseif insIn and not rawIn then calib[key].dx = tl.X end
        end
    end
    local function attachCalib(b)
        b.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
                learnCalibFromBtn(b, inp)
            end
        end)
    end
    for _, mb in pairs(modeBtns) do attachCalib(mb) end
    attachCalib(fitBtn); attachCalib(zoomInBtn); attachCalib(zoomOutBtn); attachCalib(tpBtn)
    task.defer(function()
        local sg = mapView:FindFirstAncestorOfClass("ScreenGui")
        if sg then
            for _, d in ipairs(sg:GetDescendants()) do
                if d:IsA("TextButton") and d ~= mapHitOverlay and d.AbsoluteSize.Y > 4 and d.AbsoluteSize.Y <= 52 then
                    attachCalib(d)
                end
            end
        end
    end)

    local function resolvePointerScreenPos(inp)
        local inpType = inp.UserInputType
        local key = (inpType == Enum.UserInputType.Touch) and "Touch" or "Mouse"
        local okIn, tl = pcall(function() return GuiService:GetGuiInset() end)
        tl = (okIn and tl) or Vector2.zero
        local sg = mapView:FindFirstAncestorOfClass("ScreenGui")
        local sgPos = (sg and sg.AbsolutePosition) or Vector2.zero

        local cx, cy = inp.Position.X, inp.Position.Y
        if calib[key].dx ~= nil or calib[key].dy ~= nil then
            local dx = (calib[key].dx ~= nil) and calib[key].dx or ((sg and sg.IgnoreGuiInset and sgPos.Magnitude < 2) and tl.X or 0)
            local dy = (calib[key].dy ~= nil) and calib[key].dy or ((sg and sg.IgnoreGuiInset and sgPos.Magnitude < 2) and tl.Y or 0)
            return cx + dx, cy + dy
        end
        if inpType == Enum.UserInputType.MouseButton1 then
            local okMl, ml = pcall(function() return UserInputService:GetMouseLocation() end)
            if okMl and ml then
                local vp, vs = mapView.AbsolutePosition, mapView.AbsoluteSize
                if ml.X >= vp.X - 6 and ml.X <= vp.X + vs.X + 6 and ml.Y >= vp.Y - 6 and ml.Y <= vp.Y + vs.Y + 6 then
                    return ml.X, ml.Y
                end
            end
        end
        if sg and sg.IgnoreGuiInset and sgPos.Magnitude < 2 then
            return cx + tl.X, cy + tl.Y
        end
        return cx, cy
    end

    local function handleMapTap(cx, cy)
        local vp, vs = mapView.AbsolutePosition, mapView.AbsoluteSize
        if cx < vp.X or cy < vp.Y or cx > vp.X + vs.X or cy > vp.Y + vs.Y then return end
        local absPos, absSize = mapCanvas.AbsolutePosition, mapCanvas.AbsoluteSize
        local maxW, maxH = (H.gt and H.gt.w) or 100, (H.gt and H.gt.h) or 60
        local rx, ry = cx - absPos.X, cy - absPos.Y
        if absSize.X <= 1 or absSize.Y <= 1 then return end
        if rx < -6 or ry < -6 or rx > absSize.X + 6 or ry > absSize.Y + 6 then return end
        local tx = clamp(math.floor((clamp(rx, 0, absSize.X - 0.01) / absSize.X) * maxW), 0, maxW - 1)
        local ty = clamp(math.floor((clamp(ry, 0, absSize.Y - 0.01) / absSize.Y) * maxH), 0, maxH - 1)

        if tpState.mapClickMode == "PABRIK_TILE" then
            local added = Pabrik.ToggleTile(tx, ty)
            infoLbl.Text = string.format("Pabrik Tile (%d, %d): %s", tx, ty, added and "ON" or "OFF")
        elseif tpState.mapClickMode == "PABRIK_LINE" then
            local added = Pabrik.ToggleLine(ty, tx)
            infoLbl.Text = string.format("Pabrik Line Y=%d: %s", ty, added and "1 LINE CONNECTED" or "UNSELECTED")
        elseif tpState.mapClickMode == "BREAK_POS" then
            Pabrik.SetBreakPos(tx, ty)
            infoLbl.Text = string.format("BreakPos diset -> (%d, %d)", tx, ty)
        else
            local ok, msg = Core.ValidateTile(tx, ty)
            tpState.selectedX, tpState.selectedY = tx, ty
            UI:SetValue("TpManualX", tostring(tx))
            UI:SetValue("TpManualY", tostring(ty))
            UI:SetValue("ValidStatusDisplay", msg)
            infoLbl.Text = msg
            infoLbl.TextColor3 = ok and Color3.fromRGB(56, 189, 248) or Color3.fromRGB(239, 68, 68)
        end
        renderMap(true)
    end

    local activeInput, moved, startScr, startPan, savedScroll = nil, false, nil, nil, nil
    local function onMapDown(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            activeInput, moved, startScr, startPan = inp, false, inp.Position, Vector2.new(mapPanX, mapPanY)
            scroller = scroller or rowContainer:FindFirstAncestorOfClass("ScrollingFrame")
            if scroller and savedScroll == nil then
                savedScroll = scroller.ScrollingEnabled
                scroller.ScrollingEnabled = false
            end
        end
    end
    mapHitOverlay.InputBegan:Connect(onMapDown)
    mapView.InputBegan:Connect(onMapDown)

    local function onMapWheel(inp)
        if inp.UserInputType == Enum.UserInputType.MouseWheel then
            applyZoom(mapTilePx * (inp.Position.Z > 0 and 1.18 or (1 / 1.18)))
        end
    end
    mapHitOverlay.InputChanged:Connect(onMapWheel)
    mapView.InputChanged:Connect(onMapWheel)

    UserInputService.InputChanged:Connect(function(inp)
        if not activeInput then return end
        local same = (activeInput.UserInputType == Enum.UserInputType.Touch and inp == activeInput)
            or (activeInput.UserInputType == Enum.UserInputType.MouseButton1 and inp.UserInputType == Enum.UserInputType.MouseMovement)
        if same and startScr and startPan then
            local d = inp.Position - startScr
            if d.Magnitude > 14 then
                moved = true
                userPanned = true
                local s = getScale()
                mapPanX, mapPanY = startPan.X + d.X / s, startPan.Y + d.Y / s
                updateTransform()
            end
        end
    end)
    UserInputService.InputEnded:Connect(function(inp)
        if not activeInput then return end
        if inp ~= activeInput and not (activeInput.UserInputType == Enum.UserInputType.MouseButton1 and inp.UserInputType == Enum.UserInputType.MouseButton1) then return end
        local wasMoved = moved
        activeInput = nil
        if scroller and savedScroll ~= nil then scroller.ScrollingEnabled = savedScroll; savedScroll = nil end
        if not wasMoved and (not scroller or scroller.Visible) and rowContainer.Visible and mapView.AbsoluteSize.X > 10 then
            local cx, cy = resolvePointerScreenPos(inp)
            handleMapTap(cx, cy)
        end
    end)

    fitBtn.MouseButton1Click:Connect(function() fitMap(); renderMap(true) end)
    zoomInBtn.MouseButton1Click:Connect(function() applyZoom(mapTilePx + 1.5); renderMap(true) end)
    zoomOutBtn.MouseButton1Click:Connect(function() applyZoom(mapTilePx - 1.5); renderMap(true) end)
    tpBtn.MouseButton1Click:Connect(function()
        if tpState.selectedX and tpState.selectedY then
            local ok, msg = Packets.WalkTeleport({ tx = tpState.selectedX, ty = tpState.selectedY, mode = "step", stepSize = 3 })
            UI:SetValue("ValidStatusDisplay", (ok and "[OK] " or "[STOP/NO-SEND] ") .. tostring(msg))
            infoLbl.Text = tostring(msg)
            renderMap(true)
        end
    end)
end)

-- B. MOUNT 2: VISUAL BACKPACK ITEM SELECTOR WITH REAL ITEM SPRITES (__BP_ITEM_ANCHOR_KEY__)
mountEmbeddedCanvas("__BP_ITEM_ANCHOR_KEY__", 225, function(rowContainer)
    local scroller = rowContainer:FindFirstAncestorOfClass("ScrollingFrame")
    local topBar = Instance.new("Frame")
    topBar.Size = UDim2.new(1, -12, 0, 24)
    topBar.Position = UDim2.fromOffset(6, 5)
    topBar.BackgroundTransparency = 1
    topBar.Parent = rowContainer

    local filterMode = "BLOCK" -- "BLOCK" | "SEED" | "ALL"
    local filterBtns = {}
    local rebuildBP
    for i, m in ipairs({ "BLOCK", "SEED", "ALL" }) do
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0.24, -3, 1, 0)
        b.Position = UDim2.new((i - 1) * 0.25, 0, 0, 0)
        b.BorderSizePixel = 0
        b.Font = Enum.Font.GothamBold
        b.TextSize = 10
        b.Parent = topBar
        b.Text = m
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
        b.MouseButton1Click:Connect(function()
            filterMode = m
            if rebuildBP then rebuildBP() end
        end)
        filterBtns[m] = b
    end

    local bpCountLbl = Instance.new("TextLabel")
    bpCountLbl.Size = UDim2.new(0.25, 0, 1, 0)
    bpCountLbl.Position = UDim2.new(0.75, 0, 0, 0)
    bpCountLbl.BackgroundTransparency = 1
    bpCountLbl.Font = Enum.Font.Code
    bpCountLbl.TextSize = 10
    bpCountLbl.TextXAlignment = Enum.TextXAlignment.Right
    bpCountLbl.TextColor3 = Color3.fromRGB(148, 163, 184)
    bpCountLbl.Text = "0 item"
    bpCountLbl.Parent = topBar

    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, -12, 1, -36)
    scroll.Position = UDim2.fromOffset(6, 32)
    scroll.BackgroundColor3 = Color3.fromRGB(8, 10, 15)
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 4
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.ZIndex = (rowContainer.ZIndex or 1) + 2
    scroll.Parent = rowContainer
    Instance.new("UIStroke", scroll).Color = Color3.fromRGB(45, 55, 72)

    local grid = Instance.new("UIGridLayout")
    grid.CellSize = UDim2.fromOffset(74, 74)
    grid.CellPadding = UDim2.fromOffset(5, 5)
    grid.Parent = scroll
    local pad = Instance.new("UIPadding", scroll)
    pad.PaddingLeft, pad.PaddingTop, pad.PaddingRight, pad.PaddingBottom = UDim.new(0, 5), UDim.new(0, 5), UDim.new(0, 5), UDim.new(0, 5)

    rebuildBP = function()
        for m, b in pairs(filterBtns) do
            local on = (filterMode == m)
            b.BackgroundColor3 = on and Color3.fromRGB(56, 189, 248) or Color3.fromRGB(31, 35, 44)
            b.TextColor3 = on and Color3.new(0, 0, 0) or Color3.fromRGB(226, 232, 240)
        end
        for _, ch in ipairs(scroll:GetChildren()) do
            if ch:IsA("TextButton") then ch:Destroy() end
        end
        local items = PNB.GetBackpackBlocks(filterMode ~= "BLOCK")
        local shownCount = 0
        for _, it in ipairs(items) do
            local show = (filterMode == "ALL") or (filterMode == "SEED" and it.kind == "seed") or (filterMode == "BLOCK" and it.kind ~= "seed")
            if show then
                shownCount += 1
                local isSel = (PNB.State.selectedBlockId == it.id) or (Pabrik.State.blockId == it.id) or (Pabrik.State.seedId == it.id)
                local cell = Instance.new("TextButton")
                cell.Text = ""
                cell.AutoButtonColor = false
                cell.BackgroundColor3 = isSel and Color3.fromRGB(22, 48, 68) or Color3.fromRGB(19, 24, 34)
                cell.BorderSizePixel = 0
                cell.ZIndex = (scroll.ZIndex or 3) + 1
                cell.Parent = scroll
                Instance.new("UICorner", cell).CornerRadius = UDim.new(0, 6)
                local st = Instance.new("UIStroke", cell)
                st.Color = isSel and Color3.fromRGB(56, 189, 248) or Color3.fromRGB(48, 58, 76)
                st.Thickness = isSel and 1.8 or 1

                local iconHolder = Instance.new("Frame")
                iconHolder.Size = UDim2.fromOffset(36, 36)
                iconHolder.AnchorPoint = Vector2.new(0.5, 0)
                iconHolder.Position = UDim2.new(0.5, 0, 0, 6)
                iconHolder.BackgroundTransparency = 1
                iconHolder.ZIndex = cell.ZIndex + 1
                iconHolder.Parent = cell
                Core.AttachItemSprite(iconHolder, it.id, 34)

                local cntLbl = Instance.new("TextLabel")
                cntLbl.Size = UDim2.fromOffset(34, 14)
                cntLbl.Position = UDim2.new(1, -36, 0, 2)
                cntLbl.BackgroundTransparency = 1
                cntLbl.Font = Enum.Font.Code
                cntLbl.TextSize = 10
                cntLbl.TextXAlignment = Enum.TextXAlignment.Right
                cntLbl.TextColor3 = Color3.fromRGB(250, 204, 21)
                cntLbl.Text = "x" .. tostring(it.count)
                cntLbl.ZIndex = cell.ZIndex + 4
                cntLbl.Parent = cell

                local nameLbl = Instance.new("TextLabel")
                nameLbl.Size = UDim2.new(1, -6, 0, 24)
                nameLbl.Position = UDim2.new(0, 3, 1, -26)
                nameLbl.BackgroundTransparency = 1
                nameLbl.Font = Enum.Font.Gotham
                nameLbl.TextSize = 9
                nameLbl.TextWrapped = true
                nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
                nameLbl.TextColor3 = Color3.fromRGB(226, 232, 240)
                nameLbl.Text = string.format("%s [%d]", it.name, it.id)
                nameLbl.ZIndex = cell.ZIndex + 4
                nameLbl.Parent = cell

                cell.MouseButton1Click:Connect(function()
                    if it.kind ~= "seed" then
                        PNB.State.selectedBlockId = it.id
                        UI:SetValue("PnbSelectedDisplay", string.format("%s (ID:%d | x%d)", it.name, it.id, it.count))
                    end
                    Pabrik.SetItem(it.id)
                    UI:SetValue("PabrikItemInput", tostring(it.id))
                    rebuildBP()
                    if UIHooks.refreshPad5x5 then UIHooks.refreshPad5x5() end
                end)
            end
        end
        bpCountLbl.Text = shownCount > 0 and (tostring(shownCount) .. " item") or "Kosong"
    end
    UIHooks.refreshBP = rebuildBP
    if scroller then
        scroller:GetPropertyChangedSignal("Visible"):Connect(function()
            if scroller.Visible then rebuildBP() end
        end)
    end
    task.delay(0.4, rebuildBP)
    task.delay(1.5, function()
        local inv = Core.GetLiveInventory()
        if inv and typeof(inv.changed) == "Instance" and inv.changed:IsA("BindableEvent") then
            inv.changed.Event:Connect(function()
                task.defer(rebuildBP)
            end)
        end
        rebuildBP()
    end)
end)

-- C. MOUNT 3: 5x5 CENTER-PLAYER TILE SELECTOR PAD (__PAD_5X5_ANCHOR_KEY__)
mountEmbeddedCanvas("__PAD_5X5_ANCHOR_KEY__", 230, function(rowContainer)
    local padFrame = Instance.new("Frame")
    padFrame.Size = UDim2.new(1, -12, 1, -38)
    padFrame.Position = UDim2.fromOffset(6, 6)
    padFrame.BackgroundTransparency = 1
    padFrame.Parent = rowContainer

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
                        cell.Text = string.format("%s\n(%d,%d)", string.sub(myGameName, 1, 7), pos.tx, pos.ty)
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
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(0.2, -4, 0.2, -4)
            btn.Position = UDim2.new(c * 0.2, 2, r * 0.2, 2)
            btn.BorderSizePixel = 0
            btn.Font = Enum.Font.Code
            btn.TextSize = 10
            btn.TextWrapped = true
            btn.Parent = padFrame
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)
            if dx ~= 0 or dy ~= 0 then
                btn.MouseButton1Click:Connect(function() PNB.ToggleTile5x5(dx, dy) end)
            end
            cellMap[tileKey(dx, dy)] = btn
        end
    end

    local presetBar = Instance.new("Frame")
    presetBar.Size = UDim2.new(1, -12, 0, 24)
    presetBar.Position = UDim2.new(0, 6, 1, -28)
    presetBar.BackgroundTransparency = 1
    presetBar.Parent = rowContainer

    local presets = {
        { label = "1 Atas",  apply = function() PNB.State.grid5x5 = { ["0,-1"] = true } end },
        { label = "3 Atas",  apply = function() PNB.State.grid5x5 = { ["-1,-1"] = true, ["0,-1"] = true, ["1,-1"] = true } end },
        { label = "Ring 8",  apply = function()
            PNB.State.grid5x5 = {}
            for yy = -1, 1 do for xx = -1, 1 do if xx ~= 0 or yy ~= 0 then PNB.State.grid5x5[tileKey(xx, yy)] = true end end end
        end },
        { label = "Clear",   apply = function() PNB.State.grid5x5 = {} end },
    }
    for i, pr in ipairs(presets) do
        local pb = Instance.new("TextButton")
        pb.Size = UDim2.new(0.24, -2, 1, 0)
        pb.Position = UDim2.new((i - 1) * 0.25, 0, 0, 0)
        pb.BackgroundColor3 = Color3.fromRGB(31, 35, 44)
        pb.BorderSizePixel = 0
        pb.Font = Enum.Font.GothamBold
        pb.TextSize = 10
        pb.TextColor3 = Color3.fromRGB(226, 232, 240)
        pb.Text = pr.label
        pb.Parent = presetBar
        Instance.new("UICorner", pb).CornerRadius = UDim.new(0, 4)
        pb.MouseButton1Click:Connect(function() pr.apply(); refresh5x5() end)
    end
    UIHooks.refreshPad5x5 = refresh5x5
    refresh5x5()
end)

-- D. MOUNT 4: AUTO PABRIK HEAD BREAK PAD (__PAD_PABRIK_ANCHOR_KEY__)
mountEmbeddedCanvas("__PAD_PABRIK_ANCHOR_KEY__", 112, function(rowContainer)
    local cells = {}
    local function refreshPabrikPad()
        local offs = {}
        for _, o in ipairs(computePabrikBreakOffsets(Pabrik.State.breakTileCount)) do
            offs[tileKey(o.dx, o.dy)] = true
        end
        local bp = Pabrik.State.breakPos or Core.ReadPos()
        local bx, by = bp.x or bp.tx or 0, bp.y or bp.ty or 0
        for dx = -1, 1 do
            local top = cells[tileKey(dx, -1)]
            if top then
                local active = offs[tileKey(dx, -1)] == true
                top.BackgroundColor3 = active and Color3.fromRGB(16, 185, 129) or Color3.fromRGB(23, 29, 41)
                top.TextColor3 = active and Color3.new(0, 0, 0) or Color3.fromRGB(148, 163, 184)
                top.Text = string.format("Break (%d,%d)\n%s", bx + dx, by - 1, active and "[ON]" or "[OFF]")
            end
        end
        local mid = cells["0,0"]
        if mid then
            mid.BackgroundColor3 = Color3.fromRGB(161, 98, 7)
            mid.TextColor3 = Color3.fromRGB(254, 240, 138)
            mid.Text = string.format("%s\n(%d, %d)", string.sub(Core.GetInGameName(LP, true), 1, 10), bx, by)
        end
    end

    for row = 0, 1 do
        local dy = (row == 0) and -1 or 0
        for col = 0, 2 do
            local dx = col - 1
            local b = Instance.new("TextButton")
            b.Size = UDim2.new(0.333, -6, 0.5, -6)
            b.Position = UDim2.new(col * 0.333, 3, row * 0.5, 3)
            b.BorderSizePixel = 0
            b.Font = Enum.Font.Code
            b.TextSize = 10
            b.TextWrapped = true
            b.Parent = rowContainer
            Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
            if dy == 0 and dx ~= 0 then
                b.BackgroundColor3 = Color3.fromRGB(15, 20, 30)
                b.TextColor3 = Color3.fromRGB(100, 116, 139)
                b.Text = (dx == -1) and "Set: 3 Tile" or "Set: 2 Tile"
                b.MouseButton1Click:Connect(function() Pabrik.SetBreakCount((dx == -1) and 3 or 2) end)
            elseif dy == -1 then
                b.MouseButton1Click:Connect(function()
                    local nxt = (dx == -1 and 3) or (dx == 1 and 2) or 1
                    Pabrik.SetBreakCount(nxt)
                end)
            end
            cells[tileKey(dx, dy)] = b
        end
    end
    UIHooks.refreshPadPab = refreshPabrikPad
    refreshPabrikPad()
end)

    task.defer(function()
        if getEnv().__SYT_SCRIPT_TOKEN ~= MY_SCRIPT_TOKEN then return end
        pcall(SYT_Logic.Init, false)
        pcall(scanResponsiveButtons)
        pcall(UIHooks.updateButtons)
        if UIHooks.refreshBP then pcall(UIHooks.refreshBP) end
        if UIHooks.refreshMap then pcall(UIHooks.refreshMap, true) end
    end)
end

-- Instant Boot: Hubungkan engine non-blocking + pasang ULTIMAX Guard -> Buka UI langsung utuh
cleanupSYTGuiContainers(nil)
ensureSharedModulesReady(2.0)
LP = LP or Players.LocalPlayer
pcall(SYT_Logic.Init, false)
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
        enforceSingleActiveFeatureTab()
        local sg = getActiveMenuGui()
        if sg and sg.Parent then
            sg.Enabled = true
            task.defer(function()
                if UI and type(UI.SyncNavCanvas) == "function" then
                    pcall(UI.SyncNavCanvas)
                end
            end)
            pcall(scanResponsiveButtons)
            pcall(UIHooks.updateButtons)
            if UIHooks.refreshBP then pcall(UIHooks.refreshBP) end
            if UIHooks.refreshPad5x5 then pcall(UIHooks.refreshPad5x5) end
            if UIHooks.refreshPadPab then pcall(UIHooks.refreshPadPab) end
            if UIHooks.refreshMap then pcall(UIHooks.refreshMap, true) end
        else
            warn("[SYT] ScreenGui menu belum terpasang: " .. tostring(menuIsReady()))
        end
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- 9. RUNTIME WATCHER: LIVE POS, IN-GAME NAME SYNC, LOCK NAMES
-- ═══════════════════════════════════════════════════════════════════════════
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

local lastFastTick, lastSlowTick, lastLivePos, lastInvHash = 0, 0, "", ""
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

    local gt = H.gt
    local curWorld = gt and cleanWorldName(gt.name) or ""

    -- Sinkronkan perubahan world cepat tanpa rebuild ulang GUI yang sudah terbuka
    if curWorld ~= Visual.State.lastWorldName then
        local prev = Visual.State.lastWorldName
        Visual.State.lastWorldName = curWorld
        if prev ~= "" and not DirtFarm.State.switchingWorld then
            stopAllAutomationImpl("Pindah world -> Otomasi OFF")
        end
        if curWorld ~= "" then
            task.delay(0.08, function()
                if getEnv().__SYT_SCRIPT_TOKEN ~= MY_SCRIPT_TOKEN then return end
                pcall(SYT_Logic.Init, true)
                pcall(Core.InstallAntiBackGuard)
                pcall(hookIncomingNetGuard)
                if Visual.State.lockNames or Visual.HasActiveSpoof() then
                    pcall(Visual.OnWorldChanged)
                end
                if UI and UI._DropRefresh and UI._DropRefresh.SpoofWearPick and H.ItemDB then
                    pcall(function()
                        UI._DropRefresh.SpoofWearPick(Visual.GetWearableOptionsForSlot(Visual.State.selectedSlot or "back", Visual.State.wearSearch))
                    end)
                end
                if UIHooks.refreshBP then pcall(UIHooks.refreshBP) end
                if UIHooks.refreshMap then pcall(UIHooks.refreshMap, true) end
                if UIHooks.refreshPad5x5 then pcall(UIHooks.refreshPad5x5) end
            end)
        end
    end

    if gt and (gt.name or "") ~= "" then
        local pos = Core.ReadPos()
        local okHere = Core.ValidateTile(pos.tx, pos.ty)
        local liveStr = string.format("Stats (%d, %d) | Tile (%d, %d) | %s [%s]", pos.sx, pos.sy, pos.tx, pos.ty, tostring(gt.name), okHere and "VALID" or "SOLID")
        if liveStr ~= lastLivePos then
            lastLivePos = liveStr
            if UI then UI:SetValue("LivePosDisplay", liveStr) end
            if Visual.State.tilesName then Visual.Apply() end
            if UIHooks.refreshPad5x5 then UIHooks.refreshPad5x5() end
            if UIHooks.refreshMap then UIHooks.refreshMap(true) end
        end
        if UIHooks.sidebarNameLbl and UIHooks.sidebarNameLbl.Parent then
            UIHooks.sidebarNameLbl.Text = Core.GetInGameName(LP, true)
        end
        if UIHooks.sidebarSubLbl and UIHooks.sidebarSubLbl.Parent then
            UIHooks.sidebarSubLbl.Text = string.format("%s (%d,%d)", tostring(gt.name), pos.sx, pos.sy)
        end
        if Misc.State.seems then evaluateSeems() end
    end

    if (now - lastSlowTick) >= 1.2 then
        lastSlowTick = now
        if not H.gt or not H.ItemDB or not H.Net or not H.inv then pcall(SYT_Logic.Init) end
        if not Visual._wearInitSynced and H.ItemDB and UI and UI._DropRefresh and UI._DropRefresh.SpoofWearPick then
            Visual._wearInitSynced = true
            pcall(function()
                UI._DropRefresh.SpoofWearPick(Visual.GetWearableOptionsForSlot(Visual.State.selectedSlot or "back", Visual.State.wearSearch))
            end)
        end
        if not buttonMap["[PNB]"] or not buttonMap["[PABRIK]"] or not buttonMap["[DF]"] or not buttonMap["[SPAM]"] or not buttonMap["[GAP TP]"] or not UIHooks.sidebarNameLbl then
            pcall(scanResponsiveButtons)
            pcall(UIHooks.updateButtons)
        end
        local invHash = computeInvHash()
        if invHash ~= lastInvHash then
            lastInvHash = invHash
            if UIHooks.refreshBP then UIHooks.refreshBP() end
        end
        if UIHooks.refreshMap then UIHooks.refreshMap(false) end
        if UI then
            UI:SetValue("UltimaxStatusDisplay", GetcSkipper.GetUltimaxStatusText())
        end
        if gt and gt.name ~= "" and UI then
            local plrs = Core.GetInWorldPlayers(true)
            local nms = {}
            for _, p in ipairs(plrs) do nms[#nms + 1] = p.gameName .. (p.isStaff and "[MOD]" or "") end
            UI:SetValue("LiveInGameAccount", string.format("%s | World: %s", Core.GetInGameName(LP, true), tostring(gt.name)))
            UI:SetValue("LiveWorldPlayers", #nms > 0 and table.concat(nms, ", ") or "-")

            local fCands = Misc.GetFollowCandidates()
            local fHash = table.concat(fCands, "|")
            if fHash ~= Misc.State.lastFollowHash then
                Misc.State.lastFollowHash = fHash
                if UI._DropRefresh and UI._DropRefresh.MiscFollowTarget then
                    UI._DropRefresh.MiscFollowTarget(fCands)
                end
            end
        end
    end
end)
getEnv().__SYT_WATCHER_CONN = H.watcherConn

getEnv().SYT_Logic = SYT_Logic
return SYT_Logic
