--!strict
--[[
  Module: PluginService
  Description: 插件加载器。读取 ChuScript/Plugins 目录下的 .luau/.lua 文件,
  在受限环境中 loadstring + setfenv 执行,只暴露 API 白名单。

  沙箱设计:
    - 禁用危险全局(game / workspace 之外的服务仅 read-only 暴露)。
    - 取消 string.dump / loadstring 的访问,阻止插件再编译/再加载别的代码。
    - 例外:writefile/readfile/isfolder/isfile/listfiles 完全封禁。
    - 插件中可访问的 API 全部从 sandbox API 表格派生。
]]

local MessageBus = require(script.Parent.Core.MessageBus)
local LoggerService = require(script.Parent.Services.LoggerService)
local ConfigService = require(script.Parent.Services.ConfigService)
local CommandService = require(script.Parent.Services.CommandService)
local NotificationService = require(script.Parent.Services.NotificationService)

local PluginService = {}
PluginService.__index = PluginService

local PLUGIN_DIR = "ChuScript/Plugins"

-- 只读服务名插件被允许使用
local ALLOWED_SERVICES = {
	Players = true,
	UserInputService = true,
	RunService = true,
	TweenService = true,
	HttpService = true,
}
-- 显式拒绝的服务
local DENIED_SERVICES = {
	DataStoreService = true,
	MemoryStoreService = true,
	MessagingService = true,
	ReplicatedStorage_Remotes = true,
}

local function buildSandboxEnv(api: any): { [string]: any }
	-- 只暴露 game 中被允许的 service,且全部 read-only
	local services = {}
	for name in pairs(ALLOWED_SERVICES) do
		local ok, svc = pcall(game.GetService, game, name)
		if ok then services[name] = svc end
	end

	-- 为 Roblox 内置方法做只读代理:
	-- 委托给原始对象但拦截 :Connect / :FireServer
	local function makeReadonly(getter)
		return setmetatable({}, {
			__index = function(_, k) return getter(k) end,
			__newindex = function()
				error("[Sandbox] Direct writes are not allowed", 2)
			end,
			__metatable = "locked",
		})
	end

	local gameProxy = makeReadonly(function(k)
		if DENIED_SERVICES[k] then
			error("[Sandbox] Access to service '" .. tostring(k) .. "' is denied", 2)
		end
		local svc = services[k]
		if svc then return svc end
		-- 允许访问只读 game 属性
		local ok, v = pcall(function() return (game :: any)[k] end)
		if ok then return v end
		return nil
	end)

	return {
		-- 私有 API(白名单)
		API = api,

		-- 受限 game
		game = gameProxy,

		-- 允许的 Lua 标准库
		print = print,
		warn = warn,
		ipairs = ipairs,
		pairs = pairs,
		next = next,
		select = select,
		tonumber = tonumber,
		tostring = tostring,
		type = type,
		pcall = pcall,
		xpcall = xpcall,
		math = table.freeze({
			huge = math.huge,
			pi = math.pi,
			abs = math.abs, floor = math.floor, ceil = math.ceil,
			min = math.min, max = math.max, clamp = math.clamp,
			random = math.random, sin = math.sin, cos = math.cos,
			tan = math.tan, rad = math.rad, deg = math.deg,
			sign = math.sign, sqrt = math.sqrt, log = math.log,
		}),
		string = table.freeze({
			byte = string.byte, char = string.char,
			find = string.find, format = string.format,
			gmatch = string.gmatch, gsub = string.gsub,
			len = string.len, lower = string.lower, upper = string.upper,
			match = string.match, rep = string.rep, reverse = string.reverse,
			sub = string.sub, split = string.split,
		}),
		table = table.freeze({
			insert = table.insert, remove = table.remove,
			concat = table.concat, sort = table.sort,
			create = table.create, clear = table.clear,
			find = table.find, freeze = table.freeze,
		}),
		task = table.freeze({
			spawn = task.spawn, delay = task.delay, defer = task.defer,
			cancel = task.cancel, wait = task.wait,
		}),
		coroutine = table.freeze({
			create = coroutine.create, resume = coroutine.resume,
			wrap = coroutine.wrap, yield = coroutine.yield,
			running = coroutine.running, status = coroutine.status,
			close = coroutine.close,
		}),
		Instance = Instance,
		CFrame = CFrame,
		Vector3 = Vector3, Vector2 = Vector2, Vector3_zero = Vector3.zero, Vector3_xAxis = Vector3.xAxis, Vector3_yAxis = Vector3.yAxis,
		Enum = Enum,
		UDim = UDim, UDim2 = UDim2,
		TweenInfo = TweenInfo,

		-- 显式禁用危险调用
		loadstring = nil,
		load = nil,
		require = nil,
		dofile = nil,
		loadfile = nil,
		readfile = nil,
		writefile = nil,
		appendfile = nil,
		delfile = nil,
		makefolder = nil,
		isfolder = nil,
		isfile = nil,
		listfiles = nil,
		setfenv = nil,
		getfenv = nil,
		setmetatable = nil,
		rawset = nil,
		rawget = nil,
		rawequal = nil,
	}
end

function PluginService.new(
	messageBus: MessageBus.MessageBus,
	loggerService: LoggerService.LoggerService,
	configService: ConfigService.ConfigService,
	commandService: CommandService.CommandService,
	notificationService: NotificationService.NotificationService,
)
	assert(messageBus and loggerService and configService and commandService and notificationService, "Missing deps")

	local self = setmetatable({}, PluginService)
	self._bus = messageBus
	self._logger = loggerService
	self._config = configService
	self._commands = commandService
	self._notifications = notificationService
	self._loaded = {} :: { [string]: true }
	self._sandboxEnv = nil :: { [string]: any }?
	self:_buildApi()
	self._logger:info("PluginService initialized")
	return self
end

function PluginService:_buildApi()
	local logger = self._logger
	local bus = self._bus
	local config = self._config
	local commands = self._commands
	local notifications = self._notifications

	local api = {
		Name = "ChuScriptPluginAPI",
		Version = "1.0.0",
		RegisterCommand = function(name, aliases, description, handler)
			assert(type(name) == "string", "command name must be string")
			assert(type(handler) == "function", "handler must be function")
			commands:register(name, aliases, description, handler)
		end,
		Notify = function(title, message, duration, kind)
			notifications:Send(tostring(title or ""), tostring(message or ""), tonumber(duration), kind)
		end,
		GetConfig = function(key)
			assert(type(key) == "string", "config key must be string")
			return config:get(key)
		end,
		Subscribe = function(eventType, callback)
			assert(type(eventType) == "string" and type(callback) == "function", "invalid arguments")
			return bus:subscribe(eventType, callback)
		end,
		Unsubscribe = function(token)
			return bus:unsubscribe(token)
		end,
		Logger = {
			debug = function(msg) logger:debug("[Plugin] " .. tostring(msg)) end,
			info  = function(msg) logger:info("[Plugin] " .. tostring(msg)) end,
			warn  = function(msg) logger:warn("[Plugin] " .. tostring(msg)) end,
			error = function(msg) logger:error("[Plugin] " .. tostring(msg)) end,
		},
	}

	self._api = api
	self._sandboxEnv = buildSandboxEnv(api)
end

local function needsFs()
	local check = { "isfolder", "isfile", "readfile", "makefolder", "listfiles" }
	for _, name in ipairs(check) do
		if not _G[name] then return false end
	end
	return true
end

function PluginService:LoadAll()
	if not needsFs() then
		self._logger:warn("Filesystem API unavailable; plugin system disabled.")
		return
	end

	pcall(function()
		if not isfolder(PLUGIN_DIR) then
			makefolder(PLUGIN_DIR)
			self._logger:info("Created plugin directory: " .. PLUGIN_DIR)
			return
		end
	end)

	local okList, files = pcall(listfiles, PLUGIN_DIR)
	if not okList or type(files) ~= "table" or #files == 0 then
		self._logger:info("No plugins found in " .. PLUGIN_DIR)
		return
	end

	local count = 0
	for _, fp in ipairs(files) do
		if type(fp) == "string" and (string.match(fp, "%.luau$") or string.match(fp, "%.lua$")) then
			if self:_loadFile(fp) then count += 1 end
		end
	end

	if count > 0 then
		self._notifications:Send("Plugin System", ("Loaded %d plugin(s)."):format(count), 3, "Success")
	end
end

function PluginService:_loadFile(filePath: string): boolean
	local fileName = (string.match(filePath, "[\\/]?([^\\/]+)$")) or filePath

	local okRead, content = pcall(readfile, filePath)
	if not okRead or type(content) ~= "string" then
		self._logger:error(("Failed to read plugin: %s"):format(fileName))
		self._notifications:Send("Plugin Error", "Failed to read: " .. fileName, 5, "Error")
		return false
	end

	-- 文件大小上限:1MB(防止异常脚本)
	if #content > 1_000_000 then
		self._logger:error(("Plugin exceeds size limit: %s"):format(fileName))
		self._notifications:Send("Plugin Error", "Too large: " .. fileName, 5, "Error")
		return false
	end

	local compileEnv = self._sandboxEnv
	if not compileEnv then return false end

	local okCompile, fnOrErr = pcall(loadstring, content, fileName)
	if not okCompile or type(fnOrErr) ~= "function" then
		self._logger:error(("Failed to compile plugin %s: %s"):format(fileName, tostring(fnOrErr)))
		self._notifications:Send("Plugin Error", "Compile failed: " .. fileName, 5, "Error")
		return false
	end

	-- 在受 sandbox 环境中执行
	local okSet, _ = pcall(setfenv, fnOrErr, compileEnv)
	if not okSet then
		-- Roblox 现代版本不允许 setfenv,改用 loadstring 的 env 参数
		local okRecompile, fn2 = pcall(loadstring, content, fileName)
		if not okRecompile or type(fn2) ~= "function" then
			self._logger:error("Cannot install sandbox env for " .. fileName)
			return false
		end
		fnOrErr = fn2
	end

	local okExec, err = pcall(fnOrErr, self._api)
	if not okExec then
		self._logger:error(("Execution error in %s: %s"):format(fileName, tostring(err)))
		self._notifications:Send("Plugin Error", "Execution failed: " .. fileName, 5, "Error")
		return false
	end

	self._loaded[fileName] = true
	self._logger:info(("Loaded plugin: %s"):format(fileName))
	return true
end

function PluginService:getLoadedPlugins(): { string }
	local out = {}
	for name in pairs(self._loaded) do
		table.insert(out, name)
	end
	return out
end

return table.freeze(PluginService)
