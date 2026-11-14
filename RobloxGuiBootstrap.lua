--[=[
    ============================================================================
    RobloxGuiBootstrap.lua
    Modular, Responsive, High-Efficiency 3-Tab GUI Framework for Roblox (Lua/Luau)
    Designed for Low-End Mobile (HP) to High-End PC | Executor & Studio Ready
    Repo: https://github.com/Mytzcodes/GUIX
    Raw : https://raw.githubusercontent.com/Mytzcodes/GUIX/main/RobloxGuiBootstrap.lua
    ============================================================================

    Features:
      - 3-Tab Architecture:
          * LEFT TAB   : Sidebar Navigation + Brand Logo + Device/Perf Badge
          * CENTER TAB : Main Feature / Menu Content (Dynamic Grid + Pattern)
          * RIGHT TAB  : Live Further Preferences & Quick Shortcuts Panel
      - 1 Top Shortcut Bar:
          * Draggable (Mouse + Touch)
          * [-]  Minimize to draggable floating Shortcut Icon
          * [[]] Maximize / Restore window
          * [X]  Close & full Janitor cleanup
      - Full GameCanvas & Topbar Blocker:
          * Blocks clicks/touches outside menu from reaching the 3D GameCanvas
          * Covers Roblox Topbar inset & optionally toggles CoreGui while open
      - Responsive Auto-Scale:
          * Dynamic UIScale & compact mobile layout adaptation on ViewportSize change
      - Efficiency & Performance Engine:
          * Auto / Low / Medium / High tiers with FPS throttling & Janitor cleanup
      - 14 Reusable Components:
          Button, GridShape, Layout, Card (w/ or w/o Image), Radio, Title,
          Label, Logo, Rendering (3D Viewport / 2D Canvas), Toggle,
          Notifications, Loading, Bar (Progress/Update/Slider/Stat),
          Picker (Color + Add to Preset / Dropdown)
      - Built-in Presets:
          * Default Color Palettes + Custom Color & Add to Preset (JSON persistence)
          * 7 Grids: Grid Modular, Bento Grid, Masonry, Swiss, Golden Ratio Layout,
                     12 Column Grid, Baseline Grid
          * 7 Patterns: F-Pattern, Z-Pattern, Single Column, Multi Column,
                        Split Screen, Full-Blend Hero, Sticky Sidebar
          * 10 Visual Graphics: Minimalist, Maximalism, Editorial, Newspaper,
                                Brutalist Layout, Deconstructed, Collage,
                                Isometric, Card Base, Dashboard Layout
]=]

local Bootstrap = {}
Bootstrap.__index = Bootstrap
Bootstrap.Version = "2.0.0"
Bootstrap.RepoUrl = "https://github.com/Mytzcodes/GUIX"
Bootstrap.RawBasePath = "https://raw.githubusercontent.com/Mytzcodes/GUIX/main/"

function Bootstrap.GetRawUrl(relativePath)
    local clean = tostring(relativePath or ""):gsub("^/+", "")
    return Bootstrap.RawBasePath .. clean
end

--============================================================================--
-- 1. SERVICES & EXECUTOR ENVIRONMENT ABSTRACTION
--============================================================================--

local cloneref = cloneref or function(obj) return obj end
local function getService(name)
    return cloneref(game:GetService(name))
end

local Players = getService("Players")
local RunService = getService("RunService")
local TweenService = getService("TweenService")
local UserInputService = getService("UserInputService")
local StarterGui = getService("StarterGui")
local HttpService = getService("HttpService")
local ContextActionService = getService("ContextActionService")
local CoreGui = nil
pcall(function()
    CoreGui = getService("CoreGui")
end)

local taskLib = task or {
    wait = wait,
    spawn = spawn,
    defer = delay,
}

local function getLocalPlayer()
    local lp = Players.LocalPlayer
    if not lp then
        Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
        lp = Players.LocalPlayer
    end
    return lp
end

local function resolveGuiParent()
    if typeof(gethui) == "function" then
        local ok, hui = pcall(gethui)
        if ok and hui then
            return hui, true
        end
    end
    if CoreGui then
        local ok = pcall(function()
            local probe = Instance.new("Folder")
            probe.Name = "__BootstrapProbe"
            probe.Parent = CoreGui
            probe:Destroy()
        end)
        if ok then
            return CoreGui, false
        end
    end
    local lp = getLocalPlayer()
    return lp:WaitForChild("PlayerGui"), false
end

local function protectScreenGui(gui, fromGethui)
    if fromGethui then
        return
    end
    if syn and typeof(syn.protect_gui) == "function" then
        pcall(syn.protect_gui, gui)
    elseif typeof(protectgui) == "function" then
        pcall(protectgui, gui)
    end
end

local function getViewportSize()
    local cam = workspace.CurrentCamera
    if cam then
        return cam.ViewportSize
    end
    return Vector2.new(1280, 720)
end

--============================================================================--
-- 2. JANITOR & PERFORMANCE ENGINE
--============================================================================--

local Janitor = {}
Janitor.__index = Janitor

function Janitor.new()
    return setmetatable({ _tasks = {} }, Janitor)
end

function Janitor:Add(item, methodName)
    if item == nil then
        return item
    end
    table.insert(self._tasks, { item = item, method = methodName })
    return item
end

function Janitor:Connect(signal, fn)
    local conn = signal:Connect(fn)
    self:Add(conn, "Disconnect")
    return conn
end

function Janitor:Cleanup()
    for i = #self._tasks, 1, -1 do
        local entry = self._tasks[i]
        self._tasks[i] = nil
        local item = entry.item
        local kind = typeof(item)
        if kind == "RBXScriptConnection" then
            if item.Connected then
                pcall(function() item:Disconnect() end)
            end
        elseif kind == "Instance" then
            pcall(function() item:Destroy() end)
        elseif type(item) == "function" then
            pcall(item)
        elseif type(item) == "table" then
            local m = entry.method or "Destroy"
            if type(item[m]) == "function" then
                pcall(item[m], item)
            elseif type(item.Cleanup) == "function" then
                pcall(item.Cleanup, item)
            end
        end
    end
end

function Janitor:Destroy()
    self:Cleanup()
end

local PerformanceTiers = {
    Low = {
        Name = "Low",
        TweenTime = 0,
        UseShadows = false,
        UseGradients = false,
        RenderFps = 12,
        CornerScale = 0.65,
    },
    Medium = {
        Name = "Medium",
        TweenTime = 0.12,
        UseShadows = true,
        UseGradients = true,
        RenderFps = 30,
        CornerScale = 1,
    },
    High = {
        Name = "High",
        TweenTime = 0.2,
        UseShadows = true,
        UseGradients = true,
        RenderFps = 60,
        CornerScale = 1,
    },
}

local function safeTween(inst, props, duration, style, dir)
    if not inst or not inst.Parent then
        return nil
    end
    if not duration or duration <= 0 then
        for k, v in pairs(props) do
            pcall(function() inst[k] = v end)
        end
        return nil
    end
    local info = TweenInfo.new(
        duration,
        style or Enum.EasingStyle.Quart,
        dir or Enum.EasingDirection.Out
    )
    local tw = TweenService:Create(inst, info, props)
    tw:Play()
    return tw
end

--============================================================================--
-- 3. COLOR UTILITIES, DEFAULT PALETTES & CUSTOM PRESET PERSISTENCE
--============================================================================--

local function clamp01(x)
    return math.clamp(x, 0, 1)
end

local function color3ToHex(c)
    return string.format(
        "#%02X%02X%02X",
        math.round(clamp01(c.R) * 255),
        math.round(clamp01(c.G) * 255),
        math.round(clamp01(c.B) * 255)
    )
end

local function hexToColor3(hex)
    local clean = tostring(hex or ""):gsub("#", "")
    if #clean ~= 6 then
        return Color3.fromRGB(99, 102, 241)
    end
    local r = tonumber(clean:sub(1, 2), 16) or 99
    local g = tonumber(clean:sub(3, 4), 16) or 102
    local b = tonumber(clean:sub(5, 6), 16) or 241
    return Color3.fromRGB(r, g, b)
end

local function copyPalette(src)
    local out = {}
    for k, v in pairs(src) do
        out[k] = v
    end
    return out
end

local function lightenColor(c, amount)
    return Color3.new(
        clamp01(c.R + (1 - c.R) * amount),
        clamp01(c.G + (1 - c.G) * amount),
        clamp01(c.B + (1 - c.B) * amount)
    )
end

local function darkenColor(c, amount)
    return Color3.new(
        clamp01(c.R * (1 - amount)),
        clamp01(c.G * (1 - amount)),
        clamp01(c.B * (1 - amount))
    )
end

Bootstrap.Palettes = {
    ObsidianDark = {
        Background = Color3.fromRGB(14, 16, 22),
        Sidebar = Color3.fromRGB(19, 22, 30),
        Surface = Color3.fromRGB(26, 30, 41),
        SurfaceAlt = Color3.fromRGB(34, 39, 53),
        Primary = Color3.fromRGB(99, 102, 241),
        Secondary = Color3.fromRGB(56, 189, 248),
        Text = Color3.fromRGB(241, 245, 249),
        MutedText = Color3.fromRGB(148, 163, 184),
        Border = Color3.fromRGB(51, 59, 80),
        Success = Color3.fromRGB(34, 197, 94),
        Warning = Color3.fromRGB(245, 158, 11),
        Danger = Color3.fromRGB(239, 68, 68),
    },
    CyberNeon = {
        Background = Color3.fromRGB(10, 10, 18),
        Sidebar = Color3.fromRGB(16, 14, 28),
        Surface = Color3.fromRGB(24, 21, 42),
        SurfaceAlt = Color3.fromRGB(35, 30, 62),
        Primary = Color3.fromRGB(0, 245, 212),
        Secondary = Color3.fromRGB(255, 42, 133),
        Text = Color3.fromRGB(240, 253, 255),
        MutedText = Color3.fromRGB(156, 163, 195),
        Border = Color3.fromRGB(72, 58, 128),
        Success = Color3.fromRGB(0, 245, 160),
        Warning = Color3.fromRGB(255, 200, 0),
        Danger = Color3.fromRGB(255, 56, 96),
    },
    SwissMono = {
        Background = Color3.fromRGB(244, 244, 240),
        Sidebar = Color3.fromRGB(232, 232, 226),
        Surface = Color3.fromRGB(255, 255, 255),
        SurfaceAlt = Color3.fromRGB(236, 236, 232),
        Primary = Color3.fromRGB(220, 38, 38),
        Secondary = Color3.fromRGB(20, 20, 20),
        Text = Color3.fromRGB(17, 17, 17),
        MutedText = Color3.fromRGB(95, 95, 92),
        Border = Color3.fromRGB(24, 24, 24),
        Success = Color3.fromRGB(22, 163, 74),
        Warning = Color3.fromRGB(217, 119, 6),
        Danger = Color3.fromRGB(220, 38, 38),
    },
    EmeraldMatrix = {
        Background = Color3.fromRGB(9, 17, 14),
        Sidebar = Color3.fromRGB(13, 24, 19),
        Surface = Color3.fromRGB(18, 34, 27),
        SurfaceAlt = Color3.fromRGB(25, 46, 37),
        Primary = Color3.fromRGB(16, 185, 129),
        Secondary = Color3.fromRGB(110, 231, 183),
        Text = Color3.fromRGB(236, 253, 245),
        MutedText = Color3.fromRGB(134, 175, 158),
        Border = Color3.fromRGB(36, 74, 58),
        Success = Color3.fromRGB(52, 211, 153),
        Warning = Color3.fromRGB(251, 191, 36),
        Danger = Color3.fromRGB(248, 113, 113),
    },
    OceanicDeep = {
        Background = Color3.fromRGB(11, 20, 32),
        Sidebar = Color3.fromRGB(15, 28, 44),
        Surface = Color3.fromRGB(21, 38, 60),
        SurfaceAlt = Color3.fromRGB(28, 50, 79),
        Primary = Color3.fromRGB(14, 165, 233),
        Secondary = Color3.fromRGB(45, 212, 191),
        Text = Color3.fromRGB(240, 249, 255),
        MutedText = Color3.fromRGB(147, 180, 212),
        Border = Color3.fromRGB(45, 78, 118),
        Success = Color3.fromRGB(34, 197, 94),
        Warning = Color3.fromRGB(245, 158, 11),
        Danger = Color3.fromRGB(244, 63, 94),
    },
    SunsetEditorial = {
        Background = Color3.fromRGB(27, 19, 24),
        Sidebar = Color3.fromRGB(35, 24, 31),
        Surface = Color3.fromRGB(47, 32, 41),
        SurfaceAlt = Color3.fromRGB(61, 41, 52),
        Primary = Color3.fromRGB(249, 115, 22),
        Secondary = Color3.fromRGB(244, 63, 94),
        Text = Color3.fromRGB(255, 247, 237),
        MutedText = Color3.fromRGB(205, 170, 165),
        Border = Color3.fromRGB(92, 60, 74),
        Success = Color3.fromRGB(74, 222, 128),
        Warning = Color3.fromRGB(250, 204, 21),
        Danger = Color3.fromRGB(251, 113, 133),
    },
    NewspaperInk = {
        Background = Color3.fromRGB(238, 233, 220),
        Sidebar = Color3.fromRGB(228, 222, 207),
        Surface = Color3.fromRGB(247, 243, 234),
        SurfaceAlt = Color3.fromRGB(221, 214, 198),
        Primary = Color3.fromRGB(32, 30, 27),
        Secondary = Color3.fromRGB(148, 42, 34),
        Text = Color3.fromRGB(24, 22, 20),
        MutedText = Color3.fromRGB(92, 86, 76),
        Border = Color3.fromRGB(46, 42, 38),
        Success = Color3.fromRGB(46, 125, 50),
        Warning = Color3.fromRGB(180, 105, 14),
        Danger = Color3.fromRGB(165, 36, 30),
    },
    BrutalistYellow = {
        Background = Color3.fromRGB(250, 240, 137),
        Sidebar = Color3.fromRGB(245, 228, 92),
        Surface = Color3.fromRGB(255, 255, 255),
        SurfaceAlt = Color3.fromRGB(243, 244, 246),
        Primary = Color3.fromRGB(255, 77, 0),
        Secondary = Color3.fromRGB(59, 130, 246),
        Text = Color3.fromRGB(10, 10, 10),
        MutedText = Color3.fromRGB(64, 64, 64),
        Border = Color3.fromRGB(0, 0, 0),
        Success = Color3.fromRGB(22, 163, 74),
        Warning = Color3.fromRGB(234, 88, 12),
        Danger = Color3.fromRGB(220, 38, 38),
    },
}

Bootstrap.PaletteOrder = {
    "ObsidianDark",
    "CyberNeon",
    "SwissMono",
    "EmeraldMatrix",
    "OceanicDeep",
    "SunsetEditorial",
    "NewspaperInk",
    "BrutalistYellow",
}

local PRESET_STORAGE_FILE = "RobloxGuiBootstrap_Presets.json"

local function loadSavedPresets()
    if typeof(isfile) ~= "function" or typeof(readfile) ~= "function" then
        return
    end
    local ok, raw = pcall(function()
        if isfile(PRESET_STORAGE_FILE) then
            return readfile(PRESET_STORAGE_FILE)
        end
        return nil
    end)
    if not ok or not raw or raw == "" then
        return
    end
    local okDec, data = pcall(HttpService.JSONDecode, HttpService, raw)
    if not okDec or type(data) ~= "table" then
        return
    end
    for presetName, hexMap in pairs(data) do
        if type(hexMap) == "table" and not Bootstrap.Palettes[presetName] then
            local pal = copyPalette(Bootstrap.Palettes.ObsidianDark)
            for role, hex in pairs(hexMap) do
                if type(hex) == "string" then
                    pal[role] = hexToColor3(hex)
                end
            end
            Bootstrap.Palettes[presetName] = pal
            table.insert(Bootstrap.PaletteOrder, presetName)
        end
    end
end

local function persistPresetToFile(presetName, palette)
    if typeof(writefile) ~= "function" then
        return false
    end
    local saved = {}
    if typeof(isfile) == "function" and typeof(readfile) == "function" then
        local ok, raw = pcall(function()
            return isfile(PRESET_STORAGE_FILE) and readfile(PRESET_STORAGE_FILE) or nil
        end)
        if ok and raw and raw ~= "" then
            local okDec, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
            if okDec and type(decoded) == "table" then
                saved = decoded
            end
        end
    end
    local serialized = {}
    for role, col in pairs(palette) do
        if typeof(col) == "Color3" then
            serialized[role] = color3ToHex(col)
        end
    end
    saved[presetName] = serialized
    local okEnc, json = pcall(HttpService.JSONEncode, HttpService, saved)
    if not okEnc then
        return false
    end
    local okWrite = pcall(writefile, PRESET_STORAGE_FILE, json)
    return okWrite
end

pcall(loadSavedPresets)

--============================================================================--
-- 4. VISUAL GRAPHICS REGISTRY (10 ARCHETYPES) & STYLE ENGINE
--============================================================================--

Bootstrap.Visuals = {
    ["Minimalist"] = {
        CornerRadius = 8,
        StrokeThickness = 1,
        StrokeTransparency = 0.65,
        FontTitle = Enum.Font.GothamBold,
        FontBody = Enum.Font.Gotham,
        ShadowMode = "None",
        GradientBg = false,
        AccentTags = false,
        Padding = 10,
        CardRotation = 0,
    },
    ["Maximalism"] = {
        CornerRadius = 14,
        StrokeThickness = 2,
        StrokeTransparency = 0.15,
        FontTitle = Enum.Font.FredokaOne,
        FontBody = Enum.Font.GothamMedium,
        ShadowMode = "Soft",
        GradientBg = true,
        AccentTags = true,
        Padding = 12,
        CardRotation = 0,
    },
    ["Editorial"] = {
        CornerRadius = 3,
        StrokeThickness = 1,
        StrokeTransparency = 0.45,
        FontTitle = Enum.Font.Merriweather,
        FontBody = Enum.Font.SourceSans,
        ShadowMode = "None",
        GradientBg = false,
        AccentTags = true,
        Padding = 12,
        CardRotation = 0,
    },
    ["Newspaper"] = {
        CornerRadius = 0,
        StrokeThickness = 1.5,
        StrokeTransparency = 0,
        FontTitle = Enum.Font.Antique,
        FontBody = Enum.Font.Merriweather,
        ShadowMode = "DoubleRule",
        GradientBg = false,
        AccentTags = true,
        Padding = 8,
        CardRotation = 0,
    },
    ["Brutalist Layout"] = {
        CornerRadius = 0,
        StrokeThickness = 2.5,
        StrokeTransparency = 0,
        FontTitle = Enum.Font.Code,
        FontBody = Enum.Font.RobotoMono,
        ShadowMode = "HardOffset",
        GradientBg = false,
        AccentTags = true,
        Padding = 8,
        CardRotation = 0,
    },
    ["Deconstructed"] = {
        CornerRadius = 2,
        StrokeThickness = 1.5,
        StrokeTransparency = 0.15,
        FontTitle = Enum.Font.RobotoMono,
        FontBody = Enum.Font.Gotham,
        ShadowMode = "HardOffset",
        GradientBg = false,
        AccentTags = true,
        Padding = 10,
        CardRotation = -0.6,
    },
    ["Collage"] = {
        CornerRadius = 12,
        StrokeThickness = 1.5,
        StrokeTransparency = 0.2,
        FontTitle = Enum.Font.GothamBlack,
        FontBody = Enum.Font.GothamMedium,
        ShadowMode = "Soft",
        GradientBg = true,
        AccentTags = true,
        Padding = 11,
        CardRotation = 0.7,
    },
    ["Isometric"] = {
        CornerRadius = 6,
        StrokeThickness = 1.5,
        StrokeTransparency = 0.1,
        FontTitle = Enum.Font.GothamBold,
        FontBody = Enum.Font.Gotham,
        ShadowMode = "IsometricBevel",
        GradientBg = true,
        AccentTags = false,
        Padding = 10,
        CardRotation = 0,
    },
    ["Card Base"] = {
        CornerRadius = 10,
        StrokeThickness = 1,
        StrokeTransparency = 0.45,
        FontTitle = Enum.Font.GothamBold,
        FontBody = Enum.Font.Gotham,
        ShadowMode = "Soft",
        GradientBg = false,
        AccentTags = false,
        Padding = 11,
        CardRotation = 0,
    },
    ["Dashboard Layout"] = {
        CornerRadius = 6,
        StrokeThickness = 1,
        StrokeTransparency = 0.5,
        FontTitle = Enum.Font.GothamSemibold,
        FontBody = Enum.Font.RobotoMono,
        ShadowMode = "None",
        GradientBg = false,
        AccentTags = true,
        Padding = 7,
        CardRotation = 0,
    },
}

Bootstrap.VisualOrder = {
    "Minimalist",
    "Maximalism",
    "Editorial",
    "Newspaper",
    "Brutalist Layout",
    "Deconstructed",
    "Collage",
    "Isometric",
    "Card Base",
    "Dashboard Layout",
}

local function ensureCorner(inst, radius)
    local corner = inst:FindFirstChildOfClass("UICorner")
    if not corner then
        corner = Instance.new("UICorner")
        corner.Parent = inst
    end
    corner.CornerRadius = UDim.new(0, radius)
    return corner
end

local function ensureStroke(inst, color, thickness, transparency)
    local stroke = inst:FindFirstChildOfClass("UIStroke")
    if not stroke then
        stroke = Instance.new("UIStroke")
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        stroke.Parent = inst
    end
    stroke.Color = color
    stroke.Thickness = thickness
    stroke.Transparency = transparency
    return stroke
end

local function clearDecorations(inst)
    for _, name in ipairs({
        "__VisualGrad",
        "__VisualShadowR",
        "__VisualShadowB",
        "__VisualBevelR",
        "__VisualBevelB",
        "__VisualInnerRule",
        "__VisualTag",
    }) do
        local child = inst:FindFirstChild(name)
        if child then
            child:Destroy()
        end
    end
end

local function addOuterRim(inst, prefix, color, transparency, thickness, cornerPx)
    local r = Instance.new("Frame")
    r.Name = prefix .. "R"
    r.Size = UDim2.new(0, thickness, 1, 0)
    r.Position = UDim2.new(1, 0, 0, thickness)
    r.BackgroundColor3 = color
    r.BackgroundTransparency = transparency
    r.BorderSizePixel = 0
    r.ZIndex = inst.ZIndex
    if cornerPx > 0 then
        ensureCorner(r, math.min(cornerPx, thickness))
    end
    r.Parent = inst

    local b = Instance.new("Frame")
    b.Name = prefix .. "B"
    b.Size = UDim2.new(1, 0, 0, thickness)
    b.Position = UDim2.new(0, thickness, 1, 0)
    b.BackgroundColor3 = color
    b.BackgroundTransparency = transparency
    b.BorderSizePixel = 0
    b.ZIndex = inst.ZIndex
    if cornerPx > 0 then
        ensureCorner(b, math.min(cornerPx, thickness))
    end
    b.Parent = inst
end

local function applyVisualToSurface(inst, visual, palette, perfTier, role, indexTag)
    if not inst or not inst.Parent then
        return
    end
    role = role or "Surface"
    local cornerPx = math.round(visual.CornerRadius * (perfTier.CornerScale or 1))
    if role == "Window" then
        cornerPx = math.min(cornerPx + 2, 16)
    elseif role == "Pill" then
        cornerPx = 999
    end

    ensureCorner(inst, cornerPx)
    ensureStroke(
        inst,
        palette.Border,
        visual.StrokeThickness,
        visual.StrokeTransparency
    )

    if inst:IsA("GuiObject") then
        if role == "Primary" then
            inst.BackgroundColor3 = palette.Primary
        elseif role == "Sidebar" then
            inst.BackgroundColor3 = palette.Sidebar
        elseif role == "Background" or role == "Window" then
            inst.BackgroundColor3 = palette.Background
        elseif role == "SurfaceAlt" then
            inst.BackgroundColor3 = palette.SurfaceAlt
        else
            inst.BackgroundColor3 = palette.Surface
        end
    end

    if role ~= "Window" and role ~= "Sidebar" and role ~= "Background" and role ~= "Pill" then
        clearDecorations(inst)

        if visual.CardRotation ~= 0 and perfTier.Name ~= "Low" then
            local sign = ((indexTag or 1) % 2 == 0) and 1 or -1
            inst.Rotation = visual.CardRotation * sign
        else
            inst.Rotation = 0
        end

        if visual.GradientBg and perfTier.UseGradients then
            local grad = Instance.new("UIGradient")
            grad.Name = "__VisualGrad"
            grad.Rotation = 35
            grad.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, lightenColor(inst.BackgroundColor3, 0.08)),
                ColorSequenceKeypoint.new(1, darkenColor(inst.BackgroundColor3, 0.12)),
            })
            grad.Parent = inst
        end

        if perfTier.UseShadows then
            if visual.ShadowMode == "HardOffset" then
                addOuterRim(inst, "__VisualShadow", palette.Border, 0, 4, 0)
            elseif visual.ShadowMode == "Soft" then
                addOuterRim(inst, "__VisualShadow", Color3.new(0, 0, 0), 0.72, 3, 2)
            elseif visual.ShadowMode == "IsometricBevel" then
                addOuterRim(inst, "__VisualBevel", darkenColor(palette.Primary, 0.42), 0.12, 4, math.min(cornerPx, 3))
            elseif visual.ShadowMode == "DoubleRule" then
                local rule = Instance.new("Frame")
                rule.Name = "__VisualInnerRule"
                rule.Size = UDim2.new(1, -6, 1, -6)
                rule.Position = UDim2.fromOffset(3, 3)
                rule.BackgroundTransparency = 1
                rule.ZIndex = inst.ZIndex
                ensureStroke(rule, palette.Border, 1, 0.35)
                rule.Parent = inst
            end
        end

        if visual.AccentTags and indexTag then
            local tag = Instance.new("TextLabel")
            tag.Name = "__VisualTag"
            tag.Size = UDim2.fromOffset(44, 14)
            tag.Position = UDim2.new(1, -48, 0, 3)
            tag.BackgroundColor3 = palette.Primary
            tag.BackgroundTransparency = 0.15
            tag.Text = string.format("#%02d", indexTag)
            tag.Font = Enum.Font.RobotoMono
            tag.TextSize = 9
            tag.TextColor3 = Color3.new(1, 1, 1)
            tag.ZIndex = inst.ZIndex + 3
            ensureCorner(tag, math.min(cornerPx, 4))
            tag.Parent = inst
        end
    end
end

--============================================================================--
-- 5. DEFAULT GRIDS (7) & DEFAULT PATTERNS (7)
--============================================================================--

Bootstrap.Grids = {
    "Grid Modular",
    "Bento Grid",
    "Masonry",
    "Swiss",
    "Golden Ratio Layout",
    "12 Column Grid",
    "Baseline Grid",
}

Bootstrap.Patterns = {
    "F-Pattern",
    "Z-Pattern",
    "Single Column",
    "Multi Column",
    "Split Screen",
    "Full-Blend Hero",
    "Sticky Sidebar",
}

local function snapToStep(val, step)
    return math.max(step, math.round(val / step) * step)
end

local function clearGridHelpers(container)
    for _, child in ipairs(container:GetChildren()) do
        if child.Name == "__GridHelper" or child:IsA("UIGridLayout") or child:IsA("UIListLayout") then
            child:Destroy()
        end
    end
end

local function layoutItemsWithGrid(container, items, gridName, palette, visual)
    clearGridHelpers(container)
    if #items == 0 then
        return 0
    end

    local width = math.max(container.AbsoluteSize.X, 260)
    local pad = visual.Padding or 10
    local gap = (gridName == "Swiss") and 2 or (gridName == "Baseline Grid" and 8 or 8)

    if gridName == "Baseline Grid" then
        pad = 8
        for i = 0, 12 do
            local line = Instance.new("Frame")
            line.Name = "__GridHelper"
            line.Size = UDim2.new(1, 0, 0, 1)
            line.Position = UDim2.fromOffset(0, i * 48)
            line.BackgroundColor3 = palette.Border
            line.BackgroundTransparency = 0.88
            line.BorderSizePixel = 0
            line.ZIndex = 1
            line.Parent = container
        end
    end

    local innerW = math.max(width - pad * 2, 180)
    local maxCols = (innerW >= 540) and 3 or ((innerW >= 320) and 2 or 1)

    local function placeItem(item, x, y, w, h)
        item.Root.Parent = container
        item.Root.Position = UDim2.fromOffset(math.round(x), math.round(y))
        item.Root.Size = UDim2.fromOffset(math.round(math.max(w, 60)), math.round(math.max(h, 32)))
        item.Root.ZIndex = 2
    end

    if gridName == "Grid Modular" or gridName == "Swiss" then
        local cols = maxCols
        local colW = (innerW - gap * (cols - 1)) / cols
        local y = pad
        local rowIdx = 1
        local idx = 1
        while idx <= #items do
            local item = items[idx]
            local isFull = item.FullWidth or (item.ColSpan and item.ColSpan >= 10)
            if isFull or cols == 1 then
                local h = item.PreferredHeight or 56
                placeItem(item, pad, y, innerW, h)
                y = y + h + gap
                idx = idx + 1
            else
                local rowMaxH = 0
                local c = 0
                while c < cols and idx <= #items do
                    local cur = items[idx]
                    if cur.FullWidth or (cur.ColSpan and cur.ColSpan >= 10) then
                        break
                    end
                    local h = cur.PreferredHeight or 96
                    rowMaxH = math.max(rowMaxH, h)
                    c = c + 1
                    idx = idx + 1
                end
                local startIdx = idx - c
                for k = 0, c - 1 do
                    local cur = items[startIdx + k]
                    local x = pad + k * (colW + gap)
                    placeItem(cur, x, y, colW, rowMaxH)
                    if gridName == "Swiss" then
                        cur.Root.Rotation = 0
                        ensureCorner(cur.Root, 0)
                    end
                end
                y = y + rowMaxH + gap
                rowIdx = rowIdx + 1
            end
        end
        return y + pad
    end

    if gridName == "Bento Grid" then
        if maxCols == 1 then
            local y = pad
            for _, item in ipairs(items) do
                local h = item.PreferredHeight or 84
                placeItem(item, pad, y, innerW, h)
                y = y + h + gap
            end
            return y + pad
        end

        local y = pad
        local i = 1
        while i <= #items do
            local remaining = #items - i + 1
            if i == 1 and remaining >= 3 then
                local bigW = innerW * 0.62 - gap * 0.5
                local sideW = innerW - bigW - gap
                local h1 = math.max(items[i].PreferredHeight or 110, 120)
                local h2 = items[i + 1].PreferredHeight or 56
                local h3 = items[i + 2].PreferredHeight or 56
                local totalH = math.max(h1, h2 + gap + h3)
                placeItem(items[i], pad, y, bigW, totalH)
                placeItem(items[i + 1], pad + bigW + gap, y, sideW, h2)
                placeItem(items[i + 2], pad + bigW + gap, y + h2 + gap, sideW, totalH - h2 - gap)
                y = y + totalH + gap
                i = i + 3
            elseif remaining >= 2 and not items[i].FullWidth and not items[i + 1].FullWidth then
                local split = ((i % 2) == 0) and 0.36 or 0.64
                local wA = innerW * split - gap * 0.5
                local wB = innerW - wA - gap
                local rowH = math.max(items[i].PreferredHeight or 84, items[i + 1].PreferredHeight or 84)
                placeItem(items[i], pad, y, wA, rowH)
                placeItem(items[i + 1], pad + wA + gap, y, wB, rowH)
                y = y + rowH + gap
                i = i + 2
            else
                local h = items[i].PreferredHeight or 80
                placeItem(items[i], pad, y, innerW, h)
                y = y + h + gap
                i = i + 1
            end
        end
        return y + pad
    end

    if gridName == "Masonry" then
        local cols = maxCols
        local colW = (innerW - gap * (cols - 1)) / cols
        local colY = {}
        for c = 1, cols do
            colY[c] = pad
        end
        for _, item in ipairs(items) do
            if item.FullWidth or cols == 1 then
                local maxY = pad
                for c = 1, cols do
                    maxY = math.max(maxY, colY[c])
                end
                local h = item.PreferredHeight or 64
                placeItem(item, pad, maxY, innerW, h)
                local nextY = maxY + h + gap
                for c = 1, cols do
                    colY[c] = nextY
                end
            else
                local bestCol = 1
                for c = 2, cols do
                    if colY[c] < colY[bestCol] then
                        bestCol = c
                    end
                end
                local h = item.PreferredHeight or 90
                local x = pad + (bestCol - 1) * (colW + gap)
                placeItem(item, x, colY[bestCol], colW, h)
                colY[bestCol] = colY[bestCol] + h + gap
            end
        end
        local total = pad
        for c = 1, cols do
            total = math.max(total, colY[c])
        end
        return total + pad
    end

    if gridName == "Golden Ratio Layout" then
        local phi = 0.618034
        local y = pad
        local i = 1
        while i <= #items do
            local itemA = items[i]
            local itemB = items[i + 1]
            if maxCols > 1 and itemB and not itemA.FullWidth and not itemB.FullWidth then
                local flip = (math.floor(i / 2) % 2) == 1
                local ratioA = flip and (1 - phi) or phi
                local wA = (innerW - gap) * ratioA
                local wB = innerW - gap - wA
                local h = math.max(itemA.PreferredHeight or 88, itemB.PreferredHeight or 88)
                placeItem(itemA, pad, y, wA, h)
                placeItem(itemB, pad + wA + gap, y, wB, h)
                y = y + h + gap
                i = i + 2
            else
                local h = itemA.PreferredHeight or 72
                placeItem(itemA, pad, y, innerW, h)
                y = y + h + gap
                i = i + 1
            end
        end
        return y + pad
    end

    if gridName == "12 Column Grid" then
        local colUnit = (innerW - gap * 11) / 12
        local y = pad
        local curCol = 0
        local rowMaxH = 0
        for _, item in ipairs(items) do
            local span = item.ColSpan or (item.FullWidth and 12 or 6)
            if maxCols == 1 then
                span = 12
            elseif maxCols == 2 and span < 6 then
                span = 6
            end
            span = math.clamp(span, 1, 12)
            if curCol + span > 12 then
                y = y + rowMaxH + gap
                curCol = 0
                rowMaxH = 0
            end
            local w = colUnit * span + gap * (span - 1)
            local x = pad + curCol * (colUnit + gap)
            local h = item.PreferredHeight or 76
            placeItem(item, x, y, w, h)
            curCol = curCol + span
            rowMaxH = math.max(rowMaxH, h)
        end
        return y + rowMaxH + pad * 2
    end

    -- Baseline Grid (default fallback)
    local y = 8
    for _, item in ipairs(items) do
        local h = snapToStep(item.PreferredHeight or 64, 8)
        placeItem(item, pad, y, innerW, h)
        y = y + h + 8
    end
    return y + 8
end

local function makeRegionFrame(parent, name)
    local f = Instance.new("Frame")
    f.Name = name or "__PatternRegion"
    f.BackgroundTransparency = 1
    f.BorderSizePixel = 0
    f.Parent = parent
    return f
end

local function applyPatternAndGrid(pageScroller, items, patternName, gridName, palette, visual)
    for _, item in ipairs(items) do
        item.Root.Parent = nil
    end
    for _, child in ipairs(pageScroller:GetChildren()) do
        if child.Name:sub(1, 9) == "__Pattern" or child.Name == "__GridHelper" then
            child:Destroy()
        end
    end

    local viewW = math.max(pageScroller.AbsoluteSize.X - 10, 260)
    local pad = visual.Padding or 10
    local gap = 10

    if #items == 0 then
        pageScroller.CanvasSize = UDim2.fromOffset(0, 0)
        return
    end

    if patternName == "Single Column" then
        local colW = math.min(viewW, 660)
        local xOffset = math.max(0, (viewW - colW) * 0.5)
        local reg = makeRegionFrame(pageScroller, "__PatternSingle")
        reg.Position = UDim2.fromOffset(xOffset, 0)
        reg.Size = UDim2.fromOffset(colW, 100)
        local y = pad
        for _, item in ipairs(items) do
            local h = item.PreferredHeight or 64
            item.Root.Parent = reg
            item.Root.Position = UDim2.fromOffset(pad, y)
            item.Root.Size = UDim2.fromOffset(math.max(colW - pad * 2, 120), h)
            y = y + h + gap
        end
        reg.Size = UDim2.fromOffset(colW, y + pad)
        pageScroller.CanvasSize = UDim2.fromOffset(0, y + pad)
        return
    end

    if patternName == "Multi Column" then
        local reg = makeRegionFrame(pageScroller, "__PatternMulti")
        reg.Position = UDim2.fromOffset(0, 0)
        reg.Size = UDim2.fromOffset(viewW, 100)
        local usedGrid = (gridName == "Baseline Grid") and "Grid Modular" or gridName
        local h = layoutItemsWithGrid(reg, items, usedGrid, palette, visual)
        reg.Size = UDim2.fromOffset(viewW, h)
        pageScroller.CanvasSize = UDim2.fromOffset(0, h)
        return
    end

    if patternName == "Split Screen" and viewW >= 460 then
        local halfW = math.floor((viewW - gap) * 0.5)
        local leftReg = makeRegionFrame(pageScroller, "__PatternSplitL")
        leftReg.Position = UDim2.fromOffset(0, 0)
        leftReg.Size = UDim2.fromOffset(halfW, 100)

        local rightReg = makeRegionFrame(pageScroller, "__PatternSplitR")
        rightReg.Position = UDim2.fromOffset(halfW + gap, 0)
        rightReg.Size = UDim2.fromOffset(halfW, 100)

        local leftItems, rightItems = {}, {}
        for i, item in ipairs(items) do
            if i % 2 == 1 then
                table.insert(leftItems, item)
            else
                table.insert(rightItems, item)
            end
        end
        local hL = layoutItemsWithGrid(leftReg, leftItems, gridName, palette, visual)
        local hR = layoutItemsWithGrid(rightReg, rightItems, gridName, palette, visual)
        leftReg.Size = UDim2.fromOffset(halfW, hL)
        rightReg.Size = UDim2.fromOffset(halfW, hR)
        pageScroller.CanvasSize = UDim2.fromOffset(0, math.max(hL, hR))
        return
    end

    if patternName == "F-Pattern" and viewW >= 480 then
        local topBar = makeRegionFrame(pageScroller, "__PatternFTop")
        topBar.Position = UDim2.fromOffset(0, 0)
        topBar.Size = UDim2.fromOffset(viewW, 100)
        local topList, leftList, rightList = {}, {}, {}
        for i, item in ipairs(items) do
            if i <= 2 then
                table.insert(topList, item)
            elseif ((i - 2) % 3 == 0) then
                table.insert(rightList, item)
            else
                table.insert(leftList, item)
            end
        end
        local hTop = layoutItemsWithGrid(topBar, topList, "12 Column Grid", palette, visual)
        topBar.Size = UDim2.fromOffset(viewW, hTop)

        local leftW = math.floor(viewW * 0.65)
        local rightW = viewW - leftW - gap
        local leftReg = makeRegionFrame(pageScroller, "__PatternFLeft")
        leftReg.Position = UDim2.fromOffset(0, hTop)
        leftReg.Size = UDim2.fromOffset(leftW, 100)

        local rightReg = makeRegionFrame(pageScroller, "__PatternFRight")
        rightReg.Position = UDim2.fromOffset(leftW + gap, hTop)
        rightReg.Size = UDim2.fromOffset(rightW, 100)

        local hL = layoutItemsWithGrid(leftReg, leftList, gridName, palette, visual)
        local hR = layoutItemsWithGrid(rightReg, rightList, "Baseline Grid", palette, visual)
        leftReg.Size = UDim2.fromOffset(leftW, hL)
        rightReg.Size = UDim2.fromOffset(rightW, hR)
        pageScroller.CanvasSize = UDim2.fromOffset(0, hTop + math.max(hL, hR))
        return
    end

    if patternName == "Z-Pattern" and viewW >= 460 then
        local topReg = makeRegionFrame(pageScroller, "__PatternZTop")
        topReg.Position = UDim2.fromOffset(0, 0)
        topReg.Size = UDim2.fromOffset(viewW, 100)

        local midReg = makeRegionFrame(pageScroller, "__PatternZMid")
        midReg.Size = UDim2.fromOffset(viewW, 100)

        local botReg = makeRegionFrame(pageScroller, "__PatternZBot")
        botReg.Size = UDim2.fromOffset(viewW, 100)

        local topItems, midItems, botItems = {}, {}, {}
        for i, item in ipairs(items) do
            if i <= 2 then
                table.insert(topItems, item)
            elseif i == 3 then
                table.insert(midItems, item)
            else
                table.insert(botItems, item)
            end
        end
        local h1 = layoutItemsWithGrid(topReg, topItems, "Golden Ratio Layout", palette, visual)
        topReg.Size = UDim2.fromOffset(viewW, h1)
        midReg.Position = UDim2.fromOffset(0, h1)
        local h2 = layoutItemsWithGrid(midReg, midItems, "Grid Modular", palette, visual)
        midReg.Size = UDim2.fromOffset(viewW, h2)
        botReg.Position = UDim2.fromOffset(0, h1 + h2)
        local h3 = layoutItemsWithGrid(botReg, botItems, gridName, palette, visual)
        botReg.Size = UDim2.fromOffset(viewW, h3)
        pageScroller.CanvasSize = UDim2.fromOffset(0, h1 + h2 + h3)
        return
    end

    if patternName == "Full-Blend Hero" then
        local heroReg = makeRegionFrame(pageScroller, "__PatternHero")
        heroReg.Position = UDim2.fromOffset(0, 0)
        heroReg.Size = UDim2.fromOffset(viewW, 100)
        heroReg.BackgroundTransparency = 0.08
        heroReg.BackgroundColor3 = darkenColor(palette.Primary, 0.45)
        ensureCorner(heroReg, visual.CornerRadius)
        local grad = Instance.new("UIGradient")
        grad.Rotation = 90
        grad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, palette.Primary),
            ColorSequenceKeypoint.new(1, palette.Background),
        })
        grad.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.35),
            NumberSequenceKeypoint.new(1, 0.92),
        })
        grad.Parent = heroReg

        local heroItems, bodyItems = {}, {}
        for i, item in ipairs(items) do
            if i <= 2 then
                table.insert(heroItems, item)
            else
                table.insert(bodyItems, item)
            end
        end
        local hHero = layoutItemsWithGrid(heroReg, heroItems, "12 Column Grid", palette, visual)
        heroReg.Size = UDim2.fromOffset(viewW, hHero + 6)

        local bodyReg = makeRegionFrame(pageScroller, "__PatternHeroBody")
        bodyReg.Position = UDim2.fromOffset(0, hHero + 10)
        bodyReg.Size = UDim2.fromOffset(viewW, 100)
        local hBody = layoutItemsWithGrid(bodyReg, bodyItems, gridName, palette, visual)
        bodyReg.Size = UDim2.fromOffset(viewW, hBody)
        pageScroller.CanvasSize = UDim2.fromOffset(0, hHero + 10 + hBody)
        return
    end

    if patternName == "Sticky Sidebar" and viewW >= 460 then
        local railW = math.clamp(math.floor(viewW * 0.28), 130, 210)
        local mainW = viewW - railW - gap
        local railReg = makeRegionFrame(pageScroller, "__PatternStickyRail")
        railReg.Position = UDim2.fromOffset(0, 0)
        railReg.Size = UDim2.fromOffset(railW, 100)
        railReg.BackgroundTransparency = 0.25
        railReg.BackgroundColor3 = palette.Sidebar
        ensureCorner(railReg, visual.CornerRadius)
        ensureStroke(railReg, palette.Border, 1, 0.5)

        local mainReg = makeRegionFrame(pageScroller, "__PatternStickyMain")
        mainReg.Position = UDim2.fromOffset(railW + gap, 0)
        mainReg.Size = UDim2.fromOffset(mainW, 100)

        local railItems, mainItems = {}, {}
        for i, item in ipairs(items) do
            if i <= 2 or item.Type == "Label" or item.Type == "Radio" then
                table.insert(railItems, item)
            else
                table.insert(mainItems, item)
            end
        end
        if #railItems == 0 and #items > 1 then
            table.insert(railItems, table.remove(mainItems, 1))
        end
        local hRail = layoutItemsWithGrid(railReg, railItems, "Baseline Grid", palette, visual)
        local hMain = layoutItemsWithGrid(mainReg, mainItems, gridName, palette, visual)
        railReg.Size = UDim2.fromOffset(railW, hRail)
        mainReg.Size = UDim2.fromOffset(mainW, hMain)
        pageScroller.CanvasSize = UDim2.fromOffset(0, math.max(hRail, hMain))
        return
    end

    -- Fallback / Responsive narrow screen single flow
    local reg = makeRegionFrame(pageScroller, "__PatternDefault")
    reg.Position = UDim2.fromOffset(0, 0)
    reg.Size = UDim2.fromOffset(viewW, 100)
    local h = layoutItemsWithGrid(reg, items, gridName, palette, visual)
    reg.Size = UDim2.fromOffset(viewW, h)
    pageScroller.CanvasSize = UDim2.fromOffset(0, h)
end

--============================================================================--
-- 6. WINDOW SHELL, INPUT/TOPBAR BLOCKER & MOBILE AUTO-SCALER
--============================================================================--

local SINK_ACTION_NAME = "__RobloxGuiBootstrap_InputSink"

local function makeText(parent, props)
    local lbl = Instance.new(props.IsButton and "TextButton" or "TextLabel")
    lbl.Name = props.Name or "Label"
    lbl.BackgroundTransparency = props.BgTransparency ~= nil and props.BgTransparency or 1
    lbl.BorderSizePixel = 0
    lbl.Text = props.Text or ""
    lbl.Font = props.Font or Enum.Font.Gotham
    lbl.TextSize = props.TextSize or 13
    lbl.TextColor3 = props.TextColor or Color3.new(1, 1, 1)
    lbl.TextXAlignment = props.XAlign or Enum.TextXAlignment.Left
    lbl.TextYAlignment = props.YAlign or Enum.TextYAlignment.Center
    lbl.TextWrapped = props.Wrapped ~= false
    if props.Truncate then
        lbl.TextTruncate = props.Truncate
    end
    lbl.Size = props.Size or UDim2.fromScale(1, 1)
    lbl.Position = props.Position or UDim2.fromOffset(0, 0)
    lbl.ZIndex = props.ZIndex or 3
    if props.IsButton then
        lbl.AutoButtonColor = false
    end
    lbl.Parent = parent
    return lbl
end

function Bootstrap.CreateWindow(config)
    config = config or {}
    local janitor = Janitor.new()
    local guiParent, fromGethui = resolveGuiParent()

    local paletteName = config.Palette or "ObsidianDark"
    local initialPalette = Bootstrap.Palettes[paletteName] or Bootstrap.Palettes.ObsidianDark
    local activePalette = copyPalette(initialPalette)

    local window = setmetatable({
        Title = config.Title or "Bootstrap GUI",
        Subtitle = config.Subtitle or "3-Tab Framework",
        LogoText = config.LogoText or "BG",
        LogoImage = config.LogoImage or "",
        PaletteName = paletteName,
        Palette = activePalette,
        GridName = config.Grid or "Bento Grid",
        PatternName = config.Pattern or "Multi Column",
        VisualName = config.Visual or "Minimalist",
        PerfMode = config.PerformanceMode or "Auto",
        PerfTier = PerformanceTiers.High,
        BlockGameCanvas = config.BlockGameCanvas ~= false,
        BlockTopbar = config.BlockTopbar ~= false,
        ScaleOverride = config.ScaleOverride or 0, -- 0 = Auto Responsive
        Minimized = false,
        Maximized = false,
        RightTabOpen = true,
        Closed = false,
        _janitor = janitor,
        _tabs = {},
        _activeTab = nil,
        _themeHooks = {},
        _savedCoreGui = nil,
        _notifications = {},
        _onPresetSavedCallbacks = {},
    }, Bootstrap)

    if window.PerfMode ~= "Auto" and PerformanceTiers[window.PerfMode] then
        window.PerfTier = PerformanceTiers[window.PerfMode]
    end

    -- Root ScreenGui
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = config.Name or "RobloxGuiBootstrap"
    screenGui.IgnoreGuiInset = true
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.DisplayOrder = config.DisplayOrder or 999999
    protectScreenGui(screenGui, fromGethui)
    screenGui.Parent = guiParent
    janitor:Add(screenGui, "Destroy")
    window.ScreenGui = screenGui

    -- Full-Screen Modal Blocker + Topbar Cover
    local modalBlocker = Instance.new("TextButton")
    modalBlocker.Name = "GameCanvasBlocker"
    modalBlocker.Size = UDim2.fromScale(1, 1)
    modalBlocker.Position = UDim2.fromScale(0, 0)
    modalBlocker.BackgroundColor3 = Color3.new(0, 0, 0)
    modalBlocker.BackgroundTransparency = config.BackdropTransparency or 0.42
    modalBlocker.BorderSizePixel = 0
    modalBlocker.Text = ""
    modalBlocker.AutoButtonColor = false
    modalBlocker.Active = true
    modalBlocker.Modal = true
    modalBlocker.ZIndex = 1
    modalBlocker.Parent = screenGui
    window.ModalBlocker = modalBlocker

    -- Explicit Topbar Shield Strip (covers Roblox topbar inset 0..58px visually & interactively)
    local topbarShield = Instance.new("Frame")
    topbarShield.Name = "TopbarShield"
    topbarShield.Size = UDim2.new(1, 0, 0, 58)
    topbarShield.Position = UDim2.fromOffset(0, 0)
    topbarShield.BackgroundColor3 = Color3.new(0, 0, 0)
    topbarShield.BackgroundTransparency = 0.25
    topbarShield.BorderSizePixel = 0
    topbarShield.Active = true
    topbarShield.ZIndex = 2
    topbarShield.Parent = modalBlocker
    window.TopbarShield = topbarShield

    -- Main Window Container
    local baseSize = config.Size or UDim2.fromOffset(880, 530)
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainWindow"
    mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    mainFrame.Position = UDim2.fromScale(0.5, 0.5)
    mainFrame.Size = baseSize
    mainFrame.ClipsDescendants = true
    mainFrame.Active = true
    mainFrame.ZIndex = 10
    mainFrame.Parent = screenGui
    window.MainFrame = mainFrame

    local uiScale = Instance.new("UIScale")
    uiScale.Name = "ResponsiveScale"
    uiScale.Parent = mainFrame
    window.UIScale = uiScale

    -- Sink stray pointer/keyboard events when GUI is open & active
    local sinkBound = false
    local function updateInputLock()
        local shouldBlock = (not window.Closed) and (not window.Minimized) and window.BlockGameCanvas
        modalBlocker.Visible = shouldBlock
        modalBlocker.Active = shouldBlock
        modalBlocker.Modal = shouldBlock
        topbarShield.Visible = shouldBlock and window.BlockTopbar

        if (not window.Closed) and (not window.Minimized) and window.BlockTopbar then
            if not window._savedCoreGui then
                window._savedCoreGui = {}
                for _, coreType in ipairs({
                    Enum.CoreGuiType.PlayerList,
                    Enum.CoreGuiType.Health,
                    Enum.CoreGuiType.Backpack,
                    Enum.CoreGuiType.Chat,
                    Enum.CoreGuiType.EmotesMenu,
                }) do
                    local ok, enabled = pcall(StarterGui.GetCoreGuiEnabled, StarterGui, coreType)
                    if ok then
                        window._savedCoreGui[coreType] = enabled
                    end
                end
            end
            pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.All, false)
        elseif window._savedCoreGui then
            for coreType, wasEnabled in pairs(window._savedCoreGui) do
                pcall(StarterGui.SetCoreGuiEnabled, StarterGui, coreType, wasEnabled)
            end
            window._savedCoreGui = nil
        end

        if shouldBlock and not sinkBound then
            sinkBound = true
            pcall(function()
                ContextActionService:BindActionAtPriority(
                    SINK_ACTION_NAME,
                    function()
                        return Enum.ContextActionResult.Sink
                    end,
                    false,
                    Enum.ContextActionPriority.High.Value + 500,
                    Enum.UserInputType.MouseButton1,
                    Enum.UserInputType.MouseButton2,
                    Enum.UserInputType.MouseWheel
                )
            end)
        elseif (not shouldBlock) and sinkBound then
            sinkBound = false
            pcall(ContextActionService.UnbindAction, ContextActionService, SINK_ACTION_NAME)
        end
    end
    janitor:Add(function()
        if sinkBound then
            pcall(ContextActionService.UnbindAction, ContextActionService, SINK_ACTION_NAME)
        end
        if window._savedCoreGui then
            for coreType, wasEnabled in pairs(window._savedCoreGui) do
                pcall(StarterGui.SetCoreGuiEnabled, StarterGui, coreType, wasEnabled)
            end
            window._savedCoreGui = nil
        end
    end)
    window._updateInputLock = updateInputLock

    -- Also consume clicks directly on ModalBlocker so nothing leaks
    janitor:Connect(modalBlocker.MouseButton1Down, function() end)
    janitor:Connect(modalBlocker.InputBegan, function() end)

    -- 1 BAR SHORTCUT (Top Bar: Drag + LogoTitle + Controls [-], [[]], [X])
    local shortcutBar = Instance.new("Frame")
    shortcutBar.Name = "ShortcutBar"
    shortcutBar.Size = UDim2.new(1, 0, 0, 42)
    shortcutBar.Position = UDim2.fromOffset(0, 0)
    shortcutBar.BorderSizePixel = 0
    shortcutBar.Active = true
    shortcutBar.ZIndex = 12
    shortcutBar.Parent = mainFrame
    window.ShortcutBar = shortcutBar

    local barDivider = Instance.new("Frame")
    barDivider.Name = "Divider"
    barDivider.Size = UDim2.new(1, 0, 0, 1)
    barDivider.Position = UDim2.new(0, 0, 1, -1)
    barDivider.BorderSizePixel = 0
    barDivider.ZIndex = 13
    barDivider.Parent = shortcutBar

    local topLogoBadge = Instance.new("Frame")
    topLogoBadge.Size = UDim2.fromOffset(26, 26)
    topLogoBadge.Position = UDim2.fromOffset(10, 8)
    topLogoBadge.ZIndex = 13
    topLogoBadge.Parent = shortcutBar
    ensureCorner(topLogoBadge, 6)

    local topLogoText = makeText(topLogoBadge, {
        Text = window.LogoText,
        Font = Enum.Font.GothamBlack,
        TextSize = 11,
        XAlign = Enum.TextXAlignment.Center,
        ZIndex = 14,
    })

    local topTitleLabel = makeText(shortcutBar, {
        Name = "TitleLabel",
        Position = UDim2.fromOffset(44, 4),
        Size = UDim2.new(0.5, -50, 0, 18),
        Text = window.Title,
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        Wrapped = false,
        Truncate = Enum.TextTruncate.AtEnd,
        ZIndex = 13,
    })

    local topBreadcrumb = makeText(shortcutBar, {
        Name = "Breadcrumb",
        Position = UDim2.fromOffset(44, 21),
        Size = UDim2.new(0.5, -50, 0, 14),
        Text = window.Subtitle,
        Font = Enum.Font.Gotham,
        TextSize = 10,
        Wrapped = false,
        Truncate = Enum.TextTruncate.AtEnd,
        ZIndex = 13,
    })

    -- Right-side Shortcut Bar controls: [RightTab Toggle] [-] [[]] [X]
    local controlsRow = Instance.new("Frame")
    controlsRow.Name = "Controls"
    controlsRow.Size = UDim2.fromOffset(174, 30)
    controlsRow.Position = UDim2.new(1, -182, 0, 6)
    controlsRow.BackgroundTransparency = 1
    controlsRow.ZIndex = 13
    controlsRow.Parent = shortcutBar

    local ctrlLayout = Instance.new("UIListLayout")
    ctrlLayout.FillDirection = Enum.FillDirection.Horizontal
    ctrlLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    ctrlLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    ctrlLayout.Padding = UDim.new(0, 6)
    ctrlLayout.Parent = controlsRow

    local function makeBarBtn(txt, w, roleColor)
        local b = Instance.new("TextButton")
        b.Size = UDim2.fromOffset(w, 26)
        b.Text = txt
        b.Font = Enum.Font.GothamBold
        b.TextSize = 12
        b.AutoButtonColor = false
        b.ZIndex = 14
        b.Parent = controlsRow
        ensureCorner(b, 6)
        return b, roleColor
    end

    local btnPrefsToggle = makeBarBtn("PREFS", 54)
    local btnMinimize = makeBarBtn("-", 30)
    local btnMaximize = makeBarBtn("[]", 32)
    local btnClose = makeBarBtn("X", 30)

    -- Body Container below ShortcutBar
    local bodyContainer = Instance.new("Frame")
    bodyContainer.Name = "BodyContainer"
    bodyContainer.Position = UDim2.fromOffset(0, 42)
    bodyContainer.Size = UDim2.new(1, 0, 1, -42)
    bodyContainer.BackgroundTransparency = 1
    bodyContainer.ZIndex = 11
    bodyContainer.Parent = mainFrame

    -- LEFT TAB (Sidebar Navigation)
    local leftTabFrame = Instance.new("Frame")
    leftTabFrame.Name = "LeftTab"
    leftTabFrame.Position = UDim2.fromOffset(0, 0)
    leftTabFrame.Size = UDim2.new(0.21, 0, 1, 0)
    leftTabFrame.BorderSizePixel = 0
    leftTabFrame.ZIndex = 12
    leftTabFrame.Parent = bodyContainer
    window.LeftTabFrame = leftTabFrame

    local leftBrandBox = Instance.new("Frame")
    leftBrandBox.Name = "BrandBox"
    leftBrandBox.Position = UDim2.fromOffset(8, 8)
    leftBrandBox.Size = UDim2.new(1, -16, 0, 56)
    leftBrandBox.ZIndex = 13
    leftBrandBox.Parent = leftTabFrame

    local leftLogoImg = Instance.new("ImageLabel")
    leftLogoImg.Size = UDim2.fromOffset(36, 36)
    leftLogoImg.Position = UDim2.fromOffset(10, 10)
    leftLogoImg.BackgroundTransparency = 0
    leftLogoImg.ScaleType = Enum.ScaleType.Fit
    leftLogoImg.ZIndex = 14
    leftLogoImg.Parent = leftBrandBox
    ensureCorner(leftLogoImg, 8)

    local leftLogoMono = makeText(leftLogoImg, {
        Text = window.LogoText,
        Font = Enum.Font.GothamBlack,
        TextSize = 14,
        XAlign = Enum.TextXAlignment.Center,
        ZIndex = 15,
    })

    local leftLogoTitle = makeText(leftBrandBox, {
        Position = UDim2.fromOffset(54, 10),
        Size = UDim2.new(1, -60, 0, 18),
        Text = window.Title,
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        Wrapped = false,
        Truncate = Enum.TextTruncate.AtEnd,
        ZIndex = 14,
    })

    local leftLogoSub = makeText(leftBrandBox, {
        Position = UDim2.fromOffset(54, 28),
        Size = UDim2.new(1, -60, 0, 14),
        Text = "v" .. Bootstrap.Version,
        Font = Enum.Font.RobotoMono,
        TextSize = 10,
        Wrapped = false,
        Truncate = Enum.TextTruncate.AtEnd,
        ZIndex = 14,
    })

    local leftNavScroller = Instance.new("ScrollingFrame")
    leftNavScroller.Name = "NavList"
    leftNavScroller.Position = UDim2.fromOffset(8, 72)
    leftNavScroller.Size = UDim2.new(1, -16, 1, -118)
    leftNavScroller.BackgroundTransparency = 1
    leftNavScroller.BorderSizePixel = 0
    leftNavScroller.ScrollBarThickness = 3
    leftNavScroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
    leftNavScroller.CanvasSize = UDim2.fromOffset(0, 0)
    leftNavScroller.ZIndex = 13
    leftNavScroller.Parent = leftTabFrame

    local navLayout = Instance.new("UIListLayout")
    navLayout.Padding = UDim.new(0, 6)
    navLayout.SortOrder = Enum.SortOrder.LayoutOrder
    navLayout.Parent = leftNavScroller

    local statusFooter = Instance.new("Frame")
    statusFooter.Name = "StatusFooter"
    statusFooter.Position = UDim2.new(0, 8, 1, -38)
    statusFooter.Size = UDim2.new(1, -16, 0, 30)
    statusFooter.ZIndex = 13
    statusFooter.Parent = leftTabFrame

    local statusLabel = makeText(statusFooter, {
        Position = UDim2.fromOffset(8, 0),
        Size = UDim2.new(1, -16, 1, 0),
        Text = "PERF: AUTO | FPS --",
        Font = Enum.Font.RobotoMono,
        TextSize = 10,
        ZIndex = 14,
    })

    -- CENTER TAB (Feature / Menu Content)
    local centerTabFrame = Instance.new("Frame")
    centerTabFrame.Name = "CenterTab"
    centerTabFrame.Position = UDim2.new(0.21, 0, 0, 0)
    centerTabFrame.Size = UDim2.new(0.53, 0, 1, 0)
    centerTabFrame.BackgroundTransparency = 1
    centerTabFrame.ZIndex = 11
    centerTabFrame.Parent = bodyContainer
    window.CenterTabFrame = centerTabFrame

    local centerHeader = Instance.new("Frame")
    centerHeader.Name = "CenterHeader"
    centerHeader.Position = UDim2.fromOffset(8, 8)
    centerHeader.Size = UDim2.new(1, -16, 0, 34)
    centerHeader.ZIndex = 12
    centerHeader.Parent = centerTabFrame

    local centerTitle = makeText(centerHeader, {
        Position = UDim2.fromOffset(10, 0),
        Size = UDim2.new(0.45, -10, 1, 0),
        Text = "MENU",
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        Wrapped = false,
        Truncate = Enum.TextTruncate.AtEnd,
        ZIndex = 13,
    })

    local centerMeta = makeText(centerHeader, {
        Position = UDim2.new(0.45, 0, 0, 0),
        Size = UDim2.new(0.55, -10, 1, 0),
        Text = "",
        Font = Enum.Font.RobotoMono,
        TextSize = 10,
        XAlign = Enum.TextXAlignment.Right,
        Wrapped = false,
        Truncate = Enum.TextTruncate.AtEnd,
        ZIndex = 13,
    })

    local centerContentHolder = Instance.new("Frame")
    centerContentHolder.Name = "ContentHolder"
    centerContentHolder.Position = UDim2.fromOffset(8, 48)
    centerContentHolder.Size = UDim2.new(1, -16, 1, -56)
    centerContentHolder.BackgroundTransparency = 1
    centerContentHolder.ClipsDescendants = true
    centerContentHolder.ZIndex = 12
    centerContentHolder.Parent = centerTabFrame
    window.CenterContentHolder = centerContentHolder

    -- RIGHT TAB (Further Preferences / Shortcut Inspector)
    local rightTabFrame = Instance.new("Frame")
    rightTabFrame.Name = "RightTab"
    rightTabFrame.Position = UDim2.new(0.74, 0, 0, 0)
    rightTabFrame.Size = UDim2.new(0.26, 0, 1, 0)
    rightTabFrame.BorderSizePixel = 0
    rightTabFrame.ZIndex = 12
    rightTabFrame.Parent = bodyContainer
    window.RightTabFrame = rightTabFrame

    local rightHeader = makeText(rightTabFrame, {
        Position = UDim2.fromOffset(10, 8),
        Size = UDim2.new(1, -20, 0, 22),
        Text = "PREFERENCES & SHORTCUTS",
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        ZIndex = 13,
    })

    local rightScroller = Instance.new("ScrollingFrame")
    rightScroller.Name = "RightScroller"
    rightScroller.Position = UDim2.fromOffset(8, 34)
    rightScroller.Size = UDim2.new(1, -16, 1, -42)
    rightScroller.BackgroundTransparency = 1
    rightScroller.BorderSizePixel = 0
    rightScroller.ScrollBarThickness = 3
    rightScroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
    rightScroller.CanvasSize = UDim2.fromOffset(0, 0)
    rightScroller.ZIndex = 13
    rightScroller.Parent = rightTabFrame
    window.RightScroller = rightScroller

    local rightLayout = Instance.new("UIListLayout")
    rightLayout.Padding = UDim.new(0, 8)
    rightLayout.SortOrder = Enum.SortOrder.LayoutOrder
    rightLayout.Parent = rightScroller

    -- Floating Draggable Shortcut Icon (Shown when Minimized)
    local shortcutIcon = Instance.new("TextButton")
    shortcutIcon.Name = "ShortcutIcon"
    shortcutIcon.Size = UDim2.fromOffset(132, 42)
    shortcutIcon.Position = UDim2.new(0, 18, 0.5, -21)
    shortcutIcon.Text = ""
    shortcutIcon.AutoButtonColor = false
    shortcutIcon.Visible = false
    shortcutIcon.Active = true
    shortcutIcon.ZIndex = 30
    shortcutIcon.Parent = screenGui
    ensureCorner(shortcutIcon, 21)
    window.ShortcutIcon = shortcutIcon

    local iconScale = Instance.new("UIScale")
    iconScale.Parent = shortcutIcon

    local shortcutBadge = Instance.new("Frame")
    shortcutBadge.Size = UDim2.fromOffset(28, 28)
    shortcutBadge.Position = UDim2.fromOffset(7, 7)
    shortcutBadge.ZIndex = 31
    shortcutBadge.Parent = shortcutIcon
    ensureCorner(shortcutBadge, 14)

    local shortcutBadgeTxt = makeText(shortcutBadge, {
        Text = window.LogoText,
        Font = Enum.Font.GothamBlack,
        TextSize = 11,
        XAlign = Enum.TextXAlignment.Center,
        ZIndex = 32,
    })

    local shortcutLabel = makeText(shortcutIcon, {
        Position = UDim2.fromOffset(42, 4),
        Size = UDim2.new(1, -48, 0, 18),
        Text = window.Title,
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        ZIndex = 31,
    })

    local shortcutHint = makeText(shortcutIcon, {
        Position = UDim2.fromOffset(42, 21),
        Size = UDim2.new(1, -48, 0, 14),
        Text = "Tap to Open",
        Font = Enum.Font.Gotham,
        TextSize = 9,
        ZIndex = 31,
    })

    -- Notification Toast Container
    local notifHolder = Instance.new("Frame")
    notifHolder.Name = "Notifications"
    notifHolder.AnchorPoint = Vector2.new(1, 1)
    notifHolder.Position = UDim2.new(1, -16, 1, -16)
    notifHolder.Size = UDim2.fromOffset(270, 320)
    notifHolder.BackgroundTransparency = 1
    notifHolder.ZIndex = 50
    notifHolder.Parent = screenGui
    window.NotifHolder = notifHolder

    local notifLayout = Instance.new("UIListLayout")
    notifLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
    notifLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    notifLayout.Padding = UDim.new(0, 8)
    notifLayout.SortOrder = Enum.SortOrder.LayoutOrder
    notifLayout.Parent = notifHolder

    -- Responsive Column & Scale Adjustment (Mobile HP <-> Desktop PC)
    local function updateColumnProportions()
        local vp = getViewportSize()
        local isCompact = vp.X < 640
        local leftPct = isCompact and 0.27 or 0.21
        local rightPct = isCompact and 0.36 or 0.26

        if window.RightTabOpen then
            leftTabFrame.Size = UDim2.new(leftPct, 0, 1, 0)
            centerTabFrame.Position = UDim2.new(leftPct, 0, 0, 0)
            centerTabFrame.Size = UDim2.new(1 - leftPct - rightPct, 0, 1, 0)
            rightTabFrame.Position = UDim2.new(1 - rightPct, 0, 0, 0)
            rightTabFrame.Size = UDim2.new(rightPct, 0, 1, 0)
            rightTabFrame.Visible = true
        else
            leftTabFrame.Size = UDim2.new(leftPct, 0, 1, 0)
            centerTabFrame.Position = UDim2.new(leftPct, 0, 0, 0)
            centerTabFrame.Size = UDim2.new(1 - leftPct, 0, 1, 0)
            rightTabFrame.Visible = false
        end
    end

    local function updateResponsiveScale()
        local vp = getViewportSize()
        local autoScale = math.clamp(math.min((vp.X - 18) / 890, (vp.Y - 18) / 540), 0.44, 1.15)
        if window.ScaleOverride and window.ScaleOverride > 0 then
            uiScale.Scale = window.ScaleOverride
        elseif window.Maximized then
            uiScale.Scale = 1
            mainFrame.Size = UDim2.fromOffset(math.max(300, vp.X - 16), math.max(240, vp.Y - 16))
            mainFrame.Position = UDim2.fromScale(0.5, 0.5)
        else
            uiScale.Scale = autoScale
            mainFrame.Size = baseSize
        end
        iconScale.Scale = math.clamp(autoScale * 1.05, 0.72, 1.1)
        updateColumnProportions()
        if window._activeTab then
            window:RefreshLayout()
        end
    end

    local function bindCameraListener()
        local cam = workspace.CurrentCamera
        if cam then
            janitor:Connect(cam:GetPropertyChangedSignal("ViewportSize"), updateResponsiveScale)
        end
    end
    bindCameraListener()
    janitor:Connect(workspace:GetPropertyChangedSignal("CurrentCamera"), function()
        bindCameraListener()
        updateResponsiveScale()
    end)

    -- Draggable helper (works on Mouse & Touch; distinguishes drag vs tap)
    local function makeDraggable(handle, target, onTap)
        local dragging = false
        local dragMoved = false
        local activeInput = nil
        local startPos = Vector2.zero
        local targetStartPos = target.Position

        janitor:Connect(handle.InputBegan, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                if window.Maximized and target == mainFrame then
                    return
                end
                dragging = true
                dragMoved = false
                activeInput = input
                startPos = Vector2.new(input.Position.X, input.Position.Y)
                targetStartPos = target.Position
            end
        end)

        janitor:Connect(UserInputService.InputChanged, function(input)
            if not dragging then
                return
            end
            if input.UserInputType == Enum.UserInputType.MouseMovement or input == activeInput then
                local cur = Vector2.new(input.Position.X, input.Position.Y)
                local delta = cur - startPos
                if delta.Magnitude > 5 then
                    dragMoved = true
                end
                if dragMoved then
                    target.Position = UDim2.new(
                        targetStartPos.X.Scale,
                        targetStartPos.X.Offset + delta.X,
                        targetStartPos.Y.Scale,
                        targetStartPos.Y.Offset + delta.Y
                    )
                end
            end
        end)

        janitor:Connect(UserInputService.InputEnded, function(input)
            if dragging and (input == activeInput or input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
                local wasTap = not dragMoved
                dragging = false
                activeInput = nil
                if wasTap and onTap then
                    onTap()
                end
            end
        end)
    end

    makeDraggable(shortcutBar, mainFrame)
    makeDraggable(shortcutIcon, shortcutIcon, function()
        window:SetMinimized(false)
    end)

    -- Window Control Actions: Minimize [-], Maximize [[]], Close [X], RightTab Toggle
    function window:SetMinimized(state)
        self.Minimized = state
        mainFrame.Visible = not state
        shortcutIcon.Visible = state
        updateInputLock()
    end

    function window:SetMaximized(state)
        self.Maximized = state
        btnMaximize.Text = state and "[-]" or "[]"
        if state then
            uiScale.Scale = 1
            local vp = getViewportSize()
            safeTween(mainFrame, {
                Position = UDim2.fromScale(0.5, 0.5),
                Size = UDim2.fromOffset(math.max(300, vp.X - 16), math.max(240, vp.Y - 16)),
            }, self.PerfTier.TweenTime)
        else
            mainFrame.Position = UDim2.fromScale(0.5, 0.5)
            updateResponsiveScale()
        end
        taskLib.defer(function()
            self:RefreshLayout()
        end)
    end

    function window:ToggleRightTab(forceState)
        if forceState ~= nil then
            self.RightTabOpen = forceState
        else
            self.RightTabOpen = not self.RightTabOpen
        end
        updateColumnProportions()
        taskLib.defer(function()
            self:RefreshLayout()
        end)
    end

    function window:Close()
        if self.Closed then
            return
        end
        self.Closed = true
        updateInputLock()
        janitor:Cleanup()
    end

    janitor:Connect(btnMinimize.MouseButton1Click, function()
        window:SetMinimized(true)
    end)
    janitor:Connect(btnMaximize.MouseButton1Click, function()
        window:SetMaximized(not window.Maximized)
    end)
    janitor:Connect(btnClose.MouseButton1Click, function()
        window:Close()
    end)
    janitor:Connect(btnPrefsToggle.MouseButton1Click, function()
        window:ToggleRightTab()
    end)

    -- Auto Performance FPS Monitor (Throttled, zero UI thrash)
    local frameAccum = 0
    local frameCount = 0
    local lastEval = os.clock()
    janitor:Connect(RunService.RenderStepped, function(dt)
        if window.Closed or window.Minimized then
            return
        end
        frameAccum = frameAccum + dt
        frameCount = frameCount + 1
        local now = os.clock()
        if now - lastEval >= 1.5 then
            local avgFps = math.round(frameCount / math.max(frameAccum, 0.001))
            frameAccum = 0
            frameCount = 0
            lastEval = now
            if window.PerfMode == "Auto" then
                if avgFps < 34 then
                    window.PerfTier = PerformanceTiers.Low
                elseif avgFps < 52 then
                    window.PerfTier = PerformanceTiers.Medium
                else
                    window.PerfTier = PerformanceTiers.High
                end
            end
            statusLabel.Text = string.format("PERF:%s | %d FPS", window.PerfTier.Name:upper(), avgFps)
        end
    end)

    -- Theme & Visual Refresh Engine
    function window:RegisterThemeHook(fn)
        table.insert(self._themeHooks, fn)
        fn(self.Palette, self:GetVisual(), self.PerfTier)
    end

    function window:GetVisual()
        return Bootstrap.Visuals[self.VisualName] or Bootstrap.Visuals.Minimalist
    end

    function window:ApplyTheme()
        local pal = self.Palette
        local vis = self:GetVisual()
        local perf = self.PerfTier

        applyVisualToSurface(mainFrame, vis, pal, perf, "Window")
        shortcutBar.BackgroundColor3 = pal.Sidebar
        barDivider.BackgroundColor3 = pal.Border
        topLogoBadge.BackgroundColor3 = pal.Primary
        topLogoText.Text = self.LogoText
        topLogoText.TextColor3 = Color3.new(1, 1, 1)
        topTitleLabel.Text = self.Title
        topTitleLabel.TextColor3 = pal.Text
        topTitleLabel.Font = vis.FontTitle
        topBreadcrumb.TextColor3 = pal.MutedText

        btnPrefsToggle.BackgroundColor3 = pal.SurfaceAlt
        btnPrefsToggle.TextColor3 = pal.Text
        btnMinimize.BackgroundColor3 = pal.SurfaceAlt
        btnMinimize.TextColor3 = pal.Text
        btnMaximize.BackgroundColor3 = pal.SurfaceAlt
        btnMaximize.TextColor3 = pal.Text
        btnClose.BackgroundColor3 = pal.Danger
        btnClose.TextColor3 = Color3.new(1, 1, 1)

        leftTabFrame.BackgroundColor3 = pal.Sidebar
        applyVisualToSurface(leftBrandBox, vis, pal, perf, "SurfaceAlt")
        leftLogoImg.BackgroundColor3 = pal.Primary
        leftLogoImg.Image = self.LogoImage or ""
        leftLogoMono.Visible = (self.LogoImage == nil or self.LogoImage == "")
        leftLogoMono.Text = self.LogoText
        leftLogoTitle.Text = self.Title
        leftLogoTitle.TextColor3 = pal.Text
        leftLogoTitle.Font = vis.FontTitle
        leftLogoSub.TextColor3 = pal.MutedText

        applyVisualToSurface(statusFooter, vis, pal, perf, "SurfaceAlt")
        statusLabel.TextColor3 = pal.MutedText

        applyVisualToSurface(centerHeader, vis, pal, perf, "Surface")
        centerTitle.TextColor3 = pal.Text
        centerTitle.Font = vis.FontTitle
        centerMeta.TextColor3 = pal.Secondary
        centerMeta.Text = string.format("%s | %s | %s", self.GridName, self.PatternName, self.VisualName)

        rightTabFrame.BackgroundColor3 = pal.Sidebar
        rightHeader.TextColor3 = pal.MutedText
        rightHeader.Font = vis.FontTitle

        shortcutIcon.BackgroundColor3 = pal.Surface
        ensureStroke(shortcutIcon, pal.Primary, 1.5, 0.1)
        shortcutBadge.BackgroundColor3 = pal.Primary
        shortcutBadgeTxt.Text = self.LogoText
        shortcutLabel.Text = self.Title
        shortcutLabel.TextColor3 = pal.Text
        shortcutHint.TextColor3 = pal.MutedText

        for _, hook in ipairs(self._themeHooks) do
            pcall(hook, pal, vis, perf)
        end
        self:RefreshLayout()
    end

    function window:SetLogo(cfg)
        if cfg.Title then self.Title = cfg.Title end
        if cfg.Subtitle then self.Subtitle = cfg.Subtitle end
        if cfg.LogoText then self.LogoText = cfg.LogoText end
        if cfg.LogoImage ~= nil then self.LogoImage = cfg.LogoImage end
        if cfg.Version then leftLogoSub.Text = cfg.Version end
        self:ApplyTheme()
    end

    function window:SetPalette(nameOrTable)
        if type(nameOrTable) == "string" then
            local found = Bootstrap.Palettes[nameOrTable]
            if found then
                self.PaletteName = nameOrTable
                self.Palette = copyPalette(found)
            end
        elseif type(nameOrTable) == "table" then
            self.PaletteName = "Custom"
            for k, v in pairs(nameOrTable) do
                self.Palette[k] = v
            end
        end
        self:ApplyTheme()
    end

    function window:SetColor(role, color3)
        self.Palette[role] = color3
        self.PaletteName = "Custom"
        self:ApplyTheme()
    end

    function window:SaveColorPreset(presetName, customTable)
        local cleanName = tostring(presetName or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if cleanName == "" then
            cleanName = "Custom_" .. tostring(math.random(100, 999))
        end
        local pal = copyPalette(self.Palette)
        if type(customTable) == "table" then
            for role, col in pairs(customTable) do
                pal[role] = col
            end
        end
        if not Bootstrap.Palettes[cleanName] then
            table.insert(Bootstrap.PaletteOrder, cleanName)
        end
        Bootstrap.Palettes[cleanName] = pal
        self.PaletteName = cleanName
        self.Palette = copyPalette(pal)
        local persisted = persistPresetToFile(cleanName, pal)
        for _, cb in ipairs(self._onPresetSavedCallbacks) do
            pcall(cb, cleanName, persisted)
        end
        self:ApplyTheme()
        return cleanName, persisted
    end

    function window:SetGrid(gridName)
        self.GridName = gridName
        self:ApplyTheme()
    end

    function window:SetPattern(patternName)
        self.PatternName = patternName
        self:ApplyTheme()
    end

    function window:SetVisual(visualName)
        if Bootstrap.Visuals[visualName] then
            self.VisualName = visualName
            self:ApplyTheme()
        end
    end

    function window:SetPerformanceMode(mode)
        self.PerfMode = mode
        if mode ~= "Auto" and PerformanceTiers[mode] then
            self.PerfTier = PerformanceTiers[mode]
        end
        self:ApplyTheme()
    end

    function window:SetBlockers(blockCanvas, blockTopbar)
        if blockCanvas ~= nil then self.BlockGameCanvas = blockCanvas end
        if blockTopbar ~= nil then self.BlockTopbar = blockTopbar end
        updateInputLock()
    end

    function window:SetScaleOverride(scaleVal)
        self.ScaleOverride = scaleVal or 0
        updateResponsiveScale()
    end

    -- Notifications (Component #11)
    function window:Notify(cfg)
        cfg = cfg or {}
        local pal = self.Palette
        local vis = self:GetVisual()
        local kind = cfg.Type or "Info"
        local accent = pal.Primary
        if kind == "Success" then accent = pal.Success
        elseif kind == "Warning" then accent = pal.Warning
        elseif kind == "Error" then accent = pal.Danger end

        local toast = Instance.new("Frame")
        toast.Size = UDim2.fromOffset(264, 68)
        toast.BackgroundColor3 = pal.Surface
        toast.ClipsDescendants = true
        toast.ZIndex = 55
        toast.Parent = notifHolder
        ensureCorner(toast, vis.CornerRadius)
        ensureStroke(toast, accent, 1.5, 0.2)

        local stripe = Instance.new("Frame")
        stripe.Size = UDim2.new(0, 4, 1, 0)
        stripe.BackgroundColor3 = accent
        stripe.BorderSizePixel = 0
        stripe.ZIndex = 56
        stripe.Parent = toast

        makeText(toast, {
            Position = UDim2.fromOffset(12, 6),
            Size = UDim2.new(1, -40, 0, 18),
            Text = cfg.Title or kind,
            Font = vis.FontTitle,
            TextSize = 12,
            TextColor = pal.Text,
            ZIndex = 56,
        })

        makeText(toast, {
            Position = UDim2.fromOffset(12, 24),
            Size = UDim2.new(1, -20, 0, 34),
            Text = cfg.Content or "",
            Font = vis.FontBody,
            TextSize = 11,
            TextColor = pal.MutedText,
            YAlign = Enum.TextYAlignment.Top,
            ZIndex = 56,
        })

        local closeT = makeText(toast, {
            IsButton = true,
            Position = UDim2.new(1, -24, 0, 6),
            Size = UDim2.fromOffset(18, 18),
            Text = "x",
            Font = Enum.Font.GothamBold,
            TextSize = 11,
            TextColor = pal.MutedText,
            XAlign = Enum.TextXAlignment.Center,
            ZIndex = 57,
        })

        local lifeBar = Instance.new("Frame")
        lifeBar.Size = UDim2.new(1, 0, 0, 3)
        lifeBar.Position = UDim2.new(0, 0, 1, -3)
        lifeBar.BackgroundColor3 = accent
        lifeBar.BorderSizePixel = 0
        lifeBar.ZIndex = 56
        lifeBar.Parent = toast

        local dismissed = false
        local function dismiss()
            if dismissed then return end
            dismissed = true
            if toast.Parent then toast:Destroy() end
        end
        janitor:Connect(closeT.MouseButton1Click, dismiss)

        local dur = cfg.Duration or 3.5
        safeTween(lifeBar, { Size = UDim2.new(0, 0, 0, 3) }, dur, Enum.EasingStyle.Linear)
        taskLib.spawn(function()
            taskLib.wait(dur)
            dismiss()
        end)
        return { Dismiss = dismiss }
    end

    -- Modal Window Loading Overlay (Component #12)
    function window:ShowLoading(cfg)
        cfg = cfg or {}
        local pal = self.Palette
        local vis = self:GetVisual()

        local overlay = Instance.new("Frame")
        overlay.Name = "LoadingOverlay"
        overlay.Size = UDim2.fromScale(1, 1)
        overlay.BackgroundColor3 = pal.Background
        overlay.BackgroundTransparency = 0.25
        overlay.Active = true
        overlay.ZIndex = 40
        overlay.Parent = mainFrame

        local box = Instance.new("Frame")
        box.Size = UDim2.fromOffset(270, 118)
        box.AnchorPoint = Vector2.new(0.5, 0.5)
        box.Position = UDim2.fromScale(0.5, 0.5)
        box.ZIndex = 41
        box.Parent = overlay
        applyVisualToSurface(box, vis, pal, self.PerfTier, "Surface")

        local spinner = Instance.new("Frame")
        spinner.Size = UDim2.fromOffset(22, 22)
        spinner.Position = UDim2.fromOffset(16, 16)
        spinner.BackgroundColor3 = pal.Primary
        spinner.ZIndex = 42
        spinner.Parent = box
        ensureCorner(spinner, 5)

        local titleL = makeText(box, {
            Position = UDim2.fromOffset(48, 14),
            Size = UDim2.new(1, -60, 0, 22),
            Text = cfg.Title or "Loading...",
            Font = vis.FontTitle,
            TextSize = 13,
            TextColor = pal.Text,
            ZIndex = 42,
        })

        local statusL = makeText(box, {
            Position = UDim2.fromOffset(16, 48),
            Size = UDim2.new(1, -32, 0, 22),
            Text = cfg.Status or "Initializing components...",
            Font = vis.FontBody,
            TextSize = 11,
            TextColor = pal.MutedText,
            ZIndex = 42,
        })

        local track = Instance.new("Frame")
        track.Position = UDim2.fromOffset(16, 82)
        track.Size = UDim2.new(1, -32, 0, 10)
        track.BackgroundColor3 = pal.SurfaceAlt
        track.ZIndex = 42
        track.Parent = box
        ensureCorner(track, 5)

        local fill = Instance.new("Frame")
        fill.Size = UDim2.new(cfg.Progress or 0.1, 0, 1, 0)
        fill.BackgroundColor3 = pal.Primary
        fill.ZIndex = 43
        fill.Parent = track
        ensureCorner(fill, 5)

        local alive = true
        local spinConn = janitor:Connect(RunService.RenderStepped, function(dt)
            if not alive or not spinner.Parent then return end
            spinner.Rotation = (spinner.Rotation + dt * 240) % 360
        end)

        local controller = {}
        function controller:SetProgress(pct, text)
            local p = math.clamp(pct or 0, 0, 1)
            safeTween(fill, { Size = UDim2.new(p, 0, 1, 0) }, window.PerfTier.TweenTime)
            if text then statusL.Text = text end
        end
        function controller:SetTitle(t)
            titleL.Text = t
        end
        function controller:Finish()
            alive = false
            if spinConn and spinConn.Connected then spinConn:Disconnect() end
            if overlay.Parent then overlay:Destroy() end
        end
        return controller
    end

    --========================================================================--
    -- 8. COMPONENT FACTORY (ATTACHED TO TAB OR NESTED LAYOUT)
    --========================================================================--

    local function attachComponentMethods(containerApi, windowRef, itemsList, scrollerRef, isNested)
        local function registerItem(itemType, root, cfg, hookFn)
            local rec = {
                Type = itemType,
                Root = root,
                ColSpan = cfg.ColSpan,
                FullWidth = cfg.FullWidth,
                PreferredHeight = cfg.Height or 64,
                Index = #itemsList + 1,
            }
            table.insert(itemsList, rec)
            if hookFn then
                windowRef:RegisterThemeHook(function(pal, vis, perf)
                    hookFn(pal, vis, perf, rec.Index)
                end)
            end
            if not isNested then
                windowRef:QueueLayoutRefresh()
            elseif containerApi._relayout then
                containerApi._relayout()
            end
            return rec
        end

        local function buildControlObj(rec, extra)
            local obj = extra or {}
            function obj:SetVisible(vis)
                rec.Root.Visible = vis
            end
            function obj:Destroy()
                for i, v in ipairs(itemsList) do
                    if v == rec then
                        table.remove(itemsList, i)
                        break
                    end
                end
                if rec.Root.Parent then rec.Root:Destroy() end
                windowRef:RefreshLayout()
            end
            return obj
        end

        -- 1. TITLE
        function containerApi:AddTitle(cfg)
            cfg = cfg or {}
            local root = Instance.new("Frame")
            root.Name = "TitleBlock"
            local tLbl = makeText(root, {
                Position = UDim2.fromOffset(10, 4),
                Size = UDim2.new(1, -20, 0, 22),
                Text = cfg.Title or "Section Title",
                TextSize = cfg.TextSize or 15,
            })
            local subLbl = makeText(root, {
                Position = UDim2.fromOffset(10, 25),
                Size = UDim2.new(1, -20, 0, 15),
                Text = cfg.Subtitle or "",
                TextSize = 11,
            })
            local line = Instance.new("Frame")
            line.Position = UDim2.new(0, 10, 1, -3)
            line.Size = UDim2.new(0, 44, 0, 2)
            line.BorderSizePixel = 0
            line.ZIndex = 4
            line.Parent = root

            local rec = registerItem("Title", root, {
                ColSpan = cfg.ColSpan or 12,
                FullWidth = cfg.FullWidth ~= false,
                Height = cfg.Subtitle and 46 or 38,
            }, function(pal, vis, perf, idx)
                applyVisualToSurface(root, vis, pal, perf, "SurfaceAlt", idx)
                tLbl.Font = vis.FontTitle
                tLbl.TextColor3 = pal.Text
                subLbl.Font = vis.FontBody
                subLbl.TextColor3 = pal.MutedText
                subLbl.Visible = (subLbl.Text ~= "")
                line.BackgroundColor3 = pal.Primary
            end)

            return buildControlObj(rec, {
                SetTitle = function(_, txt) tLbl.Text = txt end,
                SetSubtitle = function(_, txt) subLbl.Text = txt end,
            })
        end

        -- 2. LABEL
        function containerApi:AddLabel(cfg)
            cfg = cfg or {}
            local root = Instance.new("Frame")
            root.Name = "LabelBlock"
            local badge = makeText(root, {
                Position = UDim2.fromOffset(8, 8),
                Size = UDim2.fromOffset(22, 22),
                Text = cfg.Icon or "i",
                Font = Enum.Font.RobotoMono,
                TextSize = 11,
                BgTransparency = 0,
                XAlign = Enum.TextXAlignment.Center,
            })
            ensureCorner(badge, 6)

            local txtL = makeText(root, {
                Position = UDim2.fromOffset(38, 6),
                Size = UDim2.new(1, -48, 1, -12),
                Text = cfg.Text or "Information label",
                TextSize = 12,
            })

            local rec = registerItem("Label", root, {
                ColSpan = cfg.ColSpan or 12,
                FullWidth = cfg.FullWidth,
                Height = cfg.Height or 42,
            }, function(pal, vis, perf, idx)
                applyVisualToSurface(root, vis, pal, perf, "Surface", idx)
                badge.BackgroundColor3 = pal.SurfaceAlt
                badge.TextColor3 = pal.Secondary
                txtL.Font = vis.FontBody
                txtL.TextColor3 = pal.Text
            end)

            return buildControlObj(rec, {
                SetText = function(_, t) txtL.Text = t end,
                GetText = function() return txtL.Text end,
            })
        end

        -- 3. LOGO / LOGO TITLE
        function containerApi:AddLogo(cfg)
            cfg = cfg or {}
            local root = Instance.new("Frame")
            root.Name = "LogoBlock"
            local iconBox = Instance.new("ImageLabel")
            iconBox.Size = UDim2.fromOffset(44, 44)
            iconBox.Position = UDim2.fromOffset(10, 10)
            iconBox.Image = cfg.Image or ""
            iconBox.ScaleType = Enum.ScaleType.Fit
            iconBox.ZIndex = 4
            iconBox.Parent = root
            ensureCorner(iconBox, 10)

            local monoL = makeText(iconBox, {
                Text = cfg.Monogram or "LG",
                Font = Enum.Font.GothamBlack,
                TextSize = 15,
                XAlign = Enum.TextXAlignment.Center,
                ZIndex = 5,
            })
            monoL.Visible = (iconBox.Image == "")

            local titleL = makeText(root, {
                Position = UDim2.fromOffset(64, 11),
                Size = UDim2.new(1, -74, 0, 20),
                Text = cfg.Title or "Brand Logo",
                TextSize = 14,
            })
            local tagL = makeText(root, {
                Position = UDim2.fromOffset(64, 32),
                Size = UDim2.new(1, -74, 0, 16),
                Text = cfg.Subtitle or "Modular Framework",
                TextSize = 11,
            })

            local rec = registerItem("Logo", root, {
                ColSpan = cfg.ColSpan or 6,
                FullWidth = cfg.FullWidth,
                Height = cfg.Height or 64,
            }, function(pal, vis, perf, idx)
                applyVisualToSurface(root, vis, pal, perf, "Surface", idx)
                iconBox.BackgroundColor3 = pal.Primary
                monoL.TextColor3 = Color3.new(1, 1, 1)
                titleL.Font = vis.FontTitle
                titleL.TextColor3 = pal.Text
                tagL.Font = vis.FontBody
                tagL.TextColor3 = pal.MutedText
            end)

            return buildControlObj(rec, {
                SetLogo = function(_, newCfg)
                    if newCfg.Title then titleL.Text = newCfg.Title end
                    if newCfg.Subtitle then tagL.Text = newCfg.Subtitle end
                    if newCfg.Monogram then monoL.Text = newCfg.Monogram end
                    if newCfg.Image ~= nil then
                        iconBox.Image = newCfg.Image
                        monoL.Visible = (newCfg.Image == "")
                    end
                end,
            })
        end

        -- 4. BUTTON
        function containerApi:AddButton(cfg)
            cfg = cfg or {}
            local root = Instance.new("TextButton")
            root.Name = "ButtonBlock"
            root.Text = ""
            root.AutoButtonColor = false

            local titleL = makeText(root, {
                Position = UDim2.fromOffset(10, 5),
                Size = UDim2.new(1, -20, 0, 18),
                Text = cfg.Title or "Action Button",
                TextSize = 12,
                XAlign = cfg.Description and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center,
            })
            local descL = makeText(root, {
                Position = UDim2.fromOffset(10, 23),
                Size = UDim2.new(1, -20, 0, 14),
                Text = cfg.Description or "",
                TextSize = 10,
                XAlign = Enum.TextXAlignment.Left,
            })

            local variant = cfg.Variant or "Primary" -- Primary | Secondary | Danger | Ghost
            local rec = registerItem("Button", root, {
                ColSpan = cfg.ColSpan or 4,
                FullWidth = cfg.FullWidth,
                Height = cfg.Height or (cfg.Description and 46 or 40),
            }, function(pal, vis, perf, idx)
                local role = (variant == "Primary" and "Primary") or "SurfaceAlt"
                applyVisualToSurface(root, vis, pal, perf, role, idx)
                if variant == "Danger" then
                    root.BackgroundColor3 = pal.Danger
                elseif variant == "Secondary" then
                    root.BackgroundColor3 = pal.Secondary
                end
                titleL.Font = vis.FontTitle
                titleL.TextColor3 = (variant == "Ghost") and pal.Text or Color3.new(1, 1, 1)
                if variant == "Secondary" then titleL.TextColor3 = pal.Text end
                descL.Font = vis.FontBody
                descL.TextColor3 = (variant == "Primary" or variant == "Danger") and Color3.fromRGB(235, 240, 250) or pal.MutedText
                descL.Visible = (descL.Text ~= "")
                if not descL.Visible then
                    titleL.Size = UDim2.new(1, -20, 1, -10)
                else
                    titleL.Size = UDim2.new(1, -20, 0, 18)
                end
            end)

            janitor:Connect(root.MouseButton1Click, function()
                local orig = root.BackgroundTransparency
                root.BackgroundTransparency = 0.25
                safeTween(root, { BackgroundTransparency = orig }, windowRef.PerfTier.TweenTime)
                if cfg.Callback then
                    taskLib.spawn(cfg.Callback)
                end
            end)

            return buildControlObj(rec, {
                SetText = function(_, t) titleL.Text = t end,
            })
        end

        -- 5. TOGGLE
        function containerApi:AddToggle(cfg)
            cfg = cfg or {}
            local state = cfg.Default == true
            local root = Instance.new("TextButton")
            root.Name = "ToggleBlock"
            root.Text = ""
            root.AutoButtonColor = false

            local titleL = makeText(root, {
                Position = UDim2.fromOffset(10, 6),
                Size = UDim2.new(1, -68, 0, 18),
                Text = cfg.Title or "Toggle",
                TextSize = 12,
            })
            local descL = makeText(root, {
                Position = UDim2.fromOffset(10, 23),
                Size = UDim2.new(1, -68, 0, 14),
                Text = cfg.Description or "",
                TextSize = 10,
            })

            local track = Instance.new("Frame")
            track.Size = UDim2.fromOffset(42, 22)
            track.Position = UDim2.new(1, -52, 0.5, -11)
            track.ZIndex = 4
            track.Parent = root
            ensureCorner(track, 11)

            local knob = Instance.new("Frame")
            knob.Size = UDim2.fromOffset(16, 16)
            knob.Position = UDim2.fromOffset(state and 23 or 3, 3)
            knob.BackgroundColor3 = Color3.new(1, 1, 1)
            knob.ZIndex = 5
            knob.Parent = track
            ensureCorner(knob, 8)

            local function syncVisual(animate)
                local pal = windowRef.Palette
                local dur = animate and windowRef.PerfTier.TweenTime or 0
                safeTween(track, { BackgroundColor3 = state and pal.Primary or pal.SurfaceAlt }, dur)
                safeTween(knob, { Position = UDim2.fromOffset(state and 23 or 3, 3) }, dur)
            end

            local rec = registerItem("Toggle", root, {
                ColSpan = cfg.ColSpan or 4,
                FullWidth = cfg.FullWidth,
                Height = cfg.Height or 46,
            }, function(pal, vis, perf, idx)
                applyVisualToSurface(root, vis, pal, perf, "Surface", idx)
                titleL.Font = vis.FontTitle
                titleL.TextColor3 = pal.Text
                descL.Font = vis.FontBody
                descL.TextColor3 = pal.MutedText
                descL.Visible = (descL.Text ~= "")
                if not descL.Visible then
                    titleL.Size = UDim2.new(1, -68, 1, -12)
                end
                ensureStroke(track, pal.Border, 1, 0.4)
                syncVisual(false)
            end)

            local function setValue(v, fireCb)
                state = v == true
                syncVisual(true)
                if fireCb and cfg.Callback then
                    taskLib.spawn(cfg.Callback, state)
                end
            end

            janitor:Connect(root.MouseButton1Click, function()
                setValue(not state, true)
            end)

            return buildControlObj(rec, {
                Set = function(_, v) setValue(v, false) end,
                Get = function() return state end,
            })
        end

        -- 6. RADIO
        function containerApi:AddRadio(cfg)
            cfg = cfg or {}
            local options = cfg.Options or { "Option A", "Option B", "Option C" }
            local selected = cfg.Default or options[1]

            local root = Instance.new("Frame")
            root.Name = "RadioBlock"

            local titleL = makeText(root, {
                Position = UDim2.fromOffset(10, 6),
                Size = UDim2.new(1, -20, 0, 18),
                Text = cfg.Title or "Radio Selection",
                TextSize = 12,
            })

            local optHolder = Instance.new("Frame")
            optHolder.Position = UDim2.fromOffset(10, 28)
            optHolder.Size = UDim2.new(1, -20, 1, -34)
            optHolder.BackgroundTransparency = 1
            optHolder.ZIndex = 4
            optHolder.Parent = root

            local list = Instance.new("UIListLayout")
            list.Padding = UDim.new(0, 4)
            list.Parent = optHolder

            local optButtons = {}
            local function refreshRadio()
                local pal = windowRef.Palette
                for _, entry in ipairs(optButtons) do
                    local isSel = (entry.Value == selected)
                    entry.Dot.BackgroundColor3 = isSel and pal.Primary or pal.SurfaceAlt
                    entry.InnerDot.Visible = isSel
                    entry.Label.TextColor3 = isSel and pal.Text or pal.MutedText
                    entry.Row.BackgroundColor3 = isSel and pal.SurfaceAlt or pal.Background
                end
            end

            for _, opt in ipairs(options) do
                local row = Instance.new("TextButton")
                row.Size = UDim2.new(1, 0, 0, 24)
                row.Text = ""
                row.AutoButtonColor = false
                row.ZIndex = 4
                row.Parent = optHolder
                ensureCorner(row, 6)

                local dot = Instance.new("Frame")
                dot.Size = UDim2.fromOffset(14, 14)
                dot.Position = UDim2.fromOffset(6, 5)
                dot.ZIndex = 5
                dot.Parent = row
                ensureCorner(dot, 7)

                local innerDot = Instance.new("Frame")
                innerDot.Size = UDim2.fromOffset(6, 6)
                innerDot.Position = UDim2.fromOffset(4, 4)
                innerDot.BackgroundColor3 = Color3.new(1, 1, 1)
                innerDot.ZIndex = 6
                innerDot.Parent = dot
                ensureCorner(innerDot, 3)

                local lbl = makeText(row, {
                    Position = UDim2.fromOffset(26, 0),
                    Size = UDim2.new(1, -32, 1, 0),
                    Text = tostring(opt),
                    TextSize = 11,
                    ZIndex = 5,
                })

                table.insert(optButtons, { Value = opt, Row = row, Dot = dot, InnerDot = innerDot, Label = lbl })
                janitor:Connect(row.MouseButton1Click, function()
                    selected = opt
                    refreshRadio()
                    if cfg.Callback then
                        taskLib.spawn(cfg.Callback, selected)
                    end
                end)
            end

            local calcH = 36 + (#options * 28)
            local rec = registerItem("Radio", root, {
                ColSpan = cfg.ColSpan or 6,
                FullWidth = cfg.FullWidth,
                Height = cfg.Height or calcH,
            }, function(pal, vis, perf, idx)
                applyVisualToSurface(root, vis, pal, perf, "Surface", idx)
                titleL.Font = vis.FontTitle
                titleL.TextColor3 = pal.Text
                for _, e in ipairs(optButtons) do
                    e.Label.Font = vis.FontBody
                end
                refreshRadio()
            end)

            return buildControlObj(rec, {
                Set = function(_, val) selected = val; refreshRadio() end,
                Get = function() return selected end,
            })
        end

        -- 7. CARD (WITH IMG OR WITHOUT IMG)
        function containerApi:AddCard(cfg)
            cfg = cfg or {}
            local withImage = cfg.WithImage ~= false and (cfg.Image ~= nil or cfg.WithImage == true)
            local root = Instance.new("Frame")
            root.Name = "CardBlock"
            root.ClipsDescendants = false

            local imgFrame = Instance.new("ImageLabel")
            imgFrame.Position = UDim2.fromOffset(8, 8)
            imgFrame.Size = UDim2.new(1, -16, 0, withImage and 64 or 0)
            imgFrame.Visible = withImage
            imgFrame.ClipsDescendants = true
            imgFrame.Image = cfg.Image or ""
            imgFrame.ScaleType = Enum.ScaleType.Crop
            imgFrame.ZIndex = 4
            imgFrame.Parent = root
            ensureCorner(imgFrame, 8)

            local fallbackArt = makeText(imgFrame, {
                Text = cfg.ImageBadge or "MEDIA PREVIEW",
                Font = Enum.Font.RobotoMono,
                TextSize = 11,
                XAlign = Enum.TextXAlignment.Center,
                ZIndex = 5,
            })
            fallbackArt.Visible = withImage and (imgFrame.Image == "")

            local yStart = withImage and 78 or 10
            local badge = makeText(root, {
                Position = UDim2.fromOffset(10, yStart),
                Size = UDim2.fromOffset(74, 16),
                Text = cfg.Badge or "FEATURE",
                Font = Enum.Font.RobotoMono,
                TextSize = 9,
                BgTransparency = 0,
                XAlign = Enum.TextXAlignment.Center,
                ZIndex = 4,
            })
            ensureCorner(badge, 4)
            badge.Visible = (cfg.Badge ~= false)

            local titleY = badge.Visible and (yStart + 20) or yStart
            local titleL = makeText(root, {
                Position = UDim2.fromOffset(10, titleY),
                Size = UDim2.new(1, -20, 0, 18),
                Text = cfg.Title or "Card Item",
                TextSize = 13,
                ZIndex = 4,
            })

            local bodyL = makeText(root, {
                Position = UDim2.fromOffset(10, titleY + 20),
                Size = UDim2.new(1, -20, 1, -(titleY + (cfg.ActionText and 54 or 24))),
                Text = cfg.Body or "Reusable card container.",
                TextSize = 11,
                YAlign = Enum.TextYAlignment.Top,
                ZIndex = 4,
            })

            local actionBtn
            if cfg.ActionText then
                actionBtn = makeText(root, {
                    IsButton = true,
                    Position = UDim2.new(0, 10, 1, -34),
                    Size = UDim2.new(1, -20, 0, 26),
                    Text = cfg.ActionText,
                    Font = Enum.Font.GothamBold,
                    TextSize = 11,
                    BgTransparency = 0,
                    XAlign = Enum.TextXAlignment.Center,
                    ZIndex = 5,
                })
                ensureCorner(actionBtn, 6)
                janitor:Connect(actionBtn.MouseButton1Click, function()
                    if cfg.Callback then taskLib.spawn(cfg.Callback) end
                end)
            end

            local defaultH = withImage and (cfg.ActionText and 178 or 150) or (cfg.ActionText and 116 or 92)
            local rec = registerItem("Card", root, {
                ColSpan = cfg.ColSpan or 6,
                FullWidth = cfg.FullWidth,
                Height = cfg.Height or defaultH,
            }, function(pal, vis, perf, idx)
                applyVisualToSurface(root, vis, pal, perf, "Surface", idx)
                imgFrame.BackgroundColor3 = pal.SurfaceAlt
                fallbackArt.TextColor3 = pal.Secondary
                badge.BackgroundColor3 = pal.SurfaceAlt
                badge.TextColor3 = pal.Primary
                titleL.Font = vis.FontTitle
                titleL.TextColor3 = pal.Text
                bodyL.Font = vis.FontBody
                bodyL.TextColor3 = pal.MutedText
                if actionBtn then
                    actionBtn.BackgroundColor3 = pal.Primary
                    actionBtn.TextColor3 = Color3.new(1, 1, 1)
                end
            end)

            return buildControlObj(rec, {
                SetTitle = function(_, t) titleL.Text = t end,
                SetBody = function(_, b) bodyL.Text = b end,
            })
        end

        -- 8. GRID SHAPE
        function containerApi:AddGridShape(cfg)
            cfg = cfg or {}
            local shapeKind = cfg.Shape or "Rounded" -- Square | Rounded | Circle | Pill | Diamond
            local root = Instance.new("TextButton")
            root.Name = "GridShapeBlock"
            root.Text = ""
            root.AutoButtonColor = false

            local shapeBox = Instance.new("Frame")
            shapeBox.AnchorPoint = Vector2.new(0.5, 0)
            shapeBox.Position = UDim2.new(0.5, 0, 0, 12)
            shapeBox.Size = UDim2.fromOffset(38, 38)
            shapeBox.ZIndex = 4
            shapeBox.Parent = root

            if shapeKind == "Circle" then
                ensureCorner(shapeBox, 999)
            elseif shapeKind == "Pill" then
                shapeBox.Size = UDim2.fromOffset(58, 28)
                shapeBox.Position = UDim2.new(0.5, 0, 0, 17)
                ensureCorner(shapeBox, 999)
            elseif shapeKind == "Square" then
                ensureCorner(shapeBox, 0)
            elseif shapeKind == "Diamond" then
                ensureCorner(shapeBox, 4)
                shapeBox.Rotation = 45
            else
                ensureCorner(shapeBox, 10)
            end

            local symL = makeText(root, {
                Position = UDim2.fromOffset(0, 12),
                Size = UDim2.new(1, 0, 0, 38),
                Text = cfg.Symbol or "+",
                Font = Enum.Font.GothamBlack,
                TextSize = 14,
                XAlign = Enum.TextXAlignment.Center,
                ZIndex = 5,
            })

            local lbl = makeText(root, {
                Position = UDim2.fromOffset(6, 56),
                Size = UDim2.new(1, -12, 0, 26),
                Text = cfg.Title or shapeKind,
                TextSize = 11,
                XAlign = Enum.TextXAlignment.Center,
                ZIndex = 4,
            })

            local rec = registerItem("GridShape", root, {
                ColSpan = cfg.ColSpan or 3,
                FullWidth = cfg.FullWidth,
                Height = cfg.Height or 90,
            }, function(pal, vis, perf, idx)
                applyVisualToSurface(root, vis, pal, perf, "Surface", idx)
                shapeBox.BackgroundColor3 = pal.Primary
                symL.TextColor3 = Color3.new(1, 1, 1)
                lbl.Font = vis.FontTitle
                lbl.TextColor3 = pal.Text
            end)

            janitor:Connect(root.MouseButton1Click, function()
                if cfg.Callback then taskLib.spawn(cfg.Callback, shapeKind) end
            end)

            return buildControlObj(rec, { Shape = shapeKind })
        end

        -- 9. LAYOUT (NESTED SUB-CONTAINER WITH INDEPENDENT GRID)
        function containerApi:AddLayout(cfg)
            cfg = cfg or {}
            local subGrid = cfg.Grid or "Grid Modular"
            local root = Instance.new("Frame")
            root.Name = "NestedLayoutBlock"

            local hdr = makeText(root, {
                Position = UDim2.fromOffset(10, 6),
                Size = UDim2.new(1, -20, 0, 18),
                Text = (cfg.Title or "Nested Layout") .. " [" .. subGrid .. "]",
                TextSize = 11,
                ZIndex = 4,
            })

            local inner = Instance.new("Frame")
            inner.Position = UDim2.fromOffset(4, 26)
            inner.Size = UDim2.new(1, -8, 1, -30)
            inner.BackgroundTransparency = 1
            inner.ZIndex = 3
            inner.Parent = root

            local subItems = {}
            local subApi = {}
            local rec
            function subApi._relayout()
                local totalH = layoutItemsWithGrid(inner, subItems, subGrid, windowRef.Palette, windowRef:GetVisual())
                rec.PreferredHeight = math.max(cfg.Height or 80, totalH + 34)
                if not isNested then
                    windowRef:RefreshLayout()
                end
            end

            rec = registerItem("Layout", root, {
                ColSpan = cfg.ColSpan or 12,
                FullWidth = cfg.FullWidth ~= false,
                Height = cfg.Height or 120,
            }, function(pal, vis, perf, idx)
                applyVisualToSurface(root, vis, pal, perf, "SurfaceAlt", idx)
                hdr.Font = vis.FontTitle
                hdr.TextColor3 = pal.MutedText
                subApi._relayout()
            end)

            janitor:Connect(inner:GetPropertyChangedSignal("AbsoluteSize"), function()
                subApi._relayout()
            end)

            attachComponentMethods(subApi, windowRef, subItems, scrollerRef, true)
            return buildControlObj(rec, subApi)
        end

        -- 10. RENDERING (3D VIEWPORTFRAME OR 2D PROCEDURAL CANVAS)
        function containerApi:AddRendering(cfg)
            cfg = cfg or {}
            local mode = cfg.Mode or "3D" -- "3D" | "2D"
            local root = Instance.new("Frame")
            root.Name = "RenderingBlock"
            root.ClipsDescendants = false

            local hdr = makeText(root, {
                Position = UDim2.fromOffset(10, 6),
                Size = UDim2.new(1, -20, 0, 18),
                Text = cfg.Title or ("Rendering (" .. mode .. ")"),
                TextSize = 12,
                ZIndex = 5,
            })

            local fpsTag = makeText(root, {
                Position = UDim2.fromOffset(10, 6),
                Size = UDim2.new(1, -20, 0, 18),
                Text = mode .. " RENDER",
                Font = Enum.Font.RobotoMono,
                TextSize = 9,
                XAlign = Enum.TextXAlignment.Right,
                ZIndex = 5,
            })

            local canvas = Instance.new("Frame")
            canvas.Position = UDim2.fromOffset(10, 28)
            canvas.Size = UDim2.new(1, -20, 1, -38)
            canvas.ClipsDescendants = true
            canvas.ZIndex = 4
            canvas.Parent = root
            ensureCorner(canvas, 8)

            local isPaused = false
            local accum = 0

            if mode == "3D" then
                local vp = Instance.new("ViewportFrame")
                vp.Size = UDim2.fromScale(1, 1)
                vp.BackgroundTransparency = 1
                vp.Ambient = Color3.fromRGB(160, 170, 200)
                vp.LightColor = Color3.fromRGB(255, 255, 255)
                vp.ZIndex = 5
                vp.Parent = canvas

                local wm = Instance.new("WorldModel")
                wm.Parent = vp

                local part = Instance.new("Part")
                part.Size = Vector3.new(2.2, 2.2, 2.2)
                part.Material = Enum.Material.SmoothPlastic
                part.Color = windowRef.Palette.Primary
                part.Anchored = true
                part.Parent = wm

                local cam = Instance.new("Camera")
                cam.CFrame = CFrame.new(Vector3.new(0, 1.8, 4.6), Vector3.new(0, 0, 0))
                cam.Parent = vp
                vp.CurrentCamera = cam

                local angle = 0
                janitor:Connect(RunService.RenderStepped, function(dt)
                    if isPaused or windowRef.Closed or windowRef.Minimized or not root.Visible or (scrollerRef and not scrollerRef.Visible) then
                        return
                    end
                    -- Skip work when tab is inactive
                    if not root:IsDescendantOf(windowRef.ScreenGui) then
                        return
                    end
                    accum = accum + dt
                    local minStep = 1 / math.max(windowRef.PerfTier.RenderFps, 10)
                    if accum < minStep then
                        return
                    end
                    angle = angle + accum * 1.4
                    accum = 0
                    part.CFrame = CFrame.Angles(angle * 0.6, angle, angle * 0.25)
                    part.Color = windowRef.Palette.Primary
                end)
            else
                -- 2D Procedural Animated Telemetry Bars
                local barCount = 14
                local bars = {}
                for b = 1, barCount do
                    local bar = Instance.new("Frame")
                    bar.AnchorPoint = Vector2.new(0, 1)
                    bar.Position = UDim2.new((b - 1) / barCount, 2, 1, -4)
                    bar.Size = UDim2.new(1 / barCount, -4, 0.4, 0)
                    bar.BorderSizePixel = 0
                    bar.ZIndex = 5
                    bar.Parent = canvas
                    ensureCorner(bar, 3)
                    bars[b] = bar
                end
                local t = 0
                janitor:Connect(RunService.RenderStepped, function(dt)
                    if isPaused or windowRef.Closed or windowRef.Minimized or not root.Visible or (scrollerRef and not scrollerRef.Visible) then
                        return
                    end
                    accum = accum + dt
                    local minStep = 1 / math.max(windowRef.PerfTier.RenderFps, 10)
                    if accum < minStep then
                        return
                    end
                    t = t + accum * 3.5
                    accum = 0
                    for b, bar in ipairs(bars) do
                        local h = 0.2 + 0.65 * (0.5 + 0.5 * math.sin(t + b * 0.55))
                        bar.Size = UDim2.new(1 / barCount, -4, h, 0)
                        bar.BackgroundColor3 = (b % 2 == 0) and windowRef.Palette.Primary or windowRef.Palette.Secondary
                    end
                end)
            end

            local rec = registerItem("Rendering", root, {
                ColSpan = cfg.ColSpan or 6,
                FullWidth = cfg.FullWidth,
                Height = cfg.Height or 146,
            }, function(pal, vis, perf, idx)
                applyVisualToSurface(root, vis, pal, perf, "Surface", idx)
                hdr.Font = vis.FontTitle
                hdr.TextColor3 = pal.Text
                fpsTag.TextColor3 = pal.Secondary
                fpsTag.Text = string.format("%s | %dFPS", mode, perf.RenderFps)
                canvas.BackgroundColor3 = pal.Background
                ensureStroke(canvas, pal.Border, 1, 0.5)
            end)

            return buildControlObj(rec, {
                SetPaused = function(_, p) isPaused = p end,
            })
        end

        -- 11. BAR (PROGRESS / UPDATE / SLIDER / STAT)
        function containerApi:AddBar(cfg)
            cfg = cfg or {}
            local mode = cfg.Mode or "Progress" -- "Progress" | "Update" | "Slider" | "Stat"
            local minVal = cfg.Min or 0
            local maxVal = cfg.Max or 100
            local value = cfg.Default or (mode == "Progress" and 65 or 50)
            local statusText = cfg.Status or ""

            local root = Instance.new("Frame")
            root.Name = "BarBlock"

            local titleL = makeText(root, {
                Position = UDim2.fromOffset(10, 6),
                Size = UDim2.new(0.65, -10, 0, 18),
                Text = cfg.Title or (mode .. " Bar"),
                TextSize = 12,
            })
            local valL = makeText(root, {
                Position = UDim2.new(0.65, 0, 0, 6),
                Size = UDim2.new(0.35, -10, 0, 18),
                Text = "",
                Font = Enum.Font.RobotoMono,
                TextSize = 11,
                XAlign = Enum.TextXAlignment.Right,
            })

            local track = Instance.new("TextButton")
            track.Position = UDim2.fromOffset(10, 30)
            track.Size = UDim2.new(1, -20, 0, 12)
            track.Text = ""
            track.AutoButtonColor = false
            track.ZIndex = 4
            track.Parent = root
            ensureCorner(track, 6)

            local fill = Instance.new("Frame")
            fill.Size = UDim2.new(0.5, 0, 1, 0)
            fill.ZIndex = 5
            fill.Parent = track
            ensureCorner(fill, 6)

            local function syncBar(animate)
                local frac = math.clamp((value - minVal) / math.max(maxVal - minVal, 0.0001), 0, 1)
                local dur = animate and windowRef.PerfTier.TweenTime or 0
                safeTween(fill, { Size = UDim2.new(frac, 0, 1, 0) }, dur)
                if statusText ~= "" then
                    valL.Text = string.format("%s (%d%%)", statusText, math.round(frac * 100))
                else
                    valL.Text = string.format("%s / %s", tostring(math.round(value * 10) / 10), tostring(maxVal))
                end
            end

            if mode == "Slider" or cfg.Interactive then
                local sliding = false
                local activeInput = nil
                local function applyX(xPos)
                    local absX = track.AbsolutePosition.X
                    local absW = math.max(track.AbsoluteSize.X, 1)
                    local frac = math.clamp((xPos - absX) / absW, 0, 1)
                    value = math.round((minVal + (maxVal - minVal) * frac) * 10) / 10
                    syncBar(false)
                    if cfg.Callback then
                        taskLib.spawn(cfg.Callback, value)
                    end
                end
                janitor:Connect(track.InputBegan, function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        sliding = true
                        activeInput = input
                        applyX(input.Position.X)
                    end
                end)
                janitor:Connect(UserInputService.InputChanged, function(input)
                    if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input == activeInput) then
                        applyX(input.Position.X)
                    end
                end)
                janitor:Connect(UserInputService.InputEnded, function(input)
                    if sliding and (input == activeInput or input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
                        sliding = false
                        activeInput = nil
                    end
                end)
            end

            local rec = registerItem("Bar", root, {
                ColSpan = cfg.ColSpan or 6,
                FullWidth = cfg.FullWidth,
                Height = cfg.Height or 52,
            }, function(pal, vis, perf, idx)
                applyVisualToSurface(root, vis, pal, perf, "Surface", idx)
                titleL.Font = vis.FontTitle
                titleL.TextColor3 = pal.Text
                valL.TextColor3 = pal.Secondary
                track.BackgroundColor3 = pal.SurfaceAlt
                fill.BackgroundColor3 = (mode == "Update" and pal.Success) or pal.Primary
                syncBar(false)
            end)

            return buildControlObj(rec, {
                Set = function(_, newVal, newStatus)
                    value = math.clamp(newVal, minVal, maxVal)
                    if newStatus ~= nil then statusText = newStatus end
                    syncBar(true)
                end,
                Get = function() return value end,
            })
        end

        -- 12. PICKER (COLOR PICKER + ADD TO PRESET OR DROPDOWN)
        function containerApi:AddPicker(cfg)
            cfg = cfg or {}
            local mode = cfg.Mode or "Dropdown" -- "Dropdown" | "Color"
            local root = Instance.new("Frame")
            root.Name = "PickerBlock"
            root.ClipsDescendants = false

            if mode == "Color" then
                local currentColor = cfg.Default or windowRef.Palette.Primary
                local rVal = math.round(currentColor.R * 255)
                local gVal = math.round(currentColor.G * 255)
                local bVal = math.round(currentColor.B * 255)

                local titleL = makeText(root, {
                    Position = UDim2.fromOffset(10, 6),
                    Size = UDim2.new(1, -60, 0, 18),
                    Text = cfg.Title or "Color Picker",
                    TextSize = 12,
                })
                local preview = Instance.new("Frame")
                preview.Size = UDim2.fromOffset(38, 18)
                preview.Position = UDim2.new(1, -48, 0, 6)
                preview.BackgroundColor3 = currentColor
                preview.ZIndex = 4
                preview.Parent = root
                ensureCorner(preview, 5)

                local channels = {
                    { Label = "R", Val = function() return rVal end, Set = function(v) rVal = v end, Y = 30, Col = Color3.fromRGB(239, 68, 68) },
                    { Label = "G", Val = function() return gVal end, Set = function(v) gVal = v end, Y = 52, Col = Color3.fromRGB(34, 197, 94) },
                    { Label = "B", Val = function() return bVal end, Set = function(v) bVal = v end, Y = 74, Col = Color3.fromRGB(59, 130, 246) },
                }
                local fills = {}
                local function refreshColor(fireCb)
                    currentColor = Color3.fromRGB(rVal, gVal, bVal)
                    preview.BackgroundColor3 = currentColor
                    for i, ch in ipairs(channels) do
                        fills[i].Fill.Size = UDim2.new(ch.Val() / 255, 0, 1, 0)
                        fills[i].Txt.Text = ch.Label .. ":" .. tostring(ch.Val())
                    end
                    if fireCb and cfg.Callback then
                        taskLib.spawn(cfg.Callback, currentColor)
                    end
                end

                for i, ch in ipairs(channels) do
                    local lbl = makeText(root, {
                        Position = UDim2.fromOffset(10, ch.Y),
                        Size = UDim2.fromOffset(42, 16),
                        Text = ch.Label .. ":" .. tostring(ch.Val()),
                        Font = Enum.Font.RobotoMono,
                        TextSize = 10,
                        ZIndex = 4,
                    })
                    local tr = Instance.new("TextButton")
                    tr.Position = UDim2.fromOffset(56, ch.Y + 3)
                    tr.Size = UDim2.new(1, -66, 0, 10)
                    tr.Text = ""
                    tr.AutoButtonColor = false
                    tr.ZIndex = 4
                    tr.Parent = root
                    ensureCorner(tr, 5)

                    local fl = Instance.new("Frame")
                    fl.Size = UDim2.new(ch.Val() / 255, 0, 1, 0)
                    fl.BackgroundColor3 = ch.Col
                    fl.ZIndex = 5
                    fl.Parent = tr
                    ensureCorner(fl, 5)
                    fills[i] = { Track = tr, Fill = fl, Txt = lbl }

                    local drag = false
                    local actIn = nil
                    local function upd(xp)
                        local frac = math.clamp((xp - tr.AbsolutePosition.X) / math.max(tr.AbsoluteSize.X, 1), 0, 1)
                        ch.Set(math.round(frac * 255))
                        refreshColor(true)
                    end
                    janitor:Connect(tr.InputBegan, function(inp)
                        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
                            drag = true; actIn = inp; upd(inp.Position.X)
                        end
                    end)
                    janitor:Connect(UserInputService.InputChanged, function(inp)
                        if drag and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp == actIn) then
                            upd(inp.Position.X)
                        end
                    end)
                    janitor:Connect(UserInputService.InputEnded, function(inp)
                        if drag and (inp == actIn or inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch) then
                            drag = false; actIn = nil
                        end
                    end)
                end

                local rec = registerItem("Picker", root, {
                    ColSpan = cfg.ColSpan or 6,
                    FullWidth = cfg.FullWidth,
                    Height = cfg.Height or 100,
                }, function(pal, vis, perf, idx)
                    applyVisualToSurface(root, vis, pal, perf, "Surface", idx)
                    titleL.Font = vis.FontTitle
                    titleL.TextColor3 = pal.Text
                    for _, f in ipairs(fills) do
                        f.Track.BackgroundColor3 = pal.SurfaceAlt
                        f.Txt.TextColor3 = pal.MutedText
                    end
                    refreshColor(false)
                end)

                return buildControlObj(rec, {
                    Get = function() return currentColor end,
                    Set = function(_, col)
                        rVal = math.round(col.R * 255)
                        gVal = math.round(col.G * 255)
                        bVal = math.round(col.B * 255)
                        refreshColor(false)
                    end,
                })
            end

            -- Dropdown Picker Mode
            local options = cfg.Options or { "Item 1", "Item 2", "Item 3" }
            local selected = cfg.Default or options[1]
            local expanded = false

            local titleL = makeText(root, {
                Position = UDim2.fromOffset(10, 6),
                Size = UDim2.new(1, -20, 0, 16),
                Text = cfg.Title or "Select Option",
                TextSize = 11,
            })

            local selectBtn = makeText(root, {
                IsButton = true,
                Position = UDim2.fromOffset(10, 26),
                Size = UDim2.new(1, -20, 0, 26),
                Text = "  " .. tostring(selected) .. "  [v]",
                TextSize = 11,
                BgTransparency = 0,
                ZIndex = 5,
            })
            ensureCorner(selectBtn, 6)

            local listBox = Instance.new("ScrollingFrame")
            listBox.Position = UDim2.fromOffset(10, 56)
            listBox.Size = UDim2.new(1, -20, 0, 92)
            listBox.BorderSizePixel = 0
            listBox.ScrollBarThickness = 3
            listBox.AutomaticCanvasSize = Enum.AutomaticSize.Y
            listBox.CanvasSize = UDim2.fromOffset(0, 0)
            listBox.Visible = false
            listBox.ZIndex = 5
            listBox.Parent = root
            ensureCorner(listBox, 6)

            local listLayout = Instance.new("UIListLayout")
            listLayout.Padding = UDim.new(0, 2)
            listLayout.Parent = listBox

            local rec
            local function rebuildOptions(newOpts)
                options = newOpts
                for _, c in ipairs(listBox:GetChildren()) do
                    if c:IsA("TextButton") then c:Destroy() end
                end
                for _, opt in ipairs(options) do
                    local b = makeText(listBox, {
                        IsButton = true,
                        Size = UDim2.new(1, -4, 0, 22),
                        Text = "  " .. tostring(opt),
                        TextSize = 11,
                        TextColor = windowRef.Palette.Text,
                        BgTransparency = 0,
                        ZIndex = 6,
                    })
                    b.BackgroundColor3 = windowRef.Palette.SurfaceAlt
                    ensureCorner(b, 4)
                    janitor:Connect(b.MouseButton1Click, function()
                        selected = opt
                        expanded = false
                        listBox.Visible = false
                        selectBtn.Text = "  " .. tostring(selected) .. "  [v]"
                        rec.PreferredHeight = 60
                        windowRef:RefreshLayout()
                        if cfg.Callback then taskLib.spawn(cfg.Callback, selected) end
                    end)
                end
            end

            rec = registerItem("Picker", root, {
                ColSpan = cfg.ColSpan or 6,
                FullWidth = cfg.FullWidth,
                Height = 60,
            }, function(pal, vis, perf, idx)
                applyVisualToSurface(root, vis, pal, perf, "Surface", idx)
                titleL.Font = vis.FontTitle
                titleL.TextColor3 = pal.MutedText
                selectBtn.BackgroundColor3 = pal.SurfaceAlt
                selectBtn.TextColor3 = pal.Text
                selectBtn.Font = vis.FontBody
                listBox.BackgroundColor3 = pal.Background
                rebuildOptions(options)
            end)

            janitor:Connect(selectBtn.MouseButton1Click, function()
                expanded = not expanded
                listBox.Visible = expanded
                rec.PreferredHeight = expanded and 156 or 60
                selectBtn.Text = "  " .. tostring(selected) .. (expanded and "  [^]" or "  [v]")
                windowRef:RefreshLayout()
            end)

            return buildControlObj(rec, {
                Set = function(_, v)
                    selected = v
                    selectBtn.Text = "  " .. tostring(selected) .. "  [v]"
                end,
                SetOptions = function(_, opts) rebuildOptions(opts) end,
                Get = function() return selected end,
            })
        end

        -- 13. INLINE LOADING SECTION WIDGET
        function containerApi:AddLoading(cfg)
            cfg = cfg or {}
            local root = Instance.new("Frame")
            root.Name = "LoadingBlock"

            local dot = Instance.new("Frame")
            dot.Size = UDim2.fromOffset(16, 16)
            dot.Position = UDim2.fromOffset(12, 12)
            dot.ZIndex = 4
            dot.Parent = root
            ensureCorner(dot, 4)

            local titleL = makeText(root, {
                Position = UDim2.fromOffset(36, 9),
                Size = UDim2.new(1, -46, 0, 20),
                Text = cfg.Title or "Processing Task...",
                TextSize = 12,
                ZIndex = 4,
            })
            local track = Instance.new("Frame")
            track.Position = UDim2.fromOffset(12, 36)
            track.Size = UDim2.new(1, -24, 0, 8)
            track.ZIndex = 4
            track.Parent = root
            ensureCorner(track, 4)

            local fill = Instance.new("Frame")
            fill.Size = UDim2.new(cfg.Progress or 0.4, 0, 1, 0)
            fill.ZIndex = 5
            fill.Parent = track
            ensureCorner(fill, 4)

            local spinning = true
            janitor:Connect(RunService.RenderStepped, function(dt)
                if not spinning or windowRef.Closed or windowRef.Minimized or not root.Visible or (scrollerRef and not scrollerRef.Visible) then
                    return
                end
                dot.Rotation = (dot.Rotation + dt * 220) % 360
            end)

            local rec = registerItem("Loading", root, {
                ColSpan = cfg.ColSpan or 6,
                FullWidth = cfg.FullWidth,
                Height = cfg.Height or 54,
            }, function(pal, vis, perf, idx)
                applyVisualToSurface(root, vis, pal, perf, "Surface", idx)
                dot.BackgroundColor3 = pal.Primary
                titleL.Font = vis.FontTitle
                titleL.TextColor3 = pal.Text
                track.BackgroundColor3 = pal.SurfaceAlt
                fill.BackgroundColor3 = pal.Secondary
            end)

            return buildControlObj(rec, {
                SetProgress = function(_, pct, text)
                    safeTween(fill, { Size = UDim2.new(math.clamp(pct, 0, 1), 0, 1, 0) }, windowRef.PerfTier.TweenTime)
                    if text then titleL.Text = text end
                end,
                SetSpinning = function(_, active) spinning = active end,
            })
        end
    end

    --========================================================================--
    -- 7b. TAB CREATION (LEFT TAB SIDEBAR BUTTONS -> CENTER TAB PAGES)
    --========================================================================--

    function window:RefreshLayout()
        self._layoutDirty = false
        if not self._activeTab then
            return
        end
        local tab = self._activeTab
        centerTitle.Text = tab.Name:upper()
        applyPatternAndGrid(
            tab.PageScroller,
            tab.Items,
            self.PatternName,
            self.GridName,
            self.Palette,
            self:GetVisual()
        )
    end

    function window:QueueLayoutRefresh()
        if self._layoutDirty then
            return
        end
        self._layoutDirty = true
        taskLib.defer(function()
            if not self.Closed and self._layoutDirty then
                self:RefreshLayout()
            end
        end)
    end

    function window:SelectTab(tabObj)
        if self._activeTab == tabObj then
            return
        end
        for _, t in ipairs(self._tabs) do
            local isSel = (t == tabObj)
            t.PageScroller.Visible = isSel
            t.SidebarButton.BackgroundColor3 = isSel and self.Palette.Primary or self.Palette.SurfaceAlt
            t.SidebarLabel.TextColor3 = isSel and Color3.new(1, 1, 1) or self.Palette.Text
        end
        self._activeTab = tabObj
        self:RefreshLayout()
    end

    function window:AddTab(cfg)
        if type(cfg) == "string" then
            cfg = { Name = cfg }
        end
        cfg = cfg or {}
        local tabName = cfg.Name or ("Tab " .. tostring(#self._tabs + 1))

        local navBtn = Instance.new("TextButton")
        navBtn.Name = "Nav_" .. tabName
        navBtn.Size = UDim2.new(1, 0, 0, 34)
        navBtn.Text = ""
        navBtn.AutoButtonColor = false
        navBtn.LayoutOrder = #self._tabs + 1
        navBtn.ZIndex = 14
        navBtn.Parent = leftNavScroller

        local navBadge = makeText(navBtn, {
            Position = UDim2.fromOffset(8, 7),
            Size = UDim2.fromOffset(20, 20),
            Text = cfg.Icon or string.sub(tabName, 1, 1):upper(),
            Font = Enum.Font.RobotoMono,
            TextSize = 10,
            XAlign = Enum.TextXAlignment.Center,
            ZIndex = 15,
        })
        ensureCorner(navBadge, 5)

        local navLbl = makeText(navBtn, {
            Position = UDim2.fromOffset(34, 0),
            Size = UDim2.new(1, -40, 1, 0),
            Text = tabName,
            TextSize = 11,
            Wrapped = false,
            Truncate = Enum.TextTruncate.AtEnd,
            ZIndex = 15,
        })

        local scroller = Instance.new("ScrollingFrame")
        scroller.Name = "Page_" .. tabName
        scroller.Size = UDim2.fromScale(1, 1)
        scroller.BackgroundTransparency = 1
        scroller.BorderSizePixel = 0
        scroller.ScrollBarThickness = 4
        scroller.CanvasSize = UDim2.fromOffset(0, 0)
        scroller.Visible = false
        scroller.ZIndex = 12
        scroller.Parent = centerContentHolder

        local tabObj = {
            Name = tabName,
            SidebarButton = navBtn,
            SidebarLabel = navLbl,
            PageScroller = scroller,
            Items = {},
        }
        table.insert(self._tabs, tabObj)

        attachComponentMethods(tabObj, self, tabObj.Items, scroller, false)

        self:RegisterThemeHook(function(pal, vis, perf)
            local isSel = (self._activeTab == tabObj)
            ensureCorner(navBtn, math.min(vis.CornerRadius, 8))
            ensureStroke(navBtn, pal.Border, 1, 0.5)
            navBtn.BackgroundColor3 = isSel and pal.Primary or pal.SurfaceAlt
            navLbl.Font = vis.FontTitle
            navLbl.TextColor3 = isSel and Color3.new(1, 1, 1) or pal.Text
            navBadge.BackgroundTransparency = 0.75
            navBadge.BackgroundColor3 = Color3.new(0, 0, 0)
            navBadge.TextColor3 = isSel and Color3.new(1, 1, 1) or pal.Secondary
            scroller.ScrollBarImageColor3 = pal.Primary
        end)

        janitor:Connect(navBtn.MouseButton1Click, function()
            self:SelectTab(tabObj)
        end)

        janitor:Connect(scroller:GetPropertyChangedSignal("AbsoluteSize"), function()
            if self._activeTab == tabObj then
                self:RefreshLayout()
            end
        end)

        if #self._tabs == 1 then
            self:SelectTab(tabObj)
        end

        return tabObj
    end

    --========================================================================--
    -- 9. RIGHT TAB: BUILT-IN PREFERENCES & SHORTCUT PANEL + EXTENSIBLE API
    --========================================================================--

    local rightOrder = 0
    local function nextRightOrder()
        rightOrder = rightOrder + 1
        return rightOrder
    end

    function window:AddRightSection(titleText)
        local box = Instance.new("Frame")
        box.Size = UDim2.new(1, -2, 0, 0)
        box.AutomaticSize = Enum.AutomaticSize.Y
        box.LayoutOrder = nextRightOrder()
        box.ZIndex = 14
        box.Parent = rightScroller

        local pad = Instance.new("UIPadding")
        pad.PaddingTop = UDim.new(0, 8)
        pad.PaddingBottom = UDim.new(0, 8)
        pad.PaddingLeft = UDim.new(0, 8)
        pad.PaddingRight = UDim.new(0, 8)
        pad.Parent = box

        local lay = Instance.new("UIListLayout")
        lay.Padding = UDim.new(0, 6)
        lay.SortOrder = Enum.SortOrder.LayoutOrder
        lay.Parent = box

        local hdr = makeText(box, {
            Size = UDim2.new(1, 0, 0, 16),
            Text = titleText,
            TextSize = 11,
            ZIndex = 15,
        })
        hdr.LayoutOrder = 0

        self:RegisterThemeHook(function(pal, vis, perf)
            applyVisualToSurface(box, vis, pal, perf, "SurfaceAlt")
            hdr.Font = vis.FontTitle
            hdr.TextColor3 = pal.Secondary
        end)
        return box
    end

    function window:AddRightButton(parentSection, labelText, onClick)
        local btn = makeText(parentSection, {
            IsButton = true,
            Size = UDim2.new(1, 0, 0, 26),
            Text = labelText,
            TextSize = 11,
            BgTransparency = 0,
            XAlign = Enum.TextXAlignment.Center,
            ZIndex = 15,
        })
        ensureCorner(btn, 6)
        self:RegisterThemeHook(function(pal, vis)
            btn.BackgroundColor3 = pal.Surface
            btn.TextColor3 = pal.Text
            btn.Font = vis.FontBody
            ensureStroke(btn, pal.Border, 1, 0.5)
        end)
        janitor:Connect(btn.MouseButton1Click, function()
            if onClick then taskLib.spawn(onClick) end
        end)
        return btn
    end

    function window:AddRightCycleSelector(parentSection, labelPrefix, optionsList, getCurrent, onSelect)
        local btn = self:AddRightButton(parentSection, "", function()
            local cur = getCurrent()
            local nextIdx = 1
            for i, name in ipairs(optionsList) do
                if name == cur then
                    nextIdx = (i % #optionsList) + 1
                    break
                end
            end
            onSelect(optionsList[nextIdx])
        end)

        local listGrid = Instance.new("Frame")
        listGrid.Size = UDim2.new(1, 0, 0, 0)
        listGrid.AutomaticSize = Enum.AutomaticSize.Y
        listGrid.BackgroundTransparency = 1
        listGrid.ZIndex = 15
        listGrid.Parent = parentSection

        local gl = Instance.new("UIGridLayout")
        gl.CellSize = UDim2.new(0.485, 0, 0, 22)
        gl.CellPadding = UDim2.fromOffset(4, 4)
        gl.Parent = listGrid

        local pills = {}
        local function rebuildPills()
            for _, p in ipairs(pills) do
                if p.Btn.Parent then p.Btn:Destroy() end
            end
            pills = {}
            for _, opt in ipairs(optionsList) do
                local pill = makeText(listGrid, {
                    IsButton = true,
                    Text = opt,
                    TextSize = 9,
                    BgTransparency = 0,
                    XAlign = Enum.TextXAlignment.Center,
                    ZIndex = 16,
                })
                ensureCorner(pill, 4)
                table.insert(pills, { Name = opt, Btn = pill })
                janitor:Connect(pill.MouseButton1Click, function()
                    onSelect(opt)
                end)
            end
        end
        rebuildPills()

        self:RegisterThemeHook(function(pal, vis)
            btn.Text = labelPrefix .. ": " .. tostring(getCurrent()) .. "  [Cycle]"
            btn.BackgroundColor3 = pal.Primary
            btn.TextColor3 = Color3.new(1, 1, 1)
            local cur = getCurrent()
            for _, p in ipairs(pills) do
                local active = (p.Name == cur)
                p.Btn.BackgroundColor3 = active and pal.Secondary or pal.Surface
                p.Btn.TextColor3 = active and pal.Background or pal.MutedText
                p.Btn.Font = vis.FontBody
            end
        end)

        return { Rebuild = rebuildPills }
    end

    if config.DefaultRightPreferences ~= false then
        -- 1. Palette + Custom Color & Add to Preset
        local secTheme = window:AddRightSection("COLOR PALETTE & PRESET")
        local palSelector = window:AddRightCycleSelector(
            secTheme,
            "Palette",
            Bootstrap.PaletteOrder,
            function() return window.PaletteName end,
            function(name) window:SetPalette(name) end
        )
        table.insert(window._onPresetSavedCallbacks, function()
            palSelector.Rebuild()
            window:ApplyTheme()
        end)

        local presetInput = Instance.new("TextBox")
        presetInput.Size = UDim2.new(1, 0, 0, 26)
        presetInput.PlaceholderText = "New preset name..."
        presetInput.Text = ""
        presetInput.Font = Enum.Font.Gotham
        presetInput.TextSize = 11
        presetInput.ClearTextOnFocus = false
        presetInput.ZIndex = 15
        presetInput.Parent = secTheme
        ensureCorner(presetInput, 5)
        window:RegisterThemeHook(function(pal)
            presetInput.BackgroundColor3 = pal.Background
            presetInput.TextColor3 = pal.Text
            presetInput.PlaceholderColor3 = pal.MutedText
            ensureStroke(presetInput, pal.Border, 1, 0.4)
        end)

        local hexInput = Instance.new("TextBox")
        hexInput.Size = UDim2.new(1, 0, 0, 24)
        hexInput.PlaceholderText = "Primary Hex e.g. #FF4D00"
        hexInput.Text = ""
        hexInput.Font = Enum.Font.RobotoMono
        hexInput.TextSize = 10
        hexInput.ClearTextOnFocus = false
        hexInput.ZIndex = 15
        hexInput.Parent = secTheme
        ensureCorner(hexInput, 5)
        window:RegisterThemeHook(function(pal)
            hexInput.BackgroundColor3 = pal.Background
            hexInput.TextColor3 = pal.Text
            hexInput.PlaceholderColor3 = pal.MutedText
            ensureStroke(hexInput, pal.Border, 1, 0.4)
        end)

        window:AddRightButton(secTheme, "+ Apply Hex & Add to Preset", function()
            if hexInput.Text ~= "" then
                window:SetColor("Primary", hexToColor3(hexInput.Text))
            end
            local name = (presetInput.Text ~= "") and presetInput.Text or ("Preset_" .. tostring(#Bootstrap.PaletteOrder + 1))
            local savedName, persisted = window:SaveColorPreset(name)
            presetInput.Text = ""
            window:Notify({
                Title = "Preset Saved",
                Content = savedName .. (persisted and " saved to file & palette list." or " added to palette list."),
                Type = "Success",
            })
        end)

        -- 2. Default Grid Switcher (7 Grids)
        local secGrid = window:AddRightSection("DEFAULT GRID (7)")
        window:AddRightCycleSelector(
            secGrid,
            "Grid",
            Bootstrap.Grids,
            function() return window.GridName end,
            function(name) window:SetGrid(name) end
        )

        -- 3. Default Pattern Switcher (7 Patterns)
        local secPattern = window:AddRightSection("DEFAULT PATTERN (7)")
        window:AddRightCycleSelector(
            secPattern,
            "Pattern",
            Bootstrap.Patterns,
            function() return window.PatternName end,
            function(name) window:SetPattern(name) end
        )

        -- 4. Visual Graphics Switcher (10 Styles)
        local secVisual = window:AddRightSection("VISUAL GRAPHICS (10)")
        window:AddRightCycleSelector(
            secVisual,
            "Visual",
            Bootstrap.VisualOrder,
            function() return window.VisualName end,
            function(name) window:SetVisual(name) end
        )

        -- 5. Quick Engine Shortcuts
        local secEngine = window:AddRightSection("ENGINE & PROTECTION")
        window:AddRightCycleSelector(
            secEngine,
            "Perf Tier",
            { "Auto", "Low", "Medium", "High" },
            function() return window.PerfMode end,
            function(mode) window:SetPerformanceMode(mode) end
        )

        window:AddRightButton(secEngine, "Toggle Topbar & Canvas Lock", function()
            window:SetBlockers(not window.BlockGameCanvas, not window.BlockTopbar)
            window:Notify({
                Title = "Input & Topbar Lock",
                Content = window.BlockGameCanvas and "GameCanvas & Topbar BLOCKED." or "GameCanvas UNLOCKED.",
                Type = window.BlockGameCanvas and "Info" or "Warning",
                Duration = 2.5,
            })
        end)

        window:AddRightButton(secEngine, "Reset Default Layout", function()
            window:SetPalette("ObsidianDark")
            window:SetGrid("Bento Grid")
            window:SetPattern("Multi Column")
            window:SetVisual("Minimalist")
            window:SetPerformanceMode("Auto")
            window:SetScaleOverride(0)
        end)
    end

    -- Initialize Responsive Scale, Theme, and Input Lock
    window:ApplyTheme()
    updateResponsiveScale()
    updateInputLock()

    return window
end

--============================================================================--
-- 10. BUILT-IN SHOWCASE DEMO (SHOWCASES ALL 14 COMPONENTS + PRESETS)
--============================================================================--

function Bootstrap.CreateDemo()
    local win = Bootstrap.CreateWindow({
        Title = "NEXUS BOOTSTRAP",
        Subtitle = "3-Tab Responsive Lua Framework",
        LogoText = "NX",
        Palette = "ObsidianDark",
        Grid = "Bento Grid",
        Pattern = "Multi Column",
        Visual = "Minimalist",
    })

    local loader = win:ShowLoading({
        Title = "Bootstrapping Framework",
        Status = "Mounting 3-Tab architecture & presets...",
        Progress = 0.25,
    })

    -- TAB 1: DASHBOARD & OVERVIEW
    local tabDash = win:AddTab({ Name = "Dashboard", Icon = "D" })
    tabDash:AddTitle({
        Title = "Framework Control Center",
        Subtitle = "Responsive on HP & PC | GameCanvas & Topbar Blocked while open",
    })
    tabDash:AddLogo({
        Title = "RobloxGuiBootstrap",
        Subtitle = "Zero-Leak Janitor + Auto FPS Tiering",
        Monogram = "BG",
        ColSpan = 6,
    })
    tabDash:AddCard({
        Title = "Active Input Blocker",
        Badge = "SHIELD",
        Body = "Clicks outside this window are captured by ModalBlocker so 3D game buttons never trigger accidentally.",
        WithImage = false,
        ActionText = "Test Toast Notification",
        ColSpan = 6,
        Callback = function()
            win:Notify({
                Title = "Input Shield Active",
                Content = "GameCanvas & Topbar protection verified.",
                Type = "Success",
            })
        end,
    })
    tabDash:AddBar({
        Title = "Framework Update Bar",
        Mode = "Update",
        Default = 100,
        Status = "Ready v" .. Bootstrap.Version,
        ColSpan = 6,
    })
    tabDash:AddRendering({
        Title = "Live 3D Viewport Preview",
        Mode = "3D",
        ColSpan = 6,
    })

    -- TAB 2: CORE COMPONENTS
    local tabComp = win:AddTab({ Name = "Components", Icon = "C" })
    tabComp:AddTitle({
        Title = "Interactive Inputs & Pickers",
        Subtitle = "Button, Toggle, Radio, Label, Bar Slider, Color & Dropdown Picker",
    })
    local statusLbl = tabComp:AddLabel({
        Text = "Click any component below to test reactive callbacks.",
        ColSpan = 12,
    })
    tabComp:AddButton({
        Title = "Primary Action",
        Description = "Fires callback & updates label",
        Variant = "Primary",
        ColSpan = 4,
        Callback = function()
            statusLbl:SetText("Primary Action executed at " .. os.date("%H:%M:%S"))
        end,
    })
    tabComp:AddButton({
        Title = "Danger Trigger",
        Description = "Shows warning notification",
        Variant = "Danger",
        ColSpan = 4,
        Callback = function()
            win:Notify({ Title = "Alert", Content = "Danger button pressed.", Type = "Error" })
        end,
    })
    tabComp:AddToggle({
        Title = "Topbar & Canvas Lock",
        Description = "Block clicks outside GUI",
        Default = true,
        ColSpan = 4,
        Callback = function(v)
            win:SetBlockers(v, v)
        end,
    })
    tabComp:AddRadio({
        Title = "Performance Profile",
        Options = { "Auto", "Low", "Medium", "High" },
        Default = "Auto",
        ColSpan = 6,
        Callback = function(choice)
            win:SetPerformanceMode(choice)
            statusLbl:SetText("Performance Tier set to: " .. choice)
        end,
    })
    tabComp:AddBar({
        Title = "UI Scale Override (0 = Auto)",
        Mode = "Slider",
        Min = 0,
        Max = 1.4,
        Default = 0,
        ColSpan = 6,
        Callback = function(val)
            win:SetScaleOverride(val < 0.3 and 0 or val)
        end,
    })
    tabComp:AddPicker({
        Title = "Custom Primary Color",
        Mode = "Color",
        Default = win.Palette.Primary,
        ColSpan = 6,
        Callback = function(col)
            win:SetColor("Primary", col)
        end,
    })
    tabComp:AddPicker({
        Title = "Quick Grid Dropdown",
        Mode = "Dropdown",
        Options = Bootstrap.Grids,
        Default = win.GridName,
        ColSpan = 6,
        Callback = function(choice)
            win:SetGrid(choice)
        end,
    })

    -- TAB 3: CARDS, SHAPES & NESTED LAYOUT
    local tabCards = win:AddTab({ Name = "Cards & Shapes", Icon = "S" })
    tabCards:AddTitle({
        Title = "Cards (Image / Text-Only) & Grid Shapes",
        Subtitle = "Reusable containers adaptable to all 10 Visual Graphics",
    })
    tabCards:AddCard({
        Title = "Card With Visual Banner",
        Badge = "IMAGE CARD",
        WithImage = true,
        ImageBadge = "PREVIEW ART",
        Body = "Supports rbxassetid:// textures or clean procedural fallback.",
        ActionText = "Inspect Card",
        ColSpan = 6,
        Callback = function()
            win:Notify({ Title = "Card Action", Content = "Image Card clicked!", Type = "Info" })
        end,
    })
    tabCards:AddCard({
        Title = "Card Without Image",
        Badge = "CLEAN TEXT",
        WithImage = false,
        Body = "Minimal footprint card optimized for low-end mobile devices.",
        ActionText = "Select",
        ColSpan = 6,
        Callback = function()
            win:Notify({ Title = "Card Action", Content = "Text-Only Card clicked!", Type = "Success" })
        end,
    })
    tabCards:AddGridShape({ Title = "Circle", Shape = "Circle", Symbol = "O", ColSpan = 3 })
    tabCards:AddGridShape({ Title = "Rounded", Shape = "Rounded", Symbol = "#", ColSpan = 3 })
    tabCards:AddGridShape({ Title = "Diamond", Shape = "Diamond", Symbol = "<>", ColSpan = 3 })
    tabCards:AddGridShape({ Title = "Pill", Shape = "Pill", Symbol = "--", ColSpan = 3 })

    local nested = tabCards:AddLayout({
        Title = "Nested Sub-Layout",
        Grid = "12 Column Grid",
        ColSpan = 12,
    })
    nested:AddButton({ Title = "Nested Btn A", ColSpan = 4, Variant = "Secondary" })
    nested:AddButton({ Title = "Nested Btn B", ColSpan = 4, Variant = "Ghost" })
    nested:AddToggle({ Title = "Nested Toggle", ColSpan = 4, Default = true })

    -- TAB 4: RENDERING, PROGRESS & LOADING
    local tabRender = win:AddTab({ Name = "Rendering & Bars", Icon = "R" })
    tabRender:AddTitle({
        Title = "Rendering, Telemetry Bars & Inline Loading",
        Subtitle = "Automatically throttles FPS according to device Performance Tier",
    })
    tabRender:AddRendering({ Title = "3D Part Viewport", Mode = "3D", ColSpan = 6 })
    tabRender:AddRendering({ Title = "2D Procedural Waveform", Mode = "2D", ColSpan = 6 })
    tabRender:AddBar({ Title = "Download Progress", Mode = "Progress", Default = 78, ColSpan = 6 })
    local inlineLoader = tabRender:AddLoading({ Title = "Background Sync Active", Progress = 0.65, ColSpan = 6 })

    taskLib.spawn(function()
        taskLib.wait(0.25)
        loader:SetProgress(0.65, "Applying visual archetypes & mobile UIScale...")
        taskLib.wait(0.25)
        loader:SetProgress(1, "Ready!")
        taskLib.wait(0.15)
        loader:Finish()
        inlineLoader:SetProgress(0.92, "Sync Healthy (92%)")
        win:Notify({
            Title = "Bootstrap Loaded",
            Content = "Use Right Tab to switch Grids, Patterns, Visuals & Color Presets.",
            Type = "Success",
            Duration = 4,
        })
    end)

    return win
end

-- Auto-run showcase when executed standalone (unless library-only mode or ModuleScript)
local isModule = typeof(script) == "Instance" and script:IsA("ModuleScript")
if not isModule and not _G.ROBLOX_GUI_BOOTSTRAP_LIBRARY_ONLY then
    Bootstrap.CreateDemo()
end

return Bootstrap
