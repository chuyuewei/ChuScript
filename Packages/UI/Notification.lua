--!strict
--[[
  Module: Notification
  Description: 侧边滑出通知。被给定父 ScreenGui,内部维护队列容器。
]]

local TweenService = game:GetService("TweenService")
local Theme = require(script.Parent.Theme)

local Notification = {}
Notification.__index = Notification

local SLIDE_IN  = TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local SLIDE_OUT = TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.In)

local NOTIF_SIZE = 60

local function accentColor(kind: string?): Color3
	if kind == "Success" then return Theme.Success end
	if kind == "Warn"    then return Theme.WarnAccent end
	if kind == "Error"   then return Theme.Error end
	return Theme.Accent
end

function Notification.new(parent: Instance)
	local self = setmetatable({}, Notification)
	self._orderCounter = 0
	self._durations = {} :: { [Frame]: number }

	self._container = Instance.new("Frame")
	self._container.Name = "NotificationContainer"
	self._container.Size = UDim2.new(0, 300, 1, -100)
	self._container.Position = UDim2.new(1, -20, 0, 20)
	self._container.AnchorPoint = Vector2.new(1, 0)
	self._container.BackgroundTransparency = 1
	self._container.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	layout.Parent = self._container

	return self
end

function Notification:Push(title: string, message: string, duration: number?, notifType: string?)
	title = title or ""
	message = message or ""
	duration = if type(duration) == "number" and duration > 0 then duration else 3
	notifType = notifType or "Info"

	self._orderCounter += 1
	local order = self._orderCounter

	local accent = accentColor(notifType)

	local frame = Instance.new("Frame")
	frame.Name = "Notif_" .. notifType
	frame.Size = UDim2.new(1, 0, 0, NOTIF_SIZE)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.BackgroundColor3 = Theme.Background
	frame.BorderSizePixel = 0
	frame.LayoutOrder = order
	frame.Position = UDim2.new(1, 50, 0, 0)
	frame.ClipsDescendants = true
	frame.Parent = self._container

	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.CornerRadius
	corner.Parent = frame

	local accentBar = Instance.new("Frame")
	accentBar.Name = "AccentBar"
	accentBar.Size = UDim2.new(0, 4, 1, 0)
	accentBar.BackgroundColor3 = accent
	accentBar.BorderSizePixel = 0
	accentBar.ZIndex = 2
	accentBar.Parent = frame

	local accentCorner = Instance.new("UICorner")
	accentCorner.CornerRadius = UDim.new(0, 2)
	accentCorner.Parent = accentBar

	local titleLbl = Instance.new("TextLabel")
	titleLbl.Size = UDim2.new(1, -24, 0, 20)
	titleLbl.Position = UDim2.new(0, 12, 0, 8)
	titleLbl.BackgroundTransparency = 1
	titleLbl.Font = Theme.Font
	titleLbl.TextSize = Theme.FontSize
	titleLbl.TextColor3 = accent
	titleLbl.TextXAlignment = Enum.TextXAlignment.Left
	titleLbl.Text = (string.upper(notifType) .. ": " .. title)
	titleLbl.Parent = frame

	local msgLbl = Instance.new("TextLabel")
	msgLbl.Size = UDim2.new(1, -24, 0, 15)
	msgLbl.Position = UDim2.new(0, 12, 0, 28)
	msgLbl.AutomaticSize = Enum.AutomaticSize.Y
	msgLbl.BackgroundTransparency = 1
	msgLbl.Font = Theme.Font
	msgLbl.TextSize = 12
	msgLbl.TextColor3 = Theme.SubText
	msgLbl.TextWrapped = true
	msgLbl.TextXAlignment = Enum.TextXAlignment.Left
	msgLbl.TextYAlignment = Enum.TextYAlignment.Top
	msgLbl.Text = message
	msgLbl.Parent = frame

	-- 滑入
	local tweenIn = TweenService:Create(frame, SLIDE_IN, { Position = UDim2.new(0, 0, 0, 0) })
	tweenIn:Play()

	-- 注册超时销毁
	self._durations[frame] = duration
	task.delay(duration, function()
		-- 运行时可能 container 已销毁
		if not frame.Parent then return end
		local tweenOut = TweenService:Create(frame, SLIDE_OUT, { Position = UDim2.new(1, 50, 0, 0) })
		tweenOut:Play()
		tweenOut.Completed:Once(function()
			if frame.Parent then frame:Destroy() end
			self._durations[frame] = nil
		end)
	end)
end

function Notification:ClearAll()
	for _, child in ipairs(self._container:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end
	table.clear(self._durations)
end

return table.freeze(Notification)
