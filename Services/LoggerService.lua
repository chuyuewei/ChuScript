--!strict
--[[
  Module: LoggerService
  Description: 结构化日志服务。支持级别过滤、上下文附加、总线广播。
]]

local MessageBus = require(script.Parent.Core.MessageBus)

local LoggerService = {}
LoggerService.__index = LoggerService

local LEVEL_INFO = {
	DEBUG = { value = 10, label = "DEBUG", stream = "print" },
	INFO  = { value = 20, label = "INFO",  stream = "print" },
	WARN  = { value = 30, label = "WARN",  stream = "warn" },
	ERROR = { value = 40, label = "ERROR", stream = "warn" },
}

--- 构造。
function LoggerService.new(messageBus: MessageBus.MessageBus)
	assert(messageBus ~= nil, "LoggerService requires a MessageBus")

	local self = setmetatable({}, LoggerService)
	self._bus = messageBus
	self._minLevel = LEVEL_INFO.INFO
	-- 测试标志:收集日志条目而不是直接打印
	self._buffer = {} :: { any }
	return self
end

function LoggerService:setLevel(levelName: string)
	local lvl = LEVEL_INFO[levelName]
	if lvl then
		self._minLevel = lvl
	end
end

function LoggerService:getLevel(): number
	return self._minLevel.value
end

function LoggerService:getBuffer(): { any }
	return self._buffer
end

function LoggerService:clearBuffer()
	table.clear(self._buffer)
end

--- 内部统一出口。
function LoggerService:_emit(levelName: string, message: any, context: { [string]: any }?)
	local level = LEVEL_INFO[levelName]
	if not level then
		warn("[LoggerService] Unknown level: " .. tostring(levelName))
		return
	end

	if level.value < self._minLevel.value then return end

	local safeMsg = if type(message) == "string" then message else tostring(message)
	local safeCtx = if context ~= nil then context else {}

	-- 防循环:日志广播使用 MessageBus,要在日志处理器出错时仍可工作
	local entry = {
		timestamp = os.time(),
		level = level.label,
		message = safeMsg,
		context = safeCtx,
	}

	local line = string.format("[ChuScript] [%s] %s", level.label, safeMsg)
	if level.stream == "warn" then
		warn(line)
	else
		print(line)
	end

	table.insert(self._buffer, entry)
	if #self._buffer > 500 then
		table.remove(self._buffer, 1)
	end

	local _, busErr = pcall(function()
		self._bus:publish("LogEntry", entry)
	end)
	if busErr then
		warn("[LoggerService] Bus publish error: " .. tostring(busErr))
	end

	if level.value >= LEVEL_INFO.ERROR.value then
		local _, err2 = pcall(function()
			self._bus:publish("SystemError", entry)
		end)
		if err2 then
			warn("[LoggerService] Bus publish error: " .. tostring(err2))
		end
	end
end

function LoggerService:debug(message: any, context: { [string]: any }?) self:_emit("DEBUG", message, context) end
function LoggerService:info(message: any, context: { [string]: any }?)  self:_emit("INFO",  message, context) end
function LoggerService:warn(message: any, context: { [string]: any }?)  self:_emit("WARN",  message, context) end
function LoggerService:error(message: any, context: { [string]: any }?) self:_emit("ERROR", message, context) end

return table.freeze(LoggerService)
