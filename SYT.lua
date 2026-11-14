--!nocheck
--[[
    SkyP_R8_FullSuite.lua — Unified R&8_DV Frontend + Full Backend Logic (Single Script)
    Template GUI: https://raw.githubusercontent.com/Mytzcodes/R-8/refs/heads/main/Sample%20Gui/SampleGui.lua
    Framework   : https://raw.githubusercontent.com/Mytzcodes/R-8/refs/heads/main/r%268_dv.lua

    Fitur Lengkap dalam 1 Script Terintegrasi (Backend <-> Frontend Responsive):
      - Overview         : Profil Akun In-Game (bukan username Roblox), live world/posisi, list player world, Scan & Stop All
      - Teleport & Map   : Manual TP validasi, Step TP (<=5 tile), Fast Gap Random TP Start/Stop, Peta World Interaktif
                           (Click mode: TP / Pabrik Tile / Pabrik Line / Break Pos + tampilkan player in-game di peta)
      - Misc (V1)        : Fly, Seems (auto-quiet player > 1 / Staff masuk), Fast Roulette (hasil instan),
                           No Clip (Visual Ghost + kembali ke posisi awal), God Mode, Collect State (Popup Gems)
      - PNB (V2)         : Visual Backpack Block Selector (gambar item asli Game Atlas/ItemIcon),
                           5x5 Tile Selector Pad (posisi tengah = akun in-game kita), 1-Hit, Show Hand, Delay, Auto Collect, 1-Button Start/Stop
      - Auto Pabrik (V3) : Visual Backpack/Item Selector + auto-pair Block & Seed ID, Select Tile/Line di map,
                           Break Pos & 1-3 Break Tile Pad di atas kepala, Priority Block -> Plant Seed -> Wait Grow -> Harvest & Tile Collect
      - Visualisasi (V4) : Custom In-Game Name, Role Visual, Colour Prefix, Title, Tiles Pos di Nama, Hidden Name, Lock Names (+ auto-OFF saat pindah world)
      - Spam & Skipper(V5): Input Spam (max 120), Colour Prefix / Auto Cycle, Delay + Jitter, Experimental Whisper All (In-Game Players), [GETC SKIPER]
]]

-- ═══════════════════════════════════════════════════════════════════════════
-- 1. LOAD R&8_DV IMGUI FRAMEWORK (SAMPLEGUI SHELL)
-- ═══════════════════════════════════════════════════════════════════════════
local function loadR8Framework()
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
    assert(okFetch and type(rawScript) == "string" and #rawScript > 128, "[R&8_DV] Gagal memuat r&8_dv.lua dari GitHub.")
    local loader, loadErr = loadstring(rawScript)
    assert(type(loader) == "function", "[R&8_DV] Compile error: " .. tostring(loadErr))
    return loader()
end

local ImGui = loadR8Framework()

local UI = ImGui({
    Title         = "DRY CURSED - IMGUI",
    BrandTitle    = "R&8_DV",
    BrandSubtitle = "IMGUI SUITE",
    Theme         = "Minimalist Monochrome",
    CheckboxStyle = "Modern",
    LetterSpacing = 1,
    AutoLoading   = false,
}).Call(3)

local feature = UI.feature
local function center(fn) return fn end
local function right(fn) return fn end

local ThemeChoices = UI.GetThemes and UI:GetThemes() or {
    "Minimalist Monochrome",
    "Blue Night Sky",
    "Violet Amethyst",
    "Orange Sand",
    "Midnight Monokai",
}

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
    local g1 = (_debug and _debug.getupvalue) or getupvalue
    if type(g1) == "function" then
        local ok, _, val = pcall(g1, fn, idx)
        if ok then return val end
    end
    local g2 = (_debug and _debug.getupvalues) or getupvalues
    if type(g2) == "function" then
        local ok, ups = pcall(g2, fn)
        if ok and type(ups) == "table" then return ups[idx] end
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
    initialized    = false,
    Net            = nil,
    ItemDB         = nil,
    Roles          = nil,
    Assets         = nil,
    ItemIcon       = nil,
    Autotile       = nil,
    gt             = nil,
    inv            = nil,
    others         = nil,
    stateObj       = nil,
    trees          = nil,
    mirroredTrees  = {},
    wheelSpins     = nil,
    renderFn       = nil,
    pxIdx          = nil,
    pyIdx          = nil,
    vxIdx          = nil,
    vyIdx          = nil,
    prevXIdx       = nil,
    prevYIdx       = nil,
    deadIdx        = nil,
    goPxIdx        = nil,
    goPyIdx        = nil,
    goPrevXIdx     = nil,
    goPrevYIdx     = nil,
    goVxIdx        = nil,
    goVyIdx        = nil,
    lastTileAt     = 0,
    lastDropAt     = 0,
    origMoveSend   = nil,
    origDiedSend   = nil,
    origTakeDrop   = nil,
    takeSeq        = 0,
    takeDropHooked = false,
    wheelHooked    = false,
    seemsHooked    = false,
    watcherConn    = nil,
    flyConn        = nil,
    godConn        = nil,
    onNotify       = nil,
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
    return type(t) == "table"
        and type(rawget(t, "slots")) == "table"
        and type(rawget(t, "count")) == "function"
        and type(rawget(t, "add")) == "function"
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
        for idx = 10, 50 do
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
        if H.pxIdx then
            local idx = H.pxIdx
            if type(uv(H.renderFn, idx - 3)) == "number" and type(uv(H.renderFn, idx - 2)) == "number" then
                H.vxIdx, H.vyIdx = idx - 3, idx - 2
            end
            if type(uv(H.renderFn, idx + 3)) == "number" and type(uv(H.renderFn, idx + 4)) == "number" then
                H.prevXIdx, H.prevYIdx = idx + 3, idx + 4
            end
            for dIdx = idx + 2, idx + 12 do
                local v = uv(H.renderFn, dIdx)
                if type(v) == "boolean" and dIdx ~= idx + 2 then
                    H.deadIdx = dIdx
                    break
                end
            end
        end
    end
end

local Core = {}
local SkyP_Logic = { VERSION = "2.0.0", _Hooks = H, Core = Core }

function SkyP_Logic.Init(forceRefresh)
    if H.initialized and not forceRefresh and isValidGT(H.gt) and H.Net and H.ItemDB then
        return true
    end

    H.Net      = H.Net      or safeRequireShared("Net")
    H.ItemDB   = H.ItemDB   or safeRequireShared("ItemDB")
    H.Roles    = H.Roles    or safeRequireShared("Roles")
    H.Assets   = H.Assets   or safeRequireShared("Assets")
    H.ItemIcon = H.ItemIcon or safeRequireShared("ItemIcon")
    H.Autotile = H.Autotile or safeRequireShared("Autotile")

    for _, v in ipairs(safeGetGC(true)) do
        if type(v) == "table" then
            if not H.gt and isValidGT(v) then
                H.gt = v
            elseif not H.Net and isValidNet(v) then
                H.Net = v
            elseif not H.ItemDB and isValidItemDB(v) then
                H.ItemDB = v
            elseif not H.inv and isValidInv(v) then
                H.inv = v
            elseif not H.stateObj and isValidStateObj(v) then
                H.stateObj = v
            elseif not H.others and isValidOthers(v) then
                H.others = v
            elseif not H.trees and isTreeMapCandidate(v) then
                H.trees = v
            elseif not H.wheelSpins and isWheelMapCandidate(v) then
                H.wheelSpins = v
            end
        end
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
                            end
                        end
                    end
                end
                if H.trees and H.wheelSpins then break end
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
    if H.ItemIcon and type(H.ItemIcon.new) == "function" and type(H.ItemIcon.set) == "function" then
        local ok, ic = pcall(H.ItemIcon.new, parent, UDim2.fromOffset(sizePx, sizePx), (parent.ZIndex or 2) + 2)
        if ok and ic and ic.frame then
            ic.frame.AnchorPoint = Vector2.new(0.5, 0.5)
            ic.frame.Position = UDim2.fromScale(0.5, 0.5)
            pcall(H.ItemIcon.set, ic, itemId)
            return true
        end
    end
    -- Fallback manual dari ItemDB + Assets.Atlas
    local info = H.ItemDB and H.ItemDB[itemId]
    if info and info.atlas and H.Assets and H.Assets.Atlas and H.Assets.Atlas[info.atlas] then
        local img = Instance.new("ImageLabel")
        img.Size = UDim2.fromOffset(sizePx, sizePx)
        img.AnchorPoint = Vector2.new(0.5, 0.5)
        img.Position = UDim2.fromScale(0.5, 0.5)
        img.BackgroundTransparency = 1
        img.ResampleMode = Enum.ResamplerMode.Pixelated
        img.Image = H.Assets.Atlas[info.atlas]
        img.ImageRectSize = Vector2.new(32, 32)
        local cx, cy = info.tx or 0, info.ty or 0
        if H.Autotile and type(H.Autotile.aloneCell) == "function" then
            local okC, ax, ay = pcall(H.Autotile.aloneCell, info)
            if okC and ax and ay then cx, cy = ax, ay end
        end
        img.ImageRectOffset = Vector2.new(cx * 32, cy * 32)
        img.ImageColor3 = info.tint or Color3.new(1, 1, 1)
        img.ZIndex = (parent.ZIndex or 2) + 2
        img.Parent = parent
        return true
    end
    return false
end

-- Core World / Pos / Inventory / Tree helpers
function Core.EnsureInit()
    if not H.initialized or not isValidGT(H.gt) then
        SkyP_Logic.Init(true)
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
    if not H.ItemDB then SkyP_Logic.Init() end
    return (H.ItemDB and id and id ~= 0) and H.ItemDB[id] or nil
end

function Core.GetItemName(id)
    local info = Core.GetItemInfo(id)
    return info and info.name or ("Item#" .. tostring(id))
end

function Core.CountItem(id)
    if not H.inv or not id then return 0 end
    local ok, c = pcall(function() return H.inv:count(id) end)
    return (ok and type(c) == "number") and c or 0
end

function Core.GetItemRoom(id)
    if not H.inv or not id then return 0 end
    if type(H.inv.room) == "function" then
        local ok, r = pcall(function() return H.inv:room(id) end)
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
        StarterGui:SetCore("SendNotification", { Title = tostring(title or "R&8_DV"), Text = tostring(text or ""), Duration = 3 })
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
SkyP_Logic.GetcSkipper = GetcSkipper

function GetcSkipper.SetSkipUpdateItems(on)
    local S = GetcSkipper.State
    S.skipUpdateItems = on == true
    Core.EnsureInit()
    if not H.inv then return false end
    local cbKey = (type(H.inv.onChange) == "function" and "onChange")
        or (type(H.inv.changed) == "function" and "changed")
        or (type(H.inv.notify) == "function" and "notify")
    if not cbKey then return true end
    if S.skipUpdateItems then
        S.origInvNotify = S.origInvNotify or H.inv[cbKey]
        H.inv[cbKey] = function(...)
            if S.skipUpdateItems then return end
            return S.origInvNotify(...)
        end
    elseif S.origInvNotify then
        H.inv[cbKey] = S.origInvNotify
    end
    return true
end

function GetcSkipper.RandomizedWait(baseDelay, packetKind)
    local S = GetcSkipper.State
    local req = math.max(0, tonumber(baseDelay) or 0)
    if not S.enabled then
        if req > 0 then task.wait(req) end
        return req
    end
    local kind    = tostring(packetKind or "tile")
    local minInt  = S.minIntervals[kind] or 0.04
    local now     = os.clock()
    local elapsed = now - (S.lastSent[kind] or 0)
    local waitTime = req
    if req < minInt or elapsed < minInt then
        S.jitterCount += 1
        local j = S.jitterMin + math.random() * math.max(0, S.jitterMax - S.jitterMin)
        waitTime = math.max(req, minInt - elapsed) * (1 + j)
    elseif waitTime > 0 then
        waitTime = waitTime * (1 + math.random() * 0.08)
    end
    if waitTime > 0 then task.wait(waitTime) end
    S.lastSent[kind] = os.clock()
    return waitTime
end

function GetcSkipper.InRange(tx, ty, maxRange)
    local pos = Core.ReadPos()
    local d = math.max(math.abs(math.floor(tx) - pos.tx), math.abs(math.floor(ty) - pos.ty))
    return d <= (tonumber(maxRange) or GetcSkipper.State.maxRangeTiles or 5), d
end

local stepTeleportImpl
function GetcSkipper.EnsureRange(tx, ty, maxRange, stepDelay)
    if GetcSkipper.InRange(tx, ty, maxRange) then return true end
    if type(stepTeleportImpl) == "function" then
        return stepTeleportImpl(tx, ty, math.min(4, GetcSkipper.State.maxRangeTiles), stepDelay or 0.04)
    end
    return false
end

-- ═══════════════════════════════════════════════════════════════════════════
-- 5. REUSABLE RAW PACKETS (PUNCH, HIT DAMAGE, WALK/TP, PLACE, CHAT, COLLECT)
-- ═══════════════════════════════════════════════════════════════════════════
local Packets = {}
SkyP_Logic.Packets    = Packets
SkyP_Logic.RawPackets = Packets

local function moveTs()
    return math.floor((os.clock() * 1000) % 65535)
end

function Packets.SendRawMove(px, py, vx, vy, flags)
    Core.EnsureInit()
    local sendFn = H.origMoveSend or (H.Net and H.Net.move and H.Net.move.send)
    if type(sendFn) ~= "function" then return false end
    return pcall(sendFn, { x = px, y = py, vx = vx or 0, vy = vy or 0, flags = toInt(flags, 2), t = moveTs() })
end

function Packets.FindTilePath(sx, sy, gx, gy)
    local gt = H.gt
    if not gt then return nil end
    local w, h = gt.w, gt.h
    sx, sy = clamp(math.floor(sx), 0, w - 1), clamp(math.floor(sy), 0, h - 1)
    gx, gy = clamp(math.floor(gx), 0, w - 1), clamp(math.floor(gy), 0, h - 1)
    if sx == gx and sy == gy then return { { x = gx, y = gy } } end

    local startIdx, goalIdx = sy * w + sx, gy * w + gx
    local cameFrom = { [startIdx] = -1 }
    local queue, head = { startIdx }, 1
    local dirs = { { 1, 0 }, { -1, 0 }, { 0, -1 }, { 0, 1 } }
    local found = false

    while head <= #queue do
        local cur = queue[head]
        head += 1
        if cur == goalIdx then found = true; break end
        local cx, cy = cur % w, math.floor(cur / w)
        for _, d in ipairs(dirs) do
            local nx, ny = cx + d[1], cy + d[2]
            if nx >= 0 and nx < w and ny >= 0 and ny < h then
                local nIdx = ny * w + nx
                if cameFrom[nIdx] == nil and (nIdx == goalIdx or not Core.IsSolid(nx, ny)) then
                    cameFrom[nIdx] = cur
                    queue[#queue + 1] = nIdx
                end
            end
        end
    end
    if not found then return nil end
    local rev, cur = {}, goalIdx
    while cur ~= -1 do
        rev[#rev + 1] = { x = cur % w, y = math.floor(cur / w) }
        cur = cameFrom[cur]
    end
    local path = {}
    for i = #rev, 1, -1 do path[#path + 1] = rev[i] end
    return path
end

function Packets.StepTeleport(tx, ty, stepSize, stepDelay)
    Core.EnsureInit()
    local gt = H.gt
    if not gt then return false, "gt nil" end
    tx = clamp(math.floor(tx), 0, gt.w - 1)
    ty = clamp(math.floor(ty), 0, gt.h - 1)
    local maxStep = clamp(toInt(stepSize, 4), 1, 5)
    local delay   = tonumber(stepDelay) or 0.04

    local cur = Core.ReadPos()
    if cur.tx == tx and cur.ty == ty then return true, "at_target" end

    local path = Packets.FindTilePath(cur.tx, cur.ty, tx, ty)
    if path and #path > 1 then
        local idx = 1
        while idx < #path do
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
            if idx < #path then GetcSkipper.RandomizedWait(delay, "move") end
        end
        return true, "bfs_step_ok"
    end

    local cx, cy, guard = cur.tx, cur.ty, 0
    while (cx ~= tx or cy ~= ty) and guard < 200 do
        guard += 1
        cx += clamp(tx - cx, -maxStep, maxStep)
        cy += clamp(ty - cy, -maxStep, maxStep)
        local px, py = cx + 0.5, cy + 1
        Core.SetLocalCoords(px, py, 0, 0)
        Packets.SendRawMove(px, py, 0, 0, 2)
        if cx ~= tx or cy ~= ty then GetcSkipper.RandomizedWait(delay, "move") end
    end
    return true, "linear_step_ok"
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
    if m == "direct" or m == "force" then
        local px, wy = cx + 0.5, cy + 1
        Core.SetLocalCoords(px, wy, 0, 0)
        if type(gt.goTo) == "function" then pcall(gt.goTo, cx, cy) end
        Packets.SendRawMove(px, wy, 0, 0, 2)
        return true, string.format("Teleported -> Tile (%d, %d) | Stats (%d, %d)", cx, cy, cx + 1, cy + 1)
    end
    return Packets.StepTeleport(cx, cy, opts.stepSize or 4, opts.stepDelay or 0.04)
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
    local okD, drops = pcall(gt.dropList)
    if not okD or type(drops) ~= "table" then return { totalTaken = 0, gemsTaken = 0, itemsTaken = 0 } end

    local pos, now = Core.ReadPos(), os.clock()
    local list = {}
    for i = 1, #drops do
        local d = drops[i]
        if type(d) == "table" and d.uid and d.x and d.y and (d.n or 0) > 0 and (d.readyAt or 0) <= now then
            if not targetId or d.id == targetId then
                local dist = math.max(math.abs(d.x - pos.x), math.abs(d.y - (pos.y - 0.5)))
                if (stepFar or dist <= radius) and (d.id == 112 or Core.GetItemRoom(d.id) > 0) then
                    list[#list + 1] = { drop = d, dist = dist }
                end
            end
        end
    end
    table.sort(list, function(a, b) return a.dist < b.dist end)

    local sum = { totalTaken = 0, gemsTaken = 0, itemsTaken = 0 }
    for _, item in ipairs(list) do
        local d = item.drop
        local cp = Core.ReadPos()
        local dist = math.max(math.abs(d.x - cp.x), math.abs(d.y - (cp.y - 0.5)))
        if dist > 5 and stepFar then
            Packets.StepTeleport(math.floor(d.x), math.floor(d.y), 4, math.max(0.03, delay))
        end
        if dist <= 5.5 or stepFar then
            local want = math.min(d.n, (d.id == 112) and d.n or Core.GetItemRoom(d.id))
            if want > 0 then
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
                    if d.id == 112 then
                        sum.gemsTaken += got
                    else
                        sum.itemsTaken += got
                        if H.inv and type(H.inv.add) == "function" then pcall(function() H.inv:add(d.id, got) end) end
                    end
                    if delay > 0 then GetcSkipper.RandomizedWait(delay, "take") end
                end
            end
        end
    end
    return sum
end

-- ═══════════════════════════════════════════════════════════════════════════
-- 6. V1 [MISC], V2 [PNB], V3 [AUTO PABRIK], V4 [VISUAL], V5 [SPAM]
-- ═══════════════════════════════════════════════════════════════════════════
local stopAllAutomationImpl

local Misc = {
    State = {
        fly = false, flySpeed = 18,
        seems = false, seemsPaused = false, seemsReason = "",
        fastRoulette = false, lastWheelSpin = nil,
        noClip = false, noClipAnchor = nil,
        godMode = false,
        collectState = false, comboGems = 0, lastGemAt = 0, sessionGems = 0,
    }
}
SkyP_Logic.Misc = Misc

function Misc.SetFly(enabled, speed)
    Core.EnsureInit()
    Misc.State.fly = enabled == true
    if type(speed) == "number" then Misc.State.flySpeed = clamp(speed, 4, 60) end
    if H.flyConn then H.flyConn:Disconnect(); H.flyConn = nil end
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

function Misc.SetFastRoulette(enabled)
    Core.EnsureInit()
    Misc.State.fastRoulette = enabled == true
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
                local msg = string.format("%s -> %s (%d, %d)", stripColorTags(pkt.name), tostring(pkt.n), toInt(pkt.x, 0), toInt(pkt.y, 0))
                UI:SetValue("RouletteResultDisplay", msg)
                emitNotify("Fast Roulette", msg)
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

function Misc.SetGodMode(enabled)
    Core.EnsureInit()
    local net, gt = H.Net, H.gt
    Misc.State.godMode = enabled == true
    if H.godConn then H.godConn:Disconnect(); H.godConn = nil end
    if net and net.died then
        H.origDiedSend = H.origDiedSend or net.died.send
        net.died.send = Misc.State.godMode and (function() return nil end) or H.origDiedSend
    end
    if Misc.State.godMode then
        H.godConn = RunService.RenderStepped:Connect(function()
            if not Misc.State.godMode then return end
            if H.renderFn and H.deadIdx then suv(H.renderFn, H.deadIdx, false) end
            if gt and not Misc.State.noClip then
                local p = Core.ReadPos()
                local f1, f2 = Core.GetItemInfo(Core.GetFG(p.tx, p.ty)), Core.GetItemInfo(Core.GetFG(p.tx, p.ty + 1))
                gt.ghost = ((f1 and (f1.deadly or f1.hurts)) or (f2 and (f2.deadly or f2.hurts))) == true
            end
        end)
    elseif gt and not Misc.State.noClip then
        gt.ghost = false
    end
    return Misc.State.godMode
end

function Misc.SetCollectState(enabled)
    Core.EnsureInit()
    Misc.State.collectState = enabled == true
    local gt = H.gt
    if gt and type(gt.takeDrop) == "function" and not H.takeDropHooked then
        H.takeDropHooked = true
        H.origTakeDrop = H.origTakeDrop or gt.takeDrop
        gt.takeDrop = function(uid, want)
            local matchedId = nil
            if type(gt.dropList) == "function" then
                local ok, drops = pcall(gt.dropList)
                if ok and type(drops) == "table" then
                    for _, d in ipairs(drops) do
                        if type(d) == "table" and d.uid == uid then matchedId = d.id; break end
                    end
                end
            end
            local got = H.origTakeDrop(uid, want)
            if Misc.State.collectState and matchedId == 112 and type(got) == "number" and got > 0 then
                local now = os.clock()
                Misc.State.comboGems = ((now - Misc.State.lastGemAt) <= 2.5) and (Misc.State.comboGems + got) or got
                Misc.State.lastGemAt = now
                Misc.State.sessionGems += got
                local txt = string.format("Get %d Gems (Session: %d)", Misc.State.comboGems, Misc.State.sessionGems)
                UI:SetValue("CollectGemsDisplay", txt)
                emitNotify("Collect State", txt)
            end
            return got
        end
    end
    return Misc.State.collectState
end

-- V2 [PNB]
local PNB = {
    State = {
        running = false, sessionToken = 0, status = "Idle",
        selectedBlockId = nil, grid5x5 = { ["0,-1"] = true },
        oneHit = false, showHand = true, placeDelay = 0.12, breakDelay = 0.18, collectDelay = 0.05,
        autoCollect = true, lockCenterPos = false, centerPos = nil,
    }
}
SkyP_Logic.PNB = PNB

local function setPNBStatus(msg)
    PNB.State.status = msg
    UI:SetValue("PnbStatusDisplay", msg)
    if UIHooks.updateButtons then UIHooks.updateButtons() end
end

function PNB.GetBackpackBlocks(includeSeeds)
    Core.EnsureInit()
    local list = {}
    if not H.inv or type(H.inv.slots) ~= "table" then return list end
    for _, slot in ipairs(H.inv.slots) do
        if type(slot) == "table" and slot.id and (slot.n or 0) > 0 then
            local info = Core.GetItemInfo(slot.id)
            local kind = info and info.kind or "block"
            if info and slot.id ~= 18 and slot.id ~= 32 and slot.id ~= 112 and kind ~= "cloth" and kind ~= "tool" then
                if includeSeeds or kind ~= "seed" then
                    list[#list + 1] = {
                        id = slot.id, name = info.name or ("Item#" .. slot.id), count = slot.n,
                        kind = kind, layer = info.background and 2 or 1, hits = info.hits or 3,
                    }
                end
            end
        end
    end
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
    setPNBStatus("Running...")

    task.spawn(function()
        while S.running and S.sessionToken == token do
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
                if not S.running or S.sessionToken ~= token then break end
                local curId = Core.GetLayerTile(t.tx, t.ty, layer)
                if curId ~= 0 and curId ~= bid then
                    local g = 0
                    while S.running and S.sessionToken == token and Core.GetLayerTile(t.tx, t.ty, layer) ~= 0 and g < 12 do
                        g += 1
                        Packets.HitDamage({ tx = t.tx, ty = t.ty, oneHit = S.oneHit, hitDelay = S.breakDelay, layer = layer, showHand = S.showHand })
                        GetcSkipper.RandomizedWait(S.breakDelay, "tile")
                    end
                    if S.autoCollect then Packets.Collect(5, nil, false, S.collectDelay) end
                end
            end

            -- Place pass (skip jika sudah terpasang block target)
            local placedAny = false
            for _, t in ipairs(targets) do
                if not S.running or S.sessionToken ~= token then break end
                local curId = Core.GetLayerTile(t.tx, t.ty, layer)
                if curId == bid then
                    placedAny = true
                elseif curId == 0 and Core.CountItem(bid) > 0 then
                    setPNBStatus(string.format("Place (%d, %d)", t.tx, t.ty))
                    if Packets.Place({ tx = t.tx, ty = t.ty, itemId = bid, layer = layer, showHand = S.showHand }) then
                        placedAny = true
                    end
                    GetcSkipper.RandomizedWait(S.placeDelay, "tile")
                end
            end

            -- Break pass 1 per 1 sampai habis
            local brokeAny = false
            for _, t in ipairs(targets) do
                if not S.running or S.sessionToken ~= token then break end
                if Core.GetLayerTile(t.tx, t.ty, layer) ~= 0 then
                    setPNBStatus(string.format("Break (%d, %d)", t.tx, t.ty))
                    local g = 0
                    while S.running and S.sessionToken == token and Core.GetLayerTile(t.tx, t.ty, layer) ~= 0 and g < 12 do
                        g += 1
                        Packets.HitDamage({ tx = t.tx, ty = t.ty, oneHit = S.oneHit, hitDelay = S.breakDelay, layer = layer, showHand = S.showHand })
                        GetcSkipper.RandomizedWait(S.breakDelay, "tile")
                    end
                    brokeAny = true
                end
            end

            if S.running and S.sessionToken == token and S.autoCollect then
                Packets.Collect(5, nil, true, S.collectDelay)
                GetcSkipper.RandomizedWait(S.collectDelay, "take")
            end

            if not S.running or S.sessionToken ~= token then break end
            if Core.CountItem(bid) <= 0 and not brokeAny and not placedAny then
                setPNBStatus("Selesai: Block habis di backpack")
                break
            end
            task.wait(0.03)
        end
        if S.sessionToken == token then
            S.running = false
            if UIHooks.refreshBP then UIHooks.refreshBP() end
            if UIHooks.updateButtons then UIHooks.updateButtons() end
        end
    end)
    return true
end

function PNB.Toggle()
    return PNB.State.running and PNB.Stop() or PNB.Start()
end

-- V3 [AUTO PABRIK]
local Pabrik = {
    State = {
        running = false, sessionToken = 0, status = "Idle",
        selectedTiles = {}, selectedLines = {},
        blockId = nil, seedId = nil, itemName = "",
        breakPos = nil, breakTileCount = 1,
        oneHit = false, showHand = true, placeDelay = 0.14, breakDelay = 0.18, collectDelay = 0.05,
    }
}
SkyP_Logic.Pabrik = Pabrik

local function countSelectedPabrikTiles()
    local n = 0
    for _ in pairs(Pabrik.State.selectedTiles) do n += 1 end
    return n
end

local function setPabrikStatus(msg)
    Pabrik.State.status = msg
    UI:SetValue("PabrikStatusDisplay", string.format("%s | Tiles: %d", msg, countSelectedPabrikTiles()))
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

function Pabrik.ToggleLine(ty)
    Core.EnsureInit()
    local gt = H.gt
    ty = toInt(ty)
    if not gt or not ty or ty < 0 or ty >= gt.h - 1 then return false end
    if Pabrik.State.selectedLines[ty] then
        Pabrik.State.selectedLines[ty] = nil
        for x = 0, gt.w - 1 do Pabrik.State.selectedTiles[tileKey(x, ty)] = nil end
    else
        local added = 0
        for x = 0, gt.w - 1 do
            local bInfo = Core.GetItemInfo(Core.GetFG(x, ty + 1))
            if bInfo and (bInfo.solid or bInfo.platform) and Core.CanEditTile(x, ty) then
                local cId = Core.GetFG(x, ty)
                local cInfo = Core.GetItemInfo(cId)
                if cId == 0 or (cInfo and cInfo.kind == "seed") then
                    Pabrik.State.selectedTiles[tileKey(x, ty)] = { x = x, y = ty }
                    added += 1
                end
            end
        end
        if added > 0 then Pabrik.State.selectedLines[ty] = true end
    end
    setPabrikStatus("Line Y=" .. tostring(ty))
    if UIHooks.refreshMap then UIHooks.refreshMap(true) end
    return Pabrik.State.selectedLines[ty] == true
end

function Pabrik.SetItem(idOrName)
    local pair = Core.ResolveBlockAndSeedPair(idOrName)
    if not pair then return nil end
    Pabrik.State.blockId  = pair.blockId
    Pabrik.State.seedId   = pair.seedId
    Pabrik.State.itemName = pair.blockName ~= "" and pair.blockName or pair.seedName
    UI:SetValue("PabrikPairDisplay", string.format("%s | Block:%s Seed:%s", Pabrik.State.itemName, tostring(pair.blockId), tostring(pair.seedId)))
    if UIHooks.refreshPadPab then UIHooks.refreshPadPab() end
    return pair
end

function Pabrik.SetBreakPos(tx, ty)
    if tx == nil or ty == nil then
        local p = Core.ReadPos()
        tx, ty = p.tx, p.ty
    end
    Pabrik.State.breakPos = { x = math.floor(tx), y = math.floor(ty) }
    UI:SetValue("PabrikBreakPosDisplay", string.format("BreakPos (%d, %d) [%d tile]", Pabrik.State.breakPos.x, Pabrik.State.breakPos.y, Pabrik.State.breakTileCount))
    if UIHooks.refreshPadPab then UIHooks.refreshPadPab() end
    if UIHooks.refreshMap then UIHooks.refreshMap(true) end
    return Pabrik.State.breakPos
end

function Pabrik.SetBreakCount(c)
    Pabrik.State.breakTileCount = clamp(toInt(c, 1), 1, 3)
    if Pabrik.State.breakPos then
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
    setPabrikStatus("Running...")

    task.spawn(function()
        local bInfo = Core.GetItemInfo(S.blockId)
        local layer = (bInfo and bInfo.background) and 2 or 1
        while S.running and S.sessionToken == token do
            if evaluateSeems() then break end
            local gt = H.gt
            if not gt or gt.name == "" then break end

            if Core.CountItem(S.blockId) > 0 then
                setPabrikStatus(string.format("PNB Block (%d)", Core.CountItem(S.blockId)))
                Packets.StepTeleport(S.breakPos.x, S.breakPos.y, 4, 0.045)
                local offs = computePabrikBreakOffsets(S.breakTileCount)
                while S.running and S.sessionToken == token and Core.CountItem(S.blockId) > 0 do
                    if evaluateSeems() then break end
                    for _, off in ipairs(offs) do
                        if not S.running or S.sessionToken ~= token or Core.CountItem(S.blockId) <= 0 then break end
                        local tx, ty = S.breakPos.x + off.dx, S.breakPos.y + off.dy
                        if tx >= 0 and tx < gt.w and ty >= 0 and ty < gt.h and Core.CanEditTile(tx, ty) then
                            local curId = Core.GetLayerTile(tx, ty, layer)
                            if curId ~= 0 and curId ~= S.blockId then
                                Packets.HitDamage({ tx = tx, ty = ty, oneHit = S.oneHit, hitDelay = S.breakDelay, layer = layer, showHand = S.showHand, autoRange = false })
                                GetcSkipper.RandomizedWait(S.breakDelay, "tile")
                            end
                            if Core.GetLayerTile(tx, ty, layer) == 0 and Core.CountItem(S.blockId) > 0 then
                                Packets.Place({ tx = tx, ty = ty, itemId = S.blockId, layer = layer, showHand = S.showHand, autoRange = false })
                                GetcSkipper.RandomizedWait(S.placeDelay, "tile")
                            end
                        end
                    end
                    for _, off in ipairs(offs) do
                        if not S.running or S.sessionToken ~= token then break end
                        local tx, ty = S.breakPos.x + off.dx, S.breakPos.y + off.dy
                        local g = 0
                        while S.running and S.sessionToken == token and Core.GetLayerTile(tx, ty, layer) ~= 0 and g < 12 do
                            g += 1
                            Packets.HitDamage({ tx = tx, ty = ty, oneHit = S.oneHit, hitDelay = S.breakDelay, layer = layer, showHand = S.showHand, autoRange = false })
                            GetcSkipper.RandomizedWait(S.breakDelay, "tile")
                        end
                    end
                    Packets.Collect(5, nil, true, S.collectDelay)
                    GetcSkipper.RandomizedWait(S.collectDelay, "take")
                end
            elseif Core.CountItem(S.seedId) > 0 then
                Packets.Collect(5, nil, false, S.collectDelay)
                for _, t in ipairs(Pabrik.GetSortedTiles()) do
                    if not S.running or S.sessionToken ~= token or evaluateSeems() then break end
                    if Core.CountItem(S.blockId) > 0 or Core.CountItem(S.seedId) <= 0 then break end
                    if Core.IsPlantable(t.x, t.y) then
                        setPabrikStatus(string.format("Plant (%d, %d)", t.x, t.y))
                        GetcSkipper.EnsureRange(t.x, t.y, 4, 0.045)
                        Packets.Place({ tx = t.x, ty = t.y, itemId = S.seedId, layer = 1, showHand = S.showHand, autoRange = false })
                        GetcSkipper.RandomizedWait(S.placeDelay, "tile")
                    end
                end
            end

            if not S.running or S.sessionToken ~= token or evaluateSeems() then break end
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
                    Packets.Collect(5, nil, true, S.collectDelay)
                    setPabrikStatus("Menunggu seed/block (habis)")
                    task.wait(0.45)
                else
                    task.wait(0.2)
                end
            elseif #ready < #planted then
                setPabrikStatus(string.format("Grow %d/%d (~%.1fs)", #ready, #planted, minRem or 0))
                task.wait(0.35)
            else
                setPabrikStatus(string.format("Harvesting %d trees", #ready))
                for _, t in ipairs(ready) do
                    if not S.running or S.sessionToken ~= token or evaluateSeems() then break end
                    GetcSkipper.EnsureRange(t.x, t.y, 4, 0.045)
                    Packets.PunchBreak({ tx = t.x, ty = t.y, layer = 1, showHand = S.showHand, autoRange = false })
                    GetcSkipper.RandomizedWait(S.breakDelay, "tile")
                    if Core.GetFG(t.x, t.y) == 0 then Packets.Collect(5, nil, false, S.collectDelay) end
                end
                Packets.Collect(5, nil, true, S.collectDelay)
                GetcSkipper.RandomizedWait(S.collectDelay, "take")
            end
        end
        if S.sessionToken == token then
            S.running = false
            if UIHooks.refreshBP then UIHooks.refreshBP() end
            if UIHooks.updateButtons then UIHooks.updateButtons() end
        end
    end)
    return true
end

function Pabrik.Toggle()
    return Pabrik.State.running and Pabrik.Stop() or Pabrik.Start()
end

-- V4 [SET VISUALISASI]
local Visual = {
    State = {
        customName = "", role = "none", colorCode = "", customTitle = "",
        tilesName = false, hideName = false, lockNames = false,
        lastWorldName = "", lastPosKey = "", origSaved = false,
        origNick = nil, origGameName = nil, origWornTitle = nil, origDrTitle = nil, origRoleAttr = nil, origTitleAttr = nil,
    }
}
SkyP_Logic.Visual = Visual

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
    local k = "u" .. tostring(LP.UserId)
    local sr, tl = ReplicatedStorage:FindFirstChild("StaffRoles"), ReplicatedStorage:FindFirstChild("TitleList")
    S.origRoleAttr  = sr and sr:GetAttribute(k) or nil
    S.origTitleAttr = tl and tl:GetAttribute(k) or nil
end

function Visual.Apply()
    Core.EnsureInit()
    saveOrigVisual()
    local S = Visual.State
    if not LP then return false end
    local base = (S.customName ~= "" and S.customName) or (S.origGameName and tostring(S.origGameName)) or Core.GetInGameName(LP, true)
    local pos  = Core.ReadPos()
    local str  = base .. (S.tilesName and string.format(" [%d, %d]", pos.tx, pos.ty) or "")
    if S.colorCode ~= "" then str = S.colorCode .. str end
    LP:SetAttribute("Nick", str)

    local k = "u" .. tostring(LP.UserId)
    local sr = ReplicatedStorage:FindFirstChild("StaffRoles")
    if sr then
        local r = string.lower(tostring(S.role or "none"))
        sr:SetAttribute(k, (r == "developer" or r == "moderator" or r == "vip") and r or S.origRoleAttr)
    end
    local tl = ReplicatedStorage:FindFirstChild("TitleList")
    if S.customTitle ~= "" and S.customTitle ~= "none" then
        LP:SetAttribute("WornTitle", S.customTitle)
        if S.customTitle == "dr" then LP:SetAttribute("DrTitle", "Dr." .. base) end
        if tl then tl:SetAttribute(k, S.customTitle) end
    else
        LP:SetAttribute("WornTitle", S.origWornTitle)
        LP:SetAttribute("DrTitle", S.origDrTitle)
        if tl then tl:SetAttribute(k, S.origTitleAttr) end
    end
    local tag = findNameTag()
    if tag then tag.Visible = not S.hideName end
    S.lastPosKey = tileKey(pos.tx, pos.ty)
    return true
end

function Visual.Restore()
    saveOrigVisual()
    local S = Visual.State
    S.customName, S.role, S.colorCode, S.customTitle, S.tilesName, S.hideName = "", "none", "", "", false, false
    if LP then
        LP:SetAttribute("Nick", S.origNick)
        LP:SetAttribute("GameName", S.origGameName)
        LP:SetAttribute("WornTitle", S.origWornTitle)
        LP:SetAttribute("DrTitle", S.origDrTitle)
        local k = "u" .. tostring(LP.UserId)
        local sr, tl = ReplicatedStorage:FindFirstChild("StaffRoles"), ReplicatedStorage:FindFirstChild("TitleList")
        if sr then sr:SetAttribute(k, S.origRoleAttr) end
        if tl then tl:SetAttribute(k, S.origTitleAttr) end
    end
    local tag = findNameTag()
    if tag then tag.Visible = true end
    return true
end

-- V5 [SET SPAMING]
local Spam = {
    State = {
        running = false, sessionToken = 0, status = "Idle",
        text = "", maxLength = 120, prefixColor = "", autoCycleColor = false, colorIndex = 1,
        delay = 3.0, experimentalWhisperAll = false,
    }
}
SkyP_Logic.Spam = Spam

local function setSpamStatus(msg)
    Spam.State.status = msg
    UI:SetValue("SpamStatusDisplay", msg)
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
    setSpamStatus("Spamming...")

    task.spawn(function()
        while S.running and S.sessionToken == token do
            if evaluateSeems() or not H.gt or H.gt.name == "" then break end
            if S.experimentalWhisperAll then
                for _, p in ipairs(Core.GetInWorldPlayers(false)) do
                    if not S.running or S.sessionToken ~= token or evaluateSeems() then break end
                    setSpamStatus("Whisper -> " .. p.gameName)
                    Packets.SendChat({ message = Spam.FormatNextMessage(), maxLength = S.maxLength, isWhisper = true, whisperTarget = p.gameName, bypassRateLimit = true })
                    GetcSkipper.RandomizedWait(S.delay, "chat")
                end
            else
                Packets.SendChat({ message = Spam.FormatNextMessage(), maxLength = S.maxLength, bypassRateLimit = true })
                GetcSkipper.RandomizedWait(S.delay, "chat")
            end
        end
        if S.sessionToken == token then
            S.running = false
            if UIHooks.updateButtons then UIHooks.updateButtons() end
        end
    end)
    return true
end

function Spam.Toggle()
    return Spam.State.running and Spam.Stop() or Spam.Start()
end

-- Random Valid Gap Teleport State
local tpState = {
    selectedX = nil, selectedY = nil,
    patrolOn = false, patrolToken = 0, patrolDelay = 0.25,
    mapClickMode = "TP", -- "TP" | "PABRIK_TILE" | "PABRIK_LINE" | "BREAK_POS"
}

local function stopRandomTp()
    tpState.patrolOn = false
    tpState.patrolToken += 1
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
        UI:SetValue("ValidStatusDisplay", "Random Gap Teleport dihentikan.")
        return
    end
    Core.EnsureInit()
    local gt = H.gt
    if not gt or gt.name == "" then
        UI:SetValue("ValidStatusDisplay", "Belum masuk world.")
        return
    end
    tpState.patrolOn = true
    tpState.patrolToken += 1
    local tok = tpState.patrolToken
    if UIHooks.updateButtons then UIHooks.updateButtons() end
    UI:SetValue("ValidStatusDisplay", "Random Gap TP AKTIF...")

    task.spawn(function()
        while tpState.patrolOn and tpState.patrolToken == tok do
            if evaluateSeems() then break end
            local pick = pickReachableGapTile()
            if pick then
                tpState.selectedX, tpState.selectedY = pick.x, pick.y
                UI:SetValue("TpManualX", tostring(pick.x))
                UI:SetValue("TpManualY", tostring(pick.y))
                local ok, msg = Packets.WalkTeleport({ tx = pick.x, ty = pick.y, mode = "step", stepSize = 4, stepDelay = tpState.patrolDelay })
                UI:SetValue("ValidStatusDisplay", (ok and "[GAP-TP] " or "[ERR] ") .. tostring(msg))
                if UIHooks.refreshMap then UIHooks.refreshMap(true) end
            end
            task.wait(math.max(0.08, tpState.patrolDelay))
        end
        if tpState.patrolToken == tok then
            tpState.patrolOn = false
            if UIHooks.updateButtons then UIHooks.updateButtons() end
        end
    end)
end

stopAllAutomationImpl = function(reason)
    PNB.Stop()
    Pabrik.Stop()
    Spam.Stop()
    stopRandomTp()
    if Misc.State.fly then Misc.SetFly(false) end
    if Misc.State.noClip then Misc.SetNoClip(false) end
    if reason and reason ~= "" then
        UI:SetValue("ValidStatusDisplay", reason)
        setPNBStatus(reason)
        setPabrikStatus(reason)
        setSpamStatus(reason)
    end
    if UIHooks.updateButtons then UIHooks.updateButtons() end
end
SkyP_Logic.StopAllAutomation = stopAllAutomationImpl

-- ═══════════════════════════════════════════════════════════════════════════
-- 7. R&8_DV GUI LAYOUT (CANVAS LAYOUT SAMA PERSIS SAMPLEGUI.LUA)
-- ═══════════════════════════════════════════════════════════════════════════
if UI.Category then UI:Category("Overview") end

feature("Home", "Home")({
    center = center(function(c)
        c:Header("Growblox Suite Overview", "Akun In-Game aktif, player di world & kontrol cepat", "Ready")

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
            pcall(SkyP_Logic.Init, true)
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

    -- Panel Kanan Global (Identik dengan SampleGui.lua)
    right = right(function(r)
        local ThemeCard = r:Card("Theme & Checklist", nil, "Palette", {
            Subtitle = "Choose colour palette and switch/checkbox style"
        })
        if ThemeCard.ThemeSwatches then ThemeCard:ThemeSwatches("Colour Palette") end
        ThemeCard:Dropdown("Color Style", "ThemeSelect", ThemeChoices, "Minimalist Monochrome", function(sel)
            UI:SetTheme(sel)
        end)
        ThemeCard:Dropdown("Checkbox Style", "CheckboxStyleMode", { "Modern", "Checkbox" }, "Modern", function(mode)
            if UI.SetCheckboxStyle then UI:SetCheckboxStyle(mode) end
        end)
        ThemeCard:Slider("Letter Spacing", "LetterSpacingVal", 0, 3, 1, "x", function(val)
            if UI.SetLetterSpacing then UI:SetLetterSpacing(val) end
        end)

        local LayoutCard = r:Card("Window & Layout", nil, "Sliders", {
            Subtitle = "Scale, surface opacity, corners and menu hotkey"
        })
        LayoutCard:Slider("UI Scale", "UIScalePct", 60, 130, 100, "%", function(val)
            if UI.SetScale then UI:SetScale(val / 100) else UI.UIScale = val / 100 end
        end)
        LayoutCard:Slider("Transparency", "BgTransPct", 0, 55, 4, "%", function(val)
            UI:SetTransparency(val / 100)
        end)
        LayoutCard:Toggle("Rounded Borders", "RoundedState", true, function(v) UI:SetRounded(v) end)
        LayoutCard:Toggle("Lock Position", "LockPosition", false)
        if LayoutCard.Keybind then
            LayoutCard:Keybind("Toggle Menu Key", "MenuHotkey", Enum.KeyCode.RightShift, function(k)
                if k then UI.ToggleKey = k end
            end)
        end

        local PerfCard = r:Card("Performance", nil, "Bolt", {
            Subtitle = "Instant zero-tween mode for low-end devices"
        })
        PerfCard:Toggle("FPS Boost", "FPSBoost", false)
        PerfCard:Toggle("Reduce Effects", "ReduceEffects", false)
    end)
})

if UI.Category then UI:Category("Modules") end

-- TAB 1: TELEPORT & INTERACTIVE MAP
feature("Teleports", "Teleport & Map")({
    center = center(function(c)
        c:Header("Teleport & World Map", "Validasi koordinat, Step TP celah, & kontrol peta interaktif", "Active")

        local PosCard = c:Card("Lokasi Saat Ini & Validasi", "Live", "Player", {
            Subtitle = "Koordinat Stats (1-based) & Tile (0-based) langsung dari engine game"
        })
        PosCard:Input("Lokasi Saat Ini (Live)", "LivePosDisplay", "Menunggu world...", "-")
        PosCard:Input("Status Validasi", "ValidStatusDisplay", "Belum ada aksi", "-")

        local ManualCard = c:Card("Manual Teleport (Harus Valid)", nil, "Teleports", {
            Subtitle = "Masukkan X / Y atau ketuk peta untuk memilih target"
        })
        ManualCard:Input("Target Tile X", "TpManualX", "0 .. 99", "0")
        ManualCard:Input("Target Tile Y", "TpManualY", "0 .. 59", "0")
        ManualCard:Button("Cek Validasi Tile", "CEK", "Shield", function()
            local ok, msg, cx, cy = Core.ValidateTile(tonumber(UI:GetValue("TpManualX")), tonumber(UI:GetValue("TpManualY")))
            UI:SetValue("ValidStatusDisplay", msg)
            if ok then
                tpState.selectedX, tpState.selectedY = cx, cy
                if UIHooks.refreshMap then UIHooks.refreshMap(true) end
            end
        end)
        ManualCard:Button("Step Teleport (Via Celah <= 5 Tile)", "STEP TP", "Teleports", function()
            local ok, msg = Packets.WalkTeleport({ tx = tonumber(UI:GetValue("TpManualX")), ty = tonumber(UI:GetValue("TpManualY")), mode = "step", stepSize = 4 })
            UI:SetValue("ValidStatusDisplay", (ok and "[OK] " or "[INVALID] ") .. tostring(msg))
            if UIHooks.refreshMap then UIHooks.refreshMap(true) end
        end)
        ManualCard:Button("Direct Teleport (Valid)", "DIRECT TP", "Bolt", function()
            local ok, msg = Packets.WalkTeleport({ tx = tonumber(UI:GetValue("TpManualX")), ty = tonumber(UI:GetValue("TpManualY")), mode = "direct" })
            UI:SetValue("ValidStatusDisplay", (ok and "[OK] " or "[INVALID] ") .. tostring(msg))
            if UIHooks.refreshMap then UIHooks.refreshMap(true) end
        end)

        local SpamTpCard = c:Card("Spam Random Teleport (Via Celah)", nil, "Bolt", {
            Subtitle = "Otomatis cari celah valid secara cepat + tombol Stop"
        })
        SpamTpCard:Slider("Jeda Step (detik)", "SpamTpDelaySec", 0.08, 2.0, 0.25, " s", function(v)
            tpState.patrolDelay = math.max(0.08, tonumber(v) or 0.25)
        end, 0.05)
        SpamTpCard:Button("[GAP TP] Start / Stop Random Teleport", "TOGGLE", "Bolt", toggleRandomTp)
        SpamTpCard:Button("Hentikan Random Teleport", "STOP TP", "Shield", function()
            stopRandomTp()
            UI:SetValue("ValidStatusDisplay", "Random Gap Teleport dihentikan.")
        end)

        local MapCard = c:Card("Peta World Interaktif (Klik Mode Switch)", nil, "Visuals", {
            Subtitle = "Kuning: Anda | Merah: Player lain | Ungu: Tile Pabrik | Oranye: BreakPos"
        })
        MapCard:Input("Embedded World Map", "__WORLD_MAP_ANCHOR__", "__WORLD_MAP_ANCHOR_KEY__", "__WORLD_MAP_ANCHOR_KEY__")
    end)
})

-- TAB 2: V1 [MISC]
feature("Misc", "Misc (V1)")({
    center = center(function(c)
        c:Header("V1 [MISC] Utility", "Fly, Seems Safety, Fast Roulette, No Clip, God Mode & Collect State", "V1")

        local MoveMisc = c:Card("Fly & No Clip (Visual Ghost)", nil, "Teleports", {
            Subtitle = "Fly tahan posisi udara; No Clip menjaga koordinat server tetap di posisi awal"
        })
        MoveMisc:Toggle("Fly Mode (WASD / Arrow / Space)", "MiscFlyToggle", false, function(on)
            Misc.SetFly(on)
        end)
        MoveMisc:Slider("Kecepatan Fly", "MiscFlySpeed", 6, 45, 18, " t/s", function(v)
            Misc.State.flySpeed = tonumber(v) or 18
        end)
        MoveMisc:Toggle("No Clip (Visual Ghost)", "MiscNoClipToggle", false, function(on)
            Misc.SetNoClip(on)
        end)

        local SafetyMisc = c:Card("Seems & God Mode", nil, "Shield", {
            Subtitle = "Seems hentikan semua fitur bila player > 1 atau Mod/Dev masuk world"
        })
        SafetyMisc:Toggle("SEEMS (Auto Stop & Normal)", "MiscSeemsToggle", false, function(on)
            Misc.SetSeems(on)
        end)
        SafetyMisc:Toggle("God Mode (Anti Lava/Spike/Die)", "MiscGodToggle", false, function(on)
            Misc.SetGodMode(on)
        end)

        local ExtraMisc = c:Card("Fast Roulette & Collect State", nil, "Bolt", {
            Subtitle = "Lewati animasi wheel & hitung popup gems otomatis"
        })
        ExtraMisc:Toggle("Fast Roulette (Hasil Server Instan)", "MiscRouletteToggle", false, function(on)
            Misc.SetFastRoulette(on)
        end)
        ExtraMisc:Input("Hasil Roulette Terakhir", "RouletteResultDisplay", "Menunggu spin...", "-")
        ExtraMisc:Toggle("Collect State (Popup Jumlah Gems)", "MiscCollectToggle", false, function(on)
            Misc.SetCollectState(on)
        end)
        ExtraMisc:Input("Gems Terkumpul", "CollectGemsDisplay", "Get 0 Gems", "Get 0 Gems")
        ExtraMisc:Button("Collect Drops Sekitar Sekarang", "COLLECT", "Bolt", function()
            local res = Packets.Collect(5, nil, true, 0.03)
            UI:SetValue("CollectGemsDisplay", string.format("Diambil: %d items | %d gems", res.itemsTaken, res.gemsTaken))
        end)
    end)
})

-- TAB 3: V2 [PNB] (BACKPACK ITEM SPRITES + 5x5 CENTER PAD)
feature("Combat", "PNB (V2)")({
    center = center(function(c)
        c:Header("V2 [PNB] Place & Break", "Pilih item block dari Backpack (ikon asli) & atur Pad 5x5 posisi Anda di tengah", "V2")

        local CtrlCard = c:Card("Kontrol & Status PNB", nil, "Bolt", {
            Subtitle = "1 tombol Start/Stop responsif terhubung ke loop PNB"
        })
        CtrlCard:Input("Status PNB", "PnbStatusDisplay", "Idle", "Idle")
        CtrlCard:Input("Block Terpilih", "PnbSelectedDisplay", "Belum dipilih", "Belum dipilih")
        CtrlCard:Button("[PNB] Start / Stop Engine", "TOGGLE", "Bolt", function()
            PNB.Toggle()
        end)

        local BpCard = c:Card("Backpack Item Selector (Gambar Item Asli)", nil, "Visuals", {
            Subtitle = "Ketuk block di backpack untuk langsung memilih Item PNB & Pabrik"
        })
        BpCard:Input("Embedded Backpack Items", "__BP_ITEM_ANCHOR__", "__BP_ITEM_ANCHOR_KEY__", "__BP_ITEM_ANCHOR_KEY__")
        BpCard:Button("Refresh Isi Backpack", "REFRESH BP", "Visuals", function()
            if UIHooks.refreshBP then UIHooks.refreshBP() end
        end)

        local PadCard = c:Card("Pad Selector Tile 5x5 (Center = Akun In-Game Kita)", nil, "Teleports", {
            Subtitle = "Ketuk kotak sekitar karakter untuk target Place & Break"
        })
        PadCard:Input("Embedded 5x5 Pad", "__PAD_5X5_ANCHOR__", "__PAD_5X5_ANCHOR_KEY__", "__PAD_5X5_ANCHOR_KEY__")

        local OptCard = c:Card("Pengaturan Timing & Mode PNB", nil, "Sliders", {
            Subtitle = "Atur 1-Hit, Show Hand, Auto Collect & custom delay"
        })
        OptCard:Toggle("1-Hit Break Mode", "PnbOneHit", false, function(v) PNB.State.oneHit = v end)
        OptCard:Toggle("Show Hand Break", "PnbShowHand", true, function(v) PNB.State.showHand = v end)
        OptCard:Toggle("Auto Collect Drops", "PnbAutoCollect", true, function(v) PNB.State.autoCollect = v end)
        OptCard:Toggle("Lock Posisi Tengah Saat Start", "PnbLockCenter", false, function(v) PNB.State.lockCenterPos = v end)
        OptCard:Slider("Place Delay (ms)", "PnbPlaceMs", 30, 600, 120, " ms", function(v) PNB.State.placeDelay = v / 1000 end, 10)
        OptCard:Slider("Break Delay (ms)", "PnbBreakMs", 30, 600, 180, " ms", function(v) PNB.State.breakDelay = v / 1000 end, 10)
        OptCard:Slider("Collect Delay (ms)", "PnbCollectMs", 20, 400, 50, " ms", function(v) PNB.State.collectDelay = v / 1000 end, 10)
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
        StatCard:Input("Pair Block & Seed Aktif", "PabrikPairDisplay", "Belum diatur", "-")
        StatCard:Input("Posisi Break Pabrik", "PabrikBreakPosDisplay", "Belum diset", "-")
        StatCard:Button("[PABRIK] Start / Stop Auto", "TOGGLE", "Bolt", function()
            Pabrik.Toggle()
        end)

        local ItemCard = c:Card("Pilih Seed / Block & Break Pad (1-3 Tile)", nil, "Teleports", {
            Subtitle = "Ketik nama/ID item (otomatis baca ID Block + Seed) atau pilih dari tab BP"
        })
        ItemCard:Input("Nama / ID Block atau Seed", "PabrikItemInput", "Contoh: Dirt atau 2", "", function(txt)
            if txt and txt ~= "" then Pabrik.SetItem(txt) end
        end)
        ItemCard:Button("Set Item Pabrik dari Input", "SET ITEM", "Shield", function()
            local pair = Pabrik.SetItem(UI:GetValue("PabrikItemInput"))
            if not pair then
                UI:SetValue("PabrikPairDisplay", "Item tidak ditemukan di ItemDB")
            end
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
        ItemCard:Slider("Jumlah Tile Break (1-3)", "PabrikBreakCount", 1, 3, 1, " tile", function(v)
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
        TileCard:Toggle("1-Hit Mode (Pabrik)", "PabrikOneHit", false, function(v) Pabrik.State.oneHit = v end)
        TileCard:Toggle("Show Hand (Pabrik)", "PabrikShowHand", true, function(v) Pabrik.State.showHand = v end)
        TileCard:Slider("Place Delay (ms)", "PabrikPlaceMs", 40, 600, 140, " ms", function(v) Pabrik.State.placeDelay = v / 1000 end, 10)
        TileCard:Slider("Break Delay (ms)", "PabrikBreakMs", 40, 600, 180, " ms", function(v) Pabrik.State.breakDelay = v / 1000 end, 10)
        TileCard:Slider("Collect Delay (ms)", "PabrikCollectMs", 20, 400, 50, " ms", function(v) Pabrik.State.collectDelay = v / 1000 end, 10)
    end)
})

-- TAB 5: V4 [SET VISUALISASI]
feature("Visuals", "Visualisasi (V4)")({
    center = center(function(c)
        c:Header("V4 [SET VISUALISASI]", "Ubah Nama In-Game, Role, Warna, Title, Posisi Nama & Lock Names", "V4")

        local VisCard = c:Card("Pengaturan Nama & Role Visual", nil, "Player", {
            Subtitle = "Berlaku ke tampilan nama game Anda (kosongkan nama untuk pakai asli)"
        })
        VisCard:Input("Custom Name Visual", "VisCustomName", "Nama baru...", "", function(txt)
            Visual.State.customName = tostring(txt or "")
        end)
        VisCard:Dropdown("Roles Visual", "VisRoleSelect", { "none", "moderator", "developer", "vip" }, "none", function(v)
            Visual.State.role = v
        end)
        VisCard:Dropdown("Colour Name", "VisColorSelect", { "None", "`1", "`2", "`3", "`4", "`5", "`6", "`7", "`8", "`9", "`b", "`d", "`#", "`@" }, "None", function(v)
            Visual.State.colorCode = (v == "None") and "" or v
        end)
        VisCard:Dropdown("Title Visual", "VisTitleSelect", { "none", "legend", "dr", "mentor", "maxLevel" }, "none", function(v)
            Visual.State.customTitle = (v == "none") and "" or v
        end)
        VisCard:Toggle("Tiles Name [X, Y] di Nama", "VisTilesName", false, function(v) Visual.State.tilesName = v; Visual.Apply() end)
        VisCard:Toggle("Hidden Name (Sembunyikan Tag)", "VisHideName", false, function(v) Visual.State.hideName = v; Visual.Apply() end)
        VisCard:Toggle("Lock Names (Re-apply World Baru & Auto-OFF Menu)", "VisLockNames", false, function(v) Visual.State.lockNames = v end)
        VisCard:Button("Terapkan Visualisasi Sekarang", "APPLY", "Bolt", function()
            Visual.State.customName = tostring(UI:GetValue("VisCustomName") or "")
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
        c:Header("V5 [SET SPAMING] & [GETC SKIPER]", "Auto Chat Spam dengan Prefix Warna & Guard Rate-Limit", "V5")

        local SpamCard = c:Card("Set Spaming (Max 120 Karakter)", nil, "Bolt", {
            Subtitle = "Mendukung prefix warna otomatis & whisper ke player in-game"
        })
        SpamCard:Input("Status Spam", "SpamStatusDisplay", "Idle", "Idle")
        SpamCard:Input("Pesan Spam", "SpamTextInput", "Ketik pesan di sini...", "", function(txt)
            Spam.State.text = tostring(txt or "")
        end)
        SpamCard:Dropdown("Prefix Warna", "SpamPrefixSelect", { "None", "`1", "`2", "`3", "`4", "`5", "`6", "`7", "`8", "`9", "`b", "`d", "`#", "`@" }, "None", function(v)
            Spam.State.prefixColor = (v == "None") and "" or v
        end)
        SpamCard:Toggle("Auto Cycle Colour (`1..`9)", "SpamAutoColor", false, function(v) Spam.State.autoCycleColor = v end)
        SpamCard:Toggle("Experimental: Whisper All (Player Game)", "SpamWhisperAll", false, function(v) Spam.State.experimentalWhisperAll = v end)
        SpamCard:Slider("Delay Kirim (detik)", "SpamDelaySec", 1.7, 10.0, 3.0, " s", function(v)
            Spam.State.delay = math.max(1.65, tonumber(v) or 3.0)
        end, 0.1)
        SpamCard:Button("[SPAM] Start / Stop Chat", "TOGGLE", "Bolt", function()
            Spam.State.text = tostring(UI:GetValue("SpamTextInput") or "")
            Spam.Toggle()
        end)

        local GuardCard = c:Card("[GETC SKIPER] Rate Limit & Range Guard", nil, "Shield", {
            Subtitle = "Otomatis acak jeda bila fitur berjalan terlalu cepat & jaga range <= 5 tile"
        })
        GuardCard:Toggle("Aktifkan Randomized Jitter Guard", "GuardEnabled", true, function(v)
            GetcSkipper.State.enabled = v
        end)
        GuardCard:Toggle("Skip Update Items UI Berulang", "GuardSkipItems", false, function(v)
            GetcSkipper.SetSkipUpdateItems(v)
        end)
        GuardCard:Slider("Max Range Auto Step (Tiles)", "GuardMaxRange", 1, 5, 5, " tiles", function(v)
            GetcSkipper.State.maxRangeTiles = clamp(toInt(v, 5), 1, 5)
        end, 1)
    end)
})

-- ═══════════════════════════════════════════════════════════════════════════
-- 8. EMBEDDED CANVAS MOUNTING + SIDEBAR IN-GAME ACCOUNT SYNC
-- ═══════════════════════════════════════════════════════════════════════════
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
local buttonMap = {}
local function scanResponsiveButtons()
    local specs = {
        { prefix = "[PNB]",    getState = function() return PNB.State.running,    "STOP PNB",    "START PNB",    "[PNB] AKTIF (Klik untuk STOP)",    "[PNB] Start / Stop Engine" end },
        { prefix = "[PABRIK]", getState = function() return Pabrik.State.running, "STOP PABRIK", "START PABRIK", "[PABRIK] AKTIF (Klik untuk STOP)", "[PABRIK] Start / Stop Auto" end },
        { prefix = "[SPAM]",   getState = function() return Spam.State.running,   "STOP SPAM",   "START SPAM",   "[SPAM] AKTIF (Klik untuk STOP)",   "[SPAM] Start / Stop Chat" end },
        { prefix = "[GAP TP]", getState = function() return tpState.patrolOn,     "STOP TP",     "START TP",     "[GAP TP] AKTIF (Klik untuk STOP)", "[GAP TP] Start / Stop Random Teleport" end },
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
                                    task.delay(0.60, function()
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

-- A. MOUNT 1: EMBEDDED WORLD MAP RENDERER (__WORLD_MAP_ANCHOR_KEY__)
mountEmbeddedCanvas("__WORLD_MAP_ANCHOR_KEY__", 285, function(rowContainer)
    local scroller = rowContainer:FindFirstAncestorOfClass("ScrollingFrame")

    -- Top Mode Switcher Bar
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
    mapView.BackgroundColor3 = Color3.fromRGB(8, 10, 15)
    mapView.BorderSizePixel = 0
    mapView.ClipsDescendants = true
    mapView.Active = true
    mapView.Parent = rowContainer

    local mapCanvas = Instance.new("Frame")
    mapCanvas.BackgroundColor3 = Color3.fromRGB(15, 20, 30)
    mapCanvas.BorderSizePixel = 0
    mapCanvas.Parent = mapView
    Instance.new("UIStroke", mapCanvas).Color = Color3.fromRGB(70, 86, 114)

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

    local function renderMap(force)
        if not rowContainer or not rowContainer.Parent or not mapView.Visible then return end
        if mapView.AbsoluteSize.X <= 10 or mapView.AbsoluteSize.Y <= 10 then return end
        local now = os.clock()
        if not force and (now - lastDraw) < 0.25 then return end
        lastDraw = now

        local gt = H.gt
        local w, h = (gt and gt.w) or 100, (gt and gt.h) or 60
        if not didFit or fittedW ~= w or fittedH ~= h then fitMap() else updateTransform() end
        if not gt or not gt.fg then return end

        local px, used = mapTilePx, 0
        -- 1. Walls (BG when FG == 0)
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
                            local f = getBox(used, 1, Color3.fromRGB(24, 30, 42), 0, false)
                            f.Position = UDim2.fromOffset(sx * px, y * px)
                            f.Size = UDim2.fromOffset(math.max(1, (x - sx) * px), math.max(1, px))
                        else
                            x += 1
                        end
                    end
                end
            end
        end

        -- 2. Terrain solid + seeds + doors
        for y = 0, h - 1 do
            local row = gt.fg[y]
            if row then
                local x = 0
                while x < w do
                    local id = row[x] or 0
                    local info = Core.GetItemInfo(id)
                    if id ~= 0 and ((info and (info.solid or info.platform)) or not info) then
                        local isBed = (id == 8)
                        local sx = x
                        while x < w do
                            local nid = row[x] or 0
                            local ninfo = Core.GetItemInfo(nid)
                            local isT = (nid ~= 0) and ((ninfo and (ninfo.solid or ninfo.platform)) or not ninfo)
                            if not isT or ((nid == 8) ~= isBed) then break end
                            x += 1
                        end
                        used += 1
                        local f = getBox(used, 2, isBed and Color3.fromRGB(54, 61, 76) or Color3.fromRGB(84, 93, 112), 0, false)
                        f.Position = UDim2.fromOffset(sx * px, y * px)
                        f.Size = UDim2.fromOffset(math.max(1, (x - sx) * px), math.max(1, px))
                    else
                        if info and (info.kind == "seed" or info.door or id == 6) then
                            used += 1
                            local col = (info.kind == "seed") and (Core.IsTreeRipe(x, y) and Color3.fromRGB(250, 204, 21) or Color3.fromRGB(52, 185, 110)) or Color3.fromRGB(96, 165, 250)
                            local f = getBox(used, 3, col, 0, false)
                            f.Position = UDim2.fromOffset(x * px, y * px)
                            f.Size = UDim2.fromOffset(math.max(2, px), math.max(2, px))
                        end
                        x += 1
                    end
                end
            end
        end

        -- 3. Auto Pabrik selected tiles (Purple) & breakPos (Orange)
        for _, pt in pairs(Pabrik.State.selectedTiles) do
            used += 1
            local f = getBox(used, 3, Color3.fromRGB(168, 85, 247), 0.25, false)
            f.Position = UDim2.fromOffset(pt.x * px, pt.y * px)
            f.Size = UDim2.fromOffset(math.max(2, px), math.max(2, px))
        end
        if Pabrik.State.breakPos then
            used += 1
            local f = getBox(used, 4, Color3.fromRGB(249, 115, 22), 0.1, false)
            f.Position = UDim2.fromOffset(Pabrik.State.breakPos.x * px, Pabrik.State.breakPos.y * px)
            f.Size = UDim2.fromOffset(math.max(4, px), math.max(4, px))
        end

        -- 4. Selected TP tile (Cyan/Red)
        if tpState.selectedX and tpState.selectedY then
            local ok = Core.ValidateTile(tpState.selectedX, tpState.selectedY)
            used += 1
            local f = getBox(used, 4, ok and Color3.fromRGB(56, 189, 248) or Color3.fromRGB(239, 68, 68), 0.1, false)
            f.Position = UDim2.fromOffset(tpState.selectedX * px, tpState.selectedY * px)
            f.Size = UDim2.fromOffset(math.max(4, px), math.max(4, px))
        end

        -- 5. Other in-world players (Red dot) + Self (Yellow dot)
        for _, op in ipairs(Core.GetInWorldPlayers(false)) do
            if op.tx and op.ty then
                used += 1
                local f = getBox(used, 5, Color3.fromRGB(244, 63, 94), 0, true)
                local dsz = math.max(4, px + 1)
                f.Position = UDim2.fromOffset(op.tx * px, op.ty * px)
                f.Size = UDim2.fromOffset(dsz, dsz)
            end
        end
        local selfPos = Core.ReadPos()
        used += 1
        local dot = getBox(used, 6, Color3.fromRGB(250, 204, 21), 0, true)
        local dsz = math.max(5, px + 1.5)
        dot.Position = UDim2.fromOffset(selfPos.tx * px, selfPos.ty * px)
        dot.Size = UDim2.fromOffset(dsz, dsz)

        for i = used + 1, #mapPool do mapPool[i].Visible = false end
    end
    UIHooks.refreshMap = renderMap

    local activeInput, moved, startScr, startPan, savedScroll = nil, false, nil, nil, nil
    mapView.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            activeInput, moved, startScr, startPan = inp, false, inp.Position, Vector2.new(mapPanX, mapPanY)
            scroller = scroller or rowContainer:FindFirstAncestorOfClass("ScrollingFrame")
            if scroller and savedScroll == nil then
                savedScroll = scroller.ScrollingEnabled
                scroller.ScrollingEnabled = false
            end
        end
    end)
    mapView.InputChanged:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseWheel then
            applyZoom(mapTilePx * (inp.Position.Z > 0 and 1.18 or (1 / 1.18)))
            renderMap(true)
        end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if not activeInput then return end
        local same = (activeInput.UserInputType == Enum.UserInputType.Touch and inp == activeInput)
            or (activeInput.UserInputType == Enum.UserInputType.MouseButton1 and inp.UserInputType == Enum.UserInputType.MouseMovement)
        if same and startScr and startPan then
            local d = inp.Position - startScr
            if d.Magnitude > 6 then
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
        local wasMoved, inpType = moved, inp.UserInputType
        activeInput = nil
        if scroller and savedScroll ~= nil then scroller.ScrollingEnabled = savedScroll; savedScroll = nil end
        if not wasMoved and rowContainer.Visible and mapView.AbsoluteSize.X > 10 then
            local cx, cy = inp.Position.X, inp.Position.Y
            local sg = mapView:FindFirstAncestorOfClass("ScreenGui")
            if sg and sg.IgnoreGuiInset then
                if inpType == Enum.UserInputType.MouseButton1 then
                    local okMl, ml = pcall(function() return UserInputService:GetMouseLocation() end)
                    if okMl and ml then cx, cy = ml.X, ml.Y end
                else
                    local okIn, top = pcall(function() return GuiService:GetGuiInset() end)
                    if okIn and top then cx += top.X; cy += top.Y end
                end
            end
            local absPos, absSize = mapCanvas.AbsolutePosition, mapCanvas.AbsoluteSize
            local maxW, maxH = (H.gt and H.gt.w) or 100, (H.gt and H.gt.h) or 60
            local rx, ry = cx - absPos.X, cy - absPos.Y
            if absSize.X <= 1 or absSize.Y <= 1 or rx < 0 or ry < 0 or rx >= absSize.X or ry >= absSize.Y then return end
            local tx = clamp(math.floor((rx / absSize.X) * maxW), 0, maxW - 1)
            local ty = clamp(math.floor((ry / absSize.Y) * maxH), 0, maxH - 1)

            if tpState.mapClickMode == "PABRIK_TILE" then
                local added = Pabrik.ToggleTile(tx, ty)
                infoLbl.Text = string.format("Pabrik Tile (%d, %d): %s", tx, ty, added and "ON" or "OFF")
            elseif tpState.mapClickMode == "PABRIK_LINE" then
                local added = Pabrik.ToggleLine(ty)
                infoLbl.Text = string.format("Pabrik Line Y=%d: %s", ty, added and "SELECTED" or "UNSELECTED")
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
        b.Size = UDim2.new(0.28, -4, 1, 0)
        b.Position = UDim2.new((i - 1) * 0.29, 0, 0, 0)
        b.BorderSizePixel = 0
        b.Font = Enum.Font.GothamBold
        b.TextSize = 10
        b.Text = m
        b.Parent = topBar
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
        b.MouseButton1Click:Connect(function()
            filterMode = m
            if rebuildBP then rebuildBP() end
        end)
        filterBtns[m] = b
    end

    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, -12, 1, -36)
    scroll.Position = UDim2.fromOffset(6, 32)
    scroll.BackgroundColor3 = Color3.fromRGB(8, 10, 15)
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 4
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
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
        for _, it in ipairs(items) do
            local show = (filterMode == "ALL") or (filterMode == "SEED" and it.kind == "seed") or (filterMode == "BLOCK" and it.kind ~= "seed")
            if show then
                local isSel = (PNB.State.selectedBlockId == it.id) or (Pabrik.State.blockId == it.id) or (Pabrik.State.seedId == it.id)
                local cell = Instance.new("TextButton")
                cell.Text = ""
                cell.AutoButtonColor = false
                cell.BackgroundColor3 = isSel and Color3.fromRGB(22, 48, 68) or Color3.fromRGB(19, 24, 34)
                cell.BorderSizePixel = 0
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
    end
    UIHooks.refreshBP = rebuildBP
    task.delay(0.4, rebuildBP)
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

-- ═══════════════════════════════════════════════════════════════════════════
-- 9. RUNTIME WATCHER: LIVE POS, IN-GAME NAME SIDEBAR SYNC, LOCK NAMES, SEEMS
-- ═══════════════════════════════════════════════════════════════════════════
task.spawn(function()
    task.wait(0.6)
    pcall(SkyP_Logic.Init, true)
    scanResponsiveButtons()
    UIHooks.updateButtons()
    if UIHooks.refreshBP then UIHooks.refreshBP() end
    if UIHooks.refreshMap then UIHooks.refreshMap(true) end
end)

local function computeInvHash()
    if not H.inv or type(H.inv.slots) ~= "table" then return "" end
    local sum, cnt = 0, 0
    for i, s in ipairs(H.inv.slots) do
        if type(s) == "table" and (s.n or 0) > 0 then
            cnt += 1
            sum += ((s.id or 0) * 13 + s.n) * (i % 7 + 1)
        end
    end
    return tostring(cnt) .. ":" .. tostring(sum)
end

local lastFastTick, lastSlowTick, lastLivePos, lastInvHash = 0, 0, "", ""
H.watcherConn = RunService.Heartbeat:Connect(function()
    local now = os.clock()
    if (now - lastFastTick) < 0.25 then return end
    lastFastTick = now

    local gt = H.gt
    local curWorld = gt and cleanWorldName(gt.name) or ""

    -- Sinkronkan perubahan world: reset semua fitur auto ke OFF + Lock Names re-apply
    if curWorld ~= Visual.State.lastWorldName then
        local prev = Visual.State.lastWorldName
        Visual.State.lastWorldName = curWorld
        if prev ~= "" then
            stopAllAutomationImpl("Pindah world -> Otomasi OFF")
        end
        if curWorld ~= "" and Visual.State.lockNames then
            task.delay(0.35, function() if Visual.State.lockNames then Visual.Apply() end end)
        end
    end

    if gt and (gt.name or "") ~= "" then
        local pos = Core.ReadPos()
        local okHere = Core.ValidateTile(pos.tx, pos.ty)
        local liveStr = string.format("Stats (%d, %d) | Tile (%d, %d) | %s [%s]", pos.sx, pos.sy, pos.tx, pos.ty, tostring(gt.name), okHere and "VALID" or "SOLID")
        if liveStr ~= lastLivePos then
            lastLivePos = liveStr
            UI:SetValue("LivePosDisplay", liveStr)
            if Visual.State.tilesName then Visual.Apply() end
            if UIHooks.refreshPad5x5 then UIHooks.refreshPad5x5() end
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
        if not H.gt or not H.ItemDB or not H.Net or not H.inv or not H.others then pcall(SkyP_Logic.Init) end
        if not buttonMap["[PNB]"] or not buttonMap["[PABRIK]"] or not buttonMap["[SPAM]"] or not buttonMap["[GAP TP]"] or not UIHooks.sidebarNameLbl then
            scanResponsiveButtons()
            UIHooks.updateButtons()
        end
        local invHash = computeInvHash()
        if invHash ~= lastInvHash then
            lastInvHash = invHash
            if UIHooks.refreshBP then UIHooks.refreshBP() end
        end
        if UIHooks.refreshMap then UIHooks.refreshMap(false) end
        if gt and gt.name ~= "" then
            local plrs = Core.GetInWorldPlayers(true)
            local nms = {}
            for _, p in ipairs(plrs) do nms[#nms + 1] = p.gameName .. (p.isStaff and "[MOD]" or "") end
            UI:SetValue("LiveInGameAccount", string.format("%s | World: %s", Core.GetInGameName(LP, true), tostring(gt.name)))
            UI:SetValue("LiveWorldPlayers", #nms > 0 and table.concat(nms, ", ") or "-")
        end
    end
end)

getEnv().SkyP_Logic = SkyP_Logic
return SkyP_Logic
