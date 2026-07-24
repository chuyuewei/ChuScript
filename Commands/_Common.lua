--!strict
--[[
  Module: Commands.Common
  Description: 命令模块共享的辅助函数。
]]

local Players = game:GetService("Players")

local Common = {}

function Common.getHumanoid(player: Player?): Humanoid?
	local char = player and player.Character
	return char and char:FindFirstChildOfClass("Humanoid") :: Humanoid?
end

function Common.getRoot(player: Player?): BasePart?
	local char = player and player.Character
	return char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function Common.isAlive(player: Player?): boolean
	local h = Common.getHumanoid(player)
	return h ~= nil and h.Health > 0
end

--- 解析目标 → 应用于玩家,带空目标与异常保护。
-- 返回 (ok, message) 给 CommandService。
function Common.applyToTargets(
	playerService: any,
	selector: string?,
	excludeSelf: boolean?,
	callback: (Player) -> (boolean?, string?),
): (boolean, string)
	assert(playerService and type(playerService.getTargets) == "function", "playerService required")
	assert(type(callback) == "function", "callback required")

	local targets = playerService:getTargets(selector or "me", excludeSelf or false)
	if #targets == 0 then
		return false, "No valid targets found."
	end

	local failures: { string } = {}
	for _, player in ipairs(targets) do
		local ok, err = pcall(callback, player)
		if not ok then
			table.insert(failures, tostring(err))
		end
	end

	if #failures > 0 then
		return false, ("Applied to %d/%d player(s). Errors: %s"):format(
			#targets - #failures, #targets, table.concat(failures, "; ")
		)
	end
	return true, ("Applied to %d player(s)."):format(#targets)
end

--- 解析数字参数,允许 (值, 默认) 或 nil。
function Common.parseNumber(value: string?, fallback: number?): number?
	if value == nil or value == "" then return fallback end
	return tonumber(value)
end

--- 解析 on/off/true/false 切换。
function Common.parseToggle(value: string?): boolean?
	if value == nil or value == "" then return nil end
	local v = string.lower(value)
	if v == "on" or v == "true"  or v == "1" then return true  end
	if v == "off" or v == "false" or v == "0" then return false end
	-- 纯数字:非 0 表示 on
	local n = tonumber(v)
	if n ~= nil then return n ~= 0 end
	return nil
end

--- 防止命令自身给自己施加效果。
function Common.isSelf(player: Player?): boolean
	return player == Players.LocalPlayer
end

return table.freeze(Common)
