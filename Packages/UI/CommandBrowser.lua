--!strict
--[[
  Module: CommandBrowser
  Description: 命令浏览面板,带动画显隐。
]]

local TweenService = game:GetService("TweenService")
local Theme = require(script.Parent.Theme)

local CommandBrowser = {}
CommandBrowser.__index = CommandBrowser

local SHOW_TWEEN = TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local HIDE_TWEEN = TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.In)

function CommandBrowser.new(parent: Instance)
	local self = setmetatable({}, CommandBrowser)
	self._entries = {} :: { TextButton }

	self.Frame = Instance.new("Frame")
	self.Frame.Name = "CommandBrowser"
	self.Frame.Size = UDim2.new(0, 350, 0, 400)
	self.Frame.Position = UDim2.new(1, 360, 1, -50) -- 初始在屏幕外,动画进入
	self.Frame.AnchorPoint = Vector2.new(1, 1)
	self.Frame.BackgroundColor3 = Theme.Background
	self.Frame.BorderSizePixel = 0
	self.Frame.Visible = true
	self.Frame.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.CornerRadius
	corner.Parent = self.Frame

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
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = self.ScrollFrame

	self._isOpen = false
	self.Frame.Visible = false
	return self
end

function CommandBrowser:Toggle()
	if self._isOpen then
		self._isOpen = false
		local t = TweenService:Create(self.Frame, HIDE_TWEEN, {
			Position = UDim2.new(1, 360, 1, -50),
		})
		t:Play()
		t.Completed:Once(function()
			if not self._isOpen and self.Frame then
				self.Frame.Visible = false
			end
		end)
	else
		self._isOpen = true
		self.Frame.Visible = true
		TweenService:Create(self.Frame, SHOW_TWEEN, {
			Position = UDim2.new(1, 0, 1, -50),
		}):Play()
	end
end

-- 关闭
function CommandBrowser:Close()
	if self._isOpen then self:Toggle() end
end

function CommandBrowser:AddCommand(cmdData: any, onClick: (any) -> ())
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, -10, 0, 45)
	btn.BackgroundColor3 = Theme.BackgroundLight
	btn.Text = ""
	btn.LayoutOrder = #self._entries + 1
	btn.AutoButtonColor = true
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
	nameLbl.Text = (function()
		if cmdData.aliases and #cmdData.aliases > 0 then
			return ("%s (%s)"):format(cmdData.name, table.concat(cmdData.aliases, ", "))
		end
		return cmdData.name
	end)()
	nameLbl.Parent = btn

	local descLbl = Instance.new("TextLabel")
	descLbl.Size = UDim2.new(1, -10, 0, 15)
	descLbl.Position = UDim2.new(0, 5, 0, 25)
	descLbl.BackgroundTransparency = 1
	descLbl.Font = Theme.Font
	descLbl.TextSize = 12
	descLbl.TextColor3 = Theme.SubText
	descLbl.TextXAlignment = Enum.TextXAlignment.Left
	descLbl.Text = cmdData.description or ""
	descLbl.Parent = btn

	btn.MouseButton1Click:Connect(function()
		onClick(cmdData)
	end)
	table.insert(self._entries, btn)
end

function CommandBrowser:Clear()
	for _, btn in ipairs(self._entries) do
		if btn and btn.Parent then btn:Destroy() end
	end
	table.clear(self._entries)
end

return table.freeze(CommandBrowser)
