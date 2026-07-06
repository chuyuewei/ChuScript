--[[
  Module: UIService
  Description: UI 业务编排服务。
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent.Parent.Packages.UI.Theme)
local Console = require(script.Parent.Parent.Packages.UI.Console)
local CommandBrowser = require(script.Parent.Parent.Packages.UI.CommandBrowser)

local UIService = {}
UIService.__index = UIService

function UIService.new(messageBus, configService, loggerService, commandService)
  local self = setmetatable({}, UIService)
  self._bus = messageBus
  self._config = configService
  self._logger = loggerService
  self._commands = commandService

  self._playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
  
  self:_buildGui()
  self:_bindEvents()
  self:_loadExistingCommands()

  self._logger:info("UIService initialized")
  return self
end

function UIService:_buildGui()
  self._screenGui = Instance.new("ScreenGui")
  self._screenGui.Name = "ChuScriptUI"
  self._screenGui.ResetOnSpawn = false
  self._screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
  self._screenGui.Parent = self._playerGui

  self._console = Console.new(self._screenGui)
  self._console:SetPrefix(self._config:get("prefix"))
  self._browser = CommandBrowser.new(self._screenGui)
end

function UIService:_bindEvents()
  local textBox = self._console.TextBox
  local autoComplete = self._console.AutoComplete

  -- 1. 控制台提交命令
  self._console:OnSubmit(function(inputText)
    if inputText == "" then return end
    autoComplete:Hide()
    self._commands:execute(inputText)
  end)

  -- 2. 切换命令浏览器
  self._console:OnMenuToggle(function()
    self._browser:Toggle()
  end)

  -- 3. [新增] 监听输入框文本变化，实时获取建议
  textBox:GetPropertyChangedSignal("Text"):Connect(function()
    local text = textBox.Text
    local prefix = self._config:get("prefix")
    
    -- 如果不以正确前缀开头，或者包含空格(说明已在输入参数)，则隐藏补全
    if string.sub(text, 1, #prefix) ~= prefix or string.find(text, " ", 1, true) then
      autoComplete:Hide()
      return
    end

    -- 提取命令部分 (去掉前缀)
    local partialCmd = string.sub(text, #prefix + 1)
    if partialCmd == "" then
      autoComplete:Hide()
      return
    end

    -- 请求 CommandService 获取建议
    local suggestions = self._commands:getSuggestions(partialCmd, 5)
    autoComplete:Update(suggestions)
  end)

  -- 4. [新增] 监听按键操作 (Tab 补全, 上下导航)
  UserInputService.InputBegan:Connect(function(input, gameProcessed)
    -- 只有在输入框聚焦且补全框可见时处理这些按键
    if not textBox:IsFocused() or not autoComplete:IsVisible() then 
      -- 处理右Ctrl聚焦
      if not gameProcessed and input.KeyCode == Enum.KeyCode.RightControl then
        textBox:CaptureFocus()
      end
      return 
    end

    -- Tab 键补全
    if input.KeyCode == Enum.KeyCode.Tab then
      local selectedCmd = autoComplete:GetSelectedCommand()
      if selectedCmd then
        -- 补全命令并加一个空格，方便用户继续输入参数
        textBox.Text = self._config:get("prefix") .. selectedCmd.name .. " "
        -- 将光标移到最后
        textBox.CursorPosition = #textBox.Text + 1
        autoComplete:Hide()
      end
    -- 上方向键
    elseif input.KeyCode == Enum.KeyCode.Up then
      autoComplete:MoveSelection(-1)
    -- 下方向键
    elseif input.KeyCode == Enum.KeyCode.Down then
      autoComplete:MoveSelection(1)
    end
  end)

  -- 5. 监听配置变更
  self._bus:subscribe("ConfigChanged", function(data)
    if data.key == "prefix" then
      self._console:SetPrefix(data.newValue)
    end
  end)

  -- 6. 监听新命令注册事件
  self._bus:subscribe("CommandRegistered", function(data)
    self._browser:AddCommand(data.command, function(cmdData)
      local prefix = self._config:get("prefix")
      self._console.TextBox.Text = prefix .. cmdData.name .. " "
      self._browser:Toggle()
      self._console.TextBox:CaptureFocus()
    end)
  end)
end

function UIService:_loadExistingCommands()
  for _, cmd in pairs(self._commands._commands) do
    self._browser:AddCommand(cmd, function(cmdData)
      local prefix = self._config:get("prefix")
      self._console.TextBox.Text = prefix .. cmdData.name .. " "
      self._browser:Toggle()
      self._console.TextBox:CaptureFocus()
    end)
  end
end

return UIService