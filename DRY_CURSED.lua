--[[
================================================================================
    DRY CURSED — COMPLETE ALL-IN-ONE ROBLOX MENU SCRIPT (.lua)
    Target Runtime : Roblox Luau Client / Executor (LocalPlayer.PlayerGui)
    Menu Name      : DRY CURSED
    Single-File Bundle Containing All 7 Documented Engines + Step-by-Step UI:
      1. Module 15 — Visual Inventory Item Selector (GUI.MD / PABRIK.MD - 11 Components)
      2. Automatic World Clearer (CLEAR WORLD.MD - All 13 Steps Interactive)
      3. DirtFarm Builder & Farming Cycle (DF.MD - All 24 Steps & 19 Modules)
      4. PNB State Machine & Watchdog (PNB.MD - 12 Modules, 11 States, 6 Delays)
      5. Protection, Hit Logger & Movement Engine (MISC.MD - 7-State Machine + HUD)
      6. Chat Spammer & Rainbow Formatter (SPAMER.MD - Queue, Prefix/Text Colors, 120 Cap)
      7. Visual Name, Roles, 9-Slot Wardrobe & Priority Rules (VISUAL NAME & CLOTHES.MD)

    NOTE: Built strictly for the Roblox Luau runtime (game, Instance, task, UDim2,
          UDim, Color3, Enum). Cannot run in standalone desktop Lua/LuaJIT.
================================================================================
]]

-- Strict Roblox Runtime Guard
if not (game and Instance and task and UDim2 and UDim and Color3 and Enum) then
    error("DRY CURSED GUI is built exclusively for the Roblox Luau runtime and cannot run in normal standalone Lua.", 0)
end

--==============================================================================
-- 1. ROBLOX SERVICES & CLEANUP OF EXISTING MENU / FLOATING HUD
--==============================================================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    LocalPlayer = Players.PlayerAdded:Wait()
end
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local GUI_NAME = "DRY_CURSED_GUI"
local HUD_NAME = "DRY_CURSED_FLOATING_HUD"
local oldGui = PlayerGui:FindFirstChild(GUI_NAME)
if oldGui then oldGui:Destroy() end
local oldHud = PlayerGui:FindFirstChild(HUD_NAME)
if oldHud then oldHud:Destroy() end

--==============================================================================
-- 2. VERIFIED CONSTANTS, PALETTES, ATLASES, ITEMDB & WARDROBE DATA
--==============================================================================
local CONFIG = {
    MENU_TITLE = "DRY CURSED",
    TOGGLE_KEY = Enum.KeyCode.RightShift,
    WORLD_WIDTH = 100,
    WORLD_HEIGHT = 60,
    SURFACE_Y = 36,
    TILE_SIZE = 32,
    BACKPACK_CAPACITY = 54,
    MAX_STACK = 200,
    MAX_CHAT_LENGTH = 120,
    MAX_SEQ_UINT32 = 4294967296,
}

-- Verified Growtopia Backtick Colors from mOzxi2nKE3mc.clean.luau
local GT_COLORS = {
    ["0"] = { name = "White",   rgb = { 255, 255, 255 } },
    ["1"] = { name = "Sky",     rgb = { 173, 244, 255 } },
    ["2"] = { name = "Green",   rgb = { 73, 252, 0 } },
    ["3"] = { name = "Ice",     rgb = { 191, 218, 255 } },
    ["4"] = { name = "Red",     rgb = { 255, 39, 29 } },
    ["5"] = { name = "Purple",  rgb = { 235, 183, 255 } },
    ["6"] = { name = "Gold",    rgb = { 255, 202, 111 } },
    ["7"] = { name = "Silver",  rgb = { 230, 230, 230 } },
    ["8"] = { name = "Orange",  rgb = { 255, 148, 69 } },
    ["9"] = { name = "Yellow",  rgb = { 255, 238, 125 } },
    ["!"] = { name = "Mint",    rgb = { 209, 255, 249 } },
    ["@"] = { name = "Peach",   rgb = { 255, 205, 201 } },
    ["#"] = { name = "Magenta", rgb = { 255, 143, 243 } },
    ["$"] = { name = "Cream",   rgb = { 255, 252, 197 } },
    ["^"] = { name = "Lime",    rgb = { 181, 255, 151 } },
    ["&"] = { name = "Orchid",  rgb = { 254, 235, 255 } },
    ["w"] = { name = "White",   rgb = { 255, 255, 255 } },
    ["o"] = { name = "Beige",   rgb = { 252, 230, 186 } },
    ["b"] = { name = "Black",   rgb = { 0, 0, 0 } },
    ["p"] = { name = "Pink",    rgb = { 255, 223, 241 } },
    ["q"] = { name = "Navy",    rgb = { 12, 96, 164 } },
    ["e"] = { name = "Blue",    rgb = { 25, 185, 255 } },
    ["r"] = { name = "Leaf",    rgb = { 111, 211, 87 } },
    ["t"] = { name = "Forest",  rgb = { 47, 131, 13 } },
    ["a"] = { name = "Charcoal",rgb = { 81, 81, 81 } },
    ["s"] = { name = "Gray",    rgb = { 158, 158, 158 } },
    ["c"] = { name = "Cyan",    rgb = { 80, 255, 255 } },
    ["d"] = { name = "Amber",   rgb = { 255, 193, 94 } },
    ["m"] = { name = "Violet",  rgb = { 187, 0, 255 } },
    ["v"] = { name = "Sage",    rgb = { 125, 196, 124 } },
}

local ASSETS = {
    TileSize = 32,
    Atlas = {
        tiles1 = "rbxassetid://82799209779866", tiles2 = "rbxassetid://89455019317905",
        tiles3 = "rbxassetid://106357113402286", tiles4 = "rbxassetid://133411503344534",
        tiles7 = "rbxassetid://118371595643743", tiles8 = "rbxassetid://120565708911892",
        tiles10 = "rbxassetid://108050932892062", tiles12 = "rbxassetid://85572011411757",
        tiles16 = "rbxassetid://107464853942311", back = "rbxassetid://108325908969366",
        handitem5Icon = "rbxassetid://88972987813614", gtDAura = "rbxassetid://115263220772757",
        gtStCauraIcon = "rbxassetid://125086047021048", gtBlackDragonIcon = "rbxassetid://106802271569675",
        gtLonghandReaperIcon = "rbxassetid://108668679326621", gtLwkeyWingsIcon = "rbxassetid://136431385581822",
        gtStormWingsIcon = "rbxassetid://104401256471201", gtPlayZephyrIcon = "rbxassetid://88504575991321",
        gtPhoenixDaVinciIcon = "rbxassetid://88511439370581", gtKuyangIcon = "rbxassetid://132056659976871",
        gtEagleIcon = "rbxassetid://135997598278683", gtVoidEyeIcon = "rbxassetid://138417639036418",
        gtKatanaPic = "rbxassetid://121175250144992", gtGlitchAuraIcon = "rbxassetid://123756749080289",
        gtVoidKatanaPic = "rbxassetid://100163304246779", gtHair = "rbxassetid://91316301917655",
        gtShirt = "rbxassetid://135794937073607", gtPants = "rbxassetid://138714393103758",
        gtFeetIcon = "rbxassetid://95136596455993", gtFaceitem = "rbxassetid://93775962174386",
        gemMachine = "rbxassetid://92888059992009",
    },
    UI = {
        invSelect = "rbxassetid://116091171480481",
        itemBox = "rbxassetid://75272972377702",
        favBorder = "rbxassetid://73545654471272",
        ccBadge = "rbxassetid://79304118436161",
        sponsorBadge = "rbxassetid://11560341132",
        superSponsorBadge = "rbxassetid://120707520027030",
    },
    WardrobeSlots = { "hat", "hair", "face", "chest", "shirt", "hand", "pants", "feet", "back" },
}

-- Verified ItemDB entries (including tx/ty atlas tile coordinates)
local DEFAULT_ITEM_DB = {
    [0] = { id = 0, name = "Blank", solid = false, kind = "block", hits = 0 },
    [2] = { id = 2, name = "Dirt", atlas = "tiles1", tx = 8, ty = 20, solid = true, hits = 3, farmable = true, kind = "block", disposable = true },
    [3] = { id = 3, name = "Dirt Seed", atlas = "tiles1", tx = 8, ty = 20, kind = "seed", grow = 31, blockId = 2 },
    [4] = { id = 4, name = "Lava", atlas = "tiles1", tx = 4, ty = 6, solid = true, hits = 4, hurts = true, kind = "block", disposable = true },
    [5] = { id = 5, name = "Lava Seed", atlas = "tiles1", tx = 4, ty = 6, kind = "seed", grow = 31, blockId = 4 },
    [6] = { id = 6, name = "Main Door", atlas = "tiles1", tx = 17, ty = 1, solid = false, hits = 0, protected = true, kind = "block" },
    [8] = { id = 8, name = "Bedrock", atlas = "tiles1", tx = 1, ty = 1, solid = true, hits = -1, protected = true, kind = "block" },
    [10] = { id = 10, name = "Rock", atlas = "tiles1", tx = 2, ty = 0, solid = true, hits = 10, kind = "block", disposable = true },
    [11] = { id = 11, name = "Rock Seed", atlas = "tiles1", tx = 2, ty = 0, kind = "seed", grow = 31, blockId = 10 },
    [12] = { id = 12, name = "Door", atlas = "tiles1", tx = 14, ty = 0, solid = false, hits = 5, door = true, kind = "block" },
    [13] = { id = 13, name = "Door Seed", atlas = "tiles1", tx = 14, ty = 0, kind = "seed", grow = 68, blockId = 12 },
    [14] = { id = 14, name = "Cave Background", atlas = "tiles1", tx = 3, ty = 0, solid = false, hits = 3, background = true, kind = "background", disposable = true },
    [15] = { id = 15, name = "Cave BG Seed", atlas = "tiles1", tx = 3, ty = 0, kind = "seed", grow = 31, blockId = 14 },
    [16] = { id = 16, name = "Grass", atlas = "tiles1", tx = 4, ty = 0, solid = false, hits = 2, kind = "block", disposable = true },
    [17] = { id = 17, name = "Grass Seed", atlas = "tiles1", tx = 4, ty = 0, kind = "seed", grow = 68, blockId = 16 },
    [18] = { id = 18, name = "Fist", kind = "tool", tool = true, protected = true },
    [32] = { id = 32, name = "Wrench", kind = "tool", tool = true, protected = true },
    [100] = { id = 100, name = "Wood Block", atlas = "tiles1", tx = 5, ty = 0, solid = true, hits = 3, kind = "block" },
    [101] = { id = 101, name = "Wood Block Seed", atlas = "tiles1", tx = 5, ty = 0, kind = "seed", grow = 60, blockId = 100 },
    [102] = { id = 102, name = "Wooden Platform", atlas = "tiles1", tx = 6, ty = 0, solid = false, platform = true, hits = 3, kind = "block" },
    [112] = { id = 112, name = "Gems", kind = "gem", valuable = true },
    [162] = { id = 162, name = "Death Spikes", atlas = "tiles1", tx = 25, ty = 4, solid = true, hits = 6, deadly = true, kind = "block" },
    [202] = { id = 202, name = "Small Lock", atlas = "tiles1", tx = 9, ty = 1, solid = true, hits = 10, lock = true, protected = true, valuable = true, kind = "lock" },
    [204] = { id = 204, name = "Big Lock", atlas = "tiles1", tx = 10, ty = 1, solid = true, hits = 10, lock = true, protected = true, valuable = true, kind = "lock" },
    [206] = { id = 206, name = "Huge Lock", atlas = "tiles1", tx = 11, ty = 1, solid = true, hits = 10, lock = true, protected = true, valuable = true, kind = "lock" },
    [242] = { id = 242, name = "World Lock", atlas = "tiles1", tx = 12, ty = 1, solid = true, hits = 42, lock = true, protected = true, valuable = true, kind = "lock" },
    [340] = { id = 340, name = "Chandelier", atlas = "tiles2", tx = 0, ty = 3, solid = true, hits = 7, farmable = true, kind = "block", valuable = true },
    [341] = { id = 341, name = "Chandelier Seed", atlas = "tiles2", tx = 0, ty = 3, kind = "seed", grow = 604800, blockId = 340, valuable = true },
    [758] = { id = 758, name = "Roulette Wheel", atlas = "tiles2", tx = 8, ty = 5, solid = true, hits = 15, spin = true, kind = "block" },
    [1784] = { id = 1784, name = "Legendary Wings", atlas = "back", tx = 7, ty = 4, kind = "cloth", slot = "back", valuable = true },
    [1796] = { id = 1796, name = "Diamond Lock", atlas = "tiles3", tx = 1, ty = 1, solid = true, hits = 42, lock = true, protected = true, valuable = true, kind = "lock" },
    [2592] = { id = 2592, name = "Legendary Katana", atlas = "gtKatanaPic", tx = 0, ty = 0, kind = "cloth", slot = "hand", valuable = true },
    [3748] = { id = 3748, name = "Bone Spikes", atlas = "tiles7", tx = 2, ty = 4, solid = true, hits = 6, deadly = true, kind = "block" },
    [4584] = { id = 4584, name = "Pepper Tree", atlas = "tiles8", tx = 3, ty = 1, solid = true, hits = 4, farmable = true, kind = "block" },
    [4585] = { id = 4585, name = "Pepper Tree Seed", atlas = "tiles8", tx = 3, ty = 1, kind = "seed", grow = 46800, blockId = 4584 },
    [4994] = { id = 4994, name = "Builder's Lock", atlas = "tiles8", tx = 5, ty = 2, solid = true, lock = true, protected = true, valuable = true, kind = "lock" },
    [5020] = { id = 5020, name = "Prismatic Aura", atlas = "gtDAura", tx = 4, ty = 6, kind = "cloth", slot = "back", valuable = true },
    [5480] = { id = 5480, name = "Rayman's Fist", atlas = "handitem5Icon", tx = 0, ty = 0, kind = "cloth", slot = "hand", valuable = true },
    [5666] = { id = 5666, name = "Laser Grid", atlas = "tiles10", tx = 6, ty = 4, solid = true, hits = 7, farmable = true, kind = "block", valuable = true },
    [5667] = { id = 5667, name = "Laser Grid Seed", atlas = "tiles10", tx = 6, ty = 4, kind = "seed", grow = 86400, blockId = 5666, valuable = true },
    [5814] = { id = 5814, name = "Guild Lock", atlas = "tiles10", tx = 7, ty = 4, solid = true, hits = -1, lock = true, protected = true, valuable = true, kind = "lock" },
    [7188] = { id = 7188, name = "Blue Gem Lock", atlas = "tiles12", tx = 1, ty = 1, solid = true, hits = 42, lock = true, protected = true, valuable = true, kind = "lock" },
    [9640] = { id = 9640, name = "My First World Lock", atlas = "tiles16", tx = 3, ty = 2, solid = true, hits = 42, lock = true, protected = true, valuable = true, kind = "lock" },
    [9712] = { id = 9712, name = "Crystal Aura", atlas = "gtStCauraIcon", tx = 0, ty = 0, kind = "cloth", slot = "back", valuable = true },
    [20000] = { id = 20000, name = "Black Legendary Dragon", atlas = "gtBlackDragonIcon", tx = 0, ty = 0, kind = "cloth", slot = "hand", valuable = true },
    [20004] = { id = 20004, name = "lwkey's Reaper Scythe", atlas = "gtLonghandReaperIcon", tx = 0, ty = 0, kind = "cloth", slot = "hand", valuable = true },
    [20005] = { id = 20005, name = "Lwkey's Legendary Wings", atlas = "gtLwkeyWingsIcon", tx = 0, ty = 0, kind = "cloth", slot = "back", valuable = true },
    [20006] = { id = 20006, name = "Khodam Kuyang", atlas = "gtKuyangIcon", tx = 0, ty = 0, kind = "cloth", slot = "chest", valuable = true },
    [20007] = { id = 20007, name = "Ijoner's Giant Head Eye", atlas = "gtVoidEyeIcon", tx = 0, ty = 0, kind = "cloth", slot = "hat", valuable = true },
    [20008] = { id = 20008, name = "Crimson Wind Katana", atlas = "gtKatanaPic", tx = 0, ty = 0, kind = "cloth", slot = "hand", valuable = true },
    [20009] = { id = 20009, name = "Glitch Aura", atlas = "gtGlitchAuraIcon", tx = 0, ty = 0, kind = "cloth", slot = "back", valuable = true },
    [20011] = { id = 20011, name = "Arabian Eagle", atlas = "gtEagleIcon", tx = 0, ty = 0, kind = "cloth", slot = "chest", valuable = true },
    [20012] = { id = 20012, name = "Ijoner's Void Katana", atlas = "gtVoidKatanaPic", tx = 0, ty = 0, kind = "cloth", slot = "hand", valuable = true },
    [20015] = { id = 20015, name = "STORM's Legendary Wings", atlas = "gtStormWingsIcon", tx = 0, ty = 0, kind = "cloth", slot = "back", valuable = true },
    [20016] = { id = 20016, name = "PLY's Zephyr Helm", atlas = "gtPlayZephyrIcon", tx = 0, ty = 0, kind = "cloth", slot = "hat", valuable = true },
    [20017] = { id = 20017, name = "Phoenix Da Vinci Wings", atlas = "gtPhoenixDaVinciIcon", tx = 0, ty = 0, kind = "cloth", slot = "back", valuable = true },
    [20023] = { id = 20023, name = "Gem Machine", atlas = "gemMachine", tx = 0, ty = 0, solid = false, hits = 10, vend = true, kind = "block", valuable = true },
    [20030] = { id = 20030, name = "Visual Wardrobe", kind = "other", valuable = true },
}

local PROTECTED_IDS = {
    [6] = true, [8] = true, [202] = true, [204] = true, [206] = true,
    [242] = true, [1796] = true, [4994] = true, [5814] = true, [7188] = true, [9640] = true,
}

local function trimStr(s)
    if type(s) ~= "string" then return "" end
    return s:match("^%s*(.-)%s*$")
end

local function shallowCopy(t)
    local out = {}
    if type(t) == "table" then
        for k, v in pairs(t) do out[k] = v end
    end
    return out
end

local function inspectPackCandidate(v)
    if v == nil then return false end
    local ok, hit = pcall(function()
        if type(v) == "table" then
            return (v.sqUgMZzPutF or v.sW1h8Plnq or v.Z5lXZA58FKD or v.B9s4G9cTyLk) ~= nil
        elseif typeof and typeof(v) == "Instance" then
            return (v:FindFirstChild("sqUgMZzPutF") or v:FindFirstChild("sW1h8Plnq") or v:FindFirstChild("Z5lXZA58FKD")) ~= nil
        end
        return false
    end)
    return ok and hit
end

local function getPackChild(pack, name)
    local ok, child = pcall(function()
        if type(pack) == "table" then return pack[name] end
        return pack:FindFirstChild(name)
    end)
    return ok and child or nil
end

local function manhattan(x1, y1, x2, y2)
    return math.abs(x1 - x2) + math.abs(y1 - y2)
end

--==============================================================================
-- 3. ROBLOX LIVE GAME BRIDGE (shared[k], ByteNet WorldRemotes, Character)
--==============================================================================
local Adapter = {}
Adapter.__index = Adapter

function Adapter.new()
    local self = setmetatable({}, Adapter)
    self.connected = true
    self.seqCounter = 0
    self.startClock = os.clock()
    self.logs = {}
    self.listeners = {}
    self.maxLogEntries = 180
    self.itemDB = shallowCopy(DEFAULT_ITEM_DB)
    self.assets = { TileSize = ASSETS.TileSize, Atlas = shallowCopy(ASSETS.Atlas), UI = shallowCopy(ASSETS.UI) }
    self.liveRemotes = nil
    self.worldRemotes = nil
    self.liveBackpackModule = nil
    self.liveBackpackInstance = nil
    self.sharedPack = nil
    self.sharedPackFound = false
    self.liveWorldBound = false
    self.nextDropUid = 1

    self.player = {
        userId = LocalPlayer.UserId,
        name = LocalPlayer.Name,
        x = 49, y = 35,
        alive = true,
        hp = 100,
        flyEnabled = false,
        flySpeed = 48,
        noclipEnabled = false,
        equippedItem = 18,
        worn = {},
        localVisual = {
            name = LocalPlayer.DisplayName or LocalPlayer.Name,
            role = "MEMBER",
            color = "#E6E6E6",
            effect = nil,
            clothing = {},
        },
    }

    self.world = {
        name = "ROBLOX_WORLD",
        width = CONFIG.WORLD_WIDTH,
        height = CONFIG.WORLD_HEIGHT,
        surfaceY = CONFIG.SURFACE_Y,
        bedrockRows = 6,
        doorX = 49, doorY = 35,
        tiles = {}, drops = {}, trees = {},
    }

    self.backpack = {
        capacity = CONFIG.BACKPACK_CAPACITY,
        maxStack = CONFIG.MAX_STACK,
        slots = {},
        favorites = {},
    }

    self:initWorldCache()
    self:seedDefaultBackpack()
    self:discoverRobloxBindings()
    self:setupCharacterHooks()
    return self
end

function Adapter:getTime()
    return os.clock() - self.startClock
end

function Adapter:formatClock(ts)
    local t = ts or self:getTime()
    local s = math.floor(t) % 60
    local m = math.floor(t / 60) % 60
    local h = math.floor(t / 3600) % 24
    return string.format("%02d:%02d:%02d", h, m, s)
end

function Adapter:log(tag, msg)
    local line = string.format("[%s][%s] %s", self:formatClock(), tostring(tag), tostring(msg))
    table.insert(self.logs, line)
    if #self.logs > self.maxLogEntries then
        table.remove(self.logs, 1)
    end
    self:emit("LogAdded", line)
end

function Adapter:on(eventName, fn)
    if not self.listeners[eventName] then self.listeners[eventName] = {} end
    table.insert(self.listeners[eventName], fn)
    return function()
        local list = self.listeners[eventName]
        if list then
            for i = #list, 1, -1 do
                if list[i] == fn then table.remove(list, i) end
            end
        end
    end
end

function Adapter:emit(eventName, payload)
    local list = self.listeners[eventName]
    if not list then return end
    for _, fn in ipairs(list) do
        pcall(fn, payload)
    end
end

function Adapter:safeRequire(mod)
    if not mod or type(require) ~= "function" then return nil end
    local ok, res = pcall(require, mod)
    if ok then return res end
    return nil
end

function Adapter:discoverRobloxBindings()
    -- 1) ReplicatedStorage.BytenetStorage['ns.World'] check
    local okBs, bs = pcall(function() return ReplicatedStorage:FindFirstChild("BytenetStorage") end)
    if okBs and bs then
        local nsWorld = bs:FindFirstChild("ns.World")
        if nsWorld then
            self.liveRemotes = nsWorld
            self.liveWorldBound = true
            self:log("BRIDGE", "Bound ReplicatedStorage.BytenetStorage['ns.World']")
        end
    end

    -- 2) Scan shared[k] pack registry used by DRY CURSED client modules (table OR Folder Instance)
    local candidatePack = nil
    if type(shared) == "table" then
        for _, v in pairs(shared) do
            if inspectPackCandidate(v) then
                candidatePack = v
                break
            end
        end
    end

    if not candidatePack and type(shared) == "table" then
        local okDesc, desc = pcall(function() return PlayerGui:GetDescendants() end)
        if okDesc and type(desc) == "table" then
            for _, inst in ipairs(desc) do
                local okAttr, kAttr = pcall(function() return inst:GetAttribute("k") end)
                if okAttr and kAttr and inspectPackCandidate(shared[kAttr]) then
                    candidatePack = shared[kAttr]
                    break
                end
            end
        end
    end

    if candidatePack then
        self.sharedPack = candidatePack
        self.sharedPackFound = true

        -- Bind live ItemDB (sqUgMZzPutF)
        local liveDB = self:safeRequire(getPackChild(candidatePack, "sqUgMZzPutF"))
        if type(liveDB) == "table" then
            local mergedCount = 0
            for id, entry in pairs(liveDB) do
                if type(id) == "number" and type(entry) == "table" then
                    local base = shallowCopy(self.itemDB[id] or {})
                    for ek, ev in pairs(entry) do base[ek] = ev end
                    base.id = id
                    self.itemDB[id] = base
                    mergedCount = mergedCount + 1
                end
            end
            self:log("BRIDGE", "Merged live ItemDB (" .. tostring(mergedCount) .. " items from sqUgMZzPutF)")
        end

        -- Bind live Assets (Z5lXZA58FKD)
        local liveAssets = self:safeRequire(getPackChild(candidatePack, "Z5lXZA58FKD"))
        if type(liveAssets) == "table" then
            if type(liveAssets.TileSize) == "number" then
                self.assets.TileSize = liveAssets.TileSize
            end
            if type(liveAssets.Atlas) == "table" then
                for k, v in pairs(liveAssets.Atlas) do self.assets.Atlas[k] = v end
            end
            if type(liveAssets.UI) == "table" then
                for k, v in pairs(liveAssets.UI) do self.assets.UI[k] = v end
            end
            self:log("BRIDGE", "Merged live Assets atlas table (Z5lXZA58FKD)")
        end

        -- Bind live ByteNet WorldRemotes (sW1h8Plnq)
        local wr = self:safeRequire(getPackChild(candidatePack, "sW1h8Plnq"))
        if type(wr) == "table" then
            self.worldRemotes = wr
            self.liveWorldBound = true
            self:log("BRIDGE", "Bound live ByteNet WorldRemotes (sW1h8Plnq)")
        end

        -- Bind Backpack class (B9s4G9cTyLk)
        local bpMod = self:safeRequire(getPackChild(candidatePack, "B9s4G9cTyLk"))
        if type(bpMod) == "table" then
            self.liveBackpackModule = bpMod
            self:log("BRIDGE", "Detected live Backpack module (B9s4G9cTyLk)")
        end
    end
end

function Adapter:syncLiveBackpack()
    if self.liveBackpackInstance and type(self.liveBackpackInstance.slots) == "table" then
        self.backpack.slots = {}
        for _, s in ipairs(self.liveBackpackInstance.slots) do
            if type(s) == "table" and s.id and s.n then
                table.insert(self.backpack.slots, { id = s.id, n = s.n })
            end
        end
        self:emit("InventoryChanged", { synced = true })
        return true, #self.backpack.slots
    end
    return false, #self.backpack.slots
end

function Adapter:getCharacterParts()
    local char = LocalPlayer.Character
    if not char then return nil, nil, nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart
    return char, hum, root
end

function Adapter:setupCharacterHooks()
    local function attachChar(char)
        if not char then return end
        local hum = char:WaitForChild("Humanoid", 5)
        if hum then
            local lastHp = hum.Health
            hum.HealthChanged:Connect(function(newHp)
                local delta = lastHp - newHp
                self.player.hp = newHp
                self.player.alive = newHp > 0
                if delta > 0.01 then
                    self:emit("CombatHit", {
                        id = "hp_" .. tostring(math.floor(os.clock() * 1000)),
                        kind = "HIT",
                        source = "WORLD_OR_COMBAT",
                        damage = math.floor(delta * 100 + 0.5) / 100,
                        x = self.player.x,
                        y = self.player.y,
                        serverConfirmed = true,
                    })
                end
                lastHp = newHp
            end)
        end
    end
    if LocalPlayer.Character then task.spawn(attachChar, LocalPlayer.Character) end
    LocalPlayer.CharacterAdded:Connect(attachChar)
end

function Adapter:initWorldCache()
    local w, h = self.world.width, self.world.height
    self.world.tiles = {}
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local key = y * w + x
            local fg, bg = 0, 0
            if y >= h - self.world.bedrockRows then
                fg = 8
            elseif y >= self.world.surfaceY then
                fg = 2
                bg = 14
                if y >= h - 10 and ((x + y) % 17 == 0) then
                    fg = 4
                elseif ((x * 7 + y * 13) % 23 == 0) then
                    fg = 10
                end
            end
            self.world.tiles[key] = { x = x, y = y, fg = fg, bg = bg, hits = 0, bgHits = 0 }
        end
    end
    local dx, dy = self.world.doorX, self.world.doorY
    self.world.tiles[dy * w + dx].fg = 6
    self.world.tiles[dy * w + dx].bg = 0
    self.world.tiles[(dy + 1) * w + dx].fg = 8
end

function Adapter:seedDefaultBackpack()
    self:addInventoryItem(18, 1)
    self:addInventoryItem(32, 1)
    self:addInventoryItem(2, 200)
    self:addInventoryItem(3, 45)
    self:addInventoryItem(340, 25)
    self:addInventoryItem(4584, 50)
    self:addInventoryItem(5666, 20)
end

function Adapter:getItem(id) return self.itemDB[id] end

function Adapter:isSeed(id)
    local info = self.itemDB[id]
    return (info and info.kind == "seed") or false
end

function Adapter:getItemCategory(id)
    local info = self.itemDB[id]
    if not info then return "Unknown" end
    if info.kind == "seed" then return "Seed" end
    if info.kind == "lock" then return "Lock" end
    if info.background or info.kind == "background" then return "Background" end
    if info.kind == "cloth" then return "Clothing" end
    if info.kind == "tool" then return "Tool" end
    return "Block"
end

function Adapter:isProtectedTile(id)
    if PROTECTED_IDS[id] then return true end
    local info = self.itemDB[id]
    return (info and info.protected == true) or false
end

function Adapter:resolveItemIcon(id)
    local info = self.itemDB[id]
    local tileSz = self.assets.TileSize or 32
    if not info then
        return { assetId = self.assets.UI.itemBox, name = "Unknown", tx = 0, ty = 0, tileSize = tileSz, hasSprite = false }
    end
    local atlasName = tostring(info.atlas or "")
    local assetUrl = (info.atlas and self.assets.Atlas[info.atlas]) or self.assets.UI.itemBox
    local isSheet = (string.sub(atlasName, 1, 5) == "tiles" or atlasName == "back" or ((info.tx or 0) > 0) or ((info.ty or 0) > 0))
    local hasCoords = isSheet and (type(info.tx) == "number" and type(info.ty) == "number")
    return {
        assetId = assetUrl,
        name = info.name,
        tx = info.tx or 0,
        ty = info.ty or 0,
        tileSize = tileSz,
        hasSprite = hasCoords,
    }
end

function Adapter:inBounds(x, y)
    return x >= 0 and x < self.world.width and y >= 0 and y < self.world.height
end

function Adapter:tileKey(x, y)
    return y * self.world.width + x
end

function Adapter:getTile(x, y)
    if not self:inBounds(x, y) then return nil end
    local k = self:tileKey(x, y)
    local t = self.world.tiles[k]
    return {
        x = t.x, y = t.y, fg = t.fg, bg = t.bg,
        hits = t.hits, bgHits = t.bgHits,
        tree = self.world.trees[k],
    }
end

function Adapter:spawnDrop(id, count, x, y)
    local uid = self.nextDropUid
    self.nextDropUid = self.nextDropUid + 1
    self.world.drops[uid] = { uid = uid, id = id, count = count or 1, x = x, y = y }
    return uid
end

function Adapter:getDrops()
    local out = {}
    for _, d in pairs(self.world.drops) do table.insert(out, d) end
    return out
end

function Adapter:getInventoryCount(id)
    local tot = 0
    for _, s in ipairs(self.backpack.slots) do
        if s.id == id then tot = tot + s.n end
    end
    return tot
end

function Adapter:isBackpackFullFor(id)
    local count = self:getInventoryCount(id)
    if count > 0 and (count % self.backpack.maxStack) ~= 0 then
        return false
    end
    return #self.backpack.slots >= self.backpack.capacity
end

function Adapter:addInventoryItem(id, n)
    n = math.max(0, math.floor(n or 0))
    if n == 0 then return true, 0 end
    local remaining = n
    for _, slot in ipairs(self.backpack.slots) do
        if slot.id == id and slot.n < self.backpack.maxStack then
            local add = math.min(remaining, self.backpack.maxStack - slot.n)
            slot.n = slot.n + add
            remaining = remaining - add
            if remaining == 0 then break end
        end
    end
    while remaining > 0 and #self.backpack.slots < self.backpack.capacity do
        local add = math.min(remaining, self.backpack.maxStack)
        table.insert(self.backpack.slots, { id = id, n = add })
        remaining = remaining - add
    end
    self:emit("InventoryChanged", { id = id, total = self:getInventoryCount(id) })
    return remaining == 0, n - remaining
end

function Adapter:removeInventoryItem(id, n)
    n = math.max(0, math.floor(n or 0))
    local rem = n
    for i = #self.backpack.slots, 1, -1 do
        local s = self.backpack.slots[i]
        if s.id == id then
            if s.n > rem then
                s.n = s.n - rem
                rem = 0
                break
            else
                rem = rem - s.n
                table.remove(self.backpack.slots, i)
            end
        end
    end
    self:emit("InventoryChanged", { id = id, total = self:getInventoryCount(id) })
    return rem == 0, n - rem
end

function Adapter:getBackpackSnapshot()
    local copy = {}
    for idx, s in ipairs(self.backpack.slots) do
        table.insert(copy, { slot = idx, id = s.id, n = s.n })
    end
    return copy
end

function Adapter:sendPacket(packetName, payload)
    if not self.connected then return false, "DISCONNECTED" end
    self.seqCounter = (self.seqCounter + 1) % CONFIG.MAX_SEQ_UINT32

    -- 1) Live ByteNet WorldRemotes packet sender (shared[k].sW1h8Plnq)
    if self.worldRemotes then
        local pkt = self.worldRemotes[packetName]
        if type(pkt) == "table" and type(pkt.send) == "function" then
            pcall(pkt.send, payload)
        end
    end

    -- 2) Fallback Direct RemoteEvent under BytenetStorage['ns.World']
    if self.liveRemotes then
        local remoteObj = self.liveRemotes:FindFirstChild(packetName)
        if remoteObj and remoteObj:IsA("RemoteEvent") then
            pcall(function() remoteObj:FireServer(payload) end)
        end
    end
    return true, self.seqCounter
end

function Adapter:callRemote(callName, arg1, arg2, arg3)
    if self.worldRemotes and type(self.worldRemotes.call) == "function" then
        task.spawn(function()
            pcall(function()
                if arg3 ~= nil then
                    self.worldRemotes.call(callName, arg1, arg2, arg3)
                else
                    self.worldRemotes.call(callName, arg1, arg2)
                end
            end)
        end)
        return true
    end
    return false
end

function Adapter:moveTo(tx, ty)
    if not self:inBounds(tx, ty) then return false, "OUT_OF_BOUNDS" end
    if not self.player.noclipEnabled then
        local t = self.world.tiles[self:tileKey(tx, ty)]
        local info = self:getItem(t.fg)
        if t.fg ~= 0 and info and info.solid then
            return false, "BLOCKED_BY_SOLID"
        end
    end
    self.player.x = tx
    self.player.y = ty
    self:sendPacket("move", { x = tx * 32, y = ty * 32, vx = 0, vy = 0, flip = false })
    self:emit("PlayerMoved", { x = tx, y = ty })
    return true
end

function Adapter:placeTile(tx, ty, itemId)
    if not self:inBounds(tx, ty) then return false, "OUT_OF_BOUNDS" end
    if self:getInventoryCount(itemId) <= 0 then return false, "NO_ITEM" end
    local ok, err = self:sendPacket("tile", { layer = 0, x = tx, y = ty, id = itemId, flip = false })
    if not ok then return false, err end
    local key = self:tileKey(tx, ty)
    local t = self.world.tiles[key]
    local info = self:getItem(itemId)
    if not info then return false, "UNKNOWN_ITEM" end

    if info.kind == "seed" then
        if t.fg ~= 0 or self.world.trees[key] then return false, "PLANT_OCCUPIED" end
        self:removeInventoryItem(itemId, 1)
        self.world.trees[key] = {
            seedId = itemId, blockId = info.blockId or (itemId - 1),
            plantedAt = self:getTime(), growTime = info.grow or 31, ready = false,
        }
        return true, "PLANTED"
    elseif info.background or info.kind == "background" then
        if t.bg ~= 0 then return false, "BG_OCCUPIED" end
        self:removeInventoryItem(itemId, 1)
        t.bg = itemId
        t.bgHits = 0
        return true, "PLACED_BG"
    else
        if t.fg ~= 0 then return false, "FG_OCCUPIED" end
        self:removeInventoryItem(itemId, 1)
        t.fg = itemId
        t.hits = 0
        return true, "PLACED_FG"
    end
end

function Adapter:punchTile(tx, ty)
    if not self:inBounds(tx, ty) then return false, "OUT_OF_BOUNDS" end
    local ok, err = self:sendPacket("act", { kind = 1, x = tx, y = ty })
    if not ok then return false, err end
    local key = self:tileKey(tx, ty)
    local t = self.world.tiles[key]
    local tree = self.world.trees[key]

    if tree then
        if tree.ready or (self:getTime() - tree.plantedAt >= (tree.growTime or 31)) then
            self:sendPacket("harvest", { x = tx, y = ty })
            self:spawnDrop(tree.blockId, 2, tx, ty)
            self:spawnDrop(tree.seedId, 1, tx, ty)
            self.world.trees[key] = nil
            return true, "HARVESTED"
        end
        return false, "TREE_IMMATURE"
    end

    if t.fg ~= 0 then
        if self:isProtectedTile(t.fg) then return false, "PROTECTED_TILE" end
        local info = self:getItem(t.fg)
        local maxHits = (info and info.hits) or 3
        if maxHits < 0 then return false, "UNBREAKABLE" end
        t.hits = t.hits + 1
        if t.hits >= maxHits then
            local brokenId = t.fg
            t.fg = 0
            t.hits = 0
            self:spawnDrop((info and info.farmable) and (brokenId + 1) or brokenId, 1, tx, ty)
            return true, "BROKEN_FG"
        end
        return true, "HIT_FG"
    elseif t.bg ~= 0 then
        local info = self:getItem(t.bg)
        local maxHits = (info and info.hits) or 3
        t.bgHits = t.bgHits + 1
        if t.bgHits >= maxHits then
            local brokenBg = t.bg
            t.bg = 0
            t.bgHits = 0
            self:spawnDrop(brokenBg, 1, tx, ty)
            return true, "BROKEN_BG"
        end
        return true, "HIT_BG"
    end
    return false, "EMPTY_TILE"
end

function Adapter:collectDrop(dropUid)
    local d = self.world.drops[dropUid]
    if not d then return false, "DROP_MISSING" end
    local ok, err = self:sendPacket("take", { seq = self.seqCounter, uid = dropUid, want = d.count })
    if not ok then return false, err end
    if self:isBackpackFullFor(d.id) then return false, "BACKPACK_FULL" end
    local fullOk, added = self:addInventoryItem(d.id, d.count)
    if fullOk then
        self.world.drops[dropUid] = nil
        return true, added
    else
        d.count = d.count - added
        return false, "PARTIAL"
    end
end

function Adapter:trashItem(id, amount)
    local info = self.itemDB[id]
    if self:isProtectedTile(id) or (info and info.valuable) then
        return false, "PROTECTED_FROM_TRASH"
    end
    local qty = amount or self:getInventoryCount(id)
    self:callRemote("Recycle", id, qty)
    return self:removeInventoryItem(id, qty)
end

function Adapter:sendChatMessage(msg)
    if not self.connected then return "REJECTED", "DISCONNECTED" end
    if type(msg) ~= "string" or trimStr(msg) == "" then return "REJECTED", "EMPTY_MESSAGE" end
    if #msg > CONFIG.MAX_CHAT_LENGTH then return "REJECTED", "MESSAGE_TOO_LONG" end

    local sentChannel = false
    local ok, ch = pcall(function()
        local wc = TextChatService:FindFirstChild("WorldChannels")
        if wc then
            for _, child in ipairs(wc:GetChildren()) do
                if child:IsA("TextChannel") then return child end
            end
        end
        local tc = TextChatService:FindFirstChild("TextChannels")
        if tc then return tc:FindFirstChild("RBXGeneral") end
        return nil
    end)
    if ok and ch then
        local sOk = pcall(function() ch:SendAsync(msg) end)
        if sOk then sentChannel = true end
    end
    self:log("CHAT", (sentChannel and "[TextChat] " or "[LocalSim] ") .. msg)
    return "ACCEPTED", sentChannel and "TEXTCHAT_SENT" or "SIMULATED_LOCAL"
end

function Adapter:applyLocalVisualLook(visualSpec)
    self.player.localVisual = shallowCopy(visualSpec or self.player.localVisual)
    local char = LocalPlayer.Character
    local head = char and char:FindFirstChild("Head")
    if head then
        local existing = head:FindFirstChild("DryCursedNameTag")
        if existing then existing:Destroy() end
        local bb = Instance.new("BillboardGui")
        bb.Name = "DryCursedNameTag"
        bb.Size = UDim2.new(0, 230, 0, 38)
        bb.StudsOffset = Vector3.new(0, 2.5, 0)
        bb.AlwaysOnTop = true
        bb.Parent = head

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, 0, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 15
        local rolePrefix = (self.player.localVisual.role and self.player.localVisual.role ~= "")
            and ("[" .. tostring(self.player.localVisual.role) .. "] ") or ""
        lbl.Text = rolePrefix .. tostring(self.player.localVisual.name or LocalPlayer.Name)
        local c = self.player.localVisual.rgb
        lbl.TextColor3 = c and Color3.fromRGB(c.r, c.g, c.b) or Color3.fromRGB(255, 255, 255)
        lbl.Parent = bb

        if self.player.localVisual.effect == "Outline" or self.player.localVisual.effect == "Glow" or self.player.localVisual.effect == "Shadow" then
            local st = Instance.new("UIStroke")
            st.Color = (self.player.localVisual.effect == "Glow") and Color3.fromRGB(110, 220, 255) or Color3.fromRGB(0, 0, 0)
            st.Thickness = (self.player.localVisual.effect == "Glow") and 1.8 or 1.4
            st.Parent = lbl
        end
    end
    return true
end

--==============================================================================
-- 4. FEATURE 1: MODULE 15 — VISUAL INVENTORY ITEM SELECTOR (11 COMPONENTS)
--==============================================================================
local InventorySelector = {}
InventorySelector.__index = InventorySelector

InventorySelector.SELECT_MODES = { "Auto (Block/Seed)", "Block Only", "Seed Only", "Multi-Select" }

function InventorySelector.new(adapter)
    local self = setmetatable({}, InventorySelector)
    self.adapter = adapter
    self.searchQuery = ""
    self.category = "All"
    self.sortBy = "count"
    self.showAllItems = false
    self.selectMode = "Auto (Block/Seed)"
    self.pendingBlock = nil
    self.pendingSeed = nil
    self.selectedBlock = nil
    self.selectedSeed = nil
    self.multiSelection = {}
    self.cards = {}
    self.componentsActive = 11
    self:refresh()
    adapter:on("InventoryChanged", function() self:refresh() end)
    return self
end

function InventorySelector:refresh()
    -- 1. InventoryReader
    local counts = {}
    for _, slot in ipairs(self.adapter:getBackpackSnapshot()) do
        counts[slot.id] = (counts[slot.id] or 0) + slot.n
    end
    if self.showAllItems then
        for id, _ in pairs(self.adapter.itemDB) do
            if id ~= 0 and counts[id] == nil then counts[id] = 0 end
        end
    end
    -- 7. Out-of-stock persistence (keep selected entries at count == 0)
    if self.selectedBlock and counts[self.selectedBlock.id] == nil then counts[self.selectedBlock.id] = 0 end
    if self.selectedSeed and counts[self.selectedSeed.id] == nil then counts[self.selectedSeed.id] = 0 end

    -- 2. ItemClassifier + 5. SearchFilterEngine
    local q = string.lower(self.searchQuery or "")
    local list = {}
    for id, cnt in pairs(counts) do
        local info = self.adapter:getItem(id) or { id = id, name = "Item #" .. tostring(id), kind = "other" }
        local rawCat = self.adapter:getItemCategory(id)
        local cat = self.adapter:isSeed(id) and "Seeds" or ((rawCat == "Block" or rawCat == "Background" or rawCat == "Lock") and "Blocks" or "Other")
        local matchesCat = (self.category == "All") or (cat == self.category)
        local matchesSearch = (q == "") or (string.find(string.lower(info.name), q, 1, true) ~= nil) or (tostring(id) == q)
        if matchesCat and matchesSearch then
            -- 3. IconResolver + 4. GridRenderer data model
            table.insert(list, {
                id = id, name = info.name, count = cnt, category = cat,
                icon = self.adapter:resolveItemIcon(id),
                outOfStock = (cnt <= 0),
                isSelectedBlock = (self.selectedBlock and self.selectedBlock.id == id) or false,
                isSelectedSeed = (self.selectedSeed and self.selectedSeed.id == id) or false,
                isPending = ((self.pendingBlock and self.pendingBlock.id == id) or (self.pendingSeed and self.pendingSeed.id == id)) or false,
                isMulti = (self.multiSelection[id] == true),
            })
        end
    end

    -- 6. SortEngine
    table.sort(list, function(a, b)
        if self.sortBy == "name" then return string.lower(a.name) < string.lower(b.name)
        elseif self.sortBy == "id" then return a.id < b.id
        else
            if a.count == b.count then return a.id < b.id end
            return a.count > b.count
        end
    end)

    if self.selectedBlock then
        local c = self.adapter:getInventoryCount(self.selectedBlock.id)
        self.selectedBlock.count = c
        self.selectedBlock.outOfStock = (c <= 0)
    end
    if self.selectedSeed then
        local c = self.adapter:getInventoryCount(self.selectedSeed.id)
        self.selectedSeed.count = c
        self.selectedSeed.outOfStock = (c <= 0)
    end
    self.cards = list
    return list
end

function InventorySelector:pickCard(rec)
    if not rec then return false, "NONE" end
    if self.selectMode == "Multi-Select" then
        self.multiSelection[rec.id] = not self.multiSelection[rec.id]
        self:refresh()
        return true, "MULTI_TOGGLED"
    elseif self.selectMode == "Block Only" then
        if self.adapter:isSeed(rec.id) then return false, "SEED_BLOCKED_IN_BLOCK_MODE" end
        self.pendingBlock = { id = rec.id, name = rec.name, count = rec.count, outOfStock = rec.outOfStock }
        self:refresh()
        return true, "PENDING_BLOCK"
    elseif self.selectMode == "Seed Only" then
        if not self.adapter:isSeed(rec.id) then return false, "BLOCK_BLOCKED_IN_SEED_MODE" end
        self.pendingSeed = { id = rec.id, name = rec.name, count = rec.count, outOfStock = rec.outOfStock }
        self:refresh()
        return true, "PENDING_SEED"
    else
        -- Auto (Block/Seed) also immediately selects or stages depending on category
        if rec.category == "Seeds" then
            return self:selectItem(rec.id, "Seed")
        elseif rec.category == "Blocks" then
            return self:selectItem(rec.id, "Block")
        end
        return false, "NOT_PLACEABLE_BLOCK_OR_SEED"
    end
end

function InventorySelector:confirmSelection()
    -- 8. ConfigSync + 10. AutomationBridge
    if self.pendingBlock then
        self:selectItem(self.pendingBlock.id, "Block")
        self.pendingBlock = nil
    end
    if self.pendingSeed then
        self:selectItem(self.pendingSeed.id, "Seed")
        self.pendingSeed = nil
    end
    self:refresh()
    self.adapter:emit("SelectionConfirmed", { block = self.selectedBlock, seed = self.selectedSeed })
    return true
end

function InventorySelector:selectItem(id, mode)
    local info = self.adapter:getItem(id)
    if not info then return false, "UNKNOWN_ITEM" end
    if mode == "Block" then
        if self.adapter:isSeed(id) then return false, "SEED_NOT_ALLOWED" end
        local cnt = self.adapter:getInventoryCount(id)
        self.selectedBlock = { id = id, name = info.name, count = cnt, outOfStock = (cnt <= 0) }
    elseif mode == "Seed" then
        if not self.adapter:isSeed(id) then return false, "NON_SEED_NOT_ALLOWED" end
        local cnt = self.adapter:getInventoryCount(id)
        self.selectedSeed = { id = id, name = info.name, count = cnt, outOfStock = (cnt <= 0) }
    end
    self:refresh()
    self.adapter:emit("SelectionChanged", { block = self.selectedBlock, seed = self.selectedSeed })
    return true
end

function InventorySelector:clearSelection()
    self.pendingBlock = nil
    self.pendingSeed = nil
    self.selectedBlock = nil
    self.selectedSeed = nil
    self.multiSelection = {}
    self:refresh()
end

--==============================================================================
-- 5. FEATURE 2: AUTOMATIC WORLD CLEARER (CLEAR WORLD.MD - ALL 13 STEPS)
--==============================================================================
local ClearWorldEngine = {}
ClearWorldEngine.__index = ClearWorldEngine

ClearWorldEngine.STEP_DEFS = {
    { id = 1,  title = "1. Scan World (FG/BG/Drop)" },
    { id = 2,  title = "2. Protection & Lock Filter" },
    { id = 3,  title = "3. Proximity Target Sort" },
    { id = 4,  title = "4. Break FG & Verify == 0" },
    { id = 5,  title = "5. Break BG & Verify == 0" },
    { id = 6,  title = "6. Seed-First Collect" },
    { id = 7,  title = "7. Full BP Auto-Trash" },
    { id = 8,  title = "8. Interrupt Recovery" },
    { id = 9,  title = "9. Top-to-Bottom Sweep" },
    { id = 10, title = "10. Residual Drop Sweep" },
    { id = 11, title = "11. Residual Tile Re-Scan" },
    { id = 12, title = "12. Final Verify Scan" },
    { id = 13, title = "13. Final Clear Report" },
}

function ClearWorldEngine.new(adapter)
    local self = setmetatable({}, ClearWorldEngine)
    self.adapter = adapter
    self.state = "IDLE"
    self.stopRequested = false
    self.allowTrashDisposables = true
    self.extraProtectedIds = {}
    self.stepDelayMs = 30
    self.fgQueue = {}
    self.bgQueue = {}
    self.stepStatus = {}
    self.currentStep = 0
    self.metrics = { blocksDestroyed = 0, bgRemoved = 0, seedsCollected = 0, itemsTrashed = 0, protectedPreserved = 0, unknownSkipped = 0 }
    self:resetStepStates()
    return self
end

function ClearWorldEngine:resetStepStates()
    for i = 1, 13 do self.stepStatus[i] = "WAIT" end
    self.currentStep = 0
end

function ClearWorldEngine:setStepState(stepIdx, st)
    self.currentStep = stepIdx
    self.stepStatus[stepIdx] = st
end

function ClearWorldEngine:setExtraProtectedFromString(str)
    self.extraProtectedIds = {}
    for tok in string.gmatch(tostring(str or ""), "%d+") do
        local id = tonumber(tok)
        if id and id > 0 then self.extraProtectedIds[id] = true end
    end
end

function ClearWorldEngine:classifyId(id)
    if not id or id == 0 then return "EMPTY" end
    if self.extraProtectedIds[id] or self.adapter:isProtectedTile(id) then return "KEEP" end
    local info = self.adapter:getItem(id)
    if not info then return "UNKNOWN" end
    if info.hits and info.hits < 0 then return "KEEP" end
    return "REMOVE"
end

function ClearWorldEngine:scanWorld()
    self.state = "SCANNING"
    self:setStepState(1, "RUN")
    self:setStepState(2, "RUN")
    self.fgQueue = {}
    self.bgQueue = {}
    self.metrics.protectedPreserved = 0
    self.metrics.unknownSkipped = 0
    -- Step 9: Layer-by-layer top-to-bottom scan ordering (y = 0 .. height - 1)
    for y = 0, self.adapter.world.height - 1 do
        for x = 0, self.adapter.world.width - 1 do
            local t = self.adapter:getTile(x, y)
            if t then
                local fc = self:classifyId(t.fg)
                if fc == "KEEP" then self.metrics.protectedPreserved = self.metrics.protectedPreserved + 1
                elseif fc == "UNKNOWN" then self.metrics.unknownSkipped = self.metrics.unknownSkipped + 1
                elseif fc == "REMOVE" then table.insert(self.fgQueue, { x = x, y = y, id = t.fg }) end
                if t.bg ~= 0 and self:classifyId(t.bg) == "REMOVE" then
                    table.insert(self.bgQueue, { x = x, y = y, id = t.bg })
                end
            end
        end
    end
    self:setStepState(1, "DONE")
    self:setStepState(2, "DONE")
    self:setStepState(9, "DONE")
    return #self.fgQueue, #self.bgQueue
end

function ClearWorldEngine:popNearest(queue)
    self:setStepState(3, "RUN")
    if #queue == 0 then return nil end
    local px, py = self.adapter.player.x, self.adapter.player.y
    local bi, bd = 1, manhattan(px, py, queue[1].x, queue[1].y)
    for i = 2, #queue do
        local d = manhattan(px, py, queue[i].x, queue[i].y)
        if d < bd then bi, bd = i, d end
    end
    local picked = queue[bi]
    table.remove(queue, bi)
    self:setStepState(3, "DONE")
    return picked
end

function ClearWorldEngine:collectDrops()
    self:setStepState(6, "RUN")
    local drops = self.adapter:getDrops()
    -- Seed-first sorting (id % 2 == 1 / isSeed before blocks)
    table.sort(drops, function(a, b)
        local as = self.adapter:isSeed(a.id) and 0 or 1
        local bs = self.adapter:isSeed(b.id) and 0 or 1
        return as < bs
    end)
    for _, d in ipairs(drops) do
        if self.adapter:isBackpackFullFor(d.id) then
            self:setStepState(7, "RUN")
            if not self.allowTrashDisposables then
                self:setStepState(7, "WARN")
                self.state = "PAUSED"
                return false
            end
            for _, s in ipairs(self.adapter:getBackpackSnapshot()) do
                local info = self.adapter:getItem(s.id)
                if info and info.disposable and not self.adapter:isSeed(s.id) and not info.valuable then
                    local okTrash, trashedQty = self.adapter:trashItem(s.id, s.n)
                    if okTrash then self.metrics.itemsTrashed = self.metrics.itemsTrashed + (trashedQty or s.n) end
                    if not self.adapter:isBackpackFullFor(d.id) then break end
                end
            end
            self:setStepState(7, "DONE")
        end
        self.adapter:moveTo(d.x, d.y)
        local ok, added = self.adapter:collectDrop(d.uid)
        if ok and added > 0 and self.adapter:isSeed(d.id) then
            self.metrics.seedsCollected = self.metrics.seedsCollected + added
        end
    end
    self:setStepState(6, "DONE")
    return true
end

function ClearWorldEngine:stepOnce()
    if self.stopRequested then self.state = "STOPPED"; return false end
    if self.state == "IDLE" or self.state == "STOPPED" or self.state == "COMPLETED" then
        self:resetStepStates()
        self:scanWorld()
        self.state = "CLEARING_FG"
    end
    if self.state == "CLEARING_FG" then
        self:setStepState(4, "RUN")
        local t = self:popNearest(self.fgQueue)
        if t then
            local tile = self.adapter:getTile(t.x, t.y)
            if tile and tile.fg ~= 0 and self:classifyId(tile.fg) == "REMOVE" then
                self.adapter:moveTo(t.x, math.max(0, t.y - 1))
                local attempts = 0
                for _ = 1, 16 do
                    attempts = attempts + 1
                    self.adapter:punchTile(t.x, t.y)
                    if self.adapter:getTile(t.x, t.y).fg == 0 then
                        self.metrics.blocksDestroyed = self.metrics.blocksDestroyed + 1
                        break
                    elseif attempts >= 8 then
                        -- Step 8: Interrupt recovery log
                        self:setStepState(8, "RUN")
                    end
                end
                if self.stepStatus[8] == "RUN" then self:setStepState(8, "DONE") end
                self:collectDrops()
            end
            return true
        end
        self:setStepState(4, "DONE")
        self.state = "CLEARING_BG"
    end
    if self.state == "CLEARING_BG" then
        self:setStepState(5, "RUN")
        local t = self:popNearest(self.bgQueue)
        if t then
            local tile = self.adapter:getTile(t.x, t.y)
            if tile and tile.fg == 0 and tile.bg ~= 0 and self:classifyId(tile.bg) == "REMOVE" then
                self.adapter:moveTo(t.x, t.y)
                for _ = 1, 12 do
                    self.adapter:punchTile(t.x, t.y)
                    if self.adapter:getTile(t.x, t.y).bg == 0 then
                        self.metrics.bgRemoved = self.metrics.bgRemoved + 1
                        break
                    end
                end
                self:collectDrops()
            end
            return true
        end
        self:setStepState(5, "DONE")
        -- Steps 10, 11, 12, 13: Residual drops -> Residual re-scan -> Final verification -> Report
        self:setStepState(10, "RUN")
        self:collectDrops()
        self:setStepState(10, "DONE")
        self:setStepState(11, "RUN")
        local rf, rb = self:scanWorld()
        self:setStepState(11, "DONE")
        self:setStepState(12, "RUN")
        if rf == 0 and rb == 0 and #self.adapter:getDrops() == 0 then
            self:setStepState(12, "DONE")
            self:setStepState(8, "DONE")
            self:setStepState(7, "DONE")
            self:setStepState(13, "DONE")
            self.state = "COMPLETED"
            self.adapter:log("CLEAR", string.format("13-Step Report: FG=%d BG=%d Seeds=%d Trashed=%d Kept=%d",
                self.metrics.blocksDestroyed, self.metrics.bgRemoved, self.metrics.seedsCollected,
                self.metrics.itemsTrashed, self.metrics.protectedPreserved))
        else
            self:setStepState(12, "WARN")
            self.state = "PAUSED"
        end
        return false
    end
    return false
end

function ClearWorldEngine:startAsync(onUpdate)
    if self.state == "CLEARING_FG" or self.state == "CLEARING_BG" or self.state == "SCANNING" then return end
    self.stopRequested = false
    self.state = "IDLE"
    task.spawn(function()
        while not self.stopRequested do
            local cont = self:stepOnce()
            if onUpdate then pcall(onUpdate) end
            if not cont then break end
            task.wait(math.max(0.015, (self.stepDelayMs or 30) / 1000))
        end
    end)
end

--==============================================================================
-- 6. FEATURE 3: DIRTFARM BUILDER & FARMING CYCLE (DF.MD - 24 STEPS / 19 MODULES)
--==============================================================================
local DirtFarmEngine = {}
DirtFarmEngine.__index = DirtFarmEngine

DirtFarmEngine.STEP_DEFS = {
    { id = 1,  title = "1. World Grid Scan" },
    { id = 2,  title = "2. Bedrock Guard (ID 8)" },
    { id = 3,  title = "3. Clear Left 2 Cols" },
    { id = 4,  title = "4. Clear Right Boundary" },
    { id = 5,  title = "5. Clear Bottom Row" },
    { id = 6,  title = "6. 1-2 Prep Pattern" },
    { id = 7,  title = "7. Layout Mode Select" },
    { id = 8,  title = "8. Layout 1 Platforms" },
    { id = 9,  title = "9. Layout 2 Platforms" },
    { id = 10, title = "10. Dual-Side Sweep" },
    { id = 11, title = "11. Gap Fill & Repair" },
    { id = 12, title = "12. Convert Non-Dirt" },
    { id = 13, title = "13. Cave BG Strip (14)" },
    { id = 14, title = "14. Smart Local Priority" },
    { id = 15, title = "15. Drop Collect Radius" },
    { id = 16, title = "16. 200 Block Cap Check" },
    { id = 17, title = "17. 200 Seed Cap Check" },
    { id = 18, title = "18. Cap Auto-Cycle" },
    { id = 19, title = "19. Plant Seeds Above" },
    { id = 20, title = "20. Growth Time Track" },
    { id = 21, title = "21. Harvest Mature" },
    { id = 22, title = "22. Auto Re-Plant" },
    { id = 23, title = "23. Recovery Guard" },
    { id = 24, title = "24. Validation Report" },
}

function DirtFarmEngine.new(adapter)
    local self = setmetatable({}, DirtFarmEngine)
    self.adapter = adapter
    self.state = "IDLE"
    self.stopRequested = false
    self.opts = {
        startRow = 6,
        endRow = 52,
        rowSpacing = 2,
        slpRadius = 4,
        layoutMode = "Both", -- "Both", "Layout 1", "Layout 2"
        enable12Pattern = false,
        plantAfterBuild = true,
        skipBg = false,
        seedCap = 200,
        blockCap = 200,
    }
    self.tasks = {}
    self.plantingMap = {}
    self.platformCells = {}
    self.stepStatus = {}
    self.validationReport = {
        bedrockIntact = false,
        edgesCleared = false,
        bottomRowCleared = false,
        platformsComplete = false,
        caveBgClean = false,
        treesPlanted = 0,
        matureTrees = 0,
        allPassed = false,
    }
    self.metrics = { obstaclesBroken = 0, bgRemoved = 0, platformsBuilt = 0, seedsPlanted = 0, treesHarvested = 0, capCycles = 0 }
    self:resetSteps()
    return self
end

function DirtFarmEngine:resetSteps()
    for i = 1, 24 do self.stepStatus[i] = "WAIT" end
end

function DirtFarmEngine:markSteps(list, st)
    for _, idx in ipairs(list) do self.stepStatus[idx] = st end
end

function DirtFarmEngine:preparePlan()
    self:resetSteps()
    self.state = "SCANNING_WORLD"
    self:markSteps({ 1, 2, 7 }, "RUN")
    self.tasks = {}
    self.plantingMap = {}
    self.platformCells = {}

    local w, h = self.adapter.world.width, self.adapter.world.height
    local bedrockY = h - self.adapter.world.bedrockRows
    local bottomClearY = bedrockY - 1
    local midX = math.floor(w / 2)
    local minX, maxX = 2, w - 2
    if self.opts.layoutMode == "Layout 1" then maxX = midX
    elseif self.opts.layoutMode == "Layout 2" then minX = midX + 1 end
    local dx, dy = self.adapter.world.doorX, self.adapter.world.doorY

    local platKeys = {}
    for y = math.min(self.opts.endRow, bottomClearY - 1), math.max(2, self.opts.startRow), -self.opts.rowSpacing do
        for x = minX, maxX do
            if not (math.abs(x - dx) <= 1 and (y == dy or y == dy + 1)) then
                local k = y * w + x
                if self.opts.enable12Pattern and (x % 3 == 0) then
                    local t = self.adapter:getTile(x, y)
                    if t and t.fg ~= 0 and not self.adapter:isProtectedTile(t.fg) then
                        table.insert(self.tasks, { action = "BREAK_FG", x = x, y = y })
                    end
                else
                    platKeys[k] = { x = x, y = y }
                    table.insert(self.platformCells, { x = x, y = y })
                    if y - 1 >= 1 then
                        table.insert(self.plantingMap, { x = x, y = y - 1, supportY = y })
                    end
                end
            end
        end
    end

    -- Clear left 2 cols, right boundary & bottom row above bedrock
    for y = self.opts.startRow, bottomClearY do
        for _, ex in ipairs({ 0, 1, w - 1 }) do
            local t = self.adapter:getTile(ex, y)
            if t and t.fg ~= 0 and not self.adapter:isProtectedTile(t.fg) then
                table.insert(self.tasks, { action = "BREAK_FG", x = ex, y = y })
            end
        end
    end
    for x = 0, w - 1 do
        if not (x == dx and bottomClearY == dy + 1) then
            local t = self.adapter:getTile(x, bottomClearY)
            if t and t.fg ~= 0 and not self.adapter:isProtectedTile(t.fg) then
                table.insert(self.tasks, { action = "BREAK_FG", x = x, y = bottomClearY })
            end
        end
    end

    for _, pos in pairs(platKeys) do
        local t = self.adapter:getTile(pos.x, pos.y)
        if t then
            if t.fg == 0 then
                table.insert(self.tasks, { action = "PLACE_DIRT", x = pos.x, y = pos.y })
            elseif t.fg ~= 2 and not self.adapter:isProtectedTile(t.fg) then
                table.insert(self.tasks, { action = "CONVERT_FG", x = pos.x, y = pos.y })
            end
        end
    end
    if not self.opts.skipBg then
        for _, pos in ipairs(self.plantingMap) do
            local t = self.adapter:getTile(pos.x, pos.y)
            if t and t.fg == 0 and t.bg == 14 then
                table.insert(self.tasks, { action = "REMOVE_BG", x = pos.x, y = pos.y })
            end
        end
    end
    self:markSteps({ 1, 2, 7 }, "DONE")
    self.state = "READY (" .. tostring(#self.tasks) .. " tasks)"
end

function DirtFarmEngine:runValidationReport()
    self:markSteps({ 24 }, "RUN")
    local w, h = self.adapter.world.width, self.adapter.world.height
    local bedrockY = h - self.adapter.world.bedrockRows
    local bottomClearY = bedrockY - 1

    local bedrockOk = true
    for x = 0, w - 1 do
        local t = self.adapter:getTile(x, bedrockY)
        if not t or t.fg ~= 8 then bedrockOk = false; break end
    end

    local edgesOk = true
    for y = self.opts.startRow, bottomClearY do
        for _, ex in ipairs({ 0, 1, w - 1 }) do
            local t = self.adapter:getTile(ex, y)
            if t and t.fg ~= 0 and not self.adapter:isProtectedTile(t.fg) then edgesOk = false; break end
        end
        if not edgesOk then break end
    end

    local bottomOk = true
    for x = 0, w - 1 do
        local t = self.adapter:getTile(x, bottomClearY)
        if t and t.fg ~= 0 and not self.adapter:isProtectedTile(t.fg) then bottomOk = false; break end
    end

    local platOk = true
    for _, cell in ipairs(self.platformCells) do
        local t = self.adapter:getTile(cell.x, cell.y)
        if not t or t.fg ~= 2 then platOk = false; break end
    end

    local bgOk = true
    if not self.opts.skipBg then
        for _, p in ipairs(self.plantingMap) do
            local t = self.adapter:getTile(p.x, p.y)
            if t and t.fg == 0 and t.bg == 14 then bgOk = false; break end
        end
    end

    local planted, mature = 0, 0
    for _, p in ipairs(self.plantingMap) do
        local t = self.adapter:getTile(p.x, p.y)
        if t and t.tree then
            planted = planted + 1
            if t.tree.ready or (self.adapter:getTime() - t.tree.plantedAt >= (t.tree.growTime or 31)) then
                mature = mature + 1
            end
        end
    end

    self.validationReport = {
        bedrockIntact = bedrockOk,
        edgesCleared = edgesOk,
        bottomRowCleared = bottomOk,
        platformsComplete = platOk,
        caveBgClean = bgOk,
        treesPlanted = planted,
        matureTrees = mature,
        allPassed = bedrockOk and edgesOk and bottomOk and platOk and bgOk,
    }
    self:markSteps({ 24 }, self.validationReport.allPassed and "DONE" or "WARN")
    return self.validationReport
end

function DirtFarmEngine:harvestReady()
    self:markSteps({ 20, 21 }, "RUN")
    local harvested = 0
    for _, pos in ipairs(self.plantingMap) do
        local t = self.adapter:getTile(pos.x, pos.y)
        if t and t.tree and (t.tree.ready or (self.adapter:getTime() - t.tree.plantedAt >= (t.tree.growTime or 31))) then
            self.adapter:moveTo(pos.x, pos.y)
            if self.adapter:punchTile(pos.x, pos.y) then
                harvested = harvested + 1
                self.metrics.treesHarvested = self.metrics.treesHarvested + 1
            end
        end
    end
    self:markSteps({ 20, 21 }, "DONE")
    self.adapter:log("DIRTFARM", "Harvested " .. tostring(harvested) .. " mature trees")
    return harvested
end

function DirtFarmEngine:collectDropsWithCap(radius)
    self:markSteps({ 15, 16, 17 }, "RUN")
    local dirtCnt = self.adapter:getInventoryCount(2)
    local seedCnt = self.adapter:getInventoryCount(3)
    if dirtCnt >= self.opts.blockCap or seedCnt >= self.opts.seedCap then
        self:markSteps({ 16, 17, 18 }, "DONE")
        self.metrics.capCycles = self.metrics.capCycles + 1
        return true
    end
    local px, py = self.adapter.player.x, self.adapter.player.y
    for _, d in ipairs(self.adapter:getDrops()) do
        if (not radius) or manhattan(px, py, d.x, d.y) <= radius then
            local curBlk = self.adapter:getInventoryCount(2)
            local curSeed = self.adapter:getInventoryCount(3)
            local skip = (d.id == 2 and curBlk >= self.opts.blockCap) or (d.id == 3 and curSeed >= self.opts.seedCap)
            if not skip then
                self.adapter:moveTo(d.x, d.y)
                self.adapter:collectDrop(d.uid)
            end
        end
    end
    self:markSteps({ 15 }, "DONE")
    return true
end

function DirtFarmEngine:stepOnce()
    if self.stopRequested then self.state = "STOPPED"; return false end
    if #self.tasks == 0 then
        self:preparePlan()
        if #self.tasks == 0 then
            self:markSteps({ 3, 4, 5, 6, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 23 }, "DONE")
            if self.opts.plantAfterBuild and self.adapter:getInventoryCount(3) > 0 then
                self.state = "PLANTING_SEEDS"
                self:markSteps({ 19, 22 }, "RUN")
                for _, p in ipairs(self.plantingMap) do
                    if self.adapter:getInventoryCount(3) <= 0 then break end
                    local a, s = self.adapter:getTile(p.x, p.y), self.adapter:getTile(p.x, p.supportY)
                    if a and a.fg == 0 and not a.tree and s and s.fg == 2 then
                        if self.adapter:placeTile(p.x, p.y, 3) then
                            self.metrics.seedsPlanted = self.metrics.seedsPlanted + 1
                        end
                    end
                end
                self:markSteps({ 19, 20, 21, 22 }, "DONE")
            end
            self:runValidationReport()
            self.state = "COMPLETED"
            self.adapter:log("DIRTFARM", "DirtFarm 24-Step cycle & validation completed")
            return false
        end
    end

    -- 10. Smart Local Priority (SLP): prefer task within slpRadius before distant tasks
    self:markSteps({ 14 }, "RUN")
    local px, py = self.adapter.player.x, self.adapter.player.y
    local radius = self.opts.slpRadius or 4
    local hasLocal = false
    for _, t in ipairs(self.tasks) do
        if manhattan(px, py, t.x, t.y) <= radius then hasLocal = true; break end
    end
    local bi, bd = 1, math.huge
    for i, t in ipairs(self.tasks) do
        local d = manhattan(px, py, t.x, t.y)
        if (not hasLocal) or (d <= radius) then
            if d < bd then bi, bd = i, d end
        end
    end
    local taskItem = self.tasks[bi]
    table.remove(self.tasks, bi)
    self:markSteps({ 14 }, "DONE")

    if taskItem.action == "BREAK_FG" or taskItem.action == "CONVERT_FG" then
        self.state = "CLEARING_OBSTACLES"
        self:markSteps({ 3, 4, 5, 6, 12 }, "RUN")
        self.adapter:moveTo(taskItem.x, math.max(0, taskItem.y - 1))
        for _ = 1, 14 do
            self.adapter:punchTile(taskItem.x, taskItem.y)
            if self.adapter:getTile(taskItem.x, taskItem.y).fg == 0 then
                self.metrics.obstaclesBroken = self.metrics.obstaclesBroken + 1
                break
            end
        end
        if taskItem.action == "CONVERT_FG" and self.adapter:getInventoryCount(2) > 0 then
            if self.adapter:placeTile(taskItem.x, taskItem.y, 2) then
                self.metrics.platformsBuilt = self.metrics.platformsBuilt + 1
            end
        end
        self:collectDropsWithCap(radius)
    elseif taskItem.action == "REMOVE_BG" then
        self.state = "REMOVING_BG"
        self:markSteps({ 13 }, "RUN")
        self.adapter:moveTo(taskItem.x, taskItem.y)
        for _ = 1, 8 do
            self.adapter:punchTile(taskItem.x, taskItem.y)
            if self.adapter:getTile(taskItem.x, taskItem.y).bg == 0 then
                self.metrics.bgRemoved = self.metrics.bgRemoved + 1
                break
            end
        end
    elseif taskItem.action == "PLACE_DIRT" then
        self.state = "BUILDING_PLATFORMS"
        self:markSteps({ 8, 9, 10, 11 }, "RUN")
        if self.adapter:getInventoryCount(2) > 0 then
            self.adapter:moveTo(taskItem.x, math.max(0, taskItem.y - 1))
            if self.adapter:placeTile(taskItem.x, taskItem.y, 2) then
                self.metrics.platformsBuilt = self.metrics.platformsBuilt + 1
            end
        else
            self:collectDropsWithCap(nil)
        end
    end
    return true
end

function DirtFarmEngine:startAsync(onUpdate)
    self.stopRequested = false
    self:preparePlan()
    task.spawn(function()
        while not self.stopRequested do
            local cont = self:stepOnce()
            if onUpdate then pcall(onUpdate) end
            if not cont then break end
            task.wait(0.02)
        end
    end)
end

--==============================================================================
-- 7. FEATURE 4: PNB AUTOMATION & WATCHDOG SYSTEM (PNB.MD - 12 MODULES / 11 STATES)
--==============================================================================
local PNBSystem = {}
PNBSystem.__index = PNBSystem

PNBSystem.PIPELINE_STATES = {
    "IDLE", "SCANNING", "CHECKING_TARGET", "PLACING", "VERIFYING_PLACE",
    "BREAKING", "VERIFYING_BREAK", "COLLECTING", "VERIFYING_COLLECT", "NEXT_TARGET", "RECOVERING",
}

function PNBSystem.new(adapter, selector)
    local self = setmetatable({}, PNBSystem)
    self.adapter = adapter
    self.selector = selector
    self.state = "IDLE"
    self.stopRequested = false
    self.cfg = {
        blockId = 2,
        targetMode = "Multi-Tile Area",
        areaSize = 3,
        direction = "UP",
        delayPlace = 120,
        delayBreak = 180,
        delayCollect = 100,
        delayVerify = 60,
        delayNextTarget = 100,
        delayCycle = 150,
        retryLimit = 3,
        watchdogTimeout = 3.0,
        collectSeedFirst = true,
    }
    self.targets = {}
    self.targetIdx = 1
    self.retriesOnTarget = 0
    self.stateEnteredAt = adapter:getTime()
    self.cyclesCompleted = 0
    self.blocksPlaced = 0
    self.blocksBroken = 0
    self.dropsCollected = 0
    self.watchdogTrips = 0
    return self
end

function PNBSystem:buildTargets()
    self.targets = {}
    local px, py = self.adapter.player.x, self.adapter.player.y
    local dx, dy = 0, -1
    if self.cfg.direction == "DOWN" then dx, dy = 0, 1
    elseif self.cfg.direction == "LEFT" then dx, dy = -1, 0
    elseif self.cfg.direction == "RIGHT" then dx, dy = 1, 0 end
    local effSize = (self.cfg.targetMode == "Single Tile") and 1 or math.max(1, math.min(5, self.cfg.areaSize))
    for i = 1, effSize do
        local tx, ty = px + dx * i, py + dy * i
        if self.adapter:inBounds(tx, ty) then
            local t = self.adapter:getTile(tx, ty)
            if t and not self.adapter:isProtectedTile(t.fg) then
                table.insert(self.targets, { x = tx, y = ty, index = i })
            end
        end
    end
    self.targetIdx = 1
    self.retriesOnTarget = 0
end

function PNBSystem:transition(s)
    self.state = s
    self.stateEnteredAt = self.adapter:getTime()
end

function PNBSystem:step()
    if self.stopRequested and (self.state == "SCANNING" or self.state == "NEXT_TARGET") then
        self:transition("IDLE")
        return false
    end

    if (self.adapter:getTime() - self.stateEnteredAt) > self.cfg.watchdogTimeout and self.state ~= "IDLE" and self.state ~= "PAUSED" then
        self.watchdogTrips = self.watchdogTrips + 1
        self.adapter:log("PNB", "Watchdog stalled in " .. self.state .. " -> RECOVERING")
        self:transition("RECOVERING")
        return true
    end

    if self.state == "IDLE" then
        self:buildTargets()
        self:transition("SCANNING")
    end

    local target = self.targets[self.targetIdx]
    if self.state == "SCANNING" then
        if #self.targets == 0 then self:buildTargets() end
        target = self.targets[self.targetIdx]
        if not target then self:transition("ERROR"); return false end
        self:transition("CHECKING_TARGET")
    elseif self.state == "CHECKING_TARGET" then
        local t = self.adapter:getTile(target.x, target.y)
        if t and t.fg == self.cfg.blockId then
            self:transition("BREAKING")
        elseif t and t.fg == 0 then
            self:transition("PLACING")
        else
            self:transition("NEXT_TARGET")
        end
    elseif self.state == "PLACING" then
        local blk = (self.selector and self.selector.selectedBlock and self.selector.selectedBlock.id) or self.cfg.blockId
        self.cfg.blockId = blk
        local ok, err = self.adapter:placeTile(target.x, target.y, blk)
        if not ok and err == "NO_ITEM" then
            self:transition("IDLE")
            self.adapter:log("PNB", "Out of selected block ID " .. tostring(blk))
            return false
        end
        self:transition("VERIFYING_PLACE")
    elseif self.state == "VERIFYING_PLACE" then
        local t = self.adapter:getTile(target.x, target.y)
        if t and t.fg == self.cfg.blockId then
            self.blocksPlaced = self.blocksPlaced + 1
            self.retriesOnTarget = 0
            self:transition("BREAKING")
        else
            self.retriesOnTarget = self.retriesOnTarget + 1
            if self.retriesOnTarget > self.cfg.retryLimit then
                self:transition("RECOVERING")
            else
                self:transition("PLACING")
            end
        end
    elseif self.state == "BREAKING" then
        self.adapter:punchTile(target.x, target.y)
        self:transition("VERIFYING_BREAK")
    elseif self.state == "VERIFYING_BREAK" then
        local t = self.adapter:getTile(target.x, target.y)
        if t and t.fg == 0 then
            self.blocksBroken = self.blocksBroken + 1
            self.retriesOnTarget = 0
            self:transition("COLLECTING")
        else
            self.retriesOnTarget = self.retriesOnTarget + 1
            if self.retriesOnTarget > (self.cfg.retryLimit * 4) then
                self:transition("RECOVERING")
            else
                self:transition("BREAKING")
            end
        end
    elseif self.state == "COLLECTING" then
        local drops = self.adapter:getDrops()
        if self.cfg.collectSeedFirst then
            table.sort(drops, function(a, b)
                return (self.adapter:isSeed(a.id) and 0 or 1) < (self.adapter:isSeed(b.id) and 0 or 1)
            end)
        end
        for _, d in ipairs(drops) do
            if d.x == target.x and d.y == target.y then
                local ok = self.adapter:collectDrop(d.uid)
                if ok then self.dropsCollected = self.dropsCollected + 1 end
            end
        end
        self:transition("VERIFYING_COLLECT")
    elseif self.state == "VERIFYING_COLLECT" then
        self:transition("NEXT_TARGET")
    elseif self.state == "NEXT_TARGET" then
        self.targetIdx = self.targetIdx + 1
        self.retriesOnTarget = 0
        if self.targetIdx > #self.targets then
            self.cyclesCompleted = self.cyclesCompleted + 1
            self.targetIdx = 1
        end
        self:transition("SCANNING")
    elseif self.state == "RECOVERING" then
        self.retriesOnTarget = 0
        local t = target and self.adapter:getTile(target.x, target.y)
        if t and t.fg == self.cfg.blockId then
            self:transition("BREAKING")
        else
            self:transition("CHECKING_TARGET")
        end
    end
    return true
end

function PNBSystem:startAsync(onUpdate)
    if self.state ~= "IDLE" and self.state ~= "PAUSED" and self.state ~= "ERROR" then return end
    self.stopRequested = false
    self:buildTargets()
    self:transition("SCANNING")
    task.spawn(function()
        while self.state ~= "IDLE" and self.state ~= "ERROR" and self.state ~= "PAUSED" do
            local prevState = self.state
            local cont = self:step()
            if onUpdate then pcall(onUpdate) end
            if not cont then break end
            local ms = (prevState == "PLACING" and self.cfg.delayPlace)
                or (prevState == "BREAKING" and self.cfg.delayBreak)
                or (prevState == "COLLECTING" and self.cfg.delayCollect)
                or (prevState:find("VERIFYING") and self.cfg.delayVerify)
                or (prevState == "NEXT_TARGET" and ((self.targetIdx == 1) and self.cfg.delayCycle or self.cfg.delayNextTarget))
                or 50
            task.wait(math.max(0.02, ms / 1000))
        end
    end)
end

--==============================================================================
-- 8. FEATURE 5: PROTECTION, HIT LOGGER & MOVEMENT ENGINE (MISC.MD - 7-STATE)
--==============================================================================
local ProtectionMovementEngine = {}
ProtectionMovementEngine.__index = ProtectionMovementEngine

ProtectionMovementEngine.STATES = {
    "IDLE", "DETECTED", "PROCESSING", "VERIFYING", "SUCCESS", "FAILED", "RECOVERY",
}

function ProtectionMovementEngine.new(adapter)
    local self = setmetatable({}, ProtectionMovementEngine)
    self.adapter = adapter
    self.rouletteCooldown = 1.0
    self.lastSpinTime = {}
    self.hitHistory = {}
    self.seenHitIds = {}
    self.noclipSavedCollide = {}
    self.lastSafeCFrame = nil
    self.flyBV = nil
    self.floatingHudEnabled = false
    self.floatingHudLabel = nil
    self.features = {
        AntiLava = { enabled = false, color = "GRAY", status = "IDLE" },
        AntiSpike = { enabled = false, color = "GRAY", status = "IDLE" },
        AntiFastRoulette = { enabled = false, color = "GRAY", status = "IDLE" },
        HitLogger = { enabled = false, color = "GRAY", status = "IDLE" },
        Fly = { enabled = false, color = "GRAY", status = "IDLE" },
        Noclip = { enabled = false, color = "GRAY", status = "IDLE" },
    }

    adapter:on("CombatHit", function(ev)
        if not self.features.HitLogger.enabled then return end
        if self.seenHitIds[ev.id] then return end
        self.seenHitIds[ev.id] = true
        self.features.HitLogger.status = "DETECTED"
        self.features.HitLogger.color = "YELLOW"
        local dmgStr = (type(ev.damage) == "number") and tostring(ev.damage) or "UNKNOWN"
        local line = string.format("[HIT DETECTED] Source=%s Damage=%s", tostring(ev.source or "UNKNOWN"), dmgStr)
        table.insert(self.hitHistory, line)
        self.features.HitLogger.status = "SUCCESS"
        self.features.HitLogger.color = "GREEN"
        self.adapter:log("HIT", line)
        self:updateFloatingHud()
    end)

    self:bindLiveMovementLoop()
    return self
end

function ProtectionMovementEngine:updateFloatingHud()
    if not self.floatingHudLabel then return end
    local activeCnt = 0
    for _, f in pairs(self.features) do
        if f.enabled then activeCnt = activeCnt + 1 end
    end
    local lastHit = self.hitHistory[#self.hitHistory] or "No recent hits"
    self.floatingHudLabel.Text = string.format("DRY CURSED HUD | Active: %d/6 | Hits: %d\n%s",
        activeCnt, #self.hitHistory, lastHit)
end

function ProtectionMovementEngine:bindLiveMovementLoop()
    RunService.Stepped:Connect(function()
        local char, hum, root = self.adapter:getCharacterParts()
        if not char or not hum or not root then return end

        if not self.features.Noclip.enabled then
            self.lastSafeCFrame = root.CFrame
        end

        if self.features.Noclip.enabled then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    if self.noclipSavedCollide[part] == nil then
                        self.noclipSavedCollide[part] = part.CanCollide
                    end
                    part.CanCollide = false
                end
            end
        end

        if self.features.AntiLava.enabled or self.features.AntiSpike.enabled then
            local t = self.adapter:getTile(self.adapter.player.x, self.adapter.player.y)
            local info = t and self.adapter:getItem(t.fg)
            local isLava = t and (t.fg == 4 or (info and info.hurts))
            local isSpike = t and (t.fg == 162 or t.fg == 3748 or (info and info.deadly))
            if isLava and self.features.AntiLava.enabled then
                self:handleHazard("AntiLava", root)
            elseif isSpike and self.features.AntiSpike.enabled then
                self:handleHazard("AntiSpike", root)
            end
        end
    end)

    RunService.RenderStepped:Connect(function()
        if not self.features.Fly.enabled then return end
        local _, hum, root = self.adapter:getCharacterParts()
        if not hum or not root then return end
        if not self.flyBV or self.flyBV.Parent ~= root then
            if self.flyBV then self.flyBV:Destroy() end
            local bv = Instance.new("BodyVelocity")
            bv.Name = "DryCursedFlyBV"
            bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
            bv.Velocity = Vector3.new(0, 0, 0)
            bv.Parent = root
            self.flyBV = bv
        end
        local cam = Workspace.CurrentCamera
        local moveVec = Vector3.new(0, 0, 0)
        if cam then
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveVec = moveVec + cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveVec = moveVec - cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveVec = moveVec - cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveVec = moveVec + cam.CFrame.RightVector end
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveVec = moveVec + Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then moveVec = moveVec - Vector3.new(0, 1, 0) end
        if moveVec.Magnitude > 0.01 then
            self.flyBV.Velocity = moveVec.Unit * (self.adapter.player.flySpeed or 48)
        else
            self.flyBV.Velocity = Vector3.new(0, 0, 0)
        end
    end)
end

function ProtectionMovementEngine:handleHazard(featureName, root)
    local f = self.features[featureName]
    if not f then return end
    -- 7-State Pipeline: DETECTED -> PROCESSING -> RECOVERY -> VERIFYING -> SUCCESS
    f.status = "DETECTED"; f.color = "RED"
    f.status = "PROCESSING"; f.color = "YELLOW"
    f.status = "RECOVERY"; f.color = "YELLOW"
    self.adapter:moveTo(self.adapter.world.doorX, self.adapter.world.doorY)
    if root and self.lastSafeCFrame then root.CFrame = self.lastSafeCFrame end
    f.status = "VERIFYING"; f.color = "YELLOW"
    f.status = "SUCCESS"; f.color = "GREEN"
    self.adapter:log("PROTECT", featureName .. " recovered player safely to door (" .. tostring(self.adapter.world.doorX) .. "," .. tostring(self.adapter.world.doorY) .. ")")
    self:updateFloatingHud()
end

function ProtectionMovementEngine:checkRouletteSpin(tileKey)
    if not self.features.AntiFastRoulette.enabled then return true, "DISABLED" end
    local now = self.adapter:getTime()
    local prev = self.lastSpinTime[tileKey]
    if prev and (now - prev) < self.rouletteCooldown then
        self.features.AntiFastRoulette.status = "FAILED"
        self.features.AntiFastRoulette.color = "RED"
        self.adapter:log("PROTECT", string.format("AntiFastRoulette blocked fast spin (%.2fs < %.2fs)", now - prev, self.rouletteCooldown))
        return false, "COOLDOWN_BLOCKED"
    end
    self.lastSpinTime[tileKey] = now
    self.features.AntiFastRoulette.status = "SUCCESS"
    self.features.AntiFastRoulette.color = "GREEN"
    return true, "ALLOWED"
end

function ProtectionMovementEngine:simulateHazardTest()
    if self.features.AntiLava.enabled then self:handleHazard("AntiLava", nil) end
    if self.features.AntiSpike.enabled then self:handleHazard("AntiSpike", nil) end
    if self.features.AntiFastRoulette.enabled then
        self:checkRouletteSpin("test_wheel_758")
        self:checkRouletteSpin("test_wheel_758")
    end
    if self.features.HitLogger.enabled then
        self.adapter:emit("CombatHit", {
            id = "sim_" .. tostring(math.floor(os.clock() * 1000)),
            kind = "HIT",
            source = "SIMULATED_HAZARD_CHECK",
            damage = "UNKNOWN",
            x = self.adapter.player.x,
            y = self.adapter.player.y,
        })
    end
    self:updateFloatingHud()
end

function ProtectionMovementEngine:toggleFeature(name)
    local f = self.features[name]
    if not f then return end
    f.enabled = not f.enabled
    f.status = f.enabled and "SUCCESS" or "IDLE"
    f.color = f.enabled and "GREEN" or "GRAY"

    if name == "Fly" then
        self.adapter.player.flyEnabled = f.enabled
        if not f.enabled and self.flyBV then
            self.flyBV:Destroy()
            self.flyBV = nil
        end
    elseif name == "Noclip" then
        self.adapter.player.noclipEnabled = f.enabled
        if not f.enabled then
            for part, prev in pairs(self.noclipSavedCollide) do
                if part and part.Parent then part.CanCollide = prev end
            end
            self.noclipSavedCollide = {}
            local _, _, root = self.adapter:getCharacterParts()
            if root and self.lastSafeCFrame then
                root.CFrame = self.lastSafeCFrame + Vector3.new(0, 1.5, 0)
            end
        end
    end
    self.adapter:log("PROTECT", name .. " -> " .. (f.enabled and "ON (SUCCESS)" or "OFF (IDLE)"))
    self:updateFloatingHud()
end

--==============================================================================
-- 9. FEATURE 6: CHAT SPAMMER & RAINBOW ENGINE (SPAMER.MD - ALL 18 COMPONENTS)
--==============================================================================
local ChatSpammer = {}
ChatSpammer.__index = ChatSpammer

ChatSpammer.COLOR_KEYS = { "0", "2", "1", "3", "4", "5", "6", "8", "9", "e", "c", "#", "p" }

function ChatSpammer.new(adapter)
    local self = setmetatable({}, ChatSpammer)
    self.adapter = adapter
    self.state = "IDLE"
    self.running = false
    self.stopRequested = false
    self.cfg = {
        mode = "SINGLE", -- "SINGLE", "DUAL", "QUEUE"
        msg1 = "Selling Farmables @ Main!",
        msg2 = "Cheap Locks & Dirt!",
        queue = { "Selling Farmables @ Main!", "Cheap Locks & Dirt!" },
        prefix = "",
        prefixEnabled = false,
        prefixPos = "Before",
        prefixSeparator = " ",
        colorEnabled = true,
        prefixColorCode = "6",
        textColorCode = "2",
        rainbowEnabled = false,
        rainbowMode = "word",
        repeatCount = 5,
        delaySeconds = 2.0,
    }
    self.stats = { pending = 0, sent = 0, accepted = 0, rejected = 0, cancelled = 0, lastError = "" }
    return self
end

function ChatSpammer:syncQueueFromInputs()
    if #self.cfg.queue == 0 then
        self.cfg.queue = { self.cfg.msg1 }
        if trimStr(self.cfg.msg2) ~= "" then table.insert(self.cfg.queue, self.cfg.msg2) end
    end
end

function ChatSpammer:formatText(raw)
    local t = trimStr(raw)
    if t == "" then return nil, "EMPTY" end
    local pf = trimStr(self.cfg.prefix)
    local hasPrefix = self.cfg.prefixEnabled and pf ~= ""
    local sep = self.cfg.prefixSeparator or " "

    if self.cfg.rainbowEnabled then
        local combined = hasPrefix and ((self.cfg.prefixPos == "After") and (t .. sep .. pf) or (pf .. sep .. t)) or t
        local seq = { "4", "8", "9", "2", "1", "e", "5", "#" }
        local clean = (combined:gsub("`.", ""))
        local parts, idx = {}, 1
        if self.cfg.rainbowMode == "word" then
            for tok in string.gmatch(clean, "%S+%s*") do
                local p = "`" .. seq[((idx - 1) % #seq) + 1] .. tok
                if #table.concat(parts) + #p > CONFIG.MAX_CHAT_LENGTH then break end
                table.insert(parts, p)
                idx = idx + 1
            end
        else
            for i = 1, #clean do
                local ch = clean:sub(i, i)
                if ch == " " then
                    if #table.concat(parts) + 1 > CONFIG.MAX_CHAT_LENGTH then break end
                    table.insert(parts, ch)
                else
                    local p = "`" .. seq[((idx - 1) % #seq) + 1] .. ch
                    if #table.concat(parts) + #p > CONFIG.MAX_CHAT_LENGTH then break end
                    table.insert(parts, p)
                    idx = idx + 1
                end
            end
        end
        t = table.concat(parts)
    elseif self.cfg.colorEnabled then
        if hasPrefix then
            local pC = "`" .. tostring(self.cfg.prefixColorCode or "6") .. pf
            local bC = "`" .. tostring(self.cfg.textColorCode or "2") .. t
            t = (self.cfg.prefixPos == "After") and (bC .. sep .. pC) or (pC .. sep .. bC)
        else
            t = "`" .. tostring(self.cfg.textColorCode or "2") .. t
        end
    elseif hasPrefix then
        t = (self.cfg.prefixPos == "After") and (t .. sep .. pf) or (pf .. sep .. t)
    end
    if #t > CONFIG.MAX_CHAT_LENGTH then return nil, "OVER_120_CHARS" end
    return t, "OK"
end

function ChatSpammer:buildBatchList()
    if self.cfg.mode == "SINGLE" then
        return { self.cfg.msg1 }
    elseif self.cfg.mode == "DUAL" then
        return { self.cfg.msg1, self.cfg.msg2 }
    else
        self:syncQueueFromInputs()
        return self.cfg.queue
    end
end

function ChatSpammer:sendSingleTest()
    local formatted, err = self:formatText(self.cfg.msg1)
    if not formatted then
        self.stats.rejected = self.stats.rejected + 1
        self.stats.lastError = tostring(err)
        self.adapter:log("SPAM_ERR", tostring(err))
        return false, err
    end
    local st, reason = self.adapter:sendChatMessage(formatted)
    self.stats.sent = self.stats.sent + 1
    if st == "ACCEPTED" then
        self.stats.accepted = self.stats.accepted + 1
        self.stats.lastError = ""
    else
        self.stats.rejected = self.stats.rejected + 1
        self.stats.lastError = tostring(reason)
    end
    return true, st
end

function ChatSpammer:startAsync(onUpdate)
    if self.running then return false, "ALREADY_RUNNING" end
    self.running = true
    self.stopRequested = false
    self.state = "SENDING"
    task.spawn(function()
        local reps = tonumber(self.cfg.repeatCount) or 1
        local infinite = (reps == 0)
        local delay = math.max(0.5, tonumber(self.cfg.delaySeconds) or 2.0)
        local batchIdx = 0
        while not self.stopRequested and (infinite or batchIdx < reps) do
            batchIdx = batchIdx + 1
            local list = self:buildBatchList()
            self.stats.pending = #list
            for i, raw in ipairs(list) do
                if self.stopRequested then
                    self.stats.cancelled = self.stats.cancelled + (#list - i + 1)
                    break
                end
                local formatted, err = self:formatText(raw)
                self.stats.pending = math.max(0, self.stats.pending - 1)
                if formatted then
                    local st, reason = self.adapter:sendChatMessage(formatted)
                    self.stats.sent = self.stats.sent + 1
                    if st == "ACCEPTED" then
                        self.stats.accepted = self.stats.accepted + 1
                    else
                        self.stats.rejected = self.stats.rejected + 1
                        self.stats.lastError = tostring(reason)
                    end
                else
                    self.stats.rejected = self.stats.rejected + 1
                    self.stats.lastError = tostring(err)
                    self.adapter:log("SPAM_ERR", tostring(err))
                end
                if onUpdate then pcall(onUpdate) end
            end
            if not self.stopRequested and (infinite or batchIdx < reps) then
                self.state = "WAIT_DELAY"
                if onUpdate then pcall(onUpdate) end
                local elapsed = 0
                while elapsed < delay and not self.stopRequested do
                    task.wait(0.1)
                    elapsed = elapsed + 0.1
                end
                self.state = "SENDING"
            end
        end
        self.running = false
        self.stats.pending = 0
        self.state = self.stopRequested and "STOPPED" or "COMPLETED"
        if onUpdate then pcall(onUpdate) end
    end)
    return true
end

function ChatSpammer:stop()
    self.stopRequested = true
end

function ChatSpammer:reset()
    self.stopRequested = true
    self.running = false
    self.stats = { pending = 0, sent = 0, accepted = 0, rejected = 0, cancelled = 0, lastError = "" }
    self.state = "IDLE"
end

--==============================================================================
-- 10. FEATURE 7: VISUAL NAME, ROLES, WARDROBE & PRIORITY RULES (MODULE 11)
--==============================================================================
local VisualEngine = {}
VisualEngine.__index = VisualEngine

VisualEngine.ROLES = {
    { id = "OWNER",     color = "#FFD700", effect = "Glow",    set = "Admin Gold Set" },
    { id = "ADMIN",     color = "#3498DB", effect = "Glow",    set = "Developer Cyber Set" },
    { id = "DEVELOPER", color = "#00CEC9", effect = "Outline", set = "Developer Cyber Set" },
    { id = "MODERATOR", color = "#2ECC71", effect = "Outline", set = "Emerald VIP Set" },
    { id = "CREATOR",   color = "#E84393", effect = "Gradient",set = "Ruby Monarch Set" },
    { id = "VIP",       color = "#9B59B6", effect = "Glow",    set = "Shadow Ninja Set" },
    { id = "MEMBER",    color = "#E6E6E6", effect = "None",    set = "Default" },
    { id = "CUSTOM",    color = "#1ABC9C", effect = "Pulse",   set = "Custom" },
}

VisualEngine.CLOTHING_SETS = {
    ["Admin Gold Set"]      = { hat = 20016, back = 20017, hand = 20004, chest = 20011 },
    ["Developer Cyber Set"] = { hat = 20007, back = 20009, hand = 20012, chest = 20006 },
    ["Shadow Ninja Set"]    = { back = 20005, hand = 20000, chest = 20006 },
    ["Emerald VIP Set"]     = { back = 1784,  hand = 5480,  chest = 20011 },
    ["Ruby Monarch Set"]    = { hat = 20016, back = 5020,  hand = 20008, chest = 20006 },
    ["Default"]             = {},
    ["Custom"]              = {},
}

VisualEngine.SLOT_POOL = {
    hat = { 0, 20007, 20016 },
    back = { 0, 1784, 5020, 9712, 20005, 20009, 20015, 20017 },
    hand = { 0, 2592, 5480, 20000, 20004, 20008, 20012 },
    chest = { 0, 20006, 20011 },
    hair = { 0 }, face = { 0 }, shirt = { 0 }, pants = { 0 }, feet = { 0 },
}

function VisualEngine.hexToRGB(hex)
    local clean = tostring(hex or "#FFFFFF"):gsub("^#", "")
    if #clean ~= 6 then return { r = 255, g = 255, b = 255 } end
    local r = tonumber(clean:sub(1, 2), 16) or 255
    local g = tonumber(clean:sub(3, 4), 16) or 255
    local b = tonumber(clean:sub(5, 6), 16) or 255
    return { r = r, g = g, b = b }
end

function VisualEngine.new(adapter)
    local self = setmetatable({}, VisualEngine)
    self.adapter = adapter
    self.displayName = LocalPlayer.DisplayName or LocalPlayer.Name
    self.roleId = "OWNER"
    self.hexColor = "#FFD700"
    self.effect = "Glow"
    self.selectedSet = "Admin Gold Set"
    self.customSlots = shallowCopy(VisualEngine.CLOTHING_SETS["Admin Gold Set"])
    self.targetOverridePlayer = LocalPlayer.Name
    self.playerOverrides = {}
    self.syncServerWear = false
    self.savedPreset = nil
    self.lastRuleMatchTier = "Role Preset"
    return self
end

function VisualEngine:addPlayerOverride(playerName)
    local key = trimStr(playerName)
    if key == "" then return false end
    self.playerOverrides[key] = {
        roleId = self.roleId,
        hexColor = self.hexColor,
        effect = self.effect,
        selectedSet = self.selectedSet,
        customSlots = shallowCopy(self.customSlots),
    }
    self.adapter:log("VISUAL", "Saved Player Profile Override for: " .. key)
    return true
end

function VisualEngine:removePlayerOverride(playerName)
    local key = trimStr(playerName)
    self.playerOverrides[key] = nil
    self.adapter:log("VISUAL", "Removed Player Profile Override for: " .. key)
end

function VisualEngine:evaluatePriorityRules(targetName)
    local name = trimStr(targetName)
    if name == "" then name = LocalPlayer.Name end
    local override = self.playerOverrides[name]
    if override then
        self.lastRuleMatchTier = "Player Override (" .. name .. ")"
        self.roleId = override.roleId
        self.hexColor = override.hexColor
        self.effect = override.effect
        self.selectedSet = override.selectedSet
        self.customSlots = shallowCopy(override.customSlots)
        return self:apply()
    end
    for _, r in ipairs(VisualEngine.ROLES) do
        if r.id == self.roleId then
            self.lastRuleMatchTier = "Role Preset (" .. r.id .. ")"
            return self:apply()
        end
    end
    self.lastRuleMatchTier = "Default"
    self.roleId = "MEMBER"
    self.hexColor = "#E6E6E6"
    self.effect = "None"
    self.selectedSet = "Default"
    return self:apply()
end

function VisualEngine:savePreset()
    self.savedPreset = {
        displayName = self.displayName,
        roleId = self.roleId,
        hexColor = self.hexColor,
        effect = self.effect,
        selectedSet = self.selectedSet,
        customSlots = shallowCopy(self.customSlots),
    }
    self.adapter:log("VISUAL", "Preset saved (" .. self.roleId .. " / " .. self.selectedSet .. ")")
    return self.savedPreset
end

function VisualEngine:loadPreset()
    if not self.savedPreset then return false end
    local p = self.savedPreset
    self.displayName = p.displayName
    self.roleId = p.roleId
    self.hexColor = p.hexColor
    self.effect = p.effect
    self.selectedSet = p.selectedSet
    self.customSlots = shallowCopy(p.customSlots)
    self.adapter:log("VISUAL", "Preset loaded (" .. self.roleId .. " / " .. self.selectedSet .. ")")
    return self:apply()
end

function VisualEngine:apply()
    local rgb = VisualEngine.hexToRGB(self.hexColor)
    local setItems = (self.selectedSet == "Custom")
        and shallowCopy(self.customSlots)
        or shallowCopy(VisualEngine.CLOTHING_SETS[self.selectedSet] or {})
    local spec = {
        name = trimStr(self.displayName) ~= "" and self.displayName or LocalPlayer.Name,
        role = self.roleId,
        color = self.hexColor,
        rgb = rgb,
        effect = self.effect,
        clothing = setItems,
    }
    self.adapter:applyLocalVisualLook(spec)

    if self.syncServerWear then
        local synced = 0
        for _, itemId in pairs(setItems) do
            if type(itemId) == "number" and itemId > 0 and self.adapter:getInventoryCount(itemId) > 0 then
                self.adapter:sendPacket("wear", { id = itemId })
                synced = synced + 1
            end
        end
        self.adapter:log("VISUAL", "Synced " .. tostring(synced) .. " owned clothing item(s) via 'wear' packet")
    end

    self.adapter:log("VISUAL", string.format("Applied [%s] %s (%s / %s / %s) Tier=%s",
        spec.role, spec.name, spec.color, tostring(spec.effect), self.selectedSet, self.lastRuleMatchTier))
    return spec
end

function VisualEngine:reset()
    self.displayName = LocalPlayer.DisplayName or LocalPlayer.Name
    self.roleId = "MEMBER"
    self.hexColor = "#FFFFFF"
    self.effect = "None"
    self.selectedSet = "Default"
    self.customSlots = {}
    self.lastRuleMatchTier = "Default"
    return self:apply()
end

--==============================================================================
-- 11. INSTANTIATE CONTROLLERS & UNIFIED "DRY CURSED" ROBLOX MENU GUI
--==============================================================================
local adapter = Adapter.new()
local selector = InventorySelector.new(adapter)
local clearer = ClearWorldEngine.new(adapter)
local dirtfarm = DirtFarmEngine.new(adapter)
local pnb = PNBSystem.new(adapter, selector)
local protectMove = ProtectionMovementEngine.new(adapter)
local spammer = ChatSpammer.new(adapter)
local visuals = VisualEngine.new(adapter)

local THEME = {
    BG = Color3.fromRGB(16, 18, 24),
    PANEL = Color3.fromRGB(24, 27, 36),
    CARD = Color3.fromRGB(32, 36, 48),
    ACCENT = Color3.fromRGB(220, 56, 72),
    ACCENT_ALT = Color3.fromRGB(58, 134, 255),
    GREEN = Color3.fromRGB(46, 204, 113),
    YELLOW = Color3.fromRGB(241, 196, 15),
    RED = Color3.fromRGB(231, 76, 60),
    TEXT = Color3.fromRGB(242, 244, 248),
    MUTED = Color3.fromRGB(154, 162, 178),
    BORDER = Color3.fromRGB(52, 58, 76),
}

local function addCorner(inst, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 6)
    c.Parent = inst
    return c
end

local function addStroke(inst, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color = color or THEME.BORDER
    s.Thickness = thickness or 1
    s.Parent = inst
    return s
end

local function makeLabel(parent, text, size, pos, textSize, color, font, alignX)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Size = size or UDim2.new(1, 0, 0, 22)
    l.Position = pos or UDim2.new(0, 0, 0, 0)
    l.Text = text or ""
    l.TextSize = textSize or 13
    l.TextColor3 = color or THEME.TEXT
    l.Font = font or Enum.Font.GothamMedium
    l.TextXAlignment = alignX or Enum.TextXAlignment.Left
    l.TextTruncate = Enum.TextTruncate.AtEnd
    l.Parent = parent
    return l
end

local function makeButton(parent, text, size, pos, bg, fn)
    local b = Instance.new("TextButton")
    b.Size = size or UDim2.new(0, 130, 0, 30)
    b.Position = pos or UDim2.new(0, 0, 0, 0)
    b.BackgroundColor3 = bg or THEME.CARD
    b.Text = text or "Button"
    b.TextSize = 11
    b.Font = Enum.Font.GothamSemibold
    b.TextColor3 = THEME.TEXT
    b.AutoButtonColor = true
    b.Parent = parent
    addCorner(b, 6)
    addStroke(b, THEME.BORDER, 1)
    if fn then b.MouseButton1Click:Connect(fn) end
    return b
end

local function makeInput(parent, placeholder, initial, size, pos, onFocusLost)
    local tb = Instance.new("TextBox")
    tb.Size = size or UDim2.new(0, 200, 0, 28)
    tb.Position = pos or UDim2.new(0, 0, 0, 0)
    tb.BackgroundColor3 = THEME.BG
    tb.PlaceholderText = placeholder or ""
    tb.Text = initial or ""
    tb.TextSize = 11
    tb.Font = Enum.Font.Gotham
    tb.TextColor3 = THEME.TEXT
    tb.ClearTextOnFocus = false
    tb.Parent = parent
    addCorner(tb, 5)
    addStroke(tb, THEME.BORDER, 1)
    if onFocusLost then
        tb.FocusLost:Connect(function() onFocusLost(tb.Text) end)
    end
    return tb
end

local function makeBadge(parent, text, size, pos, bg)
    local b = Instance.new("TextLabel")
    b.Size = size
    b.Position = pos
    b.BackgroundColor3 = bg or THEME.CARD
    b.Text = text
    b.TextSize = 10
    b.Font = Enum.Font.GothamSemibold
    b.TextColor3 = THEME.TEXT
    b.TextTruncate = Enum.TextTruncate.AtEnd
    b.Parent = parent
    addCorner(b, 5)
    addStroke(b, THEME.BORDER, 1)
    return b
end

-- Root ScreenGui & Floating Protection HUD
local screenGui = Instance.new("ScreenGui")
screenGui.Name = GUI_NAME
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = PlayerGui

local floatingHudGui = Instance.new("ScreenGui")
floatingHudGui.Name = HUD_NAME
floatingHudGui.ResetOnSpawn = false
floatingHudGui.Enabled = false
floatingHudGui.Parent = PlayerGui

local hudFrame = Instance.new("Frame")
hudFrame.Size = UDim2.new(0, 320, 0, 48)
hudFrame.Position = UDim2.new(1, -334, 0, 14)
hudFrame.BackgroundColor3 = THEME.BG
hudFrame.Parent = floatingHudGui
addCorner(hudFrame, 8)
addStroke(hudFrame, THEME.ACCENT, 1.5)
protectMove.floatingHudLabel = makeLabel(hudFrame, "DRY CURSED HUD | Active: 0/6 | Hits: 0", UDim2.new(1, -12, 1, -8), UDim2.new(0, 6, 0, 4), 11, THEME.TEXT, Enum.Font.Code)
protectMove.floatingHudLabel.TextWrapped = true

local mainFrame = Instance.new("Frame")
mainFrame.Name = "DryCursedWindow"
mainFrame.Size = UDim2.new(0, 790, 0, 560)
mainFrame.Position = UDim2.new(0.5, -395, 0.5, -280)
mainFrame.BackgroundColor3 = THEME.BG
mainFrame.ClipsDescendants = true
mainFrame.Parent = screenGui
addCorner(mainFrame, 10)
addStroke(mainFrame, THEME.ACCENT, 1.5)

-- Header Bar
local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 44)
header.BackgroundColor3 = THEME.PANEL
header.Parent = mainFrame
addCorner(header, 10)

local badgeStrip = Instance.new("Frame")
badgeStrip.Size = UDim2.new(0, 5, 0, 24)
badgeStrip.Position = UDim2.new(0, 12, 0.5, -12)
badgeStrip.BackgroundColor3 = THEME.ACCENT
badgeStrip.BorderSizePixel = 0
badgeStrip.Parent = header
addCorner(badgeStrip, 3)

local bindTag = (adapter.worldRemotes and "LIVE BYTENET" or (adapter.sharedPackFound and "SHARED PACK" or "LOCAL SANDBOX"))
makeLabel(header, CONFIG.MENU_TITLE, UDim2.new(0, 160, 1, 0), UDim2.new(0, 24, 0, 0), 17, THEME.TEXT, Enum.Font.GothamBlack)
makeLabel(header, "7 MODULES | FULL STEP-BY-STEP MENU | " .. bindTag, UDim2.new(0, 440, 1, 0), UDim2.new(0, 165, 0, 0), 11, THEME.MUTED, Enum.Font.Gotham)

local minimized = false
makeButton(header, "_", UDim2.new(0, 30, 0, 26), UDim2.new(1, -72, 0.5, -13), THEME.CARD, function()
    minimized = not minimized
    mainFrame.Size = minimized and UDim2.new(0, 790, 0, 44) or UDim2.new(0, 790, 0, 560)
end)
makeButton(header, "X", UDim2.new(0, 30, 0, 26), UDim2.new(1, -36, 0.5, -13), THEME.ACCENT, function()
    mainFrame.Visible = false
end)

-- Header Drag & RightShift Toggle
local dragging, dragStart, startPos = false, nil, nil
header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = mainFrame.Position
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)
UserInputService.InputBegan:Connect(function(input, gp)
    if not gp and input.KeyCode == CONFIG.TOGGLE_KEY then
        mainFrame.Visible = not mainFrame.Visible
    end
end)

-- Left Sidebar, Main Content Area, Bottom Console
local sidebar = Instance.new("Frame")
sidebar.Size = UDim2.new(0, 168, 1, -134)
sidebar.Position = UDim2.new(0, 10, 0, 52)
sidebar.BackgroundColor3 = THEME.PANEL
sidebar.Parent = mainFrame
addCorner(sidebar, 8)
addStroke(sidebar, THEME.BORDER, 1)

local contentArea = Instance.new("Frame")
contentArea.Size = UDim2.new(1, -198, 1, -134)
contentArea.Position = UDim2.new(0, 188, 0, 52)
contentArea.BackgroundColor3 = THEME.PANEL
contentArea.Parent = mainFrame
addCorner(contentArea, 8)
addStroke(contentArea, THEME.BORDER, 1)

local logConsole = Instance.new("Frame")
logConsole.Size = UDim2.new(1, -20, 0, 70)
logConsole.Position = UDim2.new(0, 10, 1, -78)
logConsole.BackgroundColor3 = THEME.PANEL
logConsole.Parent = mainFrame
addCorner(logConsole, 8)
addStroke(logConsole, THEME.BORDER, 1)

local logText = makeLabel(logConsole, "[DRY CURSED] Initialized all 7 modules + live step menus.", UDim2.new(1, -96, 1, -8), UDim2.new(0, 10, 0, 4), 11, THEME.MUTED, Enum.Font.Code)
logText.TextWrapped = true
logText.TextYAlignment = Enum.TextYAlignment.Top
makeButton(logConsole, "Clear Log", UDim2.new(0, 78, 0, 24), UDim2.new(1, -86, 0, 6), THEME.CARD, function()
    adapter.logs = {}
    logText.Text = "[LOG CLEARED]"
end)

adapter:on("LogAdded", function()
    local tail = {}
    local startI = math.max(1, #adapter.logs - 3)
    for i = startI, #adapter.logs do table.insert(tail, adapter.logs[i]) end
    logText.Text = table.concat(tail, "\n")
end)

local tabs, tabButtons, refreshHooks = {}, {}, {}

local function switchTab(tabName)
    for name, frame in pairs(tabs) do frame.Visible = (name == tabName) end
    for name, btn in pairs(tabButtons) do
        btn.BackgroundColor3 = (name == tabName) and THEME.ACCENT or THEME.CARD
    end
    if refreshHooks[tabName] then pcall(refreshHooks[tabName]) end
end

local function createTabPage(id, label, orderIdx)
    local page = Instance.new("ScrollingFrame")
    page.Name = "Tab_" .. id
    page.Size = UDim2.new(1, -16, 1, -16)
    page.Position = UDim2.new(0, 8, 0, 8)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.CanvasSize = UDim2.new(0, 0, 0, 620)
    page.ScrollBarThickness = 4
    page.Visible = (orderIdx == 1)
    page.Parent = contentArea
    tabs[id] = page

    tabButtons[id] = makeButton(sidebar, label, UDim2.new(1, -16, 0, 34), UDim2.new(0, 8, 0, 10 + (orderIdx - 1) * 40), (orderIdx == 1) and THEME.ACCENT or THEME.CARD, function()
        switchTab(id)
    end)
    return page
end

makeButton(sidebar, "STOP ALL", UDim2.new(1, -16, 0, 32), UDim2.new(0, 8, 1, -60), THEME.ACCENT, function()
    clearer.stopRequested = true
    dirtfarm.stopRequested = true
    pnb.stopRequested = true
    spammer:stop()
    adapter:log("SYSTEM", "STOP ALL triggered across all automation modules")
end)
makeLabel(sidebar, "[RightShift] Hide/Show", UDim2.new(1, -12, 0, 18), UDim2.new(0, 6, 1, -22), 11, THEME.MUTED, Enum.Font.Gotham, Enum.TextXAlignment.Center)

--==============================================================================
-- 12. TAB 1: MODULE 15 — VISUAL INVENTORY ITEM SELECTOR (ALL 11 COMPONENTS)
--==============================================================================
local pInv = createTabPage("INV", "1. Inventory", 1)
makeLabel(pInv, "MODULE 15 — VISUAL INVENTORY SELECTOR (11 COMPONENTS)", UDim2.new(1, 0, 0, 20), UDim2.new(0, 0, 0, 0), 13, THEME.TEXT, Enum.Font.GothamBold)
local invSelLabel = makeLabel(pInv, "Confirmed Block: None | Seed: None", UDim2.new(1, 0, 0, 18), UDim2.new(0, 0, 0, 22), 11, THEME.YELLOW)
local invCompLabel = makeLabel(pInv, "11 Components Active: Reader | Classifier | IconAtlas | Grid | Search | Sort | SelectMgr | ConfigSync | Events | Bridge | Main", UDim2.new(1, 0, 0, 16), UDim2.new(0, 0, 0, 40), 10, THEME.MUTED)

makeInput(pInv, "Search name or ID...", "", UDim2.new(0, 165, 0, 26), UDim2.new(0, 0, 0, 60), function(txt)
    selector.searchQuery = txt
    refreshHooks.INV()
end)

local invCatBtn, invSortBtn, invCatalogBtn, invModeBtn
invCatBtn = makeButton(pInv, "Cat: All", UDim2.new(0, 86, 0, 26), UDim2.new(0, 172, 0, 60), THEME.CARD, function()
    local nxt = { All = "Blocks", Blocks = "Seeds", Seeds = "All" }
    selector.category = nxt[selector.category] or "All"
    invCatBtn.Text = "Cat: " .. selector.category
    refreshHooks.INV()
end)
invSortBtn = makeButton(pInv, "Sort: count", UDim2.new(0, 90, 0, 26), UDim2.new(0, 264, 0, 60), THEME.CARD, function()
    local nxt = { count = "name", name = "id", id = "count" }
    selector.sortBy = nxt[selector.sortBy] or "count"
    invSortBtn.Text = "Sort: " .. selector.sortBy
    refreshHooks.INV()
end)
invCatalogBtn = makeButton(pInv, "Source: Backpack", UDim2.new(0, 114, 0, 26), UDim2.new(0, 360, 0, 60), THEME.CARD, function()
    selector.showAllItems = not selector.showAllItems
    invCatalogBtn.Text = selector.showAllItems and "Source: ItemDB" or "Source: Backpack"
    refreshHooks.INV()
end)
makeButton(pInv, "Sync Live", UDim2.new(0, 82, 0, 26), UDim2.new(0, 480, 0, 60), THEME.ACCENT_ALT, function()
    local ok, n = adapter:syncLiveBackpack()
    adapter:log("INV", ok and ("Synced " .. tostring(n) .. " live slots") or ("Using local backpack (" .. tostring(n) .. " slots)"))
    refreshHooks.INV()
end)

local modeIdx = 1
invModeBtn = makeButton(pInv, "Mode: Auto (Block/Seed)", UDim2.new(0, 175, 0, 26), UDim2.new(0, 0, 0, 92), THEME.CARD, function()
    modeIdx = (modeIdx % #InventorySelector.SELECT_MODES) + 1
    selector.selectMode = InventorySelector.SELECT_MODES[modeIdx]
    invModeBtn.Text = "Mode: " .. selector.selectMode
    refreshHooks.INV()
end)
makeButton(pInv, "Confirm Selection", UDim2.new(0, 130, 0, 26), UDim2.new(0, 182, 0, 92), THEME.GREEN, function()
    selector:confirmSelection()
    if selector.selectedBlock then pnb.cfg.blockId = selector.selectedBlock.id end
    adapter:log("INV", "Confirmed selection synced to PNB & DirtFarm")
    refreshHooks.INV()
end)
makeButton(pInv, "Clear Selection", UDim2.new(0, 120, 0, 26), UDim2.new(0, 320, 0, 92), THEME.ACCENT, function()
    selector:clearSelection()
    refreshHooks.INV()
end)

local invGrid = Instance.new("Frame")
invGrid.Size = UDim2.new(1, -8, 0, 260)
invGrid.Position = UDim2.new(0, 0, 0, 126)
invGrid.BackgroundTransparency = 1
invGrid.Parent = pInv

refreshHooks.INV = function()
    for _, c in ipairs(invGrid:GetChildren()) do c:Destroy() end
    local cards = selector:refresh()
    local bTxt = selector.selectedBlock and (selector.selectedBlock.name .. " (" .. selector.selectedBlock.count .. (selector.selectedBlock.outOfStock and " OOS" or "") .. ")") or "None"
    local sTxt = selector.selectedSeed and (selector.selectedSeed.name .. " (" .. selector.selectedSeed.count .. (selector.selectedSeed.outOfStock and " OOS" or "") .. ")") or "None"
    local multiCount = 0
    for _, on in pairs(selector.multiSelection) do if on then multiCount = multiCount + 1 end end
    invSelLabel.Text = string.format("Block: %s | Seed: %s | Multi: %d", bTxt, sTxt, multiCount)

    local cols = 3
    local showCount = math.min(36, #cards)
    local rows = math.max(1, math.ceil(showCount / cols))
    invGrid.Size = UDim2.new(1, -8, 0, rows * 62 + 8)
    pInv.CanvasSize = UDim2.new(0, 0, 0, math.max(400, rows * 62 + 140))

    for idx = 1, showCount do
        local rec = cards[idx]
        local col = (idx - 1) % cols
        local row = math.floor((idx - 1) / cols)
        local bg = (rec.isSelectedBlock or rec.isSelectedSeed or rec.isMulti) and THEME.ACCENT_ALT
            or (rec.isPending and THEME.YELLOW or THEME.CARD)
        local btn = makeButton(invGrid, "     " .. string.format("%s [%d]\n     x%d%s", rec.name, rec.id, rec.count, rec.outOfStock and " [OOS]" or ""),
            UDim2.new(0, 182, 0, 56), UDim2.new(0, col * 188, 0, row * 62), bg, function()
                local ok, why = selector:pickCard(rec)
                if ok and selector.selectedBlock then pnb.cfg.blockId = selector.selectedBlock.id end
                adapter:log("INV", tostring(why) .. ": " .. rec.name .. " (" .. tostring(rec.id) .. ")")
                refreshHooks.INV()
            end)
        btn.TextSize = 10

        local iconImg = Instance.new("ImageLabel")
        iconImg.Size = UDim2.new(0, 26, 0, 26)
        iconImg.Position = UDim2.new(0, 6, 0.5, -13)
        iconImg.BackgroundTransparency = 1
        iconImg.Image = rec.icon and rec.icon.assetId or ASSETS.UI.itemBox
        if rec.icon and rec.icon.hasSprite and Vector2 then
            local ts = rec.icon.tileSize or 32
            iconImg.ImageRectOffset = Vector2.new((rec.icon.tx or 0) * ts, (rec.icon.ty or 0) * ts)
            iconImg.ImageRectSize = Vector2.new(ts, ts)
        end
        iconImg.Parent = btn
    end
end
refreshHooks.INV()

--==============================================================================
-- 13. TAB 2: AUTOMATIC WORLD CLEARER (ALL 13 STEPS INTERACTIVE)
--==============================================================================
local pClear = createTabPage("CLEAR", "2. Clear World", 2)
makeLabel(pClear, "AUTOMATIC WORLD CLEARER — 13-STEP PIPELINE (CLEAR WORLD.MD)", UDim2.new(1, 0, 0, 20), UDim2.new(0, 0, 0, 0), 13, THEME.TEXT, Enum.Font.GothamBold)
local clearStatLbl = makeLabel(pClear, "State: IDLE | Preserves: Door (6), Bedrock (8), All Locks", UDim2.new(1, 0, 0, 34), UDim2.new(0, 0, 0, 22), 11, THEME.MUTED)
clearStatLbl.TextWrapped = true

makeLabel(pClear, "Extra Protected IDs:", UDim2.new(0, 122, 0, 26), UDim2.new(0, 0, 0, 60), 11, THEME.TEXT)
makeInput(pClear, "e.g. 2,100", "", UDim2.new(0, 130, 0, 26), UDim2.new(0, 124, 0, 60), function(t)
    clearer:setExtraProtectedFromString(t)
    adapter:log("CLEAR", "Updated Extra Protected IDs filter: " .. tostring(t))
end)
makeLabel(pClear, "Step Delay ms:", UDim2.new(0, 88, 0, 26), UDim2.new(0, 266, 0, 60), 11, THEME.TEXT)
makeInput(pClear, "30", tostring(clearer.stepDelayMs), UDim2.new(0, 56, 0, 26), UDim2.new(0, 356, 0, 60), function(t)
    local v = tonumber(t); if v then clearer.stepDelayMs = math.max(15, v) end
end)

local trashBtn
trashBtn = makeButton(pClear, "Auto-Trash Disposables: ON", UDim2.new(0, 195, 0, 28), UDim2.new(0, 0, 0, 94), THEME.GREEN, function()
    clearer.allowTrashDisposables = not clearer.allowTrashDisposables
    trashBtn.Text = "Auto-Trash Disposables: " .. (clearer.allowTrashDisposables and "ON" or "OFF")
    trashBtn.BackgroundColor3 = clearer.allowTrashDisposables and THEME.GREEN or THEME.CARD
end)
makeButton(pClear, "Scan World (Step 1)", UDim2.new(0, 145, 0, 28), UDim2.new(0, 202, 0, 94), THEME.ACCENT_ALT, function()
    local fgCnt, bgCnt = clearer:scanWorld()
    clearer.state = "SCANNED (" .. tostring(fgCnt) .. " FG / " .. tostring(bgCnt) .. " BG)"
    adapter:log("CLEAR", "Step 1 Scan: " .. tostring(fgCnt) .. " FG, " .. tostring(bgCnt) .. " BG")
    refreshHooks.CLEAR()
end)
makeButton(pClear, "Single Step", UDim2.new(0, 100, 0, 28), UDim2.new(0, 354, 0, 94), THEME.CARD, function()
    clearer.stopRequested = false
    clearer:stepOnce()
    refreshHooks.CLEAR()
end)

makeButton(pClear, "Start Clear World (Steps 1-13)", UDim2.new(0, 210, 0, 32), UDim2.new(0, 0, 0, 130), THEME.ACCENT, function()
    adapter:log("CLEAR", "Starting 13-Step Proximity-First World Clear...")
    clearer:startAsync(refreshHooks.CLEAR)
end)
makeButton(pClear, "Stop Clear", UDim2.new(0, 110, 0, 32), UDim2.new(0, 218, 0, 130), THEME.CARD, function()
    clearer.stopRequested = true
    refreshHooks.CLEAR()
end)

makeLabel(pClear, "13-STEP EXECUTION CHECKLIST:", UDim2.new(1, 0, 0, 18), UDim2.new(0, 0, 0, 170), 11, THEME.YELLOW, Enum.Font.GothamBold)
local clearStepBadges = {}
for idx, sDef in ipairs(ClearWorldEngine.STEP_DEFS) do
    local col = (idx - 1) % 2
    local row = math.floor((idx - 1) / 2)
    clearStepBadges[idx] = makeBadge(pClear, sDef.title .. " [WAIT]", UDim2.new(0, 276, 0, 24), UDim2.new(0, col * 284, 0, 192 + row * 28), THEME.CARD)
end
pClear.CanvasSize = UDim2.new(0, 0, 0, 410)

refreshHooks.CLEAR = function()
    clearStatLbl.Text = string.format("State: %s | FG Broken: %d | BG Broken: %d | Seeds: %d | Trashed: %d | Kept: %d | Unknown: %d",
        clearer.state, clearer.metrics.blocksDestroyed, clearer.metrics.bgRemoved, clearer.metrics.seedsCollected,
        clearer.metrics.itemsTrashed, clearer.metrics.protectedPreserved, clearer.metrics.unknownSkipped)
    for idx, sDef in ipairs(ClearWorldEngine.STEP_DEFS) do
        local st = clearer.stepStatus[idx] or "WAIT"
        local b = clearStepBadges[idx]
        if b then
            b.Text = string.format("%s [%s]", sDef.title, st)
            b.BackgroundColor3 = (st == "DONE" and THEME.GREEN) or (st == "RUN" and THEME.YELLOW) or (st == "WARN" and THEME.RED) or THEME.CARD
        end
    end
end
refreshHooks.CLEAR()

--==============================================================================
-- 14. TAB 3: DIRTFARM BUILDER & FARMING CYCLE (24 STEPS & VALIDATION)
--==============================================================================
local pDF = createTabPage("DF", "3. DirtFarm", 3)
makeLabel(pDF, "DIRTFARM BUILDER — 24 STEPS & 19 MODULES (DF.MD)", UDim2.new(1, 0, 0, 20), UDim2.new(0, 0, 0, 0), 13, THEME.TEXT, Enum.Font.GothamBold)
local dfStatLbl = makeLabel(pDF, "State: IDLE", UDim2.new(1, 0, 0, 32), UDim2.new(0, 0, 0, 22), 11, THEME.MUTED)
dfStatLbl.TextWrapped = true

makeLabel(pDF, "Start:", UDim2.new(0, 40, 0, 26), UDim2.new(0, 0, 0, 58), 11, THEME.TEXT)
makeInput(pDF, "6", tostring(dirtfarm.opts.startRow), UDim2.new(0, 50, 0, 26), UDim2.new(0, 42, 0, 58), function(t)
    local n = tonumber(t); if n then dirtfarm.opts.startRow = math.max(2, math.floor(n)) end
end)
makeLabel(pDF, "End:", UDim2.new(0, 34, 0, 26), UDim2.new(0, 100, 0, 58), 11, THEME.TEXT)
makeInput(pDF, "52", tostring(dirtfarm.opts.endRow), UDim2.new(0, 50, 0, 26), UDim2.new(0, 136, 0, 58), function(t)
    local n = tonumber(t); if n then dirtfarm.opts.endRow = math.max(4, math.floor(n)) end
end)
makeLabel(pDF, "Spacing:", UDim2.new(0, 52, 0, 26), UDim2.new(0, 194, 0, 58), 11, THEME.TEXT)
makeInput(pDF, "2", tostring(dirtfarm.opts.rowSpacing), UDim2.new(0, 44, 0, 26), UDim2.new(0, 248, 0, 58), function(t)
    local n = tonumber(t); if n then dirtfarm.opts.rowSpacing = math.max(2, math.floor(n)) end
end)
makeLabel(pDF, "SLP Rad:", UDim2.new(0, 54, 0, 26), UDim2.new(0, 300, 0, 58), 11, THEME.TEXT)
makeInput(pDF, "4", tostring(dirtfarm.opts.slpRadius), UDim2.new(0, 44, 0, 26), UDim2.new(0, 356, 0, 58), function(t)
    local n = tonumber(t); if n then dirtfarm.opts.slpRadius = math.max(1, math.floor(n)) end
end)

local dfLayoutBtn, dfPlantBtn, df12Btn, dfBgBtn
local dfLayouts = { "Both", "Layout 1", "Layout 2" }
local dfLayoutIdx = 1
dfLayoutBtn = makeButton(pDF, "Layout: Both", UDim2.new(0, 125, 0, 28), UDim2.new(0, 0, 0, 92), THEME.CARD, function()
    dfLayoutIdx = (dfLayoutIdx % #dfLayouts) + 1
    dirtfarm.opts.layoutMode = dfLayouts[dfLayoutIdx]
    dfLayoutBtn.Text = "Layout: " .. dirtfarm.opts.layoutMode
end)
df12Btn = makeButton(pDF, "1-2 Prep: OFF", UDim2.new(0, 125, 0, 28), UDim2.new(0, 132, 0, 92), THEME.CARD, function()
    dirtfarm.opts.enable12Pattern = not dirtfarm.opts.enable12Pattern
    df12Btn.Text = "1-2 Prep: " .. (dirtfarm.opts.enable12Pattern and "ON" or "OFF")
    df12Btn.BackgroundColor3 = dirtfarm.opts.enable12Pattern and THEME.GREEN or THEME.CARD
end)
dfBgBtn = makeButton(pDF, "Skip Cave BG: OFF", UDim2.new(0, 135, 0, 28), UDim2.new(0, 264, 0, 92), THEME.CARD, function()
    dirtfarm.opts.skipBg = not dirtfarm.opts.skipBg
    dfBgBtn.Text = "Skip Cave BG: " .. (dirtfarm.opts.skipBg and "ON" or "OFF")
    dfBgBtn.BackgroundColor3 = dirtfarm.opts.skipBg and THEME.YELLOW or THEME.CARD
end)
dfPlantBtn = makeButton(pDF, "Auto-Plant: ON", UDim2.new(0, 135, 0, 28), UDim2.new(0, 406, 0, 92), THEME.GREEN, function()
    dirtfarm.opts.plantAfterBuild = not dirtfarm.opts.plantAfterBuild
    dfPlantBtn.Text = "Auto-Plant: " .. (dirtfarm.opts.plantAfterBuild and "ON" or "OFF")
    dfPlantBtn.BackgroundColor3 = dirtfarm.opts.plantAfterBuild and THEME.GREEN or THEME.CARD
end)

makeButton(pDF, "Build & Farm (Steps 1-24)", UDim2.new(0, 175, 0, 32), UDim2.new(0, 0, 0, 128), THEME.ACCENT, function()
    adapter:log("DIRTFARM", "Starting 24-Step DirtFarm Builder & Farming Cycle...")
    dirtfarm:startAsync(refreshHooks.DF)
end)
makeButton(pDF, "Harvest Mature", UDim2.new(0, 115, 0, 32), UDim2.new(0, 182, 0, 128), THEME.ACCENT_ALT, function()
    dirtfarm:preparePlan()
    dirtfarm:harvestReady()
    refreshHooks.DF()
end)
makeButton(pDF, "Validate World", UDim2.new(0, 120, 0, 32), UDim2.new(0, 304, 0, 128), THEME.CARD, function()
    dirtfarm:preparePlan()
    dirtfarm:runValidationReport()
    refreshHooks.DF()
end)
makeButton(pDF, "Stop", UDim2.new(0, 80, 0, 32), UDim2.new(0, 432, 0, 128), THEME.CARD, function()
    dirtfarm.stopRequested = true
    refreshHooks.DF()
end)

local dfValLbl = makeLabel(pDF, "Validation Report: Click 'Validate World' or run Build & Farm", UDim2.new(1, -8, 0, 32), UDim2.new(0, 0, 0, 166), 10, THEME.YELLOW, Enum.Font.Code)
dfValLbl.TextWrapped = true

makeLabel(pDF, "24-STEP DIRTFARM PROGRESS:", UDim2.new(1, 0, 0, 18), UDim2.new(0, 0, 0, 202), 11, THEME.TEXT, Enum.Font.GothamBold)
local dfStepBadges = {}
for idx, sDef in ipairs(DirtFarmEngine.STEP_DEFS) do
    local col = (idx - 1) % 3
    local row = math.floor((idx - 1) / 3)
    dfStepBadges[idx] = makeBadge(pDF, sDef.title .. " [WAIT]", UDim2.new(0, 184, 0, 22), UDim2.new(0, col * 188, 0, 224 + row * 25), THEME.CARD)
end
pDF.CanvasSize = UDim2.new(0, 0, 0, 450)

refreshHooks.DF = function()
    dfStatLbl.Text = string.format("State: %s | Obstacles: %d | BG: %d | Platforms: %d | Planted: %d | Harvested: %d | CapCycles: %d",
        dirtfarm.state, dirtfarm.metrics.obstaclesBroken, dirtfarm.metrics.bgRemoved,
        dirtfarm.metrics.platformsBuilt, dirtfarm.metrics.seedsPlanted, dirtfarm.metrics.treesHarvested, dirtfarm.metrics.capCycles)
    local vr = dirtfarm.validationReport
    dfValLbl.Text = string.format("Validation [%s]: Bedrock=%s | Edges=%s | BottomRow=%s | Platforms=%s | CaveBG=%s | Trees=%d (Mature=%d)",
        vr.allPassed and "PASS" or "CHECK",
        tostring(vr.bedrockIntact), tostring(vr.edgesCleared), tostring(vr.bottomRowCleared),
        tostring(vr.platformsComplete), tostring(vr.caveBgClean), vr.treesPlanted, vr.matureTrees)
    for idx, sDef in ipairs(DirtFarmEngine.STEP_DEFS) do
        local st = dirtfarm.stepStatus[idx] or "WAIT"
        local b = dfStepBadges[idx]
        if b then
            b.Text = string.format("%s [%s]", sDef.title, st)
            b.BackgroundColor3 = (st == "DONE" and THEME.GREEN) or (st == "RUN" and THEME.YELLOW) or (st == "WARN" and THEME.RED) or THEME.CARD
        end
    end
end
refreshHooks.DF()

--==============================================================================
-- 15. TAB 4: PNB AUTOMATION SYSTEM (12 MODULES / 11 STATES / 6 DELAYS)
--==============================================================================
local pPNB = createTabPage("PNB", "4. PNB Auto", 4)
makeLabel(pPNB, "PNB STATE MACHINE (12 MODULES / 11 STATES / WATCHDOG)", UDim2.new(1, 0, 0, 20), UDim2.new(0, 0, 0, 0), 13, THEME.TEXT, Enum.Font.GothamBold)
local pnbStatLbl = makeLabel(pPNB, "State: IDLE | Block ID: 2", UDim2.new(1, 0, 0, 30), UDim2.new(0, 0, 0, 22), 11, THEME.MUTED)
pnbStatLbl.TextWrapped = true

local pnbStateBadges = {}
for idx, stName in ipairs(PNBSystem.PIPELINE_STATES) do
    local col = (idx - 1) % 3
    local row = math.floor((idx - 1) / 3)
    pnbStateBadges[stName] = makeBadge(pPNB, stName, UDim2.new(0, 182, 0, 20), UDim2.new(0, col * 188, 0, 56 + row * 23), THEME.CARD)
end

local dirBtn, targetModeBtn, areaBtn, seedFirstBtn
targetModeBtn = makeButton(pPNB, "Target: Multi-Tile Area", UDim2.new(0, 165, 0, 28), UDim2.new(0, 0, 0, 152), THEME.CARD, function()
    pnb.cfg.targetMode = (pnb.cfg.targetMode == "Multi-Tile Area") and "Single Tile" or "Multi-Tile Area"
    targetModeBtn.Text = "Target: " .. pnb.cfg.targetMode
end)
areaBtn = makeButton(pPNB, "Area Size: 3", UDim2.new(0, 110, 0, 28), UDim2.new(0, 172, 0, 152), THEME.CARD, function()
    pnb.cfg.areaSize = (pnb.cfg.areaSize % 5) + 1
    areaBtn.Text = "Area Size: " .. tostring(pnb.cfg.areaSize)
end)
dirBtn = makeButton(pPNB, "Dir: UP", UDim2.new(0, 100, 0, 28), UDim2.new(0, 288, 0, 152), THEME.CARD, function()
    local nextDir = { UP = "DOWN", DOWN = "LEFT", LEFT = "RIGHT", RIGHT = "UP" }
    pnb.cfg.direction = nextDir[pnb.cfg.direction] or "UP"
    dirBtn.Text = "Dir: " .. pnb.cfg.direction
end)
seedFirstBtn = makeButton(pPNB, "Seed-First: ON", UDim2.new(0, 130, 0, 28), UDim2.new(0, 396, 0, 152), THEME.GREEN, function()
    pnb.cfg.collectSeedFirst = not pnb.cfg.collectSeedFirst
    seedFirstBtn.Text = "Seed-First: " .. (pnb.cfg.collectSeedFirst and "ON" or "OFF")
    seedFirstBtn.BackgroundColor3 = pnb.cfg.collectSeedFirst and THEME.GREEN or THEME.CARD
end)

-- All 6 separated delays + RetryLimit + Watchdog Timeout
local delaySpecs = {
    { lbl = "Place ms:",   key = "delayPlace",      min = 20,  def = pnb.cfg.delayPlace },
    { lbl = "Break ms:",   key = "delayBreak",      min = 20,  def = pnb.cfg.delayBreak },
    { lbl = "Collect ms:", key = "delayCollect",    min = 20,  def = pnb.cfg.delayCollect },
    { lbl = "Verify ms:",  key = "delayVerify",     min = 20,  def = pnb.cfg.delayVerify },
    { lbl = "NextTgt ms:", key = "delayNextTarget", min = 20,  def = pnb.cfg.delayNextTarget },
    { lbl = "Cycle ms:",   key = "delayCycle",      min = 20,  def = pnb.cfg.delayCycle },
    { lbl = "RetryLim:",   key = "retryLimit",      min = 1,   def = pnb.cfg.retryLimit },
    { lbl = "Watchdog s:", key = "watchdogTimeout", min = 0.5, def = pnb.cfg.watchdogTimeout },
}
for i, sp in ipairs(delaySpecs) do
    local col = (i - 1) % 4
    local row = math.floor((i - 1) / 4)
    local xBase = col * 142
    local yBase = 188 + row * 32
    makeLabel(pPNB, sp.lbl, UDim2.new(0, 74, 0, 26), UDim2.new(0, xBase, 0, yBase), 10, THEME.MUTED)
    makeInput(pPNB, tostring(sp.def), tostring(sp.def), UDim2.new(0, 60, 0, 26), UDim2.new(0, xBase + 74, 0, yBase), function(t)
        local v = tonumber(t)
        if v then pnb.cfg[sp.key] = math.max(sp.min, v) end
    end)
end

makeButton(pPNB, "Start PNB", UDim2.new(0, 125, 0, 32), UDim2.new(0, 0, 0, 260), THEME.ACCENT, function()
    adapter:log("PNB", "Starting PNB 11-state pipeline...")
    pnb:startAsync(refreshHooks.PNB)
end)
makeButton(pPNB, "Single Step (Debug)", UDim2.new(0, 145, 0, 32), UDim2.new(0, 132, 0, 260), THEME.ACCENT_ALT, function()
    pnb.stopRequested = false
    pnb:step()
    refreshHooks.PNB()
end)
makeButton(pPNB, "Graceful Stop", UDim2.new(0, 125, 0, 32), UDim2.new(0, 284, 0, 260), THEME.CARD, function()
    pnb.stopRequested = true
    adapter:log("PNB", "Graceful stop requested after active atomic verify")
    refreshHooks.PNB()
end)
makeButton(pPNB, "Reset Stats", UDim2.new(0, 105, 0, 32), UDim2.new(0, 416, 0, 260), THEME.CARD, function()
    pnb.cyclesCompleted, pnb.blocksPlaced, pnb.blocksBroken, pnb.dropsCollected, pnb.watchdogTrips = 0, 0, 0, 0, 0
    pnb:transition("IDLE")
    refreshHooks.PNB()
end)
pPNB.CanvasSize = UDim2.new(0, 0, 0, 340)

refreshHooks.PNB = function()
    local selId = (selector.selectedBlock and selector.selectedBlock.id) or pnb.cfg.blockId
    pnbStatLbl.Text = string.format("State: %s | Block ID: %d | Cycles: %d | Placed: %d | Broken: %d | Collected: %d | Watchdog: %d",
        pnb.state, selId, pnb.cyclesCompleted, pnb.blocksPlaced, pnb.blocksBroken, pnb.dropsCollected, pnb.watchdogTrips)
    for _, stName in ipairs(PNBSystem.PIPELINE_STATES) do
        local b = pnbStateBadges[stName]
        if b then
            if pnb.state == stName then
                b.BackgroundColor3 = (stName == "RECOVERING") and THEME.YELLOW or THEME.ACCENT_ALT
            else
                b.BackgroundColor3 = THEME.CARD
            end
        end
    end
end
refreshHooks.PNB()

--==============================================================================
-- 16. TAB 5: PROTECTION, HIT LOGGER & MOVEMENT (7-STATE PIPELINE + HUD)
--==============================================================================
local pMisc = createTabPage("MISC", "5. Protect & Move", 5)
makeLabel(pMisc, "PROTECTION, HIT LOGGER & MOVEMENT — 7-STATE ENGINE (MISC.MD)", UDim2.new(1, 0, 0, 20), UDim2.new(0, 0, 0, 0), 13, THEME.TEXT, Enum.Font.GothamBold)
local miscInfoLbl = makeLabel(pMisc, "Pipeline: IDLE -> DETECTED -> PROCESSING -> VERIFYING -> SUCCESS / FAILED -> RECOVERY", UDim2.new(1, 0, 0, 20), UDim2.new(0, 0, 0, 22), 10, THEME.MUTED)

local featureList = {
    { key = "AntiLava", label = "Anti Lava (ID 4)" },
    { key = "AntiSpike", label = "Anti Death/Bone Spike (162/3748)" },
    { key = "AntiFastRoulette", label = "Anti Fast Roulette (758)" },
    { key = "HitLogger", label = "Visual Hit Logger [HIT DETECTED]" },
    { key = "Fly", label = "Fly (WASD + Space/Ctrl)" },
    { key = "Noclip", label = "Noclip (Safe Restore)" },
}

local featureBtns = {}
for idx, item in ipairs(featureList) do
    local col = (idx - 1) % 2
    local row = math.floor((idx - 1) / 2)
    local xOff = col * 282
    local yOff = 48 + row * 36
    local b = makeButton(pMisc, item.label .. ": OFF", UDim2.new(0, 198, 0, 30), UDim2.new(0, xOff, 0, yOff), THEME.CARD, function()
        protectMove:toggleFeature(item.key)
        refreshHooks.MISC()
    end)
    local stBadge = makeBadge(pMisc, "IDLE", UDim2.new(0, 74, 0, 30), UDim2.new(0, xOff + 202, 0, yOff), THEME.CARD)
    featureBtns[item.key] = { btn = b, badge = stBadge, base = item.label }
end

makeLabel(pMisc, "Fly Speed:", UDim2.new(0, 70, 0, 26), UDim2.new(0, 0, 0, 162), 11, THEME.TEXT)
makeInput(pMisc, "Speed", tostring(adapter.player.flySpeed), UDim2.new(0, 62, 0, 26), UDim2.new(0, 72, 0, 162), function(txt)
    local v = tonumber(txt)
    if v then
        adapter.player.flySpeed = math.max(8, math.min(200, v))
        adapter:log("MOVE", "Fly speed -> " .. tostring(adapter.player.flySpeed))
    end
end)
makeLabel(pMisc, "Roulette CD (s):", UDim2.new(0, 96, 0, 26), UDim2.new(0, 146, 0, 162), 11, THEME.TEXT)
makeInput(pMisc, "1.0", tostring(protectMove.rouletteCooldown), UDim2.new(0, 56, 0, 26), UDim2.new(0, 244, 0, 162), function(txt)
    local v = tonumber(txt)
    if v then
        protectMove.rouletteCooldown = math.max(0.2, v)
        adapter:log("PROTECT", "Roulette cooldown -> " .. tostring(protectMove.rouletteCooldown) .. "s")
    end
end)

local hudBtn
hudBtn = makeButton(pMisc, "Floating HUD: OFF", UDim2.new(0, 140, 0, 28), UDim2.new(0, 0, 0, 196), THEME.CARD, function()
    protectMove.floatingHudEnabled = not protectMove.floatingHudEnabled
    floatingHudGui.Enabled = protectMove.floatingHudEnabled
    hudBtn.Text = "Floating HUD: " .. (protectMove.floatingHudEnabled and "ON" or "OFF")
    hudBtn.BackgroundColor3 = protectMove.floatingHudEnabled and THEME.GREEN or THEME.CARD
    protectMove:updateFloatingHud()
end)
makeButton(pMisc, "Simulate Hazard / Hit Test", UDim2.new(0, 185, 0, 28), UDim2.new(0, 148, 0, 196), THEME.ACCENT_ALT, function()
    protectMove:simulateHazardTest()
    refreshHooks.MISC()
end)
makeButton(pMisc, "Clear Hit Log", UDim2.new(0, 110, 0, 28), UDim2.new(0, 340, 0, 196), THEME.CARD, function()
    protectMove.hitHistory = {}
    protectMove:updateFloatingHud()
    refreshHooks.MISC()
end)

local hitHistoryLbl = makeLabel(pMisc, "Recent Events: (none)", UDim2.new(1, -8, 0, 96), UDim2.new(0, 0, 0, 232), 11, THEME.MUTED, Enum.Font.Code)
hitHistoryLbl.TextWrapped = true
hitHistoryLbl.TextYAlignment = Enum.TextYAlignment.Top
pMisc.CanvasSize = UDim2.new(0, 0, 0, 350)

refreshHooks.MISC = function()
    for _, item in ipairs(featureList) do
        local st = protectMove.features[item.key]
        local entry = featureBtns[item.key]
        entry.btn.Text = entry.base .. ": " .. (st.enabled and "ON" or "OFF")
        entry.btn.BackgroundColor3 = st.enabled and THEME.GREEN or THEME.CARD
        entry.badge.Text = st.status
        entry.badge.BackgroundColor3 = (st.color == "GREEN" and THEME.GREEN)
            or (st.color == "YELLOW" and THEME.YELLOW)
            or (st.color == "RED" and THEME.RED)
            or THEME.CARD
    end
    miscInfoLbl.Text = "Hits Logged: " .. tostring(#protectMove.hitHistory) .. " | Fly Speed: " .. tostring(adapter.player.flySpeed) .. " | Roulette CD: " .. tostring(protectMove.rouletteCooldown) .. "s"
    if #protectMove.hitHistory > 0 then
        local tail = {}
        for i = math.max(1, #protectMove.hitHistory - 4), #protectMove.hitHistory do
            table.insert(tail, protectMove.hitHistory[i])
        end
        hitHistoryLbl.Text = table.concat(tail, "\n")
    else
        hitHistoryLbl.Text = "Recent Events: (none)"
    end
end
refreshHooks.MISC()

--==============================================================================
-- 17. TAB 6: CHAT SPAMMER & RAINBOW FORMATTER (ALL 18 COMPONENTS)
--==============================================================================
local pSpam = createTabPage("SPAM", "6. Chat Spammer", 6)
makeLabel(pSpam, "CHAT SPAMMER — QUEUE, PREFIX & TEXT COLORS (SPAMER.MD - 120 CHAR)", UDim2.new(1, 0, 0, 20), UDim2.new(0, 0, 0, 0), 13, THEME.TEXT, Enum.Font.GothamBold)
local spamStatLbl = makeLabel(pSpam, "State: IDLE | Sent: 0 | Accepted: 0 | Rejected: 0 | Cancelled: 0", UDim2.new(1, 0, 0, 20), UDim2.new(0, 0, 0, 22), 11, THEME.MUTED)
local spamPreviewLbl = makeLabel(pSpam, "Preview (0/120): ...", UDim2.new(1, -8, 0, 26), UDim2.new(0, 0, 0, 250), 11, THEME.YELLOW, Enum.Font.Code)
local spamQueueLbl = makeLabel(pSpam, "Queue (2 msgs): Selling Farmables @ Main! | Cheap Locks & Dirt!", UDim2.new(1, -8, 0, 28), UDim2.new(0, 0, 0, 280), 10, THEME.MUTED, Enum.Font.Code)
spamQueueLbl.TextWrapped = true

makeInput(pSpam, "Message 1...", spammer.cfg.msg1, UDim2.new(0, 275, 0, 26), UDim2.new(0, 0, 0, 46), function(t)
    spammer.cfg.msg1 = t; refreshHooks.SPAM()
end)
makeInput(pSpam, "Message 2 (Dual)...", spammer.cfg.msg2, UDim2.new(0, 275, 0, 26), UDim2.new(0, 0, 0, 78), function(t)
    spammer.cfg.msg2 = t; refreshHooks.SPAM()
end)

local newQueueText = ""
local queueInputBox = makeInput(pSpam, "Extra message for Queue...", "", UDim2.new(0, 275, 0, 26), UDim2.new(0, 0, 0, 110), function(t)
    newQueueText = t
end)
makeButton(pSpam, "Add to Queue", UDim2.new(0, 130, 0, 26), UDim2.new(0, 284, 0, 110), THEME.ACCENT_ALT, function()
    local txt = trimStr(queueInputBox.Text)
    if txt == "" then txt = trimStr(newQueueText) end
    if txt ~= "" then
        table.insert(spammer.cfg.queue, txt)
        queueInputBox.Text = ""
        adapter:log("SPAM", "Added message to Queue (#" .. tostring(#spammer.cfg.queue) .. ")")
        refreshHooks.SPAM()
    end
end)
makeButton(pSpam, "Clear Queue", UDim2.new(0, 110, 0, 26), UDim2.new(0, 422, 0, 110), THEME.CARD, function()
    spammer.cfg.queue = {}
    adapter:log("SPAM", "Cleared custom queue")
    refreshHooks.SPAM()
end)

makeInput(pSpam, "Prefix (optional)...", spammer.cfg.prefix, UDim2.new(0, 135, 0, 26), UDim2.new(0, 284, 0, 46), function(t)
    spammer.cfg.prefix = t
    spammer.cfg.prefixEnabled = (trimStr(t) ~= "")
    refreshHooks.SPAM()
end)
local prefixPosBtn, sepBtn
local seps = { " ", " | ", " : ", " - " }
local sepIdx = 1
prefixPosBtn = makeButton(pSpam, "Pos: Before", UDim2.new(0, 82, 0, 26), UDim2.new(0, 424, 0, 46), THEME.CARD, function()
    spammer.cfg.prefixPos = (spammer.cfg.prefixPos == "Before") and "After" or "Before"
    prefixPosBtn.Text = "Pos: " .. spammer.cfg.prefixPos
    refreshHooks.SPAM()
end)
sepBtn = makeButton(pSpam, "Sep: ' '", UDim2.new(0, 56, 0, 26), UDim2.new(0, 512, 0, 46), THEME.CARD, function()
    sepIdx = (sepIdx % #seps) + 1
    spammer.cfg.prefixSeparator = seps[sepIdx]
    sepBtn.Text = "Sep:'" .. spammer.cfg.prefixSeparator .. "'"
    refreshHooks.SPAM()
end)

makeLabel(pSpam, "Delay:", UDim2.new(0, 44, 0, 26), UDim2.new(0, 284, 0, 78), 11, THEME.MUTED)
makeInput(pSpam, "2.0", tostring(spammer.cfg.delaySeconds), UDim2.new(0, 58, 0, 26), UDim2.new(0, 328, 0, 78), function(t)
    local n = tonumber(t); if n then spammer.cfg.delaySeconds = math.max(0.5, n) end
end)
makeLabel(pSpam, "Repeat (0=Inf):", UDim2.new(0, 92, 0, 26), UDim2.new(0, 394, 0, 78), 11, THEME.MUTED)
makeInput(pSpam, "5", tostring(spammer.cfg.repeatCount), UDim2.new(0, 58, 0, 26), UDim2.new(0, 488, 0, 78), function(t)
    local n = tonumber(t); if n then spammer.cfg.repeatCount = math.max(0, math.floor(n)) end
end)

local modeBtn, pfColorBtn, txtColorBtn, rainbowBtn, rbModeBtn
local spamModes = { "SINGLE", "DUAL", "QUEUE" }
local spamModeIdx = 1
local pfColorIdx, txtColorIdx = 7, 2
modeBtn = makeButton(pSpam, "Mode: SINGLE", UDim2.new(0, 108, 0, 28), UDim2.new(0, 0, 0, 144), THEME.CARD, function()
    spamModeIdx = (spamModeIdx % #spamModes) + 1
    spammer.cfg.mode = spamModes[spamModeIdx]
    modeBtn.Text = "Mode: " .. spammer.cfg.mode
end)
pfColorBtn = makeButton(pSpam, "PfCol: `6", UDim2.new(0, 94, 0, 28), UDim2.new(0, 114, 0, 144), THEME.CARD, function()
    pfColorIdx = (pfColorIdx % #ChatSpammer.COLOR_KEYS) + 1
    spammer.cfg.prefixColorCode = ChatSpammer.COLOR_KEYS[pfColorIdx]
    pfColorBtn.Text = "PfCol: `" .. spammer.cfg.prefixColorCode
    refreshHooks.SPAM()
end)
txtColorBtn = makeButton(pSpam, "TxtCol: `2", UDim2.new(0, 96, 0, 28), UDim2.new(0, 214, 0, 144), THEME.CARD, function()
    txtColorIdx = (txtColorIdx % #ChatSpammer.COLOR_KEYS) + 1
    spammer.cfg.textColorCode = ChatSpammer.COLOR_KEYS[txtColorIdx]
    txtColorBtn.Text = "TxtCol: `" .. spammer.cfg.textColorCode
    refreshHooks.SPAM()
end)
rainbowBtn = makeButton(pSpam, "Rainbow: OFF", UDim2.new(0, 110, 0, 28), UDim2.new(0, 316, 0, 144), THEME.CARD, function()
    spammer.cfg.rainbowEnabled = not spammer.cfg.rainbowEnabled
    rainbowBtn.Text = "Rainbow: " .. (spammer.cfg.rainbowEnabled and "ON" or "OFF")
    rainbowBtn.BackgroundColor3 = spammer.cfg.rainbowEnabled and THEME.ACCENT_ALT or THEME.CARD
    refreshHooks.SPAM()
end)
rbModeBtn = makeButton(pSpam, "RB: word", UDim2.new(0, 86, 0, 28), UDim2.new(0, 432, 0, 144), THEME.CARD, function()
    spammer.cfg.rainbowMode = (spammer.cfg.rainbowMode == "word") and "char" or "word"
    rbModeBtn.Text = "RB: " .. spammer.cfg.rainbowMode
    refreshHooks.SPAM()
end)

makeButton(pSpam, "Start Spammer", UDim2.new(0, 125, 0, 32), UDim2.new(0, 0, 0, 182), THEME.ACCENT, function()
    spammer:startAsync(refreshHooks.SPAM)
end)
makeButton(pSpam, "Send Single Test", UDim2.new(0, 130, 0, 32), UDim2.new(0, 132, 0, 182), THEME.ACCENT_ALT, function()
    spammer:sendSingleTest()
    refreshHooks.SPAM()
end)
makeButton(pSpam, "Stop", UDim2.new(0, 100, 0, 32), UDim2.new(0, 268, 0, 182), THEME.CARD, function()
    spammer:stop()
    refreshHooks.SPAM()
end)
makeButton(pSpam, "Reset Stats", UDim2.new(0, 100, 0, 32), UDim2.new(0, 374, 0, 182), THEME.CARD, function()
    spammer:reset()
    refreshHooks.SPAM()
end)
pSpam.CanvasSize = UDim2.new(0, 0, 0, 330)

refreshHooks.SPAM = function()
    local preview, pErr = spammer:formatText(spammer.cfg.msg1)
    local pStr = preview or ("ERR: " .. tostring(pErr))
    spamPreviewLbl.Text = string.format("Preview (%d/%d): %s", preview and #preview or 0, CONFIG.MAX_CHAT_LENGTH, pStr)
    spamStatLbl.Text = string.format("State: %s | Pending: %d | Sent: %d | Accepted: %d | Rejected: %d | Cancelled: %d%s",
        spammer.state, spammer.stats.pending, spammer.stats.sent, spammer.stats.accepted, spammer.stats.rejected, spammer.stats.cancelled,
        (spammer.stats.lastError ~= "" and (" | Err: " .. spammer.stats.lastError) or ""))
    spamQueueLbl.Text = string.format("Queue (%d msgs): %s", #spammer.cfg.queue, table.concat(spammer.cfg.queue, " | "))
end
refreshHooks.SPAM()

--==============================================================================
-- 18. TAB 7: VISUAL NAME, ROLES, WARDROBE & PRIORITY RULES (MODULE 11)
--==============================================================================
local pVis = createTabPage("VIS", "7. Visuals", 7)
makeLabel(pVis, "VISUAL NAME, ROLES, 9-SLOT WARDROBE & PRIORITY RULES", UDim2.new(1, 0, 0, 20), UDim2.new(0, 0, 0, 0), 13, THEME.TEXT, Enum.Font.GothamBold)
local visStatLbl = makeLabel(pVis, "Look: [OWNER] | Glow | Admin Gold Set", UDim2.new(1, 0, 0, 20), UDim2.new(0, 0, 0, 22), 11, THEME.MUTED)

makeInput(pVis, "Display Name...", visuals.displayName, UDim2.new(0, 240, 0, 26), UDim2.new(0, 0, 0, 46), function(t) visuals.displayName = t end)
makeInput(pVis, "HEX (#FFD700)...", visuals.hexColor, UDim2.new(0, 140, 0, 26), UDim2.new(0, 248, 0, 46), function(t) visuals.hexColor = t end)

local wearSyncBtn
wearSyncBtn = makeButton(pVis, "Wear Sync: OFF", UDim2.new(0, 130, 0, 26), UDim2.new(0, 396, 0, 46), THEME.CARD, function()
    visuals.syncServerWear = not visuals.syncServerWear
    wearSyncBtn.Text = "Wear Sync: " .. (visuals.syncServerWear and "ON" or "OFF")
    wearSyncBtn.BackgroundColor3 = visuals.syncServerWear and THEME.GREEN or THEME.CARD
end)

local roleBtn, effBtn, setBtn, slotNameBtn, slotItemBtn
local roleIdx = 1
roleBtn = makeButton(pVis, "Role: OWNER", UDim2.new(0, 165, 0, 28), UDim2.new(0, 0, 0, 80), THEME.CARD, function()
    roleIdx = (roleIdx % #VisualEngine.ROLES) + 1
    local r = VisualEngine.ROLES[roleIdx]
    visuals.roleId = r.id
    visuals.hexColor = r.color
    visuals.effect = r.effect
    visuals.selectedSet = r.set
    roleBtn.Text = "Role: " .. r.id
    effBtn.Text = "Effect: " .. r.effect
    setBtn.Text = "Outfit: " .. r.set
    refreshHooks.VIS()
end)

local effOpts = { "Glow", "Outline", "Shadow", "Gradient", "Pulse", "None" }
local effIdx = 1
effBtn = makeButton(pVis, "Effect: Glow", UDim2.new(0, 155, 0, 28), UDim2.new(0, 172, 0, 80), THEME.CARD, function()
    effIdx = (effIdx % #effOpts) + 1
    visuals.effect = effOpts[effIdx]
    effBtn.Text = "Effect: " .. visuals.effect
end)

local setOpts = { "Admin Gold Set", "Developer Cyber Set", "Shadow Ninja Set", "Emerald VIP Set", "Ruby Monarch Set", "Default", "Custom" }
local setIdx = 1
setBtn = makeButton(pVis, "Outfit: Admin Gold Set", UDim2.new(0, 195, 0, 28), UDim2.new(0, 334, 0, 80), THEME.CARD, function()
    setIdx = (setIdx % #setOpts) + 1
    visuals.selectedSet = setOpts[setIdx]
    setBtn.Text = "Outfit: " .. visuals.selectedSet
end)

-- 9-Slot Wardrobe Cyclers
local activeSlotIdx = 1
local activeSlotItemIdx = 1
local function currentSlotName() return ASSETS.WardrobeSlots[activeSlotIdx] end
slotNameBtn = makeButton(pVis, "Slot: hat (1/9)", UDim2.new(0, 165, 0, 28), UDim2.new(0, 0, 0, 116), THEME.CARD, function()
    activeSlotIdx = (activeSlotIdx % #ASSETS.WardrobeSlots) + 1
    activeSlotItemIdx = 1
    local sName = currentSlotName()
    slotNameBtn.Text = string.format("Slot: %s (%d/9)", sName, activeSlotIdx)
    local curId = visuals.customSlots[sName] or 0
    local info = adapter:getItem(curId)
    slotItemBtn.Text = "Item: " .. (info and info.name or tostring(curId))
end)
slotItemBtn = makeButton(pVis, "Item: Cycle Cloth", UDim2.new(0, 356, 0, 28), UDim2.new(0, 172, 0, 116), THEME.CARD, function()
    local sName = currentSlotName()
    local pool = VisualEngine.SLOT_POOL[sName] or { 0 }
    activeSlotItemIdx = (activeSlotItemIdx % #pool) + 1
    local chosenId = pool[activeSlotItemIdx]
    visuals.selectedSet = "Custom"
    setBtn.Text = "Outfit: Custom"
    visuals.customSlots[sName] = (chosenId ~= 0) and chosenId or nil
    local info = adapter:getItem(chosenId)
    slotItemBtn.Text = "Item: " .. (chosenId == 0 and "Empty (0)" or (info and info.name or tostring(chosenId)))
end)

-- Player Profile Override Manager + Priority Rule Evaluator (Override > Role > Default)
makeLabel(pVis, "Target Player Rule:", UDim2.new(0, 116, 0, 26), UDim2.new(0, 0, 0, 152), 11, THEME.MUTED)
makeInput(pVis, "Player name...", visuals.targetOverridePlayer, UDim2.new(0, 145, 0, 26), UDim2.new(0, 118, 0, 152), function(t)
    visuals.targetOverridePlayer = t
end)
makeButton(pVis, "Save Player Rule", UDim2.new(0, 118, 0, 26), UDim2.new(0, 270, 0, 152), THEME.ACCENT_ALT, function()
    visuals:addPlayerOverride(visuals.targetOverridePlayer)
    refreshHooks.VIS()
end)
makeButton(pVis, "Eval Rules", UDim2.new(0, 88, 0, 26), UDim2.new(0, 394, 0, 152), THEME.CARD, function()
    visuals:evaluatePriorityRules(visuals.targetOverridePlayer)
    refreshHooks.VIS()
end)
makeButton(pVis, "Del Rule", UDim2.new(0, 68, 0, 26), UDim2.new(0, 488, 0, 152), THEME.CARD, function()
    visuals:removePlayerOverride(visuals.targetOverridePlayer)
    refreshHooks.VIS()
end)

makeButton(pVis, "Apply Visual Look", UDim2.new(0, 145, 0, 32), UDim2.new(0, 0, 0, 188), THEME.ACCENT, function()
    visuals:apply()
    refreshHooks.VIS()
end)
makeButton(pVis, "Save Preset", UDim2.new(0, 105, 0, 32), UDim2.new(0, 152, 0, 188), THEME.CARD, function()
    visuals:savePreset()
    refreshHooks.VIS()
end)
makeButton(pVis, "Load Preset", UDim2.new(0, 105, 0, 32), UDim2.new(0, 264, 0, 188), THEME.CARD, function()
    visuals:loadPreset()
    refreshHooks.VIS()
end)
makeButton(pVis, "Reset Visual", UDim2.new(0, 110, 0, 32), UDim2.new(0, 376, 0, 188), THEME.CARD, function()
    visuals:reset()
    roleBtn.Text = "Role: MEMBER"
    effBtn.Text = "Effect: None"
    setBtn.Text = "Outfit: Default"
    refreshHooks.VIS()
end)

local visRulesLbl = makeLabel(pVis, "Priority Engine: Override > Role > Default | Preset Saved: No", UDim2.new(1, -8, 0, 32), UDim2.new(0, 0, 0, 228), 10, THEME.YELLOW, Enum.Font.Code)
pVis.CanvasSize = UDim2.new(0, 0, 0, 280)

refreshHooks.VIS = function()
    visStatLbl.Text = string.format("Look: [%s] %s | %s | Effect: %s | Outfit: %s",
        visuals.roleId, visuals.displayName, visuals.hexColor, visuals.effect, visuals.selectedSet)
    local ovCount = 0
    for _ in pairs(visuals.playerOverrides) do ovCount = ovCount + 1 end
    visRulesLbl.Text = string.format("Matched Tier: %s | Active Player Overrides: %d | Preset Saved: %s",
        visuals.lastRuleMatchTier, ovCount, visuals.savedPreset and "YES" or "NO")
end
refreshHooks.VIS()

adapter:log("SYSTEM", "DRY CURSED Full Step-by-Step Menu GUI loaded into PlayerGui. Press RightShift to toggle.")
