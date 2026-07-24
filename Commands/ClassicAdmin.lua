--!strict
--[[
  Module: ClassicAdminCommands
  Description: god / invis / visible / explode / reset / kick。
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

return function(cs: any)
	local players = cs.players
	if not players then
		cs.logger:error("ClassicAdminCommands: cs.players missing")
		return
	end

	local Common = require(script.Parent._Common)

	local godStates: { [Player]: { maxHealth: number, health: number } } = {}
	local invisStates: { [Player]: { [BasePart]: number } } = {}

	local function apply(selector, callback)
		return Common.applyToTargets(players, selector, false, callback)
	end

	cs:registerCommand("god", {"godmode"}, "Toggle god mode.", function(args)
		return apply(args[1], function(player)
			local hum = Common.getHumanoid(player)
			if not hum then return end
			local stored = godStates[player]
			if stored then
				hum.MaxHealth = math.max(stored.maxHealth, 1)
				hum.Health = math.min(stored.health, hum.MaxHealth)
				godStates[player] = nil
			else
				godStates[player] = { maxHealth = hum.MaxHealth, health = hum.Health }
				hum.MaxHealth = 100000000
				hum.Health = 100000000
			end
		end)
	end)

	cs:registerCommand("invis", {"invisible", "ghost"}, "Toggle invisibility.", function(args)
		return apply(args[1], function(player)
			local char = player and player.Character
			if not char then return end
			local stored = invisStates[player]
			if stored then
				for part, original in pairs(stored) do
					if part and part.Parent then part.Transparency = original end
				end
				invisStates[player] = nil
			else
				local records: { [BasePart]: number } = {}
				for _, descendant in ipairs(char:GetDescendants()) do
					if descendant:IsA("BasePart") then
						records[descendant] = descendant.Transparency
						descendant.Transparency = 1
					end
				end
				invisStates[player] = records
			end
		end)
	end)

	cs:registerCommand("visible", {"vis"}, "Restore visibility.", function(args)
		return apply(args[1], function(player)
			local records = invisStates[player]
			if not records then return end
			for part, original in pairs(records) do
				if part and part.Parent then part.Transparency = original end
			end
			invisStates[player] = nil
		end)
	end)

	cs:registerCommand("explode", {"boom"}, "Explode target.", function(args)
		return apply(args[1], function(player)
			local root = Common.getRoot(player)
			if not root then return end
			local ex = Instance.new("Explosion")
			ex.Position = root.Position
			ex.BlastRadius = 8
			ex.BlastPressure = 0
			ex.DestroyJointRadiusPercent = 0
			ex.Parent = Workspace
		end)
	end)

	cs:registerCommand("reset", {"rejoin"}, "Reset character.", function(args)
		return apply(args[1], function(player)
			if player and player.Parent then player:LoadCharacter() end
		end)
	end)

	cs:registerCommand("kick", {}, "Kick target (client-side, skip self).", function(args)
		local targets = players:getTargets(args[1] or "me")
		if #targets == 0 then return false, "No valid targets found." end

		local reason = table.concat(args, " ", 2)
		if reason == "" then reason = "Kicked by admin" end

		local kicked = 0
		for _, player in ipairs(targets) do
			if player ~= Players.LocalPlayer then
				local ok = pcall(function() player:Kick(reason) end)
				if ok then kicked += 1 end
			end
		end

		return true, ("Kicked %d player(s)."):format(kicked)
	end)
end
