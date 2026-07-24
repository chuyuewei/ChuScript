--!strict
--[[
  Module: ConfigService
  Description: 运行时配置 + 本地文件持久化。真正的单次延迟防抖,可动态修改合并。
]]

local HttpService = game:GetService("HttpService")
local MessageBus = require(script.Parent.Core.MessageBus)
local LoggerService = require(script.Parent.Services.LoggerService)

local ConfigService = {}
ConfigService.__index = ConfigService

local CONFIG_DIR = "ChuScript"
local CONFIG_FILE = "ChuScript/config.json"
local DEBOUNCE_SECONDS = 2

local DEFAULT_CONFIG = {
	prefix = ":",
	fuzzyMatchThreshold = 0.6,
	autoExecuteOnFuzzyMatch = false,
	theme = "Dark",
}

function ConfigService.new(messageBus: MessageBus.MessageBus, loggerService: LoggerService.LoggerService)
	assert(messageBus, "ConfigService requires MessageBus")
	local self = setmetatable({}, ConfigService)
	self._bus = messageBus
	self._logger = loggerService
	self._data = {} :: { [string]: any }

	-- 是否支持文件 IO(标志合并,避免反复访问全局)
	local fs = readfile and writefile and isfile and isfolder and makefolder
	self._fsSupported = fs and true or false

	self:_loadFromFile()
	self._logger:info("ConfigService initialized")
	return self
end

--- 合并默认值,然后叠加磁盘内容。
function ConfigService:_loadFromFile()
	for k, v in pairs(DEFAULT_CONFIG) do
		self._data[k] = v
	end

	if not self._fsSupported then
		self._logger:warn("Filesystem unsupported; running with default config only.")
		return
	end

	pcall(function()
		-- 确保目录存在
		if not isfolder(CONFIG_DIR) then
			makefolder(CONFIG_DIR)
		end
	end)

	if not isfile(CONFIG_FILE) then return end

	local okRead, content = pcall(readfile, CONFIG_FILE)
	if not okRead or type(content) ~= "string" or content == "" then return end

	local okParse, parsed = pcall(HttpService.JSONDecode, HttpService, content)
	if not okParse or type(parsed) ~= "table" then
		self._logger:warn("Config file corrupt; falling back to defaults.")
		return
	end

	for k, v in pairs(parsed :: { [string]: any }) do
		self._data[k] = v
	end
end

--- 真实单次延迟防抖:每次 set 都取消之前未触发的 timer。
function ConfigService:_scheduleSave()
	if not self._fsSupported then return end

	-- 取消旧的延迟任务,避免累积
	if self._saveThread then
		pcall(task.cancel, self._saveThread)
		self._saveThread = nil
	end

	local delay = DEBOUNCE_SECONDS
	self._saveThread = task.delay(delay, function()
		self._saveThread = nil
		local ok, err = pcall(function() self:_flushSave() end)
		if not ok then
			self._logger:error("Config write failed: " .. tostring(err))
		end
	end)
end

function ConfigService:_flushSave()
	local okEncode, jsonStr = pcall(HttpService.JSONEncode, HttpService, self._data)
	if not okEncode or type(jsonStr) ~= "string" then return end

	pcall(function()
		if not isfolder(CONFIG_DIR) then makefolder(CONFIG_DIR) end
	end)

	pcall(writefile, CONFIG_FILE, jsonStr)
end

function ConfigService:get(key: string): any
	return self._data[key]
end

function ConfigService:getAll(): { [string]: any }
	-- 返回浅拷贝,避免外部篡改内部状态
	local copy = {}
	for k, v in pairs(self._data) do
		copy[k] = v
	end
	return copy
end

function ConfigService:set(key: string, value: any)
	assert(type(key) == "string", "key must be string")
	if self._data[key] == value then return end

	local oldValue = self._data[key]
	self._data[key] = value

	self._bus:publish("ConfigChanged", {
		key = key,
		oldValue = oldValue,
		newValue = value,
	})
	self:_scheduleSave()
end

--- 同步立即落盘(用于脚本结束、游戏退出前)。
function ConfigService:flush()
	if self._saveThread then
		pcall(task.cancel, self._saveThread)
		self._saveThread = nil
	end
	self:_flushSave()
end

return table.freeze(ConfigService)
