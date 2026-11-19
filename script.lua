local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local player = Players.LocalPlayer
local channel = TextChatService:WaitForChild("TextChannels"):WaitForChild("RBXGeneral")

-- قفل نافذة الشات الأصلية فقط
local win = TextChatService:FindFirstChildOfClass("ChatWindowConfiguration")
if win then win.Enabled = false end

local gui = Instance.new("ScreenGui")
gui.Name = "ServerChatGui"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local toggle = Instance.new("TextButton")
toggle.Size = UDim2.fromOffset(44, 44)
toggle.Position = UDim2.fromOffset(20, 20)
toggle.BackgroundColor3 = Color3.fromRGB(60, 140, 220)
toggle.Text = "💬"
toggle.TextSize = 22
toggle.TextColor3 = Color3.new(1, 1, 1)
toggle.Parent = gui
Instance.new("UICorner", toggle)

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(340, 320)
frame.Position = UDim2.fromOffset(20, 74)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
frame.Active = true
frame.Draggable = true
frame.Parent = gui
Instance.new("UICorner", frame)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -50, 0, 32)
title.Position = UDim2.fromOffset(10, 0)
title.BackgroundTransparency = 1
title.Text = "شات السيرفر"
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local close = Instance.new("TextButton")
close.Size = UDim2.fromOffset(28, 24)
close.Position = UDim2.new(1, -34, 0, 4)
close.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
close.Text = "X"
close.TextColor3 = Color3.new(1, 1, 1)
close.Font = Enum.Font.GothamBold
close.Parent = frame
Instance.new("UICorner", close)

local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -20, 1, -84)
scroll.Position = UDim2.fromOffset(10, 36)
scroll.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 4
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.CanvasSize = UDim2.new()
scroll.Parent = frame

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 4)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = scroll

local pad = Instance.new("UIPadding")
pad.PaddingLeft = UDim.new(0, 6)
pad.PaddingRight = UDim.new(0, 6)
pad.PaddingTop = UDim.new(0, 4)
pad.Parent = scroll

local box = Instance.new("TextBox")
box.Size = UDim2.new(1, -80, 0, 30)
box.Position = UDim2.new(0, 10, 1, -38)
box.BackgroundColor3 = Color3.fromRGB(45, 45, 52)
box.TextColor3 = Color3.new(1, 1, 1)
box.PlaceholderText = "اكتب رسالة..."
box.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
box.ClearTextOnFocus = false
box.Font = Enum.Font.GothamMedium
box.TextSize = 15
box.Parent = frame
Instance.new("UICorner", box)

local send = Instance.new("TextButton")
send.Size = UDim2.fromOffset(60, 30)
send.Position = UDim2.new(1, -70, 1, -38)
send.BackgroundColor3 = Color3.fromRGB(60, 140, 220)
send.Text = "إرسال"
send.TextColor3 = Color3.new(1, 1, 1)
send.Font = Enum.Font.GothamBold
send.Parent = frame
Instance.new("UICorner", send)

local function esc(s)
	return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

local order = 0
local shown = {} -- يمنع تكرار نفس الرسالة

local function addLine(name, text)
	order += 1
	local l = Instance.new("TextLabel")
	l.LayoutOrder = order
	l.Size = UDim2.new(1, 0, 0, 0)
	l.AutomaticSize = Enum.AutomaticSize.Y
	l.BackgroundTransparency = 1
	l.TextWrapped = true
	l.RichText = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextColor3 = Color3.new(1, 1, 1)
	l.Font = Enum.Font.GothamMedium
	l.TextSize = 16
	l.Text = '<font color="#6CB4FF"><b>' .. esc(name) .. '</b></font>: ' .. esc(text)
	l.Parent = scroll
	scroll.CanvasPosition = Vector2.new(0, 99999)
end

local function addMessage(message)
	if message.MessageId and shown[message.MessageId] then return end
	if message.MessageId then shown[message.MessageId] = true end

	local name = "النظام"
	local src = message.TextSource
	if src then
		local p = Players:GetPlayerByUserId(src.UserId)
		name = p and p.DisplayName or src.Name
	end
	addLine(name, message.Text)
end

-- الرسائل القادمة من السيرفر
channel.MessageReceived:Connect(addMessage)

-- الإرسال
local function submit()
	local text = box.Text
	if not text:match("%S") then return end
	box.Text = ""
	text = text:sub(1, 200)

	local ok, result = pcall(function()
		return channel:SendAsync(text)
	end)

	if not ok then
		warn("فشل الإرسال:", result)
		addLine("النظام", "تعذر إرسال الرسالة")
	elseif typeof(result) == "Instance" then
		addMessage(result) -- رسالتك تظهر عندك (مفلترة)
	end
end

send.MouseButton1Click:Connect(submit)
box.FocusLost:Connect(function(enter)
	if enter then submit() end
end)

toggle.MouseButton1Click:Connect(function() frame.Visible = not frame.Visible end)
close.MouseButton1Click:Connect(function() frame.Visible = false end)
