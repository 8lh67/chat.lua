local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")
local RunService = game:GetService("RunService")

local MessagingService = RunService:IsServer() and game:GetService("MessagingService") or nil
local TextService = RunService:IsServer() and game:GetService("TextService") or nil
local HttpService = game:GetService("HttpService")

-- إعدادات الربط بين الألعاب (اتركها فاضية لو ما تبي)
local API_URL = "" -- مثال: "https://your-worker.workers.dev"
local API_KEY = ""
local POLL_EVERY = 3
local TOPIC = "GlobalChat"

-- إخفاء واجهة الشات الافتراضية
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)
end)
pcall(function()
	local win = TextChatService:FindFirstChildOfClass("ChatWindowConfiguration")
	if win then win.Enabled = false end
	local bar = TextChatService:FindFirstChildOfClass("ChatInputBarConfiguration")
	if bar then bar.Enabled = false end
end)

local function esc(s)
	return (tostring(s):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

-- جزء السيرفر (يعمل تلقائياً إذا كان السكربت يعمل على السيرفر)
if RunService:IsServer() then
	local remote = RS:FindFirstChild("ServerChat") or Instance.new("RemoteEvent")
	remote.Name = "ServerChat"
	remote.Parent = RS

	local last = {}
	local lastId = 0
	local myOrigin = tostring(game.GameId) .. ":" .. tostring(game.JobId)

	remote.OnServerEvent:Connect(function(player, msg)
		if typeof(msg) ~= "string" then return end
		msg = msg:sub(1, 200)
		if not msg:match("%S") then return end

		local now = os.clock()
		if last[player] and now - last[player] < 1 then return end
		last[player] = now

		local filtered = msg
		if TextService then
			local ok, res = pcall(function()
				return TextService:FilterStringAsync(msg, player.UserId)
					:GetNonChatStringForBroadcastAsync()
			end)
			if not ok or not res then return end
			filtered = res
		end

		remote:FireAllClients(player.DisplayName, filtered)

		if MessagingService then
			pcall(function()
				MessagingService:PublishAsync(TOPIC, {
					name = player.DisplayName,
					text = filtered,
					job = game.JobId,
				})
			end)
		end

		if API_URL ~= "" then
			task.spawn(function()
				pcall(function()
					HttpService:PostAsync(
						API_URL .. "/send",
						HttpService:JSONEncode({
							name = player.DisplayName,
							text = filtered,
							origin = myOrigin,
						}),
						Enum.HttpContentType.ApplicationJson,
						false,
						{ ["x-api-key"] = API_KEY }
					)
				end)
			end)
		end
	end)

	if MessagingService then
		pcall(function()
			MessagingService:SubscribeAsync(TOPIC, function(packet)
				local d = packet.Data
				if typeof(d) ~= "table" or d.job == game.JobId then return end
				if typeof(d.name) == "string" and typeof(d.text) == "string" then
					remote:FireAllClients(d.name, d.text)
				end
			end)
		end)
	end

	if API_URL ~= "" then
		task.spawn(function()
			while true do
				task.wait(POLL_EVERY)
				local ok, res = pcall(function()
					return HttpService:GetAsync(
						API_URL .. "/poll?after=" .. tostring(lastId),
						false,
						{ ["x-api-key"] = API_KEY }
					)
				end)
				if ok and res then
					local ok2, data = pcall(function()
						return HttpService:JSONDecode(res)
					end)
					if ok2 and typeof(data) == "table" and typeof(data.messages) == "table" then
						for _, m in ipairs(data.messages) do
							lastId = math.max(lastId, tonumber(m.id) or lastId)
							if m.origin ~= myOrigin
								and typeof(m.name) == "string"
								and typeof(m.text) == "string" then
								remote:FireAllClients(m.name, m.text)
							end
						end
					end
				end
			end
		end)
	end

	Players.PlayerRemoving:Connect(function(p)
		last[p] = nil
	end)
end

-- جزء العميل والواجهة
local localPlayer = Players.LocalPlayer
if not localPlayer then return end

local remote = RS:WaitForChild("ServerChat", 10)
local guiParent = localPlayer:WaitForChild("PlayerGui")

local gui = Instance.new("ScreenGui")
gui.Name = "ServerChatGui"
gui.ResetOnSpawn = false
gui.Parent = guiParent

local function make(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	o.Parent = parent
	return o
end

local toggle = make("TextButton", {
	Size = UDim2.fromOffset(44, 44), Position = UDim2.fromOffset(20, 20),
	BackgroundColor3 = Color3.fromRGB(60, 140, 220),
	Text = "💬", TextSize = 22, TextColor3 = Color3.new(1, 1, 1),
}, gui)
Instance.new("UICorner", toggle)

local frame = make("Frame", {
	Size = UDim2.fromOffset(340, 320), Position = UDim2.fromOffset(20, 74),
	BackgroundColor3 = Color3.fromRGB(30, 30, 35), Active = true, Draggable = true,
}, gui)
Instance.new("UICorner", frame)

make("TextLabel", {
	Size = UDim2.new(1, -50, 0, 32), Position = UDim2.fromOffset(10, 0),
	BackgroundTransparency = 1, Text = "شات السيرفر",
	TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold,
	TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left,
}, frame)

local close = make("TextButton", {
	Size = UDim2.fromOffset(28, 24), Position = UDim2.new(1, -34, 0, 4),
	BackgroundColor3 = Color3.fromRGB(200, 60, 60), Text = "X",
	TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold,
}, frame)
Instance.new("UICorner", close)

local scroll = make("ScrollingFrame", {
	Size = UDim2.new(1, -20, 1, -84), Position = UDim2.fromOffset(10, 36),
	BackgroundColor3 = Color3.fromRGB(15, 15, 18), BorderSizePixel = 0,
	ScrollBarThickness = 4, AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
}, frame)
make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, scroll)
make("UIPadding", {
	PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 4),
}, scroll)

local box = make("TextBox", {
	Size = UDim2.new(1, -80, 0, 30), Position = UDim2.new(0, 10, 1, -38),
	BackgroundColor3 = Color3.fromRGB(45, 45, 52), TextColor3 = Color3.new(1, 1, 1),
	PlaceholderText = "اكتب رسالة...", PlaceholderColor3 = Color3.fromRGB(150, 150, 150),
	ClearTextOnFocus = false, Font = Enum.Font.GothamMedium, TextSize = 15,
}, frame)
Instance.new("UICorner", box)

local send = make("TextButton", {
	Size = UDim2.fromOffset(60, 30), Position = UDim2.new(1, -70, 1, -38),
	BackgroundColor3 = Color3.fromRGB(60, 140, 220), Text = "إرسال",
	TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold,
}, frame)
Instance.new("UICorner", send)

local order = 0
local function addLine(name, msg)
	order += 1
	make("TextLabel", {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1, TextWrapped = true, RichText = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.GothamMedium, TextSize = 16,
		Text = '<font color="#6CB4FF"><b>' .. esc(name) .. '</b></font>: ' .. esc(msg),
	}, scroll)
	scroll.CanvasPosition = Vector2.new(0, 99999)
end

local function submit()
	local txt = box.Text
	if not txt:match("%S") then return end
	txt = txt:sub(1, 200)
	if remote then
		remote:FireServer(txt)
	else
		addLine(localPlayer.DisplayName, txt)
	end
	box.Text = ""
end

send.MouseButton1Click:Connect(submit)
box.FocusLost:Connect(function(enter)
	if enter then submit() end
end)

if remote then
	remote.OnClientEvent:Connect(function(name, msg)
		addLine(name, msg)
	end)
end

toggle.MouseButton1Click:Connect(function()
	frame.Visible = not frame.Visible
end)
close.MouseButton1Click:Connect(function()
	frame.Visible = false
end)

