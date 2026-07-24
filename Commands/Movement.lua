--!strict
--[[
  Module: MovementCommands
  Description: 飞行、穿墙、walkspeed、jumppower、传送。
]]

local Players = game:GetService("Players")

return function(cs: any)
	local players = cs.players
	local utility = cs.utility
	if not players or not utility then
		cs.logger:error("MovementCommands: cs.players or cs.utility missing")
		return
	end

	local Common = require(script.Parent._Common)

	local function apply(selector, callback)
		return Common.applyToTargets(players, selector, false, callback)
	end

	cs:registerCommand("fly", {"f"}, "Toggle fly or set speed.", function(args)
		local targets = players:getTargets(args[1] or "me")
		if #targets == 0 then return false, "No valid targets found." end

		local arg2 = args[2]
		local toggle = Common.parseToggle(arg2)
		local speed = Common.parseNumber(arg2, 50) or 50

		for _, target in ipairs(targets) do
			if toggle == false then
				utility:stopFly(target)
			elseif toggle == true then
				utility:startFly(target, speed)
			elseif utility:isFlying(target) then
				utility:stopFly(target)
			else
				utility:startFly(target, speed)
			end
		end
		return true, ("Toggled fly for %d player(s)."):format(#targets)
	end)

	cs:registerCommand("noclip", {"nc"}, "Toggle noclip.", function(args)
		local targets = players:getTargets(args[1] or "me")
		if #targets == 0 then return false, "No valid targets found." end

		for _, target in ipairs(targets) do
			if utility:isNoclipping(target) then
				utility:stopNoclip(target)
			else
				utility:startNoclip(target)
			end
		end
		return true, ("Toggled noclip for %d player(s)."):format(#targets)
	end)

	cs:registerCommand("walkspeed", {"ws", "speed"}, "Set walk speed.", function(args)
		local targets = players:getTargets(args[1] or "me")
		if #targets == 0 then return false, "No valid targets found." end

		local speed = Common.parseNumber(args[2], 16)
		if speed == nil then return false, "Invalid speed value." end
		speed = math.clamp(speed, 0, 1000)

		for _, target in ipairs(targets) do
			local hum = Common.getHumanoid(target)
			if hum then hum.WalkSpeed = speed end
		end
		return true, ("Set WalkSpeed to %d for %d player(s)."):format(speed, #targets)
	end)

	cs:registerCommand("jumppower", {"jp"}, "Set jump power.", function(args)
		local targets = players:getTargets(args[1] or "me")
		if #targets == 0 then return false, "No valid targets found." end

		local power = Common.parseNumber(args[2], 50)
		if power == nil then return false, "Invalid jump power value." end
		power = math.clamp(power, 0, 1000)

		for _, target in ipairs(targets) do
			local hum = Common.getHumanoid(target)
			if hum then
				hum.UseJumpPower = true
				hum.JumpPower = power
			end
		end
		return true, ("Set JumpPower to %d for %d player(s)."):format(power, #targets)
	end)

	cs:registerCommand("goto", {"to"}, "Teleport to player.", function(args)
		local targets = players:getTargets(args[1] or "")
		if #targets == 0 then return false, "No target found to goto." end

		local targetRoot = Common.getRoot(targets[1])
		local localRoot = Common.getRoot(Players.LocalPlayer)
		if targetRoot and localRoot then
			localRoot.CFrame = targetRoot.CFrame * CFrame.new(0, 0, 3)
			return true, ("Teleported to %s"):format(targets[1].Name)
		end
		return false, "Failed to get HumanoidRootPart."
	end)

	cs:registerCommand("teleport", {"tp"}, "Teleport to coordinates.", function(args)
		local x = Common.parseNumber(args[1], nil)
		local y = Common.parseNumber(args[2], nil)
		local z = Common.parseNumber(args[3], nil)
		if not (x and y and z) then return false, "Invalid coordinates. Usage: tp <x> <y> <z>" end

		local localRoot = Common.getRoot(Players.LocalPlayer)
		if not localRoot then return false, "Local character not found." end
		localRoot.CFrame = CFrame.new(x, y, z)
		return true, ("Teleported to %d, %d, %d"):format(x, y, z)
	end)
end
