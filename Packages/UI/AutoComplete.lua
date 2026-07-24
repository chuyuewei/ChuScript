--!strict
--[[
  Module: AutoComplete
  Description: 建议下拉框。元素复用 + 类型化索引。
]]

local Theme = require(script.Parent.Theme)

local AutoComplete = {}
AutoComplete.__index = AutoComplete

local POOL_SIZE = 8

function AutoComplete.new(parent: Instance)
	local self = setmetatable({}, AutoComplete)
	self._items = {} :: { any }
	self._selectedIndex = 0
	self._pool = {} :: { TextButton }

	self.Frame = Instance.new("Frame")
	self.Frame.Name = "AutoCompleteDropdown"
	self.Frame.Size = UDim2.new(1, 0, 0, 100)
	self.Frame.Position = UDim2.new(0, 0, 0, 0)
	self.Frame.AnchorPoint = Vector2.new(0, 1)
	self.Frame.BackgroundColor3 = Theme.Background
	self.Frame.Visible = false
	self.Frame.ZIndex = 2
	self.Frame.AutomaticSize = Enum.AutomaticSize.Y
	self.Frame.ClipsDescendants = true
	self.Frame.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.CornerRadius
	corner.Parent = self.Frame

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 2)
	layout.Parent = self.Frame

	-- 预先创建按钮池(避免 Update 时反复创建/销毁)
	for i = 1, POOL_SIZE do
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1, 0, 0, 30)
		btn.BackgroundColor3 = Theme.BackgroundLight
		btn.Text = ""
		btn.LayoutOrder = i
		btn.ZIndex = 2
		btn.Visible = false
		btn.Parent = self.Frame

		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = Theme.CornerRadius
		btnCorner.Parent = btn

		local label = Instance.new("TextLabel")
		label.Name = "Label"
		label.Size = UDim2.new(1, -10, 1, 0)
		label.Position = UDim2.new(0, 5, 0, 0)
		label.BackgroundTransparency = 1
		label.Font = Theme.Font
		label.TextSize = Theme.FontSize
		label.TextColor3 = Theme.Text
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.ZIndex = 3
		label.Parent = btn

		self._pool[i] = btn
	end

	return self
end

function AutoComplete:Update(suggestions: { any })
	self._items = suggestions or {}
	self._selectedIndex = 0

	local n = math.min(#suggestions, POOL_SIZE)
	for i = 1, POOL_SIZE do
		local btn = self._pool[i]
		local label = btn:FindFirstChild("Label") :: TextLabel?
		if i <= n then
			local sug = suggestions[i]
			local cmd = sug.command
			local alias = if #cmd.aliases > 0
				(" (%s)"):format(table.concat(cmd.aliases, ", "))
				else ""
			if label then label.Text = cmd.name .. alias end
			btn.Visible = true
			btn.LayoutOrder = i
			btn.BackgroundColor3 = Theme.BackgroundLight
		else
			btn.Visible = false
		end
	end

	if n == 0 then
		self.Frame.Visible = false
		return
	end

	self.Frame.Visible = true
	self:_highlight(1)
end

function AutoComplete:_highlight(index: number)
	if #self._items == 0 then return end
	local n = math.min(#self._items, POOL_SIZE)
	if index < 1 then index = n end
	if index > n then index = 1 end

	for i = 1, POOL_SIZE do
		local btn = self._pool[i]
		if btn.Visible then
			btn.BackgroundColor3 = Theme.BackgroundLight
		end
	end

	self._selectedIndex = index
	local btn = self._pool[index]
	if btn then btn.BackgroundColor3 = Theme.Accent end
end

function AutoComplete:Hide()
	self.Frame.Visible = false
	self._items = {}
	self._selectedIndex = 0
	for _, btn in ipairs(self._pool) do
		btn.Visible = false
	end
end

function AutoComplete:IsVisible(): boolean
	return self.Frame.Visible
end

function AutoComplete:GetSelectedCommand(): any?
	if self._selectedIndex >= 1 and self._items[self._selectedIndex] then
		return self._items[self._selectedIndex].command
	end
	return nil
end

function AutoComplete:MoveSelection(direction: number)
	if #self._items == 0 then return end
	self:_highlight((self._selectedIndex or 0) + direction)
end

return table.freeze(AutoComplete)
