--[[
  Module: Console
  Description: 主控制台 UI 组件。仅负责视图渲染与基础输入事件触发。
]]

local Theme = require(script.Parent.Theme)
local AutoComplete = require(script.Parent.AutoComplete)

local Console = {}
Console.__index = Console

--- 创建控制台实例。
-- @param parent Instance 父级 GUI 容器
-- @return Console
function Console.new(parent)
  local self = setmetatable({}, Console)
  
  self.Frame = Instance.new("Frame")
  self.Frame.Name = "MainConsole"
  self.Frame.Size = UDim2.new(0.5, 0, 0, 40)
  self.Frame.Position = UDim2.new(0.5, 0, 1, -50)
  self.Frame.AnchorPoint = Vector2.new(0.5, 1)
  self.Frame.BackgroundColor3 = Theme.Background
  self.Frame.BorderSizePixel = 0
  self.Frame.Parent = parent

  local corner = Instance.new("UICorner")
  corner.CornerRadius = Theme.CornerRadius
  corner.Parent = self.Frame

  -- 前缀标签
  self.PrefixLabel = Instance.new("TextLabel")
  self.PrefixLabel.Name = "Prefix"
  self.PrefixLabel.Size = UDim2.new(0, 20, 1, 0)
  self.PrefixLabel.Position = UDim2.new(0, 10, 0, 0)
  self.PrefixLabel.BackgroundTransparency = 1
  self.PrefixLabel.Font = Theme.Font
  self.PrefixLabel.TextSize = Theme.FontSize
  self.PrefixLabel.TextColor3 = Theme.Success
  self.PrefixLabel.TextXAlignment = Enum.TextXAlignment.Left
  self.PrefixLabel.Text = ";"
  self.PrefixLabel.Parent = self.Frame

  -- 输入框
  self.TextBox = Instance.new("TextBox")
  self.TextBox.Name = "Input"
  self.TextBox.Size = UDim2.new(1, -80, 1, 0)
  self.TextBox.Position = UDim2.new(0, 35, 0, 0)
  self.TextBox.BackgroundTransparency = 1
  self.TextBox.Font = Theme.Font
  self.TextBox.TextSize = Theme.FontSize
  self.TextBox.TextColor3 = Theme.Text
  self.TextBox.PlaceholderText = "Enter command..."
  self.TextBox.PlaceholderColor3 = Theme.SubText
  self.TextBox.TextXAlignment = Enum.TextXAlignment.Left
  self.TextBox.ClearTextOnFocus = false
  self.TextBox.Parent = self.Frame

  -- 菜单按钮 (打开命令浏览器)
  self.MenuButton = Instance.new("TextButton")
  self.MenuButton.Name = "MenuToggle"
  self.MenuButton.Size = UDim2.new(0, 30, 0, 30)
  self.MenuButton.Position = UDim2.new(1, -35, 0.5, -15)
  self.MenuButton.BackgroundColor3 = Theme.BackgroundLight
  self.MenuButton.Text = ">"
  self.MenuButton.Font = Theme.Font
  self.MenuButton.TextSize = Theme.FontSize
  self.MenuButton.TextColor3 = Theme.Accent
  self.MenuButton.Parent = self.Frame

  local btnCorner = Instance.new("UICorner")
  btnCorner.CornerRadius = Theme.CornerRadius
  btnCorner.Parent = self.MenuButton

  self.AutoComplete = AutoComplete.new(self.Frame)
  -- 由于 AnchorPoint 设为 (0,1)，Position Y设为0，它刚好贴在 Console Frame 的正上方
  self.AutoComplete.Frame.Position = UDim2.new(0, 0, 0, -5) 

  return self
end

--- 设置前缀文本。
function Console:SetPrefix(text)
  self.PrefixLabel.Text = text
end

--- 绑定回车提交事件。
function Console:OnSubmit(callback)
  self.TextBox.FocusLost:Connect(function(enterPressed)
    if enterPressed then
      callback(self.TextBox.Text)
      self.TextBox.Text = ""
    end
  end)
end

--- 绑定菜单按钮点击事件。
function Console:OnMenuToggle(callback)
  self.MenuButton.MouseButton1Click:Connect(callback)
end

return Console