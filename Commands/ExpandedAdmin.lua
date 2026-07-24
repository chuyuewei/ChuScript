--!strict
--[[
  Module: ExpandedAdminCommands
  Description: 工具栏、传送、状态控制。
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

return function(cs: any)
	local players = cs.players
	if not players then
		cs.logger:error("ExpandedAdminCommands: cs.players missing")
		return
	end

	local Common = require(script.Parent._Common)

	local spinStates: { [Player]: { conn: RBXScriptConnection } } = {}

	local function apply(selector, callback)
		return Common.applyToTargets(players, selector, false, callback)
	end

	local function stopSpin(player)
		local s = spinStates[player]
		if s then
			s.conn:Disconnect()
			spinStates[player] = nil
		end
	end

	Players.PlayerRemoving:Connect(stopSpin)

	cs:registerCommand("tool", {"giveweapon", "giveitem"}, "Give a tool by name.", function(args)
		local targets = players:getTargets(args[1] or "me")
		if #targets == 0 then return false, "No valid targets found." end
		local toolName = args[2]
		if not toolName or toolName == "" then return false, "Usage: tool <player> <toolName>" end

		local tool = ReplicatedStorage:FindFirstChild(toolName) or Workspace:FindFirstChild(toolName)
		if not tool then return false, ("Tool '%s' not found."):format(toolName) end

		for _, player in ipairs(targets) do
			local char = player.Character
			if char then
				local clone = tool:Clone()
				clone.Parent = char
			end
		end
		return true, ("Gave '%s' to %d player(s)."):format(toolName, #targets)
	end)

	cs:registerCommand("removeTool", {"rmtool"}, "Remove a tool by name.", function(args)
		local targets = players:getTargets(args[1] or "me")
		if #targets == 0 then return false, "No valid targets found." end
		local toolName = args[2]
		if not toolName or toolName == "" then return false, "Usage: removeTool <player> <toolName>" end

		for _, player in ipairs(targets) do
			local char = player.Character
			if char then
				local found = char:FindFirstChild(toolName)
				if found then found:Destroy() end
			end
		end
		return true, ("Removed tool '%s' from %d player(s)."):format(toolName, #targets)
	end)

	cs:registerCommand("tpall", {"bringall"}, "Bring all players to you.", function()
		local localRoot = Common.getRoot(Players.LocalPlayer)
		if not localRoot then return false, "Local character not found." end

		local count = 0
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= Players.LocalPlayer then
				local root = Common.getRoot(player)
				if root then
					root.CFrame = localRoot.CFrame * CFrame.new(0, 0, -3)
					count += 1
				end
			end
		end
		return true, ("Brought %d player(s) to you."):format(count)
	end)

	cs:registerCommand("spin", {}, "Toggle spin on target.", function(args)
		return apply(args[1], function(player)
			if spinStates[player] then
				stopSpin(player)
				return
			end
			local root = Common.getRoot(player)
			if not root then return end
			local conn = RunService.RenderStepped:Connect(function()
				if not root.Parent or not Common.isAlive(player) then
					stopSpin(player)
					return
				end
				root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(15), 0)
			end)
			spinStates[player] = { conn = conn }
		end)
	end)

	cs:registerCommand("ragdoll", {}, "Ragdoll target.", function(args)
		return apply(args[1], function(player)
			local hum = Common.getHumanoid(player)
			if hum then
				hum.PlatformStand = true
				hum.WalkSpeed = 0
			end
		end)
	end)

	cs:registerCommand("unragdoll", {}, "Unragdoll target.", function(args)
		return apply(args[1], function(player)
			local hum = Common.getHumanoid(player)
			if hum then
				hum.PlatformStand = false
				hum.WalkSpeed = 16
			end
		end)
	end)

	cs:registerCommand("sethealth", {"health"}, "Set target's health.", function(args)
		local targets = players:getTargets(args[1] or "me")
		if #targets == 0 then return false, "No valid targets found." end

		local value = Common.parseNumber(args[2], nil)
		if value == nil then return false, "Usage: sethealth <player> <number>" end
		value = math.clamp(value, 0, 1e9)

		for _, player in ipairs(targets) do
			local hum = Common.getHumanoid(player)
			if hum then
				hum.MaxHealth = math.max(value, hum.MaxHealth)
				hum.Health = value
			end
		end
		return true, ("Set health to %d for %d player(s)."):format(value, #targets)
	end)
end
