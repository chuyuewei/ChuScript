--[[
  Module: Notification
  Description: 右侧滑出通知 UI 组件。负责动画与生命周期管理。
]]

local TweenService = game:GetService("TweenService")
local Theme = require(script.Parent.Theme)

local Notification = {}
Notification.__index = Notification

-- 动画参数
local kSlideInTween = TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local kSlideOutTween = TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.In)

--- 创建通知系统实例并生成右侧容器。
-- @param parent Instance 父级 GUI 容器
-- @return Notification
function Notification.new(parent)
  local self = setmetatable({}, Notification)
  
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

  self._orderCounter = 0
  return self
end

--- 推送一条新通知。
-- @param title string 标题
-- @param message string 内容
-- @param duration number 持续时间 (秒)
-- @param notifType string "Info", "Success", "Warn", "Error"
function Notification:Push(title, message, duration, notifType)
  duration = duration or 3
  notifType = notifType or "Info"

  local accentColor = Theme.Accent
  if notifType == "Success" then accentColor = Theme.Success
  elseif notifType == "Warn" then accentColor = Color3.fromRGB(255, 200, 0)
  elseif notifType == "Error" then accentColor = Theme.Error end

  self._orderCounter += 1

  -- 通知主体
  local frame = Instance.new("Frame")
  frame.Name = "Notif_" .. notifType
  frame.Size = UDim2.new(1, 0, 0, 60) -- 初始高度，可由内容撑开
  frame.AutomaticSize = Enum.AutomaticSize.Y
  frame.BackgroundColor3 = Theme.Background
  frame.BorderSizePixel = 0
  frame.LayoutOrder = self._orderCounter
  -- 初始状态在屏幕外
  frame.Position = UDim2.new(1, 50, 0, 0)
  frame.Parent = self._container

  local corner = Instance.new("UICorner")
  corner.CornerRadius = Theme.CornerRadius
  corner.Parent = frame

  -- 左侧强调色条
  local accentBar = Instance.new("Frame")
  accentBar.Name = "AccentBar"
  accentBar.Size = UDim2.new(0, 4, 1, 0)
  accentBar.BackgroundColor3 = accentColor
  accentBar.BorderSizePixel = 0
  accentBar.Parent = frame

  local accentCorner = Instance.new("UICorner")
  accentCorner.CornerRadius = UDim.new(0, 2)
  accentCorner.Parent = accentBar

  -- 标题
  local titleLbl = Instance.new("TextLabel")
  titleLbl.Size = UDim2.new(1, -24, 0, 20)
  titleLbl.Position = UDim2.new(0, 12, 0, 8)
  titleLbl.BackgroundTransparency = 1
  titleLbl.Font = Theme.Font
  titleLbl.TextSize = Theme.FontSize
  titleLbl.TextColor3 = accentColor
  titleLbl.TextXAlignment = Enum.TextXAlignment.Left
  titleLbl.Text = string.upper(notifType) .. ": " .. title
  titleLbl.Parent = frame

  -- 内容
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

  -- 滑入动画
  local slideIn = TweenService:Create(frame, kSlideInTween, { Position = UDim2.new(0, 0, 0, 0) })
  slideIn:Play()

  -- 计时与滑出销毁
  task.delay(duration, function()
    local slideOut = TweenService:Create(frame, kSlideOutTween, { Position = UDim2.new(1, 50, 0, 0) })
    slideOut:Play()
    slideOut.Completed:Connect(function()
      frame:Destroy()
    end)
  end)
end

return Notification