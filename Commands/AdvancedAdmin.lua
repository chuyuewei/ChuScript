--!strict
--[[
  Module: AdvancedAdminCommands
  Description: ban / mute / server lock / announcement。注意:在客户端执行器中,
  Kick/ban 只能影响本地进程内的玩家(无法强制服务端踢人)。公告用本地通知。
]]

local Players = game:GetService("Players")

return function(cs: any)
	local players = cs.players
	local notifications = cs.notifications
	if not players or not notifications then
		cs.logger:error("AdvancedAdminCommands: cs.players or cs.notifications missing")
		return
	end

	local Common = require(script.Parent._Common)

	-- 仅本地执行器视角内的"封禁/静音/锁服"记录
	local banned: { [Player]: string } = {}
	local muted: { [Player]: boolean } = {}
	local serverLocked = false
	local allowedLockBypass: { [Player]: boolean } = {}

	local function isAdmin(player)	return player == Players.LocalPlayer end

	cs:registerCommand("ban", {}, "Bans a player (client-side).", function(args)
		local target = players:getPlayerByName(args[1]) or players:getTargets(args[1] or "me")[1]
		if not target then return false, "Target not found." end
		local reason = table.concat(args, " ", 2)
		if reason == "" then reason = "Banned by admin" end
		banned[target] = reason

		-- 客户端 Kick 仅生效于本地视图(无法真正阻止玩家)
		local ok = pcall(function() target:Kick("You were banned. Reason: " .. reason) end)
		if not ok then return false, "Failed to kick target." end
		return true, ("Banned %s."):format(target.Name)
	end)

	cs:registerCommand("unban", {}, "Unban a player (client-side).", function(args)
		local target = players:getPlayerByName(args[1])
		if not target then return false, "Target not found." end
		banned[target] = nil
		return true, ("Unbanned %s."):format(target.Name)
	end)

	cs:registerCommand("mute", {}, "Mute a player (client-side).", function(args)
		local target = players:getPlayerByName(args[1]) or players:getTargets(args[1] or "me")[1]
		if not target then return false, "Target not found." end
		muted[target] = true
		return true, ("Muted %s."):format(target.Name)
	end)

	cs:registerCommand("unmute", {}, "Unmute a player.", function(args)
		local target = players:getPlayerByName(args[1]) or players:getTargets(args[1] or "me")[1]
		if not target then return false, "Target not found." end
		muted[target] = nil
		return true, ("Unmuted %s."):format(target.Name)
	end)

	cs:registerCommand("serverlock", {"lockserver"}, "Lock server against new joiners (client-side).", function()
		serverLocked = true
		return true, "Server locked."
	end)

	cs:registerCommand("serverunlock", {"unlockserver"}, "Unlock server.", function()
		serverLocked = false
		return true, "Server unlocked."
	end)

	-- 修正:以前的 announce 是反复 Kick 全员,这是 bug;现在改为本地通知 + 日志广播。
	cs:registerCommand("announce", {"bc", "broadcast"},
		"Send a local announcement. Use chat for real broadcast.",
		function(args)
			local message = table.concat(args, " ")
			if message == "" then return false, "Usage: announce <message>" end

			-- 发送一条全局可视化通知 + 输出到 output
			notifications:Send("Announcement", message, 6, "Info")
			cs.logger:info("[Announce] " .. message)
			return true, "Announcement sent."
		end
	)

	Players.PlayerAdded:Connect(function(player)
		if banned[player] then
			pcall(function()
				player:Kick("You were banned. Reason: " .. banned[player])
			end)
			return
		end
		if serverLocked and not isAdmin(player) and not allowedLockBypass[player] then
			pcall(function() player:Kick("Server is locked.") end)
		end
	end)
end
