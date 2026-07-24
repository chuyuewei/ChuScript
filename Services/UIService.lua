--!strict
--[[
  Module: UIService
  Description: UI 整合:Console + AutoComplete + CommandBrowser + 键盘绑定。
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent.Parent.Packages.UI.Theme)
local Console = require(script.Parent.Parent.Packages.UI.Console)
local CommandBrowser = require(script.Parent.Parent.Packages.UI.CommandBrowser)

local MessageBus = require(script.Parent.Core.MessageBus)
local ConfigService = require(script.Parent.Services.ConfigService)
local LoggerService = require(script.Parent.Services.LoggerService)
local CommandService = require(script.Parent.Services.CommandService)

local UIService = {}
UIService.__index = UIService

function UIService.new(
	messageBus: MessageBus.MessageBus,
	configService: ConfigService.ConfigService,
	loggerService: LoggerService.LoggerService,
	commandService: CommandService.CommandService,
)
	assert(messageBus and configService and loggerService and commandService, "Missing deps")

	local self = setmetatable({}, UIService)
	self._bus = messageBus
	self._config = configService
	self._logger = loggerService
	self._commands = commandService
	self._bindings = {} :: { [string]: number }

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	self._playerGui = playerGui

	self:_buildGui()
	self:_bindEvents()

	self._logger:info("UIService initialized")
	return self
end

function UIService:_buildGui()
	self._screenGui = Instance.new("ScreenGui")
	self._screenGui.Name = "ChuScriptUI"
	self._screenGui.ResetOnSpawn = false
	self._screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	self._screenGui.IgnoreGuiInset = true
	self._screenGui.Parent = self._playerGui

	self._console = Console.new(self._screenGui)
	self._console:SetPrefix(self._config:get("prefix") or ":")
	self._browser = CommandBrowser.new(self._screenGui)
end

function UIService:_bindEvents()
	local console = self._console
	local browser = self._browser
	local autoComplete = console.AutoComplete
	local textBox = console.TextBox

	console:OnSubmit(function(inputText)
		if type(inputText) ~= "string" or inputText == "" then return end
		autoComplete:Hide()
		self._commands:execute(inputText)
	end)

	console:OnMenuToggle(function()
		browser:Toggle()
	end)

	-- 输入框变化:节流后请求建议
	local lastRequestId = 0
	textBox:GetPropertyChangedSignal("Text"):Connect(function()
		local id = (lastRequestId :: number) + 1
		lastRequestId = id
		-- 微延迟合并连续按键
		task.delay(0.03, function()
			if id ~= lastRequestId then return end
			local text = textBox.Text
			local prefix = self._config:get("prefix") or ":"
			if #text < #prefix
				or string.sub(text, 1, #prefix) ~= prefix
				or string.find(text, " ", 1, true) then
				autoComplete:Hide()
				return
			end
			local partial = string.sub(text, #prefix + 1)
			if partial == "" then
				autoComplete:Hide()
				return
			end
			local suggestions = self._commands:getSuggestions(partial, 5)
			autoComplete:Update(suggestions)
		end)
	end)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not textBox:IsFocused() then
			-- 用 RightControl 拉起控制台(无游戏内占用)
			if not gameProcessed and input.KeyCode == Enum.KeyCode.RightControl then
				textBox:CaptureFocus()
			end
			return
		end

		if not autoComplete:IsVisible() then return end

		if input.KeyCode == Enum.KeyCode.Tab then
			local selected = autoComplete:GetSelectedCommand()
			if selected then
				local prefix2 = self._config:get("prefix") or ":"
				textBox.Text = prefix2 .. selected.name .. " "
				textBox.CursorPosition = #textBox.Text + 1
				autoComplete:Hide()
			end
		elseif input.KeyCode == Enum.KeyCode.Up then
			autoComplete:MoveSelection(-1)
		elseif input.KeyCode == Enum.KeyCode.Down then
			autoComplete:MoveSelection(1)
		end
	end)

	-- 配置变化广播
	self._bindings.config = self._bus:subscribe("ConfigChanged", function(data)
		if type(data) == "table" and data.key == "prefix" then
			console:SetPrefix(tostring(data.newValue))
		end
	end)

	-- 命令注册广播
	self._bindings.cmdReg = self._bus:subscribe("CommandRegistered", function(data)
		if type(data) ~= "table" or type(data.command) ~= "table" then return end
		self:_addBrowserEntry(data.command :: any)
	end)

	-- 初次显示已注册命令
	for _, cmd in ipairs(self._commands:getCommands()) do
		self:_addBrowserEntry(cmd)
	end
end

function UIService:_addBrowserEntry(cmd)
	self._browser:AddCommand(cmd, function(cmdData)
		local prefix = self._config:get("prefix") or ":"
		self._console.TextBox.Text = prefix .. cmdData.name .. " "
		self._browser:Toggle()
		self._console.TextBox:CaptureFocus()
	end)
end

function UIService:destroy()
	for _, token in pairs(self._bindings) do
		self._bus:unsubscribe(token)
	end
	if self._screenGui and self._screenGui.Parent then
		self._screenGui:Destroy()
	end
end

return table.freeze(UIService)
