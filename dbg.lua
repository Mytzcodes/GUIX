-- File: debugger_sender.luau
-- Runtime: Roblox Client Executor (supports request/http_request, decompile, getscriptbytecode, getnilinstances)

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")

local httpRequest = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request
assert(httpRequest, "[KANHA DEBUGGER] Executor requires HTTP request capability (request / http_request).")

-- ============================================================================
-- STATE & CONFIGURATION
-- ============================================================================
local DebuggerState = {
    ServerEndpoint = "http://100.90.69.99:8080", -- Replace with your Tailscale IPv4:8080 or https://your-node.ts.net
    IsRunning      = false,
    SessionID      = "NONE",
    TotalScripts   = 0,
    SentScripts    = 0,
}

local function normalizeEndpoint(raw)
    local url = tostring(raw or ""):gsub("^%s+", ""):gsub("%s+$", ""):gsub("/+$", "")
    if url == "" then
        return "http://127.0.0.1:8080"
    end
    if not url:match("^https?://") then
        url = "http://" .. url
    end
    local scheme, hostPort = url:match("^(https?://)([^/]+)$")
    if scheme and hostPort and not hostPort:find(":", 1, true) and scheme == "http://" then
        url = scheme .. hostPort .. ":8080"
    end
    return url
end

local function getGuiParent()
    if type(gethui) == "function" then
        local ok, hui = pcall(gethui)
        if ok and typeof(hui) == "Instance" then
            return hui
        end
    end
    local ok = pcall(function()
        local _ = CoreGui.Name
    end)
    if ok then
        return CoreGui
    end
    local lp = Players.LocalPlayer or Players.PlayerAdded:Wait()
    return lp:WaitForChild("PlayerGui")
end

-- ============================================================================
-- IN-GAME 2.5D GUI CONSTRUCTION (START / STOP + SERVER PROGRESS)
-- ============================================================================
local guiParent = getGuiParent()
local existing = guiParent:FindFirstChild("SyphusGoDebuggerHUD")
if existing then
    existing:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "SyphusGoDebuggerHUD"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 999999
ScreenGui.IgnoreGuiInset = true

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 380, 0, 210)
MainFrame.Position = UDim2.new(0.5, -190, 0.15, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(16, 20, 28)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.ClipsDescendants = true
MainFrame.ZIndex = 1
MainFrame.Visible = true

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 8)
UICorner.Parent = MainFrame

local UIStroke = Instance.new("UIStroke")
UIStroke.Color = Color3.fromRGB(48, 58, 82)
UIStroke.Thickness = 2
UIStroke.Parent = MainFrame

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Name = "TitleLabel"
TitleLabel.Size = UDim2.new(1, -20, 0, 28)
TitleLabel.Position = UDim2.new(0, 10, 0, 8)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "SYPHUS // GO + TAILSCALE SOURCE DUMPER"
TitleLabel.TextColor3 = Color3.fromRGB(235, 240, 255)
TitleLabel.Font = Enum.Font.Code
TitleLabel.TextSize = 14
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.ZIndex = 2
TitleLabel.Parent = MainFrame

local EndpointBox = Instance.new("TextBox")
EndpointBox.Name = "EndpointBox"
EndpointBox.Size = UDim2.new(1, -20, 0, 30)
EndpointBox.Position = UDim2.new(0, 10, 0, 40)
EndpointBox.BackgroundColor3 = Color3.fromRGB(10, 12, 18)
EndpointBox.BorderSizePixel = 0
EndpointBox.TextColor3 = Color3.fromRGB(96, 165, 250)
EndpointBox.PlaceholderColor3 = Color3.fromRGB(100, 116, 139)
EndpointBox.Font = Enum.Font.Code
EndpointBox.TextSize = 12
EndpointBox.Text = DebuggerState.ServerEndpoint
EndpointBox.PlaceholderText = "Tailscale IP / Funnel URL (e.g. http://100.x.x.x:8080)"
EndpointBox.ClearTextOnFocus = false
EndpointBox.ClipsDescendants = true
EndpointBox.ZIndex = 2
local EndpointCorner = Instance.new("UICorner")
EndpointCorner.CornerRadius = UDim.new(0, 5)
EndpointCorner.Parent = EndpointBox
EndpointBox.Parent = MainFrame

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Name = "StatusLabel"
StatusLabel.Size = UDim2.new(1, -20, 0, 22)
StatusLabel.Position = UDim2.new(0, 10, 0, 76)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "Folder: Awaiting Start..."
StatusLabel.TextColor3 = Color3.fromRGB(148, 163, 184)
StatusLabel.Font = Enum.Font.Code
StatusLabel.TextSize = 12
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.ClipsDescendants = true
StatusLabel.ZIndex = 2
StatusLabel.Parent = MainFrame

local ProgressBg = Instance.new("Frame")
ProgressBg.Name = "ProgressBg"
ProgressBg.Size = UDim2.new(1, -20, 0, 16)
ProgressBg.Position = UDim2.new(0, 10, 0, 104)
ProgressBg.BackgroundColor3 = Color3.fromRGB(8, 10, 14)
ProgressBg.BorderSizePixel = 0
ProgressBg.ClipsDescendants = true
ProgressBg.ZIndex = 2
local ProgressBgCorner = Instance.new("UICorner")
ProgressBgCorner.CornerRadius = UDim.new(0, 6)
ProgressBgCorner.Parent = ProgressBg

local ProgressFill = Instance.new("Frame")
ProgressFill.Name = "ProgressFill"
ProgressFill.Size = UDim2.new(0, 0, 1, 0)
ProgressFill.BackgroundColor3 = Color3.fromRGB(16, 185, 129)
ProgressFill.BorderSizePixel = 0
ProgressFill.ZIndex = 3
local ProgressFillCorner = Instance.new("UICorner")
ProgressFillCorner.CornerRadius = UDim.new(0, 6)
ProgressFillCorner.Parent = ProgressFill
ProgressFill.Parent = ProgressBg
ProgressBg.Parent = MainFrame

local ProgressText = Instance.new("TextLabel")
ProgressText.Name = "ProgressText"
ProgressText.Size = UDim2.new(1, -20, 0, 18)
ProgressText.Position = UDim2.new(0, 10, 0, 124)
ProgressText.BackgroundTransparency = 1
ProgressText.Text = "Progress: 0 / 0 (0%)"
ProgressText.TextColor3 = Color3.fromRGB(226, 232, 240)
ProgressText.Font = Enum.Font.Code
ProgressText.TextSize = 12
ProgressText.TextXAlignment = Enum.TextXAlignment.Left
ProgressText.ClipsDescendants = true
ProgressText.ZIndex = 2
ProgressText.Parent = MainFrame

local StartBtn = Instance.new("TextButton")
StartBtn.Name = "StartBtn"
StartBtn.Size = UDim2.new(0.48, -10, 0, 38)
StartBtn.Position = UDim2.new(0, 10, 0, 154)
StartBtn.BackgroundColor3 = Color3.fromRGB(16, 185, 129)
StartBtn.BorderSizePixel = 0
StartBtn.TextColor3 = Color3.fromRGB(5, 46, 22)
StartBtn.Font = Enum.Font.Code
StartBtn.TextSize = 13
StartBtn.Text = "START EXPORT"
StartBtn.AutoButtonColor = true
StartBtn.ZIndex = 2
local StartCorner = Instance.new("UICorner")
StartCorner.CornerRadius = UDim.new(0, 6)
StartCorner.Parent = StartBtn
StartBtn.Parent = MainFrame

local StopBtn = Instance.new("TextButton")
StopBtn.Name = "StopBtn"
StopBtn.Size = UDim2.new(0.48, -10, 0, 38)
StopBtn.Position = UDim2.new(0.52, 0, 0, 154)
StopBtn.BackgroundColor3 = Color3.fromRGB(239, 68, 68)
StopBtn.BorderSizePixel = 0
StopBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
StopBtn.Font = Enum.Font.Code
StopBtn.TextSize = 13
StopBtn.Text = "STOP / ABORT"
StopBtn.AutoButtonColor = true
StopBtn.ZIndex = 2
local StopCorner = Instance.new("UICorner")
StopCorner.CornerRadius = UDim.new(0, 6)
StopCorner.Parent = StopBtn
StopBtn.Parent = MainFrame

-- Parent ScreenGui only after the entire tree is configured
MainFrame.Parent = ScreenGui
ScreenGui.Parent = guiParent

-- Reliable cross-executor drag behavior (replaces deprecated Frame.Draggable)
do
    local dragging = false
    local dragInput, dragStart, startPos

    MainFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = MainFrame.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    MainFrame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
end

-- ============================================================================
-- SOURCE & BYTECODE COLLECTOR ENGINE
-- ============================================================================
local function base64Encode(data)
    if crypt and crypt.base64encode then
        return crypt.base64encode(data)
    end
    local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    return ((data:gsub('.', function(x)
        local r, byte = '', x:byte()
        for i = 8, 1, -1 do r = r .. (byte % 2^i - byte % 2^(i - 1) > 0 and '1' or '0') end
        return r
    end) .. '0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if #x < 6 then return '' end
        local c = 0
        for i = 1, 6 do c = c + (x:sub(i, i) == '1' and 2^(6 - i) or 0) end
        return b:sub(c + 1, c + 1)
    end) .. ({ '', '==', '=' })[#data % 3 + 1])
end

local function extractScriptData(scr)
    local rawSrc = ""
    local bcB64 = ""

    -- 1. Try direct .Source property
    pcall(function()
        if scr.Source and #scr.Source > 0 then
            rawSrc = scr.Source
        end
    end)

    -- 2. Try executor decompile()
    if rawSrc == "" and type(decompile) == "function" then
        pcall(function()
            local dec = decompile(scr)
            if dec and #dec > 0 then
                rawSrc = dec
            end
        end)
    end

    -- 3. Always grab raw bytecode if available for server-side constant/string recovery
    if type(getscriptbytecode) == "function" then
        pcall(function()
            local bc = getscriptbytecode(scr)
            if bc and #bc > 0 then
                bcB64 = base64Encode(bc)
            end
        end)
    end

    return rawSrc, bcB64
end

local function gatherAllMapScripts()
    local list = {}
    local seen = {}

    for _, inst in ipairs(game:GetDescendants()) do
        if inst:IsA("LocalScript") or inst:IsA("ModuleScript") or inst:IsA("Script") then
            seen[inst] = true
            table.insert(list, inst)
        end
    end

    if type(getnilinstances) == "function" then
        pcall(function()
            for _, inst in ipairs(getnilinstances()) do
                if (inst:IsA("LocalScript") or inst:IsA("ModuleScript")) and not seen[inst] then
                    seen[inst] = true
                    table.insert(list, inst)
                end
            end
        end)
    end

    return list
end

-- ============================================================================
-- DISPATCHER & PROGRESS SYNC WITH GO SERVER
-- ============================================================================
local function safeRequest(req)
    local ok, res = pcall(httpRequest, req)
    if not ok then
        return nil, tostring(res)
    end
    return res, nil
end

local function startExportPipeline()
    if DebuggerState.IsRunning then return end
    DebuggerState.IsRunning = true
    DebuggerState.ServerEndpoint = normalizeEndpoint(EndpointBox.Text)
    EndpointBox.Text = DebuggerState.ServerEndpoint

    task.spawn(function()
        StatusLabel.Text = "Scanning DataModel & Nil Instances..."
        ProgressFill.Size = UDim2.new(0, 0, 1, 0)
        ProgressText.Text = "Progress: 0 / 0 (0%)"

        local scripts = gatherAllMapScripts()
        DebuggerState.TotalScripts = #scripts
        DebuggerState.SentScripts = 0

        -- 1. Initialize EXP_DATE_GAME_RANDOM_UNIX folder on Go Server
        local initRes = safeRequest({
            Url = DebuggerState.ServerEndpoint .. "/api/init",
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode({
                place_id = game.PlaceId,
                game_name = "RobloxPlace_" .. tostring(game.PlaceId),
                total_scripts = DebuggerState.TotalScripts,
            })
        })

        if not initRes or initRes.StatusCode ~= 200 then
            local code = initRes and tostring(initRes.StatusCode) or "NO_RESPONSE"
            StatusLabel.Text = "ERROR: Cannot reach Go Server (" .. code .. ")"
            DebuggerState.IsRunning = false
            return
        end

        local okDecode, initData = pcall(function()
            return HttpService:JSONDecode(initRes.Body)
        end)
        if not okDecode or type(initData) ~= "table" or not initData.session_id then
            StatusLabel.Text = "ERROR: Invalid JSON response from /api/init"
            DebuggerState.IsRunning = false
            return
        end

        DebuggerState.SessionID = initData.session_id
        StatusLabel.Text = "Folder: " .. tostring(DebuggerState.SessionID)

        -- 2. Stream every script to Go server for storage + deobfuscation
        for idx, scr in ipairs(scripts) do
            if not DebuggerState.IsRunning then
                StatusLabel.Text = "ABORTED AT " .. idx .. " / " .. DebuggerState.TotalScripts
                break
            end

            local sPath = "NilInstance." .. scr.Name
            pcall(function() sPath = scr:GetFullName() end)

            local src, bcB64 = extractScriptData(scr)
            if src == "" and bcB64 == "" then
                src = "-- [[ EMPTY OR SERVER-ONLY SCRIPT: " .. sPath .. " ]]"
            end

            local payload = HttpService:JSONEncode({
                session_id   = DebuggerState.SessionID,
                place_id     = game.PlaceId,
                script_path  = sPath,
                class_name   = scr.ClassName,
                source       = src,
                bytecode_b64 = bcB64,
                index        = idx,
                total        = DebuggerState.TotalScripts,
            })

            local res = safeRequest({
                Url = DebuggerState.ServerEndpoint .. "/api/ingest",
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = payload,
            })

            while res and res.StatusCode == 503 and DebuggerState.IsRunning do
                StatusLabel.Text = "Server Paused by Go GUI Operator..."
                task.wait(1)
                if not DebuggerState.IsRunning then break end
                res = safeRequest({
                    Url = DebuggerState.ServerEndpoint .. "/api/ingest",
                    Method = "POST",
                    Headers = { ["Content-Type"] = "application/json" },
                    Body = payload,
                })
            end

            if not DebuggerState.IsRunning then
                StatusLabel.Text = "ABORTED AT " .. idx .. " / " .. DebuggerState.TotalScripts
                break
            end

            if res and res.StatusCode == 200 then
                StatusLabel.Text = "Folder: " .. tostring(DebuggerState.SessionID)
            end

            DebuggerState.SentScripts = idx
            local ratio = idx / math.max(1, DebuggerState.TotalScripts)
            ProgressFill.Size = UDim2.new(ratio, 0, 1, 0)
            ProgressText.Text = string.format("Progress: %d / %d (%d%%) - %s", idx, DebuggerState.TotalScripts, math.floor(ratio * 100), scr.Name)

            task.wait(0.02)
        end

        if DebuggerState.IsRunning then
            StatusLabel.Text = "DONE -> " .. tostring(DebuggerState.SessionID)
            DebuggerState.IsRunning = false
        end
    end)
end

StartBtn.MouseButton1Click:Connect(startExportPipeline)
StopBtn.MouseButton1Click:Connect(function()
    DebuggerState.IsRunning = false
end)