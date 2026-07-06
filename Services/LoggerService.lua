--[[
  Module: LoggerService
  Description: 结构化日志服务。
]]

local LoggerService = {}
LoggerService.__index = LoggerService

local LOG_LEVELS = {
  DEBUG = {value = 1, label = "DEBUG"},
  INFO  = {value = 2, label = "INFO"},
  WARN  = {value = 3, label = "WARN"},
  ERROR = {value = 4, label = "ERROR"}
}

--- 构造函数。
-- @param messageBus MessageBus 消息总线实例
-- @return LoggerService
function LoggerService.new(messageBus)
  local self = setmetatable({}, LoggerService)
  self._bus = messageBus
  self._minLevel = LOG_LEVELS.INFO
  return self
end

--- 设置最低日志级别。
-- @param level string "DEBUG", "INFO", "WARN", "ERROR"
function LoggerService:setLevel(level)
  self._minLevel = LOG_LEVELS[level] or LOG_LEVELS.INFO
end

--- 内部日志打印与广播实现。
-- @param level table 级别定义表
-- @param message string 日志消息
-- @param context table 附加上下文
function LoggerService:_log(level, message, context)
  if level.value < self._minLevel.value then return end

  local entry = {
    timestamp = os.time(),
    level = level.label,
    message = message,
    context = context or {}
  }

  local output = string.format("[ChuScript] [%s] %s", level.label, message)
  if level == LOG_LEVELS.ERROR then
    warn(output)
  elseif level == LOG_LEVELS.WARN then
    warn(output)
  else
    print(output)
  end

  self._bus:publish("LogEntry", entry)
  if level == LOG_LEVELS.ERROR then
    self._bus:publish("SystemError", entry)
  end
end

function LoggerService:debug(msg, ctx) self:_log(LOG_LEVELS.DEBUG, msg, ctx) end
function LoggerService:info(msg, ctx)  self:_log(LOG_LEVELS.INFO, msg, ctx) end
function LoggerService:warn(msg, ctx)  self:_log(LOG_LEVELS.WARN, msg, ctx) end
function LoggerService:error(msg, ctx) self:_log(LOG_LEVELS.ERROR, msg, ctx) end

return LoggerService