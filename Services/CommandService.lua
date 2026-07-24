--!strict
--[[
  Module: CommandService
  Description: 命令注册中心、执行引擎、模糊匹配建议。

  优化要点:
    - 注册和别名查找 O(1)
    - getSuggestions 缓存(同 partial 30 条 LRU)
    - handler 签名校验
    - 错误统一经总线广播
]]

local MessageBus = require(script.Parent.Core.MessageBus)
local ConfigService = require(script.Parent.Services.ConfigService)
local LoggerService = require(script.Parent.Services.LoggerService)
local StringUtils = require(script.Parent.Parent.Utils.StringUtils)

local CommandService = {}
CommandService.__index = CommandService

export type Command = {
	name: string,
	aliases: { string },
	description: string,
	handler: ({ string }) -> (boolean, string),
}

type Suggestion = {
	command: Command,
	score: number,
}

-- 建议缓存:FIFO(简单实现,避免使用过期 Optional)
local MAX_SUGGESTION_CACHE = 64
local suggestionCache = {} :: { [string]: { Suggestion } }

local function sanitizeName(name: any): string
	assert(type(name) == "string", "Command name must be string")
	name = string.match(name, "^%s*(.-)%s*$") or ""
	assert(#name > 0 and string.match(name, "^[%w_%-]+$"), "Command name must be non-empty alphanumeric (with _ or -)")
	return string.lower(name)
end

local function validateHandler(handler: any)
	assert(type(handler) == "function", "Command handler must be function")
end

--- 修剪 FIFO 缓存(超过上限移除最早项)。
local function trimCache()
	local excess = #suggestionCache - MAX_SUGGESTION_CACHE
	if excess <= 0 then return end
	-- 删除前 N 项;这里我们使用 array 简单截断
	for _ = 1, excess do table.remove(suggestionCache, 1) end
end

function CommandService.new(messageBus: MessageBus.MessageBus, configService: ConfigService.ConfigService, loggerService: LoggerService.LoggerService)
	assert(messageBus and configService and loggerService, "Missing dependencies")

	local self = setmetatable({}, CommandService)
	self._bus = messageBus
	self._config = configService
	self._logger = loggerService

	self._commands = {} :: { [string]: Command }
	self._aliases = {} :: { [string]: string }

	self._logger:info("CommandService initialized")
	return self
end

function CommandService:register(name: string, aliases: { string }?, description: string?, handler: ({ string }) -> (boolean, string)?)
	-- 兼容旧 API: 接受 (name, aliases, description, handler)
	if description ~= nil and handler == nil and type(description) == "function" then
		handler = description :: any
		description = nil
	end

	name = sanitizeName(name)
	validateHandler(handler)

	if self._commands[name] then
		self._logger:warn(("Overwriting existing command: %s"):format(name))
	end

	local cmd: Command = {
		name = name,
		aliases = {},
		description = if type(description) == "string" then description else "No description",
		handler = handler :: any,
	}

	if aliases ~= nil then
		assert(type(aliases) == "table", "Aliases must be a table")
		for _, alias in ipairs(aliases) do
			assert(type(alias) == "string", "Alias must be string")
			local lowered = string.lower(alias)
			if lowered ~= name and (self._aliases[lowered] == nil or self._aliases[lowered] == name) then
				table.insert(cmd.aliases, lowered)
				self._aliases[lowered] = name
			end
		end
	end

	self._commands[name] = cmd
	-- 失效缓存
	table.clear(suggestionCache)

	self._bus:publish("CommandRegistered", { command = cmd })
end

function CommandService:_resolveCommand(input: string): Command?
	if input == nil or input == "" then return nil end
	local lower = string.lower(input)
	local cmd = self._commands[lower]
	if cmd then return cmd end
	local main = self._aliases[lower]
	return main and self._commands[main] or nil
end

function CommandService:getCommand(name: string): Command?
	return self:_resolveCommand(name)
end

function CommandService:getCommands(): { Command }
	-- 返回浅拷贝,避免外部 mutate
	local out: { Command } = table.create(0)
	for _, cmd in pairs(self._commands) do
		table.insert(out, cmd)
	end
	return out
end

function CommandService:getNames(): { string }
	local out: { string } = {}
	for name in pairs(self._commands) do
		table.insert(out, name)
	end
	table.sort(out)
	return out
end

function CommandService:getSuggestions(partial: string?, maxResults: number?): { Suggestion }
	partial = string.lower(string.match(partial or "", "^%s*(.-)%s*$") or "")
	maxResults = maxResults or 5
	if partial == "" then return {} end

	local cacheKey = partial .. "|" .. tostring(maxResults)
	if suggestionCache[cacheKey] then
		return suggestionCache[cacheKey]
	end

	local threshold = self._config:get("fuzzyMatchThreshold") or 0.6
	local matches: { Suggestion } = {}

	for _, cmd in pairs(self._commands) do
		local score = StringUtils.calculateSimilarity(partial, cmd.name)
		if score < threshold then
			-- 仍尝试别名
			for _, alias in ipairs(cmd.aliases) do
				local aliasScore = StringUtils.calculateSimilarity(partial, alias)
				if aliasScore > score then score = aliasScore end
			end
		end
		if score >= threshold then
			table.insert(matches, { command = cmd, score = score })
		end
	end

	table.sort(matches, function(a, b) return a.score > b.score end)

	local result: { Suggestion } = table.create(math.min(maxResults, #matches))
	for i = 1, math.min(maxResults, #matches) do
		result[i] = matches[i]
	end

	suggestionCache[cacheKey] = result
	trimCache()
	return result
end

function CommandService:execute(rawInput: string): (boolean, string)
	if type(rawInput) ~= "string" or rawInput == "" then
		self._bus:publish("CommandProcessed", { success = false, message = "Empty input", input = "" })
		return false, "Empty input"
	end

	local prefix = self._config:get("prefix") or ":"
	if not StringUtils.startsWith(rawInput, prefix) then
		self._bus:publish("CommandProcessed", { success = false, message = "Invalid prefix", input = rawInput })
		return false, "Invalid prefix"
	end

	local content = string.sub(rawInput, #prefix + 1)
	if content == "" then
		self._bus:publish("CommandProcessed", { success = false, message = "Empty command", input = rawInput })
		return false, "Empty command"
	end

	local tokens = StringUtils.tokenize(content)
	if #tokens == 0 then
		self._bus:publish("CommandProcessed", { success = false, message = "Empty command", input = rawInput })
		return false, "Empty command"
	end

	local cmdName = table.remove(tokens, 1) :: string
	local cmd = self:_resolveCommand(cmdName)
	local ok, msg

	if cmd then
		ok, msg = self:_executeHandler(cmd, tokens, rawInput)
	else
		local autoExec = self._config:get("autoExecuteOnFuzzyMatch") or false
		local suggestions = self:getSuggestions(cmdName, 3)
		if #suggestions > 0 then
			local best = suggestions[1]
			if autoExec and best.score >= 0.9 then
				self._logger:info(("Auto-correcting '%s' to '%s'"):format(cmdName, best.command.name))
				ok, msg = self:_executeHandler(best.command, tokens, rawInput)
			else
				local names = table.create(#suggestions)
				for i, sug in ipairs(suggestions) do
					names[i] = prefix .. sug.command.name
				end
				ok = false
				msg = ("Unknown command. Did you mean: %s?"):format(table.concat(names, ", "))
			end
		else
			ok = false
			msg = ("Unknown command: %s"):format(cmdName)
		end
	end

	self._bus:publish("CommandProcessed", {
		success = ok,
		message = if type(msg) == "string" then msg else tostring(msg),
		input = rawInput,
	})
	return ok, msg :: string
end

function CommandService:_executeHandler(cmd: Command, args: { string }, rawInput: string): (boolean, string)
	self._logger:debug(("Executing: %s (args: %d)"):format(cmd.name, #args))

	local ok, result = pcall(cmd.handler, args)

	if not ok then
		local errStr = tostring(result)
		self._logger:error(("Command '%s' failed: %s"):format(cmd.name, errStr))
		self._bus:publish("CommandFailed", {
			command = cmd.name,
			error = errStr,
			input = rawInput,
		})
		return false, ("Error: %s"):format(errStr)
	end

	if result == nil then result = "Success" end
	self._bus:publish("CommandExecuted", {
		command = cmd.name,
		args = args,
		result = if type(result) == "string" then result else tostring(result),
	})
	return true, result
end

function CommandService:invalidateCache()
	table.clear(suggestionCache)
end

return table.freeze(CommandService)
