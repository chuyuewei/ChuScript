--!strict
--[[
  Module: ChuScript
  Description: 微服务编排入口与公共 API。
]]

local ServiceContainer = require(script.Core.ServiceContainer)
local MessageBus = require(script.Core.MessageBus)
local LoggerService = require(script.Services.LoggerService)
local ConfigService = require(script.Services.ConfigService)
local PlayerService = require(script.Services.PlayerService)
local UtilityService = require(script.Services.UtilityService)
local CommandService = require(script.Services.CommandService)
local NotificationService = require(script.Services.NotificationService)
local UIService = require(script.Services.UIService)
local PluginService = require(script.Services.PluginService)
local CommandLoaderService = require(script.Services.CommandLoaderService)

local ChuScript = {}
ChuScript.__index = ChuScript

function ChuScript.new()
	local self = setmetatable({}, ChuScript)

	self._container = ServiceContainer.new()
	self._bus = MessageBus.new()

	-- 基础设施
	self._container:register("MessageBus", function() return self._bus end)

	-- 核心服务
	self._container:register("LoggerService", function(bus) return LoggerService.new(bus) end, { "MessageBus" })
	self._container:register("ConfigService", function(bus, logger)
		return ConfigService.new(bus, logger)
	end, { "MessageBus", "LoggerService" })
	self._container:register("PlayerService", function() return PlayerService.new() end, {})
	self._container:register("UtilityService", function() return UtilityService.new() end, {})
	self._container:register("CommandService", function(bus, config, logger)
		return CommandService.new(bus, config, logger)
	end, { "MessageBus", "ConfigService", "LoggerService" })
	self._container:register("NotificationService", function(bus, logger)
		return NotificationService.new(bus, logger)
	end, { "MessageBus", "LoggerService" })
	self._container:register("UIService", function(bus, config, logger, commands)
		return UIService.new(bus, config, logger, commands)
	end, { "MessageBus", "ConfigService", "LoggerService", "CommandService" })
	self._container:register("PluginService", function(bus, logger, config, commands, notifs)
		return PluginService.new(bus, logger, config, commands, notifs)
	end, { "MessageBus", "LoggerService", "ConfigService", "CommandService", "NotificationService" })
	self._container:register("CommandLoaderService", function(logger)
		return CommandLoaderService.new(logger)
	end, { "LoggerService" })

	-- 解析为公开属性
	self.logger          = self._container:resolve("LoggerService")
	self.config          = self._container:resolve("ConfigService")
	self.players         = self._container:resolve("PlayerService")
	self.utility         = self._container:resolve("UtilityService")
	self.commands        = self._container:resolve("CommandService")
	self.notifications   = self._container:resolve("NotificationService")
	self.ui              = self._container:resolve("UIService")
	self.plugins         = self._container:resolve("PluginService")
	self.loader          = self._container:resolve("CommandLoaderService")
	self.events          = self._bus

	self.logger:info("ChuScript Microservices Initialized")

	-- 扫描 Commands 目录
	local commandsFolder = script:FindFirstChild("Commands")
	if commandsFolder ~= nil then
		self.loader:loadDirectory(self, commandsFolder)
	else
		self.logger:warn("Commands folder not found. Skipping built-in commands.")
	end

	-- 加载外部插件
	self.plugins:LoadAll()

	-- 内置:修改前缀
	self.commands:register(
		"setprefix",
		{ "changeprefix" },
		"修改命令前缀并保存",
		function(args)
			local newPrefix = args[1]
			if type(newPrefix) ~= "string" or #newPrefix ~= 1 or string.match(newPrefix, "%s") then
				return false, "Prefix must be a single non-space character."
			end
			self.config:set("prefix", newPrefix)
			return true, ("Prefix changed to '%s' and saved."):format(newPrefix)
		end
	)

	-- 关闭钩子:游戏退出时刷盘并安全释放服务(本进程内的客户端执行器不需要这些,
	-- 这里保留以让用户在脚本里手动调用 cs:flush())
	return self
end

-- 公共 API ----------------------------------------------------------

function ChuScript:registerCommand(name: string, aliases: { string }?, description: string?, handler: any)
	return self.commands:register(name, aliases, description, handler)
end

function ChuScript:execute(input: string)
	return self.commands:execute(input)
end

function ChuScript:getSuggestions(partial: string?, maxResults: number?)
	return self.commands:getSuggestions(partial, maxResults)
end

function ChuScript:setConfig(key: string, value: any)
	self.config:set(key, value)
end

function ChuScript:getConfig(key: string)
	return self.config:get(key)
end

function ChuScript:flush()
	self.config:flush()
end

return table.freeze(ChuScript)
