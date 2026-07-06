--[[
  Module: UtilityCommands
  Description: 额外辅助命令集合。
]]

return function(cs)
  cs:registerCommand("help", {"?"}, "显示可用命令列表", function(args)
    local names = {}
    local commandService = cs.commands
    for name, cmd in pairs(commandService._commands) do
      table.insert(names, string.format("%s - %s", name, cmd.description))
    end

    table.sort(names)
    return true, table.concat(names, "\n")
  end)

  cs:registerCommand("ping", {}, "测试命令是否正常工作", function(args)
    return true, "Pong!"
  end)

  cs:registerCommand("say", {}, "向控制台输出消息", function(args)
    local message = table.concat(args, " ")
    if message == "" then
      return false, "Usage: say <message>"
    end

    print("[ChuScript]", message)
    return true, "Printed message."
  end)
end
