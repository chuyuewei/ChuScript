--[[
  Module: CommandService
  Description: 命令注册中心与执行引擎。
]]

local StringUtils = require(script.Parent.Parent.Utils.StringUtils)

local CommandService = {}
CommandService.__index = CommandService

--- 构造函数（依赖注入）。
-- @param messageBus MessageBus
-- @param configService ConfigService
-- @param loggerService LoggerService
-- @return CommandService
function CommandService.new(messageBus, configService, loggerService)
  local self = setmetatable({}, CommandService)
  self._bus = messageBus
  self._config = configService
  self._logger = loggerService

  self._commands = {}  -- [name] = commandObject
  self._aliases = {}   -- [alias] = name

  self._logger:info("CommandService initialized")
  return self
end

--- 注册新命令。
-- @param name string 命令名称（小写）
-- @param aliases table 别名数组
-- @param description string 描述
-- @param handler function 执行函数 (args) -> boolean, string
function CommandService:register(name, aliases, description, handler)
  name = string.lower(name)

  if self._commands[name] then
    self._logger:warn(string.format("Overwriting existing command: %s", name))
  end

  local cmd = {
    name = name,
    aliases = aliases or {},
    description = description or "No description",
    handler = handler
  }

  self._commands[name] = cmd

  for _, alias in ipairs(cmd.aliases) do
    self._aliases[string.lower(alias)] = name
  end

  self._bus:publish("CommandRegistered", {command = cmd})
end

--- 精确解析命令对象（通过名称或别名）。
-- @param input string 输入的命令名
-- @return table|nil 命令对象
function CommandService:_resolveCommand(input)
  input = string.lower(input)
  if self._commands[input] then
    return self._commands[input]
  end
  local mainName = self._aliases[input]
  return mainName and self._commands[mainName] or nil
end

--- 获取模糊匹配建议。
-- @param partial string 部分输入的命令名
-- @param maxResults number 最大返回数量
-- @return table 建议数组
function CommandService:getSuggestions(partial, maxResults)
  maxResults = maxResults or 5
  local threshold = self._config:get("fuzzyMatchThreshold")
  local matches = {}

  for _, cmd in pairs(self._commands) do
    local score = StringUtils.calculateSimilarity(partial, cmd.name)

    for _, alias in ipairs(cmd.aliases) do
      local aliasScore = StringUtils.calculateSimilarity(partial, alias)
      if aliasScore > score then score = aliasScore end
    end

    if score >= threshold then
      table.insert(matches, {command = cmd, score = score})
    end
  end

  table.sort(matches, function(a, b) return a.score > b.score end)

  local result = {}
  for i = 1, math.min(maxResults, #matches) do
    result[i] = matches[i]
  end
  return result
end

--- 解析并执行原始输入字符串。
-- @param rawInput string 完整输入
-- @return boolean 是否成功
-- @return string 返回消息
function CommandService:execute(rawInput)
  local prefix = self._config:get("prefix")
  local ok = false
  local msg = ""

  if string.sub(rawInput, 1, #prefix) ~= prefix then
    ok, msg = false, "Invalid prefix"
  else
    local content = string.sub(rawInput, #prefix + 1)
    if content == "" then
      ok, msg = false, "Empty command"
    else
      local tokens = StringUtils.tokenize(content)
      local cmdName = table.remove(tokens, 1)
      local cmd = self:_resolveCommand(cmdName)

      if cmd then
        ok, msg = self:_executeCommand(cmd, tokens, rawInput)
      else
        -- 模糊匹配回退逻辑
        local suggestions = self:getSuggestions(cmdName, 3)
        if #suggestions > 0 then
          local bestMatch = suggestions[1]
          if bestMatch.score > 0.9 and self._config:get("autoExecuteOnFuzzyMatch") then
            self._logger:info(string.format("Auto-correcting '%s' to '%s'", cmdName, bestMatch.command.name))
            ok, msg = self:_executeCommand(bestMatch.command, tokens, rawInput)
          else
            local names = {}
            for _, sug in ipairs(suggestions) do
              table.insert(names, prefix .. sug.command.name)
            end
            ok, msg = false, string.format("Unknown command. Did you mean: %s?", table.concat(names, ", "))
          end
        else
          ok, msg = false, string.format("Unknown command: %s", cmdName)
        end
      end
    end
  end

  -- [新增] 统一发布命令处理结果事件
  self._bus:publish("CommandProcessed", {
    success = ok,
    message = msg,
    input = rawInput
  })

  return ok, msg
end

--- 内部命令执行器。
-- @param cmd table 命令对象
-- @param args table 参数数组
-- @param originalInput string 原始输入
-- @return boolean, string
function CommandService:_executeCommand(cmd, args, originalInput)
  self._logger:debug(string.format("Executing: %s (args: %d)", cmd.name, #args))

  local ok, result = pcall(cmd.handler, args)

  if not ok then
    self._logger:error(string.format("Command '%s' failed: %s", cmd.name, tostring(result)))
    self._bus:publish("CommandFailed", {
      command = cmd.name,
      error = tostring(result),
      input = originalInput
    })
    return false, string.format("Error: %s", tostring(result))
  end

  self._bus:publish("CommandExecuted", {
    command = cmd.name,
    args = args,
    result = result
  })

  return true, result or "Success"
end

return CommandService