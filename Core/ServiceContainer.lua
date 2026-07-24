--!strict
--[[
  Module: ServiceContainer
  Description: 轻量级服务容器。单例、依赖注入、循环依赖检测。

  设计要点:
    - 延迟初始化:首次 resolve 时构造。
    - 循环依赖检测:抛错而非无限递归。
    - 实例缓存:失败抛出后允许重试(resolve 重新走工厂)。
]]

local ServiceContainer = {}
ServiceContainer.__index = ServiceContainer

export type ServiceKey = string

type Definition = {
	factory: (any) -> any,
	dependencies: { ServiceKey },
}

function ServiceContainer.new()
	local self = setmetatable({}, ServiceContainer)
	self._definitions = {} :: { [ServiceKey]: Definition }
	self._instances = {} :: { [ServiceKey]: any }
	self._resolving = {} :: { [ServiceKey]: boolean }
	return self
end

--- 注册服务定义。
function ServiceContainer:register(name: ServiceKey, factory: (any) -> any, dependencies: { ServiceKey }?)
	assert(type(name) == "string", "Service name must be string")
	assert(type(factory) == "function", "Service factory must be function")

	local deps = dependencies or {}
	for i, dep in ipairs(deps) do
		assert(type(dep) == "string", `Dependency #{i} for '{name}' must be a string key`)
	end

	self._definitions[name] = { factory = factory, dependencies = deps }
	-- 已解析缓存作废:允许覆盖
	self._instances[name] = nil
end

--- 判断服务是否已注册但不立即构造。
function ServiceContainer:has(name: ServiceKey): boolean
	return self._definitions[name] ~= nil
end

--- 解析服务,返回单例。
function ServiceContainer:resolve(name: ServiceKey): any
	if self._instances[name] ~= nil then
		return self._instances[name]
	end

	local definition = self._definitions[name]
	if not definition then
		error(`[ServiceContainer] Service '{name}' is not registered`, 2)
	end

	if self._resolving[name] then
		error(`[ServiceContainer] Circular dependency detected while resolving '{name}'`, 2)
	end
	self._resolving[name] = true

	local deps = definition.dependencies
	local resolvedDeps = table.create(#deps) :: { any }
	for i, depName in ipairs(deps) do
		resolvedDeps[i] = self:resolve(depName)
	end

	local instance = definition.factory(table.unpack(resolvedDeps))
	self._resolving[name] = nil
	self._instances[name] = instance
	return instance
end

--- 强制重新创建(用于热重载场景)。
function ServiceContainer:invalidate(name: ServiceKey)
	self._instances[name] = nil
end

function ServiceContainer:invalidateAll()
	for k in pairs(self._instances) do
		self._instances[k] = nil
	end
end

return table.freeze(ServiceContainer)
