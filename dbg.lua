-- File: dbg.lua
-- Runtime: Roblox Client Executor (supports request/http_request, getscriptbytecode, decompile, getnilinstances)

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local httpRequest = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request
assert(httpRequest, "[SYPHUS DEBUGGER] Executor requires HTTP request capability (request / http_request).")

-- ============================================================================
-- STATE & CONFIGURATION
-- ============================================================================
local DebuggerState = {
    ServerEndpoint = "http://100.90.69.99:8080", -- Tailscale IPv4:8080 or https://your-node.ts.net
    IsRunning      = false,
    DecompileMode  = false, -- false = FAST TRANSFER (Bytecode + Source), true = FULL DECOMPILE (Dedup + Guard)
    SessionID      = "NONE",
    TotalScripts   = 0,
    SentScripts    = 0,
    FailedScripts  = 0,
}

local BATCH_MAX_COUNT    = 30
local BATCH_MAX_BYTES    = 512 * 1024
local MAX_WORKERS        = 4
local MAX_QUEUE_DEPTH    = 10
local MAX_DECOMP_BYTES   = 262144 -- Skip decompile() on bytecode >256KB to prevent executor crash
local FRAME_BUDGET_SEC   = 0.012  -- Yield every ~12ms so Roblox never freezes or disconnects

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
-- IN-GAME 2.5D GUI CONSTRUCTION (FAST BATCH TRANSFER + MODE TOGGLE)
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
MainFrame.Size = UDim2.new(0, 380, 0, 246)
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
TitleLabel.Text = "SYPHUS // FAST BATCH SOURCE DUMPER"
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

local ModeBtn = Instance.new("TextButton")
ModeBtn.Name = "ModeBtn"
ModeBtn.Size = UDim2.new(1, -20, 0, 28)
ModeBtn.Position = UDim2.new(0, 10, 0, 150)
ModeBtn.BackgroundColor3 = Color3.fromRGB(30, 41, 59)
ModeBtn.BorderSizePixel = 0
ModeBtn.TextColor3 = Color3.fromRGB(56, 189, 248)
ModeBtn.Font = Enum.Font.Code
ModeBtn.TextSize = 12
ModeBtn.Text = "MODE: FAST TRANSFER (BYTECODE + SRC)"
ModeBtn.AutoButtonColor = true
ModeBtn.ZIndex = 2
local ModeCorner = Instance.new("UICorner")
ModeCorner.CornerRadius = UDim.new(0, 5)
ModeCorner.Parent = ModeBtn
ModeBtn.Parent = MainFrame

local StartBtn = Instance.new("TextButton")
StartBtn.Name = "StartBtn"
StartBtn.Size = UDim2.new(0.48, -10, 0, 38)
StartBtn.Position = UDim2.new(0, 10, 0, 190)
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
StopBtn.Position = UDim2.new(0.52, 0, 0, 190)
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

MainFrame.Parent = ScreenGui
ScreenGui.Parent = guiParent

-- Reliable cross-executor drag behavior
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
-- FAST O(N) BASE64 + FRAME-BUDGETED COLLECTOR ENGINE
-- ============================================================================
local nativeB64 = (crypt and (crypt.base64encode or (crypt.base64 and crypt.base64.encode)))
    or (syn and syn.crypt and syn.crypt.base64 and syn.crypt.base64.encode)
    or base64_encode
    or (base64 and base64.encode)

local B64_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64_LUT = {}
for i = 0, 63 do
    B64_LUT[i] = B64_ALPHABET:sub(i + 1, i + 1)
end

local function base64Encode(data)
    if data == "" then return "" end
    if nativeB64 then
        local ok, res = pcall(nativeB64, data)
        if ok and type(res) == "string" then
            return res
        end
    end

    local len = #data
    local out = table.create(math.ceil(len / 3))
    local idx = 1
    for i = 1, len, 3 do
        local b1, b2, b3 = data:byte(i, i + 2)
        local n = b1 * 65536 + (b2 or 0) * 256 + (b3 or 0)
        local c1 = math.floor(n / 262144) % 64
        local c2 = math.floor(n / 4096) % 64
        local c3 = math.floor(n / 64) % 64
        local c4 = n % 64
        out[idx] = B64_LUT[c1] .. B64_LUT[c2] .. (b2 and B64_LUT[c3] or "=") .. (b3 and B64_LUT[c4] or "=")
        idx += 1
    end
    return table.concat(out)
end

local lastYieldAt = os.clock()
local function maybeYield()
    if os.clock() - lastYieldAt >= FRAME_BUDGET_SEC then
        RunService.Heartbeat:Wait()
        lastYieldAt = os.clock()
    end
end

local function isClientRunnableScript(inst)
    if inst:IsA("LocalScript") or inst:IsA("ModuleScript") then
        return true
    end
    if inst:IsA("Script") then
        local ok, rc = pcall(function() return inst.RunContext end)
        if ok and rc == Enum.RunContext.Client then
            return true
        end
    end
    return false
end

local function gatherAllMapScripts()
    local list = {}
    local seen = {}

    for _, inst in ipairs(game:GetDescendants()) do
        if isClientRunnableScript(inst) then
            seen[inst] = true
            table.insert(list, inst)
        end
        maybeYield()
    end

    if type(getnilinstances) == "function" then
        pcall(function()
            for _, inst in ipairs(getnilinstances()) do
                if isClientRunnableScript(inst) and not seen[inst] then
                    seen[inst] = true
                    table.insert(list, inst)
                end
                maybeYield()
            end
        end)
    end

    return list
end

local function extractScriptData(scr, decompCache, allowDecompile)
    local rawSrc = ""
    local bcRaw = ""
    local bcB64 = ""

    -- 1. Try direct .Source property (instant)
    pcall(function()
        if scr.Source and #scr.Source > 0 then
            rawSrc = scr.Source
        end
    end)

    -- 2. Grab raw bytecode (instant C-side call)
    if type(getscriptbytecode) == "function" then
        pcall(function()
            local bc = getscriptbytecode(scr)
            if bc and #bc > 0 then
                bcRaw = bc
                bcB64 = base64Encode(bc)
            end
        end)
    end

    -- 3. Optional decompile() ONLY in FULL DECOMPILE mode, with dedup cache & crash size guard
    if allowDecompile and rawSrc == "" and type(decompile) == "function" then
        if bcRaw ~= "" and decompCache[bcRaw] ~= nil then
            rawSrc = decompCache[bcRaw]
        elseif #bcRaw <= MAX_DECOMP_BYTES then
            pcall(function()
                local dec = decompile(scr)
                if dec and #dec > 0 then
                    rawSrc = dec
                end
            end)
            if bcRaw ~= "" then
                decompCache[bcRaw] = rawSrc
            end
        else
            rawSrc = "-- [[ SKIPPED DECOMPILE (>256KB BYTECODE CRASH GUARD); RAW BYTECODE ATTACHED ]]"
        end
    end

    return rawSrc, bcB64
end

-- ============================================================================
-- BOUNDED CONCURRENT BATCH UPLOADER + ANTI-IDLE PROTECTION
-- ============================================================================
local function safeRequest(req)
    local ok, res = pcall(httpRequest, req)
    if not ok then
        return nil, tostring(res)
    end
    return res, nil
end

local function updateProgressUI(sent, total, failed, startTime)
    local elapsed = math.max(0.01, os.clock() - startTime)
    local rate = math.floor(sent / elapsed)
    local ratio = sent / math.max(1, total)
    ProgressFill.Size = UDim2.new(ratio, 0, 1, 0)
    if failed > 0 then
        ProgressText.Text = string.format("Progress: %d / %d (%d%%) | %d/s | Err:%d", sent, total, math.floor(ratio * 100), rate, failed)
    else
        ProgressText.Text = string.format("Progress: %d / %d (%d%%) | %d scripts/s", sent, total, math.floor(ratio * 100), rate)
    end
end

local function sendBatchWithRetry(endpoint, sessionID, placeID, totalScripts, items)
    local okJson, body = pcall(function()
        return HttpService:JSONEncode({
            session_id = sessionID,
            place_id   = placeID,
            total      = totalScripts,
            scripts    = items,
        })
    end)
    if not okJson then
        return false, "json_encode_err"
    end

    for attempt = 1, 3 do
        if not DebuggerState.IsRunning then
            return false, "aborted"
        end

        local res = safeRequest({
            Url     = endpoint .. "/api/ingest-batch",
            Method  = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body    = body,
        })

        while res and res.StatusCode == 503 and DebuggerState.IsRunning do
            StatusLabel.Text = "Server Paused by Go GUI Operator..."
            task.wait(1)
            if not DebuggerState.IsRunning then
                return false, "aborted"
            end
            res = safeRequest({
                Url     = endpoint .. "/api/ingest-batch",
                Method  = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body    = body,
            })
        end

        if res and res.StatusCode == 200 then
            return true, nil
        end

        -- Backward compatibility fallback if server only exposes /api/ingest
        if res and res.StatusCode == 404 then
            local allOk = true
            for _, item in ipairs(items) do
                if not DebuggerState.IsRunning then return false, "aborted" end
                local rSingle = safeRequest({
                    Url     = endpoint .. "/api/ingest",
                    Method  = "POST",
                    Headers = { ["Content-Type"] = "application/json" },
                    Body    = HttpService:JSONEncode(item),
                })
                if not rSingle or rSingle.StatusCode ~= 200 then
                    allOk = false
                end
            end
            return allOk, allOk and nil or "single_fallback_err"
        end

        task.wait(0.25 * attempt)
    end

    return false, "batch_failed"
end

local function startExportPipeline()
    if DebuggerState.IsRunning then return end
    DebuggerState.IsRunning = true
    DebuggerState.ServerEndpoint = normalizeEndpoint(EndpointBox.Text)
    EndpointBox.Text = DebuggerState.ServerEndpoint

    local idleConn
    pcall(function()
        local vu = game:GetService("VirtualUser")
        local lp = Players.LocalPlayer
        if vu and lp then
            idleConn = lp.Idled:Connect(function()
                pcall(function()
                    vu:CaptureController()
                    vu:ClickButton2(Vector2.new())
                end)
            end)
        end
    end)

    task.spawn(function()
        local startedAt = os.clock()
        StatusLabel.Text = "Scanning Client Scripts & Nil Instances..."
        ProgressFill.Size = UDim2.new(0, 0, 1, 0)
        ProgressText.Text = "Progress: 0 / 0 (0%)"

        local scripts = gatherAllMapScripts()
        DebuggerState.TotalScripts = #scripts
        DebuggerState.SentScripts = 0
        DebuggerState.FailedScripts = 0

        -- 1. Initialize session folder on Go Server
        local initRes = safeRequest({
            Url     = DebuggerState.ServerEndpoint .. "/api/init",
            Method  = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body    = HttpService:JSONEncode({
                place_id      = game.PlaceId,
                game_name     = "RobloxPlace_" .. tostring(game.PlaceId),
                total_scripts = DebuggerState.TotalScripts,
            })
        })

        if not initRes or initRes.StatusCode ~= 200 then
            local code = initRes and tostring(initRes.StatusCode) or "NO_RESPONSE"
            StatusLabel.Text = "ERROR: Cannot reach Go Server (" .. code .. ")"
            DebuggerState.IsRunning = false
            if idleConn then idleConn:Disconnect() end
            return
        end

        local okDecode, initData = pcall(function()
            return HttpService:JSONDecode(initRes.Body)
        end)
        if not okDecode or type(initData) ~= "table" or not initData.session_id then
            StatusLabel.Text = "ERROR: Invalid JSON response from /api/init"
            DebuggerState.IsRunning = false
            if idleConn then idleConn:Disconnect() end
            return
        end

        DebuggerState.SessionID = initData.session_id
        StatusLabel.Text = "Streaming -> " .. tostring(DebuggerState.SessionID)

        -- 2. Bounded Producer-Consumer Batch Upload Pipeline
        local batchQueue = {}
        local producerDone = false
        local activeWorkers = 0
        local decompCache = {}
        local allowDecompile = DebuggerState.DecompileMode

        for w = 1, MAX_WORKERS do
            activeWorkers += 1
            task.spawn(function()
                while true do
                    if not DebuggerState.IsRunning then
                        break
                    end

                    local batch = table.remove(batchQueue, 1)
                    if batch then
                        local ok = sendBatchWithRetry(
                            DebuggerState.ServerEndpoint,
                            DebuggerState.SessionID,
                            game.PlaceId,
                            DebuggerState.TotalScripts,
                            batch
                        )
                        if ok then
                            DebuggerState.SentScripts += #batch
                        else
                            DebuggerState.FailedScripts += #batch
                        end
                        updateProgressUI(
                            DebuggerState.SentScripts,
                            DebuggerState.TotalScripts,
                            DebuggerState.FailedScripts,
                            startedAt
                        )
                    elseif producerDone then
                        break
                    else
                        task.wait(0.02)
                    end
                end
                activeWorkers -= 1
            end)
        end

        local currentBatch = {}
        local currentBytes = 0

        for idx, scr in ipairs(scripts) do
            if not DebuggerState.IsRunning then
                break
            end

            local sPath = "NilInstance." .. scr.Name
            pcall(function() sPath = scr:GetFullName() end)

            local src, bcB64 = extractScriptData(scr, decompCache, allowDecompile)
            if src == "" and bcB64 == "" then
                src = "-- [[ EMPTY OR PROTECTED SCRIPT: " .. sPath .. " ]]"
            end

            local item = {
                session_id   = DebuggerState.SessionID,
                place_id     = game.PlaceId,
                script_path  = sPath,
                class_name   = scr.ClassName,
                source       = src,
                bytecode_b64 = bcB64,
                index        = idx,
                total        = DebuggerState.TotalScripts,
            }

            table.insert(currentBatch, item)
            currentBytes += #src + #bcB64 + #sPath + 128

            if #currentBatch >= BATCH_MAX_COUNT or currentBytes >= BATCH_MAX_BYTES then
                while #batchQueue >= MAX_QUEUE_DEPTH and DebuggerState.IsRunning do
                    RunService.Heartbeat:Wait()
                    lastYieldAt = os.clock()
                end
                if not DebuggerState.IsRunning then break end
                table.insert(batchQueue, currentBatch)
                currentBatch = {}
                currentBytes = 0
            end

            maybeYield()
        end

        if #currentBatch > 0 and DebuggerState.IsRunning then
            table.insert(batchQueue, currentBatch)
        end
        producerDone = true

        while activeWorkers > 0 do
            task.wait(0.05)
        end

        if idleConn then
            idleConn:Disconnect()
        end

        if not DebuggerState.IsRunning then
            StatusLabel.Text = "ABORTED AT " .. DebuggerState.SentScripts .. " / " .. DebuggerState.TotalScripts
        else
            local elapsed = os.clock() - startedAt
            StatusLabel.Text = string.format("DONE (%.1fs) -> %s", elapsed, tostring(DebuggerState.SessionID))
            DebuggerState.IsRunning = false
        end
    end)
end

ModeBtn.MouseButton1Click:Connect(function()
    if DebuggerState.IsRunning then return end
    DebuggerState.DecompileMode = not DebuggerState.DecompileMode
    if DebuggerState.DecompileMode then
        ModeBtn.Text = "MODE: FULL DECOMPILE (DEDUP + GUARD)"
        ModeBtn.TextColor3 = Color3.fromRGB(251, 191, 36)
    else
        ModeBtn.Text = "MODE: FAST TRANSFER (BYTECODE + SRC)"
        ModeBtn.TextColor3 = Color3.fromRGB(56, 189, 248)
    end
end)

StartBtn.MouseButton1Click:Connect(startExportPipeline)
StopBtn.MouseButton1Click:Connect(function()
    DebuggerState.IsRunning = false
end)
