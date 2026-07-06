--[[
  Module: AutoComplete
  Description: 命令自动补全下拉框 UI 组件。
]]

local Theme = require(script.Parent.Theme)

local AutoComplete = {}
AutoComplete.__index = AutoComplete

--- 创建自动补全实例。
-- @param parent Instance 父级容器 (通常挂载在 Console 下方)
-- @return AutoComplete
function AutoComplete.new(parent)
  local self = setmetatable({}, AutoComplete)
  self._currentItems = {}
  self._selectedIndex = 0

  self.Frame = Instance.new("Frame")
  self.Frame.Name = "AutoCompleteDropdown"
  self.Frame.Size = UDim2.new(1, 0, 0, 100)
  self.Frame.Position = UDim2.new(0, 0, 0, 0) -- 由 Console 调整位置至正上方
  self.Frame.AnchorPoint = Vector2.new(0, 1)
  self.Frame.BackgroundColor3 = Theme.Background
  self.Frame.Visible = false
  self.Frame.ZIndex = 2 -- 确保在控制台之上
  self.Frame.Parent = parent

  local corner = Instance.new("UICorner")
  corner.CornerRadius = Theme.CornerRadius
  corner.Parent = self.Frame

  local layout = Instance.new("UIListLayout")
  layout.SortOrder = Enum.SortOrder.LayoutOrder
  layout.Padding = UDim.new(0, 2)
  layout.Parent = self.Frame

  -- 自动调整容器高度
  self.Frame.AutomaticSize = Enum.AutomaticSize.Y
  
  return self
end

--- 更新下拉框显示的建议列表。
-- @param suggestions table CommandService 返回的建议数组 { {command=cmd, score=score}, ... }
-- @param inputText string 当前用户输入的文本 (用于高亮匹配，暂略)
function AutoComplete:Update(suggestions)
  -- 清空旧元素
  for _, child in ipairs(self.Frame:GetChildren()) do
    if child:IsA("TextButton") then
      child:Destroy()
    end
  end
  
  self._currentItems = suggestions
  self._selectedIndex = 0

  if #suggestions == 0 then
    self.Frame.Visible = false
    return
  end

  for i, sug in ipairs(suggestions) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 30)
    btn.BackgroundColor3 = Theme.BackgroundLight
    btn.Text = ""
    btn.LayoutOrder = i
    btn.ZIndex = 2
    btn.Parent = self.Frame

    local corner = Instance.new("UICorner")
    corner.CornerRadius = Theme.CornerRadius
    corner.Parent = btn

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -10, 1, 0)
    lbl.Position = UDim2.new(0, 5, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Font = Theme.Font
    lbl.TextSize = Theme.FontSize
    lbl.TextColor3 = Theme.Text
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    -- 显示命令名和别名
    local aliasStr = #sug.command.aliases > 0 and string.format(" (%s)", table.concat(sug.command.aliases, ", ")) or ""
    lbl.Text = sug.command.name .. aliasStr
    lbl.Parent = btn

    -- 鼠标悬停高亮
    btn.MouseEnter:Connect(function()
      self:_highlight(i)
    end)
  end

  self.Frame.Visible = true
  self:_highlight(1) -- 默认高亮第一项
end

--- 隐藏下拉框。
function AutoComplete:Hide()
  self.Frame.Visible = false
  self._currentItems = {}
  self._selectedIndex = 0
end

--- 是否当前处于可见状态。
function AutoComplete:IsVisible()
  return self.Frame.Visible
end

--- 内部高亮逻辑。
function AutoComplete:_highlight(index)
  if #self._currentItems == 0 then return end
  
  -- 移除旧高亮
  for i, child in ipairs(self.Frame:GetChildren()) do
    if child:IsA("TextButton") then
      child.BackgroundColor3 = Theme.BackgroundLight
    end
  end

  self._selectedIndex = index
  local btn = self.Frame:GetChildren()[index]
  if btn and btn:IsA("TextButton") then
    btn.BackgroundColor3 = Theme.Accent
  end
end

--- 获取当前高亮项的命令对象。
-- @return table|nil
function AutoComplete:GetSelectedCommand()
  if self._selectedIndex > 0 and self._currentItems[self._selectedIndex] then
    return self._currentItems[self._selectedIndex].command
  end
  return nil
end

--- 移动高亮选择 (用于上下方向键导航)。
-- @param direction number 1 为下移, -1 为上移
function AutoComplete:MoveSelection(direction)
  if #self._currentItems == 0 then return end
  
  local newIndex = self._selectedIndex + direction
  if newIndex < 1 then newIndex = #self._currentItems end
  if newIndex > #self._currentItems then newIndex = 1 end
  
  self:_highlight(newIndex)
end

return AutoComplete