--[[
  Module: PluginService
  Description: 插件管理微服务。负责扫描、加载外部 Lua 插件并注入 API。
  Part of: ChuScript Microservices Architecture
]]

local PluginService = {}
PluginService.__index = PluginService

local kPluginFolder = "ChuScript/Plugins"

--- 构造函数（依赖注入）。
-- @param messageBus MessageBus
-- @param loggerService LoggerService
-- @param configService ConfigService
-- @param commandService CommandService
-- @param notificationService NotificationService
-- @return PluginService
function PluginService.new(messageBus, loggerService, configService, commandService, notificationService)
  local self = setmetatable({}, PluginService)
  self._bus = messageBus
  self._logger = loggerService
  self._config = configService
  self._commands = commandService
  self._notifications = notificationService

  self._loadedPlugins = {}

  self:_buildApi()
  self._logger:info("PluginService initialized")
  return self
end

--- 构建暴露给插件的沙盒 API 表。
function PluginService:_buildApi()
  local api = {}
  local logger = self._logger
  local bus = self._bus
  local config = self._config
  local commands = self._commands
  local notifications = self._notifications

  -- 插件版本与名称标识
  api.Name = "ChuScriptPluginAPI"
  api.Version = "1.0.0"

  -- 1. 命令注册 API
  api.RegisterCommand = function(name, aliases, description, handler)
    commands:register(name, aliases, description, handler)
  end

  -- 2. 通知 API
  api.Notify = function(title, message, duration, notifType)
    notifications:Send(title, message, duration, notifType)
  end

  -- 3. 配置读取 API (不允许插件修改核心配置，只读)
  api.GetConfig = function(key)
    return config:get(key)
  end

  -- 4. 事件订阅 API
  api.Subscribe = function(eventType, callback)
    return bus:subscribe(eventType, callback)
  end

  -- 5. 日志 API
  api.Logger = {
    debug = function(msg) logger:debug("[Plugin] " .. msg) end,
    info = function(msg) logger:info("[Plugin] " .. msg) end,
    warn = function(msg) logger:warn("[Plugin] " .. msg) end,
    error = function(msg) logger:error("[Plugin] " .. msg) end
  }

  self._api = api
end

--- 扫描并加载所有插件。
function PluginService:LoadAll()
  -- 1. 检查执行器是否支持文件系统 API
  if not isfolder or not isfile or not readfile or not listfiles or not makefolder then
    self._logger:warn("Exploit does not support filesystem API. Plugin system disabled.")
    self._notifications:Send("Plugin System", "Current executor does not support filesystem API.", 5, "Warn")
    return
  end

  -- 2. 确保目录存在
  if not isfolder(kPluginFolder) then
    makefolder(kPluginFolder)
    self._logger:info("Created plugin directory: " .. kPluginFolder)
    self._notifications:Send("Plugin System", "Created plugin directory. Put your .lua files in workspace/ChuScript/Plugins", 5, "Info")
    return -- 首次创建无需加载
  end

  -- 3. 遍历并加载文件
  local files = listfiles(kPluginFolder)
  if not files or #files == 0 then
    self._logger:info("No plugins found in " .. kPluginFolder)
    return
  end

  local loadedCount = 0
  for _, filePath in ipairs(files) do
    -- 仅处理 .lua 或 .luau 文件
    if string.match(filePath, "%.lua$") or string.match(filePath, "%.luau$") then
      local success = self:_loadFile(filePath)
      if success then loadedCount += 1 end
    end
  end

  if loadedCount > 0 then
    self._notifications:Send("Plugin System", string.format("Successfully loaded %d plugin(s).", loadedCount), 3, "Success")
  end
end

--- 加载单个插件文件。
-- @param filePath string 文件绝对路径
-- @return boolean 是否成功加载
function PluginService:_loadFile(filePath)
  local fileName = string.match(filePath, "([^/\\]+)$") or filePath
  
  local okRead, content = pcall(readfile, filePath)
  if not okRead or not content then
    self._logger:error(string.format("Failed to read plugin: %s", fileName))
    self._notifications:Send("Plugin Error", "Failed to read: " .. fileName, 5, "Error")
    return false
  end

  -- 编译插件代码
  local okCompile, func = pcall(loadstring, content, fileName)
  if not okCompile or type(func) ~= "function" then
    self._logger:error(string.format("Failed to compile plugin %s: %s", fileName, tostring(func)))
    self._notifications:Send("Plugin Error", "Compile failed: " .. fileName, 5, "Error")
    return false
  end

  -- 执行插件代码，注入 API
  local okExec, err = pcall(func, self._api)
  if not okExec then
    self._logger:error(string.format("Error executing plugin %s: %s", fileName, tostring(err)))
    self._notifications:Send("Plugin Error", "Execution failed: " .. fileName, 5, "Error")
    return false
  end

  table.insert(self._loadedPlugins, fileName)
  self._logger:info(string.format("Loaded plugin: %s", fileName))
  return true
end

return PluginService