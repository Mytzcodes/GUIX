--[[
    ============================================================================
    ExampleUsage.lua
    Reusable Starter Template for RobloxGuiBootstrap.lua
    Repo: https://github.com/Mytzcodes/GUIX
    ============================================================================

    How to run in an Executor:
      1. Direct from GitHub Raw:
         loadstring(game:HttpGet("https://raw.githubusercontent.com/Mytzcodes/GUIX/main/ExampleUsage.lua"))()
      2. Or place RobloxGuiBootstrap.lua in your executor's workspace folder.
      3. Setting `_G.ROBLOX_GUI_BOOTSTRAP_LIBRARY_ONLY = true` imports the
         framework without launching the built-in demo window.
]]

_G.ROBLOX_GUI_BOOTSTRAP_LIBRARY_ONLY = true

local RAW_BASE = "https://raw.githubusercontent.com/Mytzcodes/GUIX/main/"

local Bootstrap
if typeof(readfile) == "function" and typeof(isfile) == "function" and isfile("RobloxGuiBootstrap.lua") then
    Bootstrap = loadstring(readfile("RobloxGuiBootstrap.lua"))()
elseif typeof(script) == "Instance" and script.Parent and script.Parent:FindFirstChild("RobloxGuiBootstrap") then
    Bootstrap = require(script.Parent:FindFirstChild("RobloxGuiBootstrap"))
else
    Bootstrap = loadstring(game:HttpGet(RAW_BASE .. "RobloxGuiBootstrap.lua"))()
end

-- Create a reusable 3-Tab Window (Left Sidebar, Center Features, Right Preferences)
local Window = Bootstrap.CreateWindow({
    Title = "MY CUSTOM SUITE",
    Subtitle = "Powered by RobloxGuiBootstrap",
    LogoText = "MS",
    Palette = "CyberNeon",          -- Choose any built-in or saved custom preset
    Grid = "Bento Grid",            -- 7 Grids available
    Pattern = "F-Pattern",          -- 7 Patterns available
    Visual = "Card Base",           -- 10 Visual Graphics available
    PerformanceMode = "Auto",       -- Auto | Low | Medium | High
    BlockGameCanvas = true,         -- Blocks clicks outside GUI from hitting 3D game
    BlockTopbar = true,             -- Covers & hides Roblox topbar elements while open
})

-- Add Custom Tabs to LEFT TAB -> renders in CENTER TAB
local MainTab = Window:AddTab({ Name = "Main Features", Icon = "M" })
local VisualTab = Window:AddTab({ Name = "Visuals & Stats", Icon = "V" })

-- Populate MainTab using reusable non-hardcoded config tables
MainTab:AddTitle({
    Title = "Player & World Controls",
    Subtitle = "Switch Grid / Pattern / Visual live in the Right Tab!",
})

local StatusLabel = MainTab:AddLabel({
    Text = "Status: Waiting for input...",
})

MainTab:AddToggle({
    Title = "Auto Optimization",
    Description = "Balances effects for low-end mobile devices",
    Default = true,
    ColSpan = 6,
    Callback = function(enabled)
        StatusLabel:SetText("Auto Optimization: " .. tostring(enabled))
        Window:Notify({
            Title = "Setting Updated",
            Content = "Auto Optimization set to " .. tostring(enabled),
            Type = enabled and "Success" or "Warning",
        })
    end,
})

MainTab:AddBar({
    Title = "WalkSpeed Multiplier",
    Mode = "Slider",
    Min = 1,
    Max = 5,
    Default = 1.5,
    ColSpan = 6,
    Callback = function(val)
        StatusLabel:SetText("Speed Multiplier: " .. tostring(val) .. "x")
    end,
})

MainTab:AddRadio({
    Title = "Target Mode",
    Options = { "Balanced", "Performance (Low HP)", "Quality (High PC)" },
    Default = "Balanced",
    ColSpan = 6,
    Callback = function(selected)
        if selected == "Performance (Low HP)" then
            Window:SetPerformanceMode("Low")
        elseif selected == "Quality (High PC)" then
            Window:SetPerformanceMode("High")
        else
            Window:SetPerformanceMode("Auto")
        end
    end,
})

MainTab:AddButton({
    Title = "Save Custom Color Preset",
    Description = "Saves your current theme into Right Tab & JSON",
    Variant = "Primary",
    ColSpan = 6,
    Callback = function()
        local name = Window:SaveColorPreset("MyNeonTheme", {
            Primary = Color3.fromRGB(0, 220, 255),
            Secondary = Color3.fromRGB(255, 85, 175),
        })
        Window:Notify({
            Title = "Preset Created",
            Content = "Saved preset: " .. name,
            Type = "Success",
        })
    end,
})

-- Populate VisualTab with Cards, Shapes, Rendering, and Nested Layout
VisualTab:AddCard({
    Title = "Card With Image Preview",
    Badge = "BANNER",
    WithImage = true,
    ImageBadge = "CUSTOM ART",
    Body = "Pass `Image = 'rbxassetid://...'` or leave blank for fallback.",
    ActionText = "Trigger Card",
    ColSpan = 6,
    Callback = function()
        Window:Notify({ Title = "Card", Content = "Banner card pressed!", Type = "Info" })
    end,
})

VisualTab:AddRendering({
    Title = "2D Telemetry Monitor",
    Mode = "2D",
    ColSpan = 6,
})

VisualTab:AddGridShape({ Title = "Node A", Shape = "Circle", Symbol = "A", ColSpan = 3 })
VisualTab:AddGridShape({ Title = "Node B", Shape = "Rounded", Symbol = "B", ColSpan = 3 })
VisualTab:AddGridShape({ Title = "Node C", Shape = "Diamond", Symbol = "C", ColSpan = 3 })
VisualTab:AddGridShape({ Title = "Node D", Shape = "Pill", Symbol = "D", ColSpan = 3 })

-- Extend RIGHT TAB with custom developer quick-shortcuts
local CustomRight = Window:AddRightSection("APP SHORTCUTS")
Window:AddRightButton(CustomRight, "Quick Minimize (-)", function()
    Window:SetMinimized(true)
end)
Window:AddRightButton(CustomRight, "Send Test Toast", function()
    Window:Notify({ Title = "Shortcut", Content = "Triggered from Right Tab!", Type = "Info" })
end)
