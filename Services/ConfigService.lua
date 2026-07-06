--[[
  Module: ConfigService
  Description: 运行时配置管理服务，支持本地文件持久化。
  Part of: ChuScript Microservices Architecture
]]

local HttpService = game:GetService("HttpService")

local ConfigService = {}
ConfigService.__index = ConfigService

local kConfigPath = "ChuScript/config.json"
local kDebounceTime = 2 -- 写入防抖时间(秒)，避免频繁修改导致IO卡顿

local kDefaultConfig = {
  prefix = ":",
  fuzzyMatchThreshold = 0.6,
  autoExecuteOnFuzzyMatch = false,
  theme = "Dark"
}

--- 构造函数。
-- @param messageBus MessageBus
-- @return ConfigService
function ConfigService.new(messageBus)
  local self = setmetatable({}, ConfigService)
  self._bus = messageBus
  self._data = {}
  self._savePending = false
  self._lastSaveTime = 0

  -- 探测文件系统支持
  self._fsSupported = (readfile and writefile and isfile and isfolder and makefolder) ~= nil

  self:_loadFromFile()
  
  return self
end

--- 从文件加载配置，合并默认值。
function ConfigService:_loadFromFile()
  -- 初始化默认值
  for k, v in pairs(kDefaultConfig) do
    self._data[k] = v
  end

  if not self._fsSupported then
    return -- 不支持文件系统，仅使用内存默认配置
  end

  if not isfile(kConfigPath) then
    return -- 配置文件不存在，首次运行，使用默认值
  end

  local okRead, content = pcall(readfile, kConfigPath)
  if not okRead or not content then return end

  local okParse, parsedData = pcall(HttpService.JSONDecode, HttpService, content)
  if not okParse or type(parsedData) ~= "table" then return end

  -- 将解析到的有效配置覆盖默认值
  for k, v in pairs(parsedData) do
    self._data[k] = v
  end
end

--- 触发防抖写入文件。
function ConfigService:_scheduleSave()
  if not self._fsSupported then return end

  self._savePending = true
  local currentTime = os.clock()
  local timeSinceLastSave = currentTime - self._lastSaveTime

  if timeSinceLastSave >= kDebounceTime then
    self:_flushSave()
  else
    -- 在防抖时间内，安排延迟写入
    task.delay(kDebounceTime - timeSinceLastSave, function()
      if self._savePending then
        self:_flushSave()
      end
    end)
  end
end

--- 执行实际写入操作。
function ConfigService:_flushSave()
  self._savePending = false
  self._lastSaveTime = os.clock()

  -- 确保目录存在
  if not isfolder("ChuScript") then
    pcall(makefolder, "ChuScript")
  end

  local okEncode, jsonStr = pcall(HttpService.JSONEncode, HttpService, self._data)
  if not okEncode then return end

  pcall(writefile, kConfigPath, jsonStr)
end

--- 获取配置项。
-- @param key string
-- @return any
function ConfigService:get(key)
  return self._data[key]
end

--- 设置配置项并广播变更，触发持久化。
-- @param key string
-- @param value any
function ConfigService:set(key, value)
  local oldValue = self._data[key]
  if oldValue == value then return end

  self._data[key] = value
  
  self._bus:publish("ConfigChanged", {
    key = key,
    newValue = value,
    oldValue = oldValue
  })

  self:_scheduleSave()
end

return ConfigService