--[[
  Module: ServiceContainer
  Description: 服务定位器与依赖注入容器。
]]

local ServiceContainer = {}
ServiceContainer.__index = ServiceContainer

--- 创建新的服务容器实例。
-- @return ServiceContainer
function ServiceContainer.new()
  local self = setmetatable({}, ServiceContainer)
  self._definitions = {}
  self._instances = {}
  return self
end

--- 注册服务定义。
-- @param name string 服务名称
-- @param factory function 工厂函数，接收依赖项，返回服务实例
-- @param dependencies table 依赖的服务名数组
function ServiceContainer:register(name, factory, dependencies)
  self._definitions[name] = {
    factory = factory,
    dependencies = dependencies or {}
  }
end

--- 解析并获取服务实例（单例）。
-- @param name string 服务名称
-- @return any 服务实例
function ServiceContainer:resolve(name)
  if self._instances[name] then
    return self._instances[name]
  end

  local definition = self._definitions[name]
  if not definition then
    error(string.format("Service '%s' not registered", name), 2)
  end

  local deps = {}
  for _, depName in ipairs(definition.dependencies) do
    table.insert(deps, self:resolve(depName))
  end

  local instance = definition.factory(table.unpack(deps))
  self._instances[name] = instance
  return instance
end

return ServiceContainer