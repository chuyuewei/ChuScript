--!strict
--[[
  Module: CommandLoaderService
  Description: 扫描指定文件夹中的命令模块并注册。
]]

local LoggerService = require(script.Parent.Services.LoggerService)

local CommandLoaderService = {}
CommandLoaderService.__index = CommandLoaderService

function CommandLoaderService.new(loggerService: LoggerService.LoggerService)
	assert(loggerService, "loggerService required")
	local self = setmetatable({}, CommandLoaderService)
	self._logger = loggerService
	return self
end

--- 加载一个文件夹下的所有 ModuleScript(它们必须返回函数 fn(csInstance)).
-- @param csInstance table ChuScript 主实例
-- @param folder Instance 文件夹
-- @return number 成功加载数量
function CommandLoaderService:loadDirectory(csInstance: any, folder: Instance?): number
	if folder == nil then
		self._logger:warn("Command folder not found.")
		return 0
	end

	local modules = folder:GetChildren()
	local names = {}
	for i, m in ipairs(modules) do names[i] = m.Name end
	table.sort(names, function(a, b) return a < b end)

	-- 用名字重新 Get 避免顺序问题(modules 已经有序但保留兼容性)
	local loaded = 0
	for _, name in ipairs(names) do
		local module = folder:FindFirstChild(name)
		if module and module:IsA("ModuleScript") then
			loaded += self:_loadOne(csInstance, module) and 1 or 0
		end
	end

	self._logger:info(("Auto-loaded %d command module(s)."):format(loaded))
	return loaded
end

function CommandLoaderService:_loadOne(csInstance: any, module: ModuleScript): boolean
	local ok, modFunc = pcall(require, module)
	if not ok then
		self._logger:error(("require failed for '%s': %s"):format(module.Name, tostring(modFunc)))
		return false
	end

	if type(modFunc) ~= "function" then
		self._logger:error(("Module '%s' did not return a function (got %s)"):format(module.Name, type(modFunc)))
		return false
	end

	local okExec, err = pcall(modFunc, csInstance)
	if not okExec then
		self._logger:error(("Command module '%s' threw: %s"):format(module.Name, tostring(err)))
		return false
	end

	self._logger:debug(("Loaded command module: %s"):format(module.Name))
	return true
end

return table.freeze(CommandLoaderService)
