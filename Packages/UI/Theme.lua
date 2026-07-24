--!strict
--[[
  Module: Theme
  Description: ChuScript UI 主题常量。
]]

local Theme = table.freeze({
	Background     = Color3.fromRGB(30, 30, 30),
	BackgroundLight = Color3.fromRGB(45, 45, 45),
	Accent         = Color3.fromRGB(0, 162, 255),
	Success        = Color3.fromRGB(85, 255, 127),
	Text           = Color3.fromRGB(255, 255, 255),
	SubText        = Color3.fromRGB(150, 150, 150),
	Error          = Color3.fromRGB(255, 75, 75),
	WarnAccent     = Color3.fromRGB(255, 200, 0),

	Font           = Enum.Font.Code,
	FontSize       = 14,
	HeaderSize     = 18,

	CornerRadius   = UDim.new(0, 6),
	Padding        = UDim.new(0, 8),
})

return Theme
