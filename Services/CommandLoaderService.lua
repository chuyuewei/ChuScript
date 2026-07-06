--[[
  Module: CommandLoaderService
  Description: 命令自动发现与注册微服务。扫描目录并动态加载命令模块。
  Part of: ChuScript Microservices Architecture
]]

local CommandLoaderService = {}
CommandLoaderService.__index = CommandLoaderService

--- 构造函数（依赖注入）。
-- @param loggerService LoggerService
-- @return CommandLoaderService
function CommandLoaderService.new(loggerService)
  local self = setmetatable({}, CommandLoaderService)
  self._logger = loggerService
  return self
end

--- 扫描并加载指定文件夹下的所有命令模块。
-- @param csInstance table ChuScript 主实例 (用于注入给命令模块作为 API)
-- @param folder Instance 包含命令 ModuleScript 的文件夹实例
function CommandLoaderService:loadDirectory(csInstance, folder)
  if not folder then
    self._logger:warn("Command folder not found.")
    return 0
  end

  local modules = folder:GetChildren()
  -- 按名称排序，确保加载顺序一致
  table.sort(modules, function(a, b) return a.Name < b.Name end)

  local loadedCount = 0

  for _, module in ipairs(modules) do
    if module:IsA("ModuleScript") then
      local success, result = pcall(function()
        local modFunc = require(module)
        
        -- 验证模块签名：必须返回一个函数
        if type(modFunc) ~= "function" then
          error(string.format("Module must return a function, got %s", type(modFunc)))
        end
        
        -- 执行命令注册函数，注入 ChuScript 实例
        modFunc(csInstance)
      end)

      if success then
        loadedCount += 1
        self._logger:debug(string.format("Loaded command module: %s", module.Name))
      else
        self._logger:error(string.format("Failed to load command module '%s': %s", module.Name, tostring(result)))
      end
    end
  end

  self._logger:info(string.format("Auto-loaded %d command module(s).", loadedCount))
  return loadedCount
end

return CommandLoaderService