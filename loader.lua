--!nocheck
local TARGET_URL = "https://raw.githubusercontent.com/Mytzcodes/GUIX/refs/heads/main/SYT_CN.lua"

local function notify(title, text)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = tostring(title),
            Text = tostring(text),
            Duration = 5,
        })
    end)
end

if not game:IsLoaded() then
    pcall(function()
        game.Loaded:Wait()
    end)
end

local Players = game:GetService("Players")
if not Players.LocalPlayer then
    local deadline = os.clock() + 10
    while not Players.LocalPlayer and os.clock() < deadline do
        task.wait(0.1)
    end
end

local function isValidSource(body)
    return type(body) == "string" and #body > 128 and string.sub(body, 1, 4) ~= "404:"
end

local function fetchSource(url)
    local okPlain, resPlain = pcall(function()
        return game:HttpGet(url, true)
    end)
    if okPlain and isValidSource(resPlain) then
        return resPlain
    end

    local bustUrl = url .. "?t=" .. tostring(math.floor(os.time()))
    local okBust, resBust = pcall(function()
        return game:HttpGet(bustUrl, true)
    end)
    if okBust and isValidSource(resBust) then
        return resBust
    end

    local reqFn = (type(syn) == "table" and type(syn.request) == "function" and syn.request)
        or (type(http_request) == "function" and http_request)
        or (type(request) == "function" and request)
        or nil

    if reqFn then
        local okReq, resp = pcall(reqFn, { Url = bustUrl, Method = "GET" })
        if okReq and type(resp) == "table" and isValidSource(resp.Body) then
            return resp.Body
        end
    end

    return nil, tostring(resPlain or resBust or "Gagal mengunduh SYT.lua")
end

local src, fetchErr = fetchSource(TARGET_URL)
if not src then
    warn("[SYT Loader] Download gagal: " .. tostring(fetchErr))
    notify("SYT Loader", "Gagal mengunduh script. Cek koneksi/URL.")
    return
end

local chunk, compileErr = loadstring(src)
if type(chunk) ~= "function" then
    warn("[SYT Loader] Compile error: " .. tostring(compileErr))
    notify("SYT Loader", "Compile error! Cek F9 console.")
    return
end

local okRun, resOrErr = xpcall(chunk, debug.traceback)
if not okRun then
    warn("[SYT Loader] Runtime error:\n" .. tostring(resOrErr))
    notify("SYT Loader", "Runtime error! Cek F9 console.")
    return
end

return resOrErr
