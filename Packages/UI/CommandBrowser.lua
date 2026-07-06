--[[
  Module: CommandBrowser
  Description: 命令浏览系统 UI 组件。展示所有可用命令及其描述。
]]

local Theme = require(script.Parent.Theme)

local CommandBrowser = {}
CommandBrowser.__index = CommandBrowser

--- 创建命令浏览器实例。
-- @param parent Instance 父级 GUI 容器
-- @return CommandBrowser
function CommandBrowser.new(parent)
  local self = setmetatable({}, CommandBrowser)
  
  self.Frame = Instance.new("Frame")
  self.Frame.Name = "CommandBrowser"
  self.Frame.Size = UDim2.new(0, 350, 0, 400)
  self.Frame.Position = UDim2.new(1, 0, 1, -50) -- 初始在屏幕外右下角
  self.Frame.AnchorPoint = Vector2.new(1, 1)
  self.Frame.BackgroundColor3 = Theme.Background
  self.Frame.Visible = false
  self.Frame.Parent = parent

  local corner = Instance.new("UICorner")
  corner.CornerRadius = Theme.CornerRadius
  corner.Parent = self.Frame

  -- 标题栏
  local header = Instance.new("Frame")
  header.Name = "Header"
  header.Size = UDim2.new(1, 0, 0, 35)
  header.BackgroundTransparency = 1
  header.Parent = self.Frame

  local title = Instance.new("TextLabel")
  title.Size = UDim2.new(1, -20, 1, 0)
  title.Position = UDim2.new(0, 10, 0, 0)
  title.BackgroundTransparency = 1
  title.Text = "Command Browser"
  title.Font = Theme.Font
  title.TextSize = Theme.HeaderSize
  title.TextColor3 = Theme.Accent
  title.TextXAlignment = Enum.TextXAlignment.Left
  title.Parent = header

  -- 命令列表滚动框
  self.ScrollFrame = Instance.new("ScrollingFrame")
  self.ScrollFrame.Size = UDim2.new(1, 0, 1, -40)
  self.ScrollFrame.Position = UDim2.new(0, 0, 0, 40)
  self.ScrollFrame.BackgroundTransparency = 1
  self.ScrollFrame.ScrollBarThickness = 4
  self.ScrollFrame.ScrollBarImageColor3 = Theme.Accent
  self.ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
  self.ScrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
  self.ScrollFrame.Parent = self.Frame

  local layout = Instance.new("UIListLayout")
  layout.Padding = UDim.new(0, 4)
  layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
  layout.Parent = self.ScrollFrame
  
  return self
end

--- 切换面板显示状态。
function CommandBrowser:Toggle()
  self.Frame.Visible = not self.Frame.Visible
  -- 这里可以使用 TweenService 做动画，为了精简先直接切换 Visible
end

--- 向浏览器添加一个命令项。
-- @param cmdData table 命令数据 {name, aliases, description}
-- @param onClick function 点击该命令项时的回调
function CommandBrowser:AddCommand(cmdData, onClick)
  local btn = Instance.new("TextButton")
  btn.Size = UDim2.new(1, -10, 0, 45)
  btn.BackgroundColor3 = Theme.BackgroundLight
  btn.Text = ""
  btn.Parent = self.ScrollFrame

  local corner = Instance.new("UICorner")
  corner.CornerRadius = Theme.CornerRadius
  corner.Parent = btn

  local nameLbl = Instance.new("TextLabel")
  nameLbl.Size = UDim2.new(1, -10, 0, 20)
  nameLbl.Position = UDim2.new(0, 5, 0, 5)
  nameLbl.BackgroundTransparency = 1
  nameLbl.Font = Theme.Font
  nameLbl.TextSize = Theme.FontSize
  nameLbl.TextColor3 = Theme.Text
  nameLbl.TextXAlignment = Enum.TextXAlignment.Left
  nameLbl.Text = string.format("%s %s", cmdData.name, #cmdData.aliases > 0 and "("..table.concat(cmdData.aliases, ", ")..")" or "")
  nameLbl.Parent = btn

  local descLbl = Instance.new("TextLabel")
  descLbl.Size = UDim2.new(1, -10, 0, 15)
  descLbl.Position = UDim2.new(0, 5, 0, 25)
  descLbl.BackgroundTransparency = 1
  descLbl.Font = Theme.Font
  descLbl.TextSize = 12
  descLbl.TextColor3 = Theme.SubText
  descLbl.TextXAlignment = Enum.TextXAlignment.Left
  descLbl.Text = cmdData.description
  descLbl.Parent = btn

  btn.MouseButton1Click:Connect(function()
    onClick(cmdData)
  end)
end

return CommandBrowser