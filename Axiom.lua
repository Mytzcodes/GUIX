--[[
	AXIOM
	Monochrome engineering menu for a Roblox place.

	Run this file in a Roblox executor, or drop it in as a LocalScript.
	It builds a ScreenGui with the normal engine API.

	The $250 mark is a price label on the chrome.
	The redeem step accepts one local demonstration key and only flips a
	flag in this session. Names, passwords, and keys stay in memory.
	Nothing is sent to a server. This script does not change gameplay.

	Default shortcut: Right Shift shows and hides the window.
	Re-executing the script replaces the previous window.

	Extension (interface rows only), after the menu is open:
		Axiom.addToggle("Label", false, function(on) end)
		Axiom.addSlider("Label", 0, 100, 50, function(value) end)
		Axiom.addInput("Label", "", function(text) end)
		Axiom.addButton("Label", function() end)
		Axiom.notify("Note")
		Axiom.destroy()
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer or Players.PlayerAdded:Wait()
local playerGui = player:WaitForChild("PlayerGui")

local DEMO_KEY = "AXIO-2500-MONO-0001"
local PRICE = "$250"

local function font(name)
	local ok, value = pcall(function()
		return Enum.Font[name]
	end)
	if ok and value then
		return value
	end
	return Enum.Font.SourceSans
end

local FONT = font("Gotham")
local FONT_MED = font("GothamMedium")
local FONT_BOLD = font("GothamBold")
local FONT_CODE = font("Code")

local T = {
	bg = Color3.fromRGB(10, 10, 10),
	raised = Color3.fromRGB(18, 18, 18),
	inset = Color3.fromRGB(6, 6, 6),
	hover = Color3.fromRGB(28, 28, 28),
	line = Color3.fromRGB(58, 58, 58),
	lineSoft = Color3.fromRGB(36, 36, 36),
	text = Color3.fromRGB(242, 242, 242),
	dim = Color3.fromRGB(186, 186, 186),
	mute = Color3.fromRGB(154, 154, 154),
	ink = Color3.fromRGB(10, 10, 10),
}

local settings = {
	motion = true,
	opacity = 1,
	scale = 1,
	animSpeed = 1,
	menuKey = Enum.KeyCode.RightShift,
	notes = "",
	callsign = "",
	indexValue = "01",
	density = "Comfort",
}

local session = {
	user = nil,
	email = nil,
	licensed = false,
}

local accounts = {}
local customRows = {}
local conns = {}
local destroyed = false
local userMoved = false
local authTab = "login"
local appTab = "Home"
local view = "auth"
local mobile = false
local fitScale = 1
local animToken = 0
local toastToken = 0
local listening = nil
local dropdownCloser = nil

local screen
local shell
local uiScale
local header
local sectionBar
local sectionTitle
local sectionHint
local body
local rail
local railRule
local railLayout
local canvas
local scroll
local content
local footerLabel
local toast
local dock
local errorLabel

local function track(conn)
	table.insert(conns, conn)
	return conn
end

local function new(class, props)
	local inst = Instance.new(class)
	local parent = props.Parent
	for key, value in pairs(props) do
		if key ~= "Parent" then
			inst[key] = value
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function corner(parent, radius)
	return new("UICorner", {
		CornerRadius = UDim.new(0, radius or 2),
		Parent = parent,
	})
end

local function stroke(parent, color, thickness)
	local item = new("UIStroke", {
		Color = color or T.line,
		Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
	pcall(function()
		item.BorderStrokePosition = Enum.BorderStrokePosition.Inside
	end)
	return item
end

local function tween(instance, duration, props)
	if not settings.motion then
		for key, value in pairs(props) do
			instance[key] = value
		end
		return nil
	end
	local speed = settings.animSpeed
	if speed < 0.5 then
		speed = 0.5
	end
	local info = TweenInfo.new(duration / speed, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	local play = TweenService:Create(instance, info, props)
	play:Play()
	return play
end

local function viewport()
	local camera = workspace.CurrentCamera
	if camera then
		return camera.ViewportSize
	end
	return Vector2.new(1280, 720)
end

local function rowHeight()
	if mobile then
		return 48
	end
	if settings.density == "Dense" then
		return 36
	end
	return 44
end

local function keyName(code)
	if typeof(code) ~= "EnumItem" then
		return "None"
	end
	local name = code.Name
	name = string.gsub(name, "(%l)(%u)", "%1 %2")
	name = string.gsub(name, "(%u)(%u%l)", "%1 %2")
	return name
end

local function targetScale()
	return math.clamp(settings.scale, 0.85, 1.2) * fitScale
end

local function applyChrome()
	if not shell then
		return
	end
	shell.BackgroundTransparency = 1 - settings.opacity
	if not stateMinimized() then
		uiScale.Scale = targetScale()
	end
end

local minimized = false
function stateMinimized()
	return minimized
end

local function notify(text)
	if not toast then
		return
	end
	toastToken = toastToken + 1
	local token = toastToken
	toast.Text = "  " .. tostring(text)
	toast.Visible = true
	task.delay(2.4, function()
		if token == toastToken and toast then
			toast.Visible = false
		end
	end)
end

local function shutdown()
	if destroyed then
		return
	end
	destroyed = true
	for index = #conns, 1, -1 do
		local conn = conns[index]
		if conn then
			conn:Disconnect()
		end
		conns[index] = nil
	end
	if screen then
		screen:Destroy()
	end
	screen = nil
end

local function paint(root, color)
	for _, item in ipairs(root:GetDescendants()) do
		if item:IsA("Frame") then
			item.BackgroundColor3 = color
		elseif item:IsA("UIStroke") then
			item.Color = color
		end
	end
end

local function px(parent, x, y, w, h, color, radius)
	local frame = new("Frame", {
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		Parent = parent,
	})
	if radius and radius > 0 then
		corner(frame, radius)
	end
	return frame
end

local function drawIcon(kind, parent, color)
	local host = new("Frame", {
		Name = "Icon",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(16, 16),
		Parent = parent,
	})
	color = color or T.text
	if kind == "Home" then
		px(host, 3, 7, 10, 8, color, 1)
		px(host, 1, 6, 14, 2, color, 0)
		px(host, 6, 1, 4, 6, color, 0)
	elseif kind == "Menu" then
		px(host, 1, 3, 14, 2, color, 0)
		px(host, 1, 7, 10, 2, color, 0)
		px(host, 1, 11, 14, 2, color, 0)
	elseif kind == "Input" then
		local box = px(host, 1, 3, 14, 10, color, 1)
		box.BackgroundTransparency = 1
		stroke(box, color, 1)
		px(host, 4, 5, 1, 6, color, 0)
	elseif kind == "Keys" then
		local head = px(host, 1, 4, 7, 7, color, 4)
		head.BackgroundTransparency = 1
		stroke(head, color, 1)
		px(host, 7, 6, 8, 2, color, 0)
		px(host, 12, 6, 2, 4, color, 0)
	elseif kind == "User" then
		px(host, 5, 1, 6, 6, color, 3)
		px(host, 3, 9, 10, 6, color, 3)
	elseif kind == "Min" then
		px(host, 2, 7, 12, 2, color, 0)
	elseif kind == "Close" then
		local a = px(host, 0, 7, 16, 2, color, 0)
		local b = px(host, 0, 7, 16, 2, color, 0)
		a.AnchorPoint = Vector2.new(0.5, 0.5)
		b.AnchorPoint = Vector2.new(0.5, 0.5)
		a.Position = UDim2.fromScale(0.5, 0.5)
		b.Position = UDim2.fromScale(0.5, 0.5)
		a.Rotation = 45
		b.Rotation = -45
	else
		local mark = px(host, 1, 1, 14, 14, color, 1)
		mark.BackgroundTransparency = 1
		stroke(mark, color, 1)
		px(host, 5, 5, 6, 6, color, 0)
	end
	return host
end

local function clearContent()
	for _, child in ipairs(content:GetChildren()) do
		if child:IsA("UIListLayout") or child:IsA("UIPadding") then
			continue
		end
		child:Destroy()
	end
	errorLabel = nil
end

local function section(text)
	local holder = new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 18),
		Parent = content,
	})
	new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -8, 1, 0),
		Font = FONT_CODE,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = T.mute,
		Text = string.upper(text),
		Parent = holder,
	})
	return holder
end

local function hint(text)
	return new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 32),
		Font = FONT,
		TextSize = 13,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = T.dim,
		Text = text,
		Parent = content,
	})
end

local function setSection(title, hintText)
	sectionTitle.Text = string.upper(title)
	sectionHint.Text = hintText or ""
end

local function fieldLabel(text)
	return new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 16),
		Font = FONT_MED,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = T.dim,
		Text = string.upper(text),
		Parent = content,
	})
end

local function inputBox(placeholder, hidden)
	local height = rowHeight()
	local box = new("TextBox", {
		BackgroundColor3 = T.inset,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, height),
		Font = hidden and FONT_CODE or FONT,
		TextSize = 15,
		TextColor3 = T.text,
		PlaceholderText = placeholder or "",
		PlaceholderColor3 = T.mute,
		ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		ClipsDescendants = true,
		Parent = content,
	})
	corner(box, 2)
	local line = stroke(box, T.line, 1)
	new("UIPadding", {
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
		Parent = box,
	})
	box.Focused:Connect(function()
		tween(line, 0.14, { Color = T.text })
	end)
	box.FocusLost:Connect(function()
		tween(line, 0.14, { Color = T.line })
	end)

	local secret = ""
	if hidden then
		local busy = false
		box:GetPropertyChangedSignal("Text"):Connect(function()
			if busy then
				return
			end
			local shown = box.Text
			if shown == string.rep("*", #secret) then
				return
			end
			if #shown > #secret then
				secret = secret .. string.gsub(string.sub(shown, #secret + 1), "%*", "")
			elseif #shown < #secret then
				secret = string.sub(secret, 1, #shown)
			else
				local added = string.gsub(shown, "%*", "")
				if added ~= "" then
					secret = added
				end
			end
			busy = true
			box.Text = string.rep("*", #secret)
			box.CursorPosition = #secret + 1
			busy = false
		end)
	end

	local api = {}
	function api.get()
		if hidden then
			return secret
		end
		return box.Text
	end
	function api.set(text)
		if hidden then
			secret = tostring(text or "")
			box.Text = string.rep("*", #secret)
		else
			box.Text = tostring(text or "")
		end
	end
	function api.focus()
		box:CaptureFocus()
	end
	api.root = box
	return api
end

local function actionButton(text, style, callback)
	local height = math.max(rowHeight(), 44)
	local primary = style == "primary"
	local btn = new("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = primary and T.text or T.bg,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, height),
		Font = FONT_MED,
		TextSize = 14,
		TextColor3 = primary and T.ink or T.text,
		Text = text,
		Parent = content,
	})
	corner(btn, 2)
	if not primary then
		stroke(btn, T.line, 1)
	end
	btn.MouseEnter:Connect(function()
		local nextColor = primary and Color3.fromRGB(220, 220, 220) or T.hover
		tween(btn, 0.12, { BackgroundColor3 = nextColor })
	end)
	btn.MouseLeave:Connect(function()
		tween(btn, 0.12, { BackgroundColor3 = primary and T.text or T.bg })
	end)
	btn.Activated:Connect(function()
		if callback then
			callback()
		end
	end)
	return btn
end

local function showError(text)
	if not errorLabel then
		errorLabel = new("TextLabel", {
			BackgroundTransparency = 1,
			LayoutOrder = 1000,
			Size = UDim2.new(1, 0, 0, 32),
			Font = FONT_CODE,
			TextSize = 12,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextColor3 = T.text,
			Text = "",
			Parent = content,
		})
	end
	if text then
		errorLabel.Text = "ERR  " .. text
		errorLabel.Visible = true
	else
		errorLabel.Text = ""
		errorLabel.Visible = false
	end
end

local function card(parent, kicker, valueText, sub, widthScale)
	local item = new("Frame", {
		BackgroundColor3 = T.raised,
		BorderSizePixel = 0,
		Size = widthScale,
		Parent = parent,
	})
	corner(item, 2)
	stroke(item, T.lineSoft, 1)
	new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 8),
		Size = UDim2.new(1, -20, 0, 14),
		Font = FONT_CODE,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = T.mute,
		Text = string.upper(kicker),
		Parent = item,
	})
	new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 24),
		Size = UDim2.new(1, -20, 0, 22),
		Font = FONT_BOLD,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = T.text,
		Text = valueText,
		Parent = item,
	})
	new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 48),
		Size = UDim2.new(1, -20, 0, 16),
		Font = FONT,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = T.dim,
		Text = sub,
		Parent = item,
	})
	return item
end

local function cardRow(pairsList)
	local height = mobile and (78 * #pairsList + 8 * (#pairsList - 1)) or 78
	local row = new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, height),
		Parent = content,
	})
	new("UIListLayout", {
		FillDirection = mobile and Enum.FillDirection.Vertical or Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = row,
	})
	for index, item in ipairs(pairsList) do
		local width = mobile and UDim2.new(1, 0, 0, 78) or UDim2.new(0.5, -4, 1, 0)
		local made = card(row, item[1], item[2], item[3], width)
		made.LayoutOrder = index
	end
end

local function closeDropdown()
	if dropdownCloser then
		dropdownCloser()
		dropdownCloser = nil
	end
end

local function makeDropdown(labelText, options, getValue, setValue)
	fieldLabel(labelText)
	local height = rowHeight()
	local btn = new("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = T.inset,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, height),
		Font = FONT,
		TextSize = 15,
		TextColor3 = T.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "  " .. tostring(getValue()),
		Parent = content,
	})
	corner(btn, 2)
	stroke(btn, T.line, 1)
	new("TextLabel", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(16, 16),
		Font = FONT_CODE,
		TextSize = 14,
		TextColor3 = T.dim,
		Text = "+",
		Parent = btn,
	})

	btn.Activated:Connect(function()
		if dropdownCloser then
			closeDropdown()
			return
		end
		local blocker = new("TextButton", {
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 20,
			Parent = screen,
		})
		local menu = new("Frame", {
			BackgroundColor3 = T.bg,
			BorderSizePixel = 0,
			ZIndex = 21,
			Parent = screen,
		})
		corner(menu, 2)
		stroke(menu, T.text, 1)
		local list = new("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = menu,
		})
		local abs = btn.AbsolutePosition
		local size = btn.AbsoluteSize
		local menuHeight = math.min(#options * 36, 180)
		local menuY = abs.Y + size.Y + 4
		local viewSize = viewport()
		if menuY + menuHeight > viewSize.Y - 8 then
			menuY = math.max(8, abs.Y - menuHeight - 4)
		end
		menu.Position = UDim2.fromOffset(abs.X, menuY)
		menu.Size = UDim2.fromOffset(size.X, menuHeight)
		for index, option in ipairs(options) do
			local choice = new("TextButton", {
				AutoButtonColor = false,
				BackgroundColor3 = option == getValue() and T.text or T.bg,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 36),
				Font = FONT,
				TextSize = 14,
				TextColor3 = option == getValue() and T.ink or T.text,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = "  " .. option,
				ZIndex = 22,
				LayoutOrder = index,
				Parent = menu,
			})
			choice.Activated:Connect(function()
				btn.Text = "  " .. option
				closeDropdown()
				setValue(option)
			end)
		end
		list.Padding = UDim.new(0, 0)
		local function close()
			blocker:Destroy()
			menu:Destroy()
		end
		dropdownCloser = close
		blocker.Activated:Connect(closeDropdown)
	end)
end

local function makeToggle(labelText, getValue, setValue)
	local height = rowHeight()
	local btn = new("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = T.bg,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, height),
		Text = "",
		Parent = content,
	})
	new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(1, -120, 1, 0),
		Font = FONT,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = T.text,
		Text = labelText,
		Parent = btn,
	})
	local stateText = new("TextLabel", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -56, 0.5, 0),
		Size = UDim2.fromOffset(36, 18),
		Font = FONT_CODE,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = T.dim,
		Text = getValue() and "ON" or "OFF",
		Parent = btn,
	})
	local track = new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(40, 22),
		BackgroundColor3 = getValue() and T.text or T.inset,
		BorderSizePixel = 0,
		Parent = btn,
	})
	corner(track, 2)
	stroke(track, getValue() and T.text or T.line, 1)
	local knob = new("Frame", {
		Size = UDim2.fromOffset(14, 14),
		Position = UDim2.fromOffset(getValue() and 22 or 4, 4),
		BackgroundColor3 = getValue() and T.ink or T.text,
		BorderSizePixel = 0,
		Parent = track,
	})
	corner(knob, 1)

	local function paintState(on)
		stateText.Text = on and "ON" or "OFF"
		tween(track, 0.14, { BackgroundColor3 = on and T.text or T.inset })
		tween(knob, 0.14, {
			Position = UDim2.fromOffset(on and 22 or 4, 4),
			BackgroundColor3 = on and T.ink or T.text,
		})
		local line = track:FindFirstChildOfClass("UIStroke")
		if line then
			tween(line, 0.14, { Color = on and T.text or T.line })
		end
	end

	btn.Activated:Connect(function()
		local nextValue = not getValue()
		setValue(nextValue)
		paintState(nextValue)
	end)
end

local function makeSlider(labelText, minValue, maxValue, getValue, setValue, formatValue)
	local height = rowHeight()
	local holder = new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, height),
		Parent = content,
	})
	new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(0.42, 0, 1, 0),
		Font = FONT,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = T.text,
		Text = labelText,
		Parent = holder,
	})
	local valueLabel = new("TextLabel", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0.2, 0, 0, 16),
		Font = FONT_CODE,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = T.dim,
		Text = "",
		Parent = holder,
	})
	local hit = new("TextButton", {
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Text = "",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.new(0.48, 0, 1, 0),
		Parent = holder,
	})
	local track = new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.new(1, 0, 0, 2),
		BackgroundColor3 = T.line,
		BorderSizePixel = 0,
		Parent = hit,
	})
	local fill = new("Frame", {
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = T.text,
		BorderSizePixel = 0,
		Parent = track,
	})
	local grab = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(10, 16),
		BackgroundColor3 = T.text,
		BorderSizePixel = 0,
		Parent = track,
	})

	local function paintValue(value)
		local alpha = (value - minValue) / (maxValue - minValue)
		alpha = math.clamp(alpha, 0, 1)
		fill.Size = UDim2.new(alpha, 0, 1, 0)
		grab.Position = UDim2.new(alpha, 0, 0.5, 0)
		valueLabel.Text = formatValue and formatValue(value) or tostring(value)
	end
	paintValue(getValue())

	local dragging = false
	local moveConn
	local function stop()
		dragging = false
		if moveConn then
			moveConn:Disconnect()
			moveConn = nil
		end
	end
	local function applyAt(x)
		local origin = hit.AbsolutePosition.X
		local width = math.max(hit.AbsoluteSize.X, 1)
		local alpha = math.clamp((x - origin) / width, 0, 1)
		local value = minValue + (maxValue - minValue) * alpha
		value = math.floor(value * 100 + 0.5) / 100
		setValue(value)
		paintValue(getValue())
	end
	hit.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		dragging = true
		applyAt(input.Position.X)
		moveConn = UserInputService.InputChanged:Connect(function(changed)
			if not dragging then
				return
			end
			if changed.UserInputType == Enum.UserInputType.MouseMovement or changed.UserInputType == Enum.UserInputType.Touch then
				applyAt(changed.Position.X)
			end
		end)
	end)
	hit.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			stop()
		end
	end)
end

local function makeKeybind(labelText, getValue, setValue)
	local height = rowHeight()
	local row = new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, height),
		Parent = content,
	})
	new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(0.55, 0, 1, 0),
		Font = FONT,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = T.text,
		Text = labelText,
		Parent = row,
	})
	local btn = new("TextButton", {
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.new(0.46, 0, 0, math.max(36, height - 8)),
		BackgroundColor3 = T.inset,
		BorderSizePixel = 0,
		Font = FONT_CODE,
		TextSize = 12,
		TextColor3 = T.text,
		Text = keyName(getValue()),
		Parent = row,
	})
	corner(btn, 2)
	local line = stroke(btn, T.line, 1)
	btn.Activated:Connect(function()
		if listening and listening.button == btn then
			listening = nil
			btn.Text = keyName(getValue())
			tween(line, 0.12, { Color = T.line })
			return
		end
		btn.Text = "PRESS KEY"
		tween(line, 0.12, { Color = T.text })
		listening = {
			button = btn,
			line = line,
			getValue = getValue,
			apply = function(code)
				if code == Enum.KeyCode.Unknown then
					btn.Text = keyName(getValue())
					return
				end
				setValue(code)
				btn.Text = keyName(code)
				notify("Key set to " .. keyName(code))
			end,
		}
	end)
end

local function validName(name)
	return string.match(name, "^[%w_][%w_][%w_]+$") ~= nil and #name <= 16
end

local function validEmail(email)
	return string.match(email, "^[^@%s]+@[^@%s]+%.[^@%s]+$") ~= nil
end

local layoutBody
local renderCurrent
local showAuth
local showGate
local showApp
local place

local function setMinimized(on)
	minimized = on
	animToken = animToken + 1
	local token = animToken
	if on then
		local function hide()
			if token ~= animToken then
				return
			end
			shell.Visible = false
			dock.Visible = true
		end
		local play = tween(uiScale, 0.16, { Scale = targetScale() * 0.96 })
		if play then
			task.spawn(function()
				play.Completed:Wait()
				hide()
			end)
		else
			hide()
		end
	else
		dock.Visible = false
		shell.Visible = true
		if settings.motion then
			uiScale.Scale = targetScale() * 0.96
			tween(uiScale, 0.18, { Scale = targetScale() })
		else
			uiScale.Scale = targetScale()
		end
	end
end

local function renderMenuRows()
	section("Display")
	makeToggle("Motion", function()
		return settings.motion
	end, function(on)
		settings.motion = on
		notify(on and "Motion on" or "Motion off")
	end)
	makeSlider("Opacity", 0.72, 1, function()
		return settings.opacity
	end, function(value)
		settings.opacity = value
		applyChrome()
	end, function(value)
		return string.format("%d%%", math.floor(value * 100 + 0.5))
	end)
	makeSlider("Scale", 0.9, 1.15, function()
		return settings.scale
	end, function(value)
		settings.scale = value
		applyChrome()
	end, function(value)
		return string.format("%d%%", math.floor(value * 100 + 0.5))
	end)
	makeSlider("Speed", 0.75, 1.5, function()
		return settings.animSpeed
	end, function(value)
		settings.animSpeed = value
	end, function(value)
		return string.format("%.2fx", value)
	end)
	makeDropdown("Density", { "Comfort", "Dense" }, function()
		return settings.density
	end, function(option)
		settings.density = option
		if view == "app" then
			showApp()
		end
		notify("Density " .. option)
	end)
	hint("Density changes row height on desktop. Mobile stays at a touch size.")

	if #customRows > 0 then
		section("Custom")
		for _, row in ipairs(customRows) do
			if row.kind == "toggle" then
				makeToggle(row.text, function()
					return row.value
				end, function(value)
					row.value = value
					if row.callback then
						local ok, err = pcall(row.callback, value)
						if not ok then
							warn("[Axiom] " .. tostring(err))
							notify("ERR  Action failed")
						end
					end
				end)
			elseif row.kind == "slider" then
				makeSlider(row.text, row.min, row.max, function()
					return row.value
				end, function(value)
					row.value = value
					if row.callback then
						local ok, err = pcall(row.callback, value)
						if not ok then
							warn("[Axiom] " .. tostring(err))
							notify("ERR  Action failed")
						end
					end
				end, function(value)
					return string.format("%.2f", value)
				end)
			elseif row.kind == "input" then
				fieldLabel(row.text)
				local box = inputBox(row.text, false)
				box.set(row.value or "")
				box.root.FocusLost:Connect(function()
					row.value = box.get()
					if row.callback then
						local ok, err = pcall(row.callback, row.value)
						if not ok then
							warn("[Axiom] " .. tostring(err))
							notify("ERR  Action failed")
						end
					end
				end)
			elseif row.kind == "button" then
				actionButton(row.text, "ghost", function()
					if row.callback then
						local ok, err = pcall(row.callback)
						if not ok then
							warn("[Axiom] " .. tostring(err))
							notify("ERR  Action failed")
						end
					end
				end)
			end
		end
	end
end

local commands

local function renderInput()
	section("Fields")
	fieldLabel("Call sign")
	local call = inputBox("Name shown in this session", false)
	call.set(settings.callsign)
	call.root.FocusLost:Connect(function()
		settings.callsign = call.get()
	end)
	fieldLabel("Index")
	local indexBox = inputBox("01", false)
	indexBox.set(settings.indexValue)
	indexBox.root.FocusLost:Connect(function()
		local text = indexBox.get()
		if string.match(text, "^%d+$") then
			settings.indexValue = text
			showError(nil)
		else
			showError("Index needs digits only")
		end
	end)
	fieldLabel("Notes")
	local notes = new("TextBox", {
		BackgroundColor3 = T.inset,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 96),
		Font = FONT,
		TextSize = 14,
		TextColor3 = T.text,
		PlaceholderText = "Session notes. Stored in memory only.",
		PlaceholderColor3 = T.mute,
		Text = settings.notes,
		ClearTextOnFocus = false,
		MultiLine = true,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = content,
	})
	corner(notes, 2)
	stroke(notes, T.line, 1)
	new("UIPadding", {
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
		Parent = notes,
	})
	notes.FocusLost:Connect(function()
		settings.notes = notes.Text
	end)

	section("Commands")
	fieldLabel("Find")
	local search = inputBox("Type to filter", false)
	local listHolder = new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = content,
	})
	new("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = listHolder,
	})

	local function paintCommands()
		for _, child in ipairs(listHolder:GetChildren()) do
			if child:IsA("UIListLayout") then
				continue
			end
			child:Destroy()
		end
		local query = string.lower(search.get())
		local shown = 0
		for _, command in ipairs(commands) do
			if query == "" or string.find(string.lower(command.name), query, 1, true) then
				shown = shown + 1
				local btn = new("TextButton", {
					AutoButtonColor = false,
					BackgroundColor3 = T.bg,
					BorderSizePixel = 0,
					Size = UDim2.new(1, 0, 0, rowHeight()),
					Font = FONT,
					TextSize = 14,
					TextColor3 = T.text,
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = "  " .. command.name,
					LayoutOrder = shown,
					Parent = listHolder,
				})
				corner(btn, 2)
				stroke(btn, T.lineSoft, 1)
				btn.Activated:Connect(command.run)
			end
		end
		if shown == 0 then
			new("TextLabel", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 24),
				Font = FONT,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = T.dim,
				Text = "No matching command",
				Parent = listHolder,
			})
		end
	end
	search.root:GetPropertyChangedSignal("Text"):Connect(paintCommands)
	paintCommands()
end

local function renderKeys()
	section("Shortcuts")
	hint("Right Shift shows and hides the window. Click a key, then press a new one. Escape cancels.")
	makeKeybind("Show and hide", function()
		return settings.menuKey
	end, function(code)
		settings.menuKey = code
		setSection(appTab, keyName(settings.menuKey))
	end)
	hint("The dock button does the same thing on touch screens, where a keyboard may be absent.")
end

local function renderHome()
	section("Status")
	cardRow({
		{ "License", session.licensed and "ACTIVE" or "LOCKED", "Local demonstration seat" },
		{ "Price", PRICE, "Label on this interface" },
	})
	cardRow({
		{ "Session", session.user or "NONE", session.email or "No email stored" },
		{ "Motion", settings.motion and "ON" or "OFF", "Window and control transitions" },
	})
	hint("AXIOM is a client menu. Account data and the license flag live in this script session only. Closing the dock ends the UI.")
	actionButton("Minimize", "ghost", function()
		setMinimized(true)
	end)
end

local function renderUser()
	section("Account")
	cardRow({
		{ "User", session.user or "NONE", "Signed in on this client" },
		{ "License", session.licensed and "ACTIVE" or "LOCKED", DEMO_KEY },
	})
	fieldLabel("Call sign")
	local call = inputBox("Optional display name", false)
	call.set(settings.callsign)
	call.root.FocusLost:Connect(function()
		settings.callsign = call.get()
	end)
	actionButton("Sign out", "ghost", function()
		session.user = nil
		session.email = nil
		notify("Signed out")
		showAuth()
	end)
	actionButton("Lock license", "ghost", function()
		session.licensed = false
		notify("License locked")
		showGate()
	end)
end

local function renderAppPage()
	clearContent()
	layoutBody(true)
	setSection(appTab, keyName(settings.menuKey))
	if appTab == "Home" then
		renderHome()
	elseif appTab == "Menu" then
		renderMenuRows()
	elseif appTab == "Input" then
		renderInput()
	elseif appTab == "Keys" then
		renderKeys()
	else
		renderUser()
	end
	for _, child in ipairs(rail:GetChildren()) do
		if child:IsA("TextButton") then
			local selected = child.Name == appTab
			child.BackgroundColor3 = selected and T.text or T.bg
			local caption = child:FindFirstChild("Caption")
			if caption then
				caption.TextColor3 = selected and T.ink or T.dim
			end
			local icon = child:FindFirstChild("Icon")
			if icon then
				paint(icon, selected and T.ink or T.text)
			end
		end
	end
end

function showApp()
	if not session.user then
		showAuth()
		return
	end
	if not session.licensed then
		showGate()
		return
	end
	view = "app"
	closeDropdown()
	renderAppPage()
end

function showGate()
	view = "gate"
	closeDropdown()
	clearContent()
	layoutBody(false)
	setSection("Redeem", "License")
	section("License")
	hint("The price label is " .. PRICE .. ". This seat unlocks with the local demonstration key. It does not take payment.")
	fieldLabel("Key")
	local keyBox = inputBox("AXIO-0000-0000-0000", false)
	keyBox.root.Font = FONT_CODE
	showError(nil)
	actionButton("Use demonstration key", "ghost", function()
		keyBox.set(DEMO_KEY)
		showError(nil)
	end)
	actionButton("Redeem", "primary", function()
		local key = string.upper(string.gsub(keyBox.get(), "%s+", ""))
		if key == DEMO_KEY then
			session.licensed = true
			notify("Key accepted")
			if session.user then
				showApp()
			else
				showError(nil)
				notify("Sign in to open the menu")
				authTab = "login"
				showAuth()
			end
		else
			showError("Key not recognized")
		end
	end)
	actionButton("Back to sign in", "ghost", function()
		session.user = nil
		showAuth()
	end)
end

function showAuth()
	view = "auth"
	closeDropdown()
	clearContent()
	layoutBody(false)
	local titles = {
		login = { "Sign in", "Session" },
		register = { "Register", "New session" },
		redeem = { "Redeem", "License" },
	}
	local meta = titles[authTab] or titles.login
	setSection(meta[1], meta[2])

	local tabs = new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 40),
		Parent = content,
	})
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		Parent = tabs,
	})
	local function tabButton(id, label)
		local selected = authTab == id
		local btn = new("TextButton", {
			AutoButtonColor = false,
			BackgroundColor3 = selected and T.text or T.bg,
			BorderSizePixel = 0,
			Size = UDim2.new(1 / 3, -4, 1, 0),
			Font = FONT_MED,
			TextSize = 13,
			TextColor3 = selected and T.ink or T.dim,
			Text = label,
			Parent = tabs,
		})
		corner(btn, 2)
		if not selected then
			stroke(btn, T.line, 1)
		end
		btn.Activated:Connect(function()
			authTab = id
			showAuth()
		end)
	end
	tabButton("login", "Login")
	tabButton("register", "Register")
	tabButton("redeem", "Redeem")

	if authTab == "login" then
		section("Credentials")
		fieldLabel("Username")
		local userBox = inputBox("At least 3 characters", false)
		fieldLabel("Password")
		local passBox = inputBox("At least 4 characters", true)
		showError(nil)
		actionButton("Sign in", "primary", function()
			local user = userBox.get()
			local pass = passBox.get()
			local record = accounts[string.lower(user)]
			if not validName(user) then
				showError("Username needs 3 to 16 letters, numbers, or underscores")
				return
			end
			if not record or record.password ~= pass then
				showError("No session matches that username and password")
				return
			end
			session.user = record.user
			session.email = record.email
			notify("Signed in")
			if session.licensed then
				showApp()
			else
				showGate()
			end
		end)
		hint("Register on this client first. The account exists only until you close AXIOM.")
	elseif authTab == "register" then
		section("Create")
		fieldLabel("Username")
		local userBox = inputBox("letter and numbers", false)
		fieldLabel("Email")
		local emailBox = inputBox("name@place.com", false)
		fieldLabel("Password")
		local passBox = inputBox("At least 4 characters", true)
		fieldLabel("Confirm password")
		local confirmBox = inputBox("Repeat password", true)
		showError(nil)
		actionButton("Create account", "primary", function()
			local user = userBox.get()
			local email = emailBox.get()
			local pass = passBox.get()
			local confirm = confirmBox.get()
			if not validName(user) then
				showError("Username needs 3 to 16 letters, numbers, or underscores")
				return
			end
			if accounts[string.lower(user)] then
				showError("That username is already in this session")
				return
			end
			if not validEmail(email) then
				showError("Email needs a name, @, and a domain")
				return
			end
			if #pass < 4 then
				showError("Password needs at least 4 characters")
				return
			end
			if pass ~= confirm then
				showError("Passwords do not match")
				return
			end
			accounts[string.lower(user)] = {
				user = user,
				email = email,
				password = pass,
			}
			session.user = user
			session.email = email
			notify("Account created")
			if session.licensed then
				showApp()
			else
				showGate()
			end
		end)
	else
		section("Key")
		hint("Demonstration key: " .. DEMO_KEY .. ". Redeem stays on this client.")
		fieldLabel("Key")
		local keyBox = inputBox("AXIO-0000-0000-0000", false)
		keyBox.root.Font = FONT_CODE
		showError(nil)
		actionButton("Use demonstration key", "ghost", function()
			keyBox.set(DEMO_KEY)
		end)
		actionButton("Redeem", "primary", function()
			local key = string.upper(string.gsub(keyBox.get(), "%s+", ""))
			if key ~= DEMO_KEY then
				showError("Key not recognized")
				return
			end
			session.licensed = true
			notify("Key accepted")
			if session.user then
				showApp()
			else
				showError(nil)
				authTab = "login"
				showAuth()
				notify("Sign in to open the menu")
			end
		end)
	end
end

commands = {
	{
		name = "Minimize window",
		run = function()
			setMinimized(true)
		end,
	},
	{
		name = "Reset layout",
		run = function()
			userMoved = false
			settings.scale = 1
			settings.opacity = 1
			settings.animSpeed = 1
			place()
			applyChrome()
			notify("Layout reset")
		end,
	},
	{
		name = "Turn motion on",
		run = function()
			settings.motion = true
			notify("Motion on")
		end,
	},
	{
		name = "Turn motion off",
		run = function()
			settings.motion = false
			notify("Motion off")
		end,
	},
	{
		name = "Open keys",
		run = function()
			appTab = "Keys"
			showApp()
		end,
	},
	{
		name = "Open menu",
		run = function()
			appTab = "Menu"
			showApp()
		end,
	},
	{
		name = "Sign out",
		run = function()
			session.user = nil
			session.email = nil
			notify("Signed out")
			showAuth()
		end,
	},
}

local function buildRail()
	for _, child in ipairs(rail:GetChildren()) do
		if child:IsA("UIListLayout") or child:IsA("UIPadding") then
			continue
		end
		child:Destroy()
	end
	local tabs = {
		{ "Home", "Home" },
		{ "Menu", "Menu" },
		{ "Input", "Input" },
		{ "Keys", "Keys" },
		{ "User", "User" },
	}
	for _, item in ipairs(tabs) do
		local btn = new("TextButton", {
			Name = item[1],
			AutoButtonColor = false,
			BackgroundColor3 = T.bg,
			BorderSizePixel = 0,
			Size = mobile and UDim2.new(0.2, -6, 1, -10) or UDim2.new(1, -12, 0, 58),
			Text = "",
			Parent = rail,
		})
		corner(btn, 2)
		drawIcon(item[1], btn, T.text)
		local caption = new("TextLabel", {
			Name = "Caption",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -4),
			Size = UDim2.new(1, -4, 0, 14),
			Font = FONT_MED,
			TextSize = 12,
			TextColor3 = T.dim,
			Text = item[2],
			Parent = btn,
		})
		caption.Text = item[2]
		btn.Activated:Connect(function()
			appTab = item[1]
			if view == "app" then
				renderAppPage()
			end
		end)
	end
end

function layoutBody(withRail)
	if withRail then
		rail.Visible = true
		buildRail()
		if mobile then
			rail.Position = UDim2.fromOffset(0, 0)
			rail.Size = UDim2.new(1, 0, 0, 64)
			railLayout.FillDirection = Enum.FillDirection.Horizontal
			railLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
			railLayout.VerticalAlignment = Enum.VerticalAlignment.Center
			canvas.Position = UDim2.fromOffset(0, 64)
			canvas.Size = UDim2.new(1, 0, 1, -64)
		else
			rail.Position = UDim2.fromOffset(0, 0)
			rail.Size = UDim2.new(0, 84, 1, 0)
			railLayout.FillDirection = Enum.FillDirection.Vertical
			railLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
			railLayout.VerticalAlignment = Enum.VerticalAlignment.Top
			canvas.Position = UDim2.fromOffset(84, 0)
			canvas.Size = UDim2.new(1, -84, 1, 0)
		end
		if railRule then
			railRule.Visible = true
			if mobile then
				railRule.Position = UDim2.fromOffset(0, 63)
				railRule.Size = UDim2.new(1, 0, 0, 1)
			else
				railRule.Position = UDim2.fromOffset(84, 0)
				railRule.Size = UDim2.new(0, 1, 1, 0)
			end
		end
	else
		rail.Visible = false
		if railRule then
			railRule.Visible = false
		end
		canvas.Position = UDim2.fromOffset(0, 0)
		canvas.Size = UDim2.fromScale(1, 1)
	end
end

function place()
	local size = viewport()
	local nextMobile = size.X < 760
	local changed = mobile ~= nextMobile
	mobile = nextMobile
	local inset = GuiService:GetGuiInset()
	local maxW = math.max(280, size.X - 16)
	local maxH = math.max(320, size.Y - inset.Y - 16)
	local width = mobile and maxW or math.clamp(maxW, 320, 520)
	local height = mobile and maxH or math.clamp(maxH, 360, 660)
	if not mobile then
		width = math.min(520, maxW)
		height = math.min(660, maxH)
	end
	shell.Size = UDim2.fromOffset(width, height)
	fitScale = 1
	if width * settings.scale > maxW or height * settings.scale > maxH then
		fitScale = math.min(maxW / width, maxH / height)
	end
	applyChrome()
	if not userMoved then
		shell.Position = UDim2.fromOffset(size.X / 2, inset.Y + (size.Y - inset.Y) / 2)
	else
		local halfW = (width * targetScale()) / 2
		local halfH = (height * targetScale()) / 2
		local x = math.clamp(shell.Position.X.Offset, halfW + 8, math.max(halfW + 8, size.X - halfW - 8))
		local y = math.clamp(shell.Position.Y.Offset, inset.Y + halfH + 8, math.max(inset.Y + halfH + 8, size.Y - halfH - 8))
		shell.Position = UDim2.fromOffset(x, y)
	end
	scroll.ScrollBarThickness = mobile and 6 or 4
	dock.Position = UDim2.new(0.5, 0, 1, mobile and -96 or -28)
	if changed and not destroyed then
		renderCurrent()
	end
end

function renderCurrent()
	if view == "app" then
		showApp()
	elseif view == "gate" then
		showGate()
	else
		showAuth()
	end
end

local function build()
	local existing = playerGui:FindFirstChild("AxiomInterface")
	if existing then
		existing:Destroy()
	end

	screen = new("ScreenGui", {
		Name = "AxiomInterface",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 500,
		Parent = playerGui,
	})

	shell = new("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = T.bg,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Active = true,
		Parent = screen,
	})
	corner(shell, 4)
	stroke(shell, T.line, 1)
	uiScale = new("UIScale", { Scale = 1, Parent = shell })

	new("TextButton", {
		Name = "ModalSink",
		Modal = true,
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Text = "",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 0,
		Parent = shell,
	})

	header = new("Frame", {
		Name = "Header",
		BackgroundColor3 = T.raised,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 56),
		ZIndex = 2,
		Active = true,
		Parent = shell,
	})
	local mark = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 16),
		Size = UDim2.fromOffset(16, 16),
		Parent = header,
	})
	drawIcon("Mark", mark, T.text)
	local markHost = mark:FindFirstChild("Icon")
	if markHost then
		markHost.Position = UDim2.fromScale(0.5, 0.5)
	end

	local drag = new("TextButton", {
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Text = "",
		Position = UDim2.fromOffset(36, 0),
		Size = UDim2.new(1, -212, 1, 0),
		Parent = header,
	})
	new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 8),
		Size = UDim2.new(1, 0, 0, 18),
		Font = FONT_BOLD,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = T.text,
		Text = "AXIOM",
		Parent = drag,
	})
	new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 26),
		Size = UDim2.new(1, 0, 0, 14),
		Font = FONT_CODE,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = T.mute,
		Text = "INTERFACE",
		Parent = drag,
	})

	local price = new("TextLabel", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -108, 0.5, 0),
		Size = UDim2.fromOffset(56, 22),
		BackgroundColor3 = T.text,
		Font = FONT_CODE,
		TextSize = 12,
		TextColor3 = T.ink,
		Text = PRICE,
		Parent = header,
	})
	corner(price, 2)

	local function headerIcon(offset, label, callback)
		local btn = new("TextButton", {
			Name = label == "×" and "Close" or "Minimize",
			AutoButtonColor = false,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, offset, 0.5, 0),
			Size = UDim2.fromOffset(44, 44),
			BackgroundColor3 = T.raised,
			BorderSizePixel = 0,
			Font = FONT_MED,
			TextSize = 20,
			TextColor3 = T.text,
			Text = label,
			Parent = header,
		})
		corner(btn, 2)
		btn.MouseEnter:Connect(function()
			tween(btn, 0.12, { BackgroundColor3 = T.hover })
		end)
		btn.MouseLeave:Connect(function()
			tween(btn, 0.12, { BackgroundColor3 = T.raised })
		end)
		btn.Activated:Connect(callback)
		return btn
	end
	headerIcon(-56, "–", function()
		setMinimized(true)
	end)
	headerIcon(-8, "×", function()
		shutdown()
	end)

	sectionBar = new("Frame", {
		BackgroundColor3 = T.bg,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 56),
		Size = UDim2.new(1, 0, 0, 32),
		Parent = shell,
	})
	new("Frame", {
		BackgroundColor3 = T.lineSoft,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 1),
		Parent = sectionBar,
	})
	new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = T.lineSoft,
		BorderSizePixel = 0,
		Parent = sectionBar,
	})
	sectionTitle = new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(0.6, 0, 1, 0),
		Font = FONT_CODE,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = T.text,
		Text = "SIGN IN",
		Parent = sectionBar,
	})
	sectionHint = new("TextLabel", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 0),
		Size = UDim2.new(0.4, 0, 1, 0),
		Font = FONT_CODE,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = T.mute,
		Text = "SESSION",
		Parent = sectionBar,
	})

	body = new("Frame", {
		Name = "Canvas",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 88),
		Size = UDim2.new(1, 0, 1, -114),
		Parent = shell,
	})
	rail = new("Frame", {
		Name = "Shortcuts",
		BackgroundColor3 = T.bg,
		BorderSizePixel = 0,
		Visible = false,
		Parent = body,
	})
	railLayout = new("UIListLayout", {
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = rail,
	})
	new("UIPadding", {
		PaddingTop = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 6),
		Parent = rail,
	})
	railRule = new("Frame", {
		Name = "RailRule",
		Visible = false,
		BackgroundColor3 = T.lineSoft,
		BorderSizePixel = 0,
		Parent = body,
	})

	canvas = new("Frame", {
		Name = "Page",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = body,
	})
	scroll = new("ScrollingFrame", {
		Name = "Scroll",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = T.dim,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = canvas,
	})
	pcall(function()
		scroll.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
	end)
	content = new("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = scroll,
	})
	new("UIListLayout", {
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = content,
	})
	new("UIPadding", {
		PaddingTop = UDim.new(0, 12),
		PaddingBottom = UDim.new(0, 18),
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
		Parent = content,
	})
	local footer = new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundColor3 = T.bg,
		BorderSizePixel = 0,
		Parent = shell,
	})
	new("Frame", {
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = T.lineSoft,
		BorderSizePixel = 0,
		Parent = footer,
	})
	footerLabel = new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -24, 1, 0),
		Font = FONT_CODE,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = T.mute,
		Text = "AXIOM   LOCAL   " .. PRICE .. "   – HIDES   × CLOSES",
		Parent = footer,
	})

	toast = new("TextLabel", {
		Visible = false,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 8, 1, -32),
		Size = UDim2.new(1, -16, 0, 28),
		BackgroundColor3 = T.text,
		Font = FONT_MED,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = T.ink,
		Text = "",
		ZIndex = 6,
		Parent = shell,
	})
	corner(toast, 2)

	dock = new("Frame", {
		Name = "Dock",
		Visible = false,
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromOffset(176, 48),
		BackgroundColor3 = T.bg,
		BorderSizePixel = 0,
		Active = true,
		Parent = screen,
	})
	corner(dock, 2)
	stroke(dock, T.text, 1)
	local dockMark = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 16),
		Size = UDim2.fromOffset(16, 16),
		Parent = dock,
	})
	drawIcon("Mark", dockMark, T.text)
	local dockIcon = dockMark:FindFirstChild("Icon")
	if dockIcon then
		dockIcon.Position = UDim2.fromScale(0.5, 0.5)
	end
	new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(36, 0),
		Size = UDim2.new(1, -64, 1, 0),
		Font = FONT_BOLD,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = T.text,
		Text = "AXIOM",
		Parent = dock,
	})
	local restore = new("TextButton", {
		Name = "Restore",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Text = "",
		Size = UDim2.new(1, -48, 1, 0),
		Parent = dock,
	})
	local dockClose = new("TextButton", {
		Name = "Close",
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -2, 0.5, 0),
		Size = UDim2.fromOffset(44, 44),
		BackgroundTransparency = 1,
		Font = FONT_MED,
		TextSize = 18,
		TextColor3 = T.dim,
		Text = "×",
		Parent = dock,
	})
	restore.Activated:Connect(function()
		setMinimized(false)
	end)
	dockClose.Activated:Connect(function()
		shutdown()
	end)

	local dragStart
	local startPos
	local dragMove
	local function stopDrag()
		if dragMove then
			dragMove:Disconnect()
			dragMove = nil
		end
	end
	drag.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		userMoved = true
		dragStart = input.Position
		startPos = shell.Position
		stopDrag()
		dragMove = UserInputService.InputChanged:Connect(function(changed)
			if changed.UserInputType ~= Enum.UserInputType.MouseMovement and changed.UserInputType ~= Enum.UserInputType.Touch then
				return
			end
			local delta = changed.Position - dragStart
			shell.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end)
	end)
	drag.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			stopDrag()
			place()
		end
	end)

	track(UserInputService.InputBegan:Connect(function(input, processed)
		if destroyed then
			return
		end
		if listening and input.UserInputType == Enum.UserInputType.Keyboard then
			local bind = listening
			listening = nil
			if bind.line then
				tween(bind.line, 0.12, { Color = T.line })
			end
			if input.KeyCode == Enum.KeyCode.Escape then
				if bind.button and bind.getValue then
					bind.button.Text = keyName(bind.getValue())
				end
				return
			end
			bind.apply(input.KeyCode)
			return
		end
		if UserInputService:GetFocusedTextBox() then
			return
		end
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Escape then
			if dropdownCloser then
				closeDropdown()
				return
			end
			setMinimized(not minimized)
			return
		end
		if input.KeyCode == settings.menuKey then
			setMinimized(not minimized)
		end
	end))

	local camera = workspace.CurrentCamera
	if camera then
		track(camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			if not destroyed then
				place()
			end
		end))
	end
	track(workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		local nextCamera = workspace.CurrentCamera
		if nextCamera then
			track(nextCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
				if not destroyed then
					place()
				end
			end))
		end
		place()
	end))

	place()
	showAuth()
	if settings.motion then
		uiScale.Scale = targetScale() * 0.96
		tween(uiScale, 0.2, { Scale = targetScale() })
	end
	notify("Right Shift shows and hides the window")
end

local function previousApi()
	if typeof(getgenv) == "function" then
		local ok, env = pcall(getgenv)
		if ok and type(env) == "table" then
			return env
		end
	end
	return _G
end

do
	local env = previousApi()
	local old = env.Axiom
	if type(old) == "table" and type(old.destroy) == "function" then
		pcall(old.destroy)
	end
end

local api = {
	notify = notify,
	destroy = shutdown,
}

function api.addToggle(text, default, callback)
	table.insert(customRows, {
		kind = "toggle",
		text = tostring(text or "Toggle"),
		value = default and true or false,
		callback = callback,
		custom = true,
	})
	if view == "app" and appTab == "Menu" then
		renderAppPage()
	end
end

function api.addSlider(text, minValue, maxValue, default, callback)
	table.insert(customRows, {
		kind = "slider",
		text = tostring(text or "Slider"),
		min = tonumber(minValue) or 0,
		max = tonumber(maxValue) or 1,
		value = tonumber(default) or 0,
		callback = callback,
		custom = true,
	})
	if view == "app" and appTab == "Menu" then
		renderAppPage()
	end
end

function api.addInput(text, default, callback)
	table.insert(customRows, {
		kind = "input",
		text = tostring(text or "Input"),
		value = tostring(default or ""),
		callback = callback,
		custom = true,
	})
	if view == "app" and appTab == "Menu" then
		renderAppPage()
	end
end

function api.addButton(text, callback)
	table.insert(customRows, {
		kind = "button",
		text = tostring(text or "Button"),
		callback = callback,
		custom = true,
	})
	if view == "app" and appTab == "Menu" then
		renderAppPage()
	end
end

build()
previousApi().Axiom = api
