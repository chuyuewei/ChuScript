--!strict
--[[
  Module: AdministrationCommands
  Description: 基础管理员命令。包含 applyToTargets 与角色守护。
]]

return function(cs: any)
	local players = cs.players
	if not players or type(players.getTargets) ~= "function" then
		cs.logger:error("AdministrationCommands: cs.players missing")
		return
	end

	local Common = require(script.Parent._Common)

	local function apply(selector, callback)
		return Common.applyToTargets(players, selector, false, callback)
	end

	cs:registerCommand("kill", {"slay"}, "Kill target player(s).", function(args: { string })
		return apply(args[1], function(player)
			local hum = Common.getHumanoid(player)
			if hum then hum.Health = 0 end
		end)
	end)

	cs:registerCommand("heal", {"hp"}, "Restore health.", function(args)
		return apply(args[1], function(player)
			local hum = Common.getHumanoid(player)
			if hum then
				hum.MaxHealth = hum.MaxHealth
				hum.Health = hum.MaxHealth
			end
		end)
	end)

	cs:registerCommand("respawn", {"re"}, "Respawn target.", function(args)
		return apply(args[1], function(player)
			if player and player.Parent then
				player:LoadCharacter()
			end
		end)
	end)

	cs:registerCommand("freeze", {"ff"}, "Freeze movement.", function(args)
		return apply(args[1], function(player)
			local hum = Common.getHumanoid(player)
			if hum then
				hum.WalkSpeed = 0
				hum.JumpPower = 0
				hum.PlatformStand = true
			end
		end)
	end)

	cs:registerCommand("unfreeze", {"uf"}, "Unfreeze.", function(args)
		return apply(args[1], function(player)
			local hum = Common.getHumanoid(player)
			if hum then
				hum.WalkSpeed = 16
				hum.JumpPower = 50
				hum.PlatformStand = false
			end
		end)
	end)

	cs:registerCommand("sit", {}, "Sit.", function(args)
		return apply(args[1], function(player)
			local hum = Common.getHumanoid(player)
			if hum then hum.Sit = true end
		end)
	end)

	cs:registerCommand("stand", {}, "Stand.", function(args)
		return apply(args[1], function(player)
			local hum = Common.getHumanoid(player)
			if hum then hum.Sit = false end
		end)
	end)

	cs:registerCommand("bring", {"gethere"}, "Bring target to you.", function(args)
		local targets = players:getTargets(args[1] or "me")
		if #targets == 0 then return false, "No valid targets found." end

		local localRoot = Common.getRoot(game:GetService("Players").LocalPlayer)
		if not localRoot then return false, "Local character not found." end

		for _, target in ipairs(targets) do
			local root = Common.getRoot(target)
			if root then
				root.CFrame = localRoot.CFrame * CFrame.new(0, 0, -3)
			end
		end

		return true, ("Brought %d player(s) to you."):format(#targets)
	end)
end
