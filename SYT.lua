--!nocheck
--[[
    SYT.lua — Unified R&8_DV Frontend + Full Backend Logic (Single Script)
    Template GUI: https://raw.githubusercontent.com/Mytzcodes/R-8/refs/heads/main/Sample%20Gui/SampleGui.lua
    Framework   : https://raw.githubusercontent.com/Mytzcodes/R-8/refs/heads/main/r%268_dv.lua

    Fitur Lengkap V1 + V2 dalam 1 Script Terintegrasi (SYT):
      - Overview         : Profil Akun In-Game, live world/posisi, list player, Auto Save/Load Config, Theme & FPS Boost
      - Teleport & Map   : Manual TP validasi, Walk-Path Safe (anti-rubberband jarak jauh), Step TP, Gap TP, Peta World 2D
      - Misc (V1)        : Fly, Seems, Fast Roulette (0-36), No Clip, True God Mode (HP Full/Anti-Die/Anti-Respawn),
                           Auto Follow Player (Dropdown Scroll Walk), Collect State, Radius Auto Collect, FPS Boost, Auto Rerun
      - PNB (V2)         : Visual Backpack Selector (Texture Asli Game Atlas/ItemIcon), 5x5 Tile Pad, 1-Hit, Hand, Delay
      - Auto Pabrik (V3) : Visual Backpack/Seed Pair, Map Tile & Connected Line (-----) Selector, BreakPos 1-3 Tile Head Pad
      - Dirt Farm (DF)   : Auto Break & Ubah ke Dirt (Skip Door/Bedrock/Locks), Pola Kelipatan 2, Rotation World Otomatis
      - Visualisasi (V4) : Custom In-Game Name, Roles Lengkap + Effects (Rainbow/Sponsor/Supporter/CC/Guild/Booster), Title, Lock
      - Spam & Skipper(V5): Input Spam, Color Prefix / Cycle, Fixed 1-Button Stop, Experimental Whisper All, [GETC SKIPER]
]]

-- ═══════════════════════════════════════════════════════════════════════════
-- 1. LOAD R&8_DV IMGUI FRAMEWORK (SAMPLEGUI SHELL + SCROLLY DROPDOWN PATCH)
-- ═══════════════════════════════════════════════════════════════════════════
local cachedR8Source = nil
local cachedImGuiFactory = nil

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
    -- V2: Hook tombol Close (X) agar mendukung Auto Rerun Menu
    patched = string.gsub(
        patched,
        'CreateVectorWindowBtn%("Close", function%(%)%s*\n%s*Self:MinimizeToIcon%(%)%s*\n%s*end%)',
        'CreateVectorWindowBtn("Close", function()\n        if type(Self.OnCloseMenu) == "function" then\n            local handled = pcall(Self.OnCloseMenu, Self)\n            if handled and Self._CancelDefaultClose then\n                Self._CancelDefaultClose = false\n                return\n            end\n        end\n        Self:MinimizeToIcon()\n    end)'
    )
    return patched
end

local function loadR8Framework(forceReload)
    if cachedImGuiFactory and not forceReload then
        return cachedImGuiFactory
    end
    if not cachedR8Source then
        local urls = {
            "https://raw.githubusercontent.com/Mytzcodes/R-8/refs/heads/main/r%268_dv.lua",
            "https://raw.githubusercontent.com/Mytzcodes/R-8/refs/heads/main/r&8_dv.lua",
        }
        local okFetch, rawScript
        for _, url in ipairs(urls) do
            okFetch, rawScript = pcall(function() return game:HttpGet(url) end)
            if okFetch and type(rawScript) == "string" and #rawScript > 128 and string.sub(rawScript, 1, 4) ~= "404:" then
                break
            end
        end
        assert(okFetch and type(rawScript) == "string" and #rawScript > 128, "[SYT] Gagal memuat r&8_dv.lua dari GitHub.")
        cachedR8Source = patchR8FrameworkSource(rawScript)
    end
    local loader, loadErr = loadstring(cachedR8Source)
    assert(type(loader) == "function", "[SYT] Compile error: " .. tostring(loadErr))
    cachedImGuiFactory = loader()
    return cachedImGuiFactory
end

local UI, ThemeChoices
local function feature(...)
    return UI.feature(...)
end
local function center(fn) return fn end
local function right(fn) return fn end

local function initSYTWindow(themeOverride, scaleOverride)
    local ImGui = loadR8Framework()
    UI = ImGui({
        Title         = "SYT SUITE - IMGUI",
        BrandTitle    = "SYT",
        BrandSubtitle = "GROWBLOX SUITE",
        Theme         = themeOverride or "Minimalist Monochrome",
        CheckboxStyle = "Modern",
        LetterSpacing = 1,
        AutoLoading   = false,
    }).Call(3)
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
initSYTWindow("Minimalist Monochrome")

-- ═══════════════════════════════════════════════════════════════════════════
-- 2. SERVICES, EXECUTOR HELPERS & SHARED TABLES
-- ═══════════════════════════════════════════════════════════════════════════
local Players           = game:GetService("Players")
local CoreGui           = game:GetService("CoreGui")
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
    takeDropHooked   = false,
    wheelHooked      = false,
    seemsHooked      = false,
    netGodHooked     = false,
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
    rerunning      = false,
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

    local goTo = rawget(gt, "goTo")
    if type(goTo) == "function" then
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
                break
            end
        end
    end

    if (not refX or not refY) and H.goPxIdx and H.goPyIdx and type(goTo) == "function" then
        refX, refY = uv(goTo, H.goPxIdx), uv(goTo, H.goPyIdx)
    end

    local getconns = getconnections
    if type(getconns) == "function" and not H.renderFn then
        local okConns, conns = pcall(getconns, RunService.RenderStepped)
        if okConns and type(conns) == "table" then
            for _, c in ipairs(conns) do
                local fn = type(c) == "table" and (c.Function or c["function"]) or nil
                if type(fn) == "function" and uv(fn, 1) == gt then
                    local hasScale, has64 = false, false
                    for idx = 1, 80 do
                        local val = uv(fn, idx)
                        if val == nil and idx > 65 then break end
                        if typeof(val) == "Instance" and val:IsA("UIScale") then hasScale = true end
                        if val == 64 then has64 = true end
                    end
                    if hasScale and has64 then
                        H.renderFn = fn
                        break
                    end
                end
            end
        end
    end

    if H.renderFn and refX and refY then
        local fallbackIdx = nil
        for idx = 10, 55 do
            local vx, vy = uv(H.renderFn, idx), uv(H.renderFn, idx + 1)
            if type(vx) == "number" and type(vy) == "number"
                and math.abs(vx - refX) < 0.05 and math.abs(vy - refY) < 0.05 then
                if not fallbackIdx then fallbackIdx = idx end
                if type(uv(H.renderFn, idx + 2)) == "boolean" and type(uv(H.renderFn, idx - 1)) == "number" then
                    H.pxIdx, H.pyIdx = idx, idx + 1
                    break
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
        for uIdx = 1, 95 do
            local val = uv(H.renderFn, uIdx)
            if type(val) == "table" then
                if not H.particles and type(rawget(val, "swirl")) == "function" and type(rawget(val, "yolk")) == "function" then
                    H.particles = val
                elseif not H.backdropObj and type(rawget(val, "setWorld")) == "function" then
                    H.backdropObj = val
                end
            elseif type(val) == "function" then
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

        -- Pinpoint HP & Dead upvalue langsung dari blok RenderStepped (v_u_243..v_u_75..v_u_268 & v_u_94..v_u_200)
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
            if type(uv(H.renderFn, idx - 3)) == "number" and type(uv(H.renderFn, idx - 2)) == "number" then
                H.vxIdx, H.vyIdx = idx - 3, idx - 2
            end
            if type(uv(H.renderFn, idx + 3)) == "number" and type(uv(H.renderFn, idx + 4)) == "number" then
                H.prevXIdx, H.prevYIdx = idx + 3, idx + 4
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
                    if type(v) == "number" and hIdx ~= idx and hIdx ~= idx + 1 and hIdx ~= H.vxIdx and hIdx ~= H.vyIdx and hIdx ~= H.prevXIdx and hIdx ~= H.prevYIdx then
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
local SYT_Logic = { VERSION = "2.0.0", _Hooks = H, Core = Core }

function SYT_Logic.Init(forceRefresh)
    local curWName = (H.gt and type(rawget(H.gt, "name")) == "string") and rawget(H.gt, "name") or ""
    if curWName ~= "" and curWName ~= H.lastWorldTag then
        forceRefresh = true
        H.lastWorldTag = curWName
        H.inv = nil
    end
    if H.initialized and not forceRefresh and isValidGT(H.gt) and H.Net and H.ItemDB and H.inv then
        return true
    end

    H.Net        = H.Net        or safeRequireShared("Net")
    H.ItemDB     = H.ItemDB     or safeRequireShared("ItemDB")
    H.Roles      = H.Roles      or safeRequireShared("Roles")
    H.Assets     = H.Assets     or safeRequireShared("Assets")
    H.ItemIcon   = H.ItemIcon   or safeRequireShared("ItemIcon")
    H.Autotile   = H.Autotile   or safeRequireShared("Autotile")
    H.BitmapText = H.BitmapText or safeRequireShared("BitmapText")

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

    if H.gt and (not H.renderFn or forceRefresh) then
        pcall(inspectUpvalues, H.gt)
        for _, fn in ipairs(safeGetGC(false)) do
            if type(fn) == "function" then
                local src = fnSource(fn)
                if src ~= "" and string.find(src, "Game", 1, true) then
                    local uvs = guvs(fn)
                    if uvs then
                        for _, u in pairs(uvs) do
                            if type(u) == "table" then
                                if not H.trees and isTreeMapCandidate(u) then H.trees = u end
                                if not H.wheelSpins and isWheelMapCandidate(u) then H.wheelSpins = u end
                                if not H.particles and type(rawget(u, "swirl")) == "function" and type(rawget(u, "yolk")) == "function" then
                                    H.particles = u
                                end
                            end
                        end
                    end
                end
                if H.trees and H.wheelSpins and H.particles then break end
            end
        end
    end

    H.initialized = isValidGT(H.gt) and H.Net ~= nil and H.ItemDB ~= nil
    return H.initialized
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
    if not isValidInv(H.inv) then
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

function Core.ClearStuckDropVisuals(uid)
    Core.EnsureInit()
    local gt = H.gt
    if gt and type(gt.dropList) == "function" then
        local okD, drops = pcall(gt.dropList)
        if okD and type(drops) == "table" then
            for i = #drops, 1, -1 do
                local d = drops[i]
                if type(d) == "table" and (uid == nil or d.uid == uid) then
                    local shouldClean = (uid ~= nil and d.uid == uid) or ((d.n or 0) <= 0) or (d.frame and not d.frame.Parent)
                    if shouldClean then
                        if uid ~= nil and type(gt.dropTaken) == "function" then
                            pcall(gt.dropTaken, d.uid, 0)
                        end
                        pcall(function()
                            if d.frame and d.frame.Destroy then d.frame:Destroy() end
                        end)
                        if drops[i] == d then
                            table.remove(drops, i)
                        end
                    end
                end
            end
        end
    end
    -- Bersihkan clone gem / item drop yang tersangkut secara visual di GameGui
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

-- Core World / Pos / Inventory / Tree helpers
function Core.EnsureInit()
    local curName = (H.gt and type(rawget(H.gt, "name")) == "string") and rawget(H.gt, "name") or ""
    if not H.initialized or not isValidGT(H.gt) or (curName ~= "" and curName ~= H.lastWorldTag) then
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
    if H.renderFn and H.pxIdx and H.pyIdx then
        suv(H.renderFn, H.pxIdx, px)
        suv(H.renderFn, H.pyIdx, py)
        if H.prevXIdx then suv(H.renderFn, H.prevXIdx, px) end
        if H.prevYIdx then suv(H.renderFn, H.prevYIdx, py) end
        if H.vxIdx then suv(H.renderFn, H.vxIdx, vx or 0) end
        if H.vyIdx then suv(H.renderFn, H.vyIdx, vy or 0) end
    elseif type(gt.goTo) == "function" and H.goPxIdx and H.goPyIdx then
        suv(gt.goTo, H.goPxIdx, px)
        suv(gt.goTo, H.goPyIdx, py)
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

function Core.MirrorLocalTile(layer, tx, ty, id)
    local gt = H.gt
    if not gt then return end
    if layer == 2 then
        if gt.bg and gt.bg[ty] then gt.bg[ty][tx] = id end
    else
        if gt.fg and gt.fg[ty] then gt.fg[ty][tx] = id end
    end
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

function Core.CanEditTile(tx, ty)
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
        enabled         = true,
        skipUpdateItems = false,
        maxRangeTiles   = 5,
        jitterMin       = 0.05,
        jitterMax       = 0.35,
        minIntervals    = { tile = 0.045, move = 0.030, act = 0.040, take = 0.025, drop = 1.080, chat = 1.650 },
        lastSent        = {},
        jitterCount     = 0,
        origInvNotify   = nil,
    }
}
SYT_Logic.GetcSkipper = GetcSkipper

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

function GetcSkipper.RandomizedWait(baseDelay, packetKind, shouldContinueFn)
    local S = GetcSkipper.State
    local req = math.max(0, tonumber(baseDelay) or 0)
    local waitTime = req
    if S.enabled then
        local kind    = tostring(packetKind or "tile")
        local minInt  = S.minIntervals[kind] or 0.04
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
    if packetKind then S.lastSent[tostring(packetKind)] = os.clock() end
    return waitTime
end

function GetcSkipper.InRange(tx, ty, maxRange)
    local pos = Core.ReadPos()
    local d = math.max(math.abs(math.floor(tx) - pos.tx), math.abs(math.floor(ty) - pos.ty))
    return d <= (tonumber(maxRange) or GetcSkipper.State.maxRangeTiles or 5), d
end

local stepTeleportImpl
function GetcSkipper.EnsureRange(tx, ty, maxRange, stepDelay, shouldContinueFn)
    if GetcSkipper.InRange(tx, ty, maxRange) then return true end
    if type(stepTeleportImpl) == "function" then
        return stepTeleportImpl(tx, ty, math.min(4, GetcSkipper.State.maxRangeTiles), stepDelay or 0.04, shouldContinueFn)
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

function Packets.SendRawMove(px, py, vx, vy, flags)
    Core.EnsureInit()
    local sendFn = H.origMoveSend or (H.Net and H.Net.move and H.Net.move.send)
    if type(sendFn) ~= "function" then return false end
    return pcall(sendFn, { x = px, y = py, vx = vx or 0, vy = vy or 0, flags = toInt(flags, 2), t = moveTs() })
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
                        local okHazard = ignoreDanger or (nIdx == goalIdx) or Misc.State.godMode
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

-- Metode Rekomendasi Jarak Jauh: Walk-Path aman anti rubberband/balik ke base
function Packets.WalkPathTo(tx, ty, speedTilesPerSec, shouldContinueFn)
    Core.EnsureInit()
    local gt = H.gt
    if not gt then return false, "gt nil" end
    tx = clamp(math.floor(tx), 0, gt.w - 1)
    ty = clamp(math.floor(ty), 0, gt.h - 1)

    local cur = Core.ReadPos()
    if cur.tx == tx and cur.ty == ty then return true, "at_target" end

    local speed = clamp(tonumber(speedTilesPerSec) or 13, 5.5, 16)
    local stepDelay = clamp(1 / speed, 0.062, 0.22)
    local retriedSnap = false

    for _ = 1, 2 do
        cur = Core.ReadPos()
        if cur.tx == tx and cur.ty == ty then return true, "walk_path_ok" end
        local path = Packets.FindTilePath(cur.tx, cur.ty, tx, ty)
        if not path or #path <= 1 then
            return false, "Jalur tertutup blok! Buka 1 celah atau gunakan Direct/Force."
        end
        local snapped = false
        local prevX, prevY = cur.tx, cur.ty
        for idx = 2, #path do
            if type(shouldContinueFn) == "function" and not shouldContinueFn() then return false, "cancelled" end
            local node = path[idx]
            if idx == #path and Core.IsSolid(node.x, node.y) then break end
            local vx = (node.x - prevX) * speed
            local vy = (node.y - prevY) * speed
            local px, py = node.x + 0.5, node.y + 1
            Core.SetLocalCoords(px, py, vx, vy)
            Packets.SendRawMove(px, py, vx, vy, 2)
            prevX, prevY = node.x, node.y
            GetcSkipper.RandomizedWait(stepDelay, "move", shouldContinueFn)
            if (idx % 6) == 0 then
                local act = Core.ReadPos()
                if (math.abs(act.tx - node.x) + math.abs(act.ty - node.y)) > 7 then
                    snapped = true
                    break
                end
            end
        end
        if not snapped then
            local fin = Core.ReadPos()
            if (math.abs(fin.tx - tx) + math.abs(fin.ty - ty)) <= 3 then
                if type(gt.goTo) == "function" and not Core.IsSolid(tx, ty) then pcall(gt.goTo, tx, ty) end
                Core.SetLocalCoords(tx + 0.5, ty + 1, 0, 0)
                return true, string.format("Walk-Path OK -> (%d, %d)", tx, ty)
            end
            snapped = true
        end
        if snapped and not retriedSnap then
            retriedSnap = true
            speed = 9.5
            stepDelay = 0.11
            task.wait(0.22)
        else
            break
        end
    end
    local f = Core.ReadPos()
    return (math.abs(f.tx - tx) + math.abs(f.ty - ty)) <= 4,
        string.format("Sampai (%d,%d) - Gunakan Walk-Path lambat bila server lag", f.tx, f.ty)
end

function Packets.StepTeleport(tx, ty, stepSize, stepDelay, shouldContinueFn)
    Core.EnsureInit()
    local gt = H.gt
    if not gt then return false, "gt nil" end
    tx = clamp(math.floor(tx), 0, gt.w - 1)
    ty = clamp(math.floor(ty), 0, gt.h - 1)

    local cur = Core.ReadPos()
    if cur.tx == tx and cur.ty == ty then return true, "at_target" end

    local path = Packets.FindTilePath(cur.tx, cur.ty, tx, ty)
    if not path or #path <= 1 then
        return false, "Jalur tertutup blok! Rekomendasi: buka celah & pakai Walk-Path Safe"
    end

    local totalDist = #path - 1
    -- Radius jauh (>14 tile): batasi hop <=2 tile & rate <=14.5 t/s agar tidak balik ke base/spawn
    local maxStep = (totalDist > 14) and math.min(toInt(stepSize, 2), 2) or clamp(toInt(stepSize, 3), 1, 4)
    local rawDelay = tonumber(stepDelay) or 0.06
    local safeDelay = (totalDist > 14) and math.max(rawDelay, maxStep / 14.5) or math.max(rawDelay, maxStep / 24)

    local idx = 1
    local hopsSinceCheck = 0
    while idx < #path do
        if type(shouldContinueFn) == "function" and not shouldContinueFn() then return false, "cancelled" end
        local nextIdx = math.min(#path, idx + maxStep)
        local node = path[nextIdx]
        if nextIdx == #path and Core.IsSolid(node.x, node.y) and nextIdx > 1 then
            node = path[nextIdx - 1]
        end
        local px, py = node.x + 0.5, node.y + 1
        Core.SetLocalCoords(px, py, 0, 0)
        if type(gt.goTo) == "function" and nextIdx == #path then pcall(gt.goTo, node.x, node.y) end
        Packets.SendRawMove(px, py, 0, 0, 2)
        idx = nextIdx
        hopsSinceCheck += 1
        if idx < #path then
            GetcSkipper.RandomizedWait(safeDelay, "move", shouldContinueFn)
        end
        if hopsSinceCheck >= 5 and idx < #path then
            hopsSinceCheck = 0
            local act = Core.ReadPos()
            if (math.abs(act.tx - node.x) + math.abs(act.ty - node.y)) > 8 then
                task.wait(0.22)
                return Packets.WalkPathTo(tx, ty, 11, shouldContinueFn)
            end
        end
    end

    local fin = Core.ReadPos()
    if (math.abs(fin.tx - tx) + math.abs(fin.ty - ty)) > 6 then
        task.wait(0.2)
        return Packets.WalkPathTo(tx, ty, 10, shouldContinueFn)
    end
    return true, string.format("Step TP (%d nodes) -> (%d, %d)", totalDist, tx, ty)
end
stepTeleportImpl = Packets.StepTeleport

function Packets.WalkTeleport(arg1, ty, mode, stepSize, stepDelay)
    Core.EnsureInit()
    local gt = H.gt
    if not gt then return false, "gt nil" end
    local opts = type(arg1) == "table" and arg1 or { tx = arg1, ty = ty, mode = mode, stepSize = stepSize, stepDelay = stepDelay }
    local m = string.lower(tostring(opts.mode or "step"))
    if m == "raw" then
        return Packets.SendRawMove(opts.x or opts.tx or 0, opts.y or opts.ty or 0, opts.vx or 0, opts.vy or 0, opts.flags or 2)
    end
    local tx, py = toInt(opts.tx), toInt(opts.ty)
    if not tx or not py then return false, "invalid coords" end
    local okVal, msg, cx, cy = Core.ValidateTile(tx, py)
    if not okVal and m ~= "force" then return false, msg end
    cx, cy = cx or clamp(tx, 0, gt.w - 1), cy or clamp(py, 0, gt.h - 1)
    if m == "walk" or m == "walkpath" or m == "safe" then
        return Packets.WalkPathTo(cx, cy, opts.speed or 13, opts.shouldContinueFn)
    elseif m == "direct" or m == "force" then
        local cur = Core.ReadPos()
        local manhattan = math.abs(cx - cur.tx) + math.abs(cy - cur.ty)
        if m == "direct" and manhattan > 20 then
            -- Rekomendasi anti-balik base: jarak >20 lewat WalkPathTo
            return Packets.WalkPathTo(cx, cy, 13, opts.shouldContinueFn)
        end
        local px, wy = cx + 0.5, cy + 1
        Core.SetLocalCoords(px, wy, 0, 0)
        if type(gt.goTo) == "function" then pcall(gt.goTo, cx, cy) end
        Packets.SendRawMove(px, wy, 0, 0, 2)
        return true, string.format("Direct TP -> Tile (%d, %d) | Stats (%d, %d)", cx, cy, cx + 1, cy + 1)
    end
    return Packets.StepTeleport(cx, cy, opts.stepSize or 2, opts.stepDelay or 0.06, opts.shouldContinueFn)
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
    if not opts.ignoreProtected and Core.IsProtectedTile(curId) then return false, "protected" end
    if opts.autoRange ~= false then GetcSkipper.EnsureRange(tx, py, GetcSkipper.State.maxRangeTiles) end

    local info = Core.GetItemInfo(curId)
    if opts.showHand ~= false and net.act and net.act.send then
        pcall(net.act.send, { kind = 1, x = tx + 0.5, y = py + 0.5 })
        pcall(net.act.send, { kind = 6, x = tx + 0.5, y = py + 0.5 })
    end
    if opts.harvestIfTree ~= false and info and info.kind == "seed" and info.provider and net.harvest and net.harvest.send then
        return (pcall(net.harvest.send, { x = tx, y = py })), "harvest_sent"
    end
    local ok = pcall(net.tile.send, { layer = targetLayer, x = tx, y = py, id = 0, flip = opts.flip == true })
    if ok then
        H.lastTileAt = os.clock()
        Core.MirrorLocalTile(targetLayer, tx, py, 0)
    end
    return ok, ok and "break_sent" or "send_failed"
end

function Packets.HitDamage(arg1, ty, oneHit, customHits, hitDelay, layer, showHand)
    Core.EnsureInit()
    local gt, net = H.gt, H.Net
    if not gt or not net then return false end
    local opts = type(arg1) == "table" and arg1 or { tx = arg1, ty = ty, oneHit = oneHit, customHits = customHits, hitDelay = hitDelay, layer = layer, showHand = showHand }
    local tx, py = toInt(opts.tx), toInt(opts.ty)
    if not tx or not py then return false end
    local targetLayer = toInt(opts.layer, 1)
    local curId = Core.GetLayerTile(tx, py, targetLayer)
    if curId == 0 then return true end
    if Core.IsProtectedTile(curId) then return false end
    if opts.autoRange ~= false then GetcSkipper.EnsureRange(tx, py, GetcSkipper.State.maxRangeTiles) end

    local info = Core.GetItemInfo(curId)
    local totalHits = (opts.oneHit == true and 1) or toInt(opts.customHits, (info and info.hits) or 3)
    if opts.oneHit == true then pcall(function() LP:SetAttribute("OneHitUntil", serverNow() + 60) end) end
    if totalHits <= 1 then
        return Packets.PunchBreak({ tx = tx, ty = py, layer = targetLayer, showHand = opts.showHand ~= false, autoRange = false })
    end
    local delay = tonumber(opts.hitDelay) or 0.16
    for _ = 1, totalHits - 1 do
        if opts.showHand ~= false and net.act and net.act.send then
            pcall(net.act.send, { kind = 1, x = tx + 0.5, y = py + 0.5 })
            pcall(net.act.send, { kind = 6, x = tx + 0.5, y = py + 0.5 })
        end
        GetcSkipper.RandomizedWait(delay, "act")
        if Core.GetLayerTile(tx, py, targetLayer) == 0 then return true end
    end
    return Packets.PunchBreak({ tx = tx, ty = py, layer = targetLayer, showHand = opts.showHand ~= false, autoRange = false })
end

function Packets.Place(arg1, ty, itemId, layer, flip, showHand)
    Core.EnsureInit()
    local gt, net = H.gt, H.Net
    if not gt or not net or not net.tile or not net.tile.send then return false, "net nil" end
    local opts = type(arg1) == "table" and arg1 or { tx = arg1, ty = ty, itemId = itemId, layer = layer, flip = flip, showHand = showHand }
    local tx, py, id = toInt(opts.tx), toInt(opts.ty), toInt(opts.itemId or opts.id)
    if not tx or not py or not id or id <= 0 or tx < 0 or tx >= gt.w or py < 0 or py >= gt.h then return false, "invalid" end
    if Core.CountItem(id) <= 0 and not opts.ignoreCount then return false, "no_item" end

    local info = Core.GetItemInfo(id)
    local targetLayer = toInt(opts.layer, (info and info.background) and 2 or 1)
    if Core.GetLayerTile(tx, py, targetLayer) ~= 0 and not opts.force then return false, "occupied" end
    if opts.autoRange ~= false then GetcSkipper.EnsureRange(tx, py, GetcSkipper.State.maxRangeTiles) end

    if opts.showHand ~= false and net.act and net.act.send then
        pcall(net.act.send, { kind = (info and info.kind == "seed") and 3 or 2, x = tx + 0.5, y = py + 0.5 })
    end
    local ok = pcall(net.tile.send, { layer = targetLayer, x = tx, y = py, id = id, flip = opts.flip == true })
    if ok then
        H.lastTileAt = os.clock()
        Core.MirrorLocalTile(targetLayer, tx, py, id)
        if H.inv and type(H.inv.remove) == "function" then pcall(function() H.inv:remove(id, 1) end) end
    end
    return ok, ok and "placed" or "failed"
end

function Packets.SendChat(arg1, prefixColor, isWhisper, whisperTarget)
    Core.EnsureInit()
    local opts = type(arg1) == "table" and arg1 or { message = arg1, prefixColor = prefixColor, isWhisper = isWhisper, whisperTarget = whisperTarget }
    local rawMsg = tostring(opts.message or opts.text or "")
    local prefix = tostring(opts.prefixColor or opts.color or "")
    if rawMsg == "" then return false, "empty" end
    local fullMsg = prefix ~= "" and (prefix .. rawMsg) or rawMsg
    local maxLen  = clamp(toInt(opts.maxLength, 120), 1, 120)
    if #fullMsg > maxLen then fullMsg = string.sub(fullMsg, 1, maxLen) end
    if opts.bypassRateLimit ~= true then GetcSkipper.RandomizedWait(0, "chat") end

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
    local radius, targetId, stepFar = tonumber(opts.radius) or 5, opts.filterId, opts.stepMoveIfFar == true
    local delay = tonumber(opts.collectDelay) or 0.03
    local shouldContinueFn = opts.shouldContinue
    local okD, drops = pcall(gt.dropList)
    if not okD or type(drops) ~= "table" then return { totalTaken = 0, gemsTaken = 0, itemsTaken = 0 } end

    local now = os.clock()
    H.takingUids = H.takingUids or {}
    for uid, exp in pairs(H.takingUids) do
        if exp <= now then H.takingUids[uid] = nil end
    end

    local pos = Core.ReadPos()
    local list = {}
    for i = 1, #drops do
        local d = drops[i]
        if type(d) == "table" and d.uid and d.x and d.y and (d.n or 0) > 0 and (d.readyAt or 0) <= now then
            if not d.taking and (not H.takingUids[d.uid] or H.takingUids[d.uid] <= now) then
                if not targetId or d.id == targetId then
                    local distBody = math.max(math.abs(d.x - pos.x), math.abs(d.y - (pos.y - 0.5)))
                    local distTile = math.max(math.abs(d.x - (pos.tx + 0.5)), math.abs(d.y - (pos.ty + 0.5)))
                    local dist = math.min(distBody, distTile)
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
    local pickupRange = math.max(radius, 5.5)

    local function distToDrop(d, cp)
        local distBody = math.max(math.abs(d.x - cp.x), math.abs(d.y - (cp.y - 0.5)))
        local distTile = math.max(math.abs(d.x - (cp.tx + 0.5)), math.abs(d.y - (cp.ty + 0.5)))
        return math.min(distBody, distTile)
    end

    local function collectBatchInRange()
        local cp = Core.ReadPos()
        local batch = {}
        local tNow = os.clock()
        for _, item in ipairs(list) do
            local d = item.drop
            if (d.n or 0) > 0 and not d.taking and (not H.takingUids[d.uid] or H.takingUids[d.uid] <= tNow) then
                if distToDrop(d, cp) <= pickupRange then
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
                    local rem = math.max(0, (d.n or got) - got)
                    d.n = rem
                    d.flown = (rem <= 0)
                    if d.frame and rem <= 0 then
                        pcall(function() d.frame.Visible = false end)
                    end
                    if type(gt.dropTaken) == "function" then
                        pcall(gt.dropTaken, d.uid, rem)
                    end
                    if rem <= 0 then
                        Core.ClearStuckDropVisuals(d.uid)
                    end
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
                if (d.n or 0) > 0 and not d.taking then
                    local dist = distToDrop(d, cp)
                    if dist < bestDist then
                        bestDist = dist
                        nextDrop = d
                    end
                end
            end
            if not nextDrop then break end
            if bestDist > 5 then
                Packets.StepTeleport(math.floor(nextDrop.x), math.floor(nextDrop.y), 4, math.max(0.03, delay), shouldContinueFn)
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
-- 6. V1 [MISC], V2 [PNB], V3 [AUTO PABRIK], V4 [VISUAL], V5 [SPAM] + CONFIG
-- ═══════════════════════════════════════════════════════════════════════════
local stopAllAutomationImpl
local buildSYTMenuFn

local Config = {
    Folder = "SYT_Config",
    File   = "SYT_Config/config.json",
    State  = {
        autoSave          = true,
        autoRerun         = false,
        autoRerunDelay    = 2.5,
        autoRerunSafe     = true,
        theme             = "Minimalist Monochrome",
        scale             = 1.0,
        fpsBoost          = false,
        fly               = false,
        flySpeed          = 18,
        seems             = false,
        fastRoulette      = false,
        godMode           = false,
        collectState      = false,
        autoCleanDrops    = true,
        autoCollect       = false,
        autoCollectRadius = 5,
        autoCollectStep   = false,
        pnbBlockId        = nil,
        pnbOneHit         = false,
        pnbShowHand       = true,
        pnbAutoCollect    = true,
        pnbLockCenter     = false,
        pnbPlaceDelay     = 0.12,
        pnbBreakDelay     = 0.18,
        pnbCollectDelay   = 0.05,
        pnbGrid5x5        = { ["0,-1"] = true },
        pabrikItem        = "",
        pabrikBreakCount  = 1,
        pabrikOneHit      = false,
        pabrikShowHand    = true,
        pabrikPlaceDelay  = 0.14,
        pabrikBreakDelay  = 0.18,
        pabrikCollectDelay= 0.05,
        visCustomName     = "",
        visRole           = "none",
        visEffect         = "None",
        visTitle          = "none",
        visColorCode      = "",
        visTilesName      = false,
        visHideName       = false,
        visLockNames      = false,
        visGuildTag       = "",
        visBooster        = false,
        spamText          = "",
        spamMaxLen        = 120,
        spamPrefix        = "",
        spamAutoCycle     = false,
        spamDelay         = 3.0,
        spamWhisperAll    = false,
        skipperEnabled    = true,
        skipperUpdateItems= false,
        skipperRange      = 5,
        skipperJMin       = 0.05,
        skipperJMax       = 0.35,
        gapTpDelay        = 0.25,
        followTarget      = "",
        dfBreakDelay      = 0.16,
        dfPlaceDelay      = 0.12,
        dfCollectDelay    = 0.05,
        dfOneHit          = false,
        dfShowHand        = true,
        dfAutoCollect     = true,
        dfCenterGap       = true,
        dfRotationWorlds  = "",
    },
    dirty = false,
}
SYT_Logic.Config = Config

local function markConfigDirty()
    Config.dirty = true
end

local Misc = {
    State = {
        fly = false, flySpeed = 18,
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

function Misc.SetFly(enabled, speed)
    Core.EnsureInit()
    Misc.State.fly = enabled == true
    if type(speed) == "number" then Misc.State.flySpeed = clamp(speed, 4, 60) end
    if H.flyConn then H.flyConn:Disconnect(); H.flyConn = nil end
    Config.State.fly = Misc.State.fly
    Config.State.flySpeed = Misc.State.flySpeed
    markConfigDirty()
    if not Misc.State.fly then
        local p = Core.ReadPos()
        Packets.SendRawMove(p.x, p.y, 0, 0, 2)
        return false
    end
    local lastSync, lastSynced = 0, Core.ReadPos()
    H.flyConn = RunService.RenderStepped:Connect(function(dt)
        if not Misc.State.fly or not H.gt or H.gt.name == "" then return end
        local dx, dy = 0, 0
        if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left) then dx -= 1 end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then dx += 1 end
        if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up) or UserInputService:IsKeyDown(Enum.KeyCode.Space) then dy -= 1 end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down) then dy += 1 end
        local p = Core.ReadPos()
        local nx = clamp(p.x + dx * Misc.State.flySpeed * dt, 0.5, H.gt.w - 0.5)
        local ny = clamp(p.y + dy * Misc.State.flySpeed * dt, 1, H.gt.h - 0.5)
        Core.SetLocalCoords(nx, ny, 0, 0)
        local now = os.clock()
        if (now - lastSync) >= 0.08 or math.max(math.abs(nx - lastSynced.x), math.abs(ny - lastSynced.y)) >= 3.5 then
            local sx = clamp(nx, lastSynced.x - 4, lastSynced.x + 4)
            local sy = clamp(ny, lastSynced.y - 4, lastSynced.y + 4)
            Packets.SendRawMove(sx, sy, 0, 0, 2)
            lastSync = now
            lastSynced = { x = sx, y = sy }
        end
    end)
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
    Config.State.fpsBoost = on
    markConfigDirty()

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

    local parentGui = CoreGui or (LP and LP:FindFirstChildOfClass("PlayerGui"))
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

function Misc.SetFastRoulette(enabled)
    Core.EnsureInit()
    Misc.State.fastRoulette = enabled == true
    Config.State.fastRoulette = Misc.State.fastRoulette
    markConfigDirty()
    if not H.wheelHooked and H.Net and H.Net.wheelSpun and type(H.Net.wheelSpun.listen) == "function" then
        H.wheelHooked = true
        H.Net.wheelSpun.listen(function(pkt)
            if type(pkt) ~= "table" then return end
            Misc.State.lastWheelSpin = pkt
            if Misc.State.fastRoulette then
                task.defer(function()
                    local w = pkt.w or (H.gt and H.gt.w or 100)
                    local idx = (pkt.y or 0) * w + (pkt.x or 0)
                    if H.wheelSpins and type(H.wheelSpins[idx]) == "table" then
                        H.wheelSpins[idx].ends = os.clock()
                    end
                end)
                local validNum = sanitizeRouletteNumber(pkt.n)
                local roller = stripColorTags(pkt.name or "")
                local px, py = toInt(pkt.x, 0), toInt(pkt.y, 0)
                if validNum ~= nil then
                    local msg = string.format("%s -> %d (%d, %d)", roller, validNum, px, py)
                    UI:SetValue("RouletteResultDisplay", msg)
                    showRoulettePopup(roller, validNum, px, py)
                    emitNotify("Fast Roulette [0-36]", msg)
                else
                    local blockedMsg = string.format("Anomali >2 digit diblokir (%s)", tostring(pkt.n))
                    UI:SetValue("RouletteResultDisplay", blockedMsg)
                end
            end
        end)
    end
    return Misc.State.fastRoulette
end

function Misc.SetNoClip(enabled)
    Core.EnsureInit()
    local gt, net = H.gt, H.Net
    if not gt then return false end
    local on = enabled == true
    if on == Misc.State.noClip then return on end
    Misc.State.noClip = on
    if on then
        local pos = Core.ReadPos()
        Misc.State.noClipAnchor = { x = pos.x, y = pos.y, tx = pos.tx, ty = pos.ty }
        gt.ghost = true
        if net and net.move then
            H.origMoveSend = H.origMoveSend or net.move.send
            net.move.send = function(pkt)
                if Misc.State.noClip and Misc.State.noClipAnchor then
                    local a = Misc.State.noClipAnchor
                    return H.origMoveSend({ x = a.x, y = a.y, vx = 0, vy = 0, flags = 2, t = (type(pkt) == "table" and pkt.t) or moveTs() })
                end
                return H.origMoveSend(pkt)
            end
        end
    else
        if net and net.move and H.origMoveSend then net.move.send = H.origMoveSend end
        gt.ghost = false
        local a = Misc.State.noClipAnchor
        Misc.State.noClipAnchor = nil
        if a then
            Core.SetLocalCoords(a.x, a.y, 0, 0)
            if type(gt.goTo) == "function" then pcall(gt.goTo, a.tx, a.ty) end
            Packets.SendRawMove(a.x, a.y, 0, 0, 2)
        end
    end
    return Misc.State.noClip
end

local function hookIncomingGodNet()
    if H.netGodHooked then return end
    H.netGodHooked = true
    local targetEvents = {
        knocked = true, impulse = true, forcedie = true, burned = true, useonplayerfx = true, hurt = true,
    }
    -- Hook tabel handler internal Net DAN gt.on (ForceDie / Burned / Knocked / Impulse / MoveTo)
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

    local function shouldDropMoveTo(x, y)
        if not Misc.State.godMode then return false end
        if x == nil or y == nil then return true end
        local sp = H.gt and H.gt.spawn
        if sp and sp.X and sp.Y then
            local p = Core.ReadPos()
            local distSpawnNow = math.abs(p.x - sp.X) + math.abs(p.y - sp.Y)
            local toSpawn = math.abs(x - sp.X) <= 1.8 and math.abs(y - sp.Y) <= 1.8
            if toSpawn and distSpawnNow > 3 then return true end
        end
        return false
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
                                local origH = handler
                                u[k] = function(...)
                                    if isDmgEv and Misc.State.godMode then return end
                                    if isMoveEv and shouldDropMoveTo(...) then return end
                                    return origH(...)
                                end
                            elseif type(handler) == "table" then
                                for i, cb in pairs(handler) do
                                    if type(cb) == "function" then
                                        local origCb = cb
                                        handler[i] = function(...)
                                            if isDmgEv and Misc.State.godMode then return end
                                            if isMoveEv and shouldDropMoveTo(...) then return end
                                            return origCb(...)
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

function Misc.SetGodMode(enabled)
    Core.EnsureInit()
    local net, gt = H.Net, H.gt
    Misc.State.godMode = enabled == true
    Config.State.godMode = Misc.State.godMode
    markConfigDirty()
    if H.godConn then H.godConn:Disconnect(); H.godConn = nil end

    if net and net.died then
        H.origDiedSend = H.origDiedSend or net.died.send
        net.died.send = Misc.State.godMode and (function() return nil end) or H.origDiedSend
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

    if Misc.State.godMode then
        pcall(hookIncomingGodNet)
    end

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
            end
            if gt then
                if gt.deadSince then gt.deadSince = nil end
                if gt.dying then gt.dying = nil end
                if not Misc.State.noClip and not H.touchHurtIdx then
                    local p = Core.ReadPos()
                    local f1, f2 = Core.GetItemInfo(Core.GetFG(p.tx, p.ty)), Core.GetItemInfo(Core.GetFG(p.tx, p.ty + 1))
                    gt.ghost = ((f1 and (f1.deadly or f1.hurts)) or (f2 and (f2.deadly or f2.hurts))) == true
                end
            end
        end)
    elseif gt and not Misc.State.noClip then
        gt.ghost = false
    end
    return Misc.State.godMode
end

-- Auto Follow Player (Scrollable Dropdown via Walk)
local function extractFollowName(raw)
    local s = trim(tostring(raw or ""))
    if s == "" or s == "Tidak ada player lain" then return "" end
    local bare = string.match(s, "^([^%(%[]+)")
    return trim(bare or s)
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
    Config.State.followTarget = nm
    markConfigDirty()
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
    Config.State.collectState = Misc.State.collectState
    markConfigDirty()
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
                    if type(gt.dropTaken) == "function" then
                        pcall(gt.dropTaken, uid, rem)
                    end
                    task.delay(0.12, function()
                        Core.ClearStuckDropVisuals(uid)
                    end)
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
        Config.State.autoCollectRadius = S.autoCollectRadius
    end
    if stepEnabled ~= nil then
        S.autoCollectStep = stepEnabled == true
        Config.State.autoCollectStep = S.autoCollectStep
    end
    local wantOn = enabled == true
    S.autoCollect = wantOn
    Config.State.autoCollect = wantOn
    markConfigDirty()

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
        running = false, sessionToken = 0, thread = nil, status = "Idle",
        selectedBlockId = nil, grid5x5 = { ["0,-1"] = true },
        oneHit = false, showHand = true, placeDelay = 0.12, breakDelay = 0.18, collectDelay = 0.05,
        autoCollect = true, lockCenterPos = false, centerPos = nil,
    }
}
SYT_Logic.PNB = PNB

local function setPNBStatus(msg)
    PNB.State.status = msg
    if UI then UI:SetValue("PnbStatusDisplay", msg) end
    if UIHooks.updateButtons then UIHooks.updateButtons() end
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
    markConfigDirty()
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
    setPNBStatus("Stopped")
    return false
end

function PNB.Start()
    Core.EnsureInit()
    local S = PNB.State
    if S.running then return true end
    if not S.selectedBlockId then setPNBStatus("Pilih block dari Backpack terlebih dahulu"); return false end
    if #PNB.GetActiveOffsets() == 0 then setPNBStatus("Pilih minimal 1 tile di Pad 5x5"); return false end

    S.running = true
    S.sessionToken += 1
    local token = S.sessionToken
    local pos0 = Core.ReadPos()
    S.centerPos = { tx = pos0.tx, ty = pos0.ty }
    local function alive() return S.running and S.sessionToken == token end
    setPNBStatus("Running...")

    S.thread = task.spawn(function()
        while alive() do
            if evaluateSeems() then break end
            local gt = H.gt
            if not gt or gt.name == "" then setPNBStatus("Keluar dari world"); break end

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
                        targets[#targets + 1] = { tx = tx, ty = ty }
                    end
                end
            end

            -- Bersihkan blok lain jika ada sebelum place target
            for _, t in ipairs(targets) do
                if not alive() then break end
                local curId = Core.GetLayerTile(t.tx, t.ty, layer)
                if curId ~= 0 and curId ~= bid then
                    local g = 0
                    while alive() and Core.GetLayerTile(t.tx, t.ty, layer) ~= 0 and g < 12 do
                        g += 1
                        Packets.HitDamage({ tx = t.tx, ty = t.ty, oneHit = S.oneHit, hitDelay = S.breakDelay, layer = layer, showHand = S.showHand })
                        GetcSkipper.RandomizedWait(S.breakDelay, "tile", alive)
                    end
                    if alive() and S.autoCollect then
                        Packets.Collect({ radius = 5, stepMoveIfFar = false, collectDelay = S.collectDelay, shouldContinue = alive })
                    end
                end
            end

            -- Place pass (skip jika sudah terpasang block target)
            local placedAny = false
            for _, t in ipairs(targets) do
                if not alive() then break end
                local curId = Core.GetLayerTile(t.tx, t.ty, layer)
                if curId == bid then
                    placedAny = true
                elseif curId == 0 and Core.CountItem(bid) > 0 then
                    setPNBStatus(string.format("Place (%d, %d)", t.tx, t.ty))
                    if Packets.Place({ tx = t.tx, ty = t.ty, itemId = bid, layer = layer, showHand = S.showHand }) then
                        placedAny = true
                    end
                    GetcSkipper.RandomizedWait(S.placeDelay, "tile", alive)
                end
            end

            -- Break pass 1 per 1 sampai habis
            local brokeAny = false
            for _, t in ipairs(targets) do
                if not alive() then break end
                if Core.GetLayerTile(t.tx, t.ty, layer) ~= 0 then
                    setPNBStatus(string.format("Break (%d, %d)", t.tx, t.ty))
                    local g = 0
                    while alive() and Core.GetLayerTile(t.tx, t.ty, layer) ~= 0 and g < 12 do
                        g += 1
                        Packets.HitDamage({ tx = t.tx, ty = t.ty, oneHit = S.oneHit, hitDelay = S.breakDelay, layer = layer, showHand = S.showHand })
                        GetcSkipper.RandomizedWait(S.breakDelay, "tile", alive)
                    end
                    brokeAny = true
                end
            end

            if alive() and S.autoCollect then
                Packets.Collect({ radius = 5, stepMoveIfFar = true, collectDelay = S.collectDelay, shouldContinue = alive })
                GetcSkipper.RandomizedWait(S.collectDelay, "take", alive)
            end

            if not alive() then break end
            if Core.CountItem(bid) <= 0 and not brokeAny and not placedAny then
                setPNBStatus("Selesai: Block habis di backpack")
                break
            end
            task.wait(0.03)
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
    Config.State.pabrikItem = Pabrik.State.itemName
    markConfigDirty()
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
    Config.State.pabrikBreakPos = { x = Pabrik.State.breakPos.x, y = Pabrik.State.breakPos.y }
    markConfigDirty()
    if UI then UI:SetValue("PabrikBreakPosDisplay", string.format("BreakPos (%d, %d) [%d tile]", Pabrik.State.breakPos.x, Pabrik.State.breakPos.y, Pabrik.State.breakTileCount)) end
    if UIHooks.refreshPadPab then UIHooks.refreshPadPab() end
    if UIHooks.refreshMap then UIHooks.refreshMap(true) end
    return Pabrik.State.breakPos
end

function Pabrik.SetBreakCount(c)
    Pabrik.State.breakTileCount = clamp(toInt(c, 1), 1, 3)
    Config.State.pabrikBreakCount = Pabrik.State.breakTileCount
    markConfigDirty()
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
                setPabrikStatus(string.format("PNB Block (%d)", Core.CountItem(S.blockId)))
                Packets.StepTeleport(S.breakPos.x, S.breakPos.y, 4, 0.045, alive)
                local offs = computePabrikBreakOffsets(S.breakTileCount)
                while alive() and Core.CountItem(S.blockId) > 0 do
                    if evaluateSeems() then break end
                    for _, off in ipairs(offs) do
                        if not alive() or Core.CountItem(S.blockId) <= 0 then break end
                        local tx, ty = S.breakPos.x + off.dx, S.breakPos.y + off.dy
                        if tx >= 0 and tx < gt.w and ty >= 0 and ty < gt.h and Core.CanEditTile(tx, ty) then
                            local curId = Core.GetLayerTile(tx, ty, layer)
                            if curId ~= 0 and curId ~= S.blockId then
                                Packets.HitDamage({ tx = tx, ty = ty, oneHit = S.oneHit, hitDelay = S.breakDelay, layer = layer, showHand = S.showHand, autoRange = false })
                                GetcSkipper.RandomizedWait(S.breakDelay, "tile", alive)
                            end
                            if alive() and Core.GetLayerTile(tx, ty, layer) == 0 and Core.CountItem(S.blockId) > 0 then
                                Packets.Place({ tx = tx, ty = ty, itemId = S.blockId, layer = layer, showHand = S.showHand, autoRange = false })
                                GetcSkipper.RandomizedWait(S.placeDelay, "tile", alive)
                            end
                        end
                    end
                    for _, off in ipairs(offs) do
                        if not alive() then break end
                        local tx, ty = S.breakPos.x + off.dx, S.breakPos.y + off.dy
                        local g = 0
                        while alive() and Core.GetLayerTile(tx, ty, layer) ~= 0 and g < 12 do
                            g += 1
                            Packets.HitDamage({ tx = tx, ty = ty, oneHit = S.oneHit, hitDelay = S.breakDelay, layer = layer, showHand = S.showHand, autoRange = false })
                            GetcSkipper.RandomizedWait(S.breakDelay, "tile", alive)
                        end
                    end
                    if alive() then
                        Packets.Collect({ radius = 5, stepMoveIfFar = true, collectDelay = S.collectDelay, shouldContinue = alive })
                        GetcSkipper.RandomizedWait(S.collectDelay, "take", alive)
                    end
                end
            elseif Core.CountItem(S.seedId) > 0 then
                Packets.Collect({ radius = 5, stepMoveIfFar = false, collectDelay = S.collectDelay, shouldContinue = alive })
                for _, t in ipairs(Pabrik.GetSortedTiles()) do
                    if not alive() or evaluateSeems() then break end
                    if Core.CountItem(S.blockId) > 0 or Core.CountItem(S.seedId) <= 0 then break end
                    if Core.IsPlantable(t.x, t.y) then
                        setPabrikStatus(string.format("Plant (%d, %d)", t.x, t.y))
                        GetcSkipper.EnsureRange(t.x, t.y, 4, 0.045, alive)
                        if alive() then
                            Packets.Place({ tx = t.x, ty = t.y, itemId = S.seedId, layer = 1, showHand = S.showHand, autoRange = false })
                            GetcSkipper.RandomizedWait(S.placeDelay, "tile", alive)
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
                    Packets.Collect({ radius = 5, stepMoveIfFar = true, collectDelay = S.collectDelay, shouldContinue = alive })
                    setPabrikStatus("Menunggu seed/block (habis)")
                    GetcSkipper.RandomizedWait(0.45, nil, alive)
                else
                    GetcSkipper.RandomizedWait(0.20, nil, alive)
                end
            elseif #ready < #planted then
                setPabrikStatus(string.format("Grow %d/%d (~%.1fs)", #ready, #planted, minRem or 0))
                GetcSkipper.RandomizedWait(0.35, nil, alive)
            else
                setPabrikStatus(string.format("Harvesting %d trees", #ready))
                for _, t in ipairs(ready) do
                    if not alive() or evaluateSeems() then break end
                    GetcSkipper.EnsureRange(t.x, t.y, 4, 0.045, alive)
                    if not alive() then break end
                    Packets.PunchBreak({ tx = t.x, ty = t.y, layer = 1, showHand = S.showHand, autoRange = false })
                    GetcSkipper.RandomizedWait(S.breakDelay, "tile", alive)
                    if alive() and Core.GetFG(t.x, t.y) == 0 then
                        Packets.Collect({ radius = 5, stepMoveIfFar = false, collectDelay = S.collectDelay, shouldContinue = alive })
                    end
                end
                if alive() then
                    Packets.Collect({ radius = 5, stepMoveIfFar = true, collectDelay = S.collectDelay, shouldContinue = alive })
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

-- [DIRT FARM] Auto Break & Replace Non-Dirt -> Format Dirt Farm + Rotation World
local DirtFarm = {
    State = {
        running = false, sessionToken = 0, thread = nil, status = "Idle",
        breakDelay = 0.16, placeDelay = 0.12, collectDelay = 0.05,
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
        local w = string.upper(trim(token))
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
    Config.State.dfRotationWorlds = DirtFarm.State.rotationText
    markConfigDirty()
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
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local id = Core.GetFG(x, y)
            if id == 6 then
                doorX, doorY = x, y
                break
            elseif id > 0 then
                local info = Core.GetItemInfo(id)
                if info and (info.door or info.entrance) then
                    doorX, doorY = x, y
                    break
                end
            end
        end
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

local function moveNearDfTile(tx, ty, shouldContinueFn)
    local cur = Core.ReadPos()
    if math.max(math.abs(cur.tx - tx), math.abs(cur.ty - ty)) <= 4 then
        return true
    end
    local gt = H.gt
    local w, h = (gt and gt.w) or 100, (gt and gt.h) or 60
    local candOffsets = {
        { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 },
        { -2, 0 }, { 2, 0 }, { 0, -2 }, { 0, 2 },
        { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 },
    }
    local goalX, goalY = tx, ty
    for _, off in ipairs(candOffsets) do
        local ax, ay = clamp(tx + off[1], 0, w - 1), clamp(ty + off[2], 0, h - 1)
        if not Core.IsSolid(ax, ay) then
            goalX, goalY = ax, ay
            break
        end
    end
    local ok = Packets.StepTeleport(goalX, goalY, 2, 0.065, shouldContinueFn)
    if not ok then
        GetcSkipper.EnsureRange(tx, ty, 4)
    end
    return true
end

local function dfBreakTile(tx, ty, aliveFn)
    local S = DirtFarm.State
    moveNearDfTile(tx, ty, aliveFn)
    Packets.HitDamage({
        tx = tx, ty = ty, layer = 1,
        oneHit = S.oneHit, showHand = S.showHand,
        hitDelay = S.breakDelay,
    })
    GetcSkipper.RandomizedWait(S.breakDelay, "act", aliveFn)
    if S.autoCollect then
        Packets.Collect({ radius = 5, collectDelay = S.collectDelay, shouldContinueFn = aliveFn })
    end
end

local function dfPlaceDirt(tx, ty, dirtId, aliveFn)
    local S = DirtFarm.State
    if Core.CountItem(dirtId) <= 0 and S.autoCollect then
        Packets.Collect({ radius = 6, stepMoveIfFar = true, collectDelay = S.collectDelay, shouldContinueFn = aliveFn })
    end
    if Core.CountItem(dirtId) <= 0 then
        return false, "no_dirt"
    end
    moveNearDfTile(tx, ty, aliveFn)
    Packets.Place({ tx = tx, ty = ty, itemId = dirtId, layer = 1, showHand = S.showHand })
    GetcSkipper.RandomizedWait(S.placeDelay, "tile", aliveFn)
    return true
end

function DirtFarm.Start()
    Core.EnsureInit()
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
        while alive() do
            if evaluateSeems() then break end
            Core.EnsureInit()
            gt = H.gt
            if not gt or gt.name == "" then
                setDfStatus("Menunggu world...")
                task.wait(0.5)
            else
                local bp = buildDfBlueprint(gt)
                local dirtId = bp.dirtId

                -- 1. Kumpulkan semua tugas DF berurutan:
                --    (A) Gali sisi 2 kiri/kanan + center + lorong air bawah kelipatan 2 + baris atas bedrock
                --    (B) Ganti non-dirt (rock/lava) & isi celah di baris dirt bawah
                --    (C) Bersihkan + Place Dirt baris atas (y < doorY) kelipatan 2 bottom-up
                local digLowerTasks, fillLowerTasks, upperTasks = {}, {}, {}

                for y = bp.doorY, bp.maxWorkY do
                    local rev = ((y - bp.doorY) % 2 == 1)
                    local xStart, xEnd, xStep = rev and (bp.w - 1) or 0, rev and 0 or (bp.w - 1), rev and -1 or 1
                    for x = xStart, xEnd, xStep do
                        local want = bp.desiredAt(x, y)
                        if want ~= nil then
                            local curId = Core.GetFG(x, y)
                            if want == 0 and curId ~= 0 then
                                digLowerTasks[#digLowerTasks + 1] = { x = x, y = y, op = "break" }
                            elseif want == dirtId and curId ~= dirtId then
                                fillLowerTasks[#fillLowerTasks + 1] = { x = x, y = y, op = (curId ~= 0) and "replace" or "place" }
                            end
                        end
                    end
                end

                for y = bp.doorY - 1, bp.topY, -1 do
                    local rev = ((bp.doorY - y) % 2 == 0)
                    local xStart, xEnd, xStep = rev and (bp.w - 1) or 0, rev and 0 or (bp.w - 1), rev and -1 or 1
                    for x = xStart, xEnd, xStep do
                        local want = bp.desiredAt(x, y)
                        if want ~= nil then
                            local curId = Core.GetFG(x, y)
                            if want == 0 and curId ~= 0 then
                                digLowerTasks[#digLowerTasks + 1] = { x = x, y = y, op = "break" }
                            elseif want == dirtId and curId ~= dirtId then
                                upperTasks[#upperTasks + 1] = { x = x, y = y, op = (curId ~= 0) and "replace" or "place" }
                            end
                        end
                    end
                end

                local totalTodo = #digLowerTasks + #fillLowerTasks + #upperTasks
                if totalTodo == 0 then
                    local curW = cleanWorldName(gt.name)
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
                            Packets.Collect({ radius = 6, stepMoveIfFar = true, collectDelay = DirtFarm.State.collectDelay, shouldContinueFn = alive })
                        end
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
                        setDfStatus(string.format("Selesai! World %s 100%% Dirt Farm", curW))
                        emitNotify("SYT Dirt Farm", "Dirt Farm selesai sempurna di world " .. curW)
                        DirtFarm.State.running = false
                        break
                    end
                else
                    local activeQueue = (#digLowerTasks > 0 and digLowerTasks)
                        or (#fillLowerTasks > 0 and fillLowerTasks)
                        or upperTasks
                    local phaseLabel = (#digLowerTasks > 0 and "Fase 1: Gali Pojok & Baris Bawah")
                        or (#fillLowerTasks > 0 and "Fase 1b: Ubah Rock/Lava -> Dirt")
                        or "Fase 2: Place Dirt Atas"

                    for i, taskItem in ipairs(activeQueue) do
                        if not alive() or evaluateSeems() then break end
                        setDfStatus(string.format("%s (%d/%d | Sisa:%d) (%d,%d)", phaseLabel, i, #activeQueue, totalTodo - i + 1, taskItem.x, taskItem.y))
                        local curId = Core.GetFG(taskItem.x, taskItem.y)
                        if taskItem.op == "break" then
                            if curId ~= 0 and not Core.IsProtectedTile(curId) then
                                dfBreakTile(taskItem.x, taskItem.y, alive)
                            end
                        elseif taskItem.op == "replace" then
                            if curId ~= 0 and curId ~= dirtId and not Core.IsProtectedTile(curId) then
                                dfBreakTile(taskItem.x, taskItem.y, alive)
                            end
                            if Core.GetFG(taskItem.x, taskItem.y) == 0 then
                                local okP = dfPlaceDirt(taskItem.x, taskItem.y, dirtId, alive)
                                if not okP then
                                    setDfStatus("Dirt di Backpack habis! Cari/ambil Dirt drops...")
                                    task.wait(0.8)
                                    break
                                end
                            end
                        elseif taskItem.op == "place" then
                            if Core.GetFG(taskItem.x, taskItem.y) == 0 then
                                local okP = dfPlaceDirt(taskItem.x, taskItem.y, dirtId, alive)
                                if not okP then
                                    setDfStatus("Dirt di Backpack habis! Cari/ambil Dirt drops...")
                                    task.wait(0.8)
                                    break
                                end
                            end
                        end
                    end
                end
            end
            task.wait(0.05)
        end

        DirtFarm.State.switchingWorld = false
        if DirtFarm.State.sessionToken == tok then
            DirtFarm.State.running = false
            DirtFarm.State.thread = nil
            if DirtFarm.State.status == "Idle" or string.find(DirtFarm.State.status, "Fase", 1, true) then
                setDfStatus("Stopped")
            elseif UIHooks.updateButtons then
                UIHooks.updateButtons()
            end
        end
    end)
    return true
end

function DirtFarm.Stop()
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

-- V4 [SET VISUALISASI]
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
    State = {
        customName = "", role = "none", effect = "None", colorCode = "", customTitle = "none",
        guildTag = "", booster = false,
        tilesName = false, hideName = false, lockNames = false,
        lastWorldName = "", lastPosKey = "", origSaved = false,
        origNick = nil, origGameName = nil, origWornTitle = nil, origDrTitle = nil,
        origRoleAttr = nil, origTitleAttr = nil, origGuildRank = nil, origBooster = nil,
    }
}
SYT_Logic.Visual = Visual

local function findNameTag()
    local pg = LP and LP:FindFirstChildOfClass("PlayerGui")
    local gg = pg and pg:FindFirstChild("GameGui")
    if not gg then return nil end
    for _, obj in ipairs(gg:GetDescendants()) do
        if obj.Name == "NameTag" and obj:IsA("GuiObject") then return obj end
    end
    return nil
end

local function saveOrigVisual()
    local S = Visual.State
    if S.origSaved or not LP then return end
    S.origSaved = true
    S.origNick      = LP:GetAttribute("Nick")
    S.origGameName  = LP:GetAttribute("GameName")
    S.origWornTitle = LP:GetAttribute("WornTitle")
    S.origDrTitle   = LP:GetAttribute("DrTitle")
    S.origGuildRank = LP:GetAttribute("GuildRank")
    S.origBooster   = LP:GetAttribute("DiscordBooster")
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

function Visual.Apply()
    Core.EnsureInit()
    saveOrigVisual()
    local S = Visual.State
    if not LP then return false end
    local base = (S.customName ~= "" and S.customName) or (S.origGameName and tostring(S.origGameName)) or Core.GetInGameName(LP, true)
    local pos  = Core.ReadPos()
    local rLow = string.lower(tostring(S.role or "none"))
    local body = base .. (S.tilesName and string.format(" [%d,%d]", pos.tx, pos.ty) or "")

    -- Gabungkan effect + role badge (dengan efek BitmapText game asli)
    local styledBody = wrapVisualEffect(body, S.effect or "None", S.colorCode or "")
    local roleBadge  = ROLE_BADGES[rLow] or ""
    local finalNick  = (roleBadge ~= "" and rLow ~= "developer" and rLow ~= "moderator") and (roleBadge .. styledBody) or styledBody
    if rLow == "dr" and not string.find(string.lower(body), "^dr%.") then
        finalNick = wrapVisualEffect("Dr." .. body, S.effect or "None", (S.colorCode ~= "") and S.colorCode or "`2")
    end

    -- Trigger attribute redraw di NameUI/Game.lua (`Nick` & `Undercover`)
    LP:SetAttribute("Nick", finalNick)

    local k = "u" .. tostring(LP.UserId)
    local sr = ReplicatedStorage:FindFirstChild("StaffRoles")
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
        LP:SetAttribute("WornTitle", chosenTitle)
        if chosenTitle == "dr" then LP:SetAttribute("DrTitle", "Dr." .. base) end
        if tl then tl:SetAttribute(k, chosenTitle) end
    else
        LP:SetAttribute("WornTitle", S.origWornTitle)
        LP:SetAttribute("DrTitle", S.origDrTitle)
        if tl then tl:SetAttribute(k, S.origTitleAttr) end
    end

    if S.guildTag ~= "" then
        LP:SetAttribute("GuildRank", S.guildTag)
    else
        LP:SetAttribute("GuildRank", S.origGuildRank)
    end
    LP:SetAttribute("DiscordBooster", S.booster == true or S.origBooster)

    local tag = findNameTag()
    if tag then tag.Visible = not S.hideName end
    S.lastPosKey = tileKey(pos.tx, pos.ty)
    markConfigDirty()
    return true
end

function Visual.Restore()
    saveOrigVisual()
    local S = Visual.State
    S.customName, S.role, S.effect, S.colorCode, S.customTitle = "", "none", "None", "", "none"
    S.guildTag, S.booster, S.tilesName, S.hideName = "", false, false, false
    if LP then
        LP:SetAttribute("Nick", S.origNick)
        LP:SetAttribute("GameName", S.origGameName)
        LP:SetAttribute("WornTitle", S.origWornTitle)
        LP:SetAttribute("DrTitle", S.origDrTitle)
        LP:SetAttribute("GuildRank", S.origGuildRank)
        LP:SetAttribute("DiscordBooster", S.origBooster)
        local k = "u" .. tostring(LP.UserId)
        local sr, tl = ReplicatedStorage:FindFirstChild("StaffRoles"), ReplicatedStorage:FindFirstChild("TitleList")
        if sr then sr:SetAttribute(k, S.origRoleAttr) end
        if tl then tl:SetAttribute(k, S.origTitleAttr) end
    end
    local tag = findNameTag()
    if tag then tag.Visible = true end
    markConfigDirty()
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
        while alive() do
            if evaluateSeems() or not H.gt or H.gt.name == "" then break end
            if S.experimentalWhisperAll then
                for _, p in ipairs(Core.GetInWorldPlayers(false)) do
                    if not alive() or evaluateSeems() then break end
                    setSpamStatus("Whisper -> " .. p.gameName)
                    Packets.SendChat({ message = Spam.FormatNextMessage(), maxLength = S.maxLength, isWhisper = true, whisperTarget = p.gameName, bypassRateLimit = true })
                    GetcSkipper.RandomizedWait(S.delay, "chat", alive)
                end
            else
                Packets.SendChat({ message = Spam.FormatNextMessage(), maxLength = S.maxLength, bypassRateLimit = true })
                GetcSkipper.RandomizedWait(S.delay, "chat", alive)
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

stopAllAutomationImpl = function(reason)
    PNB.Stop()
    Pabrik.Stop()
    DirtFarm.Stop()
    Spam.Stop()
    stopRandomTp()
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
    end
    if UIHooks.updateButtons then UIHooks.updateButtons() end
end
SYT_Logic.StopAllAutomation = stopAllAutomationImpl

-- Config Save / Auto-Load / Safe-Rerun Engine
function Config.CaptureFromRuntime()
    local C = Config.State
    C.flySpeed          = Misc.State.flySpeed
    C.fly               = Misc.State.fly
    C.seems             = Misc.State.seems
    C.fastRoulette      = Misc.State.fastRoulette
    C.godMode           = Misc.State.godMode
    C.collectState      = Misc.State.collectState
    C.autoCleanDrops    = Misc.State.autoCleanDrops
    C.autoCollect       = Misc.State.autoCollect
    C.autoCollectRadius = Misc.State.autoCollectRadius
    C.autoCollectStep   = Misc.State.autoCollectStep
    C.fpsBoost          = Misc.State.fpsBoost

    C.pnbBlockId     = PNB.State.selectedBlockId
    C.pnbOneHit      = PNB.State.oneHit
    C.pnbShowHand    = PNB.State.showHand
    C.pnbAutoCollect = PNB.State.autoCollect
    C.pnbLockCenter  = PNB.State.lockCenterPos
    C.pnbPlaceDelay  = PNB.State.placeDelay
    C.pnbBreakDelay  = PNB.State.breakDelay
    C.pnbCollectDelay= PNB.State.collectDelay
    C.pnbGrid5x5     = PNB.State.grid5x5

    C.pabrikItem         = Pabrik.State.itemName
    C.pabrikBreakCount   = Pabrik.State.breakTileCount
    C.pabrikOneHit       = Pabrik.State.oneHit
    C.pabrikShowHand     = Pabrik.State.showHand
    C.pabrikPlaceDelay   = Pabrik.State.placeDelay
    C.pabrikBreakDelay   = Pabrik.State.breakDelay
    C.pabrikCollectDelay = Pabrik.State.collectDelay
    C.pabrikBreakPos     = Pabrik.State.breakPos

    C.visCustomName = Visual.State.customName
    C.visRole       = Visual.State.role
    C.visEffect     = Visual.State.effect
    C.visTitle      = Visual.State.customTitle
    C.visColorCode  = Visual.State.colorCode
    C.visTilesName  = Visual.State.tilesName
    C.visHideName   = Visual.State.hideName
    C.visLockNames  = Visual.State.lockNames
    C.visGuildTag   = Visual.State.guildTag
    C.visBooster    = Visual.State.booster

    C.spamText       = Spam.State.text
    C.spamMaxLen     = Spam.State.maxLength
    C.spamPrefix     = Spam.State.prefixColor
    C.spamAutoCycle  = Spam.State.autoCycleColor
    C.spamDelay      = Spam.State.delay
    C.spamWhisperAll = Spam.State.experimentalWhisperAll

    C.skipperEnabled     = GetcSkipper.State.enabled
    C.skipperUpdateItems = GetcSkipper.State.skipUpdateItems
    C.skipperRange       = GetcSkipper.State.maxRangeTiles
    C.skipperJMin        = GetcSkipper.State.jitterMin
    C.skipperJMax        = GetcSkipper.State.jitterMax
    C.gapTpDelay         = tpState.patrolDelay
    C.followTarget       = Misc.State.followTarget

    C.dfBreakDelay       = DirtFarm.State.breakDelay
    C.dfPlaceDelay       = DirtFarm.State.placeDelay
    C.dfCollectDelay     = DirtFarm.State.collectDelay
    C.dfOneHit           = DirtFarm.State.oneHit
    C.dfShowHand         = DirtFarm.State.showHand
    C.dfAutoCollect      = DirtFarm.State.autoCollect
    C.dfCenterGap        = DirtFarm.State.centerGap
    C.dfRotationWorlds   = DirtFarm.State.rotationText
    return C
end

function Config.Save(silent)
    Config.CaptureFromRuntime()
    Config.dirty = false
    local env = getEnv()
    env.SYT_SavedConfig = Config.State
    local okEnc, jsonStr = pcall(function() return HttpService:JSONEncode(Config.State) end)
    if okEnc and type(jsonStr) == "string" then
        pcall(function()
            if type(isfolder) == "function" and type(makefolder) == "function" and not isfolder(Config.Folder) then
                makefolder(Config.Folder)
            end
            if type(writefile) == "function" then
                writefile(Config.File, jsonStr)
            end
        end)
    end
    if not silent then
        emitNotify("SYT Config", "Konfigurasi tersimpan ke SYT_Config/config.json")
    end
    return true
end

function Config.ApplyRuntime(safeBoot)
    local C = Config.State
    PNB.State.selectedBlockId = C.pnbBlockId
    PNB.State.oneHit          = C.pnbOneHit == true
    PNB.State.showHand        = C.pnbShowHand ~= false
    PNB.State.autoCollect     = C.pnbAutoCollect ~= false
    PNB.State.lockCenterPos   = C.pnbLockCenter == true
    PNB.State.placeDelay      = tonumber(C.pnbPlaceDelay) or 0.12
    PNB.State.breakDelay      = tonumber(C.pnbBreakDelay) or 0.18
    PNB.State.collectDelay    = tonumber(C.pnbCollectDelay) or 0.05
    if type(C.pnbGrid5x5) == "table" and next(C.pnbGrid5x5) ~= nil then
        PNB.State.grid5x5 = C.pnbGrid5x5
    end

    Pabrik.State.breakTileCount = clamp(toInt(C.pabrikBreakCount, 1), 1, 3)
    Pabrik.State.oneHit         = C.pabrikOneHit == true
    Pabrik.State.showHand       = C.pabrikShowHand ~= false
    Pabrik.State.placeDelay     = tonumber(C.pabrikPlaceDelay) or 0.14
    Pabrik.State.breakDelay     = tonumber(C.pabrikBreakDelay) or 0.18
    Pabrik.State.collectDelay   = tonumber(C.pabrikCollectDelay) or 0.05
    if type(C.pabrikBreakPos) == "table" and C.pabrikBreakPos.x and C.pabrikBreakPos.y then
        Pabrik.State.breakPos = { x = C.pabrikBreakPos.x, y = C.pabrikBreakPos.y }
    end
    if type(C.pabrikItem) == "string" and C.pabrikItem ~= "" then
        pcall(Pabrik.SetItem, C.pabrikItem)
    end

    Visual.State.customName  = tostring(C.visCustomName or "")
    Visual.State.role        = tostring(C.visRole or "none")
    Visual.State.effect      = tostring(C.visEffect or "None")
    Visual.State.customTitle = tostring(C.visTitle or "none")
    Visual.State.colorCode   = tostring(C.visColorCode or "")
    Visual.State.tilesName   = C.visTilesName == true
    Visual.State.hideName    = C.visHideName == true
    Visual.State.lockNames   = C.visLockNames == true
    Visual.State.guildTag    = tostring(C.visGuildTag or "")
    Visual.State.booster     = C.visBooster == true

    Spam.State.text                   = tostring(C.spamText or "")
    Spam.State.maxLength              = clamp(toInt(C.spamMaxLen, 120), 20, 120)
    Spam.State.prefixColor            = tostring(C.spamPrefix or "")
    Spam.State.autoCycleColor         = C.spamAutoCycle == true
    Spam.State.delay                  = tonumber(C.spamDelay) or 3.0
    Spam.State.experimentalWhisperAll = C.spamWhisperAll == true

    GetcSkipper.State.enabled       = C.skipperEnabled ~= false
    GetcSkipper.State.maxRangeTiles = clamp(toInt(C.skipperRange, 5), 1, 5)
    GetcSkipper.State.jitterMin     = tonumber(C.skipperJMin) or 0.05
    GetcSkipper.State.jitterMax     = tonumber(C.skipperJMax) or 0.35
    tpState.patrolDelay             = tonumber(C.gapTpDelay) or 0.25

    Misc.State.flySpeed          = clamp(toInt(C.flySpeed, 18), 4, 60)
    Misc.State.autoCleanDrops    = C.autoCleanDrops ~= false
    Misc.State.autoCollectRadius = clamp(toInt(C.autoCollectRadius, 5), 1, 6)
    Misc.State.autoCollectStep   = C.autoCollectStep == true
    Misc.State.followTarget      = tostring(C.followTarget or "")

    DirtFarm.State.breakDelay   = tonumber(C.dfBreakDelay) or 0.16
    DirtFarm.State.placeDelay   = tonumber(C.dfPlaceDelay) or 0.12
    DirtFarm.State.collectDelay = tonumber(C.dfCollectDelay) or 0.05
    DirtFarm.State.oneHit       = C.dfOneHit == true
    DirtFarm.State.showHand     = C.dfShowHand ~= false
    DirtFarm.State.autoCollect  = C.dfAutoCollect ~= false
    DirtFarm.State.centerGap    = C.dfCenterGap ~= false
    if type(C.dfRotationWorlds) == "string" then
        DirtFarm.SetRotationWorlds(C.dfRotationWorlds)
    end

    -- Pastikan Safe Mode menjaga loop berbahaya OFF sementara fitur aman / non-safe dipulihkan
    if not safeBoot then
        if C.fly then Misc.SetFly(true, C.flySpeed) end
        if C.seems then Misc.SetSeems(true) end
        if C.fastRoulette then Misc.SetFastRoulette(true) end
        if C.godMode then Misc.SetGodMode(true) end
        if C.collectState then Misc.SetCollectState(true) end
        if C.autoCollect then Misc.SetAutoCollect(true, C.autoCollectRadius, C.autoCollectStep) end
        if C.fpsBoost then Misc.SetFpsBoost(true) end
        if C.skipperUpdateItems then GetcSkipper.SetSkipUpdateItems(true) end
    else
        -- Safe ON: hanya pulihkan utilitas pasif yang aman jika aktif, semua loop tetap OFF
        PNB.State.running, Pabrik.State.running, DirtFarm.State.running, Spam.State.running, tpState.patrolOn, Misc.State.autoFollow = false, false, false, false, false, false
        if C.fpsBoost then Misc.SetFpsBoost(true) end
        if C.fastRoulette then Misc.SetFastRoulette(true) end
        if C.collectState then Misc.SetCollectState(true) end
        if C.seems then Misc.SetSeems(true) end
        if C.godMode then Misc.SetGodMode(true) end
    end
    if UI then
        if C.theme and UI.SetTheme then pcall(function() UI:SetTheme(C.theme) end) end
        if C.scale and UI.SetScale then pcall(function() UI:SetScale(C.scale) end) end
    end
end

function Config.Load(applyNow)
    local rawTbl = nil
    pcall(function()
        if type(isfile) == "function" and type(readfile) == "function" and isfile(Config.File) then
            local content = readfile(Config.File)
            if type(content) == "string" and #content > 2 then
                local okDec, dec = pcall(function() return HttpService:JSONDecode(content) end)
                if okDec and type(dec) == "table" then rawTbl = dec end
            end
        end
    end)
    if not rawTbl then
        local env = getEnv()
        if type(env.SYT_SavedConfig) == "table" then rawTbl = env.SYT_SavedConfig end
    end
    if type(rawTbl) == "table" then
        for k, v in pairs(rawTbl) do
            if Config.State[k] ~= nil or k == "pnbBlockId" or k == "pabrikBreakPos" then
                Config.State[k] = v
            end
        end
    end
    if applyNow then
        Config.ApplyRuntime(Config.State.autoRerunSafe ~= false)
    end
    return rawTbl ~= nil
end

function Config.Reset()
    pcall(function()
        if type(delfile) == "function" and type(isfile) == "function" and isfile(Config.File) then
            delfile(Config.File)
        end
    end)
    getEnv().SYT_SavedConfig = nil
    emitNotify("SYT Config", "File config di-reset.")
end

function SYT_Logic.TriggerAutoRerun(reason)
    if UIHooks.rerunning then return end
    UIHooks.rerunning = true
    Config.Save(true)
    local delaySec = clamp(tonumber(Config.State.autoRerunDelay) or 2.5, 0.5, 15)
    local isSafe   = Config.State.autoRerunSafe ~= false

    if UI and UI.Destroy then
        pcall(function() UI:Destroy() end)
    end

    task.spawn(function()
        emitNotify("SYT Auto Rerun", string.format("%s | Rerun dalam %.1fs (Safe: %s)", tostring(reason or "Menu Closed"), delaySec, isSafe and "ON" or "OFF"))
        task.wait(delaySec)
        for _ = 1, 80 do
            if Players.LocalPlayer and SYT_Logic.Init(true) and H.gt and H.gt.name ~= "" then
                break
            end
            task.wait(0.25)
        end
        Config.Load(false)
        initSYTWindow(Config.State.theme, Config.State.scale)
        if type(buildSYTMenuFn) == "function" then
            buildSYTMenuFn()
        end
        Config.ApplyRuntime(isSafe)
        if UIHooks.refreshMap then UIHooks.refreshMap(true) end
        if UIHooks.refreshBP then UIHooks.refreshBP() end
        if UIHooks.updateButtons then UIHooks.updateButtons() end
        UIHooks.rerunning = false
        emitNotify("SYT Auto Rerun", "Menu aktif kembali dengan konfigurasi tersimpan!")
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- 7. SYT GUI LAYOUT (R&8_DV CANVAS + V1/V2 TABS + FEATURE TAMBAHAN PANELS)
-- ═══════════════════════════════════════════════════════════════════════════
local buildMountedCanvasesFn

buildSYTMenuFn = function()
    UIHooks.refreshMap     = nil
    UIHooks.refreshBP      = nil
    UIHooks.refreshPad5x5  = nil
    UIHooks.refreshPadPab  = nil
    UIHooks.sidebarNameLbl = nil
    UIHooks.sidebarSubLbl  = nil

    -- Hook Close Button (X) & ScreenGui Destroy untuk Auto Rerun Menu
    UI.OnCloseMenu = function(self)
        if Config.State.autoRerun then
            self._CancelDefaultClose = true
            task.defer(function()
                SYT_Logic.TriggerAutoRerun("Menu Ditutup")
            end)
        end
    end
    task.defer(function()
        local gEnv = getEnv()
        local activeUi = gEnv and gEnv.__R8_DV_ACTIVE_UI
        local sg = activeUi and activeUi.ScreenGui
        if sg then
            sg.AncestryChanged:Connect(function(_, newParent)
                if not newParent and Config.State.autoRerun and not UIHooks.rerunning then
                    task.defer(function()
                        SYT_Logic.TriggerAutoRerun("GUI Closed")
                    end)
                end
            end)
        end
    end)

    local C = Config.State
    if UI.Category then UI:Category("Overview") end

    feature("Home", "Home")({
        center = center(function(c)
            c:Header("SYT Growblox Suite Overview", "Akun In-Game aktif, player di world, konfigurasi & kontrol cepat", "SYT")

            c:StatRow({
                { Icon = "Player",    Label = "In-Game Account", Value = Core.GetInGameName(LP, true) },
                { Icon = "Teleports", Label = "Max Step Range",  Value = "<= 5 Tiles" },
                { Icon = "Shield",    Label = "Guard System",    Value = "GetcSkip" },
            })

            local InfoCard = c:Card("Akun Game & Player World (Live)", "Live", "Player", {
                Subtitle = "Mengambil akun in-game (GameName/Nick), bukan username Roblox"
            })
            InfoCard:Input("Akun Game & World", "LiveInGameAccount", "Menunggu world...", Core.GetInGameName(LP, true))
            InfoCard:Input("Daftar Player World", "LiveWorldPlayers", "Menunggu scan...", "-")
            InfoCard:Button("Scan / Refresh Semua Modul", "SCAN", "Bolt", function()
                pcall(SYT_Logic.Init, true)
                local plrs = Core.GetInWorldPlayers(true)
                local names = {}
                for _, p in ipairs(plrs) do
                    names[#names + 1] = p.gameName .. (p.isStaff and "[STAFF]" or "")
                end
                UI:SetValue("LiveInGameAccount", string.format("%s | World: %s", Core.GetInGameName(LP, true), (H.gt and H.gt.name ~= "" and H.gt.name) or "-"))
                UI:SetValue("LiveWorldPlayers", #names > 0 and table.concat(names, ", ") or "-")
                if UIHooks.refreshBP then UIHooks.refreshBP() end
                if UIHooks.refreshMap then UIHooks.refreshMap(true) end
            end)
            InfoCard:Button("STOP SEMUA OTOMASI", "STOP ALL", "Shield", function()
                stopAllAutomationImpl("Dihentikan manual oleh user")
            end)
        end),

        right = right(function(r)
            local CfgCard = r:Card("Save Config & Auto Load", "Auto", "Shield", {
                Subtitle = "Simpan ke SYT_Config/config.json agar langsung termuat saat rerun"
            })
            CfgCard:Toggle("Auto Save Config", "CfgAutoSave", C.autoSave ~= false, function(v)
                C.autoSave = v
                markConfigDirty()
                if v then Config.Save(true) end
            end)
            CfgCard:Button("Simpan Config Sekarang", "SAVE", "Bolt", function()
                Config.Save(false)
            end)
            CfgCard:Button("Muat Ulang Config Tersimpan", "LOAD", "Visuals", function()
                if Config.Load(true) then
                    emitNotify("SYT Config", "Config tersimpan dimuat!")
                else
                    emitNotify("SYT Config", "Belum ada file config tersimpan.")
                end
            end)
            CfgCard:Button("Reset Config Tersimpan", "RESET", "Shield", function()
                Config.Reset()
            end)

            local ThemeCard = r:Card("Theme & Checklist", nil, "Palette", {
                Subtitle = "Pilih tema tampilan dan gaya switch"
            })
            if ThemeCard.ThemeSwatches then ThemeCard:ThemeSwatches("Colour Palette") end
            ThemeCard:Dropdown("Color Style", "ThemeSelect", ThemeChoices, C.theme or "Minimalist Monochrome", function(sel)
                C.theme = sel
                markConfigDirty()
                UI:SetTheme(sel)
            end)
            ThemeCard:Dropdown("Checkbox Style", "CheckboxStyleMode", { "Modern", "Checkbox" }, "Modern", function(mode)
                if UI.SetCheckboxStyle then UI:SetCheckboxStyle(mode) end
            end)
            ThemeCard:Slider("Letter Spacing", "LetterSpacingVal", 0, 3, 1, "x", function(val)
                if UI.SetLetterSpacing then UI:SetLetterSpacing(val) end
            end)

            local LayoutCard = r:Card("Window & Layout", nil, "Sliders", {
                Subtitle = "Atur UI Scale, transparency, rounded borders & hotkey menu"
            })
            LayoutCard:Slider("UI Scale", "UIScalePct", 60, 130, math.floor((C.scale or 1) * 100), "%", function(val)
                C.scale = val / 100
                markConfigDirty()
                if UI.SetScale then UI:SetScale(C.scale) else UI.UIScale = C.scale end
            end)
            LayoutCard:Slider("Transparency", "BgTransPct", 0, 55, 4, "%", function(val)
                UI:SetTransparency(val / 100)
            end)
            LayoutCard:Toggle("Rounded Borders", "RoundedState", true, function(v) UI:SetRounded(v) end)
            if LayoutCard.Keybind then
                LayoutCard:Keybind("Toggle Menu Key", "MenuHotkey", Enum.KeyCode.RightShift, function(k)
                    if k then UI.ToggleKey = k end
                end)
            end
        end)
    })

    if UI.Category then UI:Category("Modules") end

    -- TAB 1: TELEPORT & INTERACTIVE MAP
    feature("Teleports", "Teleport & Map")({
        center = center(function(c)
            c:Header("Teleport & World Map", "Validasi koordinat, Step TP celah, & peta world 2D interaktif", "Active")

            local PosCard = c:Card("Lokasi Saat Ini & Validasi", "Live", "Player", {
                Subtitle = "Koordinat Stats (1-based) & Tile (0-based) langsung dari engine game"
            })
            PosCard:Input("Lokasi Saat Ini (Live)", "LivePosDisplay", "Menunggu world...", "-")
            PosCard:Input("Status Validasi", "ValidStatusDisplay", "Belum ada aksi", "-")

            local ManualCard = c:Card("Manual Teleport (Harus Valid)", nil, "Teleports", {
                Subtitle = "Masukkan X / Y atau ketuk peta untuk memilih target"
            })
            ManualCard:Input("Target Tile X", "TpManualX", "0 .. 99", tostring(tpState.selectedX or 0))
            ManualCard:Input("Target Tile Y", "TpManualY", "0 .. 59", tostring(tpState.selectedY or 0))
            ManualCard:Button("Cek Validasi Tile", "CEK", "Shield", function()
                local ok, msg, cx, cy = Core.ValidateTile(tonumber(UI:GetValue("TpManualX")), tonumber(UI:GetValue("TpManualY")))
                UI:SetValue("ValidStatusDisplay", msg)
                if ok then
                    tpState.selectedX, tpState.selectedY = cx, cy
                    if UIHooks.refreshMap then UIHooks.refreshMap(true) end
                end
            end)
            ManualCard:Button("Walk-Path Safe (Rekomendasi Jarak Jauh / Anti-Balik Base)", "WALK TP", "Teleports", function()
                local ok, msg = Packets.WalkTeleport({ tx = tonumber(UI:GetValue("TpManualX")), ty = tonumber(UI:GetValue("TpManualY")), mode = "walk", speed = 13 })
                UI:SetValue("ValidStatusDisplay", (ok and "[WALK] " or "[BLOCKED] ") .. tostring(msg))
                if UIHooks.refreshMap then UIHooks.refreshMap(true) end
            end)
            ManualCard:Button("Step Teleport (Via Celah Auto-Pace Jarak Jauh)", "STEP TP", "Teleports", function()
                local ok, msg = Packets.WalkTeleport({ tx = tonumber(UI:GetValue("TpManualX")), ty = tonumber(UI:GetValue("TpManualY")), mode = "step", stepSize = 2 })
                UI:SetValue("ValidStatusDisplay", (ok and "[OK] " or "[INVALID] ") .. tostring(msg))
                if UIHooks.refreshMap then UIHooks.refreshMap(true) end
            end)
            ManualCard:Button("Direct Teleport (Dekat <=20 / Auto Walk Jauh)", "DIRECT TP", "Bolt", function()
                local ok, msg = Packets.WalkTeleport({ tx = tonumber(UI:GetValue("TpManualX")), ty = tonumber(UI:GetValue("TpManualY")), mode = "direct" })
                UI:SetValue("ValidStatusDisplay", (ok and "[OK] " or "[INVALID] ") .. tostring(msg))
                if UIHooks.refreshMap then UIHooks.refreshMap(true) end
            end)
            ManualCard:Button("TP ke Spawn / White Door", "SPAWN", "Teleports", function()
                Core.EnsureInit()
                local sp = H.gt and H.gt.spawn
                if sp then
                    local ok, msg = Packets.WalkTeleport({ tx = math.floor(sp.X), ty = math.floor(sp.Y), mode = "step", stepSize = 4 })
                    UI:SetValue("ValidStatusDisplay", (ok and "[SPAWN] " or "[ERR] ") .. tostring(msg))
                    if UIHooks.refreshMap then UIHooks.refreshMap(true) end
                end
            end)

            local SpamTpCard = c:Card("Random Teleport (Via Celah)", nil, "Bolt", {
                Subtitle = "Otomatis cari celah valid — klik tombol sekali lagi untuk STOP"
            })
            SpamTpCard:Slider("Jeda Step (detik)", "SpamTpDelaySec", 0.08, 2.0, C.gapTpDelay or 0.25, " s", function(v)
                tpState.patrolDelay = math.max(0.08, tonumber(v) or 0.25)
                C.gapTpDelay = tpState.patrolDelay
                markConfigDirty()
            end, 0.05)
            SpamTpCard:Button("[GAP TP] Start / Stop Random Teleport", "TOGGLE", "Bolt", toggleRandomTp)

            local MapCard = c:Card("Peta World 2D Interaktif (Klik Mode Switch)", nil, "Visuals", {
                Subtitle = "Kuning Crosshair: Anda (YOU) | Merah: Player lain | Cyan: Drop | Ungu: Pabrik | Oranye: BreakPos"
            })
            MapCard:Input("Embedded World Map", "__WORLD_MAP_ANCHOR__", "__WORLD_MAP_ANCHOR_KEY__", "__WORLD_MAP_ANCHOR_KEY__")
        end)
    })

    -- TAB 2: V1 [MISC]
    feature("Misc", "Misc (V1)")({
        center = center(function(c)
            c:Header("V1 [MISC] Utility", "Fly, Seems, Fast Roulette, Auto Collect Radius, God Mode, FPS Boost & Auto Rerun", "V1")

            local MoveMisc = c:Card("Fly & No Clip (Visual Ghost)", nil, "Teleports", {
                Subtitle = "Fly tahan posisi udara; No Clip menjaga koordinat server tetap di posisi awal"
            })
            MoveMisc:Toggle("Fly Mode (WASD / Arrow / Space)", "MiscFlyToggle", Misc.State.fly, function(on)
                Misc.SetFly(on)
            end)
            MoveMisc:Slider("Kecepatan Fly", "MiscFlySpeed", 6, 45, Misc.State.flySpeed, " t/s", function(v)
                Misc.State.flySpeed = tonumber(v) or 18
                C.flySpeed = Misc.State.flySpeed
                markConfigDirty()
            end)
            MoveMisc:Toggle("No Clip (Visual Ghost)", "MiscNoClipToggle", Misc.State.noClip, function(on)
                Misc.SetNoClip(on)
            end)

            local SafetyMisc = c:Card("Seems & True God Mode (Full Protection)", nil, "Shield", {
                Subtitle = "HP selalu penuh (5), anti mati, anti respawn balik door, kebal lava/burn/knock"
            })
            SafetyMisc:Toggle("SEEMS (Auto Stop & Normal)", "MiscSeemsToggle", Misc.State.seems, function(on)
                Misc.SetSeems(on)
            end)
            SafetyMisc:Toggle("True God Mode (No HP Loss / Anti-Die & Respawn)", "MiscGodToggle", Misc.State.godMode, function(on)
                Misc.SetGodMode(on)
            end)

            local FollowCard = c:Card("Auto Follow Player (Via Walk)", "New", "Player", {
                Subtitle = "Dropdown scrollable daftar player di world — berjalan halus mengikuti target"
            })
            FollowCard:Input("Status Auto Follow", "FollowStatusDisplay", "Idle", Misc.State.followStatus or "Idle")
            local initCands = Misc.GetFollowCandidates()
            local defFollow = (Misc.State.followTarget ~= "" and Misc.State.followTarget) or initCands[1]
            FollowCard:Dropdown("Pilih Player Target (Scroll)", "MiscFollowTarget", initCands, defFollow, function(v)
                local chosen = Misc.SetFollowTarget(v)
                if UI then UI:SetValue("FollowStatusDisplay", chosen ~= "" and ("Target: " .. chosen) or "Belum ada player lain") end
            end)
            FollowCard:Button("Refresh Daftar Player World", "REFRESH", "Player", function()
                local list = Misc.GetFollowCandidates()
                if UI and UI._DropRefresh and UI._DropRefresh.MiscFollowTarget then
                    UI._DropRefresh.MiscFollowTarget(list)
                end
                if UI then UI:SetValue("FollowStatusDisplay", "Daftar di-refresh (" .. tostring(#list) .. ")") end
            end)
            FollowCard:Toggle("Auto Follow Player (Walk-Path)", "MiscFollowToggle", Misc.State.autoFollow, function(on)
                Misc.SetAutoFollow(on, UI and UI:GetValue("MiscFollowTarget") or Misc.State.followTarget)
            end)

            local CollectCard = c:Card("Radius Auto Collect (360° Sekitar) & Visual Drop", "New", "Bolt", {
                Subtitle = "Ambil seluruh drop radius 1-6 tile sekitar + bersihkan drop tersangkut"
            })
            CollectCard:Toggle("Auto Collect Sekitar Player", "MiscAutoCollectToggle", Misc.State.autoCollect, function(on)
                Misc.SetAutoCollect(on, Misc.State.autoCollectRadius, Misc.State.autoCollectStep)
            end)
            CollectCard:Slider("Radius Auto Collect (Tile)", "MiscCollectRadius", 1, 6, Misc.State.autoCollectRadius, " tile", function(v)
                Misc.State.autoCollectRadius = clamp(toInt(v, 5), 1, 6)
                C.autoCollectRadius = Misc.State.autoCollectRadius
                markConfigDirty()
            end, 1)
            CollectCard:Toggle("Step Thread (Jalan Step ke Drop Agak Jauh)", "MiscCollectStep", Misc.State.autoCollectStep, function(on)
                Misc.State.autoCollectStep = on == true
                C.autoCollectStep = Misc.State.autoCollectStep
                markConfigDirty()
            end)
            CollectCard:Toggle("Collect State (Popup Jumlah Gems)", "MiscCollectToggle", Misc.State.collectState, function(on)
                Misc.SetCollectState(on)
            end)
            CollectCard:Toggle("Auto Clean Drop Visual Stuck", "MiscCleanDropToggle", Misc.State.autoCleanDrops, function(on)
                Misc.State.autoCleanDrops = on == true
                C.autoCleanDrops = Misc.State.autoCleanDrops
                markConfigDirty()
                if on then Core.ClearStuckDropVisuals() end
            end)
            CollectCard:Input("Gems Terkumpul", "CollectGemsDisplay", "Get 0 Gems", "Get 0 Gems")
            CollectCard:Button("Collect Drops Sekitar Sekarang", "COLLECT", "Bolt", function()
                local res = Packets.Collect({ radius = Misc.State.autoCollectRadius, stepMoveIfFar = true, collectDelay = 0.03 })
                Core.ClearStuckDropVisuals()
                UI:SetValue("CollectGemsDisplay", string.format("Diambil: %d items | %d gems", res.itemsTaken, res.gemsTaken))
            end)

            local ExtraMisc = c:Card("Fast Roulette (0-36) & FPS Boost & Auto Rerun", "V2", "Bolt", {
                Subtitle = "Roulette filter anomali >2 digit, FPS Boost hapus BG/FX & Auto Rerun Menu"
            })
            ExtraMisc:Toggle("Fast Roulette (Popup 0-36 Instan)", "MiscRouletteToggle", Misc.State.fastRoulette, function(on)
                Misc.SetFastRoulette(on)
            end)
            ExtraMisc:Input("Hasil Roulette Terakhir", "RouletteResultDisplay", "Menunggu spin (0-36)...", "-")
            ExtraMisc:Toggle("Boost Performance FPS (Hide BG/FX)", "MiscFpsBoost", Misc.State.fpsBoost, function(on)
                Misc.SetFpsBoost(on)
            end)
            ExtraMisc:Toggle("Auto Rerun Menu (Saat Menu Ditutup)", "MiscAutoRerun", C.autoRerun == true, function(on)
                C.autoRerun = on == true
                markConfigDirty()
                Config.Save(true)
            end)
            ExtraMisc:Slider("Delay Auto Rerun (detik)", "MiscRerunDelay", 0.5, 15.0, C.autoRerunDelay or 2.5, " s", function(v)
                C.autoRerunDelay = clamp(tonumber(v) or 2.5, 0.5, 15.0)
                markConfigDirty()
            end, 0.5)
            ExtraMisc:Toggle("Safe Mode Config saat Rerun (Loop OFF)", "MiscRerunSafe", C.autoRerunSafe ~= false, function(on)
                C.autoRerunSafe = on == true
                markConfigDirty()
            end)
        end)
    })

    -- TAB 3: V2 [PNB]
    feature("Combat", "PNB (V2)")({
        center = center(function(c)
            c:Header("V2 [PNB] Place & Break", "Pilih item block dari Backpack (ikon asli) & atur Pad 5x5 posisi Anda di tengah", "V2")

            local CtrlCard = c:Card("Kontrol & Status PNB", nil, "Bolt", {
                Subtitle = "1 tombol Start/Stop responsif terhubung ke loop PNB"
            })
            CtrlCard:Input("Status PNB", "PnbStatusDisplay", "Idle", "Idle")
            CtrlCard:Input("Block Terpilih", "PnbSelectedDisplay", "Belum dipilih", PNB.State.selectedBlockId and string.format("%s (ID:%d)", Core.GetItemName(PNB.State.selectedBlockId), PNB.State.selectedBlockId) or "Belum dipilih")
            CtrlCard:Button("[PNB] Start / Stop Engine", "TOGGLE", "Bolt", function()
                PNB.Toggle()
            end)

            local BpCard = c:Card("Backpack Item Selector (Gambar Item Asli)", nil, "Visuals", {
                Subtitle = "Ketuk block di backpack untuk langsung memilih Item PNB & Pabrik"
            })
            BpCard:Input("Embedded Backpack Items", "__BP_ITEM_ANCHOR__", "__BP_ITEM_ANCHOR_KEY__", "__BP_ITEM_ANCHOR_KEY__")
            BpCard:Button("Refresh Isi Backpack", "REFRESH BP", "Visuals", function()
                Core.EnsureInit()
                if UIHooks.refreshBP then UIHooks.refreshBP() end
            end)

            local PadCard = c:Card("Pad Selector Tile 5x5 (Center = Akun In-Game Kita)", nil, "Teleports", {
                Subtitle = "Ketuk kotak sekitar karakter untuk target Place & Break"
            })
            PadCard:Input("Embedded 5x5 Pad", "__PAD_5X5_ANCHOR__", "__PAD_5X5_ANCHOR_KEY__", "__PAD_5X5_ANCHOR_KEY__")

            local OptCard = c:Card("Pengaturan Timing & Mode PNB", nil, "Sliders", {
                Subtitle = "Atur 1-Hit, Show Hand, Auto Collect & custom delay"
            })
            OptCard:Toggle("1-Hit Break Mode", "PnbOneHit", PNB.State.oneHit, function(v) PNB.State.oneHit = v; markConfigDirty() end)
            OptCard:Toggle("Show Hand Break", "PnbShowHand", PNB.State.showHand, function(v) PNB.State.showHand = v; markConfigDirty() end)
            OptCard:Toggle("Auto Collect Drops", "PnbAutoCollect", PNB.State.autoCollect, function(v) PNB.State.autoCollect = v; markConfigDirty() end)
            OptCard:Toggle("Lock Posisi Tengah Saat Start", "PnbLockCenter", PNB.State.lockCenterPos, function(v) PNB.State.lockCenterPos = v; markConfigDirty() end)
            OptCard:Slider("Place Delay (ms)", "PnbPlaceMs", 30, 600, math.floor(PNB.State.placeDelay * 1000), " ms", function(v) PNB.State.placeDelay = v / 1000; markConfigDirty() end, 10)
            OptCard:Slider("Break Delay (ms)", "PnbBreakMs", 30, 600, math.floor(PNB.State.breakDelay * 1000), " ms", function(v) PNB.State.breakDelay = v / 1000; markConfigDirty() end, 10)
            OptCard:Slider("Collect Delay (ms)", "PnbCollectMs", 20, 400, math.floor(PNB.State.collectDelay * 1000), " ms", function(v) PNB.State.collectDelay = v / 1000; markConfigDirty() end, 10)
        end)
    })

    -- TAB 4: V3 [AUTO PABRIK]
    feature("AutoFarm", "Auto Pabrik (V3)")({
        center = center(function(c)
            c:Header("V3 [AUTO PABRIK]", "Auto PNB Block -> Tanam Seed -> Tunggu Grow -> Panen & Collect Tile-by-Tile", "V3")

            local StatCard = c:Card("Kontrol & Status Auto Pabrik", nil, "Bolt", {
                Subtitle = "Prioritas: Block di BP terlebih dulu, habis -> tanam & tunggu matang"
            })
            StatCard:Input("Status Pabrik", "PabrikStatusDisplay", "Idle | Tiles: 0", "Idle | Tiles: 0")
            StatCard:Input("Pair Block & Seed Aktif", "PabrikPairDisplay", "Belum diatur", Pabrik.State.itemName ~= "" and string.format("%s | Block:%s Seed:%s", Pabrik.State.itemName, tostring(Pabrik.State.blockId), tostring(Pabrik.State.seedId)) or "-")
            StatCard:Input("Posisi Break Pabrik", "PabrikBreakPosDisplay", "Belum diset", Pabrik.State.breakPos and string.format("BreakPos (%d, %d) [%d tile]", Pabrik.State.breakPos.x, Pabrik.State.breakPos.y, Pabrik.State.breakTileCount) or "-")
            StatCard:Button("[PABRIK] Start / Stop Auto", "TOGGLE", "Bolt", function()
                Pabrik.Toggle()
            end)

            local ItemCard = c:Card("Pilih Seed / Block & Break Pad (1-3 Tile)", nil, "Teleports", {
                Subtitle = "Ketik nama/ID item (otomatis baca ID Block + Seed) atau pilih dari tab BP"
            })
            ItemCard:Input("Nama / ID Block atau Seed", "PabrikItemInput", "Contoh: Dirt atau 2", tostring(Pabrik.State.itemName or ""), function(txt)
                if txt and txt ~= "" then Pabrik.SetItem(txt) end
            end)
            ItemCard:Button("Set Item Pabrik dari Input", "SET ITEM", "Shield", function()
                local pair = Pabrik.SetItem(UI:GetValue("PabrikItemInput"))
                if not pair then UI:SetValue("PabrikPairDisplay", "Item tidak ditemukan di ItemDB") end
            end)
            ItemCard:Button("Gunakan Item Terpilih dari BP PNB", "SYNC BP", "Visuals", function()
                if PNB.State.selectedBlockId then
                    Pabrik.SetItem(PNB.State.selectedBlockId)
                    UI:SetValue("PabrikItemInput", tostring(PNB.State.selectedBlockId))
                end
            end)
            ItemCard:Input("Embedded Pabrik Head Pad", "__PAD_PABRIK_ANCHOR__", "__PAD_PABRIK_ANCHOR_KEY__", "__PAD_PABRIK_ANCHOR_KEY__")
            ItemCard:Button("Set Break Pos = Posisi Sekarang", "SET POS", "Teleports", function()
                Pabrik.SetBreakPos()
            end)
            ItemCard:Slider("Jumlah Tile Break (1-3)", "PabrikBreakCount", 1, 3, Pabrik.State.breakTileCount, " tile", function(v)
                Pabrik.SetBreakCount(v)
            end, 1)

            local TileCard = c:Card("Seleksi Tile / Line Peta & Timing", nil, "Sliders", {
                Subtitle = "Bisa juga pilih langsung dari Peta World (mode PABRIK TILE / LINE)"
            })
            TileCard:Button("Toggle Line Y Posisi Saat Ini", "TOGGLE LINE", "Visuals", function()
                local p = Core.ReadPos()
                Pabrik.ToggleLine(p.ty)
            end)
            TileCard:Button("Toggle Tile Posisi Saat Ini", "TOGGLE TILE", "Visuals", function()
                local p = Core.ReadPos()
                Pabrik.ToggleTile(p.tx, p.ty)
            end)
            TileCard:Button("Clear Semua Tile Pabrik", "CLEAR", "Shield", function()
                Pabrik.State.selectedTiles = {}
                Pabrik.State.selectedLines = {}
                setPabrikStatus("Cleared")
                if UIHooks.refreshMap then UIHooks.refreshMap(true) end
            end)
            TileCard:Toggle("1-Hit Mode (Pabrik)", "PabrikOneHit", Pabrik.State.oneHit, function(v) Pabrik.State.oneHit = v; markConfigDirty() end)
            TileCard:Toggle("Show Hand (Pabrik)", "PabrikShowHand", Pabrik.State.showHand, function(v) Pabrik.State.showHand = v; markConfigDirty() end)
            TileCard:Slider("Place Delay (ms)", "PabrikPlaceMs", 40, 600, math.floor(Pabrik.State.placeDelay * 1000), " ms", function(v) Pabrik.State.placeDelay = v / 1000; markConfigDirty() end, 10)
            TileCard:Slider("Break Delay (ms)", "PabrikBreakMs", 40, 600, math.floor(Pabrik.State.breakDelay * 1000), " ms", function(v) Pabrik.State.breakDelay = v / 1000; markConfigDirty() end, 10)
            TileCard:Slider("Collect Delay (ms)", "PabrikCollectMs", 20, 400, math.floor(Pabrik.State.collectDelay * 1000), " ms", function(v) Pabrik.State.collectDelay = v / 1000; markConfigDirty() end, 10)
        end)
    })

    -- TAB 4B: [DIRT FARM] AUTO FORMAT DIRT FARM & ROTATION
    feature("Active", "Dirt Farm")({
        center = center(function(c)
            c:Header("[DIRT FARM] Auto Builder & Rotation", "Gali pojok 2 kiri/kanan, ubah Lava/Rock -> Dirt, pola kelipatan 2 + Rotation World", "Active")

            local DfStatCard = c:Card("Kontrol & Status Dirt Farm", nil, "Bolt", {
                Subtitle = "Otomatis skip White Door, Bedrock & Locks; pindah ke Rotation DF saat selesai"
            })
            DfStatCard:Input("Status Dirt Farm", "DfStatusDisplay", "Idle", DirtFarm.State.status or "Idle")
            DfStatCard:Button("[DF] Start / Stop Dirt Farm", "TOGGLE", "Bolt", function()
                DirtFarm.Toggle()
            end)

            local DfRotCard = c:Card("Rotation DF (Auto Pindah World Saat Selesai)", nil, "Teleports", {
                Subtitle = "Pisahkan nama world dengan koma (contoh: FARM1, FARM2, FARM3)"
            })
            DfRotCard:Input("Daftar World Rotation DF", "DfRotationInput", "WORLD1, WORLD2, WORLD3", DirtFarm.State.rotationText or "", function(txt)
                DirtFarm.SetRotationWorlds(txt)
            end)
            DfRotCard:Button("Tambahkan World Saat Ini ke Rotation", "ADD WORLD", "Teleports", function()
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
                    setDfStatus("Ditambahkan ke Rotation: " .. curW)
                end
            end)
            DfRotCard:Button("Masuk World Rotation Berikutnya", "NEXT WORLD", "Bolt", function()
                Core.EnsureInit()
                local gt = H.gt
                local list = DirtFarm.SetRotationWorlds(UI:GetValue("DfRotationInput") or DirtFarm.State.rotationText)
                if gt and #list > 0 and type(gt.enter) == "function" then
                    local curW = cleanWorldName(gt.name)
                    local nxt = list[1]
                    for i, w in ipairs(list) do if w == curW and list[i + 1] then nxt = list[i + 1]; break end end
                    if nxt and nxt ~= "" then
                        setDfStatus("Masuk world: " .. nxt)
                        pcall(gt.enter, nxt)
                    end
                end
            end)

            local DfCfgCard = c:Card("Delay & Opsi Format Dirt Farm", nil, "Sliders", {
                Subtitle = "Atur Break/Place/Collect delay dan opsi bolong tengah (Center Shaft)"
            })
            DfCfgCard:Slider("Break Delay (ms)", "DfBreakMs", 40, 600, math.floor(DirtFarm.State.breakDelay * 1000), " ms", function(v) DirtFarm.State.breakDelay = v / 1000; markConfigDirty() end, 10)
            DfCfgCard:Slider("Place Delay (ms)", "DfPlaceMs", 40, 600, math.floor(DirtFarm.State.placeDelay * 1000), " ms", function(v) DirtFarm.State.placeDelay = v / 1000; markConfigDirty() end, 10)
            DfCfgCard:Slider("Collect Delay (ms)", "DfCollectMs", 20, 400, math.floor(DirtFarm.State.collectDelay * 1000), " ms", function(v) DirtFarm.State.collectDelay = v / 1000; markConfigDirty() end, 10)
            DfCfgCard:Toggle("1-Hit Mode (DF)", "DfOneHit", DirtFarm.State.oneHit, function(v) DirtFarm.State.oneHit = v; markConfigDirty() end)
            DfCfgCard:Toggle("Show Hand (DF)", "DfShowHand", DirtFarm.State.showHand, function(v) DirtFarm.State.showHand = v; markConfigDirty() end)
            DfCfgCard:Toggle("Auto Collect Drops (DF)", "DfAutoCollect", DirtFarm.State.autoCollect, function(v) DirtFarm.State.autoCollect = v; markConfigDirty() end)
            DfCfgCard:Toggle("Center Shaft / Bolong Tengah (2 Kolom)", "DfCenterGap", DirtFarm.State.centerGap, function(v) DirtFarm.State.centerGap = v; markConfigDirty() end)
        end)
    })

    -- TAB 5: V4 [SET VISUALISASI]
    feature("Visuals", "Visualisasi (V4)")({
        center = center(function(c)
            c:Header("V4 [SET VISUALISASI]", "Ubah Nama In-Game, Roles Lengkap + Effects Animasi, Title & Lock Names", "V4")

            local VisCard = c:Card("Pengaturan Nama, Roles & Effects Visual", nil, "Player", {
                Subtitle = "Semua dropdown dapat di-scroll; efek BitmapText & StaffRoles tampil real-time"
            })
            VisCard:Input("Custom Name Visual", "VisCustomName", "Nama baru...", Visual.State.customName, function(txt)
                Visual.State.customName = tostring(txt or "")
                markConfigDirty()
            end)
            VisCard:Dropdown("Roles Visual", "VisRoleSelect", VISUAL_ROLES, Visual.State.role or "none", function(v)
                Visual.State.role = v
                Visual.Apply()
            end)
            VisCard:Dropdown("Effect Nama Animasi", "VisEffectSelect", VISUAL_EFFECTS, Visual.State.effect or "None", function(v)
                Visual.State.effect = v
                Visual.Apply()
            end)
            VisCard:Dropdown("Colour Prefix (Jika Tanpa Effect)", "VisColorSelect", { "None", "`1", "`2", "`3", "`4", "`5", "`6", "`7", "`8", "`9", "`b", "`d", "`#", "`@" }, (Visual.State.colorCode ~= "" and Visual.State.colorCode) or "None", function(v)
                Visual.State.colorCode = (v == "None") and "" or v
                Visual.Apply()
            end)
            VisCard:Dropdown("Title Visual", "VisTitleSelect", VISUAL_TITLES, Visual.State.customTitle or "none", function(v)
                Visual.State.customTitle = v
                Visual.Apply()
            end)
            VisCard:Input("Guild Tag Visual (Opsional)", "VisGuildInput", "Contoh: SYT / PRO", Visual.State.guildTag or "", function(txt)
                Visual.State.guildTag = tostring(txt or "")
                markConfigDirty()
            end)
            VisCard:Toggle("Discord Booster Icon", "VisBoosterToggle", Visual.State.booster, function(v)
                Visual.State.booster = v
                Visual.Apply()
            end)
            VisCard:Toggle("Tiles Name [X, Y] di Nama", "VisTilesName", Visual.State.tilesName, function(v) Visual.State.tilesName = v; Visual.Apply() end)
            VisCard:Toggle("Hidden Name (Sembunyikan Tag)", "VisHideName", Visual.State.hideName, function(v) Visual.State.hideName = v; Visual.Apply() end)
            VisCard:Toggle("Lock Names (Re-apply World Baru & Auto-OFF Menu)", "VisLockNames", Visual.State.lockNames, function(v) Visual.State.lockNames = v; markConfigDirty() end)
            VisCard:Button("Terapkan Visualisasi Sekarang", "APPLY", "Bolt", function()
                Visual.State.customName = tostring(UI:GetValue("VisCustomName") or "")
                Visual.State.guildTag   = tostring(UI:GetValue("VisGuildInput") or "")
                Visual.Apply()
            end)
            VisCard:Button("Kembalikan Nama & Role Asli", "RESTORE", "Shield", function()
                Visual.Restore()
            end)
        end)
    })

    -- TAB 6: V5 [SET SPAMING] & [GETC SKIPER]
    feature("Chat", "Spam & Skipper")({
        center = center(function(c)
            c:Header("V5 [SET SPAMING] & [GETC SKIPER]", "Auto Chat Spam dengan 1-Button Stop responsif & Guard Rate-Limit", "V5")

            local SpamCard = c:Card("Set Spaming (Max 120 Karakter)", nil, "Bolt", {
                Subtitle = "Mendukung prefix warna otomatis, whisper & Stop instan 1 tombol"
            })
            SpamCard:Input("Status Spam", "SpamStatusDisplay", "Idle", "Idle")
            SpamCard:Input("Pesan Spam", "SpamTextInput", "Ketik pesan di sini...", Spam.State.text, function(txt)
                Spam.State.text = tostring(txt or "")
                markConfigDirty()
            end)
            SpamCard:Dropdown("Prefix Warna", "SpamPrefixSelect", { "None", "`1", "`2", "`3", "`4", "`5", "`6", "`7", "`8", "`9", "`b", "`d", "`#", "`@" }, (Spam.State.prefixColor ~= "" and Spam.State.prefixColor) or "None", function(v)
                Spam.State.prefixColor = (v == "None") and "" or v
                markConfigDirty()
            end)
            SpamCard:Toggle("Auto Cycle Colour (`1..`9)", "SpamAutoColor", Spam.State.autoCycleColor, function(v) Spam.State.autoCycleColor = v; markConfigDirty() end)
            SpamCard:Toggle("Experimental: Whisper All (Player Game)", "SpamWhisperAll", Spam.State.experimentalWhisperAll, function(v) Spam.State.experimentalWhisperAll = v; markConfigDirty() end)
            SpamCard:Slider("Delay Kirim (detik)", "SpamDelaySec", 1.7, 10.0, Spam.State.delay, " s", function(v)
                Spam.State.delay = math.max(1.65, tonumber(v) or 3.0)
                markConfigDirty()
            end, 0.1)
            SpamCard:Button("[SPAM] Start / Stop Chat", "TOGGLE", "Bolt", function()
                if not Spam.State.running then
                    Spam.State.text = tostring(UI:GetValue("SpamTextInput") or "")
                end
                Spam.Toggle()
            end)
            SpamCard:Button("Hentikan Spam Chat Paksa", "STOP SPAM", "Shield", function()
                Spam.Stop()
            end)

            local GuardCard = c:Card("[GETC SKIPER] Rate Limit & Range Guard", nil, "Shield", {
                Subtitle = "Otomatis acak jeda bila fitur berjalan terlalu cepat & jaga range <= 5 tile"
            })
            GuardCard:Toggle("Aktifkan Randomized Jitter Guard", "GuardEnabled", GetcSkipper.State.enabled, function(v)
                GetcSkipper.State.enabled = v
                markConfigDirty()
            end)
            GuardCard:Toggle("Skip Update Items UI Berulang", "GuardSkipItems", GetcSkipper.State.skipUpdateItems, function(v)
                GetcSkipper.SetSkipUpdateItems(v)
                markConfigDirty()
            end)
            GuardCard:Slider("Max Range Auto Step (Tiles)", "GuardMaxRange", 1, 5, GetcSkipper.State.maxRangeTiles, " tiles", function(v)
                GetcSkipper.State.maxRangeTiles = clamp(toInt(v, 5), 1, 5)
                markConfigDirty()
            end, 1)
        end)
    })

    if type(buildMountedCanvasesFn) == "function" then
        buildMountedCanvasesFn()
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- 8. EMBEDDED CANVAS MOUNTING + SIDEBAR IN-GAME ACCOUNT SYNC
-- ═══════════════════════════════════════════════════════════════════════════
local buttonMap = {}

local function findAllTextBoxesWithKey(key)
    local found = {}
    for _, root in ipairs({ CoreGui, LP and LP:FindFirstChildOfClass("PlayerGui") }) do
        if root then
            for _, d in ipairs(root:GetDescendants()) do
                if d:IsA("TextBox") and d.Text == key then
                    found[#found + 1] = d
                end
            end
        end
    end
    return found
end

local function mountEmbeddedCanvas(anchorKey, heightPx, buildFn)
    task.spawn(function()
        local anchorBox = nil
        for _ = 1, 80 do
            local hits = findAllTextBoxesWithKey(anchorKey)
            if #hits > 0 then
                anchorBox = hits[1]
                break
            end
            task.wait(0.1)
        end
        if not anchorBox or not anchorBox.Parent then return end
        local rowContainer = anchorBox.Parent
        for _, ch in ipairs(rowContainer:GetChildren()) do
            if not ch:IsA("UICorner") and not ch:IsA("UIStroke") then
                ch:Destroy()
            end
        end
        rowContainer.Size = UDim2.new(1, 0, 0, heightPx)
        rowContainer.BackgroundColor3 = Color3.fromRGB(11, 14, 20)
        rowContainer.ClipsDescendants = true
        buildFn(rowContainer)
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
    for _, root in ipairs({ CoreGui, LP and LP:FindFirstChildOfClass("PlayerGui") }) do
        if root then
            for _, d in ipairs(root:GetDescendants()) do
                if d:IsA("TextLabel") then
                    for _, sp in ipairs(specs) do
                        if not buttonMap[sp.prefix] and string.sub(d.Text, 1, #sp.prefix) == sp.prefix then
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
                    if not UIHooks.sidebarSubLbl and d.Text == "Active Session" then
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
    local didFit, fittedW, fittedH, lastDraw = false, nil, nil, 0
    local mapPool = {}

    local function getScale()
        local h = rowContainer.AbsoluteSize.Y
        return (h > 10) and clamp(h / 285, 0.25, 4) or 1
    end

    local function updateTransform()
        local w, h = (H.gt and H.gt.w) or 100, (H.gt and H.gt.h) or 60
        local s = getScale()
        local vw, vh = math.max(100, mapView.AbsoluteSize.X / s), math.max(80, mapView.AbsoluteSize.Y / s)
        local cw, ch = w * mapTilePx, h * mapTilePx
        mapPanX = (cw <= vw) and clamp(mapPanX, 4, math.max(4, vw - cw - 4)) or clamp(mapPanX, vw - cw - 12, 12)
        mapPanY = (ch <= vh) and clamp(mapPanY, 4, math.max(4, vh - ch - 4)) or clamp(mapPanY, vh - ch - 12, 12)
        mapCanvas.Size = UDim2.fromOffset(cw, ch)
        mapCanvas.Position = UDim2.fromOffset(mapPanX, mapPanY)
    end

    local function fitMap()
        local w, h = (H.gt and H.gt.w) or 100, (H.gt and H.gt.h) or 60
        local s = getScale()
        local vw, vh = math.max(120, mapView.AbsoluteSize.X / s), math.max(80, mapView.AbsoluteSize.Y / s)
        mapTilePx = clamp(math.min((vw - 10) / w, (vh - 10) / h), 2, 18)
        mapPanX = math.floor((vw - w * mapTilePx) * 0.5)
        mapPanY = math.floor((vh - h * mapTilePx) * 0.5)
        didFit, fittedW, fittedH = true, w, h
        updateTransform()
    end

    local function applyZoom(newPx)
        local s = getScale()
        local vw, vh = math.max(100, mapView.AbsoluteSize.X / s), math.max(80, mapView.AbsoluteSize.Y / s)
        local oldPx = mapTilePx
        local clamped = clamp(newPx, 2, 18)
        if math.abs(clamped - oldPx) < 0.01 then return end
        local cx, cy = (vw * 0.5 - mapPanX) / oldPx, (vh * 0.5 - mapPanY) / oldPx
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
        -- 1. Background cave walls (soft cave brown when FG empty)
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
                            f.Position = UDim2.fromOffset(sx * px, y * px)
                            f.Size = UDim2.fromOffset(math.max(1, (x - sx) * px), math.max(1, px))
                        else
                            x += 1
                        end
                    end
                end
            end
        end

        -- 2. Terrain, Lava, Water, Locks, Seeds, Doors (merged per color bucket)
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
                        f.Position = UDim2.fromOffset(sx * px, y * px)
                        f.Size = UDim2.fromOffset(math.max(1, (x - sx) * px), math.max(1, px))
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
                            f.Position = UDim2.fromOffset(x * px, y * px)
                            f.Size = UDim2.fromOffset(math.max(2, px), math.max(2, px))
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
                        f.Position = UDim2.fromOffset(d.x * px - 1, (d.y - 0.5) * px - 1)
                        f.Size = UDim2.fromOffset(math.max(3, px * 0.65), math.max(3, px * 0.65))
                    end
                end
            end
        end

        -- 4. Auto Pabrik connected horizontal lines (-----) (Purple) & breakPos (Orange)
        for _, seg in ipairs(Pabrik.GetConnectedLines()) do
            used += 1
            local f = getBox(used, 4, Color3.fromRGB(168, 85, 247), 0.12, false)
            local hBar = (seg.len > 1) and math.max(3, px * 0.72) or math.max(3, px)
            local yOff = (seg.len > 1) and (px - hBar) * 0.5 or 0
            f.Position = UDim2.fromOffset(seg.x1 * px, seg.y * px + yOff)
            f.Size = UDim2.fromOffset(math.max(3, seg.len * px), hBar)
        end
        if Pabrik.State.breakPos then
            breakBox.Visible = true
            breakBox.Position = UDim2.fromOffset(Pabrik.State.breakPos.x * px, Pabrik.State.breakPos.y * px)
            breakBox.Size = UDim2.fromOffset(math.max(6, px), math.max(6, px))
        else
            breakBox.Visible = false
        end

        -- 5. Selected TP tile (Cyan/Red)
        if tpState.selectedX and tpState.selectedY then
            local ok = Core.ValidateTile(tpState.selectedX, tpState.selectedY)
            local col = ok and Color3.fromRGB(56, 189, 248) or Color3.fromRGB(239, 68, 68)
            selBox.Visible = true
            selBox.BackgroundColor3 = col
            local boxSz = math.max(7, px)
            selBox.Position = UDim2.fromOffset((tpState.selectedX + 0.5) * px - boxSz * 0.5, (tpState.selectedY + 0.5) * px - boxSz * 0.5)
            selBox.Size = UDim2.fromOffset(boxSz, boxSz)
        else
            selBox.Visible = false
        end

        -- 6. Other in-world players (Red dot) + Self (Crosshair + Bright Yellow Pin "YOU")
        for _, op in ipairs(Core.GetInWorldPlayers(false)) do
            if op.tx and op.ty then
                used += 1
                local f = getBox(used, 6, Color3.fromRGB(244, 63, 94), 0, true)
                local dsz = math.max(5, px + 1.5)
                f.Position = UDim2.fromOffset(op.tx * px, op.ty * px)
                f.Size = UDim2.fromOffset(dsz, dsz)
            end
        end

        local pcx = (selfPos.tx + 0.5) * px
        local pcy = (selfPos.ty + 0.5) * px
        local dsz = math.max(9, px + 4)
        crossH.Position = UDim2.fromOffset(0, pcy)
        crossV.Position = UDim2.fromOffset(pcx, 0)
        playerDot.Size = UDim2.fromOffset(dsz, dsz)
        playerDot.Position = UDim2.fromOffset(pcx, pcy)
        local cw = w * px
        local tagX = clamp(pcx, 16, math.max(16, cw - 16))
        if pcy < 18 then
            youTag.AnchorPoint = Vector2.new(0.5, 0)
            youTag.Position = UDim2.fromOffset(tagX, pcy + dsz * 0.5 + 2)
        else
            youTag.AnchorPoint = Vector2.new(0.5, 1)
            youTag.Position = UDim2.fromOffset(tagX, pcy - dsz * 0.5 - 2)
        end

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
            renderMap(true)
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
    zoomInBtn.MouseButton1Click:Connect(function() applyZoom(mapTilePx + 1); renderMap(true) end)
    zoomOutBtn.MouseButton1Click:Connect(function() applyZoom(mapTilePx - 1); renderMap(true) end)
    tpBtn.MouseButton1Click:Connect(function()
        if tpState.selectedX and tpState.selectedY then
            local ok, msg = Packets.WalkTeleport({ tx = tpState.selectedX, ty = tpState.selectedY, mode = "step", stepSize = 4 })
            UI:SetValue("ValidStatusDisplay", (ok and "[OK] " or "[INVALID] ") .. tostring(msg))
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
                        Config.State.pnbBlockId = it.id
                        markConfigDirty()
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

    task.spawn(function()
        task.wait(0.6)
        pcall(SYT_Logic.Init, true)
        scanResponsiveButtons()
        UIHooks.updateButtons()
        if UIHooks.refreshBP then UIHooks.refreshBP() end
        if UIHooks.refreshMap then UIHooks.refreshMap(true) end
    end)
end

-- Muat Config Tersimpan -> Bangun Frontend SYT -> Terapkan Safe State
Config.Load(false)
if Config.State.theme and UI and UI.SetTheme then pcall(function() UI:SetTheme(Config.State.theme) end) end
if Config.State.scale and UI and UI.SetScale then pcall(function() UI:SetScale(Config.State.scale) end) end
buildSYTMenuFn()
Config.ApplyRuntime(Config.State.autoRerunSafe ~= false)

-- ═══════════════════════════════════════════════════════════════════════════
-- 9. RUNTIME WATCHER: LIVE POS, IN-GAME NAME SYNC, LOCK NAMES, AUTO SAVE
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
    local now = os.clock()
    if (now - lastFastTick) < 0.25 then return end
    lastFastTick = now

    local gt = H.gt
    local curWorld = gt and cleanWorldName(gt.name) or ""

    -- Sinkronkan perubahan world: reset semua fitur auto ke OFF + Lock Names re-apply (kecuali Rotation DF)
    if curWorld ~= Visual.State.lastWorldName then
        local prev = Visual.State.lastWorldName
        Visual.State.lastWorldName = curWorld
        if prev ~= "" and not DirtFarm.State.switchingWorld then
            stopAllAutomationImpl("Pindah world -> Otomasi OFF")
        end
        if curWorld ~= "" then
            task.delay(0.35, function()
                pcall(SYT_Logic.Init, true)
                if Visual.State.lockNames then Visual.Apply() end
                if UIHooks.refreshBP then UIHooks.refreshBP() end
                if UIHooks.refreshMap then UIHooks.refreshMap(true) end
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

    if (now - lastSlowTick) >= 1.5 then
        lastSlowTick = now
        if not H.gt or not H.ItemDB or not H.Net or not H.inv or not H.others then pcall(SYT_Logic.Init) end
        if not buttonMap["[PNB]"] or not buttonMap["[PABRIK]"] or not buttonMap["[DF]"] or not buttonMap["[SPAM]"] or not buttonMap["[GAP TP]"] or not UIHooks.sidebarNameLbl then
            scanResponsiveButtons()
            UIHooks.updateButtons()
        end
        local invHash = computeInvHash()
        if invHash ~= lastInvHash then
            lastInvHash = invHash
            if UIHooks.refreshBP then UIHooks.refreshBP() end
        end
        if UIHooks.refreshMap then UIHooks.refreshMap(false) end
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
        if Config.dirty and Config.State.autoSave then
            Config.Save(true)
        end
    end
end)

getEnv().SYT_Logic = SYT_Logic
return SYT_Logic
