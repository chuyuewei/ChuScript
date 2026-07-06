--[[
  Module: ChuScript
  Description: 微服务编排入口与公共 API 网关。
  Version: 1.0.0
]]

local ServiceContainer = require(script.Core.ServiceContainer)
local MessageBus = require(script.Core.MessageBus)
local LoggerService = require(script.Services.LoggerService)
local ConfigService = require(script.Services.ConfigService)
local CommandService = require(script.Services.CommandService)
local NotificationService = require(script.Services.NotificationService)
local UIService = require(script.Services.UIService)
local PluginService = require(script.Services.PluginService)
local PlayerService = require(script.Services.PlayerService)
local UtilityService = require(script.Services.UtilityService)
local CommandLoaderService = require(script.Services.CommandLoaderService) -- [新增] 引入加载服务

local ChuScript = {}
ChuScript.__index = ChuScript

function ChuScript.new()
  local self = setmetatable({}, ChuScript)

  self._container = ServiceContainer.new()
  self._bus = MessageBus.new()

  -- 注册基础设施
  self._container:register("MessageBus", function() return self._bus end)

  -- 注册核心服务
  self._container:register("LoggerService", function(bus) return LoggerService.new(bus) end, {"MessageBus"})
  self._container:register("ConfigService", function(bus) return ConfigService.new(bus) end, {"MessageBus"})
  self._container:register("PlayerService", function() return PlayerService.new() end, {})
  self._container:register("UtilityService", function() return UtilityService.new() end, {})
  self._container:register("CommandService", function(bus, config, logger)
    return CommandService.new(bus, config, logger)
  end, {"MessageBus", "ConfigService", "LoggerService"})
  self._container:register("NotificationService", function(bus, logger)
    return NotificationService.new(bus, logger)
  end, {"MessageBus", "LoggerService"})
  self._container:register("UIService", function(bus, config, logger, commands)
    return UIService.new(bus, config, logger, commands)
  end, {"MessageBus", "ConfigService", "LoggerService", "CommandService"})
  self._container:register("PluginService", function(bus, logger, config, commands, notifications)
    return PluginService.new(bus, logger, config, commands, notifications)
  end, {"MessageBus", "LoggerService", "ConfigService", "CommandService", "NotificationService"})
  
  -- [新增] 注册命令加载服务
  self._container:register("CommandLoaderService", function(logger)
    return CommandLoaderService.new(logger)
  end, {"LoggerService"})

  -- 解析服务
  self.logger = self._container:resolve("LoggerService")
  self.config = self._container:resolve("ConfigService")
  self.players = self._container:resolve("PlayerService")
  self.utility = self._container:resolve("UtilityService")
  self.commands = self._container:resolve("CommandService")
  self.notifications = self._container:resolve("NotificationService")
  self.ui = self._container:resolve("UIService")
  self.plugins = self._container:resolve("PluginService")
  self.loader = self._container:resolve("CommandLoaderService") -- [新增]
  self.events = self._bus

  self.logger:info("ChuScript Microservices Initialized")

  -- [修改] 自动扫描并加载 Commands 目录下的模块
  local commandsFolder = script:FindFirstChild("Commands")
  if commandsFolder then
    self.loader:loadDirectory(self, commandsFolder)
  else
    self.logger:warn("Commands folder not found. Skipping built-in commands.")
  end

  -- 加载外部插件
  self.plugins:LoadAll()

  -- [保留] 配置测试命令 (也可以移到 Commands/Config.lua 中)
  self.commands:register("setprefix", {"changeprefix"}, "修改命令前缀并保存", function(args)
    local newPrefix = args[1]
    if not newPrefix or #newPrefix ~= 1 then
      return false, "Prefix must be a single character (e.g., !, ;, /)"
    end
    self.config:set("prefix", newPrefix)
    return true, string.format("Prefix changed to '%s' and saved.", newPrefix)
  end)

  return self
end


--- 公共 API：注册命令
function ChuScript:registerCommand(name, aliases, description, handler)
  self.commands:register(name, aliases, description, handler)
end

--- 公共 API：执行输入
function ChuScript:execute(input)
  return self.commands:execute(input)
end

--- 公共 API：获取建议
function ChuScript:getSuggestions(partial)
  return self.commands:getSuggestions(partial)
end

--- 公共 API：修改配置
function ChuScript:setConfig(key, value)
  self.config:set(key, value)
end

--- 公共 API：读取配置
function ChuScript:getConfig(key)
  return self.config:get(key)
end

return ChuScript