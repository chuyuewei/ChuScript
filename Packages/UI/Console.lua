--!strict
--[[
  Module: Console
  Description: 主控制台:单向垂直条,right-control / Enter 提交。
]]

local Theme = require(script.Parent.Theme)
local AutoComplete = require(script.Parent.AutoComplete)

local Console = {}
Console.__index = Console

function Console.new(parent: Instance)
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

	self.PrefixLabel = Instance.new("TextLabel")
	self.PrefixLabel.Name = "Prefix"
	self.PrefixLabel.Size = UDim2.new(0, 20, 1, 0)
	self.PrefixLabel.Position = UDim2.new(0, 10, 0, 0)
	self.PrefixLabel.BackgroundTransparency = 1
	self.PrefixLabel.Font = Theme.Font
	self.PrefixLabel.TextSize = Theme.FontSize
	self.PrefixLabel.TextColor3 = Theme.Success
	self.PrefixLabel.TextXAlignment = Enum.TextXAlignment.Left
	self.PrefixLabel.Text = ":"
	self.PrefixLabel.Parent = self.Frame

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

	self.MenuButton = Instance.new("TextButton")
	self.MenuButton.Name = "MenuToggle"
	self.MenuButton.Size = UDim2.new(0, 30, 0, 30)
	self.MenuButton.Position = UDim2.new(1, -35, 0.5, -15)
	self.MenuButton.BackgroundColor3 = Theme.BackgroundLight
	self.MenuButton.Text = ">"
	self.MenuButton.Font = Theme.Font
	self.MenuButton.TextSize = Theme.FontSize
	self.MenuButton.TextColor3 = Theme.Accent
	self.MenuButton.AutoButtonColor = true
	self.MenuButton.Parent = self.Frame

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = Theme.CornerRadius
	btnCorner.Parent = self.MenuButton

	self.AutoComplete = AutoComplete.new(self.Frame)
	self.AutoComplete.Frame.Position = UDim2.new(0, 0, 0, -5)

	return self
end

function Console:SetPrefix(text: string)
	self.PrefixLabel.Text = text
end

function Console:OnSubmit(callback: (string) -> ())
	self.TextBox.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			local value = self.TextBox.Text
			callback(value)
			self.TextBox.Text = ""
		end
	end)
end

function Console:OnMenuToggle(callback: () -> ())
	self.MenuButton.MouseButton1Click:Connect(callback)
end

return table.freeze(Console)
