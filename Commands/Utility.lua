--!strict
--[[
  Module: UtilityCommands
  Description: 帮助 / ping / say 等小工具。
]]

return function(cs: any)
	local commands = cs.commands
	if not commands or type(commands.getNames) ~= "function" then
		cs.logger:error("UtilityCommands: cs.commands missing")
		return
	end

	cs:registerCommand("help", {"?"}, "List all commands.", function()
		local list = commands:getNames()
		table.sort(list)
		local lines = {}
		for _, name in ipairs(list) do
			local cmd = commands:getCommand(name)
			lines[#lines + 1] = ("%s - %s"):format(name, cmd and cmd.description or "")
		end
		return true, table.concat(lines, "\n")
	end)

	cs:registerCommand("ping", {}, "Health check.", function()
		return true, "Pong!"
	end)

	cs:registerCommand("say", {}, "Print a message to output.", function(args)
		local message = table.concat(args, " ")
		if message == "" then return false, "Usage: say <message>" end
		print("[ChuScript]", message)
		return true, "Printed message."
	end)

	cs:registerCommand("prefix", {"setprefix"}, "Change command prefix (deprecated; use setprefix).", function()
		return true, "Use ':setprefix <char>' or call cs:setConfig('prefix','!')."
	end)
end
